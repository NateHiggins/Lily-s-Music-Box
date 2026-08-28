#!/usr/bin/env python3
"""Read-only floor reconstruction progress ledger for the Orison.

Aggregates the existing tooling into one deterministic answer to "how far
along is each floor, and what is the next evidence task?"  It is a progress
ledger, NOT a completion authority: no state emitted here ever means a room
is done.  Completion requires visual, architectural, interaction and route
evidence beyond static aggregation, so the strongest state this tool can
report is equivalent to "layout drift green; manual/runtime evidence
remains."

The ledger reuses, and never reinterprets, the existing machinery:

  - tools/audit_orison_rooms.py            spatial-census candidates
  - tools/room_layout_workbench.py         object index, room views, profiles
  - tools/room_checkpoint_reconciler.py    decision survival vs regeneration
  - tools/room_checkpoint_linter.py        machine-checkability of rows

Per-room states (a room may carry several):
  UNPROFILED / PROFILED           written room-purpose profile found or not
  AUDIT_PENDING                   spatial-census candidates and no structured
                                  checkpoint yet
  CHECKPOINT_PROSE_ONLY           covered only by a checkpoint without a
                                  verdict table or manifest
  CHECKPOINT_STRUCTURED           machine-parseable decisions exist
  DRIFT_GREEN / DRIFT_RED         no structured decision contradicted / at
                                  least one contradiction or conflict
  MANUAL_EVIDENCE_REQUIRED        unverifiable (manual/runtime/prose)
                                  decisions remain
  MALFORMED                       a covering checkpoint has malformed rows

Exit codes (aligned with the reconciler and linter):
  0   aggregation succeeded; no contradictions, conflicts or malformed data
  1   at least one contradiction or cross-checkpoint conflict
  3   refused to overwrite existing output (pass --force)
  4   malformed checkpoint data
  5   both 1 and 4
  2   command-line usage error (argparse default)
  70  unexpected internal failure
OPEN, UNVERIFIABLE and incomplete coverage stay visible but never fail the
aggregation.

Usage:
  python tools/room_reconstruction_progress.py --output <dir>
  python tools/room_reconstruction_progress.py \
      --layout art/data/building_layout.json --checkpoints design \
      --output <dir> [--floor F01] [--room F01_COMMON_B] \
      [--json-only | --markdown-only] [--force] [--no-git]

Room-profile discovery scans the --checkpoints directory (design/ in
production) for markdown whose "Room profile" section names the room.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_orison_rooms as audit        # noqa: E402
import room_checkpoint_linter as rl       # noqa: E402
import room_checkpoint_reconciler as rc   # noqa: E402
import room_layout_workbench as wb        # noqa: E402

ROOT = rc.ROOT
DEFAULT_LAYOUT = rc.DEFAULT_LAYOUT

# Reconstruction sequence positions transcribed from
# design/ORISON_ROOM_RECONSTRUCTION_PLAN_2026-08-27.md "Order of work":
# 1 opening route (F01), 2 player route (F04), 3 case-one apartment (F02),
# 4 building services (B1, ROOF), 5+ remaining floors, then reconciliation.
PLAN_SEQUENCE = {"F01": 1, "F04": 2, "F02": 3, "B1": 4, "ROOF": 4,
                 "F03": 5, "F05": 5, "F06": 5}

STATES = ("UNPROFILED", "PROFILED", "AUDIT_PENDING", "CHECKPOINT_PROSE_ONLY",
          "CHECKPOINT_STRUCTURED", "DRIFT_GREEN", "DRIFT_RED",
          "MANUAL_EVIDENCE_REQUIRED", "MALFORMED")

EVIDENCE_HEADING = re.compile(r"^##+\s.*(validation|evidence)", re.IGNORECASE)


# ---------------------------------------------------------------------------
# Source gathering
# ---------------------------------------------------------------------------

def gather(layout_path, checkpoints_dir, use_git=True):
    """Run every underlying tool once and return their raw products."""
    layout = json.loads(Path(layout_path).read_text(encoding="utf-8"))
    tables = wb.load_footprint_tables()
    checkpoints_dir = Path(checkpoints_dir)
    if checkpoints_dir.is_dir():
        recon = rc.reconcile(layout_path, checkpoints_dir, tables=tables,
                             use_git=use_git)
        ctx = rl.build_context(layout_path)
        docs, manifests = rc.discover_checkpoints(checkpoints_dir)
        lint_docs = [rl.lint_checkpoint(p, ctx) for p in docs + manifests]
    else:
        recon = {"summary": {s: 0 for s in ("SATISFIED", "OPEN",
                                            "CONTRADICTED", "UNVERIFIABLE",
                                            "MALFORMED")},
                 "documents": [], "provenance": {}, "decisions_by_room": {},
                 "conflicts": [], "duplicates": [], "malformed_rows": [],
                 "runtime_only_dependencies": [],
                 "next_reconstruction_actions": []}
        lint_docs = []
    census = audit.audit(layout)
    return {"layout": layout, "tables": tables, "recon": recon,
            "lint_docs": lint_docs, "census": census,
            "checkpoints_dir": checkpoints_dir}


def checkpoint_evidence(path):
    """Validation/evidence bullets cited by one checkpoint, verbatim, with a
    recorded result only when the document explicitly states one."""
    try:
        lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    out, active = [], False
    for line in lines:
        if line.startswith("#"):
            active = bool(EVIDENCE_HEADING.match(line))
            continue
        if active and line.lstrip().startswith("- "):
            text = line.strip()[2:].strip()
            if "PASS" in text:
                result = "PASS (recorded)"
            elif "FAIL" in text:
                result = "FAIL (recorded)"
            elif "exit 0" in text:
                result = "exit 0 (recorded)"
            else:
                result = "cited; no recorded result"
            out.append({"evidence": text[:180], "result": result})
    return out


# ---------------------------------------------------------------------------
# Per-room assembly
# ---------------------------------------------------------------------------

def doc_index(sources):
    """path -> {kind, verdict_tables, rooms_named, malformed, evidence}."""
    idx = {}
    for doc in sources["recon"]["documents"]:
        idx[doc["path"]] = {
            "kind": doc["kind"],
            "verdict_tables": doc.get("verdict_tables", 0),
            "rooms_named": doc.get("rooms_named", []),
            "malformed": doc.get("malformed_rows", 0),
            "evidence": (checkpoint_evidence(doc["path"])
                         if doc["kind"] == "markdown-checkpoint" else []),
        }
    return idx


def census_by_room(sources):
    """Map spatial-census candidates onto rooms, conservatively.

    Door-sweep candidates attach to the rooms a door serves (rooms field or
    adjacency probe); wall near-misses attach to rooms whose padded rect
    contains an endpoint; unassigned records stay floor-level.
    """
    per_room = defaultdict(lambda: {"door_sweep": 0, "wall_near_miss": 0})
    floor_level = {}
    layout = sources["layout"]
    for floor, result in zip(layout["floors"], sources["census"]):
        rooms = floor.get("rooms", [])
        door_rooms = {}
        for m in floor.get("markers", []):
            if wb.is_room_door(m):
                view = wb.door_view(m, rooms)
                door_rooms[view["id"]] = sorted(set(
                    view["rooms_field"]
                    + [r for r in view["adjacent_rooms"] if r]))
        for door_id, _obj in result["door_hits"]:
            for room_id in door_rooms.get(door_id, []):
                per_room[room_id]["door_sweep"] += 1
        for _wa, _wb, _dist, pa, pb in result["near_misses"]:
            for room in rooms:
                pad = wb.inflate(room["rect"], 0.6)
                if audit.inside(pa, pad) or audit.inside(pb, pad):
                    per_room[room["id"]]["wall_near_miss"] += 1
        floor_level[floor["id"]] = {
            "outside_any_room_records": len(result["unassigned"]),
            "door_sweep_candidates": len(result["door_hits"]),
            "wall_near_misses": len(result["near_misses"]),
        }
    return per_room, floor_level


def room_limitations(sources, room_id):
    """Workbench-view limitation counts; also proves a packet is generatable."""
    try:
        view = wb.collect_room_view(sources["layout"], room_id,
                                    sources["tables"])
    except Exception as exc:                # noqa: BLE001 - reported, not fatal
        return {"packet_generatable": False,
                "error": f"{type(exc).__name__}: {exc}"}
    objects = view["objects"]
    return {
        "packet_generatable": True,
        "objects": len(objects),
        "unknown_footprints": sum(o["tier"] == wb.UNKNOWN for o in objects),
        "ambiguous_ownership": sum(
            bool(o.get("ownership", {}).get("ambiguous")) for o in objects),
        "boundary_crossers": sum(
            bool(o.get("ownership", {}).get("crosses_room_boundary"))
            for o in objects),
    }


def build_room_record(sources, room, floor_id, docs, per_room_census):
    room_id = room["id"]
    recon = sources["recon"]
    residents = sources["layout"].get("meta", {}).get("residents", {})
    decisions = recon["decisions_by_room"].get(room_id, [])
    covering_docs = sorted({d["source"]["path"] for d in decisions})
    prose_docs = sorted(p for p, meta in docs.items()
                        if meta["verdict_tables"] == 0
                        and room_id in meta["rooms_named"])
    structured_kinds = {docs[p]["kind"] for p in covering_docs if p in docs}
    if any(k == "decisions-manifest" for k in structured_kinds):
        coverage = "manifest-backed"
    elif covering_docs:
        coverage = "verdict-table"
    elif prose_docs:
        coverage = "prose-only"
    else:
        coverage = "none"

    counts = {s: 0 for s in ("SATISFIED", "OPEN", "CONTRADICTED",
                             "UNVERIFIABLE")}
    for d in decisions:
        counts[d["status"]] += 1
    malformed = sum(docs[p]["malformed"] for p in covering_docs + prose_docs
                    if p in docs)

    lint = {"READY": 0, "NEEDS_ATTENTION": 0, "runtime_only": 0,
            "manual_visual": 0, "ambiguous": 0, "unknown": 0}
    for doc in sources["lint_docs"]:
        for row in doc["rows"]:
            if row["room"] != room_id:
                continue
            lint[row["status"]] += 1
            diags = set(row["diagnostics"])
            lint["runtime_only"] += "RUNTIME_ONLY" in diags
            lint["manual_visual"] += "MANUAL_TARGET" in diags
            lint["ambiguous"] += "AMBIGUOUS" in diags
            lint["unknown"] += "UNKNOWN" in diags

    objects_here = {d["object"] for d in decisions if d["object"]}
    conflicts = sorted(c["object"] for c in recon["conflicts"]
                       if c["object"] in objects_here)
    duplicates = sorted(c["object"] for c in recon["duplicates"]
                        if c["object"] in objects_here)

    provenance = None
    for path in covering_docs + prose_docs:
        prov = recon["provenance"].get(path)
        if prov and prov.get("commit"):
            if provenance is None or (prov["layout_commits_since"] or 0) < \
                    (provenance["layout_commits_since"] or 1 << 30):
                provenance = {"checkpoint": path, "commit": prov["commit"],
                              "layout_commits_since":
                                  prov["layout_commits_since"]}

    evidence = []
    for path in covering_docs + prose_docs:
        for item in docs.get(path, {}).get("evidence", []):
            evidence.append(dict(item, checkpoint=path))
    census_counts = per_room_census.get(room_id,
                                        {"door_sweep": 0,
                                         "wall_near_miss": 0})
    limitations = room_limitations(sources, room_id)

    profiles = wb.find_room_profiles(room_id, sources["checkpoints_dir"])
    profiled = any(p["profile_excerpt"] for p in profiles)

    states = ["PROFILED" if profiled else "UNPROFILED"]
    structured = coverage in ("verdict-table", "manifest-backed")
    if structured:
        states.append("CHECKPOINT_STRUCTURED")
    elif coverage == "prose-only":
        states.append("CHECKPOINT_PROSE_ONLY")
    total_candidates = sum(census_counts.values())
    if total_candidates and not structured:
        states.append("AUDIT_PENDING")
    if structured:
        states.append("DRIFT_RED" if counts["CONTRADICTED"] or conflicts
                      else "DRIFT_GREEN")
    if counts["UNVERIFIABLE"]:
        states.append("MANUAL_EVIDENCE_REQUIRED")
    if malformed:
        states.append("MALFORMED")

    if "DRIFT_RED" in states:
        headline = "layout drift RED: contradicted decisions or conflicts"
    elif "DRIFT_GREEN" in states and "MANUAL_EVIDENCE_REQUIRED" in states:
        headline = "layout drift green; manual/runtime evidence remains"
    elif "DRIFT_GREEN" in states:
        headline = ("layout drift green; completion still requires visual/"
                    "interaction evidence beyond these tools")
    elif coverage == "prose-only":
        headline = "checkpointed in prose only; not machine-checkable"
    elif profiled:
        headline = "profiled; no checkpoint yet"
    else:
        headline = "no profile, no checkpoint"

    return {
        "floor": floor_id, "room": room_id,
        "kind": room.get("kind"), "unit": room.get("unit"),
        "resident": residents.get(room.get("unit", "")),
        "profiled": profiled,
        "profile_sources": [p["path"] for p in profiles
                            if p["profile_excerpt"]],
        "coverage": coverage,
        "checkpoints": covering_docs + [p for p in prose_docs
                                        if p not in covering_docs],
        "decisions": dict(counts, MALFORMED_in_covering_docs=malformed),
        "lint": lint,
        "conflicts": conflicts, "compatible_duplicates": duplicates,
        "census_candidates": dict(census_counts, total=total_candidates),
        "workbench": limitations,
        "provenance": provenance,
        "validation_evidence": evidence,
        "states": states,
        "headline": headline,
    }


# ---------------------------------------------------------------------------
# Roll-ups
# ---------------------------------------------------------------------------

def floor_rollup(floor_id, records, floor_census):
    def n(pred):
        return sum(1 for r in records if pred(r))

    regen = [r["provenance"]["layout_commits_since"] for r in records
             if r["provenance"]
             and r["provenance"]["layout_commits_since"] is not None]
    return {
        "floor": floor_id,
        "plan_sequence_position": PLAN_SEQUENCE.get(floor_id),
        "rooms": len(records),
        "profiled": n(lambda r: r["profiled"]),
        "checkpointed": n(lambda r: r["coverage"] != "none"),
        "structured": n(lambda r: r["coverage"] in ("verdict-table",
                                                    "manifest-backed")),
        "prose_only": n(lambda r: r["coverage"] == "prose-only"),
        "decisions": {
            s: sum(r["decisions"][s] for r in records)
            for s in ("SATISFIED", "OPEN", "CONTRADICTED", "UNVERIFIABLE")},
        "rooms_with_conflicts_or_malformed": n(
            lambda r: r["conflicts"]
            or r["decisions"]["MALFORMED_in_covering_docs"]),
        "rooms_with_census_candidates": n(
            lambda r: r["census_candidates"]["total"]),
        "rooms_needing_manual_or_runtime_evidence": n(
            lambda r: "MANUAL_EVIDENCE_REQUIRED" in r["states"]),
        "max_layout_regenerations_since_checkpoint": max(regen, default=None),
        "floor_level_census": floor_census.get(floor_id, {}),
    }


def building_summary(records, sources, docs):
    recon = sources["recon"]
    unresolved_rooms = sorted(
        {d["source"]["path"] + ":" + str(d["source"]["line"])
         for room, rows in recon["decisions_by_room"].items()
         if room == "(room unresolved)" for d in rows})
    declared = {r["room"] for r in records}
    phantom = sorted(room for room in recon["decisions_by_room"]
                     if room not in declared and room != "(room unresolved)")
    docs_no_room = sorted(p for p, meta in docs.items()
                          if meta["kind"] == "markdown-checkpoint"
                          and not meta["rooms_named"])
    lint_ready = sum(r["lint"]["READY"] for r in records)
    lint_needs = sum(r["lint"]["NEEDS_ATTENTION"] for r in records)
    return {
        "declared_rooms": len(records),
        "rooms_checkpointed": sum(1 for r in records
                                  if r["coverage"] != "none"),
        "rooms_structured": sum(1 for r in records if r["coverage"] in
                                ("verdict-table", "manifest-backed")),
        "structured_decisions": sum(
            sum(r["decisions"][s] for s in ("SATISFIED", "OPEN",
                                            "CONTRADICTED", "UNVERIFIABLE"))
            for r in records),
        "drift": dict(recon["summary"]),
        "lint": {"READY": lint_ready, "NEEDS_ATTENTION": lint_needs},
        "manual_runtime_evidence_debt": sum(
            r["decisions"]["UNVERIFIABLE"] for r in records),
        "floors_with_no_reconstruction_work": sorted(
            {r["floor"] for r in records}
            - {r["floor"] for r in records
               if r["profiled"] or r["coverage"] != "none"}),
        "checkpoints_resolving_to_no_declared_room": docs_no_room,
        "room_ids_referenced_but_not_declared": phantom,
        "decisions_with_unresolved_room_mapping": unresolved_rooms,
        "note": ("a green drift summary is not proof of visual or functional "
                 "completion"),
    }


# ---------------------------------------------------------------------------
# Next-action queue
# ---------------------------------------------------------------------------

RANK_REASON = {
    1: "rank 1: contradictions or conflicts",
    2: "rank 2: malformed decision records",
    3: "rank 3: checkpointed room with unknown regeneration status",
    4: "rank 4: prose-only checkpoint",
    5: "rank 5: unresolved machine-checkability / evidence debt",
    6: "rank 6: profiled but uncheckpointed room",
    7: "rank 7: unprofiled room on the plan's current floor",
    8: "rank 8: later-floor work",
}


def next_actions(records, docs, sources):
    actions = []

    def add(rank, room, action, detail):
        actions.append({"rank": rank, "room": room, "action": action,
                        "detail": detail, "ranking_source": RANK_REASON[rank]})

    for r in records:
        if "DRIFT_RED" in r["states"]:
            add(1, r["room"], "resolve contradicted decisions",
                f"contradicted={r['decisions']['CONTRADICTED']}, "
                f"conflicts={r['conflicts']}")
    for path, meta in sorted(docs.items()):
        if meta["malformed"]:
            add(2, None, "fix malformed decision records",
                f"{meta['malformed']} malformed row(s) in {path}")
    for r in records:
        if r["coverage"] in ("verdict-table", "manifest-backed") \
                and (r["provenance"] is None
                     or r["provenance"]["layout_commits_since"] is None):
            add(3, r["room"], "rerun reconciliation after regeneration",
                "checkpoint base commit or regeneration count unknown")
    for path, meta in sorted(docs.items()):
        if meta["kind"] == "markdown-checkpoint" \
                and meta["verdict_tables"] == 0:
            rooms = ", ".join(meta["rooms_named"]) or "no room resolved"
            add(4, None, "create a structured checkpoint (verdict table or "
                "manifest)", f"{path} is prose-only (rooms: {rooms})")
    for r in records:
        if r["lint"]["NEEDS_ATTENTION"]:
            add(5, r["room"], "add exact IDs/targets to the checkpoint",
                f"{r['lint']['NEEDS_ATTENTION']} lint row(s) need attention "
                f"(ambiguous={r['lint']['ambiguous']}, "
                f"unknown={r['lint']['unknown']})")
        if r["decisions"]["UNVERIFIABLE"]:
            add(5, r["room"], "collect manual/runtime evidence",
                f"{r['decisions']['UNVERIFIABLE']} decision(s) are outside "
                "layout proof")
    for r in records:
        if r["profiled"] and r["coverage"] == "none":
            add(6, r["room"], "create a checkpoint",
                "room is profiled but has no checkpoint")
    current = min((PLAN_SEQUENCE.get(r["floor"], 99) for r in records
                   if not r["profiled"] or r["coverage"] == "none"),
                  default=None)
    for r in records:
        if r["profiled"] or r["coverage"] != "none":
            continue
        rank = 7 if PLAN_SEQUENCE.get(r["floor"], 99) == current else 8
        detail = "write a room profile"
        if r["census_candidates"]["total"]:
            detail += (f"; {r['census_candidates']['total']} spatial-census "
                       "candidate(s) await review")
        add(rank, r["room"], "write a room profile", detail)
    actions.sort(key=lambda a: (a["rank"], a["room"] or "",
                                a["action"], a["detail"]))
    return actions


# ---------------------------------------------------------------------------
# Report emission
# ---------------------------------------------------------------------------

def build_report(sources, floor_filter=None, room_filter=None):
    layout = sources["layout"]
    docs = doc_index(sources)
    per_room_census, floor_census = census_by_room(sources)
    records = []
    for floor in layout["floors"]:
        if floor_filter and floor["id"] != floor_filter:
            continue
        for room in floor.get("rooms", []):
            if room_filter and room["id"] != room_filter:
                continue
            records.append(build_room_record(sources, room, floor["id"],
                                             docs, per_room_census))
    records.sort(key=lambda r: (r["floor"], r["room"]))
    floors = []
    for floor in layout["floors"]:
        if floor_filter and floor["id"] != floor_filter:
            continue
        floor_records = [r for r in records if r["floor"] == floor["id"]]
        if floor_records:
            floors.append(floor_rollup(floor["id"], floor_records,
                                       floor_census))
    return {
        "ledger": {
            "authority": ("progress ledger only; never a completion "
                          "authority.  Completion requires visual, "
                          "architectural, interaction and route evidence "
                          "beyond these tools."),
            "layout": str(sources.get("layout_path", "")).replace("\\", "/"),
            "filters": {"floor": floor_filter, "room": room_filter},
            "plan_sequence_source":
                "design/ORISON_ROOM_RECONSTRUCTION_PLAN_2026-08-27.md",
        },
        "building": building_summary(records, sources, docs),
        "floors": floors,
        "rooms": records,
        "next_actions": next_actions(records, docs, sources),
    }


def report_markdown(report):
    b = report["building"]
    lines = ["# Orison reconstruction progress ledger", "",
             f"> {report['ledger']['authority']}", "",
             "## Building", "",
             f"- Declared rooms: {b['declared_rooms']}; checkpointed: "
             f"{b['rooms_checkpointed']}; structured: {b['rooms_structured']}",
             f"- Structured decisions: {b['structured_decisions']} "
             f"(drift: {b['drift']})",
             f"- Lint readiness: {b['lint']['READY']} READY / "
             f"{b['lint']['NEEDS_ATTENTION']} needing attention",
             f"- Manual/runtime evidence debt: "
             f"{b['manual_runtime_evidence_debt']} decision(s)",
             f"- Floors with no reconstruction work: "
             f"{', '.join(b['floors_with_no_reconstruction_work']) or 'none'}"]
    if b["room_ids_referenced_but_not_declared"]:
        lines.append(f"- Referenced but undeclared room ids: "
                     f"{b['room_ids_referenced_but_not_declared']}")
    if b["decisions_with_unresolved_room_mapping"]:
        lines.append(f"- Decisions with unresolved room mapping: "
                     f"{b['decisions_with_unresolved_room_mapping']}")
    if b["checkpoints_resolving_to_no_declared_room"]:
        lines.append(f"- Checkpoints naming no declared room: "
                     f"{b['checkpoints_resolving_to_no_declared_room']}")
    lines += ["", "## Floors", "",
              "| Floor | Seq | Rooms | Profiled | Ckpt | Structured | "
              "SAT/OPEN/CON/UNV | Census cands | Manual debt | Regens |",
              "|---|---:|---:|---:|---:|---:|---|---:|---:|---:|"]
    for f in report["floors"]:
        d = f["decisions"]
        lines.append(
            f"| {f['floor']} | {f['plan_sequence_position'] or '-'} | "
            f"{f['rooms']} | {f['profiled']} | {f['checkpointed']} | "
            f"{f['structured']} | {d['SATISFIED']}/{d['OPEN']}/"
            f"{d['CONTRADICTED']}/{d['UNVERIFIABLE']} | "
            f"{f['rooms_with_census_candidates']} | "
            f"{f['rooms_needing_manual_or_runtime_evidence']} | "
            f"{f['max_layout_regenerations_since_checkpoint'] if f['max_layout_regenerations_since_checkpoint'] is not None else '-'} |")
    lines += ["", "## Rooms", ""]
    current_floor = None
    for r in report["rooms"]:
        if r["floor"] != current_floor:
            current_floor = r["floor"]
            lines += [f"### {current_floor}", "",
                      "| Room | Kind | States | Headline | Decisions "
                      "S/O/C/U | Lint R/N | Census |",
                      "|---|---|---|---|---|---|---:|"]
        d = r["decisions"]
        lines.append(
            f"| {r['room']} | {r['kind']} | "
            f"{', '.join(r['states'])} | {r['headline']} | "
            f"{d['SATISFIED']}/{d['OPEN']}/{d['CONTRADICTED']}/"
            f"{d['UNVERIFIABLE']} | {r['lint']['READY']}/"
            f"{r['lint']['NEEDS_ATTENTION']} | "
            f"{r['census_candidates']['total']} |")
    lines += ["", "## Next actions (evidence-only queue)", ""]
    if not report["next_actions"]:
        lines.append("- none: every declared room is structured, green and "
                     "lint-clean (manual evidence may still be pending)")
    for a in report["next_actions"][:60]:
        where = a["room"] or "(document)"
        lines.append(f"- [{a['rank']}] {where}: {a['action']} - {a['detail']} "
                     f"({a['ranking_source']})")
    if len(report["next_actions"]) > 60:
        lines.append(f"- ... {len(report['next_actions']) - 60} further "
                     "action(s) in the JSON ledger")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def exit_code_for(report):
    code = 0
    drift = report["building"]["drift"]
    if drift.get("CONTRADICTED") or any(r["conflicts"]
                                        for r in report["rooms"]):
        code |= 1
    if drift.get("MALFORMED"):
        code |= 4
    return code


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Read-only floor reconstruction progress ledger")
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--checkpoints", type=Path,
                        default=rc.DEFAULT_CHECKPOINTS)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--floor")
    parser.add_argument("--room")
    parser.add_argument("--json-only", action="store_true")
    parser.add_argument("--markdown-only", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--no-git", action="store_true",
                        help="skip git provenance (fully repository-state "
                             "independent output)")
    args = parser.parse_args(argv)

    args.output.mkdir(parents=True, exist_ok=True)
    targets = []
    if not args.markdown_only:
        targets.append(args.output / "room_reconstruction_progress.json")
    if not args.json_only:
        targets.append(args.output / "room_reconstruction_progress.md")
    try:
        wb.preflight_overwrite(targets, args.force)
    except FileExistsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 3

    try:
        sources = gather(args.layout, args.checkpoints,
                         use_git=not args.no_git)
        sources["layout_path"] = args.layout
        report = build_report(sources, floor_filter=args.floor,
                              room_filter=args.room)
    except Exception as exc:                # noqa: BLE001 - stable exit code
        print(f"internal failure: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 70

    for path in targets:
        if path.suffix == ".json":
            path.write_text(json.dumps(report, indent=1, sort_keys=True)
                            + "\n", encoding="utf-8")
        else:
            path.write_text(report_markdown(report), encoding="utf-8")
        print(path)
    code = exit_code_for(report)
    b = report["building"]
    print(f"rooms={b['declared_rooms']} checkpointed="
          f"{b['rooms_checkpointed']} drift={b['drift']} -> exit {code}",
          file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
