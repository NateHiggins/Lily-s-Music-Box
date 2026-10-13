import unittest

from oracle import guard
from oracle.content import coverage_report, load_registry


class ContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.r = load_registry()

    def test_registry_loads_and_has_the_expected_shape(self):
        r = self.r
        self.assertEqual(r.opener()["id"], "counter")
        self.assertEqual(r.finale()["id"], "reading_room")
        self.assertGreaterEqual(len(r.chamber_seeds()), 30)
        self.assertEqual(len(r.axis_ids()), 17)
        self.assertEqual(len(r.gdv_field_ids()), 31)
        self.assertGreaterEqual(len(r.skins), 12)

    def test_every_core_dimension_is_probed_in_more_than_one_frame(self):
        """Confidence needs differently framed evidence, so one kind of room is not enough."""
        report = coverage_report(self.r)
        thin = [d for d in self.r.axis_ids() if len(report[d]["kinds"]) < 2]
        self.assertEqual(thin, [])

    def test_every_room_can_be_left(self):
        for seed in self.r.seeds.values():
            self.assertTrue(any(o["resolves"] for o in seed["options"]), seed["id"])
            open_at_start = [o for o in seed["options"]
                             if "flag" not in (o.get("when") or {}) and o["resolves"]]
            self.assertTrue(open_at_start, f"{seed['id']} has no way out before a flag is set")

    def test_when_conditions_refer_to_flags_the_room_can_set(self):
        for seed in self.r.seeds.values():
            settable = {"joker_gone"}
            for option in seed["options"]:
                settable |= set(((option.get("effects") or {}).get("flags") or {}).keys())
            for option in seed["options"]:
                for flag in (option.get("when") or {}).values():
                    self.assertIn(flag, settable, f"{seed['id']}.{option['id']} waits on {flag!r}")

    def test_reading_conditions_refer_to_flags_some_room_sets(self):
        settable = set()
        for seed in self.r.seeds.values():
            for option in seed["options"]:
                settable |= set(((option.get("effects") or {}).get("flags") or {}).keys())
        for table in ("callbacks", "unrequested", "facts"):
            for item in self.r.reading[table]:
                flag = item["when"].get("flag")
                if flag:
                    self.assertIn(flag, settable, f"reading.json {table} waits on {flag!r}")

    def test_no_room_asks_what_games_the_player_likes(self):
        """The night measures choices; it never asks about taste."""
        banned = ("what games", "which games", "favorite game", "favourite game", "genre",
                  "do you like", "do you prefer", "difficulty")
        for seed in self.r.seeds.values():
            texts = [seed["intro"], seed["hint"], seed["fallback"], seed["nudge"], seed["close"]]
            for option in seed["options"]:
                texts.append(option.get("outcome", ""))
                texts.extend(option.get("outcomes", []))
            for text in texts:
                low = text.lower()
                for phrase in banned:
                    self.assertNotIn(phrase, low, f"{seed['id']}: {phrase!r}")
                self.assertEqual(guard.narration_leaks(text), [], f"{seed['id']}: {text[:60]}")

    def test_authored_moments_read_back_in_the_second_person(self):
        from oracle.synthesis import second_person
        for seed in self.r.seeds.values():
            for option in seed["options"]:
                moment = option.get("moment")
                if not moment:
                    continue
                line = second_person(moment)
                self.assertTrue(line.startswith("You ") and line.endswith("."), line)
                for word in (" they ", " their ", " them ", "You was "):
                    self.assertNotIn(word, line, line)

    def test_the_reading_never_speaks_in_analysis(self):
        r = self.r
        lines = list(r.reading["addresses"]) + [f["text"] for f in r.reading["facts"]]
        lines += [c["vision"] for c in r.reading["callbacks"]]
        lines += [v for vs in r.reading["weight_visions"].values() for v in vs]
        lines += [c["vision"] for c in r.implications["contradictions"]]
        for poles in r.implications["axis_rules"].values():
            for rule in poles.values():
                lines += rule.get("visions", [])
        for rule in r.implications["weight_rules"].values():
            lines += (rule.get("high") or {}).get("visions", [])
        self.assertGreater(len(lines), 120)
        self.assertEqual(guard.prophecy_problems(lines), [])

    def test_prompts_have_their_placeholders(self):
        t = self.r.texts
        for mark in ("{{SETTING}}", "{{DIMENSIONS}}", "{{SIGNALS}}"):
            self.assertIn(mark, t["narrator_system"])
        for mark in ("{{SCOPE}}", "{{EVIDENCE}}", "{{GDV_FIELDS}}"):
            self.assertIn(mark, t["synthesis_design"])
        for mark in ("{{DESIGN}}", "{{NIGHT}}"):
            self.assertIn(mark, t["synthesis_prophecy"])
        for mark in ("{{TITLE}}", "{{PITCH}}", "{{NIGHT}}", "{{SIGNALS}}", "{{QUIET}}", "{{VECTOR}}", "{{LAWS}}",
                     "{{ECHOES}}", "{{UNKNOWN}}", "{{VISION_COUNT}}", "{{VISIONS}}", "{{SCOPE}}", "{{FOOTER}}"):
            self.assertIn(mark, t["build_prompt"])

    def test_every_word_on_the_hint_card_does_what_it_says(self):
        from itertools import combinations
        from oracle.offline import available_options, hint_words, match_option
        HIDDEN_TAGS = {"exploit", "transgress", "trick"}     # said here, not borrowed from the code under test
        for seed in self.r.seeds.values():
            names = sorted({(o.get("when") or {}).get(k) for o in seed["options"] for k in ("flag", "not_flag")} - {None})
            states = [dict.fromkeys(group, True) for n in range(len(names) + 1) for group in combinations(names, n)]
            for flags in states:                                # every state the room can be in
                where = f"{seed['id']} {sorted(flags)}"
                words = hint_words(seed, flags)
                self.assertTrue(words, where)
                shown = [o for o in available_options(seed, flags) if not HIDDEN_TAGS & set(o.get("tags", []))]
                # One word for every way the house will name, and typed back it selects that way and no other.
                self.assertEqual(len(words), len(shown), where)
                for word, option in zip(words, shown):
                    chosen, score = match_option(seed, flags, word)
                    self.assertIs(chosen, option, f"{where}: the card says {word!r} and the room hears {chosen and chosen['id']!r}")
                    self.assertGreaterEqual(score, 0.6, where)
                # What is meant to be found is never named.
                for option in available_options(seed, flags):
                    if HIDDEN_TAGS & set(option.get("tags", [])):
                        for word in words:
                            self.assertIsNot(match_option(seed, flags, word)[0], option, where)
                if seed.get("role") != "finale":
                    self.assertTrue(any(o["resolves"] for o in shown), f"{where}: no hinted way leaves the room")

    def test_every_act_can_be_told_to_someone_else(self):
        import re
        second = re.compile(r"\b(you|your|yours|yourself)\b", re.IGNORECASE)
        for seed in self.r.seeds.values():
            for option in seed["options"]:
                where = f"{seed['id']}.{option['id']}"
                if option.get("obs"):
                    told = option.get("moment") or option.get("did")
                    self.assertTrue(told, f"{where}: evidence with no words for what was done")
                    self.assertNotRegex(told, second, where)
                    self.assertRegex(told, r"^[a-z]", where)        # a phrase that follows "they", not a sentence
                    self.assertFalse(told.endswith("."), where)
        for signal in self.r.signals.values():
            self.assertRegex(signal["seen"], r"^[a-z]", signal["id"])
            self.assertNotRegex(signal["seen"], second, signal["id"])
            # Past tense: "asked", "tried", "went", never "asks".
            self.assertNotRegex(signal["seen"].split()[0], r"^(asks|examines|waits|tries|takes|pushes|jokes|argues|does|looks|goes|abandons|declines|spends|speaks|puts|checks|tests|sets|is|follows|stays|states)$", signal["id"])


if __name__ == "__main__":
    unittest.main()
