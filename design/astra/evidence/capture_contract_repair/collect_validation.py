"""Reproduce CLI receipt-consumer red/green proof without Git writes or Godot."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[3]
sys.path.insert(0, str(root / "tools/tests"))
import test_orison_v2_completeness as fixture


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_record(name, args):
    result = subprocess.run([sys.executable, *args], cwd=root,
                            capture_output=True, text=True, check=False)
    out, err = [evidence / (name + suffix) for suffix in (".stdout.txt", ".stderr.txt")]
    out.write_text(result.stdout, encoding="utf-8", newline="\n")
    err.write_text(result.stderr, encoding="utf-8", newline="\n")
    return {"exit_code": result.returncode,
            "stdout": out.relative_to(root).as_posix(), "stdout_sha256": digest(out),
            "stderr": err.relative_to(root).as_posix(), "stderr_sha256": digest(err)}, result.stdout


runs = {}
runs["selftests"], _ = run_record("selftests_final", ["tools/tests/test_orison_v2_completeness.py"])
assert runs["selftests"]["exit_code"] == 0
runs["audit"], after_text = run_record("audit_final", ["tools/audit_orison_v2_completeness.py", "--json"])
runs["first_slice"], first_text = run_record("first_slice_final", [
    "tools/audit_orison_v2_completeness.py", "--json", "--blockers-for", "first-slice"])
assert runs["audit"]["exit_code"] == 2 and runs["first_slice"]["exit_code"] == 2

legacy = {"schema_version": 1, "production_runtime": True, "selector": "v2", "records": [
    {"frame": "save_reconstruction_contract", "save_phase": "closed", "capture": "PASS"},
    {"frame": "premature_action_denied", "capture": "PASS"},
    {"frame": "teardown_0_retained", "capture": "PASS"}]}
mutations = {
    "legacy_capture_only": lambda data: None,
    "unexecuted_save": lambda data: data["contracts"]["save_reconstruction"].update(executed=False),
    "missing_denial": lambda data: data["contracts"].pop("premature_action_denial"),
    "nonzero_exit": lambda data: data["execution"].update(exit_code=2),
    "boolean_exit": lambda data: data["execution"].update(exit_code=False),
    "incomplete": lambda data: data["execution"].update(completed=False),
    "timeout": lambda data: data["execution"].update(timed_out=True),
    "stale_source": lambda data: data["source"].update(test_sha256="0" * 64),
    "external_source": lambda data: data["source"].update(test_path="../outside.gd"),
    "unscoped_identity": lambda data: data["contracts"]["production_composition"]["identities"].remove("F01_NIGHT_REGISTER"),
    "unmeasured_teardown": lambda data: data["contracts"]["teardown"].pop("retained_nodes"),
    "retained_resource": lambda data: data["contracts"]["teardown"].update(retained_resources=1),
    "retained_playback": lambda data: data["contracts"]["teardown"].update(retained_playbacks=1),
}
pairs = []
for name, mutate in mutations.items():
    with fixture.TempRepo() as temp_root:
        fixture.make_slice_complete(temp_root)
        receipt = temp_root / "art/renders/orison_v2/mini_m08f_composition/runtime_authority_receipt.json"
        original = receipt.read_text(encoding="utf-8")
        bad = json.loads(original)
        mutate(bad)
        if name == "legacy_capture_only":
            bad = legacy
        receipt.write_text(json.dumps(bad), encoding="utf-8")
        args = ["tools/audit_orison_v2_completeness.py", "--root", str(temp_root),
                "--json", "--blockers-for", "first-slice"]
        red, red_text = run_record("fixture_" + name + "_red", args)
        assert red["exit_code"] == 2, (name, red)
        assert "ritual.F01_NIGHT_REGISTER" in json.loads(red_text)["blockers_by_scope"]["FIRST_SLICE_TECHNICAL"]
        receipt.write_text(original, encoding="utf-8")
        green, green_text = run_record("fixture_" + name + "_green", args)
        assert green["exit_code"] == 0, (name, green)
        assert json.loads(green_text)["blockers_by_scope"]["FIRST_SLICE_TECHNICAL"] == []
        pairs.append({"case": name, "red": red, "green": green,
                      "scope": "synthetic receipt-consumer fixture only; no Godot execution"})

before = json.loads((evidence / "audit_before.stdout.json").read_text(encoding="utf-8-sig"))
after = json.loads(after_text)
old_rows = {r["id"]: r for r in before["requirements"]}
deltas = [{"id": r["id"], "before": old_rows[r["id"]]["status"], "after": r["status"]}
          for r in after["requirements"] if r["status"] != old_rows[r["id"]]["status"]]
expected = {"ritual.F01_WATCHMAN_DETECTOR", "ritual.F01_NIGHT_REGISTER",
            "ritual.F01_SIGNAL_REGISTER", "ritual.F01_TOUR_KEY_GUARD",
            "contract.B1_BOILER_01", "contract.F02_B_RADIATOR_01", "job.lena_radiator_round_2b"}
assert {r["id"] for r in deltas} == expected, deltas
historical = root / "art/renders/orison_v2/m08f_runtime_composition_01/runtime_authority_receipt.json"
before_receipt = json.loads((evidence / "before.json").read_text(encoding="utf-8-sig"))
assert digest(historical) == before_receipt["historical_receipt_sha256"]
source_paths = ["game/tests/orison_v2_m08f_runtime_shot.gd", "tools/audit_orison_v2_completeness.py",
                "tools/tests/test_orison_v2_completeness.py"]
proof = {"schema_version": 1, "kind": "capture_contract_audit_repair",
         "repository_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
         "working_tree_source_hashes": {p: digest(root / p) for p in source_paths},
         "collector_sha256": digest(Path(__file__)),
         "before": before_receipt, "negative_proof": {
             "test": "ChronologyTests.test_legacy_capture_only_receipt_cannot_clear_runtime_gate",
             "before_selftest_exit": 1, "before_legacy_fixture_cli_exit": 0,
             "before_failure_log": "design/astra/evidence/capture_contract_repair/legacy_negative_before.stderr.txt",
             "after_legacy_fixture_cli_exit": 2, "corrected_synthetic_fixture_cli_exit": 0},
         "runs": runs, "selftests_passed": 102, "actual_cli_red_green_pairs": pairs,
         "historical_receipt_preserved": {"path": historical.relative_to(root).as_posix(), "sha256": digest(historical)},
         "expected_status_demotions": deltas, "other_requirement_status_changes": [],
         "first_slice_blockers_after": json.loads(first_text)["blockers_by_scope"]["FIRST_SLICE_TECHNICAL"],
         "rejected_receipts": after["evidence_intake"]["rejected_runtime_receipts"],
         "limits": ["No Godot execution in this task; capture script has not been rendered or runtime-validated.",
                    "Positive runtime receipts exist only inside disposable synthetic fixtures.",
                    "No historical evidence, live ledger, game product script, Git index or commit was modified.",
                    "The audit checks explicit execution attestation and source identity; it is not a replacement for executing the runtime test."]}
(evidence / "validation.json").write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"selftests": runs["selftests"]["exit_code"], "fixture_pairs": len(pairs),
                  "demotions": deltas, "validation_sha256": digest(evidence / "validation.json")}, indent=2))
