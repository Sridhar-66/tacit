.pragma library

// What the viewer says about a file, as plain strings. No state: everything is passed in.

var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function bytes(n) {
    if (!(n >= 0)) return "";
    if (n < 1000) return n + " B";
    if (n < 1e6) return Math.round(n / 1e3) + " KB";
    if (n < 1e9) return (n / 1e6).toFixed(1) + " MB";
    return (n / 1e9).toFixed(1) + " GB";
}

// 9000 -> "0:09", 4331000 -> "1:12:11"
function clock(ms) {
    var s = Math.max(0, Math.floor(ms / 1000)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
    var two = function (x) { return (x < 10 ? "0" : "") + x; };
    return h > 0 ? h + ":" + two(m) + ":" + two(r) : m + ":" + two(r);
}

function hm(d) { return (d.getHours() < 10 ? "0" : "") + d.getHours() + ":" + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes(); }
function dateShort(d) { return d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear(); }
function dateLong(d) { return DAYS[d.getDay()] + " " + dateShort(d) + ", " + hm(d); }
function dateDay(d) { return DAYS[d.getDay()].slice(0, 3) + " " + dateShort(d); }

function ago(d, now) {
    var s = (now - d.getTime()) / 1000;
    if (s < 60) return "just now";
    var units = [["year", 31557600], ["month", 2629800], ["week", 604800], ["day", 86400], ["hour", 3600], ["minute", 60]];
    for (var i = 0; i < units.length; i++) {
        var n = Math.floor(s / units[i][1]);
        if (n >= 1) return n + " " + units[i][0] + (n > 1 ? "s" : "") + " ago";
    }
    return "";
}

// EXIF "2024:09:14 14:32:08" -> Date, or null
function exifDate(s) {
    var m = /^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)/.exec(s || "");
    return m ? new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) : null;
}

function paper(w, h) {
    var a = Math.min(w, h), b = Math.max(w, h);
    if (Math.abs(a - 595) < 4 && Math.abs(b - 842) < 4) return "A4";
    if (Math.abs(a - 612) < 4 && Math.abs(b - 792) < 4) return "Letter";
    if (Math.abs(a - 420) < 4 && Math.abs(b - 595) < 4) return "A5";
    return "";
}

var CODEC = { h264: "H.264", hevc: "H.265", vp9: "VP9", av1: "AV1", vp8: "VP8", aac: "AAC", mp3: "MP3", opus: "Opus",
              vorbis: "Vorbis", flac: "FLAC", pcm_s16le: "PCM", alac: "ALAC", mpeg4: "MPEG-4" };
function codec(c) { return CODEC[c] || (c || "").toUpperCase(); }

function channels(n) { return n === 1 ? "mono" : n === 2 ? "stereo" : n > 2 ? n + " channels" : ""; }
function rate(hz) { return hz ? (hz / 1000).toFixed(hz % 1000 ? 1 : 0) + " kHz" : ""; }

function join(parts) { return parts.filter(function (p) { return p && p.length; }).join(", "); }

var FORMAT = { jpg: "JPEG", jpeg: "JPEG", png: "PNG", webp: "WebP", gif: "GIF", bmp: "BMP", svg: "SVG", tif: "TIFF", tiff: "TIFF", ico: "ICO" };
function format(path) { var x = path.split(".").pop().toLowerCase(); return FORMAT[x] || x.toUpperCase(); }

function kindOf(path) {
    var x = path.split(".").pop().toLowerCase();
    for (var k in KINDS) if (KINDS[k].indexOf(x) >= 0) return k;
    return "file";
}
var KINDS = {
    image: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "tiff", "tif", "ico"],
    pdf: ["pdf"],
    video: ["mp4", "mkv", "webm", "mov", "avi", "m4v"],
    audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac"]
};
function patterns() {
    var out = [];
    for (var k in KINDS) KINDS[k].forEach(function (x) { out.push("*." + x, "*." + x.toUpperCase()); });
    return out;
}

// ---- plain words

// "Codsi_Beddelidda_Lambarka.pdf" -> "Codsi Beddelidda Lambarka": no extension, separators as spaces
var MON_L = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var STAMPED = { img: "Photo", pxl: "Photo", dsc: "Photo", dscn: "Photo", vid: "Video", screenshot: "Screenshot", screenrecording: "Screen recording" };
// "Screenshot from 2026-10-02 21-14-07", "IMG_20240914_143208" -> "Screenshot, 2 October 2026 at 21:14"
function stamped(n, kind) {
    var m = /^(.*?)[ _-]*(?:from[ _-]*)?(\d{4})[-_. ]?(\d\d)[-_. ]?(\d\d)[ _T.-]+(\d\d)[-_. :]?(\d\d)(?:[-_. :]?\d\d)?(?:[ _-]*\(?(\d*)\)?)?$/.exec(n);
    if (!m || +m[3] < 1 || +m[3] > 12) return "";
    var lead = m[1].replace(/[_\-.]+/g, " ").replace(/\s+/g, " ").trim();
    lead = STAMPED[lead.toLowerCase().replace(/ /g, "")] || lead || KIND_LEAD[kind] || "Picture";
    return lead + ", " + (+m[4]) + " " + MON_L[+m[3] - 1] + " " + m[2] + " at " + m[5] + ":" + m[6] + (m[7] ? " (" + m[7] + ")" : "");
}
// a machine id or hash says nothing to a person: "Ansökan_cfa3e791-35cc-46d6-8c45-7172d7705f88" -> "Ansökan"
var UUID = /[0-9a-f]{8}[-_][0-9a-f]{4}[-_][0-9a-f]{4}[-_][0-9a-f]{4}[-_][0-9a-f]{12}/gi;
function isHash(w) { return w.length >= 16 && /^[0-9a-z]+$/i.test(w) && /\d/.test(w) && /[a-z]/i.test(w); }
var KIND_LEAD = { image: "Picture", pdf: "Document", video: "Video", audio: "Recording" };
function stem(name) {
    var n = name, m;
    while ((m = /\.([A-Za-z0-9]{1,5})$/.exec(n)) && (n === name || isKnownExt(m[1]))) n = n.slice(0, m.index);
    return n;
}
// kind and at (the file's date) are for a name that is only an id: "Picture, 14 September 2024"
function title(name, kind, at) {
    var n = stem(name);
    // a song's file name often starts with its track number: "01 Slow Water", "03 - Tide"
    if (kind === "audio") { var bare = n.replace(/^\d{1,3}(?:\s*[-._)]\s*|[\s_]+)/, ""); if (bare.length) n = bare; }
    var st = stamped(n, kind);
    if (st) return st;
    var t = n.replace(UUID, " ").replace(/[_\-.]+/g, " ").split(/\s+/).filter(function (w) { return w.length && !isHash(w); }).join(" ");
    if (!t.length && KIND_LEAD[kind]) {
        var d = at ? new Date(at) : null;
        return KIND_LEAD[kind] + (d && !isNaN(d.getTime()) ? ", " + d.getDate() + " " + MON_L[d.getMonth()] + " " + d.getFullYear() : "");
    }
    if (!t.length) t = n.replace(/[_\-.]+/g, " ").replace(/\s+/g, " ").trim();
    return t.length ? t : name;
}
// the folder's own name, as words: "my_files" -> "My files"
function folderTitle(dir) {
    var last = dir.split("/").pop();
    if (!last) return "/";
    var t = last.replace(/[_\-]+/g, " ").trim();
    return cap(t);
}
function isKnownExt(x) {
    x = x.toLowerCase();
    for (var k in KINDS) if (KINDS[k].indexOf(x) >= 0) return true;
    return false;
}

// "PDF", "Photo", "Video", "Song"; o.origin tells a screenshot, m is the probe (EXIF present = a photo)
function kindWord(e, m, o) {
    var x = e.path.split(".").pop().toLowerCase();
    if (e.kind === "pdf") return "PDF";
    if (e.kind === "video") return "Video";
    if (e.kind === "audio") return "Song";
    if (e.kind === "image") {
        if ((o && o.origin && o.origin.kind === "screenshot") || /screenshot/i.test(e.name)) return "Screenshot";
        if (x === "svg" || x === "gif") return "Picture";
        return m && m.exif && m.exif.taken ? "Photo" : (x === "png" ? "Picture" : "Photo");
    }
    return "File";
}

function pagesOf(n) { return n + (n === 1 ? " page" : " pages"); }
// only when there is more than one
function pageCounter(page, pages) { return pages > 1 ? (page + 1) + " of " + pages : ""; }

var LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
function dayMonth(d, now) { return d.getDate() + " " + LONG[d.getMonth()] + (d.getFullYear() !== new Date(now).getFullYear() ? " " + d.getFullYear() : ""); }
function takenLong(d) { return DAYS[d.getDay()] + " " + d.getDate() + " " + LONG[d.getMonth()] + " " + d.getFullYear() + " at " + hm(d); }

// "In Downloads"; the home folder itself is "In your home folder", any other folder by its own name
var HOMEDIRS = ["Downloads", "Pictures", "Documents", "Desktop", "Music", "Videos"];
function folderName(path, home) {
    var dir = path.replace(/\/[^\/]*$/, "") || "/";
    if (home && dir === home) return "In your home folder";
    var last = dir.split("/").pop() || "/";
    return "In " + last;
}

function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }

// the sentences services/Origins.qml describe() builds, with the date: "Saved from Opsis on 14 September"
function originSentence(o, appName, now) {
    if (!o) return "";
    var on = o.at ? " on " + dayMonth(new Date(o.at), now) : "";
    var app = o.app ? cap(appName(o.app)) : "";
    switch (o.kind) {
    case "screenshot": return (app ? "Screenshot of " + app : "Screenshot") + on;
    case "phone": return "From " + (o.device || "your phone") + on;
    case "agent": return "Written by " + (o.app === "codex" ? "Codex" : "Claude") + on;
    case "clipboard": return app ? "Copied in " + app + on : "";
    default: return (app ? "Saved from " + app : "Downloaded") + on;
    }
}

function camera(ex) {
    var make = ex.make && ex.make === ex.make.toUpperCase() && ex.make.length > 4 ? cap(ex.make.toLowerCase()) : ex.make;
    var model = ex.model || "";
    if (make && model && model.toLowerCase().indexOf(make.toLowerCase()) !== 0) return make + " " + model;
    return model || make || "";
}

function clip(parts, sep) { return parts.filter(function (p) { return p && p.length; }).join(sep || ", "); }

// What the Info panel says: { sections: [[label, value, sub], ..] as the approved mock lays them out, in
// plain words; lines: the same as short sentences, for the Roll; more: [[label, value], ..] behind More }.
// m = probe result, o = { home, origin, appName, dims, pages, paper }.
function facts(e, m, o) {
    var now = Date.now(), lines = [], more = [], sec = [];
    var size = e.size >= 0 ? bytes(e.size) : "";
    var from = originSentence(o.origin, o.appName, now);
    var at = new Date(e.at);
    if (e.kind === "image") {
        var ex = (m && m.exif) || {}, d = exifDate(ex.taken), cam = camera(ex), wh = o.dims;
        if (d) lines.push("Taken " + takenLong(d));
        if (cam) lines.push("on a " + cam);
        if (d) sec.push(["Taken", takenLong(d), ago(d, now)]);
        if (cam) sec.push(["Camera", cam, ""]);
        if (wh || size) sec.push(["Size", wh ? wh[0] + " × " + wh[1] : size, wh ? size : ""]);
        if (from) lines.push(from);
        lines.push(folderName(e.path, o.home));
        var s = clip([wh ? wh[0] + " × " + wh[1] : "", size]);
        if (s) lines.push(s);
        if (ex.lens) more.push(["Lens", ex.lens]);
        var shot = clip([ex.focal, ex.fnumber ? ex.fnumber.replace("F", "f/") : "", (ex.exposure || "").replace(" s", "") ? (ex.exposure || "").replace(" s", "") + " s" : "", ex.iso ? "ISO " + ex.iso : ""]);
        if (shot) more.push(["Settings", shot]);
        if (wh) more.push(["Pixels", (wh[0] * wh[1] / 1e6).toFixed(1) + " megapixels"]);
        more.push(["Format", format(e.path)]);
    } else if (e.kind === "video") {
        lines.push(clock(((m && m.duration) || 0) * 1000) + " long");
        sec.push(["Length", clock(((m && m.duration) || 0) * 1000), ""]);
        if ((m && m.w) || size) sec.push(["Size", m && m.w ? m.w + " × " + m.h : size, m && m.w ? size : ""]);
        if (from) lines.push(from);
        lines.push(folderName(e.path, o.home));
        var v = clip([m && m.w ? m.w + " × " + m.h : "", size]);
        if (v) lines.push(v);
        if (m && m.fps) more.push(["Frame rate", m.fps + " fps"]);
        more.push(["Codec", clip([codec(m && m.codec), codec(m && m.acodec)], ", ")]);
    } else if (e.kind === "audio") {
        var t = (m && m.tags) || {}, tr = /^(\d+)(?:\/(\d+))?/.exec(t.track || "");
        if (tr) lines.push("Track " + (tr[2] ? tr[1] + " of " + tr[2] : tr[1]));
        lines.push(clock(((m && m.duration) || 0) * 1000) + " long");
        sec.push(["Length", clock(((m && m.duration) || 0) * 1000), tr ? "Track " + (tr[2] ? tr[1] + " of " + tr[2] : tr[1]) : ""]);
        if (size) sec.push(["Size", size, ""]);
        if (from) lines.push(from);
        lines.push(folderName(e.path, o.home));
        if (size) lines.push(size);
        more.push(["Format", clip([codec(m && m.codec), rate(m && m.rate), channels(m && m.channels)], ", ")]);
    } else if (e.kind === "pdf") {
        lines.push(clip([o.pages ? pagesOf(o.pages) : "", o.paper]));
        sec.push(["Pages", clip([o.pages ? pagesOf(o.pages) : "", o.paper]) || "PDF", size]);
        if (from) lines.push(from);
        lines.push(folderName(e.path, o.home));
        if (size) lines.push(size);
    } else {
        if (from) lines.push(from);
        lines.push(folderName(e.path, o.home));
        if (size) lines.push(size);
        if (size) sec.push(["Size", size, ""]);
    }
    if (from) sec.push(["Came from", from, ""]);
    sec.push(["Where", folderName(e.path, o.home).replace(/^In /, "").replace(/^your home folder$/, "Your home folder"), ""]);
    lines = lines.filter(function (l) { return l && l.length; });
    if (o.origin && o.origin.title) more.push(["From the page", o.origin.title]);
    var dir = e.path.replace(/\/[^\/]*$/, "");
    if (o.home && dir.indexOf(o.home) === 0) dir = "~" + dir.slice(o.home.length);
    more.push(["File name", e.name]);
    more.push(["Folder", dir]);
    more.push(["Modified", dateLong(at)]);
    return { lines: lines, sections: sec.filter(function (r) { return r[1] && r[1].length; }), more: more.filter(function (r) { return r[1] && r[1].length; }) };
}

// the one line of facts beside the name in the Roll
function line(e, m, o) {
    if (e.kind === "image") {
        var ex = (m && m.exif) || {}, d = exifDate(ex.taken), wh = o.dims;
        // a title that already says when it was taken ("Photo, 14 September 2024 at 14:32") does not get the date twice
        return clip([d && !stamped(stem(e.name), e.kind) ? dateShort(d) : "", wh ? wh[0] + " × " + wh[1] : ""]);
    }
    if (e.kind === "video") return clip([clock(((m && m.duration) || 0) * 1000), m && m.w ? m.w + " × " + m.h : ""]);
    if (e.kind === "audio") return clip([clock(((m && m.duration) || 0) * 1000), bytes(e.size)]);
    if (e.kind === "pdf") return clip([o.pages > 1 ? pagesOf(o.pages) : "", bytes(e.size)]);
    return bytes(e.size);
}
