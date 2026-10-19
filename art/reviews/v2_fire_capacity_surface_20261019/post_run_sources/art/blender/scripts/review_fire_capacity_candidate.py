"""Native static/13carrier review of the owning capacity candidate. No game publication."""
import os
"""INERT candidate collision diagnostic. Never publishes game geometry."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3];OUT=Path(os.environ.get('ORISON_FIRE_CAPACITY_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/capacity_stock_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
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
report['source_bindings']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'art/blender/fire_capacity_candidate.blend',ROOT/'art/blender/fire_service.blend',ROOT/'art/blender/fire_floor_enamel.blend',ROOT/'art/blender/fire_joint_stock.blend',ROOT/'art/data/fire_service/source_plan.json',ROOT/'game/scripts/props/v2_fire_line_cabinet.gd',Path(__file__)]}
(OUT/'current_static_contacts.json').write_text(json.dumps(report,indent=2)+'\n')
print('NATIVE STATIC CONTACT DIAGNOSTIC',json.dumps(report,indent=2))
assert report['self_crossing_pairs_without_shared_vertices']==0,report['first_self_pairs']
assert not any(report['retained_static_crossings'].values()),report['retained_static_crossings']
assert not any(report['new_coating_crossings'].values()),report['new_coating_crossings']
assert report['loose_original_gasket_at_current_rest']==0

import os
"""INERT native bearing study. No game publication."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3];OUT=Path(os.environ.get('ORISON_FIRE_CAPACITY_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/capacity_stock_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
def b(p):return Vector((p[0],-p[2],p[1]))
def tree(obj,at=Matrix.Identity(4)):
    return BVHTree.FromPolygons([at@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
cloth=tree(bpy.data.objects['Capacity study hose'])
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_hose_rack.blend'),link=False) as (_,loaded):loaded.objects=['CarrierArm_Editable']
arm=loaded.objects[0];assert arm is not None
checks=[];crossings=[];negative=[];maximum_gap=0
for i in range(13):
    x=-.264+i*.0295
    at=Matrix.Translation(b((x,.666,.032)))
    fitted=tree(arm,at)
    crossings.append(len(fitted.overlap(cloth)))
    bad=tree(arm,Matrix.Translation(b((x,.665,.032))))
    for dx in [-.002,-.001,0,.001,.002]:
        origin=b((x+dx,.678,.100));direction=b((0,1,0))
        a=fitted.ray_cast(origin,direction,.016)[0];c=cloth.ray_cast(origin,direction,.016)[0]
        gap=(a-c).length if a is not None and c is not None else None
        checks.append(gap is not None and gap<.0001)
        maximum_gap=max(maximum_gap,gap or 0)
        a=bad.ray_cast(origin,direction,.016)[0]
        negative.append(a is not None and c is not None and (a-c).length>.0009)
    obj=arm.copy();obj.data=arm.data.copy();obj.name='Proposed carrier %02d'%i
    bpy.context.collection.objects.link(obj);obj.matrix_world=at;obj.hide_render=False
result={'evidence_class':'INERT','scope':'Resting13carrier fit only; shaft/brackets, deployed poses, UV/PBR and runtime remain unqualified.',
'bearing_samples':len(checks),'bearing_passes':sum(checks),'maximum_gap_m':maximum_gap,
'crossing_pairs_by_arm':crossings,'displaced_arm_negative_controls':len(negative),'negative_control_passes':sum(negative),
'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'art/blender/fire_capacity_candidate.blend',ROOT/'art/blender/fire_hose_rack.blend',Path(__file__)]}}

# Refit the shaft's plain middle length while retaining its actual end
# shoulder, head and thread pitch. Prototype geometry only; no UV claim.
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_hose_rack.blend'),link=False) as (_,loaded):
    loaded.objects=['Shaft_Editable','EndNut_Editable','MountBracket_Editable']
shaft,nut,bracket=loaded.objects
assert shaft is not None and nut is not None and bracket is not None
for v in shaft.data.vertices:
    x=v.co.x
    if x<=-.276:v.co.x=x-.009
    elif x<.050:v.co.x=-.285+(x+.276)*(.393/.326)
    else:v.co.x=x+.058
shaft.data.update()
base=Matrix.Translation(b((0,.666,.032)))
shaft_tree=tree(shaft,base)
nut_at=Matrix.Translation(b((.058,.666,.032)))
result['shaft_nut_crossings']=len(shaft_tree.overlap(tree(nut,nut_at)))
result['shaft_arm_crossings']=[]
for i in range(13):
    at=Matrix.Translation(b((-.264+i*.0295,.666,.032)))
    result['shaft_arm_crossings'].append(len(shaft_tree.overlap(tree(arm,at))))
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (_,loaded):loaded.objects=['F007']
case_tree=tree(loaded.objects[0],Matrix.Translation(b((0,.390,.009))))
mount_gaps=[]
for x in [-.279,.103]:
    posed=Matrix.Translation(b((x,.666,.032)));mount_tree=tree(bracket,posed)
    for dy in [-.012,-.006,.006,.012]:
        origin=b((x,.666+dy,.019));direction=b((0,0,-1))
        a=case_tree.ray_cast(origin,direction,.005)[0];c=mount_tree.ray_cast(origin,direction,.005)[0]
        mount_gaps.append((a-c).length if a is not None and c is not None else None)
    obj=bracket.copy();obj.data=bracket.data.copy();bpy.context.collection.objects.link(obj);obj.matrix_world=posed;obj.hide_render=False
for obj,at in [(shaft,base),(nut,nut_at)]:
    obj.hide_render=False;bpy.context.collection.objects.link(obj);obj.matrix_world=at
result['case_bearing_gaps_m']=mount_gaps
result['shaft_left_coating_clearance_m']=min(v.co.x for v in shaft.data.vertices)+.28795
result['scope']='Uninstalled resting13carrier plus refittedshaft/endnut/two brackets. No deployed pose, UV/PBR, support strength or runtime acceptance.'

(OUT/'rack_bearing_study.json').write_text(json.dumps(result,indent=2)+'\n')
print('SINGLE BANK RACK FIT',json.dumps(result))
assert result['bearing_passes']==result['bearing_samples']==65
assert result['negative_control_passes']==result['displaced_arm_negative_controls']==65
assert not any(result['crossing_pairs_by_arm']) and not any(result['shaft_arm_crossings'])
assert result['shaft_nut_crossings']==0 and result['shaft_left_coating_clearance_m']>0.
assert len(mount_gaps)==8 and all(gap is not None and gap<.0001 for gap in mount_gaps)
scene=bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'hose_with_carriers.blend'))
scene.render.filepath=str(OUT/'carrier_study.png')
if os.environ.get('ORISON_FIRE_CAPACITY_SKIP_RENDER')!='1':bpy.ops.render.render(write_still=True)

for name,position,target in [
    ('cloth_crowns_close',(-.06,.735,.40),(-.06,.670,.100)),
    ('cloth_returns_close',(-.12,.170,.40),(-.12,.140,.100))]:
    scene.camera.location=b(position)
    scene.camera.rotation_euler=(b(target)-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(name+'.png'))
    if os.environ.get('ORISON_FIRE_CAPACITY_SKIP_RENDER')!='1':bpy.ops.render.render(write_still=True)
print('FIRE CAPACITY NATIVE REVIEW COMPLETE')
