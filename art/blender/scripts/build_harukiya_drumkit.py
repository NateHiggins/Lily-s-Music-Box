"""Original compact Harukiya drum kit. Metric source; no gameplay or cast authority.

Blender --background --python-exit-code 1 --python this.py -- --report DIR [--render]
All input coordinates are Godot metres: Y up, drummer at +Z facing -Z.
Catalogue images stay external; runtime binds the declared finishes to named slots.
"""
from pathlib import Path
import argparse,collections,hashlib,json,math,shutil,sys,time
import bpy,bmesh,numpy as np
from mathutils import Matrix,Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
from check_exported_tangents import validate
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
FAMILY='harukiya_drumkit'
parser=argparse.ArgumentParser();parser.add_argument('--report',required=True,type=Path)
parser.add_argument('--render',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
args.report.mkdir(parents=True,exist_ok=True)
started=time.time()
def sha(p):
 raw=Path(p).read_bytes()
 return hashlib.sha256(raw if Path(p).suffix in ['.blend','.glb','.png'] else raw.replace(b'\r\n',b'\n')).hexdigest()
outputs=[ROOT/'art/blender'/f'{FAMILY}.blend',ROOT/'art/blender'/f'{FAMILY}_inventory.json',
 ROOT/'game/assets/props'/f'{FAMILY}.glb',ROOT/'game/data/orison_v2'/f'{FAMILY}.json']
prior=[]
for p in outputs:
 if p.exists():
  keep=args.report/'prior'/p.name;keep.parent.mkdir(exist_ok=True)
  if keep.exists():raise FileExistsError('Use a fresh report directory: '+str(keep))
  shutil.copy2(p,keep);assert sha(p)==sha(keep);prior.append({'source':str(p),'preserved':str(keep),'sha256':sha(p)})
for p in (ROOT/'art/blender').glob(FAMILY+'.blend[0-9]*'):
 keep=args.report/'prior'/p.name;keep.parent.mkdir(exist_ok=True);shutil.copy2(p,keep)
 assert sha(p)==sha(keep);prior.append({'source':str(p),'preserved':str(keep),'sha256':sha(p)})
(args.report/'PRIOR_CUSTODY.json').write_text(json.dumps(prior,indent=2))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
stock=bpy.data.collections.new('Closed editable construction');scene.collection.children.link(stock)
draws=bpy.data.collections.new('Runtime material partitions');scene.collection.children.link(draws)
catalog_path=ROOT/'game/data/runtime_material_sets.json'
catalog=json.loads(catalog_path.read_text())['materials']
# These are scoped finish variants, not new image recipes. Surface maps retain
# their catalogue scale; hide is used only for actual skins/seating, not paper.
def finish(key,tint=(1,1,1,1),normal=.2,roughness=1,pigment=1):
 return dict(catalog_key=key,tint=list(tint),normal=normal,roughness=roughness,pigment=pigment)
finishes={
 'KitWalnut':finish('wood_dark',(.70,.62,.55,1),.10,.75),
 'KitHide':finish('leather_worn',(1.40,1.65,2.00,1),.035,.78,.42),
 'KitNickel':finish('nickel_plated',(1,1,1,1),.12,.82),
 'KitBronze':finish('bronze_sheet',(1,1,1,1),.25,.78),
 'KitRubber':finish('rubber_aged',(.35,.35,.35,1),.12,.95),
 'KitSeat':finish('leather_worn',(.16,.15,.14,1),.22,.85),
 'KitSticks':finish('timber',(1,1,1,1),.08,.85)}
mats={k:material(ROOT,k,f,catalog) for k,f in finishes.items()}
pieces=[];checks=[];contacts={};pivots={};supports=[]

def solid(name,verts,faces,key,group='static'):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([C.to_3x3()@Vector(v) for v in verts],[],faces);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges),(name,'open stock')
 volume=bm.calc_volume(signed=True);assert volume>1e-13,(name,'nonpositive volume',volume)
 bm.to_mesh(mesh);bm.free();mesh.materials.append(mats[key])
 obj=bpy.data.objects.new(name,mesh);stock.objects.link(obj);pieces.append((obj,key,group))
 checks.append({'name':name,'finish':key,'group':group,'volume_m3':volume,'closed':True})
 return obj

def basis(axis):
 w=Vector(axis).normalized();seed=Vector((0,0,1)) if abs(w.z)<.9 else Vector((0,1,0))
 u=seed.cross(w).normalized();v=w.cross(u);return u,v,w

def lathe(name,profile,at,key,axis=(0,1,0),n=48,closed_profile=False,group='static'):
 # Profile is (axial offset,radius); closed profiles make real annular stock.
 u,v,w=basis(axis);at=Vector(at)
 verts=[at+w*h+(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n))*r for h,r in profile for i in range(n)]
 faces=[];bands=len(profile) if closed_profile else len(profile)-1
 for j in range(bands):
  k=(j+1)%len(profile)
  faces.extend((j*n+i,j*n+(i+1)%n,k*n+(i+1)%n,k*n+i) for i in range(n))
 if not closed_profile:faces=[tuple(reversed(range(n)))]+faces+[tuple(range((len(profile)-1)*n,len(profile)*n))]
 return solid(name,verts,faces,key,group)

def rod(name,a,b,r,key='KitNickel',n=12,group='static'):
 a,b=Vector(a),Vector(b);d=(b-a).length
 return lathe(name,[(-d/2,r),(d/2,r)],(a+b)/2,key,b-a,n,group=group)

def ring(name,at,r,inside,depth,key='KitNickel',axis=(0,1,0),n=48,group='static'):
 return lathe(name,[(-depth/2,r),(depth/2,r),(depth/2,inside),(-depth/2,inside)],at,key,axis,n,True,group)

def box(name,at,size,key,group='static',rotation=None):
 rot=rotation if rotation is not None else Matrix.Identity(3);at=Vector(at);half=Vector(size)/2
 verts=[at+rot@Vector((x*half.x,y*half.y,z*half.z)) for z in [-1,1] for y in [-1,1] for x in [-1,1]]
 return solid(name,verts,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],key,group)

def foot(name,at):
 x,_,z=at;rod(name,(x,0,z),(x,.036,z),.025,'KitRubber',16)
 supports.append({'id':name,'floor_contact':[x,0,z],'radius_m':.025})

def tripod(name,x,z,top,spread=.25):
 rod(name+' lower tube',(x,.07,z),(x,top*.63,z),.012)
 rod(name+' telescopic tube',(x,top*.49,z),(x,top,z),.008)
 ring(name+' clamp',(x,top*.54,z),.018,.008,.035,n=16)
 rod(name+' wing screw',(x-.025,top*.54,z),(x+.025,top*.54,z),.004,n=8)
 for i in range(3):
  angle=i*math.tau/3+.32;end=(x+spread*math.cos(angle),.025,z+spread*math.sin(angle))
  rod(name+' leg '+str(i),(x,.27,z),end,.009);foot(name+' rubber foot '+str(i),end)
  rod(name+' stay '+str(i),(x,.13,z),((x+end[0])/2,.15,(z+end[2])/2),.004,n=8)
 return Vector((x,top,z))

def drum(name,at,r,depth,axis=(0,1,0),lugs=8,shell='KitWalnut',heads=True):
 at=Vector(at);u,v,w=basis(axis)
 ring(name+' bent shell',at,r,r-.006,depth,shell,axis,48)
 for side in [-1,1]:
  edge=at+w*side*depth/2
  # Rolled tension hoop surrounds the skin; its opening remains real.
  ring(name+' rolled hoop '+str(side),edge+w*side*.004,r+.010,r-.006,.024,'KitNickel',axis,48)
  if heads:lathe(name+' hide membrane '+str(side),[(-.0012,r-.002),(.0012,r-.002)],edge,'KitHide',axis,48)
  for j in range(lugs):
   theta=(j+.5)*math.tau/lugs;radial=u*math.cos(theta)+v*math.sin(theta)
   body=at+radial*(r+.013)+w*side*depth*.19
   rod(name+' tension lug '+str((side,j)),body-w*.022,body+w*.022,.012,n=10)
   rod(name+' lug mounting boss '+str((side,j)),body-radial*.016,body,.010,n=10)
   rod(name+' tension bolt '+str((side,j)),body,edge+radial*(r+.013)+w*side*.016,.0032,n=8)
   rod(name+' bolt head '+str((side,j)),edge+radial*(r+.013)+w*side*.008,edge+radial*(r+.013)+w*side*.022,.006,n=6)
 contacts[name]={'position':list(at+w*(depth/2+.0012)),'normal':list(w),'radius_m':r-.026,'role':'strike surface'}

# Compact playable arrangement, bass batter points toward the seated drummer.
drum('Bass',( .18,.335,-.205),.3048,.40,(0,0,1),10)
for x in [-.105,.465]:
 rod('Bass spur',(x,.22,-.31),(x*1.35,.03,-.48),.012)
 foot('Bass spur foot',(x*1.35,0,-.48))
# Bass cradle and rack tom support are mechanically connected to the shell.
ring('Bass saddle',(.18,.335,-.205),.312,.304,.045,'KitNickel',(0,0,1),64)
rod('Rack upright',(.18,.56,-.18),(.18,.965,-.18),.014)
rod('Rack crossbar',(-.20,.935,-.18),(.45,.935,-.18),.012)
drum('RackTomLeft',(-.12,.925,-.245),.1524,.235,(0,.985,.174),6)
drum('RackTomRight',(.265,.945,-.235),.1778,.255,(0,.985,.174),8)
for x,z,y in [(-.12,-.245,.925),(.265,-.235,.945)]:
 rod('Tom bracket '+str(x),(x,.935,-.18),(x,y-.10,z),.011)
 ring('Tom bracket collar '+str(x),(x,y-.10,z),.023,.011,.025,n=16)
drum('FloorTom',(.66,.57,.14),.2032,.36,lugs=8)
for i in range(3):
 t=i*math.tau/3;u=Vector((math.cos(t),0,math.sin(t)))
 a=Vector((.66,.57,.14))+u*.209;b=Vector((.66,.03,.14))+u*.255
 rod('Floor tom leg '+str(i),a,b,.009);foot('Floor tom foot '+str(i),b)
 ring('Floor tom leg clamp '+str(i),a,.016,.009,.035,n=12)
drum('Snare',(-.285,.645,.22),.1778,.14,shell='KitNickel')
tripod('Snare basket',-.285,.22,.565,.235)
for i in range(3):
 t=i*math.tau/3;end=Vector((-.285,.575,.22))+Vector((math.cos(t)*.17,0,math.sin(t)*.17))
 rod('Snare basket arm '+str(i),(-.285,.55,.22),end,.006)
 box('Snare basket rubber '+str(i),end,(.024,.018,.024),'KitRubber')
for i in range(10):
 x=-.285+(i-4.5)*.0032
 rod('Snare wire '+str(i),(x,.572,.064),(x,.572,.376),.0007,n=6)
box('Snare throwoff',(-.472,.65,.22),(.018,.062,.035),'KitNickel')
rod('Snare throw lever',(-.486,.64,.22),(-.486,.70,.22),.004,n=8)

def cymbal(name,at,r,axis=(0,1,0),group='static'):
 # Closed 1.2mm formed bronze; crown, rolled shoulder and outward tapered bow.
 profile=[(.043,.008),(.045,r*.15),(.035,r*.24),(.012,r*.47),(0,r*.78),(-.010,r),
          (-.0115,r),(-.0015,r*.78),(.0105,r*.47),(.0335,r*.24),(.0435,r*.15),(.0415,.008)]
 lathe(name,profile,at,'KitBronze',axis,64,True,group)
 w=Vector(axis).normalized();a=Vector(at)
 rod(name+' spindle',a-w*.045,a+w*.075,.004,n=12)
 ring(name+' felt washer',a+w*.048,.015,.004,.008,'KitRubber',axis,n=24)
 rod(name+' wing nut',a+w*.061-Vector((.016,0,0)),a+w*.061+Vector((.016,0,0)),.0035,n=8)
 # Choose an actual top bow vertex on the drummer-facing side, never the hole.
 u,v,_=basis(axis);toward=Vector((0,0,1));theta=round(math.atan2(toward.dot(v),toward.dot(u))*64/math.tau)*math.tau/64
 radial=u*math.cos(theta)+v*math.sin(theta)
 contacts[name]={'position':list(a+radial*r*.78),'normal':list((w+radial*(.012/(r*.31))).normalized()),
  'radius_m':r*.15,'role':'drummer-facing strike bow; actual authored top vertex, clear of central spindle'}

tripod('Crash stand',-.69,-.37,1.08,.25)
rod('Crash boom',(-.69,1.08,-.37),(-.63,1.17,-.40),.009)
cymbal('Crash',(-.63,1.17,-.40),.2286,(.12,.985,.10))
tripod('Ride stand',.83,-.28,1.02,.25)
rod('Ride boom',(.83,1.02,-.28),(.75,1.10,-.29),.009)
cymbal('Ride',(.75,1.10,-.29),.254,(-.12,.99,.055))
tripod('HiHat stand',-.66,.15,.945,.225)
cymbal('HiHatLower',(-.66,.944,.15),.1778)
cymbal('HiHatUpper',(-.66,.965,.15),.1778,group='HiHatUpper')
pivots['HiHatUpper']={'position':[-.66,.965,.15],'axis':[0,1,0],'motion':'translate','travel_m':.021}
rod('HiHat pull rod',(-.66,.10,.15),(-.66,1.08,.15),.004)

def pedal(name,x,z,group):
 # Pivot at the heel, toe nearer the instrument; footboard stays independent.
 box(name+' base',(x,.014,z),(.10,.028,.29),'KitRubber')
 pivot=Vector((x,.04,z+.115));rot=Matrix.Rotation(math.radians(9),3,'X')
 board_center=pivot+rot@Vector((0,0,-.115))
 box(name+' footboard',board_center,(.075,.014,.25),'KitNickel',group,rot)
 rod(name+' heel pin',pivot-Vector((.052,0,0)),pivot+Vector((.052,0,0)),.006)
 pivots[group]={'position':list(pivot),'axis':[1,0,0],'motion':'rotate','rest_degrees':0,'pressed_degrees':-9}
 normal=rot@Vector((0,1,0))
 contacts[name]={'position':list(board_center+normal*.007),'normal':list(normal),'role':'foot contact on actual tilted footboard top'}
 return pivot,board_center
pedal('BassPedal',.18,.235,'BassPedal')
for side in [-1,1]:
 box('Bass pedal upright '+str(side),(.18+side*.052,.105,.09),(.014,.18,.02),'KitNickel')
rod('Bass pedal axle',(.12,.19,.09),(.24,.19,.09),.007)
rod('Bass pedal connecting link',(.18,.09,.20),(.18,.19,.09),.004,n=8)
rod('Bass beater shaft',(.18,.19,.09),(.18,.335,.035),.005,group='BassBeater')
lathe('Bass felt beater',[(-.018,.027),(.018,.027)],(.18,.335,.02),'KitHide',(0,0,1),24,group='BassBeater')
pivots['BassBeater']={'position':[.18,.19,.09],'axis':[1,0,0],'motion':'rotate','rest_degrees':0,'strike_degrees':-12}
pedal('HiHatPedal',-.52,.36,'HiHatPedal')
rod('HiHat pedal link',(-.52,.06,.25),(-.66,.11,.15),.005)
contacts['right_foot']=dict(contacts['BassPedal']);contacts['left_foot']=dict(contacts['HiHatPedal'])

tripod('Throne',0,.72,.52,.265)
lathe('Throne upholstered seat',[(-.034,.185),(-.024,.195),(.025,.195),(.034,.182)],(0,.555,.72),'KitSeat',n=48)
ring('Throne edge piping',(0,.552,.72),.198,.194,.008,'KitRubber',n=64)
contacts['seat']={'position':[0,.589,.72],'normal':[0,1,0],'role':'pelvis support; fit the actual cast rig separately'}
contacts['performer_forward']={'direction':[0,0,-1]}
contacts['standing_approach']={'position':[0,0,1.35],'role':'layout reservation outside kit footprint; not collision qualification'}
# Resting sticks on the snare, separately selectable and anchored at the grip.
for name,a,b in [('StickLeft',(-.37,.733,.32),(-.20,.733,-.035)),('StickRight',(-.38,.746,.06),(-.16,.746,.39))]:
 a,b=Vector(a),Vector(b);w=(b-a).normalized();length=(b-a).length
 lathe(name,[(0,.006),(length*.68,.0055),(length*.91,.0035),(length*.95,.005),(length,.003)],a,'KitSticks',w,12,group=name)
 pivots[name]={'position':list(a+w*.10),'axis':[1,0,0],'motion':'held prop; bind to existing hand target without adding bones'}
 contacts[name]={'position':list(a+w*.10),'tip':list(b),'role':'grip and tip; runtime must validate actual hand contact'}

# Construct metric UVs and tangent guides through the shared validated exporter.
partitions=[]
groups=collections.defaultdict(list)
for obj,key,group in pieces:groups[(group,key)].append(obj)
for (group,key),objects in sorted(groups.items()):
 name='DrumKit_'+group+'_'+key
 obj=partition(draws,name,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
 if group in pivots:
  p=C.to_3x3()@Vector(pivots[group]['position'])
  for vertex in obj.data.vertices:vertex.co-=p
  obj.matrix_world=Matrix.Translation(p)
 partitions.append({'mesh':name,'materials':[key],'group':group,'triangles':len(obj.data.polygons)})
stock.hide_render=True;stock.hide_viewport=True
bpy.context.view_layer.update()
proof=export(ROOT,FAMILY,draws,material_names_only=True)
assert proof['status']=='PASS' and proof['triangles']<32000 and proof['primitives']<=15,proof
assert proof['triangles']==sum(row['triangles'] for row in partitions),'Export lost triangles'
all_points=np.array([C.inverted().to_3x3()@v.co for obj,_,_ in pieces for v in obj.data.vertices])
lo=all_points.min(axis=0);hi=all_points.max(axis=0)
assert lo[1]>=-1e-6 and hi[0]-lo[0]<2.2 and hi[2]-lo[2]<2.0,(lo,hi)
runtime={'schema_version':1,'asset':'res://assets/props/harukiya_drumkit.glb','coordinates':'Godot metres; Y up; performer at +Z facing -Z',
 'aabb':{'min':lo.tolist(),'max':hi.tolist(),'size':(hi-lo).tolist()},'partitions':partitions,
 'materials':[dict(key=k,**f,meters_per_tile=catalog[f['catalog_key']]['meters_per_tile']) for k,f in finishes.items()],
 'contacts':contacts,'pivots':pivots,'floor_supports':supports,
 'integration':'Root assembly transform applies exactly once. Named moving groups preserve local pivots. No collisions, scripts, animation, sound or gameplay authority are authored here.'}
outputs[3].write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[Path(__file__),catalog_path]+[ROOT/'art/blender/scripts'/n for n in ['fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_uvs.py','fabrication_normals.py','fabrication_grain.py','check_exported_tangents.py']]
bindings+=list({ROOT/'game/assets/building/textures'/p for f in finishes.values() for p in catalog[f['catalog_key']]['files']})
inventory={'evidence_class':'INERT','status':'native_export_pass','original_modeling':True,'blender_version':bpy.app.version_string,
 'closed_stock_count':len(checks),'closed_stocks':checks,'aabb':runtime['aabb'],'runtime_triangles':proof['triangles'],
 'draw_surfaces':proof['primitives'],'tangent_check':proof,'asset_sha256':sha(outputs[2]),'blend_sha256':sha(outputs[0]),
 'data_sha256':sha(outputs[3]),'source_bindings':{p.relative_to(ROOT).as_posix():sha(p) for p in bindings},
 'no_new_images':True,'native_review':'pending','runtime_import_and_loaded_mips':'pending root room family integration',
 'contact_status':'Measured static targets only; actual cast reach, seating and performed contacts remain unqualified.'}
outputs[1].write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8',newline='\n')
(args.report/'NATIVE_BUILD.json').write_text(json.dumps(inventory,indent=2))
(args.report/'CONTACTS.json').write_text(json.dumps(runtime,indent=2))
print('DRUMKIT_NATIVE_PASS',json.dumps({k:inventory[k] for k in ['closed_stock_count','runtime_triangles','draw_surfaces','aabb']}),flush=True)

if args.render:
 # Reopen the actual saved blend rather than reviewing only in-memory geometry.
 bpy.ops.wm.open_mainfile(filepath=str(outputs[0]));scene=bpy.context.scene
 scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
 scene.cycles.device='CPU';scene.render.threads_mode='FIXED';scene.render.threads=8
 scene.render.resolution_x=1280;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
 scene.view_settings.view_transform='AgX'
 scene.world=bpy.data.worlds.new('Neutral drumkit review');scene.world.use_nodes=True
 scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.35,.4,1)
 scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
 # Diagnostic ground is render-only and is never saved/exported.
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.005))
 floor=bpy.context.object;floor.name='Review ground only'
 mat=bpy.data.materials.new('Review neutral ground');mat.diffuse_color=(.18,.18,.18,1);floor.data.materials.append(mat)
 aim=C.to_3x3()@Vector((0,.62,.03));lights=[]
 for location,power,size in [((-2,3,2),450,3),((2,2,-2),300,2.5),((0,3,-1),220,2)]:
  bpy.ops.object.light_add(type='AREA',location=C.to_3x3()@Vector(location));o=bpy.context.object
  o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(aim-o.location).to_track_quat('-Z','Y').to_euler();lights.append(o)
 views=[]
 for name,position in [('audience_three_quarter',(2.8,2.35,-3.6)),('drummer',(-1.6,2.1,3.1)),('front',(0,1.35,-4.1)),('overhead',(0,4.3,.05))]:
  bpy.ops.object.camera_add(location=C.to_3x3()@Vector(position));cam=bpy.context.object;cam.data.lens=46
  cam.rotation_euler=(aim-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
  path=args.report/(name+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
  views.append({'id':name,'file':str(path),'sha256':sha(path),'position_godot_m':list(position)})
  bpy.data.objects.remove(cam,do_unlink=True)
 (args.report/'NATIVE_VIEWS.json').write_text(json.dumps({'status':'captured_not_yet_reviewed','blend_sha256':sha(outputs[0]),'views':views},indent=2))
print('DRUMKIT_COMPLETE_SECONDS',round(time.time()-started,2),flush=True)
