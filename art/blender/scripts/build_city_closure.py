"""Join the four original parapet stocks per building; retain source envelopes."""
from pathlib import Path
import collections,hashlib,json,math,re
import sys
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
import bpy,bmesh,numpy as np
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

plan_path=ROOT/'art/data/city_closure/source_plan.json'
layout_path=ROOT/'art/data/building_layout.json'
registration_path=ROOT/'art/blender/city_shells_registration.json'
native_path=ROOT/'art/blender/city_shells.blend'
v2_path=ROOT/'game/data/orison_v2_blockout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text())
registration=json.loads(registration_path.read_text())
def digest(path):return hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n') if path.suffix not in ['.blend','.glb','.png'] else path.read_bytes()).hexdigest()
assert plan['classification']=='ADAPTATION' and digest(native_path)==registration['source_native_sha256']
for path,value in registration['bindings'].items():
 if path!='game/data/orison_v2_blockout.json':assert digest(ROOT/path)==value,path
# The historical registration predates later blockout ports. Re-derive every
# consumed registration value from the current authority; do not silently reuse
# an old whole-file binding. Actual saved bounds are checked below as well.
v2=json.loads(v2_path.read_text());regions=json.loads((ROOT/'game/data/orison_v2/exterior/regions.json').read_text())
spaces={r['id']:r for r in v2['spaces']}
instance=next(r for r in regions['instances'] if r['semantic_identity']=='SHOP_BODEGA')
street=next(t for t in regions['surface_templates'] if t['id']=='TEMPLATE_STREET_SEGMENT_V1')
pavement=next(s for s in street['surfaces'] if s['id']=='pavement')
east=float(pavement['point_m'][0])+float(instance['offset_uvn_m'][0])-17.4
west=-(spaces['F01_D_MAIN']['rect'][2]+2.35+.24+.08)-.08-(-15.2)
source_rows=next(row for row in layout['floors'] if row['id']=='F01')['furniture']
ne=[r for r in source_rows if re.match(r'^site_ne\d+_',r['id']) and 'rect' in r and not r['id'].endswith('_beacon')]
region=next(r for r in regions['regions'] if r['id']=='REGION_STREET')
northeast=max(p[0] for p in region['boundary'])+.08-min(r['rect'][0] for r in ne)
derived={'site_nbr_e':east,'site_nbr_w':west}
derived.update({re.match(r'^(site_nw\d+)_',r['id']).group(1):west for r in source_rows if re.match(r'^site_nw\d+_',r['id'])})
derived.update({re.match(r'^(site_ne\d+)_',r['id']).group(1):northeast for r in ne})
assert set(derived)==set(registration['offsets'])
assert all(abs(derived[k]-registration['offsets'][k])<1e-9 for k in derived)
floor=next(row for row in layout['floors'] if row['id']=='F01')
def selected(identity):return identity.startswith(('site_nbr_','site_back_','site_far_')) or re.match(r'^site_(?:nw|ne|sw|se)\d+_',identity)
def group(identity):return '_'.join(identity.split('_')[:3]) if identity.startswith(('site_nbr_','site_back_','site_far_')) else '_'.join(identity.split('_')[:2])
records=[row for row in floor['furniture'] if selected(row['id']) and 'rect' in row and not row['id'].endswith('_beacon')]
assert len(records)==plan['original_record_count']
groups=sorted({group(row['id']) for row in records});assert len(groups)==25
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
context=bpy.data.collections.new('RetainedCityReference');bpy.context.scene.collection.children.link(context)
context.hide_render=True
with bpy.data.libraries.load(str(native_path),link=True) as (available,loaded):
 loaded.objects=[identity for identity in available.objects if selected(identity)]
references=loaded.objects
shell_rows={r['id']:r for r in floor['furniture'] if selected(r['id']) and 'rect' in r and not r['id'].endswith('_beacon')}
assert len(references)==335 and {o.name for o in references}==set(shell_rows)
max_bounds_error=0.0
for obj in references:
 row=shell_rows[obj.name];dx=derived.get(group(obj.name),0);x0,y0,x1,y1=row['rect'];z0=float(row.get('z0',0));h=row['h']
 expected=[x0+dx,y0,z0,x1+dx,y1,z0+h]
 pose=Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale)
 points=[pose@v.co for v in obj.data.vertices]
 actual=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
 error=max(abs(a-b) for a,b in zip(expected,actual));max_bounds_error=max(max_bounds_error,error)
 assert error<.00002,(obj.name,error)
for obj in references:context.objects.link(obj);obj.hide_set(True)
for library in bpy.data.libraries:library.filepath=bpy.path.relpath(library.filepath,start=str(ROOT/'art/blender'))

materials={};sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for key in plan['runtime_keys']:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
 node=mat.node_tree.nodes['Principled BSDF'];spec=sets[key];node.inputs['Metallic'].default_value=spec['metallic']
 coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
 for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True);image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
  if index>0:image.colorspace_settings.name='Non-Color'
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
  if index==2:
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],node.inputs['Normal'])
  else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
welded=bpy.data.collections.new('ClosedParapets');bpy.context.scene.collection.children.link(welded);welded.hide_render=True
stocks={};parapets=collections.defaultdict(list);original_records=[]
for reference in references:
 row=shell_rows[reference.name];key=plan['source_material_keys'][row['mat']]
 stock=reference.copy();stock.data=reference.data.copy();closed.objects.link(stock);stock.name=reference.name+'__RetainedStock';stock.hide_set(True);stock.hide_render=True
 stock.data.materials.clear();stock.data.materials.append(materials[key]);stocks[reference.name]=stock
 original_records.append({'id':row['id'],'rect':row['rect'],'z0':float(row.get('z0',0)),'h':row['h'],'mat':row['mat'],'key':key,'registration_offset_x':derived.get(group(row['id']),0)})
 if '_par_' in reference.name and reference.name.rsplit('_',1)[-1] in ['n','s','e','w']:parapets[group(reference.name)].append(stock)
assert len(stocks)==335 and len(parapets)==25 and sum(map(len,parapets.values()))==100
def closed_check(obj,allow_zero_area=False):
 bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold and e.is_contiguous for e in bm.edges),obj.name;assert bm.calc_volume(signed=True)>0,obj.name
 unseen=set(bm.verts);components=0
 while unseen:
  components+=1;stack=[unseen.pop()]
  while stack:
   v=stack.pop()
   for e in v.link_edges:
    other=e.other_vert(v)
    if other in unseen:unseen.remove(other);stack.append(other)
 assert components==1,(obj.name,components)
 result={'volume_m3':bm.calc_volume(signed=True),'vertices':len(bm.verts),'faces':len(bm.faces),'components':components,'zero_area_faces':sum(face.calc_area()==0 for face in bm.faces)};assert allow_zero_area or result['zero_area_faces']==0,(obj.name,result);bm.free();return result
def boundary_distance(point,triangles):
 # Compare boundary positions in double precision. Single-precision nearest
 # queries on long skinny Boolean triangles are insufficient at this scale.
 a=triangles[:,0];b=triangles[:,1];c=triangles[:,2]
 n=np.cross(b-a,c-a);n2=np.sum(n*n,axis=1);valid=n2>0;a=a[valid];b=b[valid];c=c[valid];n=n[valid];n2=n2[valid]
 signed=np.sum((point-a)*n,axis=1);projected=point-n*(signed/n2)[:,None]
 inside=np.ones(len(a),dtype=bool);nearest=np.full(len(a),np.inf)
 for first,second in [(a,b),(b,c),(c,a)]:
  edge=second-first;inside &= np.sum(np.cross(edge,projected-first)*n,axis=1)>=-1e-20
  t=np.clip(np.sum((point-first)*edge,axis=1)/np.sum(edge*edge,axis=1),0,1)
  at=first+edge*t[:,None];nearest=np.minimum(nearest,np.sum((at-point)**2,axis=1))
 nearest=np.minimum(nearest,np.where(inside,signed*signed/n2,np.inf))
 return float(np.sqrt(np.min(nearest)))
source_checks={name:closed_check(obj) for name,obj in stocks.items()};merged={};ring_checks={};ring_keys={}
for name,objects in sorted(parapets.items()):
 assert len(objects)==4
 keys={obj.data.materials[0].name for obj in objects};assert len(keys)==1,(name,keys);ring_keys[name]=keys.pop()
 clones=[]
 for obj in objects:
  clone=obj.copy();clone.data=obj.data.copy();bpy.context.scene.collection.objects.link(clone);clone.hide_set(False);clone.hide_render=False;clones.append(clone)
 result=clones[0]
 for other in clones[1:]:
  bpy.context.view_layer.objects.active=result;mod=result.modifiers.new('Exact closed corner joint','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=other;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(other,do_unlink=True)
 result.name=name+'__JoinedParapet';closed_check(result,allow_zero_area=True)
 bm=bmesh.new();bm.from_mesh(result.data)
 # Exact Boolean intersections can retain sub-micrometre coincident edges.
 # Weld only within 2 micrometres, well below the native-envelope check,
 # before triangulation and the unchanged closed-manifold checks.
 before_vertices=np.asarray([v.co[:] for v in bm.verts],dtype=np.float64)
 before_volume=bm.calc_volume(signed=True);before_area=sum(face.calc_area() for face in bm.faces)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002)
 weld_vertices=np.asarray([v.co[:] for v in bm.verts],dtype=np.float64)
 maximum_move=max(min(np.linalg.norm(weld_vertices-p,axis=1)) for p in before_vertices)
 assert maximum_move<=.0000021,(name,maximum_move)
 bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.0000001)
 bmesh.ops.dissolve_limit(bm,angle_limit=.00001,use_dissolve_boundaries=True,verts=list(bm.verts),edges=list(bm.edges),delimit={'MATERIAL'})
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 surface_triangles=np.asarray([[loop.vert.co[:] for loop in triangle] for triangle in bm.calc_loop_triangles()],dtype=np.float64)
 maximum_boundary_error=max(boundary_distance(p,surface_triangles) for p in before_vertices)
 assert maximum_boundary_error<=.0000021,(name,maximum_boundary_error)
 after_volume=bm.calc_volume(signed=True)
 # Bound volume change by the measured boundary area and weld reach.
 # A fixed cubic-metre cutoff would ignore building size.
 assert abs(after_volume-before_volume)<=before_area*.0000021+1e-10,(name,before_volume,after_volume)
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.0000001)
 # A triangulator may retain three exactly collinear boundary vertices.
 # Merge only that zero-area face across its longest edge; keep its exact
 # boundary vertices and the adjacent positive-area surface as an n-gon.
 for iteration in range(100):
  zero=[face for face in bm.faces if face.calc_area()==0]
  if not zero:break
  edge=max(zero[0].edges,key=lambda edge:edge.calc_length())
  bmesh.ops.dissolve_edges(bm,edges=[edge],use_verts=False,use_face_split=False)
 else:raise AssertionError(('unresolved zero-area native join',name))
 bm.to_mesh(result.data);bm.free();ring_checks[name]=closed_check(result)
 ring_checks[name]['maximum_boolean_weld_distance_m']=maximum_move
 ring_checks[name]['maximum_cleanup_boundary_error_m']=maximum_boundary_error
 ring_checks[name]['boolean_weld_volume_change_m3']=abs(after_volume-before_volume)
 ring_checks[name]['boolean_weld_volume_bound_m3']=before_area*.0000021+1e-10
 bpy.context.scene.collection.objects.unlink(result);welded.objects.link(result);result.hide_set(True);result.hide_render=True;merged[name]=result
export_objects=[(name,obj,plan['source_material_keys'][shell_rows[name]['mat']]) for name,obj in stocks.items() if obj not in sum(parapets.values(),[])]+[(name,obj,ring_keys[name]) for name,obj in merged.items()]
assert len(export_objects)==260
batches=collections.defaultdict(list)
for name,obj,key in export_objects:batches[(group(name),key)].append(obj)
assert len(batches)==84,(len(batches),sorted(batches))
draws=[];inventory=[];total_triangles=0;precision_chart_fallbacks=0;float32_zero_area_triangles=0
for (identity,key),objects in sorted(batches.items()):
 polygons=[]
 for obj in objects:
  pose=np.asarray(Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale),dtype=np.float64)
  for face in obj.data.polygons:polygons.append([pose[:3,:3]@np.asarray(obj.data.vertices[i].co[:],dtype=np.float64)+pose[:3,3] for i in face.vertices])
 points=[p for polygon in polygons for p in polygon];origin=Vector(tuple(round(sum(p[i] for p in points)/len(points),3) for i in range(3)));name=identity+'__'+key
 vertices=[];faces=[]
 for polygon in polygons:
  first=len(vertices);vertices.extend(polygon);faces.append(tuple(range(first,first+len(polygon))))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(p[i])-float(origin[i]) for i in range(3)) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces))
 zero=[]
 for face in bm.faces:
  pts=np.asarray([v.co[:] for v in face.verts],dtype=np.float64);cross=np.cross(pts[1]-pts[0],pts[2]-pts[0])
  if np.dot(cross,cross)==0:zero.append(face)
 # These faces have exactly zero represented area, not a small-area cutoff.
 # Keep every positive-area triangle and retain closed native source rings.
 float32_zero_area_triangles+=len(zero)
 if zero:bmesh.ops.delete(bm,geom=zero,context='FACES_ONLY')
 bm.to_mesh(mesh);bm.free();chart=mesh.uv_layers.new(name='Metres');chart.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
 for face in mesh.polygons:
  pts=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
  try:n,u,values,local=chart_for_triangle(pts,origin[:],sets[key]['meters_per_tile'])
  except AssertionError:
   print('CITY CLOSURE CHART DIAGNOSTIC',name,face.index,pts.tolist(),flush=True);raise
  precision_chart_fallbacks+=local
  for j,loop in enumerate(face.loop_indices):chart.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(n)
 mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
 mesh.calc_loop_triangles();triangles=len(mesh.loop_triangles);total_triangles+=triangles;inventory.append({'name':name,'group':identity,'key':key,'triangles':triangles})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/city_closure.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
class ExportUVHandedness:
 corrected=0
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  # The guide is native authoring data; only the derived standard tangent
  # enters the portable mesh, without an unused custom runtime attribute.
  for primitive in mesh.primitives:
   # Attribute callbacks run in mesh storage order; custom corner data may
   # precede POSITION and NORMAL. Read the completed primitive instead.
   def vectors(key):
    accessor=primitive.attributes[key]
    assert accessor.component_type==5126 and accessor.type=='VEC3'
    array=np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,3)).astype(np.float64)
    assert len(array)==primitive.attributes['POSITION'].count
    return array
   n=vectors('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
   guide=vectors('_TANGENT_GUIDE')
   tangent=guide-n*np.sum(guide*n,axis=1)[:,None]
   tangent/=np.linalg.norm(tangent,axis=1)[:,None]
   assert np.isfinite(tangent).all() and np.max(np.abs(np.sum(n*tangent,axis=1)))<1e-7
   tangent=np.column_stack((tangent,-np.ones(len(n)))).astype(np.float32)
   from io_scene_gltf2.io.exp.binary_data import BinaryData
   from io_scene_gltf2.io.com.constants import BufferViewTarget
   primitive.attributes['TANGENT'].buffer_view=BinaryData(tangent.tobytes(),BufferViewTarget.ARRAY_BUFFER)
   type(self).corrected+=1
   for key in list(primitive.attributes):
    if key.upper()=='_TANGENT_GUIDE':del primitive.attributes[key]
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/city_shells.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True)
assert ExportUVHandedness.corrected==len(draws),(ExportUVHandedness.corrected,len(draws))

bindings=[plan_path,layout_path,registration_path,native_path,v2_path,ROOT/'game/data/orison_v2/exterior/regions.json',Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'game/data/runtime_material_sets.json']
for key in plan['runtime_keys']:
 bindings.extend(ROOT/'game/assets/building/textures'/name for name in sets[key]['files'])
corners=[]
for name,obj in sorted(merged.items()):
 pose=Matrix.LocRotScale(obj.location,obj.rotation_euler.to_quaternion(),obj.scale);points=[pose@v.co for v in obj.data.vertices]
 corners.append({'group':name,'point':[max(v[i] for v in points) for i in range(3)]})
for key in ['bronze_sheet','galvanized_roof']:
 bindings.extend([ROOT/f'art/tools/build_{key}.py',ROOT/f'art/textures/procedural/{key}/material.json'])
 bindings.extend(ROOT/f'art/textures/procedural/{key}'/name for name in ['albedo.png','roughness.png','height.png','normal.png'])
for name in ['masts','aerials','tanks']:bindings.extend([ROOT/f'game/assets/props/city_{name}.glb',ROOT/f'game/tests/fixtures/orison_city_{name}.json'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':original_records,'original_record_count':335,'source_checks':source_checks,'source_parapet_stocks':100,'closed_joined_parapets':ring_checks,'groups':groups,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':precision_chart_fallbacks,'float32_zero_area_triangles_omitted':float32_zero_area_triangles,'corner_stations':corners,'capture_offsets_godot':plan['capture_offsets_godot'],'skyline_views_godot':plan['skyline_views_godot'],'current_native_derivation':{'bounds_checked':335,'max_bounds_error_m':max_bounds_error,'current_offsets':derived,'historical_blockout_binding_stale':digest(v2_path)!=registration['bindings']['game/data/orison_v2_blockout.json']},'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for path in ['art/blender/city_closure_construction.json','game/tests/fixtures/orison_city_closure.json']:(ROOT/path).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('CITY CLOSURE',len(stocks),'retained closed source stocks;',len(merged),'closed parapet rings;',len(draws),'parts;',total_triangles,'triangles')
