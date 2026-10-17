#!/usr/bin/env python3
"""stored.py: the Apps window's backend (store.qml). One JSON object per line on stdout.

  stored.py home                 the curated page: feature, jobs, picks, with each app's facts
  stored.py search <words>       desktop apps that match, best first
  stored.py app <package>        one app in full: screenshots, description, what's new, whether it can be got
  stored.py install <package>    gets it: progress lines, then {"result": ...}
  stored.py remove <package>     removes it, then {"result": ...}

Where things come from: names, icons, screenshots, descriptions and release notes from Arch's signed app catalogue
(archlinux-appstream-data, /usr/share/swcatalog), matched to packages by its pkgname field; versions, sizes,
licences, what is installed and what this computer can install from pacman itself; the store's own words (jobs, who
each app suits, the feature) from assets/store/editorial.json. Installs and removals go through pkexec, so the
password prompt is the desktop's own (the shell's polkit agent).

Never `pacman -Sy`: refreshing the package lists without updating the system is what leaves an Arch system half
updated. An install that would upgrade anything already installed is refused ("needs a system update first").
"""
import gzip, hashlib, json, os, re, shutil, subprocess, sys, urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor

SHELL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EDITORIAL = os.path.join(SHELL, "assets", "store", "editorial.json")
CATALOGUE = "/usr/share/swcatalog"
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "tacit-store")
LANG = "{http://www.w3.org/XML/1998/namespace}lang"
INDEX_VERSION = 3


def out(obj):
    print(json.dumps(obj), flush=True)


def run(cmd, timeout=60):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, env=dict(os.environ, LC_ALL="C")).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


# ---- the catalogue ---------------------------------------------------------------------------------------------

def english(c, tag):
    for e in c.findall(tag):
        if e.get(LANG) in (None, "en", "en-GB", "en-US"):
            return (e.text or "").strip()
    return ""


def paragraphs(desc):
    if desc is None:
        return []
    out_ = []
    for e in desc:
        if e.tag == "p" and (e.text or "").strip():
            out_.append(" ".join(e.text.split()))
        elif e.tag in ("ul", "ol"):
            items = [" ".join((li.text or "").split()) for li in e if (li.text or "").strip()]
            if items:
                out_.append(" · ".join(items))
    return out_


def component(c, origin):
    pkg = c.findtext("pkgname") or ""
    desc = next((d for d in c.findall("description") if d.get(LANG) is None), None)
    icon = next((i.text for i in c.findall("icon") if i.get("type") == "cached" and i.get("width") == "128"), None)
    shots = []
    sc = c.find("screenshots")
    for s in (list(sc) if sc is not None else []):
        src = next((i.text for i in s if i.tag == "image" and i.get("type") == "source" and i.get(LANG) is None), None)
        cap = next(((x.text or "").strip() for x in s if x.tag == "caption" and x.get(LANG) is None), "")
        if src:
            shots.append({"url": src.strip(), "caption": cap})
    rel = c.find("releases")
    release = None
    if rel is not None and len(rel):
        r0 = rel[0]
        rd = next((d for d in r0.findall("description") if d.get(LANG) is None), None)
        release = {"version": r0.get("version") or "", "notes": paragraphs(rd)}
    keywords = []
    for k in c.findall("keywords"):
        if k.get(LANG) in (None, "en"):
            keywords += [(w.text or "").strip().lower() for w in k if (w.text or "").strip()]
    return pkg, {
        "id": c.findtext("id") or "", "name": english(c, "name"), "summary": english(c, "summary"),
        "developer": english(c, "developer_name") or (c.find("developer").findtext("name") if c.find("developer") is not None else "") or "",
        "license": c.findtext("project_license") or "",
        "homepage": next(((u.text or "").strip() for u in c.findall("url") if u.get("type") == "homepage"), ""),
        "desktop": next(((l.text or "").strip() for l in c.findall("launchable") if l.get("type") == "desktop-id"), ""),
        "icon": f"{CATALOGUE}/icons/{origin}/128x128/{icon}" if icon else "",
        "shots": shots, "release": release, "description": paragraphs(desc), "keywords": keywords,
    }


def load_index():
    files = [f"{CATALOGUE}/xml/{r}.xml.gz" for r in ("core", "extra", "multilib") if os.path.exists(f"{CATALOGUE}/xml/{r}.xml.gz")]
    stamp = [INDEX_VERSION] + [os.path.getmtime(f) for f in files]
    path = os.path.join(CACHE, "index.json")
    try:
        cached = json.load(open(path))
        if cached.get("stamp") == stamp:
            return cached["apps"]
    except (OSError, ValueError):
        pass
    apps = {}
    for f in files:
        root = ET.parse(gzip.open(f)).getroot()
        origin = root.get("origin") or ""
        for c in root:
            if c.get("type") != "desktop-application":
                continue
            pkg, info = component(c, origin)
            if not pkg:
                continue
            # a package with several apps (LibreOffice: Base, Calc, … and "LibreOffice"): keep the umbrella one,
            # whose name is the shortest
            if pkg in apps and len(apps[pkg]["name"] or "~" * 99) <= len(info["name"] or "~" * 99):
                continue
            apps[pkg] = info
    os.makedirs(CACHE, exist_ok=True)
    tmp = path + ".tmp"
    json.dump({"stamp": stamp, "apps": apps}, open(tmp, "w"))
    os.replace(tmp, path)
    return apps


# ---- pacman ------------------------------------------------------------------------------------------------------

def available():
    return set(run(["pacman", "-Slq"]).split())


def installed():
    return set(run(["pacman", "-Qq"]).split())


def mib(text):
    m = re.match(r"([\d.]+)\s*(B|KiB|MiB|GiB)", text or "")
    if not m:
        return 0
    return round(float(m.group(1)) * {"B": 1 / 1048576, "KiB": 1 / 1024, "MiB": 1, "GiB": 1024}[m.group(2)] * 1.048576)   # MB


def facts(pkgs):
    """version, download and installed size (MB), licences from the repos, for several packages in one call"""
    res, cur = {}, None
    for line in run(["pacman", "-Si", *pkgs], timeout=120).splitlines():
        if ":" not in line:
            continue
        k, v = (x.strip() for x in line.split(":", 1))
        if k == "Name":
            cur = res.setdefault(v, {})
        elif cur is not None and k == "Version":
            cur["version"] = v.split(":")[-1].rsplit("-", 1)[0]
        elif cur is not None and k == "Download Size":
            cur["download"] = mib(v)
        elif cur is not None and k == "Installed Size":
            cur["size"] = mib(v)
        elif cur is not None and k == "Licenses":
            cur["licenses"] = v
    return res


def free_license(spdx):
    s = (spdx or "").lower()
    return bool(s) and "proprietary" not in s and "licenseref" not in s


# ---- pictures ----------------------------------------------------------------------------------------------------

def icon_png(src):
    """the catalogue's icons are JPEG XL, which Qt cannot read: converted once, kept"""
    if not src or not os.path.exists(src):
        return ""
    dst = os.path.join(CACHE, "icons", os.path.basename(src).rsplit(".", 1)[0] + ".png")
    if not os.path.exists(dst):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        subprocess.run(["magick", src, dst], capture_output=True, timeout=30)
    return dst if os.path.exists(dst) else ""


def shot(url):
    """a screenshot from the developer's own site, kept at most 1600 px wide as JPEG; "" when it cannot be had"""
    name = hashlib.sha1(url.encode()).hexdigest()[:20]
    dst = os.path.join(CACHE, "shots", name + ".jpg")
    if os.path.exists(dst):
        return dst
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    raw = dst + ".download"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Tacit Apps"})
        with urllib.request.urlopen(req, timeout=20) as r, open(raw, "wb") as f:
            f.write(r.read(40 * 1024 * 1024))
        subprocess.run(["magick", raw + "[0]", "-resize", "1600x>", "-quality", "86", dst], capture_output=True, timeout=60)
    except Exception:
        pass
    finally:
        if os.path.exists(raw):
            os.remove(raw)
    return dst if os.path.exists(dst) else ""


# ---- what the window gets ----------------------------------------------------------------------------------------

def cropped(path, crop):
    """the part of a screenshot a featured picture shows (editorial.json gives it as fractions); kept beside it"""
    if not path or not crop:
        return path
    dst = path[:-4] + "-" + hashlib.sha1(json.dumps(crop).encode()).hexdigest()[:8] + ".jpg"
    if not os.path.exists(dst):
        size = run(["identify", "-format", "%w %h", path]).split()
        if len(size) != 2:
            return path
        w, h = int(size[0]), int(size[1])
        x, y, cw, ch = (round(crop[0] * w), round(crop[1] * h), round(crop[2] * w), round(crop[3] * h))
        subprocess.run(["magick", path, "-crop", f"{cw}x{ch}+{x}+{y}", "+repage", "-quality", "88", dst], capture_output=True, timeout=60)
    return dst if os.path.exists(dst) else path


def tone(path):
    """a picture's own colour for the window to carry (a wash behind the page, the shade under words on it): of
    the picture's main colours, the one with the most colour in it that is neither near black nor near white"""
    if not path:
        return ""
    out_ = run(["magick", path, "-resize", "96x96", "-colors", "8", "-format", "%c", "histogram:info:-"], timeout=30)
    best, score = "", 0.0
    for line in out_.splitlines():
        m = re.search(r"(\d+):.*#([0-9A-Fa-f]{6})", line)
        if not m:
            continue
        n, hx = int(m.group(1)), m.group(2)
        r, g, b = (int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4))
        hi, lo = max(r, g, b), min(r, g, b)
        light = (hi + lo) / 2
        sat = 0 if hi == lo else (hi - lo) / (1 - abs(2 * light - 1))
        if not 0.18 < light < 0.82:
            continue
        sc = n * (0.15 + sat) ** 2
        if sc > score:
            best, score = "#" + hx.lower(), sc
    return best


def editorial():
    return json.load(open(EDITORIAL))


def info(pkg, cat, ed, avail, inst, f=None):
    c = cat.get(pkg, {})
    e = ed["apps"].get(pkg, {})
    names = [pkg] + e.get("also", [])
    have = next((n for n in names if n in inst), "")
    f = f or {}
    return {
        "pkg": pkg, "name": e.get("name") or c.get("name") or pkg, "line": e.get("line") or c.get("summary", ""), "like": e.get("like", ""),
        "developer": c.get("developer", ""), "icon": icon_png(c.get("icon", "")), "desktop": c.get("desktop", ""),
        "available": pkg in avail or bool(have), "installed": bool(have), "installedAs": have,
        "version": f.get("version", ""), "download": f.get("download", 0), "size": f.get("size", 0),
        "free": free_license(c.get("license") or f.get("licenses", "")),
    }


def home():
    ed, cat, avail, inst = editorial(), load_index(), available(), installed()
    pkgs = sorted({p for j in ed["jobs"] for p in j["pkgs"]} | set(ed["picks"]) | {ed["feature"]["pkg"]})
    f = facts([p for p in pkgs if p in avail])
    apps = {p: info(p, cat, ed, avail, inst, f.get(p)) for p in pkgs}
    def first_shot(p):
        return next((s for s in (shot(x["url"]) for x in cat.get(p, {}).get("shots", [])[:2]) if s), "")
    feature = dict(ed["feature"], picture=cropped(first_shot(ed["feature"]["pkg"]), ed["feature"].get("crop")))
    feature["tone"] = tone(feature["picture"])
    picks = [{"pkg": p, "picture": cropped(first_shot(p), ed["apps"].get(p, {}).get("crop"))} for p in ed["picks"]]
    for pk in picks:
        pk["tone"] = tone(pk["picture"])
    windows = None
    for path in (os.environ.get("STORE_WINDOWS_APPS", ""), os.path.expanduser("~/.local/state/tacit-setup/windows-apps.json")):
        if path and os.path.exists(path):
            windows = json.load(open(path))
            break
    out({"arch": os.uname().machine, "feature": feature, "picks": picks, "jobs": ed["jobs"], "apps": apps, "windows": windows,
         "installed": sorted(p for p in apps if apps[p]["installed"])})


def search(words):
    q = " ".join(words).lower().strip()
    if not q:
        return out({"query": q, "apps": []})
    ed, cat, avail, inst = editorial(), load_index(), available(), installed()
    scored = []
    for pkg, c in cat.items():
        if pkg not in avail and pkg not in inst:
            continue
        name, summ = c["name"].lower(), c["summary"].lower()
        s = 0
        if name == q or pkg == q:
            s += 10
        elif name.startswith(q):
            s += 6
        elif q in name:
            s += 4
        if any(q == k or q in k for k in c["keywords"]):
            s += 3
        if q in summ:
            s += 2
        if pkg in ed["apps"]:
            s += 1 if s else 0
        if s:
            scored.append((-s, name, pkg))
    scored.sort()
    out({"query": q, "apps": [info(p, cat, ed, avail, inst) for _, _, p in scored[:24]]})


def targets(pkg):
    """what installing `pkg` would download: [(name, MB)]"""
    res = []
    for line in run(["pacman", "-Sp", "--print-format", "%n %s", pkg], timeout=120).splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1].isdigit():
            res.append((parts[0], round(int(parts[1]) / 1e6)))
    return res


def plan(pkg, inst):
    """whether `pkg` can be got now, and if not why, in the window's words"""
    t = targets(pkg)
    if not t:
        return {"can": False, "why": "unavailable", "count": 0}
    upgrades = [n for n, _ in t if n in inst and n != pkg]
    if upgrades:
        return {"can": False, "why": "update", "count": len(t), "upgrades": upgrades[:6]}
    f = facts([n for n, _ in t])
    need = sum(f.get(n, {}).get("size", 0) for n, _ in t)
    free = shutil.disk_usage("/").free // 1_000_000
    if need + 500 > free:
        return {"can": False, "why": "space", "count": len(t), "need": need, "freeMB": free}
    return {"can": True, "count": len(t), "download": sum(s for _, s in t), "need": need}


def app(pkg):
    ed, cat, avail, inst = editorial(), load_index(), available(), installed()
    f = facts([pkg]) if pkg in avail else {}
    a = info(pkg, cat, ed, avail, inst, f.get(pkg))
    c = cat.get(pkg, {})
    with ThreadPoolExecutor(4) as pool:   # the developers' sites, all at once
        paths = list(pool.map(shot, [x["url"] for x in c.get("shots", [])[:4]]))
    a["shots"] = [{"path": p, "caption": x["caption"]} for p, x in zip(paths, c.get("shots", [])[:4]) if p]
    a["hero"] = cropped(a["shots"][0]["path"], ed["apps"].get(pkg, {}).get("crop")) if a["shots"] else ""
    a["tone"] = tone(a["hero"] or a["icon"])
    a["description"] = c.get("description", [])[:2]
    rel = c.get("release")
    # "what's new" only for the version this computer would get: the catalogue can lag the repos
    a["whatsNew"] = [n for n in rel["notes"] if len(n) > 24][:2] if rel and a["version"] and rel["version"] and a["version"].startswith(rel["version"]) else []
    a["homepage"] = c.get("homepage", "")
    a["plan"] = {"can": False, "why": "installed"} if a["installed"] else (plan(pkg, inst) if a["available"] else {"can": False, "why": "unavailable"})
    out(a)


PKEXEC = ["pkexec", "--disable-internal-agent", "/usr/bin/env", "LC_ALL=C", "/usr/bin/stdbuf", "-oL", "/usr/bin/pacman"]


def why(code, lines):
    text = "\n".join(lines[-30:]).lower()
    if code in (126, 127):
        return "cancelled"
    if "unable to lock database" in text:
        return "busy"
    if "failed retrieving file" in text or "could not resolve" in text or "failed to download" in text:
        return "offline"
    if "not enough free disk space" in text:
        return "space"
    return "failed"


def install(pkg):
    inst = installed()
    if pkg in inst:
        return out({"result": "ok"})
    p = plan(pkg, inst)
    if not p["can"]:
        return out({"result": p["why"], "plan": p})
    total, dl, done_inst, n = max(1, p["count"]), 0, 0, 0
    out({"progress": 0.02, "phase": "Waiting for your password"})
    proc = subprocess.Popen(PKEXEC + ["-S", "--noconfirm", "--needed", pkg], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace")
    lines = []
    for line in proc.stdout:
        line = line.rstrip()
        lines.append(line)
        if line.endswith("downloading...") or re.search(r"\sdownloading\b", line):
            dl += 1
            out({"progress": 0.05 + 0.6 * min(dl, total) / total, "phase": f"Downloading {min(dl, total)} of {total}"})
        elif line.startswith(":: Processing package changes"):
            out({"progress": 0.7, "phase": "Installing"})
        else:
            m = re.match(r"\(\s*(\d+)/(\d+)\)\s+(installing|reinstalling|upgrading)\s", line)
            if m:
                done_inst, n = int(m.group(1)), int(m.group(2))
                out({"progress": 0.7 + 0.28 * done_inst / max(1, n), "phase": f"Installing {done_inst} of {n}"})
    code = proc.wait()
    if code == 0:
        return out({"result": "ok"})
    out({"result": why(code, lines), "detail": lines[-1] if lines else ""})


def remove(pkg):
    ed, inst = editorial(), installed()
    names = [pkg] + ed["apps"].get(pkg, {}).get("also", [])
    have = next((n for n in names if n in inst), None)
    if not have:
        return out({"result": "ok"})
    required = re.search(r"^Required By\s*:\s*(.+)$", run(["pacman", "-Qi", have]), re.M)
    if required and required.group(1).strip() != "None":
        return out({"result": "needed", "by": required.group(1).split()[:4]})
    proc = subprocess.run(PKEXEC + ["-Rs", "--noconfirm", have], capture_output=True, text=True, errors="replace")
    out({"result": "ok"} if proc.returncode == 0 else {"result": why(proc.returncode, (proc.stdout + proc.stderr).splitlines())})


if __name__ == "__main__":
    cmd, args = (sys.argv[1] if len(sys.argv) > 1 else ""), sys.argv[2:]
    commands = {"home": lambda: home(), "search": lambda: search(args), "app": lambda: app(args[0]),
                "install": lambda: install(args[0]), "remove": lambda: remove(args[0])}
    if cmd not in commands or (cmd in ("app", "install", "remove") and not args):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    commands[cmd]()
