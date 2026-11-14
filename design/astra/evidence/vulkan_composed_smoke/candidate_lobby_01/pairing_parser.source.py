"""Fresh standalone project/profile, unchanged serialized runner, fail-closed log gate.

This intentionally returns 1 for an expected red raw/omission run. An engine exit
of zero is not sufficient. No live game source or engine setting is changed.
"""
from __future__ import annotations

import argparse
from collections import Counter
import datetime
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
RUNNER = ROOT / "tools/run_godot_serial.ps1"
EVIDENCE = ROOT / "design/astra/evidence/vulkan_layer_pairing/runs"
PWSH = Path(r"C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe")
UNPAIRED_LIGHT = "BUG, indexing did not unpair geometries from light."
# The installed engine emits the compact "geom->softshadow_count==0 - BUG!".
# Also recognize Godot's spaced condition formatting without double counting.
SOFTSHADOW_UNDERFLOW = re.compile(r"geom->softshadow_count\s*==\s*0\b")
EXPECTED_ENGINE = "Godot Engine v4.7.1.stable.official.a13da4feb"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def dump(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def utc() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def is_pairing_diagnostic(line: str) -> bool:
    return UNPAIRED_LIGHT in line or SOFTSHADOW_UNDERFLOW.search(line) is not None


def manifest(project: Path) -> dict:
    rows = sorted([p.relative_to(project).as_posix(), sha(p.read_bytes())]
                  for p in project.rglob("*")
                  if p.is_file() and ".godot" not in p.relative_to(project).parts
                  and (p.suffix in {".gd", ".tscn", ".tres", ".json"} or p.name == "project.godot"))
    return {"files": rows, "sha256": sha(json.dumps(rows, separators=(",", ":"), ensure_ascii=True).encode())}


def diagnostic_gate(engine_exit: int, stdout: str, stderr: str, probe: dict | None,
                    source_unchanged: bool, case: str, engine_binding_valid: bool = True) -> dict:
    text = stdout + "\n" + stderr
    lines = text.splitlines()
    pairing_count = sum(is_pairing_diagnostic(line) for line in lines)
    headers = Counter(line for line in lines
                      if line.startswith(("ERROR:", "SCRIPT ERROR:", "WARNING:")))
    # Only known host layer-manifest errors are classified as inherited. Each
    # allowlisted header must have the exact loader_get_json next line; other
    # Vulkan errors bearing the same generic header remain failures.
    inherited = 0
    unexpected_errors = []
    for index, line in enumerate(lines):
        if not line.startswith(("ERROR:", "SCRIPT ERROR:")):
            continue
        next_line = lines[index + 1].strip() if index + 1 < len(lines) else ""
        known_manifest = (line == "ERROR: GENERAL - Message Id Number: 0 | Message Id Name: Loader Message"
                          and next_line.startswith("loader_get_json: Failed to open JSON file ")
                          and any(s in next_line for s in ("TikTok LIVE Studio", "Epic Games\\Launcher\\Portal\\Extras\\Overlay")))
        if known_manifest:
            inherited += 1
        else:
            unexpected_errors.append(line)
    retention = [line for line in lines if any(x in line for x in (
        "ObjectDB instances leaked", "resources still in use at exit", "Unreferenced static string"))]
    reasons = []
    if engine_exit != 0:
        reasons.append(f"engine/runner exit {engine_exit}")
    if EXPECTED_ENGINE not in stdout or "Forward+" not in stdout or "Vulkan " not in stdout:
        reasons.append("expected engine revision / Vulkan Forward+ identity absent")
    if not source_unchanged:
        reasons.append("source or serial runner changed during run")
    if not engine_binding_valid:
        reasons.append("installed launcher/GUI engine identity binding missing or changed")
    if unexpected_errors:
        reasons.append(f"{len(unexpected_errors)} non-inherited error headers")
    if pairing_count:
        reasons.append(f"{pairing_count} pairing/soft-shadow diagnostics")
    if retention:
        reasons.append(f"{len(retention)} retention diagnostics")
    if not probe:
        reasons.append("missing probe receipt")
    else:
        if probe.get("case") != case or probe.get("renderer") != "forward_plus" or not probe.get("pid"):
            reasons.append("invalid probe identity")
        if probe.get("functional_failures") != 0 or not probe.get("checks") or not all(c.get("passed") is True for c in probe["checks"]):
            reasons.append("functional checks failed or missing")
        captures = probe.get("captures", [])
        if len(captures) != 4 or any(not Path(c.get("file", "")).is_file() for c in captures):
            reasons.append("four actual captures required")
    diagnostic_exit = int(bool(reasons))
    expected_red = case in {"raw", "omission"}
    allowed_red_reasons = {f"{len(unexpected_errors)} non-inherited error headers",
                           f"{pairing_count} pairing/soft-shadow diagnostics"}
    only_pairing_errors = all(is_pairing_diagnostic(line) for line in unexpected_errors)
    controls_ok = ((pairing_count > 0 and only_pairing_errors and set(reasons) <= allowed_red_reasons)
                   if expected_red else diagnostic_exit == 0)
    return {"diagnostic_gate_exit": diagnostic_exit, "reasons": reasons,
            "pairing_diagnostics": pairing_count, "inherited_host_manifest_errors": inherited,
            "unexpected_error_headers": dict(Counter(unexpected_errors)),
            "retention_diagnostics": retention, "all_diagnostic_headers": dict(headers),
            "expected_diagnostic_result": "red" if expected_red else "green",
            "control_expectation_met": controls_ok}


def psquote(value: Path | str) -> str:
    return "'" + str(value).replace("'", "''") + "'"


def engine_binary_manifest() -> list[dict]:
    # Match the runner's PowerShell Get-Command resolution. Python shutil.which
    # on Windows prepends CWD, where this repository also has a launcher copy.
    executable = subprocess.check_output([str(PWSH), "-NoProfile", "-Command",
        "(Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction Stop).Source"],
        cwd=ROOT, text=True).strip()
    rows = []
    if executable:
        for path in [Path(executable), Path(executable).with_name("Godot_v4.7.1-stable_win64.exe")]:
            if path.is_file():
                rows.append({"path": str(path), "bytes": path.stat().st_size, "sha256": sha(path.read_bytes())})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("case", choices=["static", "raw", "candidate", "omission"])
    parser.add_argument("run_name")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", args.run_name):
        parser.error("run_name must be a simple new directory name")
    out = EVIDENCE / args.run_name
    out.mkdir(parents=True, exist_ok=False)
    project = out / "project"
    shutil.copytree(BASE / "project", project)
    if args.case == "omission":
        helper = project / "zone_layer_gate.gd"
        before = helper.read_text(encoding="utf-8")
        operation = "\t\t\tRenderingServer.instance_set_scenario(target.get_instance(), world.scenario)\n\t\t\trebinds += 1"
        assert before.count(operation) == 1, "omission target must be exact and unique"
        after = before.replace(operation, "\t\t\tpass # Negative control: omit only the pre-change rebind operation/counter.")
        helper.write_text(after, encoding="utf-8")
        (out / "omission.diff").write_text("".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
            fromfile="candidate/zone_layer_gate.gd", tofile="omission/zone_layer_gate.gd")), encoding="utf-8")
    shots = out / "shots"
    shots.mkdir()
    profile = out / "APPDATA"
    profile.mkdir()
    log = out / "godot.stdout.log"
    command = out / "command.ps1"
    command.write_text(f"& {psquote(RUNNER)} -ProjectPath {psquote(project)} -Scene 'res://probe.tscn' "
        f"-LogPath {psquote(log)} -TimeoutSeconds 90 -Windowed -ShotDir {psquote(shots)} "
        "-ExtraArgs @('--verbose', '--audio-driver', 'Dummy', '--resolution', '1280x720', "
        "'--rendering-method', 'forward_plus', '--rendering-driver', 'vulkan')\nexit $LASTEXITCODE\n", encoding="utf-8")
    shutil.copy2(Path(__file__), out / "run_case.source.py")
    shutil.copy2(RUNNER, out / "run_godot_serial.source.ps1")
    before = manifest(project)
    dump(out / "source_before.json", before)
    runner_sha = sha(RUNNER.read_bytes())
    env = os.environ.copy()
    env["APPDATA"] = str(profile)
    env["VULKAN_PAIRING_CASE"] = args.case
    config = {"case": args.case, "created_utc": utc(), "command_file": str(command),
              "project": str(project), "APPDATA": str(profile), "SHOT_DIR": str(shots),
              "runner_sha256": runner_sha, "wrapper_sha256": sha(Path(__file__).read_bytes()),
              "source_sha256": before["sha256"], "prepared_only": args.prepare_only}
    dump(out / "run_config.json", config)
    if args.prepare_only:
        print(json.dumps({"prepared": str(out), "launched": False}))
        return 0
    config["started_utc"] = utc()
    binaries_before = engine_binary_manifest()
    config["engine_binaries_before"] = binaries_before
    dump(out / "run_config.json", config)
    started = time.monotonic()
    with (out / "runner.stdout.log").open("w", encoding="utf-8") as stdout_file, (out / "runner.stderr.log").open("w", encoding="utf-8") as stderr_file:
        process = subprocess.Popen([str(PWSH), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(command)],
                                   env=env, stdout=stdout_file, stderr=stderr_file, cwd=ROOT)
        dump(out / "runner_pid.json", {"pid": process.pid, "started_utc": config["started_utc"]})
        code = process.wait()
    duration = time.monotonic() - started
    after = manifest(project)
    dump(out / "source_after.json", after)
    stdout = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    stderr_path = Path(str(log) + ".stderr")
    stderr = stderr_path.read_text(encoding="utf-8", errors="replace") if stderr_path.exists() else ""
    probe_path = shots / "probe_receipt.json"
    probe = json.loads(probe_path.read_text(encoding="utf-8")) if probe_path.exists() else None
    binaries = engine_binary_manifest()
    gate = diagnostic_gate(code, stdout, stderr, probe,
        before == after and runner_sha == sha(RUNNER.read_bytes()), args.case,
        engine_binding_valid=len(binaries_before) == 2 and binaries == binaries_before)
    result = {**config, "finished_utc": utc(), "wall_seconds": duration, "runner_pid": process.pid,
              "engine_exit": code, "engine_binaries": binaries,
              "godot_pid": probe.get("pid") if probe else None,
              "renderer_adapter_lines": [line for line in stdout.splitlines() if "Vulkan " in line or "Forward+" in line],
              "artifacts": [{"path": p.relative_to(out).as_posix(), "sha256": sha(p.read_bytes()), "bytes": p.stat().st_size}
                            for p in sorted(out.rglob("*")) if p.is_file() and ".godot" not in p.relative_to(out).parts and "APPDATA" not in p.relative_to(out).parts],
              "gate": gate, "visual_review": "pending manual inspection; no human acceptance implied"}
    dump(out / "result.json", result)
    print(json.dumps({"run": str(out), "engine_exit": code, "wall_seconds": duration, "gate": gate}))
    return gate["diagnostic_gate_exit"]


if __name__ == "__main__":
    raise SystemExit(main())
