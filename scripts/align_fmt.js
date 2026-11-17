#!/usr/bin/env node
// Run `forge fmt`, then align runs of single-line statements into columns.
//
// Pipeline per file:
//   1. format - run `forge fmt` over the project, untouched
//   2. align  - pad runs of single-line statements so their columns line up:
//               `assertEq` / `require` on their arguments, assignments on their
//               `=` (and `+=`, `-=`, ...) operator
//
// `assertEq` and assignments are aligned everywhere; `require` is aligned only
// outside the project's `test` directory, so revert strings line up in contracts
// while tests keep the shape forge gives them.
//
// Nothing is ever written into the source to hold formatting back: `forge fmt` runs
// on the pristine file and every other construct - including custom assertion helpers
// such as `assertPoolState({ ... })` - is left exactly as forge formats it. The
// alignment pass then recomputes `assertEq` columns from scratch, so the result does
// not depend on how the author happened to space the block.
//
// Because step 2 adds padding that `forge fmt` would remove, the result is NOT a
// `forge fmt` fixed point: `forge fmt --check` will fail on any file containing an
// aligned block. This tool is the project formatter; CI must run
// `align_fmt.js --check`, not `forge fmt --check`.
//
// Usage:
//     align_fmt.js [paths...]            format in place (default: contracts tests)
//     align_fmt.js --check [paths...]    exit 1 if formatting would change anything
//     align_fmt.js --root DIR            foundry project root (default: cwd)
//
// Requires node and a `forge` on PATH; no npm dependencies.
"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

// Call statements that are aligned on their arguments. Custom helpers
// (assertPoolState, assertStrategyManager*) are ordinary function calls and are
// left to `forge fmt`.
//
// A run only ever groups one kind, so an `assertEq` sitting directly above a
// `require` starts a new run rather than sharing its columns. `assign` is the
// third kind and is matched structurally rather than by a regex.
const CALL_RES = {
    assertEq: /^assertEq\s*\(/,
    require: /^require\s*\(/,
};

// Assignment operators, longest first so `>>=` is preferred over `>=`.
const ASSIGN_OPS = ["<<=", ">>=", "+=", "-=", "*=", "/=", "%=", "|=", "&=", "^=", "="];

// Left-hand sides that are control flow rather than a declaration. `single_line_
// statement_blocks = "preserve"` lets `if (cond) x = 1;` survive as one line, and
// its assignment is genuinely top-level - but `if (cond)` is not a type, so such a
// statement is left alone instead of being carved into columns.
const NOT_A_TYPE = /^(if|else|for|while|do|try|catch|unchecked|return)\b/;

// Return `line` with any trailing `//` line comment removed.
//
// Quote-aware: `//` inside a string literal is content, not a comment, so
// `assertEq(uri, "https://x")` keeps its full argument list.
function stripComment(line) {
    let quote = null;
    let i = 0;
    while (i < line.length) {
        const c = line[i];
        if (quote) {
            if (c === "\\") {
                i += 2;
                continue;
            }
            if (c === quote) quote = null;
        } else if (c === '"' || c === "'") {
            quote = c;
        } else if (line.startsWith("//", i)) {
            return line.slice(0, i);
        }
        i += 1;
    }
    return line;
}

// Split a single-line `kind` call into segments at its top-level commas.
//
// Returns a list where every segment but the last ends with its comma, or null
// when the line is not a complete single-line call of that kind with at least one
// top-level comma. Commas nested inside calls, brackets or braces are skipped, as
// are commas inside string literals - so `assertEq(keccak256("a,b"), x)` splits at
// the second comma, not the one in the string, and `require(transfer(a, b), "E")`
// splits only before the revert string.
function splitArgs(line, kind) {
    const code = stripComment(line);
    if (!CALL_RES[kind].test(code.trim()) || !code.trimEnd().endsWith(");")) {
        return null;
    }

    const openParen = line.indexOf("(");
    const segments = [];
    let start = 0;
    let depth = 0;
    let quote = null;
    let i = openParen;
    while (i < line.length) {
        const c = line[i];
        if (quote) {
            if (c === "\\") {
                i += 2;
                continue;
            }
            if (c === quote) quote = null;
        } else if (c === '"' || c === "'") {
            quote = c;
        } else if ("([{".includes(c)) {
            depth += 1;
        } else if (")]}".includes(c)) {
            depth -= 1;
            if (depth === 0) break; // call closed; any later comma is not an argument separator
        } else if (c === "," && depth === 1) {
            segments.push(line.slice(start, i + 1));
            start = i + 1;
        }
        i += 1;
    }
    if (segments.length === 0) return null;
    segments.push(line.slice(start));
    // Existing padding lives at the head of each segment; drop it so that a column
    // is rebuilt from its content alone and the pass is idempotent. The first
    // segment keeps its leading whitespace because that is the statement's indent.
    return [segments[0], ...segments.slice(1).map((s) => s.trimStart())];
}

// Locate the statement's assignment operator, or null if it has none.
//
// Only a top-level operator counts, so the `=` inside `f(a = b)` or a `mapping(a =>
// b)` type is never the anchor, and the scan stops at the first one - in
// `uint256 x = recordedAssets += y;` that is the `=`, not the `+=`. Comparisons
// (`==`, `!=`, `<=`, `>=`), the arrow `=>` and Yul's `:=` are rejected outright.
function findAssignment(code) {
    let depth = 0;
    let quote = null;
    for (let i = 0; i < code.length; i++) {
        const c = code[i];
        if (quote) {
            if (c === "\\") i += 1;
            else if (c === quote) quote = null;
            continue;
        }
        if (c === '"' || c === "'") quote = c;
        else if ("([{".includes(c)) depth += 1;
        else if (")]}".includes(c)) depth -= 1;
        else if (c === "=" && depth === 0) {
            if (code[i + 1] === "=" || code[i + 1] === ">") continue; // ==, =>
            const prev = code[i - 1];
            if (prev === "=" || prev === "!" || prev === ":") continue; // ==, !=, :=
            if (prev === "<" || prev === ">") {
                // `<=` / `>=` compare; `<<=` / `>>=` assign.
                if (code[i - 2] === prev) return { start: i - 2, end: i + 1 };
                continue;
            }
            const op = ASSIGN_OPS.find((o) => code.startsWith(o, i - o.length + 1));
            return { start: i - op.length + 1, end: i + 1 };
        }
    }
    return null;
}

// Split a single-line assignment into `{ indent, type, name, op, rhs }`.
//
// `type` is everything on the left-hand side before its final token, so a
// declaration splits as `uint256 internal constant` + `HUNDRED_PERCENT` and a plain
// assignment such as `deployedAssetsOf[msg.sender] += x` has an empty `type`. A
// tuple destructure keeps its whole left-hand side as `name`, since it has no type
// column to speak of. Every field is trimmed, so a line that is already padded
// parses to the same parts as an unpadded one and the pass is idempotent.
//
// Returns null when the left-hand side is not a target this can safely split - see
// NOT_A_TYPE - which also ends the run.
function splitAssign(line) {
    const code = stripComment(line);
    if (!code.trimEnd().endsWith(";")) return null;

    const at = findAssignment(code);
    if (at === null) return null;

    const lhs = code.slice(0, at.start).trim();
    if (lhs === "") return null;

    // A tuple destructure is taken whole; anything else carrying a paren or brace is
    // not a plain declaration and is left alone.
    const tuple = lhs.startsWith("(");
    if (!tuple && (NOT_A_TYPE.test(lhs) || /[(){}]/.test(lhs))) return null;

    const tokens = tuple ? [lhs] : lhs.split(/\s+/);
    return {
        indent: line.slice(0, line.length - line.trimStart().length),
        type: tokens.slice(0, -1).join(" "),
        name: tokens[tokens.length - 1],
        op: code.slice(at.start, at.end),
        rhs: line.slice(at.end).trim(), // from `line`, so a trailing comment survives
    };
}

// Parse `line` as the first of `kinds` that matches, or null if none do.
function classify(line, kinds) {
    for (const kind of kinds) {
        const value = kind === "assign" ? splitAssign(line) : splitArgs(line, kind);
        if (value !== null) return { kind, value };
    }
    return null;
}

// Build a call run's columns left to right, with at least one space after each
// comma. A column's width is set only by the lines that actually reach it, so a
// 2-argument call sitting in a run of 3-argument ones does not stretch the third
// column.
function renderCall(rows) {
    const built = new Map([...rows].map(([i, r]) => [i, r[0]]));
    const cols = Math.max(...[...rows.values()].map((r) => r.length));
    for (let col = 1; col < cols; col++) {
        const reaching = [...rows.keys()].filter((i) => rows.get(i).length > col);
        const width = Math.max(...reaching.map((i) => built.get(i).length)) + 1;
        for (const i of reaching) {
            built.set(i, built.get(i).padEnd(width) + rows.get(i)[col]);
        }
    }
    return built;
}

// Build an assignment run's two columns: names start at a common column, then the
// operators do.
//
// The type column is sized by the declarations alone, so a bare assignment sharing
// a run with them keeps its left-hand side at the indent instead of being pushed
// out under their names. Operators are right-aligned - padded so they all *end* at
// one column - so a lone `=` among `+=` lands under the other `=` signs rather than
// under their `+`.
function renderAssign(rows) {
    const typed = [...rows.values()].filter((p) => p.type !== "");
    const typeWidth = typed.length === 0 ? 0 : Math.max(...typed.map((p) => p.type.length)) + 1;

    const lhs = new Map(
        [...rows].map(([i, p]) => [i, p.indent + p.type.padEnd(p.type === "" ? 0 : typeWidth) + p.name]),
    );
    const opEnd = Math.max(...[...rows].map(([i, p]) => lhs.get(i).length + 1 + p.op.length));

    return new Map(
        [...rows].map(([i, p]) => [i, `${lhs.get(i).padEnd(opEnd - p.op.length)}${p.op} ${p.rhs}`]),
    );
}

// The run written with single spaces - the same output `forge fmt` produces.
function renderPlain(kind, rows) {
    if (kind === "assign") {
        return new Map(
            [...rows].map(([i, p]) => [
                i,
                p.indent + [p.type, p.name, p.op, p.rhs].filter((s) => s !== "").join(" "),
            ]),
        );
    }
    return new Map([...rows].map(([i, r]) => [i, r.map((s) => s.trimEnd()).join(" ")]));
}

// A call whose sole argument is a named-argument block, written on one line:
// `head({ a: 1, b: 2 });`. The head is lazy, so the first `({` wins, and the line
// must end at `});` - which keeps nested uses such as `assertEq(f({ a: 1 }), 2);`
// out of scope, since those end at `);`.
const INLINE_NAMED_CALL = /^([ \t]*)(.*?[\w\])]\(\s*)\{\s*(.*?)\s*\}\s*\)\s*;$/;

// The opening line of a block `forge fmt` already broke, and one `key: value` entry
// inside it.
const OPEN_NAMED_CALL = /^([ \t]*)(.*?[\w\])]\(\s*)\{$/;
const NAMED_ARG = /^\s*([A-Za-z_]\w*)\s*:\s*(\S.*?)(,?)$/;
const CLOSE_NAMED_CALL = /^[ \t]*\}\s*\)\s*;$/;

// Split `s` at its top-level commas, or null if it has none.
//
// Depth- and quote-aware, so a nested `g({ a: 1, b: 2 })` or a string containing a
// comma stays inside one entry.
function splitTopLevelCommas(s) {
    const parts = [];
    let depth = 0;
    let quote = null;
    let start = 0;
    for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if (quote) {
            if (c === "\\") i += 1;
            else if (c === quote) quote = null;
            continue;
        }
        if (c === '"' || c === "'") quote = c;
        else if ("([{".includes(c)) depth += 1;
        else if (")]}".includes(c)) depth -= 1;
        else if (c === "," && depth === 0) {
            parts.push(s.slice(start, i));
            start = i + 1;
        }
    }
    parts.push(s.slice(start));
    const trimmed = parts.map((x) => x.trim()).filter((x) => x !== "");
    return trimmed.length === 0 ? null : trimmed;
}

// Render a named-argument block one entry per line, values in a column.
//
// Returns null if any entry is not a plain `key: value`, or if a line would end up
// past `lineLength` - in both cases the block is left as `forge fmt` wrote it.
function renderNamedArgs(indent, head, args, indentUnit, lineLength, suffix = "") {
    const parsed = args.map((a) => a.match(NAMED_ARG));
    if (parsed.some((m) => m === null)) return null;

    const width = Math.max(...parsed.map((m) => m[1].length)) + 2; // `key:` plus a space
    const inner = indent + indentUnit;
    const lines = [
        `${indent}${head}{`,
        ...parsed.map((m, i) => `${inner}${(m[1] + ":").padEnd(width)}${m[2]}${i < parsed.length - 1 ? "," : ""}`),
        `${indent}});${suffix}`,
    ];
    return lines.some((l) => l.length > lineLength) ? null : lines;
}

// Give every named argument its own line, with the values aligned.
//
// `forge fmt` collapses `f({ a: 1, b: 2 })` onto one line whenever it fits, which
// buries the field names this codebase reads by; this puts them back, and lines up
// blocks forge had already broken. A block carrying a comment is left untouched -
// reflowing it would move the comment away from the entry it describes.
function expandNamedArgs(text, indentUnit, lineLength) {
    const lines = text.split("\n");
    const out = [];
    let inBlockComment = false;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // `stripComment` is single-line, so track `/* */` spans here: a call sitting
        // inside one is commented out just as surely as a `//` one.
        const opens = (line.match(/\/\*/g) || []).length;
        const closes = (line.match(/\*\//g) || []).length;
        if (inBlockComment || opens > closes) {
            const wasInside = inBlockComment;
            if (opens > closes) inBlockComment = true;
            if (closes > opens) inBlockComment = false;
            if (wasInside || opens > 0) {
                out.push(line);
                continue;
            }
        }

        // Match on the comment-stripped line: a commented-out call must never be
        // expanded, or the `//` would be left behind on the opening line only and the
        // rest would become live code.
        const code = stripComment(line);
        const trailing = line.slice(code.length);

        const inline = code.match(INLINE_NAMED_CALL);
        if (inline !== null) {
            const args = splitTopLevelCommas(inline[3]);
            const built = args && renderNamedArgs(inline[1], inline[2], args, indentUnit, lineLength, trailing);
            if (built !== null) {
                out.push(...built);
                continue;
            }
        }

        // A block forge already broke: realign its values in place.
        const open = trailing === "" ? code.match(OPEN_NAMED_CALL) : null;
        if (open !== null) {
            let end = i + 1;
            while (end < lines.length && !CLOSE_NAMED_CALL.test(lines[end])) end += 1;
            const body = lines.slice(i + 1, end);
            if (end < lines.length && body.length > 0 && !body.some((l) => /\/\/|\/\*/.test(l))) {
                const args = body.map((l) => l.trim().replace(/,$/, ""));
                const built = renderNamedArgs(open[1], open[2], args, indentUnit, lineLength);
                if (built !== null) {
                    out.push(...built);
                    i = end;
                    continue;
                }
            }
        }

        out.push(line);
    }

    return out.join("\n");
}

// Pad runs of single-line statements so their columns line up.
//
// A run is a group of same-kind statements on consecutive lines; anything else - a
// blank line, a comment, a multi-line statement, a different statement kind - ends
// it.
//
// If the result would push any line past `lineLength`, the run falls back to
// single spacing rather than emitting over-length lines.
function align(text, lineLength, kinds) {
    const lines = text.split("\n");

    const runs = []; // each run: { kind, rows: Map<lineIndex, parsed> }, indices ascending
    lines.forEach((line, i) => {
        const parsed = classify(line, kinds);
        if (parsed === null) return;
        const last = runs[runs.length - 1];
        if (last && last.kind === parsed.kind && Math.max(...last.rows.keys()) === i - 1) {
            last.rows.set(i, parsed.value);
        } else {
            runs.push({ kind: parsed.kind, rows: new Map([[i, parsed.value]]) });
        }
    });

    for (const { kind, rows } of runs) {
        let built = kind === "assign" ? renderAssign(rows) : renderCall(rows);

        if ([...built.values()].some((v) => v.length > lineLength)) {
            built = renderPlain(kind, rows);
        }

        for (const [i, value] of built) lines[i] = value;
    }

    return lines.join("\n");
}

function runForge(cmd, root) {
    const proc = spawnSync("forge", cmd, { cwd: root, encoding: "utf8" });
    if (proc.error) {
        if (proc.error.code === "ENOENT") {
            process.stderr.write("error: `forge` not found on PATH\n");
            process.exit(1);
        }
        throw proc.error;
    }
    return proc;
}

// Read the resolved project config: `fmt.line_length` as `forge fmt` itself uses
// it, and `test` so require-alignment can skip the test tree.
//
// `forge config` always reports a value - the project's `[profile.*]` setting when
// one is present, otherwise forge's own default - so the width used here is always
// the width forge formatted to. There is deliberately no fallback: guessing a
// different width than forge used would align blocks against the wrong limit.
function forgeConfig(root) {
    const proc = runForge(["config", "--json"], root);
    if (proc.status !== 0) {
        throw new Error(`forge config failed:\n${proc.stderr}`);
    }
    return JSON.parse(proc.stdout);
}

// `require` is aligned only outside the test tree: revert strings are part of a
// contract's surface and read better in a column, while test files keep the shape
// forge gives their requires. `assertEq` and assignments are aligned everywhere.
//
// Order matters - `assign` is tried last, so a `require(...)` line is never
// mistaken for an assignment on account of an `=` in its arguments.
function alignedKinds(file, testDir) {
    const inTests = file === testDir || file.startsWith(testDir + path.sep);
    return inTests ? ["assertEq", "assign"] : ["assertEq", "require", "assign"];
}

// Decode UTF-8 and normalise \r\n / \r to \n, so a CRLF file aligns on the same
// line boundaries as an LF one and is written back with consistent endings.
function readText(f) {
    return fs.readFileSync(f, "utf8").replace(/\r\n|\r/g, "\n");
}

function solFiles(root, paths) {
    const files = [];
    for (const p of paths) {
        const target = path.resolve(root, p);
        let stat = null;
        try {
            stat = fs.statSync(target);
        } catch {
            /* fall through to the warning */
        }
        if (stat && stat.isDirectory()) {
            files.push(...walkSol(target));
        } else if (stat && stat.isFile()) {
            files.push(target);
        } else {
            process.stderr.write(`warning: path not found: ${p}\n`);
        }
    }
    return [...new Set(files)]; // overlapping args must not process a file twice
}

function walkSol(dir) {
    const found = [];
    const walk = (d) => {
        for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
            const p = path.join(d, entry.name);
            if (entry.isDirectory()) walk(p);
            else if (entry.isFile() && entry.name.endsWith(".sol")) found.push(p);
        }
    };
    walk(dir);
    return found.sort(); // stable order, so --check reports files the same way each run
}

function parseArgs(argv) {
    const args = { paths: [], check: false, root: "." };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === "--check") {
            args.check = true;
        } else if (a === "--root") {
            i += 1;
            if (i >= argv.length) {
                process.stderr.write("error: --root requires a value\n");
                process.exit(2);
            }
            args.root = argv[i];
        } else if (a.startsWith("--root=")) {
            args.root = a.slice("--root=".length);
        } else if (a.startsWith("-")) {
            process.stderr.write(`error: unrecognized argument: ${a}\n`);
            process.exit(2);
        } else {
            args.paths.push(a);
        }
    }
    if (args.paths.length === 0) args.paths = ["contracts", "tests"];
    return args;
}

function main() {
    const args = parseArgs(process.argv.slice(2));

    const root = path.resolve(args.root);
    const files = solFiles(root, args.paths);
    if (files.length === 0) {
        process.stderr.write("no .sol files found\n");
        return 1;
    }

    const config = forgeConfig(root);
    const lineLength = config.fmt.line_length;
    const indentUnit = config.fmt.style === "tab" ? "\t" : " ".repeat(config.fmt.tab_width);
    const testDir = path.resolve(root, config.test);
    const original = new Map(files.map((f) => [f, readText(f)]));

    let results = null;
    try {
        const proc = runForge(["fmt", ...files], root);
        if (proc.status !== 0) {
            process.stderr.write(proc.stderr);
            throw new Error("forge fmt failed");
        }

        results = new Map(
            files.map((f) => [
                f,
                align(
                    expandNamedArgs(readText(f), indentUnit, lineLength),
                    lineLength,
                    alignedKinds(f, testDir),
                ),
            ]),
        );
    } finally {
        // `forge fmt` wrote into the tree, so settle every file to its final
        // content: the aligned result, or the pristine original under --check or
        // when the pipeline died partway (hence finally, not catch). Compare
        // before writing so files that end up unchanged keep their mtime and
        // forge's build cache stays valid.
        const final = args.check || results === null ? original : results;
        for (const f of files) {
            if (readText(f) !== final.get(f)) fs.writeFileSync(f, final.get(f));
        }
    }

    const changed = files.filter((f) => results.get(f) !== original.get(f));

    for (const f of changed) {
        process.stdout.write(`${path.relative(root, f)}\n`);
    }

    if (args.check && changed.length > 0) {
        process.stderr.write(`\n${changed.length} file(s) would be reformatted\n`);
        return 1;
    }
    if (!args.check) {
        process.stdout.write(`\n${changed.length} file(s) reformatted\n`);
    }
    return 0;
}

process.exitCode = main();
