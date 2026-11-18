"""Which Godot test scenes are alive, what do they cost, and how fast does the world start?

Reads the run receipts the runners write (`<log>.receipt.json`, schema
orison.run-receipt.v1) under a reports root and every scene in game/tests, and
writes census.json and census.md:

- per scene: runs, total and median lane seconds, timeouts, how the last run
  ended, and the days since it last ran (or that it never has);
- the scenes that cost the most lane time;
- world startup: the `[ORISON V2 RUNTIME] ready startup_ms=` line from each
  run's own log, by week, so a startup regression shows as a step.

It reads only; it runs nothing and changes nothing. A receipt proves a process
ran and how it ended, not that a test passed its contract (RUL-003).

    python tools/test_census.py [--reports C:/ov/reports] [--out DIR] [--json]
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import statistics
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
STARTUP = re.compile(rb"\[ORISON V2 RUNTIME\] ready startup_ms=([0-9.]+)")
KINDS = ("Shots", "Shot", "Capture", "Review", "Bench", "Profile", "Survey", "Preview",
         "Diagnostic", "Probe", "Test", "Route", "World", "Matrix", "Contract")


def kind_of(scene: str) -> str:
    stem = scene.rsplit("/", 1)[-1].removesuffix(".tscn")
    for kind in KINDS:
        if stem.endswith(kind):
            return kind.removesuffix("s") if kind == "Shots" else kind
    return "other"


def read_receipts(reports: pathlib.Path) -> list[dict]:
    runs = []
    for path in reports.rglob("*.receipt.json"):
        try:
            receipt = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if receipt.get("schema") != "orison.run-receipt.v1" or not receipt.get("scene"):
            continue
        execution = receipt.get("execution") or {}
        log = receipt.get("log") or {}
        runs.append({
            "scene": str(receipt["scene"]),
            "started": str(execution.get("started_utc") or ""),
            "elapsed_s": float(execution.get("elapsed_s") or 0.0),
            "timed_out": bool(execution.get("timed_out")),
            "exit_code": execution.get("exit_code"),
            "fail_count": int(log.get("fail_count") or 0),
            "script_errors": int(log.get("script_error_count") or 0),
            "stdout": str(log.get("stdout") or ""),
        })
    return runs


def startup_ms(stdout: str) -> float | None:
    """The world's own startup report in a run's log, if it composed one."""
    try:
        with open(stdout, "rb") as handle:
            head = handle.read(1 << 20)
    except OSError:
        return None
    match = STARTUP.search(head)
    return float(match.group(1)) if match else None


def outcome(run: dict) -> str:
    if run["timed_out"]:
        return "timeout"
    if run["exit_code"] is None:
        return "no-exit"
    if run["exit_code"] == 0 and run["fail_count"] == 0 and run["script_errors"] == 0:
        return "exit-0"
    return "failed"


def census(root: pathlib.Path, reports: pathlib.Path, today: dt.date) -> dict:
    scenes = sorted("res://tests/" + p.name for p in (root / "game" / "tests").glob("*.tscn"))
    runs = read_receipts(reports)
    by_scene: dict[str, list[dict]] = {}
    for run in runs:
        by_scene.setdefault(run["scene"], []).append(run)
    rows = []
    for scene in sorted(set(scenes) | set(by_scene)):
        history = sorted(by_scene.get(scene, []), key=lambda r: r["started"])
        last = history[-1] if history else None
        last_day = dt.date.fromisoformat(last["started"][:10]) if last and last["started"] else None
        rows.append({
            "scene": scene,
            "kind": kind_of(scene),
            "in_tree": scene in scenes,
            "runs": len(history),
            "lane_s": round(sum(r["elapsed_s"] for r in history), 1),
            "median_s": round(statistics.median(r["elapsed_s"] for r in history), 1) if history else None,
            "timeouts": sum(r["timed_out"] for r in history),
            "last_run": last["started"] if last else None,
            "last_outcome": outcome(last) if last else "never",
            "idle_days": (today - last_day).days if last_day else None,
        })
    weekly: dict[str, list[float]] = {}
    for run in runs:
        if not run["started"]:
            continue
        ms = startup_ms(run["stdout"])
        if ms is None:
            continue
        day = dt.date.fromisoformat(run["started"][:10])
        week = (day - dt.timedelta(days=day.weekday())).isoformat()
        weekly.setdefault(week, []).append(ms)
    in_tree = [r for r in rows if r["in_tree"]]
    kinds: dict[str, dict] = {}
    for row in in_tree:
        entry = kinds.setdefault(row["kind"], {"scenes": 0, "ever_run": 0})
        entry["scenes"] += 1
        entry["ever_run"] += row["runs"] > 0
    first = min((r["started"] for r in runs if r["started"]), default=None)
    return {
        "schema": "orison.test-census.v1",
        "generated": today.isoformat(),
        "reports_root": str(reports),
        "receipts_since": first[:10] if first else None,
        "totals": {
            "scenes": len(in_tree),
            "ever_run": sum(r["runs"] > 0 for r in in_tree),
            "never_run": sum(r["runs"] == 0 for r in in_tree),
            "runs": len(runs),
            "lane_hours": round(sum(r["elapsed_s"] for r in runs) / 3600, 1),
            "receipts_for_removed_scenes": sum(1 for r in rows if not r["in_tree"]),
        },
        "kinds": dict(sorted(kinds.items(), key=lambda kv: -kv[1]["scenes"])),
        "startup_by_week": {week: {"runs": len(values), "median_ms": round(statistics.median(values)),
                                   "min_ms": round(min(values))}
                            for week, values in sorted(weekly.items())},
        "scenes": rows,
    }


def markdown(board: dict, top: int = 25) -> str:
    totals = board["totals"]
    lines = [
        f"# Test census {board['generated']}",
        "",
        f"Receipts since {board['receipts_since']}: {totals['runs']} runs, {totals['lane_hours']} lane hours.",
        f"{totals['scenes']} test scenes in the tree; {totals['ever_run']} ran at least once, "
        f"{totals['never_run']} never did.",
        "",
        "## By kind",
        "",
        "| kind | scenes | ever run |",
        "| --- | ---: | ---: |",
    ]
    lines += [f"| {k} | {v['scenes']} | {v['ever_run']} |" for k, v in board["kinds"].items()]
    lines += ["", "## Most lane time", "", "| scene | runs | median s | lane h | last |",
              "| --- | ---: | ---: | ---: | --- |"]
    costly = sorted(board["scenes"], key=lambda r: -r["lane_s"])[:top]
    lines += [f"| {r['scene'].removeprefix('res://tests/')} | {r['runs']} | {r['median_s']} | "
              f"{r['lane_s'] / 3600:.1f} | {r['last_outcome']} |" for r in costly]
    lines += ["", "## World startup by week", "", "| week of | runs | median s | fastest s |",
              "| --- | ---: | ---: | ---: |"]
    lines += [f"| {w} | {v['runs']} | {v['median_ms'] / 1000:.1f} | {v['min_ms'] / 1000:.1f} |"
              for w, v in board["startup_by_week"].items()]
    return "\n".join(lines) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=str(ROOT))
    parser.add_argument("--reports", default="C:/ov/reports")
    parser.add_argument("--out", help="directory for census.json and census.md")
    parser.add_argument("--today", help="YYYY-MM-DD; defaults to today (for reproducible output)")
    parser.add_argument("--json", action="store_true", help="print the census JSON")
    args = parser.parse_args(argv)
    today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
    board = census(pathlib.Path(args.root), pathlib.Path(args.reports), today)
    if args.out:
        out = pathlib.Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        (out / "census.json").write_text(json.dumps(board, indent=1), encoding="utf-8")
        (out / "census.md").write_text(markdown(board), encoding="utf-8")
    if args.json:
        json.dump(board, sys.stdout, indent=1)
    else:
        sys.stdout.write(markdown(board, top=15))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
