"""Add two source-owned roof fixtures/controls using accepted native lamp stock.

The existing circuit controller owns switching. Concealed branch distribution
is an explicit remaining fabrication item; this tool does not counterfeit a
modeled physical connection to the roof junction.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
fixtures = [
    {"id":"ROOF_PUBLIC_PLANT_LT", "room":"ROOF_PUBLIC_CORE", "kind":"cage_bulb",
     "properties":{"range_clamp":6.5,"energy_scale":2.0}},
    {"id":"ROOF_SERVICE_PLANT_LT", "room":"ROOF_SERVICE_CORE", "kind":"cage_bulb",
     "properties":{"range_clamp":6.5,"energy_scale":2.0}},
]
switches = [{"id":"ROOF_PUBLIC_PLANT_SWITCH","room":"ROOF_PUBLIC_CORE"},
            {"id":"ROOF_SERVICE_PLANT_SWITCH","room":"ROOF_SERVICE_CORE"}]
anchors = [
    {"id":"ROOF_PUBLIC_PLANT_LT","level":"ROOF","space":"ROOF_PUBLIC_CORE","position":[.2,2.7,-.4],"yaw":0,"kind":"fixture"},
    {"id":"ROOF_SERVICE_PLANT_LT","level":"ROOF","space":"ROOF_SERVICE_CORE","position":[11.9,2.7,2.3],"yaw":0,"kind":"fixture"},
    {"id":"ROOF_PUBLIC_PLANT_SWITCH","level":"ROOF","space":"ROOF_PUBLIC_CORE","position":[-2.01,1.2,.8],"yaw":1.5707963267948966,"kind":"interaction"},
    {"id":"ROOF_SERVICE_PLANT_SWITCH","level":"ROOF","space":"ROOF_SERVICE_CORE","position":[9.685,1.2,4.0],"yaw":1.5707963267948966,"kind":"interaction"},
]
def save(path, value):
    path.write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8",newline="\n")

source_path=ROOT/"art/data/orison_v2/roof_source.json"
source=json.loads(source_path.read_text(encoding="utf-8"))
owned={r["id"] for r in anchors}
source["records"]["anchors"]=[r for r in source["records"].get("anchors",[]) if r["id"] not in owned]+anchors
save(source_path,source)
from build_v2_roof import project,render
layout_path=ROOT/"game/data/orison_v2_blockout.json"
original=layout_path.read_text(encoding="utf-8")
layout_path.write_text(render(original,project(json.loads(original),source)),encoding="utf-8",newline="\n")
save(ROOT/"game/data/orison_v2/roof_plant_lighting.json",{"fixtures":fixtures,"switches":switches})
for name in ["art/data/fixed_lighting/source_plan.json","game/data/orison_v2/fixed_lighting.json"]:
    path=ROOT/name;data=json.loads(path.read_text(encoding="utf-8"))
    data["instances"]=[r for r in data["instances"] if r["id"] not in {f["id"] for f in fixtures}]
    data["instances"] += [{"id":f["id"],"variant":"cage_bulb_rise300"} for f in fixtures]
    save(path,data)
print("Two roof cage fixtures and native switches; original lamp geometry reused")
