"""Source-fitted paired shoes, supported benches, passive machinery and shop fittings."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('COBBLER_FITTINGS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('COBBLER_FITTINGS_PLAN',str(ROOT/'art/data/cobbler_fittings/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text());assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_shoe_rebuilding.gltf';source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog_path=Path(os.environ.get('COBBLER_FITTINGS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text())['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=OUT/f'art/textures/{spec["catalog_mapping"]}/material.json'
  if not definition.exists():definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json'
 else:
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+plan.get('material_aliases',{}).get(key,key)+'_b','M_'+plan.get('material_aliases',{}).get(key,key)]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr['baseColorTexture'],pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name)
  mapping=files[0].removeprefix('T_').removesuffix('_albedo.png').replace('ai_materials_','ai_materials/',1)
  definition=ROOT/f'art/textures/{mapping}/material.json'
  sets[key]={'files':files,'meters_per_tile':json.loads(definition.read_text())['meters_per_tile'],'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1)}
 material_definitions.append(definition)
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_shoe_rebuilding_floor'];ceil=rows['storm_shop_shoe_rebuilding_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_shoe_rebuilding','floor':floor})
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
  elif index==0 and key in plan.get('material_tints',{}):
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





def cabinet(identity,row,key,top,floor_z=.01):
 x0,y0,x1,y1=row['rect'];bottom=float(row['z0']);th=.022
 for i,(xx,yy) in enumerate([(x0+.03,y0+.03),(x1-.03,y0+.03),(x0+.03,y1-.03),(x1-.03,y1-.03)]):
  box(identity+f'_Foot{i}',(xx-.026,yy-.026,floor_z),(xx+.026,yy+.026,bottom+.055),identity,key,.004)
  support(identity,floor['id'],(xx,yy,floor_z),(0,0,1),'cabinet foot')
 box(identity+'_Bottom',(x0,y0,bottom+.028),(x1,y1,bottom+.054),identity,key,.003)
 for xx in [x0,x1-th]:box(identity+f'_Side{xx}',(xx,y0,bottom+.04),(xx+th,y1,top),identity,key,.003)
 for yy in [y0,y1-th]:box(identity+f'_End{yy}',(x0+th,yy,bottom+.04),(x1-th,yy+th,top),identity,key,.003)

def floor_height(x,y):
 dust=rows['storm_shop_shoe_rebuilding_dust_felt'];r=dust['rect']
 return dust['z0']+dust['h'] if r[0]<x<r[2] and r[1]<y<r[3] else .01

def feet(identity,rect,top,key='cast_iron'):
 x0,y0,x1,y1=rect
 for i,(xx,yy) in enumerate([(x0+.07,y0+.07),(x1-.07,y0+.07),(x0+.07,y1-.07),(x1-.07,y1-.07)]):
  base=floor_height(xx,yy)
  box(identity+f'_Foot{i}',(xx-.045,yy-.045,base),(xx+.045,yy+.045,base+.035),identity,key,.004)
  box(identity+f'_Leg{i}',(xx-.023,yy-.023,base+.025),(xx+.023,yy+.023,top),identity,key,.004)
  support(identity,'storm_shop_shoe_rebuilding_dust_felt' if base>.011 else floor['id'],(xx,yy,base),(0,0,1),'fitted foot')

def shoe_form(name,cx,cy,z,width,length,height,identity,key,upper=False):
 # Longitudinal closed loft: rounded heel, instep, vamp and low toe.
 profile=[(0,.15,.75),(.04,.75,.95),(.18,.85,1.),(.36,.94,.90),(.55,1.,.59),(.76,1.,.44),(.91,.84,.36),(.985,.24,.28),(1.,.025,.22)]
 n=24;verts=[]
 for t,w,h in profile:
  bottom=z;top=z+height*h;center=(bottom+top)*.5
  verts.extend((cx+width*.5*w*math.cos(j*math.tau/n),cy+length*(t-.5),center+(top-bottom)*.5*math.sin(j*math.tau/n)) for j in range(n))
 faces=[tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))]
 faces.extend((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(profile)-1) for j in range(n))
 obj=solid(name,verts,faces,identity,key)
 if upper:
  # Cut a finite oval collar cavity from the saved solid, leaving its floor.
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=(cx,cy-length*.31,z+height*.90))
  cutter=bpy.context.object;cutter.scale=(width*.30,length*.145,height*.66)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bpy.context.view_layer.objects.active=obj
  mod=obj.modifiers.new('Open collar','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0000001);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00000001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
 return obj

for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];x=(x0+x1)*.5;y=(y0+y1)*.5;z=float(row['z0']);kind=item['kind']
 if kind=='window_cabinet':
  cabinet(identity,row,'wood_dark',.425)
  box(identity+'_Top',(x0,y0,.425),(x1,y1,.44),identity,'wood_dark')
  back=item['members'][1];a,b,c,d=back['rect'];box(identity+'_DisplayBack',(a,b,.42),(c,d,1.57),identity,'plywood')
  for i,yy in enumerate([y0+.05,y1-.05]):box(identity+f'_BackBrace{i}',(x0-.01,yy,.4),(x0+.03,yy+.026,1.57),identity,'wood_dark')
 elif kind=='bench':
  feet(identity,row['rect'],.97,'timber')
  for yy in [y0+.035,y1-.075]:box(identity+f'_Apron{yy}',(x0+.03,yy,.76),(x1-.03,yy+.04,.97),identity,'timber')
  box(identity+'_UnderShelf',(x0+.04,y0+.04,.24),(x1-.04,y1-.04,.275),identity,'timber')
  top=item['members'][1];a,b,c,d=top['rect'];box(identity+'_Top',(a,b,.97),(c,d,1.03),identity,'wood_dark',.005)
 elif kind=='finisher':
  feet(identity,row['rect'],.90)
  box(identity+'_Pedestal',(x0+.08,y0+.035,.12),(x1-.035,y1-.035,.935),identity,'cast_iron',.018)
  box(identity+'_HeadBed',(5.74,-47.12,.93),(6.54,-45.78,1.03),identity,'cast_iron',.01)
  # Bearings stand on the bed and carry the source shaft's actual Y axis.
  for i,yy in enumerate([-47.12,-45.80]):
   box(identity+f'_Bearing{i}',(5.73,yy-.055,1.02),(5.82,yy+.055,1.19),identity,'cast_iron')
  rod(identity+'_Spindle',(5.775,-47.18,1.15),(5.775,-45.72,1.15),.026,identity,'metal')
  for i,wheel in enumerate(item['members'][4:]):
   a,b,c,d=wheel['rect'];cy=(b+d)*.5
   rod(identity+f'_Buff{i}',(5.775,b,1.15),(5.775,d,1.15),.15,identity,'rubber_aged' if i%2 else 'cast_iron')
   rod(identity+f'_Hub{i}',(5.775,b-.006,1.15),(5.775,d+.006,1.15),.046,identity,'metal')
   box(identity+f'_Rest{i}',(5.46,b+.016,.97),(5.67,d-.016,.994),identity,'metal')
   rod(identity+f'_RestStay{i}',(5.59,cy,.98),(5.76,cy,1.027),.009,identity,'metal')
  box(identity+'_HoodBack',(6.46,-47.12,1.02),(6.50,-45.78,1.71),identity,'cast_iron')
  box(identity+'_HoodRoof',(6.12,-47.12,1.69),(6.50,-45.78,1.71),identity,'cast_iron')
  for i,yy in enumerate([-47.12,-45.805]):box(identity+f'_HoodEnd{i}',(6.12,yy,1.35),(6.5,yy+.025,1.70),identity,'cast_iron')
  box(identity+'_DustDrawer',(5.84,-47.065,.17),(6.40,-47.005,.42),identity,'cast_iron')
  rod(identity+'_DrawerPull',(6.05,-47.083,.32),(6.24,-47.083,.32),.008,identity,'metal')
  for xx in [6.055,6.235]:rod(identity+f'_PullStem{xx}',(xx,-47.083,.32),(xx,-47.045,.32),.006,identity,'metal')
 elif kind=='shoe_rack':
  # Keep the rear doorway clear; pair owners retain identity, not the bad
  # source pose that placed them across its leaf and beyond a shelf end.
  left=6.13;right=8.70
  for i,xx in enumerate([left+.025,right-.025]):
   for j,yy in enumerate([y0+.025,y1-.025]):
    base=floor_height(xx,yy);box(identity+f'_Upright{i}_{j}',(xx-.020,yy-.020,base),(xx+.020,yy+.020,1.925),identity,'timber')
    support(identity,'storm_shop_shoe_rebuilding_dust_felt' if base>.011 else floor['id'],(xx,yy,base),(0,0,1),'shoe rack foot')
  for rack in item['members'][:5]:
   box(identity+'_'+rack['id'].split('_')[-1],(left,y0,rack['z0']),(right,y1,rack['z0']+.04),identity,'timber')
  levels=collections.defaultdict(int)
  for shoe in item['members'][5:]:
   number=int(shoe['id'].split('shoe')[-1]);level=number%5;slot=levels[level];levels[level]+=1
   cx=6.34+slot*.76;cy=-50.05;base=.46+.36*level
   key='vinyl_oxblood' if shoe['mat']=='vinyl_oxblood' else 'shoe_dark'
   for side in [-1,1]:
    sx=cx+side*.057;label=identity+f'_Pair{number}_{side}'
    # A broad, flat sole, separate heel and closed hollow upper are joined.
    outline=[(sx+dx*.093,cy+dy*.25) for dx,dy in [(-.35,-.5),(.35,-.5),(.48,-.30),(.5,.25),(.35,.46),(0,.5),(-.35,.46),(-.5,.25),(-.48,-.30)]]
    prism(label+'_Sole',outline,base,base+.015,identity,'rubber_aged',.0015)
    box(label+'_Heel',(sx-.030,cy-.110,base),(sx+.030,cy-.055,base+.025),identity,'rubber_aged',.002)
    shoe_form(label+'_Upper',sx,cy,base+.012,.088,.246,.090,identity,key,True)
    # Lacing lies on the sloped vamp; each end enters the upper shell.
    for j in range(3):
     yy=cy-.025+j*.014;zz=base+.087-j*.008
     rod(label+f'_Lace{j}',(sx-.035,yy,zz-.006),(sx+.035,yy+.008,zz-.006),.0015,identity,'linen')
 elif kind=='counter':
  cabinet(identity,row,'wood_dark',1.075)
  top=item['members'][1];a,b,c,d=top['rect'];box(identity+'_Top',(a,b,1.07),(c,d,1.12),identity,'countertop',.003)
  ledger=item['members'][2];a,b,c,d=ledger['rect'];box(identity+'_CleanBookSeat',(a-.01,b-.01,1.12),(c+.01,d+.01,1.131),identity,'wood_dark',.001)
  box(identity+'_BookCover',(a,b,1.13),(c,d,1.136),identity,'wood_dark',.001)
  box(identity+'_BookPages',(a+.005,b+.005,1.135),(c-.005,d-.005,1.174),identity,'paper',.001)
  box(identity+'_BookTop',(a,b,1.172),(c,d,1.18),identity,'wood_dark',.001)
 elif kind in ['outsole','patcher']:
  top=.86 if kind=='outsole' else .82;feet(identity,row['rect'],top,'cast_iron')
  box(identity+'_Bed',(x0,y0,top-.03),(x1,y1,top+.02),identity,'cast_iron')
  rod(identity+'_DriveAxle',(x0+.04,y,top-.24),(x1-.04,y,top-.24),.018,identity,'metal')
  for i,xx in enumerate([x0+.04,x1-.04]):box(identity+f'_AxleBearing{i}',(xx-.023,y-.026,top-.285),(xx+.023,y+.026,top-.02),identity,'cast_iron')
  wheelx=x1-.025
  # Open spoked flywheel with axle, hub and physical rim.
  hub=(wheelx,y,top-.24)
  # torus is built horizontally then rotated as a saved stock.
  rim=torus(identity+'_Flywheel',hub,.20,.20,.009,identity,'cast_iron');rim.rotation_euler.y=math.pi/2;
  bpy.context.view_layer.objects.active=rim;rim.select_set(True);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False);rim.select_set(False)
  # Rotation about the stock origin preserves its finite wheel centre.
  for j in range(6):
   angle=j*math.tau/6
   rod(identity+f'_Spoke{j}',hub,(wheelx,y+.195*math.cos(angle),top-.24+.195*math.sin(angle)),.007,identity,'cast_iron')
  rod(identity+'_Hub',(wheelx-.03,y,top-.24),(wheelx+.03,y,top-.24),.030,identity,'metal')
  box(identity+'_Treadle',(x0+.055,y0+.07,.10),(x1-.055,y1-.07,.125),identity,'cast_iron')
  rod(identity+'_Crank',hub,(wheelx,y+.09,top-.15),.009,identity,'metal')
  rod(identity+'_CrankPin',(wheelx-.028,y+.09,top-.15),(wheelx+.018,y+.09,top-.15),.012,identity,'metal')
  rod(identity+'_PedalLink',(x1-.06,y,.12),(x1-.045,y+.09,top-.15),.007,identity,'metal')
  if kind=='outsole':
   box(identity+'_Column',(5.75,-47.60,.86),(5.91,-47.36,1.32),identity,'cast_iron',.012)
   box(identity+'_SewingHead',(5.48,-47.59,1.22),(5.91,-47.35,1.38),identity,'cast_iron',.014)
   rod(identity+'_WorkingHorn',(5.82,-47.48,.94),(5.51,-47.48,.94),.035,identity,'metal')
   rod(identity+'_NeedleBar',(5.53,-47.48,1.25),(5.53,-47.48,1.02),.010,identity,'metal')
   curved_wire(identity+'_CurvedNeedle',[(5.53,-47.48,1.02),(5.51,-47.48,.98),(5.53,-47.48,.948)],.0025,identity,'metal')
  else:
   box(identity+'_Column',(5.51,-48.15,.82),(5.67,-47.90,1.16),identity,'cast_iron',.012)
   box(identity+'_NarrowArm',(5.50,-48.60,1.10),(5.68,-47.91,1.24),identity,'cast_iron',.012)
   rod(identity+'_LowerHorn',(5.59,-48.00,.91),(5.59,-48.57,.91),.029,identity,'metal')
   rod(identity+'_NeedleBar',(5.59,-48.54,1.15),(5.59,-48.54,.935),.006,identity,'metal')
   box(identity+'_NeedlePlate',(5.55,-48.58,.914),(5.63,-48.50,.926),identity,'metal',.001)
 elif kind=='last_rack':
  feet(identity,row['rect'],1.66,'timber')
  for level in range(3):
   top=.32+.42*level
   box(identity+f'_Shelf{level}',(x0,-49.66,top-.025),(x1,-49.12,top),identity,'timber')
  for i,last in enumerate(item['members'][1:]):
   a,b,c,d=last['rect'];shoe_form(identity+f'_Last{i}',(a+c)*.5,(b+d)*.5,last['z0'],.128,.48,.13,identity,'cast_iron')
 elif kind=='soles':
  base=floor_height(x,y);box(identity+'_StockBase',(x0,y0,base),(x1,y1,.051),identity,'timber')
  support(identity,'storm_shop_shoe_rebuilding_dust_felt',(x,y,base),(0,0,1),'sole-stock base')
  for side in [-1,1]:
   sx=x+side*.11
   for i in range(50):
    angle=math.radians(2. if i%2 else -2.);dx=.0015*math.sin(i*.7);dy=.0015*math.cos(i*.7)
    outline=[]
    for px,py in [(-.35,-.5),(.35,-.5),(.44,-.30),(.50,.19),(.39,.42),(.16,.50),(-.16,.50),(-.39,.42),(-.50,.19),(-.44,-.30)]:
     xx=px*.185;yy=py*.55;outline.append((sx+dx+xx*math.cos(angle)-yy*math.sin(angle),y+dy+xx*math.sin(angle)+yy*math.cos(angle)))
    prism(identity+f'_Sole{side}_{i}',outline,.05+i*.0072,.0576+i*.0072,identity,'vinyl_oxblood',.0007)
 elif kind=='waiting_seat':
  feet(identity,row['rect'],.49,'wood_dark')
  box(identity+'_Seat',(x0,y0,.48),(x1,y1,.53),identity,'wood_dark',.006)
  for yy in [y0+.04,y1-.06]:box(identity+f'_Rail{yy}',(x0+.045,yy,.25),(x1-.045,yy+.02,.29),identity,'wood_dark')
 else:raise ValueError(kind)

# Fitted arrangement clears retained passage rather than accepting source
# conflicts. Source references below keep their original canonical poses.
for assembly,mode in [('storm_shop_shoe_rebuilding_finisher','mirror'),('storm_shop_shoe_rebuilding_last_rack','shift')]:
 for obj,key in pieces[assembly]:
  if mode=='mirror':
   obj.location.x=12.-obj.location.x
   for vertex in obj.data.vertices:vertex.co.x=-vertex.co.x
   bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
  else:obj.location.x+=1.55
 for contact in contacts:
  if contact['assembly']!=assembly:continue
  contact['point'][0]=12.-contact['point'][0] if mode=='mirror' else contact['point'][0]+1.55
  if mode=='mirror':contact['direction'][0]*=-1

for row in selected:
 x0,y0,x1,y1=row['rect'];z0=row['z0'];box(row['id']+'_RetainedBox',(x0,y0,z0),(x1,y1,z0+row['h']),row['id'],row['mat'],0,retained)

# Record the actual finished stock, after bevels, rather than its raw blank.
for record in stock_checks:
 obj=bpy.data.objects[record['name']];bm=bmesh.new();bm.from_mesh(obj.data)
 assert all(e.is_manifold for e in bm.edges),record['name']
 record['volume_m3']=bm.calc_volume(signed=True);assert record['volume_m3']>1e-12
 bm.free()
def partition_of(obj,key):
 if obj.name.endswith('_Upper') and '_Pair' in obj.name:
  return key+'__'+obj.name.split('_Pair',1)[1].removesuffix('_Upper')
 return key

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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/cobbler_fittings.blend'))
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
asset=OUT/'game/assets/props/cobbler_fittings.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':plan.get('material_aliases',{}).get(p['key'],p['key']),'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/cobbler_fittings.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/cobbler_fittings.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/cobbler_fittings.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(((OUT/'game/assets/building/textures'/f) if (OUT/'game/assets/building/textures'/f).exists() else (ROOT/'game/assets/building/textures'/f)) for f in sets[key]['files'])
bindings.extend([ROOT/'art/tools/build_iron_blackened.py',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'art/textures/procedural/iron_blackened/{name}.png' for name in ['albedo','roughness','normal','height'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
bindings.append(ROOT/'art/blender/scripts/inspect_cobbler_fittings.py')
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/cobbler_fittings_construction.json','game/tests/fixtures/orison_cobbler_fittings.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('COBBLER FITTINGS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
