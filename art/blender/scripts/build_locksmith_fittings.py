"""Source-fitted locksmith keys, supported benches, passive machinery and shop fittings."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('LOCKSMITH_FITTINGS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('LOCKSMITH_FITTINGS_PLAN',str(ROOT/'art/data/locksmith_fittings/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text());assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_keys_cut.gltf';source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog_path=Path(os.environ.get('LOCKSMITH_FITTINGS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text())['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=OUT/f'art/textures/{spec["catalog_mapping"]}/material.json'
  if not definition.exists():definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json'
 else:
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+key+'_b','M_'+key]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr['baseColorTexture'],pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name)
  mapping=files[0].removeprefix('T_').removesuffix('_albedo.png').replace('ai_materials_','ai_materials/',1)
  definition=ROOT/f'art/textures/{mapping}/material.json'
  sets[key]={'files':files,'meters_per_tile':json.loads(definition.read_text())['meters_per_tile'],'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1)}
 material_definitions.append(definition)
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_keys_cut_floor'];ceil=rows['storm_shop_keys_cut_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_keys_cut','floor':floor})
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
 for index,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  image=bpy.data.images.load(str(((OUT/'game/assets/building/textures'/spec['files'][index]) if (OUT/'game/assets/building/textures'/spec['files'][index]).exists() else (ROOT/'game/assets/building/textures'/spec['files'][index]))),check_existing=True);image.filepath=bpy.path.relpath(image.filepath,start=str(OUT/'art/blender'))
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
def basin(name,cx,cy,rx,ry,zbottom,ztop,identity,key):
 # One closed metal shell with an open cavity. The inner bottom is joined
 # to the outer underside by the continuous wall, rather than a solid fill.
 n=64;profiles=[(zbottom,rx*.70,ry*.70),(ztop,rx,ry),(ztop,rx-.003,ry-.003),(zbottom+.003,rx*.70-.003,ry*.70-.003)]
 verts=[(cx+a*math.cos(i*math.tau/n),cy+b*math.sin(i*math.tau/n),z) for z,a,b in profiles for i in range(n)]
 faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
 for ring in range(3):
  faces.extend((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i) for i in range(n))
 return solid(name,verts,faces,identity,key)

def prism(name,outline,z0,z1,identity,key,bevel=0):
 n=len(outline);obj=solid(name,[(x,y,z) for z in [z0,z1] for x,y in outline],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key)
 if bevel:
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked perimeter','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj

def gear(name,cx,cy,cz,radius,identity,key='cast_iron'):
 # Closed toothed blank. Teeth are integral, not detached decorative cubes.
 count=96;outline=[]
 for i in range(count):
  angle=i*math.tau/count;r=radius if i%4 in [1,2] else radius-.006
  outline.append((cx+r*math.cos(angle),cz+r*math.sin(angle)))
 n=len(outline);verts=[(x,y,z) for y in [cy-.009,cy+.009] for x,z in outline]
 return solid(name,verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key)

def annulus_x(name,x0,x1,cy,cz,outer,inner,identity,key):
 n=48
 rings=[(x0,outer),(x1,outer),(x1,inner),(x0,inner)]
 verts=[(x,cy+r*math.cos(i*math.tau/n),cz+r*math.sin(i*math.tau/n)) for x,r in rings for i in range(n)]
 faces=[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)]
 return solid(name,verts,faces,identity,key)

def bow_ring(name,x0,x1,cy,cz,form,identity,key):
 # Dossier slice 56: oval and rounded-square bows beside the original round one.
 n=48;loops=[]
 for rx,rz in ([(.024,.017),(.014,.0092)] if form=='oval' else [(.0185,.0185),(.0105,.0105)]):
  pts=[]
  for i in range(n):
   a=i*math.tau/n;c,s=math.cos(a),math.sin(a)
   k=1. if form=='oval' else 1./((abs(c)**4+abs(s)**4)**.25)
   pts.append((cy+rx*k*c,cz+rz*k*s))
  loops.append(pts)
 rings=[(x0,loops[0]),(x1,loops[0]),(x1,loops[1]),(x0,loops[1])]
 verts=[(x,y,z) for x,loop in rings for y,z in loop]
 faces=[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)]
 return solid(name,verts,faces,identity,key)

def prism_x(name,outline,x0,x1,identity,key):
 n=len(outline)
 return solid(name,[(x,y,z) for x in [x0,x1] for y,z in outline],[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,key)

def drilled(obj,at,axis,radius,depth):
 # Cut the actual blank in Blender; exported geometry is never edited.
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=at)
 cutter=bpy.context.object;cutter.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
 bpy.context.view_layer.objects.active=obj
 mod=obj.modifiers.new('Bored opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)

def cabinet(identity,row,key,top,floor_z=.01):
 x0,y0,x1,y1=row['rect'];bottom=float(row['z0']);th=.022
 for i,(xx,yy) in enumerate([(x0+.03,y0+.03),(x1-.03,y0+.03),(x0+.03,y1-.03),(x1-.03,y1-.03)]):
  box(identity+f'_Foot{i}',(xx-.026,yy-.026,floor_z),(xx+.026,yy+.026,bottom+.055),identity,key,.004)
  support(identity,floor['id'],(xx,yy,floor_z),(0,0,1),'cabinet foot')
 box(identity+'_Bottom',(x0,y0,bottom+.028),(x1,y1,bottom+.054),identity,key,.003)
 for xx in [x0,x1-th]:box(identity+f'_Side{xx}',(xx,y0,bottom+.04),(xx+th,y1,top),identity,key,.003)
 for yy in [y0,y1-th]:box(identity+f'_End{yy}',(x0+th,yy,bottom+.04),(x1-th,yy+th,top),identity,key,.003)

key_forms={}
for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];x=(x0+x1)*.5;y=(y0+y1)*.5;z=float(row['z0']);kind=item['kind']
 if kind=='key_board':
  box(identity+'_Board',(x0,y0,z),(x1,y1,z+row['h']),identity,'plywood',.004)
  # The lower opaque wall carries four spacer/button fixings. The borrowed
  # light above it is retained; no new wall/window ownership is introduced.
  for i,(yy,zz) in enumerate([(y0+.15,1.40),(y1-.15,1.40),(y0+.15,2.20),(y1-.15,2.20)]):
   rod(identity+f'_WallSpacer{i}',(6.06,yy,zz),(6.079,yy,zz),.011,identity,'brass_dull')
   rod(identity+f'_Screw{i}',(6.10,yy,zz),(6.123,yy,zz),.0045,identity,'brass_dull')
   support(identity,'storm_shop_keys_cut_back_lo',(6.06,yy,zz),(1,0,0),'key board wall spacer')
  # Dossier slice 56 (CITY_SHOP_KEYS_CUT-003): blanks vary by row (bow form, blade length and width,
  # bitting); the fourth row hangs empty on its pegs and six more pegs are bare.
  empties={(0,5),(1,11),(2,2),(4,8),(5,0),(6,12)};bows=('round','oval','square','round','oval','square','round')
  for blank in item['members'][1:]:
   a,b,c,d=blank['rect'];cy=(b+d)*.5;cz=float(blank['z0'])+.068;key=blank['mat'];name=blank['id']
   row_,col_=map(int,name.rsplit('_key',1)[1].split('_'));empty=row_==3 or (row_,col_) in empties
   key_forms[name]={'row':row_,'column':col_,'bow':bows[row_],'empty':empty}
   curved_wire(name+'_Peg',[(6.112,cy,cz+.008),(6.130,cy,cz+.008),(6.139,cy,cz+.012),(6.142,cy,cz+.019)],.0023,identity,'brass_dull')
   if empty:continue
   if bows[row_]=='round':annulus_x(name+'_PiercedBow',6.128,6.133,cy,cz,.020,.011,identity,key)
   else:bow_ring(name+'_PiercedBow',6.128,6.133,cy,cz,bows[row_],identity,key)
   lo=float(blank['z0']);s=(.0,.006,.012,.0,.004,.009,.002)[row_];w=(.007,.009,.008,.007,.010,.008,.009)[row_]
   step=(.035-s)/4;outline=[(cy-.005,cz-.012),(cy+.005,cz-.012),(cy+.005,lo+s+.003),(cy-w,lo+s)]
   for k in range(4):
    zk=lo+s+.004+k*step;outline+=[(cy-w,zk),(cy-w-.002-.0015*((row_*5+col_*3+k)%3),zk+step*.5)]
   outline+=[(cy-w,lo+.040),(cy-.005,lo+.043)]
   prism_x(name+'_NotchedBlade',outline,6.128,6.133,identity,key)
 elif kind=='workbench':
  # The authored end vise projects beyond the original bench. Extend only
  # this native top to seat that retained apparatus; the source rows remain.
  end=max(member['rect'][2] for member in item['members'])+.03
  box(identity+'_PlankTop',(x0,y0,.894),(end,y1,.95),identity,'timber',.004)
  for i,(xx,yy) in enumerate([(x0+.075,y0+.075),(end-.075,y0+.075),(x0+.075,y1-.075),(end-.075,y1-.075)]):
   box(identity+f'_Leg{i}',(xx-.033,yy-.033,.01),(xx+.033,yy+.033,.909),identity,'timber',.005)
   support(identity,floor['id'],(xx,yy,.01),(0,0,1),'cutter workbench foot')
  for yy in [y0+.075,y1-.075]:box(identity+f'_Apron{yy}',(x0+.04,yy-.022,.74),(end-.04,yy+.022,.903),identity,'timber',.003)
  for xx in [x0+.075,end-.075]:box(identity+f'_Stretcher{xx}',(xx-.023,y0+.05,.22),(xx+.023,y1-.05,.264),identity,'timber',.003)
  grinder=next(m for m in item['members'] if m['id'].endswith('_grinder'));r=grinder['rect'];cx=(r[0]+r[2])*.5;cy=(r[1]+r[3])*.5
  box(identity+'_GrinderFoot',(r[0],r[1],.95),(r[2],r[3],1.017),identity,'cast_iron',.007)
  box(identity+'_GrinderPedestal',(cx-.05,cy-.065,1.0),(cx+.05,cy+.065,1.225),identity,'cast_iron',.009)
  rod(identity+'_GrindingSpindle',(cx,cy-.22,1.205),(cx,cy+.22,1.205),.022,identity,'metal')
  for i,yy in enumerate([cy-.18,cy+.18]):
   rod(identity+f'_GrindingWheel{i}',(cx,yy-.018,1.205),(cx,yy+.018,1.205),.119,identity,'cast_iron')
   rod(identity+f'_WheelWasher{i}',(cx,yy-.023,1.205),(cx,yy+.023,1.205),.031,identity,'metal')
   box(identity+f'_ToolRest{i}',(cx+.123,yy-.075,1.131),(cx+.185,yy+.075,1.148),identity,'metal',.002)
   rod(identity+f'_RestStay{i}',(cx+.045,cy,1.04),(cx+.148,yy,1.141),.009,identity,'cast_iron')
  vise=next(m for m in item['members'] if m['id'].endswith('_bench_vise'));r=vise['rect'];cx=(r[0]+r[2])*.5;cy=(r[1]+r[3])*.5
  box(identity+'_ViseFoot',(r[0],r[1],.95),(r[2],r[3],1.045),identity,'cast_iron',.012)
  for i,xx in enumerate([cx-.076,cx+.076]):
   box(identity+f'_ViseJaw{i}',(xx-.03,cy-.125,1.03),(xx+.03,cy+.125,1.27),identity,'cast_iron',.012)
   box(identity+f'_HardenedJaw{i}',(xx-.034,cy-.124,1.233),(xx+.034,cy+.124,1.279),identity,'metal',.0015)
  rod(identity+'_ViseScrew',(cx-.165,cy,1.102),(cx+.165,cy,1.102),.015,identity,'metal')
  rod(identity+'_ViseHandle',(cx+.164,cy-.155,1.102),(cx+.164,cy+.155,1.102),.009,identity,'metal')
 elif kind=='key_cutter':
  # Passive paired vises, guide and toothed cutting wheel. Operating motion,
  # power and cutting effects are still owned by the existing counter service.
  box(identity+'_MachineFoot',(x0,y0,.95),(x1,y1,1.018),identity,'cast_iron',.010)
  for xx in [x0+.065,x1-.065]:box(identity+f'_Yoke{xx}',(xx-.035,y0+.05,1.002),(xx+.035,y1-.05,1.29),identity,'cast_iron',.009)
  for i,yy in enumerate([-.73,-.99]):
   cy=-50+yy
   box(identity+f'_ViseCarriage{i}',(7.14,cy-.06,1.219),(7.60,cy+.06,1.261),identity,'cast_iron',.006)
   for side in [-1,1]:box(identity+f'_ClampJaw{i}_{side}',(7.15,cy+side*.023-.012,1.255),(7.59,cy+side*.023+.012,1.366),identity,'cast_iron',.004)
   rod(identity+f'_ClampScrew{i}',(7.48,cy-.082,1.312),(7.48,cy+.082,1.312),.008,identity,'metal')
   rod(identity+f'_ClampHandle{i}',(7.43,cy+.083,1.312),(7.53,cy+.083,1.312),.008,identity,'timber')
   box(identity+f'_CarriageKeyBlank{i}',(7.33,cy-.002,1.335),(7.60,cy+.002,1.348),identity,'brass_dull',.001)
  gear(identity+'_IntegralCuttingTeeth',7.375,-50.73,1.424,.106,identity,'metal')
  rod(identity+'_WheelSpindle',(7.375,-50.786,1.424),(7.375,-50.64,1.424),.021,identity,'metal')
  for yy in [-50.775,-50.639]:rod(identity+f'_SpindleHub{yy}',(7.375,yy-.01,1.424),(7.375,yy+.01,1.424),.036,identity,'metal')
  for yy in [-50.785,-51.034]:
   box(identity+f'_SpindleBearing{yy}',(7.30,yy-.018,1.26),(7.45,yy+.018,1.438),identity,'cast_iron',.008)
  rod(identity+'_GuideStylus',(7.375,-51.04,1.346),(7.375,-50.960,1.346),.008,identity,'brass_dull')
  rod(identity+'_GuideBoss',(7.375,-51.044,1.349),(7.375,-51.007,1.349),.026,identity,'brass_dull')
  rod(identity+'_ManualFeedShaft',(7.21,-51.128,1.147),(7.62,-51.128,1.147),.013,identity,'metal')
  for xx in [7.21,7.62]:box(identity+f'_FeedBearing{xx}',(xx-.035,-51.15,1.005),(xx+.035,-51.10,1.181),identity,'cast_iron',.006)
  rod(identity+'_FeedCrank',(7.62,-51.128,1.147),(7.62,-51.128,1.233),.011,identity,'metal')
  rod(identity+'_FeedGrip',(7.62,-51.180,1.233),(7.62,-51.124,1.233),.018,identity,'timber')
  for xx in [x0+.055,x1-.055]:
   for yy in [y0+.055,y1-.055]:support(identity,'storm_shop_keys_cut_cutter_bench',(xx,yy,.95),(0,0,1),'cutting machine foot on retained-height bench')
 elif kind=='safe':
  # Shorten the closed case at the back-door end; keep the dial and service face.
  y0+=.090
  cabinet(identity,{**row,'rect':[x0,y0,x1,y1]},'cast_iron',z+row['h'])
  box(identity+'_SafeRoof',(x0,y0,z+row['h']-.022),(x1,y1,z+row['h']),identity,'cast_iron',.006)
  # The original dial was behind the safe. Seat its fitted counterpart on
  # the visible door; keep the original record and safe identity in the plan.
  front=x1+.004
  box(identity+'_RecessedDoor',(front-.024,y0+.036,z+.074),(front,y1-.036,z+row['h']-.044),identity,'cast_iron',.012)
  for yy in [y0+.032,y1-.032]:box(identity+f'_DoorFrame{yy}',(front-.038,yy-.014,z+.044),(front+.008,yy+.014,z+row['h']-.023),identity,'cast_iron',.005)
  for zz in [z+.046,z+row['h']-.025]:box(identity+f'_DoorCross{zz}',(front-.03,y0+.022,zz-.014),(front+.008,y1-.022,zz+.014),identity,'cast_iron',.005)
  rod(identity+'_DialRim',(front-.001,y,.69),(front+.018,y,.69),.072,identity,'brass_bright')
  rod(identity+'_DialFace',(front+.015,y,.69),(front+.023,y,.69),.058,identity,'cast_iron')
  rod(identity+'_DialKnob',(front+.018,y,.69),(front+.048,y,.69),.022,identity,'brass_bright')
  for i in range(24):
   a=i*math.tau/24;cy=y+.063*math.cos(a);cz=.69+.063*math.sin(a)
   rod(identity+f'_DialIndex{i}',(front+.015,cy,cz),(front+.021,cy,cz),.0018,identity,'cast_iron')
  for zz in [.29,.88]:rod(identity+f'_DoorHinge{zz}',(front,y0+.023,zz-.045),(front,y0+.023,zz+.045),.016,identity,'metal')
  for zz in [.42,.51]:rod(identity+f'_HandleStand{zz}',(front-.004,y+.18,zz),(front+.045,y+.18,zz),.010,identity,'brass_bright')
  rod(identity+'_PullHandle',(front+.045,y+.18,.42),(front+.045,y+.18,.51),.011,identity,'brass_bright')
  # Dossier slice 56 (CITY_SHOP_KEYS_CUT-001): the second-hand fire safe's blank gold-leaf cartouche and
  # a gold pinstripe round the door panel. No name, no lettering.
  dy=(y0+y1)*.5
  prism_x(identity+'_GoldCartouche',[(dy+.17*math.cos(i*math.tau/64),.93+.07*math.sin(i*math.tau/64)) for i in range(64)],front-.0004,front+.0009,identity,'brass_bright')
  prism_x(identity+'_BlankField',[(dy+.152*math.cos(i*math.tau/64),.93+.056*math.sin(i*math.tau/64)) for i in range(64)],front+.0005,front+.0014,identity,'cast_iron')
  for yy in [dy-.185,dy+.185]:rod(identity+f'_Flourish{yy}',(front-.0004,yy,.93),(front+.0009,yy,.93),.012,identity,'brass_bright',24)
  for zz in [.16,1.02]:box(identity+f'_PinstripeH{zz}',(front-.0004,y0+.07,zz),(front+.0008,y1-.07,zz+.003),identity,'brass_bright',0)
  for yy in [y0+.07,y1-.073]:box(identity+f'_PinstripeV{yy}',(front-.0004,yy,.16),(front+.0008,yy+.003,1.023),identity,'brass_bright',0)
 elif kind=='counter':
  cabinet(identity,row,'wood_dark',1.07)
  # Recessed end panels and a kick rail leave the retained transaction top
  # and its permission/copy interaction area at the exact authored pose.
  for yy in [y0+.1,y1-.1]:box(identity+f'_PanelStile{yy}',(x0-.006,yy-.020,.15),(x0+.032,yy+.020,1.054),identity,'wood_dark',.004)
  for zz in [.15,1.028]:box(identity+f'_PanelRail{zz}',(x0-.006,y0+.08,zz),(x0+.032,y1-.08,zz+.026),identity,'wood_dark',.004)
  top=next(m for m in item['members'] if m['id'].endswith('_counter_top'));a,b,c,d=top['rect']
  box(identity+'_RetainedTop',(a,b,top['z0']),(c,d,top['z0']+top['h']),identity,'countertop',.003)
  ledger=next(m for m in item['members'] if m['id'].endswith('_ledger'));a,b,c,d=ledger['rect'];zz=1.12
  # Dossier slice 56 (CITY_SHOP_KEYS_CUT-002): the register lies open, the left page full, the right begun;
  # a column of figures as ink strokes on blank rules, no legible numerals; a pencil on a string.
  e=d+(d-b)
  box(identity+'_LedgerBinding',(a,b,zz),(c,e,zz+.005),identity,'vinyl_oxblood',.002)
  box(identity+'_LeftLeaves',(a+.006,b+.005,zz+.0045),(c-.006,d-.003,zz+.022),identity,'paper',.0015)
  box(identity+'_RightLeaves',(a+.006,d+.003,zz+.0045),(c-.006,e-.005,zz+.016),identity,'paper',.0015)
  box(identity+'_SpineGutter',(a+.004,d-.0035,zz+.0045),(c-.004,d+.0035,zz+.010),identity,'paper',.001)
  for side,(p0,p1,top,filled) in enumerate([(b+.005,d-.003,zz+.022,17),(d+.003,e-.005,zz+.016,7)]):
   for i in range(18):
    xx=a+.03+i*(c-a-.05)/18
    box(identity+f'_Rule{side}_{i}',(xx,p0+.012,top-.0002),(xx+.0007,p1-.012,top+.0002),identity,'ledger_rule',0)
    if i>=filled or i==0:continue
    name_len=.05+.012*((i*7+side*3)%5)
    box(identity+f'_Entry{side}_{i}',(xx-.0030,p0+.03,top-.0001),(xx-.0018,p0+.03+name_len,top+.0004),identity,'ink',0)
    for k in range(3+(i+side)%3):
     ys=p1-.05+k*.0042
     box(identity+f'_Figure{side}_{i}_{k}',(xx-.0048,ys,top-.0001),(xx-.0010,ys+.0011,top+.0004),identity,'ink',0)
  pz=zz+.016+.0035-.0002
  rod(identity+'_Pencil',(a+.10,d+.07,pz),(a+.22,d+.19,pz),.0035,identity,'timber',6)
  rod(identity+'_PencilLead',(a+.219,d+.189,pz),(a+.226,d+.196,pz),.0012,identity,'cast_iron',12)
  rod(identity+'_StringEye',(c+.08,d+.10,zz-.0002),(c+.08,d+.10,zz+.006),.0025,identity,'brass_dull',16)
  rod(identity+'_StringEyeHead',(c+.08,d+.10,zz+.004),(c+.08,d+.10,zz+.0065),.0045,identity,'brass_dull',16)
  curved_wire(identity+'_PencilString',[(a+.102,d+.072,pz),(a+.20,d+.075,zz+.0165),(c-.006,d+.08,zz+.0165),(c+.01,d+.085,zz+.004),(c+.04,d+.092,zz+.0007),(c+.08,d+.10,zz+.005)],.0007,identity,'linen')
 elif kind=='lock_table':
  # The source lock cloth and tools had no table beneath them. A bounded
  # support follows their union, keeping the existing four lock-case poses.
  a=min(m['rect'][0] for m in item['members'])-.05;c=max(m['rect'][2] for m in item['members'])+.05
  b=min(m['rect'][1] for m in item['members'])-.04;d=max(m['rect'][3] for m in item['members'])+.04
  box(identity+'_SupportedTop',(a,b,.895),(c,d,.94),identity,'timber',.004)
  for i,(xx,yy) in enumerate([(a+.06,b+.06),(c-.06,b+.06),(a+.06,d-.06),(c-.06,d-.06)]):
   box(identity+f'_TableLeg{i}',(xx-.025,yy-.025,.01),(xx+.025,yy+.025,.91),identity,'timber',.004)
   support(identity,floor['id'],(xx,yy,.01),(0,0,1),'lock demonstration table foot')
  for yy in [b+.06,d-.06]:box(identity+f'_TableApron{yy}',(a+.035,yy-.016,.78),(c-.035,yy+.016,.909),identity,'timber',.003)
  box(identity+'_LinenField',(x0,y0,.94),(x1,y1,.95),identity,'linen',.003)
  for xx in [x0,x1-.008]:box(identity+f'_ClothHem{xx}',(xx,y0,.908),(xx+.008,y1,.946),identity,'linen',.002)
  for case in [m for m in item['members'] if '_mortise' in m['id']]:
   a,b,c,d=case['rect'];cx=(a+c)*.5;cy=(b+d)*.5;n=int(case['id'][-1])
   if n==3:
    # Dossier slice 56 (CITY_SHOP_KEYS_CUT-003): the fourth record is the open case's cover, lifted off and
    # laid on the cloth, its two screws beside it.
    box(case['id']+'_LiftedCover',(a+.03,b+.012,.9498),(c-.006,d-.012,.9528),identity,'brass_dull',.001)
    for xx in [a+.06,c-.05]:rod(case['id']+f'_LooseScrew{xx}',(xx,d+.015,.9543),(xx+.012,d+.021,.9543),.0045,identity,'metal',16)
    continue
   if n==2:
    # The open case: cover off, its bolt, stacked levers, spring and follower showing.
    box(case['id']+'_CaseBack',(a+.012,b,.95),(c-.012,d,.956),identity,'brass_dull',.002)
    for yy in [b,d-.004]:box(case['id']+f'_CaseWall{yy}',(a+.012,yy,.9555),(c-.012,yy+.004,1.045),identity,'brass_dull',.001)
    box(case['id']+'_CaseEnd',(c-.016,b+.0035,.9555),(c-.012,d-.0035,1.045),identity,'brass_dull',.001)
    box(case['id']+'_Bolt',(a+.016,cy-.03,.9558),(a+.12,cy+.03,.972),identity,'metal',.002)
    for k in range(3):box(case['id']+f'_Lever{k}',(a+.03+.008*k,cy-.05,.9718+.0028*k),(cx,cy+.045,.9748+.0028*k),identity,'brass_dull',.0005)
    rod(case['id']+'_Follower',(cx+.06,cy+.01,.9558),(cx+.06,cy+.01,.99),.017,identity,'brass_dull')
    curved_wire(case['id']+'_LeverSpring',[(cx-.005,cy+.04,.979),(cx+.02,cy+.055,.979),(cx+.05,cy+.06,.979),(cx+.08,d-.002,.979)],.0016,identity,'metal')
   else:
    body=box(case['id']+'_Case',(a+.012,b,.95),(c-.012,d,1.045),identity,'brass_dull',.007)
    drilled(body,(cx,cy,1.02),(0,0,1),.015,.19)
    for xx in [a+.032,c-.032]:rod(case['id']+f'_CaseScrew{xx}',(xx,cy,1.039),(xx,cy,1.048),.0045,identity,'metal')
   box(case['id']+'_Faceplate',(a,b,.95),(a+.018,d,1.06),identity,'brass_dull',.003)
   for zz in [.981,1.024]:box(case['id']+f'_ProjectingBolt{zz}',(a-.012,cy-.034,zz),(a+.014,cy+.034,zz+.015),identity,'metal',.002)
  roll=next(m for m in item['members'] if m['id'].endswith('_pick_roll'));a,b,c,d=roll['rect']
  box(identity+'_UnrolledToolWallet',(a,b,.94),(c,d,.949),identity,'vinyl_oxblood',.003)
  for i in range(6):
   yy=b+.08+i*(d-b-.16)/5;xx=a+.075
   box(identity+f'_ToolPocket{i}',(a,yy-.020,.947),(a+.078,yy+.020,.956),identity,'vinyl_oxblood',.002)
   curved_wire(identity+f'_LockPick{i}',[(xx-.010,yy,.956),(c-.043,yy,.956),(c-.023,yy+.012,.956),(c-.012,yy+.006,.956)],.0016,identity,'chrome')
   rod(identity+f'_PickGrip{i}',(a+.04,yy,.956),(a+.11,yy,.956),.0036,identity,'timber')
 elif kind=='padlocks':
  cy=(y0+y1)*.5;center_z=1.5025
  rod(identity+'_DisplayRail',(x0+.025,cy,center_z),(x1-.025,cy,center_z),.0125,identity,'brass_dull')
  for i,xx in enumerate([x0+.04,x1-.04]):
   box(identity+f'_RailFoot{i}',(xx-.026,cy-.032,.01),(xx+.026,cy+.032,.025),identity,'cast_iron',.003)
   rod(identity+f'_RailPost{i}',(xx,cy,.015),(xx,cy,center_z+.007),.013,identity,'brass_dull')
   support(identity,floor['id'],(xx,cy,.01),(0,0,1),'padlock rail stand foot')
  for i,blank in enumerate(item['members'][1:]):
   cx=x0+.19+i*(x1-x0-.38)/5
   body=box(blank['id']+'_RoundedBody',(cx-.075,cy-.030,1.32),(cx+.075,cy+.030,1.449),identity,'brass_dull',.018)
   drilled(body,(cx,cy,1.377),(0,1,0),.008,.12)
   path=[(cx-.064,cy,1.440),(cx-.064,cy,1.458)]
   path.extend((cx+.064*math.cos(math.pi-i*math.pi/24),cy,1.458+.064*math.sin(math.pi-i*math.pi/24)) for i in range(25))
   path.append((cx+.064,cy,1.440));curved_wire(blank['id']+'_OpenShackle',path,.007,identity,'chrome')
 elif kind=='folded_ladder':
  # Two hinged frames, rather than two solid panels. Original source blank
  # orientations are retained in the hidden reference collection.
  lx0=min(m['rect'][0] for m in item['members']);lx1=max(m['rect'][2] for m in item['members']);cy=sum([y0,y1])*.5-.12
  for frame,yy in enumerate([cy-.100,cy+.100]):
   for xx in [lx0+.045,lx1-.045]:
    rod(identity+f'_Stile{frame}_{xx}',(xx,yy,.030),(xx,cy,1.636),.024,identity,'timber')
    box(identity+f'_Foot{frame}_{xx}',(xx-.027,yy-.027,.01),(xx+.027,yy+.027,.045),identity,'timber',.004)
    support(identity,floor['id'],(xx,yy,.01),(0,0,1),'folded ladder foot')
   for i in range(4):
    zz=.26+i*.32;at_y=yy+(cy-yy)*(zz-.030)/1.606
    rod(identity+f'_Rung{frame}_{i}',(lx0+.04,at_y,zz),(lx1-.04,at_y,zz),.020,identity,'timber')
  for xx in [lx0+.045,lx1-.045]:
   rod(identity+f'_HingePin{xx}',(xx-.035,cy,1.636),(xx+.035,cy,1.636),.017,identity,'metal')
   for yy in [cy-.029,cy+.029]:box(identity+f'_HingePlate{xx}_{yy}',(xx-.024,yy-.006,1.585),(xx+.024,yy+.006,1.653),identity,'metal',.003)
  box(identity+'_TopTread',(lx0+.015,cy-.048,1.626),(lx1-.015,cy+.048,1.671),identity,'timber',.004)
 elif kind=='window_cabinet':
  cabinet(identity,row,'wood_dark',.44)
  box(identity+'_DisplayTop',(x0,y0,.421),(x1,y1,.445),identity,'wood_dark',.003)
  back=item['members'][1];a,b,c,d=back['rect']
  box(identity+'_DisplayBack',(a,b,.425),(c,d,back['z0']+back['h']),identity,'plywood',.003)
  for yy in [b,d-.023]:box(identity+f'_FrameEdge{yy}',(a-.004,yy,.42),(c+.012,yy+.023,1.587),identity,'wood_dark',.003)
  box(identity+'_FrameHead',(a-.004,b,1.557),(c+.012,d,1.586),identity,'wood_dark',.003)
 else:raise AssertionError(kind)

for row in selected:
 x0,y0,x1,y1=row['rect'];z0=row['z0'];box(row['id']+'_RetainedBox',(x0,y0,z0),(x1,y1,z0+row['h']),row['id'],row['mat'],0,retained)

# Record the actual finished stock, after bevels, rather than its raw blank.
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12
 bm.free()
draws=[];inventory=[];fallbacks=0;total_triangles=0
for item in assemblies:
 identity=item['id'];keys=sorted({key for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['body']['z0']))
 for key in keys:
  vertices=[];faces=[]
  for obj,material_key in pieces[identity]:
   if material_key!=key:continue
   # Sum in doubles before rebasing the assembled draw. World-coordinate
   # float32 addition otherwise collapses tiny bevel faces fifty metres out.
   offset=len(vertices);vertices.extend(tuple(np.asarray(obj.location,dtype=np.float64)+np.asarray(v.co,dtype=np.float64)) for v in obj.data.vertices);faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
  name=identity+'__'+key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64)
   assert np.linalg.norm(np.cross(points[1]-points[0],points[2]-points[0]))>0,(name,face.index,points.tolist())
   n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],key=='timber');fallbacks+=local
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(n)
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/locksmith_fittings.blend'))
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
asset=OUT/'game/assets/props/locksmith_fittings.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':p['key'],'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/locksmith_fittings.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/locksmith_fittings.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/locksmith_fittings.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(((OUT/'game/assets/building/textures'/f) if (OUT/'game/assets/building/textures'/f).exists() else (ROOT/'game/assets/building/textures'/f)) for f in sets[key]['files'])
bindings.extend([ROOT/'art/tools/build_iron_blackened.py',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'art/textures/procedural/iron_blackened/{name}.png' for name in ['albedo','roughness','normal','height'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(ROOT/'art/blender/scripts/inspect_locksmith_fittings.py')
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'key_forms':key_forms,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/locksmith_fittings_construction.json','game/tests/fixtures/orison_locksmith_fittings.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('LOCKSMITH FITTINGS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
