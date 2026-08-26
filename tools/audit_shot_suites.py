#!/usr/bin/env python3
"""Inventory Orison screenshot suites without launching Godot.

The report is deliberately static: it identifies migration candidates and
capture hazards, but never edits a scene or treats source shape as runtime
proof. JSON output makes the same inventory usable by milestone tooling.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path


SHOT_PATTERN = "*_shot.gd"


@dataclass(frozen=True)
class Suite:
    path: str
    harness: bool
    reads_shot_dir: bool
    saves_png: bool
    checks_save_result: bool
    has_result_line: bool
    frame_waits: int
    timer_waits: int
    direct_godot_example: bool
    fallback_output: bool
    likely_production_root: bool
    risks: tuple[str, ...]


def _suite(repo: Path, path: Path) -> Suite:
    text = path.read_text(encoding="utf-8", errors="replace")
    lower = text.lower()
    saves_png = "save_png" in text
    checks_save = bool(re.search(
        r"(?:var\s+\w+\s*:?=\s*[^\n]*save_png|save_png\([^\n]*\)\s*==\s*OK)",
        text,
    ))
    direct_example = bool(re.search(
        r"(?im)^\s*(?:#|##).*\bgodot(?:\.exe)?\s+--path\b", text
    ))
    fallback = "user://" in lower or bool(re.search(
        r"SHOT_DIR[^\n]{0,120}(?:if|else)[^\n]{0,120}(?:/tmp|user://)", text,
        re.IGNORECASE,
    ))
    harness = "shot_harness.gd" in lower or "ShotHarness" in text
    risks: list[str] = []
    if not harness:
        risks.append("legacy_no_harness")
    if saves_png and not checks_save:
        risks.append("unchecked_save")
    if "SHOT_DIR" not in text:
        risks.append("undeclared_output")
    if direct_example:
        risks.append("direct_godot_example")
    if fallback:
        risks.append("fallback_output")
    if "RESULT:" not in text and not harness:
        risks.append("no_result_contract")
    if text.count("process_frame") >= 8:
        risks.append("high_frame_wait_count")
    return Suite(
        path=path.relative_to(repo).as_posix(),
        harness=harness,
        reads_shot_dir="SHOT_DIR" in text,
        saves_png=saves_png,
        checks_save_result=checks_save,
        has_result_line="RESULT:" in text or harness,
        frame_waits=text.count("process_frame"),
        timer_waits=text.count("create_timer"),
        direct_godot_example=direct_example,
        fallback_output=fallback,
        likely_production_root="orison_root.tscn" in lower,
        risks=tuple(risks),
    )


def _markdown(suites: list[Suite]) -> str:
    risk_counts: dict[str, int] = {}
    for suite in suites:
        for risk in suite.risks:
            risk_counts[risk] = risk_counts.get(risk, 0) + 1
    migrated = sum(s.harness for s in suites)
    lines = [
        "# Screenshot suite static audit",
        "",
        "Static source inventory only; this is not runtime or visual proof.",
        "",
        f"- Suites: {len(suites)}",
        f"- ShotHarness adopters: {migrated}",
        f"- Legacy suites: {len(suites) - migrated}",
        f"- Likely full-production suites: {sum(s.likely_production_root for s in suites)}",
        "",
        "## Risk counts",
        "",
    ]
    for name, count in sorted(risk_counts.items(), key=lambda item: (-item[1], item[0])):
        lines.append(f"- `{name}`: {count}")
    lines.extend([
        "",
        "## Migration candidates",
        "",
        "| Suite | Production | Frame waits | Risks |",
        "| --- | ---: | ---: | --- |",
    ])
    ranked = sorted(
        (s for s in suites if s.risks),
        key=lambda s: (-len(s.risks), -int(s.likely_production_root), s.path),
    )
    for suite in ranked:
        risks = ", ".join(f"`{risk}`" for risk in suite.risks)
        lines.append(
            f"| `{suite.path}` | {'yes' if suite.likely_production_root else 'no'} "
            f"| {suite.frame_waits} | {risks} |"
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    tests = repo / "game" / "tests"
    suites = [_suite(repo, path) for path in sorted(tests.glob(SHOT_PATTERN))]
    if args.format == "json":
        rendered = json.dumps(
            {"schema_version": 1, "suite_count": len(suites),
             "suites": [asdict(s) for s in suites]}, indent=2
        ) + "\n"
    else:
        rendered = _markdown(suites)
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
