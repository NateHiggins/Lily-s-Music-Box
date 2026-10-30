"""Reopen saved station stock: native walk/headroom/road checks and honest previews."""
from pathlib import Path
import hashlib,json,math,os,re,sys
import bpy,bmesh
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
OUT=Path(os.environ['CITY_TRANSPORT_REVIEW']);OUT.mkdir(parents=True,exist_ok=True)
def sha(path):
    raw=path.read_bytes()
    return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.py','.gd','.json'] else raw).hexdigest()
paths=[ROOT/'art/blender/city_transport.blend',ROOT/'art/blender/city_transport_construction.json',ROOT/'art/data/city_transport/source_plan.json',ROOT/'game/scripts/player/player_controller.gd',Path(__file__)]
hashes={p.relative_to(ROOT).as_posix():sha(p) for p in paths}
plan=json.loads(paths[2].read_text());s=plan['station'];meta=json.loads(paths[1].read_text());preview=plan['preview']
source=paths[3].read_text();height=float(re.search(r'const STANDING_HEIGHT := ([0-9.]+)',source)[1]);radius=float(re.search(r'const BODY_RADIUS := ([0-9.]+)',source)[1]);eye=float(re.search(r'const STANDING_EYE := ([0-9.]+)',source)[1])
bpy.ops.wm.open_mainfile(filepath=str(paths[0]))
lod_objects=[];closed_counts=[]
for lod in range(2):
    objects=list(bpy.data.collections['TransportExports_LOD'+str(lod)].objects);lod_objects.append(objects)
    closed=list(bpy.data.collections['ClosedConstruction_LOD'+str(lod)].objects);closed_counts.append(len(closed))
    for obj in closed:
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,obj.name
        bm.free()
    bpy.data.collections['ClosedConstruction_LOD'+str(lod)].hide_render=True
    bpy.data.collections['TransportExports_LOD'+str(lod)].hide_render=bool(lod)
bpy.context.view_layer.update()
def tree(objects):
    vertices=[];faces=[];names=[]
    for obj in objects:
        start=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(start+i for i in p.vertices) for p in obj.data.polygons);names.extend([obj.name]*len(obj.data.polygons))
    return BVHTree.FromPolygons(vertices,faces),names
bvh,names=tree(lod_objects[0]);failures=[];checks=[]
def check(ok,label,**detail):
    checks.append(dict(passed=bool(ok),label=label,**detail))
    if not ok:failures.append(checks[-1])
for contact in meta['contacts']:
    point=Vector(contact['point']);n=Vector(contact['normal'])
    hit,normal,index,distance=bvh.ray_cast(point+n*.03,-n,.06)
    check(hit is not None and (hit-point).length<.0001,'column/base plate face',id=contact['id'],hit=list(hit) if hit is not None else None)
for route in meta['stair_routes']:
    x,y,low=route['from_m'];high=route['to_m'][2];rise=route['riser_m'];tread=route['tread_m'];count=round((high-low)/(2*rise))
    cfg=s['entry_stair'] if route['id']=='PublicEntry' else s['platform_stairs'];width=cfg['flight_width_m'];lane=width+cfg['well_gap_m'];run=count*tread
    for flight in range(2):
        sign=1 if flight==0 else -1;start=x if not flight else x+run;cy=y+flight*lane;base=low+flight*(high-low)/2
        for i in range(count):
            p=Vector((start+sign*(i+.5)*tread,cy,base+(i+1)*rise))
            for dy in [-radius*.8,0,radius*.8]:
                at=p+Vector((0,dy,0));hit,normal,index,distance=bvh.ray_cast(at+Vector((0,0,.03)),Vector((0,0,-1)),.06)
                check(hit is not None and (hit-at).length<.0001 and normal.z>.99,'actual tread support',stair=route['id'],flight=flight,step=i,offset_m=dy)
                roof,normal,index,distance=bvh.ray_cast(at+Vector((0,0,.015)),Vector((0,0,1)),height+.025)
                check(roof is None,'standing headroom through stair opening',stair=route['id'],flight=flight,step=i,offset_m=dy,obstruction=names[index] if roof is not None else None,hit=list(roof) if roof is not None else None)
for lane in [-17.,-21.8]:
    for offset in [-1.4,-.7,0,.7,1.4]:
        for x in range(27,107,2):
            hit,normal,index,distance=bvh.ray_cast(Vector((x,lane+offset,0)),Vector((0,0,1)),5.5)
            check(hit is None,'carriageway clear below station',x=x,lane=lane,offset_m=offset,obstruction=names[index] if hit is not None else None)
envelope=s['rail_clearance_envelope']
for level,rail in enumerate(s['rail_top_m']):
    for cy in s['track_y_m']:
        for lateral in [-envelope['half_width_m'],0,envelope['half_width_m']]:
            for step in range(round((s['x_ends_m'][1]-s['x_ends_m'][0])*2)+1):
                x=s['x_ends_m'][0]+step*.5
                hit,n,index,distance=bvh.ray_cast(Vector((x,cy+lateral,rail+.02)),Vector((0,0,1)),envelope['height_m']-.02)
                check(hit is None,'authored rolling-stock clearance',level=level,x=x,track_y=cy,lateral=lateral,obstruction=names[index] if hit is not None else None,hit=list(hit) if hit is not None else None)
steel,_=tree([o for o in lod_objects[0] if o.name.endswith('__structure')])
timber,_=tree([o for o in lod_objects[0] if o.name.endswith('__sleeper')])
for a,b in zip(s['bent_x_m'],s['bent_x_m'][1:]):
    count=math.ceil((b-a)/s['sleeper_pitch_m'])
    for deck in s['deck_top_m']:
        for cy in s['track_y_m']:
            for step in range(count):
                x=a+(step+.5)*(b-a)/count
                for side in [-1,1]:
                    y=cy+side*s['track_gauge_m']/2
                    for label,z,support in [('sleeper on stringer',deck-s['sleeper_depth_m'],steel),('rail on sleeper',deck,timber)]:
                        point=Vector((x,y,z));hit,n,index,distance=support.ray_cast(point+Vector((0,0,.03)),Vector((0,0,-1)),.06)
                        check(hit is not None and (hit-point).length<.0001 and n.z>.99,label,point=list(point),hit=list(hit) if hit is not None else None)
(OUT/'native_geometry_checks.json').write_text(json.dumps(dict(evidence_class='INERT',source_hashes=hashes,checks=checks,failures=failures),indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures[:12]
if os.environ.get('CITY_TRANSPORT_GEOMETRY_ONLY')=='1':
    print('CITY TRANSPORT GEOMETRY:',len(checks),'checks;',len(failures),'failures; no new render claim')
    sys.exit(0)

# Reopen the retained near-city source for contextual views. The new public
# paving is real stock; surrounding soil and foundations await their replay.
fixture_path=ROOT/'game/tests/fixtures/orison_city_elevations.json';placement_path=ROOT/'art/data/city_elevations/source_plan.json';native=ROOT/'art/blender/city_elevations.blend'
for p in [fixture_path,placement_path,native]:hashes[p.relative_to(ROOT).as_posix()]=sha(p)
fixture=json.loads(fixture_path.read_text());placements={r['id']:Vector(r.get('assembly_translation_m',[0,0,0])) for r in json.loads(placement_path.read_text())['buildings']}
with bpy.data.libraries.load(str(native),link=False) as (available,loaded):loaded.objects=[r['name'] for r in fixture['parts']]
context=bpy.data.collections.new('RetainedCityContext');bpy.context.scene.collection.children.link(context)
for obj in loaded.objects:
    context.objects.link(obj);identity=next(k for k in placements if obj.name.startswith(k+'__'))
    obj.matrix_world=Matrix.Translation(placements[identity])@obj.matrix_world;obj.hide_render=False;obj.hide_set(False)
bpy.context.view_layer.update()
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=preview['samples']
scene.render.resolution_x,scene.render.resolution_y=preview['resolution'];scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('DiagnosticNativeWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=preview['world_rgba'];scene.world.node_tree.nodes['Background'].inputs[1].default_value=preview['world_strength']
sun=bpy.data.objects.new('DiagnosticSun',bpy.data.lights.new('DiagnosticSun','SUN'));scene.collection.objects.link(sun);sun.data.energy=preview['sun_energy'];sun.rotation_euler=preview['sun_euler']
camera=bpy.data.objects.new('NativeReviewCamera',bpy.data.cameras.new('NativeReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=preview['lens_mm']
views=[('west_approach',(8,-35,eye),(64,-10,10)),('east_back',(145,38,24),(65,-10,10)),('lower_platform',(45,-20,s['platform_top_m'][0]+eye),(86,-20,s['platform_top_m'][0]+1)),('upper_platform',(45,-4,s['platform_top_m'][1]+eye),(86,-4,s['platform_top_m'][1]+1)),('public_stair',(27,9,8),(35,5,3.3)),('lower_well',(29,-19.2,s['platform_top_m'][0]+eye),(36,-20,8.5)),('roof_structure',(55,-45,29),(66,-10,15))]
for label,at,target in views:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
context.hide_render=True
for lod in range(2):
    for n in range(2):bpy.data.collections['TransportExports_LOD'+str(n)].hide_render=n!=lod
    camera.location=(5,-70,32);camera.rotation_euler=(Vector((65,-10,8))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/f'body_lod{lod}.png');bpy.ops.render.render(write_still=True)
result=dict(evidence_class='INERT',scope='Reopened native source and metric support/headroom checks. Catalogue materials under diagnostic native lights, not runtime optics, player input, save, performance or artistic acceptance. Context foundations await source replay.',source_hashes=hashes,closed_stocks=closed_counts,checks=checks,failures=failures,player_dimensions=dict(height=height,radius=radius,eye=eye),renders=[v[0]+'.png' for v in views]+['body_lod0.png','body_lod1.png'])
(OUT/'native_review.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
for p,h in hashes.items():assert sha(ROOT/p)==h,p
print('CITY TRANSPORT NATIVE REVIEW:',len(checks),'checks;',len(failures),'failures')
