"""Category pass for dining and work seating, using existing source assemblies.

No engine or Blender imports. Chairs are fixed furniture, not sitting mechanics.
"""
import argparse
import ast
import importlib.util
import json
import math
from pathlib import Path
import zlib

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PI = math.pi
PLACEMENTS = [
    ("2A_din_t","F02_A_MAIN",[-11.35,0,1.15],0),
    ("2A_din_dc1","F02_A_MAIN",[-12.3,0,1.15],-PI/2),
    ("2A_din_dc2","F02_A_MAIN",[-11.35,0,.2],PI),
    ("2A_desk","F02_A_MAIN",[-13.1,0,-.15],PI),
    ("2A_desk_dkch","F02_A_MAIN",[-12.05,0,-.15],PI),
    ("2B_din_t","F02_B_MAIN",[14.75,0,-.65],0),
    ("2B_din_dc1","F02_B_MAIN",[13.75,0,-.65],-PI/2),
    ("2B_din_dc2","F02_B_MAIN",[14.75,0,-1.55],PI),
    ("2B_fabric_worktable","F02_B_MAIN",[12.65,0,-.15],0),
    ("2B_fabric_shelf_01","F02_B_PRIVATE_HALL",[15.25,0,-5.25],PI/2),
    ("2B_fabric_shelf_02","F02_B_PRIVATE_HALL",[15.25,0,-8.25],PI/2),
    ("3B_din_t","F03_B_MAIN",[13.6,0,-2.6],0),
    ("3B_din_dc1","F03_B_MAIN",[14.6,0,-2.4],PI/2),
    ("3B_din_dc2","F03_B_MAIN",[13.6,0,-3.55],PI),
    ("3B_stool","F03_B_MAIN",[15.05,0,-1.05],PI/2),
    ("4B_meal_table","F04_B_MAIN",[-14.6,0,1.6],0),
    ("4B_meal_chair_01","F04_B_MAIN",[-13.65,0,1.6],PI/2),
    ("4B_meal_chair_02","F04_B_MAIN",[-14.6,0,2.55],0),
    ("4B_desk_chair","F04_B_MAIN",[-8.05,0,2.55],PI/2),
]
STANCES = [
    ("2A_din_t_STANCE","F02_A_MAIN",[-11.35,0,2.2],0),
    ("2A_desk_STANCE","F02_A_MAIN",[-13.4,0,.75],0),
    ("2B_din_t_STANCE","F02_B_MAIN",[13.65,0,-1.8],-PI/2),
    ("2B_fabric_worktable_STANCE","F02_B_MAIN",[12.65,0,-1.25],PI),
    ("2B_fabric_shelf_01_STANCE","F02_B_PRIVATE_HALL",[14.35,0,-5.25],-PI/2),
    ("2B_fabric_shelf_02_STANCE","F02_B_PRIVATE_HALL",[14.35,0,-8.25],-PI/2),
    ("3B_din_t_STANCE","F03_B_MAIN",[12.5,0,-2.5],-PI/2),
    ("4B_meal_table_STANCE","F04_B_MAIN",[-14.6,0,.45],PI),
]


def module(relative, name):
    spec = importlib.util.spec_from_file_location(name,ROOT/relative)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def build(apply=False):
    previous = module("design/astra/work/v2_apartment_batches_01/build.py","apartment_source")
    lighting = module("design/astra/work/v2_apartment_lighting_batch_01/build.py","apartment_geometry")
    layout = previous.load("game/data/orison_v2_blockout.json")
    furniture = previous.load("game/data/orison_v2/domestic_furniture.json")
    spaces = {s["id"]:s for s in layout["spaces"]}
    source = previous.load("game/data/building_layout.json")
    records = {r["id"]:r for floor in source["floors"] for r in floor.get("furniture",[])}
    # New 4B meal group uses the established period assembly family, explicitly
    # authored here rather than attributed to nonexistent source markers.
    records.update({"4B_meal_table":dict(id="4B_meal_table",asm="table_round",mat="wood_dark"),
                    "4B_meal_chair_01":dict(id="4B_meal_chair_01",asm="chair",mat="wood_dark"),
                    "4B_meal_chair_02":dict(id="4B_meal_chair_02",asm="chair",mat="wood_dark")})
    # Compact fabric-repair worktop and two vertical storage units replace
    # the 2B planning masses while preserving a clear switch/doorway aisle.
    records.update({"2B_fabric_worktable":dict(id="2B_fabric_worktable",asm="table_rect",L=1.6,W=.5,mat="floor_oak"),
                    "2B_fabric_shelf_01":dict(id="2B_fabric_shelf_01",asm="shelf",W=1.0,H=1.85,books=False),
                    "2B_fabric_shelf_02":dict(id="2B_fabric_shelf_02",asm="shelf",W=1.0,H=1.85,books=False)})
    tree = ast.parse((ROOT/previous.SOURCE).read_text(encoding="utf-8"))
    selected = []
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name == "MeshBuf":
            node.body = [m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in previous.METHODS]
            selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name == "Frame": selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in {"asm_chair","asm_table_round","asm_table_rect","asm_desk","asm_shelf","case_wood","hash_str","_jit"}: selected.append(node)
    namespace = dict(math=math,zlib=zlib)
    exec(compile(ast.Module(body=selected,type_ignores=[]),previous.SOURCE,"exec"),namespace)
    additions = [previous.furniture_record(p[0],records,namespace) for p in PLACEMENTS]
    materials = previous.load("game/data/runtime_material_sets.json")["materials"]
    for r in additions:
        for s in r["surfaces"]:
            assert s["material"] in materials, s["material"]
            assert len(s["vertices"]) == len(s["normals"]) and len(s["vertices"]) % 9 == 0
            assert all(math.isfinite(v) for v in s["vertices"]+s["normals"])
    anchors = [dict(id=identity,level=spaces[room]["level"],space=room,position=p,yaw=yaw,kind="furniture") for identity,room,p,yaw in PLACEMENTS]
    anchors += [dict(id=identity,level=spaces[room]["level"],space=room,position=p,yaw=yaw,kind="clearance") for identity,room,p,yaw in STANCES]
    merged = lighting.merge(layout["anchors"],anchors)
    indexed = {a["id"]:a for a in merged}
    rows = lighting.merge(furniture["furniture"],additions)
    footprints = {r["id"]:lighting.footprint(r["bounds"],indexed[r["id"]]) for r in rows}
    new_ids = {r["id"] for r in additions}
    for identity in new_ids:
        rect, room = footprints[identity], spaces[indexed[identity]["space"]]["rect"]
        assert rect[0] >= room[0]+.07 and rect[2] <= room[2]-.07 and rect[1] >= room[1]+.07 and rect[3] <= room[3]-.07, (identity,"wall clearance",rect)
        for other,other_rect in footprints.items():
            if identity == other or indexed[identity]["space"] != indexed[other]["space"]: continue
            assert rect[2]<=other_rect[0] or rect[0]>=other_rect[2] or rect[3]<=other_rect[1] or rect[1]>=other_rect[3], ("overlap",identity,other)
        for a in merged:
            if a.get("space") != indexed[identity]["space"] or a.get("kind") != "clearance": continue
            p = a["position"]
            assert lighting.distance([p[0],p[2]],rect) >= .38, ("blocked stance",identity,a["id"])
    for identity,room,p,_ in STANCES:
        rect = spaces[room]["rect"]
        assert rect[0]+.4<p[0]<rect[2]-.4 and rect[1]+.4<p[2]<rect[3]-.4, identity
        for other,r in footprints.items():
            if indexed[other]["space"] == room:
                assert lighting.distance([p[0],p[2]],r) >= .38, (identity,other)
    # Protect Mina's existing walking graph from all newly placed furniture.
    paths = previous.load("game/data/orison_v2/mina_routine.json")["paths"]
    routes = []
    for path in paths:
        if all(abs(p[2]-3.2)<1e-6 for p in path): routes.append(("F02",[[p[1],p[3]] for p in path]))
        else:
            for a,b in zip(path,path[1:]):
                if abs(a[2]-3.2)<1e-6 and abs(b[2]-3.2)<1e-6: routes.append(("F02",[[a[1],a[3]],[b[1],b[3]]]))
    # Source route candidates match the revised domestic driver and the 4B
    # main-room spine. These checks do not simulate doors, actors or physics.
    routes += [("F03",[[12.5,-2.5],[12.5,-1.35],[13.65,-1.35],[12.5,-1.35],[12.5,-2.5],[12.6,-3.55],[12.6,-4.45],[14.2,-4.45],[14.2,-6.8]]),
               ("F04",[[-6.65,0],[-13,0],[-13,4.7]]),
               ("F04",[[-10.8,0],[-10.8,2.25],[-10.05,2.25]])]
    samples = 0
    for level,path in routes:
        for a,b in zip(path,path[1:]):
            steps = max(1,math.ceil(math.dist(a,b)/.025))
            for step in range(steps+1):
                p = [a[i]+(b[i]-a[i])*step/steps for i in range(2)]
                for identity in new_ids:
                    if indexed[identity]["level"] == level:
                        assert lighting.distance(p,footprints[identity]) >= .38, ("route blocked",identity,p)
                samples += 1
    if apply:
        (ROOT/"game/data/orison_v2/domestic_furniture.json").write_text(json.dumps(dict(furniture,furniture=rows),separators=(",",":"))+"\n",encoding="utf-8")
        added = merged[len(layout["anchors"]):]
        if added:
            path = ROOT/"game/data/orison_v2_blockout.json"
            text = path.read_text(encoding="utf-8")
            start = text.index("[",text.index('"anchors"'))
            _,length = json.JSONDecoder().raw_decode(text[start:])
            end=start+length-1
            data=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+data+"\n  "+text[end:],encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",new_furniture=[dict(id=r["id"],kind=r["kind"],triangles=sum(len(s["vertices"])//9 for s in r["surfaces"]),rect=footprints[r["id"]]) for r in additions],anchors_added=len(anchors),route_samples=samples,
                 limits="Fixed chairs and coarse furniture hulls; sitting, knee clearance, physics routes, materials and performance are not verified.")
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    inventory = []
    mounted_ids = {r["id"] for r in rows}
    for unit in ["2A","2B","3B","4B"]:
        prefix = "F0"+unit[0]+"_"+unit[1]+"_"
        inventory.append(dict(unit=unit,rooms=[s for s in spaces if s.startswith(prefix)],
                              mounted_furniture=[dict(id=r["id"],kind=r["kind"],room=indexed[r["id"]]["space"]) for r in rows if indexed[r["id"]]["space"].startswith(prefix)],
                              remaining_source_assemblies=[dict(id=r["id"],assembly=r["asm"]) for r in records.values() if r["id"].startswith(unit+"_") and r.get("asm") and r["id"] not in mounted_ids]))
    (OUT/"apartment_inventory.json").write_text(json.dumps(inventory,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"furniture":len(additions),"anchors":len(anchors),"route_samples":samples,"applied":apply}))


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--apply",action="store_true")
    build(parser.parse_args().apply)
