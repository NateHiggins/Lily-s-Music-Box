"""Fit original shopfront identity stocks and lettering to the new arcade."""

from collections import Counter
import re


ROLES = re.compile(r"(band|sign|cornice|awning|awn_val|awn_arm\d+|blade|bracket|plaque)$")
COUNTS = dict(band=11, sign=11, cornice=11, awning=6, awn_val=6,
              awn_arm=12, blade=5, bracket=5, plaque=11)
# Registered replacements for the old baked finishes, with explicit colour.
FINISHES = {
    "common_brick": ("arcade_brick_face", [1, 1, 1, 1]),
    "awning_vinyl": ("linen", [.69, .53, .25, 1]),
    "fabric_green": ("fabric_warm", [.38, .59, .40, 1]),
    "felt_violet": ("fabric_warm", [.57, .41, .65, 1]),
    "lacquer_red": ("enamel", [.72, .27, .23, 1]),
    "safety_orange": ("enamel", [.91, .51, .23, 1]),
    "stairwell_teal": ("enamel", [.35, .57, .56, 1]),
}
# Lateral is the label actor's local +X after the factory negates yaw.
FRONTS = {"east": ((1, 0), (0, -1), 270.),
          "west": ((-1, 0), (0, 1), 90.),
          "north": ((0, -1), (-1, 0), 180.)}
FACES = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
         (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]


def storefront(shop, floor, plan):
    cell = shop["id"]
    suffix = "otis___son" if cell == "shop_otis_son" else cell[5:]
    marker, = [m for m in floor["markers"] if m["id"] == "SITE_SHOP_SIGN_" + suffix.upper()]
    source = {}
    for row in floor["furniture"]:
        prefix = "storm_sf_" + suffix + "_"
        if row["id"].startswith(prefix) and (match := ROLES.fullmatch(row["id"][len(prefix):])):
            if match[0] in source:
                raise ValueError(f"Duplicate storefront role for {cell}: {match[0]}")
            source[match[0]] = row
    compact = marker["compact"]
    blade = bool(marker["blade_text"])
    arms = sorted(key for key in source if key.startswith("awn_arm"))
    expected = {"band", "cornice", "sign", "plaque"}
    if compact:
        expected.update(["awning", "awn_val", *arms])
    if blade:
        expected.update(["blade", "bracket"])
    if set(source) != expected or len(arms) != (2 if compact else 0) or compact and blade:
        raise ValueError(f"Unexpected original storefront roles for {cell}")

    front = shop["front"]
    normal, lateral, yaw = FRONTS[front]
    u0, v0, u1, v1 = shop["rect_m"]
    centre = {"east": (u1, (v0+v1)/2), "west": (u0, (v0+v1)/2),
              "north": ((u0+u1)/2, v0)}[front]
    half = (u1-u0 if front == "north" else v1-v0)/2
    # Use the exterior wall above the retained transom. The cloth roof rises
    # above the glazing at its wall end, with the valance at the forward edge.
    transom_top = plan["transom_clear_height_m"][1] + plan["window_frame_m"]
    band_base = transom_top
    sign_height = band_base + .17
    blade_dx = half - .46
    # The north shops face a two-metre cross aisle. A shallow canopy leaves
    # enough standing room in front of the valance to read the whole sign.
    valance_depth = .72 if front == "north" else 1.58
    marker_depth = valance_depth+.02 if compact else .17
    marker_height = 2.50 if compact else sign_height

    def xy(along, depth):
        return [centre[i]+lateral[i]*along+normal[i]*depth for i in range(2)]

    def stock(role, along, reach, heights, slope=0.):
        left, right = along
        back, forward = reach
        bottom, top = heights
        points = [xy(a, d)+[height+slope*(d-back)] for height in (bottom, top)
                  for d in (back, forward) for a in (left, right)]
        row = source[role]
        key, tint = FINISHES.get(row["mat"], (row["mat"], [1, 1, 1, 1]))
        return dict(name=row["id"], owner=cell, role=re.sub(r"\d+$", "", role),
                    source=row, catalog_key=key, tint=tint, vertices=points, faces=FACES)

    width = (-half+.08, half-.08)
    stocks = [
        stock("band", width, (0., .10), (band_base, 3.28)),
        stock("sign", (-half+.22, half-.22), (.10, .16), (band_base, 3.28)),
        stock("cornice", width, (0., .18), (3.28, 3.50)),
    ]
    along = shop["entrance_center_m"][0 if front == "north" else 1]
    mid = centre[0 if front == "north" else 1]
    door = (along-mid)*lateral[0 if front == "north" else 1]
    # Fasten the plate to the outer half of the jamb. Its overhang extends
    # away from the aperture, leaving the full measured 2 m opening clear.
    direction = lateral[0 if front == "north" else 1]
    display = sorted((point-mid)*direction for point in shop["frontage"]["display_clear_interval_m"])
    preferred = 1 if door < 0 else -1
    available = []
    for side in (preferred, -preferred):
        display_edge = display[0] if side == 1 else -display[1]
        edge = door*side + plan["front_frame_clear_m"]/2 + .015
        limit = min(half-.005, display_edge) if side*door < display_edge else half-.005
        width_available = min(.18, limit-edge)
        available.append((width_available, side, edge))
    width_available, side, edge = max(available, key=lambda candidate: candidate[0])
    if width_available < .08:
        raise ValueError(f"No unobstructed plaque receiver for {cell}")
    plaque = sorted((edge*side, (edge+width_available)*side))
    stocks.append(stock("plaque", plaque, (0., .028), (1.32, 1.58)))
    if compact:
        cloth = (-half+.16, half-.16)
        cloth_end = valance_depth-.03
        slope = (2.62-3.09)/(cloth_end-.16)
        stocks.extend([
            stock("awning", cloth, (.16, cloth_end), (3.09, 3.18), slope),
            stock("awn_val", cloth, (valance_depth-.06, valance_depth), (2.36, 2.65)),
        ])
        for role, x in zip(arms, (cloth[0]+.04, cloth[1]-.09)):
            bearing = 3.09-.16*slope
            stocks.append(stock(role, (x, x+.05), (0., cloth_end-.01), (bearing-.05, bearing), slope))
    if blade:
        height = marker_height+.30
        stocks.append(stock("blade", (blade_dx-.04, blade_dx+.04), (marker_depth+.01, marker_depth+1.03),
                            (height-.36, height+.36)))
        bracket = stock("bracket", (blade_dx-.06, blade_dx+.06), (.10, marker_depth+1.05),
                        (height+.36, height+.41))
        # One continuous return seats the raised bracket in the cornice.
        seat = [(0., 3.30), (.10, 3.30), (.10, height+.36),
                (marker_depth+1.05, height+.36), (marker_depth+1.05, height+.41), (0., height+.41)]
        bracket["vertices"] = [xy(a, d)+[h] for a in (blade_dx-.06, blade_dx+.06) for d,h in seat]
        bracket["faces"] = [tuple(range(6)), tuple(reversed(range(6,12)))] + [
            (i, i+6, (i+1)%6+6, (i+1)%6) for i in range(6)]
        stocks.append(bracket)
    u, v = xy(0., marker_depth)
    x, y, z = plan["source_origin_blender_m"]
    return stocks, dict(pos=[x+u, y-v, z+marker_height], yaw_deg=yaw,
                        half_width=half, blade_dx=blade_dx)


def build(layout, plan):
    floor, = [f for f in layout["floors"] if f["id"] == "F01"]
    stocks = [stock for shop in plan["shops"] for stock in storefront(shop, floor, plan)[0]]
    if Counter(s["role"] for s in stocks) != COUNTS or len({s["name"] for s in stocks}) != len(stocks):
        raise ValueError("Original arcade storefront identity roster changed")
    return stocks
