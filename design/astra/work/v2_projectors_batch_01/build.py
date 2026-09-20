"""Three apartment projectors with dedicated source-checked stands.

No Godot/Blender launch. Supports and projection apertures are checked in source.
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
    ("2A_projector_stand","F02_A_MAIN",[-9.8,0,-1.5],0),
    ("3B_projector_stand","F03_B_MAIN",[15.2,0,-.5],math.pi),
    ("4B_projector_stand","F04_B_MAIN",[-10.1,0,-1.9],0),
]
STANCES={"2A":[-8.8,-1.5],"3B":[14.5,-1.65],"4B":[-9.2,-1.9]}
APPROACHES={"2A":[-8.5,0],"3B":[13.65,-1.35],"4B":[-8.5,0]}



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
    records={p[0]:dict(id=p[0],asm="table_rect",L=.6,W=.5,mat="wood_dark") for p in PLACEMENTS}
    tables=[previous.furniture_record(p[0],records,ns) for p in PLACEMENTS]
    layout=load("game/data/orison_v2_blockout.json");old_anchor_count=len(layout["anchors"])
    furniture=load("game/data/orison_v2/domestic_furniture.json");spaces={s["id"]:s for s in layout["spaces"]}
    anchors=[dict(id=i,level=spaces[room]["level"],space=room,position=p,yaw=yaw,kind="furniture") for i,room,p,yaw in PLACEMENTS]
    for i,room,_,yaw in PLACEMENTS:
        unit=i[:2]; x,z=STANCES[unit]
        anchors.append(dict(id=unit+"_tv_STANCE",level=spaces[room]["level"],space=room,position=[x,0,z],yaw=yaw+math.pi,kind="clearance"))
    layout["anchors"]=merge.merge(layout["anchors"],anchors)
    rows=merge.merge(furniture["furniture"],tables);indexed={a["id"]:a for a in layout["anchors"]}
    table_volumes=[(r["id"],indexed[r["id"]]["level"],geometry.volume(r["bounds"],indexed[r["id"]])) for r in tables]
    old_obstacles=geometry.obstacles(layout,rows)
    for identity,level,b in table_volumes:
        for other,floor,other_b in old_obstacles:
            if identity!=other and level==floor:assert not geometry.overlap(b,other_b),("projector stand overlap",identity,other)
        a=indexed[identity];r=spaces[a["space"]]["rect"]
        assert b[0]>=r[0]+.07 and b[2]>=r[1]+.07 and b[3]<=r[2]-.07 and b[5]<=r[3]-.07,("table leaves room",identity)
    route_samples,door_sweeps=geometry.check_routes_and_doors(layout,table_volumes)
    # Check new operator stances against every existing obstacle at body height.
    approach_samples=0
    for unit,target in STANCES.items():
        level=indexed[unit+"_projector_stand"]["level"]
        start=APPROACHES[unit];steps=max(1,math.ceil(math.dist(start,target)/.025))
        for n in range(steps+1):
            p=[start[i]+(target[i]-start[i])*n/steps for i in range(2)]
            for other,floor,b in old_obstacles:
                if floor==level and b[1]<1.574:
                    assert merge.distance(p,[b[0],b[2],b[3],b[5]])>=.38,("projector operator approach blocked",unit,other)
            approach_samples+=1
    walls=module("design/astra/work/v2_apartment_walls_batch_01/build.py","projection_walls")
    wall_list=walls.owned(layout)
    projectors=[];checks=[]
    for index,(identity,room,p,yaw) in enumerate(PLACEMENTS):
        unit=identity[:2];level=spaces[room]["level"]
        direction=1 if unit=="3B" else -1
        boundary=spaces[room]["rect"][3 if direction==1 else 1]
        wall_z=boundary-direction*.07
        origin=[p[0],.95,p[2]+direction*.18];distance=abs(origin[2]-wall_z)
        assert .5<distance<6
        height=max(.5,min(2.4,distance*.46));half_width=height*.34
        candidates=[w for w in wall_list if w["level"]==level and w["axis"]=="x" and abs(w["fixed"]-boundary)<1e-6
                    and w["start"]<=p[0]-half_width and w["end"]>=p[0]+half_width]
        assert candidates,("projection lacks continuous wall",unit)
        valid=[]
        for wall in candidates:
            cuts=walls.apertures(layout,wall)
            if not any(min(p[0]+half_width,c["end"])>max(p[0]-half_width,c["start"])
                       and min(origin[1]+height/2,c["sill"]+c["height"])>max(origin[1]-height/2,c["sill"]) for c in cuts): valid.append(wall)
        assert valid,("projection crosses aperture",unit)
        assert origin[1]-height/2>.1 and origin[1]+height/2<2.9
        rays=0
        for dx in [-half_width,0,half_width]:
            for dy in [-height/2,0,height/2]:
                target=[p[0]+dx,origin[1]+dy,wall_z]
                for n in range(101):
                    point=[origin[i]+(target[i]-origin[i])*n/100 for i in range(3)]
                    for other,floor,b in old_obstacles:
                        if floor==level: assert not all(b[i]<point[i]<b[i+3] for i in range(3)),("projector throw blocked",unit,other,point)
                rays+=1
        # Complete body footprint rests on the real table top. Reel/cord
        # envelope is narrower than this conservative box.
        table=next(t for t in tables if t["id"]==identity)
        body=geometry.volume([[-.145,0,-.18],[.145,.51,.22]],dict(position=[p[0],.745,p[2]],yaw=yaw))
        for other,floor,b in old_obstacles:
            if floor==level and other!=identity: assert not geometry.overlap(body,b),("projector body overlap",unit,other)
        for x in [-.135,.135]:
            for z in [-.0725,.1125]: assert contact.on_surface(table,[x,z],.745)
        eye=[STANCES[unit][0],1.41,STANCES[unit][1]];target=[p[0],.95,p[2]]
        assert math.dist(eye,target)<2.1
        for n in range(101):
            point=[eye[i]+(target[i]-eye[i])*n/100 for i in range(3)]
            for other,floor,b in old_obstacles:
                if floor==level: assert not all(b[i]<point[i]<b[i+3] for i in range(3)),("projector target blocked",unit,other)
        reel="ch_0"+str(index+1)
        assert (ROOT/"game/assets/video/clips"/(reel+".ogv")).is_file()
        projectors.append(dict(id=unit+"_tv",unit=unit,support=identity,position=[0,.745,0],yaw=0,reel=reel))
        checks.append(dict(unit=unit,wall=valid[0]["owner"],throw_m=distance,image_height_m=height,source_rays=rays,operator_distance_m=math.dist(eye,target)))
    data=dict(schema_version=1,projectors=projectors)
    target=ROOT/"game/data/orison_v2/domestic_projectors.json"
    if target.exists(): assert json.loads(target.read_text(encoding="utf-8"))==data,"conflicting projector source"
    if apply:
        target.write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
        (ROOT/"game/data/orison_v2/domestic_furniture.json").write_text(json.dumps(dict(furniture,furniture=rows),separators=(",",":"))+"\n",encoding="utf-8")
        added=layout["anchors"][old_anchor_count:]
        if added:
            path=ROOT/"game/data/orison_v2_blockout.json";text=path.read_text(encoding="utf-8")
            start=text.index("[",text.index('"anchors"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
            extra=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+extra+"\n  "+text[end:],encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",stands=3,projectors=checks,route_samples=route_samples,approach_samples=approach_samples,door_sweeps=door_sweeps,
                 limits="Sampled static placement and throw only; no Godot targeting, decoding, visuals, optical/occlusion, performance or lifecycle proof.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(receipt))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true");build(parser.parse_args().apply)
