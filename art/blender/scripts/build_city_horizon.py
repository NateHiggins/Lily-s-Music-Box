"""Build source-owned distant blocks in the actual V2 building/ground frame."""
from pathlib import Path
import bpy,bmesh,collections,json,hashlib,math,sys
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_horizon_geometry import reveal_cell,ray_hit,validate_plan,party_wall_overlap
from fabrication_native_batch import material,partition,export
from city_ground_apron_geometry import exported_bounds
plan_path=ROOT/'art/data/city_horizon/source_plan.json';plan=json.loads(plan_path.read_text())
grade_path=ROOT/'art/blender/city_ground_apron_construction.json';grade=json.loads(grade_path.read_text())
validate_plan(plan,grade['retained_ground_bounds'])
catalog_path=ROOT/'game/data/runtime_material_sets.json';catalog=json.loads(catalog_path.read_text())['materials']
OUT=ROOT/'tmp/v2-city-polish-20261018/horizon_native';OUT.mkdir(parents=True,exist_ok=True)
all_rows=[];all_windows=[];assets={};native_checks={}

for family in ['near','far']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection=bpy.data.collections.new('CityHorizon_'+family);bpy.context.scene.collection.children.link(collection)
    buffers=collections.defaultdict(lambda:([],[]));windows=[]
    rows=[r for r in plan['buildings'] if ('NEAR' in r['id'])==(family=='near')]
    by_id={r['id']:r for r in rows}
    def add(name,key,vertices,faces):
        vv,ff=buffers[(name,key)];start=len(vv);vv.extend(vertices);ff.extend(tuple(start+i for i in face) for face in faces)
    def box(name,key,lo,hi):
        x,y,z=lo;X,Y,Z=hi;assert x<X and y<Y and z<Z
        add(name,key,[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)],
            [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    def local_box(name,key,origin,tangent,out,lo,hi):
        x,y,z=lo;X,Y,Z=hi
        vv=[(u,v,w) for u,v,w in [(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)]]
        add(name,key,[tuple(origin+tangent*u+out*v+Vector((0,0,w))) for u,v,w in vv],
            [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    for row in rows:
        name=row['id'];a,b,c,d=row['rect'];x,y,X,Y=a,-d,c,-b
        h=float(row['height_m']);depth=float(row['reveal_m']);recess=float(row['glass_recess_m'])
        box(name,row['wall_key'],(x,y,-.28),(X,Y,0))
        box(name,'galvanized_roof',(x,y,h),(X,Y,h+.18))
        for lo,hi in [((x,y,h+.18),(X,y+.18,h+.65)),((x,Y-.18,h+.18),(X,Y,h+.65)),
                      ((x,y+.18,h+.18),(x+.18,Y-.18,h+.65)),((X-.18,y+.18,h+.18),(X,Y-.18,h+.65))]:box(name,row['wall_key'],lo,hi)
        for side,(origin,tangent,out,length) in enumerate([
            (Vector((X,y,0)),Vector((-1,0,0)),Vector((0,-1,0)),X-x),
            (Vector((X,Y-depth,0)),Vector((0,-1,0)),Vector((1,0,0)),Y-y-2*depth),
            (Vector((x,Y,0)),Vector((1,0,0)),Vector((0,1,0)),X-x),
            (Vector((x,y+depth,0)),Vector((0,1,0)),Vector((-1,0,0)),Y-y-2*depth)]):
            bays=max(1,round(length/row['bay_pitch_m']));pitch=length/bays
            floors=max(1,round(h/row['storey_m']));storey=h/floors
            for floor in range(floors):
                for bay in range(bays):
                    left=bay*pitch;right=left+pitch;cx=(left+right)*.5
                    first=origin+tangent*left+out*.02;last=origin+tangent*right+out*.02
                    if party_wall_overlap((first.x,-first.y),(last.x,-last.y),floor*storey,[r for r in rows if r['id']!=name]):
                        local_box(name,row['wall_key'],origin,tangent,out,(left,-depth,floor*storey),(right,0,(floor+1)*storey))
                        continue
                    w=min(float(row['window_width_m']),pitch-.65);wh=min(float(row['window_height_m']),storey-.75)
                    low=floor*storey+.6;high=low+wh;wl=cx-w*.5;wr=cx+w*.5
                    vv,ff=reveal_cell(left,floor*storey,right,(floor+1)*storey,wl,low,wr,high,depth)
                    add(name,row['wall_key'],[tuple(origin+tangent*p[0]+out*p[1]+Vector((0,0,p[2]))) for p in vv],ff)
                    # A closed opaque physical pane; these far shells imply no occupied interior.
                    pane=[(wl+.018,-recess-.035,low+.018),(wr-.018,-recess,high-.018)]
                    l,r=pane
                    vv=[(u,v,z) for u,v,z in [(l[0],l[1],l[2]),(r[0],l[1],l[2]),(r[0],r[1],l[2]),(l[0],r[1],l[2]),
                        (l[0],l[1],r[2]),(r[0],l[1],r[2]),(r[0],r[1],r[2]),(l[0],r[1],r[2])]]
                    add(name,'mirror_aged',[tuple(origin+tangent*u+out*v+Vector((0,0,z))) for u,v,z in vv],
                        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
                    windows.append(dict(building=name,side=side,point=list(origin+tangent*cx+Vector((0,0,(low+high)*.5))),normal=list(out),recess_m=recess))
    mats={};draws=[];closed_stocks=0
    for (name,key),(vertices,faces) in sorted(buffers.items()):
        row=by_id[name];tint=row['wall_tint'] if key==row['wall_key'] else [.16,.20,.23,1] if key=='mirror_aged' else [1,1,1,1]
        finish=dict(catalog_key=key,tint=tint,pigment=1.0,normal=.12 if key=='mirror_aged' else .55,roughness=.45 if key=='mirror_aged' else 1.)
        if key=='mirror_aged':finish['metallic']=0.
        cache=(key,tuple(tint))
        if cache not in mats:mats[cache]=material(ROOT,name+'__'+key,finish,catalog)
        center=Vector(((min(v[0] for v in vertices)+max(v[0] for v in vertices))*.5,(min(v[1] for v in vertices)+max(v[1] for v in vertices))*.5,0))
        mesh=bpy.data.meshes.new(name);mesh.from_pydata([Vector(v)-center for v in vertices],[],faces);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);assert all(e.is_manifold and e.is_contiguous for e in bm.edges),name
        assert bm.calc_volume(signed=True)>0,name;bm.free()
        stock=bpy.data.objects.new(name,mesh)
        obj=partition(collection,name+'__'+key,[stock],finish,mats[cache],Matrix.Translation(center),catalog);draws.append(obj)
        bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
    vertices=[];faces=[];owners=[]
    for obj in draws:
        start=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons);owners.extend([obj.name]*len(obj.data.polygons))
    bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
    for window in windows:
        point=Vector(window['point']);normal=Vector(window['normal'])
        hit,n,index,distance=bvh.ray_cast(point+normal*.05,-normal,.3)
        assert hit is not None and (hit-(point-normal*window['recess_m'])).length<.0001 and owners[index]==window['building']+'__mirror_aged',window
    proof=export(ROOT,'city_horizon_'+family,collection)
    native=ROOT/'art/blender'/('city_horizon_'+family+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
    asset=ROOT/'game/assets/props'/('city_horizon_'+family+'.glb')
    assert asset.stat().st_size<95*1024*1024 and native.stat().st_size<95*1024*1024
    assets[family]=dict(asset=asset.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),bytes=asset.stat().st_size,
        native=native.relative_to(ROOT).as_posix(),native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),bounds=exported_bounds(asset.read_bytes()),export_check=proof,
        parts=[dict(name=o.name,key=o.name.split('__')[-1],triangles=len(o.data.polygons)) for o in draws])
    native_checks[family]=dict(window_samples=len(windows),failures=[],tolerance_m=.0001)
    all_rows.extend(rows);all_windows.extend(windows)
    print('CITY HORIZON',family,len(rows),'blocks',len(windows),'recessed opaque panes',asset.stat().st_size,'bytes',flush=True)
coverage=[];rays=0
for origin in [(0,0),(-45,-65),(-45,45),(45,-65),(45,45)]:
    for height in [1.6,20.8,30.8]:
        for degree in range(360):
            direction=(math.cos(math.radians(degree)),math.sin(math.radians(degree)));rays+=1
            if not any(ray_hit(origin,direction,row,height) for row in plan['buildings']):coverage.append(dict(origin=origin,height=height,degrees=degree))
assert not coverage,coverage[:10]
runtime=ROOT/'game/data/orison_v2/exterior/city_horizon.json'
runtime.write_text(json.dumps(dict(schema=1,frame=plan['frame'],buildings=[{k:r[k] for k in ['id','wall_key','wall_tint']} for r in all_rows]),indent=2)+'\n',encoding='utf-8',newline='\n')
paths=[plan_path,grade_path,catalog_path,runtime,Path(__file__),ROOT/'game/scripts/building/orison_v2_city_horizon.gd']
paths += [ROOT/'art/blender/scripts'/p for p in ['city_horizon_geometry.py','city_ground_apron_geometry.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
for key in {r['wall_key'] for r in all_rows}|{'mirror_aged','galvanized_roof'}:paths.extend(ROOT/'game/assets/building/textures'/p for p in catalog[key]['files'])
def sha(path):
    raw=path.read_bytes();return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.json','.py','.gd'] else raw).hexdigest()
report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],buildings=all_rows,windows=len(all_windows),window_rows=all_windows,assets=assets,native_checks=native_checks,
    angular_coverage=dict(scope='Source-only synthetic horizontal rays, not runtime or played proof',rays=rays,uncovered=coverage),source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in paths})
for relative in ['art/blender/city_horizon_construction.json','game/tests/fixtures/orison_city_horizon.json']:
    (ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY HORIZON NATIVE COMPLETE:',len(all_rows),'closed blocks;',len(all_windows),'panes;',rays,'synthetic coverage rays',flush=True)
