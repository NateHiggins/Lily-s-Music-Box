"""Portable line identities, reference voices and failure-safe Rhubarb intake."""
from pathlib import Path
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "voice"))
import intake


class VoiceIntakeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dialogue = self.root / "dialogue"
        self.dialogue.mkdir()
        self.registry = intake.load_profiles(intake.PROFILES)

    def tree(self, name="cal_dwyer", nodes=None):
        path = self.dialogue / (name + ".json")
        path.write_text(json.dumps({"meta": {"speaker_default": "CAL DWYER"},
                                    "nodes": nodes or {"open": {"line": "Listen."}}}), encoding="utf-8")
        return path

    def test_ids_survive_reordering_and_distinguish_trees(self):
        path = self.tree(nodes={"b": {"line": "Second."}, "a": {"line": "First.\nStill first."}})
        first = intake.recording_lines(self.dialogue, self.registry)
        doc = intake.read_json(path)
        doc["nodes"] = dict(reversed(list(doc["nodes"].items())))
        path.write_text(json.dumps(doc), encoding="utf-8")
        self.assertEqual(first, intake.recording_lines(self.dialogue, self.registry))
        self.assertEqual(first[0]["text"], "First.\nStill first.")
        self.assertNotEqual(intake.line_id("cal_dwyer", "open"), intake.line_id("stacy", "open"))
        for tree, node in (("a__b", "c"), ("a", "b/c"), ("a", "../b"), ("a", "A")):
            with self.assertRaises(ValueError):
                intake.line_id(tree, node)

    def test_duplicate_json_nodes_are_rejected(self):
        self.tree().write_text('{"nodes":{"open":{"line":"One"},"open":{"line":"Two"}}}', encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            intake.recording_lines(self.dialogue, self.registry)

    def test_written_messages_and_explicit_silence_have_no_recording_name(self):
        (self.dialogue / "companion.json").write_text(json.dumps({"lines": [{"id": "hello", "text": "Hello."}]}))
        self.tree(nodes={"quiet": {"line": "...", "delivery": "silent"}})
        rows = intake.recording_lines(self.dialogue, self.registry)
        self.assertEqual({row["delivery"] for row in rows}, {"written", "silent"})
        self.assertTrue(all(row["wav_filename"] == "" for row in rows))

    def test_speaker_override_selects_its_own_voice(self):
        self.tree(nodes={"answer": {"line": "Tea?", "speaker": "STACY"}})
        row = intake.recording_lines(self.dialogue, self.registry)[0]
        self.assertEqual(row["profile_id"], "stacy")
        self.assertEqual(row["speaker"], "STACY")

    def test_selected_reference_requires_exact_bytes_and_uses_clone_mode(self):
        reference = self.root / "cal.wav"
        reference.write_bytes(b"a test reference")
        profile = self.registry["profiles"]["cal_dwyer"]
        profile["reference"].update(file="cal.wav", sha256=intake.fingerprint(reference))
        with self.assertRaisesRegex(ValueError, "reference-root"):
            intake.voice_request(self.registry, "cal_dwyer", "Listen.")
        request = intake.voice_request(self.registry, "cal_dwyer", "Listen.", self.root)
        self.assertEqual(request["args"]["like"], str(reference.resolve()))
        self.assertNotIn("voice", request["args"])
        reference.write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "changed"):
            intake.voice_request(self.registry, "cal_dwyer", "Listen.", self.root)

    def test_requests_reuse_direction_and_seed_and_block_unvoiced_roles(self):
        first = intake.voice_request(self.registry, "mina_vale", "First line.")
        second = intake.voice_request(self.registry, "mina_vale", "Second line.")
        self.assertEqual(first["args"]["voice"], second["args"]["voice"])
        self.assertEqual(first["args"]["seed"], second["args"]["seed"])
        for actor in ("companion", "night_man", "transient_guests", "lily"):
            with self.subTest(actor=actor), self.assertRaises(ValueError):
                intake.voice_request(self.registry, actor, "A line.")

    def recordings(self):
        self.tree()
        directory = self.root / "wavs"
        directory.mkdir()
        (directory / "cal_dwyer__open.wav").write_bytes(b"fixture audio")
        return directory, intake.recording_lines(self.dialogue, self.registry)

    def good_result(self, cmd, **kwargs):
        target = Path(cmd[cmd.index("-o") + 1])
        self.assertEqual(cmd[cmd.index("--extendedShapes") + 1], "GHX")
        self.assertEqual(Path(cmd[cmd.index("-d") + 1]).read_text(encoding="utf-8"), "Listen.")
        target.write_text(json.dumps({"metadata": {"duration": 1, "soundFile": "/private/file.wav"},
                                      "mouthCues": [{"start": 0, "end": 1, "value": "X"}]}))
        return subprocess.CompletedProcess(cmd, 0, "", "")

    def test_alignment_writes_native_schema_with_portable_audio_name(self):
        directory, rows = self.recordings()
        output = self.root / "cues"
        with patch.object(intake.subprocess, "run", self.good_result):
            paths = intake.align_wavs(directory, output, rows, "rhubarb")
        doc = intake.read_json(paths[0])
        self.assertEqual(doc["metadata"]["soundFile"], "cal_dwyer__open.wav")
        self.assertEqual(doc["mouthCues"][0], {"start": 0, "end": 1, "value": "X"})
        self.assertEqual(list(output.iterdir()), paths)

    def test_failed_tool_preserves_prior_cues(self):
        directory, rows = self.recordings()
        output = self.root / "cues"
        output.mkdir()
        old = output / "cal_dwyer__open.cues.json"
        old.write_bytes(b"previous verified result")
        with patch.object(intake.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "bad WAV")):
            with self.assertRaisesRegex(ValueError, "bad WAV"):
                intake.align_wavs(directory, output, rows, "rhubarb")
        self.assertEqual(old.read_bytes(), b"previous verified result")
        self.assertEqual(list(output.iterdir()), [old])

    def test_unknown_recording_is_rejected_before_any_generation(self):
        directory, rows = self.recordings()
        (directory / "unexpected.wav").write_bytes(b"unknown")
        with patch.object(intake.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "Unknown"):
                intake.align_wavs(directory, self.root / "cues", rows, "rhubarb")
            run.assert_not_called()

    def test_recording_change_during_alignment_preserves_prior_cues(self):
        directory, rows = self.recordings()
        output = self.root / "cues"
        output.mkdir()
        old = output / "cal_dwyer__open.cues.json"
        old.write_bytes(b"previous verified result")

        def changed_recording(cmd, **kwargs):
            result = self.good_result(cmd, **kwargs)
            (directory / "cal_dwyer__open.wav").write_bytes(b"a new take")
            return result

        with patch.object(intake.subprocess, "run", changed_recording):
            with self.assertRaisesRegex(ValueError, "changed during"):
                intake.align_wavs(directory, output, rows, "rhubarb")
        self.assertEqual(old.read_bytes(), b"previous verified result")

    def test_recording_sheet_cli_roundtrips_exact_multiline_text(self):
        self.tree(nodes={"open": {"line": 'First line, "quoted".\nSecond line.'}})
        destination = self.root / "sheet.csv"
        result = subprocess.run([sys.executable, str(Path(intake.__file__)),
                                 "--dialogue-dir", str(self.dialogue), "sheet", "--out", str(destination)],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        with destination.open(encoding="utf-8-sig", newline="") as stream:
            rows = list(intake.csv.DictReader(stream))
        self.assertEqual(rows[0]["line_id"], "cal_dwyer__open")
        self.assertEqual(rows[0]["text"], 'First line, "quoted".\nSecond line.')

    def test_invalid_and_overlapping_mouth_cues_are_rejected(self):
        good = {"metadata": {"duration": 1}, "mouthCues": [{"start": 0, "end": 1, "value": "A"}]}
        intake.validate_cues(good)
        for field, value in (("start", -1), ("end", float("nan")), ("value", "Z")):
            doc = copy.deepcopy(good)
            doc["mouthCues"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                intake.validate_cues(doc)
        good["mouthCues"].append({"start": .5, "end": 1, "value": "B"})
        with self.assertRaises(ValueError):
            intake.validate_cues(good)

    def test_current_registry_covers_the_resident_roster(self):
        roster = intake.read_json(intake.ROOT / "game/data/resident_animation_profiles.json")
        self.assertTrue({actor["slug"] for actor in roster} <= self.registry["profiles"].keys())
        self.assertTrue(all(row["profile_id"] in self.registry["profiles"] for row in
                            intake.recording_lines(intake.ROOT / "game/data/dialogue", self.registry)))


if __name__ == "__main__":
    unittest.main()
