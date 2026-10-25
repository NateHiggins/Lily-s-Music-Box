"""Blender-native compact companion study; outputs stay external until reviewed."""
from pathlib import Path
import argparse, ast, collections, hashlib, json, math, sys
import bpy,bmesh
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser()
parser.add_argument('--source',required=True,help='Precompact native from c1f8b8f2')
parser.add_argument('--source-data',required=True,help='Matching precompact JSON from c1f8b8f2')
parser.add_argument('--out',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
OUT=Path(args.out).resolve()
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import partition,export,material
for d in ['art/blender','game/assets/props','review']:(OUT/d).mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(Path(args.source).resolve()))
bpy.context.preferences.filepaths.save_version=0
files={p.name:p for p in (ROOT/'game/assets').rglob('*') if p.is_file()}
for im in bpy.data.images:
 if im.source=='FILE':
  name=Path(im.filepath).name
  assert name in files,(im.name,name)
  im.filepath=str(files[name])
exports=bpy.data.collections['ServiceRadiophoneV2'];stocks=bpy.data.collections['EditableIndividualStock']
data=json.loads(Path(args.source_data).read_text())
assert abs(data['keys'][0]['size'][0]-.013)<1e-8, 'Requires original precompact source data'
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
# Retire exact editable wing stocks from their fixed material partitions.
prefixes=['Cradle strap','Bearer tie','Chassis through-bolt washer','Chassis bolt','Rolled guard','Guard stay','Bored motor barrel','Upper journal','Rotor shaft']
old=[o for o in stocks.objects if any(o.name=='Stock__'+p or o.name.startswith('Stock__'+p+'.') for p in prefixes)]
removed={}
for surface in ['CompanionSteel','CompanionBrass']:
 draw=bpy.data.objects['CompanionFixed__'+surface]
 points={tuple(round(x,7) for x in v.co) for o in old if o.data.materials[0].name==surface for v in o.data.vertices}
 bm=bmesh.new();bm.from_mesh(draw.data);vs=[v for v in bm.verts if tuple(round(x,7) for x in v.co) in points]
 removed[surface]=len(vs);assert vs
 bmesh.ops.delete(bm,geom=vs,context='VERTS');bm.to_mesh(draw.data);bm.free()
for o in old:bpy.data.objects.remove(o,do_unlink=True)
for o in list(exports.objects):
 if o.name.startswith('LiftRotor'):bpy.data.objects.remove(o,do_unlink=True)
# Native X remapping retains the paper, glazing and writer datums. Rounded
# formed margins shrink continuously; external controls translate as assemblies.
K=.76
protected=['Paper','Fixed__Paper','Platen','Carriage','Type_hammer','TypeSelector','OrderJewel','NetJewel','CallJewel','ServiceCover','ShellStudy__ShellGlass','ShellStudy__ShellRubber']
def margin(x):
 a=abs(x)
 # Preserve circular seats around the four outer through-bolts. The formed
 # margin compresses between seats; neither bore nor fastener becomes oval.
 if a<=.0685:return x
 if a<.0985:v=.0685+(a-.0685)*(.07691-.0685)/.030
 elif a<=.1065:v=.08091+(a-.1025)
 else:v=.08491+(a-.1065)*.365
 return math.copysign(v,x)
def category(o):
 n=o.name
 if n.startswith('FlipTile'):return 'tile'
 if n.startswith(('CompanionKey','KeySocket','PortKeyboardStay','StarboardKeyboardStay','KeyboardCarriage','ShellStudy__Keyboard')):return 'keyboard'
 if any(n==p or n.startswith(p+'__') for p in protected):return 'preserve'
 return 'margin'
# Bake each changed export in its original frame and rechart metric PBR. Native
# render meshes, not generated GLB buffers, are the source of every change.
original=list(exports.objects)
for o in original:
 if o.type!='MESH':continue
 cat=category(o)
 if cat=='preserve':continue
 mw=o.matrix_world.copy();inv=mw.inverted()
 if cat=='tile':
  for v in o.data.vertices:v.co*=K
 elif cat=='keyboard':
  for v in o.data.vertices:
   p=mw@v.co;p.x*=K;v.co=inv@p
 else:
  # Disconnected hardware beyond the display translates intact. Large shell,
  # shaft or strip pieces use a continuous compressed margin.
  bm=bmesh.new();bm.from_mesh(o.data);seen=set()
  for first in bm.verts:
   if first in seen:continue
   stack=[first];component=[];seen.add(first)
   while stack:
    v=stack.pop();component.append(v)
    for e in v.link_edges:
     other=e.other_vert(v)
     if other not in seen:seen.add(other);stack.append(other)
   pts=[mw@v.co for v in component];lo=min(p.x for p in pts);hi=max(p.x for p in pts)
   rigid=(lo>.072 or hi<-.072) and hi-lo<.045
   center=(hi+lo)/2;shift=margin(center)-center
   for v,p in zip(component,pts):p.x=p.x+shift if rigid else margin(p.x);v.co=inv@p
  bm.to_mesh(o.data);bm.free()
 # Rebuild chart coordinates in the mesh's local metre frame (no scale nodes).
 surf=o.data.materials[0].name
 spec=data['finishes'].get(surf)
 if spec is None:spec=json.loads((ROOT/'game/data/device/service_radiophone_v2.json').read_text())['finishes'][surf]
 temp=partition(exports,'CompactRechart',[o],spec,o.data.materials[0],Matrix.Identity(4),catalog)
 o.data=temp.data;bpy.data.objects.remove(temp,do_unlink=True)
# Translate the corresponding mechanism origins without scaling their axes.
# Mesh coordinates above already contain the new global locations.
for o in original:
 if o.parent is not None or (o.type!='EMPTY' and not o.name.startswith('CompanionKey')):continue
 oldmw=o.matrix_world.copy();cat=category(o)
 x=oldmw.translation.x;newx=x*K if cat=='keyboard' else (x if cat=='preserve' else margin(x))
 delta=newx-x
 if abs(delta)>1e-9:
  if o.type=='MESH':o.data.transform(Matrix.Translation((-delta,0,0)))
  for child in o.children:
   if child.type=='MESH':child.data.transform(Matrix.Translation((-delta,0,0)))
  o.location.x+=delta
# Splay the short aerial outboard: its measured upright crown clearance
# was negative by 0.63 mm. The native pivot keeps its seated root and the
# existing radio owner still retracts along the aerial's own axis.
bpy.data.objects['Aerial'].rotation_euler.y += math.atan2(.006,.044)
# Key sockets live below the keyboard; match the narrowed tray exactly.
for o in original:
 if o.name.startswith('KeySocket'):o.location.x*=K
for r in data['keys']:r['point'][0]*=K;r['size'][0]*=K
# Square flip tiles retain their aspect and clear their original vertical rods.
data['flip_display']['pitch']*=K
# Column spindle X coordinates were narrowed with the tray; tile pitch follows.
# Reuse established manifold stock constructors without executing old builder.
groups=collections.defaultdict(list);pivots={};checks=[]
source=ast.parse((ROOT/'art/blender/scripts/build_service_companion.py').read_text())
functions=[n for n in source.body if isinstance(n,ast.FunctionDef) and n.name in ['coords','stock','box','ring','rod','pivot']]
exec(compile(ast.Module(body=functions,type_ignores=[]),'native_stock_functions','exec'))
data['finishes']['RotorCanvas']=dict(catalog_key='linen',tint=[.65,.57,.37,1],normal=.18,roughness=.92,pigment=.45)
material(ROOT,'RotorCanvas',data['finishes']['RotorCanvas'],catalog)
image_paths={im.name:im.filepath for im in bpy.data.images if im.source=='FILE'}
# Three bolted feet share the formed chassis top/rear plate and hold a nested
# shaft bearing cartridge; the rotating sails have separate radial journals.
for x in [-.048,.048]:
 box('Crown mounting foot',(x,.098,-.012),(.018,.005,.030))
 ring('Crown foot washer',(x,.1015,-.012),.004,.0018,.002)
 rod('Crown foot through bolt',(x,.094,-.012),(x,.104,-.012),.0016)
 rod('Crown triangulated bearer',(x,.101,-.012),(0,.126,-.012),.0025)
ring('Crown motor case',(0,.116,-.012),.018,.010,.026,'CompanionSteel',axis='y',count=32)
for y in [.104,.128]:ring('Motor end flange',(0,y,-.012),.020,.009,.003,'CompanionBrass',count=32)
rod('Inner drive spindle',(0,.110,-.012),(0,.235,-.012),.003,'CompanionSteel',count=16)
ring('Counter shaft sleeve',(0,.160,-.012),.006,.0035,.080,'CompanionBrass',count=24)
for name,y,hand in [('LiftRotorPort',.187,1),('LiftRotorStarboard',.140,-1)]:
 pivot(name,(0,y,-.012))
 ring('Separate rotor hub',(0,y,-.012),.012,.0065,.008,group=name,count=24)
 ring('Journal thrust shoulder',(0,y-.007,-.012),.014,.0063,.003,count=24)
 ring('Rotor sail root tube',(0,y+.0175,-.012),.0116,.0065,.039,'CompanionBrass',group=name,count=24)
 # Closed thin linen membrane: one helical turn, 32 angular x 3 radial cells.
 verts=[];N=32;R=3;rise=.035;radius=.076
 for layer in [-.00025,.00025]:
  for i in range(N+1):
   a=hand*i*math.tau/N
   for j in range(R+1):
    r=.011+(radius-.011)*j/R
    verts.append((r*math.cos(a),y+rise*i/N+layer,-.012+r*math.sin(a)))
 stride=R+1;sheet=(N+1)*stride;faces=[]
 for i in range(N):
  for j in range(R):
   q=i*stride+j;faces.extend([(q,q+1,q+stride+1,q+stride),(sheet+q,sheet+q+stride,sheet+q+stride+1,sheet+q+1)])
 boundary=list(range(R+1))+[i*stride+R for i in range(1,N+1)]+[N*stride+j for j in range(R-1,-1,-1)]+[i*stride for i in range(N-1,0,-1)]
 for i,a in enumerate(boundary):b=boundary[(i+1)%len(boundary)];faces.append((a,sheet+a,sheet+b,b))
 stock('Taut spiral linen membrane',verts,faces,'RotorCanvas',name)
 # Tangential edge cables and individual radial ribs form visible load paths.
 for i in range(0,N,4):
  a=hand*i*math.tau/N;h=y+rise*i/N
  rod('Sail radial rib',(.010*math.cos(a),h,-.012+.010*math.sin(a)),(radius*math.cos(a),h,-.012+radius*math.sin(a)),.00085,'CompanionBrass',name,count=8)
 for edge in [.011,radius]:
  for i in range(N):
   a=hand*i*math.tau/N;b=hand*(i+1)*math.tau/N
   rod('Sail tension edge',(edge*math.cos(a),y+rise*i/N,-.012+edge*math.sin(a)),(edge*math.cos(b),y+rise*(i+1)/N,-.012+edge*math.sin(b)),.0007,'CompanionBrass',name,count=4)
# Guard rings frame the crown without outboard wings; 5mm radial sail clearance.
for y in [.134,.229]:ring('Crown safety hoop',(0,y,-.012),.083,.081,.0025,'CompanionSteel',count=48)
for a in [math.pi/2,math.pi*7/6,math.pi*11/6]:
 x=.082*math.cos(a);z=-.012+.082*math.sin(a)
 rod('Crown guard upright',(x,.134,z),(x,.229,z),.001,'CompanionSteel',count=8)
 rod('Crown guard foot',(x,.134,z),(x*.2,.104,-.012+(z+.012)*.2),.0018,'CompanionSteel',count=8)
for (group,surface),objs in groups.items():
 spec=data['finishes'][surface];mat=bpy.data.materials[surface]
 for o in objs:o.data.materials.append(mat)
 draw=partition(exports,group+'__'+surface,objs,spec,mat,Matrix.Identity(4),catalog)
 if group in pivots:
  parent=pivots[group];draw.data.transform(Matrix.Translation(-parent.location));draw.parent=parent;draw.location=(0,0,0)
bpy.context.view_layer.update()
proof=export(OUT,'service_companion_v2',exports,material_names_only=True,staged_output=True)
data['keyboard_stay_half_span_m']=.094*K
data['asset_sha256']=hashlib.sha256((OUT/'game/assets/props/service_companion_v2.glb').read_bytes()).hexdigest()
(OUT/'service_companion_v2.json').write_text(json.dumps(data,indent=2)+'\n')
(OUT/'construction.json').write_text(json.dumps(dict(retired_fixed_vertices=removed,export=proof,stock_checks=checks,keyboard_width_scale=K,display_width_m=.137,case_width_m=.174,sail_radius_m=.076,radial_guard_clearance_m=.005),indent=2)+'\n')
for im in bpy.data.images:
 if im.name in image_paths:im.filepath=image_paths[im.name]
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'art/blender/service_companion_v2.blend'),relative_remap=False)
# Native review only; no staging camera/light is exported.
for o in bpy.data.objects:o.hide_render=o.name not in exports.objects
for o in exports.objects:
 if o.name.startswith(('CompanionKeyBlank','CompanionKeySpace','CompanionKeyEnter','CompanionKeyBackspace','FlipTile')) and o.type=='MESH':o.hide_render=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1100;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
camera_data=bpy.data.cameras.new('CompactReviewCamera');camera=bpy.data.objects.new('CompactReviewCamera',camera_data);scene.collection.objects.link(camera)
camera.location=(.30,-.65,.29);target=Vector((0,-.015,.08));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=.47;scene.camera=camera
for position,energy,size in [((.3,-.6,.6),70,.55),((-.3,-.1,.3),40,.4),((0,.4,.5),55,.3)]:
 ld=bpy.data.lights.new('CompactReviewSoftbox','AREA');ld.energy=energy;ld.shape='DISK';ld.size=size
 light=bpy.data.objects.new('CompactReviewSoftbox',ld);scene.collection.objects.link(light);light.location=position;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'review/native_closed.png');bpy.ops.render.render(write_still=True)
print('COMPACT CROWN',json.dumps(proof))
