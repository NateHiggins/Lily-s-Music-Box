"""Closed lobed liquid surface with physical 0.08 m UV charts."""
import bpy,math
from pathlib import Path
R=Path(__file__).resolve().parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=128,ring_count=48)
o=bpy.context.object;o.name='FLOWING_RESIDUE'
for v in o.data.vertices:
 a=math.atan2(v.co.y,v.co.x);r=1+.08*math.sin(5*a)+.045*math.sin(9*a+.4)
 v.co.x*=.36*r;v.co.y*=.32*r;v.co.z=v.co.z*.018+.014
for f in o.data.polygons:f.use_smooth=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
m=o.data;m.calc_loop_triangles();uv=m.uv_layers.active.data
area=sum(t.area for t in m.loop_triangles);ua=0
for t in m.loop_triangles:
 a,b,c=[uv[i].uv for i in t.loops];ua+=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5
for loop in uv:loop.uv*=math.sqrt(area/ua)/.08
mat=bpy.data.materials.new('tentacle_gang_residue');mat.diffuse_color=(.24,.06,.4,1);mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.7
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.22
o.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(R/'art/blender/tentacle_gang_residue.blend'))
bpy.ops.export_scene.gltf(filepath=str(R/'game/assets/dream/tentacle_gang/gang_residue.glb'),export_format='GLB',export_yup=True)
