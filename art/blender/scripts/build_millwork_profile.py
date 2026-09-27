"""Normalized V2 beaded trim extrusion. Runtime owns lengths and wall clipping.
Run: blender -b -P art/blender/scripts/build_millwork_profile.py
"""
from pathlib import Path
import math
import bpy

ROOT=Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for old in list(bpy.data.materials): bpy.data.materials.remove(old)
material=bpy.data.materials.new('wood_dark')
material.use_nodes=True
shader=material.node_tree.nodes['Principled BSDF']
shader.inputs['Base Color'].default_value=(.12,.065,.03,1)
shader.inputs['Roughness'].default_value=.5

# Local X is the run, Y the section height, and +Z faces into the room.
# Flat end caps preserve butt joints even when long runs are scaled.
profile=[(-.5,-.5)]
for i in range(41):
    y=-.5+i/40
    bead=max(math.exp(-((y-.35)/.065)**2),math.exp(-((y+.35)/.065)**2))
    profile.append((y,.20+.30*bead))
profile.append((.5,-.5))
n=len(profile)
vertices=[(x,-z,y) for x in [-.5,.5] for y,z in profile]
faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh=bpy.data.meshes.new('BeadedTrim')
mesh.from_pydata(vertices,[],faces); mesh.update()
obj=bpy.data.objects.new('BeadedTrim',mesh)
bpy.context.collection.objects.link(obj)
obj.data.materials.append(material)
bpy.context.view_layer.objects.active=obj; obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.uv.smart_project(island_margin=.01)
bpy.ops.object.mode_set(mode='OBJECT')
for face in mesh.polygons:
    # Only the exposed flowing section is smooth, not end caps or back edges.
    face.use_smooth=face.index>=3 and face.index<=42
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/millwork_profile.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/props/millwork_profile.glb'),
    export_format='GLB',export_yup=True,export_apply=True)
