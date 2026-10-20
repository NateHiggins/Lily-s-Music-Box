"""Candidate pressed cabinet and real interleaved hinge stock; no authority changes."""
from pathlib import Path
import argparse, ast, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True)
parser.add_argument('--finishes',type=Path,required=True)
parser.add_argument('--skip-render',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);OUT=args.out.resolve()
assert OUT.is_relative_to(ROOT/'tmp');OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_uvs import chart_for_triangle
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
parts={};roles={};bindings={}
(OUT/'construction.json').unlink(missing_ok=True)
def bind(path):
 path=path.resolve()
 if not path.is_relative_to(ROOT):raise ValueError('Source escapes repository')
 raw=path.read_bytes()
 if path.suffix in {'.py','.json'}:raw=raw.replace(b'\r\n',b'\n')
 key=path.relative_to(ROOT).as_posix();value=hashlib.sha256(raw).hexdigest()
 if key in bindings and bindings[key]!=value:raise ValueError('Source changed while building: '+key)
 bindings[key]=value
for path in [Path(__file__),ROOT/'art/data/fire_service/source_plan.json',
             ROOT/'art/blender/scripts/fabrication_uvs.py',ROOT/'art/blender/scripts/check_exported_tangents.py',
             ROOT/'art/blender/scripts/build_media_battery_supply.py']:bind(path)

def b(p):return Vector((p[0],-p[2],p[1]))
def material(key,transmission=False):
 folder=args.finishes/key
 if folder.is_dir():
  bind(folder/'material.json')
  spec=json.loads((folder/'material.json').read_text());files=[folder/(name+'.png') for name in ['albedo','roughness','normal']];tile=float(spec['meters_per_tile'])
 else:
  bind(ROOT/'game/data/runtime_material_sets.json')
  spec=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials'][key];files=[ROOT/'game/assets/building/textures'/name for name in spec['files']];tile=float(spec['meters_per_tile'])
 for path in files:bind(path)
 m=bpy.data.materials.new(key);m.use_nodes=True;n=m.node_tree.nodes;links=m.node_tree.links;bs=n.get('Principled BSDF')
 bs.inputs['Metallic'].default_value=float(spec.get('metallic',0.));bs.inputs['IOR'].default_value=1.52
 if transmission:bs.inputs['Transmission Weight'].default_value=1.
 uv=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/tile;links.new(uv.outputs['UV'],scale.inputs[0])
 for i,(channel,target) in enumerate([('albedo','Base Color'),('roughness','Roughness'),('normal','Normal')]):
  tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(files[i]),check_existing=True);tex.image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color';links.new(scale.outputs[0],tex.inputs['Vector'])
  if channel=='normal':
   normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=1.;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs[target])
  else:links.new(tex.outputs['Color'],bs.inputs[target])
 return m
red=material('fire_cabinet_enamel');lining=material('fire_cabinet_lining');glass=material('glass_cut',True)
brass=material('radiator_service_brass');rubber=material('washer_rubber')
steel=material('fire_hardware_steel');steel.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.88
def cube(size,at=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=b(at));o=bpy.context.object;o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
def cylinder(radius,length,at=(0,0,0)):
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=length,location=b(at));return bpy.context.object
def boolean(o,c,operation='DIFFERENCE'):
 bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Fabricated stock','BOOLEAN');mod.operation=operation;mod.solver='EXACT';mod.object=c;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(c,do_unlink=True)
def tube(radius,bore,length,at=(0,0,0)):
 o=cylinder(radius,length,at);boolean(o,cylinder(bore,length+.004,at));return o
def wire(points,radius,closed=False):
 curve=bpy.data.curves.new('Worked continuous wire','CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=3;curve.use_fill_caps=not closed
 line=curve.splines.new('POLY');line.points.add(len(points)-1)
 for v,point in zip(line.points,points):v.co=(*b(point),1.)
 line.use_cyclic_u=closed;o=bpy.data.objects.new('Wire stock',curve);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');return bpy.context.object
def strap(points,width,thickness):
 vertices=[];faces=[];points=[Vector(p) for p in points]
 for i,p in enumerate(points):
  tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized();normal=tangent.cross(Vector((1,0,0))).normalized()
  for u,v in [(-1,-1),(1,-1),(1,1),(-1,1)]:vertices.append(b(p+Vector((u*width/2,0,0))+normal*(v*thickness/2)))
 for i in range(len(points)-1):
  for j in range(4):faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
 faces.extend([(3,2,1,0),tuple(range((len(points)-1)*4,len(points)*4))])
 mesh=bpy.data.meshes.new('Folded spring steel');mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new('Spring clip',mesh);bpy.context.collection.objects.link(o);return o
def finish(name,objects,mat,pose=(0,0,0),parent='actor',bevel=.00045):
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 if len(objects)>1:bpy.ops.object.join()
 o=bpy.context.object
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 if bevel:
  mod=o.modifiers.new('Rolled worked edges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=5e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),name;assert bm.calc_volume(signed=True)>0,name
 bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 o.data.materials.clear();o.data.materials.append(mat)
 for uv in list(o.data.uv_layers):o.data.uv_layers.remove(uv)
 uv=o.data.uv_layers.new(name='MetreStock')
 for face in o.data.polygons:
  face.material_index=0;pts=np.array([o.data.vertices[i].co[:] for i in face.vertices]);_,_,values,_=chart_for_triangle(pts,np.zeros(3),1.)
  for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
 o.name=name;o.location=b(pose);parts[name]=o;roles[name]={'parent':parent,'position':list(pose),'material':mat.name};return o
plan=json.loads((ROOT/'art/data/fire_service/source_plan.json').read_text())['parts']
for index in [7,8,9,10,11,16,17,18,19,62,63,65]:
 row=plan[index];size=row['size'];o=cube(size)
 # Pressed recesses, rolled edges and real sheet returns replace featureless
 # slabs while retaining the original external seats for all service stock.
 if index==7:
  for x in [-.16,.16]:
   for y in [-.22,.22]:boolean(o,cube((.20,.14,.003),(x,y,size[2]/2)))
 elif index==62:
  boolean(o,cube((.064,.022,.064),(0,.0015,0)))
 elif index==63:
  bpy.data.objects.remove(o,do_unlink=True)
  o=strap([(0,-.028,-.008),(0,-.024,-.008),(0,-.020,-.003),(0,.018,-.003),(0,.026,.001),(0,.026,.008),(0,.020,.010)],.018,.0012)
 elif index==65:
  bpy.data.objects.remove(o,do_unlink=True)
  # Continuous pressed frame, retaining the original F065/pivot authority.
  o=cube((.610,.780,.024),(-.281,0,0))
  boolean(o,cube((.516,.610,.050),(-.281,.055,0)))
  cavity=cube((.606,.776,.026),(-.281,0,-.003))
  boolean(cavity,cube((.520,.614,.040),(-.281,.055,-.003)))
  boolean(o,cavity)
 elif index in [16,17,18,19]:
  # Rolled edge stock gains an actual return channel; ends remain capped.
  inner=[max(.002,v-.003) for v in size];boolean(o,cube(inner))
 pose=(.245,.033,.150) if index==62 else ((.245,.071,.124) if index==63 else tuple(row['pose_position']))
 finish('F%03d'%index,[o],lining if index==7 else (steel if index in [62,63] else red),pose, 'door' if index>=65 else 'actor',.0002 if index in [62,63] else (.0012 if index<65 else .0007))
row=plan[69];finish('F069',[cube(row['size'])],glass,tuple(row['pose_position']),'door',.0006)
# A real resilient glazing bead, following the aperture as one closed loop.
path=[];width,height,corner=.518,.612,.008
for cx,cy,start in [(width/2-corner,height/2-corner,0),(-width/2+corner,height/2-corner,90),(-width/2+corner,-height/2+corner,180),(width/2-corner,-height/2+corner,270)]:
 for j in range(17):
  a=math.radians(start+j*90/16);path.append((cx+corner*math.cos(a),cy+corner*math.sin(a),0))
finish('GlazingSeal',[wire(path,.0013,True)],rubber,(0,.445,.217),'door',0)
# Formed pull, its backing plate and slotted mounts replace the old plain peg.
plate=cube((.020,.080,.0025));loop=wire([(0,-.024,.001),(0,-.027,.006),(0,-.027,.026),(0,-.020,.034),(0,.020,.034),(0,.027,.026),(0,.027,.006),(0,.024,.001)],.004)
for y in [-.032,.032]:
 bore=cylinder(.0015,.010,(0,y,0));bore.rotation_euler.x=math.pi/2;bpy.context.view_layer.objects.active=bore;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);boolean(plate,bore)
boolean(plate,loop,'UNION');finish('DoorPull',[plate],brass,(-.273,.390,.2195),'door',.0004)
for i,y in enumerate([-.032,.032]):
 head=cylinder(.0035,.002);head.rotation_euler.x=math.pi/2;bpy.context.view_layer.objects.active=head;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 boolean(head,cube((.005,.00075,.0015),(0,0,.001)))
 finish('PullScrew%d'%i,[head],steel,(-.273,.390+y,.22175),'door',.00012)
# Fine embedded diamond wire, rather than thick bars pasted onto the pane.
wires=[];half_x,half_y=.258,.305
for slope in [-1,1]:
 for k in range(-18,19):
  c=k*.032;hits=[]
  for x in [-half_x,half_x]:
   y=slope*x+c
   if -half_y<=y<=half_y:hits.append((x,y))
  for y in [-half_y,half_y]:
   x=(y-c)/slope
   if -half_x<x<half_x:hits.append((x,y))
  if len(hits)==2:wires.append(wire([(x,y,slope*.0003) for x,y in hits],.00025))
finish('SafetyWire',wires,steel,(0,.445,.211),'door',0)
# Two three-knuckle hinges on the existing real Y axis. Fixed end knuckles
# and moving centre knuckle leave0.2mm axial gaps around a2.5mm captive pin.
for i,y in enumerate([-.19,.21]):
 fixed=cube((.011,.042,.002),(.0095,0,-.001))
 boolean(fixed,cube((.004,.0124,.008),(.0048,0,0)))
 for offset in [-.012,.012]:boolean(fixed,tube(.006,.0026,.0118,(0,offset,0)),'UNION')
 finish('HingeFixed%d'%i,[fixed],steel,(.305,.390+y,.206),bevel=.00015)
 moving=tube(.006,.0026,.0118)
 boolean(moving,cube((.002,.0118,.011),(-.0048,0,-.0055)),'UNION')
 boolean(moving,cube((.024,.030,.002),(-.016,0,-.011)),'UNION')
 finish('HingeMoving%d'%i,[moving],steel,(.305,.390+y,.206),'door',.00015)
 pin=cylinder(.0025,.038)
 boolean(pin,cylinder(.0045,.0015,(0,.0195,0)),'UNION')
 finish('HingePin%d'%i,[pin],steel,(.305,.390+y,.206),bevel=.00012)
# Raised slotted mounting fasteners give the voxel beam actual silhouettes.
for i,(x,y) in enumerate([(-.285,.06),(.285,.06),(-.285,.72),(.285,.72)]):
 head=cylinder(.004,.0025);head.rotation_euler.x=math.pi/2;bpy.context.view_layer.objects.active=head;bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 boolean(head,cube((.006,.0008,.002),(0,0,.001)))
 finish('CaseFastener%d'%i,[head],steel,(x,y,.021),bevel=.00015)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fire_cabinet_skin.blend'))
tree=ast.parse((ROOT/'art/blender/scripts/build_media_battery_supply.py').read_text(encoding='utf8'));exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportDerivatives'],type_ignores=[]),'derivatives','exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportDerivatives
bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUT/'fire_cabinet_skin.glb'),export_format='GLB',export_yup=True,export_tangents=True,export_materials='NONE')
from check_exported_tangents import validate
report=validate(OUT/'fire_cabinet_skin.glb')
for name in list(bindings):bind(ROOT/name)
construction={'schema_version':1,'evidence_class':'INERT','status':'CANDIDATE_NOT_INSTALLED',
 'parts':roles,'retired_source_visuals':['F066','F067','F068','F081']+['F%03d'%i for i in range(70,81)],
 'source_bindings':bindings,'outputs':{name:hashlib.sha256((OUT/name).read_bytes()).hexdigest()
   for name in ['fire_cabinet_skin.blend','fire_cabinet_skin.glb']},'export':report}
(OUT/'construction.json').write_text(json.dumps(construction,indent=2)+'\n',encoding='utf8',newline='\n')
if args.skip_render:
 print('CABINET SKIN CANDIDATE',len(parts),'native stocks',report);raise SystemExit(0)

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=2
scene.render.resolution_x=1050;scene.render.resolution_y=1250;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Dark service landing');scene.world.color=(.035,.035,.035)
bpy.ops.object.camera_add(location=b((1.05,.92,1.5)));cam=bpy.context.object;cam.rotation_euler=(b((0,.39,.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.02;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=b((.25,.70,.80)));light=bpy.context.object;light.data.energy=35;light.data.shape='DISK';light.data.size=.20;light.rotation_euler=(b((0,.4,.1))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'cabinet_source_review.png');bpy.ops.render.render(write_still=True)
print('CABINET SKIN CANDIDATE',len(parts),'native stocks',report)
