"""Reproduce the two harness-owned fresh-profile directory repairs once."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
OUT = Path(__file__).resolve().parent
PWSH = r"C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe"
RUNNER = ROOT / "tools/run_godot_serial.ps1"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.DEVNULL)


def source_snapshot(label):
    diff = git("diff", "--binary", "HEAD", "--", "game", "tools")
    (OUT / (label + ".game_tools.diff")).write_bytes(diff)
    changed = git("diff", "--name-only", "HEAD", "--", "game", "tools").decode().splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard", "game", "tools").decode().splitlines()
    files = []
    for rel in sorted(set(changed + untracked)):
        path = ROOT / rel
        if path.is_file():
            data = path.read_bytes()
            files.append({"path": rel, "bytes": len(data), "sha256": sha(data)})
    return {"head": git("rev-parse", "HEAD").decode().strip(), "diff_sha256": sha(diff),
            "diff_path": label + ".game_tools.diff", "changed_or_untracked_files": files}


receipt_path = OUT / "receipt.json"
assert not receipt_path.exists(), "Do not overwrite completed evidence"
receipt = {
    "schema": "astra.harness_directory_repair.v1", "started_at_utc": utc(),
    "scope": "Harness-owned fresh-profile save-directory creation only; no new whole-route, visual, performance, or audio-lifecycle acceptance.",
    "context": {"engine": "Godot 4.7.1 stable", "mode": "headless", "gpu": "RTX 4080", "cpu": "i7-13700KF", "elapsed_meaning": "wall-clock process duration only"},
    "red_controls": [
        {"receipt": "../base_runtime/receipt.json", "suite": "M08F first fresh-profile run", "exit": 1, "checks": "28/29", "cause": "missing user://tests parent"},
        {"receipt": "../m11b_runtime/receipt.json", "suite": "M11A first fresh-profile run", "exit": 3, "checks": "37/40", "cause": "missing user://tests parent"}
    ],
    "runner_sha256": sha(RUNNER.read_bytes()), "runs": [], "source_before": source_snapshot("source_before")
}

for name, scene in [
    ("m08f", "res://tests/orison_v2_m08f_runtime_test.tscn"),
    ("m11a", "res://tests/OrisonV2M11AFirstExteriorCellTest.tscn")
]:
    profile = OUT / "userdata" / name
    assert not profile.exists(), "Fresh profile must not already exist"
    profile.mkdir(parents=True)
    tests_dir = profile / "PleaseRemainOnTheLine" / "tests"
    assert not tests_dir.exists(), "Do not supply harness-owned test directory"
    env = os.environ.copy()
    env["APPDATA"] = str(profile)
    env.pop("ORISON_BUILDING_ROOT", None)
    env.pop("SHOT_DIR", None)
    env["M11A_OBJECTIVE_RECEIPT"] = str(OUT / (name + ".objective_receipt.json"))
    log = OUT / (name + ".stdout.log")
    cmd = [PWSH, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(RUNNER),
           "-Scene", scene, "-ProjectPath", str(ROOT / "game"), "-LogPath", str(log), "-TimeoutSeconds", "60"]
    started = utc()
    before = time.perf_counter()
    proc = subprocess.run(cmd, cwd=ROOT, env=env, capture_output=True)
    elapsed = time.perf_counter() - before
    (OUT / (name + ".runner.stdout.log")).write_bytes(proc.stdout)
    (OUT / (name + ".runner.stderr.log")).write_bytes(proc.stderr)
    stdout = log.read_text(encoding="utf-8-sig", errors="replace") if log.exists() else ""
    errpath = Path(str(log) + ".stderr")
    stderr = errpath.read_text(encoding="utf-8-sig", errors="replace") if errpath.exists() else ""
    diagnostics = [line for line in (stdout + "\n" + stderr).splitlines()
                   if re.search(r"WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use", line, re.I)]
    summaries = [line for line in stdout.splitlines() if re.search(r"PASS|FAIL|checks|summary", line, re.I)]
    run = {"suite": name, "scene": scene, "command": cmd, "started_at_utc": started,
           "finished_at_utc": utc(), "elapsed_seconds": round(elapsed, 3), "runner_exit": proc.returncode,
           "APPDATA": str(profile), "test_directory_existed_before": False,
           "test_directory_exists_after": tests_dir.is_dir(),
           "test_directory_files_after": [str(p.relative_to(profile)) for p in tests_dir.rglob("*") if p.is_file()] if tests_dir.is_dir() else [],
           "diagnostic_lines": diagnostics, "summary_lines": summaries,
           "stdout_path": log.name, "stderr_path": errpath.name,
           "warning_interpretation": "M08F existing project-associated audio retention remains unresolved; any warnings are preserved and are not an approved engine baseline." if name == "m08f" else "No waiver; inspect retained raw logs."}
    receipt["runs"].append(run)
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: run[k] for k in ["suite", "runner_exit", "elapsed_seconds", "test_directory_exists_after", "diagnostic_lines"]}), flush=True)
    if proc.returncode in (73, 78, 124):
        break

receipt["source_after"] = source_snapshot("source_after")
receipt["source_unchanged_during_runs"] = receipt["source_before"]["head"] == receipt["source_after"]["head"] and receipt["source_before"]["diff_sha256"] == receipt["source_after"]["diff_sha256"] and receipt["source_before"]["changed_or_untracked_files"] == receipt["source_after"]["changed_or_untracked_files"]
receipt["finished_at_utc"] = utc()
receipt["directory_repair_verdict"] = "PASS" if len(receipt["runs"]) == 2 and all(r["runner_exit"] == 0 and r["test_directory_exists_after"] for r in receipt["runs"]) else "FAIL_OR_INCOMPLETE"
receipt["artifact_hashes"] = [{"path": str(p.relative_to(OUT)), "sha256": sha(p.read_bytes()), "bytes": p.stat().st_size}
                              for p in OUT.iterdir() if p.is_file() and p != receipt_path]
receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print("FINAL", receipt["directory_repair_verdict"], "source unchanged:", receipt["source_unchanged_during_runs"], flush=True)
