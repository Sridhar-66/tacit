// Engine.js against a plain-object document: `node modules/code/engine.test.js`.
// No dependencies, no harness. It prints one line per group and exits non-zero on
// the first failure.
//
// The cases below are the ones that caught the blank-line bug: an added empty line
// has no text to type, so the line it needs was never opened and every hunk after
// it landed one row too low.

const E = require("./Engine.js");

let failed = 0;

function mkDoc(text) {
    let t = text;
    return {
        text: () => t,
        insert: (pos, s) => { t = t.substring(0, pos) + s + t.substring(pos); },
        remove: (a, b) => { t = t.substring(0, a) + t.substring(b); },
    };
}

// Step to completion, or give up: a session that cannot finish is a failure of its own.
function finish(s, doc) {
    for (let i = 0; i < 200000 && !s.complete(); i++) s.step();
    if (!s.complete()) throw new Error("session never completed");
    return doc.text();
}

function check(name, before, after) {
    const doc = mkDoc(E.norm(before));
    const s = E.Session(doc, before, after);
    let got;
    try {
        got = finish(s, doc);
    } catch (e) {
        got = `<${e.message}>`;
    }
    if (got !== E.norm(after)) {
        failed++;
        console.log(`FAIL ${name}\n  want ${JSON.stringify(E.norm(after))}\n  got  ${JSON.stringify(got)}`);
    }
}

// ── the ten hand cases ──────────────────────────────────────────────────────
const cases = [
    ["blank line inserted mid-file", "a\nb\nc\n", "a\n\nb\nc\n"],
    ["blank line appended", "a\nb\n", "a\nb\n\n"],
    ["blank line prepended", "a\nb\n", "\na\nb\n"],
    ["two blank lines inserted", "a\nb\n", "a\n\n\nb\n"],
    ["blank line plus a later edit", "a\nb\nc\n", "a\n\nb\nC\n"],
    ["python blank separator and a body change",
        "def a():\n    pass\ndef b():\n    pass\n",
        "def a():\n    pass\n\ndef b():\n    return 2\n"],
    ["line replaced by a blank line", "a\nb\nc\n", "a\n\nc\n"],
    ["blank line removed", "a\n\nb\n", "a\nb\n"],
    ["blank lines both sides of a new line", "a\nb\n", "a\n\nnew\n\nb\n"],
    ["only a blank line", "", "\n"],
];
for (const [name, before, after] of cases) check(name, before, after);
console.log(`hand cases: ${cases.length - failed} of ${cases.length} ok`);

// ── fuzz: random documents full of blank lines ──────────────────────────────
// A seeded generator, so a failure can be reproduced from the seed printed below.
function rng(seed) {
    let x = seed >>> 0;
    return () => {
        x ^= x << 13; x >>>= 0;
        x ^= x >> 17;
        x ^= x << 5; x >>>= 0;
        return x / 4294967296;
    };
}

function randomDoc(r) {
    const n = 1 + Math.floor(r() * 9);
    const out = [];
    for (let i = 0; i < n; i++) {
        const k = r();
        if (k < 0.35) out.push("");                                   // blank lines are the point
        else if (k < 0.6) out.push("    " + "abcdef".charAt(Math.floor(r() * 6)));
        else out.push("line " + Math.floor(r() * 5));
    }
    return out.join("\n") + "\n";
}

function edit(before, r) {
    const lines = before.split("\n");
    lines.pop();
    const ops = 1 + Math.floor(r() * 3);
    for (let i = 0; i < ops; i++) {
        const at = Math.floor(r() * (lines.length + 1)), k = r();
        if (k < 0.4) lines.splice(at, 0, r() < 0.6 ? "" : "added " + Math.floor(r() * 5));
        else if (k < 0.7 && lines.length) lines.splice(at % lines.length, 1);
        else if (lines.length) lines[at % lines.length] = r() < 0.4 ? "" : "changed " + Math.floor(r() * 5);
    }
    return lines.length ? lines.join("\n") + "\n" : "";
}

function fuzz(rounds) {
    const bad = { plain: 0, undone: 0, fed: 0 };
    for (let i = 0; i < rounds; i++) {
        const r = rng(i + 1);
        const before = randomDoc(r), after = edit(before, r), third = edit(after, r);

        let doc = mkDoc(E.norm(before));
        let s = E.Session(doc, before, after);
        if (finish(s, doc) !== E.norm(after) && bad.plain++ === 0) console.log(`FAIL fuzz seed ${i + 1}: typed out wrong`);

        // half typed, some of it taken back, then finished: still the target
        doc = mkDoc(E.norm(before));
        s = E.Session(doc, before, after);
        const half = Math.max(1, Math.floor(r() * 12));
        for (let j = 0; j < half && !s.complete(); j++) s.step();
        for (let j = 0; j < 3; j++) s.untype();
        if (finish(s, doc) !== E.norm(after) && bad.undone++ === 0) console.log(`FAIL fuzz seed ${i + 1}: wrong after untype`);

        // a newer version fed while it runs is typed after the current one
        doc = mkDoc(E.norm(before));
        s = E.Session(doc, before, after);
        for (let j = 0; j < half && !s.complete(); j++) s.step();
        s.feed(third);
        if (finish(s, doc) !== E.norm(third) && bad.fed++ === 0) console.log(`FAIL fuzz seed ${i + 1}: wrong after feed`);
    }
    failed += bad.plain + bad.undone + bad.fed;
    console.log(`fuzz ${rounds} rounds: ${bad.plain} wrong, ${bad.undone} wrong after untype, ${bad.fed} wrong after feed`);
}
fuzz(8000);

console.log(failed === 0 ? "engine: ok" : `engine: ${failed} failures`);
process.exit(failed === 0 ? 0 : 1);
