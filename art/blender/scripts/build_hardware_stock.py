"""Source-owned hardware rack stock, window stand and original service counter."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('HARDWARE_STOCK_OUT',str(ROOT)))
plan_path=Path(os.environ.get('HARDWARE_STOCK_PLAN',str(ROOT/'art/data/hardware_stock/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text());assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_hardware_paint.gltf';source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog_path=Path(os.environ.get('HARDWARE_STOCK_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text())['materials']
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

prefix="storm_shop_hardware_paint_"
labels_by_cell={}
# Original bins identify stock positions; new cases carry their actual shelves.
def bounds(row):
 x0,y0,x1,y1=row['rect'];return x0,y0,x1,y1,row['z0'],row['z0']+row['h']
def rack_span(row):
 x0,_,x1,_=row['rect'];x0+=.20;x1+=.20
 if '_bin_e' in row['id']:x0=max(x0,rows[prefix+'boh_door']['rect'][2]+.040)
 return x0,x1
for item in assemblies:
 identity=item['id'];kind=item['kind'];row=item['body'];x0,y0,x1,y1,z0,z1=bounds(row);ground=floor['z0']+floor['h']
 if kind=='rack':
  x0,x1=rack_span(row);upper=max(r['z0']+r['h'] for r in item['members'])
  for xx in [x0+.026,(x0+x1)*.5,x1-.026]:
   for yy in [y0+.028,y1-.028]:
    box(identity+'_CasePost'+str(xx)+str(yy),(xx-.022,yy-.022,ground),(xx+.022,yy+.022,upper),identity,'timber',.002)
    support(identity,floor['id'],(xx,yy,ground),(0,0,1),'rack floor bearing')
  for shelf in item['members']:
   sx0,sy0,sx1,sy1,sz0,sz1=bounds(shelf);sx0,sx1=rack_span(shelf)
   box(shelf['id']+'_Shelf',(sx0,sy0,sz0),(sx1,sy1,sz1),identity,'timber',.003)
   for yy in [sy0+.018,sy1-.032]:box(shelf['id']+'_ReturnedEdge'+str(yy),(sx0,yy,sz0-.055),(sx1,yy+.014,sz0+.004),identity,'timber',.001)
  for xx in [x0+.029,x1-.029]:
   rod(identity+'_SideBrace'+str(xx),(xx,y0+.025,.14),(xx,y1-.025,upper-.025),.009,identity,'metal')
  if identity==prefix+'bin_w0':
   # Dossier slice 69 (CITY_SHOP_HARDWARE_PAINT-001): the capsules are bought here. An open plywood box of
   # carbon transmitter capsules at the rack end nearest the counter, seated 0.2 mm into the shelf.
   shelf=rows[prefix+'bin_w2'];t=shelf['z0']+shelf['h']-.0002;bx0,bx1,by0,by1=8.80,9.03,-54.52,-54.27
   box(identity+'_CapsuleBoxBase',(bx0,by0,t),(bx1,by1,t+.008),identity,'plywood',.001)
   for xx in [bx0,bx1-.008]:box(identity+'_CapsuleBoxSide'+str(xx),(xx,by0,t+.0078),(xx+.008,by1,t+.055),identity,'plywood',.001)
   for yy in [by0,by1-.008]:box(identity+'_CapsuleBoxEnd'+str(yy),(bx0+.0078,yy,t+.0078),(bx1-.0078,yy+.008,t+.055),identity,'plywood',.001)
   # The lid stood up against the back, hinged on its paper tape.
   box(identity+'_CapsuleBoxLid',(bx0,by1-.004,t+.05),(bx1,by1+.004,t+.29),identity,'plywood',.001)
   for i in range(2):
    for j in range(4):
     cx=bx0+.06+i*.11;cy=by0+.037+j*.059
     vessel(identity+f'_Capsule{i}{j}',cx,cy,t+.0076,[(0,0),(.024,0),(.025,.004),(.025,.017),(.021,.021),(0,.021)],identity,'metal')
     vessel(identity+f'_CapsuleRim{i}{j}',cx,cy,t+.0076+.0205,[(0,0),(.0215,0),(.0215,.0025),(0,.0025)],identity,'brass_dull')
 elif kind in ['orange_stock','brass_stock','nail_stock']:
  x0+=.20;x1+=.20
  if '_stock_e' in identity:
   shelf=rows[prefix+'bin_e0'];a,b=rack_span(shelf);old_a=shelf['rect'][0]+.20
   center=(x0+x1)*.5;shift=a+(center-old_a)*(b-a)/(b-old_a)-center;x0+=shift;x1+=shift
  cx=(x0+x1)/2;cy=(y0+y1)/2;key='safety_orange' if kind=='orange_stock' else 'timber'
  box(identity+'_TrayBase',(x0,y0,z0),(x1,y1,z0+.012),identity,key,.001)
  for xx in [x0,x1-.012]:box(identity+'_TraySide'+str(xx),(xx,y0,z0+.009),(xx+.012,y1,z0+.12),identity,key,.001)
  for yy in [y0,y1-.012]:box(identity+'_TrayEnd'+str(yy),(x0,yy,z0+.009),(x1,yy+.012,z0+.055),identity,key,.001)
  if kind=='brass_stock':
   for xx in [cx-.072,cx+.072]:
    for yy in [cy-.077,cy+.077]:
     vessel(identity+'_OpenCoupling'+str(xx)+str(yy),xx,yy,z0+.012,[(.036,0),(.040,.006),(.040,.021),(.032,.023),(.032,.106),(.04,.108),(.04,.125),(.035,.13),(.022,.13),(.022,0),(.036,0)],identity,'brass_dull')
  elif kind=='nail_stock':
   for k in range(9):
    xx=x0+.038+k*.031;zz=z0+.022
    rod(identity+'_NailShaft'+str(k),(xx,cy-.101,zz),(xx,cy+.095,z0+.0155),.0035,identity,'metal')
    rod(identity+'_NailHead'+str(k),(xx,cy-.103,zz),(xx,cy-.100,zz),.010,identity,'metal')
  else:
   for xx in [cx-.077,cx+.077]:
    for yy in [cy-.082,cy+.082]:
     vessel(identity+'_SteelWasher'+str(xx)+str(yy),xx,yy,z0+.012,[(.049,0),(.05,.003),(.05,.012),(.025,.012),(.025,0),(.049,0)],identity,'metal')
     rod(identity+'_BoltShaft'+str(xx)+str(yy),(xx,yy,z0+.012),(xx,yy,z0+.103),.016,identity,'metal')
     rod(identity+'_BoltHead'+str(xx)+str(yy),(xx,yy,z0+.096),(xx,yy,z0+.116),.032,identity,'metal',6)
  shelf=prefix+'bin_'+('w' if '_stock_w' in identity else 'e')+str(int(re.search(r'stock_[we](\d+)$',identity).group(1))//6)
  support(identity,shelf,(cx,cy,z0),(0,0,1),'stock tray on original shelf datum')
 elif kind=='counter':
  top=item['members'][1];tx0,ty0,tx1,ty1,tz0,tz1=bounds(top)
  for xx in [x0+.035,x1-.035]:
   for yy in [y0+.04,y1-.04]:
    box(identity+'_Leg'+str(xx)+str(yy),(xx-.024,yy-.024,ground),(xx+.024,yy+.024,tz0),identity,'wood_dark',.003)
    support(identity,floor['id'],(xx,yy,ground),(0,0,1),'service counter floor bearing')
  for zz in [.10,tz0-.085]:
   for xx in [x0+.02,x1-.04]:box(identity+'_LongRail'+str(xx)+str(zz),(xx,y0+.016,zz),(xx+.022,y1-.016,zz+.085),identity,'wood_dark',.002)
   for yy in [y0+.02,y1-.04]:box(identity+'_EndRail'+str(yy)+str(zz),(x0+.016,yy,zz),(x1-.016,yy+.022,zz+.085),identity,'wood_dark',.002)
  # Aisle-facing inset panels and their stile frame meet both rails.
  for k in range(4):
   yy=y0+.10+k*(y1-y0-.20)/4;end=yy+(y1-y0-.20)/4
   box(identity+'_InsetPanel'+str(k),(x0+.016,yy,.18),(x0+.026,end,tz0-.045),identity,'wood_dark',.002)
   box(identity+'_Stile'+str(k),(x0+.005,yy-.01,.11),(x0+.035,yy+.014,tz0),identity,'wood_dark',.002)
  box(identity+'_WorkTop',(tx0,ty0,tz0),(tx1,ty1,tz1),identity,'countertop',.003)
  ledger=item['members'][2];lx0,ly0,lx1,ly1,lz0,lz1=bounds(ledger)
  box(identity+'_LedgerSeat',(lx0,ly0,tz1),(lx1,ly1,lz0+.003),identity,'wood_dark',.001)
  box(identity+'_LedgerLeaves',(lx0+.005,ly0+.005,lz0),(lx1-.005,ly1-.005,lz1-.005),identity,'paper',.001)
  box(identity+'_LedgerCover',(lx0,ly0,lz1-.007),(lx1,ly1,lz1),identity,'wood_dark',.001)
  # Dossier slice 69 (CITY_SHOP_HARDWARE_PAINT-001): a brass counter bell and the night-service card at the
  # north end, clear of the purchase reach over the counter's middle; both seated 0.2 mm into the top.
  bz=tz1-.0002
  vessel(identity+'_BellBase',9.74,-55.30,bz,[(0,0),(.05,0),(.05,.010),(.046,.014),(0,.014)],identity,'wood_dark')
  vessel(identity+'_BellDome',9.74,-55.30,bz+.0138,[(0,0),(.043,0),(.042,.008),(.036,.024),(.024,.036),(.010,.041),(0,.042)],identity,'brass_dull')
  rod(identity+'_BellPlunger',(9.74,-55.30,bz+.0545),(9.74,-55.30,bz+.072),.004,identity,'metal')
  vessel(identity+'_BellButton',9.74,-55.30,bz+.0715,[(0,0),(.011,0),(.011,.005),(.006,.008),(0,.008)],identity,'brass_dull')
  box(identity+'_NightCard',(9.700,-55.11,bz),(9.703,-54.99,bz+.085),identity,'paper',.0004)
  rod(identity+'_CardStay',(9.7025,-55.05,bz+.07),(9.76,-55.05,bz+.0004),.0018,identity,'metal')
  labels_by_cell.setdefault(item['cell'],[]).append({'id':'night_service','text':'NIGHT SERVICE\nRING BELL STOP','at':[9.6995,round(bz+.046,4),55.05],'yaw':-1.5707963,'font_size':40,'pixel_size':.0004})
 elif kind=='window_stand':
  for xx in [x0+.032,x1-.032]:
   for yy in [y0+.05,y1-.05]:
    box(identity+'_Foot'+str(xx)+str(yy),(xx-.024,yy-.024,ground),(xx+.024,yy+.024,z1),identity,'wood_dark',.002)
    support(identity,floor['id'],(xx,yy,ground),(0,0,1),'window stand floor bearing')
  box(identity+'_Deck',(x0,y0,z1-.032),(x1,y1,z1),identity,'wood_dark',.002)
  for yy in [y0+.025,y1-.04]:box(identity+'_EndFrame'+str(yy),(x0,yy,z0+.07),(x1,yy+.02,z1),identity,'wood_dark',.001)
  for xx in [x0+.01,x1-.03]:box(identity+'_LongFrame'+str(xx),(xx,y0,z0+.07),(xx+.02,y1,z1),identity,'wood_dark',.001)
  back=item['members'][1];bx0,by0,bx1,by1,bz0,bz1=bounds(back)
  box(identity+'_BackPanel',(bx0,by0,bz0),(bx1,by1,bz1),identity,'plywood',.002)
  for yy in [by0+.023,by1-.023]:box(identity+'_BackStile'+str(yy),(bx0-.01,yy-.017,ground),(bx1+.018,yy+.017,bz1),identity,'wood_dark',.002)
  for zz in [bz0,bz1-.04]:box(identity+'_BackRail'+str(zz),(bx0-.005,by0,zz),(bx1+.014,by1,zz+.04),identity,'wood_dark',.002)
 else:raise AssertionError(kind)

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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/hardware_stock.blend'))
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
asset=OUT/'game/assets/props/hardware_stock.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),**({'plain_alpha':True} if p['key']=='glassish' else {})} for p in inventory if p['cell']==identity],'replace':replace})
for cell in cells:
 if labels_by_cell.get(cell['id']):cell['labels']=labels_by_cell[cell['id']]
runtime={'schema_version':1,'asset':'res://assets/props/hardware_stock.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/hardware_stock.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/hardware_stock.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend([ROOT/'art/tools/build_iron_blackened.py',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'art/textures/procedural/iron_blackened/{name}.png' for name in ['albedo','roughness','normal','height'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(OUT/'art/blender/scripts/inspect_hardware_stock.py')
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/hardware_stock_construction.json','game/tests/fixtures/orison_hardware_stock.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('HARDWARE STOCK',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
