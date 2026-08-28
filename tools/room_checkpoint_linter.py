#!/usr/bin/env python3
"""Read-only linter/scaffolder: make room verdicts machine-checkable BEFORE
a checkpoint is committed.

The reconciler (tools/room_checkpoint_reconciler.py) can only verify what a
checkpoint states in checkable form.  This linter analyzes a checkpoint draft
row by row and reports, for every verdict-table row and likely object phrase:

  - what each token resolves to (one exact layout id, several ids, an id
    family, an assembly/marker kind, a runtime GDScript object, a
    room/architectural element, or nothing known);
  - whether the row is sufficiently checkable for its verdict;
  - the exact backticked id tokens to use where evidence is unambiguous;
  - precisely which additional fact the author must supply otherwise.

It never modifies the checkpoint, layout, generator or any production data,
never rewrites prose, and never selects among ambiguous candidates.  Parsing
and object inventory are reused from the reconciler and workbench so all
three tools share one interpretation of ids, rooms and ownership.

Diagnostics (stable, tested):
  EXACT             token resolves to exactly one layout record (or one
                    explicit stable set: a full `a..b` range or a glob)
  AMBIGUOUS         several candidate records; the author must choose
  PREFIX_ONLY       no exact record, but ids extending the token exist
  KIND_NOT_ID       token names an assembly/marker kind, not a record id
  RUNTIME_ONLY      token appears only in runtime sources (gd/data), never
                    in layout JSON
  ARCHITECTURAL     room-envelope vocabulary (walls/floor/ceiling/trim...)
                    with no per-object id
  MANUAL_TARGET     the row explicitly declares manual/visual verification
                    via a documented `[manual]` or `[visual]` tag
  UNKNOWN           no known repository entity matches
  MISSING_TARGET    the verdict needs a target fact that is absent
  MISSING_TOLERANCE advisory: a positional target without explicit tolerance
                    (the reconciler's defaults, 0.05 m / 1.0 deg, will apply)
  CONFLICTING_TOKEN token matches more than one entity class, or an ADD /
                    REPLACE proposes an id that already exists
  NO_VERDICT_TABLE  document-level: a checkpoint with no verdict table
  READY             row is machine-checkable as written, or explicitly manual

Exit codes (aligned with the reconciler):
  0   every parsed decision is machine-checkable or explicitly manual
  1   unresolved/ambiguous decisions remain
  3   refused to overwrite existing scaffold output (pass --force)
  4   malformed checkpoint structure (broken rows, unrecognized verdicts)
  5   both 1 and 4
  2   command-line usage error (argparse default)
  70  unexpected internal failure

Usage:
  python tools/room_checkpoint_linter.py --checkpoint design/ORISON_X_CHECKPOINT.md
  python tools/room_checkpoint_linter.py --checkpoint design   # all checkpoints
  python tools/room_checkpoint_linter.py --checkpoint <draft.md> \
      --scaffold-output <explicit-dir> [--force]

Scaffold mode writes, per checkpoint, `<name>.lint.json`, `<name>.lint.md`
and `<name>.decisions.json.proposed` into the explicit output directory only.
The proposed manifest is deliberately NOT named `*.decisions.json`, so the
reconciler will never pick it up until an author reviews it, fills every
"REQUIRED" marker and renames it.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import room_checkpoint_reconciler as rc   # noqa: E402
import room_layout_workbench as wb        # noqa: E402

ROOT = rc.ROOT
DEFAULT_LAYOUT = rc.DEFAULT_LAYOUT

READY = "READY"
NEEDS_ATTENTION = "NEEDS_ATTENTION"

MANUAL_TAG = re.compile(r"\[(manual|visual)\]", re.IGNORECASE)

# Room-envelope vocabulary: architectural surfaces that legitimately have no
# per-object placement record.
ARCH_VOCAB = {
    "wall", "walls", "floor", "floors", "ceiling", "ceilings", "trim",
    "wainscot", "dado", "enclosure", "envelope", "threshold", "reveal",
    "reveals", "junction", "junctions", "doorway", "tile", "tiled",
    "plaster", "window", "windows", "facade", "surround", "step", "opening",
}

STOPWORDS = {
    "and", "the", "with", "its", "their", "for", "of", "a", "an", "or",
    "on", "in", "to", "two", "one", "pair", "set", "unit", "area", "zone",
    "north", "south", "east", "west", "final", "clear", "complete",
}


def rel_path(path):
    p = Path(path)
    if not p.is_absolute():
        p = ROOT / p
    try:
        return p.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path).replace("\\", "/")


# ---------------------------------------------------------------------------
# Row reconstruction (from the reconciler's per-token decisions)
# ---------------------------------------------------------------------------

def rows_from_decisions(decisions):
    """Group the reconciler's per-token decisions back into table rows."""
    grouped = defaultdict(list)
    for d in decisions:
        grouped[(d["source"]["path"], d["source"]["line"])].append(d)
    rows = []
    for key in sorted(grouped):
        group = grouped[key]
        first = group[0]
        tokens = []
        seen = set()
        for d in group:
            if d["object"] is None:
                continue
            raw = d.get("object_source_token", d["object"])
            if raw in seen:
                tokens[-1]["ids"].append(d["object"])
                continue
            seen.add(raw)
            tokens.append({"raw": raw, "form": d["object_form"],
                           "ids": [d["object"]]})
        rows.append({
            "source": first["source"], "room": first["room"],
            "room_resolution": first["room_resolution"],
            "verdict": first["verdict"],
            "element_text": first["element_text"],
            "rationale": first["rationale"],
            "replacement": first.get("replacement"),
            "expected": first.get("expected") or {},
            "scope": first.get("scope", "layout"),
            "tokens": tokens,
        })
    return rows


# ---------------------------------------------------------------------------
# Token resolution
# ---------------------------------------------------------------------------

def occurrence_row(rid, occ):
    return {"id": rid, "room": occ["assigned_room"],
            "floor": occ["floor"], "category": occ["category"],
            "kind": occ["kind"], "asm": occ["asm"],
            "position": wb.fpt(occ["point"]) if occ["point"] else None,
            "yaw_deg": wb.fnum(occ["yaw"]) if occ["yaw"] is not None else None}


def kind_records(kind, ctx):
    """EVERY record of one assembly/marker kind (display layers may trim,
    but filtering by room must always see the full set)."""
    hits = []
    for rid in sorted(ctx["index"]):
        for occ in ctx["index"][rid]:
            if occ["asm"] == kind or occ["kind"] == kind:
                hits.append(occurrence_row(rid, occ))
                break
    return hits


def analyze_token(token, form, ids, ctx):
    """Resolve one backticked token.  Never guesses."""
    index = ctx["index"]
    out = {"token": token, "form": form, "diagnostics": [],
           "matches": [], "suggestion": ""}
    if form == "glob":
        matches = sorted(rid for rid in index
                         if fnmatch.fnmatchcase(rid, token))
        out["matches"] = [occurrence_row(r, index[r][0]) for r in matches[:10]]
        out["diagnostics"].append("EXACT")
        out["resolution"] = "family"
        out["suggestion"] = (f"glob currently matches {len(matches)} id(s); "
                             "an explicit stable set only if the WHOLE family "
                             "is intended")
        return out
    if form == "range":
        missing = [i for i in ids if i not in index]
        out["matches"] = [occurrence_row(i, index[i][0])
                          for i in ids if i in index][:10]
        if missing:
            out["diagnostics"].append("AMBIGUOUS")
            out["resolution"] = "partial-range"
            out["suggestion"] = (f"range expands to {len(ids)} ids but "
                                 f"{missing} do not exist in the layout; "
                                 "list the real ids explicitly")
        else:
            out["diagnostics"].append("EXACT")
            out["resolution"] = "range"
            out["suggestion"] = f"stable set of {len(ids)} existing ids"
        return out
    # literal
    occs = index.get(token, [])
    is_kind = token in ctx["kind_census"]
    if occs and is_kind:
        out["diagnostics"].append("CONFLICTING_TOKEN")
        out["resolution"] = "id-and-kind"
        out["matches"] = [occurrence_row(token, o) for o in occs[:4]]
        out["suggestion"] = (f"'{token}' is BOTH a record id and an "
                             "assembly/marker kind name; state which is meant")
        return out
    if len(occs) == 1:
        out["diagnostics"].append("EXACT")
        out["resolution"] = "exact"
        out["matches"] = [occurrence_row(token, occs[0])]
        out["suggestion"] = f"use `{token}`"
        return out
    if len(occs) > 1:
        out["diagnostics"].append("AMBIGUOUS")
        out["resolution"] = "duplicated-id"
        out["matches"] = [occurrence_row(token, o) for o in occs[:6]]
        out["suggestion"] = (f"id occurs {len(occs)} times in the layout; "
                             "the duplication itself needs a decision")
        return out
    if is_kind:
        out["diagnostics"].append("KIND_NOT_ID")
        out["resolution"] = "kind"
        out["matches"] = kind_records(token, ctx)[:10]
        out["suggestion"] = (f"'{token}' is an assembly/marker KIND "
                             f"({ctx['kind_census'][token]} record(s)), not an "
                             "object id; name the exact id(s) - a kind-wide "
                             "rule must be written as the explicit id list")
        return out
    near = rc.prefix_matches(token, index, limit=10)
    if near:
        out["diagnostics"].append("PREFIX_ONLY")
        out["resolution"] = "prefix"
        out["matches"] = [occurrence_row(r, index[r][0]) for r in near]
        if len(near) == 1:
            out["suggestion"] = (f"no record `{token}`; did the author mean "
                                 f"`{near[0]}`? (not assumed)")
        else:
            out["suggestion"] = (f"no record `{token}`; {len(near)} ids extend "
                                 f"it: {near}. Name them explicitly, or use "
                                 f"`{token}*` ONLY if the whole family is "
                                 "intended")
        return out
    runtime = ctx["runtime_scan"](token) if ctx["runtime_scan"] else []
    if runtime:
        out["diagnostics"].append("RUNTIME_ONLY")
        out["resolution"] = "runtime"
        out["matches"] = [{"id": token, "evidence": runtime}]
        out["suggestion"] = ("runtime GDScript object (identifier found in "
                             f"{runtime}); a text match does not prove "
                             "instantiation or placement - declare "
                             "`scope: runtime` in a manifest with a manual, "
                             "scene or live-proof field")
        return out
    out["diagnostics"].append("UNKNOWN")
    out["resolution"] = "unknown"
    out["suggestion"] = ("matches no layout id, kind or runtime identifier; "
                         "supply the exact object id or a manual-verification "
                         "record")
    return out


# ---------------------------------------------------------------------------
# Prose phrase analysis (rows with no backticked tokens)
# ---------------------------------------------------------------------------

def phrase_words(text):
    words = re.split(r"[^a-z0-9_]+", text.lower())
    return [w for w in words if len(w) >= 3 and w not in STOPWORDS]


def analyze_prose(element_text, room, ctx):
    """Conservative phrase resolution: architectural vocabulary, kind names
    (with in-room narrowing), and nothing else.  Multiple candidates are
    listed, never reduced to one."""
    words = phrase_words(element_text)
    arch = sorted({w for w in words if w in ARCH_VOCAB})
    findings = []
    seen_kinds = set()
    for i, word in enumerate(words):
        exact_kinds = []
        if word in ctx["kind_census"]:
            exact_kinds.append(word)
        bigram = "_".join(words[i:i + 2])
        if bigram in ctx["kind_census"]:
            exact_kinds.append(bigram)
        # Containment-derived candidates ("pendant" -> pendant_shade) are
        # weaker evidence: only reported when the room actually holds one.
        contained = [k for k in ctx["kind_census"]
                     if len(word) >= 4 and word in k.split("_")
                     and k not in exact_kinds]
        for kind, weak in ([(k, False) for k in exact_kinds]
                           + [(k, True) for k in contained]):
            if kind in seen_kinds:
                continue
            seen_kinds.add(kind)
            records = kind_records(kind, ctx)
            in_room = [r for r in records if room and r["room"] == room]
            if weak and not in_room:
                continue
            finding = {"phrase_word": word, "kind": kind,
                       "in_room": in_room, "elsewhere": len(records)}
            if room and len(in_room) == 1:
                finding["diagnostic"] = "EXACT"
                finding["suggestion"] = (f"phrase '{word}' resolves to exactly "
                                         f"one {kind} in {room}: use "
                                         f"`{in_room[0]['id']}`")
            elif in_room:
                finding["diagnostic"] = "AMBIGUOUS"
                finding["suggestion"] = (f"{len(in_room)} {kind} records in "
                                         f"{room}: "
                                         f"{[r['id'] for r in in_room]}; "
                                         "name each intended id")
            else:
                finding["diagnostic"] = "AMBIGUOUS"
                finding["suggestion"] = (f"kind '{kind}' matches no record in "
                                         f"{room or 'the (unresolved) room'}; "
                                         "check the room or the phrase")
            findings.append(finding)
    return arch, findings


# ---------------------------------------------------------------------------
# Verdict completeness
# ---------------------------------------------------------------------------

def lint_row(row, ctx):
    """Full analysis of one verdict row.  Returns the row result dict."""
    verdict = row["verdict"]
    result = {
        "source": row["source"], "room": row["room"],
        "room_resolution": row["room_resolution"], "verdict": verdict,
        "element_text": row["element_text"], "tokens": [],
        "prose": None, "diagnostics": [], "needs": [], "notes": [],
        "status": NEEDS_ATTENTION,
    }
    manual = bool(MANUAL_TAG.search(row["rationale"] or "")
                  or MANUAL_TAG.search(row["element_text"] or ""))
    if row["room_resolution"] == "unresolved":
        result["needs"].append("target room (not machine-resolved from the "
                               "checkpoint)")
    token_results = [analyze_token(t["raw"], t["form"], t["ids"], ctx)
                     for t in row["tokens"]]
    result["tokens"] = token_results
    diags = {d for t in token_results for d in t["diagnostics"]}

    if not token_results:
        arch, findings = analyze_prose(row["element_text"], row["room"], ctx)
        result["prose"] = {"architectural_vocabulary": arch,
                           "kind_findings": findings}
        if arch:
            diags.add("ARCHITECTURAL")
            result["notes"].append(
                "room-envelope element(s) "
                f"{arch}: no per-object id exists; use a `[manual]`/`[visual]` "
                "tag or a manifest manual-verification record")
        for f in findings:
            diags.add(f["diagnostic"])
        if not arch and not findings:
            diags.add("UNKNOWN")
            result["needs"].append("exact object id (phrase matches no known "
                                   "repository entity)")

    checkable_tokens = [t for t in token_results
                        if t["diagnostics"] == ["EXACT"]]
    exact_one = [t for t in checkable_tokens if t["resolution"] == "exact"]

    # verdict-specific requirements ---------------------------------------
    if verdict in ("REMOVE", "KEEP ABSENT"):
        # A literal token matching nothing is a perfectly checkable absence
        # target: the reconciler verifies "no such id" whether the object was
        # already retired or never existed.  (PREFIX_ONLY stays a warning -
        # a misspelt id would "verify" absent forever.)
        for t in token_results:
            if t["resolution"] == "unknown":
                diags.discard("UNKNOWN")
                t["diagnostics"] = ["EXACT"]
                t["suggestion"] = (f"`{t['token']}` matches nothing - already "
                                   "absent (or never existed); absence is "
                                   "checkable as written")
        checkable_tokens = [t for t in token_results
                            if t["diagnostics"] == ["EXACT"]]
        if not checkable_tokens and not manual:
            result["needs"].append("exact object id or explicit stable set "
                                   "(or a `[manual]` declaration)")
    elif verdict == "KEEP":
        runtime_row = any(t["resolution"] == "runtime" for t in token_results)
        if not checkable_tokens and not manual and not runtime_row:
            result["needs"].append("exact object id or explicit stable set "
                                   "(or a `[manual]` declaration)")
    elif verdict == "MOVE":
        exp = row["expected"]
        if not exact_one:
            result["needs"].append("exact object id for the moved object")
        if not (exp.get("position") or exp.get("room")):
            diags.add("MISSING_TARGET")
            result["needs"].append("target room and/or coordinates (a table's "
                                   "Room column is context, not a target)")
            for t in exact_one:
                cur = t["matches"][0].get("position")
                if cur:
                    result["notes"].append(
                        f"current position of `{t['token']}` is {cur} - for "
                        "reference only, never the target")
        else:
            if exp.get("position") and "tolerance_m" not in exp:
                diags.add("MISSING_TOLERANCE")
                result["notes"].append("no explicit tolerance_m; the "
                                       "reconciler default 0.05 m will apply")
            if exp.get("yaw_deg") is not None \
                    and "yaw_tolerance_deg" not in exp:
                diags.add("MISSING_TOLERANCE")
                result["notes"].append("no explicit yaw_tolerance_deg; the "
                                       "reconciler default 1.0 deg will apply")
    elif verdict == "REPAIR":
        if not row["expected"] and not manual:
            diags.add("MISSING_TARGET")
            result["needs"].append("a layout-checkable property (expected "
                                   "position/yaw/assembly) OR an explicit "
                                   "`[visual]`/`[manual]` marker - repairing "
                                   "appearance is not layout-verifiable")
    elif verdict == "REPLACE":
        if not row["replacement"]:
            diags.add("MISSING_TARGET")
            result["needs"].append("both old and replacement ids "
                                   "(`old` -> `new` in the element cell, or a "
                                   "manifest `replacement` field)")
        else:
            rep = row["replacement"]
            if rep in ctx["index"]:
                result["notes"].append(f"replacement `{rep}` already exists "
                                       "in the layout")
            if exact_one:
                result["notes"].append("old object still present; REPLACE is "
                                       "not yet applied")
    elif verdict == "ADD":
        # For an ADD, a token matching NOTHING is the good case: it is the
        # proposed new id.  Only a token that already exists is a problem.
        kind_tokens = [t for t in token_results if t["resolution"] == "kind"]
        proposed = [t for t in token_results
                    if t["resolution"] in ("unknown", "prefix", "runtime")]
        for t in proposed:
            diags.discard(t["diagnostics"][0])
            t["diagnostics"] = ["EXACT"]
            t["suggestion"] = (f"proposed new id `{t['token']}` (does not "
                               "exist yet - correct for ADD)")
        if not proposed and not any(t["resolution"] == "exact"
                                    for t in token_results):
            diags.add("MISSING_TARGET")
            result["needs"].append("a stable proposed id for the addition")
        for t in token_results:
            if t["resolution"] == "exact":
                diags.add("CONFLICTING_TOKEN")
                result["needs"].append(
                    f"proposed id `{t['token']}` ALREADY exists "
                    f"(in {t['matches'][0]['room']}); choose a new id or "
                    "change the verdict")
        if not row["room"]:
            result["needs"].append("target room for the addition")
        if kind_tokens:
            diags.discard("KIND_NOT_ID")
            result["notes"].append(
                "expected type taken from kind token(s): "
                f"{[t['token'] for t in kind_tokens]}")
        elif not (row["expected"].get("assembly")
                  or row["expected"].get("kind")):
            diags.add("MISSING_TARGET")
            result["needs"].append("expected assembly/type of the addition")

    if row.get("scope") == "runtime":
        if row["expected"].get("proof") or row["expected"].get("evidence") \
                or manual:
            diags.discard("RUNTIME_ONLY")
            result["notes"].append("declared runtime scope with a proof "
                                   "field; the reconciler will treat this as "
                                   "explicitly unverifiable-by-layout")
        else:
            result["needs"].append("a manual, scene or live-proof field for "
                                   "this runtime-scoped spatial verdict")
    elif "RUNTIME_ONLY" in diags:
        result["needs"].append("`scope: runtime` declaration in a manifest, "
                               "plus a manual/scene/live-proof field")

    if manual:
        diags.add("MANUAL_TARGET")

    blocking = {"AMBIGUOUS", "PREFIX_ONLY", "KIND_NOT_ID", "UNKNOWN",
                "MISSING_TARGET", "CONFLICTING_TOKEN", "RUNTIME_ONLY",
                "ARCHITECTURAL"}
    is_blocked = bool(diags & blocking) or bool(result["needs"])
    if manual and not (diags & {"CONFLICTING_TOKEN"}):
        # An explicit manual/visual declaration is a legitimate final state.
        is_blocked = False
        result["needs"] = []
    result["status"] = NEEDS_ATTENTION if is_blocked else READY
    if result["status"] == READY:
        diags.add("READY")
    result["diagnostics"] = sorted(diags)
    return result


# ---------------------------------------------------------------------------
# Document linting
# ---------------------------------------------------------------------------

def build_context(layout_path, runtime_scan_root=None):
    layout = json.loads(Path(layout_path).read_text(encoding="utf-8"))
    tables = wb.load_footprint_tables()
    index, rooms_by_id, kind_census = rc.build_object_index(layout, tables)
    scan = rc.build_runtime_evidence_scanner(runtime_scan_root or ROOT)
    return {"index": index, "rooms_by_id": rooms_by_id,
            "kind_census": kind_census, "runtime_scan": scan,
            "layout_path": rel_path(layout_path)}


def document_token_inventory(path, ctx):
    """For prose-only checkpoints: resolve every backticked token in the
    document (informational; these are not decisions)."""
    text = Path(path).read_text(encoding="utf-8")
    inventory = []
    seen = set()
    for raw in rc.BACKTICK.findall(text):
        expanded = rc.expand_object_token(raw)
        if not expanded or raw in seen or raw in ctx["rooms_by_id"]:
            continue
        seen.add(raw)
        form, ids = expanded
        inventory.append(analyze_token(raw, form, ids, ctx))
    return inventory


def lint_checkpoint(path, ctx):
    """Lint one checkpoint (markdown) or manifest (json) file."""
    path = Path(path)
    if path.suffix == ".json":
        decisions, malformed, doc_report = rc.parse_manifest(path)
    else:
        decisions, malformed, doc_report = rc.parse_checkpoint_markdown(
            path, set(ctx["rooms_by_id"]))
    rows = [lint_row(r, ctx) for r in rows_from_decisions(decisions)]
    doc = {
        "path": rel_path(path), "kind": doc_report["kind"],
        "verdict_tables": doc_report["verdict_tables"],
        "rows": rows, "malformed": malformed,
        "document_diagnostics": [],
        "token_inventory": [],
        "summary": {
            "ready": sum(r["status"] == READY for r in rows),
            "needs_attention": sum(r["status"] == NEEDS_ATTENTION
                                   for r in rows),
            "malformed": len(malformed),
        },
    }
    if doc_report["verdict_tables"] == 0 and path.suffix != ".json":
        doc["document_diagnostics"].append("NO_VERDICT_TABLE")
        doc["token_inventory"] = document_token_inventory(path, ctx)
    return doc


def exit_code_for(docs):
    code = 0
    if any(d["summary"]["needs_attention"] for d in docs) \
            or any(d["document_diagnostics"] for d in docs):
        code |= 1
    if any(d["summary"]["malformed"] for d in docs):
        code |= 4
    return code


# ---------------------------------------------------------------------------
# Reports and scaffolds
# ---------------------------------------------------------------------------

def lint_markdown(doc):
    lines = [f"# Checkpoint lint: {doc['path']}", "",
             f"- Verdict tables: {doc['verdict_tables']}; rows analyzed: "
             f"{len(doc['rows'])}; READY: {doc['summary']['ready']}; needs "
             f"attention: {doc['summary']['needs_attention']}; malformed: "
             f"{doc['summary']['malformed']}", ""]
    if "NO_VERDICT_TABLE" in doc["document_diagnostics"]:
        lines += ["**NO_VERDICT_TABLE** - prose-only checkpoint: its room "
                  "verdicts live in sentences no tool will guess at.  Add an "
                  "`Object and architecture verdicts` table or a "
                  "`*.decisions.json` manifest.", ""]
        if doc["token_inventory"]:
            lines += ["Backticked tokens found in the prose (informational):",
                      ""]
            for t in doc["token_inventory"]:
                lines.append(f"- `{t['token']}` [{'/'.join(t['diagnostics'])}]"
                             f": {t['suggestion']}")
            lines.append("")
    for r in doc["rows"]:
        head = (f"## line {r['source']['line']} - {r['verdict']} in "
                f"{r['room'] or '(room unresolved)'} - **{r['status']}**")
        lines += [head, "", f"> {r['source']['quote'][:220]}", ""]
        lines.append(f"- Diagnostics: {', '.join(r['diagnostics'])}")
        for t in r["tokens"]:
            lines.append(f"- token `{t['token']}` "
                         f"[{'/'.join(t['diagnostics'])}]: {t['suggestion']}")
            for m in t["matches"][:6]:
                if "evidence" in m:
                    lines.append(f"  - runtime evidence: {m['evidence']}")
                else:
                    lines.append(
                        f"  - `{m['id']}` in {m['room'] or 'no declared room'}"
                        f" ({m['category']}"
                        + (f"/{m['asm'] or m['kind']}"
                           if (m['asm'] or m['kind']) else "")
                        + (f", pos {m['position']}" if m['position'] else "")
                        + (f", yaw {m['yaw_deg']}"
                           if m['yaw_deg'] is not None else "") + ")")
        if r["prose"]:
            for f in r["prose"]["kind_findings"]:
                lines.append(f"- phrase [{f['diagnostic']}]: {f['suggestion']}")
            if r["prose"]["architectural_vocabulary"]:
                lines.append(f"- architectural vocabulary: "
                             f"{r['prose']['architectural_vocabulary']}")
        for n in r["needs"]:
            lines.append(f"- NEEDS: {n}")
        for n in r["notes"]:
            lines.append(f"- note: {n}")
        lines.append("")
    if doc["malformed"]:
        lines += ["## Malformed rows", ""]
        for m in doc["malformed"]:
            lines.append(f"- line {m['line']}: {m['problem']}")
            lines.append(f"  - quoted: `{m['quote'][:160]}`")
        lines.append("")
    return "\n".join(lines) + "\n"


REQUIRED = "REQUIRED"


def proposed_manifest(doc):
    """Evidence-backed scaffold of a decisions manifest for one checkpoint.

    Every field the author must still decide carries the "REQUIRED" marker;
    ambiguous candidates are listed, never chosen.  The file is suffixed
    `.proposed` so the reconciler will not read it.
    """
    decisions = []
    for r in doc["rows"]:
        exact = [t for t in r["tokens"]
                 if t["diagnostics"] == ["EXACT"] and t["resolution"] == "exact"]
        candidates = sorted({m["id"] for t in r["tokens"]
                             for m in t["matches"]
                             if "id" in m and "evidence" not in m})
        runtime = [t for t in r["tokens"] if t["resolution"] == "runtime"]
        entry = {
            "room": r["room"] or REQUIRED,
            "object": exact[0]["token"] if len(exact) == 1 else None,
            "verdict": r["verdict"],
            "rationale": REQUIRED,
            "source": {"path": r["source"]["path"],
                       "line": r["source"]["line"],
                       "quote": r["source"]["quote"][:240]},
        }
        if entry["object"] is None:
            entry["object_required"] = True
            if candidates:
                entry["object_candidates"] = candidates[:12]
        if len(exact) > 1:
            entry["note"] = ("row names several exact ids; one manifest "
                            "entry per id is required")
            entry["object_candidates"] = [t["token"] for t in exact]
        if r["verdict"] == "MOVE":
            entry["expected"] = {"room": r["room"] or REQUIRED,
                                 "position": REQUIRED,
                                 "tolerance_m": REQUIRED,
                                 "yaw_deg": REQUIRED,
                                 "yaw_tolerance_deg": REQUIRED}
        elif r["verdict"] == "REPAIR":
            entry["expected"] = REQUIRED
            entry["or_mark_manual"] = "[visual] / [manual] in the checkpoint"
        elif r["verdict"] == "REPLACE":
            entry["replacement"] = REQUIRED
        elif r["verdict"] == "ADD":
            entry["expected"] = {"assembly": REQUIRED}
        if runtime:
            entry["scope"] = "runtime"
            entry["evidence"] = runtime[0]["matches"][0]["evidence"]
            entry["proof"] = REQUIRED
            if entry["object"] is None and len(runtime) == 1 \
                    and len(r["tokens"]) == 1:
                # The runtime identifier IS the object; the reconciler
                # accepts it under scope: runtime.
                entry["object"] = runtime[0]["token"]
                entry.pop("object_required", None)
                entry.pop("object_candidates", None)
        decisions.append(entry)
    return {
        "version": 1,
        "PROPOSED": ("generated by room_checkpoint_linter; NOT an approved "
                     "checkpoint manifest.  Review every entry, replace every "
                     "'REQUIRED', delete what you do not endorse, then rename "
                     "away the .proposed suffix."),
        "source_checkpoint": doc["path"],
        "base_commit": None,
        "decisions": decisions,
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def discover_targets(checkpoint):
    p = Path(checkpoint)
    if p.is_dir():
        return sorted(p.rglob(rc.CHECKPOINT_GLOB))
    return [p]


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Read-only linter/scaffolder for room checkpoint drafts")
    parser.add_argument("--checkpoint", type=Path, required=True,
                        help="a checkpoint .md (or .decisions.json), or a "
                             "directory scanned for ORISON_*CHECKPOINT*.md")
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--scaffold-output", type=Path,
                        help="explicit directory for <name>.lint.json/.md and "
                             "<name>.decisions.json.proposed (never written "
                             "beside the checkpoints by default)")
    parser.add_argument("--force", action="store_true",
                        help="overwrite existing scaffold files")
    args = parser.parse_args(argv)

    try:
        ctx = build_context(args.layout)
        targets = discover_targets(args.checkpoint)
        if not targets or not all(Path(t).exists() for t in targets):
            print(f"error: no checkpoint found at {args.checkpoint}",
                  file=sys.stderr)
            return 2
        docs = [lint_checkpoint(t, ctx) for t in targets]
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70

    if args.scaffold_output:
        args.scaffold_output.mkdir(parents=True, exist_ok=True)
        targets_out = []
        for doc in docs:
            stem = Path(doc["path"]).name
            if stem.endswith(".md"):
                stem = stem[:-3]
            targets_out += [
                (args.scaffold_output / f"{stem}.lint.json", doc, "json"),
                (args.scaffold_output / f"{stem}.lint.md", doc, "md"),
                (args.scaffold_output / f"{stem}.decisions.json.proposed",
                 doc, "manifest"),
            ]
        try:
            wb.preflight_overwrite([t[0] for t in targets_out], args.force)
        except FileExistsError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 3
        for path, doc, kind in targets_out:
            if kind == "json":
                path.write_text(json.dumps(doc, indent=1, sort_keys=True)
                                + "\n", encoding="utf-8")
            elif kind == "md":
                path.write_text(lint_markdown(doc), encoding="utf-8")
            else:
                path.write_text(json.dumps(proposed_manifest(doc), indent=1,
                                           sort_keys=True) + "\n",
                                encoding="utf-8")
            print(path)
    else:
        for doc in docs:
            sys.stdout.write(lint_markdown(doc))

    code = exit_code_for(docs)
    ready = sum(d["summary"]["ready"] for d in docs)
    needs = sum(d["summary"]["needs_attention"] for d in docs)
    malformed = sum(d["summary"]["malformed"] for d in docs)
    prose_only = sum("NO_VERDICT_TABLE" in d["document_diagnostics"]
                     for d in docs)
    print(f"documents={len(docs)} ready={ready} needs_attention={needs} "
          f"malformed={malformed} prose_only={prose_only} -> exit {code}",
          file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
