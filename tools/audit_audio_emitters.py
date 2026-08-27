#!/usr/bin/env python3
"""Static inventory of Orison audio construction and semantic migration debt."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path


DIRECT = re.compile(r"AudioStreamPlayer(?:2D|3D)?\.new\(\)")
DIRECT_BINDING = re.compile(
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?::=|=)\s*"
    r"AudioStreamPlayer(?:2D|3D)?\.new\(\)"
)
HELPER = re.compile(r'make_emitter\(\s*"([^"]+)"')
BUS = re.compile(r'\.bus\s*=\s*"([^"]+)"')
CUE = re.compile(
    r'(?:present_3d|observe_existing_3d)\(\s*&?"([^"]+)"'
)
REQUIRED_CUE_FIELDS = {
    "stream_key", "purpose", "bus", "priority", "volume_db", "unit_size",
    "max_distance", "cooldown", "max_instances", "caption", "graph_transmitted",
}
PURPOSE_BUSES = {
    "hazard": {"Hazard"},
    "interaction": {"Interaction"},
    "navigation": {"Navigation"},
    "state": {"State", "Machinery"},
    "telephone": {"Telephone"},
    "world": {"Architecture", "Weather"},
}
# Temporary ceilings, not targets.  These five keys currently teach unrelated
# mechanisms the same sound.  Migration may lower these numbers; new work may
# not raise them while pretending pitch variation creates a new vocabulary.
LEGACY_HELPER_BUDGETS = {
    "tick": 29,
    "knock": 14,
    "hum_loop": 9,
    "pop": 7,
    "creak": 5,
}


def audit(repo: Path) -> dict:
    scripts = repo / "game" / "scripts"
    rows = []
    keys: Counter[str] = Counter()
    buses: Counter[str] = Counter()
    semantic: Counter[str] = Counter()
    unclassified = []
    for path in sorted(scripts.rglob("*.gd")):
        text = path.read_text(encoding="utf-8", errors="replace")
        direct = len(DIRECT.findall(text))
        helper_keys = HELPER.findall(text)
        explicit_buses = BUS.findall(text)
        cue_ids = CUE.findall(text)
        keys.update(helper_keys)
        buses.update(explicit_buses)
        semantic.update(cue_ids)
        lines = text.splitlines()
        for line_number, line in enumerate(lines, 1):
            binding = DIRECT_BINDING.search(line)
            if binding is None:
                continue
            variable = binding.group("name")
            function_end = len(lines)
            for candidate in range(line_number, len(lines)):
                if lines[candidate].startswith("func "):
                    function_end = candidate
                    break
            body = "\n".join(lines[line_number:function_end])
            if re.search(rf"\b{re.escape(variable)}\.bus\s*=", body) is None:
                unclassified.append({
                    "path": path.relative_to(repo).as_posix(),
                    "line": line_number,
                    "variable": variable,
                })
        if direct or helper_keys or explicit_buses or cue_ids:
            rows.append({
                "path": path.relative_to(repo).as_posix(),
                "direct_players": direct,
                "helper_keys": helper_keys,
                "explicit_buses": explicit_buses,
                "semantic_cues": cue_ids,
            })
    catalog_path = repo / "game" / "data" / "audio_cues.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    catalog_cues = catalog.get("cues", {})
    catalog_ids = set(catalog_cues)
    unknown_semantic = sorted(set(semantic) - catalog_ids)
    helper_budget_excess = {
        key: {"actual": keys[key], "budget": budget}
        for key, budget in LEGACY_HELPER_BUDGETS.items()
        if keys[key] > budget
    }
    catalog_failures = []
    for cue_id, cue in catalog_cues.items():
        missing = sorted(REQUIRED_CUE_FIELDS - set(cue))
        if missing:
            catalog_failures.append(f"{cue_id}: missing {', '.join(missing)}")
            continue
        purpose = str(cue["purpose"])
        bus = str(cue["bus"])
        if purpose not in PURPOSE_BUSES or bus not in PURPOSE_BUSES[purpose]:
            catalog_failures.append(f"{cue_id}: purpose {purpose!r} cannot route to {bus!r}")
        if not str(cue["stream_key"]).strip() or not str(cue["caption"]).strip():
            catalog_failures.append(f"{cue_id}: stream_key and caption must be non-empty")
        if not 0 <= int(cue["priority"]) <= 100:
            catalog_failures.append(f"{cue_id}: priority is outside 0..100")
        if float(cue["unit_size"]) <= 0.0 or float(cue["max_distance"]) <= 0.0:
            catalog_failures.append(f"{cue_id}: distance profile must be positive")
        if float(cue["cooldown"]) < 0.0 or not 1 <= int(cue["max_instances"]) <= 16:
            catalog_failures.append(f"{cue_id}: cooldown or concurrency is invalid")
    return {
        "schema_version": 1,
        "files": rows,
        "summary": {
            "files_with_audio_construction": sum(
                bool(r["direct_players"] or r["helper_keys"]) for r in rows
            ),
            "direct_player_constructions": sum(r["direct_players"] for r in rows),
            "make_emitter_calls": sum(keys.values()),
            "literal_semantic_requests": sum(semantic.values()),
            "helper_key_counts": dict(keys.most_common()),
            "explicit_bus_counts": dict(buses.most_common()),
            "semantic_cue_counts": dict(semantic.most_common()),
            "unclassified_direct_players": len(unclassified),
            "unknown_literal_semantic_cues": len(unknown_semantic),
            "invalid_catalog_cues": len(catalog_failures),
            "legacy_helper_budget_excess": len(helper_budget_excess),
        },
        "unclassified_direct_sites": unclassified,
        "unknown_literal_semantic_cues": unknown_semantic,
        "catalog_failures": catalog_failures,
        "legacy_helper_budget_excess": helper_budget_excess,
    }


def markdown(report: dict) -> str:
    summary = report["summary"]
    lines = [
        "# Static audio-emitter audit",
        "",
        "Source inventory only; audibility and masking require a listening run.",
        "",
        f'- Files constructing audio: {summary["files_with_audio_construction"]}',
        f'- Direct player constructions: {summary["direct_player_constructions"]}',
        f'- Literal `make_emitter` calls: {summary["make_emitter_calls"]}',
        f'- Literal semantic requests: {summary["literal_semantic_requests"]}',
        f'- Direct players without a same-function bus assignment: '
        f'{summary["unclassified_direct_players"]}',
        f'- Literal semantic cue ids absent from the catalogue: '
        f'{summary["unknown_literal_semantic_cues"]}',
        f'- Catalogue contract failures: {summary["invalid_catalog_cues"]}',
        f'- Overloaded helper keys above their non-regression ceiling: '
        f'{summary["legacy_helper_budget_excess"]}',
        "",
        "## Reused helper keys",
        "",
    ]
    for key, count in summary["helper_key_counts"].items():
        lines.append(f"- `{key}`: {count}")
    if report["unclassified_direct_sites"]:
        lines.extend(["", "## Unclassified direct players", ""])
        for site in report["unclassified_direct_sites"]:
            lines.append(
                f'- `{site["path"]}:{site["line"]}` — `{site["variable"]}`'
            )
    lines.extend(["", "## Files", "", "| File | Direct | Helper | Semantic |", "| --- | ---: | ---: | ---: |"])
    for row in report["files"]:
        lines.append(
            f'| `{row["path"]}` | {row["direct_players"]} | '
            f'{len(row["helper_keys"])} | {len(row["semantic_cues"])} |'
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--check", action="store_true",
        help="fail when a direct player lacks a bus or a literal cue is unknown",
    )
    parser.add_argument("--quiet", action="store_true", help="print only the check verdict")
    args = parser.parse_args()
    report = audit(args.repo.resolve())
    rendered = json.dumps(report, indent=2) + "\n" if args.format == "json" else markdown(report)
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    elif not args.quiet:
        print(rendered, end="")
    if args.check:
        failures = (
            report["summary"]["unclassified_direct_players"]
            + report["summary"]["unknown_literal_semantic_cues"]
            + report["summary"]["invalid_catalog_cues"]
            + report["summary"]["legacy_helper_budget_excess"]
        )
        if failures:
            print(f"AUDIO EMITTER AUDIT: FAIL ({failures})")
            return 1
        print(
            "AUDIO EMITTER AUDIT: PASS "
            f"({report['summary']['direct_player_constructions']} direct players; "
            f"{report['summary']['literal_semantic_requests']} literal semantic requests)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
