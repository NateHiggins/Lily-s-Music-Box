"""Source-owned period receiving chassis; existing programme owner remains."""
from pathlib import Path
import ast,collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('PHOTO_RECEIVING_OUT',str(ROOT)))
plan_path=Path(os.environ.get('PHOTO_RECEIVING_PLAN',str(ROOT/'art/data/photo_receiving/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_photo_supplies.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('PHOTO_RECEIVING_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json';definition=definition if definition.is_file() else definition.with_name('asset.json');assert definition.is_file()
 else:
  source_key=plan.get('material_aliases',{}).get(key,key)
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+source_key+'_b','M_'+source_key]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr.get('baseColorTexture'),pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name if texture is not None else None)
  if source_key=='glassish':
   assert files==[None,'T_glass_rough.png','T_glass_normal.png'] and shipping['alphaMode']=='BLEND'
   definition=ROOT/'art/tools/build_glass_maps.py';tile=1.6
  else:
   mapping=files[0].removeprefix('T_').removesuffix('_albedo.png').replace('ai_materials_','ai_materials/',1)
   if source_key in catalog:
    definition=ROOT/f'art/textures/{catalog[source_key]["catalog_mapping"]}/material.json';definition=definition if definition.is_file() else definition.with_name('asset.json');assert definition.is_file();tile=catalog[source_key]['meters_per_tile']
   else:
    suffix='_b' if shipping['name'].endswith('_b') else '';definition=ROOT/f'art/textures/ai_materials/{source_key}{suffix}/material.json';assert definition.is_file();tile=json.loads(definition.read_text(encoding='utf-8'))['meters_per_tile']
  sets[key]={'files':files,'meters_per_tile':tile,'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1),'source_color':pbr.get('baseColorFactor',[1,1,1,1]),'alpha':shipping.get('alphaMode')=='BLEND'}
 material_definitions.append(definition)

def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_photo_supplies_floor'];ceil=rows['storm_shop_photo_supplies_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_photo_supplies','floor':floor})
assert len(selected)==plan['original_records'] and len({row['id'] for row in selected})==len(selected)
source_record=selected[0];assert source_record['asm']=='arcade_cab' and source_record['variant']==2
identity=source_record['id'];theta=math.radians(source_record['yaw']);c,s=math.cos(theta),math.sin(theta)
def placed(v):return (source_record['at'][0]+c*v[0]-s*v[1],source_record['at'][1]+s*v[0]+c*v[1],v[2]+source_record.get('z0',0.))
assembler_path=ROOT/'art/blender/scripts/build_orison.py';assembler_source=assembler_path.read_text(encoding='utf-8-sig')
function=next(n for n in ast.parse(assembler_source).body if isinstance(n,ast.FunctionDef) and n.name=='asm_arcade_cab')
namespace={};exec(compile(ast.Module(body=[function],type_ignores=[]),str(assembler_path),'exec'),namespace)
class Collector:
 def __init__(self):self.records=[]
 def box(self,*args):self.records.append({'kind':'box','args':list(args),'triangles':12})
 def cyl(self,*args):self.records.append({'kind':'cyl','args':list(args),'triangles':int(args[-1])*4})
 def hull(self,*args):self.records.append({'kind':'hull','args':list(args),'triangles':12})
collector=Collector();namespace['asm_arcade_cab'](collector,source_record)
assert len(collector.records)==20 and sum(p['triangles'] for p in collector.records)==412
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
 raw=np.asarray([placed(v) for v in verts],dtype=np.float64);origin=Vector(tuple(round(float(np.mean(raw[:,i])),4) for i in range(3)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata((raw-np.asarray(origin,dtype=np.float64)).tolist(),[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 volume=bm.calc_volume(signed=True)
 if volume<0:
  # Concave radial sections can be consistently wound inward by recalc.
  # Reverse their actual faces; retain the signed-positive solid assertion.
  bmesh.ops.reverse_faces(bm,faces=list(bm.faces));volume=bm.calc_volume(signed=True)
  print('CLOSED STOCK ORIENTATION',name,'reversed inward faces; signed_volume_m3=',volume)
 if volume<=1e-12 or not all(e.is_manifold for e in bm.edges):print('CLOSED STOCK DIAGNOSTIC',name,'signed_volume_m3=',volume,'non_manifold_edges=',sum(not e.is_manifold for e in bm.edges))
 assert all(e.is_manifold for e in bm.edges) and volume>1e-12,name
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
def support(identity,owner,point,direction,label):
 contacts.append({'assembly':identity,'owner':owner,'point':[point[0],point[2],-point[1]],'direction':[direction[0],direction[2],-direction[1]],'label':label})
def rod(name,a,b,r,identity,key,n=48):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u)
 verts=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
 return solid(name,verts,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)

def tube_ring(name,a,b,outer,inner,identity,key,n=48):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u)
 verts=[p+radius*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for radius in [outer,inner] for i in range(n)]
 faces=[]
 for i in range(n):
  j=(i+1)%n;faces.extend([(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)])
 return solid(name,verts,faces,identity,key)

def turned_x(name,x_positions,radii,centres,identity,key,n=96):
 # Finite closed radial section. Each section carries its actual axis centre.
 assert len(x_positions)==len(radii)==len(centres)
 verts=[(x,cy+radius*math.cos(i*math.tau/n),cz+radius*math.sin(i*math.tau/n)) for x,radius,(cy,cz) in zip(x_positions,radii,centres) for i in range(n)]
 faces=[]
 for k in range(len(radii)):
  next_k=(k+1)%len(radii)
  for i in range(n):
   j=(i+1)%n;faces.append((k*n+i,k*n+j,next_k*n+j,next_k*n+i))
 return solid(name,verts,faces,identity,key)


floor_top=float(floor['z0'])+float(floor['h']);assert abs(floor_top-.01)<1e-12
for i,(xx,yy) in enumerate((x,y) for x in [-.27,.27] for y in [-.30,.30]):
 rod(identity+'_FloorFoot'+str(i),(xx,yy,floor_top),(xx,yy,.085),.025,identity,'bakelite',48)
 p=placed((xx,yy,floor_top));support(identity,floor['id'],p,(0,0,1),'original foot axis on actual retained floor')
box(identity+'_Bottom',(-.33,-.36,.045),(.33,.36,.075),identity,'bakelite',.004)
box(identity+'_CellTray',(-.302,-.18,.07),(.314,.18,.145),identity,'bakelite_black',.002)
box(identity+'_LeftWall',(-.33,-.36,.07),(-.302,.36,1.705),identity,'bakelite',.003)
box(identity+'_RearWall',(-.31,.332,.07),(.31,.36,1.705),identity,'bakelite',.003)
box(identity+'_Crown',(-.33,-.36,1.685),(.33,.36,1.72),identity,'bakelite',.004)
# An actual side opening surrounds a closed hinged service panel. Its native
# inspection opens no gameplay door and adds no operating or power authority.
for suffix,lo,hi in [
 ('Lower',(.302,-.36,.07),(.33,.36,.11)),('Upper',(.302,-.36,.86),(.33,.36,1.705)),
 ('Front',(.302,-.36,.10),(.33,-.245,.87)),('Rear',(.302,.245,.10),(.33,.36,.87))]:
 box(identity+'_RightFrame'+suffix,lo,hi,identity,'bakelite',.002)
box(identity+'_ServiceDoor',(.307,-.243,.113),(.331,.243,.857),identity,'bakelite',.002)
for i,zz in enumerate([.20,.77]):
 rod(identity+'_ServiceHinge'+str(i),(.326,.249,zz-.028),(.326,.249,zz+.028),.008,identity,'brass_dull',32)
 box(identity+'_HingeLeaf'+str(i),(.324,.219,zz-.021),(.334,.259,zz+.021),identity,'brass_dull',.001)
rod(identity+'_ServiceLatch',(.327,-.192,.60),(.339,-.192,.60),.011,identity,'brass_dull',32)
box(identity+'_InsideSchematic',(.304,-.14,.53),(.309,.14,.75),identity,'paper',.0008)
# Letter-free dark schematic strokes touch the inside sheet. They describe
# passive diagram stock only, without assigning circuit or power authority.
for i,zz in enumerate([.57,.71]):
 rod(identity+'_DiagramRail'+str(i),(.3035,-.11,zz),(.3035,.11,zz),.0006,identity,'bakelite_black',12)
for i,yy in enumerate([-.075,0,.075]):
 for j in range(48):
  a=j*math.tau/48;b=(j+1)*math.tau/48
  rod(identity+'_DiagramValve'+str(i)+'_'+str(j),(.3035,yy+.024*math.cos(a),.65+.024*math.sin(a)),(.3035,yy+.024*math.cos(b),.65+.024*math.sin(b)),.0006,identity,'bakelite_black',10)
 for j,(z0,z1) in enumerate([(.57,.626),(.674,.71)]):rod(identity+'_DiagramLead'+str(i)+str(j),(.3035,yy,z0),(.3035,yy,z1),.0006,identity,'bakelite_black',12)
 rod(identity+'_DiagramGrid'+str(i),(.3035,yy-.0238,.65),(.3035,yy+.0238,.65),.0006,identity,'bakelite_black',12)
box(identity+'_ValveRack',(-.30,-.20,.49),(.313,.25,.515),identity,'bakelite_black',.002)
def turned_z(name,cx,cy,profile,key,n=48):
 verts=[(cx+r*math.cos(i*math.tau/n),cy+r*math.sin(i*math.tau/n),z) for r,z in profile for i in range(n)]
 faces=[tuple(reversed(range(n)))]+[(k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for k in range(len(profile)-1) for i in range(n)]+[tuple(range((len(profile)-1)*n,len(profile)*n))]
 return solid(name,verts,faces,identity,key)
for i,yy in enumerate([-.13,.025,.18]):
 turned_z(identity+'_ValveSocket'+str(i),.18,yy,[(.036,.51),(.036,.548),(.028,.56)],'bakelite_black')
 profile=[(.025,.552),(.0255,.558),(.0268,.564),(.029,.571),(.0317,.580),(.0343,.593),(.0365,.609),(.0378,.627),(.038,.645),(.0372,.661),(.0356,.675),(.033,.688),(.0292,.700),(.0245,.710),(.019,.718),(.013,.724),(.006,.728),(.003,.729)]
 turned_z(identity+'_ValveEnvelope'+str(i),.18,yy,profile,'milk_glass',96)
for i,xx in enumerate([-.16,.10]):
 box(identity+'_WetCell'+str(i),(xx-.09,-.16,.143),(xx+.09,.14,.315),identity,'enamel_appliance',.008)
 box(identity+'_WetCellLid'+str(i),(xx-.091,-.161,.312),(xx+.091,.141,.333),identity,'bakelite_black',.003)
 for j,yy in enumerate([-.09,.07]):
  rod(identity+'_CellTerminal'+str(i)+'_'+str(j),(xx,yy,.329),(xx,yy,.355),.008,identity,'copper_aged',24)
# The original front control heights and footprint meet the retained owner.
box(identity+'_ControlDeck',(-.31,-.49,.88),(.31,-.338,.97),identity,'bakelite_black',.003)
for i in range(3):
 rod(identity+'_Button'+str(i),(-.17+i*.12,-.425,.967),(-.17+i*.12,-.425,.985),.016,identity,'enamel_appliance',32)
rod(identity+'_ExistingStick',(-.20,-.45,.967),(-.20,-.45,1.05),.008,identity,'bakelite_black',32)
# Front construction has a finite cloth-backed grille and actual circular
# scope aperture. The retained live quad stays at local Y=-.386, Z=1.20.
for suffix,lo,hi in [('Lower',(-.31,-.36,.07),(.31,-.338,.54)),('Upper',(-.31,-.36,.80),(.31,-.338,.90)),
 ('Left',(-.31,-.36,.53),(-.245,-.338,.81)),('Right',(.245,-.36,.53),(.31,-.338,.81))]:
 box(identity+'_Front'+suffix,lo,hi,identity,'bakelite',.003)
box(identity+'_GrilleCloth',(-.255,-.344,.535),(.255,-.338,.805),identity,'fabric_warm',.001)
for i in range(7):
 xx=-.228+i*.076;box(identity+'_GrilleBar'+str(i),(xx-.009,-.377,.535),(xx+.009,-.348,.805),identity,'bakelite',.002)
for suffix,zz in [('Bottom',.532),('Top',.8)]:
 box(identity+'_GrilleRail'+suffix,(-.264,-.381,zz),(.264,-.348,zz+.012),identity,'brass_dull',.001)
def rectangular_aperture(name,y0,y1,x_half,z_low,z_high,z_centre,radius,key,n=96):
 outer=[];inner=[]
 for i in range(n):
  angle=i*math.tau/n;dx,dz=math.cos(angle),math.sin(angle)
  edge=min(x_half/abs(dx) if abs(dx)>1e-12 else 1e9, ((z_high-z_centre) if dz>0 else (z_centre-z_low))/abs(dz) if abs(dz)>1e-12 else 1e9)
  outer.append((dx*edge,z_centre+dz*edge));inner.append((dx*radius,z_centre+dz*radius))
 verts=[(x,y,z) for y in [y0,y1] for ring in [outer,inner] for x,z in ring];faces=[]
 for i in range(n):
  j=(i+1)%n;faces.extend([(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)])
 return solid(name,verts,faces,identity,key)
rectangular_aperture(identity+'_ScopeFascia',-.367,-.338,.31,.977,1.557,1.20,.184,'bakelite')
tube_ring(identity+'_CircularScopeBezel',(0,-.402,1.20),(0,-.351,1.20),.212,.1808,identity,'brass_dull',128)
# Dark finite rear scope casing meets the fascia while leaving the feed clear.
tube_ring(identity+'_ScopeCasing',(0,-.356,1.20),(0,-.26,1.20),.186,.18,identity,'bakelite_black',96)
rod(identity+'_ScopeRear',(0,-.268,1.20),(0,-.25,1.20),.186,identity,'bakelite_black',96)
box(identity+'_CardBacking',(-.31,-.40,1.557),(.31,-.337,1.704),identity,'enamel_appliance',.002)
for suffix,lo,hi in [
 ('Left',(-.33,-.42,1.55),(-.30,-.36,1.71)),('Right',(.30,-.42,1.55),(.33,-.36,1.71)),
 ('Bottom',(-.33,-.42,1.548),(.33,-.36,1.558)),('Top',(-.33,-.42,1.700),(.33,-.36,1.715))]:
 box(identity+'_CardFrame'+suffix,lo,hi,identity,'brass_dull',.001)
# Retained coin-door envelope becomes a brass hinge/latch fitting. No new input.
box(identity+'_CoinPlate',(-.09,-.375,.38),(.09,-.355,.55),identity,'brass_dull',.002)
rod(identity+'_CoinLatch',(0,-.381,.448),(0,-.37,.448),.012,identity,'bakelite_black',24)
for i,xx in enumerate([-.072,.072]):
 for j,zz in enumerate([.399,.531]):rod(identity+'_CoinScrew'+str(i)+str(j),(xx,-.379,zz),(xx,-.371,zz),.003,identity,'brass_dull',16)
# A cloth-braided flex stays inside the original collision envelope and has a
# closed, capped construction. It ends on the carcass; no plug or power claim.
path=[]
for i in range(65):
 u=i/64;path.append(Vector((-.322-.038*math.sin(math.pi*u),.20+.05*math.sin(math.tau*u),.32-.245*math.sin(math.pi*u))))
for i in range(len(path)-1):rod(identity+'_FlexCore'+str(i),path[i],path[i+1],.0045,identity,'fabric_warm',16)
for braid in range(2):
 strand=[]
 for i,p in enumerate(path):
  axis=(path[min(i+1,64)]-path[max(i-1,0)]).normalized();a=axis.cross(Vector((0,1,0))).normalized();b=axis.cross(a);angle=i*.68+braid*math.pi
  strand.append(p+.0045*(math.cos(angle)*a+math.sin(angle)*b))
 for i in range(64):rod(identity+'_FlexBraid'+str(braid)+'_'+str(i),strand[i],strand[i+1],.0012,identity,'fabric_warm',10)
rod(identity+'_FlexGrommet',(-.31,.20,.32),(-.334,.20,.32),.012,identity,'bakelite_black',32)

# Hidden comparison stocks are derived from exact original assembler calls.
for i,primitive in enumerate(collector.records):
 args=primitive['args'];name=identity+'_Original'+str(i)
 if primitive['kind']=='box':box(name,tuple(args[1:4]),tuple(args[4:7]),identity,'bakelite',0,retained)
 elif primitive['kind']=='hull':box(name,tuple(args[:3]),tuple(args[3:]),identity,'bakelite',0,retained)
 else:
  key,x,y,z0,z1,r0,r1,n=args;assert r0==r1
  verts=[(x+r0*math.cos(j*math.tau/n),y+r0*math.sin(j*math.tau/n),z) for z in [z0,z1] for j in range(n)]
  solid(name,verts,[tuple(reversed(range(n)))]+[(j,(j+1)%n,n+(j+1)%n,n+j) for j in range(n)]+[tuple(range(n,2*n))],identity,'bakelite',retained)
# Record the actual finished stock, after bevels, rather than its raw blank.
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12,record['name']
 bm.free()
def partition_of(obj,key):
 if obj.name.endswith('_ServiceDoor'):return key+'__service_panel'
 if obj.name.endswith('_ServiceLatch'):return key+'__service_latch'
 if '_Diagram' in obj.name:return key+'__schematic_traces'
 return key

draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({partition_of(obj,key) for obj,key in pieces[identity]});origin=np.array((*item['body']['at'],item['body'].get('z0',0.)))
 for part_key in keys:
  key=part_key.split('__',1)[0];vertices=[];faces=[]
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
   n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],plan.get('material_aliases',{}).get(key,key) in ['timber','wood_dark','oak_quartered']);fallbacks+=local;smooth=[n,n,n]
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(smooth[j])
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/photo_receiving.blend'))
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
asset=OUT/'game/assets/props/photo_receiving.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)

if os.environ.get('PHOTO_RECEIVING_BOOTSTRAP')=='1':
 print('PHOTO RECEIVING bootstrap exported editable native and glTF; import and rebuild before a bound fixture.');sys.exit(0)
source_names={'bakelite':128,'bakelite_black':128,'brass':12,'chrome':12,'enamel':64,'milk_glass':12,'screen':12,'terracotta':32}
source_owners=[]
for key,count in source_names.items():
 name='F01_OWN_SHOP_PHOTO_SUPPLIES_retail_shop_photo_supplies_'+key
 node=next(n for n in source_gltf['nodes'] if n.get('name')==name);mesh=source_gltf['meshes'][node['mesh']];assert len(mesh['primitives'])==1
 primitive=mesh['primitives'][0];accessor=source_gltf['accessors'][primitive['indices']];assert accessor['count']==count*3
 position=source_gltf['accessors'][primitive['attributes']['POSITION']]
 source_owners.append({'name':name,'key':key,'expected_triangles':count,'low':position['min'],'high':position['max']})
raw_hull_name='F01_OWN_SHOP_PHOTO_SUPPLIES_retail_shop_photo_supplies_hull-colonly'
hull_node=next(n for n in source_gltf['nodes'] if n.get('name')==raw_hull_name)
hull_primitive=source_gltf['meshes'][hull_node['mesh']]['primitives'][0];hull_position=source_gltf['accessors'][hull_primitive['attributes']['POSITION']]
assert source_gltf['accessors'][hull_primitive['indices']]['count']==36
runtime={'schema_version':1,'asset':'res://assets/props/photo_receiving.glb','tolerance':plan['trim_tolerance_m'],
 'source_record':source_record,'original_draws':source_owners,'hull_name':raw_hull_name.removesuffix('-colonly'),'raw_hull_name':raw_hull_name,'hull_triangles':12,'hull_low':hull_position['min'],'hull_high':hull_position['max'],
 'parts':[{'name':p['name'],'key':p['key'],'catalog_key':plan['catalog_variants'][p['key']],'tile':sets[p['key']]['meters_per_tile'],'triangles':p['triangles']} for p in inventory]}
(OUT/'game/data/orison_v2/photo_receiving.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),assembler_path,ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/photo_receiving.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/shop_photo_supplies.{suffix}' for suffix in ['gltf','bin'])
bindings.extend([OUT/'art/blender/scripts/inspect_photo_receiving.py',ROOT/'art/data/shop_interiors.py'])
for stem in ['shop_seating','photo_stock','photo_counter','photo_portraits','photo_glazing','photo_cameras','photo_process','photo_enlargers']:
 bindings.extend([ROOT/f'game/assets/props/{stem}.glb',ROOT/f'game/data/orison_v2/{stem}.json',ROOT/f'art/blender/{stem}.blend'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'original_primitives':collector.records,
 'original_assembler_function_sha256':hashlib.sha256(ast.get_source_segment(assembler_source,function).encode()).hexdigest(),
 'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],
 'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),
 'fitted_datums':{'floor_top':floor_top,'maximum':1.72,'scope_centre_local':[0,1.2,-.386],'scope_diameter':.36,'bezel_inner_radius':.1808,'service_panel_closed':True},
 'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/photo_receiving_construction.json','game/tests/fixtures/orison_photo_receiving.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('PHOTO RECEIVING',len(selected),'original assembly;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'floor contacts')
