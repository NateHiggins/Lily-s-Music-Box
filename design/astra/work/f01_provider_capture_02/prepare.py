"""Prepare matched captures against the new controlled provider sequence."""
from pathlib import Path
import hashlib
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREVIOUS = HERE.with_name("f01_provider_capture_01")
assert not (HERE / "run.py").exists()
fixture = ROOT / "game/tests/vulkan_composed_root_test.gd"
assert fixture.read_bytes() == (PREVIOUS / "fixture_original.gd").read_bytes()
source = (PREVIOUS / "run.py").read_text()
assert "f01_provider_execution_05" in source
source = source.replace("f01_provider_execution_05", "f01_provider_execution_07")
assert "name='f01_provider_'+mode+'_01'" in source
source = source.replace("name='f01_provider_'+mode+'_01'", "name='f01_provider_'+mode+'_02'")
(HERE / "run.py").write_text(source, encoding="utf-8")
for name in ["fixture_original.gd", "fixture_candidate.gd"]:
    (HERE / name).write_bytes((PREVIOUS / name).read_bytes())
(HERE / "preparation.json").write_text(json.dumps({
    "previous_orchestrator_sha256": hashlib.sha256((PREVIOUS / "run.py").read_bytes()).hexdigest(),
    "changes": ["fresh execution_07 prerequisite", "fresh capture output names"],
    "fixture_unchanged": True, "game_changed": False, "engine_launched": False}, indent=2) + "\n")
print("Fresh matched-capture wrapper prepared; restored candidate is still required before execution.")
