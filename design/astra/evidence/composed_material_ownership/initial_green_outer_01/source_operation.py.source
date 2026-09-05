"""Four exact source swaps for later authorized execution. No engine calls."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
from invoke_wrapper import ROOT, PACKAGE, OWNER, FIXTURE, FIXTURE_SHA, ORIGINAL_SHA, CORRUPTION_SHA

ORIGINAL_FIXTURE_SHA = "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3"
OPERATIONS = {
    "install_fixture": (FIXTURE, ORIGINAL_FIXTURE_SHA, FIXTURE_SHA, PACKAGE / "proposed" / FIXTURE),
    "install_control": (OWNER, ORIGINAL_SHA, CORRUPTION_SHA, PACKAGE / "controls/build_wrong_storey/proposed" / OWNER),
    "restore_control": (OWNER, CORRUPTION_SHA, ORIGINAL_SHA, PACKAGE / "controls/build_wrong_storey/originals" / OWNER),
    "restore_fixture": (FIXTURE, FIXTURE_SHA, ORIGINAL_FIXTURE_SHA, PACKAGE / "originals" / FIXTURE),
}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=OPERATIONS)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--receipt-dir", required=True, type=Path)
    args = parser.parse_args()
    out = args.receipt_dir.resolve()
    if out.exists() or not out.is_relative_to(ROOT / "design/astra/evidence/composed_material_ownership"):
        parser.error("fresh dedicated source receipt directory required")
    out.mkdir(parents=True)
    relative, before_sha, after_sha, source = OPERATIONS[args.operation]
    target = (ROOT / relative).resolve()
    if not target.is_relative_to((ROOT / "game").resolve()):
        parser.error("resolved target escapes the exact game workspace")
    receipt = {"status": "PREFLIGHT", "operation": args.operation, "target": str(target), "source": str(source),
               "recorded_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "expected_before_sha256": before_sha, "expected_after_sha256": after_sha}
    temporary = target.with_name(target.name + ".astra_material_swap.tmp")
    created_temporary = False
    code = 1
    try:
        original, replacement = target.read_bytes(), source.read_bytes()
        receipt.update(actual_before_sha256=digest(original), replacement_sha256=digest(replacement))
        if digest(replacement) != after_sha:
            raise ValueError("prepared replacement bytes drifted")
        if args.operation.startswith("restore_") and digest(original) == after_sha:
            receipt["status"], code = "ALREADY_EXACTLY_RESTORED", 0
        elif digest(original) != before_sha:
            raise ValueError("live source differs; refusing to overwrite another owner's or unexpected bytes")
        elif not args.execute:
            receipt["status"], code = "CHECK_ONLY_NO_GAME_MUTATION", 0
        else:
            (out / "before.raw").write_bytes(original)
            (out / "replacement.raw").write_bytes(replacement)
            with temporary.open("xb") as handle:
                created_temporary = True
                handle.write(replacement)
            if digest(temporary.read_bytes()) != after_sha:
                raise ValueError("temporary source verification failed")
            os.replace(temporary, target)
            created_temporary = False
            receipt["actual_after_sha256"] = digest(target.read_bytes())
            if receipt["actual_after_sha256"] != after_sha:
                raise ValueError("post-swap source verification failed")
            receipt["status"], code = "EXACT_SOURCE_SWAP_COMPLETE", 0
    except (OSError, ValueError) as error:
        receipt.update(status="SOURCE_SWAP_REFUSED_OR_FAILED", error=str(error))
    finally:
        if created_temporary and temporary.exists():
            temporary.unlink()  # Only the exact temporary file created by this invocation.
        (out / "source_operation.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
