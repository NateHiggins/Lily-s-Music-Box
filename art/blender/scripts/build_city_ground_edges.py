"""External/installed source-fitted low retaining toe; no ground or runtime writes.

Blender --background --threads 1 --python-exit-code 1 --python THIS --
  --source-root REPO --out DELIVERY [--review]
The two authored inputs are this file and city_ground_edges/source_plan.json.
"""
import argparse,collections,hashlib,json,math,pathlib,random,sys,time
import bpy,bmesh
sys.dont_write_bytecode=True
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

args=argparse.ArgumentParser();args.add_argument('--source-root',type=pathlib.Path);args.add_argument('--out',type=pathlib.Path);args.add_argument('--review',action='store_true')
options=args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ROOT=(options.source_root or pathlib.Path(__file__).resolve().parents[3]).resolve();OUT=(options.out or ROOT).resolve()
assert (ROOT/'game/project.godot').is_file()
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
from city_ground_apron_geometry import relief_height
plan_path=OUT/'art/data/city_ground_edges/source_plan.json';plan=json.loads(plan_path.read_bytes())
assert plan['schema']=='orison.city-ground-edges.v1' and plan['frame']=='ORISON_V2_BUILDING_FRAME'
assert plan['along_z_m']==[-16.,16.] and plan['panel_length_m']==4.
finish=plan['finish'];catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
anchor=Vector((plan['anchor_xyz_m'][0],-plan['anchor_xyz_m'][2],plan['anchor_xyz_m'][1]));FRAME=Matrix.Translation(anchor)
relief=json.loads((ROOT/'art/data/city_ground_apron/source_plan.json').read_bytes())['relief']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
def native(x,y,z):return Vector((x,-z,y))
def tree(objects):
 vv=[];ff=[]
 for obj in objects:
  obj.data.calc_loop_triangles();start=len(vv);vv.extend(obj.matrix_world@v.co for v in obj.data.vertices);ff.extend(tuple(start+i for i in t.vertices) for t in obj.data.loop_triangles)
 return BVHTree.FromPolygons(vv,ff,all_triangles=True)
def object_triangle_count(obj):obj.data.calc_loop_triangles();return len(obj.data.loop_triangles)
def load_ground():
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/city_ground_apron.glb'));objects=[o for o in set(bpy.data.objects)-before if o.type=='MESH'];assert objects
 bpy.context.view_layer.update();return objects,tree(objects)
def top(z):return plan['terminal_top_y_m']+(plan['face_top_y_m']-plan['terminal_top_y_m'])*min(1.,(z+16)/plan['end_taper_length_m'],(16-z)/plan['end_taper_length_m'])
def build():
 started=time.perf_counter();bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
 admission_path=OUT/'ADMISSION_02.json';admission=json.loads(admission_path.read_bytes())
 for name,expected in admission['source_bindings'].items():assert sha(ROOT/name)==expected,('Admission source drift',name)
 ground,receiving=load_ground();receiving_records=[]
 # These actual imported ground faces are proof inputs only, never exported.
 for z in range(-16,17,2):
  for x in [-320.4,-320.05,-319.55,-319.4]:
   expected=relief_height(x,z,-.02,relief);hit,*_=receiving.ray_cast(native(x,expected+.3,z),Vector((0,0,-1)),1.)
   assert hit is not None and abs(hit.z-expected)<.0001,(x,z,hit,expected)
   wrong=native(x,expected+.01,z);assert (hit-wrong).length>.0001
   receiving_records.append(dict(building_xyz_m=[x,expected,z],actual_native_hit=list(hit),wrong_height_m=.01))
 for obj in ground:bpy.data.objects.remove(obj,do_unlink=True)
 levels=[];closed_sets=[]
 for level in [0,1]:
  closed=bpy.data.collections.new('EditableClosed_L'+str(level));bpy.context.scene.collection.children.link(closed);closed.hide_render=True
  exports=bpy.data.collections.new('CityGroundEdges_L'+str(level));bpy.context.scene.collection.children.link(exports)
  mat=material(ROOT,'GroundEdgeConcrete_L'+str(level),finish,catalog);objects=[];records=[];panels={}
  def stock(name,vertices,faces,role,bevel=None):
   bm=bmesh.new();verts=[bm.verts.new(native(*p)-anchor) for p in vertices]
   for f in faces:bm.faces.new([verts[i] for i in f])
   bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));amount=(plan['near_bevel_m'] if level==0 else plan['lower_bevel_m']) if bevel is None else bevel
   if amount:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=amount,segments=3 if level==0 else 1,affect='EDGES',clamp_overlap=True)
   bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges),(name,'closed stock')
   volume=bm.calc_volume(signed=True);assert volume>1e-7,(name,volume)
   mesh=bpy.data.meshes.new(name);bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new('L'+str(level)+'_'+name,mesh);closed.objects.link(obj);obj.matrix_world=FRAME;objects.append(obj)
   pts=[native(*p) for p in vertices];records.append(dict(id=name,role=role,positive_volume_m3=volume,source_bounds_native=[min(p[i] for p in pts) for i in range(3)]+[max(p[i] for p in pts) for i in range(3)],triangles=object_triangle_count(obj)))
   envelope=plan['provisional_admission_envelope_xyz_m'];assert all(all(envelope[j]<=p[j]<=envelope[j+3] for j in range(3)) for p in vertices),(name,'outside admitted construction envelope')
   return obj
  faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
  def prism(name,x,X,z,Z,low0,low1,high0,high1,role,bevel=None):
   return stock(name,[(x,low0,z),(X,low0,z),(X,low1,Z),(x,low1,Z),(x,high0,z),(X,high0,z),(X,high1,Z),(x,high1,Z)],faces,role,bevel)
  for i in range(8):
   start=-16+i*4;end=start+4;z=start+plan['joint_m']/2;Z=end-plan['joint_m']/2
   fx,fy,fX,fY=plan['footing_rect_xy_m'];foot=prism('Footing_'+str(i),fx,fX,start,end,fy,fy,fY,fY,'buried footing',.003)
   stem=prism('Panel_'+str(i),plan['stem_front_x_m'],plan['stem_back_x_m'],z,Z,plan['stem_bottom_y_m'],plan['stem_bottom_y_m'],top(z),top(Z),'low retaining toe')
   over=plan['cap_overhang_m'];cap_low=.015-plan['cap_thickness_m'];cap=prism('Coping_'+str(i),plan['stem_front_x_m']-over,plan['stem_back_x_m']+over,z,Z,top(z)+cap_low,top(Z)+cap_low,top(z)+.015,top(Z)+.015,'jointed coping')
   panels[i]=(foot,stem,cap)
  rng=random.Random(plan['seed'])
  for i in range(plan['concrete_fragments']):
   x=-321.15+rng.uniform(-.18,.18);z=-14.5+i*29/11+rng.uniform(-.35,.35);rx=rng.uniform(.09,.16);rz=rng.uniform(.12,.23);height=rng.uniform(.09,.19)
   n=8 if level==0 else 4;angle=rng.uniform(0,math.pi);points=[]
   for y,radius in [(-3.55,1.),(-3.5+height,.72)]:
    points.extend((x+rx*radius*math.cos(angle+j*2*math.pi/n),y,z+rz*radius*math.sin(angle+j*2*math.pi/n)) for j in range(n))
   f=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
   stock('ConcreteFragment_'+str(i),points,f,'buried concrete fragment',.003 if level==0 else 0.)
  bpy.context.view_layer.update();contacts=[]
  for i,(foot,stem,cap) in panels.items():
   z=-14+i*4;x=(plan['stem_front_x_m']+plan['stem_back_x_m'])/2
   for carrier,expected,name in [(foot,plan['footing_rect_xy_m'][3],'footing'),(stem,top(z),'panel')]:
    carrier_tree=tree([carrier]);p=native(x,expected,z);hit,*_=carrier_tree.ray_cast(p+Vector((0,0,.02)),Vector((0,0,-1)),.04)
    assert hit is not None and (hit-p).length<.0001,(i,name,hit,p)
    outside=native(plan['footing_rect_xy_m'][0]-.05,expected,z);miss,*_=carrier_tree.ray_cast(outside+Vector((0,0,.02)),Vector((0,0,-1)),.04);assert miss is None
    contacts.append(dict(panel=i,carrier=name,point_native=list(p),hit_native=list(hit),outside_native=list(outside)))
   assert plan['stem_bottom_y_m']<plan['footing_rect_xy_m'][3] and top(z)-.04<top(z)
  # Footing base must be embedded across its entire footprint, not hovering
  # above the slope at a chosen center. Actual ground is piecewise planar here.
  burial=[]
  for i in range(8):
   for x in [plan['footing_rect_xy_m'][0],plan['footing_rect_xy_m'][2]]:
    for z in [-16+i*4,-12+i*4]:
     depth=relief_height(x,z,-.02,relief)-plan['footing_rect_xy_m'][1];assert depth>.2;burial.append(dict(panel=i,x=x,z=z,burial_m=depth))
  ends=[]
  for i,z in [(0,-15.98),(7,15.98)]:
   cap_tree=tree([panels[i][2]])
   for x in [plan['stem_front_x_m']+.08,plan['stem_back_x_m']-.08]:
    expected=top(z)+.015;p=native(x,expected,z);hit,*_=cap_tree.ray_cast(p+Vector((0,0,.02)),Vector((0,0,-1)),.04);assert hit is not None and (hit-p).length<.0001
    ground_y=relief_height(x,z,-.02,relief);reveal=hit.z-ground_y;assert reveal<.04
    ends.append(dict(panel=i,point_native=list(hit),receiving_grade_y_m=ground_y,exposed_height_m=reveal))
  draw=partition(exports,f'{plan["id"]}_L{level}__concrete',objects,finish,mat,FRAME,catalog)
  # Partition() reads local stock coordinates; each native stock carries the
  # same frame for editing, and the export applies that frame exactly once.
  bpy.context.view_layer.update();family='city_ground_edges'+('_lod1' if level else '')
  (OUT/'game/assets/props').mkdir(parents=True,exist_ok=True);(OUT/'art/blender').mkdir(parents=True,exist_ok=True)
  proof=export(OUT,family,exports,save_native=False)
  exports.hide_render=bool(level);levels.append(dict(level=level,part=draw.name,asset=f'game/assets/props/{family}.glb',sha256=sha(OUT/f'game/assets/props/{family}.glb'),bytes=(OUT/f'game/assets/props/{family}.glb').stat().st_size,triangles=object_triangle_count(draw),closed_stocks=records,carrier_contacts=contacts,buried_footprint_stations=burial,end_transitions=ends,export_check=proof));closed_sets.append(closed)
 assert levels[1]['triangles']<levels[0]['triangles'];assert len(levels[0]['closed_stocks'])==len(levels[1]['closed_stocks'])==36
 for image in bpy.data.images:
  if image.source=='FILE':image.filepath=str(ROOT/'game/assets/building/textures'/pathlib.Path(image.filepath).name)
 for closed in closed_sets:closed.hide_viewport=True
 native_path=OUT/'art/blender/city_ground_edges.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native_path),compress=True)
 paths=[ROOT/p for p in ['art/data/city_ground_apron/source_plan.json','game/assets/props/city_ground_apron.glb','game/data/orison_v2/ground_finish.json','game/data/runtime_material_sets.json']]+[ROOT/'art/blender/scripts'/p for p in ['city_ground_apron_geometry.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','fabrication_uvs.py','check_exported_tangents.py']]
 report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],body_lod_error_m=plan['lod_error_m'],reference_guidance=plan['reference_guidance'],levels=levels,native=str(native_path.relative_to(OUT)),native_sha256=sha(native_path),admission_sha256=sha(admission_path),actual_ground_stations=receiving_records,source_bindings={str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in paths},producer_sha256=sha(pathlib.Path(__file__)),plan_sha256=sha(plan_path),maps_external={name:dict(sha256=sha(ROOT/'game/assets/building/textures'/name),colour_space='sRGB' if i==0 else 'linear') for i,name in enumerate(catalog['concrete']['files'])},build_elapsed_s=time.perf_counter()-started,failures=[])
 write(OUT/'NATIVE_CONSTRUCTION.json',report);print('NATIVE BUILD PASS',[(r['level'],r['triangles'],r['bytes']) for r in levels],flush=True)

def review():
 report=json.loads((OUT/'NATIVE_CONSTRUCTION.json').read_bytes());assert sha(OUT/report['native'])==report['native_sha256'];bpy.ops.wm.open_mainfile(filepath=str(OUT/report['native']))
 def triangles(obj):
  obj.data.calc_loop_triangles();return collections.Counter(tuple(sorted(tuple(obj.matrix_world@obj.data.vertices[i].co) for i in t.vertices)) for t in obj.data.loop_triangles)
 def corners(obj):
  result=collections.defaultdict(list);obj.data.calc_loop_triangles();uv=obj.data.uv_layers.active.data
  for t in obj.data.loop_triangles:
   values=sorted((tuple(obj.matrix_world@obj.data.vertices[i].co),tuple(uv[l].uv)) for i,l in zip(t.vertices,t.loops));result[tuple(p for p,u in values)].append(tuple(u for p,u in values))
  return result
 roundtrips=[];maximum=0.
 for r in report['levels']:
  source=bpy.data.objects[r['part']];a=triangles(source);uv=corners(source);before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(OUT/r['asset']));new=[o for o in set(bpy.data.objects)-before if o.type=='MESH'];assert len(new)==1;obj=new[0];bpy.context.view_layer.update();assert a==triangles(obj)
  actual=corners(obj);assert uv.keys()==actual.keys()
  for key,values in uv.items():
   assert len(values)==len(actual[key])
   for x,y in zip(sorted(values),sorted(actual[key])):
    for u,v in zip(x,y):
     for U,V in zip(u,v):
      drift=abs(U-V);assert drift<=4*2**-23*max(abs(U),1.);maximum=max(maximum,drift)
  for o in set(bpy.data.objects)-before:bpy.data.objects.remove(o,do_unlink=True)
  roundtrips.append(dict(part=r['part'],world_triangles_exact=True,triangles=r['triangles'],uv_corners_compared=True))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8;scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=1
 scene.cycles.denoising_use_gpu=False
 scene.render.resolution_x=1000;scene.render.resolution_y=640;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
 world=bpy.data.worlds.new('Diagnostic neutral daylight');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1);world.node_tree.nodes['Background'].inputs[1].default_value=.65
 sun_data=bpy.data.lights.new('ReviewSun','SUN');sun_data.energy=2.5;sun=bpy.data.objects.new('ReviewSun',sun_data);scene.collection.objects.link(sun);sun.rotation_euler=(.45,-.4,-.7)
 ground,_=load_ground();soil=json.loads((ROOT/'art/data/city_ground_apron/source_plan.json').read_bytes())['relief']['finishes']
 # Flat apron asphalt has its own existing ground-finish owner; it is not
 # one of relief.finishes. Bind it explicitly, never use a plain fallback.
 asphalt=json.loads((ROOT/'game/data/orison_v2/ground_finish.json').read_bytes());soil['asphalt']=dict(asphalt,catalog_key='asphalt',pigment=1.)
 materials={k:material(ROOT,'Receiving_'+k,v,catalog) for k,v in soil.items()}
 for obj in ground:
  key=obj.name.split('__')[-1].split('.')[0];assert key in materials,key;obj.data.materials.clear();obj.data.materials.append(materials[key])
 camera_data=bpy.data.cameras.new('NativeReviewCamera');camera=bpy.data.objects.new('NativeReviewCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
 poses=[('overview',(-341.,-30.,11.),(-320.,0.,-3.2),35.),('close',(-323.2,-3.,-1.65),(-320.,0.,-3.2),40.),('end',(-323.,18.,-1.55),(-320.,14.,-3.25),40.),('back',(-315.,2.,-.5),(-320.,0.,-3.2),38.)];captures=[]
 for level in [0,1]:
  bpy.data.collections['CityGroundEdges_L0'].hide_render=bool(level);bpy.data.collections['CityGroundEdges_L1'].hide_render=not bool(level)
  for label,at,target,lens in poses if level==0 else poses[:2]:
   camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.lens=lens;scene.render.filepath=str(OUT/'review'/f'L{level}_{label}.png');(OUT/'review').mkdir(exist_ok=True)
   bpy.context.view_layer.update();bpy.ops.render.render(write_still=True);p=pathlib.Path(scene.render.filepath);captures.append(dict(file=str(p.relative_to(OUT)),sha256=sha(p),level=level,pose=label))
 write(OUT/'NATIVE_REVIEW.json',dict(evidence_class='INERT',scope='Actual reopened native/imported GLBs,exact triangles/per-corner metricUV within4float32ULP andCPU diagnostic daylight against actual unchanged receiving ground;not Godot loaded mips/collision/access/performance/art acceptance',roundtrips=roundtrips,max_uv_roundtrip_drift_m=maximum,captures=captures,device='CPU',threads=1,samples=8,native_file_unchanged=sha(OUT/report['native'])==report['native_sha256'],failures=[]))
 print('NATIVE REOPEN/GLB/CPU REVIEW PASS',len(captures),'captures',flush=True)
if __name__=='__main__':
 if not options.review:build()
 review()
