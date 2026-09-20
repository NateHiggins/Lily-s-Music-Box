"""Place the authored rubber plant and verify this six-home equipment batch.

Source geometry only; no engine or Blender execution.
"""
import argparse
import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import zlib

ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='0b3b240'
FURNITURE='game/data/orison_v2/domestic_furniture.json'
LAYOUT='game/data/orison_v2_blockout.json'

def load(path):return json.loads((ROOT/path).read_text(encoding="utf-8"))
def module(path,name):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result

def plant():
    extraction=module('design/astra/work/v2_apartment_batches_01/build.py','household_extractor')
    tree=ast.parse((ROOT/extraction.SOURCE).read_text(encoding="utf-8"));selected=[]
    names={'asm_plant','_plant_species','_plant_pot','_blade','case_wood','hash_str','_jit'}
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=='MeshBuf':
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in extraction.METHODS];selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=='Frame':selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in names:selected.append(node)
        elif isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='GARDEN' for t in node.targets):selected.append(node)
    ns=dict(math=math,zlib=zlib);exec(compile(ast.Module(body=selected,type_ignores=[]),extraction.SOURCE,'exec'),ns)
    spec=next(r for f in load('game/data/building_layout.json')['floors'] for r in f.get('furniture',[]) if r['id']=='3A_story_specimen')
    assert spec['species']=='rubber' and spec['big']
    return extraction.furniture_record(spec['id'],{spec['id']:spec},ns)

def check(layout,rows,record):
    geo=module('design/astra/work/v2_storage_tables_boards_batch_01/build.py','household_geometry')
    door=module('design/astra/work/v2_apartment_doors_batch_01/check.py','household_doors')
    anchors={a['id']:a for a in layout['anchors']}
    a=anchors[record['id']];b=geo.volume(record['bounds'],a)
    for identity,level,other in geo.obstacles(layout,rows):
        if identity!=record['id'] and level==a['level']:assert not geo.overlap(b,other),('plant overlaps',identity)
    room=next(s for s in layout['spaces'] if s['id']==a['space'])['rect']
    assert b[0]>=room[0]+.07 and b[2]>=room[1]+.07 and b[3]<=room[2]-.07 and b[5]<=room[3]-.07,'plant crosses room'
    stances=0
    for stance in layout['anchors']:
        if stance['level']==a['level'] and stance.get('kind')=='clearance':
            assert door.distance([stance['position'][0],stance['position'][2]],door.rect_polygon([b[0],b[2],b[3],b[5]]))>=.38,('plant blocks stance',stance['id'])
            stances+=1
    samples,sweeps=geo.check_routes_and_doors(layout,[(record['id'],a['level'],b)])
    materials=load('game/data/runtime_material_sets.json')['materials']
    for surface in record['surfaces']:
        assert surface['material'] in materials,surface['material']
        assert all(math.isfinite(v) for v in surface['vertices']+surface['normals'])
        assert len(surface['vertices'])==len(surface['normals']) and len(surface['vertices'])%9==0
    return dict(plant_world_bounds=b,clearance_stances=stances,route_samples=samples,door_sweeps=sweeps)

def build(apply=False):
    extraction=module('design/astra/work/v2_apartment_batches_01/build.py','household_merge')
    layout=load(LAYOUT);furniture=load(FURNITURE);record=plant()
    anchor=dict(id=record['id'],level='F03',space='F03_A_MAIN',position=[-15.0,0,2.25],yaw=math.radians(155),kind='furniture')
    old_count=len(layout['anchors'])
    layout['anchors']=extraction.merge_rows(layout['anchors'],[anchor])
    furniture['furniture']=extraction.merge_rows(furniture['furniture'],[record])
    checks=check(layout,furniture['furniture'],record)
    if apply:
        (ROOT/FURNITURE).write_text(json.dumps(furniture,separators=(',',':'))+'\n')
        if len(layout['anchors'])!=old_count:
            p=ROOT/LAYOUT;text=p.read_text(encoding="utf-8");start=text.index('[',text.index('"anchors"'))
            _,length=json.JSONDecoder().raw_decode(text[start:]);end=start+length-1
            p.write_text(text[:end].rstrip()+',\n    '+json.dumps(anchor,separators=(',',':'))+'\n  '+text[end:])
    receipt=dict(status='SOURCE_PASS_RUNTIME_PENDING',godot='NOT_RUN',base=BASE,furniture_total=len(furniture['furniture']),
        surface_props=26,receivers=6,new_furniture=['3A_wireless_table','4A_wireless_table',record['id']],
        checks=checks,plant_triangles=sum(len(s['vertices'])//9 for s in record['surfaces']),
        limits='Plant is fixed, with conservative full silhouette collision; no watering or growth. Source estimates do not prove actual traversal, targeting, materials/voxel shadows, headphone perception, lifecycle or performance.')
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');build(p.parse_args().apply)
