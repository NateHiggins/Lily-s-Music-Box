"""Source-fitted shop chairs, chapel benches and soda-counter stools."""
from pathlib import Path
import collections,hashlib,json,math,re,sys
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from fabrication_uvs import chart_for_triangle
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan_path=ROOT/'art/data/shop_seating/source_plan.json';layout_path=ROOT/'art/data/building_layout.json'
plan=json.loads(plan_path.read_text());layout=json.loads(layout_path.read_text())
assert plan['classification']=='ADAPTATION'
floor=next(r for r in layout['floors'] if r['id']=='F01');rows={r['id']:r for r in floor['furniture']}
# Reuse the shipping shop variants, including oxblood vinyl, which is an
# existing glTF catalogue material rather than a MatLib runtime alias.
source_gltf_path=ROOT/'game/assets/building/floor_01_cells/shop_otis_son.gltf'
source_gltf=json.loads(source_gltf_path.read_text());sets={};material_definitions=[]
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
for key in plan['runtime_keys']:
 if key in plan.get('catalog_variants',{}):
  # Dossier slice 64: registered catalogue finishes (no shipping variant in the source cells).
  spec=catalog[plan['catalog_variants'][key]];definition=ROOT/f'art/textures/{spec["catalog_mapping"]}/material.json';material_definitions.append(definition)
  sets[key]={'files':spec['files'],'meters_per_tile':spec['meters_per_tile'],'metallic':spec['metallic'],'normal_scale':.35};continue
 definition=ROOT/f'art/textures/ai_materials/{key}_b/material.json';material_definitions.append(definition)
 shipping=next(m for m in source_gltf['materials'] if m['name']=='M_'+key+'_b')
 pbr=shipping['pbrMetallicRoughness'];files=[]
 for texture in [pbr['baseColorTexture'],pbr['metallicRoughnessTexture'],shipping['normalTexture']]:
  image=source_gltf['images'][source_gltf['textures'][texture['index']]['source']]
  files.append(Path(image['uri']).name)
 sets[key]={'files':files,'meters_per_tile':json.loads(definition.read_text())['meters_per_tile'],'metallic':pbr.get('metallicFactor',1),'normal_scale':shipping['normalTexture'].get('scale',1)}
def digest(path):
 data=path.read_bytes();return hashlib.sha256(data if path.suffix in ['.blend','.glb','.png'] else data.replace(b'\r\n',b'\n')).hexdigest()
def cell_for(row):return 'shop_otis_son' if row['batch']=='shop_otis___son' else row['batch']
selected=[];assemblies=[]
for identity,row in rows.items():
 if re.fullmatch(r'storm_shop_funeral_parlour_chair\d+_\d+',identity):
  back=rows[identity.replace('_chair','_chairb')];assemblies.append({'id':identity,'kind':'chair','body':row,'back':back,'floor':rows['storm_shop_funeral_parlour_floor']})
 elif re.fullmatch(r'storm_shop_(otis___son|luncheonette)_stool\d+',identity):
  top=rows[identity+'_top'];assemblies.append({'id':identity,'kind':'stool','body':row,'top':top,'floor':rows['storm_'+row['batch']+'_floor']})
 elif re.fullmatch(r'site_rear_funeral_parlour_chapel_pew\d+',identity):
  back=rows[identity.replace('_pew','_pewback')];assemblies.append({'id':identity,'kind':'pew','body':row,'back':back,'floor':rows['site_rear_funeral_parlour_floor']})
for item in assemblies:
 selected.extend([item['body'],item.get('top',item.get('back'))]);item['cell']=cell_for(item['body'])
assert len(selected)==plan['original_records'] and len(assemblies)==plan['assemblies']
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
def box(name,low,high,identity,key='wood_dark',bevel=.003,collection=closed):
 verts=[(x,y,z) for z in [low[2],high[2]] for y in [low[1],high[1]] for x in [low[0],high[0]]]
 obj=solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],identity,key,collection)
 if bevel:
  bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Worked edge','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj
def lathe(name,center,profile,identity,key,segments=None):
 n=segments or plan['segments'];verts=[]
 for z,rx,ry in profile:verts.extend((center[0]+rx*math.cos(i*math.tau/n),center[1]+ry*math.sin(i*math.tau/n),z) for i in range(n))
 faces=[tuple(reversed(range(n)))]
 for ring in range(len(profile)-1):
  for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
 faces.append(tuple(range((len(profile)-1)*n,len(profile)*n)))
 return solid(name,verts,faces,identity,key)
def rod(name,a,b,r,identity,key='wood_dark'):
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
def foot(identity,owner,x,y,z,r=.015):contacts.append({'assembly':identity,'floor_owner':owner,'point':[x,z,-y],'footprint':[[x+dx,z,-y+dz] for dx,dz in [(r,0),(-r,0),(0,r),(0,-r)]]})
for item in assemblies:
 identity=item['id'];body=item['body'];rect=body['rect'];x0,y0,x1,y1=rect;x=(x0+x1)*.5;y=(y0+y1)*.5
 floor_z=float(item['floor']['z0'])+float(item['floor']['h']);seat_z=float(body['z0'])+float(body['h']);item['floor_z']=floor_z
 if item['kind']=='stool':
  top=item['top'];tr=top['rect'];rx=(tr[2]-tr[0])*.5;ry=(tr[3]-tr[1])*.5;bottom=float(top['z0']);height=float(top['h']);base_r=min(x1-x0,y1-y0)*.48
  lathe(identity+'_BellBase',(x,y),[(floor_z,base_r,base_r),(floor_z+.009,base_r,base_r),(floor_z+.026,base_r*.82,base_r*.82),(floor_z+.065,.042,.042),(floor_z+.105,.032,.032)],identity,'chrome')
  lathe(identity+'_Column',(x,y),[(floor_z+.098,.027,.027),(bottom-.025,.027,.027),(bottom-.005,.045,.045)],identity,'chrome')
  ring_r=base_r-.012;ring_z=floor_z+.255;torus(identity+'_FootRing',(x,y,ring_z),ring_r,ring_r,.006,identity,'chrome')
  for n in range(4):
   angle=n*math.tau/4;rod(identity+f'_FootSpoke{n}',(x+.026*math.cos(angle),y+.026*math.sin(angle),ring_z),(x+(ring_r-.005)*math.cos(angle),y+(ring_r-.005)*math.sin(angle),ring_z),.006,identity,'chrome')
  lathe(identity+'_SeatPan',(x,y),[(bottom-.012,rx*.77,ry*.77),(bottom,rx*.98,ry*.98),(bottom+.008,rx*.98,ry*.98)],identity,'chrome')
  lathe(identity+'_Cushion',(x,y),[(bottom+.006,rx*.96,ry*.96),(bottom+.022,rx,ry),(bottom+height*.76,rx*.975,ry*.975),(bottom+height,rx*.81,ry*.81)],identity,'vinyl_oxblood')
  torus(identity+'_Welt',(x,y,bottom+.022),rx-.0035,ry-.0035,.0035,identity,'vinyl_oxblood');foot(identity,item['floor']['id'],x,y,floor_z,base_r*.75)
  if identity=='storm_shop_luncheonette_stool2':
   # Dossier slice 64 (CITY_SHOP_LUNCHEONETTE-002): the third stool's vinyl worn through on top to the cord.
   lathe(identity+'_WornCord',(x,y),[(bottom+height-.004,rx*.42,ry*.42),(bottom+height+.0015,rx*.40,ry*.40)],identity,'cord')
   torus(identity+'_TornEdge',(x,y,bottom+height+.0004),rx*.42,ry*.42,.0024,identity,'vinyl_oxblood')
 else:
  back=item['back'];br=back['rect'];back_top=float(back['z0'])+float(back['h']);seat_thickness=.045 if item['kind']=='chair' else .055;under=seat_z-seat_thickness
  box(identity+'_Seat',(x0,y0,under),(x1,y1,seat_z),identity,bevel=.009)
  leg_dx=(x1-x0)*(.36 if item['kind']=='pew' else .38);leg_dy=(y1-y0)*.36
  for n,(lx,ly) in enumerate([(x-leg_dx,y-leg_dy),(x+leg_dx,y-leg_dy),(x-leg_dx,y+leg_dy),(x+leg_dx,y+leg_dy)]):
   lathe(identity+f'_Leg{n}',(lx,ly),[(floor_z,.016,.016),(floor_z+.035,.019,.019),(floor_z+.085,.021,.021),(under-.06,.016,.016),(under-.025,.023,.023),(under+.002,.024,.024)],identity,'wood_dark',16);foot(identity,item['floor']['id'],lx,ly,floor_z,.013)
  rod(identity+'_FrontStretcher',(x-leg_dx,y-leg_dy,floor_z+.17),(x+leg_dx,y-leg_dy,floor_z+.17),.012,identity)
  rod(identity+'_RearStretcher',(x-leg_dx,y+leg_dy,floor_z+.17),(x+leg_dx,y+leg_dy,floor_z+.17),.012,identity)
  for side in [-1,1]:rod(identity+f'_SideStretcher{side}',(x+side*leg_dx,y-leg_dy,floor_z+.18),(x+side*leg_dx,y+leg_dy,floor_z+.18),.012,identity)
  bx=(br[0]+br[2])*.5;by=(br[1]+br[3])*.5
  if item['kind']=='chair':
   box(identity+'_Crest',(br[0],y0,back_top-.075),(br[2],y1,back_top),identity,bevel=.009)
   for n,py in enumerate([y-leg_dy,y+leg_dy]):rod(identity+f'_BackPost{n}',(bx,py,under),(bx,py,back_top-.035),.022,identity)
   for n in range(4):rod(identity+f'_BackSpindle{n}',(bx,y0+.075+n*(y1-y0-.15)/3,seat_z-.015),(bx,y0+.075+n*(y1-y0-.15)/3,back_top-.063),.009,identity)
  else:
   box(identity+'_Crest',(x0,br[1],back_top-.065),(x1,br[3],back_top),identity,bevel=.007)
   for n,px in enumerate([x-leg_dx,x+leg_dx]):rod(identity+f'_BackPost{n}',(px,by,under),(px,by,back_top-.032),.025,identity)
   for n in range(8):rod(identity+f'_BackSpindle{n}',(x0+.08+n*(x1-x0-.16)/7,by,seat_z-.015),(x0+.08+n*(x1-x0-.16)/7,by,back_top-.055),.012,identity)
# Dossier slice 64 (CITY_SHOP_FUNERAL_PARLOUR-004): the rows stay as arranged, but two chairs sit a few degrees
# off their marks and one in the back row is pulled back where someone stood up.
TURNS={'storm_shop_funeral_parlour_chair1_2':(math.radians(4),0.,0.),'storm_shop_funeral_parlour_chair2_1':(math.radians(-6),0.,0.),
       'storm_shop_funeral_parlour_chair3_3':(math.radians(10),.22,0.)}
for item in assemblies:
 if item['id'] not in TURNS:continue
 identity=item['id'];x0,y0,x1,y1=item['body']['rect'];x=(x0+x1)*.5;y=(y0+y1)*.5;ang,dx,dy=TURNS[identity];ca,sa=math.cos(ang),math.sin(ang)
 def move(px,py):qx=px-x;qy=py-y;return x+dx+ca*qx-sa*qy,y+dy+sa*qx+ca*qy
 for obj,_ in pieces[identity]:
  for v in obj.data.vertices:
   wx,wy=move(obj.location.x+v.co.x,obj.location.y+v.co.y);v.co.x=wx-obj.location.x;v.co.y=wy-obj.location.y
  obj.data.update()
 for c in contacts:
  if c['assembly']!=identity:continue
  px,py=move(c['point'][0],-c['point'][2]);c['point']=[px,c['point'][1],-py]
  c['footprint']=[[mx,q[1],-my] for q in c['footprint'] for mx,my in [move(q[0],-q[2])]]
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
 identity=item['id'];keys=sorted({key for obj,key in pieces[identity]});rect=item['body']['rect'];origin=np.array(((rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,item['floor_z']))
 for key in keys:
  vertices=[];faces=[]
  for obj,material_key in pieces[identity]:
   if material_key!=key:continue
   offset=len(vertices);vertices.extend(tuple(obj.location+v.co) for v in obj.data.vertices);faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
  name=identity+'__'+key;mesh=bpy.data.meshes.new(name);mesh.from_pydata([tuple(np.asarray(p)-origin) for p in vertices],[],faces);mesh.update();mesh.materials.append(materials[key])
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  uv=mesh.uv_layers.new(name='Metres');uv.active_render=True;guides=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');normals=[None]*len(mesh.loops)
  for face in mesh.polygons:
   points=np.asarray([mesh.vertices[i].co[:] for i in face.vertices],dtype=np.float64);n,u,values,local=chart_for_triangle(points,origin,sets[key]['meters_per_tile'],key=='wood_dark');fallbacks+=local
   for j,loop in enumerate(face.loop_indices):uv.data[loop].uv=tuple(values[j]);guides.data[loop].vector=(float(u[0]),float(u[2]),float(-u[1]));normals[loop]=tuple(n)
  mesh.normals_split_custom_set(normals);obj=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=origin;draws.append(obj)
  mesh.calc_loop_triangles();total_triangles+=len(mesh.loop_triangles);inventory.append({'name':name,'assembly':identity,'cell':item['cell'],'key':key,'triangles':len(mesh.loop_triangles)})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/shop_seating.blend'))
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
asset=ROOT/'game/assets/props/shop_seating.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='NONE')
assert ExportUVHandedness.corrected==len(draws)
cells=[]
for identity in sorted({a['cell'] for a in assemblies}):
 items=[a for a in assemblies if a['cell']==identity];replace=[]
 for item in items:
  for row in [item['body'],item.get('top',item.get('back'))]:
   x0,y0,x1,y1=row['rect'];z0=row['z0'];replace.append({'id':row['id'],'key':row['mat'],'low':[x0,z0,-y1],'high':[x1,z0+row['h'],-y0],'expected_triangles':12})
 cells.append({'id':identity,'parts':[{'name':p['name'],'key':p['key'],'tile':sets[p['key']]['meters_per_tile'],**({'catalog_key':plan['catalog_variants'][p['key']]} if p['key'] in plan.get('catalog_variants',{}) else {}),**({'tint':plan['material_tints'][p['key']]} if p['key'] in plan.get('material_tints',{}) else {})} for p in inventory if p['cell']==identity],'replace':replace})
runtime={'schema_version':1,'asset':'res://assets/props/shop_seating.glb','tolerance':plan['trim_tolerance_m'],'cells':cells}
(ROOT/'game/data/orison_v2/shop_seating.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[plan_path,layout_path,Path(__file__),Path(__file__).with_name('fabrication_uvs.py'),ROOT/'game/data/runtime_material_sets.json',asset.with_suffix('.glb.import'),*material_definitions]
for key in plan['runtime_keys']:bindings.extend(ROOT/'game/assets/building/textures'/f for f in sets[key]['files'])
bindings.extend(ROOT/f'game/assets/building/floor_01_cells/{identity}.{suffix}' for identity in sorted({a['cell'] for a in assemblies}) for suffix in ['gltf','bin'])
report={'evidence_class':'INERT','classification':'ADAPTATION','original_records':selected,'assemblies':[{'id':a['id'],'kind':a['kind'],'cell':a['cell'],'floor':a['floor']} for a in assemblies],'closed_stocks':stock_checks,'contacts':contacts,'parts':inventory,'triangles':total_triangles,'precision_chart_fallbacks':fallbacks,'runtime':runtime,'asset_sha256':digest(asset),'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings},'open_work':plan['open_work']}
for name in ['art/blender/shop_seating_construction.json','game/tests/fixtures/orison_shop_seating.json']:(ROOT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SHOP SEATING',len(selected),'original records;',len(assemblies),'assemblies;',len(stock_checks),'closed stocks;',len(draws),'parts;',total_triangles,'triangles;',len(contacts),'foot contacts')
