"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import sys,json,math,hashlib,collections
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import roof_drainage_field as roof
R=roof.R;O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
layout_path=R/'game/data/orison_v2_blockout.json';layout=json.loads(layout_path.read_bytes())
native_tank=R/'art/blender/house_tank.blend'
bpy.ops.wm.open_mainfile(filepath=str(native_tank))
# Derive straight post contours from the saved source vertices, never AABBs.
legs=[q for q in layout['fixtures'] if q.get('fabrication')=='house_tank' and q.get('fabrication_part')=='support']
body=next(q for q in layout['fixtures'] if q.get('fabrication')=='house_tank' and q.get('fabrication_part')=='body')
origin=Vector((body['position'][0],0,body['position'][2]))
def game(p):return Vector((p.x,p.z,-p.y))
def blender(p):return Vector((p[0],-p[2],p[1]))
def contour(obj,at):
 positions=[game(obj.matrix_world@v.co)+origin for v in obj.data.vertices];y=at[1]
 points=[]
 for edge in obj.data.edges:
  a,c=[positions[i] for i in edge.vertices]
  if abs(c.y-a.y)<1e-9:continue
  t=(y-a.y)/(c.y-a.y)
  if 0<t<1:points.append(np.array([a.x+t*(c.x-a.x),a.z+t*(c.z-a.z)]))
 unique={tuple(round(float(v),7) for v in p):p for p in points}
 points=list(unique.values());center=np.mean(points,axis=0)
 points.sort(key=lambda p:math.atan2(p[1]-center[1],p[0]-center[0]))
 # Straight triangulation crossings are collinear; retain native bevel corners.
 changed=True
 while changed:
  changed=False
  for i in range(len(points)):
   a=points[i]-points[i-1];c=points[(i+1)%len(points)]-points[i]
   if abs(a[0]*c[1]-a[1]*c[0])<1e-10:
    points.pop(i);changed=True;break
 assert len(points)>=8,(obj.name,len(points))
 return points
leg_sections=[]
bpy.context.view_layer.update()
for row in legs:
 candidates=[]
 for obj in bpy.context.scene.objects:
  if obj.type=='MESH' and obj.name.startswith('SupportColumn'):
   c=game(obj.matrix_world@Vector((0,0,0)))+origin
   if math.hypot(c.x-row['position'][0],c.z-row['position'][2])<.001:candidates.append(obj)
 assert len(candidates)==1,(row['id'],[o.name for o in candidates])
 at=list(row['position']);leg_sections.append({'id':row['id'],'source_stock':candidates[0].name,'outline':[p.tolist() for p in contour(candidates[0],at)],'native_section_y':at[1]})
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed_collection=bpy.data.collections.new('ClosedPlantWeatherStocks');bpy.context.scene.collection.children.link(closed_collection);closed_collection.hide_render=True
materials={}
for key,color,metal,rough in [('concrete',(.30,.28,.25,1),0,.9),('galvanized_roof',(.35,.37,.38,1),.9,.5),('rubber_aged',(.08,.075,.07,1),0,.9)]:
 m=bpy.data.materials.new(key);m.use_nodes=True;s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=color;s.inputs['Metallic'].default_value=metal;s.inputs['Roughness'].default_value=rough;materials[key]=m
stocks=[];groups=collections.defaultdict(list);feet=[];fan_specs=[];tank_specs=[]
def offset(outline,d):
 result=[]
 for i,p in enumerate(outline):
  before=p-outline[i-1];after=outline[(i+1)%len(outline)]-p
  n1=np.array([before[1],-before[0]])/np.linalg.norm(before);n2=np.array([after[1],-after[0]])/np.linalg.norm(after)
  m=n1+n2;result.append(p+m*d/np.dot(m,n1))
 return result
def piece(name,vertices,faces,key,owner,weights=None,omit=()):
 pivot=sum((blender(v) for v in vertices),Vector())/len(vertices);pivot=Vector(tuple(round(float(v),3) for v in pivot))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([blender(v)-pivot for v in vertices],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);source=bm.faces.layers.int.new('SourceFace')
 for index,face in enumerate(bm.faces):face[source]=index
 follow=bm.verts.layers.float.new('FollowRoof')
 for vertex,weight in zip(bm.verts,weights or [0.]*len(vertices)):vertex[follow]=weight
 if weights:
  footprint=np.array([[v[0],v[2]] for v in vertices]);lo=footprint.min(axis=0)-1e-6;hi=footprint.max(axis=0)+1e-6
  for a,c in roof.edges.values():
   if np.any(np.maximum(a,c)<lo) or np.any(np.minimum(a,c)>hi):continue
   direction=c-a;normal=Vector((-direction[1],-direction[0],0)).normalized()
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-8,plane_co=blender((a[0],19.2,a[1]))-pivot,plane_no=normal,clear_inner=False,clear_outer=False)
  for vertex in bm.verts:
   if vertex[follow]>.000001:
    p=game(vertex.co+pivot);vertex.co.z+=(roof.height(p.x,p.z)-19.2)*vertex[follow]
 # Field cuts meet at a few sub-micrometre wedges after native float storage.
 # Weld those intersections before triangulation, below the 5 micrometre fit
 # bound, so actual imported UVs do not acquire zero-area corner triangles.
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000002);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),name
 volume=bm.calc_volume(signed=True);assert volume>0,name
 bm.to_mesh(mesh);bm.free();mesh.update();mesh.materials.append(materials[key])
 obj=bpy.data.objects.new(name,mesh);closed_collection.objects.link(obj);obj.location=pivot;obj['material_key']=key;obj.hide_render=True
 stocks.append({'name':name,'owner':owner,'material':key,'volume_m3':volume,'native_closed':True})
 for polygon in mesh.polygons:
  source_id=mesh.attributes['SourceFace'].data[polygon.index].value
  if source_id not in omit:groups[(owner,key)].append([mesh.vertices[v].co+pivot for v in polygon.vertices])
 return obj
def ring(name,outline,profiles,key,owner,follow=None,omit=()):
 n=len(outline);vertices=[]
 for distance,y in profiles:
  vertices.extend([[p[0],y,p[1]] for p in offset(outline,distance)])
 faces=[(j*n+i,j*n+(i+1)%n,((j+1)%len(profiles))*n+(i+1)%n,((j+1)%len(profiles))*n+i) for j in range(len(profiles)) for i in range(n)]
 return piece(name,vertices,faces,key,owner,[q for q in follow for _ in outline] if follow else None,[j*n+i for j in omit for i in range(n)])
def weather(owner,outline,top,stand_off=0.):
 # 60 mm field foot and 1.2 mm sheet. Each native foot is split at the real
 # affine roof edges; the horizontal terminal does not follow roof height.
 if stand_off:
  profile=[(stand_off,19.2),(.060,19.2),(.060,19.2012),(stand_off+.0012,19.2012),(stand_off+.0012,top-.030),(.0012,top-.010),(.0012,top),(0.,top),(0.,top-.010),(stand_off,top-.030)]
  follows=[1,1,1,1,0,0,0,0,0,0];omit=[0,7,8,9];band_low=top-.008
 else:
  profile=[(0.,19.2),(.060,19.2),(.060,19.2012),(.0012,19.2012),(.0012,top),(0.,top)];follows=[1,1,1,1,0,0];omit=[0,5];band_low=top-.020
 obj=ring(owner+'__WeatherBoot',outline,profile,'galvanized_roof',owner,follows,omit=omit)
 # Exposed terminal clamp has a narrow compressible seal behind it.
 ring(owner+'__TerminalSeal',outline,[(0,top-.004),(.0012,top-.004),(.0012,top+.001),(0,top+.001)],'rubber_aged',owner,omit=[3])
 ring(owner+'__TerminalBand',outline,[(.0012,band_low),(.0032,band_low),(.0032,top+.002),(.0012,top+.002)],'galvanized_roof',owner,omit=[3])
 for p in offset(outline,.04):feet.append({'owner':owner,'point':[float(p[0]),roof.height(*p)+.0012,float(p[1])]})
 return obj
for anchor in [q for q in layout['anchors'] if 'ROOF_VENT_FAN_' in q['id']]:
 ident=anchor['id'];x,_,z=anchor['position'];outline=[np.array([x+a,z+c]) for a,c in [(-.36,-.36),(.36,-.36),(.36,.36),(-.36,.36)]]
 highest=roof.patch_max([x-.42,z-.42,x+.42,z+.42]);shift=highest-19.2+.032;top=19.2+shift+.148
 pedestal=ring(ident+'__CurbExtension',outline,[(0,19.2),(0,19.2+shift),(-.26,19.2+shift),(-.26,19.2)],'concrete',ident,omit=[1,3])
 inner=[np.array([x+a,z+c]) for a,c in [(-.09,-.09),(.09,-.09),(.09,.09),(-.09,.09)]]
 throat=ring(ident+'__DuctExtension',inner,[(0,19.369),(0,19.369+shift),(-.002,19.369+shift),(-.002,19.369)],'galvanized_roof',ident,omit=[1,3])
 weather(ident,outline,top)
 fan_specs.append({'id':ident,'center':[x,19.2,z],'yaw':anchor.get('yaw',0),'machine_offset_y':shift,'highest_field_y':highest,'weather_terminal_y':top,'minimum_exposed_upstand_m':top-highest,'pedestal_stock':pedestal.name,'duct_stock':throat.name,'curb_bore':.20,'duct_outer':.18,'duct_inner':.176,'retained_anchor_y':19.2,'retained_machine_local_geometry':True})
for section in leg_sections:
 ident=section['id'];outline=[np.array(p) for p in section['outline']];lo=np.min(outline,axis=0)-.06;hi=np.max(outline,axis=0)+.06
 highest=roof.patch_max([lo[0],lo[1],hi[0],hi[1]]);top=highest+.18;weather(ident,outline,top,stand_off=.010)
 tank_specs.append({**section,'highest_field_y':highest,'weather_terminal_y':top,'minimum_exposed_upstand_m':.18,'original_bearing_y':19.2,'weather_wall_stand_off_m':.010,'lower_column_rivet_clearance_m':.002,'roof_reservation':'original 220 mm physical post box; native beveled corners are inside the sealed boot'})
parts=[]
for (owner,key),polygons in sorted(groups.items()):
 pivot=sum((p for polygon in polygons for p in polygon),Vector())/sum(map(len,polygons));pivot=Vector(tuple(round(float(v),3) for v in pivot));vertices=[];faces=[]
 for polygon in polygons:
  start=len(vertices);vertices.extend(p-pivot for p in polygon);faces.append(tuple(range(start,start+len(polygon))))
 mesh=bpy.data.meshes.new(owner+'__'+key);mesh.from_pydata(vertices,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000002);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
 uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 for face in mesh.polygons:
  normal=face.normal.normalized();seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
 mesh.materials.append(materials[key]);obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=pivot;parts.append(obj)
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=O/'roof_drainage_plant_weather.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='NORMAL':self.normals=np.array(data['data'],dtype=np.float64).reshape(-1,3)
  elif attribute=='TANGENT':
   result=np.zeros((len(self.normals),4),dtype=np.float32)
   for i,normal in enumerate(self.normals):
    seed=np.array((0,0,-1) if abs(normal[2])<.85 else (1,0,0),dtype=np.float64);t=seed-normal*np.dot(seed,normal);t/=np.linalg.norm(t);result[i,:3]=t;result[i,3]=-1
   data['data']=result
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=R/'game/assets/props/roof_drainage_plant_weather.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_bindings':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() if p.suffix!='.blend' else hashlib.sha256(p.read_bytes()).hexdigest() for p in [layout_path,native_tank,roof.field_path,Path(__file__),Path(roof.__file__)]},'closed_stocks':stocks,'parts':[{'name':obj.name,'material':obj.data.materials[0].name} for obj in parts],'fan_curbs':fan_specs,'tank_boots':tank_specs,'field_feet':feet,'open_work':['reopen native and inspect true sheet contacts/bore/supports','original moving machines, controls and register audio','full composed roof route','door pans, ground receivers and production installation']}
for path in [O/'roof_drainage_plant_weather_construction.json',R/'game/tests/fixtures/orison_roof_drainage_plant_weather.json']:path.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SOURCE PLANT WEATHER',len(stocks),'closed stocks;',len(parts),'bounded parts; offsets',[(q['id'],q['machine_offset_y']) for q in fan_specs])
