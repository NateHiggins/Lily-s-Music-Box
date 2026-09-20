"""Four independent prep/storage cabinets. No Blender or engine launch."""
import argparse
import ast
import json
import math
from pathlib import Path
import zlib

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
PLACEMENTS=[
    ("2A_prep_cabinet","F02_A_KITCHEN",[-14.2,0,3.5],math.pi),
    ("2B_prep_cabinet","F02_B_KITCHEN",[11.85,0,-8.0],math.pi),
    ("3B_prep_cabinet","F03_B_KITCHEN",[11.3,0,-7.69],math.pi),
    ("4B_prep_cabinet","F04_B_KITCHEN",[-14.45,0,3.82],math.pi),
]
STANCES={"2A":[-14.2,4.4],"2B":[11.85,-6.85],"3B":[11.3,-6.55],"4B":[-14.45,4.75]}
APPROACHES={"2A":[-12,4.15],"2B":[11.4,-6.24],"3B":[12.45,-6.8],"4B":[-13,4.7]}
# Godot-local visible carcass pieces are also its collision authority.
PIECES=[
    ("wood_dark",[-.38,0,-.19],[.38,.07,.20]),
    ("plywood",[-.4,.07,-.225],[.4,.095,.225]),
    ("trim",[-.4,.095,-.225],[-.376,.865,.225]),
    ("trim",[.376,.095,-.225],[.4,.865,.225]),
    ("plywood",[-.376,.095,.201],[.376,.865,.225]),
    ("plywood",[-.376,.43,-.21],[.376,.455,.19]),
    ("countertop",[-.415,.865,-.255],[.415,.9,.245]),
]
BOUNDS=[[-.415,0,-.29],[.415,.9,.245]]


def module(path,name):
    import importlib.util
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def load(path):return json.loads((ROOT/path).read_text(encoding="utf-8"))


def build(apply=False):
    previous=module("design/astra/work/v2_apartment_batches_01/build.py","prep_source")
    merge=module("design/astra/work/v2_apartment_lighting_batch_01/build.py","prep_merge")
    geometry=module("design/astra/work/v2_storage_tables_boards_batch_01/build.py","prep_geometry")
    walls=module("design/astra/work/v2_apartment_walls_batch_01/build.py","prep_walls")
    tree=ast.parse((ROOT/previous.SOURCE).read_text(encoding="utf-8"));selected=[]
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=="MeshBuf":
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in previous.METHODS];selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=="Frame":selected.append(node)
    ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=selected,type_ignores=[]),previous.SOURCE,"exec"),ns)
    def assembly(frame,spec):
        for material,low,high in PIECES:frame.box(material,low[0],-high[2],low[1],high[0],-low[2],high[1])
    ns["asm_prep_cabinet"]=assembly
    records={p[0]:dict(id=p[0],asm="prep_cabinet") for p in PLACEMENTS}
    additions=[previous.furniture_record(p[0],records,ns) for p in PLACEMENTS]
    for r in additions:
        r["bounds"]=BOUNDS
        r["collision_boxes"]=[[lo,hi] for _,lo,hi in PIECES]
        r["mechanism"]={"unit":r["id"][:2]}
    layout=load("game/data/orison_v2_blockout.json");old_count=len(layout["anchors"])
    furniture=load("game/data/orison_v2/domestic_furniture.json");spaces={s["id"]:s for s in layout["spaces"]}
    anchors=[dict(id=i,level=spaces[room]["level"],space=room,position=p,yaw=yaw,kind="furniture") for i,room,p,yaw in PLACEMENTS]
    for i,room,_,yaw in PLACEMENTS:
        x,z=STANCES[i[:2]]
        anchors.append(dict(id=i+"_STANCE",level=spaces[room]["level"],space=room,position=[x,0,z],yaw=yaw+math.pi,kind="clearance"))
    layout["anchors"]=merge.merge(layout["anchors"],anchors)
    rows=merge.merge(furniture["furniture"],additions);indexed={a["id"]:a for a in layout["anchors"]}
    volumes=[(r["id"],indexed[r["id"]]["level"],geometry.volume(BOUNDS,indexed[r["id"]])) for r in additions]
    obstacles=geometry.obstacles(layout,rows)
    for identity,level,b in volumes:
        for other,floor,other_b in obstacles:
            if other!=identity and floor==level: assert not geometry.overlap(b,other_b),("cabinet overlap",identity,other)
        a=indexed[identity];r=spaces[a["space"]]["rect"]
        assert b[0]>=r[0]+.07 and b[2]>=r[1]+.07 and b[3]<=r[2]-.07 and b[5]<=r[3]-.07,("cabinet leaves room",identity)
        # Cabinet backs must meet a solid portion of the south room boundary.
        assert any(w["level"]==level and w["axis"]=="x" and abs(w["fixed"]-r[1])<1e-6 and w["start"]<=b[0] and w["end"]>=b[3]
                   and not any(min(c["end"],b[3])>max(c["start"],b[0]) for c in walls.apertures(layout,w)) for w in walls.owned(layout)),("cabinet blocks an aperture",identity)
    samples,sweeps=geometry.check_routes_and_doors(layout,volumes)
    approach_samples=0
    for unit,target in STANCES.items():
        level=indexed[unit+"_prep_cabinet"]["level"];start=APPROACHES[unit]
        count=max(1,math.ceil(math.dist(start,target)/.025))
        for n in range(count+1):
            p=[start[i]+(target[i]-start[i])*n/count for i in range(2)]
            for other,floor,b in obstacles:
                if floor==level and b[1]<1.574:assert merge.distance(p,[b[0],b[2],b[3],b[5]])>=.38,("cabinet approach blocked",unit,other,p)
            approach_samples+=1
    # Every pose of the bypass leaf and its pull remains in the furniture's
    # declared volume. At full travel the left shelf opening stays empty.
    def intersects(low,high,point):return all(low[i]<point[i]<high[i] for i in range(3))
    moving=[([-.376,.1,-.262],[-.006,.85,-.244]),([-.071,.5675,-.288],[-.049,.6525,-.266])]
    for n in range(101):
        for low,high in moving:
            lo=[low[0]+.382*n/100,low[1],low[2]];hi=[high[0]+.382*n/100,high[1],high[2]]
            assert all(BOUNDS[0][i]<=lo[i]<=hi[i]<=BOUNDS[1][i] for i in range(3))
    for z in [-.28,-.2,0,.16]:
        point=[-.19,.55,z]
        assert not any(intersects(lo,hi,point) for _,lo,hi in PIECES)
        assert not any(intersects([lo[0]+.382,lo[1],lo[2]],[hi[0]+.382,hi[1],hi[2]],point) for lo,hi in moving)
    if apply:
        (ROOT/"game/data/orison_v2/domestic_furniture.json").write_text(json.dumps(dict(furniture,furniture=rows),separators=(",",":"))+"\n",encoding="utf-8")
        added=layout["anchors"][old_count:]
        if added:
            path=ROOT/"game/data/orison_v2_blockout.json";text=path.read_text(encoding="utf-8")
            start=text.index("[",text.index('"anchors"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
            extra=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+extra+"\n  "+text[end:],encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",cabinets=4,static_frame_triangles=336,runtime_panel_handle_triangles=192,
                 route_samples=samples,operator_approach_samples=approach_samples,domestic_door_sweeps=sweeps,slider_poses_checked=101,
                 source_scope="Separate dry prep/storage units; installed sinks, stands and appliances retained.",
                 limits="No inventory/cooking mechanic or persistence. Physics slider motion, interior targeting, body collisions, materials and lifecycle remain unverified.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(cabinets=4,furniture_total=len(rows),route_samples=samples,operator_approach_samples=approach_samples,applied=apply)))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true");build(parser.parse_args().apply)
