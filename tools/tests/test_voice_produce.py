"""Portable failure and provenance checks for bounded offline voice production."""
from pathlib import Path
import array
import copy
import json
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "voice"))
import produce


class VoiceProduceTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.case = self.root / "case"
        self.case.mkdir()
        self.refs = self.root / "references"
        self.refs.mkdir()
        self.reference = self.refs / "alpha.wav"
        self.wav(self.reference)
        self.registry = {"profiles": {"alpha": {
            "delivery": "spoken", "seed": 117,
            "reference": {"file": self.reference.name,
                          "sha256": produce.intake.fingerprint(self.reference),
                          "text": "The reference words."}}}}
        self.backend = self.root / "fake_backend.py"
        self.backend.write_text("# Source fingerprint fixture; never executed.\n", encoding="utf-8")
        produce.write(self.case / "catalog.json", {"sources": [], "lines": []})

    def wav(self, path, values=(1000, -2000, 3000, -1000), channels=1, width=2):
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), "wb") as target:
            target.setnchannels(channels)
            target.setsampwidth(width)
            target.setframerate(24000)
            target.writeframes(array.array("h", values).tobytes() if width == 2 else bytes(values))

    def part(self, identity="alpha_1", text="Exact authored words.", profile="alpha"):
        selected = self.registry["profiles"][profile]
        return {"part_id": identity, "profile_id": profile, "text": text,
                "text_sha256": produce.catalog.text_hash(text),
                "reference_sha256": selected["reference"]["sha256"], "seed": selected["seed"]}

    def install_completed(self, part):
        target = self.case / "parts" / (part["part_id"] + ".wav")
        self.wav(target)
        produce.write(target.with_suffix(".record.json"), {
            "input": part, "wav_sha256": produce.intake.fingerprint(target)})
        return target

    def test_parts_deduplicate_only_exact_words_in_the_same_selected_voice(self):
        self.registry["profiles"]["beta"] = copy.deepcopy(self.registry["profiles"]["alpha"])
        document = {"lines": [{"segments": [
            {"part_id": "alpha_first", "profile_id": "alpha", "text": "Stay."},
            {"part_id": "alpha_alias", "profile_id": "alpha", "text": "Stay."},
            {"part_id": "beta_first", "profile_id": "beta", "text": "Stay."},
            {"part_id": "alpha_whitespace", "profile_id": "alpha", "text": "Stay.\n"}]}]}
        parts = produce.make_parts(document, self.registry)
        self.assertEqual([p["part_id"] for p in parts],
                         ["alpha_first", "beta_first", "alpha_whitespace"])
        self.assertEqual(document["lines"][0]["segments"][1]["part_id"], "alpha_first")
        self.assertEqual(parts[0]["reference_sha256"], self.registry["profiles"]["alpha"]["reference"]["sha256"])
        changed = copy.deepcopy(self.registry)
        changed["profiles"]["alpha"]["reference"]["sha256"] = "e" * 64
        replanned = produce.make_parts(copy.deepcopy(document), changed)
        self.assertNotEqual(parts[0]["reference_sha256"], replanned[0]["reference_sha256"])

    def test_batches_obey_part_and_word_caps_without_mixing_voices(self):
        self.registry["profiles"]["beta"] = copy.deepcopy(self.registry["profiles"]["alpha"])
        parts = [self.part("a1", "one two"), self.part("b1", "other", "beta"),
                 self.part("a2", "three four five"), self.part("a3", "six")]
        selected = produce.next_batch(parts, set(), max_parts=2, max_words=5)
        self.assertEqual([p["part_id"] for p in selected], ["a1", "a2"])
        self.assertEqual({p["profile_id"] for p in selected}, {"alpha"})
        self.assertLessEqual(sum(len(p["text"].split()) for p in selected), 5)
        self.assertEqual([p["part_id"] for p in produce.next_batch(parts, set(), 6, 4)], ["a1"])
        self.assertEqual([p["part_id"] for p in produce.next_batch(parts, {"a1"})], ["b1"])
        self.assertEqual(produce.next_batch(parts, {p["part_id"] for p in parts}), [])

    def test_single_long_authored_line_is_not_split_or_mixed(self):
        part = self.part(text=" ".join(["word"] * 261))
        self.assertEqual(produce.next_batch([part, self.part("next", "short")], set(), max_words=260), [part])

    def test_completed_parts_reject_changed_words_reference_or_audio(self):
        part = self.part()
        path = self.install_completed(part)
        self.assertTrue(produce.validate_part(self.case, part))
        for field, value in (("text", "Changed words."), ("reference_sha256", "f" * 64), ("seed", 118)):
            altered = {**part, field: value}
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "Changed completed"):
                produce.validate_part(self.case, altered)
        self.wav(path, values=(2000, 2000))
        with self.assertRaisesRegex(ValueError, "Changed completed"):
            produce.validate_part(self.case, part)
        self.assertFalse(produce.validate_part(self.case, self.part("missing")))

    def test_wave_inspection_rejects_empty_silent_clipped_and_non_pcm16_mono(self):
        path = self.root / "sample.wav"
        self.wav(path)
        metrics = produce.inspect_wav(path)
        self.assertEqual(metrics["sample_rate"], 24000)
        self.assertGreater(metrics["seconds"], 0)
        for samples, channels, width in (((), 1, 2), ((0, 0), 1, 2),
                                          ((32767, 1), 1, 2), ((-32768, 1), 1, 2),
                                          ((100, -100), 2, 2), ((127, 128), 1, 1)):
            with self.subTest(samples=samples, channels=channels, width=width):
                self.wav(path, samples, channels, width)
                with self.assertRaises(ValueError):
                    produce.inspect_wav(path)
        # A well-formed RIFF header declaring mu-law, rather than PCM.
        fmt = struct.pack("<HHIIHH", 7, 1, 24000, 24000, 1, 8)
        chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", 2) + b"\x80\x81"
        path.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
        with self.assertRaises((ValueError, wave.Error)):
            produce.inspect_wav(path)

    def native_stub(self, count, code, metadata_update=None):
        def launch(command, **kwargs):
            runs = produce.intake.read_json(Path(command[command.index("-BatchFile") + 1]))
            job = produce.intake.read_json(Path(runs[0]["gpu"][-1]))
            for text, name in list(zip(job["texts"], job["paths"]))[:count]:
                path = Path(name)
                self.wav(path)
                metadata = {"text": text, "kind": "clone", "ref_text": job["ref_text"],
                            "like": job["like"], "seed": job["seed"], "sample_rate": 24000}
                metadata.update(metadata_update or {})
                produce.write(path.with_suffix(".json"), metadata)
            return SimpleNamespace(pid=987654, wait=lambda: code)
        return launch

    def generate(self, batch, count=None, code=0, metadata_update=None):
        with patch.object(produce, "BACKEND", self.backend), \
             patch.object(produce, "wait_medium") as wait, \
             patch.object(produce.catalog, "verify_sources") as verify, \
             patch.object(produce.subprocess, "Popen", side_effect=self.native_stub(
                 len(batch) if count is None else count, code, metadata_update)) as process:
            try:
                return produce.generate_batch(self.root, self.case, self.registry, batch, self.refs)
            finally:
                self.assertEqual(wait.call_count, 1)
                self.assertEqual(verify.call_count, 1)
                self.assertEqual(process.call_count, 1)

    def test_failed_native_batch_retains_success_and_resume_cannot_overwrite_it(self):
        first, second = self.part("first"), self.part("second", "Another line.")
        with self.assertRaisesRegex(ValueError, "Partial/failed batch"):
            self.generate([first, second], count=1, code=1)
        self.assertTrue(produce.validate_part(self.case, first))
        self.assertFalse(produce.validate_part(self.case, second))
        accepted = self.case / "parts" / "first.wav"
        before = accepted.read_bytes()
        receipt = accepted.with_suffix(".record.json").read_bytes()
        pending = produce.next_batch([first, second], {"first"})
        self.assertEqual(pending, [second])
        self.generate(pending)
        self.assertTrue(produce.validate_part(self.case, second))
        self.assertEqual(accepted.read_bytes(), before)
        self.assertEqual(accepted.with_suffix(".record.json").read_bytes(), receipt)
        with self.assertRaisesRegex(ValueError, "Refusing to overwrite"):
            self.generate([first])
        self.assertEqual(accepted.read_bytes(), before)
        self.assertEqual(accepted.with_suffix(".record.json").read_bytes(), receipt)
        attempts = list((self.case / "attempts").glob("batch_*"))
        self.assertEqual(len(attempts), 3)
        self.assertTrue(any((attempt / "first.wav").exists() for attempt in attempts))

    def test_wrong_generated_words_never_install_a_part(self):
        part = self.part()
        with self.assertRaisesRegex(ValueError, "Generation words/reference mismatch"):
            self.generate([part], metadata_update={"text": "Not the requested words."})
        self.assertFalse(produce.validate_part(self.case, part))
        self.assertFalse((self.case / "parts" / (part["part_id"] + ".wav")).exists())

    def test_reference_changed_during_native_generation_never_installs_audio(self):
        part = self.part()
        spawn = self.native_stub(1, 0)

        def altered_reference(command, **kwargs):
            process = spawn(command, **kwargs)
            self.reference.write_bytes(b"Reference replaced while GPU job ran.")
            return process

        with patch.object(produce, "BACKEND", self.backend), \
             patch.object(produce, "wait_medium"), \
             patch.object(produce.catalog, "verify_sources"), \
             patch.object(produce.subprocess, "Popen", side_effect=altered_reference):
            with self.assertRaisesRegex(ValueError, "Reference changed"):
                produce.generate_batch(self.root, self.case, self.registry, [part], self.refs)
        self.assertFalse(produce.validate_part(self.case, part))
        self.assertTrue(any((attempt / (part["part_id"] + ".wav")).exists()
                            for attempt in (self.case / "attempts").iterdir()))

    def test_wrong_clone_reference_seed_or_sample_rate_never_install_audio(self):
        part = self.part()
        for bad in ({"like": str(self.root / "another_reference.wav")},
                    {"seed": 118}, {"sample_rate": 16000}):
            with self.subTest(metadata=bad), self.assertRaises(ValueError):
                self.generate([part], metadata_update=bad)
            self.assertFalse(produce.validate_part(self.case, part))


if __name__ == "__main__":
    unittest.main()
