"""Correct the prepared capture's collection name; retain the failed attempt."""
from pathlib import Path
import json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREVIOUS = HERE.with_name("f01_provider_capture_02")
assert not (HERE / "run.py").exists()
assert (ROOT / "game/tests/vulkan_composed_root_test.gd").read_bytes() == (PREVIOUS / "fixture_original.gd").read_bytes()
source = (PREVIOUS / "run.py").read_text()
assert source.count("name='f01_provider_'+mode+'_02'") == 1
(HERE / "run.py").write_text(source.replace("name='f01_provider_'+mode+'_02'", "name='f01_provider_'+mode+'_03'"), encoding="utf-8")
(HERE / "fixture_original.gd").write_bytes((PREVIOUS / "fixture_original.gd").read_bytes())
candidate = (PREVIOUS / "fixture_candidate.gd").read_text()
assert candidate.count('owned_controls.append({"kind":"f01_provider_capture"') == 1
candidate = candidate.replace('owned_controls.append({"kind":"f01_provider_capture"', 'controls.append({"kind":"f01_provider_capture"')
(HERE / "fixture_candidate.gd").write_text(candidate, encoding="utf-8")
(HERE / "preparation.json").write_text(json.dumps({"change": "Use the fixture's declared controls collection", "game_changed": False, "engine_launched": False}, indent=2) + "\n")
print("Corrected capture prepared in fresh folders.")
