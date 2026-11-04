"""Project reviewed native edge construction to runtime data; no geometry changes."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[1]

def read(relative):return json.loads((ROOT/relative).read_text(encoding='utf-8'))
def digest(relative):
 p=ROOT/relative;b=p.read_bytes()
 return hashlib.sha256(b if p.suffix in ['.blend','.glb','.png'] else b.replace(b'\r\n',b'\n')).hexdigest()
def main():
 plan_path='art/data/city_ground_edges/source_plan.json';report_path='art/blender/city_ground_edges_construction.json'
 producer='art/blender/scripts/build_city_ground_edges.py';native='art/blender/city_ground_edges.blend'
 plan=read(plan_path);report=read(report_path)
 assert report['evidence_class']=='INERT' and report['failures']==[]
 assert plan['frame']==report['frame']=='ORISON_V2_BUILDING_FRAME'
 assert digest(plan_path)==report['plan_sha256'] and digest(producer)==report['producer_sha256']
 assert digest(native)==report['native_sha256']
 assert [r['level'] for r in report['levels']]==[0,1]
 near,low=report['levels'];assert low['triangles']<near['triangles']
 for r in [near,low]:
  assert digest(r['asset'])==r['sha256'] and len(r['closed_stocks'])==36
 for name,expected in report['source_bindings'].items():assert digest(name)==expected,('Native source changed',name)
 recipe=dict(schema=1,frame=plan['frame'],asset='res://'+near['asset'].removeprefix('game/'),lower_asset='res://'+low['asset'].removeprefix('game/'),part=near['part'],lower_part=low['part'],lod_error_m=plan['lod_error_m'],finish=plan['finish'])
 projection='game/data/orison_v2/exterior/city_ground_edges.json';(ROOT/projection).write_text(json.dumps(recipe,indent=2)+'\n',encoding='utf-8',newline='\n')
 fixture=dict(report);fixture['source_bindings']=dict(report['source_bindings'])
 sys.path.insert(0,str(ROOT/'art/blender/scripts'))
 from city_ground_apron_geometry import exported_bounds,relief_height
 fixture['exported_bounds']={r['asset']:exported_bounds((ROOT/r['asset']).read_bytes()) for r in [near,low]}
 relief=read('art/data/city_ground_apron/source_plan.json')['relief']
 fixture['access_stations_building']=[[x,relief_height(x,z,-.02,relief),z] for x,z in [(-322.1,-18.),(-322.1,18.),(-318.8,18.),(-318.8,-18.)]]
 for name in [plan_path,report_path,producer,native,near['asset'],low['asset'],projection,'game/scripts/building/orison_v2_city_ground_edges.gd','tools/prepare_v2_city_ground_edges.py']:
  fixture['source_bindings'][name]=digest(name)
 (ROOT/'game/tests/fixtures/orison_city_ground_edges.json').write_text(json.dumps(fixture,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('CITY GROUND EDGE PROJECTION: complete near/lower bodies and existing concrete recipe; native/runtime acceptance remains separate')
if __name__=='__main__':main()
