"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
def retain_gutter(root,kind,gutter,toe,materials):
 source=root/'art/blender/roof_weather_retained_gutters.blend';original_name=gutter.name
 with bpy.data.libraries.load(str(source),link=False) as (available,target):
  assert original_name in available.objects,(original_name,available.objects);target.objects=[original_name]
 original=target.objects[0];bpy.context.scene.collection.objects.link(original);bpy.context.view_layer.update()
 bm=bmesh.new();bm.from_mesh(original.data)
 for vertex in bm.verts:vertex.co=original.matrix_world@vertex.co-gutter.location
 plane=Vector((0,0,toe))-gutter.location
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=plane,plane_no=Vector((0,0,1)),dist=.0000001,clear_inner=True,clear_outer=False)
 edges=[edge for edge in bm.edges if edge.is_boundary];assert edges and all(abs(vertex.co.z-plane.z)<.000003 for edge in edges for vertex in edge.verts)
 # Bridge the two concentric cut loops, retaining an annular open lower end.
 bmesh.ops.bridge_loops(bm,edges=edges,use_pairs=True)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(edge.is_manifold for edge in bm.edges);assert bm.calc_volume(signed=True)>0
 mesh=bpy.data.meshes.new(original_name+'_RetainedTrim');bm.to_mesh(mesh);bm.free();gutter.data=mesh;mesh.materials.append(materials['galvanized_roof']);gutter['material_key']='galvanized_roof'
 bpy.data.objects.remove(original,do_unlink=True)
 print('Trimmed actual published native gutter',kind,'at',toe,'with upper geometry retained')
