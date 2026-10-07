"""Original Diner griddle, five soda pumps and floor-supported passive mixer."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
# Godot may normalize a provisional import UID without changing any geometry.
# Refresh only that import provenance after import; other drift still refuses.
if '--refresh-import-binding' in sys.argv:
 root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
 paths=[root/'art/blender/diner_apparatus_construction.json',root/'game/tests/fixtures/orison_diner_apparatus.json']
 reports=[json.loads(p.read_text(encoding='utf-8')) for p in paths];assert reports[0]==reports[1]
 report=reports[0];assert hashlib.sha256((root/'game/assets/props/diner_apparatus.glb').read_bytes()).hexdigest()==report['asset_sha256']
 permitted={'art/blender/scripts/build_diner_apparatus.py','game/assets/props/diner_apparatus.glb.import'}
 changed=[]
 for relative,expected in report['source_bindings'].items():
  path=root/relative;data=path.read_bytes();actual=hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
  if actual!=expected:
   assert relative in permitted,('unexpected source drift',relative)
   report['source_bindings'][relative]=actual;changed.append(relative)
 assert 'game/assets/props/diner_apparatus.glb.import' in changed,'no normalized import binding to refresh'
 for path in paths:path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('Refreshed normalized import provenance:',changed,'; mesh and every other source binding unchanged.')
 raise SystemExit(0)
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('DINER_APPARATUS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('DINER_APPARATUS_PLAN',str(ROOT/'art/data/diner_apparatus/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_luncheonette.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('DINER_APPARATUS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json'
 else:
  source_key=plan.get('material_aliases',{}).get(key,key)
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+source_key+'_b','M_'+source_key]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr.get('baseColorTexture'),pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name if texture is not None else None)
  if source_key=='glassish':
   assert files==[None,'T_glass_rough.png','T_glass_normal.png'] and shipping['alphaMode']=='BLEND'
   definition=ROOT/'art/tools/build_glass_maps.py';tile=1.6
  else:
   mapping=files[0].removeprefix('T_').removesuffix('_albedo.png').replace('ai_materials_','ai_materials/',1)
   definition=ROOT/f'art/textures/{mapping}/material.json';tile=json.loads(definition.read_text(encoding='utf-8'))['meters_per_tile']
  sets[key]={'files':files,'meters_per_tile':tile,'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1),'source_color':pbr.get('baseColorFactor',[1,1,1,1]),'alpha':shipping.get('alphaMode')=='BLEND'}
 material_definitions.append(definition)

def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_luncheonette_floor'];ceil=rows['storm_shop_luncheonette_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_luncheonette','floor':floor})
assert len(selected)==plan['original_records'] and len({row['id'] for row in selected})==len(selected)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed=bpy.data.collections.new('ClosedConstruction');bpy.context.scene.collection.children.link(closed);closed.hide_render=True
retained=bpy.data.collections.new('RetainedSourceBoxes');bpy.context.scene.collection.children.link(retained);retained.hide_render=True
materials={};pieces=collections.defaultdict(list);stock_checks=[];contacts=[]
# Actual catalogue images remain in the editable native source. Runtime assigns
# the same existing keys and receives only metre charts, normals and tangents.
for key in plan['runtime_keys']:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;materials[key]=mat
 node=mat.node_tree.nodes['Principled BSDF'];spec=sets[key];node.inputs['Metallic'].default_value=spec.get('metallic',0)
 coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
 if spec.get('alpha'):
  node.inputs['Base Color'].default_value=spec['source_color'];node.inputs['Alpha'].default_value=spec['source_color'][3];mat.surface_render_method='DITHERED'
 for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  if spec['files'][index] is None:continue
  image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True);image.filepath=bpy.path.relpath(image.filepath,start=str(OUT/'art/blender'))
  if index:image.colorspace_settings.name='Non-Color'
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
  if index==2:
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=spec['normal_scale'];mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
  elif index==1:
   multiply=mat.node_tree.nodes.new('ShaderNodeMath');multiply.operation='MULTIPLY';multiply.inputs[1].default_value=spec['roughness'];mat.node_tree.links.new(tex.outputs['Color'],multiply.inputs[0]);mat.node_tree.links.new(multiply.outputs[0],node.inputs[target])
  elif key in plan.get('material_tints',{}):
   multiply=mat.node_tree.nodes.new('ShaderNodeMixRGB');multiply.blend_type='MULTIPLY';multiply.inputs[0].default_value=1.;multiply.inputs[2].default_value=plan['material_tints'][key];mat.node_tree.links.new(tex.outputs['Color'],multiply.inputs[1]);mat.node_tree.links.new(multiply.outputs[0],node.inputs[target])
  else:mat.node_tree.links.new(tex.outputs['Color'],node.inputs[target])

def solid(name,verts,faces,identity,key,collection=closed):
 verts=[Vector(v) for v in verts];origin=Vector(tuple(round(sum(v[i] for v in verts)/len(verts),4) for i in range(3)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([v-origin for v in verts],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 volume=bm.calc_volume(signed=True);assert all(e.is_manifold for e in bm.edges) and volume>1e-12,name
 bm.to_mesh(mesh);bm.free();mesh.materials.append(materials[key])
 obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);obj.location=origin;obj.hide_render=True
 if collection==closed:
  pieces[identity].append((obj,key));stock_checks.append({'name':name,'assembly':identity,'key':key,'volume_m3':volume})
 return obj
def box(name,low,high,identity,key='timber',bevel=.003,collection=closed):
 verts=[(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]]
 obj=solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key,collection)
 if bevel:
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked edge','BEVEL');mod.width=min(bevel,min(high[i]-low[i] for i in range(3))*.4);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj
def rod(name,a,b,r,identity,key='timber',n=48):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u)
 verts=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
 return solid(name,verts,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)
def torus(name,center,rx,ry,r,identity,key):
 n=64;m=12;verts=[]
 for i in range(n):
  angle=i*math.tau/n;normal=Vector((math.cos(angle)/rx,math.sin(angle)/ry,0)).normalized();at=Vector(center)+Vector((rx*math.cos(angle),ry*math.sin(angle),0))
  verts.extend(at+r*(normal*math.cos(j*math.tau/m)+Vector((0,0,math.sin(j*math.tau/m)))) for j in range(m))
 faces=[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)]
 return solid(name,verts,faces,identity,key)
def support(identity,owner,point,direction,label):
 contacts.append({'assembly':identity,'owner':owner,'point':[point[0],point[2],-point[1]],'direction':[direction[0],direction[2],-direction[1]],'label':label})
def curved_wire(name,path,radius,identity,key='chrome'):
 points=[]
 for p in path:
  at=Vector(p)
  if not points or (at-points[-1]).length>1e-9:points.append(at)
 assert len(points)>=2,name
 verts=[];n=8
 closed=(points[-1]-points[0]).length<1e-8
 if closed:points.pop()
 for i,p in enumerate(points):
  tangent=(points[(i+1)%len(points)]-points[(i-1)%len(points)]).normalized() if closed else (points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
  seed=Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0));u=tangent.cross(seed).normalized();v=tangent.cross(u)
  verts.extend(p+radius*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
 faces=[(i*n+j,i*n+(j+1)%n,((i+1)%len(points))*n+(j+1)%n,((i+1)%len(points))*n+j) for i in range(len(points) if closed else len(points)-1) for j in range(n)]
 if not closed:faces=[tuple(reversed(range(n)))]+faces+[tuple(range((len(points)-1)*n,len(points)*n))]
 return solid(name,verts,faces,identity,key)

def prism(name,outline,z0,z1,identity,key,bevel=0):
 n=len(outline);obj=solid(name,[(x,y,z) for z in [z0,z1] for x,y in outline],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key)
 if bevel:
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked perimeter','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj





def vessel(name,cx,cy,z,profile,identity,key):
 n=48;verts=[];rings=[];closed_profile=profile[0]==profile[-1]
 if closed_profile:profile=profile[:-1]
 for radius,height in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,cy,z+height))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),cy+radius*math.sin(i*math.tau/n),z+height) for i in range(n))
 faces=[]
 for a,b in zip(rings,rings[1:]+(rings[:1] if closed_profile else [])):
  for i in range(n):
   if len(a)==1:faces.append((a[0],b[i],b[(i+1)%n]))
   elif len(b)==1:faces.append((a[i],b[0],a[(i+1)%n]))
   else:faces.append((a[i],b[i],b[(i+1)%n],a[(i+1)%n]))
 return solid(name,verts,faces,identity,key)

prefix='storm_shop_luncheonette_'
ground=floor['z0']+floor['h']

def ellipse_vessel(name,cx,cy,z,profile,ratio,identity,key):
 n=64;verts=[];rings=[]
 for radius,height in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,cy,z+height))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),cy+ratio*radius*math.sin(i*math.tau/n),z+height) for i in range(n))
 faces=[]
 for aa,bb in zip(rings,rings[1:]):
  for i in range(n):
   if len(aa)==1:faces.append((aa[0],bb[i],bb[(i+1)%n]))
   elif len(bb)==1:faces.append((aa[i],bb[0],aa[(i+1)%n]))
   else:faces.append((aa[i],bb[i],bb[(i+1)%n],aa[(i+1)%n]))
 return solid(name,verts,faces,identity,key)

def envelope_shell(identity,r,low,high,t,key,tag=''):
 x0,y0,x1,y1=r
 name=identity+tag
 # Recess the plates inside the side skins: no coincident exposed faces.
 box(name+'_Bottom',(x0+.001,y0+.001,low),(x1-.001,y1-.001,low+t),identity,key,.0005)
 box(name+'_Roof',(x0+.001,y0+.001,high-t),(x1-.001,y1-.001,high),identity,key,.0005)
 for xx in [x0,x1-t]:box(name+'_Side'+str(xx),(xx,y0+.001,low+.001),(xx+t,y1-.001,high-.001),identity,key,.0004)
 for yy in [y0,y1-t]:box(name+'_End'+str(yy),(x0+.001,yy,low+.001),(x1-.001,yy+t,high-.001),identity,key,.0004)

def floor_leg(identity,x,y,top,key):
 vessel(identity+'_Foot'+str(x)+str(y),x,y,ground,[(0,0),(.027,0),(.030,.004),(.030,.020),(.022,.029),(.016,.030),(0,.030)],identity,key)
 rod(identity+'_Leg'+str(x)+str(y),(x,y,ground+.023),(x,y,top),.014,identity,key)
 support(identity,floor['id'],(x,y,ground),(0,0,1),'integral floor-bearing apparatus foot')

def nozzle(name,path,radius,inside,identity,key):
 points=[Vector(p) for p in path];n=16;verts=[]
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized();u=Vector((0,1,0));v=tangent.cross(u).normalized()
  for rr in [radius,inside]:verts.extend(p+rr*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n))
 faces=[]
 for i in range(len(points)-1):
  for j in range(n):
   k=(j+1)%n;a=i*2*n;b=(i+1)*2*n
   faces.extend([(a+j,a+k,b+k,b+j),(a+n+j,b+n+j,b+n+k,a+n+k)])
 for j in range(n):
  k=(j+1)%n;last=(len(points)-1)*2*n;faces.extend([(j,n+j,n+k,k),(last+j,last+k,last+n+k,last+n+j)])
 return solid(name,verts,faces,identity,key)

for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];maximum=max(member['z0']+member['h'] for member in item['members']);cx=(x0+x1)*.5;cy=(y0+y1)*.5
 if item['kind']=='griddle':
  for xx in [x0+.08,x1-.08]:
   for yy in [y0+.09,y1-.09]:floor_leg(identity,xx,yy,.650,'metal')
  envelope_shell(identity,row['rect'],.610,.975,.003,'metal')
  top=next(m for m in item['members'] if m['id'].endswith('_top'));r=top['rect'];a,b,c,d=r
  # Empty worked bed and front channel retain the original 1.01m maximum.
  box(identity+'_IronBed',(a+.045,b+.009,.971),(c-.009,d-.009,1.006),identity,'cast_iron',.0015)
  box(identity+'_GutterFloor',(a+.004,b+.006,.971),(a+.048,d-.006,.975),identity,'cast_iron',.0007)
  box(identity+'_GutterOuter',(a+.004,b+.006,.974),(a+.009,d-.006,maximum),identity,'cast_iron',.0007)
  for yy in [b+.006,d-.011]:box(identity+'_GutterEnd'+str(yy),(a+.005,yy,.974),(a+.048,yy+.005,maximum),identity,'cast_iron',.0007)
  for yy in [b+.006,d-.011]:box(identity+'_BedEnd'+str(yy),(a+.044,yy,1.004),(c-.004,yy+.005,maximum),identity,'cast_iron',.0007)
  box(identity+'_BedRear',(c-.011,b+.006,1.004),(c-.004,d-.006,maximum),identity,'cast_iron',.0007)
  for yy in [cy-.29,cy,cy+.29]:
   rod(identity+'_BlankControl'+str(yy),(x0+.002,yy,.83),(a+.012,yy,.83),.015,identity,'metal',32)
 elif item['kind']=='fountain':
  # Source 0.04m floor gap closes only inside its existing plan.
  box(identity+'_StonePlinth',(x0+.001,y0+.001,ground),(x1-.001,y1-.001,.085),identity,'marble_lobby',.003)
  envelope_shell(identity,(x0+.022,y0+.022,x1-.022,y1-.022),.080,.946,.018,'marble_lobby')
  box(identity+'_StoneUpperSlab',(x0,y0,.945),(x1,y1,.970),identity,'marble_lobby',.002)
  for xx in [x0+.06,x1-.06]:
   for yy in [y0+.06,y1-.06]:support(identity,floor['id'],(xx,yy,ground),(0,0,1),'stone apparatus plinth on actual shop floor')
  for pump in item['members'][1:]:
   p=pump['rect'];px=p[2]-.055;py=(p[1]+p[3])*.5;name=pump['id']
   # Closed bottom and 3mm empty body wall; flange seats on actual 0.97m slab.
   vessel(name+'_HollowPump',px,py,.970,[(0,0),(.049,0),(.052,.004),(.052,.023),(.044,.030),(.044,.336),(.041,.336),(.041,.034),(0,.034)],identity,'nickel_plated')
   vessel(name+'_Cap',px,py,1.300,[(0,0),(.043,0),(.046,.006),(.046,.014),(.040,.023),(0,.023)],identity,'nickel_plated')
   rod(name+'_Plunger',(px,py,1.315),(px,py,1.399),.006,identity,'nickel_plated',32)
   vessel(name+'_BlankButton',px,py,1.393,[(0,0),(.037,0),(.044,.008),(.044,.019),(.037,.027),(0,.027)],identity,'nickel_plated')
   nozzle(name+'_OpenNozzle',[(px,py,1.265),(px-.055,py,1.265),(p[0]+.025,py,1.256),(p[0]+.016,py,1.244),(p[0]+.016,py,1.230)],.009,.005,identity,'nickel_plated')
   for dx,dy in [(-.025,0),(.025,0),(0,-.025),(0,.025)]:support(identity,row['id'],(px+dx,py+dy,.970),(0,0,1),'pump flange on actual fitted stone upper slab')
 elif item['kind']=='mixer':
  # Explicit floor stand fixes the original metre-high floating base.
  box(identity+'_FloorStandFoot',(x0+.004,y0+.004,ground),(x1-.004,y1-.004,.055),identity,'enamel',.003)
  envelope_shell(identity,(cx-.044,cy-.044,cx+.044,cy+.044),.050,1.009,.004,'enamel','_Stand')
  envelope_shell(identity,(x0+.005,y0+.005,x1-.005,y1-.005),1.000,1.320,.003,'enamel')
  post=next(m for m in item['members'] if m['id'].endswith('_post'));p=post['rect'];py=(p[1]+p[3])*.5
  rod(identity+'_Column',(p[2]-.016,py,1.318),(p[2]-.016,py,1.829),.011,identity,'nickel_plated',48)
  # A narrow closed motor shell and unpowered spindle; no cup or liquid.
  ellipse_vessel(identity+'_EmptyMotorShell',(p[0]+p[2])*.5,py,1.790,[(0,0),(.084,0),(.096,.012),(.098,.035),(.094,.060),(.080,.070),(.076,.066),(.090,.057),(.094,.034),(.092,.014),(.080,.004),(0,.004)],.038/.098,identity,'nickel_plated')
  ellipse_vessel(identity+'_MotorLid',(p[0]+p[2])*.5,py,1.855,[(0,0),(.079,0),(.083,.002),(.083,.004),(.077,.005),(0,.005)],.038/.098,identity,'nickel_plated')
  sx=p[0]+.025
  rod(identity+'_IdleSpindle',(sx,py,1.353),(sx,py,1.804),.004,identity,'nickel_plated',32)
  rod(identity+'_BlankSpindleEnd',(sx-.010,py,1.353),(sx+.010,py,1.353),.003,identity,'nickel_plated',24)
  for xx in [x0+.035,x1-.035]:
   for yy in [y0+.035,y1-.035]:support(identity,floor['id'],(xx,yy,ground),(0,0,1),'declared integral mixer stand on actual floor')
 else:raise AssertionError(item['kind'])


for row in selected:
 x0,y0,x1,y1=row['rect'];z0=row['z0'];box(row['id']+'_RetainedBox',(x0,y0,z0),(x1,y1,z0+row['h']),row['id'],row['mat'],0,retained)

# Record the actual finished stock, after bevels, rather than its raw blank.
assert len({record['name'] for record in stock_checks})==len(stock_checks),'duplicate construction stock identity'
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12
 bm.free()
def partition_of(obj,key):return key

draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({partition_of(obj,key) for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['body']['z0']))
 for part_key in keys:
  key=part_key;vertices=[];faces=[]
  for obj,material_key in pieces[identity]:
   if partition_of(obj,material_key)!=part_key:continue
   # Sum in doubles before rebasing the assembled draw. World-coordinate
   # float32 addition otherwise collapses tiny bevel faces fifty metres out.
   offset=len(vertices);vertices.extend(tuple(np.asarray(obj.location,dtype=np.float64)+np.asarray(v.co,dtype=np.float64)) for v in obj.data.vertices);faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
  name=identity+'__'+part_key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
   assert np.linalg.norm(np.cross(points[1]-points[0],points[2]-points[0]))>0,(name,face.index,points.tolist())
   n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],key=='timber');fallbacks+=local
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(n)
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/diner_apparatus.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
class ExportUVHandedness:
 corrected=0
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  for primitive in mesh.primitives:
   def vectors(key):
    accessor=primitive.attributes[key];assert accessor.component_type==5126 and accessor.type=='VEC3'
    array=np.frombuffer(accessor.buffer_view.data,dtype='<f4').reshape((-1,3)).astype(np.float64);assert len(array)==primitive.attributes['POSITION'].count;return array
   n=vectors('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];guide=vectors('_TANGENT_GUIDE')
   tangent=guide-n*np.sum(guide*n,axis=1)[:,None];tangent/=np.linalg.norm(tangent,axis=1)[:,None]
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
asset=OUT/'game/assets/props/diner_apparatus.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),**({'plain_alpha':True} if p['key']=='glassish' else {}),} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/diner_apparatus.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/diner_apparatus.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/diner_apparatus.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend([ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_diner_apparatus.py')
for stem in ['shop_seating','diner_receiving','diner_counter','diner_till','diner_backbar','diner_urns']:bindings.extend(ROOT/name for name in [f'art/blender/{stem}.blend',f'game/assets/props/{stem}.glb',f'game/tests/fixtures/orison_{stem}.json',f'game/data/orison_v2/{stem}.json'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/diner_apparatus_construction.json','game/tests/fixtures/orison_diner_apparatus.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('DINER APPARATUS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
