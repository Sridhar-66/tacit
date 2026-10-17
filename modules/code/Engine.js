// A document walks from one version of a file to another as if typed by hand.
//
// Each step types the next character of the change (a line's indentation lands
// with its first character, as an editor indents); `untype` takes the last one
// back. Deleted lines go in one stroke, as if selected and removed. More versions
// can be fed while it runs (the file still changing on disk); each is typed after
// the one before.
//
// It works on a small document interface so the editor and the tests share it:
//   doc.text() -> string    doc.insert(pos, s)    doc.remove(start, end)
// Positions are string offsets. Loaded by the editor as a QML JavaScript file and
// by the tests through module.exports.

function norm(s) {
    s = s || "";
    return s !== "" && s.charAt(s.length - 1) !== "\n" ? s + "\n" : s;
}

function linesOf(s) {
    s = norm(s);
    if (s === "") return [];
    return s.substring(0, s.length - 1).split("\n");
}

// Line diff: hunks { row, del, add, text } top to bottom, row = where the change
// starts in the old text (0-based). Common ends are trimmed first; the middle is an
// LCS, and a middle too large for that becomes one replacement.
function hunks(before, after) {
    const a = linesOf(before), b = linesOf(after);
    let pre = 0;
    while (pre < a.length && pre < b.length && a[pre] === b[pre]) pre++;
    let suf = 0;
    while (suf < a.length - pre && suf < b.length - pre && a[a.length - 1 - suf] === b[b.length - 1 - suf]) suf++;
    const A = a.slice(pre, a.length - suf), B = b.slice(pre, b.length - suf);
    const n = A.length, m = B.length;
    const out = [];
    const push = (i, di, j, dj) => {
        if (di > 0 || dj > 0) out.push({ row: pre + i, del: di, add: dj, text: B.slice(j, j + dj).join("\n") });
    };
    // The LCS table is (n+1)*(m+1) Int32 cells; past this a whole-file replacement costs less
    // than the allocation, which this machine cannot afford.
    if (n * m > 250000) { push(0, n, 0, m); return out; }
    // lcs[i][j] = LCS length of A[i..] and B[j..]
    const w = m + 1, L = new Int32Array((n + 1) * w);
    for (let i = n - 1; i >= 0; i--)
        for (let j = m - 1; j >= 0; j--)
            L[i * w + j] = A[i] === B[j] ? L[(i + 1) * w + j + 1] + 1 : Math.max(L[(i + 1) * w + j], L[i * w + j + 1]);
    let i = 0, j = 0, hi = -1, hj = -1;
    while (i < n || j < m) {
        if (i < n && j < m && A[i] === B[j]) {
            if (hi >= 0) { push(hi, i - hi, hj, j - hj); hi = -1; }
            i++; j++;
        } else {
            if (hi < 0) { hi = i; hj = j; }
            if (j < m && (i >= n || L[i * w + j + 1] >= L[(i + 1) * w + j])) j++; else i++;
        }
    }
    if (hi >= 0) push(hi, i - hi, hj, j - hj);
    return out;
}

function lineStart(text, row) {
    let p = 0;
    for (let r = 0; r < row; r++) {
        const nl = text.indexOf("\n", p);
        if (nl < 0) return text.length;
        p = nl + 1;
    }
    return p;
}

// A person's rhythm for the watching driver: ~cps characters a second, uneven,
// slower after a line end or bracket, now and then a longer pause (milliseconds).
function pause(cps, prev, rnd) {
    rnd = rnd || Math.random;
    let d = (1000 / cps) * (0.55 + rnd() * 0.9);
    if (prev === "\n") d += 250 + rnd() * 550;
    else if (prev && ".,;:{}()[]".indexOf(prev) >= 0) d += 40 + rnd() * 180;
    if (rnd() < 0.025) d += 400 + rnd() * 1000;
    return Math.floor(d);
}

function Session(doc, before, after) {
    const s = {
        target: norm(after), queue: [], hunks: hunks(before, after), h: 0, offset: 0, pos: 0, done: false,
    };
    for (const k of s.hunks) { k.pos = 0; k.started = false; k.typed = []; }

    function begin(k) {
        k.started = true;
        const row = k.row + s.offset, text = doc.text();
        const p = lineStart(text, row);
        if (k.del > 0) doc.remove(p, lineStart(text, row + k.del));
        if (k.add > 0) doc.insert(p, "\n"); // a fresh line to type into, blank lines included
        s.pos = p;
        s.offset += k.add - k.del;
    }

    function nextVersion() {
        if (s.queue.length === 0) return false;
        const nxt = s.queue.shift();
        s.hunks = hunks(s.target, nxt);
        for (const k of s.hunks) { k.pos = 0; k.started = false; k.typed = []; }
        s.h = 0; s.offset = 0; s.target = nxt;
        return true;
    }

    // Type the next character. Returns it, or null when there is nothing left.
    s.step = function () {
        let k = s.hunks[s.h];
        while (!k) {
            if (!nextVersion()) { s.done = true; return null; }
            k = s.hunks[s.h];
        }
        s.done = false;
        if (!k.started) begin(k);
        const t = k.text;
        let last = null;
        if (k.pos < t.length) {
            let e = k.pos + 1;
            if (k.pos === 0 || t.charAt(k.pos - 1) === "\n") { // indentation with the first character
                const ind = /^[ \t]*/.exec(t.substring(k.pos))[0].length;
                e = Math.min(t.length, k.pos + ind + 1);
            }
            const c = t.charCodeAt(e - 1);
            if (c >= 0xD800 && c <= 0xDBFF && e < t.length) e++; // never split a surrogate pair
            const chunk = t.substring(k.pos, e);
            doc.insert(s.pos, chunk);
            k.typed.push({ pos: s.pos, len: chunk.length, from: k.pos });
            s.pos += chunk.length; k.pos = e; last = t.charAt(e - 1);
        }
        if (k.pos >= t.length) { s.h++; if (last === null) last = "\n"; }
        return last;
    };

    // Take back the last character typed.
    s.untype = function () {
        let k = s.hunks[s.h];
        if (!k || !k.started) {
            // nothing begun here yet: step back into the edit just finished
            k = s.hunks[s.h - 1];
            if (!k || k.typed.length === 0) return false;
            s.h--;
        } else if (k.typed.length === 0) {
            // an edit that has begun keeps its place: Backspace stops at its start,
            // or the positions it opened would no longer line up
            return false;
        }
        const t = k.typed.pop();
        doc.remove(t.pos, t.pos + t.len);
        s.pos = t.pos; k.pos = t.from; s.done = false;
        return true;
    };

    // A newer version of the file, typed after the current one.
    s.feed = function (content) {
        content = norm(content);
        if (content === (s.queue.length ? s.queue[s.queue.length - 1] : s.target)) return;
        s.queue.push(content);
        s.done = false;
    };

    // True once every character of every version so far is in.
    s.complete = function () {
        return s.queue.length === 0 && s.h >= s.hunks.length;
    };

    return s;
}

if (typeof module !== "undefined") module.exports = { norm, hunks, lineStart, pause, Session };
