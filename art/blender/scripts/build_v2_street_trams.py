"""V2 street trams: 1929 double-truck streetcars under the trolley wire on the Orison's avenue.

Design packet: design/V2_STREET_TRAMS_2026-11-08.md. Lily's ruling trams_route (2026-11-08): the line runs down
the Orison's own avenue under the el (Queensboro Plaza, where Queens Boulevard begins), a car every few minutes
sharing the road with the period traffic, arcs seen from the street and the windows.

Exports game/assets/props/v2_street_trams.glb, one object per (stock, finish):
- tram_car: a closed double-truck car, about 13 m over the bumpers. Blender +X is forward (the period traffic
  convention), the ground is Z 0, and the trailing trolley pole is raised to the wire with its wheel at POLE_TIP.
- tram_span_pole: the tubular steel pole that carries a span wire, base at the origin.
- tram_rosette: the wall plate a span wire is anchored to on a facade, face toward Blender -Y.

Writes game/data/orison_v2/exterior/street_trams.json from the same numbers. The runtime
(orison_v2_street_trams.gd) registers the car as a rail vehicle with the period traffic and lays the rails and
wire along the very path the traffic gives it. Never hand-edit the outputs; rerun:

    blender -b -P art/blender/scripts/build_v2_street_trams.py
"""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export
import build_v2_period_traffic as kit
from build_v2_period_traffic import add, box, cyl, lathe, tube, prism, W

FAMILY = "v2_street_trams"
FINISHES = {
    # Coachwork takes the runtime per-car colour, as the traffic's does.
    "coachwork": {"catalog_key": "car_paint", "tint": [0.16, 0.25, 0.19, 1], "normal": .55, "roughness": .62, "paint": True},
    "cream": {"catalog_key": "car_paint", "tint": [0.80, 0.74, 0.58, 1], "normal": .5, "roughness": .7},
    "japan_black": {"catalog_key": "car_paint", "tint": [0.075, 0.072, 0.07, 1], "normal": .6, "roughness": .55},
    "running_iron": {"catalog_key": "iron_blackened", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "cast_iron": {"catalog_key": "cast_iron", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "nickel": {"catalog_key": "nickel_plated", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "brass": {"catalog_key": "brass_dull", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "roof_canvas": {"catalog_key": "fabric_warm", "tint": [0.23, 0.22, 0.20, 1], "normal": 1., "roughness": 1.},
    # Dark glass by day; at night the saloon lamps show through it (dimmed with the street's dusk and dawn rule).
    "window": {"catalog_key": "fabric_warm", "tint": [0.10, 0.085, 0.075, 1], "normal": .8, "roughness": 1., "emission": [1.0, 0.76, 0.46, 2.0]},
    "rope": {"catalog_key": "fabric_warm", "tint": [0.62, 0.57, 0.46, 1], "normal": 1., "roughness": 1.},
    "lamp_lit": {"catalog_key": "milk_glass", "tint": [1, .93, .80, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.80, 0.52, 2.2]},
    "saloon_lit": {"catalog_key": "milk_glass", "tint": [1, .90, .72, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.74, 0.44, 1.4]},
    "lamp_tail": {"catalog_key": "milk_glass", "tint": [.75, .16, .10, 1], "normal": .5, "roughness": 1., "emission": [0.85, 0.10, 0.05, 1.6]},
}
for spec in FINISHES.values():
    spec.setdefault("pigment", 1.0)

# ---------------------------------------------------------------- the car
LENGTH = 13.0           # over the bumpers
HALF = LENGTH / 2
WIDTH = 2.45
FLOOR = 1.05
SILL = 1.78
WINDOW_TOP = 2.58
EAVE = 2.86
ROOF_TOP = 3.42
TRUCK_X = 4.1
WHEEL_R = 0.33
WIRE_HEIGHT = 5.5       # contact wire over the rail head, about 18 ft, the New York practice
POLE_BASE = (-4.4, 0.0, ROOF_TOP + 0.08)
POLE_LENGTH = 4.6
_rise = WIRE_HEIGHT - POLE_BASE[2]
POLE_TIP = (round(POLE_BASE[0] - math.sqrt(POLE_LENGTH ** 2 - _rise ** 2), 3), 0.0, WIRE_HEIGHT)


def truck(p, x):
    """A Brill-pattern truck: side frames, bolster, four wheels on two axles."""
    for s in (1, -1):
        add(p, "japan_black", box((x, s * 0.86, 0.52), (2.3, 0.08, 0.28), 0.01), box((x, s * 0.86, 0.78), (1.1, 0.1, 0.14), 0.01))
        add(p, "running_iron", *[cyl((x + dx, s * 0.72, WHEEL_R), WHEEL_R, 0.09, "Y", 16) for dx in (-0.75, 0.75)])
        add(p, "running_iron", box((x, s * 0.86, 0.36), (0.5, 0.14, 0.16), 0.02))
    add(p, "running_iron", *[cyl((x + dx, 0, WHEEL_R), 0.06, 1.52, "Y", 8) for dx in (-0.75, 0.75)])
    add(p, "japan_black", box((x, 0, 0.86), (0.36, 1.7, 0.14), 0.01))


def tram_car():
    """Closed double-truck car of a Queens line, about 1915-1925: green dash and side panels, cream window posts and
    letter board, a monitor roof with deck lights, a vestibule at each end."""
    p = {}
    body = HALF - 0.75
    # Underframe, side panels and the cream belt.
    add(p, "japan_black", box((0, 0, FLOOR - 0.12), (LENGTH - 0.9, WIDTH - 0.1, 0.2), 0.01))
    add(p, "coachwork", box((0, 0, (FLOOR + SILL) / 2), (2 * body, WIDTH, SILL - FLOOR), 0.02))
    add(p, "cream", box((0, 0, SILL + 0.03), (2 * body + 0.02, WIDTH + 0.02, 0.06), 0.01))
    # Window band: cream posts between dark glass, eight bays a side.
    bays = 8
    pitch = 2 * body / bays
    for s in (1, -1):
        for i in range(bays):
            cx = -body + pitch * (i + 0.5)
            add(p, "window", box((cx, s * (WIDTH / 2 - 0.02), (SILL + WINDOW_TOP) / 2 + 0.03), (pitch - 0.16, 0.02, WINDOW_TOP - SILL - 0.06)))
        for i in range(bays + 1):
            add(p, "cream", box((-body + pitch * i, s * (WIDTH / 2), (SILL + WINDOW_TOP) / 2 + 0.03), (0.14, 0.05, WINDOW_TOP - SILL)))
        add(p, "cream", box((0, s * WIDTH / 2, (WINDOW_TOP + EAVE) / 2 + 0.03), (2 * body, 0.04, EAVE - WINDOW_TOP)))
        add(p, "brass", tube([(-body + 0.3, s * (WIDTH / 2 + 0.03), SILL + 0.35), (body - 0.3, s * (WIDTH / 2 + 0.03), SILL + 0.35)], 0.012, 5))
    # Inside, seen through the glass at night: the saloon ceiling glows.
    add(p, "saloon_lit", box((0, 0, EAVE - 0.06), (2 * body - 0.4, WIDTH - 0.4, 0.02)))
    # Vestibules, narrowed toward the bumpers, with the windscreen and dash.
    for e in (1, -1):
        x0, x1 = e * body, e * (HALF - 0.12)
        mid = (x0 + x1) / 2
        add(p, "coachwork", box((mid, 0, (FLOOR + SILL) / 2), (abs(x1 - x0), WIDTH - 0.28, SILL - FLOOR), 0.03))
        add(p, "window", box((mid + e * 0.2, 0, (SILL + WINDOW_TOP) / 2 + 0.03), (0.04, WIDTH - 0.6, WINDOW_TOP - SILL - 0.1)))
        for s in (1, -1):
            add(p, "cream", box((mid, s * (WIDTH / 2 - 0.16), (SILL + WINDOW_TOP) / 2 + 0.03), (abs(x1 - x0), 0.08, WINDOW_TOP - SILL)))
        add(p, "cream", box((mid, 0, (WINDOW_TOP + EAVE) / 2 + 0.03), (abs(x1 - x0), WIDTH - 0.28, EAVE - WINDOW_TOP)))
        # Dash: headlamp at the leading end, a red tail lamp at the trailing one, and the bumper.
        lamp_x = e * (HALF - 0.1)
        if e > 0:
            add(p, "nickel", lathe([(0, -0.12), (0.09, -0.12), (0.13, -0.04), (0.14, 0)], (lamp_x, 0, 1.42), "X", 14))
            add(p, "lamp_lit", lathe([(0.13, 0.0), (0.08, 0.02), (0, 0.025)], (lamp_x, 0, 1.42), "X", 14))
            # Destination sign over the windscreen (lettered in the runtime, never in the texture).
            add(p, "saloon_lit", box((lamp_x - 0.12, 0, EAVE - 0.08), (0.04, 1.2, 0.2)))
            # Lifeguard tray under the front platform.
            add(p, "running_iron", box((e * (HALF + 0.05), 0, 0.22), (0.5, WIDTH - 0.5, 0.04), 0.01))
        else:
            add(p, "lamp_tail", box((lamp_x, 0.6, 1.3), (0.03, 0.09, 0.09)))
        add(p, "japan_black", box((e * (HALF - 0.04), 0, FLOOR - 0.05), (0.08, WIDTH - 0.5, 0.16), 0.01))
        # Step and grab rails at the doors.
        for s in (1, -1):
            add(p, "running_iron", box((mid, s * (WIDTH / 2 - 0.08), 0.62), (0.7, 0.3, 0.04)))
            add(p, "brass", tube([(mid - e * 0.25, s * (WIDTH / 2 - 0.12), FLOOR), (mid - e * 0.25, s * (WIDTH / 2 - 0.12), SILL + 0.6)], 0.014, 6))
    # Monitor roof: the arched lower roof, the raised deck with its lit deck lights, and the running board.
    add(p, "roof_canvas", prism([(-HALF + 0.15, EAVE), (HALF - 0.15, EAVE), (HALF - 0.15, EAVE + 0.04), (-HALF + 0.15, EAVE + 0.04)],
                                -WIDTH / 2 - 0.04, WIDTH / 2 + 0.04, 0.02))
    add(p, "roof_canvas", box((0, 0, EAVE + 0.16), (LENGTH - 0.6, WIDTH - 0.3, 0.24), 0.06))
    add(p, "cream", box((0, 0, (EAVE + 0.28 + ROOF_TOP - 0.1) / 2), (2 * body - 0.6, 1.3, ROOF_TOP - 0.1 - EAVE - 0.28)))
    for s in (1, -1):
        add(p, "saloon_lit", *[box((-body + 0.6 + 1.0 * i, s * 0.651, EAVE + 0.38), (0.6, 0.01, 0.12)) for i in range(int(2 * body - 1.0))])
    add(p, "roof_canvas", box((0, 0, ROOF_TOP - 0.05), (2 * body - 0.4, 1.5, 0.1), 0.03))
    add(p, "japan_black", box((0, 0, ROOF_TOP + 0.02), (2 * body - 1.0, 0.36, 0.04)))
    truck(p, TRUCK_X)
    truck(p, -TRUCK_X)
    # Trolley poles. The trailing one is up on the wire; the leading one is down on its roof hook.
    bx, by, bz = POLE_BASE
    add(p, "japan_black", box((bx, 0, bz - 0.04), (0.5, 0.4, 0.1), 0.01), cyl((bx, 0, bz + 0.05), 0.09, 0.12, "Z", 12))
    add(p, "japan_black", tube([POLE_BASE, POLE_TIP], 0.035, 8))
    tx, ty, tz = POLE_TIP
    add(p, "brass", box((tx, 0, tz - 0.05), (0.12, 0.1, 0.08)), cyl((tx, 0, tz - 0.01), 0.055, 0.03, "Y", 12))
    add(p, "rope", tube([(tx + 0.1, 0, tz - 0.08), (-HALF + 0.3, 0, (tz + SILL) / 2 + 0.4), (-HALF + 0.05, 0, SILL + 0.15)], 0.01, 5))
    add(p, "japan_black", box((-bx, 0, bz - 0.04), (0.5, 0.4, 0.1), 0.01), tube([(-bx, 0, bz + 0.05), (HALF + 0.55, 0, bz - 0.12)], 0.035, 8))
    add(p, "japan_black", box((HALF - 0.6, 0, ROOF_TOP - 0.02), (0.08, 0.3, 0.14)))
    return p


# ---------------------------------------------------------------- overhead line
POLE_HEIGHT = 7.4
SPAN_EYE_Z = 6.35       # where the span wire is shackled to the pole
ROSETTE_REACH = 0.09    # the rosette's eye stands this far off the wall


def tram_span_pole():
    """Tubular steel trolley pole: a cast base and collar, three tapering tubes, a ball finial."""
    p = {}
    add(p, "cast_iron", lathe([(0, 0), (0.26, 0), (0.26, 0.05), (0.21, 0.1), (0.2, 0.55), (0.24, 0.62), (0.18, 0.72), (0.15, 1.15), (0, 1.15)], (0, 0, 0), "Z", 18))
    add(p, "japan_black", cyl((0, 0, 2.6), 0.115, 2.9, "Z", 14), cyl((0, 0, 4.9), 0.1, 1.8, "Z", 14), cyl((0, 0, 6.6), 0.085, 1.65, "Z", 14))
    add(p, "cast_iron", lathe([(0, 4.03), (0.14, 4.03), (0.14, 4.1), (0, 4.1)], (0, 0, 0), "Z", 14),
        lathe([(0, 5.78), (0.12, 5.78), (0.12, 5.84), (0, 5.84)], (0, 0, 0), "Z", 14))
    add(p, "cast_iron", lathe([(0, SPAN_EYE_Z - 0.06), (0.12, SPAN_EYE_Z - 0.06), (0.12, SPAN_EYE_Z + 0.06), (0, SPAN_EYE_Z + 0.06)], (0, 0, 0), "Z", 12))
    add(p, "cast_iron", lathe([(0, POLE_HEIGHT - 0.03), (0.06, POLE_HEIGHT), (0.11, POLE_HEIGHT + 0.11), (0.06, POLE_HEIGHT + 0.22), (0, POLE_HEIGHT + 0.24)], (0, 0, 0), "Z", 14))
    return p


def tram_rosette():
    """Span-wire rosette bolted to a facade: a cast plate and an eye bolt."""
    p = {}
    add(p, "cast_iron", lathe([(0, 0), (0.15, 0), (0.15, -0.025), (0.09, -0.05), (0.04, -0.06), (0, -0.06)], (0, 0, 0), "Y", 16))
    add(p, "running_iron", cyl((0, -0.075, 0), 0.016, 0.06, "Y", 8),
        kit.torus((0, -ROSETTE_REACH, 0), 0.03, 0.009, "X", 14, 6))
    # The plate's back sits on the wall at Y 0; the plate and the eye stand out toward -Y, the street.
    return p


STOCKS = {"tram_car": tram_car, "tram_span_pole": tram_span_pole, "tram_rosette": tram_rosette}

# ---------------------------------------------------------------- the line, for the runtime
# The car as a period-traffic rail kind (the traffic's kind record, read by OrisonV2StreetTraffic).
KIND = {"id": "tram", "stock": "tram_car", "speed": [4.5, 6.0],
        "paint": [[0.16, 0.25, 0.19], [0.17, 0.27, 0.20], [0.15, 0.24, 0.18]],
        "extent": [-HALF, HALF], "width": WIDTH, "wheels": [], "horse": None,
        # Motorman at the front platform; passengers at the windows.
        "figures": [W(HALF - 0.75, 0.45, 1.6)] + [W(-4.2 + 1.55 * i, (-1) ** i * 0.72, 1.55) for i in range(6)],
        "voice": "heavy", "class": "tram", "signal_arm": []}
CLASS = {"id": "tram", "acceleration": 0.55, "service_brake": 1.25, "panic_brake": 2.8, "reaction": 0.8,
         "warning": "traffic.foot_gong", "brake": "traffic.brake_shriek"}
# Headway in minutes, each way, by local hour. 1929 Queens surface lines ran owl cars through the night.
HEADWAY = [20, 30, 30, 30, 30, 15, 8, 5, 4, 5, 6, 6, 6, 6, 6, 6, 5, 4, 4, 5, 7, 8, 10, 15]
# The overhead: support stations along the avenue (street-frame x). At each, a span wire runs from the far-kerb
# pole across both contact wires to a pole on the near kerb or, where the Orison's door, lamps and the crossing
# route leave no room, to a rosette on the Orison's own brick.
FAR_KERB_Z = 14.62
NEAR_KERB_Z = 3.975
SUPPORTS = [
    {"x": -58.0, "near": "pole"}, {"x": -33.0, "near": "pole"}, {"x": -3.0, "near": "rosette"},
    {"x": 31.0, "near": "pole"}, {"x": 57.0, "near": "pole"},
]
ORISON_FACADE_Z = 0.05  # the street face of the Orison at the door, where its rosette is bolted
CROSS = {"reach_m": 60.0, "support_pitch_m": 26.0, "kerb_offset_m": 4.95}
LINE = {"gauge_m": 1.435, "rail_head_m": 0.07, "rail_top_above_road_m": 0.006, "wire_height_m": WIRE_HEIGHT,
        "wire_radius_m": 0.0065, "span_radius_m": 0.005, "sample_m": 1.0,
        "pole_tip": W(*POLE_TIP), "pole_height_m": POLE_HEIGHT, "span_eye_z_m": SPAN_EYE_Z, "rosette_reach_m": ROSETTE_REACH,
        "pole_radius_m": 0.16}
# pole_tip is in the runtime's frame (Godot axes), like the traffic's figure seats.
# Arcs: blue-violet flashes where the trolley wheel meets the wire. More on aurora and STEVE nights
# (Lily's sun_storms ruling, 2026-11-04), and at the frogs where the tracks cross.
ARCS = {"per_minute": 1.6, "aurora_multiplier": 6.0, "aurora_phenomena": ["aurora", "steve"], "wet_multiplier": 2.0,
        "colour": [0.48, 0.36, 1.0], "energy": 3.2, "range_m": 9.0, "seconds": [0.05, 0.14], "reduced_energy": 0.6}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]
    kit.scratch = bpy.data.collections.new("EditableTramParts")
    bpy.context.scene.collection.children.link(kit.scratch)
    exports = bpy.data.collections.new("StreetTramExport")
    bpy.context.scene.collection.children.link(exports)
    mats = {}
    for fid, spec in FINISHES.items():
        mats[fid] = material(ROOT, fid, spec, catalog)
        if "emission" in spec:
            node = mats[fid].node_tree.nodes["Principled BSDF"]
            node.inputs["Emission Color"].default_value = spec["emission"][:3] + [1.0]
            node.inputs["Emission Strength"].default_value = spec["emission"][3]
    for fid, spec in FINISHES.items():
        # As the traffic recipe: paint divides out its albedo map's own mean, measured here.
        image = bpy.data.images.load(str(ROOT / "game/assets/building/textures" / catalog[spec["catalog_key"]]["files"][0]), check_existing=True)
        px = list(image.pixels[:])
        step = max(4, (len(px) // 4 // 4096) * 4)
        samples = [px[i:i + 3] for i in range(0, len(px) - 3, step)]
        spec["albedo_mean"] = [round(sum(c[k] for c in samples) / len(samples), 4) for k in range(3)]
    triangles = {}
    for name, build in STOCKS.items():
        parts = build()
        triangles[name] = 0
        for fid, objs in parts.items():
            assert fid in FINISHES, (name, fid)
            obj = partition(exports, f"{name}__{fid}", objs, FINISHES[fid], mats[fid], Matrix.Identity(4), catalog)
            triangles[name] += len(obj.data.polygons)
    kit.scratch.hide_render = True
    kit.scratch.hide_viewport = True
    proof = export(ROOT, FAMILY, exports, material_names_only=True, staged_output=True)
    runtime_finish_keys = ("catalog_key", "tint", "normal", "roughness", "paint", "emission", "albedo_mean")
    table = {
        "schema": "orison.v2.street-trams.v1",
        "frame": "ORISON_FRONT_DOOR_THRESHOLD",
        "stock": "res://assets/props/v2_street_trams.glb",
        "finishes": [dict({"id": fid}, **{k: v for k, v in spec.items() if k in runtime_finish_keys}) for fid, spec in FINISHES.items()],
        "kind": KIND,
        "class": CLASS,
        "headway_minutes": HEADWAY,
        "line": LINE,
        "supports": SUPPORTS,
        "far_kerb_z": FAR_KERB_Z,
        "near_kerb_z": NEAR_KERB_Z,
        "orison_facade_z": ORISON_FACADE_Z,
        "cross": CROSS,
        "arcs": ARCS,
    }
    (ROOT / "game/data/orison_v2/exterior/street_trams.json").write_text(json.dumps(table, indent=1) + "\n", newline="\n")
    manifest = {
        "evidence_class": "INERT",
        "source": "art/blender/scripts/build_v2_street_trams.py",
        "design": "design/V2_STREET_TRAMS_2026-11-08.md",
        "runtime_table": "game/data/orison_v2/exterior/street_trams.json",
        "export_proof": {k: v for k, v in proof.items() if k != "asset"},
        "triangles": triangles,
        "period": "Closed double-truck car of the New York & Queens County Railway / Manhattan & Queens lines, "
                  "Queensboro Plaza, 1929. Single trolley pole, owl service through the night.",
    }
    (ROOT / "art/data/v2_street_trams_manifest.json").write_text(json.dumps(manifest, indent=1) + "\n", newline="\n")
    print(json.dumps({"proof": proof, "triangles": triangles}))


if __name__ == "__main__":
    main()
