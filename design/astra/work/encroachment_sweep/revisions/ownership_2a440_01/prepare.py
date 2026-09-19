"""Prepare the one-census delta atop exact floor ownership, outside live game."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())
WORK = ROOT / "design/astra/work"
REL = Path("game/scripts/reality/apartment_encroachment.gd")
SOURCE = WORK / "apartment_floor_ownership_01/proposed" / REL
EXPECTED = "2a440504ab80404f4d9f4ab16138df7db9255801ca879ff91aabafe3c7f4d0ca"
SWEEP = WORK / "encroachment_sweep"
OLD_EQ = SWEEP / "equivalence_revisions/ownership_7c54c_01"
NEW_EQ = SWEEP / "equivalence_revisions/ownership_2a440_01"
START = "func reach_props(root: Node) -> int:\n"
END = "\n\n## Resolve all declared floor roots"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_new(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    assert not path.exists(), f"preserve existing preparation: {path}"
    path.write_bytes(data)


def main():
    raw = SOURCE.read_bytes()
    assert digest(raw) == EXPECTED
    original = raw.decode().replace("\r\n", "\n")
    method = (SWEEP / "revisions/ownership_7c54c_01/reach_props.gdfragment").read_text(encoding="utf-8")
    assert method.count("\tprops_reached = 0\n") == 1
    method = method.replace("\tprops_reached = 0\n", "\tprops_reached = 0\n\tvar floor_owners := _prop_floor_owners()\n", 1)
    old_known = '\t\t\tif rows_by_case.has(owner_id):\n'
    new_known = ('\t\t\tif rows_by_case.has(owner_id) and _prop_matches_floor(mi,\n'
                 '\t\t\t\t\t(units[owner_id] as Dictionary).floor_node, floor_owners):\n')
    assert method.count(old_known) == 1
    method = method.replace(old_known, new_known, 1)
    old_first = '\t\t\tvar unit: Dictionary = units[case_id]\n'
    new_first = (old_first + '\t\t\tif not _prop_matches_floor(mi, unit.floor_node, floor_owners):\n'
                 '\t\t\t\tcontinue\n')
    assert method.count(old_first) == 1
    method = method.replace(old_first, new_first, 1)
    method = method.replace("# when bounds overlap. Existing case metadata keeps its original authority.",
        "# when bounds overlap. Existing metadata retains authority within its real floor.")
    a = original.index(START)
    b = original.index(END, a)
    proposed = original[:a] + method.rstrip() + original[b:]
    assert proposed[proposed.index(END):] == original[b:]
    write_new(HERE / "originals" / REL, raw)
    write_new(HERE / "proposed" / REL, proposed.encode())
    write_new(HERE / "reach_props.gdfragment", method.encode())
    patch = "".join(difflib.unified_diff(original.splitlines(True), proposed.splitlines(True),
        fromfile="a/" + REL.as_posix(), tofile="b/" + REL.as_posix()))
    write_new(HERE / "encroachment_sweep.patch", patch.encode())
    binding = {"status": "PREPARED_NOT_INSTALLED_ENGINE_UNRUN", "source": str(SOURCE),
        "file": REL.as_posix(), "sha256": {"originals": digest(raw), "proposed": digest(proposed.encode())},
        "scope": "Only reach_props changes. Floor providers and both admission paths retained; one fresh mesh census per call. No persistent cache or callback suppression.",
        "preserved_historical_revision": "ownership_7c54c_01"}
    write_new(HERE / "preparation.json", (json.dumps(binding, indent=2) + "\n").encode())

    # Reuse the unchanged specimen, its exact ordered contract and gate.
    for rel in ("gate.py", "test_gate.py", "expected_check_contract.json",
                "proposed/game/tests/encroachment_sweep_equivalence_test.gd",
                "proposed/game/tests/EncroachmentSweepEquivalenceTest.tscn"):
        write_new(NEW_EQ / rel, (OLD_EQ / rel).read_bytes())
    prep = (OLD_EQ / "prepare.py").read_text(encoding="utf-8")
    prep = prep.replace("ownership_7c54c_01", "ownership_2a440_01").replace(
        "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db", EXPECTED)
    prep = prep.replace('END = "\\n\\nfunc _apply_prop_states"', 'END = "\\n\\n## Resolve all declared floor roots"')
    write_new(NEW_EQ / "prepare.py", prep.encode())
    write_new(NEW_EQ / "test_prepare.py", (OLD_EQ / "test_prepare.py").read_bytes())
    print(json.dumps(binding, indent=2))


if __name__ == "__main__":
    main()
