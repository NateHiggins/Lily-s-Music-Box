"""Skin the authored full-length cloth for physical manipulation.

Candidate only. Does not change any maintenance, save or input authority.
One independent rigid ring bone keeps the original cloth sections editable;
Godot drives these from constrained centreline points, not repair booleans.
"""
from pathlib import Path
import bpy,json,os,sys,hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(os.environ.get('ORISON_FIRE_CAPACITY_SOURCE',str(ROOT/'tmp/v2-fire-hand-20261019/capacity_stock_native1'))).resolve()
OUT=Path(os.environ.get('ORISON_FIRE_CAPACITY_RIG_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/capacity_rig_native1'))).resolve()
assert SOURCE.is_relative_to(ROOT/'tmp') and OUT.is_relative_to(ROOT/'tmp') and OUT!=SOURCE
for name in ['art/blender','game/assets/props']:(OUT/name).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import export
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'art/blender/fire_capacity_candidate.blend'))
bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Capacity study hose'];plan=json.loads((SOURCE/'capacity_plan.json').read_text())
points=[Vector(p) for p in plan['points']];hints=[Vector(p) for p in plan['sides']];count=len(points);section=32;half=count*section
assert len(obj.data.vertices)==2*half
def b(p):return Vector((p.x,-p.z,p.y))
bpy.ops.object.select_all(action='DESELECT')
armature=bpy.data.armatures.new('Physical cloth ring frames')
rig=bpy.data.objects.new('PhysicalHoseSkeleton',armature);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
names=[]
for i,p in enumerate(points):
    tangent=(points[min(i+1,count-1)]-points[max(i-1,0)]).normalized()
    side=(hints[i]-tangent*hints[i].dot(tangent)).normalized()
    bone=armature.edit_bones.new('HoseRing%04d'%i)
    bone.head=b(p);bone.tail=b(p+tangent*.01);bone.align_roll(b(side));names.append(bone.name)
bpy.ops.object.mode_set(mode='OBJECT')
for i,name in enumerate(names):
    group=obj.vertex_groups.new(name=name)
    group.add(list(range(i*section,(i+1)*section))+list(range(half+i*section,half+(i+1)*section)),1.,'REPLACE')
modifier=obj.modifiers.new('Native cloth ring skin','ARMATURE');modifier.object=rig
obj.parent=rig;obj.matrix_parent_inverse=rig.matrix_world.inverted()
exports=bpy.data.collections.new('Physical full-length hose candidate');bpy.context.scene.collection.children.link(exports)
exports.objects.link(obj);exports.objects.link(rig)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/fire_capacity_candidate.blend'))
result=export(OUT,'fire_capacity_candidate',exports,material_names_only=True)
projection={'schema_version':1,'bone_names':names,'points':[list(p) for p in points],
            'sides':[list(p) for p in hints],'length_m':float(plan['centreline_polyline_m'])}
(OUT/'rig_projection.json').write_text(json.dumps(projection,indent=2)+'\n')
paths=[Path(__file__).resolve(),SOURCE/'art/blender/fire_capacity_candidate.blend',SOURCE/'candidate_construction.json',SOURCE/'capacity_plan.json',ROOT/'art/blender/scripts/fabrication_native_batch.py']
def sha(path):
    raw=path.read_bytes()
    if path.suffix in ['.py','.json']:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()
report={'evidence_class':'INERT','scope':'Skinned native candidate, not physical deployment or runtime acceptance.',
        'bones':len(names),'export':result,'source_bindings':{p.relative_to(ROOT).as_posix():sha(p) for p in paths},
        'outputs':{p.relative_to(OUT).as_posix():sha(p) for p in [OUT/'art/blender/fire_capacity_candidate.blend',OUT/'game/assets/props/fire_capacity_candidate.glb',OUT/'rig_projection.json']}}
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('FIRE CAPACITY RIG CANDIDATE',json.dumps(report))
