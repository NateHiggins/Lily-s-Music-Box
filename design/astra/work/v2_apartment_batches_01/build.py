"""Apartment category passes. Pure source extraction; no Blender/Godot launch.

Default validates and writes the work receipt. --apply installs only additions.
"""
import argparse
import ast
import hashlib
import json
import math
from pathlib import Path
import re
import zlib

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PI = math.pi
SOURCE = "art/blender/scripts/build_orison.py"
# identity, room, building-local floor position, yaw, standing position.
FURNITURE = [
    ("2A_wc", "F02_A_BATH", [-6.94,0,5.16], 0, [-7.0,0,4.35]),
    ("2B_wc", "F02_B_BATH", [15,0,-11.8], PI, [15,0,-10.8]),
    ("2A_bed0", "F02_A_BED", [-13.7,0,9.95], 0, [-12.35,0,9.95]),
    ("2B_abed", "F02_B_BED", [10.65,0,-10.95], PI, [11.9,0,-10.95]),
    ("2A_bed0_ns", "F02_A_BED", [-12.55,0,10.7], 0, [-12.55,0,9.95]),
    ("2A_w0_wardrobe", "F02_A_BED", [-11.3,0,11.0], 0, [-11.3,0,9.65]),
    ("2B_aw_wardrobe", "F02_B_BED", [9.98,0,-9.15], -PI/2, [11.5,0,-9.15]),
    ("2A_shelf0", "F02_A_MAIN", [-15.25,0,-1.7], -PI/2, [-14.35,0,-1.7]),
    ("2A_shelf1", "F02_A_MAIN", [-15.25,0,0], -PI/2, [-14.35,0,0]),
    ("2A_shelf2", "F02_A_MAIN", [-15.25,0,1.7], -PI/2, [-14.35,0,1.7]),
    ("2A_sink_support", "F02_A_KITCHEN", [-14.7,0,5.72], 0, [-14.7,0,4.55]),
    ("2B_sink_support", "F02_B_KITCHEN", [9.96,0,-7.3], -PI/2, [11.1,0,-7.3]),
]
# Existing production marker identity, room, placement, yaw, stance.
FITTINGS = [
    ("F02_2A_SINK_01", "F02_A_BATH", [-7.85,0,3.47], PI, [-7.85,0,4.3]),
    ("F02_2B_SINK_01", "F02_B_BATH", [15.32,0,-10.05], PI/2, [14.4,0,-10.05]),
    ("F02_2A_KITCHEN_SINK_01", "F02_A_KITCHEN", [-14.7,0,5.72], 0, [-14.7,0,4.55]),
    ("F02_2B_KITCHEN_SINK_01", "F02_B_KITCHEN", [9.96,0,-7.3], -PI/2, [11.1,0,-7.3]),
    ("F02_2A_SHOWER_01", "F02_A_BATH", [-6.94,0,3.57], PI, [-7.0,0,4.35]),
    ("F02_2B_SHOWER_01", "F02_B_BATH", [13.35,0,-11.88], PI, [13.35,0,-10.8]),
    ("F02_2A_STOVE_01", "F02_A_KITCHEN", [-12.8,0,5.72], 0, [-12.8,0,4.55]),
    ("F02_2B_STOVE_01", "F02_B_KITCHEN", [9.96,0,-5.9], -PI/2, [11.1,0,-5.9]),
    ("F02_2B_FRIDGE_01", "F02_B_KITCHEN", [10.9,0,-4.75], 0, [10.9,0,-5.85]),
]
METHODS = {"__init__", "add_quad", "add_hex", "add_lathe", "add_tube", "add_tbox"}


def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def extractors():
    tree = ast.parse((ROOT / SOURCE).read_text(encoding="utf-8"))
    selected = []
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name == "MeshBuf":
            node.body = [m for m in node.body if isinstance(m, ast.FunctionDef) and m.name in METHODS]
            selected.append(node)
        elif isinstance(node, ast.ClassDef) and node.name == "Frame": selected.append(node)
        elif isinstance(node, ast.FunctionDef) and node.name in {
            "asm_toilet", "asm_bed", "asm_nightstand", "asm_wardrobe", "asm_shelf",
            "case_wood", "hash_str", "_jit"}: selected.append(node)
    namespace = {"math": math, "zlib": zlib}
    exec(compile(ast.Module(body=selected, type_ignores=[]), SOURCE, "exec"), namespace)
    return namespace


def convert(v):
    return [v[0], v[2], -v[1]]


def furniture_record(identity, source_records, ns):
    buffers = {}
    hull = ns["MeshBuf"]("hull", None)
    def get_buf(material):
        if material not in buffers: buffers[material] = ns["MeshBuf"](material, None)
        return buffers[material]
    frame = ns["Frame"](get_buf, lambda: hull, 0, 0, 0, 0)
    boxes = []
    if identity.endswith("_sink_support"):
        # New open steel stand, supporting the full-width sink and drainboard.
        # No copied countertop or slab across the bowl. Coordinates are Godot-local.
        for x in [-.335, .775]:
            for z in [-.215, .215]: boxes.append(([x-.025,0,z-.025], [x+.025,.75,z+.025]))
        for z in [-.215, .215]: boxes.append(([-.36,.65,z-.025], [.80,.75,z+.025]))
        for x in [-.335, .775]: boxes.append(([x-.025,.65,-.24], [x+.025,.75,.24]))
        for low, high in boxes:
            frame.box("metal", low[0], -high[2], low[1], high[0], -low[2], high[1])
        spec = {"asm": "counter"}
    else:
        spec = source_records[identity]
        ns["asm_" + spec["asm"]](frame, spec)
    surfaces, all_vertices = [], []
    for material, buf in buffers.items():
        if material == "fx_shadow": continue
        converted = [convert(v) for v in buf.verts]
        all_vertices += converted
        vertices, normals = [], []
        for face in buf.faces:
            for i in range(1, len(face)-1):
                a,b,c = [converted[j] for j in (face[0],face[i],face[i+1])]
                u,v = [[p[j]-a[j] for j in range(3)] for p in (b,c)]
                n = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                length = math.sqrt(sum(x*x for x in n))
                if length < 1e-12: continue
                n = [x/length for x in n]
                for vertex in (a,c,b): vertices += vertex; normals += n
        surfaces.append(dict(material=material,vertices=vertices,normals=normals))
    all_vertices += [convert(v) for v in hull.verts]
    bounds = [[min(v[i] for v in all_vertices) for i in range(3)],
              [max(v[i] for v in all_vertices) for i in range(3)]]
    record = dict(id=identity,kind=spec["asm"],bounds=bounds,surfaces=surfaces)
    if spec["asm"] == "toilet": record["bounds"] = [[-.27,0,-.4],[.27,.84,.36]]
    if spec["asm"] == "wardrobe":
        record["bounds"] = [[-.71,-.03,-.37],[.71,1.99,.37]]  # shared mechanism's hull
        record["mechanism"] = dict(id=identity,asm="wardrobe",W=spec["W"],case_wood=ns["case_wood"](spec))
    if boxes: record["collision_boxes"] = boxes
    return json.loads(json.dumps(record))


def fitting_record(identity, markers):
    marker = markers[identity]
    kind = marker["kind"]
    if kind in ["sink", "shower"]:
        properties = {"fixture": marker["fixture"]}
        if marker["fixture"] == "kitchen_sink":
            properties.update(drain_side=marker.get("drain_side",1),
                              compact_kitchen=marker.get("compact",False),
                              has_drainboard=marker.get("drainboard",True))
    elif kind == "stove": properties = {"ambient_lit": marker.get("ambient_lit",False)}
    else: properties = {"monitor_top": marker.get("monitor",False)}
    return dict(id=identity,kind=kind,unit=marker["unit"],properties=properties)


def world_rect(bounds, placement):
    _,_,position,yaw,_ = placement
    points = [(position[0]+x*math.cos(yaw)+z*math.sin(yaw),
               position[2]-x*math.sin(yaw)+z*math.cos(yaw))
              for x in [bounds[0][0],bounds[1][0]] for z in [bounds[0][2],bounds[1][2]]]
    return [min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]


def merge_rows(existing, additions):
    by_id = {r["id"]: r for r in existing}
    for r in additions:
        if r["id"] in by_id: assert by_id[r["id"]] == r, "Conflicting installed record: " + r["id"]
    return existing + [r for r in additions if r["id"] not in by_id]


def run(apply=False):
    source = load("game/data/building_layout.json")
    records = {r["id"]:r for f in source["floors"] for r in f.get("furniture",[])}
    markers = {r["id"]:r for f in source["floors"] for r in f.get("markers",[]) if "id" in r}
    layout = load("game/data/orison_v2_blockout.json")
    spaces = {r["id"]:r for r in layout["spaces"]}
    ns = extractors()
    furniture = [furniture_record(p[0],records,ns) for p in FURNITURE]
    fittings = [fitting_record(p[0],markers) for p in FITTINGS]
    materials = load("game/data/runtime_material_sets.json")["materials"]
    aliases = {"floor_oak":"oak_quartered","fabric_cool":"linen","fabric_green":"linen"}
    for record in furniture:
        for surface in record["surfaces"]:
            assert surface["material"] == "glassish" or aliases.get(surface["material"],surface["material"]) in materials, surface["material"]
            assert len(surface["vertices"]) == len(surface["normals"]) and len(surface["vertices"]) % 9 == 0
            assert all(math.isfinite(x) for x in surface["vertices"] + surface["normals"])
    anchors, footprints = [], []
    for placements, kind in [(FURNITURE,"furniture"),(FITTINGS,"fixture")]:
        for identity,room,position,yaw,stance in placements:
            assert room in spaces
            rect = spaces[room]["rect"]
            assert rect[0]+.33 < stance[0] < rect[2]-.33 and rect[1]+.33 < stance[2] < rect[3]-.33, identity
            facing = math.atan2(-(position[0]-stance[0]), -(position[2]-stance[2]))
            anchors += [dict(id=identity,level=spaces[room]["level"],space=room,position=position,yaw=yaw,kind=kind),
                        dict(id=identity+"_STANCE",level=spaces[room]["level"],space=room,position=stance,yaw=facing,kind="clearance")]
    for placement, record in zip(FURNITURE,furniture):
        footprint = world_rect(record["bounds"],placement)
        room = spaces[placement[1]]["rect"]
        assert footprint[0] >= room[0]+.07 and footprint[2] <= room[2]-.07, (record["id"],footprint,room)
        assert footprint[1] >= room[1]+.07 and footprint[3] <= room[3]-.07, (record["id"],footprint,room)
        footprints.append(dict(id=record["id"],room=placement[1],rect=footprint))
    for i,a in enumerate(footprints):
        for b in footprints[i+1:]:
            if a["room"] != b["room"]: continue
            ar,br=a["rect"],b["rect"]
            assert ar[2]<=br[0] or br[2]<=ar[0] or ar[3]<=br[1] or br[3]<=ar[1], (a["id"],b["id"])
    fitting_footprints = []
    for placement,record in zip(FITTINGS,fittings):
        kind = record["kind"]
        if kind == "shower": bounds=[[-.3775,0,-.3775],[.3775,2.1,.3775]]
        elif kind == "sink" and record["properties"]["fixture"] == "bath_sink": bounds=[[-.33,0,-.26],[.33,1,.24]]
        elif kind == "sink": bounds=[[-.34,.7,-.26],[.76,1.2,.25]]
        elif kind == "stove": bounds=[[-.35,0,-.37],[.35,1.25,.32]]
        else: bounds=[[-.38,0,-.38],[.38,1.3,.31]]
        footprint = world_rect(bounds,placement)
        room = spaces[placement[1]]["rect"]
        assert footprint[0] >= room[0]+.07-1e-8 and footprint[2] <= room[2]-.07+1e-8, (record["id"],footprint,room)
        assert footprint[1] >= room[1]+.07-1e-8 and footprint[3] <= room[3]-.07+1e-8, (record["id"],footprint,room)
        fitting_footprints.append(dict(id=record["id"],room=placement[1],rect=footprint,estimate=True))
    all_footprints = footprints + fitting_footprints
    intentional_supports = [{"2A_sink_support","F02_2A_KITCHEN_SINK_01"},
                            {"2B_sink_support","F02_2B_KITCHEN_SINK_01"}]
    for i,a in enumerate(all_footprints):
        for b in all_footprints[i+1:]:
            if a["room"] != b["room"] or {a["id"],b["id"]} in intentional_supports: continue
            ar,br=a["rect"],b["rect"]
            assert ar[2]<=br[0] or br[2]<=ar[0] or ar[3]<=br[1] or br[3]<=ar[1], (a["id"],b["id"])
    for identity,room,_,_,stance in FURNITURE + FITTINGS:
        for other in all_footprints:
            if other["room"] != room: continue
            rect=other["rect"]
            distance=math.hypot(max(rect[0]-stance[0],0,stance[0]-rect[2]),
                                max(rect[1]-stance[2],0,stance[2]-rect[3]))
            assert distance >= .38, ("stance clearance",identity,other["id"],distance)
    targets = {
        "game/data/orison_v2/domestic_furniture.json": ("furniture", furniture),
        "game/data/orison_v2/domestic_fittings.json": ("fittings", fittings),
    }
    outputs = {}
    for name,(key,additions) in targets.items():
        output = load(name)
        output[key] = merge_rows(output[key], additions)
        outputs[name] = output
    merged_anchors = merge_rows(layout["anchors"],anchors)
    mounted = {r["id"] for value in outputs.values() for rows in value.values() if isinstance(rows,list) for r in rows}
    units = sorted({m.get("unit","") for m in markers.values() if re.fullmatch(r"[1-6][A-D]",m.get("unit",""))})
    inventory = []
    for unit in units:
        prefix = f"F0{unit[0]}_{unit[1]}_"
        rooms = [s for s in spaces if s.startswith(prefix)]
        sanitary = [r["id"] for r in records.values() if r["id"]==unit+"_wc"]
        sanitary += [m["id"] for m in markers.values() if m.get("unit")==unit and m.get("kind") in ["sink","shower","stove","fridge"]]
        remaining = [r["id"] for r in records.values() if r["id"].startswith(unit+"_") and r["id"] not in mounted]
        inventory.append(dict(unit=unit,rooms=rooms,status="SOURCE_ROOM_AVAILABLE" if rooms else "V2_ROOM_DESIGN_PENDING",
                              installed_sanitary=[i for i in sanitary if i in mounted],
                              remaining_sanitary=[i for i in sanitary if i not in mounted],
                              remaining_source_furniture=remaining))
    if apply:
        for name,output in outputs.items():
            encoded = json.dumps(output,indent=2) if name.endswith("domestic_fittings.json") else json.dumps(output,separators=(",",":"))
            (ROOT/name).write_text(encoded+"\n",encoding="utf-8")
        added = merged_anchors[len(layout["anchors"]):]
        if added:
            path=ROOT/"game/data/orison_v2_blockout.json"
            text=path.read_text(encoding="utf-8")
            start=text.index("[",text.index('"anchors"'))
            _,length=json.JSONDecoder().raw_decode(text[start:])
            end=start+length-1
            additions=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+additions+"\n  "+text[end:],encoding="utf-8")
    receipt = dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",applied=apply,
                   source_sha256=hashlib.sha256((ROOT/SOURCE).read_bytes()).hexdigest(),
                   new_furniture=[dict(id=r["id"],kind=r["kind"],triangles=sum(len(s["vertices"])//9 for s in r["surfaces"])) for r in furniture],
                   new_fittings=fittings,footprints=footprints,fitting_footprint_estimates=fitting_footprints,
                   output_sha256={k:hashlib.sha256(json.dumps(v,separators=(",",":")).encode()).hexdigest() for k,v in outputs.items()})
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    (OUT/"apartment_inventory.json").write_text(json.dumps(inventory,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"furniture":len(furniture),"fittings":len(fittings),"anchors":len(anchors),
                      "apartments_with_rooms":[r["unit"] for r in inventory if r["rooms"]],
                      "apartments_without_rooms":[r["unit"] for r in inventory if not r["rooms"]],"applied":apply}))


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--apply",action="store_true")
    run(parser.parse_args().apply)
