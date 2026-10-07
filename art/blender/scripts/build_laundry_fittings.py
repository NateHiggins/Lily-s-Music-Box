"""Source-fitted hand-laundry parcels, hung shirts and ironing furniture."""
from pathlib import Path
import ast,collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=ROOT/'art/data/laundry_fittings/source_plan.json';layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text())
assert plan['classification']=='ADAPTATION'
floor=next(r for r in layout['floors'] if r['id']=='F01');rows={r['id']:r for r in floor['furniture']}
# Reuse the shipping shop variants, including oxblood vinyl, which is an
# existing glTF catalogue material rather than a MatLib runtime alias.
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_model_laundry.gltf'
source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
for key in plan['runtime_keys']:
 definition=ROOT/f'art/textures/ai_materials/{key}/material.json' if key in plan['catalog_variants'] else ROOT/f'art/textures/ai_materials/{key}_b/material.json';material_definitions.append(definition)
 shipping=next(m for m in source_gltf['materials'] if m['name']=='M_'+key+'_b')
 pbr=shipping['pbrMetallicRoughness'];files=[]
 for texture in [pbr['baseColorTexture'],pbr['metallicRoughnessTexture'],shipping['normalTexture']]:
  image=source_gltf['images'][source_gltf['textures'][texture['index']]['source']]
  files.append(Path(image['uri']).name)
 sets[key]={'files':files,'meters_per_tile':json.loads(definition.read_text())['meters_per_tile'],'metallic':pbr.get('metallicFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1)}
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
def cell_for(row):return 'shop_otis_son' if row['batch']=='shop_otis___son' else row['batch']
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for key,catalog_key in plan['catalog_variants'].items():
 spec=catalog[catalog_key];sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35}
selected=[row for row in rows.values() if row.get('batch')=='shop_model_laundry' and (re.fullmatch(r'storm_shop_model_laundry_(parcel\d+_\d+|shirt\d+)',row['id']) or row['id'] in ['storm_shop_model_laundry_rail','storm_shop_model_laundry_iron_table','storm_shop_model_laundry_iron_pad','storm_shop_model_laundry_sleeve_board'])]
assert len(selected)==plan['original_records']
floor=rows['storm_shop_model_laundry_floor'];ceil=rows['storm_shop_model_laundry_ceil']
assemblies=[{'id':row['id'],'kind':('parcel' if '_parcel' in row['id'] else 'shirt' if '_shirt' in row['id'] else row['id'].split('_laundry_')[1]),'body':row,'cell':'shop_model_laundry','floor':floor} for row in selected]
# The immutable assembler supplies the complete original receiving hull. Keep
# the receiving owner and source boxes; fit only the table's obstructing end.
receiver=rows[plan['receiving_clearance']['source_id']]
assert receiver['asm']=='arcade_cab' and receiver['variant']==0 and receiver['yaw']==180.
assembler_path=ROOT/'art/blender/scripts/build_orison.py';assembler_source=assembler_path.read_text(encoding='utf-8-sig')
function=next(n for n in ast.parse(assembler_source).body if isinstance(n,ast.FunctionDef) and n.name=='asm_arcade_cab')
namespace={};exec(compile(ast.Module(body=[function],type_ignores=[]),str(assembler_path),'exec'),namespace)
class HullCollector:
 def __init__(self):self.hulls=[]
 def box(self,*args):pass
 def cyl(self,*args):pass
 def hull(self,*args):self.hulls.append(args)
collector=HullCollector();namespace['asm_arcade_cab'](collector,receiver);assert len(collector.hulls)==1
q=collector.hulls[0];angle=math.radians(receiver['yaw']);c=math.cos(angle);sn=math.sin(angle)
corners=[(receiver['at'][0]+c*x-sn*y,receiver['at'][1]+sn*x+c*y,z+receiver.get('z0',0.)) for x in [q[0],q[3]] for y in [q[1],q[4]] for z in [q[2],q[5]]]
hull_low=[min(p[i] for p in corners) for i in range(3)];hull_high=[max(p[i] for p in corners) for i in range(3)]
hull_name=next(n['name'] for n in source_gltf['nodes'] if n['name'].endswith('_hull-colonly'))
pad_right=hull_low[0]-float(plan['receiving_clearance']['clearance_m']);table_right=pad_right-float(plan['receiving_clearance']['pad_overhang_m'])
receiver_clearance={'source_record':receiver,'raw_hull_name':hull_name,'hull_name':hull_name.removesuffix('-colonly'),'hull_low_b':hull_low,'hull_high_b':hull_high,'clearance_m':plan['receiving_clearance']['clearance_m'],'pad_overhang_m':plan['receiving_clearance']['pad_overhang_m'],'table_right_x':table_right,'pad_right_x':pad_right,'source_table_length_m':rows['storm_shop_model_laundry_iron_table']['rect'][2]-rows['storm_shop_model_laundry_iron_table']['rect'][0],'fitted_table_length_m':table_right-rows['storm_shop_model_laundry_iron_table']['rect'][0],'assembler_function_sha256':hashlib.sha256(ast.get_source_segment(assembler_source,function).encode()).hexdigest()}
assert abs(hull_low[0]-7.21)<1e-10 and abs(table_right-7.14)<1e-10 and abs(pad_right-7.18)<1e-10

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
  image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True);image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
  if index:image.colorspace_settings.name='Non-Color'
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.links.new(scale.outputs['Vector'],tex.inputs['Vector'])
  if index==2:
   normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=spec['normal_scale'];mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs[0],node.inputs[target])
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
def lathe(name,center,profile,identity,key,segments=None):
 n=segments or 24;verts=[]
 for z,rx,ry in profile:verts.extend((center[0]+rx*math.cos(i*math.tau/n),center[1]+ry*math.sin(i*math.tau/n),z) for i in range(n))
 faces=[tuple(reversed(range(n)))]
 for ring in range(len(profile)-1):
  for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
 faces.append(tuple(range((len(profile)-1)*n,len(profile)*n)))
 return solid(name,verts,faces,identity,key)
def rod(name,a,b,r,identity,key='timber'):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();seed=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(seed).normalized();v=axis.cross(u);n=16
 verts=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
 return solid(name,verts,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],identity,key)
def torus(name,center,rx,ry,r,identity,key):
 n=32;m=8;verts=[]
 for i in range(n):
  angle=i*math.tau/n;normal=Vector((math.cos(angle)/rx,math.sin(angle)/ry,0)).normalized();at=Vector(center)+Vector((rx*math.cos(angle),ry*math.sin(angle),0))
  verts.extend(at+r*(normal*math.cos(j*math.tau/m)+Vector((0,0,math.sin(j*math.tau/m)))) for j in range(m))
 faces=[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)]
 return solid(name,verts,faces,identity,key)
def support(identity,owner,point,direction,label):
 contacts.append({'assembly':identity,'owner':owner,'point':[point[0],point[2],-point[1]],'direction':[direction[0],direction[2],-direction[1]],'label':label})
def ribbon(name,path,width,thickness,identity,key='linen'):
 # Closed band follows a complete parcel perimeter. Its corners are curved
 # by the piecewise path, so it never becomes an open decal or a label.
 points=[Vector(p) for p in path];verts=[]
 for i,p in enumerate(points):
  tangent=(points[(i+1)%len(points)]-points[(i-1)%len(points)]).normalized()
  side=Vector((0,1,0)) if abs(tangent.y)<.8 else Vector((1,0,0))
  normal=tangent.cross(side).normalized();side=normal.cross(tangent)
  verts.extend(p+side*a*width*.5+normal*b*thickness*.5 for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)])
 faces=[(i*4+j,((i+1)%len(points))*4+j,((i+1)%len(points))*4+(j+1)%4,i*4+(j+1)%4) for i in range(len(points)) for j in range(4)]
 return solid(name,verts,faces,identity,key)
def cloth_panel(name,outline,cx,cy,cz,depth,identity,key='linen',phase=0):
 # Closed front/back garment shell. Deterministic shallow folds are visible
 # in silhouette and lighting; material charts retain their physical scale.
 vertices=[]
 for side in [-1,1]:
  for y,z in outline:
   fold=.0018*math.sin(y*71+phase)*(.45+.55*math.sin(z*8)**2)
   vertices.append((cx+side*depth*.5+fold,cy+y,cz+z))
 n=len(outline);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
 faces.extend((i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n))
 obj=solid(name,vertices,faces,identity,key)
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Soft cloth edge','BEVEL');mod.width=min(.001,depth*.20);mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj
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
for item in assemblies:
 identity=item['id'];row=item['body'];x0,y0,x1,y1=row['rect'];x=(x0+x1)*.5;y=(y0+y1)*.5;z=float(row['z0']);top=z+float(row['h']);kind=item['kind']
 if kind in ['iron_table','iron_pad']:
  fitted=table_right if kind=='iron_table' else pad_right;assert x0<fitted<x1
  x1=fitted;x=(x0+x1)*.5
  if kind=='iron_pad':y0+=.030;y=(y0+y1)*.5
 if kind=='parcel':
  shelf=rows['storm_shop_model_laundry_parcel_shelf'+identity.split('_parcel')[1].split('_')[0]];bottom=shelf['z0']+shelf['h']
  box(identity+'_WrappedBundle',(x0,y0,bottom),(x1,y1,top),identity,row['mat'],.018)
  # Distinct end folds and two small closed string loops read as a parcel,
  # while keeping the source's generous gaps between individual bundles.
  for end in [-1,1]:
   yy=y0+.001 if end<0 else y1-.001
   box(identity+f'_FoldSeam{end}',(x0+.012,yy-.001,z+.024),(x1-.012,yy+.001,z+.027),identity,row['mat'],.0004)
  for yy in [y-.115,y+.115]:
   rr=.012;path=[]
   # Seat the underside of the 1.2mm-radius tie on the shelf, not its centreline.
   for cx,cz,start in [(x1-rr,top-rr,0),(x0+rr,top-rr,90),(x0+rr,bottom+rr+.0012,180),(x1-rr,bottom+rr+.0012,270)]:
    for angle in range(start,start+91,15):a=math.radians(angle);path.append((cx+rr*math.cos(a),yy,cz+rr*math.sin(a)))
   curved_wire(identity+f'_String{yy:.3f}',path+[path[0]],.0012,identity,'linen')
  support(identity,shelf['id'],(x,y,bottom),(0,0,1),'parcel shelf bearing')
 elif kind=='shirt':
  h=top-z;w=y1-y0
  # Laundered long sleeves fold inward rather than spreading past the
  # original 32-centimetre merchandising bay. Hem and placket are stocks.
  outline=[(-w*.40,0),(-w*.46,.022),(-w*.45,h*.69),(-w*.5,h*.78),(-w*.46,h*.94),(-w*.19,h),(-w*.13,h*.97),(w*.13,h*.97),(w*.19,h),(w*.46,h*.94),(w*.5,h*.78),(w*.45,h*.69),(w*.46,.022),(w*.40,0)]
  cloth_panel(identity+'_PressedShirt',outline,x,y,z,.012,identity,phase=int(identity.rsplit('shirt',1)[1]))
  for side in [-1,1]:
   sleeve=[(side*w*.16,.13),(side*w*.43,.20),(side*w*.43,h*.89),(side*w*.30,h*.93)]
   cloth_panel(identity+f'_FoldedSleeve{side}',sleeve,x+.007,y,z,.006,identity)
   box(identity+f'_Cuff{side}',(x+.007,y+min(v[0] for v in sleeve),z+.13),(x+.015,y+max(v[0] for v in sleeve),z+.16),identity,'linen',.001)
  box(identity+'_ButtonPlacket',(x+.002,y-.009,z+.025),(x+.013,y+.009,top-.05),identity,'linen',.002)
  for n in range(5):
   yy=y;zz=z+.16+n*.115;rod(identity+f'_Button{n}',(x+.012,yy,zz),(x+.016,yy,zz),.004,identity,'linen')
  for side in [-1,1]:
   cloth_panel(identity+f'_Collar{side}',[(0,h-.028),(side*.047,h-.002),(side*.043,h-.066)],x+.008,y,z,.005,identity)
  rod(identity+'_HangerBar',(x,y-.14,top-.057),(x,y+.14,top-.057),.004,identity,'timber')
  for side in [-1,1]:rod(identity+f'_HangerShoulder{side}',(x,y+side*.14,top-.057),(x,y,top+.013),.006,identity,'timber')
  hook=[(x,y,top+.008),(x,y,2.054)]
  rail=rows['storm_shop_model_laundry_rail'];rx=(rail['rect'][0]+rail['rect'][2])*.5
  for deg in range(180,-46,-15):a=math.radians(deg);hook.append((rx+.0215*math.cos(a),y,2.07+.0215*math.sin(a)))
  curved_wire(identity+'_HangerHook',hook,.0022,identity)
  support(identity,'storm_shop_model_laundry_rail',(rx-.02,y,2.07),(-1,0,0),'hanger wraps tubular rail')
 elif kind=='rail':
  rod(identity+'_RoundRail',(x,y0,2.07),(x,y1,2.07),.02,identity,'chrome')
  for i,yy in enumerate([y0+.035,y1-.035]):
   rod(identity+f'_Suspension{i}',(x,yy,2.065),(x,yy,ceil['z0']-.007),.006,identity,'chrome')
   box(identity+f'_CeilingPlate{i}',(x-.035,yy-.035,ceil['z0']-.008),(x+.035,yy+.035,ceil['z0']),identity,'chrome',.002)
   support(identity,ceil['id'],(x,yy,ceil['z0']),(0,0,-1),'ceiling suspension plate')
 elif kind=='iron_table':
  pad=rows['storm_shop_model_laundry_iron_pad'];under=top-.045
  box(identity+'_TableTop',(x0,y0,under),(x1,y1,pad['z0']),identity,'timber',.007)
  for i,(xx,yy) in enumerate([(x0+.09,y0+.09),(x1-.09,y0+.09),(x0+.09,y1-.09),(x1-.09,y1-.09)]):
   box(identity+f'_Leg{i}',(xx-.029,yy-.029,floor['z0']+floor['h']),(xx+.029,yy+.029,under+.004),identity,'timber',.004)
   support(identity,floor['id'],(xx,yy,.01),(0,0,1),'ironing table foot')
  for yy in [y0+.09,y1-.09]:box(identity+f'_LongApron{yy:.3f}',(x0+.06,yy-.012,under-.11),(x1-.06,yy+.012,under+.002),identity,'timber',.003)
  for xx in [x0+.09,x1-.09]:box(identity+f'_EndApron{xx:.3f}',(xx-.012,y0+.06,under-.11),(xx+.012,y1-.06,under+.002),identity,'timber',.003)
 elif kind=='iron_pad':
  box(identity+'_PaddedTop',(x0,y0,z),(x1,y1,top),identity,'linen',.025)
  support(identity,'storm_shop_model_laundry_iron_table',(x,y,z),(0,0,1),'padded top on timber table')
 elif kind=='sleeve_board':
  # A small rounded sleeve form, carried by its cantilever tongue on the
  # large pad. The tongue bridges the source's 20-mm gap between envelopes.
  box(identity+'_SleeveForm',(x0,y0,z),(x1,y1,top),identity,'linen',.022)
  pad=rows['storm_shop_model_laundry_iron_pad'];pz=pad['z0']+pad['h']
  box(identity+'_CantileverTongue',(x0+.08,pad['rect'][3]-.11,z+.01),(x0+.30,y1-.035,z+.028),identity,'timber',.004)
  # Tongue embeds in the pad edge; no open or free-floating support stock.
  support(identity,'storm_shop_model_laundry_iron_pad',(x0+.18,pad['rect'][3],z+.013),(0,1,0),'sleeve board tongue enters pad')
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
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/laundry_fittings.blend'))
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
asset=ROOT/'game/assets/props/laundry_fittings.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in [item['body']]:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':p['key'],'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan['catalog_variants'] else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/laundry_fittings.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(ROOT/'game/data/orison_v2/laundry_fittings.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,assembler_path,Path(__file__),Path(__file__).with_name('inspect_laundry_fittings.py'),Path(__file__).with_name('fabrication_uvs.py'),ROOT/'game/data/runtime_material_sets.json',ROOT/'game/scripts/generated/material_sets.gd',asset.with_suffix('.glb.import'),*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
report={'evidence_class':'INERT','classification':'ADAPTATION','fitted_receiver_clearance':receiver_clearance,'original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/laundry_fittings_construction.json','game/tests/fixtures/orison_laundry_fittings.json']:(ROOT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('LAUNDRY FITTINGS',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
