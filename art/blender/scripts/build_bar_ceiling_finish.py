"""Metre-charted smoke finish on four unchanged original Harukiya ceiling stocks."""
from pathlib import Path
import hashlib,json,sys
import bpy,bmesh
from mathutils import Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file());sys.path.insert(0,str(ROOT/'art/blender/scripts'));from fabrication_uvs import chart_for_triangle
plan_path=ROOT/'art/data/bar_ceiling_finish/source_plan.json';plan=json.loads(plan_path.read_text());assert plan['classification']=='ADAPTATION'
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials'];spec=sets[plan['catalog_key']]
layout=json.loads((ROOT/'art/data/building_layout.json').read_bytes());floor=next(f for f in layout['floors'] if f['id']==plan['source_floor']);rows=[next(x for x in floor['furniture'] if x['id']==i) for i in plan['source_ids']]
def digest(p):
 raw=p.read_bytes();return hashlib.sha256(raw if p.suffix in {'.blend','.glb','.bin','.png'} else raw.replace(b'\r\n',b'\n')).hexdigest()
def gd(v):return [v[0],v[2],-v[1]]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf'));context=list(bpy.context.scene.objects);owner=next(o for o in context if o.name==plan['source_owner']);parts=[];original=[];checks=[]
mat=bpy.data.materials.new(plan['catalog_key']);mat.use_nodes=True;bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Metallic'].default_value=spec['metallic'];coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
for i,target in enumerate(['Base Color','Roughness','Normal']):
 image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
 if i:image.colorspace_settings.name='Non-Color'
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
 if i==2:
  normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],bs.inputs[target])
 else:mat.node_tree.links.new(tex.outputs['Color'],bs.inputs[target])
vertices=[];faces=[];replaced=[]
construction=bpy.data.collections.new('OriginalClosedCeilingStocks');bpy.context.scene.collection.children.link(construction);construction.hide_render=True
for row in rows:
 rect=row['rect'];low=Vector((rect[0],rect[1],row['z0']));high=Vector((rect[2],rect[3],row['z0']+row['h']));points=[];tris=[]
 for face in owner.data.polygons:
  values=[owner.matrix_world@owner.data.vertices[i].co for i in face.vertices];n=owner.matrix_world.to_3x3().inverted().transposed()@face.normal;axis=max(range(3),key=lambda i:abs(n[i]));plane=high[axis] if n[axis]>0 else low[axis]
  if abs(n[axis])<.999 or not all(all(low[i]-plan['tolerance_m']<=p[i]<=high[i]+plan['tolerance_m'] for i in range(3)) and abs(p[axis]-plane)<plan['tolerance_m'] for p in values):continue
  assert len(values)==3;offset=len(points);points.extend(values);tris.append(tuple(range(offset,offset+3)));original.append({'source':row['id'],'points':[gd(p) for p in values],'normal':gd(n)})
 assert len(tris)==12,(row['id'],len(tris))
 mesh=bpy.data.meshes.new(row['id']+'_Stock');mesh.from_pydata(points,[],tris);bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0;volume=bm.calc_volume(signed=True);bm.to_mesh(mesh);bm.free();mesh.materials.append(mat)
 obj=bpy.data.objects.new(mesh.name,mesh);construction.objects.link(obj);checks.append({'name':obj.name,'source':row['id'],'volume_m3':volume,'nonmanifold_edges':0})
 offset=len(vertices);vertices.extend(points);faces.extend(tuple(offset+i for i in tri) for tri in tris)
 replaced.append({'id':row['id'],'key':row['mat'],'low':[low.x,low.z,-high.y],'high':[high.x,high.z,-low.y],'expected_triangles':12})
mesh=bpy.data.meshes.new('bar_smoked_ceiling__smoked_plaster');mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(mat);uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;fallbacks=0
for face in mesh.polygons:
 points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices];n,u,values,fallback=chart_for_triangle(points,Vector((0,0,0)),spec['meters_per_tile']);fallbacks+=fallback
 for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
assert fallbacks==0;part=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(part)
for obj in context:bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=ROOT/'art/blender/bar_ceiling_finish.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT');part.select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/bar_ceiling_finish.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
runtime={'schema_version':1,'asset':'res://assets/props/bar_ceiling_finish.glb','source_floor':plan['source_floor'],'owner_name':plan['source_owner'],'tolerance':plan['tolerance_m'],'replace':replaced,'part':{'name':mesh.name,'key':plan['catalog_key'],'tile':spec['meters_per_tile']}}
(ROOT/'game/data/orison_v2/bar_ceiling_finish.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,Path(__file__),ROOT/'art/data/building_layout.json',ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'game/data/runtime_material_sets.json',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf',ROOT/'game/assets/building/floor_01_cells/shop_bar.bin',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf.import',ROOT/'game/assets/props/bar_ceiling_finish.glb.import',ROOT/'art/tools/build_smoked_plaster.py',ROOT/'art/textures/procedural/smoked_plaster/material.json']
for name in spec['files']:bindings.extend([ROOT/'game/assets/building/textures'/name,ROOT/'game/assets/building/textures'/(name+'.import')])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':rows,'original_triangles':original,'closed_stocks':checks,'parts':[{'name':mesh.name,'key':plan['catalog_key'],'tile':spec['meters_per_tile'],'triangles':48}],'triangles':48,'runtime':runtime,'precision_chart_fallbacks':0,'native_sha256':digest(native),'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/bar_ceiling_finish_construction.json','game/tests/fixtures/orison_bar_ceiling_finish.json']:(ROOT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('CEILING FINISH: four unchanged closed stocks; 48 original triangles; local smoke film and metre charts')
