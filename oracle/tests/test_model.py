import unittest

from oracle.content import load_registry
from oracle.model import CONFIDENCE_CAP, PlayerModel, betainc


def add(model, scene, hyps, strength="moderate", kind="behavioral", turn=1, frame="choice"):
    return model.add(turn=turn, scene=scene, seed=scene, frame=frame, action=f"act in {scene}",
                     hypotheses=hyps, strength=strength, kind=kind, source="test")


class BetaTests(unittest.TestCase):
    def test_known_values(self):
        self.assertAlmostEqual(betainc(4, 1, 0.5), 0.0625, places=9)
        self.assertAlmostEqual(betainc(2, 3, 0.5), 0.6875, places=9)
        self.assertAlmostEqual(betainc(2, 2, 0.5), 0.5, places=9)
        self.assertEqual(betainc(2, 2, 0.0), 0.0)
        self.assertEqual(betainc(2, 2, 1.0), 1.0)

    def test_symmetry(self):
        for a, b in ((1.3, 2.7), (5.0, 1.2), (0.6, 0.9)):
            self.assertAlmostEqual(betainc(a, b, 0.3), 1.0 - betainc(b, a, 0.7), places=9)


class ModelTests(unittest.TestCase):
    def setUp(self):
        self.r = load_registry()
        self.m = PlayerModel(self.r)

    def test_nothing_known_at_the_start(self):
        st = self.m.state("risk")
        self.assertEqual(st.status, "unknown")
        self.assertEqual(st.confidence, 0.0)
        self.assertEqual(st.value, 0.0)

    def test_one_choice_is_never_definitive(self):
        add(self.m, "c1", [("risk", 1, 1.0)], strength="strong")
        st = self.m.state("risk")
        self.assertGreater(st.value, 0)
        self.assertLessEqual(st.confidence, CONFIDENCE_CAP[1])
        self.assertNotEqual(st.status, "established")
        self.assertEqual(st.n_independent, 1)

    def test_repeated_pattern_across_scenes_builds_confidence(self):
        for i in range(4):
            add(self.m, f"c{i}", [("risk", 1, 0.8)], strength="strong", turn=i, frame=f"kind{i}")
        st = self.m.state("risk")
        self.assertEqual(st.status, "established")
        self.assertGreaterEqual(st.confidence, 0.6)
        self.assertEqual(st.n_independent, 4)
        self.assertEqual(st.n_frames, 4)
        self.assertEqual(st.last_turn, 3)

    def test_repeating_inside_one_scene_counts_for_less(self):
        same, apart = PlayerModel(self.r), PlayerModel(self.r)
        for _ in range(3):
            add(same, "c1", [("pacing", 1, 0.6)])
        for i in range(3):
            add(apart, f"c{i}", [("pacing", 1, 0.6)])
        self.assertLess(same.state("pacing").support, apart.state("pacing").support)
        self.assertLess(same.state("pacing").confidence, apart.state("pacing").confidence)

    def test_evidence_both_ways_is_contested_not_averaged_away(self):
        for i in range(3):
            add(self.m, f"a{i}", [("exploration", 1, 0.8)], strength="strong")
            add(self.m, f"b{i}", [("exploration", -1, 0.8)], strength="strong")
        st = self.m.state("exploration")
        self.assertEqual(st.status, "contested")
        self.assertLess(st.confidence, 0.3)
        self.assertEqual(len(st.supporting) + len(st.contradicting), 6)
        self.assertTrue(st.supporting and st.contradicting)
        self.assertIn("contested", self.m.label("exploration"))

    def test_a_statement_is_useful_but_not_privileged(self):
        said, did = PlayerModel(self.r), PlayerModel(self.r)
        add(said, "c1", [("friction", -1, 0.8)], kind="explicit")
        add(did, "c1", [("friction", -1, 0.8)], kind="behavioral")
        self.assertLess(said.state("friction").against, did.state("friction").against)
        self.assertEqual(said.state("friction").explicit, 1)
        self.assertEqual(did.state("friction").behavioral, 1)

    def test_malformed_evidence_is_dropped_not_guessed(self):
        self.assertIsNone(add(self.m, "c1", [("not_a_dimension", 1, 0.5)]))
        self.assertIsNone(add(self.m, "c1", [("risk", 0, 0.5)]))
        self.assertIsNone(add(self.m, "c1", [("risk", 1, "much")]))
        obs = add(self.m, "c1", [("risk", 1, 0.9), ("planning", 1, 0.9), ("nonsense", 1, 0.9)])
        self.assertEqual([h.dim for h in obs.hypotheses], ["risk", "planning"])
        self.assertAlmostEqual(sum(h.share for h in obs.hypotheses), 1.0)

    def test_later_scenes_settle_an_ambiguous_action(self):
        # One action, two readings, evenly split.
        first = add(self.m, "c1", [("risk", 1, 0.5), ("reward.transgression", 1, 0.5)])
        self.assertTrue(self.m.ambiguities()[0]["open"])
        # Other scenes corroborate only one of the readings.
        add(self.m, "c2", [("reward.transgression", 1, 0.9)], strength="strong")
        add(self.m, "c3", [("reward.transgression", 1, 0.9)], strength="strong")
        self.m.compute()
        post = {h.dim: h.posterior for h in first.hypotheses}
        self.assertGreater(post["reward.transgression"], 0.5)
        self.assertLess(post["risk"], 0.5)
        self.assertAlmostEqual(sum(post.values()), 1.0)
        self.assertFalse(self.m.ambiguities()[0]["open"])

    def test_the_profile_is_a_pure_function_of_the_log(self):
        add(self.m, "c1", [("risk", 1, 0.5), ("planning", 1, 0.4)])
        add(self.m, "c2", [("risk", 1, 0.6)], strength="strong")
        add(self.m, "c3", [("planning", -1, 0.6)], kind="explicit")
        again = PlayerModel.from_list(self.r, self.m.to_list())
        self.assertEqual(self.m.snapshot(), again.snapshot())
        self.assertEqual(self.m.state("risk").status, again.state("risk").status)

    def test_ranked_orders_by_what_should_shape_the_design(self):
        for i in range(3):
            add(self.m, f"c{i}", [("agency", 1, 0.9)], strength="strong")
        add(self.m, "c9", [("tone.cozy", 1, 0.3)], strength="weak")
        ranked = self.m.ranked()
        self.assertEqual(ranked[0].id, "agency")
        self.assertNotIn("risk", [s.id for s in ranked])


if __name__ == "__main__":
    unittest.main()
