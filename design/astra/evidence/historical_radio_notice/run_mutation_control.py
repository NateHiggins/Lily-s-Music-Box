"""Explicit bounded source omission, a real serial run, then byte-exact restore."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
name = sys.argv[1]
controls = {
    "notice_owner_cleanup_omitted": (
        "game/scripts/props/lobby_bulletin_board.gd", "focused",
        "func _exit_tree() -> void:",
        "func _omitted_exit_tree_fixture() -> void:",
    ),
    "calendar_clamp_omitted": (
        "game/scripts/game/campaign_clock.gd", "calendar",
        "\tvar seconds := mini(86399,\n\t\t\tint(floor(fposmod(total, float(MINUTES_PER_DAY)) * 60.0 + 0.00001)))",
        "\tvar seconds := int(floor(fposmod(total, float(MINUTES_PER_DAY)) * 60.0 + 0.00001))",
    ),
    "notice_coalesce_omitted": (
        "game/scripts/props/lobby_bulletin_board.gd", "focused",
        "if _inspection_tap and frame != _last_tap_physics_frame:",
        "if _inspection_tap:",
    ),
}
relative, mode, old, new = controls[name]
source = ROOT / relative
original = source.read_bytes()
needle = old.encode()
replacement = new.encode()
if needle not in original:
    needle = old.replace("\n", "\r\n").encode()
    replacement = new.replace("\n", "\r\n").encode()
assert original.count(needle) == 1, "Source must match one exact reviewed omission"
mutated = original.replace(needle, replacement)
try:
    source.write_bytes(mutated)
    result = subprocess.run([sys.executable, str(BASE / "run_notice_validation.py"), name, mode], cwd=ROOT)
finally:
    source.write_bytes(original)
receipt = {"schema": "astra.bounded_notice_mutation.v1", "source": relative,
           "mutation": name, "old": old, "new": new,
           "original_sha256": hashlib.sha256(original).hexdigest(),
           "mutated_sha256": hashlib.sha256(mutated).hexdigest(),
           "restored_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
           "restored_byte_identically": source.read_bytes() == original,
           "runner_exit": result.returncode, "run_receipt": name + "/run_receipt.json"}
path = BASE / (name + ".mutation.json")
assert not path.exists()
path.write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt, indent=2))
