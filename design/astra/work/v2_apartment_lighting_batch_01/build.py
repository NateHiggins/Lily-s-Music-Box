"""Fill the detailed apartment circuit roster without launching an engine.

--apply adds records; conflicting existing identities fail before writes.
Geometric checks are source estimates, not physics or visual acceptance.
"""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
PI = math.pi
# Room, fixture x/z, switch x/z, inward-facing yaw, stance x/z, range, gain.
PLACEMENTS = [
    ("F02_A_VESTIBULE", [-6.6,0], [-7,1.26], 0, [-7,.45], 3,1.05),
    ("F02_A_KITCHEN", [-12.9,4.7], [-10.95,3.19], PI, [-10.95,4.15], 5.2,1.25),
    ("F02_A_PRIVATE_HALL", [-9.6,5.75], [-10.16,5.6], -PI/2, [-9.5,5.6], 4,1.25),
    ("F02_A_BATH", [-7.4,4.35], [-6.04,4.45], PI/2, [-7.25,4.45], 4,1.05),
    ("F02_A_BED", [-12.8,9.25], [-10.34,6.4], PI/2, [-11.2,6.7], 5.5,1.25),
    ("F02_B_VESTIBULE", [10.5,-2.5], [10.45,-1.24], 0, [10.45,-2.15], 3,1.05),
    ("F02_B_MAIN", [13.6,-1.75], [11.59,-.8], -PI/2, [12.5,-.8], 6.5,1.5),
    ("F02_B_KITCHEN", [11.15,-6.3], [12.71,-7], PI/2, [11.85,-7], 5,1.25),
    ("F02_B_BED", [11.15,-10.35], [12.71,-9.75], PI/2, [11.85,-9.75], 5,1.25),
    ("F02_B_PRIVATE_HALL", [14.15,-6.75], [15.56,-6.7], PI/2, [14.65,-6.7], 4.5,1.25),
    ("F02_B_BATH", [14.2,-10.8], [12.89,-10.65], -PI/2, [13.7,-10.65], 4,1.05),
    ("F03_B_VESTIBULE", [10.5,-2.5], [10.45,-1.24], 0, [10.45,-2.15], 3,1.05),
    ("F03_B_PRIVATE_HALL", [14.3,-7.5], [15.56,-7.7], PI/2, [14.65,-7.7], 4.5,1.25),
    ("F04_B_VESTIBULE", [-6.6,.15], [-7,1.56], 0, [-7,.7], 3,1.05),
    ("F04_B_ALCOVE_APPROACH", [-9.05,7.3], [-9.15,8.16], 0, [-9.15,7.3], 3.5,1.05),
]


def load(path):
    return json.loads((ROOT/path).read_text(encoding="utf-8"))


def merge(old, additions):
    indexed = {r["id"]: r for r in old}
    assert len(indexed) == len(old), "duplicate source identity"
    result = list(old)
    for row in additions:
        if row["id"] in indexed:
            assert indexed[row["id"]] == row, ("conflicting identity", row["id"])
        else:
            result.append(row)
            indexed[row["id"]] = row
    return result


def footprint(bounds, anchor):
    low, high = bounds
    x, _, z = anchor["position"]
    c, s = math.cos(anchor["yaw"]), math.sin(anchor["yaw"])
    corners = [(x+c*a+s*b,z-s*a+c*b) for a in [low[0],high[0]] for b in [low[2],high[2]]]
    return [min(p[0] for p in corners),min(p[1] for p in corners),max(p[0] for p in corners),max(p[1] for p in corners)]


def distance(point, rect):
    return math.hypot(max(rect[0]-point[0],0,point[0]-rect[2]),max(rect[1]-point[1],0,point[1]-rect[3]))


def supporting_wall(layout, room, plate, yaw):
    # Blockout outlines use partition thickness. A neighbour may own this wall.
    inward = [-math.sin(yaw), -math.cos(yaw)]
    wall = [plate[i] - .09*inward[i] for i in range(2)]
    axis = "z" if abs(inward[0]) > .5 else "x"
    fixed_idx, along_idx = (0,1) if axis == "z" else (1,0)
    candidates = []
    for space in layout["spaces"]:
        if space["level"] != room["level"] or space.get("open_shell",False): continue
        r = space["rect"]
        for side, fixed, lo, hi in [("west",r[0],r[1],r[3]),("east",r[2],r[1],r[3])] if axis == "z" else [("south",r[1],r[0],r[2]),("north",r[3],r[0],r[2])]:
            if side not in space.get("wall_sides",["north","south","west","east"]): continue
            if abs(fixed-wall[fixed_idx]) > 1e-6 or not lo+.08 < wall[along_idx] < hi-.08: continue
            cuts = []
            for cut in layout["doors"] + layout.get("openings",[]):
                if space["id"] in cut["connects"] and abs(cut["center"][fixed_idx]-fixed) < 1e-6:
                    cuts.append(cut)
            for cut in layout.get("windows",[]):
                if cut["space"] == space["id"] and cut["axis"] == axis and cut["sill"] < 1.24 and cut["sill"]+cut["height"] > 1:
                    cuts.append(cut)
            if any(abs(cut["center"][along_idx]-wall[along_idx]) < cut["width"]/2+.08 for cut in cuts): continue
            candidates.append(space["id"]+":"+side)
    assert candidates, ("switch lacks uninterrupted wall",room["id"],plate)
    return candidates


def build(apply=False):
    layout = load("game/data/orison_v2_blockout.json")
    lighting = load("game/data/orison_v2/room_lighting.json")
    spaces = {r["id"]:r for r in layout["spaces"]}
    indexed = {a["id"]:a for a in layout["anchors"]}
    obstacles = []
    for record in load("game/data/orison_v2/domestic_furniture.json")["furniture"]:
        a = indexed[record["id"]]
        obstacles.append((record["id"],a["space"],footprint(record["bounds"],a)))
    for record in load("game/data/orison_v2/domestic_fittings.json")["fittings"]:
        kind, a = record["kind"], indexed[record["id"]]
        if kind == "shower": bounds=[[-.3775,0,-.3775],[.3775,2.1,.3775]]
        elif kind == "sink" and record["properties"]["fixture"] == "bath_sink": bounds=[[-.33,0,-.26],[.33,1,.24]]
        elif kind == "sink": bounds=[[-.34,0,-.26],[.76,1.2,.25]]
        elif kind == "stove": bounds=[[-.35,0,-.37],[.35,1.25,.32]]
        else: bounds=[[-.38,0,-.38],[.38,1.3,.31]]
        obstacles.append((record["id"],a["space"],footprint(bounds,a)))
    anchors, fixtures, switches, checks = [], [], [], []
    for room, lamp, plate, yaw, stance, radius, gain in PLACEMENTS:
        space, rect = spaces[room], spaces[room]["rect"]
        assert rect[0] < lamp[0] < rect[2] and rect[1] < lamp[1] < rect[3]
        wall_margin = float(layout["dimensions"]["partition_wall"])/2 + .33
        assert rect[0]+wall_margin < stance[0] < rect[2]-wall_margin and rect[1]+wall_margin < stance[1] < rect[3]-wall_margin, room
        reach = math.sqrt((plate[0]-stance[0])**2+(plate[1]-stance[1])**2+(1.41-1.12)**2)
        assert reach < 1.6, (room,reach)
        assert (stance[0]-plate[0])*-math.sin(yaw)+(stance[1]-plate[1])*-math.cos(yaw) > .4, room
        walls = supporting_wall(layout,space,plate,yaw)
        clearance = [(identity,distance(stance,r)) for identity,owner,r in obstacles if owner == room]
        assert all(d >= .38 for _,d in clearance), (room,clearance)
        kind = "pendant_shade" if room.endswith("_MAIN") else "flush_dome"
        fixture_id, switch_id = room+"_LT_"+kind.upper(), room+"_SWITCH"
        fixtures.append(dict(id=fixture_id,room=room,kind=kind,properties=dict(range_clamp=radius,energy_scale=gain)))
        switches.append(dict(id=switch_id,room=room))
        facing = math.atan2(-(plate[0]-stance[0]),-(plate[1]-stance[1]))
        for identity,p,y,k in [(fixture_id,[lamp[0],3,lamp[1]],0,"fixture"),(switch_id,[plate[0],1.12,plate[1]],yaw,"fixture"),(switch_id+"_STANCE",[stance[0],0,stance[1]],facing,"clearance")]:
            anchors.append(dict(id=identity,level=space["level"],space=room,position=p,yaw=y,kind=k))
        checks.append(dict(room=room,wall_owners=walls,eye_to_switch_m=reach,obstacle_clearances_m=dict(clearance)))
    merged_anchors = merge(layout["anchors"],anchors)
    output = dict(lighting,fixtures=merge(lighting["fixtures"],fixtures),switches=merge(lighting["switches"],switches))
    apartment_rooms = {s for s in spaces if any(s.startswith(p) for p in ["F02_A_","F02_B_","F03_B_","F04_B_"])}
    assert len(apartment_rooms) == 26
    for room in apartment_rooms:
        assert sum(r["room"]==room for r in output["switches"]) == 1, room
        assert sum(r["room"]==room and r["kind"]!="lamp" for r in output["fixtures"]) == 1, room
    if apply:
        (ROOT/"game/data/orison_v2/room_lighting.json").write_text(json.dumps(output,indent=2)+"\n",encoding="utf-8")
        added = merged_anchors[len(layout["anchors"]):]
        if added:
            path = ROOT/"game/data/orison_v2_blockout.json"
            text = path.read_text(encoding="utf-8")
            start = text.index("[",text.index('"anchors"'))
            _, length = json.JSONDecoder().raw_decode(text[start:])
            end = start+length-1
            rows = ",\n".join("    "+json.dumps(a,separators=(",",":")) for a in added)
            path.write_text(text[:end].rstrip()+",\n"+rows+"\n  "+text[end:],encoding="utf-8")
    receipt = dict(status="SOURCE_PASS_RUNTIME_PENDING",godot="NOT_RUN",fixtures_added=len(fixtures),switches_added=len(switches),anchors_added=len(anchors),apartment_rooms_with_circuits=sorted(apartment_rooms),source_checks=checks,
                   limits="Door sweep review is an estimate; physical targeting, light appearance, budgets, persistence and lifecycle require runtime validation.")
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"fixtures":len(fixtures),"switches":len(switches),"anchors":len(anchors),"rooms_with_circuits":len(apartment_rooms),"applied":apply}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply",action="store_true")
    build(parser.parse_args().apply)
