"""Build source-owned distant blocks in the actual V2 building/ground frame."""
from pathlib import Path
import bpy,bmesh,collections,json,hashlib,math,sys
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from city_horizon_geometry import reveal_cell,ray_hit,validate_plan,party_wall_overlap,building_outline,extrusion,cornice_ring,floor_intervals,offset_outline
from fabrication_native_batch import material,partition
from city_ground_apron_geometry import relief_height
from city_industrial_architecture import IndustrialBuildings,MillLofts,EasternRows
from city_residential_architecture import ResidentialHouses,EasternHouses,CourtApartments,CivicRows,CivicBlocks
from city_horizon_assets import export_blocks,manifest_paths
plan_path=ROOT/'art/data/city_horizon/source_plan.json';plan=json.loads(plan_path.read_text())
grade_path=ROOT/'art/blender/city_ground_apron_construction.json';grade=json.loads(grade_path.read_text())
validate_plan(plan,grade['retained_ground_bounds'])
catalog_path=ROOT/'game/data/runtime_material_sets.json';catalog=json.loads(catalog_path.read_text())['materials']
OUT=ROOT/'tmp/v2-city-polish-20261018/horizon_native';OUT.mkdir(parents=True,exist_ok=True)
all_rows=[];all_windows=[];all_bearings=[];assets={};native_checks={};grade_seats=[]
replacement_buffers=collections.defaultdict(lambda:([],[]))
industrial_checks=[]
for row in plan['buildings']:
    outline=building_outline(row)
    samples=[(x,-y) for x,y in outline]
    for p,q in zip(outline,outline[1:]+outline[:1]):
        if abs(q[0]-p[0])<1e-12:continue
        for x,_ in grade['relief']['west_profile']:
            t=(x-p[0])/(q[0]-p[0])
            if 0<t<1:samples.append((x,-(p[1]+t*(q[1]-p[1]))))
    heights=[relief_height(x,z,-.02,grade['relief']) for x,z in samples]
    # Passive complete assemblies follow the uphill parcel datum. Their bases
    # stay buried by .26m there; a short foundation seats the downhill edge.
    row['grade_datum_m']=max(heights)+.02
    row['grade_low_m']=min(heights)

for family in ['near','far']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    collection=bpy.data.collections.new('CityHorizon_'+family);bpy.context.scene.collection.children.link(collection)
    buffers=collections.defaultdict(lambda:([],[]));windows=[];bearings=[]
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
    def beam(name,key,start,end,width):
        axis=(end-start).normalized();u=axis.cross(Vector((0,0,1)))
        if u.length<.01:u=axis.cross(Vector((1,0,0)))
        u.normalize();v=axis.cross(u)
        verts=[tuple(p+u*a*width/2+v*b*width/2) for p in [start,end] for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        add(name,key,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    for row in rows:
        name=row['id'];a,b,c,d=row['rect'];x,y,X,Y=a,-d,c,-b
        h=float(row['height_m']);depth=float(row['reveal_m']);recess=float(row['glass_recess_m'])
        study=row.get('architecture',{});outline=building_outline(row)
        if study.get('type') in ['industrial_front','mill_front','eastern_row','residential_front']:
            neighbours=[r for r in rows if r['id']!=name]
            constructor={'industrial_front':IndustrialBuildings,'mill_front':MillLofts,'eastern_row':EasternRows,'residential_front':ResidentialHouses}[study['type']]
            if study.get('style') in EasternHouses.STYLES:constructor=EasternHouses
            if study.get('style') in CourtApartments.STYLES:constructor=CourtApartments
            if study.get('style') in CivicRows.STYLES:constructor=CivicRows
            if study.get('style') in CivicBlocks.STYLES:constructor=CivicBlocks
            authored=constructor(row,add,neighbours).build()
            windows.extend(authored['windows']);bearings.extend(authored['bearings'])
            def lower_add(owner,key,vertices,faces):
                vv,ff=replacement_buffers[(owner,key)];start=len(vv)
                vv.extend(vertices);ff.extend(tuple(start+i for i in f) for f in faces)
            lower=constructor(row,lower_add,neighbours,lower=True).build()
            industrial_checks.append(dict(building=name,style=authored['style'],
                near_closed_stocks=authored['closed_stocks'],lower_closed_stocks=lower['closed_stocks'],
                near_min_stock_volume_m3=authored['min_closed_stock_volume_m3'],
                lower_min_stock_volume_m3=lower['min_closed_stock_volume_m3'],
                near_panes=len(authored['windows']),lower_panes=len(lower['windows']),
                entries=authored['entries'],lower_entries=lower['entries'],mitre_seams=authored['mitre_seams']))
            assert authored['entries']==lower['entries'] and len(authored['windows'])==len(lower['windows'])
            continue
        if study:
            vv,ff=extrusion(outline,-.28,0);add(name,row['wall_key'],vv,ff)
            vv,ff=extrusion(outline,h,h+.18);add(name,'galvanized_roof',vv,ff)
        else:
            box(name,row['wall_key'],(x,y,-.28),(X,Y,0))
            box(name,'galvanized_roof',(x,y,h),(X,Y,h+.18))
        # Separate horizontal cornice stocks and chimney caps, never stepped floors.
        if study:
            for width,lo,hi in [(.15,h-.22,h-.1),(.32,h-.1,h+.1),(.38,h+.1,h+.18)]:
                vv,ff=cornice_ring(outline,width,lo,hi);add(name,study['cornice_key'],vv,ff)
        else:
            for lo,hi in [((x,y,h-.32),(X,y+.28,h-.17)),((x,Y-.28,h-.32),(X,Y,h-.17)),
                          ((x,y+.28,h-.32),(x+.28,Y-.28,h-.17)),((X-.28,y+.28,h-.32),(X,Y-.28,h-.17))]:box(name,'limestone',lo,hi)
        chimney_top=h+float(row['chimney_height_m'])
        box(name,row['wall_key'],(x+.75,y+.75,h+.18),(x+1.45,y+1.45,chimney_top-.12))
        box(name,'limestone',(x+.65,y+.65,chimney_top-.12),(x+1.55,y+1.55,chimney_top))
        if study:
            # Parapet follows the actual court/bay outline; no solid roof over
            # a courtyard and no square cornice crossing an angled bay.
            # The parapet bears over the masonry/roof assembly, not on the
            # projecting decorative cornice outside the wall line.
            vv,ff=cornice_ring(offset_outline(outline,-.18),.18,h+.18,h+.58);add(name,row['wall_key'],vv,ff)
            n=len(outline)
            for i in range(n):
                j=(i+1)%n
                foot=sum((Vector(vv[k]) for k in [i,j,i+n,j+n]),Vector())*.25
                edge=Vector((*outline[j],0))-Vector((*outline[i],0));edge.normalize()
                outside=(Vector((*outline[i],h+.18))+Vector((*outline[j],h+.18)))*.5+Vector((-edge.y,edge.x,0))*.09
                bearings.append(dict(building=name,wall_key=row['wall_key'],point=list(foot),outside_probe=list(outside)))
        else:
            for lo,hi in [((x,y,h+.18),(X,y+.18,h+.65)),((x,Y-.18,h+.18),(X,Y,h+.65)),
                          ((x,y+.18,h+.18),(x+.18,Y-.18,h+.65)),((X-.18,y+.18,h+.18),(X,Y-.18,h+.65))]:box(name,row['wall_key'],lo,hi)
        sides=[
            (Vector((X,y,0)),Vector((-1,0,0)),Vector((0,-1,0)),X-x),
            (Vector((X,Y-depth,0)),Vector((0,-1,0)),Vector((1,0,0)),Y-y-2*depth),
            (Vector((x,Y,0)),Vector((1,0,0)),Vector((0,1,0)),X-x),
            (Vector((x,y+depth,0)),Vector((0,1,0)),Vector((-1,0,0)),Y-y-2*depth)]
        if study:
            sides=[]
            for p,q in zip(outline,outline[1:]+outline[:1]):
                tangent=Vector((q[0]-p[0],q[1]-p[1],0));length=tangent.length;tangent.normalize()
                sides.append((Vector((*p,0)),tangent,Vector((-tangent.y,tangent.x,0)),length))
        for side,(origin,tangent,out,length) in enumerate(sides):
            if side in study.get('bracket_sides',[]):
                count=max(2,round(length/float(study['bracket_pitch_m'])))
                profile=[(0,h-.56),(.04,h-.56),(.14,h-.28),(.14,h-.22),(0,h-.22)]
                for slot in range(count):
                    center=(slot+.5)*length/count;n=len(profile)
                    vv=[tuple(origin+tangent*(center+u)+out*v+Vector((0,0,z))) for u in [-.055,.055] for v,z in profile]
                    ff=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
                    add(name,study['cornice_key'],vv,ff)
            bays=max(1,round(length/row['bay_pitch_m']));pitch=length/bays
            if study:
                bays=study['side_bays'][side];pitch=length/bays
            for floor,(bottom,top) in enumerate(floor_intervals(row)):
                storey=top-bottom
                for bay in range(bays):
                    left=bay*pitch;right=left+pitch;cx=(left+right)*.5
                    first=origin+tangent*left+out*.02;last=origin+tangent*right+out*.02
                    axis_aligned=abs(tangent.x)<1e-8 or abs(tangent.y)<1e-8
                    if axis_aligned and party_wall_overlap((first.x,-first.y),(last.x,-last.y),bottom+row['grade_datum_m'],[r for r in rows if r['id']!=name]):
                        local_box(name,row['wall_key'],origin,tangent,out,(left,-depth,bottom),(right,0,top))
                        continue
                    entrance=study.get('entrance',{})
                    entry_bay=bool(entrance) and side==entrance['side'] and bay==entrance['bay']
                    if entry_bay and floor<entrance['floor']:
                        local_box(name,row['wall_key'],origin,tangent,out,(left,-depth,bottom),(right,0,top));continue
                    door=entry_bay and floor==entrance['floor']
                    w=min(float(row['window_width_m']),pitch-(.24 if study else .65));wh=min(float(row['window_height_m']),storey-.75)
                    low=bottom+(.04 if door else .6);high=low+(entrance['height_m'] if door else wh)
                    if door:w=float(entrance['width_m'])
                    wl=cx-w*.5;wr=cx+w*.5
                    vv,ff=reveal_cell(left,bottom,right,top,wl,low,wr,high,depth)
                    add(name,row['wall_key'],[tuple(origin+tangent*p[0]+out*p[1]+Vector((0,0,p[2]))) for p in vv],ff)
                    if study:
                        local_box(name,'limestone',origin,tangent,out,(wl-.07,-depth,low-.06),(wr+.07,.075,low))
                        local_box(name,'limestone',origin,tangent,out,(wl-.09,-.05,high),(wr+.09,.06,high+.12))
                    if door:
                        local_box(name,'door_paint',origin,tangent,out,(wl+.018,-recess-.035,low+.018),(wr-.018,-recess,high-.018))
                        for zlo,zhi in [(low+.16,low+.95),(low+1.08,high-.16)]:
                            local_box(name,'door_paint',origin,tangent,out,(wl+.12,-recess,zlo),(wr-.12,-recess+.025,zhi))
                        steps=int(entrance['steps']);rise=low/max(1,steps);run=float(entrance['step_run_m'])
                        for step in range(steps):
                            local_box(name,'limestone',origin,tangent,out,(wl-.13,(steps-step-1)*run,0),(wr+.13,(steps-step)*run,(step+1)*rise))
                        if steps>1:
                            for u in [wl-.10,wr+.10]:
                                ends=[]
                                for v,z in [((steps-.5)*run,rise),(.5*run,low)]:
                                    local_box(name,'cast_iron',origin,tangent,out,(u-.035,v-.045,z),(u+.035,v+.045,z+.02))
                                    foot=origin+tangent*u+out*v+Vector((0,0,z+.02))
                                    tip=origin+tangent*u+out*v+Vector((0,0,z+.86))
                                    beam(name,'cast_iron',foot,tip,.035);ends.append(tip)
                                beam(name,'cast_iron',ends[0],ends[1],.045)
                                count=max(2,math.ceil((steps-1)*run/.18))
                                for i in range(1,count):
                                    v=(steps-.5)*run-(steps-1)*run*i/count
                                    z=(steps-min(steps-1,int(v/run)))*rise
                                    top_z=rise+.86+(low-rise)*i/count
                                    foot=origin+tangent*u+out*v+Vector((0,0,z+.015))
                                    tip=origin+tangent*u+out*v+Vector((0,0,top_z-.015))
                                    beam(name,'cast_iron',foot,tip,.018)
                        if not steps:
                            local_box(name,'limestone',origin,tangent,out,(wl-.08,-.05,0),(wr+.08,.18,low))
                        # Small seated iron pull, appropriate to a passive far
                        # entrance; it creates no new operable gameplay owner.
                        handle_x=wr-.17;handle_low=low+.95
                        for z in [handle_low,handle_low+.23]:
                            local_box(name,'cast_iron',origin,tangent,out,(handle_x-.025,-recess+.025,z),(handle_x+.025,-recess+.07,z+.025))
                        local_box(name,'cast_iron',origin,tangent,out,(handle_x-.012,-recess+.058,handle_low),(handle_x+.012,-recess+.085,handle_low+.255))
                        continue
                    # A closed opaque physical pane; these far shells imply no occupied interior.
                    pane=[(wl+.018,-recess-.035,low+.018),(wr-.018,-recess,high-.018)]
                    l,r=pane
                    vv=[(u,v,z) for u,v,z in [(l[0],l[1],l[2]),(r[0],l[1],l[2]),(r[0],r[1],l[2]),(l[0],r[1],l[2]),
                        (l[0],l[1],r[2]),(r[0],l[1],r[2]),(r[0],r[1],r[2]),(l[0],r[1],r[2])]]
                    add(name,'mirror_aged',[tuple(origin+tangent*u+out*v+Vector((0,0,z))) for u,v,z in vv],
                        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
                    joinery='cast_iron' if row['typology']=='factory' else 'door_paint'
                    # Real frame/sash bars give depth and a period window rhythm.
                    for l,r in [((wl,-recess+.01,low),(wl+.045,.012,high)),((wr-.045,-recess+.01,low),(wr,.012,high)),
                                ((wl,-recess+.01,low),(wr,.012,low+.045)),((wl,-recess+.01,high-.045),(wr,.012,high)),
                                ((wl,-recess+.025,(low+high)*.5-.022),(wr,-recess+.06,(low+high)*.5+.022))]:
                        local_box(name,joinery,origin,tangent,out,l,r)
                    if row['typology']=='factory':
                        local_box(name,joinery,origin,tangent,out,(cx-.018,-recess+.025,low),(cx+.018,-recess+.06,high))
                    windows.append(dict(building=name,side=side,point=list(origin+tangent*(cx+w*.22)+Vector((0,0,(low+high)*.5+wh*.2))),normal=list(out),recess_m=recess))
    for row in rows:
        name=row['id'];datum=float(row['grade_datum_m'])
        if datum:
            for (owner,key),(vertices,faces) in buffers.items():
                if owner==name:vertices[:]=[(x,y,z+datum) for x,y,z in vertices]
            for window in windows:
                if window['building']==name:window['point'][2]+=datum
            for bearing in bearings:
                if bearing['building']==name:
                    bearing['point'][2]+=datum;bearing['outside_probe'][2]+=datum
            for (owner,key),(vertices,faces) in replacement_buffers.items():
                if owner==name:vertices[:]=[(x,y,z+datum) for x,y,z in vertices]
        bottom=float(row['grade_low_m'])-.2;top=datum-.28
        if bottom<top-1e-7:
            vv,ff=extrusion(building_outline(row),bottom,top);add(name,'concrete',vv,ff)
            if row.get('architecture',{}).get('type') in ['industrial_front','mill_front','eastern_row','residential_front']:
                lower_add(name,'concrete',vv,ff)
        grade_seats.append(dict(building=name,assembly_datum_m=datum,soil_low_m=row['grade_low_m'],soil_high_m=datum-.02,
                                base_bottom_m=top,foundation_bottom_m=bottom if bottom<top-1e-7 else None))
    mats={};draws=[];closed_stocks=0
    for (name,key),(vertices,faces) in sorted(buffers.items()):
        row=by_id[name];tint=row['wall_tint'] if key==row['wall_key'] else row.get('joinery_tint',[1,1,1,1]) if key in ['door_paint','cast_iron'] else [.16,.20,.23,1] if key=='mirror_aged' else [1,1,1,1]
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
    for row in rows:
        points=[obj.matrix_world@v.co for obj in draws if obj.name.split('__')[0]==row['id'] for v in obj.data.vertices]
        # Independent source vertices include the actual 12 mm projecting frames.
        row['native_stock_bounds']=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
    for obj in draws:
        start=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons);owners.extend([obj.name]*len(obj.data.polygons))
    bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
    for window in windows:
        point=Vector(window['point']);normal=Vector(window['normal'])
        hit,n,index,distance=bvh.ray_cast(point+normal*.05,-normal,.3)
        assert hit is not None and (hit-(point-normal*window['recess_m'])).length<.0001 and owners[index]==window['building']+'__mirror_aged',window
    for row in rows:
        contacts=[b for b in bearings if b['building']==row['id']]
        if not contacts:continue
        roof=next(o for o in draws if o.name==row['id']+'__galvanized_roof')
        roof_bvh=BVHTree.FromPolygons([roof.matrix_world@v.co for v in roof.data.vertices],[tuple(f.vertices) for f in roof.data.polygons],all_triangles=True)
        for contact in contacts:
            point=Vector(contact['point']);hit,normal,index,distance=roof_bvh.ray_cast(point+Vector((0,0,.02)),Vector((0,0,-1)),.04)
            assert hit is not None and (hit-point).length<.0001,('unseated parapet',contact)
            outside=Vector(contact['outside_probe']);hit,normal,index,distance=roof_bvh.ray_cast(outside+Vector((0,0,.02)),Vector((0,0,-1)),.04)
            assert hit is None,('outside control accepted as roof bearing',contact)
    block_assets=export_blocks(ROOT,family,draws,{row['id'] for row in rows})
    assert not (set(assets)&set(block_assets));assets.update(block_assets)
    native_checks[family]=dict(window_samples=len(windows),parapet_samples=len(bearings),parapet_outside_controls=len(bearings),failures=[],tolerance_m=.0001)
    all_rows.extend(rows);all_windows.extend(windows);all_bearings.extend(bearings)
    print('CITY HORIZON',family,len(rows),'buildings',len(windows),'recessed opaque panes',len(block_assets),'whole-block exports',sum(a['bytes'] for a in block_assets.values()),'bytes',flush=True)
# A source-owned replacement asset contains complete authored industrial bodies.
# Other horizon meshes/imported LODs retain their existing source construction.
bpy.ops.wm.read_factory_settings(use_empty=True)
collection=bpy.data.collections.new('CityHorizonReplacementBodies');bpy.context.scene.collection.children.link(collection)
profiles_by_id={r['id']:r for r in all_rows};lower_draws=[];lower_mats={}
for (name,key),(vertices,faces) in sorted(replacement_buffers.items()):
    row=profiles_by_id[name]
    tint=row['wall_tint'] if key==row['wall_key'] else row.get('joinery_tint',[1,1,1,1]) if key in ['door_paint','cast_iron'] else [.16,.20,.23,1] if key=='mirror_aged' else [1,1,1,1]
    finish=dict(catalog_key=key,tint=tint,pigment=1.,normal=.12 if key=='mirror_aged' else .55,roughness=.45 if key=='mirror_aged' else 1.)
    if key=='mirror_aged':finish['metallic']=0.
    cache=(key,tuple(tint))
    if cache not in lower_mats:lower_mats[cache]=material(ROOT,name+'__'+key,finish,catalog)
    center=Vector(((min(v[0] for v in vertices)+max(v[0] for v in vertices))*.5,(min(v[1] for v in vertices)+max(v[1] for v in vertices))*.5,0))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([Vector(v)-center for v in vertices],[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);assert all(e.is_manifold and e.is_contiguous for e in bm.edges),name
    assert bm.calc_volume(signed=True)>0,name;bm.free()
    stock=bpy.data.objects.new(name,mesh)
    obj=partition(collection,name+'__'+key,[stock],finish,lower_mats[cache],Matrix.Translation(center),catalog);lower_draws.append(obj)
    bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
expected_bodies={row['id'] for row in plan['buildings'] if row.get('architecture',{}).get('type') in ['industrial_front','mill_front','eastern_row','residential_front']}
assert lower_draws and {row['building'] for row in industrial_checks}==expected_bodies and len(industrial_checks)==len(expected_bodies)
block_assets=export_blocks(ROOT,'lod1',lower_draws,expected_bodies)
assert not (set(assets)&set(block_assets));assets.update(block_assets)
coverage=[];rays=0
for origin in [(0,0),(-45,-65),(-45,45),(45,-65),(45,45)]:
    for height in [1.6,20.8,30.8]:
        for degree in range(360):
            direction=(math.cos(math.radians(degree)),math.sin(math.radians(degree)));rays+=1
            if not any(ray_hit(origin,direction,row,height) for row in plan['buildings']):coverage.append(dict(origin=origin,height=height,degrees=degree))
ground_gaps=[r for r in coverage if r['height']==1.6]
assert not ground_gaps,ground_gaps[:10]
runtime=ROOT/'game/data/orison_v2/exterior/city_horizon.json'
runtime_rows=[]
for row in all_rows:
    profile={k:row[k] for k in ['id','wall_key','wall_tint']}
    profile['window_typology']=row['typology']
    if 'joinery_tint' in row:profile['joinery_tint']=row['joinery_tint']
    runtime_rows.append(profile)
def runtime_asset(asset):
    return dict(asset='res://'+asset['asset'].removeprefix('game/'),block=asset['block'],buildings=asset['buildings'],parts=[p['name'] for p in asset['parts']])
body_lod=dict(assets=[runtime_asset(a) for a in assets.values() if a['role']=='body_lod'],error_m=float(plan['body_lod_error_m']),parts=[o.name for o in lower_draws])
assert body_lod['error_m']>0.
runtime_data=dict(schema=2,frame=plan['frame'],buildings=runtime_rows,assets=[runtime_asset(a) for a in assets.values() if a['role']=='base'],body_lod=body_lod)
assert len(manifest_paths(runtime_data))==len(assets)
runtime.write_text(json.dumps(runtime_data,indent=2)+'\n',encoding='utf-8',newline='\n')
paths=[plan_path,grade_path,catalog_path,runtime,Path(__file__),ROOT/'game/scripts/building/orison_v2_city_horizon.gd']
paths += [ROOT/'art/blender/scripts'/p for p in ['city_horizon_geometry.py','city_ground_apron_geometry.py','fabrication_native_batch.py','fabrication_chart_batch.py','fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py']]
paths.append(ROOT/'art/blender/scripts/city_industrial_architecture.py')
paths.append(ROOT/'art/blender/scripts/city_residential_architecture.py')
paths.append(ROOT/'art/blender/scripts/frame_mitre_geometry.py')
paths.append(ROOT/'art/blender/scripts/city_horizon_assets.py')
for key in {part['key'] for asset in assets.values() for part in asset['parts']}:paths.extend(ROOT/'game/assets/building/textures'/p for p in catalog[key]['files'])
def sha(path):
    raw=path.read_bytes();return hashlib.sha256(raw.replace(b'\r\n',b'\n') if path.suffix in ['.json','.py','.gd'] else raw).hexdigest()
report=dict(evidence_class='INERT',scope=plan['scope'],frame=plan['frame'],buildings=all_rows,windows=len(all_windows),window_rows=all_windows,parapet_contacts=all_bearings,grade_seats=grade_seats,assets=assets,native_checks=native_checks,industrial_checks=industrial_checks,
    angular_coverage=dict(scope='Source-only synthetic horizontal rays; ground continuity required, open sky above period rooflines expected. Not runtime or played proof.',rays=rays,ground_gaps=ground_gaps,open_sky_above_roofs=coverage),source_bindings={p.relative_to(ROOT).as_posix():sha(p) for p in paths})
for relative in ['art/blender/city_horizon_construction.json','game/tests/fixtures/orison_city_horizon.json']:
    (ROOT/relative).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CITY HORIZON NATIVE COMPLETE:',len(all_rows),'closed blocks;',len(all_windows),'panes;',rays,'synthetic coverage rays',flush=True)
