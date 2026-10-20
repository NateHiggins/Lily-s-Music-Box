"""INERT native bearing study. No game publication."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent/'hose_capacity_native5'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'hose_capacity_study.blend'))
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
'source_bindings':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [OUT/'hose_capacity_study.blend',ROOT/'art/blender/fire_hose_rack.blend',Path(__file__)]}}

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
scene=bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'hose_with_carriers.blend'))
scene.render.filepath=str(OUT/'carrier_study.png');bpy.ops.render.render(write_still=True)
