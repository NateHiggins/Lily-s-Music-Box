"""One card-hair style per cast member, from a library of period cuts.

    python art/tools/card_hair_styles.py <out_dir>

Every cut starts from one full bob (art/blender/cast/card_hair/base_bob.json)
and is written for one size of head; each person's file sets "fit":
"head_bone" so the generator (art/blender/scripts/build_card_hair.py) brings
their own head to that size. Colours are the cast's own.

Imported, this module only builds the tables: CUTS, CAST, BATCHES and
styles(). Run, it writes one <person>.json a head plus batches.json.
"""
import copy, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOB = json.loads((ROOT / "art/blender/cast/card_hair/base_bob.json").read_text(encoding="utf-8"))
BOB["fit"] = "head_bone"
BOB["row_every_m"] = 0.02
# On the cast the top layer sits a little lower and the part stops short of the whorl, so nothing arches over the crown.
BOB["tiers"]["part"]["lift_m"] = 0.030
BOB["tiers"]["crown"]["lift_m"] = 0.028
BOB["part"]["cards_back_y_m"] = -0.012


def cut(base, **changes):
    made = copy.deepcopy(base)
    for path, value in changes.items():
        keys = path.split("__")
        at = made
        for key in keys[:-1]:
            at = at.setdefault(key, {})
        at[keys[-1]] = value
    return made


def tiers(**each):
    return {name: dict(spec) for name, spec in each.items()}


FLAT = {"hang_m": 0.014, "bulge_m": 0.010, "curl_m": 0.0}
SHORT_ZONES = {"fringe": dict(FLAT), "temple": dict(FLAT), "part_side": dict(FLAT), "sides": dict(FLAT), "nape": dict(FLAT)}

CUTS = {
    # The pilot's own: full rounded bob, side part, fringe swept across the brow.
    "bob_swept": BOB,
    # A bob cut straight across the brow: no visible part, bangs on both sides.
    "bob_bangs": cut(BOB, part__x_m=0.006, part__brush_back=0.0, part__drop_front_corner=False,
                     fringe={"exit_half_width_degrees": 60.0, "hairline_cards": 22, "both_sides": True},
                     tiers__fringe={"lift_m": 0.018, "width_m": 0.036, "cup": 0.09, "gravity": 0.5, "comb": 0.85, "comb_to": "front", "sweep_jitter_degrees": 3.0, "twist_degrees": 0.0},
                     zones__fringe={"hem_z": 1.362, "hem_slope": 0.0, "bulge_m": 0.020, "curl_m": 0.012, "sweep_m": 0.0},
                     zones__sides__bulge_m=0.052, zones__sides__curl_m=0.03, zones__temple__forward_part_side_m=0.03,
                     tiers__part__lift_m=0.026, tiers__crown__lift_m=0.026),
    # Longer in front than behind: the nape cut high, the sides coming forward to the jaw.
    "bob_inverted": cut(BOB, zones__nape__hem_z=1.288, zones__nape__bulge_m=0.036, zones__sides__hem_z=1.256,
                        zones__temple__hem_z=1.252, zones__temple__forward_m=0.036, zones__temple__forward_part_side_m=0.012),
    # A short bob: the ends at the ear lobe.
    "bob_short": cut(BOB, zones__sides__hem_z=1.292, zones__temple__hem_z=1.296, zones__nape__hem_z=1.286,
                     zones__sides__bulge_m=0.046, zones__nape__bulge_m=0.036, zones__sides__curl_m=0.03),
    # Everything drawn back off the face into a knot at the nape.
    "bun": cut(BOB, part__cards=0, part__brush_back=0.0, part__drop_front_corner=False, root_spacing_m=0.019,
               fringe={"exit_half_width_degrees": 0.0, "hairline_cards": 16, "hairline_span_degrees": 64.0, "both_sides": True},
               hairline_degrees={"front": 47.0, "side": 84.0, "back": 122.0},
               tiers=tiers(part={"lift_m": 0.012, "width_m": 0.04, "cup": 0.07, "gravity": 0.15, "comb": 0.8, "comb_to": "back"},
                           crown={"lift_m": 0.012, "width_m": 0.040, "cup": 0.07, "gravity": 0.15, "comb": 0.8, "comb_to": "back", "sweep_jitter_degrees": 4.0, "twist_degrees": 0.0},
                           sides={"lift_m": 0.008, "width_m": 0.036, "cup": 0.08, "gravity": 0.2, "comb": 0.8, "comb_to": "back", "sweep_jitter_degrees": 4.0, "twist_degrees": 0.0, "walk_m": 0.075},
                           nape={"lift_m": 0.006, "width_m": 0.034, "cup": 0.08, "gravity": 0.1, "comb": 0.2, "comb_to": "back", "sweep_jitter_degrees": 4.0, "twist_degrees": 0.0, "walk_m": 0.03},
                           fringe={"lift_m": 0.010, "width_m": 0.040, "cup": 0.07, "gravity": 0.1, "comb": 0.85, "comb_to": "back", "sweep_jitter_degrees": 3.0, "twist_degrees": 0.0}),
               zones=SHORT_ZONES, bun={"bearing_degrees": 180.0, "down_degrees": 104.0, "radius_m": 0.038, "stand": 0.6, "depth": 0.72}),
    # A man's cut: parted at the side, the top combed over, the sides and back short.
    "side_part": cut(BOB, root_spacing_m=0.018, rows=7, tips_from=0.58, shortest_tip=0.66, part__cards=22, part__brush_back=0.5, part__drop_front_corner=False,
                     hairline_degrees={"front": 48.0, "side": 76.0, "back": 112.0},
                     fringe={"exit_half_width_degrees": 50.0, "hairline_cards": 10},
                     tiers=tiers(part={"lift_m": 0.014, "width_m": 0.034, "cup": 0.07, "gravity": 0.15, "comb": 0.85, "walk_m": 0.075, "sweep_jitter_degrees": 4.0, "twist_degrees": 0.0},
                                 crown={"lift_m": 0.012, "width_m": 0.032, "cup": 0.07, "gravity": 0.25, "comb": 0.7, "walk_m": 0.06, "sweep_jitter_degrees": 5.0, "twist_degrees": 0.0},
                                 sides={"lift_m": 0.004, "width_m": 0.028, "cup": 0.06, "gravity": 0.75, "comb": 0.1, "walk_m": 0.032, "sweep_jitter_degrees": 6.0, "twist_degrees": 0.0},
                                 nape={"lift_m": 0.003, "width_m": 0.028, "cup": 0.06, "gravity": 0.8, "comb": 0.0, "walk_m": 0.028, "sweep_jitter_degrees": 6.0, "twist_degrees": 0.0},
                                 fringe={"lift_m": 0.018, "width_m": 0.032, "cup": 0.08, "gravity": 0.05, "comb": 0.8, "walk_m": 0.06, "sweep_jitter_degrees": 5.0, "twist_degrees": 0.0}),
                     zones=SHORT_ZONES),
    # Longer on top and brushed straight back.
    "swept_back": cut(BOB, root_spacing_m=0.018, rows=8, part__cards=0, part__brush_back=0.0, part__drop_front_corner=False,
                      hairline_degrees={"front": 48.0, "side": 78.0, "back": 114.0},
                      fringe={"exit_half_width_degrees": 0.0, "hairline_cards": 16, "hairline_span_degrees": 62.0, "both_sides": True}, tips_from=0.58, shortest_tip=0.66,
                      tiers=tiers(part={"lift_m": 0.02, "width_m": 0.034, "cup": 0.07, "gravity": 0.1, "comb": 0.85, "comb_to": "back", "walk_m": 0.11},
                                  crown={"lift_m": 0.018, "width_m": 0.034, "cup": 0.07, "gravity": 0.1, "comb": 0.85, "comb_to": "back", "walk_m": 0.10, "sweep_jitter_degrees": 5.0, "twist_degrees": 0.0},
                                  sides={"lift_m": 0.006, "width_m": 0.03, "cup": 0.06, "gravity": 0.35, "comb": 0.6, "comb_to": "back", "walk_m": 0.045, "sweep_jitter_degrees": 6.0, "twist_degrees": 0.0},
                                  nape={"lift_m": 0.004, "width_m": 0.028, "cup": 0.06, "gravity": 0.8, "comb": 0.0, "walk_m": 0.03, "sweep_jitter_degrees": 6.0, "twist_degrees": 0.0},
                                  fringe={"lift_m": 0.014, "width_m": 0.034, "cup": 0.08, "gravity": 0.0, "comb": 0.9, "comb_to": "back", "walk_m": 0.10, "sweep_jitter_degrees": 4.0, "twist_degrees": 0.0}),
                      zones=SHORT_ZONES),
    # Cropped close all over.
    "crop": cut(BOB, root_spacing_m=0.014, rows=5, tips_from=0.6, shortest_tip=0.68, part__cards=0, part__brush_back=0.0, part__drop_front_corner=False,
                hairline_degrees={"front": 47.0, "side": 76.0, "back": 110.0},
                fringe={"exit_half_width_degrees": 0.0, "hairline_cards": 0},
                tiers=tiers(part={"lift_m": 0.006, "width_m": 0.028, "cup": 0.06, "gravity": 0.3, "comb": 0.3, "walk_m": 0.03},
                            crown={"lift_m": 0.006, "width_m": 0.028, "cup": 0.06, "gravity": 0.3, "comb": 0.3, "walk_m": 0.032, "sweep_jitter_degrees": 12.0, "twist_degrees": 0.0},
                            sides={"lift_m": 0.003, "width_m": 0.026, "cup": 0.05, "gravity": 0.8, "comb": 0.0, "walk_m": 0.024, "sweep_jitter_degrees": 8.0, "twist_degrees": 0.0},
                            nape={"lift_m": 0.003, "width_m": 0.026, "cup": 0.05, "gravity": 0.8, "comb": 0.0, "walk_m": 0.022, "sweep_jitter_degrees": 8.0, "twist_degrees": 0.0},
                            fringe={"lift_m": 0.006, "width_m": 0.028, "cup": 0.06, "gravity": 0.3, "comb": 0.3, "walk_m": 0.03}),
                zones=SHORT_ZONES),
    # A close waved set: side part, finger waves over the ears, gathered low at the nape.
    "waved_set": cut(BOB, root_spacing_m=0.02, part__drop_front_corner=False, part__brush_back=0.6,
                     fringe={"exit_half_width_degrees": 48.0, "hairline_cards": 12},
                     tiers=tiers(part={"lift_m": 0.010, "width_m": 0.040, "cup": 0.07, "gravity": 0.2, "comb": 0.85, "wave_degrees": 26.0, "wave_length_m": 0.042, "sweep_jitter_degrees": 2.0, "twist_degrees": 0.0},
                                 crown={"lift_m": 0.010, "width_m": 0.040, "cup": 0.07, "gravity": 0.25, "comb": 0.75, "wave_degrees": 26.0, "wave_length_m": 0.042, "sweep_jitter_degrees": 2.0, "twist_degrees": 0.0},
                                 sides={"lift_m": 0.008, "width_m": 0.036, "cup": 0.08, "gravity": 0.5, "comb": 0.3, "wave_degrees": 24.0, "wave_length_m": 0.04, "sweep_jitter_degrees": 2.0, "twist_degrees": 0.0},
                                 nape={"lift_m": 0.006, "width_m": 0.034, "cup": 0.08, "gravity": 0.6, "comb": 0.0, "sweep_jitter_degrees": 4.0, "twist_degrees": 0.0},
                                 fringe={"lift_m": 0.010, "width_m": 0.036, "cup": 0.08, "gravity": 0.35, "comb": 0.6, "wave_degrees": 26.0, "wave_length_m": 0.04, "sweep_jitter_degrees": 2.0, "twist_degrees": 0.0}),
                     zones={"fringe": {"hem_z": 1.384, "hem_slope": 0.3, "bulge_m": 0.014, "curl_m": 0.008, "sweep_m": 0.02},
                            "temple": {"hem_z": 1.318, "bulge_m": 0.022, "curl_m": 0.016, "under_share": 0.6, "forward_m": 0.012},
                            "part_side": {"hem_z": 1.318, "bulge_m": 0.022, "curl_m": 0.016, "under_share": 0.6},
                            "sides": {"hem_z": 1.312, "bulge_m": 0.024, "curl_m": 0.018, "under_share": 0.6},
                            "nape": {"hem_z": 1.292, "bulge_m": 0.020, "curl_m": 0.016, "under_share": 0.7}},
                     bun={"bearing_degrees": 180.0, "down_degrees": 112.0, "radius_m": 0.030, "stand": 0.5, "depth": 0.6}),
}
# Short cuts: the cap is the hair you see, feathered into a hairline; cards only break up its surface.
for name, shade, feather, margin in (("crop", 0.92, 0.7, 9.0), ("side_part", 0.82, 0.5, 8.0), ("swept_back", 0.82, 0.45, 8.0), ("bun", 0.78, 0.3, 6.0), ("waved_set", 0.7, 0.25, 5.0)):
    CUTS[name]["cap"] = {"shade": shade, "feather": feather}
    CUTS[name]["cap_past_hairline_degrees"] = 2.0
    CUTS[name]["root_margin_degrees"] = margin
    CUTS[name]["ragged_roots"] = 0.14
    # The shorter the cards, the flatter their tone, or rows of them read as roof tiles.
    CUTS[name]["tone_ramp"] = {"crop": 0.25, "side_part": 0.5, "swept_back": 0.5}.get(name, 0.7)
for tier in ("part", "crown", "sides", "fringe"):
    if "wave_degrees" in CUTS["waved_set"]["tiers"][tier]:
        CUTS["waved_set"]["tiers"][tier].update({"wave_degrees": 34.0, "wave_length_m": 0.05, "wave_ridge_m": 0.0045})
# Tightly curled hair cropped close: small curls every way, no combed direction.
CUTS["coil_crop"] = cut(CUTS["crop"], texture="coils", root_spacing_m=0.016,
                        cap={"shade": 0.85, "feather": 0.55})
for tier in CUTS["coil_crop"]["tiers"].values():
    tier.update({"walk_m": 0.024, "lift_m": 0.007, "width_m": 0.03, "gravity": 0.0, "comb": 0.0, "sweep_jitter_degrees": 180.0, "cup": 0.12})
# A man gone bald on top keeps a cropped fringe of hair round the sides and back.
CUTS["bald_crop"] = cut(CUTS["crop"], bald_within_degrees=44.0, hairline_degrees={"front": 46.0, "side": 76.0, "back": 110.0})

# ---------------------------------------------------------------- more cuts, for variety of shape and length


def longer(style, by_m, zones=("sides", "temple", "part_side", "nape")):
    """Drop the hem of a hanging cut by so much."""
    made = copy.deepcopy(style)
    for zone in zones:
        if zone in made["zones"] and "hem_z" in made["zones"][zone]:
            made["zones"][zone]["hem_z"] = round(made["zones"][zone]["hem_z"] - by_m, 4)
    return made


def fuller(style, factor):
    """More or less volume: how far the hair stands off the head, everywhere."""
    made = copy.deepcopy(style)
    for tier in made["tiers"].values():
        tier["lift_m"] = round(tier["lift_m"] * factor, 4)
    for zone in made["zones"].values():
        zone["bulge_m"] = round(zone["bulge_m"] * factor, 4)
        zone["curl_m"] = round(zone.get("curl_m", 0.0) * factor, 4)
    return made


# Shoulder-length hair in soft waves, the ends turned a little.
CUTS["long_waves"] = longer(cut(BOB, zones__sides__bulge_m=0.050, zones__sides__curl_m=0.016, zones__nape__bulge_m=0.046, zones__nape__curl_m=0.014,
                                zones__temple__bulge_m=0.048, zones__temple__curl_m=0.014, zones__temple__forward_m=0.02,
                                zones__part_side__bulge_m=0.048, zones__part_side__curl_m=0.014,
                                zones__sides__wave_m=0.009, zones__sides__wave_count=2.5, zones__nape__wave_m=0.008, zones__nape__wave_count=2.5,
                                zones__temple__wave_m=0.009, zones__temple__wave_count=2.5, zones__part_side__wave_m=0.009, zones__part_side__wave_count=2.5,
                                tips_from=0.74, row_every_m=0.022), 0.075)
# A long bob to the collar, straighter, the ends flicked under.
CUTS["lob"] = longer(cut(BOB, zones__sides__bulge_m=0.046, zones__sides__curl_m=0.034, zones__nape__bulge_m=0.042,
                         zones__sides__wave_m=0.004, zones__sides__wave_count=1.5, zones__temple__wave_m=0.004, zones__temple__wave_count=1.5), 0.04)
# A flat chin-length bob with little lift: neat, close to the head.
CUTS["bob_flat"] = fuller(cut(BOB, zones__temple__forward_m=0.02), 0.62)
# A pageboy: bangs, the sides to the jaw, the ends rolled well under.
CUTS["pageboy"] = longer(cut(CUTS["bob_bangs"], zones__sides__curl_m=0.058, zones__nape__curl_m=0.05, zones__temple__curl_m=0.05,
                             zones__sides__bulge_m=0.06, zones__temple__bulge_m=0.058), 0.014)
# A shingle: full on top, cut close and tapered up the back of the neck, the sides to the ear.
CUTS["shingle"] = cut(BOB, zones__sides__hem_z=1.312, zones__temple__hem_z=1.318, zones__part_side__hem_z=1.318,
                      zones__sides__bulge_m=0.040, zones__sides__curl_m=0.03, zones__temple__bulge_m=0.04, zones__temple__curl_m=0.028,
                      hairline_degrees={"front": 47.0, "side": 84.0, "back": 116.0},
                      zones__nape={"hang_m": 0.014, "bulge_m": 0.012, "curl_m": 0.0},
                      tiers__nape={"lift_m": 0.004, "width_m": 0.03, "cup": 0.07, "gravity": 0.8, "comb": 0.0, "walk_m": 0.03, "sweep_jitter_degrees": 6.0, "twist_degrees": 0.0})
# The knot worn higher, at the back of the crown.
CUTS["chignon"] = cut(CUTS["bun"], bun={"bearing_degrees": 180.0, "down_degrees": 72.0, "radius_m": 0.044, "stand": 0.62, "depth": 0.8})
for tier in ("part", "crown"):
    CUTS["chignon"]["tiers"][tier]["lift_m"] = 0.016
CUTS["chignon"]["tiers"]["fringe"]["lift_m"] = 0.009
# A man's hair parted in the middle and slicked to each side.
CUTS["centre_part"] = cut(CUTS["side_part"], part__x_m=0.0, part__brush_back=0.35, part__interleave_m=0.006)
for tier in ("part", "crown", "fringe"):
    CUTS["centre_part"]["tiers"][tier].update({"lift_m": 0.008, "walk_m": 0.07})
# The front brushed up high and back.
CUTS["pompadour"] = cut(CUTS["swept_back"])
CUTS["pompadour"]["tiers"]["fringe"].update({"lift_m": 0.024, "walk_m": 0.12, "width_m": 0.04, "sweep_jitter_degrees": 2.0})
CUTS["pompadour"]["tiers"]["crown"].update({"lift_m": 0.022, "walk_m": 0.11})
CUTS["pompadour"]["fringe"]["hairline_cards"] = 22
# Longer and untidy: the top falling forward over the brow and out over the ears.
CUTS["tousled"] = cut(CUTS["side_part"], root_spacing_m=0.019, part__brush_back=0.0, tips_from=0.6, shortest_tip=0.72,
                      fringe={"exit_half_width_degrees": 56.0, "hairline_cards": 14, "both_sides": True})
CUTS["tousled"]["tiers"]["part"].update({"lift_m": 0.022, "walk_m": 0.11, "sweep_jitter_degrees": 22.0})
CUTS["tousled"]["tiers"]["crown"].update({"lift_m": 0.022, "walk_m": 0.10, "sweep_jitter_degrees": 26.0, "comb": 0.4})
CUTS["tousled"]["tiers"]["sides"].update({"lift_m": 0.012, "walk_m": 0.06, "sweep_jitter_degrees": 16.0})
CUTS["tousled"]["tiers"]["nape"].update({"lift_m": 0.008, "walk_m": 0.05, "sweep_jitter_degrees": 14.0})
CUTS["tousled"]["tiers"]["fringe"] = {"lift_m": 0.02, "width_m": 0.032, "cup": 0.09, "gravity": 0.5, "comb": 0.5, "comb_to": "front", "sweep_jitter_degrees": 18.0, "twist_degrees": 8.0}
CUTS["tousled"]["zones"] = {"fringe": {"hang_m": 0.034, "bulge_m": 0.018, "curl_m": 0.004}, "temple": {"hang_m": 0.03, "bulge_m": 0.02, "curl_m": 0.0},
                            "part_side": {"hang_m": 0.03, "bulge_m": 0.02, "curl_m": 0.0}, "sides": {"hang_m": 0.028, "bulge_m": 0.02, "curl_m": 0.0}, "nape": {"hang_m": 0.03, "bulge_m": 0.016, "curl_m": 0.0}}
# A side part on a hairline that has gone back at the temples.
CUTS["receded"] = cut(CUTS["side_part"], hairline_degrees={"front": 38.0, "side": 76.0, "back": 112.0}, part__front_y_m=-0.085)
# Curled hair grown out a little: a rounder, fuller shape than the close crop.
CUTS["coil_top"] = cut(CUTS["coil_crop"])
for name, tier in CUTS["coil_top"]["tiers"].items():
    tier.update({"lift_m": 0.020 if name in ("part", "crown", "fringe") else 0.010, "walk_m": 0.03})
# An Eton crop: a woman's hair cut as short as a boy's, sleek, with a side part.
CUTS["eton"] = cut(CUTS["side_part"], part__brush_back=0.2, part__drop_front_corner=True)
CUTS["eton"]["tiers"]["part"].update({"walk_m": 0.09, "lift_m": 0.010})
CUTS["eton"]["tiers"]["crown"].update({"walk_m": 0.075, "lift_m": 0.010})
CUTS["eton"]["tiers"]["fringe"].update({"walk_m": 0.075, "lift_m": 0.012})

CAST = {
    # id: (cut, hair colour, what makes this head theirs)
    "adela_voss": ("waved_set", [0.72, 0.30, 0.07], {}),
    "mina_vale": ("bob_bangs", [0.045, 0.04, 0.04], {}),
    "cal_dwyer": ("bald_crop", [0.85, 0.84, 0.80], {}),
    "cam_ortiz": ("eton", [0.045, 0.04, 0.04], {"mirror": True}),
    "evelyn_marsh": ("bun", [0.60, 0.59, 0.58], {}),
    "iris_bell": ("long_waves", [0.12, 0.075, 0.05], {}),
    "jonah_price": ("tousled", [0.12, 0.075, 0.05], {}),
    "juno_kells": ("shingle", [0.12, 0.075, 0.05], {"mirror": True}),
    "lena_ortiz": ("bob_flat", [0.045, 0.04, 0.04], {"mirror": True}),
    "mae_kessler": ("chignon", [0.85, 0.84, 0.80], {}),
    "malcolm_reed": ("coil_crop", [0.25, 0.24, 0.24], {}),
    "nadia_quell": ("bob_inverted", [0.045, 0.04, 0.04], {}),
    "noel_price": ("pompadour", [0.62, 0.27, 0.08], {}),
    "omar_bell": ("receded", [0.045, 0.04, 0.04], {"mirror": True}),
    "peter_wren": ("centre_part", [0.28, 0.17, 0.09], {}),
    "rhea_sato": ("pageboy", [0.045, 0.04, 0.04], {}),
    "sacha_reed": ("coil_top", [0.045, 0.04, 0.04], {}),
    "teresa_vale": ("lob", [0.045, 0.04, 0.04], {"mirror": True}),
    "transient_guests_a": ("side_part", [0.28, 0.17, 0.09], {"mirror": True}),
    "transient_guests_b": ("bob_swept", [0.20, 0.13, 0.08], {"mirror": True}),
}
BATCHES = [["adela_voss", "mina_vale", "cal_dwyer", "evelyn_marsh", "jonah_price"],
           ["cam_ortiz", "iris_bell", "juno_kells", "lena_ortiz", "mae_kessler"],
           ["malcolm_reed", "nadia_quell", "noel_price", "omar_bell", "peter_wren"],
           ["rhea_sato", "sacha_reed", "teresa_vale", "transient_guests_a", "transient_guests_b"]]



def style_for(person):
    """The finished style for one cast member: their cut, their colour, their seed."""
    name, colour, own = CAST[person]
    style = copy.deepcopy(CUTS[name])
    style.update(own)
    style["name"] = person
    style["cut"] = name
    style["seed"] = 1929 + list(CAST).index(person) * 7
    # Dark at the root, lighter at the tip; very dark hair keeps a little depth, white hair a little shadow.
    lift = 0.03 if max(colour) < 0.1 else 0.0
    vivid = max(colour) - min(colour) > 0.35           # red hair: keep it auburn, not orange
    style["colour"] = {"root": [round(min(1.0, c * (0.55 if vivid else 0.68) + lift * 0.3), 3) for c in colour],
                       "tip": [round(min(1.0, c * (0.92 if vivid else 1.18) + lift + (0.04 if vivid else 0.02)), 3) for c in colour],
                       "streak_share": 0.14}
    # Dark hair is seen by its shine; fair hair is matt.
    style["gloss"] = 0.85 if max(colour) < 0.1 else 0.55 if max(colour) < 0.32 else 0.15
    return style


def styles():
    return {person: style_for(person) for person in CAST}


if __name__ == "__main__":
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for person, style in styles().items():
        (out / (person + ".json")).write_text(json.dumps(style, indent=1), encoding="utf-8")
    (out / "batches.json").write_text(json.dumps(BATCHES, indent=1), encoding="utf-8")
    print("styles", len(CAST), "cuts in use", sorted(set(name for name, _, _ in CAST.values())))
