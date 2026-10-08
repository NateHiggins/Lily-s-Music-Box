"""Authorized five fixed supply leads and fitted floor receptacles; visual ownership only."""
from pathlib import Path
import bpy,bmesh,json,hashlib,math,sys,collections,os
import numpy as np
from mathutils import Vector,Matrix
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_chart_batch import triangle_charts
from fabrication_grain import stock_grain_frame
from fabrication_normals import stock_corner_normals
PLAN=ROOT/'art/data/task_lamp_supply/source_plan.json'
plan=json.loads(PLAN.read_text());catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
def digest(p):
 b=p.read_bytes();return hashlib.sha256(b if p.suffix in ['.glb','.blend','.png'] else b.replace(b'\r\n',b'\n')).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
stock=bpy.data.collections.new('Closed construction');bpy.context.scene.collection.children.link(stock);stock.hide_render=True
exports=bpy.data.collections.new('Runtime partitions');bpy.context.scene.collection.children.link(exports);exports.hide_render=True
review=bpy.data.collections.new('Composed review');bpy.context.scene.collection.children.link(review)
mats={};specs={};pieces=[];records=[];checks=[];current=None
def material(key,source=None):
 if key in mats:return mats[key]
 mat=bpy.data.materials.new(key);mat.use_nodes=True;node=mat.node_tree.nodes['Principled BSDF']
 if source is not None:
  color=source.get('color',[.3,.3,.3,1]);node.inputs['Base Color'].default_value=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in color[:3]]+[color[3]]
  node.inputs['Metallic'].default_value=source.get('metallic',0);node.inputs['Roughness'].default_value=source.get('roughness',.6)
  if color[3]<1:node.inputs['Alpha'].default_value=color[3];mat.surface_render_method='DITHERED'
  specs[key]={'source':True}
 else:
  spec=catalog[key];specs[key]={'catalog':key,'tile':spec['meters_per_tile'],'normal':.035 if key in ['wood_dark','timber','bakelite','cast_iron','paper'] else .12,'roughness':spec['roughness_multiplier']}
  specs[key]['metallic']=0. if key=='cast_iron' else spec['metallic']
  specs[key]['tint']=[.30,.28,.25,1.] if key=='cast_iron' else [.55,.53,.50,1.] if key=='wood_dark' else [1.,1.,1.,1.]
  if key=='linen':specs[key].update(tint=[.32,.26,.20,1.],tile=.16,normal=.14,roughness=.84)
  if key=='porcelain':specs[key].update(normal=.025,roughness=.35)
  node.inputs['Metallic'].default_value=specs[key]['metallic']
  coord=mat.node_tree.nodes.new('ShaderNodeTexCoord');scale=mat.node_tree.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/specs[key]['tile'];mat.node_tree.links.new(coord.outputs['UV'],scale.inputs[0])
  for i,target in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
   im=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
   im.filepath=bpy.path.relpath(im.filepath,start=str(ROOT/'art/blender'))
   if i:im.colorspace_settings.name='Non-Color'
   tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;mat.node_tree.links.new(scale.outputs[0],tex.inputs[0])
   if i==2:
    n=mat.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=specs[key]['normal'];mat.node_tree.links.new(tex.outputs[0],n.inputs['Color']);mat.node_tree.links.new(n.outputs[0],node.inputs[target])
   elif i==1:
    n=mat.node_tree.nodes.new('ShaderNodeMath');n.operation='MULTIPLY';n.inputs[1].default_value=specs[key]['roughness'];mat.node_tree.links.new(tex.outputs[0],n.inputs[0]);mat.node_tree.links.new(n.outputs[0],node.inputs[target])
   else:
    n=mat.node_tree.nodes.new('ShaderNodeMixRGB');n.blend_type='MULTIPLY';n.inputs[0].default_value=1.
    n.inputs[2].default_value=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in specs[key]['tint'][:3]]+[1.]
    mat.node_tree.links.new(tex.outputs[0],n.inputs[1]);mat.node_tree.links.new(n.outputs[0],node.inputs[target])
 mats[key]=mat;return mat

def solid(name,verts,faces,key,bevel=0):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([C.to_3x3()@Vector(v) for v in verts],[],faces);mesh.update()
 obj=bpy.data.objects.new(current+'__'+name,mesh);stock.objects.link(obj);mesh.materials.append(material(key))
 bpy.context.view_layer.objects.active=obj
 if bevel:
  mod=obj.modifiers.new('Worked arris','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),(current,name,'open stock')
 volume=bm.calc_volume(signed=True);assert volume>1e-13,(current,name,volume)
 bm.to_mesh(mesh);bm.free();pieces.append((obj,key));checks.append({'name':obj.name,'volume_m3':volume})
 return obj

def box(name,size,at,key,bevel=.001):
 low=Vector(at)-Vector(size)*.5;high=Vector(at)+Vector(size)*.5
 return solid(name,[(x,y,z) for z in [low.z,high.z] for y in [low.y,high.y] for x in [low.x,high.x]],[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,min(bevel,min(size)*.22))

def tube(name,radius,inside,depth,at,key,axis='z',n=48):
 # Annular, closed sheet: an actual opening rather than a painted black disc.
 verts=[]
 for z,r in [(-depth/2,radius),(depth/2,radius),(depth/2,inside),(-depth/2,inside)]:
  for i in range(n):
   x,y=r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n)
   p=Vector((x,y,z) if axis=='z' else (x,z,y));verts.append(p+Vector(at))
 faces=[(j*n+i,j*n+(i+1)%n,((j+1)%4)*n+(i+1)%n,((j+1)%4)*n+i) for j in range(4) for i in range(n)]
 return solid(name,verts,faces,key,.00015)

def rod(name,radius,depth,at,key,axis='z',top=None,n=40):
 verts=[]
 for z,r in [(-depth/2,radius),(depth/2,radius if top is None else top)]:
  for i in range(n):
   x,y=r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n);verts.append(Vector((x,y,z) if axis=='z' else (x,z,y))+Vector(at))
 return solid(name,verts,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],key,min(.0006,depth*.1,radius*.1))

def frame(name,w,h,depth,rail,at,key):
 x,y,z=at
 for side in [-1,1]:box(name+' stile'+str(side),(rail,h,depth),(x+side*(w-rail)/2,y,z),key)
 for side in [-1,1]:box(name+' rail'+str(side),(w-2*rail,rail,depth),(x,y+side*(h-rail)/2,z),key)

def screw(name,at,key='brass',radius=.003):
 obj=rod(name,radius,.002,at,key,n=24)
 # Real slot recess, cut before export. No painted screws or raised dark lines.
 bpy.ops.mesh.primitive_cube_add(size=1,location=C.to_3x3()@(Vector(at)+Vector((0,0,.001))))
 cutter=bpy.context.object;cutter.dimensions=(radius*2.4,.0015,radius*.38)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Slotted drive','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)

def fasteners(w,h,z,y=0,key='brass'):
 for x in [-w/2,w/2]:
  for yy in [y-h/2,y+h/2]:screw('Service screw',(x,yy,z),key)

def source_blank(part,key):
 if part['type']=='BoxMesh':return box('Stock',part['size'],(0,0,0),key)
 if part['type']=='CylinderMesh':return rod('Turned stock',part['bottom_radius'],part['height'],(0,0,0),key,'y',part['top_radius'])
 if part['type']=='TorusMesh':return torus('Retained annular stock',(part['inner_radius']+part['outer_radius'])*.5,(part['outer_radius']-part['inner_radius'])*.5,key)
 raise AssertionError(part['type'])

def torus(name,major,minor,key):
 n=64;m=12;verts=[((major+minor*math.cos(j*math.tau/m))*math.cos(i*math.tau/n),minor*math.sin(j*math.tau/m),(major+minor*math.cos(j*math.tau/m))*math.sin(i*math.tau/n)) for i in range(n) for j in range(m)]
 return solid(name,verts,[(i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m) for i in range(n) for j in range(m)],key)

def ellipsoid(name,radii,key):
 n=48;m=24;verts=[(0,radii[1],0)]
 for j in range(1,m):
  a=math.pi*j/m
  verts.extend((radii[0]*math.sin(a)*math.cos(i*math.tau/n),radii[1]*math.cos(a),radii[2]*math.sin(a)*math.sin(i*math.tau/n)) for i in range(n))
 verts.append((0,-radii[1],0));last=len(verts)-1
 faces=[(0,1+i,1+(i+1)%n) for i in range(n)]+[(last,1+(m-2)*n+(i+1)%n,1+(m-2)*n+i) for i in range(n)]
 faces.extend((1+j*n+i,1+(j+1)*n+i,1+(j+1)*n+(i+1)%n,1+j*n+(i+1)%n) for j in range(m-2) for i in range(n))
 return solid(name,verts,faces,key)

def mesh_partition(name,items):
 # Each construction stock receives its own grain frame before joining.
 verts=[];faces=[];keys=[];frames=[]
 for obj,key in items:
  offset=len(verts);points=[v.co[:] for v in obj.data.vertices];verts.extend(points)
  grain=stock_grain_frame(points,catalog[key]['files'][0]) if key in catalog else None
  frames.extend([grain]*len(points));faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons);keys.extend([key]*len(obj.data.polygons))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 used=sorted(set(keys))
 for k in used:mesh.materials.append(mats[k])
 for p,k in zip(mesh.polygons,keys):p.material_index=used.index(k)
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 uv=mesh.uv_layers.new(name='Metres');guide=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
 coords=np.array([v.co[:] for v in mesh.vertices]);indices=np.array([l.vertex_index for l in mesh.loops]).reshape((-1,3));f=[frames[i] for i in indices[:,0]]
 rotations=np.stack([x[0] if x is not None else np.eye(3) for x in f]);grain=np.array([x is not None and x[1]==0 for x in f])
 ns,us,values,_=triangle_charts(coords[indices],np.zeros(3),1.,rotations,grain)
 uv.data.foreach_set('uv',values.astype(np.float32).ravel());g=np.repeat(us[:,[0,2,1]],3,axis=0);g[:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
 mesh.normals_split_custom_set(stock_corner_normals(mesh));obj=bpy.data.objects.new(name,mesh);exports.objects.link(obj)
 return obj,used

def pose_of(part):
 pose=Matrix.Identity(4)
 for i in range(3):
  for j in range(3):pose[j][i]=part['basis'][i][j]
 pose.translation=Vector(part['position']);return C@pose@C.inverted()

def rounded_path(knots):
 points=[Vector(knots[0])]
 for index in range(1,len(knots)-1):
  a,b,c=map(Vector,knots[index-1:index+2]);run=min(.022,(a-b).length*.25,(c-b).length*.25)
  before=b+(a-b).normalized()*run;after=b+(c-b).normalized()*run
  points.append(before)
  points.extend((1-t)**2*before+2*(1-t)*t*b+t*t*after for t in [j/8 for j in range(1,9)])
 points.append(Vector(knots[-1]));return points

def flex(name,points,radius):
 n=16;verts=[];lengths=[0.];previous=None;guide=None
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
  if previous is None:
   guide=tangent.cross(Vector((0,1,0)) if abs(tangent.y)<.9 else Vector((1,0,0))).normalized()
  else:
   guide=(guide-tangent*guide.dot(tangent)).normalized();lengths.append(lengths[-1]+(p-previous).length)
  v=tangent.cross(guide);verts.extend(p+radius*(guide*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n)) for j in range(n));previous=p
 faces=[tuple(reversed(range(n)))]+[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(points)-1) for j in range(n)]+[tuple(range((len(points)-1)*n,len(points)*n))]
 obj=solid(name,verts,faces,'linen');mesh=obj.data.copy();uv=mesh.uv_layers.new(name='Metres')
 for face in mesh.polygons:
  js=[v%n for v in face.vertices];rings={v//n for v in face.vertices};cap=len(rings)==1;seam=0 in js and n-1 in js
  for loop in face.loop_indices:
   index=mesh.loops[loop].vertex_index;j=index%n;i=index//n
   if cap:u,v=radius*math.cos(j*math.tau/n),radius*math.sin(j*math.tau/n)
   else:u,v=(n if seam and j==0 else j)*math.tau*radius/n,lengths[i]
   # Linen's registered fine weave follows the cord's length in a diagonal
   # crossing lay. No individual threads, custom shader or new material key.
   uv.data[loop].uv=((u+v)/math.sqrt(2),(v-u)/math.sqrt(2))
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 guide_attr=mesh.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER')
 for face in mesh.polygons:
  ids=list(face.loop_indices);p=[mesh.vertices[mesh.loops[i].vertex_index].co for i in ids];t=[uv.data[i].uv for i in ids]
  a,b=t[1]-t[0],t[2]-t[0];det=a.x*b.y-a.y*b.x;assert abs(det)>1e-12
  tangent=((p[1]-p[0])*b.y-(p[2]-p[0])*a.y)/det;tangent.normalize();g=(tangent.x,tangent.z,-tangent.y)
  for i in ids:guide_attr.data[i].vector=g
 mesh.normals_split_custom_set(stock_corner_normals(mesh));draw=bpy.data.objects.new(name,mesh);exports.objects.link(draw)
 return draw,lengths[-1]

def review_copy(obj,identity,offset=(0,0,0)):
 display=obj.copy();display.name=obj.name+'_'+identity+'_review';display.location=C.to_3x3()@Vector(offset);display['installation']=identity;review.objects.link(display)

current='SharedOutlet';start=len(pieces)
box('Cover plate',(.090,.0035,.065),(0,.00175,0),'brass',.003)
tube('Porcelain socket rim',.023,.0188,.006,(0,.005,0),'porcelain','y')
rod('Insulated socket well',.0188,.005,(0,.0025,0),'bakelite','y')
rod('Seated plug',.018,.026,(0,.021,0),'bakelite','y',top=.015,n=48)
tube('Plug strain relief',.0065,.0034,.011,(0,.0405,0),'rubber_aged','y')
for x in [-.007,.007]:box('Inserted contact blade',(.005,.012,.0014),(x,.006,0),'brass',.00015)
for x in [-.034,.034]:
 screw('Cover screw',(x,0,0),'brass')
 # screw() points along Z; fit its whole closed stock to the horizontal plate.
 obj=pieces[-1][0]
 origin=Vector((x,0,0));rot=Matrix.Rotation(-math.pi/2,4,'X')
 for v in obj.data.vertices:v.co=C.to_3x3()@(rot.to_3x3()@(C.inverted().to_3x3()@v.co-origin)+Vector((x,.004,0)))
outlet,used=mesh_partition('SupplyOutlet',pieces[start:]);outlet_record={'mesh':outlet.name,'materials':used}
routes=[]
for row in plan['installations']:
 current=row['id'];identity=row['id'];start=len(pieces)
 lamp_pose=Matrix.Translation(Vector(row['position']))@Matrix.Rotation(row['yaw'],4,'Y')
 direction=lamp_pose.to_3x3()@Vector(row['exit']);entry_local=Vector(row['exit'])*row['radius'];entry_local.y=row['entry_height']
 entry=lamp_pose@entry_local
 gland=tube('Base strain relief',.0065,.0034,.012,(0,0,0),'rubber_aged','y')
 rotate=Vector((0,1,0)).rotation_difference(direction).to_matrix()
 for v in gland.data.vertices:v.co=C.to_3x3()@(rotate@(C.inverted().to_3x3()@v.co)+entry)
 hardware,used=mesh_partition(identity+'_Entry',pieces[start:]);review_copy(hardware,identity)
 last=Vector(row['outlet'])+Vector((0,.043,0));knots=[entry+direction*.003,*map(Vector,row['waypoints']),last]
 points=rounded_path(knots);cord,length=flex(identity+'_ClothFlex',points,float(plan['cord_radius']));review_copy(cord,identity)
 review_copy(outlet,identity,row['outlet'])
 records.append({'id':identity,'support':row['support'],'parts':[{'mesh':hardware.name,'materials':used},{'mesh':cord.name,'materials':['linen']}],'outlet':row['outlet']})
 routes.append({'id':identity,'support':row['support'],'entry':list(entry),'direction':list(direction),'endpoint':list(last),'outlet':row['outlet'],'radius':plan['cord_radius'],'length':length,'centerline':[list(p) for p in points],'floor_owner':row['floor_owner']})

for obj in stock.objects:
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),obj.name
 volume=bm.calc_volume(signed=True);assert volume>1e-13,obj.name;bm.free()
 next(r for r in checks if r['name']==obj.name)['volume_m3']=volume
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/task_lamp_supply.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in exports.objects:obj.select_set(True)
class ExportUVHandedness:
 def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
  from io_scene_gltf2.io.exp.binary_data import BinaryData
  from io_scene_gltf2.io.com.constants import BufferViewTarget
  for primitive in mesh.primitives:
   def array(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
   n=array('NORMAL');g=array('_TANGENT_GUIDE');n/=np.linalg.norm(n,axis=1)[:,None];t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
   # Derive handedness from the final exported coordinates and flipped glTF
   # UVs, including both tube caps. Blender's pre-export sign is insufficient.
   positions=array('POSITION');uvs=np.frombuffer(primitive.attributes['TEXCOORD_0'].buffer_view.data,dtype='<f4').reshape((-1,2)).astype(float)
   indices=np.frombuffer(primitive.indices.buffer_view.data,dtype={5121:'u1',5123:'<u2',5125:'<u4'}[primitive.indices.component_type]).reshape((-1,3))
   p=positions[indices];uv=uvs[indices];a=uv[:,1]-uv[:,0];b=uv[:,2]-uv[:,0];det=a[:,0]*b[:,1]-a[:,1]*b[:,0];assert np.all(np.abs(det)>1e-12)
   bitangent=((p[:,2]-p[:,0])*a[:,0,None]-(p[:,1]-p[:,0])*b[:,0,None])/det[:,None]
   signs=np.sign(np.sum(np.cross(n[indices],t[indices])*bitangent[:,None,:],axis=2));assert np.all(signs!=0)
   handedness=np.empty(len(t));handedness[indices.ravel()]=signs.ravel()
   primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,handedness)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
   del primitive.attributes['_TANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=ROOT/'game/assets/props/task_lamp_supply.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
from check_exported_tangents import validate as validate_export
export_check=validate_export(asset)
runtime={'schema_version':1,'asset':'res://assets/props/task_lamp_supply.glb','materials':[{'key':key,**spec} for key,spec in specs.items()],'outlet':outlet_record,'installations':records}
(ROOT/'game/data/orison_v2/task_lamp_supply.json').write_text(json.dumps(runtime,indent=2)+'\n',newline='\n')
bindings=[PLAN,Path(__file__),ROOT/'art/blender/scripts/inspect_task_lamp_supply.py',ROOT/'game/data/runtime_material_sets.json',ROOT/'game/data/orison_v2/task_lamp_installations.json',ROOT/'game/assets/props/task_lamps.glb',ROOT/'game/scripts/props/native_task_lamp.gd',ROOT/'game/scripts/props/lamp_prop.gd']
bindings.append(ROOT/'art/blender/scripts/check_exported_tangents.py')
bindings.extend(ROOT/'art/blender/scripts'/name for name in ['fabrication_grain.py','fabrication_chart_batch.py','fabrication_normals.py'])
bindings.extend(ROOT/'game/assets/building/textures'/f for key in specs for f in catalog[key]['files'])
import_path=ROOT/'game/assets/props/task_lamp_supply.glb.import'
if import_path.exists():bindings.append(import_path)
report={'evidence_class':'INERT','classification':'ADAPTATION','asset_sha256':digest(asset),'closed_stocks':checks,'runtime':runtime,'routes':routes,'exported_tangents':export_check,'source_bindings':{p.relative_to(ROOT).as_posix():digest(p) for p in bindings}}
for name in ['art/blender/task_lamp_supply_construction.json','game/tests/fixtures/orison_task_lamp_supply.json']:(ROOT/name).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('TASK LAMP SUPPLY',len(records),'routes',len(checks),'closed stocks',len(exports.objects),'partitions')
