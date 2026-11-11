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
        "smock": ([{"kind": "jumper", "colour": colour, "vee": 0.06, "sleeves": 0.7, "ease": 0.018, "length": 0.14, "cloth": "cotton", "pattern": dots(accent, 2)}], [], []),
        "knit": ([{"kind": "jumper", "colour": colour, "vee": 0.09, "ease": 0.012, "length": 0.03}, {"kind": "hem", "colour": shade(colour, 0.6), "drop": -0.01}], [], ["arms"]),
        "evening_top": ([{"kind": "shirt", "name": "Bodice", "colour": colour, "vee": 0.13, "sleeves": 0.0, "length": 0.14, "cloth": "silk"}], [], []),
        "shirt_rolled": ([{"kind": "shirt", "colour": pale, "vee": 0.08, "sleeves": 0.55, "blouson": 0.01}], [{"kind": "braces", "colour": accent}], []),
        "shirt_long": ([{"kind": "shirt", "colour": pale, "vee": 0.05, "sleeves": 1.0}], [{"kind": "tie", "colour": accent, "length": 0.2}], ["arms"]),
        "jersey": ([{"kind": "jumper", "colour": colour, "vee": 0.0, "ease": 0.008, "length": 0.0,
                     "pattern": {"kind": "bands", "colour": accent, "width": 3, "cells": 3, "repeat": 4}}], [], ["arms", "chest"]),
        "wrap_blouse": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.17, "sleeves": 0.75, "blouson": 0.008, "cloth": "silk"},
                         {"kind": "sash", "colour": accent, "up": 0.1, "off": 0.008}], [], []),
        "bow_blouse": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.04, "sleeves": 1.0, "blouson": 0.01, "cloth": "silk"}, {"kind": "scarf", "colour": accent}], [], ["arms", "chest"]),
        "shell": ([{"kind": "shirt", "name": "Shell", "colour": colour, "vee": 0.07, "sleeves": 0.0, "length": 0.05, "cloth": "cotton", "pattern": dots(pale, 2)}], [], []),
        "tunic": ([{"kind": "jumper", "colour": colour, "vee": 0.1, "sleeves": 0.45, "ease": 0.013, "length": 0.07, "cloth": "cotton", "pattern": stripes(accent, 1)},
                   {"kind": "belt", "colour": shade(colour, 0.4)}], [], []),
        "henley": ([{"kind": "jumper", "colour": pale, "vee": 0.12, "sleeves": 0.5, "ease": 0.006, "length": 0.0, "cloth": "cotton"}],
                   [{"kind": "buttons", "colour": accent, "step": 0.045, "lift": 0.012, "size": 0.006}], []),
        "work_shirt": ([{"kind": "shirt", "colour": colour, "vee": 0.07, "sleeves": 1.0, "blouson": 0.008, "pattern": checks(pale, 1)}],
                       [{"kind": "pockets", "colour": shade(colour, 0.7), "up": 0.22, "lift": 0.012}], ["arms"]),
        "striped_shirt": ([{"kind": "shirt", "colour": pale, "vee": 0.06, "sleeves": 0.55, "pattern": stripes(colour, 1)}], [{"kind": "tie", "colour": accent, "length": 0.14}], []),
        "fairisle": ([{"kind": "jumper", "colour": colour, "vee": 0.0, "ease": 0.012, "length": 0.02,
                       "pattern": {"kind": "bands", "colour": accent, "width": 1, "cells": 5, "repeat": 8}}, {"kind": "hem", "colour": shade(colour, 0.6), "drop": -0.01}], [], ["arms", "chest"]),
        "pyjama_top": ([{"kind": "shirt", "colour": pale, "vee": 0.1, "sleeves": 1.0, "ease": 0.012, "length": 0.14, "pattern": stripes(colour, 1)}], [], ["arms"]),
    }
    return table[kind]


def bottom(kind, colour, accent, legs):
    hose = {"kind": "stockings", "colour": legs}
    table = {
        "full_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.34, "flare": 0.42, "pleats": 20}],
        "straight_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.42, "flare": 0.04}],
        "long_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.14, "flare": 0.28, "pleats": 12, "cloth": "silk"}],
        "short_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.5, "flare": 0.22, "pleats": 16}],
        "pencil_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.47, "flare": 0.0, "pattern": stripes(shade(colour, 1.7), 1)}],
        "pleated_midi": [{"kind": "skirt", "colour": colour, "hem": 0.3, "flare": 0.3, "pleats": 30}],
        "aline_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.4, "flare": 0.16, "pattern": checks(shade(colour, 1.6), 1)}],
        "slim_trousers": [{"kind": "trousers", "colour": colour, "width": 0.005}],
        "sailor_trousers": [{"kind": "trousers", "colour": colour, "width": 0.042, "turnups": False}, {"kind": "belt", "colour": accent}],
        "plus_fours": [{"kind": "stockings", "colour": accent}, {"kind": "trousers", "colour": colour, "width": 0.04, "ends": 0.3, "turnups": False, "pattern": checks(shade(colour, 1.7))}],
        "wide_trousers": [{"kind": "trousers", "colour": colour, "width": 0.03}],
        "narrow_trousers": [{"kind": "trousers", "colour": colour, "width": 0.012, "pattern": stripes(shade(colour, 1.8), 1)}],
        "check_trousers": [{"kind": "trousers", "colour": colour, "width": 0.02, "pattern": checks(shade(colour, 1.8))}],
        "knickerbockers": [{"kind": "stockings", "colour": accent}, {"kind": "trousers", "colour": colour, "width": 0.028, "ends": 0.36, "turnups": False}],
        "overalls": [{"kind": "trousers", "colour": colour, "width": 0.028}, {"kind": "bib", "colour": colour}],
        "pyjama_trousers": [{"kind": "trousers", "colour": [min(1.0, 0.55 + 0.45 * x) for x in colour], "width": 0.028, "turnups": False,
                             "pattern": stripes(colour, 1), "cloth": "cotton"}],
    }
    return table[kind]


def over(kind, colour, accent):
    table = {
        "cardigan": ([{"kind": "cardigan", "colour": colour, "vee": 0.32}], [], ["warm"]),
        "boxy_jacket": ([{"kind": "jacket", "colour": colour, "vee": 0.24, "length": 0.01, "ease": 0.021, "shoulders": 0.004}, {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.24}],
                        [{"kind": "buttons", "colour": accent, "step": 0.085, "lift": 0.038, "size": 0.011}], []),
        "long_jacket": ([{"kind": "jacket", "colour": colour, "vee": 0.3, "length": 0.17, "skirted": 0.012, "pattern": stripes(shade(colour, 1.9), 1)},
                         {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.3}], [{"kind": "pockets", "colour": shade(colour, 0.6), "up": -0.03, "lift": 0.038}], []),
        "bolero": ([{"kind": "jacket", "colour": colour, "vee": 0.34, "length": -0.13, "ease": 0.02}], [], []),
        "blazer": ([{"kind": "jacket", "colour": colour, "vee": 0.28, "length": 0.05, "ease": 0.02, "pattern": stripes(accent, 2)}, {"kind": "lapels", "colour": colour, "vee": 0.28}],
                   [{"kind": "buttons", "colour": accent, "step": 0.07, "lift": 0.036, "size": 0.01}, {"kind": "pockets", "colour": shade(colour, 0.7), "up": -0.02, "lift": 0.036}], []),
        "knit_vest": ([{"kind": "waistcoat", "colour": colour, "vee": 0.18, "cloth": "knit", "pattern": {"kind": "bands", "colour": accent, "width": 1, "cells": 4, "repeat": 6}}], [], ["warm"]),
        "duster": ([{"kind": "coat", "colour": [min(1.0, 0.45 + 0.55 * x) for x in colour], "vee": 0.22, "hem": 0.2, "flare": 0.06, "cloth": "cotton"}], [], []),
        "trench": ([{"kind": "coat", "colour": colour, "vee": 0.14, "hem": 0.36, "flare": 0.14}, {"kind": "belt", "colour": shade(colour, 0.5), "off": 0.029}, {"kind": "lapels", "colour": shade(colour, 0.8), "vee": 0.14}],
                   [{"kind": "buttons", "colour": shade(colour, 0.4), "step": 0.08, "lift": 0.036, "size": 0.01}], ["warm"]),
        "stole": ([{"kind": "shawl", "colour": colour, "length": 0.13, "cloth": "silk"}], [], []),
        "waistcoat": ([{"kind": "waistcoat", "colour": colour, "vee": 0.22}], [{"kind": "buttons", "colour": accent, "step": 0.06, "lift": 0.026, "size": 0.007}], []),
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
        "cloche": {"kind": "cloche", "colour": colour, "band": accent, "brim": 1.0},
        "toque": {"kind": "toque", "colour": colour, "band": accent, "brim": 0.0},
        "wide_hat": {"kind": "wide", "colour": colour, "band": accent, "brim": 2.3},
        "boater": {"kind": "boater", "colour": [0.85, 0.76, 0.5], "band": accent, "brim": 1.0},
        "beret": {"kind": "beret", "colour": colour, "band": colour, "brim": 0.0},
        "headscarf": {"kind": "headscarf", "colour": accent, "band": colour, "brim": 0.0},
        "cap": {"kind": "cap", "colour": colour, "band": colour, "brim": 1.0},
        "derby": {"kind": "derby", "colour": colour, "band": BLACK, "brim": 0.6},
        "fedora": {"kind": "fedora", "colour": colour, "band": accent, "brim": 1.35},
    }
    return table[kind]


def feet(kind, colour):
    table = {"strap": [{"kind": "shoes", "colour": colour, "strap": True}], "oxford": [{"kind": "shoes", "colour": colour}], "pumps": [{"kind": "shoes", "colour": shade(colour, 1.6)}],
             "ankle_boots": [{"kind": "boots", "colour": colour, "height": 0.08}], "tall_boots": [{"kind": "boots", "colour": colour, "height": 0.27}],
             "boots": [{"kind": "boots", "colour": colour, "height": 0.17}]}
    return table[kind]


# id: three sets, each (top, bottom, over, head, feet); "-" leaves that slot empty.
STYLES = {
    "adela_voss": [("wrap_blouse", "full_skirt", "cardigan", "-", "strap"), ("bow_blouse", "pencil_skirt", "bolero", "cloche", "pumps"), ("evening_top", "long_skirt", "stole", "-", "strap")],
    "mina_vale": [("knit", "pleated_midi", "knit_vest", "-", "strap"), ("blouse_long", "aline_skirt", "blazer", "beret", "oxford"), ("shell", "long_skirt", "cape", "toque", "ankle_boots")],
    "cal_dwyer": [("henley", "check_trousers", "waistcoat", "cap", "oxford"), ("shirt_long", "slim_trousers", "blazer", "fedora", "oxford"), ("pyjama_top", "pyjama_trousers", "dressing_gown", "-", "oxford")],
    "cam_ortiz": [("jersey", "knickerbockers", "knit_vest", "cap", "ankle_boots"), ("striped_shirt", "narrow_trousers", "boxy_jacket", "-", "oxford"), ("work_shirt", "sailor_trousers", "duster", "-", "boots")],
    "evelyn_marsh": [("blouse_long", "long_skirt", "cardigan", "-", "ankle_boots"), ("bow_blouse", "straight_skirt", "trench", "-", "pumps"), ("smock", "full_skirt", "shawl", "wide_hat", "strap")],
    "iris_bell": [("shirt_rolled", "overalls", "apron", "headscarf", "boots"), ("tunic", "pleated_midi", "cardigan", "-", "strap"), ("evening_top", "long_skirt", "cape", "wide_hat", "strap")],
    "jonah_price": [("pyjama_top", "pyjama_trousers", "dressing_gown", "-", "oxford"), ("shirt_long", "narrow_trousers", "long_coat", "-", "oxford"), ("fairisle", "wide_trousers", "long_jacket", "fedora", "ankle_boots")],
    "juno_kells": [("henley", "sailor_trousers", "waistcoat", "-", "ankle_boots"), ("wrap_blouse", "slim_trousers", "duster", "-", "oxford"), ("shell", "short_skirt", "bolero", "beret", "strap")],
    "lena_ortiz": [("smock", "full_skirt", "apron", "headscarf", "boots"), ("blouse_long", "aline_skirt", "shawl", "-", "ankle_boots"), ("wrap_blouse", "pencil_skirt", "swing_coat", "toque", "pumps")],
    "mae_kessler": [("blouse_long", "long_skirt", "shawl", "-", "boots"), ("tunic", "aline_skirt", "long_coat", "-", "ankle_boots"), ("evening_top", "pleated_midi", "cape", "wide_hat", "pumps")],
    "malcolm_reed": [("shirt_rolled", "overalls", "apron", "cap", "boots"), ("work_shirt", "check_trousers", "long_jacket", "derby", "oxford"), ("fairisle", "wide_trousers", "waistcoat", "fedora", "ankle_boots")],
    "nadia_quell": [("shell", "straight_skirt", "knit_vest", "-", "strap"), ("bow_blouse", "pencil_skirt", "long_jacket", "boater", "pumps"), ("evening_top", "long_skirt", "swing_coat", "wide_hat", "strap")],
    "noel_price": [("shirt_rolled", "wide_trousers", "apron", "-", "oxford"), ("striped_shirt", "slim_trousers", "trench", "fedora", "oxford"), ("jersey", "plus_fours", "waistcoat", "cap", "boots")],
    "omar_bell": [("shirt_rolled", "overalls", "apron", "cap", "boots"), ("shirt_long", "check_trousers", "boxy_jacket", "-", "oxford"), ("henley", "wide_trousers", "knit_vest", "derby", "ankle_boots")],
    "peter_wren": [("shirt_long", "narrow_trousers", "waistcoat", "-", "oxford"), ("striped_shirt", "slim_trousers", "blazer", "derby", "oxford"), ("fairisle", "plus_fours", "long_coat", "-", "oxford")],
    "rhea_sato": [("blouse_short", "aline_skirt", "stole", "-", "strap"), ("tunic", "short_skirt", "boxy_jacket", "-", "tall_boots"), ("evening_top", "long_skirt", "cape", "beret", "pumps")],
    "sacha_reed": [("jersey", "wide_trousers", "waistcoat", "cap", "boots"), ("work_shirt", "narrow_trousers", "duster", "boater", "oxford"), ("shirt_rolled", "knickerbockers", "boxy_jacket", "-", "ankle_boots")],
    "teresa_vale": [("blouse_short", "full_skirt", "apron", "-", "strap"), ("wrap_blouse", "pleated_midi", "cape", "boater", "ankle_boots"), ("knit", "short_skirt", "swing_coat", "cloche", "tall_boots")],
    "transient_guests_a": [("henley", "wide_trousers", "waistcoat", "-", "boots"), ("shirt_long", "check_trousers", "trench", "fedora", "oxford"), ("jersey", "narrow_trousers", "long_coat", "cap", "boots")],
    "transient_guests_b": [("smock", "short_skirt", "cardigan", "headscarf", "strap"), ("bow_blouse", "straight_skirt", "swing_coat", "wide_hat", "pumps"), ("knit", "full_skirt", "stole", "-", "tall_boots")],
}
SET_TAGS = [["casual", "home"], ["formal", "street"], ["occasion"]]
# A second colour for each person, chosen to stand against their own.
SECOND = {
    "adela_voss": [0.03, 0.08, 0.3], "mina_vale": [0.72, 0.42, 0.04], "cal_dwyer": [0.42, 0.05, 0.06], "cam_ortiz": [0.75, 0.5, 0.04], "evelyn_marsh": [0.02, 0.3, 0.3],
    "iris_bell": [0.85, 0.42, 0.03], "jonah_price": [0.5, 0.15, 0.05], "juno_kells": [0.7, 0.12, 0.25], "lena_ortiz": [0.7, 0.45, 0.05], "mae_kessler": [0.4, 0.34, 0.55],
    "malcolm_reed": [0.55, 0.2, 0.05], "nadia_quell": [0.8, 0.7, 0.5], "noel_price": [0.65, 0.3, 0.05], "omar_bell": [0.45, 0.06, 0.06], "peter_wren": [0.1, 0.25, 0.22],
    "rhea_sato": [0.75, 0.06, 0.2], "sacha_reed": [0.75, 0.5, 0.08], "teresa_vale": [0.72, 0.03, 0.03], "transient_guests_a": [0.6, 0.48, 0.12], "transient_guests_b": [0.5, 0.2, 0.25],
}
NEUTRALS = [[0.16, 0.13, 0.11], [0.35, 0.3, 0.24], [0.08, 0.08, 0.09]]


def decal(part, cell, at, size=0.05, colour=None, **more):
    return dict({"kind": "decal", "_to": part, "cell": cell, "at": at, "size": size, "colour": colour or [0.9, 0.88, 0.8]}, **more)


# Details the wardrobe bible names, and a little wear, per person.
DETAILS = {
    "adela_voss": [decal("a_top", "flower", "chest_l", 0.045, [0.75, 0.1, 0.12]), decal("b_over", "brooch", "lapel_l", 0.035, [0.8, 0.6, 0.1])],
    "mina_vale": [decal("b_over", "pocket", "chest_l", 0.06, [0.75, 0.8, 0.95]), decal("a_over", "darn", "elbow_l", 0.06, [0.5, 0.6, 0.9])],
    "cal_dwyer": [decal("a_over", "pocket", "hip_l", 0.07, [0.2, 0.08, 0.03]), decal("a_top", "darn", "elbow_r", 0.07, [0.4, 0.2, 0.05]), decal("c_over", "patch", "elbow_l", 0.08, [0.2, 0.05, 0.05])],
    "cam_ortiz": [decal("a_bottom", "patch", "knee_l", 0.08, [0.25, 0.14, 0.06]), decal("a_top", "pin", "chest_l", 0.035, [0.8, 0.6, 0.1]), decal("c_over", "stain", "hip_r", 0.1, [0.15, 0.1, 0.06])],
    "evelyn_marsh": [decal("b_over", "brooch", "throat", 0.035, [0.8, 0.6, 0.1]), decal("a_over", "pocket", "hip_r", 0.07, [0.6, 0.3, 0.55])],
    "iris_bell": [decal("a_bottom", "stain", "thigh_l", 0.11, [0.9, 0.5, 0.05]), decal("a_bottom", "stain", "shin_r", 0.09, [0.8, 0.1, 0.12]), decal("a_bottom", "stain", "knee_l", 0.07, [0.9, 0.9, 0.85]),
                  decal("a_over", "stain", "belly", 0.12, [0.1, 0.5, 0.3]), decal("b_top", "flower", "chest_r", 0.05, [0.9, 0.5, 0.05])],
    "jonah_price": [decal("a_over", "stain", "chest_l", 0.07, [0.05, 0.04, 0.08]), decal("b_over", "darn", "elbow_l", 0.07, [0.1, 0.15, 0.4])],
    "juno_kells": [decal("b_over", "patch", "elbow_r", 0.08, [0.05, 0.2, 0.22]), decal("a_top", "pin", "chest_l", 0.03, [0.85, 0.2, 0.3]), decal("a_bottom", "darn", "knee_r", 0.07, [0.1, 0.3, 0.32])],
    "lena_ortiz": [decal("a_top", "patch", "elbow_l", 0.075, [0.5, 0.1, 0.15]), decal("a_top", "patch", "elbow_r", 0.075, [0.55, 0.12, 0.1]), decal("a_over", "pocket", "hip_l", 0.08, [0.6, 0.6, 0.55]),
                   decal("b_top", "lace", "throat", 0.07, [0.95, 0.93, 0.88], wide=1.6)],
    "mae_kessler": [decal("b_over", "brooch", "throat", 0.04, [0.05, 0.05, 0.06]), decal("a_top", "lace", "throat", 0.07, [0.95, 0.93, 0.88], wide=1.6), decal("c_over", "brooch", "chest_l", 0.035, [0.75, 0.75, 0.7])],
    "malcolm_reed": [decal("a_bottom", "stain", "knee_l", 0.11, [0.12, 0.08, 0.04]), decal("a_bottom", "stain", "knee_r", 0.1, [0.14, 0.09, 0.04]), decal("a_bottom", "pocket", "chest_l", 0.07, [0.1, 0.16, 0.02]),
                     decal("b_over", "leaf", "lapel_l", 0.04, [0.2, 0.45, 0.05])],
    "nadia_quell": [decal("b_over", "pocket", "chest_l", 0.06, [0.15, 0.0, 0.01]), decal("c_over", "pin", "lapel_l", 0.035, [0.8, 0.7, 0.5])],
    "noel_price": [decal("b_over", "pocket", "chest_l", 0.07, [0.03, 0.01, 0.2]), decal("a_over", "stain", "belly", 0.09, [0.5, 0.45, 0.35])],
    "omar_bell": [decal("a_over", "stain", "belly", 0.12, [0.1, 0.08, 0.07]), decal("a_bottom", "patch", "knee_r", 0.08, [0.35, 0.2, 0.05]), decal("a_bottom", "pocket", "chest_l", 0.07, [0.3, 0.16, 0.02])],
    "peter_wren": [decal("b_over", "darn", "elbow_l", 0.07, [0.2, 0.1, 0.04]), decal("b_over", "darn", "elbow_r", 0.07, [0.2, 0.1, 0.04]), decal("a_over", "stitch", "chest_l", 0.06, [0.6, 0.4, 0.1])],
    "rhea_sato": [decal("c_top", "flower", "chest_l", 0.05, [0.85, 0.1, 0.25]), decal("b_over", "pin", "lapel_l", 0.03, [0.85, 0.1, 0.25])],
    "sacha_reed": [decal("b_over", "stripe", "chest_l", 0.3, [0.2, 0.1, 0.04], turn=28, wide=0.12), decal("a_bottom", "patch", "knee_l", 0.08, [0.08, 0.2, 0.16])],
    "teresa_vale": [decal("b_over", "pin", "chest_l", 0.035, [0.75, 0.75, 0.7]), decal("a_over", "pocket", "hip_r", 0.08, [0.6, 0.6, 0.55])],
    "transient_guests_a": [decal("b_over", "ticket", "lapel_l", 0.05, [0.85, 0.8, 0.6]), decal("a_bottom", "patch", "knee_r", 0.08, [0.4, 0.4, 0.42]), decal("c_over", "darn", "elbow_l", 0.07, [0.2, 0.2, 0.22])],
    "transient_guests_b": [decal("b_over", "ticket", "lapel_l", 0.05, [0.85, 0.8, 0.6]), decal("a_over", "darn", "elbow_r", 0.07, [0.4, 0.38, 0.4]), decal("c_over", "patch", "hip_l", 0.07, [0.3, 0.2, 0.2])],
}


def hash_index(text):
    return sum(ord(ch) for ch in text)


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
            s0 = SECOND[cid]
            # Each set leads with a different colour: the person's own, then a
            # dark neutral under their colour, then their second colour.
            colour = [c0, NEUTRALS[hash_index(cid) % 3], shade(s0, 0.75)][index]
            over_colour = [shade(s0, 0.9), c0, shade(c0, 0.5)][index]
            rows, trim, covers = top(t, [c0, c0, s0][index], a0, [pale, WHITE, [min(1.0, 0.6 + 0.4 * x) for x in s0]][index])
            parts[letter + "_top"] = {"slot": "top", "set": letter, "tags": SET_TAGS[index] + (["night"] if t.startswith("pyjama") else []), "covers": covers + ["trunk"], "rows": rows, "trim": trim}
            parts[letter + "_bottom"] = {"slot": "bottom", "set": letter,
                                         "tags": SET_TAGS[index] + (["night"] if b.startswith("pyjama") else []) + (["work"] if b == "overalls" else []),
                                         # Trousers fit the legs; a skirt hangs clear of them, so the body shows beneath it.
                                         "covers": ["hips"] if b in ("straight_skirt", "pencil_skirt") else [] if b.endswith(("skirt", "midi")) else ["legs", "hips"],
                                         "rows": bottom(b, colour, a0, [[0.5, 0.36, 0.26], [0.62, 0.55, 0.45], [0.12, 0.1, 0.1]][index]), "trim": []}
            rows, trim, extra_tags = over(o, over_colour, a0)
            parts[letter + "_over"] = {"slot": "over", "set": letter, "tags": SET_TAGS[index] + extra_tags,
                                       "covers": [] if o in ("apron", "waistcoat", "knit_vest", "shawl", "stole", "cape") else ["arms", "chest"], "rows": rows, "trim": trim}
            if h != "-":
                parts[letter + "_head"] = {"slot": "head", "set": letter, "tags": SET_TAGS[index], "covers": [], "rows": [], "trim": [],
                                           "hat": head(h, shade(c0, 0.6) if index else shade(c0, 0.8), a0)}
            parts[letter + "_feet"] = {"slot": "feet", "set": letter, "tags": SET_TAGS[index], "covers": ["feet"], "rows": feet(f, [shade(c0, 0.3), BLACK, shade(a0, 0.5)][index]), "trim": []}
            looks[letter] = [name for name in parts if name.startswith(letter + "_")]
        looks["mix1"] = [n for n in ("a_top", "b_bottom", "c_over", "b_head", "a_feet") if n in parts]
        looks["mix2"] = [n for n in ("c_top", "a_bottom", "b_over", "c_head", "b_feet") if n in parts]
        for row in DETAILS.get(cid, []):
            row = dict(row)
            target = row.pop("_to")
            if target in parts:
                parts[target]["trim"] = parts[target]["trim"] + [row]
        person["parts"] = parts
        person["looks"] = looks
        person.pop("outfits", None)
