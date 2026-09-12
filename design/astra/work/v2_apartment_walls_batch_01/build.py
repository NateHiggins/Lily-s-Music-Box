"""Close missing owned edge intervals; source geometry audit, no engine launch."""
import argparse
import copy
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
TARGET = ROOT / "game/data/orison_v2_blockout.json"
SIDES = ("south", "north", "west", "east")
PREFIXES = ("F02_A_", "F02_B_", "F03_B_", "F04_B_")
PATCHES = {
    "F02_A_VESTIBULE": [("east", -1.35, -.6), ("east", .6, 1.35)],
    "F02_A_MAIN": [("east", -3.85, -1.35), ("east", 1.35, 3.1)],
    "F02_A_BATH": [("south", -7.55, -5.95)],
    "F02_A_BED": [("east", 7.85, 11.65)],
    "F02_B_MAIN": [("east", -4.2, .3)],
    "F02_B_KITCHEN": [("north", 9.5, 11.5)],
    "F04_B_VESTIBULE": [("east", -1.35, -.6), ("east", .6, 1.65)],
    "F04_B_MAIN": [("east", -3.85, -1.35), ("east", 1.65, 3.45)],
    "F04_B_ALCOVE_APPROACH": [("south", -9.05, -7.55)],
    "F04_B_BATH": [("south", -7.55, -5.95)],
    "F04_B_CLOSET": [("west", 6.05, 6.35)],
}


def edge(space, side):
    x0, z0, x1, z1 = space["rect"]
    fixed, start, end = {"west": (x0,z0,z1), "east": (x1,z0,z1),
                         "south": (z0,x0,x1), "north": (z1,x0,x1)}[side]
    return dict(owner=space["id"], level=space["level"], side=side,
                axis="z" if side in ("west","east") else "x", fixed=fixed, start=start, end=end)


def owned(layout):
    result=[]
    for space in layout["spaces"]:
        if space.get("open_shell"): continue
        result += [edge(space,side) for side in space.get("wall_sides", SIDES)]
        for extension in space.get("wall_extensions", []):
            result.append(dict(edge(space,extension["side"]), **extension, extension=True))
    return result


def aligned(a,b):
    return a["level"]==b["level"] and a["axis"]==b["axis"] and abs(a["fixed"]-b["fixed"])<1e-6


def subtract(start,end,intervals):
    cursor=start; result=[]
    for a,b in sorted(intervals):
        if b<=cursor or a>=end: continue
        if a>cursor+1e-6: result.append([cursor,min(end,a)])
        cursor=max(cursor,b)
    if cursor<end-1e-6: result.append([cursor,end])
    return result


def missing(layout):
    walls=owned(layout); result=[]
    for space in layout["spaces"]:
        if not space["id"].startswith(PREFIXES): continue
        for side in SIDES:
            e=edge(space,side)
            for a,b in subtract(e["start"],e["end"],[(w["start"],w["end"]) for w in walls if aligned(e,w)]):
                result.append(dict(e,start=a,end=b))
    return result


def apertures(layout,wall):
    result=[]
    for table in ("doors","openings","windows"):
        for record in layout.get(table,[]):
            if table=="windows":
                if record["space"]!=wall["owner"]: continue
            elif wall["owner"] not in record["connects"]: continue
            if record.get("axis",wall["axis"])!=wall["axis"]: continue
            along,fixed=(record["center"] if wall["axis"]=="x" else record["center"][::-1])
            if abs(fixed-wall["fixed"])>1e-6: continue
            lo=max(wall["start"],along-record["width"]/2)
            hi=min(wall["end"],along+record["width"]/2)
            if hi>lo+1e-6: result.append(dict(id=record["id"],start=lo,end=hi,sill=record.get("sill",0),height=record["height"]))
    return result


def audit_routes(layout,walls):
    spec=importlib.util.spec_from_file_location("door_geometry",OUT.parent/"v2_apartment_doors_batch_01/check.py")
    geometry=importlib.util.module_from_spec(spec);spec.loader.exec_module(geometry)
    solid=[]
    t=layout["dimensions"]["partition_wall"]/2
    for w in walls:
        # Any wall at body height remains an obstacle; windows have a sill.
        holes=[(a["start"],a["end"]) for a in apertures(layout,w) if a["sill"]==0 and a["height"]>=1.524]
        for a,b in subtract(w["start"],w["end"],holes):
            r=[a,w["fixed"]-t,b,w["fixed"]+t] if w["axis"]=="x" else [w["fixed"]-t,a,w["fixed"]+t,b]
            solid.append((w,geometry.rect_polygon(r)))
    spec=importlib.util.spec_from_file_location("fixture_geometry",OUT.parent/"v2_apartment_lighting_batch_01/build.py")
    fixture_geometry=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture_geometry)
    anchors={a["id"]:a for a in layout["anchors"]}
    obstacles=[]
    for r in json.loads((ROOT/"game/data/orison_v2/domestic_furniture.json").read_text())["furniture"]:
        a=anchors[r["id"]]
        for bounds in r.get("collision_boxes",[r["bounds"]]):
            obstacles.append((r["id"],a["level"],fixture_geometry.footprint(bounds,a)))
    for r in json.loads((ROOT/"game/data/orison_v2/domestic_fittings.json").read_text())["fittings"]:
        a,kind=anchors[r["id"]],r["kind"]
        if kind=="shower": bounds=[[-.3775,0,-.3775],[.3775,2.1,.3775]]
        elif kind=="sink" and r["properties"]["fixture"]=="bath_sink": bounds=[[-.33,0,-.26],[.33,1,.24]]
        elif kind=="sink": bounds=[[-.34,0,-.26],[.76,1.2,.25]]
        elif kind=="stove": bounds=[[-.35,0,-.37],[.35,1.25,.32]]
        else: bounds=[[-.38,0,-.38],[.38,1.3,.31]]
        obstacles.append((r["id"],a["level"],fixture_geometry.footprint(bounds,a)))
    envelopes={e["id"]:e for e in layout["envelopes"]}
    for table in json.loads((ROOT/"game/data/orison_v2/case_one_placement.json").read_text())["tables"]:
        e=envelopes[table["anchor"]]; r=e["rect"]
        x,z=(r[0]+r[2])/2+table["offset"][0],(r[1]+r[3])/2+table["offset"][2]
        obstacles.append((table["id"],e["level"],[x-table["width"]/2,z-table["depth"]/2,x+table["width"]/2,z+table["depth"]/2]))
    for w,polygon in solid:
        for identity,level,rect in obstacles:
            if w["level"]==level: assert not geometry.overlaps(polygon,geometry.rect_polygon(rect)),("new wall intersects furnishing",w,identity)
    routes=[]
    data=json.loads((ROOT/"game/tests/data/v2_apartment_door_routes.json").read_text())
    at=data["start"]
    for step in data["steps"]:
        if "walk" in step:
            routes.append(("F02",at,step["walk"],.38));at=step["walk"]
    for path in json.loads((ROOT/"game/data/orison_v2/mina_routine.json").read_text())["paths"]:
        for a,b in zip(path,path[1:]):
            if abs(a[2]-3.2)<1e-6 and abs(b[2]-3.2)<1e-6: routes.append(("F02",[a[1],a[3]],[b[1],b[3]],.30))
    # Existing source-reviewed case, Omar and Mae circulation spines.
    for level,path in [("F02",[[-9.2,1.4],[-10.5,1],[-12.4,.85],[-11.2,.85],[-11.1,1.7],[-10.5,2.5]]),
                       ("F03",[[12.5,-2.5],[12.5,-1.35],[13.65,-1.35],[12.5,-1.35],[12.6,-4.45],[14.2,-4.45],[14.2,-6.8]]),
                       ("F04",[[-6.65,0],[-13,0],[-13,4.7],[-9.8,4.7],[-9.8,6.9]])]:
        routes += [(level,a,b,.38) for a,b in zip(path,path[1:])]
    count=0
    for level,a,b,radius in routes:
        steps=max(1,math.ceil(math.dist(a,b)/.025))
        for step in range(steps+1):
            p=[a[i]+(b[i]-a[i])*step/steps for i in range(2)]
            for w,polygon in solid:
                if w["level"]==level: assert geometry.distance(p,polygon)>=radius,("new wall blocks route",w,p)
            count+=1
    return count


def build(apply=False):
    layout=json.loads(TARGET.read_text(encoding="utf-8")); original=copy.deepcopy(layout)
    baseline=copy.deepcopy(layout)
    for s in baseline["spaces"]:
        if s["id"] in PATCHES: s.pop("wall_extensions",None)
    before=missing(baseline)
    assert len(before)==15, before
    for space in layout["spaces"]:
        if space["id"] not in PATCHES: continue
        expected=[dict(side=s,start=a,end=b) for s,a,b in PATCHES[space["id"]]]
        assert "wall_extensions" not in space or space["wall_extensions"]==expected,("conflicting extensions",space["id"])
        space["wall_extensions"]=expected
    walls=owned(layout); added=[w for w in walls if w.get("extension")]
    assert len(added)==15
    for w in added:
        for other in walls:
            if w is not other and aligned(w,other):
                assert min(w["end"],other["end"])-max(w["start"],other["start"])<=1e-6,("duplicate wall",w,other)
    assert not missing(layout), missing(layout)
    unchanged=copy.deepcopy(layout)
    for s,old in zip(unchanged["spaces"],original["spaces"]):
        if "wall_extensions" not in old: s.pop("wall_extensions",None)
    assert unchanged==original,"unexpected semantic edits"
    samples=audit_routes(layout,added)
    if apply:
        # Replace only individual space records, retaining unrelated formatting.
        text=TARGET.read_text(encoding="utf-8")
        decoder=json.JSONDecoder(); start=text.index("[",text.index('"spaces"'))+1
        spans=[]; cursor=start
        while True:
            while text[cursor] in " \t\r\n,":cursor+=1
            if text[cursor]=="]":break
            record,length=decoder.raw_decode(text[cursor:]); end=cursor+length
            if record["id"] in PATCHES and "wall_extensions" not in record:
                value=next(s["wall_extensions"] for s in layout["spaces"] if s["id"]==record["id"])
                spans.append((end-1,', "wall_extensions": '+json.dumps(value,separators=(",",":"))))
            cursor=end
        for end,addition in reversed(spans):text=text[:end]+addition+text[end:]
        TARGET.write_text(text,encoding="utf-8")
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",rooms=26,
                 missing_intervals_before=len(before),missing_intervals_after=0,
                 added_wall_intervals=[dict(w,apertures=apertures(layout,w)) for w in added],
                 route_samples=samples,limits="Owned boundary coverage only. Authored apertures retained. Source routes checked only against added wall intervals; runtime physics, visual seams and light containment remain unverified.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in receipt.items() if k!="added_wall_intervals"}))


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--apply",action="store_true")
    build(parser.parse_args().apply)
