"""Additive reassessment of retained samples; no rerender or historical rewrite."""
from pathlib import Path
import importlib.util
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location("capture_wrapper", HERE / "run.py")
wrapper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wrapper)
execution = wrapper.execution
invocation = ROOT / "design/astra/evidence/vulkan_composed/invocations/f01_provider_legacy_03/invocation.json"
result_path = ROOT / "design/astra/evidence/vulkan_composed/runs/f01_provider_legacy_03/result.json"
probe_path = result_path.parent / "frames/probe.json"
out = invocation.with_name("lifetime_reassessment.json")
assert not out.exists()
original = execution.read(invocation)
result = execution.read(result_path)
probe = execution.read(probe_path)
assert original["command_exit"] == result["actual_engine_exit"] == result["gate"]["diagnostic_gate_exit"] == 0
assert original["status"] == "EXACT_ORIGINAL_SOURCES_RESTORED"
assert all(row["passed"] for row in probe["checks"])
installed = {Path(key).as_posix(): value for key, value in original["installed_sources"].items()}
assert installed["game/tests/vulkan_composed_root_test.gd"] == execution.sha(HERE / "fixture_candidate.gd")
control = next(row for row in probe["owned_controls"] if row.get("kind") == "f01_provider_capture")
assert control["mode"] == control["census"]["mode"] == "legacy"
verdict = wrapper.classify_observations(original["samples"], original["wrapper_pid"])
assert verdict["contract_exit"] == 0
execution.dump(out, {"status": "ADDITIVE_SAMPLE_LIFETIME_REASSESSMENT_PASS",
    "original_invocation_sha256": execution.sha(invocation), "result_sha256": execution.sha(result_path),
    "probe_sha256": execution.sha(probe_path), "classifier_sha256": execution.sha(HERE / "capture_lane.py"),
    "lane": verdict, "checks": len(probe["checks"]), "captures": len(probe["captures"]),
    "rerendered": False, "original_failure_unchanged": True,
    "reason": "Null CIM retirement fields are unknown, not a conflicting known process identity."})
print(json.dumps({"status": "LEGACY_SAMPLES_REASSESSED", "checks": len(probe["checks"]), "captures": len(probe["captures"])}))
