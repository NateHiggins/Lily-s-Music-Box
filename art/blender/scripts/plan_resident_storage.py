"""Author a dimensioned 18-bay storage plan from existing identities and stock.
The compact north-end alcove avoids narrowing the protected east aisle.
"""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
layout=json.loads((ROOT/"game/data/orison_v2_blockout.json").read_text(encoding="utf-8"))
units=["1A","1D","2A","2B","2C","3A","3B","3D","4A","4B","4C","4D","5A","5B","5C","6A","6B","6C"]
rows=[]
for index,unit in enumerate(units[:8]):
 left=-9.85+index*1.56+(1.05 if index>=2 else 0)
 rows.append({"unit":unit,"row":"south","left":round(left,5),"right":round(left+1.56,5),"rear":3.94,"front":6.10,"front_direction":1,"space":"B1_RESIDENT_STORAGE"})
for index,unit in enumerate(units[9:]):
 left=-9.85+index*1.56
 rows.append({"unit":unit,"row":"north","left":round(left,5),"right":round(left+1.56,5),"rear":9.41,"front":7.25,"front_direction":-1,"space":"B1_RESIDENT_STORAGE"})
rows.append({"unit":"4A","row":"alcove","left":3.62,"right":5.18,"rear":11.72,"front":9.56,"front_direction":-1,"space":"B1_STORAGE_NORTH_BAY"})
assert len(rows)==18 and {r["unit"] for r in rows}==set(units)
for row in rows:
 row["clear_fixed_width"]=round(row["right"]-row["left"]-.06,5)
 row["clear_fixed_depth"]=round(abs(row["rear"]-row["front"])-.06,5)
 assert row["clear_fixed_width"]>=1.5 and row["clear_fixed_depth"]>=2.1
 row["approach"]=[round((row["left"]+row["right"])/2+.025,5),0,6.675 if row["row"]!="alcove" else 8.9]
 row["inside"]=[row["approach"][0],0,round((row["front"]+row["rear"])/2,5)]
plan={"evidence_class":"INERT","classification":"ADAPTATION","anchor":"B1_STORAGE_BAYS","floor_y":-3.2,"asset":"res://assets/props/resident_storage.glb","bay_units":units,"bays":rows,"clearances":{"central_aisle":round(7.25-6.10-.06,5),"east_aisle":round(5.34-(4.19+.03),5),"wet_stack_gap":{"left":-6.73,"right":-5.68,"riser_rect":[-6.4,3.1,-5.95,6.35]}},"extension":{"id":"B1_STORAGE_NORTH_BAY","level":"B1","rect":[3.45,9.5,5.4,11.85],"class":"service","purpose":"one dry resident storage cage at the north end of the existing aisle","wall_sides":["north","west","east"]},"extension_opening":{"id":"B1_STORAGE_NORTH_BAY_OPENING","level":"B1","center":[4.4,9.5],"axis":"x","width":1.2,"height":2.4,"connects":["B1_RESIDENT_STORAGE","B1_STORAGE_NORTH_BAY"]},"material_keys":["timber","iron_neutral"],"gate_state":"original open/folded fabric; no new keys, inventory or quests","stock":[],"source_layout_sha256":hashlib.sha256((ROOT/"game/data/orison_v2_blockout.json").read_bytes().replace(b"\r\n",b"\n")).hexdigest()}
assert plan["clearances"]["central_aisle"]>=1.05 and plan["clearances"]["east_aisle"]>=1.05
for anchor in layout["anchors"]:
 if not anchor["id"].startswith("B1_bay_"):continue
 unit=anchor["id"].split("_")[2];bay=next(r for r in rows if r["unit"]==unit)
 plan["stock"].append({"id":anchor["id"],"unit":unit,"space":bay["space"],"yaw":anchor["yaw"],"old_position":anchor["position"],"position":[round((bay["left"]+bay["right"])/2+.05,5),0,anchor["position"][2]],"row":bay["row"],"rear":bay["rear"]})
(ROOT/"art/data/resident_storage/source_plan.json").write_text(json.dumps(plan,indent=2)+"\n",encoding="utf-8",newline="\n")
print("18 bays, 1.50 x 2.10 fixed-panel clear dimensions; central/east aisles",plan["clearances"]["central_aisle"],plan["clearances"]["east_aisle"])
