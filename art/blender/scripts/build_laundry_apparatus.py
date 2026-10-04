"""Source-fitted wash basins, hand wringer, iron heater and suspended drying racks."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
import os
OUT=Path(os.environ.get('LAUNDRY_APPARATUS_OUT',str(ROOT)))
plan_path=Path(os.environ.get('LAUNDRY_APPARATUS_PLAN',str(ROOT/'art/data/laundry_apparatus/source_plan.json')));layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text());assert plan['classification']=='ADAPTATION'
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_model_laundry.gltf';source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog_path=Path(os.environ.get('LAUNDRY_APPARATUS_CATALOG',str(ROOT/'game/data/runtime_material_sets.json')));catalog=json.loads(catalog_path.read_text())['materials']
for key in plan['runtime_keys']:
 if key in plan['catalog_variants']:
  spec=catalog[plan['catalog_variants'][key]];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35,'roughness':spec['roughness_multiplier']};definition=OUT/f'art/textures/{spec["catalog_mapping"]}/material.json'
  if not definition.exists():definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json'
 else:
  shipping=next(m for m in source_gltf['materials'] if m['name'] in ['M_'+key+'_b','M_'+key]);pbr=shipping['pbrMetallicRoughness'];files=[]
  for texture in [pbr['baseColorTexture'],pbr['metallicRoughnessTexture'],shipping['normalTexture']]:files.append(Path(source_gltf['images'][source_gltf['textures'][texture['index']]['source']]['uri']).name)
  suffix='_b' if shipping['name'].endswith('_b') else '';definition=ROOT/f'art/textures/ai_materials/{key}{suffix}/material.json'
  sets[key]={'files':files,'meters_per_tile':json.loads(definition.read_text())['meters_per_tile'],'metallic':pbr.get('metallicFactor',1),'roughness':pbr.get('roughnessFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1)}
 material_definitions.append(definition)
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
floor=rows['storm_shop_model_laundry_floor'];ceil=rows['storm_shop_model_laundry_ceil'];selected=[];assemblies=[]
for group in plan['groups']:
 members=[rows[identity] for identity in group['sources']];selected.extend(members);assemblies.append({'id':members[0]['id'],'kind':group['kind'],'members':members,'body':members[0],'cell':'shop_model_laundry','floor':floor})
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
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
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
 points=[Vector(p) for p in path];verts=[];n=8
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

def gear(name,cx,cy,cz,radius,identity):
 # Closed toothed blank. Teeth are integral, not detached decorative cubes.
 count=48;outline=[]
 for i in range(count):
  angle=i*math.tau/count;r=radius if i%4 in [1,2] else radius-.006
  outline.append((cx+r*math.cos(angle),cz+r*math.sin(angle)))
 n=len(outline);verts=[(x,y,z) for y in [cy-.009,cy+.009] for x,z in outline]
 return solid(name,verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)],identity,'cast_iron')

for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];x=(x0+x1)*.5;y=(y0+y1)*.5;z=float(row['z0']);kind=item['kind']
 if kind=='tub':
  basin(identity+'_OpenZincBasin',x,y,(x1-x0)*.5,(y1-y0)*.5,.37,.819,identity,'zinc_liner')
  rim=item['members'][1];r=rim['rect'];torus(identity+'_RolledRim',(x,y,.8175),(r[2]-r[0])*.5-.0275,(r[3]-r[1])*.5-.0275,.0275,identity,'metal')
  # A low metal stand bears on the existing tile. Top rails intersect the
  # tapered underside; the basin cavity remains empty and unplumbed.
  for i,(dx,dy) in enumerate([(-.20,-.215),(.20,-.215),(-.20,.215),(.20,.215)]):
   box(identity+f'_StandLeg{i}',(x+dx-.016,y+dy-.016,.01),(x+dx+.016,y+dy+.016,.387),identity,'metal',.002)
   box(identity+f'_Foot{i}',(x+dx-.025,y+dy-.025,.01),(x+dx+.025,y+dy+.025,.019),identity,'metal',.002)
   support(identity,floor['id'],(x+dx,y+dy,.01),(0,0,1),'tub stand foot')
  for dy in [-.215,.215]:box(identity+f'_StandCross{dy}',(x-.219,y+dy-.018,.357),(x+.219,y+dy+.018,.386),identity,'metal',.002)
  for dx in [-.20,.20]:box(identity+f'_StandSide{dx}',(x+dx-.018,y-.234,.32),(x+dx+.018,y+.234,.379),identity,'metal',.002)
 elif kind=='mangle':
  cx=x;front=y0+.08;back=y1-.08;lower=.965;upper=1.105
  for i,(xx,yy) in enumerate([(x0+.08,front),(x1-.08,front),(x0+.08,back),(x1-.08,back)]):
   box(identity+f'_Leg{i}',(xx-.022,yy-.022,.01),(xx+.022,yy+.022,.83),identity,'timber',.004)
   support(identity,floor['id'],(xx,yy,.01),(0,0,1),'wringer timber stand foot')
  for zz in [.27,.79]:
   for yy in [front,back]:box(identity+f'_EndBrace{zz}_{yy}',(x0+.057,yy-.022,zz),(x1-.057,yy+.022,zz+.04),identity,'timber',.003)
   for xx in [x0+.08,x1-.08]:box(identity+f'_SideBrace{zz}_{xx}',(xx-.018,front-.024,zz),(xx+.018,back+.024,zz+.04),identity,'timber',.003)
  for i,yy in enumerate([front,back]):
   for xx in [cx-.11,cx+.11]:box(identity+f'_YokePost{i}_{xx}',(xx-.028,yy-.032,.815),(xx+.028,yy+.032,1.23),identity,'timber',.004)
   box(identity+f'_YokeTop{i}',(cx-.14,yy-.033,1.205),(cx+.14,yy+.033,1.25),identity,'timber',.004)
   for zz in [lower,upper]:
    box(identity+f'_Bearing{i}_{zz}',(cx-.085,yy-.023,zz-.028),(cx+.085,yy+.023,zz+.028),identity,'cast_iron',.004)
    for xx in [cx-.105,cx+.105]:rod(identity+f'_Bolt{i}_{zz}_{xx}',(xx,yy-.039,zz),(xx,yy+.039,zz),.006,identity,'cast_iron')
   rod(identity+f'_PressureScrew{i}',(cx,yy,upper+.022),(cx,yy,1.285),.007,identity,'cast_iron')
   rod(identity+f'_PressureHandle{i}',(cx-.065,yy,1.28),(cx+.065,yy,1.28),.008,identity,'cast_iron')
  for i,zz in enumerate([lower,upper]):
   rod(identity+f'_RubberRoll{i}',(cx,front+.028,zz),(cx,back-.028,zz),.071,identity,'rubber_aged')
   rod(identity+f'_RollShaft{i}',(cx,front-.20 if i==0 else front-.13,zz),(cx,back+.055,zz),.016,identity,'cast_iron')
   gear(identity+f'_DriveGear{i}',cx,front-.073,zz,.071,identity)
  rod(identity+'_CrankArm',(cx,front-.16,lower),(cx+.17,front-.16,lower-.065),.013,identity,'cast_iron')
  rod(identity+'_GripPin',(cx+.17,front-.25,lower-.065),(cx+.17,front-.145,lower-.065),.009,identity,'cast_iron')
  rod(identity+'_TurnedHandgrip',(cx+.17,front-.26,lower-.065),(cx+.17,front-.174,lower-.065),.021,identity,'timber')
  # A sloping receiving board meets the timber yoke. Closed thickness keeps
  # the cloth path readable without adding an invented interactive machine.
  prism(identity+'_FeedBoard',[(cx-.11,front+.01),(cx+.11,front+.01),(cx+.20,back-.01),(cx-.20,back-.01)],.82,.852,identity,'timber',.004)
 elif kind=='heater':
  box(identity+'_IronHeatingPlate',(x0,y0,.705),(x1,y1,.75),identity,'cast_iron',.008)
  for i,(xx,yy) in enumerate([(x0+.055,y0+.055),(x1-.055,y0+.055),(x0+.055,y1-.055),(x1-.055,y1-.055)]):
   rod(identity+f'_Leg{i}',(xx,yy,.015),(xx,yy,.723),.018,identity,'cast_iron')
   box(identity+f'_Foot{i}',(xx-.026,yy-.026,.01),(xx+.026,yy+.026,.025),identity,'cast_iron',.003)
   support(identity,floor['id'],(xx,yy,.01),(0,0,1),'iron heater foot')
  for yy in [y0+.055,y1-.055]:rod(identity+f'_Stretcher{yy}',(x0+.055,yy,.26),(x1-.055,yy,.26),.012,identity,'cast_iron')
  for xx in [x0+.055,x1-.055]:rod(identity+f'_LongBrace{xx}',(xx,y0+.055,.26),(xx,y1-.055,.26),.012,identity,'cast_iron')
  # Passive ring under the plate; gas supply and lighting are not fabricated
  # as functioning services by this visual batch.
  torus(identity+'_BurnerRing',(x,y,.675),.14,.23,.018,identity,'cast_iron')
  for xx in [x-.14,x+.14]:rod(identity+f'_BurnerMount{xx}',(xx,y,.66),(xx,y,.722),.013,identity,'cast_iron')
 elif kind=='iron':
  outline=[(x0,y0+.018),(x0+.035,y0),(x1-.075,y0+.015),(x1,y),(x1-.075,y1-.015),(x0+.035,y1),(x0,y1-.018)]
  prism(identity+'_PointedSole',outline,z,z+.043,identity,'cast_iron',.0025)
  a=(x0+.06,y,z+.038);b=(x1-.095,y,z+.038)
  path=[(a[0]+(b[0]-a[0])*i/24,y,z+.039+.095*math.sin(math.pi*i/24)**.6) for i in range(25)]
  curved_wire(identity+'_ArchedHandle',path,.011,identity,'cast_iron')
  for xx in [a[0],b[0]]:box(identity+f'_HandleLug{xx}',(xx-.014,y-.016,z+.033),(xx+.014,y+.016,z+.054),identity,'cast_iron',.002)
  support(identity,'storm_shop_model_laundry_gas_ring',(x-.01,y,z),(0,0,1),'flat iron sole on heater plate')
 elif kind=='airer':
  members=item['members'];rx0=min(r['rect'][0] for r in members);rx1=max(r['rect'][2] for r in members);ry0=min(r['rect'][1] for r in members);ry1=max(r['rect'][3] for r in members)
  for index,bar in enumerate(members):
   a,b,c,d=bar['rect'];box(identity+f'_DryingLath{index}',(a,b,bar['z0']),(c,d,bar['z0']+bar['h']),identity,'timber',.004)
  for i,xx in enumerate([rx0+.13,rx1-.13]):
   box(identity+f'_Crossmember{i}',(xx-.026,ry0-.015,2.603),(xx+.026,ry1+.015,2.645),identity,'timber',.004)
   yy=(ry0+ry1)*.5
   # Supported pulley cheeks and shafts, with a rope tied at the crossbar.
   # This retained-height airer is static; no missing hoist is simulated.
   box(identity+f'_CeilingPlate{i}',(xx-.055,yy-.048,ceil['z0']-.008),(xx+.055,yy+.048,ceil['z0']),identity,'metal',.003)
   for side in [-1,1]:box(identity+f'_PulleyCheek{i}_{side}',(xx+side*.037-.005,yy-.036,3.195),(xx+side*.037+.005,yy+.036,3.295),identity,'metal',.002)
   rod(identity+f'_PulleyAxle{i}',(xx-.045,yy,3.24),(xx+.045,yy,3.24),.006,identity,'metal')
   rod(identity+f'_PulleyWheel{i}',(xx-.025,yy,3.24),(xx+.025,yy,3.24),.026,identity,'timber')
   # Single loop through an existing fixed-height pulley: both terminated
   # ends enter the crossmember. A live lift/control route remains open.
   path=[(xx,yy-.024,2.64)]
   for angle in range(180,-1,-15):a=math.radians(angle);path.append((xx,yy+.028*math.cos(a),3.24+.028*math.sin(a)))
   path.append((xx,yy+.024,2.64));curved_wire(identity+f'_RopeLoop{i}',path,.0035,identity,'linen')
   support(identity,ceil['id'],(xx,yy,ceil['z0']),(0,0,-1),'airer pulley ceiling plate')

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
   offset=len(vertices);vertices.extend(tuple(obj.location+v.co) for v in obj.data.vertices);faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
  name=identity+'__'+key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64);n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],key=='timber');fallbacks+=local
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(n)
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/laundry_apparatus.blend'))
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
asset=OUT/'game/assets/props/laundry_apparatus.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in item['members']:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':p['key'],'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/laundry_apparatus.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(OUT/'game/data/orison_v2/laundry_apparatus.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),ROOT/'art/blender/scripts/fabrication_uvs.py',catalog_path,ROOT/'game/scripts/generated/material_sets.gd',OUT/'game/assets/props/laundry_apparatus.glb.import',*material_definitions]
for key in plan['runtime_keys']:bindings.extend(((OUT/'game/assets/building/textures'/f) if (OUT/'game/assets/building/textures'/f).exists() else (ROOT/'game/assets/building/textures'/f)) for f in sets[key]['files'])
bindings.extend([ROOT/'art/tools/build_iron_blackened.py',ROOT/'art/data/material_catalog.json',ROOT/'art/textures/catalog_mapping.json',ROOT/'art/tools/generate_runtime_materials.py'])
bindings.extend(ROOT/f'art/textures/procedural/iron_blackened/{name}.png' for name in ['albedo','roughness','normal','height'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/laundry_apparatus_construction.json','game/tests/fixtures/orison_laundry_apparatus.json']:(OUT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('LAUNDRY APPARATUS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
