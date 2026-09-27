"""Real-size brass handrail assembly for the installed 1.55 x 2.2 m V2 car."""
from pathlib import Path
import math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('brass_bright'); mat.use_nodes=True
s=mat.node_tree.nodes['Principled BSDF']
s.inputs['Base Color'].default_value=(.62,.50,.26,1)
s.inputs['Metallic'].default_value=.85; s.inputs['Roughness'].default_value=.34
def point(p): return Vector((p[0],-p[2],p[1]))
def tube(name,a,b,r,bevel=.001):
    a,b=point(a),point(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=(b-a).length,location=(a+b)/2)
    o=bpy.context.object; o.name=name
    o.rotation_mode='QUATERNION'; o.rotation_quaternion=(b-a).to_track_quat('Z','Y')
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.append(mat)
    m=o.modifiers.new('Machined edge','BEVEL'); m.width=bevel; m.segments=3
    bpy.ops.object.modifier_apply(modifier=m.name)
    return o
rails=[((-.677,.92,-.975),(-.677,.92,.94)),((.677,.92,-.975),(.677,.92,.94)),((-.65,.92,-1.002),(.65,.92,-1.002))]
for i,(a,b) in enumerate(rails):
    tube('Grip'+str(i),a,b,.021,.0015)
    av,bv=Vector(a),Vector(b); direction=(bv-av).normalized()
    for end,sign in [(av,1),(bv,-1)]:
        c=end+direction*.018*sign
        tube('EndFerrule',c-direction*.004,c+direction*.004,.0225,.0007)
mounts=[]
for side in [-1,1]:
    for z in [-.935,.90]: mounts.append((Vector((side*.75,.92,z)),Vector((-side,0,0))))
for x in [-.55,.55]: mounts.append((Vector((x,.92,-1.075)),Vector((0,0,1))))
for i,(wall,inward) in enumerate(mounts):
    # Flange rear sits on the exposed 40 mm wall course below the chair rail.
    tube('WallFlange'+str(i),wall,wall+inward*.004,.018,.0006)
    tube('MountBoss',wall+inward*.003,wall+inward*.012,.012,.0006)
    tube('SupportStem',wall+inward*.010,wall+inward*.073,.008,.0008)
    for offset in [-.011,.011]:
        screw=wall+Vector((0,offset,0))+inward*.004
        o=tube('SlottedFastener',screw,screw+inward*.002,.0032,.0003)
        # Cut a physical screwdriver slot, with no texture or baked lettering.
        center=point(screw+inward*.002)
        bpy.ops.mesh.primitive_cube_add(size=1,location=center)
        cutter=bpy.context.object
        cutter.dimensions=(.006,.0011,.0011) if inward.z else (.0011,.006,.0011)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.context.view_layer.objects.active=o
        m=o.modifiers.new('Driver slot','BOOLEAN'); m.operation='DIFFERENCE'; m.object=cutter
        bpy.ops.object.modifier_apply(modifier=m.name); bpy.data.objects.remove(cutter,do_unlink=True)
for o in list(bpy.context.scene.objects):
    if o.type!='MESH': continue
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    for face in o.data.polygons: face.use_smooth=True
    m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); m.keep_sharp=True
    bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_handrails.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_handrails.glb'),export_format='GLB',export_yup=True,export_apply=True)
