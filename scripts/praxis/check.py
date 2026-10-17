#!/usr/bin/env python3
"""Praxis live check: real Claude sessions (Haiku) driven through a test copy of Praxis, out of sight.

    python3 -I scripts/praxis/check.py [--config CLAUDE_QML] [--host AGENT_HOST] [--keep]

Starts its own headless weston, a scratch agent-host (its own socket, state and cache) and Praxis from --config
(default: the live ~/.config/quickshell/tacit/claude.qml) with PRAXIS_TEST=1, which turns on the probe in
Conversation.qml. It makes its own sessions in ~/research/praxis-live-test and sends only into those (the probe
refuses any other: a test once wrote into the owner's conversation). Prints one line per check and exits 1 if any
failed. Screenshots and logs stay in the run folder it prints. A run costs a few Haiku turns and one small agent.
"""
import json, os, socket, subprocess, sys, tempfile, time, uuid

HOME = os.path.expanduser("~")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
args = sys.argv[1:]
def opt(name, default):
    return args[args.index(name) + 1] if name in args else default
CONFIG = opt("--config", f"{HOME}/.config/quickshell/tacit/claude.qml")
HOST = opt("--host", f"{HOME}/.local/bin/agent-host")
CWD = f"{HOME}/research/praxis-live-test"
MODEL = "claude-haiku-5-5"

run = tempfile.mkdtemp(prefix="praxis-check-")
pxr = f"{RUNTIME}/pxc{os.getpid() % 10000}"   # short: a socket path has a length limit
os.makedirs(pxr, mode=0o700, exist_ok=True)
os.makedirs(CWD, exist_ok=True)
for d in ("state", "cache"):
    os.makedirs(f"{run}/{d}", exist_ok=True)
sock = f"{pxr}/agent-host.sock"
wl = f"praxis-check-{os.getpid()}"
procs = []
results = []

def spawn(cmd, log, env=None):
    p = subprocess.Popen(cmd, stdout=open(f"{run}/{log}", "w"), stderr=subprocess.STDOUT, env={**os.environ, **(env or {})},
                         start_new_session=True)
    procs.append(p)
    return p

def wait_for(pred, limit, step=0.2):
    end = time.time() + limit
    while time.time() < end:
        try:
            v = pred()
            if v:
                return v
        except Exception:
            pass
        time.sleep(step)
    return None

def ipc(target, fn, *a):
    env = {**os.environ, "XDG_RUNTIME_DIR": pxr, "WAYLAND_DISPLAY": f"{RUNTIME}/{wl}"}
    r = subprocess.run(["qs", "-p", CONFIG, "ipc", "call", target, fn, *a], env=env, capture_output=True, text=True, timeout=20)
    return r.stdout.strip()

def state():
    return json.loads(ipc("praxistest", "state") or "{}")

def host_request(req):
    s = socket.socket(socket.AF_UNIX)
    s.connect(sock)
    f = s.makefile("rw")
    f.write(json.dumps(req) + "\n")
    f.flush()
    for _ in range(20):
        r = json.loads(f.readline())
        if r.get("ev") in ("started", "error"):
            return r
    return {}

def check(name, ok, detail=""):
    results.append(ok)
    print(("ok   " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""), flush=True)
    if not ok:
        ipc("claudeapp", "shot", f"{run}/fail-{len(results)}.png")

def open_session(sid):
    """Opens one of this run's sessions by id (claudeapp testOpen, which refuses any other); verified by the probe."""
    return wait_for(lambda: ipc("claudeapp", "testOpen", sid) != "refused" and state().get("session") == sid, 30, 0.5)

def settled(limit=90):
    return wait_for(lambda: (lambda s: s and not s["busy"] and not s["echo"] and not s["loading"])(state()), limit, 0.4)

def watch(limit, every=0.1):
    """State every `every` s for `limit` s: the worst seen of the things that must never show."""
    seen = {"queuedRows": 0, "waitingRows": 0, "echoAt": None, "agentRow": "", "states": 0}
    t0 = time.time()
    while time.time() - t0 < limit:
        s = state()
        seen["states"] += 1
        seen["queuedRows"] = max(seen["queuedRows"], s.get("queuedRows", 0))
        seen["waitingRows"] = max(seen["waitingRows"], s.get("waitingRows", 0))
        if s.get("echo") and seen["echoAt"] is None:
            seen["echoAt"] = round(time.time() - t0, 2)
        for tool, desc in s.get("liveTools", []):
            if tool in ("Agent", "Task") and desc:
                seen["agentRow"] = desc
        time.sleep(every)
    return seen

try:
    spawn(["weston", "--backend=headless", "--renderer=gl", f"--socket={wl}", "--width=1280", "--height=900", "--shell=kiosk"], "weston.log")
    if not wait_for(lambda: os.path.exists(f"{RUNTIME}/{wl}"), 15):
        sys.exit("weston did not start")
    # a cache kept between runs: the history of every session is indexed once, not on every run
    os.makedirs(f"{HOME}/.cache/praxis-check", exist_ok=True)
    host = spawn([HOST, "--socket", sock], "host.log", {"XDG_STATE_HOME": f"{run}/state", "AGENT_HOST_CACHE": f"{HOME}/.cache/praxis-check"})
    if not wait_for(lambda: os.path.exists(sock), 15):
        sys.exit("agent-host did not start")
    ids = [str(uuid.uuid4()) for _ in range(2)]
    with open(f"{RUNTIME}/notch-quiet-sessions", "a") as f:   # the real notch: these are no one's
        f.write("".join(i + "\n" for i in ids))
    spawn(["dbus-run-session", "--", "qs", "-p", CONFIG], "praxis.log",
          {"XDG_RUNTIME_DIR": pxr, "WAYLAND_DISPLAY": f"{RUNTIME}/{wl}", "XDG_STATE_HOME": f"{run}/state",
           "PRAXIS_TEST": "1", "PRAXIS_TEST_SESSIONS": ",".join(ids),
           # its own sessions are told from terminals by the host's children: this host's, not the oldest agent-host's
           "PRAXIS_HOST_PID": str(host.pid)})
    if not wait_for(lambda: "Configuration Loaded" in open(f"{run}/praxis.log").read() or "Failed to load" in open(f"{run}/praxis.log").read(), 40):
        sys.exit("Praxis did not load")
    if "Failed to load" in open(f"{run}/praxis.log").read():
        sys.exit("Praxis failed to load: see " + f"{run}/praxis.log")
    print(f"run folder: {run}", flush=True)

    a, b = ids
    # long enough to scroll: a jump only shows where the view can move (a short conversation sits still)
    long = "Write 40 numbered lines, each one sentence of about 15 words about the history of tea. Plain text, no headings."
    for sid, text in ((a, long), (b, "Reply with the single word set.")):
        r = host_request({"op": "start", "id": sid, "cwd": CWD, "model": MODEL, "mode": "auto", "text": text})
        check(f"session {sid[:8]} started", r.get("ev") == "started", json.dumps(r)[:160])
    opened = bool(open_session(a))
    check("a test session opens", opened)
    if not opened:
        rows = json.loads(ipc("claudeapp", "rowsJson", "12"))
        rows = rows if isinstance(rows, list) else rows.get("rows", rows)
        print("     rows: " + "; ".join(f"{r.get('key', '')[:12]} {r.get('state', '')}" for r in rows[:12]))
        print("     praxis: " + ipc("claudeapp", "state")[:300])
    settled()
    wait_for(lambda: state().get("users", 0) >= 1, 30)

    # 0. the watch itself: a jump made on purpose is seen (a quiet watch must not pass the checks below). Only a
    # conversation longer than the view can move: the first reply is asked long, and waited for.
    scrollable = wait_for(lambda: (lambda w: w and w.get("ch", 0) > w.get("h", 0) + 150)(state().get("watch")), 60, 0.5)
    if not scrollable:
        print("     the first reply is too short to scroll: " + json.dumps(state().get("watch")))
    time.sleep(1)
    ipc("praxistest", "reset")
    before = state().get("watch")
    ipc("praxistest", "nudge")
    time.sleep(0.5)
    print("     watch before " + json.dumps(before) + "\n     watch after  " + json.dumps(state().get("watch")))
    seen = len(state().get("snaps", [])) > 0
    check("the jump watch sees a jump made on purpose", seen, "watch " + json.dumps(state().get("watch")))
    ipc("praxistest", "reset")

    # 1. a message sent while idle: no jump, no queue row, its row read
    ipc("praxistest", "reset")
    users = state().get("users", 0)
    check("the test sends into its own session", ipc("praxistest", "send", "Say hello in one sentence.") == "sent")
    seen = watch(4)
    settled()
    s = state()
    check("idle send: the bubble shows at once", seen["echoAt"] is not None and seen["echoAt"] < 0.5, f"echo at {seen['echoAt']}")
    check("idle send: no queue or waiting row", seen["queuedRows"] == 0 and seen["waitingRows"] == 0, json.dumps(seen))
    check("idle send: the view never jumped", s.get("snaps") == [], f"snaps {json.dumps(s.get('snaps'))}")
    check("idle send: its row came and the bubble went", s.get("users", 0) == users + 1 and not s.get("echo"), json.dumps(s)[:200])

    # 2. a message sent while it works: shows as sent at once, the run stops, it goes; no queue row, no jump
    ipc("praxistest", "reset")
    users = state().get("users", 0)
    ipc("praxistest", "send", "Run the shell command `sleep 6` with the Bash tool, then reply with the word ready.")
    wait_for(lambda: state().get("turnOpen"), 30)
    time.sleep(2.5)
    ipc("praxistest", "send", "What is 2+2? One word.")
    seen = watch(4)
    settled()
    s = state()
    check("send while working: the bubble shows at once", seen["echoAt"] is not None and seen["echoAt"] < 0.5, f"echo at {seen['echoAt']}")
    check("send while working: no queue or waiting row", seen["queuedRows"] == 0 and seen["waitingRows"] == 0, json.dumps(seen))
    check("send while working: the view never jumped", s.get("snaps") == [], f"snaps {json.dumps(s.get('snaps'))}")
    check("send while working: both messages are rows", s.get("users", 0) == users + 2, json.dumps({k: s.get(k) for k in ("echo", "busy", "turnOpen", "users")}))
    if s.get("users", 0) != users + 2:
        print("     events: " + "\n             ".join(s.get("events", [])))

    # 3. an agent call shows while Claude writes it
    ipc("praxistest", "reset")
    ipc("praxistest", "send", "Use the Agent tool exactly once (subagent_type general-purpose) with the description 'Count the files here' "
        "and a prompt of about 300 words explaining step by step how to count the files in the current folder with ls and wc and "
        "to report only the number. Then tell me the number in one sentence.")
    seen = watch(25, 0.15)
    settled(120)
    check("an agent call shows while it is written", seen["agentRow"] == "Count the files here", f"saw {seen['agentRow']!r}")
    s = state()
    check("the agent turn: the view never jumped", s.get("snaps") == [], f"snaps {json.dumps(s.get('snaps'))}")
    if s.get("snaps"):
        print("     events: " + "\n             ".join(s.get("events", [])[-45:]))

    # 5. smoothness (60 Hz: a frame is 16.7 ms; one over 33 ms is a visible skip)
    def frames():
        return json.loads(ipc("praxistest", "frames") or "{}")
    ipc("praxistest", "reset")
    ipc("praxistest", "send", "Write 25 numbered lines, each one short sentence about coffee. Plain text.")
    wait_for(lambda: state().get("busy"), 20)
    settled(120)
    f = frames()
    check("a reply streaming in stays smooth (95 % of frames under 20 ms, no skip over 2)", f.get("p95", 99) <= 20 and f.get("over33", 99) <= 2, json.dumps(f))
    time.sleep(1)
    ipc("praxistest", "reset")
    ipc("praxistest", "scroll")
    time.sleep(4.6)
    f = frames()
    check("a fast skim through the conversation stays smooth (95 % under 20 ms, at most 2 skips)", f.get("p95", 99) <= 20 and f.get("over33", 99) <= 2, json.dumps(f))

    # 4. a switch does not rebuild the session on its way out
    open_session(b)
    settled()
    ipc("praxistest", "reset")
    open_session(a)
    time.sleep(2)
    s = state()
    check("a switch does not rebuild the old session", s.get("rebuiltOld") == 0, f"rebuilt {s.get('rebuiltOld')}")
    f = frames()
    check("a switch does not freeze the window (no frame over 50 ms)", f.get("max", 999) <= 50, json.dumps(f))

    # 6. a real conversation of yours, read only (opened and scrolled, never sent to): the biggest of the past ones
    big = None
    blinks = []
    rows = wait_for(lambda: (lambda r: r if r else None)([r for r in (lambda x: x if isinstance(x, list) else x.get("rows", []))(
        json.loads(ipc("claudeapp", "rowsJson", "60") or "[]")) if r.get("type") == "session" and r.get("state") == "past"]), 120, 2) or []
    for r in rows[:8]:
        i = next((k for k, x in enumerate((lambda x: x if isinstance(x, list) else x.get("rows", []))(json.loads(ipc("claudeapp", "rowsJson", "60")))) if x.get("key") == r.get("key")), None)
        if i is None:
            continue
        ipc("praxistest", "reset")
        ipc("claudeapp", "selectRow", str(i))
        time.sleep(4)
        n = json.loads(ipc("claudeapp", "state")).get("items", 0)
        f = frames()
        # every frame after the switch: at the end, rows at the top and the middle of the view (a blank, then a slide, 2026-10-10)
        sw = json.loads(ipc("praxistest", "switchFrames") or "[]")
        blinks += [f"{r.get('text', '')[:20]} frame {k}: {x}" for k, x in enumerate(sw) if x["tall"] and (x["off"] != 0 or x["top"] < 0 or x["mid"] < 0)]
        if not big or n > big[1]:
            big = (i, n, f, r.get("text", "")[:30])
        if n >= 300:
            break
    check("a switch shows the conversation at once (each frame at the end, no empty part)", rows != [] and not blinks, "; ".join(blinks[:4]))
    if big and big[1] >= 100:
        i, n, f, title = big
        check(f"opening a big conversation of yours ({n} rows) does not freeze (no frame over 50 ms)", f.get("max", 999) <= 50, json.dumps(f))
        ipc("claudeapp", "selectRow", str(i))
        time.sleep(4)
        ipc("praxistest", "reset")
        ipc("praxistest", "scroll")
        time.sleep(4.6)
        f = frames()
        check(f"a fast skim through it stays smooth (95 % under 20 ms, at most 2 skips)", f.get("p95", 99) <= 20 and f.get("over33", 99) <= 2, json.dumps(f))
    else:
        print("     (no past conversation of 100+ rows found to scroll)")
    ipc("claudeapp", "shot", f"{run}/end.png")
finally:
    for p in reversed(procs):
        try:
            os.killpg(p.pid, 15)
        except Exception:
            pass
    time.sleep(1)
    for p in procs:
        try:
            os.killpg(p.pid, 9)
        except Exception:
            pass
    print(f"{sum(results)}/{len(results)} passed; logs and pictures in {run}")
sys.exit(0 if results and all(results) else 1)
