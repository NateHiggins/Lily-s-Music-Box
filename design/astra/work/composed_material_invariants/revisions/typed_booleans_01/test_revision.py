from pathlib import Path
import hashlib
import json
import unittest

HERE = Path(__file__).resolve().parent
REL = Path("game/tests/vulkan_composed_root_test.gd")


class ExplicitBooleanRevisionControls(unittest.TestCase):
    def test_only_eight_exact_declarations_change(self):
        receipt = json.loads((HERE / "preparation.json").read_text())
        old = (HERE / "originals" / REL).read_bytes()
        new = (HERE / "proposed" / REL).read_bytes()
        self.assertEqual(hashlib.sha256(old).hexdigest(), receipt["original_fixture_sha256"])
        self.assertEqual(hashlib.sha256(new).hexdigest(), receipt["fixture_sha256"])
        lines = old.decode().splitlines(keepends=True)
        self.assertEqual(len(receipt["changed_declarations"]), 8)
        for change in receipt["changed_declarations"]:
            index = change["line"] - 1
            self.assertEqual(lines[index].rstrip(), change["before"])
            lines[index] = lines[index].replace(f'var {change["name"]} :=', f'var {change["name"]}: bool =', 1)
        self.assertEqual("".join(lines).encode(), new)

    def test_helpers_receive_identical_declaration_changes_only(self):
        receipt = json.loads((HERE / "preparation.json").read_text())
        old = (HERE / "originals/material_helpers.gdfragment").read_text()
        new = (HERE / "proposed/material_helpers.gdfragment").read_text()
        for change in receipt["changed_declarations"]:
            self.assertEqual(old.count(change["before"]), 1)
            old = old.replace(change["before"], change["after"], 1)
        self.assertEqual(old, new)

    def test_every_original_assertion_and_transition_body_unchanged(self):
        old = (HERE / "originals" / REL).read_text()
        new = (HERE / "proposed" / REL).read_text()
        self.assertEqual([line for line in old.splitlines() if "_check(" in line],
                         [line for line in new.splitlines() if "_check(" in line])
        self.assertEqual(old.split("func _transition(", 1)[1].split("\nfunc _check_zone(", 1)[0],
                         new.split("func _transition(", 1)[1].split("\nfunc _check_zone(", 1)[0])


if __name__ == "__main__":
    unittest.main()
