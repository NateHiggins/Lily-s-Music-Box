"""One fresh-profile, windowed actual-game smoke through the unchanged runner.

Full tracked/nonignored game bytes are hashed before/after, in addition to the
canonical runtime-text digest. Native process exit and log-aware gate stay apart.
"""
from __future__ import annotations
import argparse
from collections import Counter
import ctypes
from ctypes import wintypes
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from haunt_control import clean_environment

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
BASE = ROOT / "design/astra/evidence/resident_f01_haunt"
RUNNER = ROOT / "tools/run_godot_serial.ps1"
PARSER_PATH = ROOT / "design/astra/work/vulkan_pairing/run_case.py"
spec = importlib.util.spec_from_file_location("recorded_pairing_parser", PARSER_PATH)
parser_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(parser_module)
PWSH = parser_module.PWSH
MODES = {"lift": ("res://tests/ResidentF01HauntTest.tscn", "game/tests/resident_f01_haunt_test.gd")}
COPIES = ["game/scripts/building/building_root.gd", "game/scripts/characters/resident_routines.gd",
          "game/scripts/characters/resident_nav.gd", "game/scripts/building/elevator.gd",
          "game/tests/ResidentF01HauntTest.tscn", "game/tests/resident_f01_haunt_test.gd"]


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def digest(rows: list) -> str:
    return hashlib.sha256(json.dumps(rows, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()


def dump(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def utc() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def snapshot(out: Path, label: str) -> dict:
    paths = sorted(set(p for p in git("ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "game").decode().split("\0") if p))
    all_files = [[relative, sha(ROOT / relative)] for relative in paths if (ROOT / relative).is_file()]
    runtime = sorted([relative, fingerprint] for relative, fingerprint in all_files
        if relative == "game/project.godot"
        or (relative.startswith("game/scripts/") and relative.endswith(".gd"))
        or (relative.startswith("game/scenes/") and relative.endswith((".tscn", ".tres")))
        or (relative.startswith("game/data/") and relative.endswith(".json")))
    dump(out / f"{label}.all_game_files.json", all_files)
    dump(out / f"{label}.runtime_inputs.json", runtime)
    diff = git("diff", "--binary", "HEAD", "--", "game")
    (out / f"{label}.game.diff").write_bytes(diff)
    for relative in COPIES:
        target = out / label / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)
    return {"head_observed": git("rev-parse", "HEAD").decode().strip(),
            "all_game_files_count": len(all_files), "all_game_files_sha256": digest(all_files),
            "runtime_inputs_count": len(runtime), "runtime_inputs_sha256": digest(runtime),
            "digest_encoding": "compact JSON sorted [relative_posix_path, raw_file_sha256] pairs, no newline",
            "asset_scope": "All tracked and nonignored game file bytes included in all_game_files digest; imported .godot cache excluded.",
            "runner_sha256": sha(RUNNER), "parser_sha256": sha(PARSER_PATH),
            "wrapper_sha256": sha(Path(__file__)),
            "control_sha256": sha(Path(__file__).with_name("haunt_control.py")),
            "engine_binaries": parser_module.engine_binary_manifest()}


class ProcessEntry(ctypes.Structure):
    _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                ("th32ProcessID", wintypes.DWORD), ("th32DefaultHeapID", ctypes.c_size_t),
                ("th32ModuleID", wintypes.DWORD), ("cntThreads", wintypes.DWORD),
                ("th32ParentProcessID", wintypes.DWORD), ("pcPriClassBase", wintypes.LONG),
                ("dwFlags", wintypes.DWORD), ("szExeFile", wintypes.WCHAR * 260)]


def godot_processes() -> list[dict]:
    """Read-only native process census; never starts, kills, or attaches to Godot."""
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(ProcessEntry)]
    kernel.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(ProcessEntry)]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.CreateToolhelp32Snapshot(2, 0)
    if handle == wintypes.HANDLE(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    rows = []
    try:
        entry = ProcessEntry()
        entry.dwSize = ctypes.sizeof(entry)
        ok = kernel.Process32FirstW(handle, ctypes.byref(entry))
        while ok:
            if entry.szExeFile.lower().startswith("godot"):
                rows.append({"pid": entry.th32ProcessID, "parent_pid": entry.th32ParentProcessID,
                             "executable": entry.szExeFile})
            ok = kernel.Process32NextW(handle, ctypes.byref(entry))
    finally:
        kernel.CloseHandle(handle)
    return rows


def log_gate(native_exit: int, stdout: str, stderr: str, completion_ok: bool,
             source_ok: bool, pid_ok: bool) -> dict:
    lines = (stdout + "\n" + stderr).splitlines()
    errors = []
    inherited = 0
    for index, line in enumerate(lines):
        if not line.startswith(("ERROR:", "SCRIPT ERROR:")):
            continue
        following = lines[index + 1].strip() if index + 1 < len(lines) else ""
        if (line == "ERROR: GENERAL - Message Id Number: 0 | Message Id Name: Loader Message"
                and following.startswith("loader_get_json: Failed to open JSON file ")
                and any(s in following for s in ("TikTok LIVE Studio", "Epic Games\\Launcher\\Portal\\Extras\\Overlay"))):
            inherited += 1
        else:
            errors.append(line)
    light_count = sum(parser_module.UNPAIRED_LIGHT in line for line in lines)
    soft_count = sum(parser_module.SOFTSHADOW_UNDERFLOW.search(line) is not None for line in lines)
    retention = [line for line in lines if any(s in line for s in (
        "ObjectDB instances leaked", "resources still in use at exit", "Unreferenced static string", "RID allocations"))]
    reasons = []
    if native_exit != 0: reasons.append(f"native/runner exit {native_exit}")
    if not completion_ok: reasons.append("expected suite/capture completion absent or failed")
    if not source_ok: reasons.append("game, wrapper, parser, runner or installed engine bytes changed during run")
    if not pid_ok: reasons.append("actual Godot process identity missing")
    if parser_module.EXPECTED_ENGINE not in stdout or "Vulkan " not in stdout or "Forward+" not in stdout:
        reasons.append("expected installed Vulkan Forward+ identity absent")
    if errors: reasons.append(f"{len(errors)} non-inherited error headers")
    if light_count: reasons.append(f"{light_count} unpaired-light diagnostics")
    if soft_count: reasons.append(f"{soft_count} soft-shadow underflow diagnostics")
    if retention: reasons.append(f"{len(retention)} retention diagnostics")
    return {"exit": int(bool(reasons)), "reasons": reasons, "light_unpair_count": light_count,
            "softshadow_underflow_count": soft_count, "inherited_host_manifest_errors": inherited,
            "retention": retention, "non_inherited_errors": dict(Counter(errors)),
            "warning_headers": dict(Counter(line for line in lines if line.startswith("WARNING:")))}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=MODES)
    ap.add_argument("run_name")
    args = ap.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", args.run_name): ap.error("use a new plain run name")
    out = BASE / args.run_name
    out.mkdir(parents=True, exist_ok=False)
    profile = out / "APPDATA"; profile.mkdir()
    shots = out / "shots"; shots.mkdir()
    scene, test_path = MODES[args.mode]
    log = out / "godot.stdout.log"
    command_file = out / "command.ps1"
    q = parser_module.psquote
    command_file.write_text(f"$ErrorActionPreference = 'Continue'\n$global:LASTEXITCODE = $null\n& {q(RUNNER)} -ProjectPath {q(ROOT / 'game')} -Scene {q(scene)} "
        f"-LogPath {q(log)} -TimeoutSeconds 180 -Windowed -ShotDir {q(shots)} "
        "-ExtraArgs @('--verbose', '--audio-driver', 'Dummy', '--resolution', '1280x720', "
        "'--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan')\n"
        "if ($null -eq $global:LASTEXITCODE) { Write-Error 'Serial runner returned without an exit code'; exit 125 }\n"
        "exit $global:LASTEXITCODE\n", encoding="utf-8")
    for source, name in [(Path(__file__), "run_haunt.source.py"), (PARSER_PATH, "pairing_parser.source.py"),
                         (RUNNER, "run_godot_serial.source.ps1"),
                         (Path(__file__).with_name("haunt_control.py"), "haunt_control.source.py")]: shutil.copy2(source, out / name)
    before = snapshot(out, "before")
    env, cleared, present_overrides = clean_environment(os.environ)
    env["APPDATA"] = str(profile)
    command = [str(PWSH), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(command_file)]
    config = {"schema": "astra-resident-f01-haunt-v1", "mode": args.mode, "scene": scene,
              "test_path": test_path, "test_sha256": sha(ROOT / test_path), "command": command,
              "fresh_APPDATA": str(profile), "cleared_environment_keys": cleared,
              "present_overrides_removed": present_overrides,
              "surface_environment_policy": "all inherited SURFACE_* keys removed", "started_utc": utc(),
              "before": before, "scope": "One actual V1 resident lift arrival, public haunt dwell and return; independent Body clearance; no human, all-resident, performance or visual acceptance"}
    dump(out / "run_config.json", config)
    started = time.perf_counter()
    observations = []
    with (out / "runner.stdout.log").open("wb") as run_out, (out / "runner.stderr.log").open("wb") as run_err:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=run_out, stderr=run_err)
        dump(out / "runner_pid.json", {"pid": process.pid, "started_utc": config["started_utc"]})
        while process.poll() is None:
            active = godot_processes()
            if active and (not observations or active != observations[-1]["processes"]):
                observations.append({"elapsed_seconds": time.perf_counter() - started, "processes": active})
                dump(out / "godot_process_observations.json", observations)
            time.sleep(0.1)
        code = process.returncode
    elapsed = time.perf_counter() - started
    after = snapshot(out, "after")
    stdout = log.read_text(encoding="utf-8-sig", errors="replace") if log.exists() else ""
    errpath = Path(str(log) + ".stderr")
    stderr = errpath.read_text(encoding="utf-8-sig", errors="replace") if errpath.exists() else ""
    receipt_path = shots / "resident_f01_haunt.json"
    receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
    complete = (re.search(r"\[RESIDENT F01 HAUNT\] RESULT [1-9]\d* passed, 0 failed", stdout) is not None
        and receipt.get("failures") == 0 and bool(receipt.get("checks"))
        and all(row.get("passed") is True for row in receipt["checks"]))
    bindings = ["all_game_files_sha256", "runtime_inputs_sha256", "runner_sha256", "parser_sha256", "wrapper_sha256", "control_sha256", "engine_binaries"]
    stable = all(before[key] == after[key] for key in bindings) and len(before["engine_binaries"]) == 2
    gate = log_gate(code, stdout, stderr, complete, stable, bool(observations))
    result = {**config, "finished_utc": utc(), "native_exit": code, "elapsed_seconds": elapsed,
              "runner_pid": process.pid, "godot_process_observations": observations, "after": after,
              "source_unchanged": stable, "suite_completion": complete, "diagnostic_gate": gate,
              "actual_renderer_lines": [line for line in stdout.splitlines() if re.match(r"Vulkan \d", line) or line.startswith("[RENDER]")],
              "summary_lines": [line for line in stdout.splitlines() if any(s in line for s in ("[RESIDENT F01 HAUNT] RESULT",))],
              "passing_assertion_lines": sum(line.startswith("[RESIDENT F01 HAUNT] PASS ") for line in stdout.splitlines()),
              "visual_review": "PENDING" if args.mode == "capture" else "NO_CAPTURE_REQUESTED",
              "artifacts": [{"path": p.relative_to(out).as_posix(), "sha256": sha(p), "bytes": p.stat().st_size}
                            for p in sorted(out.rglob("*")) if p.is_file() and "APPDATA" not in p.relative_to(out).parts]}
    dump(out / "result.json", result)
    print(json.dumps({"run": args.run_name, "native_exit": code, "elapsed_seconds": elapsed,
        "source_unchanged": stable, "completion": complete, "summary": result["summary_lines"], "gate": gate}), flush=True)
    return gate["exit"]


if __name__ == "__main__":
    raise SystemExit(main())
