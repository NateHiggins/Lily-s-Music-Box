"""One authorized diagnostic; delegates unchanged runner and restores exact fixture."""
from pathlib import Path
import datetime
import hashlib
import json
import subprocess
import sys
import time

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
OUT = Path(__file__).resolve().parent
PREP = ROOT / "design/astra/work/vulkan_composed/revisions/terminal_operator_view_01"
FIXTURE = ROOT / "game/tests/vulkan_composed_root_test.gd"
PWSH = Path(r"C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe")
SHA = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
EXPECTED = {
    "game/tests/vulkan_composed_root_test.gd": "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3",
    "game/tests/VulkanComposedRootTest.tscn": "b95080899e02aa01d87b9a688ffee970f5d3e5ef14399d87cde6d91d40cc2663",
    "game/scripts/reality/apartment_encroachment.gd": "1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776",
    "game/scripts/building/building_root.gd": "cde44cd16b9ebdfedde0bcda34b404c2a675adffe106ba4ac0d576d26e8e1fd4",
}


def census():
    result = subprocess.run([str(PWSH), "-NoProfile", "-Command", "ConvertTo-Json -Compress -InputObject @(Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine)"], capture_output=True, check=True, text=True)
    return json.loads(result.stdout)


def write_receipt(value):
    (OUT / "invocation.json").write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


receipt = {"schema": "astra.v2-terminal-operator-view.invocation.v1", "started_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "status": "PREFLIGHT", "orchestrator_sha256": SHA(Path(__file__)),
    "prior_offline_preflight": "A read-only hash lookup used the wrong building/apartment_encroachment.gd path and raised FileNotFoundError. No source was installed and no engine was launched. Correct owner is scripts/reality/apartment_encroachment.gd.",
    "command": [sys.executable, "design/astra/work/vulkan_composed/run_case.py", "v2", "candidate", "terminal_operator_view_v2_01"],
    "scope": "single ordinary diagnostic; predicted failures remain gate red; no acceptance exception"}
write_receipt(receipt)
assert not (ROOT / "design/astra/evidence/vulkan_composed/runs/terminal_operator_view_v2_01").exists()
receipt["head_before"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
assert receipt["head_before"] == "77dc5f75cd7cb68be6d1f3d0be4f57ff1b06c3d4"
receipt["source_before"] = {rel: SHA(ROOT / rel) for rel in EXPECTED}
assert receipt["source_before"] == EXPECTED
receipt["processes_before"] = census()
write_receipt(receipt)
assert receipt["processes_before"] == []
candidate = (PREP / "proposed/game/tests/vulkan_composed_root_test.gd").read_bytes()
assert hashlib.sha256(candidate).hexdigest() == "4607eca50a8e9758bcfcd9a2c218cbda6755ac81a1b3468eba46a92fab054b38"
original = FIXTURE.read_bytes()
(OUT / "fixture_original.gd").write_bytes(original)
(OUT / "fixture_candidate.gd").write_bytes(candidate)
receipt["prepared_receipt_sha256"] = SHA(PREP / "preparation.json")
installed = False
try:
    FIXTURE.write_bytes(candidate)
    installed = True
    receipt["installed_fixture_sha256"] = SHA(FIXTURE)
    receipt["status"] = "RUNNING"
    write_receipt(receipt)
    started = time.perf_counter()
    result = subprocess.run(receipt["command"], cwd=ROOT, capture_output=True)
    receipt["external_command_seconds"] = round(time.perf_counter() - started, 3)
    receipt["external_command_exit"] = result.returncode
    (OUT / "external.stdout.log").write_bytes(result.stdout)
    (OUT / "external.stderr.log").write_bytes(result.stderr)
    receipt["status"] = "RUN_ENDED_RESTORATION_PENDING"
finally:
    receipt["processes_before_restore"] = census()
    if installed and receipt["processes_before_restore"] == []:
        receipt["fixture_before_restore_sha256"] = SHA(FIXTURE)
        FIXTURE.write_bytes(original)
        receipt["source_restored"] = {rel: SHA(ROOT / rel) for rel in EXPECTED}
        receipt["exact_original_restored"] = receipt["source_restored"] == EXPECTED
        receipt["processes_after_restore"] = census()
        receipt["status"] = "ENDED_EXACT_ORIGINAL_RESTORED" if receipt["exact_original_restored"] else "RESTORATION_FAILED"
    else:
        receipt["status"] = "RESTORATION_REFUSED_PROCESS_STILL_PRESENT"
    receipt["ended_at_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    write_receipt(receipt)
print(json.dumps(receipt, indent=2))
assert receipt["status"] == "ENDED_EXACT_ORIGINAL_RESTORED"
assert receipt["processes_after_restore"] == []
