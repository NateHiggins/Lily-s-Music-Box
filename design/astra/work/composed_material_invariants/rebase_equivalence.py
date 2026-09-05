"""Create a new offline package; never overwrite the retained 69e28e preparation."""
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
old = ROOT / "design/astra/work/encroachment_sweep/equivalence"
new = ROOT / "design/astra/work/encroachment_sweep/equivalence_revisions/ownership_7c54c_01"
assert not new.exists()
new.mkdir(parents=True)
for name in ("prepare.py", "test_prepare.py", "gate.py", "test_gate.py", "README.md", "seal_preparation.py"):
    source = (old / name).read_text(encoding="utf-8")
    source = source.replace("ROOT = HERE.parents[4]", 'ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())')
    source = source.replace("ownership_69e28e_01", "ownership_7c54c_01")
    source = source.replace("69e28e38740f122fe5bfd47b9f8bc6194fd5e52dda2eae085163deee30977860",
                            "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db")
    source = source.replace("5b2fbabba674cec4ebd8644c006aac5c4033a85b8bb0dfd59d4f1a49b2ce646c",
                            "b5b977c6cdd83d4e60b1ea333822d26489651819efa3ed99163dcea180183a94")
    if name == "README.md":
        source += "\nThis new preparation supersedes the retained, unrun 69e28e package only for the final nullable living_source guard inherited outside reach_props. Earlier sources and receipts were not overwritten.\n"
    (new / name).write_bytes(source.encode())
tests = new / "proposed/game/tests"
tests.mkdir(parents=True)
for name in ("encroachment_sweep_equivalence_test.gd", "EncroachmentSweepEquivalenceTest.tscn"):
    shutil.copy2(old / "proposed/game/tests" / name, tests / name)
subprocess.run([sys.executable, str(new / "prepare.py")], cwd=ROOT, check=True)
subprocess.run([sys.executable, str(new / "seal_preparation.py")], cwd=ROOT, check=True)
