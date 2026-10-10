"""Source-owned News/Cigars furniture, folded papers, jars and hollow pipe bowls."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('NEWS_FITTINGS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('NEWS_FITTINGS_PLAN',str(ROOT/'art/data/news_fittings/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text());assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_news_cigars.gltf';source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog_path=Path(os.environ.get('NEWS_FITTINGS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text())['materials']
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
floor=rows['storm_shop_news_cigars_floor'];ceil=rows['storm_shop_news_cigars_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_news_cigars','floor':floor})
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





# News/Cigars fabrication body, assembled into a standalone production builder.
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

def at_source(row):
 x0,y0,x1,y1=row['rect'];return x0,y0,x1,y1,row['z0'],row['z0']+row['h']

def folded_paper(name,row,identity):
 x0,y0,x1,y1,z0,z1=at_source(row);cx=(x0+x1)/2
 # Four actual folded leaf stocks; the spine joins them without bitmap text.
 for layer in range(4):
  z=z0+layer*.0058
  outline=[(x0,y0,z),(cx,y0,z+.003),(x1,y0,z+.001),(x0,y0,z+.0012),(cx,y0,z+.0042),(x1,y0,z+.0022)]
  verts=outline+[(x,y1,z) for x,y,z in outline]
  faces=[(0,1,4,3),(1,2,5,4),(6,9,10,7),(7,10,11,8),(0,6,7,1),(1,7,8,2),(3,4,10,9),(4,5,11,10),(0,3,9,6),(2,8,11,5)]
  solid(name+'_Fold'+str(layer),verts,faces,identity,'paper')
 box(name+'_Spine',(cx-.002,y0,z0),(cx+.002,y1,z0+.027),identity,'paper',.0005)

for item in assemblies:
 identity=item['id'];kind=item['kind'];row=item['body'];members=item['members'];x0,y0,x1,y1,z0,z1=at_source(row)
 if kind=='counter':
  top=next(r for r in members if r['id'].endswith('_counter_top'));tx0,ty0,tx1,ty1,tz0,tz1=at_source(top)
  tx1=min(tx1,19.90) # Keep a 20mm end clearance from the closed back-door case.
  for x in [x0+.045,x1-.045]:
   for y in [y0+.045,y1-.045]:
    box(identity+f'_Foot{x}{y}',(x-.024,y-.024,.01),(x+.024,y+.024,z0+.075),identity,'wood_dark',.003)
    box(identity+f'_Leg{x}{y}',(x-.023,y-.023,z0+.055),(x+.023,y+.023,tz0),identity,'wood_dark',.003)
    support(identity,floor['id'],(x,y,.01),(0,0,1),'counter floor foot')
  box(identity+'_FrontPanel',(x0+.015,y1-.025,z0+.065),(x1-.015,y1,tz0),identity,'wood_dark',.002)
  for x in [x0,x1-.032]:box(identity+'_End'+str(x),(x,y0,z0+.065),(x+.032,y1,tz0),identity,'wood_dark',.002)
  box(identity+'_UnderShelf',(x0,y0,.759),(x1,y1,.785),identity,'timber',.002)
  box(identity+'_Top',(tx0,ty0,tz0),(tx1,ty1,tz1),identity,'countertop',.002)
  drawer=next(r for r in members if r['id'].endswith('_cash_drawer'));dx0,dy0,dx1,dy1,dz0,dz1=at_source(drawer)
  box(identity+'_DrawerBody',(dx0,dy0,dz0),(dx1,dy1,dz1),identity,'wood_dark',.004)
  box(identity+'_DrawerSlide',(dx0,dy0,dz1-.015),(dx1,dy0+.018,tz0),identity,'wood_dark',.002)
  curved_wire(identity+'_DrawerPull',[(dx0+.08,dy0+.003,.925),(dx0+.10,dy0-.029,.925),(dx1-.10,dy0-.029,.925),(dx1-.08,dy0+.003,.925)],.004,identity,'cast_iron')
  form=next(r for r in members if r['id'].endswith('_racing_form'));folded_paper(identity+'_RacingForm',form,identity)
  ledger=next(r for r in members if r['id'].endswith('_ledger'));lx0,ly0,lx1,ly1,lz0,lz1=at_source(ledger)
  lx0,lx1=17.61,17.82
  box(identity+'_LedgerSeat',(lx0,ly0,tz1),(lx1,ly1,lz0+.003),identity,'wood_dark',.001)
  box(identity+'_LedgerPages',(lx0+.004,ly0+.004,lz0+.003),(lx1-.004,ly1-.004,lz1-.005),identity,'paper',.0005)
  box(identity+'_LedgerCover',(lx0,ly0,lz1-.006),(lx1,ly1,lz1),identity,'wood_dark',.001)
  box(identity+'_LedgerSpine',(lx0,ly0,lz0),(lx0+.008,ly1,lz1),identity,'wood_dark',.001)
 elif kind=='paper_rack':
  for x in [x0+.023,x1-.023]:
   for y in [y0+.023,y1-.023]:
    box(identity+f'_Post{x}{y}',(x-.014,y-.014,.01),(x+.014,y+.014,1.71),identity,'timber',.002)
    support(identity,floor['id'],(x,y,.01),(0,0,1),'newspaper rack foot')
  for r in members:
   if '_rack' in r['id']:
    ax,ay,bx,by,az,bz=at_source(r);box(r['id']+'_Shelf',(ax,ay,az),(bx,by,bz),identity,'timber',.002)
    box(r['id']+'_Lip',(ax,by-.012,bz-.010),(bx,by+.012,bz+.018),identity,'timber',.001)
   else:folded_paper(r['id'],r,identity)
 elif kind=='service_hatch':
  shelf=members[1];sx0,sy0,sx1,sy1,sz0,sz1=at_source(shelf)
  for y in [y0,y1-.030]:box(identity+'_Jamb'+str(y),(x0,y,z0),(x1,y+.030,z1),identity,'wood_dark',.002)
  for z in [z0,z1-.030]:box(identity+'_Rail'+str(z),(x0,y0,z),(x1,y1,z+.030),identity,'wood_dark',.002)
  box(identity+'_Shelf',(sx0,sy0,sz0),(sx1,sy1,sz1),identity,'timber',.003)
  for y in [sy0+.04,sy1-.04]:
   # Floor-standing posts meet the retained projecting shelf and hatch sill.
   box(identity+'_Post'+str(y),(17.17,y-.016,.01),(17.21,y+.016,sz0+.01),identity,'wood_dark',.002)
   support(identity,floor['id'],(17.19,y,.01),(0,0,1),'service shelf floor post')
 elif kind=='cigar_case':
  box(identity+'_Base',(x0,y0,z0),(x1,y1,z0+.023),identity,'wood_dark',.002)
  support(identity,rows['storm_shop_news_cigars_counter_top']['id'],((x0+x1)/2,(y0+y1)/2,z0),(0,0,1),'cigar cabinet on transaction top')
  for x in [x0,x1-.022]:
   for y in [y0,y1-.022]:box(identity+f'_Post{x}{y}',(x,y,z0+.01),(x+.022,y+.022,z1),identity,'wood_dark',.002)
  for y in [y0,y1-.006]:box(identity+'_GlassSide'+str(y),(x0+.011,y,z0+.017),(x1-.011,y+.006,z1-.009),identity,'glassish',0)
  for x in [x0,x1-.006]:box(identity+'_GlassEnd'+str(x),(x,y0+.011,z0+.017),(x+.006,y1-.011,z1-.009),identity,'glassish',0)
  box(identity+'_GlassTop',(x0,y0,z1-.007),(x1,y1,z1),identity,'glassish',0)
  for level in range(2):
   bz=z0+.020+level*.21
   box(identity+'_Tray'+str(level),(x0+.018,y0+.018,bz),(x1-.018,y1-.018,bz+.018),identity,'timber',.001)
   for col in range(8):
    cx=x0+.065+col*.092;cy=y0+.16
    rod(identity+f'_Cigar{level}_{col}',(cx,cy-.115,bz+.031),(cx,cy+.115,bz+.031),.0135,identity,'tobacco')
    rod(identity+f'_Band{level}_{col}',(cx,cy-.050,bz+.031),(cx,cy-.038,bz+.031),.014,identity,'paper')
  for x in [x0+.022,x1-.042]:box(identity+'_TrayBracket'+str(x),(x,y0+.020,z0+.015),(x+.02,y0+.040,z0+.242),identity,'wood_dark',.001)
 elif kind=='rear_shelves':
  # Fitted extent stops before the original back-of-house leaf rectangle.
  limit=-48.98
  for y in [y0+.026,limit-.026]:
   box(identity+'_Post'+str(y),(x1-.040,y-.020,.01),(x1,y+.020,2.34),identity,'timber',.002)
   support(identity,floor['id'],(x1-.020,y,.01),(0,0,1),'back shelving floor post')
  for r in members:
   ax,ay,bx,by,az,bz=at_source(r);box(r['id']+'_Shelf',(ax,ay,az),(bx,limit,bz),identity,'timber',.002)

  # Dossier slice 53 (CITY_SHOP_NEWS_CIGARS-003): the booth's stock, every piece seated 0.2 mm into its board.
  tops={r['id'][-1]:at_source(r)[5] for r in members}
  fx,bx=x0+.02,x0+.235
  t=tops['0']-.0002
  for i,y in enumerate([-50.78,-50.36,-49.92,-49.50]):
   box(identity+f'_Bundle{i}',(fx,y,t),(bx,y+.34,t+.13),identity,'newsprint',.004)
   for dy in [.09,.25]:box(identity+f'_BundleTie{i}_{dy}',(fx-.002,y+dy,t+.0005),(bx+.002,y+dy+.006,t+.1325),identity,'paper',.0005)
  t=tops['1']-.0002
  for f,y in enumerate([-50.75,-50.20,-49.65]):
   for k,key in enumerate(['newsprint','candy','paper','tobacco','newsprint']):
    box(identity+f'_Magazine{f}_{k}',(fx+.005,y+k*.045,t+k*.0058),(fx+.205,y+k*.045+.27,t+k*.0058+.0062),identity,key,.0006)
  t=tops['2']-.0002
  for i,y in enumerate([-50.78,-50.50,-50.22]):
   box(identity+f'_CigarBox{i}',(fx,y,t),(fx+.19,y+.25,t+.055),identity,'wood_dark',.002)
   box(identity+f'_CigarBand{i}',(fx-.0012,y+.09,t+.012),(fx+.0008,y+.16,t+.043),identity,'paper',.0003)
   if i==1:
    # The open box: lid stood up on its back hinge, the cigars showing.
    box(identity+'_CigarLid',(fx+.178,y+.004,t+.0545),(fx+.186,y+.246,t+.245),identity,'wood_dark',.0015)
    for c in range(6):rod(identity+f'_OpenCigar{c}',(fx+.02,y+.03+c*.037,t+.06),(fx+.17,y+.03+c*.037,t+.06),.0115,identity,'tobacco')
  for i,y in enumerate([-49.80,-49.62,-49.44]):
   vessel(identity+f'_TobaccoTin{i}',fx+.1,y,t,[(0,0),(.048,0),(.048,.09),(0,.09)],identity,'tobacco')
   vessel(identity+f'_TinLid{i}',fx+.1,y,t+.0898,[(0,0),(.05,0),(.05,.012),(0,.012)],identity,'cast_iron')
  t=tops['3']-.0002
  for i,y in enumerate([-50.75,-50.32,-49.89,-49.46]):
   box(identity+f'_PaperStack{i}',(fx,y,t),(bx-.02,y+.36,t+.07+.012*(i%2)),identity,'newsprint',.002)
   box(identity+f'_Masthead{i}',(fx-.0012,y+.02,t+.045+.012*(i%2)),(fx+.0008,y+.34,t+.066+.012*(i%2)),identity,'masthead',.0004)
 elif kind=='candy_jar':
  cx=(x0+x1)/2;cy=(y0+y1)/2;base=1.15
  profile=[(0,0),(.060,0),(.080,.014),(.082,.225),(.055,.264),(.047,.280),(.047,.287),(.041,.287),(.041,.278),(.049,.262),(.076,.224),(.074,.018),(.054,.009),(0,.009)]
  vessel(identity+'_Glass',cx,cy,base,profile,identity,'glassish')
  vessel(identity+'_Lid',cx,cy,base,[(0,.282),(.048,.282),(.055,.292),(.055,.307),(.046,.313),(0,.313)],identity,'cast_iron')
  rod(identity+'_LidKnob',(cx,cy,base+.311),(cx,cy,base+.330),.013,identity,'bakelite_black')
  for ix in range(3):
   for iy in range(3):
    xx=cx+(ix-1)*.029;yy=cy+(iy-1)*.029
    rod(identity+f'_WrappedSweet{ix}_{iy}',(xx,yy-.014,base+.021),(xx,yy+.014,base+.021),.0125,identity,'candy')
  support(identity,rows['storm_shop_news_cigars_counter_top']['id'],(cx,cy,base),(0,0,1),'candy jar on transaction top')
 elif kind=='pipe_rack':
  for x in [x0+.030,x1-.030]:
   box(identity+'_Upright'+str(x),(x-.018,y0,.01),(x+.018,y0+.036,z1),identity,'wood_dark',.002)
   support(identity,floor['id'],(x,y0+.018,.01),(0,0,1),'pipe rack floor support')
  box(identity+'_Back',(x0,y0,z0),(x1,y0+.025,z1),identity,'wood_dark',.002)
  for r in members[1:]:
   px,py,qx,qy,pz,qz=at_source(r);cx=(px+qx)/2;cy=py+.032
   box(r['id']+'_Seat',(px-.004,y0,pz-.010),(qx+.004,py+.065,pz+.003),identity,'wood_dark',.001)
   vessel(r['id']+'_Bowl',cx,cy,pz,[(0,0),(.018,0),(.029,.021),(.030,.067),(.027,.08),(.022,.08),(.023,.067),(.021,.027),(0,.016)],identity,'bakelite_black')
   curved_wire(r['id']+'_Stem',[(cx,cy+.024,pz+.031),(cx,cy+.060,pz+.032),(cx,py+.13,pz+.040),(cx,qy-.005,pz+.065)],.007,identity,'bakelite_black')
 elif kind=='punchboard':
  x0,x1=18.45,18.88
  base=1.15
  box(identity+'_Seat',(x0,y0,base),(x1,y1,z0+.005),identity,'wood_dark',.001)
  # A stock of paper with genuine empty punches; no printed glyphs or numerals.
  board=box(identity+'_Board',(x0,y0,z0),(x1,y1,z1),identity,'paper',.001)
  for ix in range(4):
   for iy in range(4):
    if (ix+iy)%3==0:continue
    cx=x0+.065+ix*.10;cy=y0+.065+iy*.12
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.014,depth=.12,location=(cx,cy,(z0+z1)/2));tool=bpy.context.object
    bpy.context.view_layer.objects.active=board;mod=board.modifiers.new('Spent paper punch','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=tool;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
  bm=bmesh.new();bm.from_mesh(board.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-8);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(board.data);bm.free()
  support(identity,rows['storm_shop_news_cigars_counter_top']['id'],((x0+x1)/2,(y0+y1)/2,base),(0,0,1),'punchboard on transaction top')
 elif kind=='proprietor_stool':
  x0-=.40;x1-=.40
  cx=(x0+x1)/2;cy=(y0+y1)/2;base=.019;seat=z1-.040
  vessel(identity+'_Seat',cx,cy,seat,[(0,0),(.203,0),(.223,.009),(.223,.031),(.211,.040),(0,.040)],identity,'wood_dark')
  for x in [cx-.140,cx+.140]:
   for y in [cy-.140,cy+.140]:
    vessel(identity+f'_Leg{x}{y}',x,y,base,[(0,0),(.018,0),(.024,.015),(.020,.033),(.016,.11),(.020,seat-base+.005),(0,seat-base+.005)],identity,'wood_dark')
    support(identity,rows['storm_shop_news_cigars_chair_hollow']['id'],(x,y,base),(0,0,1),'stool foot on original wear-cover datum')
  for x in [cx-.140,cx+.140]:rod(identity+'_CrossY'+str(x),(x,cy-.145,.22),(x,cy+.145,.22),.009,identity,'wood_dark')
  for y in [cy-.140,cy+.140]:rod(identity+'_CrossX'+str(y),(cx-.145,y,.28),(cx+.145,y,.28),.009,identity,'wood_dark')
 elif kind=='worn_cover':
  x0-=.40;x1-=.40
  # Dossier slice 53 (CITY_SHOP_NEWS_CIGARS-001/003): a black rubber mat worn through to a pale hollow
  # where the proprietor's feet and stool have stood for years.
  box(identity+'_FloorSeatedCover',(x0,y0,.01),(x1,y1,.0135),identity,'bakelite_black',0)
  for side,(a,c) in enumerate([((x0,y0),(x1,y0+.07)),((x0,y1-.07),(x1,y1)),((x0,y0+.069),(x0+.07,y1-.069)),((x1-.07,y0+.069),(x1,y1-.069))]):
   box(identity+f'_MatRim{side}',(a[0],a[1],.0133),(c[0],c[1],z1),identity,'bakelite_black',0)
  box(identity+'_WornHollow',(x0+.12,y0+.12,.0133),(x1-.12,y1-.12,.0141),identity,'soot',0)
  support(identity,floor['id'],((x0+x1)/2,(y0+y1)/2,.01),(0,0,1),'wear-cover floor seat')
 else:raise AssertionError(kind)

# Keep the arm-height pipe display visible in the clear front wall bay.
# The original functional cabinet and every hidden source reference retain pose.
pipe_owner='storm_shop_news_cigars_pipe_rack'
for obj,key in pieces[pipe_owner]:obj.location.x-=2.4
for contact in contacts:
 if contact['assembly']==pipe_owner:contact['point'][0]-=2.4

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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/news_fittings.blend'))
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
asset=OUT/'game/assets/props/news_fittings.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {}),**({'plain_alpha':True} if p['key']=='glassish' else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/news_fittings.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/news_fittings.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/news_fittings.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'] if f is not None)
bindings.extend([ROOT/'art/tools/build_iron_blackened.py',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'art/textures/procedural/iron_blackened/{name}.png' for name in ['albedo','roughness','normal','height'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(ROOT/'art/blender/scripts/inspect_news_fittings.py')
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/news_fittings_construction.json','game/tests/fixtures/orison_news_fittings.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('NEWS FITTINGS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
