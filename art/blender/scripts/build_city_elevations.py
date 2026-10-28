"""Rebuild passive V2 city elevations against retained base and roof authorities."""
from pathlib import Path
import collections, hashlib, json, math, re, sys, os
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material,partition,export
OUT=Path(os.environ.get('CITY_ELEVATIONS_REVIEW_DIR',str(ROOT/'tmp/v2-city-rework-20261018')));OUT.mkdir(exist_ok=True,parents=True)
profiles=json.loads((ROOT/'art/data/city_elevations/source_plan.json').read_text())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
report=json.loads((ROOT/'art/blender/city_closure_construction.json').read_text())
rows=report['original_records'];groups={p['id']:p for p in profiles['buildings']}
def group(n):return '_'.join(n.split('_')[:3]) if n.startswith(('site_nbr_','site_back_','site_far_')) else '_'.join(n.split('_')[:2])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/city_closure.blend'))
original={o.name.removesuffix('__RetainedStock'):o for o in bpy.data.collections['ClosedConstruction'].objects}
rings={o.name.removesuffix('__JoinedParapet'):o for o in bpy.data.collections['ClosedParapets'].objects}
assert len(original)==335 and len(rings)==25
for o in bpy.context.scene.objects:
    o.hide_render=True;o.hide_set(True)
    # Blender must not silently suffix the new portable material ABI with .001.
    if o.library is None:o.name='RetainedReference_'+o.name
exports=bpy.data.collections.new('V2CityElevations');bpy.context.scene.collection.children.link(exports)
buffers=collections.defaultdict(lambda:([],[]));stats=[];window_rows=[]
def add(name,key,verts,faces):
    vv,ff=buffers[(name,key)];start=len(vv);vv.extend(verts);ff.extend(tuple(start+i for i in f) for f in faces)
def box(name,key,lo,hi):
    assert all(b>a for a,b in zip(lo,hi)),(name,key,lo,hi)
    x,y,z=lo;X,Y,Z=hi
    add(name,key,[(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def copied(name,key,obj):
    add(name,key,[tuple(obj.matrix_world@v.co) for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons])
def local_box(name,key,origin,tangent,out,lo,hi):
    x,y,z=lo;X,Y,Z=hi
    vv=[origin+tangent*a+out*b+Vector((0,0,c)) for a,b,c in [(x,y,z),(X,y,z),(X,Y,z),(x,Y,z),(x,y,Z),(X,y,Z),(X,Y,Z),(x,Y,Z)]]
    # tangent x out = +Z for a right-handed cell. All four facades use it.
    add(name,key,[tuple(p) for p in vv],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
def curtain_panel(name,origin,tangent,out,left,right,low,high,depth,seed):
    """Closed thin cloth with a continuous pleated silhouette, behind the pane."""
    steps=max(12,math.ceil((right-left)/.035));verts=[];faces=[]
    for i in range(steps+1):
        x=left+(right-left)*i/steps
        front=-depth+.025+.010*math.sin(i/steps*math.tau*3+seed)
        for y,z in [(front,low),(front,high),(front-.004,low),(front-.004,high)]:
            verts.append(tuple(origin+tangent*x+out*y+Vector((0,0,z))))
    for i in range(steps):
        a=i*4;b=(i+1)*4
        faces.extend([(a,a+1,b+1,b),(a+2,b+2,b+3,a+3),(a,b,b+2,a+2),(a+1,a+3,b+3,b+1)])
    faces.extend([(0,2,3,1),(steps*4,steps*4+1,steps*4+3,steps*4+2)])
    add(name,'linen',verts,faces)

def facade(name,p,rect,z0,z1):
    depth=float(p['reveal_depth']);recess=float(p['window_recess']);assert 0<recess<depth
    x,y,X,Y=rect;count=0;floor_count=max(1,round((z1-z0)/p['storey_height']));floor_h=(z1-z0)/floor_count
    intervals=[(z0+i*floor_h,z0+i*floor_h+floor_h) for i in range(floor_count)]
    if 'floor_heights' in p:
        levels=[0.]
        for h in p['floor_heights']:
            assert h>2.5
            levels.append(levels[-1]+h)
        assert any(abs(z0-v)<.00002 for v in levels) and any(abs(z1-v)<.00002 for v in levels),(name,z0,z1,levels)
        intervals=[(a,b) for a,b in zip(levels,levels[1:]) if a>=z0-.00002 and b<=z1+.00002]
    for side,(origin,tangent,out,length) in enumerate([
        (Vector((X,y,0)),Vector((-1,0,0)),Vector((0,-1,0)),X-x),
        (Vector((X,Y-depth,0)),Vector((0,-1,0)),Vector((1,0,0)),Y-y-2*depth),
        (Vector((x,Y,0)),Vector((1,0,0)),Vector((0,1,0)),X-x),
        (Vector((x,y+depth,0)),Vector((0,1,0)),Vector((-1,0,0)),Y-y-2*depth)]):
        if p['detail_faces']=='inward' and out.dot(-origin)<=0:
            # Secondary outward elevations retain closed mapped masonry;
            # concentrate physical window stock on the principal city-facing elevations.
            local_box(name,p['wall_key'],origin,tangent,out,(0,-depth,z0),(length,0,z1))
            continue
        bays=max(1,math.floor(length/p['bay_pitch']));pitch=length/bays
        for floor,(a,b) in enumerate(intervals):
            floor_h=b-a
            for bay in range(bays):
                left=bay*pitch;right=left+pitch;cx=(left+right)/2;w=min(p['window_width'],pitch-.6);h=min(p['window_height'],floor_h-.7)
                # Very short retained crowns are solid masonry, never squashed windows.
                if h<.9 or w<.6:
                    local_box(name,p['wall_key'],origin,tangent,out,(left,-depth,a),(right,0,b));continue
                low=a+.60;high=low+h;wl=cx-w/2;wr=cx+w/2
                # Four disjoint closed masonry stocks form a genuine 260 mm reveal.
                for lo,hi in [((left,-depth,a),(wl,0,b)),((wr,-depth,a),(right,0,b)),((wl,-depth,a),(wr,0,low)),((wl,-depth,high),(wr,0,b))]:local_box(name,p['wall_key'],origin,tangent,out,lo,hi)
                # Glazed, closed backing: these passive shells imply no accessible interior.
                local_box(name,'mirror_aged',origin,tangent,out,(wl+.045,-recess-.054,low+.045),(wr-.045,-recess-.044,high-.045))
                local_box(name,'wood_dark',origin,tangent,out,(wl+.045,-depth,low+.045),(wr-.045,-depth+.01,high-.045))
                seed=int(p['variation_seed']);pattern=floor*7+bay*3+side+seed
                treatment=p['window_treatment']
                assert treatment in ['roller','draped','mixed']
                if pattern%5 != 0:
                    if treatment=='draped' or (treatment=='mixed' and pattern%3==0):
                        gather=w*[.23,.31,.42][(floor+bay+seed)%3]
                        curtain_panel(name,origin,tangent,out,wl+.05,wl+gather,low+.05,high-.05,depth,seed)
                        curtain_panel(name,origin,tangent,out,wr-gather,wr-.05,low+.05,high-.05,depth,seed+1)
                    else:
                        drop=[.29,.52,.76,1.][(floor+bay+side+seed)%4]
                        local_box(name,'linen',origin,tangent,out,(wl+.05,-depth+.012,high-h*drop),(wr-.05,-depth+.02,high-.045))
                for lo,hi in [((wl,-recess-.044,low),(wl+.055,-recess,high)),((wr-.055,-recess-.044,low),(wr,-recess,high)),((wl+.055,-recess-.044,low),(wr-.055,-recess,low+.055)),((wl+.055,-recess-.044,high-.055),(wr-.055,-recess,high)),((wl+.055,-recess-.038,(low+high)/2-.025),(wr-.055,-recess+.014,(low+high)/2+.025))]:local_box(name,p['sash'],origin,tangent,out,lo,hi)
                if p['window_joinery']=='paired_sash':
                    local_box(name,p['sash'],origin,tangent,out,(cx-.025,-recess-.044,low+.055),(cx+.025,-recess+.014,high-.055))
                else:assert p['window_joinery']=='single_sash'
                local_box(name,'limestone',origin,tangent,out,(wl-.08,-.23,low-.07),(wr+.08,float(p['sill_projection']),low))
                local_box(name,p['lintel_key'],origin,tangent,out,(wl-.09,-.08,high),(wr+.09,.025,high+float(p['lintel_height'])))
                count+=1
                window_rows.append(dict(building=name,side=side,floor=floor,bay=bay,center=list(origin+tangent*cx+Vector((0,0,(low+high)/2))),width=w,height=h,recess_m=recess,
                    pane_sample=list(origin+tangent*(cx+w*.22)+Vector((0,0,(low+high)/2+h*.2)))))
    return count
for name,p in groups.items():
    assert p['massing'] in ['straight_eave','single_upper_setback']
    first_window=len(window_rows)
    rr=[r for r in rows if group(r['id'])==name];ss=sorted([r for r in rr if re.search(r'_s\d+$',r['id'])],key=lambda r:r['z0'])
    last=ss[-1];dx=last['registration_offset_x'];top=last['z0']+last['h'];rect0=list(ss[0]['rect']);rect0[0]+=dx;rect0[2]+=dx
    final_rect=list(last['rect']);final_rect[0]+=dx;final_rect[2]+=dx
    for r in rr:
        suffix=r['id'][len(name)+1:]
        if 'vertical_profile' in p and (suffix.startswith('base') or suffix=='bcorn'):continue
        if re.fullmatch('s[0-9]+',suffix) or suffix.startswith('par_'):continue
        if re.fullmatch('c[0-9]+',suffix) and r is not last and suffix!='c'+last['id'].rsplit('_s',1)[1]:continue
        key=r['key']
        if suffix.startswith('base') and key=='concrete':key='limestone'
        if suffix.startswith('base'):
            x,y,X,Y=r['rect'];x+=dx;X+=dx
            if min(X-x,Y-y)>1.5 and r['h']>2:
                box(name,'limestone',(x,y,r['z0']),(X,Y,r['z0']+.2))
                base_profile=dict(p,wall_key='limestone')
                facade(name,base_profile,[x,y,X,Y],r['z0']+.2,r['z0']+r['h'])
                continue
        if suffix=='bcorn':key='limestone'
        copied(name,key,original[r['id']])
    ring=rings[name];cap=max(v.co.z for v in ring.data.vertices)
    for face in ring.data.polygons:
        key=next(r['key'] for r in rr if '_par_' in r['id']) if all(ring.data.vertices[i].co.z>=cap-.00002 for i in face.vertices) else p['wall_key']
        add(name,key,[tuple(ring.matrix_world@ring.data.vertices[i].co) for i in face.vertices],[tuple(range(len(face.vertices)))])
    # One continuous primary shaft and at most one upper setback, retaining all
    # final roof planes and original roof equipment bearing stock exactly.
    split=last['z0'] if len(ss)>1 else top
    n=facade(name,p,rect0,0. if 'vertical_profile' in p else ss[0]['z0'],split)
    if len(ss)>1:
        n+=facade(name,p,final_rect,split,top)
        # Closed 120 mm roof terrace course; never a stack of projecting cornices.
        x,y,X,Y=rect0;u,v,U,V=final_rect
        for lo,hi in [((x,y,split-.12),(X,v,split)),((x,V,split-.12),(X,Y,split)),((x,v,split-.12),(u,V,split)),((U,v,split-.12),(X,V,split))]:box(name,'roof_bitumen',lo,hi)
    stats.append(dict(id=name,old_setbacks=len(ss)-1,new_setbacks=min(1,len(ss)-1),windows=len(window_rows)-first_window,roof_height=top,shaft_bottom=ss[0]['z0'],setback_height=split,original_roof_rect=final_rect,main_rect=rect0))
# Retired continuous cornice bands can still carry original guy anchors.
# Retain only a local closed bearing saddle outside the new terrace boundary;
# adjoining top planes meet without coplanar overlap or a repeated facade band.
anchor_seats=[]
contact_sources={asset:json.loads((ROOT/f'game/tests/fixtures/orison_city_{asset}.json').read_text()) for asset in ['masts','aerials','tanks']}
source_by_id={row['id']:row for row in rows};stats_by_id={row['id']:row for row in stats}
for asset,data in contact_sources.items():
    for contact in data['contacts']:
        owner=source_by_id.get(contact['owner'])
        if owner is None or not re.search(r'_c[0-9]+$',owner['id']):continue
        identity=group(owner['id']);building=stats_by_id[identity]
        top=owner['z0']+owner['h']
        if abs(top-building['setback_height'])>.00002:continue
        footprint=[contact['point']]+contact['footprint'];dx=owner['registration_offset_x']
        ox,oy,oX,oY=owner['rect'];ox+=dx;oX+=dx
        x=max(ox,min(p[0] for p in footprint)-.02);X=min(oX,max(p[0] for p in footprint)+.02)
        y=max(oy,min(p[1] for p in footprint)-.02);Y=min(oY,max(p[1] for p in footprint)+.02)
        u,v,U,V=building['main_rect']
        pieces=[(x,y,X,min(Y,v)),(x,max(y,V),X,Y),(x,max(y,v),min(X,u),min(Y,V)),(max(x,U),max(y,v),X,min(Y,V))]
        built=[]
        for a,b,c,d in pieces:
            if c<=a or d<=b:continue
            box(identity,'limestone',(a,b,owner['z0']),(c,d,top));built.append([a,b,c,d])
        if built:anchor_seats.append(dict(contact=contact['id'],source_owner=owner['id'],pieces=built,bottom=owner['z0'],top=top))

materials={};draws=[]
for (name,key),(vv,ff) in sorted(buffers.items()):
    p=groups[name];tint=p['wall_tint'] if key==p['wall_key'] else p['frame_tint'] if key=='door_paint' else [.18,.23,.25,1] if key=='mirror_aged' else [1,1,1,1]
    finish=dict(catalog_key=key,tint=tint,pigment=1.,normal=.65,roughness=1.)
    if key=='mirror_aged':finish.update(metallic=.65,roughness=.45,normal=.12)
    cache_key=(key,tuple(tint))
    if cache_key not in materials:materials[cache_key]=material(ROOT,name+'__'+key,finish,catalog)
    mat=materials[cache_key]
    if key=='mirror_aged':
        bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Metallic'].default_value=0;bsdf.inputs['Alpha'].default_value=.28;bsdf.inputs['Transmission Weight'].default_value=.5;bsdf.inputs['IOR'].default_value=1.52
    mesh=bpy.data.meshes.new(name+'__Raw');mesh.from_pydata(vv,[],ff);mesh.update();stock=bpy.data.objects.new(mesh.name,mesh)
    # A per-building local origin keeps even submillimetre UVs representable.
    center=Vector(((min(v[0] for v in vv)+max(v[0] for v in vv))/2,(min(v[1] for v in vv)+max(v[1] for v in vv))/2,0))
    for v in mesh.vertices:v.co-=center
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces))
    zero=[f for f in bm.faces if (f.verts[1].co-f.verts[0].co).cross(f.verts[2].co-f.verts[0].co).length_squared==0]
    if zero:bmesh.ops.delete(bm,geom=zero,context='FACES_ONLY')
    bm.to_mesh(mesh);bm.free()
    obj=partition(exports,name+'__'+key,[stock],finish,mat,Matrix.Translation(center),catalog)
    assert obj.name==name+'__'+key,(name,key,obj.name)
    obj.hide_render=False;obj.hide_set(False);draws.append(obj)
    bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
# Every rebuild must pass actual native bearing and window-depth rays before
# exporting or opening Godot. These remain source checks, never runtime proof.
vertices=[];faces=[];face_owners=[]
for obj in draws:
    offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    faces.extend(tuple(offset+i for i in f.vertices) for f in obj.data.polygons);face_owners.extend([obj.name]*len(obj.data.polygons))
bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
native_bearings=0;native_windows=0;native_failures=[]
for asset,data in contact_sources.items():
    for contact in data['contacts']:
        normal=Vector(contact['normal'])
        for sample in [contact['point']]+contact['footprint']:
            point=Vector(sample);hit,n,index,distance=bvh.ray_cast(point+normal*.03,-normal,.06);native_bearings+=1
            if hit is None or (hit-point).length>=.0001:native_failures.append(dict(kind='bearing',id=contact['id'],sample=sample))
for window in window_rows:
    # Sample inside an actual pane, clear of both sash rails and paired mullions.
    point=Vector(window['pane_sample'])
    normal=[Vector((0,-1,0)),Vector((1,0,0)),Vector((0,1,0)),Vector((-1,0,0))][window['side']]
    hit,n,index,distance=bvh.ray_cast(point+normal*.1,-normal,.4);expected=point-normal*(window['recess_m']+.044);native_windows+=1
    if hit is None or (hit-expected).length>=.0001 or not face_owners[index].endswith('__mirror_aged'):native_failures.append(dict(kind='pane',window=window))
assert not native_failures,native_failures[:12]
native_checks=dict(bearing_samples=native_bearings,window_samples=native_windows,failures=native_failures,tolerance_m=.0001)
print('CITY NATIVE CONTACTS',native_checks,flush=True)

# Native source and portable export are rebuilt together, before review cameras.
proof=export(ROOT,'city_elevations',exports)
def sha(path):
    raw=path.read_bytes()
    if path.suffix in {'.json','.py','.gd'}:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()
runtime={'schema':1,'buildings':[{k:p[k] for k in ['id','wall_key','wall_tint','frame_tint']} for p in profiles['buildings']]}
projection=ROOT/'game/data/orison_v2/exterior/city_elevations.json'
projection.write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8',newline='\n')
bindings=[ROOT/p for p in ['art/data/city_elevations/source_plan.json','art/blender/city_closure.blend','art/blender/city_closure_construction.json','art/blender/city_shells.blend','art/blender/city_shells_registration.json','game/data/runtime_material_sets.json','game/data/orison_v2/exterior/city_elevations.json','game/tests/fixtures/orison_city_masts.json','game/tests/fixtures/orison_city_aerials.json','game/tests/fixtures/orison_city_tanks.json','game/scripts/building/orison_v2_city_shells.gd','art/blender/scripts/fabrication_native_batch.py','art/blender/scripts/fabrication_normals.py','art/blender/scripts/fabrication_uvs.py']]+[Path(__file__)]
for key in {key for name,key in buffers}:
    bindings.extend(ROOT/'game/assets/building/textures'/f for f in catalog[key]['files'])
construction={k:report[k] for k in ['original_records','source_parapet_stocks','closed_joined_parapets','corner_stations','capture_offsets_godot','skyline_views_godot']}
construction.update(anchor_seats=anchor_seats,native_checks=native_checks,evidence_class='INERT',classification='ADAPTATION',scope='Passive physical city elevations. No occupied rooms or runtime acceptance inferred.',buildings=stats,windows=len(window_rows),window_rows=window_rows,parts=[dict(name=o.name,key=o.name.split('__')[-1],triangles=len(o.data.polygons)) for o in draws],triangles=sum(len(o.data.polygons) for o in draws),asset_sha256=sha(ROOT/'game/assets/props/city_elevations.glb'),source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in bindings},export_check=proof)
for dest in ['art/blender/city_elevations_construction.json','game/tests/fixtures/orison_city_elevations.json']:
    (ROOT/dest).write_text(json.dumps(construction,indent=2)+'\n',encoding='utf-8',newline='\n')
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('NeutralReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.6,.7,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
d=bpy.data.lights.new('ReviewSun','SUN');d.energy=3;d.angle=.08;sun=bpy.data.objects.new(d.name,d);scene.collection.objects.link(sun);sun.rotation_euler=(.45,-.35,-.7)
d=bpy.data.cameras.new('Review');cam=bpy.data.objects.new(d.name,d);scene.collection.objects.link(cam);scene.camera=cam;d.lens=32
for label,at,target in [('north_skyline',(3,-12,24),(0,40,29)),('west_neighbors',(-7,-23,8),(-28,-2,10)),('south_skyline',(5,10,25),(0,-55,25)),('near_elevation',(9,-20,9),(21,-1,9))]:
    cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
# Review cameras/lights remain disposable; the saved production native precedes them.
(OUT/'construction.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Read-only native visual review of the rebuilt source; no runtime acceptance',buildings=stats,windows=len(window_rows),window_rows=window_rows,partitions=len(draws),triangles=sum(len(o.data.polygons) for o in draws)),indent=2)+'\n',encoding='utf-8')
print('CITY ELEVATIONS NATIVE',len(stats),'buildings',len(window_rows),'recessed windows',len(draws),'partitions',flush=True)
