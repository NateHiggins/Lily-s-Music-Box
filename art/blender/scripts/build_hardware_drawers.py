"""Source-owned News/Cigars furniture, folded papers, jars and hollow pipe bowls."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('HARDWARE_DRAWERS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('HARDWARE_DRAWERS_PLAN',str(ROOT/'art/data/hardware_drawers/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text());assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_hardware_paint.gltf';source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog_path=Path(os.environ.get('HARDWARE_DRAWERS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text())['materials']
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
   definition=ROOT/f'art/textures/{mapping}/material.json';tile=json.loads(definition.read_text())['meters_per_tile']
  sets[key]={'files':files,'meters_per_tile':tile,'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1),'source_color':pbr.get('baseColorFactor',[1,1,1,1]),'alpha':shipping.get('alphaMode')=='BLEND'}
 material_definitions.append(definition)

def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_hardware_paint_floor'];ceil=rows['storm_shop_hardware_paint_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_hardware_paint','floor':floor})
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
def rod(name,a,b,r,identity,key='timber'):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u);n=48
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





# A fitted cabinet faces the source room on +X; the immutable original
# front/pull boxes sat between its west back and the actual party wall.
item=assemblies[0]
identity=item['id'];carcass=item['body'];x0,y0,x1,y1=carcass['rect'];bottom=carcass['z0'];top=bottom+carcass['h'];floor_top=floor['z0']+floor['h']
# Solid returned plinth; rear, end panels and an overhanging crown seat.
box(identity+'_Plinth',(x0+.018,y0+.018,floor_top),(x1-.018,y1-.018,bottom+.075),identity,'wood_dark',.003)
for yy in [y0,y1-.04]:box(identity+'_End'+str(yy),(x0,yy,bottom+.04),(x1,yy+.04,top-.025),identity,'wood_dark',.004)
box(identity+'_Back',(x0,y0,bottom+.04),(x0+.024,y1,top-.025),identity,'wood_dark',.002)
box(identity+'_Crown',(x0-.012,y0-.015,top-.035),(x1+.035,y1+.015,top),identity,'wood_dark',.004)
box(identity+'_UpperFrieze',(x1-.036,y0+.024,top-.24),(x1+.008,y1-.024,top-.028),identity,'wood_dark',.003)
box(identity+'_ToeFrieze',(x1-.036,y0+.024,bottom+.04),(x1+.008,y1-.024,.235),identity,'wood_dark',.003)
for xx in [x0+.045,x1-.045]:
 for yy in [y0+.06,y1-.06]:support(identity,floor['id'],(xx,yy,floor_top),(0,0,1),'plinth floor bearing')
# Five full-depth rails seat the actual drawer bases. Their original
# vertical spacing and the seven original drawer identities remain.
for r in range(5):
 z=rows['storm_shop_hardware_paint_drawer'+str(r)+'_0']['z0']
 box(identity+'_Rail'+str(r),(x0+.014,y0+.022,z-.035),(x1,y1-.022,z),identity,'wood_dark',.002)
# Close the large primitive spacing with a fitted fixed face frame. Small
# drawer reveals remain around each front rather than open horizontal slots.
for r in range(4):
 face=rows['storm_shop_hardware_paint_drawer'+str(r)+'_0'];next_face=rows['storm_shop_hardware_paint_drawer'+str(r+1)+'_0']
 box(identity+'_FaceRail'+str(r),(x1-.038,y0+.024,face['z0']+face['h']),(x1+.002,y1-.024,next_face['z0']-.035),identity,'wood_dark',.002)
for c in range(6):
 left=rows['storm_shop_hardware_paint_drawer0_'+str(c)];right=rows['storm_shop_hardware_paint_drawer0_'+str(c+1)];at=(left['rect'][1]+right['rect'][3])*.5
 box(identity+'_FaceMuntin'+str(c),(x1-.038,at-.009,bottom+.075),(x1+.002,at+.009,2.16),identity,'wood_dark',.002)
last=rows['storm_shop_hardware_paint_drawer0_6'];first=rows['storm_shop_hardware_paint_drawer0_0']
for index,(a,b) in enumerate([(y0+.035,last['rect'][1]-.004),(first['rect'][3]+.004,y1-.035)]):
 box(identity+'_FaceEndStile'+str(index),(x1-.038,a,bottom+.075),(x1+.002,b,2.16),identity,'wood_dark',.002)
for r in range(5):
 for c in range(7):
  face=rows['storm_shop_hardware_paint_drawer'+str(r)+'_'+str(c)];pull=rows['storm_shop_hardware_paint_drawer_pull'+str(r)+'_'+str(c)];_,a,_,b=face['rect'];z=face['z0'];h=face['h'];front=x1+.020;rear=x0+.025;key='oak_quartered';name=face['id'];identity=name
  # Dossier slice 54: one drawer of the wall stands 0.14 m open on its rail.
  pulled=.14 if (r,c)==(1,3) else 0.;front+=pulled;rear+=pulled
  # A real closed wood base, sides, rear and frame surround the inset
  # panel. Every stock joins the drawer and every drawer seats its rail.
  box(name+'_Bottom',(rear,a,z),(front-.015,b,z+.018),identity,key,.002)
  box(name+'_Rear',(rear,a,z),(rear+.025,b,z+h-.018),identity,key,.002)
  for yy in [a,b-.025]:box(name+'_Side'+str(yy),(rear,yy,z),(front-.015,yy+.025,z+h-.018),identity,key,.002)
  box(name+'_FrontBlank',(front-.05,a,z),(front,b,z+h),identity,key,.003)
  box(name+'_InsetPanel',(front-.002,a+.036,z+.034),(front+.007,b-.036,z+h-.034),identity,key,.002)
  for yy in [a+.004,b-.025]:box(name+'_FrontStile'+str(yy),(front-.002,yy,z+.008),(front+.012,yy+.021,z+h-.008),identity,key,.002)
  for zz in [z+.006,z+h-.027]:box(name+'_FrontRail'+str(zz),(front-.002,a+.004,zz),(front+.012,b-.004,zz+.021),identity,key,.002)
  # Brass rose plates and a bowed bail share the original pull width,
  # height and row datum, translated onto the new room-facing panel.
  _,pa,_,pb=pull['rect'];pz=pull['z0'];ph=pull['h'];mid=(pa+pb)/2;end=[pa+.008,pb-.008];at=pz+ph*.60
  for n,yy in enumerate(end):
   box(pull['id']+'_Rose'+str(n),(front+.005,yy-.008,pz+.015),(front+.012,yy+.008,pz+ph-.015),identity,'brass_dull',.002)
   rod(pull['id']+'_Pin'+str(n),(front+.008,yy,at),(front+.025,yy,at),.0048,identity,'brass_dull')
  path=[]
  for k in range(17):
   t=k/16;path.append((front+.023+.020*__import__('math').sin(__import__('math').pi*t),end[0]+(end[1]-end[0])*t,at-.012*__import__('math').sin(__import__('math').pi*t)))
  curved_wire(pull['id']+'_Bail',path,.0045,identity,'brass_dull')
  support(identity,carcass['id'],(x0+.18+pulled,(a+b)/2,z),(0,0,1),'drawer base on rail '+str(r)+'/'+str(c))

def vessel(name,cx,cy,z,profile,identity,key):
 n=48;verts=[];rings=[]
 for radius,height in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,cy,z+height))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),cy+radius*math.sin(i*math.tau/n),z+height) for i in range(n))
 faces=[]
 for a,b in zip(rings,rings[1:]):
  for i in range(n):
   if len(a)==1:faces.append((a[0],b[i],b[(i+1)%n]))
   elif len(b)==1:faces.append((a[i],b[0],a[(i+1)%n]))
   else:faces.append((a[i],b[i],b[(i+1)%n],a[(i+1)%n]))
 return solid(name,verts,faces,identity,key)

# The inherited paint-bench blank stood directly in front of the lower
# drawers. Fit a supported workbench and translate its passive tin stock
# together; original source rectangles remain in the retained collection.
delta=1.65
for item in assemblies[36:]:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];x0+=delta;x1+=delta;z0=row['z0'];z1=z0+row['h']
 if item['kind']=='paint_bench':
  top=item['members'][1];tx0,ty0,tx1,ty1=top['rect'];tx0+=delta;tx1+=delta;tz=top['z0']+top['h'];floor_top=floor['z0']+floor['h']
  for xx in [x0+.035,x1-.11]:
   for yy in [y0+.05,y1-.125]:
    box(identity+'_Leg'+str(xx)+str(yy),(xx,yy,floor_top),(xx+.075,yy+.075,tz-.002),identity,'timber',.003)
    support(identity,floor['id'],(xx+.0375,yy+.0375,floor_top),(0,0,1),'paint-bench floor bearing')
  for yy in [y0+.035,y1-.075]:
   box(identity+'_ApronEnd'+str(yy),(x0+.035,yy,.84),(x1-.035,yy+.04,tz-.004),identity,'timber',.003)
   box(identity+'_LowEnd'+str(yy),(x0+.055,yy,.24),(x1-.055,yy+.04,.30),identity,'timber',.003)
  for xx in [x0+.035,x1-.075]:
   box(identity+'_LongApron'+str(xx),(xx,y0+.035,.84),(xx+.04,y1-.035,tz-.004),identity,'timber',.003)
   box(identity+'_LowStretcher'+str(xx),(xx,y0+.06,.24),(xx+.04,y1-.06,.30),identity,'timber',.003)
  box(identity+'_MetalWorkFace',(tx0,ty0,tz-.004),(tx1,ty1,tz),identity,'metal',.001)
  for xx in [tx0,tx1-.004]:box(identity+'_MetalReturnX'+str(xx),(xx,ty0,top['z0']),(xx+.004,ty1,tz),identity,'metal',.0008)
  for yy in [ty0,ty1-.004]:box(identity+'_MetalReturnY'+str(yy),(tx0,yy,top['z0']),(tx1,yy+.004,tz),identity,'metal',.0008)
 elif item['kind']=='paint_can':
  cx=(x0+x1)/2;cy=(y0+y1)/2;key=row['mat']
  # Dossier slice 54 (CITY_SHOP_HARDWARE_PAINT-002): three sizes by tin, two dented lids, paint run
  # down two, a wordless paper label band with a colour stripe on each.
  n=int(identity[-1]);R,H={0:(.108,.257),1:(.075,.12),2:(.09,.19)}[(0,1,2,0,1,0,2)[n]];sr=R/.108;sh=H/.257
  vessel(identity+'_SealedTin',cx,cy,z0,[(r*sr,h*sh) for r,h in [(0,0),(.098,0),(.107,.006),(.108,.017),(.105,.020),(.103,.237),(.108,.24),(.108,.252),(.10,.257),(0,.257)]],identity,key)
  lid=[(0,.251),(.099,.251),(.105,.254),(.105,.258),(.10,.260),(0,.260)] if n not in (1,5) else [(0,.251),(.099,.251),(.105,.254),(.105,.258),(.10,.260),(.05,.252),(0,.252)]
  vessel(identity+'_FittedLid',cx,cy,z0,[(r*sr,h*sh) for r,h in lid],identity,'metal')
  vessel(identity+'_LabelBand',cx,cy,z0+H*.3,[(0,0),(R*.955+.0016,0),(R*.955+.0016,H*.38),(0,H*.38)],identity,'paper')
  vessel(identity+'_ColourStripe',cx,cy,z0+H*.44,[(0,0),(R*.955+.0026,0),(R*.955+.0026,H*.1),(0,H*.1)],identity,key)
  if n in (0,3):
   for k,a in enumerate([.4,1.1,2.6]):
    ca,sa=math.cos(a),math.sin(a);rr=R*.955+.0022
    rod(identity+f'_Drip{k}',(cx+rr*ca,cy+rr*sa,z0+H*.985),(cx+rr*ca,cy+rr*sa,z0+H*(.985-.18-.09*k)),.0042,identity,key)
  for sign in [-1,1]:rod(identity+'_BailPin'+str(sign),(cx,cy+sign*(R-.008),z0+H*.78),(cx,cy+sign*(R+.003),z0+H*.78),.006,identity,'metal')
  path=[(cx,cy+(R-.001)*math.cos(i*math.pi/24),z0+H*.78+.145*sr*math.sin(i*math.pi/24)) for i in range(25)]
  curved_wire(identity+'_RaisedBail',path,.0035,identity,'metal')
  support(identity,'storm_shop_hardware_paint_paint_top',(cx,cy,z0),(0,0,1),'sealed tin on metal work face')
 else:raise AssertionError(item['kind'])

for row in selected:
 x0,y0,x1,y1=row['rect'];z0=row['z0'];box(row['id']+'_RetainedBox',(x0,y0,z0),(x1,y1,z0+row['h']),row['id'],row['mat'],0,retained)

# Record the actual finished stock, after bevels, rather than its raw blank.
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
  key=part_key.split('__')[0];vertices=[];faces=[]
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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/hardware_drawers.blend'))
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
asset=OUT/'game/assets/props/hardware_drawers.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),**({'plain_alpha':True} if p['key']=='glassish' else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/hardware_drawers.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/hardware_drawers.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/hardware_drawers.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_hardware_drawers.py')
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/hardware_drawers_construction.json','game/tests/fixtures/orison_hardware_drawers.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('HARDWARE DRAWERS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
