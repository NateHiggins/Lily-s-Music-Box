"""Bounded parser/hash/index controls. Never add, reset, commit, or run Godot."""
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

import prepare_checkpoint as checkpoint


class CheckpointControls(unittest.TestCase):
    def test_git_blob_oracle_preserves_mixed_evidence_bytes(self):
        raw = b"original\r\nretained\n\x00binary\xff"
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "evidence.bin"
            p.write_bytes(raw)
            row = checkpoint.hashes(p)
        oracle = subprocess.check_output(["git", "hash-object", "--no-filters", "--stdin"], input=raw).decode().strip()
        self.assertEqual(row["git_blob"], oracle)
        self.assertEqual(row["raw_sha256"], hashlib.sha256(raw).hexdigest())

    def test_lf_review_guard_rejects_hidden_clean_conversion(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "review.md"
            p.write_bytes(b"retained\r\n")
            with self.assertRaisesRegex(ValueError, "plain LF"):
                checkpoint.hashes(p, require_lf=True)

    def test_profiles_caches_and_path_escape_are_rejected(self):
        for name in ["../game.gd", "/game.gd", "C:/game.gd", "a/../game", "a\\b", "a\nfile", "a\0file",
                     "evidence/APPDATA/log", "evidence/userdata_01/save", "work/__pycache__/x.pyc", "work/.godot/cache", "work/cache/x"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                checkpoint.safe_relative(name)

    def test_literal_payload_keeps_patch_metacharacters(self):
        paths = ["work/a[1].patch", "work/--historical.py", "work/name with space.json"]
        self.assertEqual(checkpoint.payload(paths).split(b"\0")[:-1], [p.encode() for p in sorted(paths)])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            checkpoint.payload([paths[0], paths[0]])

    def test_index_parser_retains_mode_and_rejects_unmerged(self):
        oid = "a" * 40
        self.assertEqual(checkpoint.parse_index(("100644 " + oid + " 0\twork/a[1].patch\0").encode()),
                         {"work/a[1].patch": {"mode": "100644", "blob": oid}})
        with self.assertRaisesRegex(ValueError, "unmerged"):
            checkpoint.parse_index(("100644 " + oid + " 2\tx\0").encode())

    def test_intent_to_add_is_not_an_empty_index(self):
        with self.assertRaisesRegex(ValueError, "intent-to-add"):
            checkpoint.require_head_index({}, {"x": {"mode": "100644", "blob": "0" * 40}})

    def specimen(self):
        heads = {"same": {"mode": "100644", "blob": "a"}, "changed": {"mode": "100644", "blob": "b"},
                 "foreign": {"mode": "100644", "blob": "f"}}
        before = {p: r.copy() for p, r in heads.items()}
        after = {p: r.copy() for p, r in heads.items()}
        after["changed"]["blob"] = "c"
        after["new"] = {"mode": "100644", "blob": "n"}
        rows = {"same": {"git_blob": "a"}, "changed": {"git_blob": "c"}, "new": {"git_blob": "n"}}
        return rows, heads, before, after

    def test_unchanged_named_path_is_verified_but_not_claimed_changed(self):
        expected, issues = checkpoint.staged_issues(*self.specimen(), ["changed", "new"])
        self.assertEqual(expected, ["changed", "new"])
        self.assertEqual(issues, [])

    def test_foreign_index_adoption_is_rejected(self):
        rows, heads, before, after = self.specimen()
        after["foreign"]["blob"] = "x"
        self.assertIn("unselected index entry changed: foreign", checkpoint.staged_issues(rows, heads, before, after, ["changed", "foreign", "new"])[1])

    def test_evidence_line_normalization_or_blob_drift_is_rejected(self):
        rows, heads, before, after = self.specimen()
        after["new"]["blob"] = "different"
        self.assertIn("staged blob differs: new", checkpoint.staged_issues(rows, heads, before, after, ["changed", "new"])[1])

    def test_silent_mode_change_is_rejected(self):
        rows, heads, before, after = self.specimen()
        after["same"]["mode"] = "100755"
        self.assertIn("staged file mode differs: same", checkpoint.staged_issues(rows, heads, before, after, ["changed", "new", "same"])[1])

    def test_missing_selected_index_entry_is_rejected(self):
        rows, heads, before, after = self.specimen()
        del after["new"]
        self.assertIn("staged blob differs: new", checkpoint.staged_issues(rows, heads, before, after, ["changed"])[1])


if __name__ == "__main__":
    unittest.main()
