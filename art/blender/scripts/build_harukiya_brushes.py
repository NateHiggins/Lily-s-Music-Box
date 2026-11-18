"""Original wire drum brush; two instances form the pair. No downloaded art.

Blender --background --python-exit-code 1 --python this.py -- --report DIR [--render]
Godot metres, +Z from butt to fan, +Y dorsal. Stock and maps remain editable.
"""
from pathlib import Path
import argparse, hashlib, json, math, shutil, sys
import bpy, bmesh, numpy as np
from mathutils import Matrix, Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True,type=Path);parser.add_argument('--render',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);args.report.mkdir(parents=True,exist_ok=True)
assert not (args.report/'NATIVE_BUILD.json').exists(),'fresh report required'
FAMILY='harukiya_drum_brush'
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def sha(p):
 raw=Path(p).read_bytes();return hashlib.sha256(raw if Path(p).suffix in ['.glb','.blend','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
prior=[]
for p in [ROOT/'art/blender'/f'{FAMILY}.blend',ROOT/'game/assets/props'/f'{FAMILY}.glb',ROOT/'game/data/orison_v2'/f'{FAMILY}.json']:
 if p.exists():
  keep=args.report/'prior'/p.name;keep.parent.mkdir(exist_ok=True)
  assert not keep.exists(),'fresh report required';shutil.copy2(p,keep);assert sha(p)==sha(keep)
  prior.append(dict(source=str(p),preserved=str(keep),sha256=sha(p)))
(args.report/'PRIOR_CUSTODY.json').write_text(json.dumps(prior,indent=2))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
stock=bpy.data.collections.new('Editable closed brush stock');scene.collection.children.link(stock)
draws=bpy.data.collections.new('Runtime material partitions');scene.collection.children.link(draws)
catalog_path=ROOT/'game/data/runtime_material_sets.json';catalog=json.loads(catalog_path.read_text())['materials']
finishes={
 'BrushHandle':dict(catalog_key='wood_dark',tint=[.55,.49,.43,1],normal=.04,roughness=.8,pigment=1),
 'BrushWire':dict(catalog_key='nickel_plated',tint=[1,1,1,1],normal=.025,roughness=.95,pigment=1)}
mats={key:material(ROOT,key,finish,catalog) for key,finish in finishes.items()}
pieces=[];checks=[];tips=[]
def tube(name,centres,radii,key,sides=8):
 # Parallel transport is unnecessary for these shallow monotonic fan curves;
 # a projected common X reference gives a continuous circular cross-section.
 points=[Vector(p) for p in centres];vertices=[]
 for j,p in enumerate(points):
  axis=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
  u=(Vector((1,0,0))-axis*axis.x).normalized();v=axis.cross(u)
  vertices.extend(C.to_3x3()@(p+(u*math.cos(i*math.tau/sides)+v*math.sin(i*math.tau/sides))*radii[j]) for i in range(sides))
 faces=[tuple(reversed(range(sides)))]
 for j in range(len(points)-1):
  for i in range(sides):faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
 faces.append(tuple(range((len(points)-1)*sides,len(points)*sides)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),name
 volume=bm.calc_volume(signed=True);assert volume>1e-13,(name,volume)
 bm.to_mesh(mesh);bm.free();mesh.materials.append(mats[key])
 obj=bpy.data.objects.new(name,mesh);stock.objects.link(obj);pieces.append((obj,key))
 checks.append(dict(name=name,volume_m3=volume,closed=True))

# A small dark wood grip and rounded nickel ferrule; no modern logo/plastic.
tube('Lacquered wooden handle',[(0,0,z) for z in [0,.003,.012,.14,.157,.165]],[.0047,.0062,.0065,.0065,.0057,.0057],'BrushHandle',24)
tube('Nickel ferrule',[(0,0,z) for z in [.155,.157,.171,.174]],[.0058,.0062,.0062,.004],'BrushWire',24)
for i in range(45):
 s=i/44*2-1;root_x=s*.0028;end_x=s*.054
 length=.136-.004*abs(s)+.0005*math.sin(i*2.4)
 points=[]
 for j in range(10):
  t=j/9;smooth=t*t*(3-2*t)
  points.append((root_x+(end_x-root_x)*smooth,.0025*(1-t)**2+.001*math.sin(math.pi*t),.169+length*t))
 tube('Spring wire %02d'%i,points,[.00016*(1-.12*j/9) for j in range(10)],'BrushWire',6)
 tips.append(list(points[-1]))
parts=[]
for key in sorted(finishes):
 objects=[o for o,k in pieces if k==key];name='DrumBrush_'+key
 obj=partition(draws,name,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
 parts.append(dict(mesh=name,materials=[key],triangles=len(obj.data.polygons)))
stock.hide_render=True;stock.hide_viewport=True;bpy.context.view_layer.update()
proof=export(ROOT,FAMILY,draws,material_names_only=True)
assert proof['status']=='PASS' and proof['triangles']<6500 and proof['primitives']==2,proof
assert proof['triangles']==sum(p['triangles'] for p in parts)
contacts={'grip':dict(position=[0,0,.065],axis=[0,0,1],radius_m=.0065),
 'fan_root':dict(position=[0,.0025,.169]),'fan_tips':dict(positions=tips),
 'fan_contact':dict(position=[0,0,.303],normal=[0,-1,0],half_width_m=.054)}
data=dict(schema_version=1,asset='res://assets/props/'+FAMILY+'.glb',
 coordinates='Godot metres, +Z butt to fan, +Y dorsal; local origin at butt',
 partitions=parts,materials=[dict(key=k,**f,meters_per_tile=catalog[f['catalog_key']]['meters_per_tile']) for k,f in finishes.items()],
 contacts=contacts,integration='Rigid development prop; instantiate twice for a pair. No collisions, inventory, animation or autonomous authority. Held contact/flex not yet qualified.')
data_path=ROOT/'game/data/orison_v2'/f'{FAMILY}.json';data_path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
blend_path=ROOT/'art/blender'/f'{FAMILY}.blend'
for image in bpy.data.images:
 if image.filepath:image.filepath=bpy.path.relpath(image.filepath,start=str(blend_path.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
bindings=[Path(__file__).resolve(),catalog_path]+[ROOT/'art/blender/scripts'/name for name in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
report=dict(status='NATIVE_PASS',closed_stock_count=len(checks),checks=checks,tangent_check=proof,
 triangles=proof['triangles'],draw_surfaces=proof['primitives'],no_new_images=True,
 source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in bindings},
 blend_sha256=sha(blend_path),asset_sha256=sha(ROOT/'game/assets/props'/f'{FAMILY}.glb'),data_sha256=sha(data_path),
 native_review='pending',loaded_review='pending',held_motion_and_audio='pending')
(args.report/'NATIVE_BUILD.json').write_text(json.dumps(report,indent=2))
print('DRUM_BRUSH_NATIVE_PASS',proof['triangles'],flush=True)
if args.render:
 bpy.ops.wm.open_mainfile(filepath=str(blend_path));scene=bpy.context.scene
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.cycles.device='CPU'
 scene.render.threads_mode='FIXED';scene.render.threads=8
 scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
 scene.world=bpy.data.worlds.new('Neutral brush review');scene.world.use_nodes=True
 scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.33,.36,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
 aim=C.to_3x3()@Vector((0,0,.16))
 for at,power,size in [((-.25,.4,.3),16,.3),((.3,.1,.1),10,.25)]:
  bpy.ops.object.light_add(type='AREA',location=C.to_3x3()@Vector(at));light=bpy.context.object
  light.data.energy=power;light.data.size=size;light.rotation_euler=(aim-light.location).to_track_quat('-Z','Y').to_euler()
 for name,at in [('front',(.1,.46,.35)),('back',(-.12,-.4,.27)),('edge',(.35,.09,.2))]:
  bpy.ops.object.camera_add(location=C.to_3x3()@Vector(at));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=.55
  cam.rotation_euler=(aim-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
  scene.render.filepath=str(args.report/(name+'.png'));bpy.ops.render.render(write_still=True);bpy.data.objects.remove(cam,do_unlink=True)
