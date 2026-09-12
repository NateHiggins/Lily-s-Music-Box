"""Source sweep/route review, without Godot. Not a physics acceptance test."""
import importlib.util
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
NEW = ["F02_DOOR_02","F02_A_HALL_DOOR","F02_A_BATH_DOOR","F02_A_BED_DOOR",
       "F02_B_ENTRY_DOOR","F02_B_KITCHEN_DOOR","F02_B_BED_DOOR","F02_B_BATH_DOOR"]


def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))


def rotate(p,angle):
    c,s = math.cos(angle),math.sin(angle)
    return [c*p[0]+s*p[1],-s*p[0]+c*p[1]]


def leaf_polygon(door,swing_out,degrees):
    right = door["hinge"] == "right"
    outward = not swing_out if right else swing_out
    offset = -.026 if outward else .026
    angle = math.radians(-degrees if outward else degrees)
    w = door["width"]
    result = []
    for p in [[.01,offset-.022],[w-.01,offset-.022],[w-.01,offset+.022],[.01,offset+.022]]:
        p = rotate(p,angle)
        p[1] -= offset
        p = rotate(p,math.pi if right else 0)
        p[0] += w/2 if right else -w/2
        p = rotate(p,door["yaw"])
        result.append([p[i]+door["center"][i] for i in range(2)])
    return result


def rect_polygon(r):
    return [[r[0],r[1]],[r[2],r[1]],[r[2],r[3]],[r[0],r[3]]]


def overlaps(a,b):
    for polygon in [a,b]:
        for p,q in zip(polygon,polygon[1:]+polygon[:1]):
            axis = [q[1]-p[1],p[0]-q[0]]
            aa = [sum(v[i]*axis[i] for i in range(2)) for v in a]
            bb = [sum(v[i]*axis[i] for i in range(2)) for v in b]
            if max(aa) <= min(bb)+1e-9 or max(bb) <= min(aa)+1e-9: return False
    return True


def distance(p,polygon):
    nearest = math.inf
    crosses = []
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        dx,dz=b[0]-a[0],b[1]-a[1]
        crosses.append(dx*(p[1]-a[1])-dz*(p[0]-a[0]))
        t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
        nearest=min(nearest,math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz))
    return 0 if all(x>=0 for x in crosses) or all(x<=0 for x in crosses) else nearest


def main():
    layout=load("game/data/orison_v2_blockout.json")
    doors={d["id"]:d for d in layout["doors"]}
    text=(ROOT/"game/scripts/building/orison_v2_domestic_doors.gd").read_text(encoding="utf-8")
    specs={identity:outward=="true" for identity,outward in re.findall(r'"([A-Z0-9_]+)": \{"kind": "[a-z_]+", "swing_out": (true|false)',text)}
    detailed={d["id"] for d in doors.values() if any(any(s.startswith(p) for p in ["F02_A_","F02_B_","F03_B_","F04_B_"]) for s in d["connects"])}
    assert detailed.issubset(specs) and len(detailed)==16
    path=ROOT/"design/astra/work/v2_apartment_lighting_batch_01/build.py"
    spec=importlib.util.spec_from_file_location("geometry",path)
    geometry=importlib.util.module_from_spec(spec); spec.loader.exec_module(geometry)
    anchors={a["id"]:a for a in layout["anchors"]}
    obstacles=[]
    for r in load("game/data/orison_v2/domestic_furniture.json")["furniture"]:
        a=anchors[r["id"]]
        obstacles.append((r["id"],a["level"],geometry.footprint(r["bounds"],a)))
    for r in load("game/data/orison_v2/domestic_fittings.json")["fittings"]:
        a,kind=anchors[r["id"]],r["kind"]
        if kind=="shower": bounds=[[-.3775,0,-.3775],[.3775,2.1,.3775]]
        elif kind=="sink" and r["properties"]["fixture"]=="bath_sink": bounds=[[-.33,0,-.26],[.33,1,.24]]
        elif kind=="sink": bounds=[[-.34,0,-.26],[.76,1.2,.25]]
        elif kind=="stove": bounds=[[-.35,0,-.37],[.35,1.25,.32]]
        else: bounds=[[-.38,0,-.38],[.38,1.3,.31]]
        obstacles.append((r["id"],a["level"],geometry.footprint(bounds,a)))
    envelopes={e["id"]:e for e in layout["envelopes"]}
    for table in load("game/data/orison_v2/case_one_placement.json")["tables"]:
        e=envelopes[table["anchor"]]; r=e["rect"]
        x,z=(r[0]+r[2])/2+table["offset"][0],(r[1]+r[3])/2+table["offset"][2]
        obstacles.append((table["id"],e["level"],[x-table["width"]/2,z-table["depth"]/2,x+table["width"]/2,z+table["depth"]/2]))
    results=[]
    for identity in NEW:
        door=doors[identity]; cloud=[]
        for step in range(201):
            polygon=leaf_polygon(door,specs[identity],step*.5); cloud+=polygon
            for other,level,r in obstacles:
                if level==door["level"]: assert not overlaps(polygon,rect_polygon(r)),("leaf hits fixture",identity,step*.5,other)
        results.append(dict(id=identity,swing=door["swing"],hinge=door["hinge"],sweep_rect=[min(p[0] for p in cloud),min(p[1] for p in cloud),max(p[0] for p in cloud),max(p[1] for p in cloud)]))
    # Leave-open behavior must not trap Mina on her existing home graph.
    samples=0
    for path in load("game/data/orison_v2/mina_routine.json")["paths"]:
        for a,b in zip(path,path[1:]):
            if abs(a[2]-3.2)>1e-6 or abs(b[2]-3.2)>1e-6: continue
            steps=max(1,math.ceil(math.hypot(a[1]-b[1],a[3]-b[3])/.025))
            for step in range(steps+1):
                p=[a[i]+(b[i]-a[i])*step/steps for i in [1,3]]
                for identity in NEW:
                    assert distance(p,leaf_polygon(doors[identity],specs[identity],100)) >= .30, ("open door blocks resident graph",identity,p)
                samples+=1
    route=load("game/tests/data/v2_apartment_door_routes.json")
    at=route["start"]; opened=set(); used=set(); player_samples=0
    for step in route["steps"]:
        if "walk" in step:
            target=step["walk"]
            count=max(1,math.ceil(math.dist(at,target)/.025))
            for n in range(count+1):
                p=[at[i]+(target[i]-at[i])*n/count for i in range(2)]
                for identity in NEW:
                    assert distance(p,leaf_polygon(doors[identity],specs[identity],100 if identity in opened else 0))>=.38, ("player route hits leaf",identity,p)
                for identity,level,r in obstacles:
                    if level=="F02": assert geometry.distance(p,r)>=.38, ("player route hits furniture",identity,p)
                player_samples+=1
            at=target
        else:
            identity=step.get("open",step.get("close"))
            for n in range(201):
                assert distance(at,leaf_polygon(doors[identity],specs[identity],n*.5))>=.38, ("player stands in sweep",identity,at)
            if "open" in step:
                assert identity not in opened
                opened.add(identity); used.add(identity)
            else:
                assert identity in opened
                opened.remove(identity)
    assert used==set(NEW)
    OUT.mkdir(parents=True,exist_ok=True)
    receipt=dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",apartment_doors=len(detailed),new_leaves=results,resident_route_samples=samples,player_route_samples=player_samples,
                 limits="Sampled leaf collider only; jamb/hardware clearance, actual motion, player/NPC targeting, acoustics and persistence require runtime checks.")
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(receipt))


if __name__=="__main__": main()
