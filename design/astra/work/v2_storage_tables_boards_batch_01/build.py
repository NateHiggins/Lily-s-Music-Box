"""Apartment category pass: four wall cupboards, two tables, three boards, crate.

Pure authored-assembly extraction. No Blender or Godot imports/launches.
"""
import argparse
import ast
import copy
import importlib.util
import json
import math
from pathlib import Path
import re
import zlib

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PLACEMENTS = [
    ("2A_k_wall_cupboard", "F02_A_KITCHEN", [-14.45,1.65,5.82], 0),
    ("2B_k_wall_cupboard", "F02_B_KITCHEN", [9.88,1.65,-7.3], -math.pi/2),
    ("3B_k_wall_cupboard", "F03_B_KITCHEN", [10.45,1.65,-5.63], 0),
    ("4B_wall_cupboard", "F04_B_KITCHEN", [-14.55,1.65,5.97], 0),
    ("2A_cof", "F02_A_MAIN", [-11.8,0,-1.75], 0),
    ("4B_coffee", "F04_B_MAIN", [-11.05,0,-2.05], 0),
    ("2A_pinboard", "F02_A_BED", [-13.7,1.15,6.29], math.pi),
    ("2B_story_pattern_board", "F02_B_MAIN", [12.65,1.15,.21], 0),
    ("3B_toolboard", "F03_B_MAIN", [13.4,1.55,.21], 0),
    ("3B_partscrate", "F03_B_MAIN", [15.15,0,-4.65], 0),
]


def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))


def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def extraction():
    previous=module("design/astra/work/v2_apartment_batches_01/build.py","assembly_source")
    source=load("game/data/building_layout.json")
    records={r["id"]:r for floor in source["floors"] for r in floor.get("furniture",[])}
    tree=ast.parse((ROOT/previous.SOURCE).read_text(encoding="utf-8")); selected=[]
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=="MeshBuf":
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in previous.METHODS]
            selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=="Frame": selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in {"asm_coffee","asm_crate","asm_pinboard","asm_toolboard","asm_kitchen","case_wood","hash_str","_jit"}: selected.append(node)
    ns=dict(math=math,zlib=zlib)
    exec(compile(ast.Module(body=selected,type_ignores=[]),previous.SOURCE,"exec"),ns)

    class UpperOnlyFrame:
        # Retain exact authored upper carcass/door/handle geometry. The lower
        # sink-cutout assembly belongs to another integration decision.
        def __init__(self, frame): self.frame=frame
        def box(self, material,x0,y0,z0,x1,y1,z1):
            if z0>=1.46: self.frame.box(material,x0,y0,z0-1.46,x1,y1,z1-1.46)
        def hull(self,*args): pass

    ns["asm_cupboard"]=lambda frame,spec: ns["asm_kitchen"](UpperOnlyFrame(frame),spec)
    for unit in ["2A","2B","3B","4B"]:
        identity=unit+"_k_wall_cupboard" if unit!="4B" else "4B_wall_cupboard"
        records[identity]=dict(records[unit+"_k"] if unit!="4B" else records["2A_k"],id=identity,asm="cupboard")
    additions=[previous.furniture_record(p[0],records,ns) for p in PLACEMENTS]
    for r in additions:
        if r["kind"]=="coffee":
            bottom=r["bounds"][0][1]
            for surface in r["surfaces"]:
                for i in range(1,len(surface["vertices"]),3):surface["vertices"][i]-=bottom
            r["bounds"][0][1]=0
            r["bounds"][1][1]-=bottom
        if r["kind"]=="cupboard":
            unit=r["id"][:2]
            r["source_component"]={"assembly":unit+"_k" if unit!="4B" else "2A_k", "component":"upper_cabinet", "new_unit_variant":unit=="4B"}
    return additions


def volume(bounds,anchor):
    geometry=module("design/astra/work/v2_apartment_lighting_batch_01/build.py","volume_geometry")
    r=geometry.footprint(bounds,anchor)
    return [r[0],bounds[0][1]+anchor["position"][1],r[1],r[2],bounds[1][1]+anchor["position"][1],r[3]]


def overlap(a,b):
    return all(min(a[i+3],b[i+3])-max(a[i],b[i])>1e-6 for i in range(3))


def obstacles(layout,furniture):
    anchors={a["id"]:a for a in layout["anchors"]}; result=[]
    for r in furniture:
        a=anchors[r["id"]]
        for bounds in r.get("collision_boxes",[r["bounds"]]):result.append((r["id"],a["level"],volume(bounds,a)))
    for r in load("game/data/orison_v2/domestic_fittings.json")["fittings"]:
        a,kind=anchors[r["id"]],r["kind"]
        if kind=="shower": bounds=[[-.3775,0,-.3775],[.3775,2.1,.3775]]
        elif kind=="sink" and r["properties"]["fixture"]=="bath_sink": bounds=[[-.33,0,-.26],[.33,1.2,.24]]
        elif kind=="sink": bounds=[[-.34,0,-.26],[.76,1.25,.25]]
        elif kind=="stove": bounds=[[-.35,0,-.37],[.35,1.25,.32]]
        else: bounds=[[-.38,0,-.38],[.38,1.5,.31]]
        result.append((r["id"],a["level"],volume(bounds,a)))
    envelopes={e["id"]:e for e in layout["envelopes"]}
    for table in load("game/data/orison_v2/case_one_placement.json")["tables"]:
        e=envelopes[table["anchor"]];r=e["rect"]
        x,z=(r[0]+r[2])/2+table["offset"][0],(r[1]+r[3])/2+table["offset"][2]
        result.append((table["id"],e["level"],[x-table["width"]/2,0,z-table["depth"]/2,x+table["width"]/2,table["height"],z+table["depth"]/2]))
    for a in layout["anchors"]:
        if "RADIATOR" in a["id"] and not a["id"].endswith("STANCE"):
            result.append((a["id"],a["level"],volume([[-.72,-.75,-.15],[.7,.2,.15]],a)))
        if a["id"].endswith("SWITCH"):
            result.append((a["id"],a["level"],volume([[-.08,-.12,-.08],[.08,.12,.08]],a)))
    # Surface dressing has no collider, but boards/cupboards must not pass
    # through its visible meshes. All current supports have semantic anchors.
    for r in load("game/data/orison_v2/domestic_surface_props.json")["props"]:
        a=anchors[r["support"]]; x,y,z=r["position"]; c,s=math.cos(a["yaw"]),math.sin(a["yaw"])
        at=dict(position=[a["position"][0]+c*x+s*z,a["position"][1]+y,a["position"][2]-s*x+c*z],yaw=a["yaw"]+r["yaw"])
        result.append((r["id"],a["level"],volume(r["bounds"],at)))
    # Child-owned appliances/cabinets remain visible obstacles for future
    # category batches even though their semantic identity has no root marker.
    accessories_path=ROOT/"game/data/orison_v2/household_accessories.json"
    if accessories_path.exists():
        for r in load("game/data/orison_v2/household_accessories.json")["accessories"]:
            a=anchors[r["support"]]; x,y,z=r["position"]; c,s=math.cos(a["yaw"]),math.sin(a["yaw"])
            at=dict(position=[a["position"][0]+c*x+s*z,a["position"][1]+y,a["position"][2]-s*x+c*z],yaw=a["yaw"]+r["yaw"])
            result.append((r["id"],a["level"],volume(r["bounds"],at)))
    # Solid service chases occupy every storey they cross, including their
    # full height. Include them for every category using this shared census.
    for riser in layout.get("risers",[]):
        if not riser.get("solid",True):continue
        r=riser["rect"]
        for level in layout["levels"]:
            result.append((riser["id"],level["id"],[r[0],riser["from_y"]-level["y"],r[1],r[2],riser["to_y"]-level["y"],r[3]]))
    return result


def check_walls(layout,new_volumes):
    walls=module("design/astra/work/v2_apartment_walls_batch_01/build.py","wall_geometry")
    spaces={s["id"]:s for s in layout["spaces"]}; thickness=layout["dimensions"]["partition_wall"]/2
    wall_list=walls.owned(layout); supports=[]
    for identity,level,b in new_volumes:
        room=next(p[1] for p in PLACEMENTS if p[0]==identity); r=spaces[room]["rect"]
        assert b[0]>=r[0]+thickness-1e-6 and b[2]>=r[1]+thickness-1e-6 and b[3]<=r[2]-thickness+1e-6 and b[5]<=r[3]-thickness+1e-6,("room containment",identity,b)
        if identity not in ["2A_cof","4B_coffee","3B_partscrate"]:
            possible=[]
            for wall in wall_list:
                if wall["level"]!=level:continue
                axis=0 if wall["axis"]=="x" else 2;fixed=2-axis
                if not (wall["start"]<=b[axis]+1e-6 and wall["end"]>=b[axis+3]-1e-6):continue
                gap=min(abs(wall["fixed"]-b[fixed]),abs(wall["fixed"]-b[fixed+3]))-thickness
                if not -.0001<=gap<=.025:continue
                blocked=False
                for cut in walls.apertures(layout,wall):
                    if min(b[axis+3],cut["end"])-max(b[axis],cut["start"])>1e-6 and min(b[4],cut["sill"]+cut["height"])-max(b[1],cut["sill"])>1e-6:blocked=True
                if not blocked:possible.append(wall["owner"]+":"+wall["side"])
            assert possible,("wall mount lacks solid backing",identity,b)
            supports.append(dict(id=identity,wall_owners=possible))
    return supports


def check_routes_and_doors(layout,new_volumes):
    geometry=module("design/astra/work/v2_apartment_doors_batch_01/check.py","route_geometry")
    def check_point(level,p,radius,height=1.574):
        for identity,floor,b in new_volumes:
            if floor!=level or b[1]>=height or b[4]<=.02:continue
            assert geometry.distance(p,geometry.rect_polygon([b[0],b[2],b[3],b[5]]))>=radius,("stance/route blocked",identity,p)
    for a in layout["anchors"]:
        if a.get("kind")=="clearance" or a["id"].endswith("STANCE"):
            check_point(a["level"],[a["position"][0],a["position"][2]],.38)
    routes=[]
    data=load("game/tests/data/v2_apartment_door_routes.json"); at=data["start"]
    for step in data["steps"]:
        if "walk" in step:routes.append(("F02",at,step["walk"],.38));at=step["walk"]
    for path in load("game/data/orison_v2/mina_routine.json")["paths"]:
        for a,b in zip(path,path[1:]):
            if abs(a[2]-3.2)<1e-6 and abs(b[2]-3.2)<1e-6:routes.append(("F02",[a[1],a[3]],[b[1],b[3]],.30))
    for level,path in [("F02",[[-9.2,1.4],[-10.5,1],[-12.4,.85],[-11.2,.85],[-11.1,1.7],[-10.5,2.5]]),
                       ("F03",[[12.5,-2.5],[12.5,-1.35],[13.65,-1.35],[12.5,-1.35],[12.6,-4.45],[14.2,-4.45],[14.2,-6.8]]),
                       ("F04",[[-6.65,0],[-13,0],[-13,4.7],[-9.8,4.7],[-9.8,6.9]]),
                       ("F04",[[-10.8,0],[-10.8,2.25],[-10.05,2.25]])]:
        routes += [(level,a,b,.38) for a,b in zip(path,path[1:])]
    samples=0
    for level,a,b,radius in routes:
        steps=max(1,math.ceil(math.dist(a,b)/.025))
        for n in range(steps+1):check_point(level,[a[i]+(b[i]-a[i])*n/steps for i in range(2)],radius);samples+=1
    text=(ROOT/"game/scripts/building/orison_v2_domestic_doors.gd").read_text(encoding="utf-8")
    specs={identity:outward=="true" for identity,outward in re.findall(r'"([A-Z0-9_]+)": \{"kind": "[a-z_]+", "swing_out": (true|false)',text)}
    swept=0
    for door in layout["doors"]:
        if door["id"] not in specs:continue
        for n in range(201):
            polygon=geometry.leaf_polygon(door,specs[door["id"]],n*.5)
            for identity,level,b in new_volumes:
                if level==door["level"] and b[1]<door["height"]:
                    assert not geometry.overlaps(polygon,geometry.rect_polygon([b[0],b[2],b[3],b[5]])),("door sweep",door["id"],identity,n)
        swept+=1
    return samples,swept


def build(apply=False):
    additions=extraction(); materials=load("game/data/runtime_material_sets.json")["materials"]
    for r in additions:
        for surface in r["surfaces"]:
            assert surface["material"]=="glassish" or surface["material"] in materials
            assert len(surface["vertices"])==len(surface["normals"]) and len(surface["vertices"])%9==0
            assert all(math.isfinite(v) for v in surface["vertices"]+surface["normals"])
    geometry=module("design/astra/work/v2_apartment_lighting_batch_01/build.py","merge_geometry")
    layout=load("game/data/orison_v2_blockout.json"); before=copy.deepcopy(layout)
    furniture=load("game/data/orison_v2/domestic_furniture.json"); spaces={s["id"]:s for s in layout["spaces"]}
    anchors=[dict(id=identity,level=spaces[room]["level"],space=room,position=p,yaw=yaw,kind="furniture") for identity,room,p,yaw in PLACEMENTS]
    layout["anchors"]=geometry.merge(layout["anchors"],anchors)
    rows=geometry.merge(furniture["furniture"],additions); indexed={a["id"]:a for a in anchors}
    new_volumes=[(r["id"],indexed[r["id"]]["level"],volume(r["bounds"],indexed[r["id"]])) for r in additions]
    supported={r["id"]:r["support_source"]["id"] for r in rows if "support_source" in r}
    for identity,level,b in new_volumes:
        for other,floor,other_b in obstacles(layout,rows):
            # The specialist-device generator checks visible support contact.
            # A support's conservative top hull may intersect its supported
            # object's base by the documented few millimetres.
            if supported.get(other)==identity or supported.get(identity)==other: continue
            if other!=identity and floor==level:assert not overlap(b,other_b),("furnishing overlap",identity,other,b,other_b)
    supports=check_walls(layout,new_volumes)
    samples,swept=check_routes_and_doors(layout,new_volumes)
    if apply:
        (ROOT/"game/data/orison_v2/domestic_furniture.json").write_text(json.dumps(dict(furniture,furniture=rows),separators=(",",":"))+"\n",encoding="utf-8")
        added=layout["anchors"][len(before["anchors"]):]
        if added:
            path=ROOT/"game/data/orison_v2_blockout.json";text=path.read_text(encoding="utf-8")
            start=text.index("[",text.index('"anchors"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
            data=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+data+"\n  "+text[end:],encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",additions=[dict(id=r["id"],kind=r["kind"],triangles=sum(len(s["vertices"])//9 for s in r["surfaces"])) for r in additions],wall_supports=supports,route_samples=samples,door_sweeps=swept,
                 limits="Fixed cupboards/boards/crate; no cabinet-door or inventory mechanics. Source volume/sampled route and leaf bounds only. Runtime physics, interaction rays, material/light response, performance and visual acceptance pending.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(additions=len(additions),furniture_total=len(rows),route_samples=samples,door_sweeps=swept,applied=apply)))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true");build(parser.parse_args().apply)
