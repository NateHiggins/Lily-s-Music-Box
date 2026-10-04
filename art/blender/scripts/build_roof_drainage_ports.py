"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json,math,hashlib,collections
import bpy,bmesh,numpy as np
from mathutils import Vector
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
study_path=R/'art/data/orison_roof_drainage/roof_grade.json';study=json.loads(study_path.read_bytes())
source_path=R/'art/data/orison_v2/roof_source.json';roof=json.loads(source_path.read_bytes())['records'];Y=study['datum'];thickness=.0012;width=.24;clear_height=.12;outfall=.01;reach=.625
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
construction=bpy.data.collections.new('ClosedNativeStocks');bpy.context.scene.collection.children.link(construction)
steel=bpy.data.materials.new('galvanized_roof');steel.diffuse_color=(.31,.33,.33,1)
masonry=bpy.data.materials.new('retained_parapet');masonry.diffuse_color=(.4,.29,.2,1)
mortar=bpy.data.materials.new('concrete');mortar.diffuse_color=(.3,.28,.24,1)
stocks=[];parts=[];ports=[]
def b(p):return Vector((p[0],-p[2],p[1]))
def make(name,points,faces,material):
 origin=[round(sum(p[i] for p in points)/len(points),3) for i in range(3)];pivot=[origin[0],-origin[2],origin[1]]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(b(p)[i])-pivot[i] for i in range(3)) for p in points],[],faces);mesh.update();mesh.materials.append(material)
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);assert bm.calc_volume(signed=True)>0;volume=bm.calc_volume(signed=True);bm.to_mesh(mesh);bm.free()
 uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 for face in mesh.polygons:
  normal=face.normal.normalized();seed=Vector((1,0,0)) if abs(normal.x)<.85 else Vector((0,1,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=Vector(pivot)+mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
 obj=bpy.data.objects.new(name,mesh);construction.objects.link(obj);obj.location=pivot;stocks.append({'name':name,'volume_m3':volume,'nonmanifold_edges':0});return obj
def box(name,lo,hi,material):
 points=[(x,y,z) for x in [lo[0],hi[0]] for y in [lo[1],hi[1]] for z in [lo[2],hi[2]]];faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)];return make(name,points,faces,material)
for drain in study['outlets']:
 side=drain['side'];x,z=drain['point'];direction={'west':[-1,0,0],'east':[1,0,0],'south':[0,0,-1],'north':[0,0,1]}[side];n=np.array(direction,dtype=float);t=np.array([0,0,1] if side in ['west','east'] else [1,0,0],dtype=float)
 top=Y+study['overburden_toe']+study['membrane_thickness'];origin=np.array([x,top,z])
 def at(along,lateral,vertical):return list(origin+n*along+t*lateral+np.array([0,vertical-outfall*along,0]))
 # Extruded open U section: closed sheet volume, unobstructed air above its
 # floor. The side tops follow the physical fall and stiffen the projecting lip.
 profile=[(-width/2-thickness,-thickness),(width/2+thickness,-thickness),(width/2+thickness,clear_height),(width/2,clear_height),(width/2,0),(-width/2,0),(-width/2,clear_height),(-width/2-thickness,clear_height)]
 vertices=[at(along,lateral,vertical) for along in [0.,reach] for lateral,vertical in profile];num=len(profile);faces=[tuple(reversed(range(num))),tuple(range(num,num*2))]+[(i,(i+1)%num,(i+1)%num+num,i+num) for i in range(num)]
 channel=make('Scupper_'+drain['id']+'__Channel',vertices,faces,steel);parts.append(channel)
 # A tapered bed rests only on the measured retained slab/rim. The channel's
 # final 220 mm projection is its folded side-wall cantilever, not a fake wall.
 bed_length=.405
 bed_profile=[(0,Y),(bed_length,Y),(bed_length,top-thickness-outfall*bed_length),(0,top-thickness)]
 verts=[]
 for lateral in [-width/2-thickness,width/2+thickness]:
  for along,y in bed_profile:verts.append(list(np.array([x,Y,z])+n*along+t*lateral+np.array([0,y-Y,0])))
 bed=make('Scupper_'+drain['id']+'__Bed',verts,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mortar);parts.append(bed)
 ports.append({'id':drain['id'],'side':side,'inner_point':[x,top,z],'normal':list(n),'tangent':list(t),'clear_width':width,'clear_height':clear_height,'sheet_thickness':thickness,'outfall':outfall,'channel_length':reach,'bed_length':bed_length,'outer_lip':at(reach,0,0),'wall_owner':'ROOF_PARAPET_'+side.upper(),'notch_width':width+thickness*2,'notch_floor_y':Y,'notch_top_y':top+clear_height,'open_work':'Fitted perimeter flashing, receiver hopper, supported leader and downstream property connection.'})
for fixture in roof['fixtures']:
 if not fixture['id'].startswith('ROOF_PARAPET_'):continue
 center=np.array(fixture['position'],dtype=float)+np.array([0,Y,0]);half=np.array(fixture['size'])/2;lo=center-half;hi=center+half
 obj=box(fixture['id']+'__NotchedWall',lo,hi,masonry);obj.hide_render=False
 for port in [p for p in ports if p['wall_owner']==fixture['id']]:
  plane=np.array(port['inner_point']);axis=2 if port['side'] in ['west','east'] else 0;cross_axis=0 if axis==2 else 2
  cutlo=lo.copy();cuthi=hi.copy();cutlo[axis]=plane[axis]-port['notch_width']/2;cuthi[axis]=plane[axis]+port['notch_width']/2;cutlo[1]=Y-.01;cuthi[1]=port['notch_top_y'];cutlo[cross_axis]-=.01;cuthi[cross_axis]+=.01
  cutter_name='Cutter_'+port['id'];cutter=box(cutter_name,cutlo,cuthi,mortar);mod=obj.modifiers.new('SourceFit_'+port['id'],'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True);stocks=[s for s in stocks if s['name']!=cutter_name]
 bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0;volume=bm.calc_volume(signed=True);bm.free()
 row=next(s for s in stocks if s['name']==obj.name);row['volume_m3']=volume;row['source_fixture']=fixture;parts.append(obj)
 # Boolean-generated inner faces get their own active metre chart.
 uv=obj.data.uv_layers.active
 for face in obj.data.polygons:
  normal=face.normal.normalized();seed=Vector((1,0,0)) if abs(normal.x)<.85 else Vector((0,1,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
# Triangulate the final fitted polygons before the native save. MikkTSpace
# cannot supply tangents for these concave U caps and Boolean wall polygons.
# This preserves the closed stocks and their already-authored metre charts.
for obj in parts:
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=O/'roof_drainage_ports.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=R/'game/assets/props/roof_drainage_ports.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','ports':ports,'closed_stocks':stocks,'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_bindings':{str(p.relative_to(R)).replace('\\','/'):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [study_path,source_path,Path(__file__)]},'open_work':['source-fitted flashing holes and weather laps','hopper, leader and bearing fixtures','complete downstream route and ground receiver','production wall and floor ownership','all production roof regressions and material acceptance']}
(O/'roof_drainage_ports_construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print('SOURCE ROOF PORTS',len(stocks),'closed stocks;',len(ports),'open U channels; original parapet top/bounds retained')

(R/'game/tests/fixtures/orison_roof_drainage_ports.json').write_bytes((O/'roof_drainage_ports_construction.json').read_bytes())
