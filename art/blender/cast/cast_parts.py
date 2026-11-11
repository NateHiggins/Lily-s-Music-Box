"""Mix-and-match wardrobe parts, added to the cast table by make_cast_wardrobe.py.

Lily, 2026-11-11: more variation in silhouette and style; three sets of
mix-and-match parts each. A set is a top, a bottom, an outer layer, headwear
and footwear. Any part goes with any other, across sets.
"""

CREAM = [0.9, 0.84, 0.66]
WHITE = [0.92, 0.9, 0.84]
BLACK = [0.02, 0.02, 0.025]


def shade(colour, k):
    return [round(min(1.0, c * k), 4) for c in colour]


def stripes(colour, width=2):
    return {"kind": "stripes", "colour": colour, "width": width, "cells": 4, "repeat": 5}


def checks(colour, width=2):
    return {"kind": "checks", "colour": colour, "width": width, "cells": 4, "repeat": 5}


def dots(colour, width=3):
    return {"kind": "dots", "colour": colour, "width": width, "cells": 6, "repeat": 6}


def top(kind, colour, accent, pale):
    table = {
        "blouse_short": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.08, "sleeves": 0.5, "blouson": 0.012, "cloth": "silk"}],
                         [{"kind": "buttons", "colour": accent, "step": 0.07, "lift": 0.016, "size": 0.007}], []),
        "blouse_long": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.05, "sleeves": 1.0, "blouson": 0.014}], [], ["arms"]),
        "smock": ([{"kind": "jumper", "colour": colour, "vee": 0.06, "sleeves": 0.7, "ease": 0.03, "length": 0.14, "cloth": "cotton", "pattern": dots(accent, 2)}], [], []),
        "knit": ([{"kind": "jumper", "colour": colour, "vee": 0.09, "ease": 0.02, "length": 0.03}, {"kind": "hem", "colour": shade(colour, 0.6), "drop": -0.01}], [], ["arms"]),
        "evening_top": ([{"kind": "shirt", "name": "Bodice", "colour": colour, "vee": 0.13, "sleeves": 0.0, "length": 0.14, "cloth": "silk"}], [], []),
        "shirt_rolled": ([{"kind": "shirt", "colour": pale, "vee": 0.08, "sleeves": 0.55, "blouson": 0.01}], [{"kind": "braces", "colour": accent}], []),
        "shirt_long": ([{"kind": "shirt", "colour": pale, "vee": 0.05, "sleeves": 1.0}], [{"kind": "tie", "colour": accent, "length": 0.2}], ["arms"]),
        "jersey": ([{"kind": "jumper", "colour": colour, "vee": 0.0, "ease": 0.012, "length": 0.0,
                     "pattern": {"kind": "bands", "colour": accent, "width": 3, "cells": 3, "repeat": 4}}], [], ["arms", "chest"]),
        "pyjama_top": ([{"kind": "shirt", "colour": pale, "vee": 0.1, "sleeves": 1.0, "ease": 0.012, "length": 0.14, "pattern": stripes(colour, 1)}], [], ["arms"]),
    }
    return table[kind]


def bottom(kind, colour, accent, legs):
    hose = {"kind": "stockings", "colour": legs}
    table = {
        "full_skirt": [hose, {"kind": "skirt", "colour": colour, "hem": 0.34, "flare": 0.42, "pleats": 20}],
        "straight_skirt": [hose, {"kind": "skirt", "colour": colour, "hem": 0.42, "flare": 0.04}],
        "long_skirt": [hose, {"kind": "skirt", "colour": colour, "hem": 0.14, "flare": 0.28, "pleats": 12, "cloth": "silk"}],
        "short_skirt": [hose, {"kind": "skirt", "colour": colour, "hem": 0.5, "flare": 0.22, "pleats": 16}],
        "wide_trousers": [{"kind": "trousers", "colour": colour, "width": 0.06}],
        "narrow_trousers": [{"kind": "trousers", "colour": colour, "width": 0.012, "pattern": stripes(shade(colour, 1.8), 1)}],
        "check_trousers": [{"kind": "trousers", "colour": colour, "width": 0.035, "pattern": checks(shade(colour, 1.8))}],
        "knickerbockers": [{"kind": "stockings", "colour": accent}, {"kind": "trousers", "colour": colour, "width": 0.05, "ends": 0.36, "turnups": False}],
        "overalls": [{"kind": "trousers", "colour": colour, "width": 0.05}, {"kind": "bib", "colour": colour}],
        "pyjama_trousers": [{"kind": "trousers", "colour": [min(1.0, 0.55 + 0.45 * x) for x in colour], "width": 0.05, "turnups": False,
                             "pattern": stripes(colour, 1), "cloth": "cotton"}],
    }
    return table[kind]


def over(kind, colour, accent):
    table = {
        "cardigan": ([{"kind": "cardigan", "colour": colour, "vee": 0.32}], [], ["warm"]),
        "boxy_jacket": ([{"kind": "jacket", "colour": colour, "vee": 0.24, "length": 0.01, "ease": 0.024, "shoulders": 0.012}, {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.24}],
                        [{"kind": "buttons", "colour": accent, "step": 0.085, "lift": 0.034, "size": 0.011}], []),
        "long_jacket": ([{"kind": "jacket", "colour": colour, "vee": 0.3, "length": 0.17, "skirted": 0.012, "pattern": stripes(shade(colour, 1.9), 1)},
                         {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.3}], [{"kind": "pockets", "colour": shade(colour, 0.6), "up": -0.03, "lift": 0.034}], []),
        "waistcoat": ([{"kind": "waistcoat", "colour": colour, "vee": 0.22}], [{"kind": "buttons", "colour": accent, "step": 0.06, "lift": 0.02, "size": 0.007}], []),
        "long_coat": ([{"kind": "coat", "colour": colour, "vee": 0.08, "hem": 0.28, "flare": 0.1}, {"kind": "sash", "colour": shade(colour, 0.5), "up": 0.07, "off": 0.027}],
                      [{"kind": "buttons", "colour": shade(colour, 0.5), "step": 0.1, "lift": 0.036, "size": 0.013, "below": 0.12}], ["warm"]),
        "swing_coat": ([{"kind": "coat", "colour": colour, "vee": 0.1, "hem": 0.42, "flare": 0.4, "pattern": checks(shade(colour, 1.7), 1)}], [], ["warm"]),
        "cape": ([{"kind": "cape", "colour": colour, "length": 0.36, "swing": 0.09}, {"kind": "scarf", "colour": accent}], [], ["warm"]),
        "shawl": ([{"kind": "shawl", "colour": colour, "pattern": {"kind": "herringbone", "colour": accent, "cells": 3, "repeat": 4}}], [], ["warm"]),
        "apron": ([{"kind": "apron", "colour": colour, "hem": 0.46}], [], ["work"]),
        "dressing_gown": ([{"kind": "coat", "colour": colour, "vee": 0.3, "hem": 0.34, "flare": 0.14, "cloth": "silk"}, {"kind": "sash", "colour": accent, "up": 0.08, "off": 0.027}], [], ["night"]),
    }
    return table[kind]


def head(kind, colour, accent):
    table = {
        "cloche": {"colour": colour, "band": accent, "brim": 1.0},
        "toque": {"colour": colour, "band": accent, "brim": 0.0, "tall": 0.012},
        "wide_hat": {"colour": colour, "band": accent, "brim": 2.3},
        "headscarf": {"colour": accent, "band": colour, "brim": 0.0},
        "cap": {"kind": "cap", "colour": colour, "band": colour, "brim": 1.0},
        "derby": {"colour": colour, "band": BLACK, "brim": 0.6, "tall": 0.016},
        "fedora": {"colour": colour, "band": accent, "brim": 1.35, "tall": 0.026},
    }
    return table[kind]


def feet(kind, colour):
    table = {"strap": [{"kind": "shoes", "colour": colour, "strap": True}], "oxford": [{"kind": "shoes", "colour": colour}],
             "boots": [{"kind": "boots", "colour": colour, "height": 0.17}]}
    return table[kind]


# id: three sets, each (top, bottom, over, head, feet); "-" leaves that slot empty.
STYLES = {
    "adela_voss": [("blouse_short", "full_skirt", "cardigan", "-", "strap"), ("blouse_long", "straight_skirt", "boxy_jacket", "cloche", "strap"), ("evening_top", "long_skirt", "shawl", "-", "strap")],
    "mina_vale": [("knit", "short_skirt", "cardigan", "-", "strap"), ("blouse_long", "straight_skirt", "long_jacket", "cloche", "strap"), ("blouse_short", "long_skirt", "cape", "toque", "boots")],
    "cal_dwyer": [("jersey", "check_trousers", "waistcoat", "cap", "oxford"), ("shirt_long", "narrow_trousers", "long_jacket", "fedora", "oxford"), ("pyjama_top", "pyjama_trousers", "dressing_gown", "-", "oxford")],
    "cam_ortiz": [("jersey", "knickerbockers", "waistcoat", "cap", "boots"), ("shirt_long", "narrow_trousers", "boxy_jacket", "cap", "oxford"), ("shirt_rolled", "wide_trousers", "long_coat", "-", "boots")],
    "evelyn_marsh": [("blouse_long", "long_skirt", "cardigan", "-", "boots"), ("blouse_long", "straight_skirt", "long_coat", "toque", "boots"), ("smock", "full_skirt", "shawl", "wide_hat", "strap")],
    "iris_bell": [("shirt_rolled", "overalls", "apron", "headscarf", "boots"), ("smock", "full_skirt", "cardigan", "-", "strap"), ("evening_top", "long_skirt", "cape", "wide_hat", "strap")],
    "jonah_price": [("pyjama_top", "pyjama_trousers", "dressing_gown", "-", "oxford"), ("shirt_long", "narrow_trousers", "long_coat", "-", "oxford"), ("jersey", "wide_trousers", "long_jacket", "fedora", "boots")],
    "juno_kells": [("knit", "wide_trousers", "waistcoat", "-", "boots"), ("shirt_long", "narrow_trousers", "long_coat", "-", "oxford"), ("evening_top", "short_skirt", "boxy_jacket", "headscarf", "strap")],
    "lena_ortiz": [("smock", "full_skirt", "apron", "headscarf", "boots"), ("blouse_long", "long_skirt", "shawl", "headscarf", "boots"), ("blouse_long", "straight_skirt", "swing_coat", "toque", "strap")],
    "mae_kessler": [("blouse_long", "long_skirt", "shawl", "-", "boots"), ("blouse_long", "long_skirt", "long_coat", "toque", "boots"), ("evening_top", "long_skirt", "cape", "wide_hat", "boots")],
    "malcolm_reed": [("shirt_rolled", "overalls", "apron", "cap", "boots"), ("shirt_long", "check_trousers", "long_jacket", "cap", "oxford"), ("jersey", "wide_trousers", "waistcoat", "fedora", "boots")],
    "nadia_quell": [("blouse_long", "straight_skirt", "waistcoat", "-", "strap"), ("blouse_long", "straight_skirt", "long_jacket", "cloche", "strap"), ("evening_top", "long_skirt", "swing_coat", "wide_hat", "strap")],
    "noel_price": [("shirt_rolled", "wide_trousers", "apron", "-", "oxford"), ("shirt_long", "narrow_trousers", "long_coat", "fedora", "oxford"), ("jersey", "check_trousers", "waistcoat", "cap", "boots")],
    "omar_bell": [("shirt_rolled", "overalls", "apron", "cap", "boots"), ("shirt_long", "check_trousers", "boxy_jacket", "cap", "oxford"), ("jersey", "wide_trousers", "waistcoat", "derby", "boots")],
    "peter_wren": [("shirt_long", "narrow_trousers", "waistcoat", "-", "oxford"), ("shirt_long", "narrow_trousers", "long_jacket", "derby", "oxford"), ("jersey", "check_trousers", "long_coat", "derby", "oxford")],
    "rhea_sato": [("blouse_short", "straight_skirt", "shawl", "-", "strap"), ("blouse_long", "short_skirt", "boxy_jacket", "cloche", "strap"), ("evening_top", "long_skirt", "cape", "toque", "strap")],
    "sacha_reed": [("jersey", "wide_trousers", "waistcoat", "cap", "boots"), ("shirt_long", "narrow_trousers", "long_coat", "cap", "oxford"), ("shirt_rolled", "knickerbockers", "boxy_jacket", "-", "boots")],
    "teresa_vale": [("blouse_short", "full_skirt", "apron", "toque", "strap"), ("blouse_long", "straight_skirt", "cape", "toque", "boots"), ("knit", "short_skirt", "swing_coat", "cloche", "strap")],
    "transient_guests_a": [("shirt_rolled", "wide_trousers", "waistcoat", "-", "boots"), ("shirt_long", "check_trousers", "long_jacket", "fedora", "oxford"), ("jersey", "narrow_trousers", "long_coat", "cap", "boots")],
    "transient_guests_b": [("smock", "short_skirt", "cardigan", "headscarf", "strap"), ("blouse_long", "straight_skirt", "swing_coat", "cloche", "strap"), ("knit", "full_skirt", "shawl", "-", "boots")],
}
SET_TAGS = [["casual", "home"], ["formal", "street"], ["occasion"]]


def add_parts(cast):
    for cid, sets in STYLES.items():
        person = cast[cid]
        c0 = person["palette"]["colour"]
        a0 = person["palette"]["accent"]
        pale = [min(1.0, 0.62 + 0.38 * x) for x in c0]
        parts = {}
        looks = {}
        for index, (t, b, o, h, f) in enumerate(sets):
            letter = "abc"[index]
            colour = [c0, shade(c0, 0.62), shade(c0, 0.85)][index]
            over_colour = [shade(c0, 1.3), c0, a0 if sum(a0) < 2.2 else shade(c0, 0.45)][index]
            rows, trim, covers = top(t, colour if index == 2 else c0, a0, [pale, WHITE, pale][index])
            parts[letter + "_top"] = {"slot": "top", "set": letter, "tags": SET_TAGS[index] + (["night"] if t.startswith("pyjama") else []), "covers": covers, "rows": rows, "trim": trim}
            parts[letter + "_bottom"] = {"slot": "bottom", "set": letter,
                                         "tags": SET_TAGS[index] + (["night"] if b.startswith("pyjama") else []) + (["work"] if b == "overalls" else []), "covers": ["legs"],
                                         "rows": bottom(b, colour, a0, [[0.5, 0.36, 0.26], [0.62, 0.55, 0.45], [0.12, 0.1, 0.1]][index]), "trim": []}
            rows, trim, extra_tags = over(o, over_colour, a0)
            parts[letter + "_over"] = {"slot": "over", "set": letter, "tags": SET_TAGS[index] + extra_tags,
                                       "covers": [] if o in ("apron", "waistcoat", "shawl", "cape") else ["arms", "chest"], "rows": rows, "trim": trim}
            if h != "-":
                parts[letter + "_head"] = {"slot": "head", "set": letter, "tags": SET_TAGS[index], "covers": [], "rows": [], "trim": [],
                                           "hat": head(h, shade(c0, 0.6) if index else shade(c0, 0.8), a0)}
            parts[letter + "_feet"] = {"slot": "feet", "set": letter, "tags": SET_TAGS[index], "covers": [], "rows": feet(f, [shade(c0, 0.3), BLACK, shade(a0, 0.5)][index]), "trim": []}
            looks[letter] = [name for name in parts if name.startswith(letter + "_")]
        looks["mix1"] = [n for n in ("a_top", "b_bottom", "c_over", "b_head", "a_feet") if n in parts]
        looks["mix2"] = [n for n in ("c_top", "a_bottom", "b_over", "c_head", "b_feet") if n in parts]
        person["parts"] = parts
        person["looks"] = looks
        person.pop("outfits", None)
