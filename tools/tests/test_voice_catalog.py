"""Production speech identity, speaker attribution, exclusions and freeze safety."""
from pathlib import Path
import copy
import hashlib
import json
import re
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/voice"))
import catalog
import intake


class VoiceCatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ("dialogue", "mystery", "opinions", "voice"):
            (self.root / "game/data" / directory).mkdir(parents=True)
        self.registry = intake.load_profiles(intake.PROFILES)
        # Catalog tests inspect attribution, not a machine's external audio bank.
        for profile in self.registry["profiles"].values():
            if profile["delivery"] == "spoken" and not profile.get("variants"):
                profile["reference"] = {"file": profile["id"] + ".wav", "sha256": "a" * 64, "text": "Fixture."}
        self.registry["profiles"]["lily"]["reference"] = None
        persisted = copy.deepcopy(self.registry)
        persisted["profiles"] = list(persisted["profiles"].values())
        self.write("voice/voice_profiles.json", persisted)
        self.write("case01_dialogue.json", {"nodes": {"fs_fixture": {"line": "A café.\nOne exact correction."}}})

    def write(self, relative, document):
        path = self.root / "game/data" / relative
        path.write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8")
        return path

    def tree(self, scope, resident, nodes, name=None):
        return self.write(f"{scope}/{name or resident}.json", {"meta": {"resident_id": resident}, "nodes": nodes})

    def lines(self, **kwargs):
        return catalog.build(self.root, self.registry, **kwargs)["lines"]

    def guest_fixture(self):
        text = "Tea. — Coffee."
        self.tree("dialogue", "cal_dwyer", {"guests": {"line": text, "speaker": "GUESTS"}})
        entry = {"source": "game/data/dialogue/cal_dwyer.json", "pointer": "/nodes/guests/line",
                 "text_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                 "turns": [{"start": 0, "end": 4, "profile_id": "transient_guest_a"},
                           {"start": text.index("Coffee"), "end": len(text), "profile_id": "transient_guest_b"}]}
        return text, {"entries": [entry]}

    def test_exact_text_pointer_and_explicit_speaker_overrides(self):
        text, guests = self.guest_fixture()
        path = self.root / "game/data/dialogue/cal_dwyer.json"
        document = intake.read_json(path)
        adela_text = "I meant ‘again.’\nNot an imitation."
        document["nodes"]["odd/name~id"] = {"line": adela_text, "speaker": "ADELA"}
        document["nodes"]["nadia"] = {"line": "It holds 3½ pounds.", "speaker": "NADIA"}
        path.write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")
        rows = {row["runtime_node_id"]: row for row in self.lines(guest_map=guests)}
        adela = rows["odd/name~id"]
        self.assertEqual(adela["profile_id"], "adela_voss")
        self.assertEqual(adela["pointer"], "/nodes/odd~1name~0id/line")
        self.assertEqual(adela["text"], adela_text)
        self.assertEqual(adela["segments"][0]["text"], adela_text)
        self.assertEqual(adela["text_sha256"], hashlib.sha256(adela_text.encode("utf-8")).hexdigest())
        self.assertEqual(rows["nadia"]["profile_id"], "nadia_quell")
        self.assertEqual(rows["guests"]["profile_id"], "transient_guests")
        self.assertEqual(rows["guests"]["text"], text)
        self.assertEqual([(part["profile_id"], part["text"]) for part in rows["guests"]["segments"]],
                         [("transient_guest_a", "Tea."), ("transient_guest_b", "Coffee.")])
        self.assertEqual(rows["fs_fixture"]["profile_id"], "mina_vale")

    def test_same_stem_and_node_in_base_and_mystery_remain_separate(self):
        self.tree("dialogue", "cal_dwyer", {"shared": {"line": "The first text."}})
        self.tree("mystery", "cal_dwyer", {"shared": {"line": "The second text."}})
        rows = {row["namespace"]: row for row in self.lines() if row["runtime_node_id"] == "shared"}
        self.assertEqual(rows["cal_dwyer"]["line_id"], "cal_dwyer__shared")
        self.assertEqual(rows["mystery_cal_dwyer"]["line_id"], "mystery_cal_dwyer__shared")
        self.assertNotEqual(rows["cal_dwyer"]["text_sha256"], rows["mystery_cal_dwyer"]["text_sha256"])

    def test_opinion_runtime_colon_ids_have_unique_safe_filenames(self):
        self.write("opinions/cal_dwyer.json", {"resident_id": "cal_dwyer", "hook_line": "Which part?",
                   "opinions": [{"id": "x", "line": "Main.", "silence_reply": "Still here.",
                                  "choices": [{"reply": "Answer."}]},
                                 {"id": "x_r0", "line": "Another opinion.", "choices": []}]})
        rows = [row for row in self.lines() if row["namespace"] == "opinion_cal_dwyer"]
        by_runtime = {row["runtime_node_id"]: row for row in rows}
        self.assertEqual(set(by_runtime), {"op_menu", "op:x", "op:x:s", "op:x:r0", "op:x_r0"})
        identities = [row["line_id"] for row in rows]
        self.assertEqual(len(identities), len(set(identities)))
        self.assertTrue(all(re.fullmatch(r"[a-z0-9_]+", identity) for identity in identities))
        self.assertNotEqual(by_runtime["op:x:r0"]["line_id"], by_runtime["op:x_r0"]["line_id"])

    def test_safe_node_encoding_cannot_collide_with_an_authored_safe_id(self):
        encoded = "encoded_" + "op:x".encode("utf-8").hex()
        self.assertNotEqual(catalog.safe_node("op:x"), catalog.safe_node(encoded))

    def test_missing_guest_map_stays_pending_and_changed_text_fails(self):
        text, guests = self.guest_fixture()
        pending = next(row for row in self.lines() if row["runtime_node_id"] == "guests")
        self.assertEqual(pending["state"], "turn_map_required")
        self.assertEqual(pending["segments"], [])
        self.assertEqual(pending["text"], text)
        ready = next(row for row in self.lines(guest_map=guests) if row["runtime_node_id"] == "guests")
        self.assertEqual(ready["state"], "ready")
        self.tree("dialogue", "cal_dwyer", {"guests": {"line": text + " Changed.", "speaker": "GUESTS"}})
        with self.assertRaisesRegex(ValueError, "Stale guest turns"):
            self.lines(guest_map=guests)

    def test_changed_guest_offsets_cannot_duplicate_or_omit_words(self):
        text, guests = self.guest_fixture()
        for mutation in ("overlap", "past_end", "missing_word", "no_turns"):
            bad = copy.deepcopy(guests)
            turns = bad["entries"][0]["turns"]
            if mutation == "overlap":
                turns[0]["end"] = len(text)
            elif mutation == "past_end":
                turns[-1]["end"] = len(text) + 2
            elif mutation == "missing_word":
                turns[0]["start"] = 2
            else:
                turns.clear()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.lines(guest_map=bad)

    def test_unspoken_unmapped_and_reference_required_lines_never_get_parts(self):
        companion = self.registry["profiles"]["companion"]["display_name"]
        lily = self.registry["profiles"]["lily"]["display_name"]
        self.tree("dialogue", "cal_dwyer", {
            "written": {"line": "Read this.", "spoken": False, "delivery": "spoken"},
            "silent": {"line": "Pause here.", "delivery": "silent"},
            "punctuation": {"line": "... — ..."},
            "companion": {"line": "Handwritten words.", "speaker": companion},
            "lily": {"line": "Her own recording.", "speaker": lily},
            "unknown": {"line": "An uncast voice.", "speaker": "Unknown speaker"},
            "reel": {"line": "A recorded scene.", "speaker": "THE REEL"},
        })
        expected = {"written": "written", "silent": "silent", "punctuation": "silent",
                    "companion": "written", "lily": "reference_required", "unknown": "unmapped",
                    "reel": "recorded_scene_required"}
        rows = {row["runtime_node_id"]: row for row in self.lines()}
        for node, state in expected.items():
            with self.subTest(node=node):
                self.assertEqual(rows[node]["state"], state)
                self.assertEqual(rows[node]["segments"], [])

    def test_source_freeze_detects_changed_input_and_refuses_overwrite(self):
        source = self.tree("dialogue", "cal_dwyer", {"open": {"line": "Exact words."}})
        case = self.root / "frozen"
        frozen = catalog.freeze(self.root, case)
        catalog.verify_sources(self.root, frozen)
        original = (case / "catalog.json").read_bytes()
        with self.assertRaisesRegex(ValueError, "already exists"):
            catalog.freeze(self.root, case)
        self.assertEqual((case / "catalog.json").read_bytes(), original)
        changed = intake.read_json(source)
        changed["nodes"]["open"]["line"] = "Different words."
        source.write_text(json.dumps(changed), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Frozen speech source changed"):
            catalog.verify_sources(self.root, frozen)


if __name__ == "__main__":
    unittest.main()
