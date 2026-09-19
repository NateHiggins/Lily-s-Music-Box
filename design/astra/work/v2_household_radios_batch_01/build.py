"""Six functional household receivers with dedicated, source-checked supports.

No Godot/Blender launch. Receiver bounds below conservatively cover the shared
families used here, their V2 speaker feet and their movable tuning knobs.
"""
import argparse
import ast
import json
import math
from pathlib import Path
import zlib

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
PLACEMENTS=[
    ("3A_wireless_table","F03_A_MAIN",[-8.02,0,-3.04],math.pi/2),
    ("4A_wireless_table","F04_A_MAIN",[12.55,0,-3.77],math.pi),
    ("2A_wireless_table","F02_A_MAIN",[-8.02,0,-3.04],math.pi/2),
    ("2B_wireless_table","F02_B_MAIN",[12.55,0,-3.77],math.pi),
    ("3B_wireless_table","F03_B_MAIN",[11.84,0,-.5],-math.pi/2),
    ("4B_wireless_table","F04_B_MAIN",[-14.95,0,-1.5],-math.pi/2),
]
STANCES={"3A":[-9.1,-3.04],"4A":[12.55,-2.65],"2A":[-9.1,-3.04],"2B":[12.55,-2.65],"3B":[12.4,-1.4],"4B":[-13.8,-1.5]}
APPROACHES={"3A":[-8.5,0],"4A":[12.5,-2.5],"2A":[-8.5,0],"2B":[12.5,-2.5],"3B":[12.5,-1.35],"4B":[-13,0]}
BOUNDS={"3A":[[-.17,0,-.12],[.29,.25,.12]],"4A":[[-.53,0,-.175],[.275,.35,.145]],"2A":[[-.53,0,-.175],[.275,.35,.145]],
        "2B":[[-.53,0,-.17],[.24,.35,.12]],
        "3B":[[-.24,0,-.17],[.53,.38,.12]],
        "4B":[[-.53,0,-.17],[.24,.35,.12]]}


def module(path,name):
    import importlib.util
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def load(path):return json.loads((ROOT/path).read_text(encoding="utf-8"))


def build(apply=False):
    previous=module("design/astra/work/v2_apartment_batches_01/build.py","radio_table_source")
    merge=module("design/astra/work/v2_apartment_lighting_batch_01/build.py","radio_merge")
    geometry=module("design/astra/work/v2_storage_tables_boards_batch_01/build.py","radio_volume")
    contact=module("design/astra/work/v2_surface_props_batch_01/build.py","radio_contact")
    tree=ast.parse((ROOT/previous.SOURCE).read_text(encoding="utf-8")); selected=[]
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=="MeshBuf":
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in previous.METHODS];selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=="Frame":selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in {"asm_table_rect","case_wood","hash_str","_jit"}:selected.append(node)
    ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=selected,type_ignores=[]),previous.SOURCE,"exec"),ns)
    records={p[0]:dict(id=p[0],asm="table_rect",L=1.1,W=.46,mat="wood_dark") for p in PLACEMENTS}
    tables=[previous.furniture_record(p[0],records,ns) for p in PLACEMENTS]
    layout=load("game/data/orison_v2_blockout.json");old_anchor_count=len(layout["anchors"])
    furniture=load("game/data/orison_v2/domestic_furniture.json");spaces={s["id"]:s for s in layout["spaces"]}
    anchors=[dict(id=i,level=spaces[room]["level"],space=room,position=p,yaw=yaw,kind="furniture") for i,room,p,yaw in PLACEMENTS]
    for i,room,_,yaw in PLACEMENTS:
        unit=i[:2]; x,z=STANCES[unit]
        anchors.append(dict(id="DomesticRadio_"+unit+"_STANCE",level=spaces[room]["level"],space=room,position=[x,0,z],yaw=yaw+math.pi,kind="clearance"))
    layout["anchors"]=merge.merge(layout["anchors"],anchors)
    rows=merge.merge(furniture["furniture"],tables);indexed={a["id"]:a for a in layout["anchors"]}
    table_volumes=[(r["id"],indexed[r["id"]]["level"],geometry.volume(r["bounds"],indexed[r["id"]])) for r in tables]
    old_obstacles=geometry.obstacles(layout,rows)
    for identity,level,b in table_volumes:
        for other,floor,other_b in old_obstacles:
            if identity!=other and level==floor:assert not geometry.overlap(b,other_b),("radio table overlap",identity,other)
        a=indexed[identity];r=spaces[a["space"]]["rect"]
        assert b[0]>=r[0]+.07 and b[2]>=r[1]+.07 and b[3]<=r[2]-.07 and b[5]<=r[3]-.07,("table leaves room",identity)
    route_samples,door_sweeps=geometry.check_routes_and_doors(layout,table_volumes)
    # Check new operator stances against every existing obstacle at body height.
    approach_samples=0
    for unit,target in STANCES.items():
        level=indexed[unit+"_wireless_table"]["level"]
        start=APPROACHES[unit];steps=max(1,math.ceil(math.dist(start,target)/.025))
        for n in range(steps+1):
            p=[start[i]+(target[i]-start[i])*n/steps for i in range(2)]
            for other,floor,b in old_obstacles:
                if floor==level and b[1]<1.574:
                    assert merge.distance(p,[b[0],b[2],b[3],b[5]])>=.38,("radio operator approach blocked",unit,other)
            approach_samples+=1
    profiles={p["unit"]:p for p in load("game/data/domestic_radios.json")["profiles"]}
    receivers=[]; checks=[]
    for table in tables:
        unit=table["id"][:2];a=indexed[table["id"]]
        local=[-.08 if unit=="3B" else .08,.745,0]
        record=dict(id="DomesticRadio_"+unit,unit=unit,support=table["id"],position=local,yaw=0)
        expected_family="crystal_set" if unit=="3A" else "atwater_kent_44" if unit in ["2A","4A"] else "three_dial_battery"
        assert profiles[unit]["family"]==expected_family
        assert profiles[unit]["speaker"]==("headphones" if unit=="3A" else "horn" if unit=="3B" else "cone")
        local_rect=merge.footprint(BOUNDS[unit],dict(position=local,yaw=0))
        for x in [local_rect[0],local_rect[2]]:
            for z in [local_rect[1],local_rect[3]]:
                assert contact.on_surface(table,[x,z],local[1]),("radio lacks physical table support",unit,x,z)
        c,s=math.cos(a["yaw"]),math.sin(a["yaw"])
        pose=dict(position=[a["position"][0]+c*local[0]+s*local[2],local[1],a["position"][2]-s*local[0]+c*local[2]],yaw=a["yaw"])
        b=geometry.volume(BOUNDS[unit],pose)
        for other,level,other_b in old_obstacles:
            if level==a["level"] and other!=table["id"]: assert not geometry.overlap(b,other_b),("receiver overlap",unit,other)
        # Intended target is above the support, within the original 2.1m ray.
        target=[pose["position"][0],local[1]+.15,pose["position"][2]]
        eye=[STANCES[unit][0],1.41,STANCES[unit][1]]
        distance=math.dist(eye,target);assert distance<2.1
        for n in range(101):
            p=[eye[i]+(target[i]-eye[i])*n/100 for i in range(3)]
            for other,level,other_b in old_obstacles:
                if level==a["level"]: assert not all(other_b[i]<p[i]<other_b[i+3] for i in range(3)),("radio sightline blocked",unit,other)
        receivers.append(record)
        checks.append(dict(unit=unit,family=expected_family,speaker=profiles[unit]["speaker"],support=table["id"],support_height_m=.745,world_bounds=b,eye_to_receiver_m=distance))
    data=dict(schema_version=1,receivers=receivers);target=ROOT/"game/data/orison_v2/domestic_radios.json"
    if target.exists():
        data["receivers"]=merge.merge(load("game/data/orison_v2/domestic_radios.json")["receivers"],receivers)
    if apply:
        target.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        (ROOT/"game/data/orison_v2/domestic_furniture.json").write_text(json.dumps(dict(furniture,furniture=rows),separators=(",",":"))+"\n",encoding="utf-8")
        added=layout["anchors"][old_anchor_count:]
        if added:
            path=ROOT/"game/data/orison_v2_blockout.json";text=path.read_text(encoding="utf-8")
            start=text.index("[",text.index('"anchors"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
            extra=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+extra+"\n  "+text[end:],encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",tables=len(tables),receivers=checks,route_samples=route_samples,operator_approach_samples=approach_samples,door_sweeps=door_sweeps,table_triangles=sum(len(s["vertices"])//9 for r in tables for s in r["surfaces"]),limits="Receiver envelope estimates and sampled sightlines only. Physical targeting, audio isolation/release, materials, conductor events, lifecycle and persistence require runtime verification.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(tables=len(tables),receivers=len(receivers),furniture_total=len(rows),route_samples=route_samples,door_sweeps=door_sweeps,applied=apply)))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true");build(parser.parse_args().apply)
