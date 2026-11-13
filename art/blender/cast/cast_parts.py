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


def pack(asset_name, colour, **more):
    return dict({"kind": "asset", "asset": asset_name, "colour": colour}, **more)


def collar(colour, **more):
    """Ruling cast_collars_20261112: collars on everything that would have had one. A soft turned-down collar."""
    return dict({"kind": "collar", "colour": colour}, **more)


def coat_collar(colour):
    return collar(shade(colour, 0.8), out=0.022, fall=0.04, point=0.03)


def made(cloth, pattern=None):
    """Ruling cast_period_pass_20261112: a ready-made dress whose own picture tints to tiger, zebra or camouflage
    wears a plain period cloth instead, with a small pattern or none."""
    return {"cloth": cloth, "pattern": pattern, "scale": 9.0}


# Shoes are leather: brown, black, tan, oxblood. Never the colour of the frock.
LEATHERS = [[0.09, 0.05, 0.03], [0.02, 0.02, 0.025], [0.2, 0.1, 0.045], [0.15, 0.04, 0.04]]


# Whole outfits from the packs take more than their own slot.
REPLACES = {
    "flapper_dress": ["bottom"], "shift_dress": ["bottom"], "keyhole_dress": ["bottom"], "day_dress": ["bottom"], "blouse_pencil": ["bottom"],
    "skirt_suit": ["bottom", "over"], "trouser_suit": ["bottom", "over"], "tie_suit": ["bottom", "over"], "db_suit": ["bottom", "over"],
    "lounge_suit": ["bottom", "over"], "dinner_suit": ["bottom", "over"], "bowtie_suit": ["bottom", "over"], "elegant_suit": ["bottom", "over"],
    "work_overalls": ["bottom"], "robe": ["bottom", "over"],
}
# No garment hides the chest: it is the skin inside any open neck, and hidden it left a toothed hole there.
WHOLE = ["arms", "trunk", "hips", "legs"]


def top(kind, colour, accent, pale):
    table = {
        "flapper_dress": ([pack("aethelraed_flapper_dress", colour, name="Dress", skirt=True, made=made("silk"))], [], []),
        "shift_dress": ([pack("toigo_shift_dress", colour, name="Dress", skirt=True, made=made("cotton", checks(shade(colour, 1.5), 1)))], [], []),
        "keyhole_dress": ([pack("toigo_keyhole_neck_dress", colour, name="Dress", skirt=True, made=made("silk", dots(pale, 2)))], [], []),
        "day_dress": ([pack("wdg_mycenaean_tunic", colour, name="Dress", skirt=True, made=made("cotton", stripes(shade(colour, 1.5), 1)))], [], []),
        "blouse_pencil": ([pack("female_elegantsuit01", colour, name="Outfit", skirt=True, hem_to_calf=True)], [], ["arms", "trunk", "hips"]),
        "skirt_suit": ([pack("toigo_female_suit", colour, name="Suit", skirt=True, hem_to_calf=True)], [], ["arms", "trunk", "hips"]),
        "trouser_suit": ([pack("toigo_female_double-breasted_suit", colour, name="Suit")], [], WHOLE),
        "tie_suit": ([pack("toigo_male_suit_tie_and_jacket", colour, name="Suit")], [], WHOLE),
        "db_suit": ([pack("toigo_male_double-breasted_suit", colour, name="Suit")], [], WHOLE),
        "lounge_suit": ([pack("toigo_male_suit_3", colour, name="Suit")], [], WHOLE),
        # A dinner suit is black. Kept pale, it came out mint white.
        "dinner_suit": ([pack("toigo_suit_with_dinner_jacket", BLACK, name="Suit")], [], WHOLE),
        "bowtie_suit": ([pack("toigo_suit_with_jacket_and_bowtie", colour, name="Suit")], [], WHOLE),
        "elegant_suit": ([pack("male_elegantsuit01", colour, name="Suit")], [], WHOLE),
        "work_overalls": ([pack("male_worksuit01", colour, name="Overalls")], [], ["trunk", "hips", "legs"]),
        # A robe is open down the chest: the body under it stays, or the open neck shows the edge of a hidden part.
        # Review of cast_r10: skin showed between the robe's front and its sleeve. A vest is worn under it, so what
        # shows there is cloth, and the trunk under the vest can be hidden like any other.
        "robe": ([{"kind": "shirt", "name": "Vest", "colour": pale, "vee": 0.1, "sleeves": 0.0, "length": 0.14, "cloth": "cotton"},
                  pack("mindfront_kimono", colour, name="Robe")], [], ["arms", "hips", "legs"]),
        "fisherman": ([pack("toigo_fisherman_sweater", colour, name="Sweater")], [], ["arms"]),
        "blouse_short": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.08, "sleeves": 0.5, "blouson": 0.012, "cloth": "silk"}, collar(pale, fall=0.022, point=0.02)],
                         [{"kind": "buttons", "colour": accent, "step": 0.07, "lift": 0.016, "size": 0.007}], []),
        "blouse_long": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.05, "sleeves": 1.0, "blouson": 0.014}, collar(pale, fall=0.022, point=0.02)], [], ["arms"]),
        "smock": ([{"kind": "jumper", "colour": colour, "vee": 0.06, "sleeves": 0.7, "ease": 0.018, "length": 0.14, "cloth": "cotton", "pattern": dots(accent, 2)}], [], []),
        "knit": ([{"kind": "jumper", "colour": colour, "vee": 0.09, "ease": 0.012, "length": 0.03}, {"kind": "hem", "colour": shade(colour, 0.6), "drop": -0.01}], [], ["arms"]),
        "evening_top": ([{"kind": "shirt", "name": "Bodice", "colour": colour, "vee": 0.13, "sleeves": 0.0, "length": 0.14, "cloth": "silk"}], [], []),
        "shirt_rolled": ([{"kind": "shirt", "colour": pale, "vee": 0.08, "sleeves": 0.55, "blouson": 0.01}, collar(pale)], [{"kind": "braces", "colour": accent}], []),
        "shirt_long": ([{"kind": "shirt", "colour": pale, "vee": 0.05, "sleeves": 1.0}, collar(pale)], [{"kind": "tie", "colour": accent, "length": 0.2}], ["arms"]),
        "jersey": ([{"kind": "jumper", "colour": colour, "vee": 0.0, "ease": 0.008, "length": 0.0,
                     "pattern": {"kind": "bands", "colour": accent, "width": 3, "cells": 3, "repeat": 4}}], [], ["arms"]),
        "wrap_blouse": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.17, "sleeves": 0.75, "blouson": 0.008, "cloth": "silk"},
                         {"kind": "sash", "colour": accent, "up": 0.1, "off": 0.008}], [], []),
        "bow_blouse": ([{"kind": "shirt", "name": "Blouse", "colour": pale, "vee": 0.04, "sleeves": 1.0, "blouson": 0.01, "cloth": "silk"}, {"kind": "scarf", "colour": accent}], [], ["arms"]),
        "shell": ([{"kind": "shirt", "name": "Shell", "colour": colour, "vee": 0.07, "sleeves": 0.0, "length": 0.05, "cloth": "cotton", "pattern": dots(pale, 2)}], [], []),
        "tunic": ([{"kind": "jumper", "colour": colour, "vee": 0.1, "sleeves": 0.45, "ease": 0.013, "length": 0.07, "cloth": "cotton", "pattern": stripes(accent, 1)},
                   {"kind": "belt", "colour": shade(colour, 0.4)}], [], []),
        "henley": ([{"kind": "jumper", "colour": pale, "vee": 0.12, "sleeves": 0.5, "ease": 0.006, "length": 0.0, "cloth": "cotton"}],
                   [{"kind": "buttons", "colour": accent, "step": 0.045, "lift": 0.012, "size": 0.006}], []),
        "work_shirt": ([{"kind": "shirt", "colour": colour, "vee": 0.07, "sleeves": 1.0, "blouson": 0.008, "pattern": checks(pale, 1)}, collar(colour)],
                       [{"kind": "pockets", "colour": shade(colour, 0.7), "up": 0.22, "lift": 0.012}], ["arms"]),
        "striped_shirt": ([{"kind": "shirt", "colour": pale, "vee": 0.06, "sleeves": 0.55, "pattern": stripes(colour, 1)}, collar(pale)], [{"kind": "tie", "colour": accent, "length": 0.14}], []),
        "fairisle": ([{"kind": "jumper", "colour": colour, "vee": 0.0, "ease": 0.012, "length": 0.02,
                       "pattern": {"kind": "bands", "colour": accent, "width": 1, "cells": 5, "repeat": 8}}, {"kind": "hem", "colour": shade(colour, 0.6), "drop": -0.01}], [], ["arms"]),
        "pyjama_top": ([{"kind": "shirt", "colour": pale, "vee": 0.1, "sleeves": 1.0, "ease": 0.012, "length": 0.14, "pattern": stripes(colour, 1)}, collar(pale)], [], ["arms"]),
    }
    return table[kind]


def bottom(kind, colour, accent, legs):
    hose = {"kind": "stockings", "colour": legs}
    table = {
        "full_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.34, "flare": 0.42, "pleats": 20}],
        "straight_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.42, "flare": 0.04}],
        "long_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.14, "flare": 0.28, "pleats": 12, "cloth": "silk"}],
        "short_skirt": [{"kind": "skirt", "colour": colour, "hem": 0.5, "flare": 0.22, "pleats": 16}],
        "pack_full_skirt": [pack("toigo_long_full_skirt", colour, name="Skirt", skirt=True, made=made("wool"))],
        "pack_ruffle_skirt": [pack("toigo_skirt_with_lace_ruffle", colour, name="Skirt", skirt=True)],
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
        "boxy_jacket": ([{"kind": "jacket", "colour": colour, "vee": 0.24, "length": 0.01, "ease": 0.021, "shoulders": 0.0}, {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.24}],
                        [{"kind": "buttons", "colour": accent, "step": 0.085, "lift": 0.038, "size": 0.011}], []),
        "long_jacket": ([{"kind": "jacket", "colour": colour, "vee": 0.3, "length": 0.17, "skirted": 0.012, "pattern": stripes(shade(colour, 1.9), 1)},
                         {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.3}], [{"kind": "pockets", "colour": shade(colour, 0.6), "up": -0.03, "lift": 0.038}], []),
        "bolero": ([{"kind": "jacket", "colour": colour, "vee": 0.34, "length": -0.13, "ease": 0.02}], [], []),
        "blazer": ([{"kind": "jacket", "colour": colour, "vee": 0.28, "length": 0.05, "ease": 0.02, "pattern": stripes(accent, 2)}, {"kind": "lapels", "colour": colour, "vee": 0.28}],
                   [{"kind": "buttons", "colour": accent, "step": 0.07, "lift": 0.036, "size": 0.01}, {"kind": "pockets", "colour": shade(colour, 0.7), "up": -0.02, "lift": 0.036}], []),
        "knit_vest": ([{"kind": "waistcoat", "colour": colour, "vee": 0.18, "cloth": "knit", "pattern": {"kind": "bands", "colour": accent, "width": 1, "cells": 4, "repeat": 6}}], [], ["warm"]),
        # Review of cast_r10: pale, with no collar, lapels or buttons, the duster read as a bath robe.
        "duster": ([{"kind": "coat", "colour": shade(colour, 0.75), "vee": 0.22, "hem": 0.26, "flare": 0.06, "cloth": "cotton"}, {"kind": "lapels", "colour": shade(colour, 0.6), "vee": 0.22},
                    coat_collar(shade(colour, 0.75))],
                   [{"kind": "buttons", "colour": shade(colour, 0.4), "step": 0.09, "lift": 0.036, "size": 0.01, "below": 0.1}], []),
        "trench": ([{"kind": "coat", "colour": colour, "vee": 0.14, "hem": 0.36, "flare": 0.14}, {"kind": "belt", "colour": shade(colour, 0.5), "off": 0.029}, {"kind": "lapels", "colour": shade(colour, 0.8), "vee": 0.14},
                    coat_collar(colour)],
                   [{"kind": "buttons", "colour": shade(colour, 0.4), "step": 0.08, "lift": 0.036, "size": 0.01}], ["warm"]),
        # Review of cast_r10: as a short shawl the stole came out as two leaves on the shoulders. It is a short
        # cape: an even band over the shoulders and upper arms.
        "stole": ([{"kind": "cape", "colour": colour, "length": 0.17, "cloth": "silk"}], [], []),
        "waistcoat": ([{"kind": "waistcoat", "colour": colour, "vee": 0.22}], [{"kind": "buttons", "colour": accent, "step": 0.06, "lift": 0.026, "size": 0.007}], []),
        # Review of cast_r10: collarless, buttoned to the throat, sashed and flared, the long coat read as a cassock,
        # and the swing coat as a tent. Both get a proper V with lapels and a collar; the swing coat hangs straighter.
        "long_coat": ([{"kind": "coat", "colour": colour, "vee": 0.14, "hem": 0.28, "flare": 0.06}, {"kind": "lapels", "colour": shade(colour, 0.8), "vee": 0.14}, coat_collar(colour)],
                      [{"kind": "buttons", "colour": shade(colour, 0.5), "step": 0.1, "lift": 0.036, "size": 0.013, "below": 0.12}], ["warm"]),
        "swing_coat": ([{"kind": "coat", "colour": colour, "vee": 0.14, "hem": 0.42, "flare": 0.14, "pattern": checks(shade(colour, 1.7), 1)}, {"kind": "lapels", "colour": shade(colour, 0.8), "vee": 0.14},
                        coat_collar(colour)],
                       [{"kind": "buttons", "colour": shade(colour, 0.5), "step": 0.1, "lift": 0.036, "size": 0.012, "below": 0.1}], ["warm"]),
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
    packs = {"tbar": "cortu_t-bar", "mary_jane": "toigo_mj_cloth_shoes", "flats": "toigo_ballet_flats", "lady_boots": "toigo_ankle_boots_female",
             "gent_boots": "toigo_ankle_boots_male", "brogues": "shoes01", "dress_shoes": "shoes04", "work_boots": "culturalibre_male_boots"}
    if kind == "work_boots":
        # Half of this pack boot is drawn on a single point of its picture: it wears made leather, unwrapped here.
        return [pack(packs[kind], colour, name="Shoes", made={"cloth": "leather", "pattern": None, "wrap": True})]
    if kind in packs:
        return [pack(packs[kind], colour, name="Shoes")]
    table = {"strap": [{"kind": "shoes", "colour": colour, "strap": True}], "oxford": [{"kind": "shoes", "colour": colour}], "pumps": [{"kind": "shoes", "colour": colour}],
             "ankle_boots": [{"kind": "boots", "colour": colour, "height": 0.08}], "tall_boots": [{"kind": "boots", "colour": colour, "height": 0.27}],
             "boots": [{"kind": "boots", "colour": colour, "height": 0.17}]}
    return table[kind]


# id: three sets, each (top, bottom, over, head, feet); "-" leaves that slot empty.
STYLES = {
    "adela_voss": [("wrap_blouse", "full_skirt", "cardigan", "-", "tbar"), ("skirt_suit", "-", "-", "-", "pumps"), ("flapper_dress", "-", "stole", "-", "mary_jane")],
    "mina_vale": [("knit", "pleated_midi", "knit_vest", "-", "mary_jane"), ("blouse_pencil", "-", "blazer", "beret", "tbar"), ("shift_dress", "-", "cape", "toque", "lady_boots")],
    "cal_dwyer": [("henley", "check_trousers", "waistcoat", "newsboy", "brogues"), ("tie_suit", "-", "-", "pack_fedora", "dress_shoes"), ("robe", "-", "-", "-", "oxford")],
    "cam_ortiz": [("jersey", "knickerbockers", "knit_vest", "newsboy", "ankle_boots"), ("trouser_suit", "-", "-", "-", "brogues"), ("work_shirt", "sailor_trousers", "duster", "-", "work_boots")],
    "evelyn_marsh": [("blouse_long", "long_skirt", "cardigan", "-", "lady_boots"), ("bow_blouse", "straight_skirt", "trench", "-", "pumps"), ("day_dress", "-", "shawl", "wide_hat", "flats")],
    "iris_bell": [("shirt_rolled", "overalls", "apron", "headscarf", "work_boots"), ("tunic", "pleated_midi", "cardigan", "-", "mary_jane"), ("keyhole_dress", "-", "cape", "wide_hat", "tbar")],
    "jonah_price": [("robe", "-", "-", "-", "oxford"), ("db_suit", "-", "-", "-", "dress_shoes"), ("fisherman", "wide_trousers", "long_jacket", "fedora", "gent_boots")],
    "juno_kells": [("henley", "sailor_trousers", "waistcoat", "-", "lady_boots"), ("trouser_suit", "-", "-", "-", "brogues"), ("keyhole_dress", "-", "bolero", "beret", "tbar")],
    "lena_ortiz": [("smock", "full_skirt", "apron", "headscarf", "boots"), ("blouse_long", "aline_skirt", "shawl", "-", "lady_boots"), ("skirt_suit", "-", "-", "toque", "pumps")],
    "mae_kessler": [("blouse_long", "long_skirt", "shawl", "-", "boots"), ("day_dress", "-", "long_coat", "-", "lady_boots"), ("evening_top", "pack_full_skirt", "cape", "wide_hat", "flats")],
    "malcolm_reed": [("shirt_rolled", "overalls", "apron", "newsboy", "work_boots"), ("lounge_suit", "-", "-", "derby", "dress_shoes"), ("fisherman", "wide_trousers", "waistcoat", "fedora", "gent_boots")],
    "nadia_quell": [("blouse_short", "straight_skirt", "knit_vest", "-", "tbar"), ("skirt_suit", "-", "-", "boater", "pumps"), ("flapper_dress", "-", "swing_coat", "wide_hat", "mary_jane")],
    "noel_price": [("shirt_rolled", "wide_trousers", "apron", "-", "brogues"), ("bowtie_suit", "-", "-", "pack_fedora", "dress_shoes"), ("jersey", "plus_fours", "waistcoat", "newsboy", "boots")],
    "omar_bell": [("shirt_rolled", "overalls", "apron", "cap", "work_boots"), ("elegant_suit", "-", "-", "-", "dress_shoes"), ("henley", "wide_trousers", "knit_vest", "derby", "gent_boots")],
    "peter_wren": [("shirt_long", "narrow_trousers", "waistcoat", "-", "brogues"), ("lounge_suit", "-", "-", "derby", "dress_shoes"), ("dinner_suit", "-", "-", "-", "dress_shoes")],
    "rhea_sato": [("blouse_short", "aline_skirt", "stole", "-", "flats"), ("blouse_pencil", "-", "boxy_jacket", "-", "tall_boots"), ("keyhole_dress", "-", "cape", "toque", "pumps")],
    "sacha_reed": [("jersey", "wide_trousers", "waistcoat", "newsboy", "work_boots"), ("tie_suit", "-", "-", "boater", "brogues"), ("shirt_rolled", "knickerbockers", "boxy_jacket", "-", "ankle_boots")],
    "teresa_vale": [("blouse_short", "short_skirt", "apron", "-", "flats"), ("wrap_blouse", "pleated_midi", "cape", "boater", "lady_boots"), ("shift_dress", "-", "swing_coat", "cloche", "tbar")],
    "transient_guests_a": [("henley", "wide_trousers", "waistcoat", "-", "work_boots"), ("db_suit", "-", "-", "pack_fedora", "dress_shoes"), ("jersey", "narrow_trousers", "long_coat", "cap", "boots")],
    "transient_guests_b": [("blouse_short", "short_skirt", "cardigan", "headscarf", "mary_jane"), ("blouse_pencil", "-", "swing_coat", "wide_hat", "pumps"), ("flapper_dress", "-", "stole", "-", "tall_boots")],
}
SET_TAGS = [["casual", "home"], ["formal", "street"], ["occasion"]]
# A second colour for each person, chosen to stand against their own.
SECOND = {
    # Cal's second was maroon, the own colour of Cam and Lena beside him: chocolate instead.
    "adela_voss": [0.03, 0.08, 0.3], "mina_vale": [0.72, 0.42, 0.04], "cal_dwyer": [0.24, 0.12, 0.05], "cam_ortiz": [0.75, 0.5, 0.04], "evelyn_marsh": [0.02, 0.3, 0.3],
    "iris_bell": [0.85, 0.42, 0.03], "jonah_price": [0.5, 0.15, 0.05], "juno_kells": [0.7, 0.12, 0.25], "lena_ortiz": [0.7, 0.45, 0.05], "mae_kessler": [0.4, 0.34, 0.55],
    "malcolm_reed": [0.55, 0.2, 0.05], "nadia_quell": [0.8, 0.7, 0.5], "noel_price": [0.65, 0.3, 0.05], "omar_bell": [0.45, 0.06, 0.06], "peter_wren": [0.1, 0.25, 0.22],
    "rhea_sato": [0.75, 0.06, 0.2], "sacha_reed": [0.75, 0.5, 0.08], "teresa_vale": [0.72, 0.03, 0.03], "transient_guests_a": [0.6, 0.48, 0.12], "transient_guests_b": [0.5, 0.2, 0.25],
}
NEUTRALS = [[0.16, 0.13, 0.11], [0.35, 0.3, 0.24], [0.08, 0.08, 0.09]]
# Ruling cast_colour_clashes_20261112: where two people blurred together, the second is re-coloured, and never in
# the everyday set, which keeps the person's own colour. "second": that set leads with the person's second colour
# (Nadia's street suit against Cam's; Mae's and Malcolm's street green against Adela's). "own": the occasion set
# leads with the person's own colour and takes the second for its outer layer (Iris against Mina, Juno against Rhea).
RELEAD = {("nadia_quell", 1): "second", ("mae_kessler", 1): "second", ("malcolm_reed", 1): "second", ("iris_bell", 2): "own", ("juno_kells", 2): "own"}


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


# Hair and skin from the packs. Adela keeps her strand ringlets and both she and Mina keep the skin Lily approved.
PACK_HAIR = {
    # Period cuts only: bobs, buns and plain short hair. Nothing swept over an eye.
    "mina_vale": "toigo_blunt_bob_with_bangs", "evelyn_marsh": "rehmanpolanski_hair_bun_brown", "iris_bell": "toigo_blunt_bob", "juno_kells": "littleright_bobcut_hair",
    "lena_ortiz": "toigo_curled_under_bob", "mae_kessler": "rehmanpolanski_hair_bun_brown", "nadia_quell": "toigo_inverted_bob", "rhea_sato": "toigo_curled_under_bob_with_bangs",
    "teresa_vale": "toigo_inverted_bob_with_bangs", "transient_guests_b": "toigo_blunt_bob", "cal_dwyer": "short02", "cam_ortiz": "short02", "jonah_price": "short02",
    "malcolm_reed": "short01", "noel_price": "short02", "omar_bell": "short01", "peter_wren": "short02", "sacha_reed": "short01", "transient_guests_a": "short02",
}
PACK_SKIN = {
    "iris_bell": "onlytheghosts_young_eurasian_female", "nadia_quell": "onlytheghosts_young_eurasian_female", "lena_ortiz": "onlytheghosts_old_eurasian_female",
    "juno_kells": "toigo_light_skin_female_bronze", "transient_guests_b": "toigo_light_skin_with_natural_makeup", "noel_price": "toigo_light_skin_male_ginger",
    "jonah_price": "toigo_light_skin_male_bronze", "omar_bell": "onlytheghosts_old_eurasian_male",
}


GOLD = [0.8, 0.62, 0.22]
SILVER = [0.78, 0.79, 0.82]


def gent(**more):
    """A man's evening hair: brushed flat with brilliantine from a parting, short over the ear and at the nape."""
    return dict({"side": 0.02, "length": 0.055, "ridge": 0.0018, "lift": 0.007, "swoop": 0.0, "sideburn": 0.035, "fade": 0.4, "wave_tone": 0.3,
                 "wisp_side": 0.01, "wisp_nape": 0.018, "wisp_front": 0.004, "wisp_repeats": 9.0, "highlight": 0.6, "shine": 0.6, "gloss_rough": 0.3}, **more)


# Lily, 2026-11-13: formal hair with the sculpted look of the two stage heads for everyone who needs it; everyday
# hair stays card hair. One dressed head each, worn as headwear that is the hair (see the builder's wave_hair):
# the women waved and set, in a bob, a knot or pinned up by age; the men brushed flat from a parting. Malcolm and
# Sacha wear a close crop that needs no dressing and have none. Adela's is her approved stage hair.
FORMAL_HAIR = {
    "adela_voss": {"length": 0.05, "side": 0.03, "waves": 3.0, "ridge": 0.006, "curly": 0.0035, "lift": 0.013, "front": 0.04, "updo": 11, "ornament": "clip", "part": 1.0, "band": GOLD},
    "mina_vale": {"length": 0.075, "side": 0.07, "waves": 3.5, "ridge": 0.0065, "lift": 0.012, "curl": 0.014, "front": 0.035, "swoop": 0.03, "part": 1.0, "ornament": "clip", "band": GOLD},
    "evelyn_marsh": {"length": 0.05, "side": 0.035, "waves": 2.5, "ridge": 0.005, "lift": 0.012, "front": 0.045, "swoop": 0.012, "part": -1.0, "knot": True, "ornament": "clip", "band": SILVER},
    "iris_bell": {"length": 0.08, "side": 0.08, "waves": 3.0, "ridge": 0.007, "lift": 0.014, "curl": 0.018, "front": 0.03, "swoop": 0.03, "part": -1.0, "ornament": "bandeau", "band": GOLD, "band_half": 0.0045, "band_height": 0.024},
    "juno_kells": {"length": 0.045, "side": 0.03, "waves": 2.0, "ridge": 0.004, "lift": 0.009, "front": 0.04, "swoop": 0.035, "swoop_width": 0.55, "part": 1.0, "wisp_nape": 0.025},
    "lena_ortiz": {"length": 0.05, "side": 0.04, "waves": 1.5, "ridge": 0.004, "lift": 0.011, "front": 0.045, "swoop": 0.008, "part": 0.3, "knot": True, "ornament": "clip", "band": WHITE},
    "mae_kessler": {"length": 0.045, "side": 0.03, "waves": 2.0, "ridge": 0.004, "curly": 0.002, "lift": 0.014, "front": 0.045, "swoop": 0.0, "part": 0.0, "updo": 9},
    "nadia_quell": {"length": 0.06, "side": 0.075, "waves": 4.0, "ridge": 0.0075, "lift": 0.011, "curl": 0.01, "front": 0.03, "swoop": 0.04, "part": -1.0, "ornament": "bandeau_star", "band": [0.8, 0.7, 0.5], "band_half": 0.0045, "band_height": 0.024},
    "rhea_sato": {"length": 0.075, "side": 0.075, "waves": 2.5, "ridge": 0.006, "lift": 0.012, "curl": 0.013, "front": 0.015, "swoop": 0.0, "part": 0.6, "ornament": "clip", "band": [0.85, 0.1, 0.25]},
    "teresa_vale": {"length": 0.05, "side": 0.045, "waves": 3.0, "ridge": 0.0055, "lift": 0.012, "front": 0.035, "swoop": 0.02, "part": 1.0, "knot": True, "ornament": "clip", "band": [0.75, 0.75, 0.7]},
    "transient_guests_b": {"length": 0.07, "side": 0.07, "waves": 3.5, "ridge": 0.006, "lift": 0.012, "curl": 0.012, "front": 0.035, "swoop": 0.025, "part": 1.0, "ornament": "bandeau", "band": [0.7, 0.55, 0.2], "band_half": 0.0045, "band_height": 0.024},
    "cal_dwyer": gent(waves=1.0, front=0.065, part=1.0, lift=0.0055),
    "cam_ortiz": gent(waves=1.0, front=0.045, part=-1.0, lift=0.009),
    "jonah_price": gent(waves=1.0, front=0.05, part=1.0, lift=0.01, ridge=0.003, length=0.07, side=0.026, fade=0.3),
    "noel_price": gent(waves=1.0, front=0.05, part=-1.0, lift=0.009, ridge=0.003),
    "omar_bell": gent(waves=1.0, front=0.06, part=0.0),
    "peter_wren": gent(waves=1.0, front=0.055, part=1.0),
    "transient_guests_a": gent(waves=1.0, front=0.045, part=-1.0, lift=0.011, ridge=0.003, length=0.08, side=0.03, fade=0.25),
}


def add_parts(cast):
    for cid, sets in STYLES.items():
        person = cast[cid]
        if cid == "adela_voss":
            # Lily, 11-11: the short, gathered, pinned style, modelled for her: waved close, pin curls low at the nape, a clip.
            person["hair"] = dict(person["hair"], set="pinned")
        if cid in PACK_HAIR:
            person["hair"] = dict(person["hair"], asset=PACK_HAIR[cid])
        if cid in PACK_SKIN:
            person["skin"] = PACK_SKIN[cid]
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
            top_colour = [c0, c0, s0][index]
            relead = RELEAD.get((cid, index))
            if relead == "second":
                top_colour, over_colour = s0, shade(s0, 0.55)
            elif relead == "own":
                top_colour, over_colour = c0, shade(s0, 0.7)
            rows, trim, covers = top(t, top_colour, a0, [pale, WHITE, [min(1.0, 0.6 + 0.4 * x) for x in s0]][index])
            parts[letter + "_top"] = {"slot": "top", "set": letter, "tags": SET_TAGS[index] + (["night"] if t.startswith("pyjama") else []), "covers": covers + ([] if t.endswith("dress") else ["trunk"]), "replaces": REPLACES.get(t, []),
                                    "rows": rows, "trim": trim}
            if b != "-":
              parts[letter + "_bottom"] = {"slot": "bottom", "set": letter,
                                         "tags": SET_TAGS[index] + (["night"] if b.startswith("pyjama") else []) + (["work"] if b == "overalls" else []),
                                         # Trousers fit the legs; a skirt hangs clear of them, so the body shows beneath it.
                                         "covers": ["hips"] if b in ("straight_skirt", "pencil_skirt") else [] if b.endswith(("skirt", "midi")) or b == "-" else ["legs", "hips"],
                                         "rows": bottom(b, colour, a0, [[0.5, 0.36, 0.26], [0.62, 0.55, 0.45], [0.12, 0.1, 0.1]][index]), "trim": []}
            rows, trim, extra_tags = over(o, over_colour, a0) if o != "-" else ([], [], [])
            if o != "-":
              parts[letter + "_over"] = {"slot": "over", "set": letter, "tags": SET_TAGS[index] + extra_tags,
                                       "covers": [] if o in ("apron", "waistcoat", "knit_vest", "shawl", "stole", "cape") else ["arms"], "rows": rows, "trim": trim}
            pack_hats = {"cloche": "aethelraed_unraed_cloche_hat", "newsboy": "jujube_newsboy_cap", "pack_fedora": "fedora01"}
            if h in pack_hats:
                parts[letter + "_head"] = {"slot": "head", "set": letter, "tags": SET_TAGS[index], "covers": [], "trim": [],
                                           "rows": [pack(pack_hats[h], shade(c0, 0.6) if index else shade(c0, 0.8), name="Hat", atype="Hat", felt=h != "newsboy")]}
            elif h != "-":
                parts[letter + "_head"] = {"slot": "head", "set": letter, "tags": SET_TAGS[index], "covers": [], "rows": [], "trim": [],
                                           "hat": head(h, shade(c0, 0.6) if index else shade(c0, 0.8), a0)}
            parts[letter + "_feet"] = {"slot": "feet", "set": letter, "tags": SET_TAGS[index], "covers": ["feet"], "rows": feet(f, [LEATHERS[hash_index(cid) % 4], BLACK, LEATHERS[(hash_index(cid) + 2) % 4]][index]), "trim": []}
            looks[letter] = [name for name in parts if name.startswith(letter + "_")]
        looks["mix1"] = [n for n in ("a_top", "b_bottom", "c_over", "b_head", "a_feet") if n in parts]
        looks["mix2"] = [n for n in ("c_top", "a_bottom", "b_over", "c_head", "b_feet") if n in parts]
        if cid in FORMAL_HAIR:
            # The dressed head, and the look it belongs to: the occasion clothes with the hat left off.
            parts["f_head"] = {"slot": "head", "set": "f", "tags": ["occasion", "evening"], "covers": [], "rows": [], "trim": [], "hair": "replace",
                               "hat": dict({"kind": "waves", "colour": person["hair"]["colour"]}, **FORMAL_HAIR[cid])}
            looks["f"] = [n for n in looks["c"] if not n.endswith("_head")] + ["f_head"]
        for row in DETAILS.get(cid, []):
            if row.get("cell") in ("patch", "pocket", "ticket", "darn", "stain", "stripe"):
                continue
            row = dict(row)
            target = row.pop("_to")
            if target in parts:
                parts[target]["trim"] = parts[target]["trim"] + [row]
        person["parts"] = parts
        person["looks"] = looks
        person.pop("outfits", None)
