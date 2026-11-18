"""Build the original eight cage-light supports for the expanded arcade roof."""
from pathlib import Path
import argparse
import json
import math
import shutil
import sys

ROOT = next(path for path in Path(__file__).resolve().parents if (path / "game/project.godot").is_file())
SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
from arcade_roof_geometry import stocks as roof_stocks

LAYOUT = "game/data/building_layout.json"
PLAN = "art/data/arcade_plaza/source_plan.json"
ROOF = "art/data/arcade_plaza/roof_plan.json"
CATALOG = "game/data/runtime_material_sets.json"
SHELL = "game/assets/props/arcade_plaza_shells.glb"
FAMILY = "arcade_aisle_pendants"
SIDES = 16


def plan_supports(layout, plan, roof):
    floor, = [floor for floor in layout["floors"] if floor["id"] == "F01"]
    original = {row["id"]: row for row in floor["furniture"] if row.get("batch") == "passage_shell"}
    fixtures = {row["id"]: row for row in floor["markers"] if row["id"].startswith("PASSAGE_AISLE_LT_")}
    if len(fixtures) != 8:
        raise ValueError("Expected the eight original arcade cage lights")
    roof_parts = roof_stocks(plan, roof)
    ox, oy, oz = plan["source_origin_blender_m"]
    contacts = []
    for index in range(8):
        suffix = f"{index:02d}"
        fixture = fixtures["PASSAGE_AISLE_LT_" + suffix]
        stem = original["site_aisle_pendant_" + suffix]
        cap = original["site_passage_aisle_pendant_canopy_" + suffix]
        x, y, height = fixture["pos"]
        if (fixture["kind"] != "cage_bulb" or fixture["zone"] != "PASSAGE"
                or stem["mat"] != "cast_iron" or cap["mat"] != "brass_dull"
                or stem["r"] != .02 or any(point[:2] != [x, y] for point in (stem["p0"], stem["p1"]))
                or abs((cap["rect"][0] + cap["rect"][2]) / 2 - x) > 1e-9
                or abs((cap["rect"][1] + cap["rect"][3]) / 2 - y) > 1e-9
                or abs(cap["z0"] + cap["h"] - stem["p1"][2]) > 1e-9):
            raise ValueError("Original suspension profile or actor changed: " + suffix)
        # The last old position is inside the new rear shop. Seat it in the
        # cross aisle and retain its original circuit, height and light profile.
        y = -60.4 if index == 7 else y
        u, v, radius = x - ox, oy - y, stem["r"]
        family = "Court_" if index < 2 else "Nave_"
        candidates = []
        for part in roof_parts:
            if part["role"] != "roof_purlin" or not part["name"].startswith(family):
                continue
            low = [min(point[axis] for point in part["vertices"]) for axis in range(3)]
            high = [max(point[axis] for point in part["vertices"]) for axis in range(3)]
            if all(lo + radius <= point <= hi - radius for lo, hi, point in zip(low[:2], high[:2], [u, v])):
                candidates.append((part["name"], low[2] + oz))
        if len(candidates) != 1:
            raise ValueError("No unique full-footprint roof receiver: " + suffix)
        receiver, top = candidates[0]
        if not top > height + cap["h"]:
            raise ValueError("Suspension has no room below the receiver: " + suffix)
        contacts.append(dict(fixture_id=fixture["id"], original_position=fixture["pos"], position=[x, y, height],
                             stem_id=stem["id"], cap_id=cap["id"], radius=radius, cap_thickness=cap["h"],
                             cap_half_width=(cap["rect"][2] - cap["rect"][0]) / 2,
                             cap_half_depth=(cap["rect"][3] - cap["rect"][1]) / 2,
                             receiver=receiver, receiver_height=top))
    return contacts


def rings(x, y, low, high, profile):
    count = len(profile)
    vertices = [(x + a, y + b, z) for z in (low, high) for a, b in profile]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, j + count, i + count))
    return vertices, faces


def main():
    import bpy
    import bmesh
    from mathutils import Matrix
    from fabrication_native_batch import export, material, partition
    from build_arcade_plaza import digest

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    out = args.out.absolute()
    if out.resolve().is_relative_to(ROOT.resolve()) or (out.exists() and any(out.iterdir())):
        raise ValueError("Use an empty private output directory")
    for folder in ("art/blender", "game/assets/props", "game/assets/building/textures", "game/data/orison_v2"):
        (out / folder).mkdir(parents=True, exist_ok=True)
    layout, plan, roof, catalog = [json.loads((ROOT / path).read_text(encoding="utf-8"))
                                   for path in (LAYOUT, PLAN, ROOF, CATALOG)]
    catalog = catalog["materials"]
    contacts = plan_supports(layout, plan, roof)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    editable = bpy.data.collections.new("Individual aisle suspension stocks")
    draws = bpy.data.collections.new("Roof-mounted hardware")
    scene.collection.children.link(editable)
    scene.collection.children.link(draws)
    recipes = {key: dict(catalog_key=key, tint=[1, 1, 1, 1], normal=.18, pigment=1.,
                         roughness=catalog[key].get("roughness_multiplier", 1.))
               for key in ("cast_iron", "brass_dull")}
    materials = {key: material(ROOT, key, recipe, catalog) for key, recipe in recipes.items()}
    parts = []
    for row in contacts:
        x, y, low = row["position"]
        a, b = row["cap_half_width"], row["cap_half_depth"]
        middle = low + row["cap_thickness"]
        polygon = [(-a, -b), (a, -b), (a, b), (-a, b)]
        circle = [(row["radius"] * math.cos(math.tau * i / SIDES),
                   row["radius"] * math.sin(math.tau * i / SIDES)) for i in range(SIDES)]
        for identity, key, bottoms, profile in (
            (row["cap_id"], "brass_dull", (low, middle), polygon),
            (row["stem_id"], "cast_iron", (middle, row["receiver_height"]), circle),
        ):
            points, faces = rings(x, y, *bottoms, profile)
            mesh = bpy.data.meshes.new(identity)
            mesh.from_pydata(points, [], faces)
            mesh.update()
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            if not all(edge.is_manifold for edge in bm.edges) or bm.calc_volume(signed=True) <= 0:
                raise ValueError("Nonmanifold or inverted stock " + identity)
            bm.to_mesh(mesh)
            bm.free()
            obj = bpy.data.objects.new(identity + "__editable", mesh)
            editable.objects.link(obj)
            draw = partition(draws, identity, [obj], recipes[key], materials[key], Matrix.Identity(4), catalog)
            parts.append(dict(name=identity, material=key, triangles=len(draw.data.polygons)))
    for image in bpy.data.images:
        if image.source == "FILE":
            dest = out / "game/assets/building/textures" / Path(image.filepath).name
            shutil.copyfile(bpy.path.abspath(image.filepath), dest)
            image.filepath = str(dest)
    editable.hide_render = True
    editable.hide_viewport = True
    scene.view_layers[0].update()
    result = export(out, FAMILY, draws, material_names_only=True)
    if result["status"] != "PASS" or result["triangles"] != sum(row["triangles"] for row in parts):
        raise ValueError("Incomplete native hardware export")
    data = dict(schema="orison.v2.arcade-pendants.v1",
                asset_sha256=digest(out / f"game/assets/props/{FAMILY}.glb"),
                shell_sha256=digest(ROOT / SHELL), fabrication_sha256_lf=digest(ROOT / LAYOUT),
                parts=parts, fixtures=[{"id": row["fixture_id"], "pos": row["position"]} for row in contacts])
    bindings = [ROOT / path for path in (LAYOUT, PLAN, ROOF, CATALOG, SHELL)]
    bindings += [SCRIPTS / name for name in (
        "build_arcade_aisle_pendants.py", "build_arcade_plaza.py", "arcade_roof_geometry.py",
        "fabrication_native_batch.py", "fabrication_chart_batch.py", "fabrication_uvs.py",
        "fabrication_normals.py", "fabrication_grain.py", "check_exported_tangents.py")]
    bindings += [ROOT / "game/assets/building/textures" / name
                 for key in recipes for name in catalog[key]["files"]]
    proof = dict(evidence_class="INERT", contacts=contacts, native=result, runtime=data,
                 blend_sha256=digest(out / f"art/blender/{FAMILY}.blend"),
                 source_bindings={path.relative_to(ROOT.resolve()).as_posix(): digest(path)
                                  for path in (path.resolve() for path in bindings)})
    (out / "PENDANTS_NATIVE.json").write_text(json.dumps(proof, indent=2) + "\n", encoding="utf-8", newline="\n")
    (out / f"game/data/orison_v2/{FAMILY}.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("ARCADE PENDANTS EXPORT PASS", len(parts), "stocks", result["triangles"], "triangles")


if __name__ == "__main__":
    main()
