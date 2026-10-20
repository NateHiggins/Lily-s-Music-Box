"""INERT candidate collision diagnostic. Never publishes game geometry."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent/'hose_capacity_native5'
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
selected=[p for p in plan['parts'] if p['index'] in [*range(1,12),*range(16,26),32,33,62,63,*range(65,82)]]
names=[f"F{p['index']:03d}" for p in selected]
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (_,loaded):loaded.objects=names
B=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def frame(position,basis=None):
    rotation=B@Matrix(basis).transposed()@B.inverted() if basis else Matrix.Identity(3)
    at=rotation.to_4x4();at.translation=B@Vector(position);return at
for p,obj in zip(selected,loaded.objects):
    if obj is None:continue
    position=p['pose_position']
    if p['index']==62:position=[.245,.033,.150]
    if p['index']==63:position=[v+d for v,d in zip(position,[.493,-.117,.054])]
    at=frame(position,p['pose_basis'])
    crossings=cloth.overlap(tree(obj,at))
    report['retained_static_crossings'][f"F{p['index']:03d} {p['path']}"]=len(crossings)
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_floor_enamel.blend'),link=False) as (_,loaded):
    loaded.objects=['FloorEnamel','LeftEnamel','RightEnamel','TopEnamel']
for name,position,obj in zip(['floor','left','right','top'],[(0,.027,.108),(-.283,.390,.108),(.283,.390,.108),(0,.753,.108)],loaded.objects):
    assert obj is not None,name
    report['new_coating_crossings'][name]=len(cloth.overlap(tree(obj,frame(position))))
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_joint_stock.blend'),link=False) as (_,loaded):loaded.objects=['UnionGasket']
assert loaded.objects[0] is not None
report['loose_original_gasket_at_current_rest']=len(cloth.overlap(tree(loaded.objects[0],frame((.245,.048,.150)))))
report['excluded_scope']='Moving/replaced upper joint, detailed nozzle, new rack, hanging-tag swing, deployment and saved poses are not qualified by this static diagnostic. Original source-plan tin/gasket placements are superseded by v2_fire_line_cabinet.gd; legacy-plan false positives retained separately.'
report['source_bindings']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'hose_capacity_study.blend',ROOT/'art/blender/fire_service.blend',ROOT/'art/blender/fire_floor_enamel.blend',ROOT/'art/blender/fire_joint_stock.blend',ROOT/'art/data/fire_service/source_plan.json',ROOT/'game/scripts/props/v2_fire_line_cabinet.gd',Path(__file__)]}
(OUT/'current_static_contacts.json').write_text(json.dumps(report,indent=2)+'\n')
print('NATIVE STATIC CONTACT DIAGNOSTIC',json.dumps(report,indent=2))
