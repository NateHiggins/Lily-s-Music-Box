"""Source-assembly surface dressing for all four detailed apartments.

No Blender/Godot imports or launches. Positions are relative to actual supports.
"""
import argparse
import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import zlib

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
TARGET = "game/data/orison_v2/domestic_surface_props.json"
# identity, unit, supporting semantic owner, local position, local yaw.
PLACEMENTS = [
    ("2A_k_kmug","2A","F02_2A_KITCHEN_SINK_01",[.62,.9195,-.09],0),
    ("2A_k_kdishrack","2A","F02_2A_KITCHEN_SINK_01",[.43,.9195,0],0),
    ("2B_k_kmug","2B","F02_2B_KITCHEN_SINK_01",[.62,.9195,-.09],0),
    ("2B_k_kdishrack","2B","F02_2B_KITCHEN_SINK_01",[.43,.9195,0],0),
    ("3B_k_kmug","3B","F03_3B_KITCHEN_SINK_01",[.62,.9195,-.09],0),
    ("3B_k_kdishrack","3B","F03_3B_KITCHEN_SINK_01",[.43,.9195,0],0),
    ("4B_mug","4B","4B_sink_counter",[-.8,.905,-.07],0),
    ("4B_dishrack","4B","4B_sink_counter",[-.52,.905,0],0),
    ("2A_papers","2A","2A_desk",[-.05,.735,0],0),
    ("2A_mug","2A","2A_desk",[.35,.735,.10],math.radians(40)),
    ("2A_phones","2A","2A_desk",[-.50,.735,.05],0),
    ("2B_story_patterns","2B","2B_fabric_worktable",[.35,.745,0],math.radians(12)),
    ("2B_story_notions","2B","2B_fabric_worktable",[-.40,.745,.07],0),
    ("3B_tray1","3B","3B_workbench",[-.40,.91,-.15],0),
    ("3B_tray2","3B","3B_workbench",[.65,.91,-.15],0),
    ("3B_jars","3B","3B_workbench",[-.20,.91,.20],0),
    ("3B_manuals","3B","3B_workbench",[-.85,.91,.10],math.radians(25)),
    ("3B_mug","3B","3B_workbench",[.25,.91,.22],0),
    ("3B_coil","3B","3B_tools1",[-.12,1.412,0],0),
]


def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))


def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def in_triangle(p,a,b,c):
    crosses=[]
    for u,v in [(a,b),(b,c),(c,a)]: crosses.append((v[0]-u[0])*(p[1]-u[1])-(v[1]-u[1])*(p[0]-u[0]))
    return all(x>=-1e-9 for x in crosses) or all(x<=1e-9 for x in crosses)


def on_surface(record,point,height):
    for surface in record["surfaces"]:
        v=surface["vertices"]
        for i in range(0,len(v),9):
            triangle=[v[i+j:i+j+3] for j in [0,3,6]]
            if all(abs(p[1]-height)<1e-6 for p in triangle):
                a,b,c=[[p[0],p[2]] for p in triangle]
                area=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
                if abs(area)>1e-9 and in_triangle(point,a,b,c):return True
    return False


def build(apply=False):
    extract=module("design/astra/work/v2_apartment_batches_01/build.py","source_assemblies")
    geometry=module("design/astra/work/v2_apartment_lighting_batch_01/build.py","geometry")
    names={r[0] for r in PLACEMENTS}
    source=load("game/data/building_layout.json")
    records={r["id"]:r for f in source["floors"] for r in f.get("furniture",[]) if r["id"] in names}
    assert set(records)==names
    tree=ast.parse((ROOT/extract.SOURCE).read_text(encoding="utf-8"))
    selected=[]; assemblies={"asm_"+r["asm"] for r in records.values()}
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=="MeshBuf":
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in extract.METHODS]
            selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=="Frame":selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in assemblies|{"case_wood","hash_str","_jit"}:selected.append(node)
    namespace=dict(math=math,zlib=zlib)
    exec(compile(ast.Module(body=selected,type_ignores=[]),extract.SOURCE,"exec"),namespace)
    furniture={r["id"]:r for r in load("game/data/orison_v2/domestic_furniture.json")["furniture"]}
    fittings={r["id"]:r for r in load("game/data/orison_v2/domestic_fittings.json")["fittings"]}
    layout=load("game/data/orison_v2_blockout.json")
    anchors={r["id"]:r for r in layout["anchors"]}
    materials=load("game/data/runtime_material_sets.json")["materials"]
    props=[]; footprints=[]; checks=[]
    for identity,unit,support,position,yaw in PLACEMENTS:
        record=extract.furniture_record(identity,records,namespace)
        vertices=[s["vertices"][i:i+3] for s in record["surfaces"] for i in range(0,len(s["vertices"]),3)]
        # Align actual visible geometry, not a larger invisible source hull.
        bottom=min(v[1] for v in vertices)
        for surface in record["surfaces"]:
            assert surface["material"]=="glassish" or surface["material"] in materials
            for i in range(1,len(surface["vertices"]),3):surface["vertices"][i]-=bottom
            assert all(math.isfinite(x) for x in surface["vertices"]+surface["normals"])
            assert len(surface["vertices"])==len(surface["normals"]) and len(surface["vertices"])%9==0
        record["bounds"]=[[min(v[i] for v in vertices) for i in range(3)],[max(v[i] for v in vertices) for i in range(3)]]
        record["bounds"][0][1]=0
        record["bounds"][1][1]-=bottom
        record.update(unit=unit,support=support,position=position,yaw=yaw)
        assert support in anchors and anchors[support]["space"].startswith("F0"+unit[0]+"_"+unit[1]+"_")
        rect=geometry.footprint(record["bounds"],dict(position=position,yaw=yaw))
        corners=[[rect[0],rect[1]],[rect[0],rect[3]],[rect[2],rect[1]],[rect[2],rect[3]]]
        if support in fittings:
            p=fittings[support]["properties"]
            assert p["fixture"]=="kitchen_sink" and p["has_drainboard"] and not p["compact_kitchen"] and p["drain_side"]==1
            # TapProp: .61m bowl + .42m board; raised rib top is .9+.014+.011/2.
            assert abs(position[1]-(.9+.014+.011/2))<1e-6
            assert all(.305+.01<=x<=.725-.01 and -.23+.01<=z<=.23-.01 for x,z in corners)
            contact="drainboard rib-top estimate"
        else:
            assert support in furniture
            assert all(on_surface(furniture[support],p,position[1]) for p in corners),(identity,"missing visible support",corners)
            contact="four footprint corners on extracted horizontal surface"
        for other,owner,other_rect in footprints:
            if owner!=support:continue
            assert rect[2]+.01<=other_rect[0] or other_rect[2]+.01<=rect[0] or rect[3]+.01<=other_rect[1] or other_rect[3]+.01<=rect[1],("surface overlap",identity,other)
        # Independent bench lamp already owns this base and switch area.
        if support=="3B_workbench":
            lamp=anchors["F03_B_LAMP_01"];bench=anchors[support]
            x,z=lamp["position"][0]-bench["position"][0],lamp["position"][2]-bench["position"][2]
            assert geometry.distance([x,z],rect)>=.13,(identity,"bench lamp clearance")
        footprints.append((identity,support,rect));props.append(record)
        checks.append(dict(id=identity,support=support,rect=rect,height=position[1],contact=contact,visual_base_adjustment_m=-bottom))
    output=dict(schema_version=1,props=props)
    encoded=json.dumps(output,separators=(",",":"))+"\n"
    if (ROOT/TARGET).exists(): assert load(TARGET)==output,"refusing to replace changed surface-prop data"
    if apply:(ROOT/TARGET).write_text(encoded,encoding="utf-8")
    OUT.mkdir(parents=True,exist_ok=True)
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",props=len(props),triangles=sum(len(s["vertices"])//9 for r in props for s in r["surfaces"]),
                 source_sha256=hashlib.sha256((ROOT/extract.SOURCE).read_bytes()).hexdigest(),checks=checks,
                 limits="Fixed noninteractive decoration. Drainboard contact is a source estimate. Runtime materials, targeting, lighting and lifetime are not verified.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in receipt.items() if k not in ["checks","limits","source_sha256"]}))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true")
    build(parser.parse_args().apply)
