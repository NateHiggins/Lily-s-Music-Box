"""Prepare/review remaining horizon buildings without writing installed assets.

Run with Python --plan-only, then Blender --background --python-exit-code 1
--python THIS -- --out EXTERNAL --block BLOCK. Each block is a bounded job.
The unchanged installed source plan is the baseline, never an output here.
"""
import argparse, collections, copy, hashlib, json, math, pathlib, sys, time

ROOT = pathlib.Path(__file__).resolve().parents[3]
FABRICATED = {'industrial_front','mill_front','eastern_row','residential_front'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8', newline='\n')


def block(identity):
    return '_'.join(identity.split('_')[:4])


def prepare(out):
    source = json.loads((ROOT/'art/data/city_horizon/source_plan.json').read_bytes())
    rows = source['buildings']; by_id={r['id']:r for r in rows}
    templates = {r['architecture']['style']:r for r in rows
                 if r.get('architecture',{}).get('type') in FABRICATED}
    replacement=copy.deepcopy(source); changed=[]
    house_styles=['italianate_2109','stone_2129','mansard_2153','narrow_2141','gable_2136','neogrec_2122']
    counts=collections.Counter()
    for row in replacement['buildings']:
        # Three older individual-outline studies predate the fabrication
        # dispatch. Preserve their reference-specific work as well.
        if row.get('architecture'): continue
        identity=row['id'];kind=row['typology'];a,b,c,d=row['rect'];dx=c-a;dz=d-b
        # Narrow houses retain their real frontage; broad blocks face the
        # longer street edge. Registration remains local to the horizon root.
        front_axis = ('z' if dx<dz else 'x') if kind=='rowhouse' else ('x' if dz>=dx else 'z')
        desired = ((-1,0) if a+c>0 else (1,0)) if front_axis=='x' else ((0,1) if b+d<0 else (0,-1))
        width,depth = (dz,dx) if front_axis=='x' else (dx,dz)
        n=counts[kind];counts[kind]+=1
        if kind=='rowhouse':
            style=house_styles[n%len(house_styles)]; template=copy.deepcopy(templates[style])
            fabricator='civic_house' if style in ['stone_2129','narrow_2141','neogrec_2122'] else 'house'
            localrect=[.28,-depth+.55,width-.28,0.]
            template['rect']=localrect
            study=template['architecture'];study.pop('outline_m',None)
            study.update(front_inset_m=3.2,side_bays=[2 if style=='narrow_2141' else 3,
                         max(3,int((depth-3.75)/3.1)),2 if style=='narrow_2141' else 3,max(3,int((depth-3.75)/3.1))])
            local_outline=[[localrect[2],-3.2],[localrect[0],-3.2],
                           [localrect[0],localrect[1]],[localrect[2],localrect[1]]]
            if style=='narrow_2141':
                middle=width/2
                local_outline=[[middle+2.44,-3.2],[middle-2.44,-3.2],
                               [middle-2.44,localrect[1]],[middle+2.44,localrect[1]]]
            canonical_front=(0,-1)
        elif kind=='walkup':
            style='hampton_7916' if identity=='HORIZON_NEAR_3_0_P2' or n%3==0 else 'plymouth_3516' if n%3==1 else 'willow_3535'
            template=copy.deepcopy(templates['plymouth_3516' if style=='hampton_7916' else style]);study=template['architecture']
            fabricator='hampton' if style=='hampton_7916' else 'court'
            old=template['rect'];localrect=[-depth+.55,.4,0.,width-.4]
            template['rect']=localrect
            def remap(point):
                return [localrect[0]+(point[0]-old[0])/(old[2]-old[0])*(localrect[2]-localrect[0]),
                        localrect[1]+(point[1]-old[1])/(old[3]-old[1])*(localrect[3]-localrect[1])]
            if style=='hampton_7916':
                # Front remains 3.2m inside its reservation, leaving the
                # stoop plus a continuous outer walk. Two independent bays.
                W=width-.8;start=.4;front=-3.2;rear=-depth+.55;bay=.32*W;cut=.075*W
                path=[(rear,start+W),(rear,start),(front,start),
                      (front,start+cut),(front+.85,start+cut+1.05),(front+.85,start+bay-1.05),
                      (front,start+bay),(front,start+W-bay),
                      (front+.85,start+W-bay+1.05),(front+.85,start+W-cut-1.05),
                      (front,start+W-cut),(front,start+W)]
                # Required clockwise native outline = CCW source X/Z.
                study.update(style=style,outline_m=[list(p) for p in path],
                             entry_sides=[6],front_side=6,court_paving_m=[[-3.2,.4,0.,width-.4]],
                             side_bays=[max(3,int(W/2.7)),max(4,int((depth-3.75)/3.1)),1,1,1,1,1,
                                        max(3,int((W-2*bay)/2.6))|1,1,1,1,1],
                             floor_heights_m=[.9,3.35,3.2,3.2,3.2,3.15],
                             precedent='Hampton Court,35-16 79th Street;George H.Wells1919-21;five stories+basement,central entablature entry,paired canted bays,openwork stone parapet',
                             source='https://s-media.nyc.gov/agencies/lpc/lp/1831.pdf',source_pdf_pages=[129])
                # Side 6 is the centre flat between the paired canted bays.
                study['entry_sides']=[6]
                study['side_bays']=[max(1,int(math.dist(p,q)/2.65)) for p,q in zip(path,path[1:]+path[:1])]
                study['side_bays'][6]=max(3,study['side_bays'][6])|1
            else:
                study['outline_m']=[remap(p) for p in study['outline_m']]
                study['court_paving_m']=[remap(r[:2])+remap(r[2:]) for r in study['court_paving_m']]
                # Real metric bays are rebuilt. Existing short returns keep
                # one bay; the axial entry remains the central odd bay.
                points=study['outline_m'];bays=[]
                for i,(p,q) in enumerate(zip(points,points[1:]+points[:1])):
                    count=max(1,int(math.dist(p,q)/2.65))
                    if i in study['entry_sides']:count=max(3,count)|1
                    bays.append(count)
                study['side_bays']=bays
            local_outline=study['outline_m'];canonical_front=(1,0)
        else:
            style=['karp_4024','karp_4018','walters_4036','mill_2102','alder_2122'][n%5]
            if kind=='commercial':style='queens_office_1927'
            template=copy.deepcopy(templates['karp_4024' if kind=='commercial' else style]);study=template['architecture']
            fabricator='office' if kind=='commercial' else 'mill' if style in ['mill_2102','alder_2122'] else 'industrial'
            localrect=[-depth+.6,.4,-1.2,width-.4];template['rect']=localrect
            study.update(style=style,side_bays=[max(3,int((depth-1.8)/3.05)),max(3,int((width-.8)/3.05))]*2)
            study.pop('outline_m',None)
            if kind=='commercial':
                study.update(precedent='Bank of the Manhattan Company,Queens Plaza;Morrell Smith1927;limestone-faced vertical office tower and stepped upper massing,AU35.2m cap',
                             source='https://s-media.nyc.gov/agencies/lpc/lp/2570.pdf',source_pdf_pages=[1,2,3,6],
                             floor_heights_m=[4.1]+[3.11]*10)
            local_outline=[[localrect[2],localrect[3]],[localrect[0],localrect[3]],
                           [localrect[0],localrect[1]],[localrect[2],localrect[1]]]
            canonical_front=(1,0)
        template['height_m']=sum(study['floor_heights_m']);template['id']=identity
        # Quarter turns only: no mesh scale, mirror, or floating root offset.
        turns=next(k for k in range(4) if ((canonical_front[0],canonical_front[1]),
              (-canonical_front[1],canonical_front[0]),(-canonical_front[0],-canonical_front[1]),
              (canonical_front[1],-canonical_front[0]))[k]==desired)
        co,si=[(1,0),(0,1),(-1,0),(0,-1)][turns]
        def rotate(x,y):return co*x-si*y,si*x+co*y
        reserve=([0,0],[width,0],[width,depth],[0,depth]) if kind=='rowhouse' else ([-depth,-width],[0,-width],[0,0],[-depth,0])
        rotated=[rotate(*p) for p in reserve];tx=a-min(p[0] for p in rotated);ty=-d-min(p[1] for p in rotated)
        frame=[[co,-si,0,tx],[si,co,0,ty],[0,0,1,0],[0,0,0,1]]
        points=[]
        for x,z in local_outline:
            X,Y=rotate(x,-z);points.append([X+tx,-Y-ty])
        row.update(height_m=template['height_m'],wall_key=template['wall_key'],
                   joinery_tint=template.get('joinery_tint',[.3,.32,.28,1]))
        row['architecture']=dict(type='packet_front',style=style,fabricator=fabricator,
            precedent=study['precedent'],source=study['source'],
            source_pages=study.get('source_pdf_pages',study.get('source_pages',[])),
            adaptation='AU lot fit,authored dimensions/finishes;reference form not surveyed1928 placement. Repeated examples are architectural families,not85different historical buildings. No new occupied interior,live leaf,shop,clock,save or collision owner.',
            outline_m=points,native_frame=frame,fabrication_profile=template)
        changed.append(identity)
    assert len(changed)==85 and len(rows)==124
    assert all(by_id[r['id']]['rect']==r['rect'] for r in replacement['buildings'])
    assert all(by_id[r['id']]==r for r in replacement['buildings'] if r['id'] not in changed)
    write(out/'proposed_source_plan.json',replacement)
    write(out/'packet_index.json',dict(evidence_class='INERT',baseline_plan_sha256=digest(ROOT/'art/data/city_horizon/source_plan.json'),
        changed=changed,preserved=[r['id'] for r in rows if r['id'] not in changed],
        blocks=sorted(set(block(i) for i in changed)),
        scope='Native delivery only;not installed,Godot-loaded,runtime-qualified or artistically accepted. Integrate once after current developer backlog;preserve current integration sources.'))
    return replacement,changed


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=pathlib.Path,required=True)
    parser.add_argument('--plan-only',action='store_true');parser.add_argument('--block');parser.add_argument('--review',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:])
    out=args.out.resolve();assert not out.is_relative_to(ROOT), 'Packet destination must be external'
    out.mkdir(parents=True,exist_ok=True)
    if args.plan_only:
        _,changed=prepare(out);print('Prepared',len(changed),'proposed replacements;installed sources unchanged');return
    sys.path.insert(0,str(ROOT/'art/blender/scripts'))
    build_block(out,args.block,args.review)


def build_block(out,identity,review):
    import bpy,bmesh
    from types import SimpleNamespace
    from mathutils import Vector,Matrix
    from mathutils.bvhtree import BVHTree
    from city_packet_architecture import PacketBuildings
    from city_horizon_geometry import building_outline,extrusion,validate_plan
    from city_ground_apron_geometry import relief_height
    from fabrication_native_batch import material,partition,export
    plan=json.loads((out/'proposed_source_plan.json').read_bytes())
    index=json.loads((out/'packet_index.json').read_bytes())
    assert digest(ROOT/'art/data/city_horizon/source_plan.json')==index['baseline_plan_sha256']
    assert identity in index['blocks'],identity
    grade=json.loads((ROOT/'art/blender/city_ground_apron_construction.json').read_bytes())
    validate_plan(plan,grade['retained_ground_bounds'])
    for row in plan['buildings']:
        outline=building_outline(row);samples=[(x,-y) for x,y in outline]
        study=row.get('architecture',{})
        if study.get('type')=='packet_front':
            frame=Matrix(study['native_frame']);local=study['fabrication_profile']
            for a,b,c,d in local['architecture'].get('court_paving_m',[]):
                samples.extend((v.x,-v.y) for v in [frame@Vector((x,-z,0)) for x,z in [(a,b),(c,b),(c,d),(a,d)]])
        for p,q in zip(outline,outline[1:]+outline[:1]):
            if abs(q[0]-p[0])<1e-12:continue
            for x,_ in grade['relief']['west_profile']:
                t=(x-p[0])/(q[0]-p[0])
                if 0<t<1:samples.append((x,-(p[1]+t*(q[1]-p[1]))))
        heights=[relief_height(x,z,-.02,grade['relief']) for x,z in samples]
        row.update(grade_datum_m=max(heights)+.02,grade_low_m=min(heights))
    rows=[r for r in plan['buildings'] if r['id'] in index['changed'] and block(r['id'])==identity]
    assert rows
    packet=out/identity.lower();packet.mkdir(exist_ok=True)
    if review:
        review_block(packet,rows);return
    assert not (packet/'manifest.json').exists(),'Do not overwrite a delivered packet'
    catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
    started=time.perf_counter();records=[]
    for lower in [False,True]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.threads_mode='FIXED';bpy.context.scene.render.threads=1
        collection=bpy.data.collections.new('ReplacementBodies');bpy.context.scene.collection.children.link(collection)
        buffers=collections.defaultdict(lambda:([],[]));witnesses=[];bearings=[];bodies=[]
        def emit(name,key,vertices,faces):
            vv,ff=buffers[(name,key)];start=len(vv);vv.extend(vertices);ff.extend(tuple(start+i for i in f) for f in faces)
        for row in rows:
            neighbours=[]
            for other in plan['buildings']:
                if other['id']==row['id']:continue
                points=building_outline(other)
                neighbours.append(dict(other,rect=[min(p[0] for p in points),-max(p[1] for p in points),
                                                   max(p[0] for p in points),-min(p[1] for p in points)]))
            proof=PacketBuildings(row,emit,neighbours,lower).build()
            datum=row['grade_datum_m']
            for (name,key),(vertices,faces) in buffers.items():
                if name==row['id']:vertices[:]=[(x,y,z+datum) for x,y,z in vertices]
            for field in ['windows','bearings','entries']:
                for witness in proof[field]:
                    for key in ['point','outside_probe']:
                        if key in witness:witness[key][2]+=datum
            bottom=row['grade_low_m']-.2;top=datum-.28
            if bottom<top-1e-7:
                v,f=extrusion(building_outline(row),bottom,top);emit(row['id'],'concrete',v,f)
            witnesses.extend(proof['windows']);bearings.extend(proof['bearings'])
            bodies.append(dict(id=row['id'],grade_datum_m=datum,proof=proof))
        by_id={r['id']:r for r in rows};draws=[];mats={}
        for (name,key),(vertices,faces) in sorted(buffers.items()):
            row=by_id[name]
            tint=row['wall_tint'] if key==row['wall_key'] else row.get('joinery_tint',[1,1,1,1]) if key in ['door_paint','cast_iron'] else [.16,.20,.23,1] if key=='mirror_aged' else [1,1,1,1]
            finish=dict(catalog_key=key,tint=tint,pigment=1.,normal=.12 if key=='mirror_aged' else .55,roughness=.45 if key=='mirror_aged' else 1.)
            if key=='mirror_aged':finish['metallic']=0.
            cache=(key,tuple(tint))
            if cache not in mats:mats[cache]=material(ROOT,name+'__'+key,finish,catalog)
            center=Vector(((min(v[0] for v in vertices)+max(v[0] for v in vertices))/2,
                           (min(v[1] for v in vertices)+max(v[1] for v in vertices))/2,0))
            mesh=bpy.data.meshes.new(name);mesh.from_pydata([Vector(v)-center for v in vertices],[],faces);mesh.update()
            bm=bmesh.new();bm.from_mesh(mesh)
            assert all(e.is_manifold and e.is_contiguous for e in bm.edges),name
            assert bm.calc_volume(signed=True)>0,name;bm.free()
            stock=bpy.data.objects.new(name,mesh)
            obj=partition(collection,name+'__'+key,[stock],finish,mats[cache],Matrix.Translation(center),catalog)
            draws.append(obj);bpy.data.objects.remove(stock);bpy.data.meshes.remove(mesh)
        vv=[];ff=[];owners=[]
        for obj in draws:
            start=len(vv);vv.extend(obj.matrix_world@v.co for v in obj.data.vertices)
            ff.extend(tuple(start+i for i in f.vertices) for f in obj.data.polygons)
            owners.extend([obj.name]*len(obj.data.polygons))
        tree=BVHTree.FromPolygons(vv,ff,all_triangles=True)
        for witness in witnesses:
            p=Vector(witness['point']);n=Vector(witness['normal'])
            hit,normal,i,distance=tree.ray_cast(p+n*.05,-n,.3)
            assert hit is not None and (hit-(p-n*witness['recess_m'])).length<.0001 and owners[i]==witness['building']+'__mirror_aged',witness
        for bearing in bearings:
            obj=next(o for o in draws if o.name==bearing['building']+'__galvanized_roof')
            roof=BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],
                 [tuple(f.vertices) for f in obj.data.polygons],all_triangles=True)
            p=Vector(bearing['point']);hit,*_=roof.ray_cast(p+Vector((0,0,.02)),Vector((0,0,-1)),.04)
            assert hit is not None and (hit-p).length<.0001,('roof seat',bearing)
            p=Vector(bearing['outside_probe']);hit,*_=roof.ray_cast(p+Vector((0,0,.02)),Vector((0,0,-1)),.04)
            assert hit is None,('roof outside control',bearing)
        level='lower' if lower else 'near';family=identity.lower()+'_'+level
        # The shared exporter writes exclusively into this external packet root.
        (packet/'game/assets/props').mkdir(parents=True,exist_ok=True)
        (packet/'art/blender').mkdir(parents=True,exist_ok=True)
        proof=export(packet,family,SimpleNamespace(objects=draws),save_native=False)
        # Keep existing maps external and explicitly bound; do not duplicate them.
        for image in bpy.data.images:
            if image.source=='FILE':image.filepath=str(ROOT/'game/assets/building/textures'/pathlib.Path(image.filepath).name)
        blend=packet/'art/blender'/(family+'.blend')
        bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
        asset=packet/'game/assets/props'/(family+'.glb')
        records.append(dict(level=level,asset=asset.relative_to(packet).as_posix(),sha256=digest(asset),bytes=asset.stat().st_size,
            native=blend.relative_to(packet).as_posix(),native_sha256=digest(blend),export_check=proof,
            parts=[dict(name=o.name,key=o.name.split('__')[-1],triangles=len(o.data.polygons)) for o in draws],
            panes=len(witnesses),roof_contacts=len(bearings),bodies=bodies))
    assert {p['name'] for p in records[0]['parts']}=={p['name'] for p in records[1]['parts']}
    assert records[0]['panes']==records[1]['panes']
    for near,lower in zip(records[0]['bodies'],records[1]['bodies']):
        assert near['id']==lower['id'] and near['proof']['entries']==lower['proof']['entries']
        assert near['proof'].get('flue_seats')==lower['proof'].get('flue_seats'),(near['id'],'replacement flues')
    sources=[ROOT/'art/data/city_horizon/source_plan.json',ROOT/'art/blender/city_ground_apron_construction.json',
             ROOT/'game/data/runtime_material_sets.json']+[ROOT/'art/blender/scripts'/p for p in
             ['build_city_building_packets.py','city_packet_architecture.py','city_industrial_architecture.py',
              'city_residential_architecture.py','fabrication_native_batch.py','fabrication_chart_batch.py',
              'fabrication_grain.py','fabrication_normals.py','check_exported_tangents.py','city_horizon_geometry.py','frame_mitre_geometry.py']]
    keys={p['key'] for p in records[0]['parts']}
    maps={name:dict(sha256=digest(ROOT/'game/assets/building/textures'/name),
                       colour_space='sRGB' if i==0 else 'linear')
          for key in keys for i,name in enumerate(catalog[key]['files'])}
    write(packet/'manifest.json',dict(evidence_class='INERT',block=identity,buildings=[r['id'] for r in rows],
        proposed_plan_sha256=digest(out/'proposed_source_plan.json'),source_bindings={str(p.relative_to(ROOT)):digest(p) for p in sources},
        maps_external=maps,records=records,native_build_elapsed_s=time.perf_counter()-started,
        scope='Closed stock,metric UV,exported derivatives,0.1mm recessed pane/roof rays. No Godot loaded mips,collision route,lighting,frame timing or artistic acceptance.'))
    print('PACKET COMPLETE',identity,len(rows),'buildings',flush=True)


def review_block(packet,rows):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from bpy_extras.object_utils import world_to_camera_view
    manifest=json.loads((packet/'manifest.json').read_bytes());roundtrips=[];captures=[]
    before={str(p.relative_to(packet)):digest(p) for p in packet.rglob('*') if p.is_file()}
    review=packet/'review';review.mkdir(exist_ok=False)
    def triangles(obj):
        obj.data.calc_loop_triangles()
        return collections.Counter(tuple(sorted(tuple(float(c) for c in obj.matrix_world@obj.data.vertices[i].co)
                    for i in t.vertices)) for t in obj.data.loop_triangles)
    def triangle_uvs(obj):
        obj.data.calc_loop_triangles();uv=obj.data.uv_layers.active.data
        result=collections.defaultdict(list)
        for t in obj.data.loop_triangles:
            pairs=sorted((tuple(float(c) for c in obj.matrix_world@obj.data.vertices[v].co),
                          tuple(float(c) for c in uv[l].uv)) for v,l in zip(t.vertices,t.loops))
            result[tuple(p for p,u in pairs)].append(tuple(u for p,u in pairs))
        return result
    for record in manifest['records']:
        native=packet/record['native'];asset=packet/record['asset']
        assert digest(native)==record['native_sha256'] and digest(asset)==record['sha256']
        bpy.ops.wm.open_mainfile(filepath=str(native))
        for col in bpy.data.collections:col.hide_viewport=False
        original={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
        for obj in original.values():obj.hide_viewport=False;obj.hide_render=True
        bpy.context.view_layer.update();prior=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(asset));bpy.context.view_layer.update()
        imported={}
        for obj in [o for o in bpy.data.objects if o not in prior and o.type=='MESH']:
            name=obj.name.split('.')[0];assert name in original and name not in imported
            assert triangles(obj)==triangles(original[name]),(name,'exported triangle coverage')
            assert len(obj.data.uv_layers)==1
            # GLB V -> 1-V -> Blender V includes two float32 roundings.
            # Compare each triangle corner, retaining coverage/multiplicity.
            import numpy as np
            actual=triangle_uvs(obj);expected=triangle_uvs(original[name]);maximum=0.
            assert actual.keys()==expected.keys()
            for key in expected:
                A=np.array(sorted(actual[key]));E=np.array(sorted(expected[key]))
                assert A.shape==E.shape
                delta=np.abs(A-E);maximum=max(maximum,float(delta.max()))
                bound=np.maximum(np.abs(E),1.)*np.finfo(np.float32).eps*4
                assert np.all(delta<=bound),(name,'UV drift',maximum,float(bound.max()))
            obj.data.materials.clear();obj.data.materials.append(original[name].data.materials[0]);imported[name]=obj
            roundtrips.append(dict(level=record['level'],part=name,triangles=len(obj.data.polygons),world_triangles_exact=True,uv_roundtrip=True,max_uv_roundtrip_drift_m=maximum,uv_bound='4 float32 ULP relative to max(abs(UV),1),including V flip'))
        assert set(imported)==set(original)
        vv=[];ff=[];owners=[]
        for name,obj in imported.items():
            start=len(vv);vv.extend(obj.matrix_world@v.co for v in obj.data.vertices)
            ff.extend(tuple(start+i for i in p.vertices) for p in obj.data.polygons);owners.extend([name]*len(obj.data.polygons))
        tree=BVHTree.FromPolygons(vv,ff)
        for body in record['bodies']:
            for witness in body['proof']['windows']:
                p=Vector(witness['point']);n=Vector(witness['normal']);hit,_,i,_=tree.ray_cast(p+n*.05,-n,.3)
                assert hit is not None and (hit-p+n*witness['recess_m']).length<.0001 and owners[i]==body['id']+'__mirror_aged'
        for image in bpy.data.images:
            if image.source=='FILE':
                name=pathlib.Path(image.filepath).name
                assert name in manifest['maps_external']
                path=ROOT/'game/assets/building/textures'/name
                assert digest(path)==manifest['maps_external'][name]['sha256']
                image.filepath=str(path);image.reload();assert min(image.size)>0
        scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU'
        scene.cycles.samples=8;scene.cycles.use_denoising=True;scene.cycles.max_bounces=3
        scene.render.threads_mode='FIXED';scene.render.threads=1
        scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
        world=bpy.data.worlds.new('Packet diagnostic daylight');world.use_nodes=True;scene.world=world
        world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.25,.30,1)
        world.node_tree.nodes['Background'].inputs[1].default_value=.8
        sun=bpy.data.objects.new('Review key',bpy.data.lights.new('Review key','SUN'));scene.collection.objects.link(sun)
        sun.data.energy=2.5;sun.data.angle=.16
        camera=bpy.data.objects.new('Review camera',bpy.data.cameras.new('Review camera'));scene.collection.objects.link(camera)
        scene.camera=camera;camera.data.type='ORTHO';camera.data.clip_start=.02;camera.data.clip_end=1500
        for row in rows:
            frame=row['architecture']['native_frame'];fabricator=row['architecture']['fabricator']
            local=(0,-1,0) if fabricator in ['house','civic_house'] else (1,0,0)
            front=Vector((frame[0][0]*local[0]+frame[0][1]*local[1],frame[1][0]*local[0]+frame[1][1]*local[1],0))
            tangent=Vector((-front.y,front.x,0))
            for label in (['front','rear'] if record['level']=='near' else ['front']):
                shown=[]
                for name,obj in imported.items():
                    obj.hide_render=name.split('__')[0]!=row['id']
                    if not obj.hide_render:shown.append(obj)
                points=[o.matrix_world@Vector(c) for o in shown for c in o.bound_box]
                lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
                target=(lo+hi)/2;direction=front if label=='front' else -front
                camera.location=target+(direction+tangent*.42+Vector((0,0,.45))).normalized()*250
                camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
                camera.data.ortho_scale=max(hi-lo)*1.2
                for attempt in range(24):
                    bpy.context.view_layer.update();projection=[world_to_camera_view(scene,camera,p) for p in points]
                    if all(p.z>0 and .04<=p.x<=.96 and .04<=p.y<=.96 for p in projection):break
                    camera.data.ortho_scale*=1.08
                else:raise AssertionError((row['id'],'whole body framing'))
                sun.rotation_euler=(-(direction+tangent*.35+Vector((0,0,1.25)))).to_track_quat('-Z','Y').to_euler()
                path=review/(row['id']+'_'+record['level']+'_'+label+'.png')
                scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
                captures.append(dict(file=path.relative_to(packet).as_posix(),sha256=digest(path),whole_body_framed=True))
                print('REVIEW FRAME',path.name,flush=True)
    assert all(digest(packet/path)==value for path,value in before.items())
    write(review/'review.json',dict(evidence_class='INERT',scope='Reopened native and imported GLB;exact world triangles/UVs,all recessed panes,CPU daylight whole-body front/rear near and front lower. Not installed renderer,capsule access,loaded mipmaps or artistic acceptance.',
        manifest_sha256=digest(packet/'manifest.json'),roundtrips=roundtrips,captures=captures,
        original_files_unchanged=before))


if __name__=='__main__':main()
