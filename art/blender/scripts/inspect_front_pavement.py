"""Read-only native paving/masonry comparison; preserve historical fixture pins."""
import hashlib, json, os
from pathlib import Path
import bpy, bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(os.environ.get('STREET_REVIEW_OUT', str(ROOT/'tmp/v2-street-finish/native')))
OUT.mkdir(parents=True, exist_ok=True)
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def digest(p):
    data=(ROOT/p).read_bytes()
    if Path(p).suffix in ['.json','.py','.gd']: data=data.replace(b'\r\n',b'\n')
    return hashlib.sha256(data).hexdigest()

fixture=read('game/tests/fixtures/orison_front_pavement_construction.json')
resume=read('art/data/v2_import_resume_20261008/resume.json')
layout=read('game/data/orison_v2_blockout.json')
projection={'door':next(r for r in layout['doors'] if r['id']=='F01_DOOR_06'),
    'floors':[{k:r.get(k) for k in ['id','level','open_shell','no_floor','rect']}
        for r in layout['spaces'] if r['level']=='F01' and not r.get('open_shell') and not r.get('no_floor')]}
assert projection==resume['pavement_preflight']['blockout_projection']
connection=read('game/data/orison_v2/world_connection.json')
assert digest('game/data/orison_v2/world_connection.json')==resume['source_hashes']['game/data/orison_v2/world_connection.json']
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(ROOT/'art/blender/exterior_masonry.blend'),link=False) as (a,b):
    assert 'PreServiceMasonry' in a.collections
    b.collections=['PreServiceMasonry']
a,z,c,d=fixture['envelope']; low,high=fixture['y']; actual={}
for obj in b.collections[0].objects:
    assert obj.type=='EMPTY' and obj.parent is None and max(abs(v) for v in obj.rotation_euler)<1e-7
    p=obj.location; e=obj.scale; center=[p.x,p.z,-p.y]; size=[e.x,e.z,e.y]
    bounds=[center[i]-size[i]/2 for i in range(3)]+[center[i]+size[i]/2 for i in range(3)]
    if bounds[1]>=high or bounds[4]<=low: continue
    rect=[bounds[0],bounds[2],bounds[3],bounds[5]]
    if rect[2]>a and rect[0]<c and rect[3]>z and rect[1]<d:
        actual['ExteriorMasonry/'+obj.name]=rect
expected={r['owner']:r['bounds'] for r in fixture['masks'] if r['kind']=='authored_original_box'}
assert actual.keys()==expected.keys(),(actual.keys()-expected.keys(),expected.keys()-actual.keys())
error=max(abs(v-w) for key in actual for v,w in zip(actual[key],expected[key]))
assert error<1e-7,error
for path,pin in fixture['source_bindings'].items():
    if path not in ['game/data/orison_v2_blockout.json','game/data/orison_v2/world_connection.json','art/blender/exterior_masonry.blend']:
        assert digest(path)==pin,path
assert digest('game/assets/props/front_pavement.glb')==fixture['asset_sha256']
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/front_pavement.blend'))
union=bpy.data.objects['FittedPavementClosedUnion'];bm=bmesh.new();bm.from_mesh(union.data)
assert all(e.is_manifold for e in bm.edges)
volume=bm.calc_volume(signed=True);bm.free()
assert abs(volume-fixture['volume_m3'])<1e-6
parts=[o for o in bpy.context.scene.objects if o.type=='MESH' and o!=union]
assert len(parts)==len(fixture['parts'])
for obj in parts:
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    bounds=[min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]
    row=next(r for r in fixture['parts'] if r['id']==obj.name)
    assert max(abs(v-w) for v,w in zip(bounds,row['bounds']))<2e-6,obj.name
report={'evidence_class':'INERT','schema':'orison.front-pavement-consumed-source-review.v1',
    'original_fixture_sha256':digest('game/tests/fixtures/orison_front_pavement_construction.json'),
    'source_bindings':{p:digest(p) for p in fixture['source_bindings']},
    'asset_sha256':fixture['asset_sha256'],'native_sha256':digest('art/blender/front_pavement.blend'),
    'blockout_projection':projection,'connection_remove_boxes':connection['remove_boxes'],
    'masonry_masks':actual,'mask_max_difference_m':error,'closed_union_volume_m3':volume,'parts':len(parts),
    'scope':'Exact consumed layout and 24 native masonry mask comparison. Original source fixture and native paving/export unchanged; no runtime proof.'}
(OUT/'pavement_source_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
if os.environ.get('STREET_WRITE_REVIEW')=='1':
    (ROOT/'game/tests/fixtures/orison_front_pavement_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('PAVEMENT NATIVE: %d unchanged masks, %d parts, positive closed %.9f m3' % (len(actual),len(parts),volume))
