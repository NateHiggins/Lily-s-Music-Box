"""Exact source coverage and lossless editorial guest A/B speech spans."""
from pathlib import Path
import copy
import hashlib
import json
import unittest


ROOT = Path(__file__).resolve().parents[2]
MAP = ROOT / "game/data/voice/guest_turns.json"
SOURCES = {f"game/data/{scope}/transient_guests.json"
           for scope in ("dialogue", "mystery", "opinions")}
SOURCES.add("game/data/mystery/rhea_sato.json")
VOICES = {"transient_guest_a", "transient_guest_b"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def resolve(document, pointer):
    current = document
    for token in pointer.lstrip("/").split("/"):
        key = token.replace("~1", "/").replace("~0", "~")
        current = current[int(key)] if isinstance(current, list) else current[key]
    return current


def validate_entry(entry, text):
    if entry["length"] != len(text) or entry["text_sha256"] != hashlib.sha256(text.encode("utf-8")).hexdigest():
        raise ValueError("Source text changed")
    pieces = []
    previous = -1
    for turn in entry["turns"]:
        start, end = turn["start"], turn["end"]
        if type(start) is not int or type(end) is not int or not 0 <= start < end <= len(text) or start < previous:
            raise ValueError("Unsafe or unordered turn offsets")
        if turn["profile_id"] not in VOICES:
            raise ValueError("Unknown guest voice")
        if not any(c.isalnum() for c in text[start:end]) or "\u2014" in text[start:end]:
            raise ValueError("A spoken turn needs words and no turn delimiter")
        previous = end
        pieces.append((start, end))
    previous = -1
    for gap in entry["gaps"]:
        start, end = gap["start"], gap["end"]
        if type(start) is not int or type(end) is not int or not 0 <= start < end <= len(text) or start < previous:
            raise ValueError("Unsafe or unordered gap offsets")
        if gap["kind"] != "separator_or_pause" or any(c.isalnum() for c in text[start:end]):
            raise ValueError("A gap omits spoken text")
        previous = end
        pieces.append((start, end))
    cursor = 0
    for start, end in sorted(pieces):
        if start != cursor:
            raise ValueError("Overlapping or missing source span")
        cursor = end
    if cursor != len(text):
        raise ValueError("Source tail missing")


class GuestTurnMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.map = load(MAP)
        cls.documents = {source: load(ROOT / source) for source in SOURCES}

    def test_source_freeze_is_portable_and_unchanged(self):
        self.assertEqual(self.map["schema_version"], 1)
        self.assertEqual(set(self.map["sources"]), SOURCES)
        for source, proof in self.map["sources"].items():
            with self.subTest(source=source):
                normalized = (ROOT / source).read_bytes().replace(b"\r\n", b"\n")
                self.assertEqual(hashlib.sha256(normalized).hexdigest(), proof["sha256_lf"])

    def test_every_authored_speech_field_has_exactly_one_entry(self):
        expected = set()
        for source, document in self.documents.items():
            if "nodes" in document:
                expected.update((source, "/nodes/" + key.replace("~", "~0").replace("/", "~1") + "/line")
                                for key, node in document["nodes"].items() if "line" in node
                                and (source.endswith("/transient_guests.json") or node.get("speaker") == "GUESTS"))
            else:
                if "hook_line" in document:
                    expected.add((source, "/hook_line"))
                for i, opinion in enumerate(document["opinions"]):
                    prefix = f"/opinions/{i}"
                    expected.add((source, prefix + "/line"))
                    if "silence_reply" in opinion:
                        expected.add((source, prefix + "/silence_reply"))
                    expected.update((source, f"{prefix}/choices/{j}/reply")
                                    for j, choice in enumerate(opinion.get("choices", [])) if "reply" in choice)
        actual = [(entry["source"], entry["pointer"]) for entry in self.map["entries"]]
        self.assertEqual(len(actual), len(set(actual)), "Duplicate guest speech entry")
        self.assertEqual(set(actual), expected)

    def test_all_words_and_separators_reconstruct_the_exact_source(self):
        for entry in self.map["entries"]:
            with self.subTest(source=entry["source"], pointer=entry["pointer"]):
                text = resolve(self.documents[entry["source"]], entry["pointer"])
                validate_entry(entry, text)
                spans = sorted((piece["start"], piece["end"])
                               for piece in entry["turns"] + entry["gaps"])
                self.assertEqual("".join(text[start:end] for start, end in spans), text)

    def test_only_distinct_approved_guest_profiles_are_used(self):
        profiles = {row["id"]: row for row in load(ROOT / "game/data/voice/voice_profiles.json")["profiles"]}
        used = {turn["profile_id"] for entry in self.map["entries"] for turn in entry["turns"]}
        self.assertEqual(used, VOICES)
        hashes = set()
        for key in VOICES:
            self.assertEqual(profiles[key]["delivery"], "spoken")
            self.assertRegex(profiles[key]["reference"]["sha256"], r"^[0-9a-f]{64}$")
            hashes.add(profiles[key]["reference"]["sha256"])
        self.assertEqual(len(hashes), 2)

    def test_staying_guest_keeps_her_drawer_and_choice(self):
        for node, phrase, voice in (("tg_drawer", "Mine. One jumper", "transient_guest_a"),
                                    ("tg_choose", "I heard. ... Stay.", "transient_guest_a"),
                                    ("tg_choose", "I'd like to stay.", "transient_guest_a"),
                                    ("tg_choose", "I'd like to go.", "transient_guest_b")):
            entry = next(row for row in self.map["entries"]
                         if row["source"] == "game/data/dialogue/transient_guests.json"
                         and row["pointer"] == f"/nodes/{node}/line")
            text = resolve(self.documents[entry["source"]], entry["pointer"])
            turn = next(turn for turn in entry["turns"] if phrase in text[turn["start"]:turn["end"]])
            self.assertEqual(turn["profile_id"], voice)

    def test_stale_text_missing_words_overlap_and_unknown_voice_fail(self):
        original = self.map["entries"][0]
        text = resolve(self.documents[original["source"]], original["pointer"])
        with self.assertRaisesRegex(ValueError, "Source text changed"):
            validate_entry(original, text + " Changed.")
        bad = copy.deepcopy(original)
        bad["turns"][0]["profile_id"] = "transient_guests"
        with self.assertRaisesRegex(ValueError, "Unknown guest voice"):
            validate_entry(bad, text)
        bad = copy.deepcopy(original)
        bad["turns"][0]["end"] -= 1
        with self.assertRaisesRegex(ValueError, "missing source span"):
            validate_entry(bad, text)
        bad = copy.deepcopy(original)
        bad["turns"][1]["start"] = bad["turns"][0]["end"] - 1
        with self.assertRaises(ValueError):
            validate_entry(bad, text)
        bad = copy.deepcopy(original)
        bad["turns"].pop(0)
        bad["gaps"].insert(0, {"start": 0, "end": original["turns"][0]["end"], "kind": "separator_or_pause"})
        with self.assertRaisesRegex(ValueError, "omits spoken text"):
            validate_entry(bad, text)


if __name__ == "__main__":
    unittest.main()
