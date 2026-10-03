import copy
import json
import unittest

from oracle import guard
from oracle.backends import BackendError, Completion
from oracle.content import load_registry
from oracle.model import PlayerModel
from oracle.session import Session
from oracle.simulate import PERSONAS, gdv_difference, run_persona, summary
from oracle.synthesis import (PRONOUNCEMENT, build_draft, build_profile, synthesize, validate_design,
                              validate_prophecy)
from oracle.ui import ScriptedConsole


class PersonaTests(unittest.TestCase):
    """Two different ways of playing must produce two different games."""

    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.runs = {name: run_persona(cls.r, name, seed=1) for name in PERSONAS}

    def test_every_persona_finishes_with_a_complete_description(self):
        for name, run in self.runs.items():
            design, prophecy = run["synthesis"]["design"], run["synthesis"]["prophecy"]
            self.assertEqual(run["session"].phase, "done", name)
            self.assertEqual(len(design["design_signals"]["dominant"]), 3, name)
            self.assertEqual(set(design["game_design_vector"]), set(self.r.gdv_field_ids()), name)
            self.assertTrue(all(v.strip() for v in design["game_design_vector"].values()), name)
            self.assertGreaterEqual(len(design["design_implications"]), 4, name)
            self.assertGreaterEqual(len(design["negative_constraints"]), 2, name)
            self.assertTrue(design["personal_callbacks"], name)
            self.assertTrue(design["unrequested_feature"]["follows_from"], name)
            self.assertEqual(validate_prophecy(prophecy), [], name)
            self.assertEqual(prophecy["pronouncement"], PRONOUNCEMENT)
            self.assertTrue(5 <= len(prophecy["visions"]) <= 9, name)
            self.assertGreaterEqual(len(prophecy["recollections"]), 3, name)

    def test_different_players_get_different_games(self):
        names = list(self.runs)
        for i, a in enumerate(names):
            for b in names[i + 1:]:
                diff = gdv_difference(self.runs[a], self.runs[b])
                self.assertGreaterEqual(diff, 6, f"{a} and {b} differ in only {diff} design fields")
                sa, sb = summary(self.runs[a]), summary(self.runs[b])
                self.assertNotEqual(sa["dominant"], sb["dominant"], f"{a} and {b} share dominant signals")

    def test_the_caricatures_come_out_recognisable(self):
        model = self.runs["firestarter"]["model"]
        self.assertGreater(model.state("reward.transgression").value, 0)
        self.assertGreater(model.state("risk").value, 0)
        model = self.runs["cartographer"]["model"]
        self.assertLess(model.state("planning").value, 0)        # deliberative
        model = self.runs["speedrunner"]["model"]
        self.assertGreater(model.state("pacing").value, 0)       # relentless

    def test_the_unrequested_feature_follows_from_something_done(self):
        for name, run in self.runs.items():
            feature = run["synthesis"]["design"]["unrequested_feature"]
            self.assertTrue(feature["feature"] and feature["follows_from"], name)

    def test_visions_are_promises_with_something_behind_them(self):
        for name, run in self.runs.items():
            for vision in run["synthesis"]["prophecy"]["visions"]:
                self.assertTrue(vision["card"].strip() and vision["text"].strip(), name)
                self.assertTrue(vision.get("fulfils"), f"{name}: {vision['card']} has nothing to make it true")
            cards = [v["card"] for v in run["synthesis"]["prophecy"]["visions"]]
            self.assertEqual(len(cards), len(set(cards)), f"{name}: a card was dealt twice")

    def test_same_seed_same_night(self):
        again = run_persona(self.r, "host", seed=1)
        self.assertEqual(summary(again), summary(self.runs["host"]))

    def test_profile_has_the_shape_a_builder_reads(self):
        run = self.runs["tinkerer"]
        profile = build_profile(self.r, run["model"], run["session"], run["synthesis"])
        for key in ("dimensions", "motivations", "problem_solving_weights", "tone_weights", "aesthetic_weights",
                    "strong_signals", "anti_preferences", "interesting_contradictions", "unknowns",
                    "memorable_player_moments", "prophetic_motifs", "design_implications",
                    "generated_prophecy", "game_design_vector", "negative_constraints"):
            self.assertIn(key, profile)
        self.assertEqual(set(profile["dimensions"]), set(self.r.axis_ids()))
        one = profile["dimensions"]["agency"]
        for key in ("value", "confidence", "status", "evidence", "contradictions", "independent_observations",
                    "explicit", "behavioral", "last_turn", "poles"):
            self.assertIn(key, one)
        self.assertTrue(-1.0 <= one["value"] <= 1.0 and 0.0 <= one["confidence"] <= 1.0)
        json.dumps(profile)                              # serialisable as it stands
        self.assertFalse(any(guard.sensitive(t) for t in json.dumps(profile).split('"')))


class UncertaintyTests(unittest.TestCase):
    def test_a_night_with_no_evidence_says_so(self):
        r = load_registry()
        session = Session.new({"no_save": True}, seed=4)
        model = PlayerModel(r)
        draft = build_draft(r, model, session)
        design = draft["design"]
        self.assertTrue(draft["thin_evidence"])
        self.assertEqual(design["design_signals"]["dominant"], [])
        self.assertGreaterEqual(len(design["unknowns"]), 5)
        self.assertTrue(design["game_design_vector"]["central_fantasy"].startswith("unknown"))
        self.assertIn("The Blank Card", [v["card"] for v in draft["prophecy"]["visions"]])
        self.assertTrue(all(src == "default" for src in draft["gdv_sources"].values()))

    def test_unknown_dimensions_do_not_shape_the_design(self):
        r = load_registry()
        session = Session.new({"no_save": True}, seed=4)
        model = PlayerModel(r)
        for i in range(3):
            model.add(turn=i, scene=f"c{i}", seed="x", frame=f"k{i}", action="walked past the marked door",
                      hypotheses=[("agency", 1, 0.9)], strength="strong", source="test")
        draft = build_draft(r, model, session)
        self.assertEqual(draft["design"]["design_signals"]["dominant"][0]["dims"][0], "agency")
        used = {src for src in draft["gdv_sources"].values() if src != "default"}
        self.assertEqual(used, {"agency+"})
        self.assertIn("No mandatory quest log.", draft["design"]["negative_constraints"])


# ---------------------------------------------------------------------------
# The model stage, with a scripted stand-in
# ---------------------------------------------------------------------------

class Scripted:
    name, label, streams = "fake", "a scripted stand-in", False

    def __init__(self, replies):
        self.replies, self.calls = list(replies), []

    def complete(self, system, prompt, *, purpose="turn", on_delta=None):
        self.calls.append((purpose, prompt))
        item = self.replies.pop(0)
        if isinstance(item, Exception):
            raise item
        return Completion(text=item if isinstance(item, str) else json.dumps(item), backend="fake")


class ModelStageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()
        cls.night = run_persona(cls.r, "firestarter", seed=2)
        cls.draft = cls.night["synthesis"]["draft"]

    def good_design(self):
        design = copy.deepcopy(self.draft["design"])
        design["working_title"] = "Do Not Press"
        design["pitch"] = "A house of buttons marked NO, each of which does something worth seeing."
        while len(design["design_signals"]["secondary"]) < 2:
            design["design_signals"]["secondary"].append(
                {"signal": "keeps moving", "dims": ["pacing"], "evidence": [], "design_consequence": "No waiting."})
        design["design_signals"]["productive_contradiction"] = {
            "between": ["mischief", "errand"], "evidence": [], "resolution": "A guided game that hopes to be disobeyed."}
        while len(design["design_implications"]) < 6:
            design["design_implications"].append("Every button does something.")
        while len(design["negative_constraints"]) < 3:
            design["negative_constraints"].append("No waiting.")
        return design

    def good_prophecy(self):
        prophecy = copy.deepcopy(self.draft["prophecy"])
        prophecy["address"] = "You carried them up. They were being made."
        return prophecy

    def synth(self, replies):
        backend = Scripted(replies)
        session = self.night["session"]
        return synthesize(self.r, self.night["model"], session, backend, ScriptedConsole()), backend

    def test_valid_answers_are_used(self):
        result, backend = self.synth([self.good_design(), self.good_prophecy()])
        self.assertEqual(result["source"], {"design": "fake", "prophecy": "fake"})
        self.assertEqual(result["design"]["working_title"], "Do Not Press")
        self.assertEqual([c[0] for c in backend.calls], ["design", "prophecy"])
        self.assertIn("Do Not Press", backend.calls[1][1])          # the reading is written for that design
        self.assertNotIn("{{", backend.calls[0][1])
        self.assertIn("Rule-based first draft", backend.calls[0][1])
        self.assertEqual(result["prompts"]["design"], backend.calls[0][1])

    def test_a_bad_answer_gets_one_repair_then_the_draft_stands(self):
        result, backend = self.synth(["not json", "{\"working_title\": \"\"}", self.good_prophecy()])
        self.assertEqual(result["source"]["design"], "rules")
        self.assertEqual(result["design"], self.draft["design"])
        self.assertIn("design", result["problems"])
        self.assertIn("rejected", backend.calls[1][1])

    def test_a_repaired_answer_is_accepted(self):
        broken = self.good_design()
        del broken["game_design_vector"]["core_verb"]
        result, backend = self.synth([broken, self.good_design(), self.good_prophecy()])
        self.assertEqual(result["source"]["design"], "fake")
        self.assertIn("core_verb", backend.calls[1][1])

    def test_a_reading_in_the_language_of_analysis_is_refused(self):
        bad = self.good_prophecy()
        bad["visions"][0]["text"] = "Based on your profile, you tend to like exploration (86%)."
        result, backend = self.synth([self.good_design(), bad, bad])
        self.assertTrue(result["source"]["prophecy"].startswith("rules"))
        self.assertTrue(result["source"]["design"].startswith("rules"))   # the pair stays consistent
        self.assertEqual(result["prophecy"], self.draft["prophecy"])

    def test_a_design_that_speaks_about_the_person_is_refused(self):
        bad = self.good_design()
        bad["pitch"] = "For a player who is probably a child."
        self.assertTrue(validate_design(bad, self.r))

    def test_if_the_model_is_gone_the_draft_is_the_answer(self):
        result, _ = self.synth([BackendError("unavailable", "down"), BackendError("unavailable", "down")])
        self.assertEqual(result["source"], {"design": "rules", "prophecy": "rules"})
        self.assertEqual(validate_prophecy(result["prophecy"]), [])


if __name__ == "__main__":
    unittest.main()
