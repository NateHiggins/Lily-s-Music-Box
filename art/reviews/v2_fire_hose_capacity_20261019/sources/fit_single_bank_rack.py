"""INERT native bearing study. No game publication."""
from pathlib import Path
import bpy,json,hashlib
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).parent/'hose_capacity_native4'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'hose_capacity_study.blend'))
def b(p):return Vector((p[0],-p[2],p[1]))
def tree(obj,at=Matrix.Identity(4)):
    return BVHTree.FromPolygons([at@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
cloth=tree(bpy.data.objects['Capacity study hose'])
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_hose_rack.blend'),link=False) as (_,loaded):loaded.objects=['CarrierArm_Editable']
arm=loaded.objects[0];assert arm is not None
checks=[];crossings=[];negative=[];maximum_gap=0
for i in range(13):
    x=-.268+i*.0295
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
(OUT/'rack_bearing_study.json').write_text(json.dumps(result,indent=2)+'\n')
print('SINGLE BANK RACK FIT',json.dumps(result))
scene=bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'hose_with_carriers.blend'))
scene.render.filepath=str(OUT/'carrier_study.png');bpy.ops.render.render(write_still=True)
