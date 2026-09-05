"""Next baseline only; explicit --execute, no live source mutation."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parents[1]
sys.path.insert(0, str(PACKAGE / "runtime_execution"))
from environment_contract import ROOT, WRAPPER, prepare_environment, actual_wrapper_environment
from invoke_wrapper import PINNED

FIXTURE = "game/tests/vulkan_composed_root_test.gd"
OWNER = "game/scripts/reality/apartment_encroachment.gd"
FIXTURE_SHA = "c2642de6f0c099a18e8d7c0f740f94a84f0d5bc90cc255973dee5ab6ad2ee6b5"
OWNER_SHA = "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db"
RUN_NAME = "material_ownership_7c54_v1_full_02"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--receipt-dir", type=Path, required=True)
    args = parser.parse_args()
    out = args.receipt_dir.resolve()
    if out.exists() or not out.is_relative_to(ROOT / "design/astra/evidence/composed_material_ownership"):
        parser.error("a fresh dedicated outside-run receipt directory is required")
    out.mkdir(parents=True)
    run_folder = ROOT / "design/astra/evidence/vulkan_composed/runs" / RUN_NAME
    command = [sys.executable, str(WRAPPER), "v1", "candidate", RUN_NAME, "--scope", "full"]
    receipt = {"status": "PREFLIGHT", "recorded_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "command": command, "run_folder": str(run_folder), "fixture_sha256": FIXTURE_SHA, "owner_sha256": OWNER_SHA}
    code = 1
    try:
        sources = [Path(__file__), PACKAGE / "runtime_execution/environment_contract.py", PACKAGE / "runtime_execution/invoke_wrapper.py"]
        receipt["invocation_sources"] = {}
        for source in sources:
            shutil.copyfile(source, out / (source.name + ".source"))
            receipt["invocation_sources"][str(source)] = sha(source)
        env, env_receipt = prepare_environment(os.environ)
        receipt["environment"] = env_receipt
        actual = actual_wrapper_environment(env, run_folder / "APPDATA", run_folder / "frames")
        keys = [*env_receipt["explicit_wrapper_material_environment"], "APPDATA", "SHOT_DIR", "CAMPAIGN_TIME_FREEZE", "VULKAN_COMPOSED_SCOPE"]
        receipt["projected_actual_child_environment"] = {key: actual[key] for key in keys}
        if not args.execute:
            receipt["status"], code = "ENVIRONMENT_CHECK_ONLY_NO_ENGINE", 0
        else:
            if run_folder.exists():
                raise ValueError("raw run folder already exists; do not overwrite it")
            expected = dict(PINNED, **{FIXTURE: FIXTURE_SHA, OWNER: OWNER_SHA})
            receipt["source_preflight"] = {path: sha(ROOT / path) for path in expected}
            if receipt["source_preflight"] != expected:
                raise ValueError("runtime owner/fixture/renderer/runner source drift")
            receipt["status"] = "WRAPPER_RUNNING"
            (out / "invocation.json").write_text(json.dumps(receipt, indent=2) + "\n")
            process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
            (out / "invocation.stdout.log").write_bytes(process.stdout)
            (out / "invocation.stderr.log").write_bytes(process.stderr)
            code = process.returncode
            receipt.update(status="WRAPPER_RETURNED", wrapper_process_exit=code)
            result = run_folder / "result.json"
            if result.is_file(): receipt["runtime_result_sha256"] = sha(result)
            receipt["invocation_sources_unchanged"] = all(sha(Path(path)) == digest for path, digest in receipt["invocation_sources"].items())
            if receipt["invocation_sources_unchanged"] is not True: code = 1
    except (OSError, ValueError) as error:
        receipt.update(status="PREFLIGHT_OR_EXECUTION_REFUSED", error=str(error))
    finally:
        (out / "invocation.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
