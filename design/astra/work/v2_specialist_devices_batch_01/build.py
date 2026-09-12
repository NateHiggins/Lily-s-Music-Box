"""Place both remaining specialist desktop devices using actual support tops."""
import argparse
import ast
import json
import math
from pathlib import Path
import zlib

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
PLACEMENTS=[("2A_deck","2A_cof",[0,.3838806653817981,0]),
            ("3B_radio","3B_tools0",[0,1.822,-.035])]


def module(path,name):
    import importlib.util
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def load(path):return json.loads((ROOT/path).read_text(encoding="utf-8"))


def build(apply=False):
    previous=module("design/astra/work/v2_apartment_batches_01/build.py","device_source")
    geometry=module("design/astra/work/v2_storage_tables_boards_batch_01/build.py","device_geometry")
    merge=module("design/astra/work/v2_apartment_lighting_batch_01/build.py","device_merge")
    contact=module("design/astra/work/v2_surface_props_batch_01/build.py","device_contact")
    original=load("game/data/building_layout.json")
    records={r["id"]:r for floor in original["floors"] for r in floor.get("furniture",[])}
    tree=ast.parse((ROOT/previous.SOURCE).read_text(encoding="utf-8"));selected=[]
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=="MeshBuf":
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in previous.METHODS];selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=="Frame":selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in {"asm_reeldeck","asm_radio"}:selected.append(node)
    ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=selected,type_ignores=[]),previous.SOURCE,"exec"),ns)
    layout=load("game/data/orison_v2_blockout.json");old_count=len(layout["anchors"])
    furniture=load("game/data/orison_v2/domestic_furniture.json");indexed={a["id"]:a for a in layout["anchors"]}
    by_id={r["id"]:r for r in furniture["furniture"]}; additions=[];anchors=[];checks=[]
    for identity,support,p in PLACEMENTS:
        r=previous.furniture_record(identity,records,ns);a=indexed[support];c,s=math.cos(a["yaw"]),math.sin(a["yaw"])
        position=[a["position"][0]+c*p[0]+s*p[2],a["position"][1]+p[1],a["position"][2]-s*p[0]+c*p[2]]
        # Receiver's cabinet base supports its weight; its tuning knob can
        # project beyond the shelf edge without requiring support under a knob.
        base=[[-.19,0,-.11],[.19,.28,.11]] if identity=="3B_radio" else r["bounds"]
        footprint=merge.footprint(base,dict(position=p,yaw=0))
        for x in [footprint[0],footprint[2]]:
            for z in [footprint[1],footprint[3]]:assert contact.on_surface(by_id[support],[x,z],p[1]),("device lacks visible support",identity,x,z)
        if r["kind"]=="radio":
            r["mechanism"]={"id":identity,"asm":"radio"}
            r["bounds"]=[[-.24,-.03,-.19],[.24,.31,.15]] # shared control/body envelope
        r["support_source"]={"id":support,"position":p}
        additions.append(r)
        anchors.append(dict(id=identity,level=a["level"],space=a["space"],position=position,yaw=a["yaw"],kind="furniture"))
        checks.append(dict(id=identity,support=support,height=p[1],kind=r["kind"]))
    layout["anchors"]=merge.merge(layout["anchors"],anchors)
    rows=merge.merge(furniture["furniture"],additions);indexed.update({a["id"]:a for a in anchors})
    obstacles=geometry.obstacles(layout,rows)
    for r in additions:
        a=indexed[r["id"]];v=geometry.volume(r["bounds"],a)
        for other,level,b in obstacles:
            if level==a["level"] and other not in [r["id"],r["support_source"]["id"]]:assert not geometry.overlap(v,b),("device overlap",r["id"],other)
    # Specialist receiver is reached from the existing equipment-shelf stance.
    radio=indexed["3B_radio"];stance=indexed["3B_tools0_STANCE"]["position"]
    eye=[stance[0],1.41,stance[2]];target=[radio["position"][0],radio["position"][1]+.14,radio["position"][2]]
    assert math.dist(eye,target)<2.1
    for n in range(101):
        p=[eye[i]+(target[i]-eye[i])*n/100 for i in range(3)]
        for other,level,b in obstacles:
            if level==radio["level"] and other!="3B_radio":assert not all(b[i]<p[i]<b[i+3] for i in range(3)),("radio sightline blocked",other,p)
    if apply:
        (ROOT/"game/data/orison_v2/domestic_furniture.json").write_text(json.dumps(dict(furniture,furniture=rows),separators=(",",":"))+"\n",encoding="utf-8")
        added=layout["anchors"][old_count:]
        if added:
            path=ROOT/"game/data/orison_v2_blockout.json";text=path.read_text(encoding="utf-8")
            start=text.index("[",text.index('"anchors"'));_,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
            extra=",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+extra+"\n  "+text[end:],encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",devices=checks,
                 triangles=sum(len(s["vertices"])//9 for r in additions for s in r["surfaces"]),radio_target_distance_m=math.dist(eye,target),
                 limits="Native radio interaction/audio plus fixed reel-deck geometry. No reel-deck playback or recording behavior invented. Support colliders overlap the native radio base and deck by their pre-existing coarse top margins. Engine targeting/audio/lifetime/appearance pending.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(dict(devices=2,furniture_total=len(rows),radio_target_distance_m=math.dist(eye,target),applied=apply)))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true");build(parser.parse_args().apply)
