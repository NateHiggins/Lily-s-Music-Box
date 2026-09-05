"""Prepared launcher. Only --execute launches the unchanged serial wrapper."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
from environment_contract import ROOT, WRAPPER, WRAPPER_SHA, prepare_environment, actual_wrapper_environment

PACKAGE = Path(__file__).resolve().parent.parent
OWNER = "game/scripts/reality/apartment_encroachment.gd"
FIXTURE = "game/tests/vulkan_composed_root_test.gd"
FIXTURE_SHA = "e132724ae67f1dc4056f9fa1c9b018706399a7c3500889af41d0e6dedeeb8991"
ORIGINAL_SHA = "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db"
CORRUPTION_SHA = "bbe60da38af51a77fe55129fb2bff9d86b65e67722f5da0b97cd07fa772c6d10"
CASES = {
    "baseline": ("material_ownership_7c54_v1_full_01", "full", ORIGINAL_SHA),
    "wrong_storey": ("material_build_wrong_storey_01", "root_retirement", CORRUPTION_SHA),
    "restored": ("material_build_wrong_storey_restored_01", "root_retirement", ORIGINAL_SHA),
}
PINNED = {
    "design/astra/work/vulkan_composed/run_case.py": WRAPPER_SHA,
    "design/astra/work/vulkan_composed/gate.py": "2197f6ad6b9a13cf83c1d99313808b20b3a8be1472997d7e53d6ef61e035d264",
    "tools/run_godot_serial.ps1": "0b4af8393a72d3a2ebb53c2d19037ea3ff41318513d08facccdbf747814d6b68",
    "game/tests/VulkanComposedRootTest.tscn": "b95080899e02aa01d87b9a688ffee970f5d3e5ef14399d87cde6d91d40cc2663",
    "game/scripts/building/building_root.gd": "cde44cd16b9ebdfedde0bcda34b404c2a675adffe106ba4ac0d576d26e8e1fd4",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("case", choices=CASES)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--receipt-dir", required=True, type=Path)
    args = parser.parse_args()
    out = args.receipt_dir.resolve()
    if out.exists() or not out.is_relative_to(ROOT / "design/astra/evidence/composed_material_ownership"):
        parser.error("receipt-dir must be a fresh path inside the dedicated outside-run evidence directory")
    out.mkdir(parents=True)
    run_name, scope, owner_sha = CASES[args.case]
    run_dir = ROOT / "design/astra/evidence/vulkan_composed/runs" / run_name
    command = [sys.executable, str(WRAPPER), "v1", "candidate", run_name, "--scope", scope]
    receipt = {"status": "PREFLIGHT", "recorded_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "case": args.case, "command": command, "run_folder": str(run_dir),
               "meaning": "candidate names renderer helper; material corruption is separately bound by owner hash",
               "expected_owner_sha256": owner_sha, "expected_fixture_sha256": FIXTURE_SHA}
    code = 1
    try:
        env, env_receipt = prepare_environment(os.environ)
        receipt["environment"] = env_receipt
        projected = actual_wrapper_environment(env, run_dir / "APPDATA", run_dir / "frames", scope=scope)
        receipt["projected_actual_child_environment"] = {key: projected[key] for key in
            [*env_receipt["explicit_wrapper_material_environment"], "APPDATA", "SHOT_DIR", "ORISON_BUILDING_ROOT",
             "VULKAN_COMPOSED_VARIANT", "VULKAN_COMPOSED_SCOPE", "CAMPAIGN_TIME_FREEZE", "WEATHER_SEED", "TITLE_SCREEN_SILENT"]}
        if not args.execute:
            receipt["status"], code = "ENVIRONMENT_CHECK_ONLY_NO_ENGINE_NO_GAME_MUTATION", 0
        else:
            if run_dir.exists():
                raise ValueError("run directory already exists; never overwrite or resume a raw run")
            expected = dict(PINNED, **{OWNER: owner_sha, FIXTURE: FIXTURE_SHA})
            observed = {path: sha(ROOT / path) for path in expected}
            receipt["preflight_source_hashes"] = observed
            if observed != expected:
                raise ValueError("source preflight differs from exact declared bindings")
            receipt["status"] = "WRAPPER_RUNNING"
            (out / "invocation.json").write_text(json.dumps(receipt, indent=2) + "\n")
            process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
            (out / "invocation.stdout.log").write_bytes(process.stdout)
            (out / "invocation.stderr.log").write_bytes(process.stderr)
            code = process.returncode
            receipt.update(status="WRAPPER_RETURNED", wrapper_process_exit=code,
                           runtime_result_present=(run_dir / "result.json").is_file())
            if (run_dir / "result.json").is_file():
                receipt["runtime_result_sha256"] = sha(run_dir / "result.json")
    except (OSError, ValueError) as error:
        receipt.update(status="PREFLIGHT_OR_EXECUTION_REFUSED", error=str(error))
    finally:
        (out / "invocation.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
