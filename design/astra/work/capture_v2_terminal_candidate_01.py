"""One candidate operator capture; exact fixture overlay and guarded restoration."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import sys
import time

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
OUT = ROOT / "design/astra/evidence/vulkan_composed/invocations/terminal_candidate_view_v2_01"
RUN = ROOT / "design/astra/evidence/vulkan_composed/runs/terminal_candidate_view_v2_01"
PREP = ROOT / "design/astra/work/vulkan_composed/revisions/terminal_operator_view_01"
TERMINAL = ROOT / "design/astra/evidence/v2_terminal_access_arrival_02"
FIXTURE = "game/tests/vulkan_composed_root_test.gd"
PWSH = Path(r"C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe")
EXPECTED = {
    FIXTURE: "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3",
    "game/tests/VulkanComposedRootTest.tscn": "b95080899e02aa01d87b9a688ffee970f5d3e5ef14399d87cde6d91d40cc2663",
    "game/tests/orison_v2_terminal_access_test.gd": "800d7bf531758e2720d70d3167378c5bb77a90b0cb054ddad0347010feec47e3",
    "game/tests/OrisonV2TerminalAccessTest.tscn": "58efa825834b160032e80ed9bdd5b754e942ffdd09aec995acc4e11919f5fd60",
    "game/scripts/reality/apartment_encroachment.gd": "1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776",
    "game/scripts/building/building_root.gd": "cde44cd16b9ebdfedde0bcda34b404c2a675adffe106ba4ac0d576d26e8e1fd4",
    "game/scripts/building/orison_v2_runtime_root.gd": "03d68b7a8f55572c722bb97d0de8b6d1b6644b2072e4d10bfce2a7605c8fe955",
    "game/scripts/call/desk_zone.gd": "2208e7549bf7ec3a7acb8ba73d689575a2f7193c5888e5de92800b044e114a4a",
    "design/astra/work/vulkan_composed/run_case.py": "8cb42f642262ccf416f0993699d7a3dff7b8cd3fa42631f6a33c0a8d0d1c6ad9",
    "design/astra/work/vulkan_composed/gate.py": "2197f6ad6b9a13cf83c1d99313808b20b3a8be1472997d7e53d6ef61e035d264",
    "tools/run_godot_serial.ps1": "0b4af8393a72d3a2ebb53c2d19037ea3ff41318513d08facccdbf747814d6b68",
}
CANDIDATE = "4607eca50a8e9758bcfcd9a2c218cbda6755ac81a1b3468eba46a92fab054b38"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()


def census():
    result = subprocess.run([str(PWSH), "-NoProfile", "-Command", "ConvertTo-Json -Compress -InputObject @(Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'Godot|Blender' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine)"], capture_output=True, check=True, text=True)
    return json.loads(result.stdout)


def main():
    assert not OUT.exists() and not RUN.exists(), "fresh capture namespace required"
    terminal_result_path = TERMINAL / "runs/06_restored_candidate/result.json"
    terminal_result = json.loads(terminal_result_path.read_text())
    assert terminal_result["actual_runner_exit"] == 0
    assert terminal_result["assessment"]["diagnostic_gate_exit"] == 0
    assert terminal_result["assessment"]["passed"] == 39
    assert terminal_result["assessment"]["total"] == 39
    assert {rel: sha(ROOT / rel) for rel in EXPECTED} == EXPECTED
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == "af9c5b6fdc42079d4bd64549b709a49ababa9e50"
    assert census() == []
    candidate = (PREP / "proposed" / FIXTURE).read_bytes()
    assert hashlib.sha256(candidate).hexdigest() == CANDIDATE
    original = (ROOT / FIXTURE).read_bytes()
    OUT.mkdir(parents=True)
    (OUT / "fixture_original.gd").write_bytes(original)
    (OUT / "fixture_candidate.gd").write_bytes(candidate)
    command = [sys.executable, "-B", "design/astra/work/vulkan_composed/run_case.py", "v2", "candidate", RUN.name]
    receipt = {"schema": "astra.v2-terminal-candidate-capture.v1", "started_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "source_before": EXPECTED, "orchestrator_sha256": sha(Path(__file__)), "command": command,
               "input_proof_sha256": sha(terminal_result_path), "status": "PREPARED",
               "scope": "Actual windowed operator and fixture-mounted PhoneCamera views; controlled pose, no walked route or physical handset flow."}
    save = lambda: (OUT / "invocation.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    save()
    installed = False
    try:
        (ROOT / FIXTURE).write_bytes(candidate)
        installed = True
        receipt["installed_fixture_sha256"] = sha(ROOT / FIXTURE)
        assert receipt["installed_fixture_sha256"] == CANDIDATE
        receipt["status"] = "RUNNING"
        save()
        started = time.perf_counter()
        with (OUT / "external.stdout.log").open("wb") as stdout, (OUT / "external.stderr.log").open("wb") as stderr:
            result = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr)
        receipt["actual_command_exit"] = result.returncode
        receipt["command_seconds"] = time.perf_counter() - started
    finally:
        receipt["processes_before_restore"] = census()
        current = sha(ROOT / FIXTURE)
        if installed and receipt["processes_before_restore"] == [] and current == CANDIDATE:
            (ROOT / FIXTURE).write_bytes(original)
            receipt["source_after"] = {rel: sha(ROOT / rel) for rel in EXPECTED}
            receipt["status"] = "EXACT_FIXTURE_RESTORED" if receipt["source_after"] == EXPECTED else "SOURCE_DRIFT"
        else:
            receipt["status"] = "RESTORATION_REFUSED_UNEXPECTED_SOURCE_OR_PROCESS"
        receipt["ended_at_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save()
    print(json.dumps({"status": receipt["status"], "actual_command_exit": receipt.get("actual_command_exit"), "receipt": str(OUT / "invocation.json")}))
    return 0 if receipt["status"] == "EXACT_FIXTURE_RESTORED" and receipt.get("actual_command_exit") == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
