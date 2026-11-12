"""The card-hair cut library: every head gets a whole style, and nothing in a style goes unread.

The generator (art/blender/scripts/build_card_hair.py) needs Blender, so this
suite reads it as text. What it holds: the library is complete and repeatable,
every setting a style carries is one the generator reads, and the reference
shader accepts everything the generator's look file sets.
"""
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "art/tools"))
import card_hair_styles as library  # noqa: E402

GENERATOR = (ROOT / "art/blender/scripts/build_card_hair.py").read_text(encoding="utf-8")
SHADER = (ROOT / "art/blender/cast/card_hair/card_hair_reference.gdshader").read_text(encoding="utf-8")
TIERS = {"part", "crown", "fringe", "sides", "nape"}
ZONES = {"fringe", "temple", "part_side", "sides", "nape"}
LIKENESS_HELD_ELSEWHERE = {"stacy"}
NOT_A_HEAD = {"companion", "prologue"}     # dialogue files that belong to no human head
LABELS = {"cut"}        # carried for people to read; the generator has no use for it


def settings(style):
    """Every setting name a style carries, at any depth; tier and zone names are not settings."""
    found = set()

    def walk(table, named_children=False):
        for key, value in table.items():
            if not named_children:
                found.add(key)
            if isinstance(value, dict):
                walk(value, key in ("tiers", "zones") and not named_children)

    walk(style)
    return found


class CardHairStyles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.styles = library.styles()

    def test_every_cast_member_has_a_cut_that_exists(self):
        self.assertGreaterEqual(len(self.styles), 20)
        for person, (cut, colour, own) in library.CAST.items():
            with self.subTest(person=person):
                self.assertIn(cut, library.CUTS)
                self.assertEqual(self.styles[person]["name"], person)
                self.assertEqual(self.styles[person]["cut"], cut)
                self.assertEqual(len(colour), 3)
                self.assertTrue(all(0.0 <= channel <= 1.0 for channel in colour))

    def test_every_resident_with_a_voice_has_hair(self):
        speakers = set()
        for path in (ROOT / "game/data/dialogue").glob("*.json"):
            if path.stem not in NOT_A_HEAD:
                speakers.add(path.stem)
        self.assertGreaterEqual(len(speakers), 15)
        # The guests are two bodies behind one voice. A likeness style is kept outside this repository.
        heads = set(self.styles) | {"transient_guests"} | LIKENESS_HELD_ELSEWHERE
        self.assertIn("transient_guests_a", self.styles)
        self.assertIn("transient_guests_b", self.styles)
        self.assertEqual(speakers - heads, set())

    def test_batches_hold_everyone_once(self):
        listed = [person for batch in library.BATCHES for person in batch]
        self.assertEqual(sorted(listed), sorted(library.CAST))

    def test_the_library_is_repeatable_and_styles_do_not_share_tables(self):
        again = library.styles()
        self.assertEqual(json.dumps(self.styles, sort_keys=True), json.dumps(again, sort_keys=True))
        self.assertEqual(len({style["seed"] for style in self.styles.values()}), len(self.styles))
        first = next(iter(again.values()))
        first["tiers"]["crown"]["lift_m"] = 99.0
        self.assertNotIn(99.0, [style["tiers"]["crown"]["lift_m"] for style in library.styles().values()])

    def test_a_style_fits_any_head_and_carries_no_one_head(self):
        for person, style in self.styles.items():
            with self.subTest(person=person):
                self.assertEqual(style["fit"], "head_bone")
                self.assertNotIn("skull_centre", style)
                self.assertLessEqual(set(style["tiers"]), TIERS)
                self.assertLessEqual(set(style["zones"]), ZONES)
                for tier in style["tiers"].values():
                    self.assertGreater(tier["width_m"], 0.0)
                    self.assertGreaterEqual(tier["lift_m"], 0.0)
                    self.assertLess(tier["lift_m"], 0.06)

    def test_colour_runs_dark_root_to_lighter_tip(self):
        for person, style in self.styles.items():
            with self.subTest(person=person):
                root, tip = style["colour"]["root"], style["colour"]["tip"]
                self.assertTrue(all(0.0 <= channel <= 1.0 for channel in root + tip))
                self.assertGreater(sum(tip), sum(root))
                self.assertTrue(0.0 <= style["gloss"] <= 1.0)

    def test_the_generator_reads_every_setting_a_style_carries(self):
        carried = set()
        for style in self.styles.values():
            carried |= settings(style)
        unread = sorted(key for key in carried - LABELS if '"%s"' % key not in GENERATOR)
        self.assertEqual(unread, [])

    def test_the_shader_accepts_the_look_file(self):
        written = re.search(r'_hair_look\.json"\)\)\.write_text\(json\.dumps\(\{(.*?)\}, indent=1\)\)', GENERATOR, re.DOTALL)
        self.assertIsNotNone(written)
        look = set(re.findall(r'"([a-z_]+)":', written.group(1)))
        self.assertLessEqual({"underside", "roundness", "gloss", "hair_centre", "cap_shade", "cap_feather", "cap_bald"}, look)
        uniforms = set(re.findall(r"^uniform \w+ (\w+)", SHADER, re.MULTILINE))
        self.assertEqual(look - uniforms, set())

    def test_short_cuts_end_in_points_and_keep_a_flat_tone(self):
        # Blunt tips on short cards drew hairlines of square teeth; a full tone ramp on them read as roof tiles.
        for name in ("crop", "side_part", "swept_back", "bald_crop", "coil_crop"):
            with self.subTest(cut=name):
                self.assertLessEqual(library.CUTS[name]["tips_from"], 0.62)
                self.assertLessEqual(library.CUTS[name]["shortest_tip"], 0.7)
                self.assertLessEqual(library.CUTS[name]["tone_ramp"], 0.5)
        self.assertNotIn("floor(UV2.x * 46.0) * 78.233", SHADER)

    def test_rounded_shading_cannot_cancel_on_an_inward_card(self):
        # A card wound to face the head, mixed raw with the outward normal, is lit as if it faced the floor:
        # a dark band round every head of fair hanging hair. The card's own normal is turned outward first.
        self.assertIn("dot(NORMAL, outward) < 0.0 ? -NORMAL : NORMAL", SHADER)
        self.assertNotIn("mix(NORMAL,", SHADER)


if __name__ == "__main__":
    unittest.main()
