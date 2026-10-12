"""Bind unchanged passive stock geometry to the reviewed resident-storage placement plan."""
from pathlib import Path
import copy,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
def digest(data):return hashlib.sha256(data.replace(b"\r\n",b"\n")).hexdigest()
def main():
 import argparse
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("--base",required=True);p.add_argument("--out",type=Path,required=True);p.add_argument("--apply",action="store_true");a=p.parse_args()
 layout="game/data/orison_v2_blockout.json";before=subprocess.check_output(["git","show",a.base+":"+layout],cwd=ROOT);after=(ROOT/layout).read_bytes();old=json.loads(before);new=json.loads(after)
 plan=json.loads((ROOT/"art/data/resident_storage/source_plan.json").read_text(encoding="utf-8"));expected=copy.deepcopy(old)
 expected["spaces"].insert(0,plan["extension"]);expected["openings"].insert(0,plan["extension_opening"])
 for room in expected["spaces"]:
  if room["id"]=="B1_RESIDENT_STORAGE":room["purpose"]="eighteen dry resident storage cages, including north-end bay, with central and east aisles"
 for stock in plan["stock"]:
  anchor=next(r for r in expected["anchors"] if r["id"]==stock["id"])
  assert anchor["position"]==stock["old_position"],stock["id"]
  anchor.update(position=stock["position"],yaw=stock["yaw"],space=stock["space"])
 assert new==expected,"Unrelated layout edit refused"
 asset="game/assets/props/domestic_objects.glb";original=subprocess.check_output(["git","show",a.base+":"+asset],cwd=ROOT);assert original==(ROOT/asset).read_bytes(),"Passive native geometry changed"
 paths=["art/blender/domestic_objects_construction.json","game/tests/fixtures/orison_domestic_objects.json"];pending=[]
 for path in paths:
  raw=(ROOT/path).read_bytes();data=json.loads(raw)
  assert data["source_bindings"][layout]==digest(before),(path,"pre-existing provenance drift")
  data["source_bindings"][layout]=digest(after);pending.append((ROOT/path,(json.dumps(data,indent=2)+"\n").encode()))
 if a.apply:
  for path,data in pending:path.write_bytes(data)
 report={"evidence_class":"INERT","base":a.base,"applied":a.apply,"stock_models_unchanged_sha256":hashlib.sha256(original).hexdigest(),"stock_pose_count":len(plan["stock"]),"new_space":plan["extension"]["id"],"new_opening":plan["extension_opening"]["id"],"all_other_layout_values_identical":True,"updated":[str(p.relative_to(ROOT)) for p,_ in pending],"scope":"Only unchanged native passive-stock provenance. Relocated installation proof is the new Blender fit review and composed Godot capture/walking, not this rebind. Other historical fixtures are not touched."}
 a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8",newline="\n")
 print("Two passive-stock provenance files; sixteen declared stock poses; no native passive mesh edits")
if __name__=="__main__":main()
