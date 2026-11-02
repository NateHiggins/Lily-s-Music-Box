"""Additive closet supply/fixing kit; installed fixture is review reference only."""
from pathlib import Path
import json,math,sys,hashlib,collections,ast
import numpy as np
import argparse
args=argparse.ArgumentParser();args.add_argument('--project-root',required=True);args.add_argument('--out');args.add_argument('--check-bindings',action='store_true');a=args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]);R=Path(a.project_root).resolve()
PROFILE_SPECS=[(.3755,False),(.4155,False),(.4255,False),(.4755,False),(.5255,False),(.4255,True)]
def check_service_bindings(root):
 library=json.loads((root/'game/data/orison_v2/domestic_furniture.json').read_text(encoding='utf-8'))
 completion=json.loads((root/'game/data/orison_v2/completion_interiors.json').read_text(encoding='utf-8'))
 layout=json.loads((root/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
 templates={r['id']:r for r in library['furniture']}
 names={'WCService_'+str(round(depth*10000))+('_Bypass' if bypass else '') for depth,bypass in PROFILE_SPECS}
 rows={}
 for row in library['furniture']:
  if row['kind']=='toilet':
   assert row.get('service_profile') in names,('missing/unknown domestic closet profile',row['id']);rows[row['id']]=row['service_profile']
 for row in completion['furniture']:
  if templates[row['template']]['kind']=='toilet':
   assert row.get('service_profile') in names,('missing/unknown completion closet profile',row['id'])
   assert row['id'] not in rows,('duplicate closet binding',row['id']);rows[row['id']]=row['service_profile']
 expected={r['id'] for r in layout['anchors'] if r['id'].endswith('_wc') or r['id']=='F01_STAFF_WC'}
 assert set(rows)==expected,('expanded closet binding/anchor mismatch',sorted(expected-set(rows)),sorted(set(rows)-expected))
 assert len(rows)==19,('changed complete closet roster requires review',len(rows))
 return rows
binding_rows=check_service_bindings(R)
if a.check_bindings:
 print(json.dumps({'scope':'expanded declared profile binding coverage; not wall fit or runtime proof','count':len(binding_rows),'profiles':binding_rows},sort_keys=True));raise SystemExit(0)
assert a.out,'--out is required for native authoring'
O=Path(a.out).resolve();O.mkdir(parents=True,exist_ok=True)
import bpy,bmesh
from mathutils import Vector,Matrix
sys.path.insert(0,str(R/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
from fabrication_normals import stock_corner_normals
from metric_gltf_export import CatalogueMetricUV
assert hashlib.sha256((R/'art/blender/bath_water_closet.blend').read_bytes()).hexdigest()=='4ecf13c4b027c3503e0ff0adf7d783eabe284e499fb651eeedf38f876d3de96b', 'Reinspect changed base closet before rebuilding fitted services'
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/bath_water_closet.blend'));bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
reference=bpy.data.collections.new('00_INSTALLED_REVIEW_REFERENCE');scene.collection.children.link(reference)
for ob in list(scene.objects):
 for c in list(ob.users_collection):c.objects.unlink(ob)
 reference.objects.link(ob)
stocks=bpy.data.collections.new('01_EDITABLE_CLOSED_KIT_STOCKS');scene.collection.children.link(stocks)
exports=bpy.data.collections.new('02_SERVICE_KIT_EXPORTS');scene.collection.children.link(exports)
review=bpy.data.collections.new('03_CPU_REVIEW');scene.collection.children.link(review)
def p(v):return Vector((v[0],-v[2],v[1]))
def g(v):return (v[0],v[2],-v[1])
catalogue=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials'];bindings=[]
optics=ast.literal_eval((R/'game/scripts/generated/material_sets.gd').read_text().split('const OPTICS := ',1)[1])
for key in ['porcelain_fixture','nickel_plated','iron_blackened','wood_dark','brass','rubber_aged']:
 mat=bpy.data.materials[key];mat.use_nodes=True;spec=catalogue[key];bs=mat.node_tree.nodes['Principled BSDF'];bs.inputs['Metallic'].default_value=spec['metallic'];nodes=mat.node_tree.nodes;links=mat.node_tree.links
 coord=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];links.new(coord.outputs['UV'],scale.inputs[0])
 for index,target in enumerate(['Base Color','Roughness','Normal']):
  path=R/'game/assets/building/textures'/spec['files'][index];im=bpy.data.images.load(str(path),check_existing=True)
  if index:im.colorspace_settings.name='Non-Color'
  tex=nodes.new('ShaderNodeTexImage');tex.image=im;links.new(scale.outputs[0],tex.inputs['Vector'])
  if index==2:
   normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=float(optics.get(key,{}).get('normal_scale',.35));links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs[target])
  elif index==1:
   mul=nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=spec['roughness_multiplier'];links.new(tex.outputs['Color'],mul.inputs[0]);links.new(mul.outputs[0],bs.inputs[target])
  else:links.new(tex.outputs['Color'],bs.inputs[target])
 bindings.append({'key':key,'tile_m':spec['meters_per_tile'],'files':spec['files'],'normal_scale':float(optics.get(key,{}).get('normal_scale',.35))})
groups=collections.defaultdict(list);stock_log=[]
def solid(name,vertices,faces,key,profile,bevel=0):
 data=bpy.data.meshes.new(name);data.from_pydata([p(v) for v in vertices],[],faces);data.update();bm=bmesh.new();bm.from_mesh(data)
 if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES')
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));volume=bm.calc_volume(signed=True);assert volume>0 and all(e.is_manifold for e in bm.edges),name
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.materials.append(bpy.data.materials[key]);ob=bpy.data.objects.new(profile+'__'+name,data);stocks.objects.link(ob);ob['profile']=profile;ob['material_key']=key
 groups[profile,key].append(ob);stock_log.append({'name':ob.name,'profile':profile,'key':key,'volume_m3':volume})
 ns=stock_corner_normals(data);data.normals_split_custom_set(ns);uv=data.uv_layers.new(name='Metres')
 for face in data.polygons:
  _,_,q,_=chart_for_triangle(np.array([data.vertices[i].co[:] for i in face.vertices]),np.zeros(3),catalogue[key]['meters_per_tile'])
  for loop,value in zip(face.loop_indices,q):uv.data[loop].uv=value
 return ob
def box(name,lo,hi,key,profile,bevel=.0005):
 return solid(name,[(x,y,z) for z in [lo[2],hi[2]] for y in [lo[1],hi[1]] for x in [lo[0],hi[0]]],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,profile,bevel)
def axial_ring(name,center,axis,outer,inner,length,key,profile,n=24,hex_outer=False):
 axis=Vector(axis).normalized();u=axis.cross(Vector((0,0,1))).normalized() if abs(axis.z)<.9 else axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u);center=Vector(center);vv=[]
 for d,r in [(0,outer),(length,outer),(length,inner),(0,inner)]:
  for j in range(n):
   a=j*math.tau/n;rr=r*math.cos(math.pi/6)/math.cos((a%(math.pi/3))-math.pi/6) if hex_outer and r==outer else r;vv.append(center+axis*d+rr*(u*math.cos(a)+v*math.sin(a)))
 return solid(name,vv,[(k*n+j,k*n+(j+1)%n,((k+1)%4)*n+(j+1)%n,((k+1)%4)*n+j) for k in range(4) for j in range(n)],key,profile)
def rod(name,start,end,r,key,profile,n=24):
 start=Vector(start);end=Vector(end);axis=(end-start).normalized();u=axis.cross(Vector((0,0,1))).normalized() if abs(axis.z)<.9 else axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u)
 vv=[at+r*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for at in [start,end] for j in range(n)];ff=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)];return solid(name,vv,ff,key,profile)
def turned(name,x,h,section,key,profile,n=32,hex_shell=False):
 vv=[]
 for k,(r,z) in enumerate(section):
  for j in range(n):
   a=j*math.tau/n;rr=r*math.cos(math.pi/6)/math.cos((a%(math.pi/3))-math.pi/6) if hex_shell and k<4 else r;vv.append((x+rr*math.cos(a),h+rr*math.sin(a),z))
 return solid(name,vv,[(k*n+j,k*n+(j+1)%n,((k+1)%len(section))*n+(j+1)%n,((k+1)%len(section))*n+j) for k in range(len(section)) for j in range(n)],key,profile)

def beam(name,start,end,width,height,key,profile):
 a=Vector(start);b=Vector(end);axis=(b-a).normalized();side=Vector((axis.z,0,-axis.x));up=Vector((0,1,0))
 vv=[at+up*y+side*x for at in (a,b) for y in (-height/2,height/2) for x in (-width/2,width/2)]
 return solid(name,vv,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,profile,.0005)

def hollow_path(name,points,outer,inner,key,profile,n=32):
 points=[Vector(v) for v in points];rings=[]
 for i,point in enumerate(points):
  axis=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized();u=Vector((0,1,0));v=axis.cross(u).normalized()
  rings.append((point,u,v))
 vertices=[]
 for radius in (outer,inner):
  for point,u,v in rings:
   vertices.extend(point+radius*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
 N=len(points);faces=[]
 for layer in range(2):
  off=layer*N*n
  for i in range(N-1):
   for j in range(n):faces.append((off+i*n+j,off+i*n+(j+1)%n,off+(i+1)*n+(j+1)%n,off+(i+1)*n+j))
 for i in (0,N-1):
  for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,N*n+i*n+(j+1)%n,N*n+i*n+j))
 return solid(name,vertices,faces,key,profile)

profiles={}
for depth,bypass in PROFILE_SPECS:
 name='WCService_'+str(round(depth*10000))+('_Bypass' if bypass else '');root=bpy.data.objects.new(name,None);exports.objects.link(root);root['wall_depth_godot_m']=depth;profiles[name]=root
 house_x=0.0 if bypass else -.17
 # Original16mm supply pipe enters a hollow receiving socket by3mm.
 r=.008
 turned('SupplySocketAndTail',-.17,.23,[(r+.003,.347),(r+.003,.359),(r,.367),(r,.38 if bypass else depth+.015),(.0063,.38 if bypass else depth+.015),(.0063,.367),(r+.0001,.359),(r+.0001,.347)],'nickel_plated',name)
 turned('SupplyCompressionNut',-.17,.23,[(r+.005,.347),(r+.006,.350),(r+.006,.360),(r+.003,.363),(r-.00015,.363),(r-.00015,.347)],'nickel_plated',name,n=24,hex_shell=True)
 turned('SupplyWallEscutcheon',house_x,.23,[(r,depth),(.025,depth),(.026,depth-.001),(.026,depth-.008),(.025,depth-.009),(r,depth-.009)],'nickel_plated',name,n=48)
 if bypass:
  path=[(-.17,.23,.38)]+[(-.158-.012*math.cos(t),.23,.38+.012*math.sin(t)) for t in np.linspace(0,math.pi/2,9)[1:]]
  path.append((-.012,.23,.392))
  path.extend([(-.012+.012*math.sin(t),.23,.404-.012*math.cos(t)) for t in np.linspace(0,math.pi/2,9)[1:]])
  path.append((0,.23,depth+.015))
  hollow_path('OffsetSupplyPipe',path,.008,.0063,'nickel_plated',name)
 for side,x in [('Left',-.16),('Right',.16)]:
  mx=-.08 if bypass and side=='Left' else x
  # Added external porcelain ears are carried by root pads. The cross bore
  # stays outside the sealed vessel; no tank-water penetration is introduced.
  box(side+'PorcelainRoot',(x-.013,.684,.342),(x+.013,.716,.350),'porcelain_fixture',name,.001)
  axial_ring(side+'PorcelainEye',(x-.0125,.70,.358),(1,0,0),.014,.0045,.025,'porcelain_fixture',name,n=24)
  for j,dx in enumerate([-.019,.013]):
   axial_ring(side+'ForkEar'+str(j),(x+dx,.7001,.358),(1,0,0),.008,.0044,.006,'iron_blackened',name,n=24)
   if mx!=x:beam(side+'ForkArm'+str(j),(x+dx+.003,.7001,.364),(mx+dx+.003,.7001,depth-.001),.006,.006,'iron_blackened',name)
   else:box(side+'ForkArm'+str(j),(x+dx,.6971,.364),(x+dx+.006,.7031,depth-.001),'iron_blackened',name,.0005)
  box(side+'WallPlate',(mx-.028,.535,depth-.002),(mx+.028,.735,depth),'iron_blackened',name,.0005)
  # A lower compression stop resists pitch about the two upper cross pins.
  # Its shoe seats on the exterior casting; no vessel bore is introduced.
  rod(side+'LowerContactShoe',(x,.56,.344),(x,.56,.350),.010,'nickel_plated',name)
  if mx!=x:
   start=Vector((x,.56,.349));end=Vector((mx,.56,depth-.001));axial_ring(side+'LowerCompressionStay',start,end-start,.008,.005,(end-start).length,'iron_blackened',name)
  else:axial_ring(side+'LowerCompressionStay',(x,.56,.349),(0,0,1),.008,.005,depth-.350,'iron_blackened',name)
  rod(side+'LoadedCrossPin',(x-.024,.7001,.358),(x+.0245,.7001,.358),.0044,'nickel_plated',name)
  rod(side+'PinHead',(x-.024,.7001,.358),(x-.019,.7001,.358),.007,'nickel_plated',name,n=6)
  axial_ring(side+'PinNut',(x+.019,.7001,.358),(1,0,0),.007,.0044,.005,'nickel_plated',name,n=24,hex_outer=True)
  for j,h in enumerate([.546,.674,.726]):
   rod(side+'AnchorShaft'+str(j),(mx,h,depth-.005),(mx,h,depth+.040),.0025,'nickel_plated',name,n=12)
   axial_ring(side+'AnchorWasher'+str(j),(mx,h,depth-.0028),(0,0,1),.007,.0025,.0008,'nickel_plated',name)
   rod(side+'AnchorHead'+str(j),(mx,h,depth-.005),(mx,h,depth-.0028),.005,'nickel_plated',name,n=6)
 for label,at in [('SupplyHouse',(house_x,.23,depth+.015)),('LeftWall',(-.08 if bypass else -.16,.70,depth)),('RightWall',(.16,.70,depth))]:root[label+'_godot']=list(at)
# Static export by profile/material. Reference remains editable and is excluded.
parts=[]
for (profile,key),objects in groups.items():
 vv=[];faces=[];normal=[];qvalues=[];guides=[]
 for ob in objects:
  mesh=ob.data
  for f in mesh.polygons:
   pp=np.array([mesh.vertices[j].co[:] for j in f.vertices]);_,t,q,_=chart_for_triangle(pp,np.zeros(3),catalogue[key]['meters_per_tile']);base=len(vv);vv.extend(pp);faces.append((base,base+1,base+2));normal.extend(mesh.corner_normals[j].vector[:] for j in f.loop_indices);qvalues.extend(q);guides.extend([g(t)]*3)
 data=bpy.data.meshes.new(profile+'__'+key);data.from_pydata(vv,[],faces);data.materials.append(bpy.data.materials[key]);data.update();data.normals_split_custom_set(normal);uv=data.uv_layers.new(name='Metres');uv.data.foreach_set('uv',np.asarray(qvalues,dtype=np.float32).ravel());metric=data.attributes.new('_METRE_UV','FLOAT_VECTOR','CORNER');metric.data.foreach_set('vector',np.column_stack((qvalues,np.zeros(len(qvalues)))).astype(np.float32).ravel());guide=data.attributes.new('_TANGENT_GUIDE','FLOAT_VECTOR','CORNER');guide.data.foreach_set('vector',np.asarray(guides,dtype=np.float32).ravel());ob=bpy.data.objects.new(profile+'__'+key,data);exports.objects.link(ob);ob.parent=bpy.data.objects[profile];ob['material_key']=key;parts.append({'name':ob.name,'profile':profile,'key':key,'triangles':len(faces)})
stocks.hide_render=True;stocks.hide_viewport=True
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=CatalogueMetricUV
def export(path,objects):
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objects:ob.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(O/path),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT',export_animations=False,export_extras=True)

export('bath_water_closet_services.glb',list(exports.objects))
report={'evidence_class':'INERT','scope':'Native library authoring only; four retained profiles, one deeper staff profile and one ventilation bypass. Original fixture and service clearances unchanged.','profiles':[{'name':n,'wall_depth_m':float(ob['wall_depth_godot_m']),'triangles':sum(x['triangles'] for x in parts if x['profile']==n)} for n,ob in profiles.items()],'parts':parts,'stocks':stock_log,'material_bindings':bindings}
(O/'construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(O/'bath_water_closet_services.blend'))
print('CORRECTED_CLOSET_NATIVE',json.dumps(report['profiles']),flush=True)
