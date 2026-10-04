"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json,math,hashlib,collections
import bpy,bmesh,numpy as np
from mathutils import Vector
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
ports_path=R/'art/blender/roof_drainage_ports_construction.json';ports=json.loads(ports_path.read_bytes())['ports']
survey_path=R/'art/data/orison_roof_drainage/source_plan.json';survey=json.loads(survey_path.read_bytes())['facade_bearings']
ri=.0762;sheet=.0012;ro=ri+sheet;bottom=.30;top=18.80;heights=[.65,3.05,6.25,9.45,12.65,15.85,18.85];N=32
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
native_collection=bpy.data.collections.new('ClosedNativeStocks');bpy.context.scene.collection.children.link(native_collection)
materials={}
for key,color in [('galvanized_roof',(.31,.33,.33,1)),('iron_blackened',(.12,.11,.10,1)),('brass',(.34,.22,.10,1))]:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=color;shader.inputs['Metallic'].default_value=.8;shader.inputs['Roughness'].default_value=.65;materials[key]=mat
stocks=[];leaders=[];supports=[];visible=[]
def b(p):return Vector((p[0],-p[2],p[1]))
def g(p):return [float(p[0]),float(p[2]),float(-p[1])]
def make(name,points,faces,key):
 pivot=[round(sum(p[i] for p in points)/len(points),3) for i in range(3)];origin=b(pivot)
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(float(b(p)[i])-float(origin[i]) for i in range(3)) for p in points],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges),name;volume=bm.calc_volume(signed=True);assert volume>0,name;bm.to_mesh(mesh);bm.free()
 mesh.materials.append(materials[key]);obj=bpy.data.objects.new(name,mesh);native_collection.objects.link(obj);obj.location=origin;obj['material_key']=key
 uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 for face in mesh.polygons:
  normal=face.normal.normalized();seed=Vector((1,0,0)) if abs(normal.x)<.85 else Vector((0,1,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=origin+mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
 stocks.append({'name':name,'volume_m3':volume,'material':key});return obj
def box(name,center,u,v,w,sizes,key='iron_blackened'):
 c=np.array(center);u=np.array(u)*sizes[0]/2;v=np.array(v)*sizes[1]/2;w=np.array(w)*sizes[2]/2
 pts=[list(c+a*u+b*v+d*w) for a in [-1,1] for b in [-1,1] for d in [-1,1]]
 return make(name,pts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],key)
def rod(name,a,c,r,key='iron_blackened',count=12):
 a=np.array(a);c=np.array(c);direction=(c-a)/np.linalg.norm(c-a);seed=np.array([1.,0,0]) if abs(direction[0])<.85 else np.array([0.,0,1.]);u=seed-direction*np.dot(seed,direction);u/=np.linalg.norm(u);v=np.cross(direction,u)
 pts=[list(at+r*(u*math.cos(i*2*math.pi/count)+v*math.sin(i*2*math.pi/count))) for at in [a,c] for i in range(count)]
 return make(name,pts,[tuple(reversed(range(count))),tuple(range(count,count*2))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)],key)
def annular_loft(name,inner_rings,outer_rings,key='galvanized_roof'):
 assert len(inner_rings)==len(outer_rings);count=len(inner_rings[0]);levels=len(inner_rings);pts=[list(p) for ring in outer_rings+inner_rings for p in ring];offset=count*levels;faces=[]
 for ring in range(levels-1):
  for i in range(count):
   j=(i+1)%count;a=ring*count+i;d=ring*count+j;faces.extend([(a,d,d+count,a+count),(offset+a,offset+a+count,offset+d+count,offset+d)])
 for i in range(count):
  j=(i+1)%count;faces.extend([(i,offset+i,offset+j,j),((levels-1)*count+i,(levels-1)*count+j,offset+(levels-1)*count+j,offset+(levels-1)*count+i)])
 return make(name,pts,faces,key)
def sweep(name,path,tangent,inner=ri,outer=ro):
 path=[np.array(p) for p in path];t=np.array(tangent);directions=[(c-a)/np.linalg.norm(c-a) for a,c in zip(path,path[1:])];inside=[];outside=[]
 for index,p in enumerate(path):
  previous=directions[max(index-1,0)];following=directions[min(index,len(directions)-1)];bisector=previous+following;bisector/=np.linalg.norm(bisector);v=np.cross(bisector,t);v/=np.linalg.norm(v);factor=1/max(np.dot(bisector,previous),1e-6)
  for radius,rings in [(inner,inside),(outer,outside)]:rings.append([p+radius*(t*math.cos(i*2*math.pi/N)+v*factor*math.sin(i*2*math.pi/N)) for i in range(N)])
 return annular_loft(name,inside,outside)
def band(name,c,n,t,lo,hi,pipe_outer):
 c=np.array(c);up=np.array([0.,1,0]);angles=np.linspace(lo,hi,17);inner_radius=(pipe_outer+.001)/math.cos((hi-lo)/(2*(len(angles)-1)));pts=[list(c+np.array(n)*r*math.cos(a)+np.array(t)*r*math.sin(a)+up*y) for y in [-.016,.016] for r in [inner_radius,inner_radius+.003] for a in angles];count=len(angles);faces=[]
 for i in range(count-1):
  faces.extend([(i,i+1,count+i+1,count+i),(2*count+i,3*count+i,3*count+i+1,2*count+i+1),(i,2*count+i,2*count+i+1,i+1),(count+i,count+i+1,3*count+i+1,3*count+i)])
 faces.extend([(0,count,3*count,2*count),(count-1,3*count-1,4*count-1,2*count-1)])
 return make(name,pts,faces,'iron_blackened')
for port in ports:
 ident=port['id'];n=np.array(port['normal']);t=np.array(port['tangent']);up=np.array([0.,1,0]);p=np.array(port['inner_point']);c=p+n*.575;c[1]=0
 bearing=survey[ident];assert bearing['owner']=='ExteriorMasonry/MasonryCollision'
 wall_coordinate=bearing['wall_coordinate']
 facade_c=c.copy()
 if port['side']=='north':facade_c+=n*(wall_coordinate+.17-float(np.dot(c,n)))
 path=[c+up*top]
 if port['side']=='north':path += [c+up*18.5,facade_c+up*(18.5-float(np.dot(c-facade_c,n)))]
 path += [facade_c+up*bottom]
 pipe=sweep('Leader_'+ident+'__Pipe',path,t)
 # Each hopper is an atmospheric receiver. Its low rear rim lies beneath the
 # projecting channel; the other three rims contain the visible funnel.
 inner=[];outer=[]
 for radius,height,shape in [(ro,18.74,'round'),(ro,18.87,'round'),(ri,18.90,'round'),(0,19.08,'rectangle'),(0,19.255,'rim')]:
  rings=[]
  for extra in [0,sheet]:
   ring=[]
   for i in range(N):
    a=i*2*math.pi/N
    if shape=='round':dn=(radius+extra)*math.cos(a);dt=(radius+extra)*math.sin(a);y=height
    else:
     divisor=max(abs(math.cos(a)),abs(math.sin(a)));dn=(.16+extra)*math.cos(a)/divisor;dt=(.18+extra)*math.sin(a)/divisor;y=19.195 if shape=='rim' and dn<-.159 else height
    ring.append(c+n*dn+t*dt+up*y)
   rings.append(ring)
  inner.append(rings[0]);outer.append(rings[1])
 hopper=annular_loft('Leader_'+ident+'__Hopper',inner,outer)
 joints=[]
 # External sleeves are actual hollow closed stocks. At straight partition
 # stations they sit on the pipe outer surface without closing its lumen.
 for y in [3.2,6.4,9.6,12.8,16.0]:
  sleeve=sweep('Leader_'+ident+'__Socket_'+str(y),[facade_c+up*(y-.025),facade_c+up*(y+.025)],t,ro,ro+sheet);joints.append({'y':y,'stock':sleeve.name})
 for index,y in enumerate(heights):
  clamp_c=(c if index==6 else facade_c)+up*y;wall=clamp_c+n*(wall_coordinate-float(np.dot(clamp_c,n)));long_bracket=port['side']=='north' and index==6
  if long_bracket:wall-=up*.25
  plate_center=wall+n*.002;prefix='Leader_'+ident+f'__Support_{index:02d}';plate_height=.50 if long_bracket else .12;anchor_y=.22 if long_bracket else .04
  plate=box(prefix+'_Plate',plate_center,t,up,n,[.12,plate_height,.004])
  for a,bv in [(-.04,-anchor_y),(-.04,anchor_y),(.04,-anchor_y),(.04,anchor_y)]:rod(prefix+f'_Anchor_{a}_{bv}',wall+t*a+up*bv+n*.004,wall+t*a+up*bv+n*.010,.004,'brass',6)
  pipe_outer=ro+sheet if index==6 else ro
  for half,(a,bv) in enumerate([(.04,math.pi-.04),(math.pi+.04,2*math.pi-.04)]):band(prefix+f'_Band_{half}',clamp_c,n,t,a,bv,pipe_outer)
  # Two tangent-side ears have through bolts and bridge the split strap.
  for sign in [-1,1]:
   ear=clamp_c+t*sign*(pipe_outer+.006)
   box(prefix+f'_Ear_{sign}',ear,t,up,n,[.018,.032,.030])
   rod(prefix+f'_Bolt_{sign}',ear-n*.021,ear+n*.021,.004,'brass',6)
  strap_outer=(pipe_outer+.001)/math.cos((math.pi-.08)/32)+.003
  attach=clamp_c-n*strap_outer;plate_end=wall+n*.004
  rod(prefix+'_Horizontal',plate_end+up*(.22 if long_bracket else 0),attach,.018 if long_bracket else .010)
  rod(prefix+'_Brace',plate_end-up*(.22 if long_bracket else .045),attach-up*.013,.014 if long_bracket else .008)
  supports.append({'id':prefix,'port':ident,'height':y,'wall_point':list(wall),'normal':list(n),'tangent':list(t),'clamp_center':list(clamp_c),'bearing_owner':'ExteriorMasonry/MasonryCollision','projection_m':float(np.dot(attach-plate_end,n)),'plate_stock':plate.name,'plate_height':plate_height,'plate_probe_y':anchor_y,'pipe_stock':hopper.name if index==6 else pipe.name,'pipe_outer_radius':pipe_outer,'minimum_band_air_gap':.001})
 leaders.append({'id':ident,'side':port['side'],'channel_lip':port['outer_lip'],'hopper_center':list(c),'hopper_stock':hopper.name,'pipe_stock':pipe.name,'pipe_axis':[[float(v) for v in p] for p in path],'bore_radius':ri,'wall':sheet,'sockets':joints,'receiver_open_work':'Fitted into the independent roof receiver socket; retained source authority and bolted property blank remain.'})
# Every closed stock remains editable in native. Export pieces are bounded by
# four-metre vertical cuts with contact faces omitted at internal joins.
export_collection=bpy.data.collections.new('BoundedRuntimeParts');bpy.context.scene.collection.children.link(export_collection);parts=[]
bpy.context.view_layer.update()
for obj in list(native_collection.objects):
 positions=[g(obj.matrix_world@v.co) for v in obj.data.vertices];lo=min(p[1] for p in positions);hi=max(p[1] for p in positions);bands=list(range(math.floor(lo/4),math.floor((hi-1e-8)/4)+1))
 for section in bands:
  bm=bmesh.new();bm.from_mesh(obj.data)
  for y,normal in [(section*4,Vector((0,0,1))),((section+1)*4,Vector((0,0,-1)))]:
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00000005,plane_co=Vector((0,0,y))-obj.location,plane_no=normal,clear_inner=True,clear_outer=False)
  if not bm.faces:bm.free();continue
  mesh=bpy.data.meshes.new(obj.name+f'_P{section}');bm.to_mesh(mesh);bm.free();mesh.materials.append(materials[obj['material_key']]);part=bpy.data.objects.new(mesh.name,mesh);export_collection.objects.link(part);part.location=obj.location.copy();part['material_key']=obj['material_key'];visible.append(part)
# Combine fixed pieces by leader, material and four-metre vertical band.
# This preserves their metre UVs and prevents one draw per screw or strap.
groups=collections.defaultdict(list)
bpy.context.view_layer.update()
for obj in visible:
 center=obj.matrix_world@Vector((0,0,0));owner='_'.join(obj.name.split('__')[0].split('_')[:3]);world=[g(obj.matrix_world@v.co)[1] for v in obj.data.vertices];section=math.floor((min(world)+max(world))/8)
 groups[(owner,obj['material_key'],section)].append(obj)
visible=[]
for (owner,key,section),objects in sorted(groups.items()):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();obj=objects[0];obj.name=f'{owner}__{key}_{section}'
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.0000001);bm.to_mesh(obj.data);bm.free()
 visible.append(obj);parts.append({'name':obj.name,'material':key,'vertical_band':section,'source_piece_count':len(objects)})
native_collection.hide_render=True
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
native=O/'roof_drainage_leaders.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in visible:obj.select_set(True)
class ExportUVHandedness:
 def gather_attribute_change(self,attribute,data,normalized,export_settings):
  if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=R/'game/assets/props/roof_drainage_leaders.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','closed_stocks':stocks,'leaders':leaders,'supports':supports,'parts':parts,'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_bindings':{str(p.relative_to(R)).replace('\\','/'):hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [ports_path,survey_path,Path(__file__)]},'open_work':['reopened native and full bore inspection','actual facade bearings and clearance','hopper and pipe PBR inspection','ground receivers/branches/soil reservations','weather joints and physical roll seams','production source and regression candidate']}
(O/'roof_drainage_leaders_construction.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
(R/'game/tests/fixtures/orison_roof_drainage_leaders.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SOURCE ROOF LEADERS',len(stocks),'closed stocks;',len(supports),'supports;',len(parts),'bounded runtime parts')
