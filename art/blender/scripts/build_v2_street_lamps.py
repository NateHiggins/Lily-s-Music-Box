"""V2 street lamps: New York bishop's-crook posts with acorn pendants, 1928.

Design packet: design/V2_STREET_LAMPS_2026-10-24.md.

A street lamp carries power, not signal (Bible VIII.2), so it is the city's
ordinary cast-iron post, painted black, with a pendant acorn globe on the
crook. The plain posts use the reviewed alternate-universe gas mantle head;
the retained signal-box variant keeps its installed incandescent globe.
The exception rides on one post: a police signal box strapped to the shaft.
Boxes on lampposts are period; this one is Vantry-grade signal gear, with a
Bakelite face, a brass speaking grille, a lit standby lamp and
cloth-braided pair climbing the post.

Exports game/assets/props/v2_street_lamps.glb, one object per (stock,
finish), and writes game/data/orison_v2/exterior/street_lamps.json from the
same numbers. Post at the origin, crook reaching Blender -Y (the street side,
Godot +Z), ground at Z 0. Never hand-edit the outputs; rerun:

    blender -b -P art/blender/scripts/build_v2_street_lamps.py
"""
from pathlib import Path
import sys, json, math, hashlib, os, shutil
import bpy, bmesh
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).parent))
from fabrication_native_batch import material, partition, export
from check_exported_tangents import validate as validate_export
import build_v2_period_traffic as kit

FAMILY = "v2_street_lamps"
FINISHES = {
    "post_iron": {"catalog_key": "iron_blackened", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "cast_iron": {"catalog_key": "cast_iron", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "brass": {"catalog_key": "brass_dull", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "globe_lit": {"catalog_key": "milk_glass", "tint": [1, .94, .84, 1], "normal": .5, "roughness": 1., "emission": [1.0, 0.72, 0.42, 3.0]},
    "box_paint": {"catalog_key": "car_paint", "tint": [0.13, 0.20, 0.16, 1], "normal": .7, "roughness": .8},
    "bakelite": {"catalog_key": "bakelite_black", "tint": [1, 1, 1, 1], "normal": 1., "roughness": 1.},
    "standby_lamp": {"catalog_key": "milk_glass", "tint": [.7, .95, .75, 1], "normal": .5, "roughness": 1., "emission": [0.45, 0.95, 0.55, 1.2]},
    "silk_flex": {"catalog_key": "fabric_warm", "tint": [0.55, 0.13, 0.08, 1], "normal": 1., "roughness": 1.},
}
GAS_FINISHES = {
    "paint": ("gas_paint", "iron_blackened", .6),
    "bare_iron": ("gas_iron", "cast_iron", .6),
    "brass": ("gas_brass", "brass_dull", .4),
    "ceramic": ("gas_ceramic", "porcelain", .3),
    "mantle": ("gas_mantle", "porcelain", .25),
    "glass": ("gas_glass", "glass_drawn_expressive", .12),
}
for source, (alias, key, normal) in GAS_FINISHES.items():
    FINISHES[alias] = {"catalog_key": key, "tint": [1,1,1,1], "normal": normal, "roughness": 1.}
FINISHES["gas_paint"]["metallic"] = 0.
FINISHES["gas_glass"]["metallic"] = 0.
FINISHES["gas_mantle"]["emission"] = [1., .78, .48, 2.2]
for spec in FINISHES.values():
    spec.setdefault("pigment", 1.0)

REACH = 0.84          # crook reach over the gutter, metres
GLOBE_Z = 3.86        # centre of the acorn globe


def add(parts, finish, *objs):
    parts.setdefault(finish, []).extend(objs)


def fluted(z0, z1, r0, r1, n=16, depth=0.12, rows=8):
    """Tapered fluted shaft: alternate vertices sit back by `depth`."""
    import bmesh
    bm = bmesh.new()
    rings = []
    for k in range(rows + 1):
        t = k / rows
        z = z0 + (z1 - z0) * t
        r = r0 + (r1 - r0) * t
        rings.append([bm.verts.new((r * (1 - depth * (i % 2)) * math.cos(2 * math.pi * i / (2 * n)),
                r * (1 - depth * (i % 2)) * math.sin(2 * math.pi * i / (2 * n)), z)) for i in range(2 * n)])
    m = 2 * n
    for a, b in zip(rings, rings[1:]):
        for i in range(m):
            bm.faces.new((a[i], a[(i + 1) % m], b[(i + 1) % m], b[i]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    return kit._obj(bm, "fluted")


def bishops_crook():
    p = {}
    add(p, "post_iron", kit.lathe([(0, 0), (0.25, 0), (0.25, 0.06), (0.22, 0.09), (0.22, 0.15), (0.185, 0.2), (0.165, 0.46),
                                   (0.19, 0.5), (0.19, 0.57), (0.145, 0.63), (0.125, 0.92), (0.15, 0.96), (0.15, 1.02), (0.1, 1.06), (0, 1.06)], (0, 0, 0), "Z", 24))
    add(p, "post_iron", fluted(1.05, 3.66, 0.085, 0.062))
    add(p, "post_iron", kit.lathe([(0, 3.64), (0.085, 3.64), (0.095, 3.69), (0.08, 3.74), (0.06, 3.78), (0, 3.78)], (0, 0, 0), "Z", 18))
    add(p, "post_iron", kit.cyl((0, 0, 3.98), 0.05, 0.42, "Z", 14))
    # The crook: up, over the gutter and down to the hanger.
    cy, cz, r = -REACH / 2, 4.42, REACH / 2
    path = [(0, 0, 4.12)] + [(0, cy + r * math.cos(math.radians(a)), cz + r * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(0, -REACH, 4.30)]
    add(p, "post_iron", kit.tube(path, 0.034, 8))
    # A scroll filling the elbow, as on the city's cast pattern.
    scroll = []
    for i in range(30):
        t = i / 29 * 2.6 * math.pi
        rr = 0.13 * (1 - t / (3.2 * math.pi))
        scroll.append((0, -0.2 + rr * math.cos(t + math.pi / 2), 4.2 + rr * math.sin(t + math.pi / 2)))
    add(p, "post_iron", kit.tube(scroll, 0.013, 6), kit.tube([(0, -0.02, 4.02), (0, -0.2, 4.33)], 0.012, 6))
    add(p, "brass", kit.lathe([(0, 4.84), (0.05, 4.84), (0.03, 4.9), (0, 4.98)], (0, cy, 0), "Z", 10))
    # The acorn pendant: cast hood, brass band, milk globe with the lamp.
    add(p, "post_iron", kit.cyl((0, -REACH, 4.24), 0.016, 0.12, "Z", 8),
        kit.lathe([(0, 4.2), (0.05, 4.19), (0.13, 4.12), (0.2, 4.06), (0.205, 4.035), (0, 4.035)], (0, -REACH, 0), "Z", 20))
    add(p, "brass", kit.torus((0, -REACH, 4.03), 0.185, 0.013, "Z", 20, 5))
    add(p, "globe_lit", kit.lathe([(0, 4.03), (0.175, 4.03), (0.19, 3.94), (0.18, 3.82), (0.145, 3.7), (0.085, 3.62), (0.03, 3.585), (0, 3.58)], (0, -REACH, 0), "Z", 20))
    add(p, "post_iron", kit.lathe([(0.03, 3.585), (0.035, 3.56), (0.02, 3.53), (0, 3.52)], (0, -REACH, 0), "Z", 10))
    return p


def signal_box_crook():
    """The same post with a police signal box on the pavement side."""
    p = bishops_crook()
    y = 0.215
    add(p, "box_paint", kit.box((0, y, 1.62), (0.34, 0.22, 0.52), 0.02))
    add(p, "cast_iron", kit.prism([(-0.21, 1.88), (0.21, 1.88), (0.18, 1.95), (-0.18, 1.95)], y - 0.13, y + 0.14), kit.box((0, 0.11, 1.62), (0.12, 0.05, 0.4)))
    add(p, "cast_iron", *[kit.torus((0, 0, z), 0.093, 0.012, "Z", 16, 4) for z in (1.44, 1.8)])
    add(p, "bakelite", kit.box((0, y + 0.112, 1.6), (0.26, 0.012, 0.4), 0.004))
    add(p, "brass", *[kit.box((0, y + 0.12, 1.66 + 0.022 * i), (0.14, 0.006, 0.008)) for i in range(5)])
    add(p, "brass", kit.cyl((0.09, y + 0.12, 1.5), 0.016, 0.02, "Y", 10), kit.cyl((-0.09, y + 0.12, 1.5), 0.016, 0.02, "Y", 10))
    # Handset on its cradle at the side: Bakelite, two cups and a bar.
    add(p, "bakelite", kit.box((0.19, y, 1.66), (0.025, 0.06, 0.16)), kit.sphere((0.21, y, 1.75), 0.03), kit.sphere((0.21, y, 1.57), 0.03),
        kit.tube([(0.21, y, 1.75), (0.215, y, 1.57)], 0.014, 6))
    add(p, "standby_lamp", kit.lathe([(0.035, 0), (0.035, 0.02), (0.02, 0.05), (0, 0.055)], (0, y, 1.95), "Z", 12))
    add(p, "silk_flex", kit.tube([(0.04, 0.1, 1.9), (0.05, 0.085, 2.6), (0.045, 0.07, 3.6), (0.04, 0.05, 4.05)], 0.011, 5, False))
    return p


STOCKS = {"bishops_crook": bishops_crook, "signal_box_crook": signal_box_crook}

# Placement in the street frame (x along the street, +z outward from Orison).
# The first two stand where the authored placeholder posts stand and take over
# their authored lights; the new ones fill the far pavement and the west run.
LIGHT = {"color_rgb": [1.0, 0.70, 0.42], "energy": 2.6, "range_m": 10.5}
LAMPS = [
    {"id": "lamp_orison_mid", "stock": "bishops_crook", "at": [8.1, 0.0, 3.975], "yaw_degrees": 0,
     "replaces": ["street_lamp_post", "street_lamp_head", "street_lamp_cap_west"], "authored_light": "street_lamp_pool", "shadows": True},
    {"id": "lamp_orison_crossing", "stock": "signal_box_crook", "at": [13.3, 0.0, 3.975], "yaw_degrees": 0,
     "replaces": ["street_lamp_post_east", "street_lamp_head_east", "street_lamp_cap_east"], "authored_light": "street_lamp_pool_east", "shadows": True},
    {"id": "lamp_orison_west", "stock": "bishops_crook", "at": [-9.6, 0.0, 3.975], "yaw_degrees": 0,
     "replaces": [], "authored_light": "", "shadows": False},
    {"id": "lamp_arcade_west", "stock": "bishops_crook", "at": [-4.2, 0.0, 14.82], "yaw_degrees": 180,
     "replaces": [], "authored_light": "", "shadows": False},
]


def gas_stocks():
    """Bootstrap the reviewed delivery once; subsequent builds use our saved stocks."""
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    if "--gas-source" in args:
        path=Path(args[args.index("--gas-source")+1]).resolve()
        assert hashlib.sha256(path.read_bytes()).hexdigest()=="c371738e8fdb52f42af425ebfedbb9c0bc0bd2c4a7e8a351042152a0e4c5a8a4"
        collection_name="01_EDITABLE_Stocks"
    else:
        path=ROOT/"art/blender/v2_street_lamps.blend"
        collection_name="MunicipalGasStocks"
        # Blender keeps an append-source library record even for local IDs;
        # append from a scratch snapshot so saving the authoring file is legal.
        snapshot=ROOT/'tmp/native_exports'/f'gas_source_{os.getpid()}.blend'
        snapshot.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,snapshot);path=snapshot
    with bpy.data.libraries.load(str(path),link=False) as (available,loaded):
        assert collection_name in available.collections, "Gas manufacturing source missing; bootstrap reviewed donor with --gas-source"
        loaded.collections=[collection_name]
    collection=loaded.collections[0]
    collection.name="MunicipalGasStocks"
    bpy.context.scene.collection.children.link(collection)
    stocks=[o for o in collection.objects if o.type=="MESH"]
    assert len(stocks)==114
    for obj in stocks:
        if "gas_finish" not in obj:
            obj["gas_finish"]=GAS_FINISHES[obj.data.materials[0].name.split('.')[0]][0]
        assert obj["gas_finish"] in FINISHES
    return collection,stocks


def retained_signal(exports,mats):
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    path=Path(args[args.index("--signal-source")+1]).resolve() if "--signal-source" in args else ROOT/'art/blender/v2_street_lamps.blend'
    if path.resolve()==(ROOT/'art/blender/v2_street_lamps.blend').resolve():
        snapshot=ROOT/'tmp/native_exports'/f'signal_source_{os.getpid()}.blend'
        snapshot.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,snapshot);path=snapshot
    with bpy.data.libraries.load(str(path),link=False) as (available,loaded):
        loaded.objects=[name for name in available.objects if name.startswith('signal_box_crook__')]
    assert len(loaded.objects)==8
    for obj in loaded.objects:
        alias=obj.name.split('__')[-1]
        obj.data.materials.clear();obj.data.materials.append(mats[alias])
        exports.objects.link(obj)
    return sum(len(obj.data.polygons) for obj in loaded.objects)


def gas_partition(stocks, exports, mats, catalog, lower=False):
    groups={};temporary=[];rows=[]
    for original in stocks:
        obj=original.copy();obj.data=original.data.copy();kit.scratch.objects.link(obj)
        obj.name=("LOD1_" if lower else "Near_")+original.name
        obj.data.transform(obj.matrix_world);obj.matrix_world=Matrix.Identity(4)
        before=len(obj.data.polygons)
        if lower and before>64:
            obj.hide_set(False);bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new("Replacement body tessellation","DECIMATE")
            mod.ratio=max(.24,48/before);mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in bm.edges),obj.name
        bm.free()
        alias=str(original["gas_finish"])
        groups.setdefault(alias,[]).append(obj);temporary.append(obj)
        rows.append({"stock":original.name,"near_triangles":before,"triangles":len(obj.data.polygons),"closed":True})
    for alias,objects in sorted(groups.items()):
        stock="bishops_crook_lod1" if lower else "bishops_crook"
        partition(exports,stock+"__"+alias,objects,FINISHES[alias],mats[alias],Matrix.Identity(4),catalog)
    if not lower:
        for obj in temporary:bpy.data.objects.remove(obj,do_unlink=True)
    return rows


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    native_source,gas=gas_stocks()
    catalog = json.loads((ROOT / "game/data/runtime_material_sets.json").read_text())["materials"]
    kit.scratch = bpy.data.collections.new("EditableLampParts")
    bpy.context.scene.collection.children.link(kit.scratch)
    exports = bpy.data.collections.new("StreetLampExport")
    bpy.context.scene.collection.children.link(exports)
    lower=bpy.data.collections.new("StreetLampLOD1Export")
    bpy.context.scene.collection.children.link(lower)
    mats = {}
    for fid, spec in FINISHES.items():
        mats[fid] = material(ROOT, fid, spec, catalog)
        if "emission" in spec:
            node = mats[fid].node_tree.nodes["Principled BSDF"]
            node.inputs["Emission Color"].default_value = spec["emission"][:3] + [1.0]
            node.inputs["Emission Strength"].default_value = spec["emission"][3]
    # Preserve the reviewed signal equipment's actual native draw arrays.
    # Re-running its older sphere generator can reorder triangles at a pole.
    triangles = {"signal_box_crook":retained_signal(exports,mats)}
    high_rows=gas_partition(gas,exports,mats,catalog)
    low_rows=gas_partition(gas,lower,mats,catalog,lower=True)
    triangles["bishops_crook"]=sum(row["triangles"] for row in high_rows)
    for obj in gas:
        obj.data.materials.clear();obj.data.materials.append(mats[str(obj["gas_finish"])])
    native_source.hide_render=True;native_source.hide_viewport=True
    kit.scratch.hide_render = True
    kit.scratch.hide_viewport = True
    lower.hide_render=True
    bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=False,do_recursive=True)
    proof = export(ROOT, FAMILY, exports, material_names_only=True, staged_output=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in lower.objects:obj.select_set(True)
    low_path=ROOT/'game/assets/props/v2_street_lamps_lod1.glb'
    staged=ROOT/'tmp/native_exports'/f'v2_street_lamps_lod1_{os.getpid()}.glb'
    bpy.ops.export_scene.gltf(filepath=str(staged),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT')
    low_proof=validate_export(staged);os.replace(staged,low_path);low_proof['asset']=str(low_path)
    keys = ("catalog_key", "tint", "normal", "roughness", "emission", "metallic")
    table = {
        "schema": "orison.v2.street-lamps.v1",
        "frame": "ORISON_FRONT_DOOR_THRESHOLD",
        "street_instance": "STREET_ORISON_01",
        "stock": "res://assets/props/v2_street_lamps.glb",
        "lod_stock": "res://assets/props/v2_street_lamps_lod1.glb",
        "lod_error_m": .009252,
        "globe_local": [0.0, GLOBE_Z, REACH],
        "post_radius_m": 0.22,
        "light": LIGHT,
        # The city lights its lamps dusk to dawn; the same local clock minutes
        # as the traffic's lamps, so street and vehicles go dark together.
        "dusk": kit.SCHEDULE["dusk"],
        "dawn": kit.SCHEDULE["dawn"],
        "finishes": [dict({"id": fid}, **{k: v for k, v in spec.items() if k in keys}) for fid, spec in FINISHES.items()],
        "lamps": LAMPS,
    }
    (ROOT / "game/data/orison_v2/exterior/street_lamps.json").write_text(json.dumps(table, indent=1) + "\n", newline="\n")
    construction={"evidence_class":"INERT","source_stocks":high_rows,"lower_stocks":low_rows,"proof":proof,"lower_proof":low_proof,"limits":"Native export; loaded surfaces, optics, LOD transitions, rendering cost and artistic acceptance remain separate."}
    (ROOT/'art/blender/v2_street_lamps_construction.json').write_text(json.dumps(construction,indent=1)+'\n',encoding='utf8',newline='\n')
    print(json.dumps({"proof": proof, "lower_proof":low_proof,"triangles": triangles}))


if __name__ == "__main__":
    main()
