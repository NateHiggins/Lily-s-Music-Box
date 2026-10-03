import json
import unittest

from oracle import guard
from oracle.backends import BackendError, Completion
from oracle.content import load_registry
from oracle.engine import Engine
from oracle.narrator import NarrationStream, parse_reply, system_prompt
from oracle.offline import available_options, match_option, match_threshold, short_way
from oracle.session import HARD_CAP, Session
from oracle.ui import ScriptedConsole


def new_engine(backend=None, length="short", seed=3):
    registry = load_registry()
    session = Session.new({"length": length, "backend_used": "test"}, seed=seed)
    ui = ScriptedConsole()
    engine = Engine(session, registry, ui, backend)
    engine.begin()
    return engine, session, ui, registry


def play_to_the_end(engine, session, registry, limit=200):
    steps = 0
    while not engine.finished and steps < limit:
        steps += 1
        if session.phase == "threshold":
            engine.turn("the first one")
        else:
            seed = registry.seeds[session.scene["seed"]]
            closing = [o for o in available_options(seed, session.scene["flags"]) if o["resolves"]]
            engine.turn("@" + closing[0]["id"])
    return steps


class MatcherTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()

    def pick(self, seed_id, text, flags=None):
        option, _ = match_option(self.r.seeds[seed_id], flags or {}, text)
        return option["id"] if option else None

    def test_plain_english_reaches_the_authored_option(self):
        self.assertEqual(self.pick("counter", "I read the ledger"), "read_ledger")
        self.assertEqual(self.pick("counter", "ring the bell"), "bell")
        self.assertEqual(self.pick("counter", "untie the ribbon and shuffle the deck"), "shuffle")
        self.assertEqual(self.pick("counter", "walk back out into the street"), "leave")
        self.assertEqual(self.pick("counter", "open the door marked PRIVATE"), "private")
        self.assertEqual(self.pick("counter", "pocket the doorknob"), "doorknob")
        self.assertEqual(self.pick("bridge", "prod the planks with the pole"), "test")
        self.assertEqual(self.pick("bridge", "take the long way round"), "long_way")

    def test_nonsense_matches_nothing(self):
        self.assertIsNone(self.pick("counter", "xyzzy plugh"))

    def test_options_wait_on_what_has_happened(self):
        self.assertEqual(self.pick("bridge", "cross the bridge"), "cross")
        self.assertEqual(self.pick("bridge", "cross the bridge", {"fell": True}), "again")

    def test_thresholds_by_name_and_by_position(self):
        ways = ["brass", "roots", "nursery"]
        self.assertEqual(match_threshold(self.r, ways, "the brass hatch"), 0)
        self.assertEqual(match_threshold(self.r, ways, "through the roots"), 1)
        self.assertEqual(match_threshold(self.r, ways, "I take the little yellow door"), 2)
        self.assertEqual(match_threshold(self.r, ways, "left"), 0)
        self.assertEqual(match_threshold(self.r, ways, "go right"), 2)
        self.assertEqual(match_threshold(self.r, ways, "2"), 1)
        self.assertIsNone(match_threshold(self.r, ways, "I sit down and think"))
        self.assertEqual(match_threshold(self.r, ["brass", "roots"], "the last one"), 1)
        self.assertEqual(short_way(self.r.skins["brass"]), "the brass hatch")


class OfflineNightTests(unittest.TestCase):
    def test_a_whole_night_reaches_the_reading(self):
        engine, s, ui, r = new_engine()
        play_to_the_end(engine, s, r)
        self.assertEqual(s.phase, "reveal")
        self.assertEqual(len(s.world.summaries), s.chamber_target + 2)
        self.assertEqual(s.world.summaries[0]["seed"], "counter")
        self.assertEqual(s.world.summaries[-1]["seed"], "reading_room")
        self.assertEqual(len(set(x["seed"] for x in s.world.summaries)), len(s.world.summaries))
        self.assertEqual(len(s.skins_taken), s.chamber_target)
        self.assertTrue(engine.model.observations)
        self.assertEqual(len(s.snapshots), s.turn)
        self.assertEqual(len([p for p in s.probes if p["kind"] == "seed"]), s.chamber_target)

    def test_every_room_dealt_records_why(self):
        engine, s, ui, r = new_engine()
        play_to_the_end(engine, s, r)
        for record in (p for p in s.probes if p["kind"] == "seed"):
            self.assertTrue(record["why"].startswith("probes "))
            self.assertTrue(record["candidates"])
            self.assertEqual(set(record["candidates"][0]["parts"]),
                             {"information", "disambiguation", "variety", "timing", "jitter"})

    def test_a_player_who_types_nonsense_is_never_stuck(self):
        engine, s, ui, r = new_engine()
        for _ in range(HARD_CAP):
            engine.turn("florb the wibble sideways")
        self.assertEqual(s.phase, "threshold")
        engine.turn("mmm")
        engine.turn("mmm")              # the house chooses a way
        self.assertEqual(s.phase, "chamber")
        self.assertEqual(s.chamber_index, 1)
        self.assertEqual(s.skins_taken and len(s.skins_taken), 1)
        # The house chose, so the pick says nothing about taste.
        self.assertFalse([o for o in engine.model.observations if o.source == "rule"])
        self.assertTrue(s.world.attempted)

    def test_choosing_a_way_is_evidence_and_dresses_the_next_room(self):
        engine, s, ui, r = new_engine()
        engine.turn("go through the inner door")
        self.assertEqual(s.phase, "threshold")
        ways = list(s.scene["thresholds"])
        self.assertEqual(len(ways), 3)
        engine.turn("@" + ways[1])
        self.assertEqual(s.scene["skin"], ways[1])
        rule = [o for o in engine.model.observations if o.source == "rule"]
        self.assertTrue(rule)
        self.assertTrue(all(h.dim.startswith(("aes.", "tone.")) for o in rule for h in o.hypotheses))
        self.assertIn(short_way(r.skins[ways[1]]), ui.out[-1][1])

    def test_what_cannot_be_afforded_does_not_happen(self):
        engine, s, ui, r = new_engine()
        s.world.matches = 0
        s.scene["seed"] = "vendor"
        engine.turn("@pole")
        self.assertEqual(s.world.matches, 0)
        self.assertNotIn("hooked pole that opens most things", s.world.inventory)
        self.assertEqual(s.phase, "chamber")

    def test_the_joker_works_once_anywhere(self):
        engine, s, ui, r = new_engine()
        engine.turn("I play the joker and say the wall is a door")
        self.assertEqual(s.world.joker, "played")
        self.assertEqual(s.phase, "threshold")
        self.assertTrue(any("Joker" in m["text"] for m in s.world.moments))

    def test_state_and_cards_follow_what_was_done(self):
        engine, s, ui, r = new_engine()
        engine.turn("shuffle the deck")
        self.assertTrue(s.world.ribbon_untied)
        self.assertEqual([c["title"] for c in s.world.cards], ["The Ribbon Untied"])
        self.assertIn("reward.transgression+", s.world.cards[0]["dims"])
        engine.turn("take the doorknob")
        self.assertIn("brass doorknob with no door", s.world.inventory)
        engine.turn("shuffle again")           # one card per room
        self.assertEqual(len(s.world.cards), 1)

    def test_a_night_can_be_put_down_and_taken_up(self):
        engine, s, ui, r = new_engine()
        engine.turn("read the ledger")
        engine.turn("go through the inner door")
        engine.turn("left")
        loaded = Session.load(s.id)
        self.assertEqual(loaded.turn, 3)
        self.assertEqual(loaded.scene["key"], s.scene["key"])
        again = Engine(loaded, r, ScriptedConsole(), None)
        self.assertEqual(again.model.snapshot(), engine.model.snapshot())
        again.begin()
        play_to_the_end(again, loaded, r)
        self.assertEqual(loaded.phase, "reveal")

    def test_the_end_of_the_night_adds_what_only_the_whole_night_shows(self):
        engine, s, ui, r = new_engine()
        engine.turn("take the doorknob")
        play_to_the_end(engine, s, r)
        before = len(engine.model.observations)
        engine.close_night()
        aggregate = [o for o in engine.model.observations if o.source == "aggregate"]
        self.assertTrue(aggregate)
        self.assertTrue(any("doorknob" in o.action for o in aggregate))
        engine.close_night()                   # idempotent
        self.assertEqual(len(engine.model.observations), before + len(aggregate))


# ---------------------------------------------------------------------------
# With a model behind the house (a scripted stand-in: nothing is called)
# ---------------------------------------------------------------------------

def reply(narration, **notes):
    return f"<narration>\n{narration}\n</narration>\n<oracle>\n{json.dumps(notes)}\n</oracle>"


class FakeBackend:
    name, label, streams = "fake", "a scripted stand-in", True

    def __init__(self, replies):
        self.replies, self.prompts, self.systems = list(replies), [], []

    def complete(self, system, prompt, *, purpose="turn", on_delta=None):
        self.systems.append(system)
        self.prompts.append(prompt)
        item = self.replies.pop(0)
        if isinstance(item, Exception):
            raise item
        if on_delta:
            for i in range(0, len(item), 7):       # arrives in small pieces, as a stream does
                on_delta(item[i:i + 7])
        return Completion(text=item, model="fake-1", latency=0.01, backend="fake")


class LiveNarratorTests(unittest.TestCase):
    def test_reply_is_split_applied_and_only_narration_is_shown(self):
        backend = FakeBackend([reply(
            "The ledger knows you. In your coat a card grows warm.",
            scene={"status": "open", "threshold_choice": None, "summary": "read the ledger first"},
            state={"inventory_add": ["a pencil stub"], "matches_delta": -1, "flags": {"read": True},
                   "threads_add": ["the PRIVATE door was never opened"]},
            observations=[{"action": "read the ledger before touching anything", "kind": "behavioral",
                           "strength": "moderate", "context": "errand against curiosity", "signal": "examines",
                           "hypotheses": [{"dim": "planning", "dir": -1, "share": 0.5, "why": "looks first"},
                                          {"dim": "story.world", "dir": 1, "share": 0.4, "why": "reads for itself"}]}],
            focus=["ledger"], card={"title": "The Ledger", "image": "wet ink"},
            moment="read the ledger before touching the bell")])
        engine, s, ui, r = new_engine(backend)
        engine.turn("I read the ledger")
        shown = ui.text()
        self.assertIn("The ledger knows you.", shown)
        self.assertNotIn("oracle", shown)
        self.assertNotIn("planning", shown)
        self.assertEqual(s.world.matches, 2)
        self.assertIn("a pencil stub", s.world.inventory)
        self.assertEqual(s.world.threads, ["the PRIVATE door was never opened"])
        self.assertEqual(s.world.cards[0]["title"], "The Ledger")
        self.assertEqual(s.world.moments[0]["text"], "read the ledger before touching the bell")
        self.assertEqual(s.world.signals, {"examines": 1})
        obs = engine.model.observations[0]
        self.assertEqual((obs.source, obs.strength, obs.scene), ("llm", "moderate", "c0:counter"))
        self.assertEqual(s.backend_log[0]["purpose"], "turn")
        # The prompt carries the state, the directive, and the player's own words.
        self.assertIn("## Scene directive", backend.prompts[0])
        self.assertIn("I read the ledger", backend.prompts[0])
        self.assertIn("The Counter", backend.prompts[0])
        self.assertEqual(backend.systems[0], system_prompt(r))
        self.assertNotIn("{{", backend.systems[0])

    def test_closing_reply_leads_to_a_threshold_and_then_a_staged_room(self):
        engine, s, ui, r = None, None, None, None
        backend = FakeBackend([])
        engine, s, ui, r = new_engine(backend)
        ways = s.scene["thresholds"]
        words = ", ".join(r.skins[w]["keywords"][0] for w in ways)
        backend.replies.append(reply(f"You go through. Three ways: {words}.",
                                     scene={"status": "resolved", "summary": "went straight on"}))
        engine.turn("go on")
        self.assertEqual(s.phase, "threshold")
        self.assertIn(" A) ", backend.prompts[0])
        next_seed = s.scene["next_seed"]
        backend.replies.append(reply("You take the second way. A new room opens around you.",
                                     scene={"status": "open", "threshold_choice": "B", "summary": "took the second way"}))
        engine.turn("the second")
        self.assertEqual(s.phase, "chamber")
        self.assertEqual(s.scene["seed"], next_seed)
        self.assertEqual(s.scene["skin"], ways[1])
        self.assertIn(r.seeds[next_seed]["title"], backend.prompts[1])
        self.assertEqual(s.scene["exchange"][0]["house"][:22], "You take the second wa")

    def test_a_forgotten_threshold_is_supplied_from_the_page(self):
        backend = FakeBackend([reply("You go through.", scene={"status": "resolved"})])
        engine, s, ui, r = new_engine(backend)
        engine.turn("go on")
        self.assertIn("The way on divides.", ui.text())

    def test_unreadable_notes_cost_the_player_nothing(self):
        backend = FakeBackend(["<narration>The bell rings in another room.</narration><oracle>{not json"])
        engine, s, ui, r = new_engine(backend)
        engine.turn("ring the bell")
        self.assertIn("The bell rings in another room.", ui.text())
        self.assertEqual(s.phase, "chamber")
        # The authored reading of the same line stands in for the lost notes.
        self.assertTrue(engine.model.observations)
        self.assertEqual(engine.model.observations[0].source, "offline")
        self.assertTrue(any(g["guard"] == "notes_unreadable" for g in s.guard_events))

    def test_when_the_model_stops_answering_the_night_goes_on_from_the_page(self):
        backend = FakeBackend([BackendError("auth", "login expired")])
        engine, s, ui, r = new_engine(backend)
        engine.turn("ring the bell")
        self.assertIsNone(engine.live)
        self.assertIn("You ring the bell.", ui.text())
        self.assertTrue(any(k == "note" and "gone quiet" in t for k, t in ui.out))
        play_to_the_end(engine, s, r)
        self.assertEqual(s.phase, "reveal")

    def test_words_about_the_person_are_removed_and_the_evidence_kept(self):
        backend = FakeBackend([reply(
            "The tube clears its throat.",
            scene={"status": "open"},
            observations=[{"action": "asked three questions; the player is probably a child",
                           "kind": "behavioral", "strength": "weak", "context": "caution",
                           "hypotheses": [{"dim": "planning", "dir": -1, "share": 0.6, "why": "seems anxious"}]}],
            moment="the bearer is clearly depressed")])
        engine, s, ui, r = new_engine(backend)
        engine.turn("who are you? what is this? why me?")
        obs = engine.model.observations[0]
        self.assertTrue(guard.removed(obs.action))
        self.assertEqual(obs.hypotheses[0].dim, "planning")
        self.assertEqual(s.world.moments, [])
        self.assertTrue(any(g["guard"] == "sensitive_text_removed" for g in s.guard_events))

    def test_the_hard_cap_closes_a_room_the_model_would_keep_open(self):
        backend = FakeBackend([reply("Nothing much happens.", scene={"status": "open"})] * HARD_CAP)
        engine, s, ui, r = new_engine(backend)
        for _ in range(HARD_CAP):
            engine.turn("hm")
        self.assertEqual(s.phase, "threshold")
        self.assertIn("MUST close", backend.prompts[-1])


class ReplyParsingTests(unittest.TestCase):
    def test_stream_filter_passes_only_the_narration(self):
        text = reply("One. Two.\n\nThree.", scene={"status": "open"})
        for size in (1, 3, 8, 50):
            out = []
            stream = NarrationStream(out.append)
            for i in range(0, len(text), size):
                stream.feed(text[i:i + size])
            self.assertEqual("".join(out), "One. Two.\n\nThree.", f"chunk size {size}")

    def test_tolerant_parsing(self):
        narration, notes, problems = parse_reply("<narration>Hi.</narration><oracle>```json\n{\"scene\": {\"status\": \"resolved\",},}\n```</oracle>")
        self.assertEqual(narration, "Hi.")
        self.assertEqual(notes["scene"]["status"], "resolved")
        self.assertEqual(problems, [])
        narration, notes, problems = parse_reply("Just prose, no tags at all.")
        self.assertEqual(narration, "Just prose, no tags at all.")
        self.assertEqual(notes, {})
        self.assertIn("oracle_block_missing", problems)
        narration, notes, problems = parse_reply("Prose first.<oracle>{\"scene\": {}}</oracle>")
        self.assertEqual(narration, "Prose first.")
        self.assertIn("narration_tag_missing", problems)


class GuardTests(unittest.TestCase):
    def test_claims_about_the_person_are_caught(self):
        for text in ("the player is probably a child", "she seems depressed", "their age shows",
                     "likely ADHD", "the bearer is clearly lonely", "a diagnosis of anxiety disorder",
                     "the user's religion", "they are not very intelligent"):
            self.assertTrue(guard.sensitive(text), text)

    def test_fiction_and_design_language_pass(self):
        for text in ("spared the sleeping man", "a smart use of the pole", "raced the other bearer",
                     "plays conservatively with matches", "the old woman at the toll", "took the straight road",
                     "the child-sized door", "a trans-dimensional lift", "protects what they have",
                     "asked the keeper her name"):
            self.assertFalse(guard.sensitive(text), text)

    def test_reading_must_not_sound_like_a_report(self):
        self.assertEqual(guard.prophecy_problems(["I see a door with no handle."]), [])
        self.assertTrue(guard.prophecy_problems(["Based on your profile, you tend to explore (86%)."]))


if __name__ == "__main__":
    unittest.main()
