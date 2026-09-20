#!/usr/bin/env python3
"""Capture exact audit exits; never update baselines or rewrite old receipts."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


AUDITS = ["orison_v2_completeness", "orison_spatial_dependencies", "systemic_situation_authority",
          "data_consumption", "interaction_prompt_carriers", "interaction_implementors", "audio_emitters"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    dest = args.out.resolve()
    dest.mkdir(parents=True, exist_ok=False)
    tasks = []
    for name in AUDITS:
        flags = ["--format", "json", "--check"] if name == "audio_emitters" else ["--json"]
        tasks.append((name, [sys.executable, "tools/audit_" + name + ".py", *flags]))
        test = root / "tools/tests" / ("test_" + name + ".py")
        if test.exists():
            tasks.append((name + "_selftest", [sys.executable, str(test), "-v"]))

    def run(item):
        name, argv = item
        start = time.perf_counter()
        proc = subprocess.run(argv, cwd=root, capture_output=True,
                              env={**os.environ, "PYTHONIOENCODING": "utf-8"})
        stdout = dest / (name + ".stdout.txt")
        stderr = dest / (name + ".stderr.txt")
        stdout.write_bytes(proc.stdout)
        stderr.write_bytes(proc.stderr)
        return {"id": name, "argv": argv, "exit_code": proc.returncode,
                "elapsed_seconds": round(time.perf_counter() - start, 3),
                "stdout": stdout.name, "stderr": stderr.name,
                "stdout_sha256": hashlib.sha256(proc.stdout).hexdigest(),
                "stderr_sha256": hashlib.sha256(proc.stderr).hexdigest()}

    with ThreadPoolExecutor(max_workers=4) as pool:
        runs = list(pool.map(run, tasks))
    receipt = {"schema_version": 1, "repository_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
               "scope": "Static audits and their existing fixtures, not runtime or human proof.",
               "runs": sorted(runs, key=lambda r: r["id"]),
               "missing_selftests": [name for name in AUDITS if not (root / "tools/tests" / ("test_" + name + ".py")).exists()], "baseline_updates": False}
    (dest / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    for run in runs:
        print(f"{run['id']}: exit {run['exit_code']}, {run['elapsed_seconds']}s")
    # This orchestration process is successful when evidence is captured. The
    # child verdicts above remain authoritative, including intentional exit 2.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
