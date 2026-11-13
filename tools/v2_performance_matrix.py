#!/usr/bin/env python3
"""The V2 performance matrix: admit a measurement, and check the receipt.

game/tests/V2PerformanceMatrix.tscn measures startup, frame time, draw calls
and memory at named stations of the composed V2 world and writes
performance_matrix.json into its shot folder. That file judges nothing.

    --admit SAMPLES --run-receipt RECEIPT --checkout DIR
        Check the samples, bind them to the commit and the lane run that made
        them, examine the measured checkout for changed or untracked game
        files, judge against the budgets below and write the receipt at
        art/renders/orison_v2/performance_matrix/performance_matrix.json.
    --check [--json]
        What the gate board runs: read the committed receipt and judge it
        again. Exit 0 within budget, 1 over budget or invalid, 2 no receipt.

The receipt is a measurement of one commit on one machine, at one resolution.
It is not bound to source hashes: performance evidence that expired with
every edit would be renewed blindly. The receipt names its commit, and the
check reports it, so a reader can see how old the measurement is.

Run the measurement through the lane, windowed (hidden desktop), for example:

    pwsh -File tools/lane.ps1 run -Scene res://tests/V2PerformanceMatrix.tscn `
        -Runner long -Windowed -ShotDir <dir> -LogPath <dir>/matrix.log
    python tools/v2_performance_matrix.py --admit <dir>/performance_matrix.json `
        --run-receipt <dir>/matrix.log.receipt.json --checkout <measured checkout>
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECEIPT = ROOT / "art/renders/orison_v2/performance_matrix/performance_matrix.json"
SAMPLES_SCHEMA = "orison.v2-performance-samples.v1"
RECEIPT_SCHEMA = "orison.v2-performance-matrix.v1"

# The stations a receipt must cover. The test's own table may grow; a receipt
# that drops one of these is not the matrix.
REQUIRED_STATIONS = (
    "street_arrival", "lobby", "main_stair_first_flight", "second_floor_landing",
    "third_floor_crossing", "fourth_floor_service_hall", "flat_4b_desk",
    "sixth_floor_landing", "roof_deck", "basement_landing", "passage_nave",
)

# Budgets. A budget with "blocking" false is reported and never fails the
# gate: it marks a number nobody has ruled on yet.
BUDGETS = {
    "frame_ms_median": {
        "limit": 16.6, "blocking": True,
        "source": "the retired release matrix's FRAME_BUDGET_MS (60 frames a second), "
                  "applied to each station's worst heading"},
    "frame_ms_p95": {
        "limit": 33.3, "blocking": False,
        "source": "two frames at 60 a second; recorded, not ruled"},
    "startup_ms": {
        "limit": None, "blocking": False,
        "source": "no startup budget has been ruled; the number is recorded"},
    "video_bytes": {
        "limit": None, "blocking": False,
        "source": "no memory budget has been ruled; the number is recorded"},
}


def _shown(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _machine() -> dict:
    """Hardware class only. No computer or account name: the repo is public."""
    info = {"os": platform.system() + " " + platform.release(), "cpu": platform.processor()}
    try:
        out = subprocess.run(
            ["powershell", "-NoProfile", "-Command",
             "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"],
            capture_output=True, text=True, timeout=30).stdout.strip()
        if out.isdigit():
            info["memory_bytes"] = int(out) * 1024
    except (OSError, subprocess.SubprocessError):
        pass
    return info


def judge(samples: dict) -> dict:
    """Budgets against samples. Pure: the gate and --admit agree by sharing it."""
    defects: list[str] = []
    notes: list[str] = []
    if samples.get("schema") != SAMPLES_SCHEMA:
        defects.append("samples schema is %r, not %s" % (samples.get("schema"), SAMPLES_SCHEMA))
        return {"defects": defects, "notes": notes, "rows": [], "worst": {}}
    if samples.get("display_server") == "headless":
        defects.append("measured headless: no frame was drawn")
    if samples.get("vsync") is not False:
        defects.append("vsync was on: frame times are the display's, not the game's")
    for line in samples.get("failures", []):
        defects.append("test failure: " + str(line))
    stations = {str(row.get("name")): row for row in samples.get("stations", [])}
    for name in REQUIRED_STATIONS:
        if name not in stations:
            defects.append("station missing: " + name)
    rows = []
    worst = {"frame_ms_median": 0.0, "frame_ms_p95": 0.0, "draw_calls": 0, "video_bytes": 0}
    frame = BUDGETS["frame_ms_median"]
    tail = BUDGETS["frame_ms_p95"]
    for name, row in stations.items():
        if not row.get("valid"):
            defects.append("station invalid: %s (%s)" % (name, row.get("why", "streaming did not settle")))
            continue
        heading = row.get("worst_heading", {})
        if int(heading.get("frames", 0)) < 60:
            defects.append("station %s has %d frames; too few to judge" % (name, int(heading.get("frames", 0))))
            continue
        if float(row.get("drift_m", 0.0)) > 1.5:
            defects.append("station %s: the player ended %.2f m from the station" % (name, float(row["drift_m"])))
        median = float(heading.get("wall_ms_median", 0.0))
        p95 = float(heading.get("wall_ms_p95", 0.0))
        video = int(row.get("memory", {}).get("video_bytes", 0))
        over = median > frame["limit"]
        if over:
            defects.append("over budget: %s %.2f ms median (budget %.1f)" % (name, median, frame["limit"]))
        if p95 > tail["limit"]:
            notes.append("%s p95 %.2f ms (unruled mark %.1f)" % (name, p95, tail["limit"]))
        rows.append({"station": name, "room": row.get("room", ""),
                     "frame_ms_median": median, "frame_ms_p95": p95,
                     "render_gpu_ms": float(heading.get("render_gpu_ms_median", 0.0)),
                     "render_cpu_ms": float(heading.get("render_cpu_ms_median", 0.0)),
                     "draw_calls": int(heading.get("draw_calls", 0)),
                     "primitives": int(heading.get("primitives", 0)),
                     "video_bytes": video, "over_budget": over})
        worst["frame_ms_median"] = max(worst["frame_ms_median"], median)
        worst["frame_ms_p95"] = max(worst["frame_ms_p95"], p95)
        worst["draw_calls"] = max(worst["draw_calls"], int(heading.get("draw_calls", 0)))
        worst["video_bytes"] = max(worst["video_bytes"], video)
    startup = samples.get("startup", {})
    if float(startup.get("startup_ms", 0.0)) <= 0.0:
        defects.append("startup time missing")
    return {"defects": defects, "notes": notes, "rows": rows, "worst": worst}


def _run_facts(run: dict) -> dict:
    """What the lane's run receipt says about the run and the checkout it ran in."""
    execution = run.get("execution", {})
    source = run.get("source", {})
    return {"scene": run.get("scene"), "runner": run.get("runner"),
            "windowed": run.get("windowed"),
            "exit_code": execution.get("exit_code"), "completed": execution.get("completed"),
            "timed_out": execution.get("timed_out"), "elapsed_s": execution.get("elapsed_s"),
            "commit": source.get("repository_head"), "tree": source.get("repository_tree"),
            "status_lines": source.get("dirty_paths"),
            "test_sha256": source.get("test_sha256"),
            "runtime_inputs_sha256": source.get("runtime_inputs_sha256")}


def _run_defects(facts: dict) -> list[str]:
    defects = []
    if facts.get("scene") != "res://tests/V2PerformanceMatrix.tscn":
        defects.append("the run receipt is for %r" % facts.get("scene"))
    if facts.get("exit_code") != 0 or not facts.get("completed") or facts.get("timed_out"):
        defects.append("the lane run did not complete cleanly (exit %r)" % facts.get("exit_code"))
    return defects


def _git_in(checkout: Path, *args: str) -> list[str]:
    out = subprocess.run(["git", "-C", str(checkout), *args], capture_output=True,
                         text=True, check=True).stdout
    return [line for line in out.splitlines() if line.strip()]


def checkout_facts(checkout: Path) -> dict:
    """Is the measured checkout its commit? The lane's own count cannot say:
    it includes untracked scratch and the line-ending-only rewrites Godot makes
    to .import files on import. Content changes and untracked game files can
    change what was measured; those are what is held to zero."""
    return {
        "head": "".join(_git_in(checkout, "rev-parse", "HEAD")),
        "content_changed": _git_in(checkout, "diff", "--ignore-cr-at-eol", "--name-only", "HEAD"),
        "untracked_game_paths": [line[3:] for line in _git_in(
            checkout, "status", "--porcelain", "--untracked-files=all", "--", "game")
            if line.startswith("??")],
    }


def _checkout_defects(checkout: dict | None, commit: str | None) -> list[str]:
    if not checkout:
        return ["the measured checkout was not examined (--checkout)"]
    defects = []
    if checkout.get("head") != commit:
        defects.append("the checkout is at %s, the run was at %s" % (checkout.get("head"), commit))
    if checkout.get("content_changed"):
        defects.append("measured with %d changed tracked files" % len(checkout["content_changed"]))
    if checkout.get("untracked_game_paths"):
        defects.append("measured with %d untracked game files" % len(checkout["untracked_game_paths"]))
    return defects


def admit(samples_path: Path, run_receipt_path: Path, out: Path, checkout: Path | None = None) -> int:
    samples = json.loads(samples_path.read_text(encoding="utf-8"))
    run = json.loads(run_receipt_path.read_text(encoding="utf-8-sig"))
    facts = _run_facts(run)
    verdict = judge(samples)
    examined = checkout_facts(checkout) if checkout else None
    problems = (list(verdict["defects"]) + _run_defects(facts)
                + _checkout_defects(examined, facts.get("commit")))
    receipt = {
        "schema": RECEIPT_SCHEMA,
        "evidence_class": "MEASUREMENT",
        "about": "One measurement of one commit on one machine. Not bound to source hashes; "
                 "read the commit and the date before leaning on it.",
        "captured_utc": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "commit": facts["commit"],
        "tree": facts["tree"],
        "machine": _machine(),
        "run": facts,
        "checkout": examined,
        "samples_sha256": _sha256(samples_path),
        "budgets": BUDGETS,
        "result": "PASS" if not problems else "FAIL",
        "defects": problems,
        "notes": verdict["notes"],
        "summary": verdict["rows"],
        "worst": verdict["worst"],
        "samples": samples,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(receipt, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("V2 PERFORMANCE MATRIX %s: %d stations, %d defects -> %s" % (
        receipt["result"], len(verdict["rows"]), len(problems), _shown(out)))
    for line in problems:
        print("  " + line)
    return 0 if not problems else 1


def check(path: Path, as_json: bool) -> int:
    if not path.is_file():
        report = {"counts": {"stations": 0, "over_budget": 0, "defects": 1},
                  "defects": ["no receipt: " + _shown(path)],
                  "info": {}}
        code = 2
    else:
        receipt = json.loads(path.read_text(encoding="utf-8"))
        defects = []
        if receipt.get("schema") != RECEIPT_SCHEMA:
            defects.append("receipt schema is %r" % receipt.get("schema"))
        verdict = judge(receipt.get("samples", {}))
        defects += verdict["defects"] + _run_defects(receipt.get("run", {}))
        defects += _checkout_defects(receipt.get("checkout"), receipt.get("commit"))
        startup = receipt.get("samples", {}).get("startup", {})
        report = {
            "counts": {"stations": len(verdict["rows"]),
                       "over_budget": sum(1 for row in verdict["rows"] if row["over_budget"]),
                       "defects": len(defects)},
            "defects": defects,
            "info": {"commit": receipt.get("commit"), "captured_utc": receipt.get("captured_utc"),
                     "resolution": receipt.get("samples", {}).get("resolution"),
                     "startup_ms": startup.get("startup_ms"),
                     "worst": verdict["worst"], "notes": verdict["notes"]},
        }
        code = 0 if not defects else 1
    if as_json:
        print(json.dumps(report, indent=1))
    else:
        print("v2 performance matrix: %s" % ("within budget" if code == 0 else
                                             "no receipt" if code == 2 else "defects"))
        for line in report["defects"]:
            print("  " + line)
        for key, value in report["info"].items():
            print("  %s: %s" % (key, value))
    return code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--admit", type=Path)
    parser.add_argument("--run-receipt", type=Path)
    parser.add_argument("--checkout", type=Path,
                        help="the checkout the lane measured; examined for changed and untracked game files")
    parser.add_argument("--out", type=Path, default=RECEIPT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.admit:
        if not args.run_receipt:
            parser.error("--admit needs --run-receipt (the lane's <log>.receipt.json)")
        return admit(args.admit, args.run_receipt, args.out, args.checkout)
    return check(args.out, args.json)


if __name__ == "__main__":
    sys.exit(main())
