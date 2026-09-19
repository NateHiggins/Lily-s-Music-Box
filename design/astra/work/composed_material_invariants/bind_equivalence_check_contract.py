"""Archive previous preparation and bind the declared 171 checks before execution."""
from pathlib import Path
import hashlib
import json
import re
import shutil

ROOT = Path(__file__).resolve().parents[4]
PACKAGE = ROOT / "design/astra/work/encroachment_sweep/equivalence_revisions/ownership_7c54c_01"
OLD = PACKAGE / "gate_contract_revision/originals"
assert not OLD.exists(), "previous declaration must not be overwritten"
receipt = json.loads((PACKAGE / "preparation_receipt.json").read_text())
for name in list(receipt["artifacts"]) + ["preparation_receipt.json"]:
    destination = OLD / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(PACKAGE / name, destination)
fixture = PACKAGE / "proposed/game/tests/encroachment_sweep_equivalence_test.gd"
text = fixture.read_text()
exercise = text.split("func _exercise(", 1)[1].split("\n\nfunc _layered(", 1)[0]
labels = re.findall(r'_check\(context, "([^"]+)"', exercise)
assert len(labels) == 38 and len(set(labels)) == 38
contract = {
    "scope": "Declared before any Godot execution. Do not lower count to match an unexpected run.",
    "fixture_sha256": hashlib.sha256(fixture.read_bytes()).hexdigest(),
    "expected_check_count": 171,
    "exercise_labels_in_order": labels,
    "phase_order": ["initial", "repeated", "late_moved_replaced", "stain", "exchange", "detached"],
}
(PACKAGE / "expected_check_contract.json").write_text(json.dumps(contract, indent=2) + "\n")
print(str(PACKAGE / "expected_check_contract.json"))
