"""Pawnbroker source cases and supported passive window stock."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
# Godot may normalize a provisional import UID without changing any geometry.
# Refresh only that import provenance after import; other drift still refuses.
if '--refresh-import-binding' in sys.argv:
 root=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
 paths=[root/'art/blender/pawn_display_construction.json',root/'game/tests/fixtures/orison_pawn_display.json']
 reports=[json.loads(p.read_text(encoding='utf-8')) for p in paths];assert reports[0]==reports[1]
 report=reports[0];assert hashlib.sha256((root/'game/assets/props/pawn_display.glb').read_bytes()).hexdigest()==report['asset_sha256']
 permitted={'art/blender/scripts/build_pawn_display.py','game/assets/props/pawn_display.glb.import'}
 changed=[]
 for relative,expected in report['source_bindings'].items():
  path=root/relative;data=path.read_bytes();actual=hashlib.sha256(data if path.suffix in ['.blend','.glb','.png','.bin'] else data.replace(b'\r\n',b'\n')).hexdigest()
  if actual!=expected:
   assert relative in permitted,('unexpected source drift',relative)
   report['source_bindings'][relative]=actual;changed.append(relative)
 assert 'game/assets/props/pawn_display.glb.import' in changed,'no normalized import binding to refresh'
 for path in paths:path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('Refreshed normalized import provenance:',changed,'; mesh and every other source binding unchanged.')
 raise SystemExit(0)
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())/'art/blender/scripts'))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('PAWN_DISPLAY_OUT',str(ROOT)))
plan_path=Path(os.environ.get('PAWN_DISPLAY_PLAN',str(ROOT/'art/data/pawn_display/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text(encoding='utf-8'));layout=json.loads(layout_path.read_text(encoding='utf-8'));assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_pawnbroker.gltf';source_gltf=json.loads(source_gltf_path.read_text(encoding='utf-8'));sets={};material_definitions=[]
catalog_path=Path(os.environ.get('PAWN_DISPLAY_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text(encoding='utf-8'))['materials']
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
floor=rows['storm_shop_pawnbroker_floor'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_pawnbroker','floor':floor})
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

# Turned sections run along Y; the front faces into the shop (-Y).
def axial(name,cx,cz,profile,identity,key,n=64):
 verts=[];rings=[];closed_profile=profile[0]==profile[-1]
 if closed_profile:profile=profile[:-1]
 for radius,yy in profile:
  if radius==0:rings.append([len(verts)]);verts.append((cx,yy,cz))
  else:
   rings.append(list(range(len(verts),len(verts)+n)));verts.extend((cx+radius*math.cos(i*math.tau/n),yy,cz+radius*math.sin(i*math.tau/n)) for i in range(n))
 faces=[]
 for a,b in zip(rings,rings[1:]+(rings[:1] if closed_profile else [])):
  for i in range(n):
   if len(a)==1:faces.append((a[0],b[i],b[(i+1)%n]))
   elif len(b)==1:faces.append((a[i],b[0],a[(i+1)%n]))
   else:faces.append((a[i],b[i],b[(i+1)%n],a[(i+1)%n]))
 return solid(name,verts,faces,identity,key)
def radial_bar(name,cx,cz,y0,y1,angle,r0,r1,width,identity,key):
 u=Vector((math.sin(angle),0,math.cos(angle)));v=Vector((math.cos(angle),0,-math.sin(angle)))
 verts=[Vector((cx,yy,cz))+u*rr+v*ww for yy in [y0,y1] for rr in [r0,r1] for ww in [-width/2,width/2]]
 return solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key)
def frame(name,x0,y0,x1,y1,z0,z1,width,identity,key):
 box(name+'_Near',(x0,y0,z0),(x1,y0+width,z1),identity,key,.001)
 box(name+'_Far',(x0,y1-width,z0),(x1,y1,z1),identity,key,.001)
 box(name+'_Left',(x0,y0+width-.001,z0),(x0+width,y1-width+.001,z1),identity,key,.001)
 box(name+'_Right',(x1-width,y0+width-.001,z0),(x1,y1-width+.001,z1),identity,key,.001)

def along_x(name,cx,cy,cz,profile,identity,key):
 # Revolved stock built on the existing Y-axis primitive, then rotated onto X.
 obj=axial(name,0,0,profile,identity,key,48)
 for v in obj.data.vertices:
  p=v.co+obj.location;v.co=Vector((p.y,p.x,p.z))
 obj.location=Vector((cx,cy,cz))
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 return obj

for item in assemblies:
 row=item['body'];identity=item['id'];x0,y0,x1,y1=row['rect'];ground=floor['z0']+floor['h']
 if item['kind']=='case':
  if identity.endswith('_e'):x1-=.15
  # A 3mm joinery inset separates the lower carcass from retained wainscot.
  y0+=.003;y1-=.003
  # Four continuous corner posts join inset lower panels, deck and glazed frame.
  for i,xx in enumerate([x0+.025,x1-.025]):
   for j,yy in enumerate([y0+.025,y1-.025]):
    box(identity+f'_Post{i}{j}',(xx-.024,yy-.024,ground),(xx+.024,yy+.024,1.428),identity,'wood_dark',.002)
    support(identity,floor['id'],(xx,yy,ground),(0,0,1),'case post seated on original oak floor')
  for zz in [.12,.895]:frame(identity+'_LowerRails'+str(zz),x0,y0,x1,y1,zz,zz+.065,.040,identity,'wood_dark')
  for yy in [y0+.010,y1-.028]:
   # Three inset panel fields leave visible rails and stiles.
   for j in range(3):
    xa=x0+.035+j*(x1-x0-.070)/3;xb=x0+.035+(j+1)*(x1-x0-.070)/3
    box(identity+f'_Panel{yy}_{j}',(xa,yy,.15),(xb,yy+.018,.93),identity,'wood_dark',.002)
    box(identity+f'_Stile{yy}_{j}',(xa-.012,yy-.006,.14),(xa+.022,yy+.023,.95),identity,'wood_dark',.001)
  for xx in [x0+.012,x1-.030]:box(identity+'_EndPanel'+str(xx),(xx,y0+.030,.15),(xx+.018,y1-.030,.93),identity,'wood_dark',.001)
  box(identity+'_DisplayDeck',(x0+.010,y0+.010,.945),(x1-.010,y1-.010,.970),identity,'wood_dark',.002)
  # A dark fabric lining stays beneath the clear, deliberately empty chamber.
  box(identity+'_DisplayLining',(x0+.048,y0+.048,.969),(x1-.048,y1-.048,.973),identity,'fabric_warm',.0004)
  for yy in [y0+.018,y1-.022]:box(identity+'_LongPane'+str(yy),(x0+.042,yy,.958),(x1-.042,yy+.004,1.430),identity,'glassish',0)
  for xx in [x0+.018,x1-.022]:box(identity+'_EndPane'+str(xx),(xx,y0+.042,.958),(xx+.004,y1-.042,1.430),identity,'glassish',0)
  for xx in [x0+.022,(x0+x1)/2,x1-.022]:
   for yy in [y0+.015,y1-.025]:box(identity+'_GlazingBar'+str(xx)+str(yy),(xx-.009,yy,.957),(xx+.009,yy+.010,1.435),identity,'brass_dull',.0007)
  tx0,ty0,tx1,ty1=item['members'][2]['rect']
  if identity.endswith('_e'):tx1-=.15
  frame(identity+'_TopCore',tx0+.002,ty0+.002,tx1-.002,ty1-.002,1.410,1.445,.057,identity,'wood_dark')
  frame(identity+'_FoldedBrassTop',tx0,ty0,tx1,ty1,1.442,1.450,.061,identity,'brass_dull')
  box(identity+'_TopPane',(tx0+.058,ty0+.058,1.440),(tx1-.058,ty1-.058,1.445),identity,'glassish',0)
  # Fixed rear service-panel escutcheons describe construction, no opening verb.
  yy=y1-.040 if identity.endswith('_w') else y0+.040
  for xx in [x0+.55,x1-.55]:
   rod(identity+'_PullPin'+str(xx),(xx,yy,.54),(xx,yy+(.017 if identity.endswith('_w') else -.017),.54),.008,identity,'brass_dull',24)
  continue
 # Narrow source window stand; deck raised to reveal stock above the .55m sill.
 for xx in [x0+.032,x1-.028]:
  for j,yy in enumerate([y0+.032,(y0+y1)/2,y1-.032]):
   box(identity+'_Foot'+str(xx)+str(j),(xx-.024,yy-.024,ground),(xx+.024,yy+.024,.632),identity,'wood_dark',.002)
   support(identity,floor['id'],(xx,yy,ground),(0,0,1),'window stand foot on retained oak floor')
 frame(identity+'_LowerFrame',x0+.012,y0+.012,x1-.012,y1-.012,.105,.17,.042,identity,'wood_dark')
 frame(identity+'_UpperFrame',x0+.004,y0+.004,x1-.004,y1-.004,.548,.617,.038,identity,'wood_dark')
 box(identity+'_Deck',(x0,y0,.615),(x1,y1,.64),identity,'wood_dark',.003)
 bx0,by0,bx1,by1=item['members'][1]['rect']
 box(identity+'_BackPanel',(bx0+.004,by0+.025,.603),(bx1-.006,by1-.025,1.548),identity,'plywood',.001)
 for yy in [by0,by1-.036]:box(identity+'_BackStile'+str(yy),(bx0-.012,yy,.59),(bx1,yy+.036,1.57),identity,'wood_dark',.001)
 for zz in [.613,1.534]:box(identity+'_BackRail'+str(zz),(bx0-.010,by0+.002,zz),(bx1-.002,by1-.002,zz+.036),identity,'wood_dark',.001)
 cx=(x0+x1)/2
 # Collapsed telescope: closed tube, nested draw rings and recessed dark lenses.
 cy=y0+.49
 for yy in [cy-.19,cy+.19]:
  box(identity+'_ScopeFoot'+str(yy),(cx-.073,yy-.044,.640),(cx+.073,yy+.044,.663),identity,'wood_dark',.002)
  box(identity+'_ScopeCradle'+str(yy),(cx-.034,yy-.024,.659),(cx+.034,yy+.024,.777),identity,'wood_dark',.003)
 axial(identity+'_TelescopeTube',cx,.784,[(.049,cy-.29),(.052,cy-.27),(.052,cy+.20),(.047,cy+.23),(.044,cy+.23),(.044,cy-.29),(.049,cy-.29)],identity,'brass_dull',64)
 axial(identity+'_TelescopeGrip',cx,.784,[(.051,cy-.10),(.055,cy-.10),(.055,cy+.14),(.051,cy+.14),(.051,cy-.10)],identity,'bakelite_black',64)
 for j,yy in enumerate([cy-.293,cy+.207]):axial(identity+'_ScopeLens'+str(j),cx,.784,[(0,yy),(.045,yy),(.045,yy+.005),(0,yy+.005)],identity,'bakelite_black',48)
 # Pocket watch laid on a real inclined cushion; its chain rests on the tray.
 cy=(y0+y1)/2;tx0=x0+.025;tx1=x1-.025;ty0=cy-.30;ty1=cy+.30
 box(identity+'_WatchTray',(tx0,ty0,.640),(tx1,ty1,.662),identity,'wood_dark',.002)
 box(identity+'_WatchLining',(tx0+.012,ty0+.012,.661),(tx1-.012,ty1-.012,.666),identity,'fabric_warm',.001)
 # The small watch face points toward the pavement (-X), on a tall cushion.
 box(identity+'_WatchCushion',(cx-.019,cy-.085,.665),(cx+.071,cy+.085,.817),identity,'fabric_warm',.015)
 along_x(identity+'_WatchCase',cx,cy,.785,[(0,-.030),(.058,-.030),(.064,-.024),(.064,-.012),(.058,-.007),(0,-.007)],identity,'brass_dull')
 along_x(identity+'_WatchDial',cx,cy,.785,[(0,-.032),(.052,-.032),(.052,-.030),(0,-.030)],identity,'porcelain')
 for j in range(12):
  a=j*math.tau/12;yy=cy+math.sin(a)*.045;zz=.785+math.cos(a)*.045
  rod(identity+'_WatchMark'+str(j),(cx-.033,yy,zz),(cx-.031,yy,zz),.0017,identity,'iron_blackened',8)
 rod(identity+'_WatchHandA',(cx-.034,cy,.785),(cx-.034,cy+.020,.813),.0016,identity,'iron_blackened',8)
 rod(identity+'_WatchHandB',(cx-.034,cy,.785),(cx-.034,cy-.026,.773),.0013,identity,'iron_blackened',8)
 along_x(identity+'_WatchPin',cx,cy,.785,[(0,-.036),(.003,-.036),(.003,-.030),(0,-.030)],identity,'brass_dull')
 rod(identity+'_WatchCrown',(cx-.017,cy,.843),(cx-.017,cy,.858),.008,identity,'brass_dull',24)
 path=[(cx-.013,cy,.852),(cx-.023,cy+.025,.845),(cx-.035,cy+.074,.78),(cx-.06,cy+.12,.667)]
 path.extend((cx-.06+.024*math.sin(i*.25),cy+.12+i*.003,.667) for i in range(26))
 curved_wire(identity+'_LaidWatchChain',path,.002,identity,'brass_dull')
 # Paired field-glass barrels face the street, linked by a central bridge.
 cy=y1-.43
 box(identity+'_FieldGlassFoot',(x0+.03,cy-.135,.640),(x1-.025,cy+.135,.665),identity,'wood_dark',.002)
 for j,yy in enumerate([cy-.069,cy+.069]):
  box(identity+'_FieldGlassCradle'+str(j),(cx-.049,yy-.030,.663),(cx+.037,yy+.030,.740),identity,'wood_dark',.003)
  along_x(identity+'_FieldGlassBody'+str(j),cx,yy,.752,[(0,-.111),(.047,-.111),(.047,-.03),(.032,.029),(.032,.083),(0,.083)],identity,'bakelite_black')
  for k,(xx,rr) in enumerate([(-.111,.049),(.070,.034)]):
   along_x(identity+f'_FieldGlassRing{j}{k}',cx,yy,.752,[(rr-.004,xx),(rr,xx),(rr,xx+.012),(rr-.004,xx+.012),(rr-.004,xx)],identity,'brass_dull')
  along_x(identity+'_FieldGlassLens'+str(j),cx,yy,.752,[(0,-.113),(.039,-.113),(.039,-.110),(0,-.110)],identity,'glassish')
 box(identity+'_FieldGlassBridge',(cx-.020,cy-.070,.748),(cx+.014,cy+.070,.764),identity,'brass_dull',.002)
 rod(identity+'_FocusWheel',(cx-.002,cy,.756),(cx-.002,cy,.791),.022,identity,'bakelite_black',32)

for row in selected:
 x0,y0,x1,y1=row['rect'];z0=row['z0'];box(row['id']+'_RetainedBox',(x0,y0,z0),(x1,y1,z0+row['h']),row['id'],row['mat'],0,retained)

# Record the actual finished stock, after bevels, rather than its raw blank.
assert len({record['name'] for record in stock_checks})==len(stock_checks),'duplicate construction stock identity'
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12,record['name']
 bm.free()
def partition_of(obj,key):return key

draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({partition_of(obj,key) for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['body']['z0']))
 for part_key in keys:
  key=part_key;vertices=[];faces=[];grain_axes=[]
  for obj,material_key in pieces[identity]:
   if partition_of(obj,material_key)!=part_key:continue
   # Sum in doubles before rebasing the assembled draw. World-coordinate
   # float32 addition otherwise collapses tiny bevel faces fifty metres out.
   offset=len(vertices);vertices.extend(tuple(np.asarray(obj.location,dtype=np.float64)+np.asarray(v.co,dtype=np.float64)) for v in obj.data.vertices)
   # Grain follows each actual length of timber, including horizontal rails.
   obj.data.calc_loop_triangles();axis=int(np.argmax(np.ptp(np.asarray([v.co[:] for v in obj.data.vertices]),axis=0)))
   faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.loop_triangles);grain_axes.extend([axis]*len(obj.data.loop_triangles))
  name=identity+'__'+part_key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
   assert np.linalg.norm(np.cross(points[1]-points[0],points[2]-points[0]))>0,(name,face.index,points.tolist())
   order=[1,2,0] if grain_axes[face.index]==0 else ([2,0,1] if grain_axes[face.index]==1 else [0,1,2])
   if key=='wood_dark':
    n,u,values,local=chart_for_triangle(points[:,order],origin[order],sets[key]['meters_per_tile']);n=n[np.argsort(order)];u=u[np.argsort(order)]
   else:n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],key=='timber')
   fallbacks+=local
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(n)
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/pawn_display.blend'))
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
asset=OUT/'game/assets/props/pawn_display.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),**({'plain_alpha':True} if p['key']=='glassish' else {}),} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/pawn_display.glb','tolerance':plan['trim_tolerance_m'],'cells':cells,'optics':plan['optics']}
(OUT/'game/data/orison_v2/pawn_display.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/pawn_display.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend([ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.extend(OUT/name for name in ['art/blender/scripts/inspect_pawn_display.py','game/scripts/building/orison_v2_pawn_display.gd','game/scripts/building/orison_v2_architectural_materials.gd','game/shaders/lamp_glass_surface.gdshader'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/passage.{suffix}' for suffix in ['gltf','bin'])
for stem in ['pawn_receiving','pawn_clocks']:bindings.extend(ROOT/name for name in [f'art/blender/{stem}.blend',f'game/assets/props/{stem}.glb',f'game/tests/fixtures/orison_{stem}.json',f'game/data/orison_v2/{stem}.json'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/pawn_display_construction.json','game/tests/fixtures/orison_pawn_display.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('PAWN DISPLAY',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
