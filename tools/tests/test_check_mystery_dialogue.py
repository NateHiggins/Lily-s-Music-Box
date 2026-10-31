"""The mystery drafts pass their own checker, and the checker can fail."""
from __future__ import annotations

import json
import pathlib
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import check_mystery_dialogue as checker  # noqa: E402


class MysteryDialogueTests(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.folder = pathlib.Path(self._dir.name) / "drafts"
        shutil.copytree(checker.DRAFTS, self.folder)

    def tearDown(self):
        self._dir.cleanup()

    def edit(self, name, change):
        path = self.folder / f"{name}.json"
        doc = json.loads(path.read_text(encoding="utf8"))
        change(doc)
        path.write_text(json.dumps(doc), encoding="utf8")

    def failures(self):
        return "\n".join(checker.run(self.folder)[0])

    def test_the_drafts_pass(self):
        self.assertEqual(checker.run()[0], [])

    def test_a_resident_may_not_call_the_player_sir(self):
        self.edit("cam_ortiz", lambda d: d["nodes"]["co_e2"].update(line="Yes, sir."))
        self.assertIn("misaddresses the player", self.failures())

    def test_a_modern_term_fails(self):
        data = self.folder.parent / "data"
        (data / "dialogue").mkdir(parents=True)
        (data / "dialogue" / "x.json").write_text('{"line": "She was transgender."}', encoding="utf8")
        self.assertIn("transgender", "\n".join(checker.check_modern_terms(data)))

    def test_the_game_text_has_no_modern_terms(self):
        self.assertEqual(checker.check_modern_terms(checker.ROOT / "game/data"), [])

    def test_a_flag_nothing_grants_fails(self):
        self.edit("cam_ortiz", lambda d: d["threads"][0].update(requires=["m_nobody_grants_this"]))
        self.assertIn("m_nobody_grants_this", self.failures())

    def test_a_living_thread_may_not_speak_from_after_her_death(self):
        self.edit("adela_voss", lambda d: d["nodes"]["av_d3"].update(line="They found the body."))
        self.assertIn("speaks from after her death", self.failures())

    def test_a_withheld_bank_line_fails(self):
        self.edit("rhea_sato", lambda d: d["nodes"]["rs_s2"].update(bank="JF027-A01"))
        self.assertIn("excluded bank line", self.failures())

    def test_a_choice_without_silence_fails(self):
        self.edit("cam_ortiz", lambda d: d["nodes"]["co_e1"].pop("silence_goto"))
        self.assertIn("no authored silence", self.failures())

    def test_a_requirement_cycle_is_caught(self):
        self.edit("cam_ortiz", lambda d: next(t for t in d["threads"] if t["id"] == "co_route").update(requires=["m_route_book"]))
        self.assertIn("can never open", self.failures())

    def test_the_letter_needs_the_route_book(self):
        def strip(doc):
            for node in doc["nodes"].values():
                if node.get("flag") == "m_route_book":
                    del node["flag"]
        self.edit("cam_ortiz", strip)
        self.assertIn("m_route_book", self.failures())


if __name__ == "__main__":
    unittest.main()
