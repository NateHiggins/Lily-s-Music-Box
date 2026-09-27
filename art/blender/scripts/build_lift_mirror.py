"""Mitered oak surround, real-size library. Glass remains a runtime surface."""
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('oak_quartered'); mat.use_nodes=True
bsdf=mat.node_tree.nodes['Principled BSDF']
bsdf.inputs['Base Color'].default_value=(.42,.28,.16,1)
bsdf.inputs['Roughness'].default_value=.45
# Nested rectangular rings form a continuous mitered section: no doubled
# faces at corners and an actual opening, rather than a pane over a box.
rings=[(.53,.43,0),(.53,.43,.019),(.527,.427,.026),
       (.516,.416,.030),(.507,.407,.030),(.503,.403,.025),
       (.494,.394,.025),(.491,.391,.032),(.486,.386,.032),
       (.479,.379,.022),(.479,.379,0)]
vertices=[]
for x,y,z in rings:
    vertices += [(-x,-z,-y),(x,-z,-y),(x,-z,y),(-x,-z,y)]
faces=[]
for ring in range(len(rings)):
    other=(ring+1)%len(rings)
    for side in range(4):
        nxt=(side+1)%4
        faces.append((ring*4+side,ring*4+nxt,other*4+nxt,other*4+side))
mesh=bpy.data.meshes.new('MiteredMirrorFrame'); mesh.from_pydata(vertices,[],faces); mesh.update()
obj=bpy.data.objects.new('MirrorFrame',mesh); bpy.context.collection.objects.link(obj)
obj.data.materials.append(mat); obj.select_set(True); bpy.context.view_layer.objects.active=obj
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(island_margin=.01)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/lift_mirror.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/lift_mirror.glb'),export_format='GLB',export_yup=True,export_apply=True)
