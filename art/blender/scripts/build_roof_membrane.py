"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json,math,hashlib,collections
import bpy,bmesh,numpy as np
from mathutils import Vector
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
field_path=R/'art/blender/roof_drainage_falls_construction.json';field=json.loads(field_path.read_bytes());plan_path=R/'art/data/roof_membrane/source_plan.json';plan=json.loads(plan_path.read_bytes())
points=np.array(field['points']);skin=plan['thickness'];width=plan['roll_width'];length=plan['sheet_length'];bond=plan['bond_width']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedRollStocks');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
materials={}
for key,tint in [('Field',1.),('Bond',plan['bond_tint'])]:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=(.04*tint,.04*tint,.04*tint,1);node.inputs['Roughness'].default_value=.86
 uv=mat.node_tree.nodes.new('ShaderNodeTexCoord')
 for file,socket,noncolor in [('albedo.png','Base Color',False),('roughness.png','Roughness',True),('normal.png','Normal',True)]:
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(R/'art/textures/procedural/roof_bitumen'/file),check_existing=True);tex.image.filepath=bpy.path.relpath(tex.image.filepath,start=str(O))
  if noncolor:tex.image.colorspace_settings.name='Non-Color'
  mat.node_tree.links.new(uv.outputs['UV'],tex.inputs['Vector'])
  if socket=='Base Color':
   mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1.;mix.inputs[2].default_value=(tint,tint,tint,1.);mat.node_tree.links.new(tex.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs['Color'],node.inputs[socket])
  elif socket=='Normal':
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],node.inputs[socket])
  else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[socket])
 materials[key]=mat
runtime_mat=materials['Field'].copy();runtime_mat.name='roof_bitumen';vertex=runtime_mat.node_tree.nodes.new('ShaderNodeVertexColor');vertex.layer_name='SeamTint';mix=next(node for node in runtime_mat.node_tree.nodes if node.type=='MIX_RGB');runtime_mat.node_tree.links.new(vertex.outputs['Color'],mix.inputs[2])
def clip(polygon,axis,bound,sign):
 old=polygon;result=[]
 if not old:return result
 previous=old[-1];pi=sign*(previous[axis]-bound)>=-1e-10
 for current in old:
  ci=sign*(current[axis]-bound)>=-1e-10
  if ci!=pi:
   fraction=(bound-previous[axis])/(current[axis]-previous[axis]);at=previous+(current-previous)*fraction;at[axis]=bound;result.append(at)
  if ci:result.append(current.copy())
  previous=current;pi=ci
 clean=[]
 for p in result:
  if not clean or np.linalg.norm(p-clean[-1])>1e-9:clean.append(p)
 if len(clean)>1 and np.linalg.norm(clean[0]-clean[-1])<1e-9:clean.pop()
 return clean
def area(poly):return abs(sum(a[0]*b[2]-a[2]*b[0] for a,b in zip(poly,poly[1:]+poly[:1])))/2
polygons=collections.defaultdict(list);render_groups=collections.defaultdict(list);expected_area=0.
for indices,owner in zip(field['triangles_by_vertex'],field['triangle_owners']):
 source=[p.copy() for p in points[indices]];expected_area+=area(source);lo=min(p[0] for p in source);hi=max(p[0] for p in source)
 for roll in range(math.floor(lo/width),math.floor((hi-1e-10)/width)+1):
  for xa,xb,xkind in [(roll*width,roll*width+bond,'Bond'),(roll*width+bond,(roll+1)*width,'Field')]:
   strip=clip(clip(source,0,xa,1),0,xb,-1)
   if len(strip)<3:continue
   zlo=min(p[2] for p in strip);zhi=max(p[2] for p in strip);phase=(roll%2)*length/2
   for end in range(math.floor((zlo-phase)/length),math.floor((zhi-phase-1e-10)/length)+1):
    for za,zb,zkind in [(phase+end*length,phase+end*length+bond,'Bond'),(phase+end*length+bond,phase+(end+1)*length,'Field')]:
     poly=clip(clip(strip,2,za,1),2,zb,-1)
     if len(poly)<3 or area(poly)<1e-11:continue
     kind='Bond' if 'Bond' in [xkind,zkind] else 'Field';polygons[(owner,roll,end,xkind,zkind)].append(poly)
     # Split exposed tops at actual four-metre culling planes. Keep the source
     # affine roof height during clipping; no new falls or collider is created.
     for ix in range(math.floor(min(p[0] for p in poly)/4),math.floor((max(p[0] for p in poly)-1e-10)/4)+1):
      px=clip(clip(poly,0,ix*4,1),0,(ix+1)*4,-1)
      if len(px)<3:continue
      for iz in range(math.floor(min(p[2] for p in px)/4),math.floor((max(p[2] for p in px)-1e-10)/4)+1):
       pz=clip(clip(px,2,iz*4,1),2,(iz+1)*4,-1)
       if len(pz)>=3 and area(pz)>1e-11:render_groups[(owner,ix,iz)].append((kind,pz))
def chart(mesh,origin):
 uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 for face in mesh.polygons:
  normal=face.normal.normalized();seed=Vector((1,0,0)) if abs(normal.x)<.85 else Vector((0,1,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=origin+mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.x,-p.y) if normal.z>.9 else (p.dot(u),p.dot(v))
stocks=[];stations=[];measured_area=0.;total_volume=0.
for (owner,roll,end,xkind,zkind),polys in sorted(polygons.items()):
 kind='Bond' if 'Bond' in [xkind,zkind] else 'Field';vertices=[];lookup={};faces=[]
 for poly in polys:
  ids=[]
  for p in poly:
   key=(round(float(p[0]),8),round(float(p[2]),8))
   if key not in lookup:lookup[key]=len(vertices);vertices.append((float(p[0]),float(-p[2]),float(p[1])))
   ids.append(lookup[key])
  faces.extend([tuple([ids[0],ids[i],ids[i+1]]) for i in range(1,len(ids)-1)])
  measured_area+=area(poly)
 count=len(vertices);vertices += [(x,z,y-skin) for x,z,y in vertices]
 edges=collections.Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,face[1:]+face[:1]));assert all(v in [1,2] for v in edges.values()),(owner,roll,end)
 body_faces=[tuple(reversed(face)) for face in faces]+[tuple(v+count for v in face) for face in faces]+[(a,b,b+count,a+count) for (a,b),number in edges.items() if number==1]
 origin=Vector(tuple(round(sum(p[i] for p in vertices)/len(vertices),3) for i in range(3)));mesh=bpy.data.meshes.new(f'{owner}__Roll_{roll}_{end}_{xkind}_{zkind}');mesh.from_pydata([tuple(float(p[i])-origin[i] for i in range(3)) for p in vertices],[],body_faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(edge.is_manifold for edge in bm.edges),mesh.name;volume=bm.calc_volume(signed=True);assert volume>0,mesh.name;bm.to_mesh(mesh);bm.free();mesh.materials.append(materials[kind]);chart(mesh,origin)
 obj=bpy.data.objects.new(mesh.name,mesh);closed.objects.link(obj);obj.location=origin;stocks.append({'name':obj.name,'owner':owner,'kind':kind,'volume_m3':volume,'roll':roll,'end':end,'polygons':len(polys)});total_volume+=volume
 for face in mesh.polygons:
  if face.normal.z>.999:
   p=sum((origin+mesh.vertices[v].co for v in face.vertices),Vector())/len(face.vertices);stations.append({'stock':obj.name,'owner':owner,'point':[p.x,p.z,-p.y],'kind':kind});break
assert abs(measured_area-expected_area)<.000001,(measured_area,expected_area)
assert abs(total_volume-expected_area*skin)<.000025,(total_volume,expected_area*skin)
parts=[];visible=[];triangles=0
for (owner,ix,iz),polys in sorted(render_groups.items()):
 absolute=[(float(p[0]),float(-p[2]),float(p[1])) for kind,poly in polys for p in poly];origin=Vector(tuple(round(sum(p[i] for p in absolute)/len(absolute),3) for i in range(3)));vertices=[];faces=[];tints=[]
 for kind,poly in polys:
  start=len(vertices);vertices.extend([(float(p[0])-origin.x,float(-p[2])-origin.y,float(p[1])-origin.z) for p in poly]);faces.extend([(start,start+i+1,start+i) for i in range(1,len(poly)-1)]);tints.extend([plan['bond_tint'] if kind=='Bond' else 1.]*len(poly))
 mesh=bpy.data.meshes.new(f'{owner}__RollFinish_{ix}_{iz}');mesh.from_pydata(vertices,[],faces);mesh.update();assert all(face.normal.z>.999 for face in mesh.polygons),mesh.name;mesh.materials.append(runtime_mat);chart(mesh,origin)
 colour=mesh.color_attributes.new(name='SeamTint',type='FLOAT_COLOR',domain='CORNER')
 for loop in mesh.loops:
  tint=tints[loop.vertex_index];colour.data[loop.index].color=(tint,tint,tint,1.)
 obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;visible.append(obj);parts.append({'name':obj.name,'owner':owner,'triangles':len(faces),'material':'roof_bitumen'});triangles+=len(faces)
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True);native=O/'roof_membrane.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in visible:obj.select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=R/'game/assets/props/roof_membrane.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','closed_stocks':stocks,'stations':stations,'parts':parts,'triangles':triangles,'exact_retained_field_area_m2':expected_area,'partitioned_stock_area_m2':measured_area,'native_volume_m3':total_volume,'expected_vertical_skin_volume_m3':expected_area*skin,'recipe':plan,'field_sha256':hashlib.sha256(field_path.read_bytes()).hexdigest(),'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_bindings':{str(p.relative_to(R)).replace('\\','/'):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [plan_path,field_path,Path(__file__)]},'open_work':['saved native stock and height/contact inspection','imported metre charts/colour/tangents','composed material and roof walking','fan/tank/door weather interfaces','ground receivers and production integration']}
(O/'roof_membrane_construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');(R/'game/tests/fixtures/orison_roof_membrane.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SCRATCH ROLLED ROOF',len(stocks),'closed stocks;',len(parts),'bounded parts;',triangles,'top triangles; area error',measured_area-expected_area,'volume error',total_volume-expected_area*skin)
