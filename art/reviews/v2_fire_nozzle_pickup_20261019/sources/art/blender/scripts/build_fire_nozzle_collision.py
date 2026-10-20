"""Native collision-only reduction of the receiving nut. Render stock unchanged.
Sample both surfaces and retain the measured bearing planes and open bore.
"""
from pathlib import Path
from itertools import combinations
import bpy,bmesh,json,math,hashlib,os,shutil
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_NOZZLE_COLLISION_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/nozzle_collision_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp');OUT.mkdir(parents=True,exist_ok=True)
if os.environ.get('ORISON_FIRE_NOZZLE_COLLISION_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for name,digest in report['source_bindings'].items():
        p=ROOT/name;raw=p.read_bytes().replace(b'\r\n',b'\n') if p.suffix=='.py' else p.read_bytes()
        assert hashlib.sha256(raw).hexdigest()==digest,name
    for name,digest in report['outputs'].items():assert hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest,name
    shutil.copy2(OUT/'fire_nozzle_collision.blend',ROOT/'art/blender/fire_nozzle_collision.blend')
    shutil.copy2(OUT/'runtime_projection.json',ROOT/'game/data/orison_v2/fire_nozzle_collision.json')
    shutil.copy2(OUT/'construction.json',ROOT/'art/blender/fire_nozzle_collision_construction.json')
    print('FIRE NOZZLE COLLISION PUBLISH PASS');raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_nozzle_joint.blend'),link=False) as (available,loaded):loaded.objects=['NozzleNut_Editable','NozzleSpigot_Editable']
source=loaded.objects[0];assert source is not None;bpy.context.collection.objects.link(source)
male=loaded.objects[1];assert male is not None;bpy.context.collection.objects.link(male)
bm=bmesh.new();bm.from_mesh(source.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(source.data);bm.free()
obj=source.copy();obj.data=source.data.copy();obj.name='EditableReceivingNutCollision';bpy.context.collection.objects.link(obj)
bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Collision-only measured reduction','DECIMATE');mod.ratio=.125;mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
def tree(o):return BVHTree.FromPolygons([v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons])
def samples(o):
    for v in o.data.vertices:yield v.co
    for e in o.data.edges:yield sum((o.data.vertices[i].co for i in e.vertices),Vector())*.5
    for f in o.data.polygons:yield sum((o.data.vertices[i].co for i in f.vertices),Vector())/len(f.vertices)
original,reduced=tree(source),tree(obj)
forward=max(reduced.find_nearest(p)[3] for p in samples(source))
reverse=max(original.find_nearest(p)[3] for p in samples(obj))
assert max(forward,reverse)<.000075,(forward,reverse)
bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
assert bad==0 and volume>0,(bad,volume)
def b(x,y,z):return Vector((x,-z,y))
bearings=0
for y,r,dy in [(.005,.025,-1),(.014,.0205,1),(.029,.025,1)]:
    for i in range(16):
        a=math.tau*i/16;at=b(r*math.cos(a),y-dy*.0002,r*math.sin(a));direction=b(0,dy,0)
        p=original.ray_cast(at,direction,.001)[0];q=reduced.ray_cast(at,direction,.001)[0]
        assert p is not None and q is not None and abs(p.z-y)<.0001 and abs(q.z-y)<.0001 and (p-q).length<.0001,(y,i,p,q)
        bearings+=1
bores=0
for target in [original,reduced]:
    for i in range(17):
        a=math.tau*i/16;r=0 if i==16 else .02015
        assert target.ray_cast(b(r*math.cos(a),0,r*math.sin(a)),b(0,1,0),.04)[0] is None
        bores+=1
    assert target.ray_cast(b(.025,0,0),b(0,1,0),.04)[0] is not None
# Certify an empty cylinder in front of the internal bearing shoulder.
# Clip every triangle to this axial interval and measure the minimum radius
# of its complete projected polygon, not only sampled vertices.
free_start,free_end,free_radius=.017,.029,.02165
def clip(points,height,above):
    result=[]
    for a,c in zip(points,points[1:]+points[:1]):
        ai=(a.z>=height) if above else (a.z<=height);ci=(c.z>=height) if above else (c.z<=height)
        if ai:result.append(a)
        if ai!=ci:result.append(a.lerp(c,(height-a.z)/(c.z-a.z)))
    return result
def cross(a,c):return a.x*c.y-a.y*c.x
minimum=math.inf
for face in obj.data.polygons:
    polygon=clip(clip([obj.data.vertices[i].co.copy() for i in face.vertices],free_start,True),free_end,False)
    if not polygon:continue
    flat=[Vector((p.x,p.y)) for p in polygon]
    signs=[cross(a,c) for a,c in zip(flat,flat[1:]+flat[:1])]
    area=abs(sum(signs))
    assert not (area>1e-15 and (min(signs)>=0 or max(signs)<=0)),'projected surface crosses bore axis'
    for a,c in zip(flat,flat[1:]+flat[:1]):
        edge=c-a;t=max(0.,min(1.,-a.dot(edge)/edge.length_squared)) if edge.length_squared else 0.
        minimum=min(minimum,(a+edge*t).length)
assert minimum>=free_radius,(minimum,free_radius)
# A kinematic entry guide precedes helical engagement. Certify the entire
# centred insertion interval against actual source triangles, independently
# of nut/body azimuth: slab inner-radius lower bounds exceed swept male
# outer-radius upper bounds. This is continuous geometry, not pose sampling.
joint_path=ROOT/'game/data/orison_v2/fire_nozzle_joint.json'
d=json.loads(joint_path.read_text())['dimensions']
pilot_max=d['nozzle_base_y_m']+d['withdrawal_m']
pilot_min=pilot_max-d['pitch_m']*.5+.00012
def triangles(o):
 # Native quads can be nonplanar. Cover every triangulation instead of
 # assuming the clipping of a four-vertex polygon covers both diagonals.
 return [(min(p.z for p in vs),max(p.z for p in vs),vs) for f in o.data.polygons
         for indices in combinations(f.vertices,3)
         for vs in [[o.data.vertices[i].co.copy() for i in indices]]]
female_faces,male_faces=triangles(source),triangles(male)
def clipped(faces,low,high):
 for minimum_z,maximum_z,vs in faces:
  if maximum_z<low or minimum_z>high:continue
  polygon=clip(clip(vs,low,True),high,False)
  if polygon:yield polygon
def inner_radius(polygon):
 result=math.inf
 for a,c in zip(polygon,polygon[1:]+polygon[:1]):
  a,c=Vector((a.x,a.y)),Vector((c.x,c.y));edge=c-a
  t=max(0.,min(1.,-a.dot(edge)/edge.length_squared)) if edge.length_squared else 0.
  result=min(result,(a+edge*t).length)
 return result
low=min(v.co.z for v in male.data.vertices)+pilot_min
count=math.ceil((free_end-low)/.00001);pilot_gap=math.inf
for i in range(count):
 a=low+(free_end-low)*i/count;c=low+(free_end-low)*(i+1)/count
 inner=min(inner_radius(poly) for poly in clipped(female_faces,a,c))
 outer=max(math.hypot(p.x,p.y) for poly in clipped(male_faces,a-pilot_max,c-pilot_min) for p in poly)
 pilot_gap=min(pilot_gap,inner-outer)
assert pilot_gap>.00002,('uncertified pilot clearance',pilot_gap)
tip=min(v.co.z for v in male.data.vertices)
entry_radius=min(inner_radius(poly) for poly in clipped(female_faces,free_end-.00001,free_end))-max(math.hypot(p.x,p.y) for poly in clipped(male_faces,tip,tip+.00001) for p in poly)-.00002
assert entry_radius>d['radial_clearance_m']
for o in [source,obj,male]:o.data.materials.clear()
source.hide_render=True;source.hide_viewport=True
male.hide_render=True;male.hide_viewport=True
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fire_nozzle_collision.blend'))
# Godot's imported collision triangles use clockwise faces. The Blender
# source uses counterclockwise outward faces; reverse explicitly on transfer.
projection=dict(schema_version=1,source_asset='res://assets/props/fire_nozzle_joint.glb',clearance_start_m=free_start,clearance_end_m=free_end,clearance_radius_m=free_radius,pilot_origin_min_m=pilot_min,pilot_origin_max_m=pilot_max,pilot_clearance_m=pilot_gap,pilot_entry_radius_m=entry_radius,vertices=[[v.co.x,v.co.z,-v.co.y] for v in obj.data.vertices],indices=[i for f in obj.data.polygons for i in reversed(f.vertices)])
(OUT/'runtime_projection.json').write_text(json.dumps(projection,separators=(',',':'))+'\n')
paths=[Path(__file__).resolve(),ROOT/'art/blender/fire_nozzle_joint.blend',ROOT/'game/assets/props/fire_nozzle_joint.glb',joint_path]
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix=='.py' else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Collision-only, no render change or runtime acceptance. Distances are sampled, not a global Hausdorff proof.',source_bindings=bindings,source_triangles=len(source.data.polygons),collision_triangles=len(obj.data.polygons),sampled_source_to_collision_m=forward,sampled_collision_to_source_m=reverse,minimum_clipped_surface_radius_m=minimum,nonmanifold_edges=bad,volume_m3=volume,bearing_rays=bearings,clear_bore_rays=bores,outputs={n:hashlib.sha256((OUT/n).read_bytes()).hexdigest() for n in ['fire_nozzle_collision.blend','runtime_projection.json']})
report['pilot_guide']=dict(origin_min_m=pilot_min,origin_max_m=pilot_max,minimum_clearance_m=pilot_gap,entry_radius_m=entry_radius,axial_slabs=count,scope='Complete clipped-surface radial bounds; all axial positions in interval and all relative rotations, centred axis only. Entry radius measures mouth/tip clearance, not a swept off-axis certificate.')
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('FIRE NOZZLE COLLISION NATIVE PASS',json.dumps(report))
