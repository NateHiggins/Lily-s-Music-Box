"""Write cast_wardrobe.json: every cast member, three outfits each.

python art/blender/cast/make_cast_wardrobe.py

Colours and signature pieces follow design/ORISON_WARDROBE_BIBLE.md (one colour
per resident), pushed bold by Lily's direction of 2026-11-11: the world is
surreal and the cast must read at a distance. Necklines are simple: round or
V, no tall starched collars. Each person has three outfits:

  casual    at home and about the building
  formal    work and the street
  occasion  the Harukiya, the Not at Home parties, the Emergence
"""
import json, os

CREAM = [0.9, 0.84, 0.66]
WHITE = [0.92, 0.9, 0.84]
BLACK = [0.02, 0.02, 0.025]
GREY = [0.3, 0.3, 0.32]


def shade(colour, k):
    return [round(min(1.0, c * k), 4) for c in colour]


def woman(age, skin, hair_style, hair_colour, colour, accent, race=None, weight=0.42, **more):
    row = {"macro": {"gender": 0.0, "age": age, "muscle": 0.4, "weight": weight, "proportions": 0.65, "height": 0.5, "cupsize": 0.42, "firmness": 0.5},
           "skin": skin, "eyes": more.pop("eyes", "brown"), "hair": {"style": hair_style, "colour": hair_colour}, "colour": colour, "accent": accent}
    if race:
        row["race"] = race
    row.update(more)
    return row


def man(age, skin, hair_style, hair_colour, colour, accent, race=None, weight=0.5, gender=1.0, **more):
    row = {"macro": {"gender": gender, "age": age, "muscle": 0.48, "weight": weight, "proportions": 0.6, "height": 0.5},
           "skin": skin, "eyes": more.pop("eyes", "brown"), "hair": {"style": hair_style, "colour": hair_colour}, "colour": colour, "accent": accent}
    if race:
        row["race"] = race
    row.update(more)
    return row


def shoes(colour, strap=False):
    return {"kind": "shoes", "colour": colour, "strap": strap}


def stripes(colour, width=2):
    return {"kind": "stripes", "colour": colour, "width": width, "cells": 4, "repeat": 5}


def checks(colour, width=2):
    return {"kind": "checks", "colour": colour, "width": width, "cells": 4, "repeat": 5}


def dots(colour, width=3):
    return {"kind": "dots", "colour": colour, "width": width, "cells": 6, "repeat": 6}


# --- outfit recipes -------------------------------------------------------
def house_dress(c, a, pattern=None, apron=False, sleeves=0.5):
    rows = [{"kind": "stockings", "colour": [0.5, 0.36, 0.26]}, {"kind": "dress", "colour": c, "vee": 0.07, "sleeves": sleeves, "hem": 0.4, "flare": 0.22, "pattern": pattern},
            {"kind": "sash", "colour": a, "up": 0.04}, shoes(shade(c, 0.35), True)]
    if apron:
        rows.insert(3, {"kind": "apron", "colour": WHITE, "hem": 0.48})
    return {"outfit": rows, "trim": [], "bare_arm_from": sleeves, "bare_chest_vee": 0.07}


def blouse_skirt(c, a, blouse=None, pattern=None, cardigan=None):
    rows = [{"kind": "stockings", "colour": [0.5, 0.36, 0.26]}, {"kind": "shirt", "name": "Blouse", "colour": blouse or CREAM, "vee": 0.09, "sleeves": 0.55, "cloth": "silk", "pattern": pattern},
            {"kind": "skirt", "colour": c, "hem": 0.36, "flare": 0.3, "pleats": 18}, {"kind": "belt", "colour": a, "off": 0.012}, shoes(shade(c, 0.4), True)]
    out = {"outfit": rows, "trim": [{"kind": "buttons", "colour": a, "step": 0.07, "lift": 0.014, "size": 0.007}], "bare_arm_from": 0.55, "bare_chest_vee": 0.09}
    if cardigan:
        rows.insert(3, {"kind": "cardigan", "colour": cardigan, "vee": 0.3})
        out["bare_arm_from"] = 1.0
    return out


def lady_suit(c, a, hat=None, pattern=None, hem=0.42):
    rows = [{"kind": "stockings", "colour": [0.62, 0.55, 0.45]}, {"kind": "shirt", "name": "Blouse", "colour": WHITE, "vee": 0.07, "cloth": "silk"},
            {"kind": "skirt", "colour": c, "hem": hem, "flare": 0.12, "pleats": 10, "pattern": pattern},
            {"kind": "jacket", "colour": c, "vee": 0.24, "pattern": pattern}, {"kind": "lapels", "colour": shade(c, 0.6), "vee": 0.24}, shoes(BLACK, True)]
    out = {"outfit": rows, "trim": [{"kind": "buttons", "colour": a, "step": 0.085, "lift": 0.03, "size": 0.011}, {"kind": "pockets", "colour": shade(c, 0.6), "up": 0.03, "lift": 0.03}],
           "bare_chest_vee": 0.07}
    if hat:
        out["hat"] = hat
    return out


def evening_dress(c, a, hem=0.2, pattern=None, sleeves=0.0, scarf=None):
    rows = [{"kind": "stockings", "colour": [0.7, 0.6, 0.5]}, {"kind": "dress", "colour": c, "vee": 0.12, "sleeves": sleeves, "hem": hem, "flare": 0.3, "pleats": 14, "cloth": "silk", "pattern": pattern},
            {"kind": "sash", "colour": a, "up": 0.02, "off": 0.016}, shoes(a, True)]
    if scarf:
        rows.append({"kind": "scarf", "colour": scarf})
    return {"outfit": rows, "trim": [], "bare_arm_from": sleeves, "bare_chest_vee": 0.12}


def coat_dress(c, a, hat=None, hem=0.4, pattern=None):
    rows = [{"kind": "stockings", "colour": [0.3, 0.22, 0.18]}, {"kind": "coat", "colour": c, "vee": 0.1, "hem": hem, "flare": 0.14, "pattern": pattern},
            {"kind": "sash", "colour": a, "up": 0.03, "off": 0.027}, shoes(BLACK, True)]
    out = {"outfit": rows, "trim": [{"kind": "buttons", "colour": a, "step": 0.09, "lift": 0.034, "size": 0.012}], "bare_chest_vee": 0.0}
    if hat:
        out["hat"] = hat
    return out


def shirt_sleeves(c, a, trousers=None, shirt=None, braces=True, pattern=None, hat=None, apron=False):
    rows = [{"kind": "trousers", "colour": trousers or shade(c, 0.45), "pattern": pattern}, {"kind": "shirt", "colour": shirt or CREAM, "vee": 0.08, "sleeves": 0.55}, shoes([0.2, 0.09, 0.04])]
    if apron:
        rows.insert(2, {"kind": "apron", "colour": c, "hem": 0.5})
    out = {"outfit": rows, "trim": [{"kind": "braces", "colour": a}] if braces and not apron else [], "bare_arm_from": 0.55, "bare_chest_vee": 0.08}
    if hat:
        out["hat"] = hat
    return out


def jumper(c, a, trousers=None, pattern=None, hat=None, short=False):
    legs = {"kind": "trousers", "colour": trousers or shade(c, 0.35), "pattern": pattern}
    rows = [legs, {"kind": "shirt", "colour": CREAM, "vee": 0.0}, {"kind": "jumper", "colour": c, "vee": 0.1}, {"kind": "hem", "colour": shade(c, 0.55), "drop": 0.01},
            {"kind": "cuffs", "colour": shade(c, 0.55), "at": 0.9}, shoes([0.25, 0.12, 0.05])]
    if short:
        legs.update({"ends": 0.36, "turnups": False})
        rows.insert(0, {"kind": "stockings", "colour": a})
    out = {"outfit": rows, "trim": [], "bare_chest_vee": 0.0}
    if hat:
        out["hat"] = hat
    return out


def suit(c, a, pattern=None, hat=None, waistcoat=None, tie=True):
    rows = [{"kind": "trousers", "colour": c, "pattern": pattern}, {"kind": "shirt", "colour": WHITE, "vee": 0.05}, {"kind": "waistcoat", "colour": waistcoat or c, "vee": 0.2},
            {"kind": "jacket", "colour": c, "vee": 0.3, "pattern": pattern}, {"kind": "lapels", "colour": shade(c, 0.6), "vee": 0.3}, shoes(BLACK)]
    out = {"outfit": rows, "trim": ([{"kind": "tie", "colour": a, "length": 0.2}] if tie else []) + [{"kind": "pockets", "colour": shade(c, 0.6), "up": 0.03, "lift": 0.03}], "bare_chest_vee": 0.05}
    if hat:
        out["hat"] = hat
    return out


def evening_suit(c, a, hat=None):
    out = suit(shade(c, 0.35), a, waistcoat=a, tie=False)
    out["trim"].insert(0, {"kind": "bow", "colour": a})
    if hat:
        out["hat"] = hat
    return out


def work_coat(c, a, hat=None, trousers=None, hem=0.5):
    rows = [{"kind": "trousers", "colour": trousers or shade(c, 0.4)}, {"kind": "shirt", "colour": CREAM, "vee": 0.06}, {"kind": "coat", "colour": c, "vee": 0.18, "hem": hem, "flare": 0.08}, shoes([0.12, 0.07, 0.04])]
    out = {"outfit": rows, "trim": [{"kind": "buttons", "colour": a, "step": 0.1, "lift": 0.036, "size": 0.012, "below": 0.1}], "bare_chest_vee": 0.06}
    if hat:
        out["hat"] = hat
    return out


def overalls(c, a, shirt=None, hat=None):
    rows = [{"kind": "trousers", "colour": c}, {"kind": "shirt", "colour": shirt or CREAM, "vee": 0.07, "sleeves": 0.55}, {"kind": "bib", "colour": c}, shoes([0.2, 0.1, 0.05])]
    out = {"outfit": rows, "trim": [{"kind": "braces", "colour": c, "lift": 0.02}, {"kind": "buttons", "colour": a, "step": 0.3, "lift": 0.03, "size": 0.012}], "bare_arm_from": 0.55, "bare_chest_vee": 0.07}
    if hat:
        out["hat"] = hat
    return out


def cloche(colour, band=None, brim=1.0):
    return {"colour": colour, "band": band or shade(colour, 0.4), "brim": brim}


def cap(colour):
    return {"kind": "cap", "colour": colour, "band": colour, "brim": 1.0}


def toque(colour, band=None):
    return {"colour": colour, "band": band or shade(colour, 0.5), "brim": 0.0}


AF = {"asian": 0.0, "caucasian": 0.0, "african": 1.0}
AS = {"asian": 1.0, "caucasian": 0.0, "african": 0.0}
MIX = {"asian": 0.35, "caucasian": 0.65, "african": 0.0}
black = [0.045, 0.04, 0.04]
dark = [0.12, 0.075, 0.05]
brown = [0.28, 0.17, 0.09]
grey_hair = [0.6, 0.59, 0.58]
white_hair = [0.85, 0.84, 0.8]
ginger = [0.62, 0.27, 0.08]

SLATE = [0.1, 0.2, 0.46]
MUSTARD = [0.72, 0.42, 0.01]
MAROON = [0.42, 0.02, 0.07]
PLUM = [0.34, 0.03, 0.3]
ULTRA = [0.03, 0.06, 0.65]
NAVY = [0.02, 0.05, 0.28]
TEAL = [0.0, 0.33, 0.36]
BURGUNDY = [0.38, 0.01, 0.1]
BOTTLE = [0.0, 0.22, 0.1]
MOSS = [0.22, 0.34, 0.03]
OXBLOOD = [0.33, 0.01, 0.015]
INDIGO = [0.1, 0.04, 0.45]
OCHRE = [0.62, 0.34, 0.04]
BROWN = [0.27, 0.11, 0.03]
INK = [0.08, 0.02, 0.32]
SLATE_GREEN = [0.12, 0.32, 0.26]
SCARLET = [0.72, 0.03, 0.03]
GOLD = [0.85, 0.6, 0.05]

CAST = {}


def nightwear(c, a, is_man):
    pale = [min(1.0, 0.55 + 0.45 * x) for x in c]
    if is_man:
        rows = [{"kind": "trousers", "colour": pale, "pattern": stripes(c, 1), "cloth": "cotton", "turnups": False}, {"kind": "shirt", "colour": pale, "vee": 0.1, "pattern": stripes(c, 1)},
                {"kind": "coat", "colour": c, "vee": 0.3, "hem": 0.36, "flare": 0.1, "cloth": "silk"}, {"kind": "sash", "colour": a, "up": 0.08, "off": 0.027}, shoes(shade(c, 0.4))]
        return {"outfit": rows, "trim": [], "bare_chest_vee": 0.1}
    rows = [{"kind": "dress", "colour": pale, "vee": 0.1, "sleeves": 0.9, "hem": 0.2, "flare": 0.25, "cloth": "cotton"},
            {"kind": "coat", "colour": c, "vee": 0.3, "hem": 0.3, "flare": 0.16, "cloth": "silk"}, {"kind": "sash", "colour": a, "up": 0.08, "off": 0.027}, shoes(shade(c, 0.4))]
    return {"outfit": rows, "trim": [], "bare_chest_vee": 0.1}


def winter(c, a, is_man, hat):
    deep = shade(c, 0.55)
    legs = {"kind": "trousers", "colour": shade(c, 0.3)} if is_man else {"kind": "stockings", "colour": [0.12, 0.1, 0.1]}
    rows = [legs, {"kind": "coat", "colour": deep, "vee": 0.06, "hem": 0.3 if is_man else 0.26, "flare": 0.1, "cloth": "wool", "pattern": checks(shade(deep, 1.5), 1) if is_man else None},
            {"kind": "scarf", "colour": a, "cloth": "knit"}, {"kind": "cuffs", "colour": shade(deep, 0.6), "at": 0.9, "off": 0.03}, shoes(BLACK)]
    return {"outfit": rows, "trim": [{"kind": "buttons", "colour": shade(deep, 0.5), "step": 0.1, "lift": 0.036, "size": 0.013, "below": 0.12}], "bare_chest_vee": 0.0, "hat": hat}


def work(c, a, is_man):
    if is_man:
        rows = [{"kind": "trousers", "colour": shade(c, 0.4)}, {"kind": "shirt", "colour": CREAM, "vee": 0.07, "sleeves": 0.55}, {"kind": "waistcoat", "colour": c, "vee": 0.22}, shoes([0.15, 0.08, 0.04])]
        return {"outfit": rows, "trim": [{"kind": "buttons", "colour": a, "step": 0.06, "lift": 0.02, "size": 0.007}], "bare_arm_from": 0.55, "bare_chest_vee": 0.07}
    rows = [{"kind": "stockings", "colour": [0.4, 0.3, 0.22]}, {"kind": "shirt", "name": "Blouse", "colour": CREAM, "vee": 0.06, "sleeves": 0.9}, {"kind": "skirt", "colour": c, "hem": 0.38, "flare": 0.2, "pleats": 8},
            {"kind": "apron", "colour": shade(WHITE, 0.95), "hem": 0.46}, shoes(shade(c, 0.35), True)]
    return {"outfit": rows, "trim": [], "bare_chest_vee": 0.06}


def mourning(c, a, is_man, hat):
    if is_man:
        out = suit(BLACK, shade(c, 0.5))
    else:
        out = coat_dress(BLACK, shade(c, 0.6), hem=0.3)
    out["hat"] = dict(hat, colour=BLACK, band=shade(c, 0.5))
    return out


def add(cid, person, casual, formal, occasion, extra=None):
    person = dict(person)
    c_ = person.pop("colour")
    a_ = person.pop("accent")
    is_man = person["macro"]["gender"] > 0.5
    hat = formal.get("hat") or (cap(shade(c_, 0.5)) if is_man else cloche(shade(c_, 0.6), a_))
    outfits = {"casual": casual, "formal": formal, "occasion": occasion, "night": nightwear(c_, a_, is_man), "winter": winter(c_, a_, is_man, hat),
               "work": work(c_, a_, is_man), "mourning": mourning(c_, a_, is_man, hat)}
    outfits.update(extra or {})
    person["outfits"] = outfits
    CAST[cid] = person


c, a = [0.0, 0.26, 0.14], [0.75, 0.1, 0.12]
add("adela_voss", woman(0.5, "young_caucasian_female", "ringlets", [0.72, 0.3, 0.07], c, a, eyes="grey", skin_tone=[0.97, 0.9, 0.86]),
    blouse_skirt(c, a, pattern=dots(a)), lady_suit([0.03, 0.08, 0.3], GOLD, hat=cloche([0.03, 0.08, 0.3], GOLD)), evening_dress([0.0, 0.3, 0.26], GOLD, hem=0.16))
c, a = SLATE, GOLD
add("mina_vale", woman(0.6, "young_caucasian_female", "bob", black, c, a, eyes="brownlight", spectacles=True, skin_tone=[0.92, 0.93, 0.97], hair_extra={"root_max_above_nose": 0.1}),
    blouse_skirt(c, a, cardigan=shade(c, 1.3)), lady_suit(c, a, hat=cloche([0.3, 0.3, 0.34], a), pattern=stripes([0.55, 0.66, 0.98])), evening_dress(shade(c, 0.8), a, sleeves=0.5))
c, a = MUSTARD, [0.6, 0.08, 0.1]
add("cal_dwyer", man(0.88, "old_caucasian_male", "short", white_hair, c, a, eyes="grey", weight=0.55),
    jumper(c, a, trousers=[0.16, 0.07, 0.03], pattern=checks([0.34, 0.18, 0.06]), hat=cap(shade(c, 0.6))), suit(shade(c, 0.7), a, pattern=checks(shade(c, 0.45)), hat=cap(shade(c, 0.5))),
    evening_suit(c, a))
c, a = MAROON, GOLD
add("cam_ortiz", man(0.55, "young_caucasian_male", "short", black, c, a, MIX, gender=0.55, weight=0.42),
    jumper(c, a, trousers=[0.2, 0.14, 0.08], hat=cap(c), short=True), suit(shade(c, 0.8), a, hat=cap(shade(c, 0.6))), evening_suit(c, a))
c, a = PLUM, GOLD
add("evelyn_marsh", woman(0.82, "old_caucasian_female", "bob", grey_hair, c, a, spectacles=True, eyes="grey", hair_extra={"length": [0.03, 0.05]}),
    blouse_skirt(c, a, cardigan=shade(c, 1.3)), coat_dress(c, a, hat=toque(c, a), hem=0.3), evening_dress(shade(c, 0.8), a, hem=0.22, sleeves=0.7, scarf=a))
c, a = ULTRA, [0.9, 0.5, 0.05]
add("iris_bell", woman(0.55, "young_caucasian_female", "bob", dark, c, a, MIX),
    overalls(c, a, shirt=[0.9, 0.5, 0.05], hat=toque(a, c)), blouse_skirt(c, a, pattern=dots(c)), evening_dress(c, a, hem=0.3, pattern=dots(a, 2)))
c, a = NAVY, CREAM
add("jonah_price", man(0.58, "young_caucasian_male", "short", dark, c, a, hair_extra={"length": [0.08, 0.11]}),
    work_coat(c, a, trousers=[0.5, 0.56, 0.7], hem=0.34), suit(c, [0.6, 0.1, 0.1], pattern=stripes(shade(c, 2.5), 1)), evening_suit(c, [0.6, 0.1, 0.1]))
c, a = TEAL, [0.85, 0.2, 0.3]
add("juno_kells", woman(0.47, "young_caucasian_female", "short", dark, c, a, weight=0.38, hair_extra={"length": [0.05, 0.07]}),
    jumper(c, a, trousers=[0.05, 0.05, 0.06]), work_coat(c, a, hem=0.3), evening_dress(c, a, hem=0.42, sleeves=0.0))
c, a = BURGUNDY, WHITE
add("lena_ortiz", woman(0.78, "old_caucasian_female", "bob", black, c, a, MIX, hair_extra={"root_max_above_nose": 0.09}),
    house_dress(c, a, apron=True, sleeves=0.9), coat_dress(c, GOLD, hat=toque(shade(c, 0.6), GOLD), hem=0.34), evening_dress(c, GOLD, hem=0.28, sleeves=0.6, scarf=GOLD))
c, a = BOTTLE, WHITE
add("mae_kessler", woman(0.9, "old_caucasian_female", "short", white_hair, c, a, eyes="grey", hair_extra={"length": [0.06, 0.09]}),
    blouse_skirt(c, a, blouse=WHITE, cardigan=shade(c, 1.4)), coat_dress(c, a, hat=toque(c, a), hem=0.26), evening_dress(shade(c, 0.9), [0.75, 0.75, 0.7], hem=0.16, sleeves=0.9))
c, a = MOSS, [0.55, 0.2, 0.05]
add("malcolm_reed", man(0.74, "middleage_african_male", "short", [0.25, 0.24, 0.24], c, a, AF, hair_extra={"length": [0.02, 0.035]}),
    shirt_sleeves(c, a, shirt=shade(c, 1.6), hat=cap(shade(c, 0.5))), suit(c, a, hat=cap(shade(c, 0.5))), evening_suit(c, GOLD))
c, a = OXBLOOD, BLACK
add("nadia_quell", woman(0.58, "young_caucasian_female", "bob", black, c, a, MIX, hair_extra={"root_max_above_nose": 0.1}),
    blouse_skirt(c, a, blouse=[0.85, 0.8, 0.7]), lady_suit(c, GOLD, hat=cloche(BLACK, c)), evening_dress(c, BLACK, hem=0.2))
c, a = INDIGO, WHITE
add("noel_price", man(0.57, "young_caucasian_male", "short", ginger, c, a),
    shirt_sleeves(c, a, shirt=[0.75, 0.78, 0.95]), work_coat(c, a, hat={"colour": shade(c, 0.5), "band": c, "brim": 0.8}), evening_suit(c, GOLD))
c, a = OCHRE, [0.2, 0.1, 0.04]
add("omar_bell", man(0.68, "middleage_caucasian_male", "short", black, c, a, MIX, spectacles=True),
    shirt_sleeves(c, a, apron=True, hat=cap(shade(c, 0.5))), suit(shade(c, 0.75), [0.45, 0.05, 0.05], hat=cap(shade(c, 0.45))), evening_suit(c, [0.45, 0.05, 0.05]))
c, a = BROWN, [0.75, 0.45, 0.05]
add("peter_wren", man(0.64, "middleage_caucasian_male", "short", brown, c, a, weight=0.44, hair_extra={"length": [0.025, 0.04]}),
    jumper(shade(c, 1.5), a, trousers=c), suit(c, a, pattern=stripes(shade(c, 1.9), 1), hat={"colour": shade(c, 0.4), "band": BLACK, "brim": 0.55}), evening_suit(c, a))
c, a = INK, [0.85, 0.1, 0.25]
add("rhea_sato", woman(0.7, "middleage_asian_female", "bob", black, c, a, AS, hair_extra={"root_max_above_nose": 0.1}),
    blouse_skirt(c, a, blouse=[0.82, 0.8, 0.9]), lady_suit(c, a, hat=cloche(BLACK, a)), evening_dress(c, a, hem=0.14))
c, a = SLATE_GREEN, [0.8, 0.55, 0.1]
add("sacha_reed", man(0.5, "young_african_male", "short", black, c, a, AF, gender=0.6, weight=0.42, hair_extra={"length": [0.03, 0.045]}),
    jumper(c, a, trousers=[0.1, 0.1, 0.1], hat=cap(shade(c, 0.6))), work_coat(c, a, hat=cap(shade(c, 0.5)), hem=0.36), evening_suit(c, a))
c, a = NAVY, SCARLET
add("teresa_vale", woman(0.66, "middleage_asian_female", "bob", black, c, a, AS, hair_extra={"length": [0.03, 0.05]}),
    blouse_skirt(c, a, blouse=WHITE), coat_dress(c, a, hem=0.36), evening_dress(c, a, hem=0.3, sleeves=0.5, scarf=a))
c, a = GREY, [0.7, 0.55, 0.2]
for guest, guest_person in (("transient_guests_a", man(0.58, "young_caucasian_male", "bob", brown, c, a, hair_extra={"length": [0.1, 0.14]})),
                            ("transient_guests_b", woman(0.55, "young_caucasian_female", "bob", [0.2, 0.13, 0.08], c, a))):
    add(guest, guest_person, shirt_sleeves(c, a, shirt=[0.7, 0.7, 0.66]) if guest.endswith("_a") else blouse_skirt(c, a, blouse=[0.7, 0.7, 0.66]),
        suit(c, a, pattern=checks(shade(c, 1.5))) if guest.endswith("_a") else lady_suit(c, a, pattern=checks(shade(c, 1.5))),
        evening_suit(c, a) if guest.endswith("_a") else evening_dress(c, a, hem=0.3))

for person in CAST.values():
    extra = person.pop("hair_extra", None)
    if extra:
        person["hair"].update(extra)
CAST["teresa_vale"]["outfits"]["work"] = {"outfit": [{"kind": "stockings", "colour": WHITE}, {"kind": "dress", "colour": WHITE, "vee": 0.04, "sleeves": 0.6, "hem": 0.36, "flare": 0.15},
    {"kind": "apron", "colour": WHITE, "hem": 0.42}, {"kind": "coat", "colour": NAVY, "vee": 0.4, "hem": 0.5, "flare": 0.2}, {"kind": "sash", "colour": SCARLET, "up": 0.1, "off": 0.03}, shoes(BLACK, True)],
    "trim": [], "bare_chest_vee": 0.04, "hat": toque(WHITE, NAVY)}
CAST["malcolm_reed"]["outfits"]["work"] = overalls(MOSS, [0.55, 0.2, 0.05], shirt=shade(MOSS, 1.6), hat=cap(shade(MOSS, 0.5)))
CAST["omar_bell"]["outfits"]["work"] = overalls(shade(OCHRE, 0.7), [0.2, 0.1, 0.04], hat=cap(shade(OCHRE, 0.5)))
CAST["iris_bell"]["outfits"]["work"] = overalls(ULTRA, [0.9, 0.5, 0.05], shirt=[0.85, 0.8, 0.7], hat=toque([0.9, 0.5, 0.05], ULTRA))
CAST["noel_price"]["outfits"]["work"] = work_coat(INDIGO, WHITE, hem=0.5)
CAST["cam_ortiz"]["outfits"]["work"] = jumper(MAROON, GOLD, trousers=[0.2, 0.14, 0.08], hat=cap(MAROON), short=True)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cast_wardrobe.json")
json.dump(CAST, open(out, "w", encoding="utf-8"), indent=1)
print(len(CAST), "people,", sum(len(p["outfits"]) for p in CAST.values()), "outfits ->", out)
