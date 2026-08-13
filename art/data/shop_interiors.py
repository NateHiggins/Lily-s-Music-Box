#!/usr/bin/env python3
"""Static interiors for the eleven shops in the Vantry Arcade.

This module owns the trade tables and the furniture emitter because the shop
second pass changes them together.  It never imports gen_layout: the Passage
packer supplies each shop's face and transform explicitly, so the map retains
one coordinate source of truth and this seam cannot become a circular import.
"""

SHOPS = [
    # (x0, x1, name, trade, awning, blade sign, function)
    (-32.4, -26.8, "MODEL LAUNDRY", "laundry", True, False,
     "hand laundry: the public Matching game, and a warm window at 3am"),
    (-26.8, -21.2, "SHOE REBUILDING", "cobbler", False, True,
     "repairs worn objects; the smell of it is half the block"),
    (-19.4, -15.8, "KEYS CUT", "locksmith", False, True,
     "cuts keys for the building's locked doors"),
    (-15.8, -12.6, "RADIO SERVICE", "radio", True, False,
     "aligns a set; knows about the carrier at 1610 and will not say"),
    (-11.4, -6.2, "LUNCHEONETTE", "diner", True, False,
     "a counter and eight stools; where residents sit between shifts"),
    # NOT on nbr_s2's east end: x 4.30..5.45 is the Harukiya's stair
    # shaft, and a shopfront there seals the only way into the bar. The
    # newsagent moves to the next block along, which is where a corner
    # news stand belongs anyway.
    (7.9, 10.2, "NEWS CIGARS", "news", False, True,
     "papers carrying case leads, and the racing page nobody admits to"),
    (10.4, 15.0, "PAWNBROKER", "pawn", False, True,
     "buys what the smash room leaves; sells what the building needs"),
    (15.2, 19.8, "FUNERAL PARLOUR", "funeral", True, False,
     "Dorothy Ash went from here. The chapel is behind the front room"),
    (21.0, 26.4, "HARDWARE PAINT", "hardware", False, True,
     "parts, and the only ladder on the block"),
    (26.4, 31.6, "PHOTO SUPPLIES", "photo", True, False,
     "film for the handset; Nadia is in here more than she is upstairs"),
]

SHOPS_N = [
    (-19.55, -15.25, "OTIS & SON", "druggist", True, False,
     "the druggist: sundries, a soda fountain nobody uses, and the "
     "prescription counter where a building with no penicillin does "
     "its worrying"),
]

SHOP_CLEAR, SHOP_H = 3.30, 3.55

SHOP_PLAN = {
    #            depth  cabs
    "laundry":  (7.00,  1),
    "cobbler":  (6.00,  0),
    "locksmith": (5.00, 0),
    "radio":    (5.00,  1),
    "diner":    (7.00,  2),
    "news":     (4.00,  1),
    "pawn":     (6.00,  1),
    "funeral":  (7.00,  0),
    "hardware": (6.50,  0),
    "photo":    (6.00,  1),
    # The one on the near side. Deep, because a druggist of this date is
    # a long room with the dispensary at the far end and the fountain
    # halfway down it.
    "druggist": (7.00,  0),
}

SHOP_FLOOR = {
    "laundry": "quarry_tile", "cobbler": "floor_oak",
    "locksmith": "concrete", "radio": "linoleum", "diner": "terrazzo",
    "news": "linoleum", "pawn": "floor_oak", "funeral": "floor_oak",
    "hardware": "concrete", "photo": "linoleum",
    "druggist": "terrazzo",
}

SHOP_CEIL = {"diner": "tin_ceiling", "pawn": "tin_ceiling",
             "photo": "tin_ceiling", "funeral": "tin_ceiling",
             "druggist": "tin_ceiling"}


def build_shop_interiors(fb, mk, asm, shops, face, S=1):
    """The eleven sales floors behind the Vantry Arcade shopfronts.

    Until now this street was a stage flat: ten beautifully sectioned
    1920s fronts with solid brick 100 mm behind the glass, a lit linen
    panel faking a room, and a doorway filled in. You could read every
    sign on the block and enter nothing.

    Each shop is now a room you walk into. The shell is generic — floor,
    ceiling, a plastered back wall, a dado — because a terrace of shops
    IS generic behind the front; what differs is the fittings, and those
    are the whole point. A trade is legible from its furniture at a
    glance or it is a beige box with a name over the door.

    Depths come from SHOP_PLAN and they are the trade's rather than a
    number: a news kiosk is a slot you stand in the mouth of, a funeral
    parlour needs a front room you can hold a service in.

    ARCADE CABINETS, and where they are is an argument rather than a
    scatter. Under the Rule of Signal (bible VIII.2) a machine that
    reproduces a signal is forty years ahead of 1927, so these are not
    anachronisms — they are the most native technology on the street.
    They go where a machine actually earns its floor space: somewhere
    with people who are WAITING (the laundry, the luncheonette), a trade
    that already sells time by the minute (the news kiosk), a shop that
    ends up owning whatever people stop collecting (the pawnbroker), and
    two shops that are signal trades themselves and would have one on
    the bench as a matter of professional interest (the radio service,
    the photo supply). The funeral parlour, the cobbler, the locksmith
    and the hardware store have none, and the absence is doing as much
    work as the presence.
    """
    F = face
    CLR = SHOP_CLEAR

    def fbn(bid, rect, z0, h, mat, batch=None, **meta):
        x0, y0, x1, y1 = rect
        if y0 > y1:
            y0, y1 = y1, y0
        fb(bid, (x0, y0, x1, y1), z0, h, mat, batch=batch, **meta)

    for x0, x1, name, trade, _awn, _bl, _use in shops:
        # Node names carry this straight through to Godot, and a
        # NodePath with punctuation in it is a lookup that fails
        # somewhere unhelpful later. Display name keeps its "&";
        # the id is alphanumerics only.
        tag = "".join(c if c.isalnum() else "_"
                      for c in name.lower()).strip("_")
        depth, _ncab = SHOP_PLAN[trade]
        ix0, ix1 = x0 + 0.10, x1 - 0.10        # brick party faces
        by = F - S * depth                          # back wall inner face
        mid = (ix0 + ix1) * 0.5

        def b(sub, rect, z0, h, mat, role="", _t=tag):
            # Ownership is data, not a naming convention.  Blender used to
            # infer retail batches from prefixes, but these arrive through
            # StormPass as `storm_shop_*` and silently fell into a floor-wide
            # furniture mesh whose 220 x 148 m AABB stole the shop lights.
            meta = {"shop_role": role} if role else {}
            if role == "hero":
                meta["hero"] = trade
            fbn("shop_%s_%s" % (_t, sub), rect, z0, h, mat,
                batch="shop_%s" % _t, **meta)

        def cab(n, cx, cy, yaw, variant, _t=tag):
            # Variant is the SILHOUETTE (upright / finned / chrome /
            # compact), not the game — which title lands in which
            # carcass is ArcadeRow's business, off the catalog, in
            # layout order.
            asm("shopcab_%s%d" % (_t, n), "arcade_cab", cx, cy, yaw,
                variant=variant, batch="shop_%s" % _t)

        # ---- the shell ------------------------------------------------
        # FLUSH WITH THE PAVEMENT, and this is not a detail. sidewalk_s
        # tops out at 0.01, and the floor was first authored 0.00..0.05 —
        # a 40 mm step up across every shop threshold, plus every fitting
        # standing on 0.05 while the arcade cabinets (which carry no z0)
        # sat at 0.00 and were buried to the ankles in their own floor.
        # The bar spent three separate fixes on a doorway before anyone
        # measured the 180 mm kerb in front of it; this one is measured
        # first. Slab hangs below the finish line, everything stands on
        # 0.01, and you walk in without noticing there was ever a change
        # of level — which is the entire objective.
        b("floor", (ix0, by, ix1, F), -0.05, 0.06, SHOP_FLOOR[trade])
        b("ceil", (ix0, by, ix1, F), CLR, SHOP_H - CLR,
          SHOP_CEIL.get(trade, "plaster"))
        # Back wall lined, side walls left as the party brick they are.
        b("back", (ix0, by, ix1, by + 0.06), 0.01, CLR - 0.05,
          "plaster_stained")
        # A dado all round, which is what stops a shop reading as a
        # cardboard box: trolleys, boot heels and crates all hit the
        # bottom metre of a wall and every shop of this date protected it.
        for sub, rect in (("dw", (ix0, by, ix0 + 0.05, F)),
                          ("de", (ix1 - 0.05, by, ix1, F)),
                          ("db", (ix0, by + 0.06, ix1, by + 0.11))):
            b(sub, rect, 0.05, 1.05, "wainscot")

        # THE BACK EXISTS WITHOUT BEING MODELLED.  A narrow closed service
        # door on the east party wall says stockroom/yard/stair and stops the
        # eye before the sales floor pretends to be the whole building.  It is
        # a shallow panel over an existing collision wall, not a new route.
        b("boh_door", (ix1 - 0.075, by + 0.24, ix1 - 0.015, by + 1.08),
          0.05, 2.08, "wood_dark")
        b("boh_knob", (ix1 - 0.105, by + 0.88, ix1 - 0.065, by + 0.94),
          0.96, 0.07, "brass_dull")

        # A window display is aimed at the pavement, not at the shopkeeper.
        # It occupies the bay opposite the recessed door and keeps a backboard
        # behind the goods so the dark room is not the display's background.
        if trade not in ("news", "diner"):
            door_left = trade in ("diner", "photo")
            wx0 = (ix0 + 1.62) if door_left else (ix0 + 0.18)
            wx1 = (ix1 - 0.18) if door_left else (ix1 - 1.62)
            if wx1 - wx0 > 0.55:
                b("window_plinth", (wx0, F - S * 0.54, wx1,
                                     F - S * 0.18), 0.05, 0.39,
                  "wood_dark")
                b("window_back", (wx0, F - S * 0.58, wx1,
                                    F - S * 0.54), 0.42, 1.15,
                  "plywood")

        # ---- the trade ------------------------------------------------
        if trade == "laundry":
            # A HAND LAUNDRY.  The first pass accidentally furnished this as
            # a coin wash with five automatic machines and two dryers—objects
            # the 1927 room cannot own.  Work arrives over the counter, is
            # washed in tubs, mangled, ironed, wrapped and waits on this wall.
            # Hundreds of parcels are the hero because the street can read
            # their repetition through the glass before it reads any label.
            for r in range(5):
                b("parcel_shelf%d" % r,
                  (ix0 + 0.22, by + 0.12, ix1 - 0.22, by + 0.42),
                  0.30 + r * 0.49, 0.055, "timber", "hero")
                for c in range(8):
                    px0 = ix0 + 0.30 + c * (ix1 - ix0 - 0.76) / 8.0
                    pw = (ix1 - ix0 - 0.92) / 8.0
                    b("parcel%d_%d" % (r, c),
                      (px0, by + 0.18, px0 + pw, by + 0.39),
                      0.36 + r * 0.49, 0.29,
                      "paper" if (r + c) % 3 else "linen", "hero")
            b("ticket_rail", (ix0 + 0.25, by + 0.48, ix1 - 0.25,
                               by + 0.52), 2.52, 0.035, "metal", "hero")
            for i in range(13):
                tx = ix0 + 0.36 + i * (ix1 - ix0 - 0.72) / 12.0
                b("ticket%d" % i, (tx - 0.045, by + 0.50, tx + 0.045,
                                    by + 0.54), 2.30 - (i % 3) * 0.06,
                  0.20, "paper", "hero")

            # Two rinse tubs and their high splash backs.  The water stays at
            # the rear rather than turning the customer counter into plumbing.
            for i in range(2):
                ty = by + 0.92 + i * 0.92
                b("tub%d" % i, (ix0 + 0.10, ty, ix0 + 0.82, ty + 0.68),
                  0.01, 0.78, "zinc_liner")
                b("tub%d_rim" % i, (ix0 + 0.06, ty - 0.04, ix0 + 0.86,
                                     ty + 0.72), 0.79, 0.055, "metal")
            # Hand-cranked mangle: two visible rollers in a timber frame.
            b("mangle_frame", (ix0 + 0.10, by + 2.92, ix0 + 0.86,
                                by + 3.62), 0.01, 0.88, "timber")
            for i in range(2):
                b("mangle_roll%d" % i, (ix0 + 0.04, by + 3.04 + i * 0.22,
                                         ix0 + 0.92, by + 3.18 + i * 0.22),
                  0.90, 0.15, "rubber_aged")
            b("mangle_crank", (ix0 + 0.86, by + 3.38, ix0 + 1.10,
                                by + 3.46), 0.96, 0.08, "cast_iron")

            # Long padded ironing table, sleeve board, and a gas-heated plate
            # of sad irons.  These occupy the trade side, clear of the route.
            b("iron_table", (ix1 - 1.00, by + 1.00, ix1 - 0.12,
                              F - S * 2.45), 0.01, 0.86, "timber")
            b("iron_pad", (ix1 - 1.04, by + 0.96, ix1 - 0.08,
                            F - S * 2.41), 0.88, 0.07, "linen")
            b("sleeve_board", (ix1 - 1.36, by + 1.18, ix1 - 1.06,
                                by + 2.22), 0.91, 0.06, "linen")
            b("gas_ring", (mid - 0.43, by + 0.78, mid + 0.43,
                            by + 1.38), 0.01, 0.72, "cast_iron")
            for i in range(4):
                px = mid - 0.32 + i * 0.20
                b("sad_iron%d" % i, (px, by + 0.91, px + 0.15,
                                      by + 1.22), 0.75, 0.15, "cast_iron")
            # Ceiling pulley airers are flat lattices, not automatic dryers.
            for r in range(2):
                ry = by + 2.05 + r * 1.55
                for i in range(5):
                    b("airer%d_%d" % (r, i),
                      (mid - 0.90 + i * 0.43, ry, mid - 0.84 + i * 0.43,
                       ry + 1.10), 2.58, 0.045, "timber")
            b("counter", (ix0 + 0.05, F - S * 1.30, ix1 - 1.60, F - S * 0.68),
              0.05, 0.95, "wood_dark")
            b("counter_top", (ix0 + 0.02, F - S * 1.34, ix1 - 1.56, F - S * 0.64),
              1.00, 0.05, "countertop")
            # Shirts on a rail over the counter, the thing that says
            # laundry from across the street.
            b("rail", (ix0 + 0.40, F - S * 2.70, ix1 - 0.40, F - S * 2.64),
              2.05, 0.04, "chrome")
            for i in range(9):
                sx = ix0 + 0.55 + i * (ix1 - ix0 - 1.10) / 8.0
                b("shirt%d" % i, (sx - 0.16, F - S * 2.80, sx + 0.16,
                                  F - S * 2.56), 1.28, 0.76, "linen")
            # Along the east wall, beyond the turn inside the door. Across
            # the frontage it occupied the only body-width lane despite the
            # counter itself ending correctly short of it.
            b("bench", (ix1 - 0.42, F - S * 2.35, ix1 - 0.10, F - S * 1.25),
              0.05, 0.44, "timber")
            b("ledger", (mid - 0.18, F - S * 1.18, mid + 0.18,
                          F - S * 0.86), 1.06, 0.055, "paper")
            b("pencil", (mid + 0.20, F - S * 1.15, mid + 0.24,
                          F - S * 0.88), 1.07, 0.035, "timber")
            # WAITING IS THE WHOLE REASON. Forty minutes with nothing to
            # do is what an arcade cabinet was invented for, and it is
            # the only room on the street where the machine is furniture
            # rather than an attraction.
            #
            # by+3.60 and not by+2.60: the driers run back to by+2.62 and
            # a cabinet at 2.60 was standing inside the second one.
            cab(0, ix1 - 0.45, by + 3.60, 270, 0)

        elif trade == "cobbler":
            # The bench is the shop. Everything else is storage for
            # other people's shoes.
            b("bench", (ix0 + 0.05, by + 0.60, ix0 + 0.85, F - S * 2.40),
              0.05, 0.92, "timber")
            b("bench_top", (ix0 + 0.02, by + 0.55, ix0 + 0.92, F - S * 2.35),
              0.97, 0.06, "wood_dark")
            # The finishing machine: a brushing and buffing head on a
            # cast stand, and the reason the smell of this shop is half
            # the block.
            b("finisher", (ix0 + 0.95, by + 0.82, ix0 + 2.15, by + 1.46),
              0.05, 0.88, "cast_iron", "hero")
            b("finisher_hd", (ix0 + 0.88, by + 0.74, ix0 + 2.22,
                               by + 1.54), 0.93, 0.42, "metal", "hero")
            b("finisher_hood", (ix0 + 0.88, by + 1.12, ix0 + 2.22,
                                 by + 1.50), 1.35, 0.36, "soot", "hero")
            b("finisher_shaft", (ix0 + 0.82, by + 0.68, ix0 + 2.28,
                                  by + 0.82), 1.07, 0.12, "metal", "hero")
            for i in range(4):
                wx = ix0 + 0.92 + i * 0.30
                b("finisher_wheel%d" % i,
                  (wx, by + 0.57, wx + 0.18, by + 0.88),
                  1.00, 0.30, "rubber_aged" if i % 2 else "cast_iron",
                  "hero")
            for i in range(5):
                b("rack%d" % i, (ix1 - 0.42, by + 0.30, ix1 - 0.05,
                                 F - S * 2.30), 0.42 + i * 0.36, 0.04,
                  "timber")
            # Somebody's shoes, paired, waiting to be collected.
            for i in range(11):
                sy = by + 0.55 + (i % 6) * 0.62
                sz = 0.46 + (i % 5) * 0.36
                b("shoe%d" % i, (ix1 - 0.38, sy, ix1 - 0.12, sy + 0.26),
                  sz, 0.11, "wood_dark" if i % 3 else "vinyl_oxblood")
            b("counter", (ix0 + 0.30, F - S * 1.45, ix1 - 1.50, F - S * 0.85),
              0.05, 1.02, "wood_dark")
            b("counter_top", (ix0 + 0.26, F - S * 1.50, ix1 - 1.46, F - S * 0.80),
              1.07, 0.05, "countertop")
            # Two different sewing machines because uppers and soles are not
            # the same operation: a curved-needle outsole stand and the small
            # treadle patcher with its narrow arm.
            b("outsole_stand", (mid - 0.52, by + 0.42, mid + 0.06,
                                 by + 1.06), 0.05, 0.78, "cast_iron")
            b("outsole_head", (mid - 0.60, by + 0.48, mid + 0.18,
                                by + 0.96), 0.86, 0.52, "metal")
            b("patcher_treadle", (mid + 0.35, by + 0.44, mid + 0.92,
                                   by + 1.02), 0.05, 0.70, "cast_iron")
            b("patcher_arm", (mid + 0.28, by + 0.50, mid + 1.02,
                               by + 0.68), 0.82, 0.42, "metal")
            # Lasts read like a bone collection when ordered by size.
            b("last_rack", (ix1 - 1.10, by + 0.26, ix1 - 0.70,
                             by + 2.55), 0.18, 1.55, "timber")
            for i in range(9):
                yy = by + 0.38 + i * 0.23
                b("last%d" % i, (ix1 - 1.16, yy, ix1 - 0.66, yy + 0.13),
                  0.32 + (i % 3) * 0.42, 0.13, "cast_iron")
            b("sole_stack", (mid + 0.20, by + 1.30, mid + 0.78,
                              by + 1.74), 0.05, 0.38, "vinyl_oxblood")
            b("waiting_seat", (ix1 - 0.42, F - S * 2.25, ix1 - 0.10,
                                F - S * 1.32), 0.05, 0.48, "wood_dark")
            b("ledger", (mid - 0.18, F - S * 1.32, mid + 0.18,
                          F - S * 0.94), 1.13, 0.05, "paper")
            # Leather felt accumulates everywhere except under the account
            # book, whose clean rectangle says it is moved every day.
            b("dust_felt", (ix0 + 0.10, by + 0.12, ix1 - 0.10,
                             F - S * 1.72), 0.012, 0.006, "soot")
            b("ledger_clean", (mid - 0.24, F - S * 1.38, mid + 0.24,
                                F - S * 0.88), 1.121, 0.006, "timber")

        elif trade == "locksmith":
            # A key board is the whole window display of this trade and
            # the only thing that makes a 3.4 m shop legible.
            b("board", (ix0 + 0.35, by + 0.07, ix1 - 0.35, by + 0.12),
              1.25, 1.55, "plywood", "hero")
            for r in range(7):
                for c in range(14):
                    kx = ix0 + 0.45 + c * (ix1 - ix0 - 0.90) / 13.0
                    b("key%d_%d" % (r, c), (kx - 0.025, by + 0.12,
                                            kx + 0.025, by + 0.16),
                      1.36 + r * 0.20, 0.09,
                      "brass_dull" if (r + c) % 3 else "chrome", "hero")
            b("cutter_bench", (ix0 + 0.05, by + 0.60, ix0 + 0.72,
                               by + 2.10), 0.01, 0.94, "timber")
            b("cutter", (ix0 + 0.10, by + 1.05, ix0 + 0.66, by + 1.70),
              0.99, 0.34, "cast_iron")
            for i in range(2):
                b("cutter_vise%d" % i,
                  (ix0 + 0.14 + i * 0.26, by + 1.14, ix0 + 0.32 + i * 0.26,
                   by + 1.60), 1.25, 0.16, "cast_iron")
            b("cutter_wheel", (ix0 + 0.16, by + 1.20, ix0 + 0.24,
                               by + 1.55), 1.33, 0.22, "metal")
            b("guide_stylus", (ix0 + 0.48, by + 1.20, ix0 + 0.54,
                                by + 1.55), 1.35, 0.08, "brass_dull")
            # A safe, because a locksmith is also the man who opens one.
            b("safe", (ix1 - 0.78, by + 0.35, ix1 - 0.08, by + 1.05),
              0.05, 1.05, "cast_iron")
            b("safe_dial", (ix1 - 0.50, by + 0.30, ix1 - 0.36, by + 0.36),
              0.62, 0.14, "brass_bright")
            b("counter", (ix0 + 0.05, F - S * 1.40, ix1 - 1.50, F - S * 0.80),
              0.05, 1.02, "wood_dark")
            b("counter_top", (ix0 + 0.02, F - S * 1.45, ix1 - 1.46, F - S * 0.75),
              1.07, 0.05, "countertop")
            b("grinder", (ix0 + 0.10, by + 1.76, ix0 + 0.62,
                           by + 2.06), 1.00, 0.34, "cast_iron")
            b("bench_vise", (ix0 + 0.08, by + 2.16, ix0 + 0.40,
                              by + 2.42), 1.00, 0.30, "cast_iron")
            b("lock_cloth", (mid - 0.46, by + 1.16, mid + 0.46,
                              by + 1.72), 0.91, 0.035, "linen")
            for i in range(4):
                lx = mid - 0.36 + i * 0.22
                b("mortise%d" % i, (lx, by + 1.25, lx + 0.15,
                                     by + 1.58), 0.95, 0.11, "brass_dull")
            b("pick_roll", (mid - 0.40, by + 1.80, mid + 0.38,
                             by + 2.12), 0.94, 0.055, "vinyl_oxblood")
            b("padlock_rail", (ix1 - 0.45, by + 1.26, ix1 - 0.10,
                                F - S * 2.20), 1.48, 0.045, "brass_dull")
            for i in range(6):
                py = by + 1.42 + i * 0.42
                b("padlock%d" % i, (ix1 - 0.50, py, ix1 - 0.07,
                                     py + 0.20), 1.32, 0.26, "brass_dull")
            # A short shop still needs the grabber's equivalent: a narrow
            # stepladder folded against the wall, never in the customer lane.
            for i, xx in enumerate((ix1 - 0.78, ix1 - 0.52)):
                b("step_rail%d" % i, (xx, F - S * 2.42, xx + 0.06,
                                      F - S * 1.78), 0.05, 1.62, "timber")
            for i in range(4):
                b("step_rung%d" % i, (ix1 - 0.76, F - S * 2.35,
                                       ix1 - 0.50, F - S * 2.29),
                  0.26 + i * 0.32, 0.05, "timber")
            b("ledger", (mid - 0.16, F - S * 1.28, mid + 0.18,
                          F - S * 0.92), 1.13, 0.05, "paper")

        elif trade == "radio":
            # A SIGNAL TRADE, which under VIII.2 means this is the most
            # modern room on the block and knows it. The bench is where a
            # set gets aligned; the shop knows about the carrier at 1610
            # and will not say.
            b("bench", (ix1 - 0.78, by + 0.50, ix1 - 0.05, F - S * 2.20),
              0.05, 0.90, "timber", "hero")
            b("bench_top", (ix1 - 0.84, by + 0.45, ix1 - 0.02, F - S * 2.15),
              0.95, 0.06, "wood_dark", "hero")
            # A set with its back off, and the test gear over it.
            b("chassis", (ix1 - 0.70, by + 1.10, ix1 - 0.16, by + 1.72),
              1.01, 0.34, "bakelite_black", "hero")
            b("scope", (ix1 - 0.72, by + 2.05, ix1 - 0.20, by + 2.55),
              1.01, 0.44, "appliance", "hero")
            b("scope_face", (ix1 - 0.76, by + 2.16, ix1 - 0.72, by + 2.44),
              1.16, 0.22, "screen", "hero")
            b("signal_gen", (ix1 - 0.70, by + 2.72, ix1 - 0.18,
                              by + 3.20), 1.01, 0.38, "bakelite_black",
              "hero")
            for i in range(5):
                vx = ix1 - 0.65 + i * 0.10
                b("bench_valve%d" % i, (vx, by + 1.20, vx + 0.07,
                                         by + 1.31), 1.36, 0.22,
                  "milk_glass", "hero")
            for i in range(4):
                b("valve_sh%d" % i, (ix0 + 0.05, by + 0.40, ix0 + 0.34,
                                     F - S * 2.60), 0.85 + i * 0.42, 0.04,
                  "timber")
            for i in range(14):
                vy = by + 0.55 + (i % 7) * 0.30
                b("valve%d" % i, (ix0 + 0.12, vy, ix0 + 0.22, vy + 0.10),
                  0.89 + (i // 7) * 0.84, 0.13, "milk_glass")
            b("counter", (ix0 + 0.05, F - S * 1.35, ix1 - 1.50, F - S * 0.75),
              0.05, 1.02, "wood_dark")
            b("counter_top", (ix0 + 0.02, F - S * 1.40, ix1 - 1.46, F - S * 0.70),
              1.07, 0.05, "countertop")
            # Battery charging belongs to 1927 even though the instruments
            # beside it do not: wet cells in glass jars, wired in series.
            b("battery_rack", (mid - 0.54, by + 0.28, mid + 0.54,
                                by + 0.72), 0.05, 0.84, "timber")
            for i in range(5):
                bx = mid - 0.46 + i * 0.20
                b("wet_cell%d" % i, (bx, by + 0.36, bx + 0.14,
                                      by + 0.64), 0.94, 0.32, "glassish")
                b("cell_cap%d" % i, (bx + 0.03, by + 0.39, bx + 0.11,
                                      by + 0.61), 1.27, 0.06, "bakelite_black")
            # Speakers make the trade legible from the pavement without a
            # word: one horn, one new cone, both on the display plinth.
            b("horn_mouth", (ix0 + 0.42, F - S * 0.74, ix0 + 0.92,
                              F - S * 0.36), 0.48, 0.48, "brass_dull")
            b("horn_throat", (ix0 + 0.84, F - S * 0.65, ix0 + 1.12,
                               F - S * 0.45), 0.54, 0.22, "brass_dull")
            # Twenty-five centimetres deeper than the horn: the old position
            # sat just inside the glazed door's quarter-sweep. The display was
            # legible from the pavement and physically hit by its own door.
            b("cone_speaker", (ix0 + 1.18, F - S * 0.99, ix0 + 1.74,
                                F - S * 0.59), 0.46, 0.58, "fabric_warm")
            b("aerial_spools", (mid - 0.42, by + 1.04, mid + 0.42,
                                 by + 1.42), 0.08, 0.46, "copper_aged")
            b("solder_ring", (mid - 0.32, by + 1.54, mid + 0.32,
                               by + 1.92), 0.08, 0.26, "cast_iron")
            b("ledger", (mid - 0.18, F - S * 1.30, mid + 0.18,
                          F - S * 0.92), 1.13, 0.05, "paper")
            # On the floor at the back, half stripped, "in for repair"
            # since before anyone asked. It works perfectly.
            #
            # Against the BACK wall rather than the west one: the valve
            # shelves are 0.29 m deep and a cabinet is 0.72, so the west
            # wall could not hold both and the cabinet was standing in
            # the shelving.
            cab(0, mid, by + 0.55, 180, 2)

        elif trade == "diner":
            # A counter and eight stools, which is what the brief says
            # and also what a luncheonette IS: the counter is not
            # furniture in the room, it is the room.
            # THE COUNTER STOPS 1.5 m SHORT OF THE EAST WALL, which is
            # what makes the rest of this room work: the two machines go
            # in that corner, on the CUSTOMER side. Run the counter the
            # full width and the only floor left for them is behind it,
            # where a customer would have to vault the servery to reach
            # a machine and the player simply cannot get to one at all.
            cy = F - S * 2.25
            CE = ix1 - 1.50                    # counter's east end
            b("counter", (ix0 + 0.35, cy - 0.34, CE, cy + 0.34),
              0.05, 1.02, "wood_dark")
            b("counter_top", (ix0 + 0.30, cy - 0.40, CE + 0.05,
                              cy + 0.40), 1.07, 0.05, "countertop")
            b("counter_kick", (ix0 + 0.30, cy + 0.34, CE + 0.05,
                               cy + 0.40), 0.01, 0.14, "chrome")
            for i in range(8):
                sx = ix0 + 0.62 + i * (CE - ix0 - 0.94) / 7.0
                b("stool%d" % i, (sx - 0.17, cy + 0.72, sx + 0.17,
                                  cy + 1.06), 0.01, 0.70, "chrome")
                b("stool%d_top" % i, (sx - 0.20, cy + 0.69, sx + 0.20,
                                      cy + 1.09), 0.75, 0.07,
                  "vinyl_oxblood")
            # Back bar: the urns, the pie case, the shelf of everything.
            b("backbar", (ix0 + 0.35, by + 0.90, ix1 - 0.30, by + 1.45),
              0.05, 0.92, "chrome", "hero")
            b("backbar_top", (ix0 + 0.30, by + 0.85, ix1 - 0.25,
                              by + 1.50), 0.97, 0.05, "countertop", "hero")
            for i in range(2):
                ux = ix0 + 0.85 + i * 0.62
                b("urn%d" % i, (ux - 0.19, by + 1.02, ux + 0.19,
                                by + 1.36), 1.02, 0.74, "nickel_plated",
                  "hero")
                b("urn%d_lid" % i, (ux - 0.23, by + 0.98, ux + 0.23,
                                     by + 1.40), 1.77, 0.08,
                  "nickel_plated", "hero")
                b("urn%d_tap" % i, (ux - 0.08, by + 1.36, ux + 0.08,
                                     by + 1.62), 1.25, 0.12,
                  "brass_dull", "hero")
                b("urn%d_gauge" % i, (ux + 0.13, by + 1.37, ux + 0.18,
                                       by + 1.55), 1.28, 0.34,
                  "glassish", "hero")
            b("piecase", (ix1 - 1.35, by + 1.00, ix1 - 0.45, by + 1.42),
              1.02, 0.46, "glassish", "hero")
            for i in range(3):
                b("bbshelf%d" % i, (ix0 + 0.35, by + 0.62, ix1 - 0.30,
                                    by + 0.67), 1.32 + i * 0.40, 0.04,
                  "timber")
            b("griddle", (ix0 + 0.40, by + 1.55, ix0 + 1.50, by + 2.10),
              0.05, 0.92, "metal")
            b("griddle_top", (ix0 + 0.38, by + 1.52, ix0 + 1.52,
                              by + 2.13), 0.97, 0.04, "cast_iron")
            # Soda fountain and syrup pumps, deliberately behind the counter;
            # self-service would be the anachronism here, not the chrome.
            b("soda_fount", (mid - 0.62, by + 1.54, mid + 0.62,
                              by + 2.12), 0.05, 0.92, "marble_lobby")
            for i in range(5):
                px = mid - 0.50 + i * 0.24
                b("syrup%d" % i, (px, by + 1.68, px + 0.12,
                                   by + 1.94), 1.00, 0.42,
                  "nickel_plated")
            b("mixer_base", (mid + 0.82, by + 1.56, mid + 1.18,
                              by + 1.90), 1.00, 0.32, "enamel")
            b("mixer_post", (mid + 0.96, by + 1.63, mid + 1.04,
                              by + 1.83), 1.32, 0.54, "nickel_plated")
            # Heavy register and cigar case at the door end of the counter.
            b("register", (CE - 0.56, cy - 0.28, CE - 0.10, cy + 0.22),
              1.13, 0.42, "nickel_plated")
            b("cigar_case", (ix0 + 0.48, cy - 0.30, ix0 + 1.18,
                              cy + 0.30), 1.13, 0.34, "glassish")
            b("menu_board", (ix0 + 0.55, by + 0.13, ix1 - 0.55,
                              by + 0.18), 2.02, 0.72, "bakelite_black")
            # One fan costs six merged boxes and makes the still air visible.
            b("fan_hub", (mid - 0.12, cy - 0.12, mid + 0.12, cy + 0.12),
              2.92, 0.16, "metal")
            for i, rect in enumerate(((mid - 1.10, cy - 0.08, mid - 0.12,
                                        cy + 0.08),
                                       (mid + 0.12, cy - 0.08, mid + 1.10,
                                        cy + 0.08),
                                       (mid - 0.08, cy - 1.10, mid + 0.08,
                                        cy - 0.12),
                                       (mid - 0.08, cy + 0.12, mid + 0.08,
                                        cy + 1.10))):
                b("fan_blade%d" % i, rect, 2.94, 0.055, "metal")
            b("ledger", (mid - 0.18, cy - 0.26, mid + 0.18, cy + 0.12),
              1.13, 0.05, "paper")
            # TWO MACHINES, in the corner the counter leaves free, which
            # is where a diner puts anything that takes coins and makes
            # noise: by the window, in everybody's way, facing the room.
            cab(0, ix1 - 0.45, F - S * 1.15, 270, 1)
            cab(1, ix1 - 0.45, F - S * 1.95, 270, 3)

        elif trade == "news":
            # 2.1 m wide: a slot you stand in the mouth of. The whole
            # trade faces out and the customer barely comes in.
            #
            # THE COUNTER RUNS DOWN THE EAST WALL, not across the front.
            # Across the front it was a 2.1 m barricade 1.2 m inside the
            # shop's own door — the customer never coming in is a
            # characterisation, not a licence to wall the room off, and
            # the machine at the back would have been unreachable.
            b("counter", (ix1 - 0.68, F - S * 2.90, ix1 - 0.05, F - S * 0.62),
              0.05, 1.05, "wood_dark")
            b("counter_top", (ix1 - 0.74, F - S * 2.95, ix1 - 0.02, F - S * 0.56),
              1.10, 0.05, "countertop")
            # Papers, racked at an angle nobody can read from indoors.
            for i in range(4):
                b("rack%d" % i, (ix0 + 0.05, F - S * 2.35, ix0 + 0.46,
                                 F - S * 1.40), 0.30 + i * 0.42, 0.05,
                  "timber", "hero")
            for i in range(8):
                py = F - S * 2.28 + (i % 4) * 0.22
                b("paper%d" % i, (ix0 + 0.09, py, ix0 + 0.42, py + 0.18),
                  0.35 + (i // 4) * 0.84, 0.03, "paper", "hero")
            # Service hatch: the public stops on the pavement; this framed
            # opening and its projecting shelf are the whole transaction.
            b("service_hatch", (ix1 - 0.58, F - S * 0.24, ix1 - 0.12,
                                 F - S * 0.14), 0.92, 0.82, "wood_dark",
              "hero")
            b("service_shelf", (ix1 - 0.66, F - S * 0.30, ix1 - 0.06,
                                 F + S * 0.03), 0.88, 0.07, "timber",
              "hero")
            b("cigars", (ix1 - 0.62, F - S * 2.80, ix1 - 0.10, F - S * 1.95),
              1.15, 0.50, "glassish")
            for i in range(5):
                b("shelf%d" % i, (ix0 + 0.05, by + 0.07, ix1 - 0.05,
                                  by + 0.34), 0.55 + i * 0.42, 0.04,
                  "timber")
            # Small vices, sold from arm's reach: candy jars, pipe rack,
            # tobacco plugs and a half-punched board.  Nothing asks the player
            # to enter the proprietor's 8.4 square metres.
            for i in range(4):
                jx = ix1 - 0.60 + (i % 2) * 0.25
                jy = F - S * (1.06 + (i // 2) * 0.34)
                b("candy_jar%d" % i, (jx, jy, jx + 0.18,
                                      jy + S * 0.20), 1.16, 0.32,
                  "glassish")
            b("pipe_rack", (ix0 + 0.10, by + 0.40, ix0 + 0.42,
                             by + 1.28), 1.10, 0.58, "wood_dark")
            for i in range(5):
                py = by + 0.48 + i * 0.15
                b("pipe%d" % i, (ix0 + 0.14, py, ix0 + 0.38, py + 0.07),
                  1.20 + (i % 2) * 0.15, 0.08, "bakelite_black")
            b("punchboard", (ix1 - 0.62, F - S * 1.82, ix1 - 0.10,
                              F - S * 1.20), 1.16, 0.08, "paper")
            b("cash_drawer", (ix1 - 0.62, F - S * 2.18, ix1 - 0.10,
                               F - S * 1.84), 0.78, 0.26, "wood_dark")
            b("stool", (mid - 0.24, by + 1.14, mid + 0.24,
                         by + 1.62), 0.05, 0.62, "wood_dark")
            b("chair_hollow", (mid - 0.34, by + 1.02, mid + 0.34,
                                by + 1.76), 0.012, 0.007, "soot")
            b("racing_form", (ix1 - 0.60, F - S * 2.54, ix1 - 0.12,
                               F - S * 2.20), 0.78, 0.035, "paper")
            b("ledger", (ix1 - 0.60, F - S * 1.18, ix1 - 0.14,
                          F - S * 0.82), 1.16, 0.045, "paper")
            # The racing page nobody admits to, and the machine that is
            # the same transaction with the pretence removed. by+0.95
            # rather than by+0.55: the back shelving is 0.27 deep and
            # 0.55 stood the cabinet in it.
            cab(0, mid - 0.25, by + 0.95, 180, 0)

        elif trade == "pawn":
            # Glass down both walls, a grille at the back, and the whole
            # inventory a record of what the block stopped being able to
            # keep. It buys what the smash room leaves.
            # The cases stop at F-2.60 rather than F-1.90, which leaves
            # the front metre of the west wall clear for the cabinet. The
            # door is at the EAST end of this bay, so the west front
            # corner is the one bit of floor nothing walks through.
            for side, sx0, sx1 in (("w", ix0 + 0.05, ix0 + 0.62),
                                   ("e", ix1 - 0.62, ix1 - 0.05)):
                b("case_%s" % side, (sx0, by + 1.20, sx1, F - S * 2.60),
                  0.05, 0.92, "wood_dark")
                b("case_%s_gl" % side, (sx0, by + 1.20, sx1, F - S * 2.60),
                  0.97, 0.44, "glassish")
                b("case_%s_top" % side, (sx0 - 0.03, by + 1.17, sx1 + 0.03,
                                         F - S * 2.57), 1.41, 0.04, "brass_dull")
            # A wall of clocks, which is what a pawnshop wall always is,
            # and none of them agree — in a building whose case system
            # already plays with time, that is not only a joke.
            # Static pawned movements reuse the reviewed clock family's
            # measured 0.32 m case language without instantiating fifteen
            # FunctionalProps. They hang on the east wall and disagree.
            for i in range(15):
                cy_clock = by + 1.52 + (i % 5) * 0.70
                b("clock%d" % i, (ix1 - 0.13, cy_clock, ix1 - 0.07,
                                  cy_clock + 0.32),
                  1.18 + (i // 5) * 0.52, 0.32,
                  "brass_dull" if i % 2 else "wood_dark")
            # The unredeemed shelf is the hero, not treasure: brown-paper
            # parcels and a few painfully specific objects behind the grille.
            for r in range(4):
                b("pledge_shelf%d" % r, (ix0 + 0.45, by + 0.14,
                                          ix1 - 0.45, by + 0.54),
                  0.26 + r * 0.55, 0.055, "timber", "hero")
                for c in range(6):
                    px = ix0 + 0.56 + c * (ix1 - ix0 - 1.12) / 6.0
                    b("pledge%d_%d" % (r, c),
                      (px, by + 0.20, px + (ix1 - ix0 - 1.34) / 6.0,
                       by + 0.49), 0.32 + r * 0.55, 0.34,
                      "paper" if (r + c) % 2 else "linen", "hero")
            b("violin_case", (mid - 0.92, by + 0.56, mid - 0.28,
                               by + 1.34), 0.30, 0.25, "wood_dark", "hero")
            b("sewing_case", (mid + 0.08, by + 0.62, mid + 0.72,
                               by + 1.18), 0.86, 0.54, "enamel", "hero")
            b("coat", (ix1 - 0.78, by + 0.55, ix1 - 0.28,
                        by + 1.06), 1.42, 1.02, "fabric_warm", "hero")
            b("grille_counter", (ix0 + 0.70, by + 0.75, ix1 - 0.70,
                                 by + 1.35), 0.01, 1.08, "wood_dark")
            b("grille_top", (ix0 + 0.66, by + 0.70, ix1 - 0.66, by + 1.40),
              1.13, 0.05, "countertop")
            b("grille", (ix0 + 0.70, by + 1.00, ix1 - 0.70, by + 1.06),
              1.18, 0.95, "brass_mesh")
            b("wicket", (mid - 0.34, by + 0.94, mid + 0.34,
                          by + 1.12), 1.22, 0.46, "brass_dull")
            b("balance_base", (mid - 0.28, by + 1.18, mid + 0.28,
                                by + 1.54), 1.19, 0.12, "brass_dull")
            b("balance_beam", (mid - 0.42, by + 1.30, mid + 0.42,
                                by + 1.38), 1.54, 0.06, "brass_dull")
            b("safe", (ix1 - 1.12, by + 0.50, ix1 - 0.28,
                        by + 1.28), 0.05, 1.08, "cast_iron")
            b("ledger", (mid - 0.22, by + 1.14, mid + 0.22,
                          by + 1.58), 1.19, 0.055, "paper")
            b("loupe", (mid + 0.28, by + 1.24, mid + 0.42,
                         by + 1.40), 1.20, 0.06, "bakelite_black")
            # Somebody pawned it and never came back for it.
            cab(0, ix0 + 0.48, F - S * 1.55, 90, 1)

        elif trade == "funeral":
            # A front room you can hold a service in. Dorothy Ash went
            # from here. Chairs, a lectern, and drapes across the chapel
            # behind — which is not modelled, and should not be.
            for r in range(4):
                for c in range(4):
                    cx_ = mid - 1.35 + c * 0.90
                    cy_ = by + 2.30 + r * 0.78
                    b("chair%d_%d" % (r, c), (cx_ - 0.21, cy_ - 0.21,
                                              cx_ + 0.21, cy_ + 0.21),
                      0.05, 0.44, "wood_dark")
                    b("chairb%d_%d" % (r, c), (cx_ - 0.21, cy_ + 0.14,
                                               cx_ + 0.21, cy_ + 0.21),
                      0.49, 0.48, "wood_dark")
            b("lectern", (mid - 0.28, by + 1.15, mid + 0.28, by + 0.85),
              0.05, 1.12, "wood_dark")
            b("lectern_top", (mid - 0.34, by + 0.80, mid + 0.34,
                              by + 1.20), 1.17, 0.05, "oak_quartered")
            b("book", (mid - 0.14, by + 0.95, mid + 0.14, by + 1.12),
              1.22, 0.05, "paper")
            # THE EMPTY BIER.  Nothing is modelled on it; that absence is the
            # room's hero and is why it is judged here rather than isolated.
            for i, bx in enumerate((mid - 1.10, mid + 0.82)):
                b("bier_trestle%d" % i, (bx, by + 1.34, bx + 0.28,
                                         by + 1.94), 0.05, 0.62,
                  "wood_dark")
            b("bier", (mid - 1.30, by + 1.28, mid + 1.30, by + 2.00),
              0.69, 0.10, "wood_dark")
            # Pleated, as alternating depths, so they read as cloth.
            for i in range(14):
                dx = ix0 + 0.20 + i * (ix1 - ix0 - 0.40) / 14.0
                dd = 0.10 if i % 2 else 0.17
                b("drape%d" % i, (dx, by + 0.13, dx + 0.16, by + 0.13 + dd),
                  0.05, 2.85, "vinyl_oxblood")
            b("stand", (ix0 + 0.25, F - S * 1.50, ix0 + 0.70, F - S * 1.05),
              0.05, 0.86, "wood_dark")
            b("wreath", (ix0 + 0.22, F - S * 1.55, ix0 + 0.73, F - S * 1.00),
              0.91, 0.14, "plant")
            # Turn the east arrangement against the party wall.  Centred in
            # the frontage it became the first thing a mourner walked into.
            b("stand_e", (ix1 - 0.42, F - S * 2.50, ix1 - 0.10,
                           F - S * 1.72), 0.05, 0.86, "wood_dark")
            b("wreath_e", (ix1 - 0.46, F - S * 2.54, ix1 - 0.06,
                            F - S * 1.68), 0.91, 0.14, "plant")
            for side, px0, px1 in (("w", ix0 + 0.18, ix0 + 0.72),
                                   ("e", ix1 - 0.72, ix1 - 0.18)):
                b("palm_pot_%s" % side, (px0, by + 0.58, px1,
                                          by + 1.06), 0.05, 0.52,
                  "brass_dull")
                b("palm_%s" % side, (px0 - 0.18, by + 0.45, px1 + 0.18,
                                      by + 1.20), 0.58, 1.28, "plant")

        elif trade == "hardware":
            # Bins, a paint bench, and the only ladder on the block —
            # which is a plot device as much as a fitting.
            # The ordered drawer wall is the hero because it is the only
            # disciplined surface in thirty years of accretion.
            b("drawer_carcass", (ix0 + 0.42, by + 0.14, mid + 0.86,
                                  by + 0.50), 0.10, 2.30, "wood_dark",
              "hero")
            for r in range(5):
                for c in range(7):
                    dx0 = ix0 + 0.50 + c * (mid + 0.24 - ix0) / 7.0
                    dw = (mid + 0.06 - ix0) / 7.0
                    b("drawer%d_%d" % (r, c),
                      (dx0, by + 0.09, dx0 + dw, by + 0.16),
                      0.24 + r * 0.40, 0.32, "oak_quartered", "hero")
                    b("drawer_pull%d_%d" % (r, c),
                      (dx0 + dw * 0.38, by + 0.06, dx0 + dw * 0.62,
                       by + 0.10), 0.36 + r * 0.40, 0.06,
                      "brass_dull", "hero")
            for side, sx0, sx1 in (("w", ix0 + 0.05, ix0 + 0.52),
                                   ("e", ix1 - 0.52, ix1 - 0.05)):
                for i in range(6):
                    b("bin_%s%d" % (side, i), (sx0, by + 0.50, sx1,
                                               F - S * 2.10),
                      0.20 + i * 0.44, 0.06, "timber")
                for i in range(18):
                    byy = by + 0.62 + (i % 6) * 0.62
                    b("stock_%s%d" % (side, i), (sx0 + 0.05, byy,
                                                 sx1 - 0.05, byy + 0.34),
                      0.26 + (i // 6) * 0.44, 0.16,
                      ("safety_orange", "brass_dull", "metal")[i % 3])
            b("paint_bench", (mid - 1.05, by + 0.55, mid + 1.05,
                              by + 1.25), 0.01, 0.92, "timber")
            b("paint_top", (mid - 1.10, by + 0.50, mid + 1.10, by + 1.30),
              0.97, 0.06, "metal")
            for i in range(7):
                px = mid - 0.90 + i * 0.30
                b("can%d" % i, (px - 0.11, by + 0.72, px + 0.11,
                                by + 1.05), 1.03, 0.26,
                  ("lacquer_red", "book_teal", "fabric_green",
                   "safety_orange")[i % 4])
            # THE LADDER, leant where a ladder is always leant.
            b("ladder_r0", (ix1 - 0.95, F - S * 3.10, ix1 - 0.87, F - S * 2.30),
              0.05, 3.05, "timber")
            b("ladder_r1", (ix1 - 0.55, F - S * 3.10, ix1 - 0.47, F - S * 2.30),
              0.05, 3.05, "timber")
            for i in range(9):
                b("ladder_rung%d" % i, (ix1 - 0.90, F - S * 3.05, ix1 - 0.50,
                                        F - S * 2.98), 0.30 + i * 0.32, 0.05,
                  "timber")
            b("counter", (ix0 + 0.60, F - S * 1.40, ix1 - 1.60, F - S * 0.80),
              0.05, 1.02, "wood_dark")
            b("counter_top", (ix0 + 0.56, F - S * 1.45, ix1 - 1.56, F - S * 0.75),
              1.07, 0.05, "countertop")
            b("scale_base", (mid - 0.34, by + 1.42, mid + 0.34,
                              by + 1.88), 0.05, 0.52, "cast_iron")
            b("scale_beam", (mid - 0.46, by + 1.57, mid + 0.46,
                              by + 1.68), 0.74, 0.07, "brass_dull")
            b("paint_shaker", (mid + 0.62, by + 1.42, mid + 1.32,
                                by + 2.12), 0.05, 1.08, "cast_iron")
            b("paddle", (mid + 0.78, by + 2.18, mid + 1.12,
                          by + 2.26), 0.10, 1.12, "timber")
            # Glass sheets on edge, kept at the back where a customer cannot
            # brush them; the cutter lies on the timber rail beside them.
            b("glass_rack", (ix0 + 0.72, by + 0.58, ix0 + 1.34,
                              by + 1.62), 0.05, 1.34, "timber")
            for i in range(5):
                gx = ix0 + 0.78 + i * 0.10
                b("glass_sheet%d" % i, (gx, by + 0.64, gx + 0.025,
                                         by + 1.56), 0.22, 1.02,
                  "glassish")
            b("glass_cutter", (ix0 + 0.82, by + 1.68, ix0 + 1.28,
                                by + 1.76), 0.92, 0.07, "brass_dull")
            # Shadow board: tools are blocks at this distance; one pale
            # silhouette deliberately has no tool over it.
            b("tool_board", (ix1 - 0.46, by + 0.22, ix1 - 0.09,
                              by + 2.88), 1.10, 1.34, "plywood")
            for i in range(8):
                ty = by + 0.36 + i * 0.30
                b("tool_shadow%d" % i, (ix1 - 0.43, ty, ix1 - 0.12,
                                         ty + 0.12), 1.22, 0.42,
                  "soot")
                if i != 5:
                    b("tool%d" % i, (ix1 - 0.39, ty + 0.02,
                                      ix1 - 0.16, ty + 0.09),
                      1.29, 0.27, "metal")
            b("ledger", (mid - 0.18, F - S * 1.30, mid + 0.18,
                          F - S * 0.92), 1.13, 0.05, "paper")

        elif trade == "photo":
            # Film for the handset. Nadia is in here more than she is
            # upstairs, and this is the only shop on the street whose
            # trade the player's own phone depends on.
            b("counter", (ix0 + 1.50, F - S * 1.65, ix1 - 1.40, F - S * 0.95),
              0.05, 1.00, "wood_dark")
            b("counter_gl", (ix0 + 1.50, F - S * 1.65, ix1 - 1.40, F - S * 0.95),
              1.05, 0.36, "glassish")
            b("counter_top", (ix0 + 1.46, F - S * 1.70, ix1 - 1.36, F - S * 0.90),
              1.41, 0.04, "brass_dull")
            for i in range(5):
                b("cab_sh%d" % i, (ix0 + 0.05, by + 1.30, ix0 + 0.40,
                                   F - S * 2.20), 0.55 + i * 0.44, 0.04,
                  "timber")
            for i in range(15):
                fy = by + 1.45 + (i % 5) * 0.52
                b("box%d" % i, (ix0 + 0.09, fy, ix0 + 0.36, fy + 0.30),
                  0.59 + (i // 5) * 0.44, 0.16,
                  ("book_ochre", "book_teal", "lacquer_red")[i % 3])
            # Enlargers on the high shelf, second-hand, all of them.
            for i in range(3):
                ex = mid - 0.70 + i * 0.70
                b("enl%d" % i, (ex - 0.17, by + 0.40, ex + 0.17,
                                by + 0.74), 1.62, 0.62, "cast_iron")
            b("enl_shelf", (ix0 + 0.45, by + 0.35, ix1 - 0.45, by + 0.80),
              1.56, 0.06, "timber")
            # THE DARKROOM DOOR, and the red light over it that is the
            # only reason anyone believes the back of this shop exists.
            b("dr_door", (ix1 - 1.30, by + 0.07, ix1 - 0.35, by + 0.13),
              0.05, 2.05, "wood_dark", "hero")
            b("dr_lamp", (ix1 - 0.95, by + 0.13, ix1 - 0.70, by + 0.22),
              2.18, 0.18, "lacquer_red", "hero")
            mk.append({"kind": "cage_bulb",
                       "id": "SITE_SHOP_DARKROOM_%s" % tag.upper(),
                       "unit": "SITE",
                       "pos": [ix1 - 0.82, by + 0.30, 2.24],
                       "yaw_deg": 0, "network": "electrical",
                       "range": 2.2, "energy": 0.34,
                       "navigation": False, "standby": 0.34,
                       "exterior": True})
            # Three expensive cameras, and no more.  Folding bellows, a box
            # camera and one press body are silhouettes under locked glass,
            # because photography in this world is dear.
            for i, xx in enumerate((ix0 + 1.82, ix0 + 2.50, ix0 + 3.18)):
                b("camera_body%d" % i, (xx, F - S * 0.70, xx + 0.42,
                                        F - S * 0.36), 0.48, 0.42,
                  "bakelite_black")
                b("camera_lens%d" % i, (xx + 0.13, F - S * 0.34,
                                         xx + 0.29, F - S * 0.24),
                  0.58, 0.17, "brass_dull")
            # Process equipment stays visibly second-hand and dangerous.
            for i in range(4):
                b("dev_tray%d" % i, (mid - 0.72, by + 1.02 + i * 0.34,
                                      mid + 0.18, by + 1.28 + i * 0.34),
                  0.08 + i * 0.10, 0.045, "enamel")
            for i in range(3):
                b("tank%d" % i, (mid + 0.34 + i * 0.30, by + 1.04,
                                  mid + 0.56 + i * 0.30, by + 1.34),
                  0.08, 0.58, "nickel_plated")
            b("print_dryer", (ix1 - 1.42, by + 1.16, ix1 - 0.78,
                               by + 1.92), 0.05, 0.90, "enamel")
            for i in range(4):
                b("tripod%d" % i, (ix1 - 0.58 + i * 0.10, by + 2.12,
                                    ix1 - 0.53 + i * 0.10, by + 2.78),
                  0.05, 1.72, "timber")
            for i in range(4):
                b("flash_tin%d" % i, (ix0 + 0.52 + i * 0.24, by + 0.42,
                                       ix0 + 0.70 + i * 0.24, by + 0.70),
                  0.46, 0.24, "metal")
            # Unclaimed portraits rhyme once, with the laundry parcels.
            b("portrait_rail", (ix0 + 0.48, by + 0.12, mid - 0.38,
                                 by + 0.18), 1.20, 0.06, "timber")
            for i in range(7):
                px = ix0 + 0.54 + (i % 4) * (mid - ix0 - 1.10) / 4.0
                b("portrait%d" % i, (px, by + 0.13,
                                      px + (mid - ix0 - 1.32) / 4.0,
                                      by + 0.19),
                  1.30 + (i // 4) * 0.54, 0.44, "paper")
            b("ledger", (mid - 0.18, F - S * 1.52, mid + 0.18,
                          F - S * 1.12), 1.46, 0.05, "paper")
            cab(0, ix1 - 0.45, by + 1.55, 270, 2)

        elif trade == "druggist":
            # THE ONLY SHOP ON THE NORTH SIDE, and the one the building
            # actually needs. Bible VIII fences the divergence to signal
            # technology alone: everything else is 1927, which here means
            # there is no penicillin, and a druggist is where a household
            # goes with things a household cannot fix. It is played as a
            # bright, orderly, well-kept room — the wrongness is that it
            # is orderly, not that it is grim.
            #
            # by is on the far side here (the north row runs +y), so
            # every offset from it reads the same as the south shops'.
            d = 1.0 if by > F else -1.0
            # The long counter down one side, which is what a druggist of
            # this date IS: you do not browse, you ask.
            b("counter", (ix0 + 0.05, F + d * 1.60, ix0 + 0.75,
                          by - d * 1.70), 0.01, 1.05, "wood_dark")
            b("counter_top", (ix0 + 0.02, F + d * 1.55, ix0 + 0.82,
                              by - d * 1.65), 1.06, 0.05, "countertop")
            # The wall of drawers behind it. A hundred small labelled
            # things, and the labels are the one place this building
            # would like you to look and cannot let you read.
            for r in range(6):
                for c in range(9):
                    dy = F + d * (1.75 + c * (SHOP_PLAN[trade][0] - 3.4)
                                  / 8.0)
                    b("drw%d_%d" % (r, c), (ix0 + 0.05, dy, ix0 + 0.12,
                                            dy + d * 0.30),
                      1.20 + r * 0.26, 0.22,
                      "oak_quartered" if (r + c) % 4 else "wood_dark")
            # THE SODA FOUNTAIN, halfway down, marble and nickel, and the
            # four stools nobody has sat on since the summer.
            b("fount", (ix1 - 0.85, F + d * 2.10, ix1 - 0.05,
                        F + d * 4.30), 0.01, 1.02, "marble_lobby")
            b("fount_top", (ix1 - 0.92, F + d * 2.05, ix1 - 0.02,
                            F + d * 4.35), 1.03, 0.05, "marble_lobby")
            for i in range(3):
                fx = ix1 - 0.60 + i * 0.22
                b("fount_tap%d" % i, (fx, F + d * 2.60, fx + 0.09,
                                      F + d * 2.69), 1.08, 0.44, "chrome")
            for i in range(4):
                sy = F + d * (2.35 + i * 0.62)
                b("stool%d" % i, (ix1 - 1.30, sy, ix1 - 1.00,
                                  sy + d * 0.30), 0.01, 0.68, "chrome")
                b("stool%d_top" % i, (ix1 - 1.34, sy - d * 0.02,
                                      ix1 - 0.96, sy + d * 0.32),
                  0.69, 0.07, "vinyl_oxblood")
            # The dispensary at the far end, screened, with the carboys
            # in the window that every chemist of this date owned.
            b("disp", (ix0 + 0.90, by - d * 0.90, ix1 - 0.30,
                       by - d * 0.30), 0.01, 1.10, "wood_dark")
            b("disp_top", (ix0 + 0.86, by - d * 0.95, ix1 - 0.26,
                           by - d * 0.25), 1.11, 0.05, "countertop")
            b("disp_screen", (ix0 + 0.90, by - d * 0.34, ix1 - 0.30,
                              by - d * 0.28), 1.16, 0.95, "glassish")
            for i, cm in enumerate(("book_teal", "lacquer_red",
                                    "fabric_green", "book_ochre")):
                # All four belong in the broad display bay opposite the
                # recessed door.  The old final pedestal sat dead-centre in
                # the north shop's entrance.
                cx_ = ix0 + 0.45 + i * 0.48
                b("carboy_ped%d" % i,
                  (cx_ - 0.23, F + d * 0.24, cx_ + 0.23, F + d * 0.70),
                  0.05, 0.55, "wood_dark", "hero")
                b("carboy%d" % i, (cx_ - 0.17, F + d * 0.30, cx_ + 0.17,
                                   F + d * 0.64), 0.62, 0.72, cm, "hero")
                b("carboy_stop%d" % i,
                  (cx_ - 0.08, F + d * 0.37, cx_ + 0.08, F + d * 0.57),
                  1.34, 0.22, "glassish", "hero")
            # Shop rounds in graded ranks. Their labels are porcelain blanks;
            # the player reads order and danger, never generated typography.
            for r in range(3):
                b("round_shelf%d" % r,
                  (mid - 0.15, by - d * 0.72, ix1 - 0.22,
                   by - d * 0.62), 0.82 + r * 0.48, 0.055, "timber")
                for i in range(7):
                    rx = mid + 0.02 + i * (ix1 - mid - 0.46) / 7.0
                    b("round%d_%d" % (r, i),
                      (rx, by - d * 0.68, rx + 0.13,
                       by - d * 0.50), 0.88 + r * 0.48, 0.34,
                      "glassish")
            # Locked poison cupboard and tactile ribbed bottles: designed to
            # be identified with the lights out, which is why it belongs here.
            b("poison_cupboard", (ix1 - 0.72, by - d * 1.62, ix1 - 0.12,
                                   by - d * 0.82), 0.22, 1.72,
              "wood_dark")
            b("poison_glass", (ix1 - 0.76, by - d * 1.54, ix1 - 0.70,
                                by - d * 0.90), 0.58, 0.92, "glassish")
            for i in range(6):
                py = by - d * (1.46 - i * 0.09)
                b("poison%d" % i, (ix1 - 0.62, py, ix1 - 0.42,
                                    py + d * 0.07),
                  0.66 + (i % 2) * 0.38, 0.34,
                  "book_teal" if i % 2 else "lacquer_red")
                b("poison_rib%d" % i, (ix1 - 0.65, py, ix1 - 0.39,
                                        py + d * 0.025),
                  0.72 + (i % 2) * 0.38, 0.05, "porcelain")
            b("mortar", (mid - 0.46, by - d * 0.82, mid - 0.12,
                          by - d * 0.48), 1.18, 0.30, "marble_lobby")
            b("pestle", (mid - 0.34, by - d * 0.92, mid - 0.24,
                          by - d * 0.44), 1.42, 0.12, "marble_lobby")
            b("balance_case", (mid + 0.08, by - d * 0.88, mid + 0.68,
                                by - d * 0.42), 1.18, 0.54, "glassish")
            b("telephone", (ix0 + 0.14, F + d * 1.86, ix0 + 0.62,
                             F + d * 2.30), 1.12, 0.38, "bakelite_black")
            b("ledger", (ix0 + 0.12, F + d * 2.54, ix0 + 0.62,
                          F + d * 3.02), 1.12, 0.05, "paper")
