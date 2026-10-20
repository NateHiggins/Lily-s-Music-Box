"""INERT candidate collision diagnostic. Never publishes game geometry."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent/'hose_capacity_native4'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'hose_capacity_study.blend'))
hose=bpy.data.objects['Capacity study hose'];mesh=hose.data
def tree(obj,at):
    return BVHTree.FromPolygons([at@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
cloth=tree(hose,hose.matrix_world)
faces=[set(p.vertices) for p in mesh.polygons]
self_pairs=[(a,b) for a,b in cloth.overlap(cloth) if a<b and not faces[a].intersection(faces[b])]
report={'evidence_class':'INERT','scope':'Uninstalled static candidate contacts only; no deployed pose, rack, support, hand or UV/PBR acceptance.',
'self_crossing_pairs_without_shared_vertices':len(self_pairs),'first_self_pairs':self_pairs[:10],'retained_static_crossings':{},'new_coating_crossings':{}}
plan=json.loads((ROOT/'art/data/fire_service/source_plan.json').read_text())
selected=[p for p in plan['parts'] if p['index'] in [*range(1,12),*range(16,29),32,33,62,63,64,*range(65,82)]]
names=[f"F{p['index']:03d}" for p in selected]
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (_,loaded):loaded.objects=names
B=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def frame(position,basis=None):
    rotation=B@Matrix(basis).transposed()@B.inverted() if basis else Matrix.Identity(3)
    at=rotation.to_4x4();at.translation=B@Vector(position);return at
for p,obj in zip(selected,loaded.objects):
    if obj is None:continue
    at=frame(p['pose_position'],p['pose_basis'])
    crossings=cloth.overlap(tree(obj,at))
    report['retained_static_crossings'][f"F{p['index']:03d} {p['path']}"]=len(crossings)
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_floor_enamel.blend'),link=False) as (_,loaded):
    loaded.objects=['FloorEnamel','LeftEnamel','RightEnamel','TopEnamel']
for name,position,obj in zip(['floor','left','right','top'],[(0,.027,.108),(-.283,.390,.108),(.283,.390,.108),(0,.753,.108)],loaded.objects):
    assert obj is not None,name
    report['new_coating_crossings'][name]=len(cloth.overlap(tree(obj,frame(position))))
report['source_bindings']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'hose_capacity_study.blend',ROOT/'art/blender/fire_service.blend',ROOT/'art/blender/fire_floor_enamel.blend',ROOT/'art/data/fire_service/source_plan.json']}
(OUT/'static_contacts.json').write_text(json.dumps(report,indent=2)+'\n')
print('NATIVE STATIC CONTACT DIAGNOSTIC',json.dumps(report,indent=2))
