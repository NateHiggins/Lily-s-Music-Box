"""Native entry draft. Run only through the shared lane; never auto-installs.
blender --background --python THIS -- --root C:/ov/ldv --out PRIVATE_DIR [--render]
"""
from pathlib import Path
import argparse, collections, hashlib, json, math, sys
import bpy, bmesh
from mathutils import Vector, Matrix
argsv=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--plan',type=Path,default=None);ap.add_argument('--render',action='store_true');args=ap.parse_args(argsv)
ROOT=args.root.resolve();OUT=args.out.resolve()
if args.plan is None:args.plan=ROOT/'art/data/harukiya_entry/source_plan.json'
assert (ROOT/'game/project.godot').is_file()
assert not OUT.is_relative_to(ROOT), 'Private output must be outside checkout'
for folder in ['art/blender','game/assets/props']: (OUT/folder).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
import fabrication_native_batch as native
from harukiya_entry_schema import runtime_entry
from frame_mitre_geometry import frame_parts, interface_points
plan=json.loads(args.plan.read_text(encoding='utf-8'));catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
stocks=bpy.data.collections.new('EditableClosedStocks');bpy.context.scene.collection.children.link(stocks);stocks.hide_render=True
materials={k:native.material(ROOT,'entry_'+k,v,catalog) for k,v in plan['finishes'].items()}
# Capture canonical paths while material() still has absolute filenames. The
# shared exporter rewrites image.filepath relative to its output blend folder.
image_paths={image:Path(bpy.path.abspath(image.filepath)).resolve() for image in bpy.data.images if image.source=='FILE'}
assert all(path.is_file() for path in image_paths.values()), 'Missing registered map'
pieces=collections.defaultdict(list);checks=[];assembly='Static'
def solid(name,vs,fs,key):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
    volume=bm.calc_volume(signed=True);assert volume>1e-12 and all(e.is_manifold for e in bm.edges),name
    bm.to_mesh(mesh);bm.free();mesh.materials.append(materials[key]);obj=bpy.data.objects.new(name,mesh);stocks.objects.link(obj)
    points=[v.co for v in mesh.vertices];checks.append({'name':name,'assembly':assembly,'finish':key,'volume_m3':volume,'bounds_source':[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]]});pieces[(assembly,key)].append(obj);return obj
F=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
def box(name,lo,hi,key):
    assert all(hi[i]>lo[i] for i in range(3)),name
    return solid(name,[(x,y,z) for z in [lo[2],hi[2]] for y in [lo[1],hi[1]] for x in [lo[0],hi[0]]],F,key)
def rod(name,a,b,r,key,n=12):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))).normalized();v=axis.cross(u)
    vs=[p+r*(u*math.cos(i*math.tau/n)+v*math.sin(i*math.tau/n)) for p in [a,b] for i in range(n)]
    return solid(name,vs,[tuple(reversed(range(n)))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]+[tuple(range(n,2*n))],key)
# Exact full supporting source volumes, not a hidden ramp or cosmetic treads.
for row in plan['source_records']:
    identity=row['id']
    if '_acc_' in identity or identity=='retail_bar_mat':continue
    x0,y0,x1,y1=row['rect'];z=row['z0'];top=z+row['h']
    key='step' if any(t in identity for t in ['tread','floor','threshold']) else 'brick'
    if identity=='retail_bar_wall_e_lint':z=plan['door']['clear_header_z']
    if key=='brick' and z<.40:
        # Same closed source volume, split at a material seam: teal lower finish
        # with exposed soot-dark brick above. No overlapping cosmetic wall skin.
        split=min(.40,top)
        box(identity+' teal lower stock',(x0,y0,z),(x1,y1,split),'teal')
        if split<top:box(identity+' exposed brick upper stock',(x0,y0,split),(x1,y1,top),'brick')
    else:box(identity+' replacement',(x0,y0,z),(x1,y1,top),key)
# Thin inset-looking mat with a true bevelled approach, within old mat footprint.
# Broad lower skin is flush with floor; upper support is only 3mm proud.
box('Mat backing',(4.40,-34.60,-2.800),(5.80,-34.10,-2.799),'mat')
# Taper all four edges via eight-vertex truncated solid.
solid('Mat tapered wearing face',[(4.40,-34.60,-2.799),(5.80,-34.60,-2.799),(5.80,-34.10,-2.799),(4.40,-34.10,-2.799),(4.43,-34.57,-2.797),(5.77,-34.57,-2.797),(5.77,-34.13,-2.797),(4.43,-34.13,-2.797)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'mat')
# Wall-side rail leaves existing x4.8 route untouched; returned ends do not snag.
for x,wall in [(4.355,4.305),(5.845,5.895)]:
    a=(x,-30.05,.72);b=(x,-34.05,-1.68)
    rod('Continuous stair handrail',a,b,.024,'iron',16)
    for at in [a,b]:rod('Handrail return',at,(wall,at[1],at[2]),.024,'iron',16)
    for t in [.18,.48,.78]:
        at=Vector(a).lerp(Vector(b),t);rod('Rail bracket',(wall,at.y,at.z-.06),at,.009,'iron')
        box('Rail bracket plate',(min(wall,x)-.003,at.y-.035,at.z-.10),(max(wall,x)+.003,at.y+.035,at.z-.025),'iron')
# Drainage side detail sits on the outermost east edge of the lower landing,
# outside retained storage-free route; no cut through support slab.
box('Drain trough edge',(5.78,-35.40,-2.80),(5.88,-34.70,-2.796),'iron')
for i in range(14):box('Drain transverse bar',(5.78,-35.39+i*.048,-2.796),(5.88,-35.38+i*.048,-2.792),'iron')
# Aged services run ABOVE rail level, never through step solids. Segments
# terminate at the real junction enclosure, not in free air at tread edges.
service_a_y=-30.05;service_b_y=-33.70
service_bounds=[]
for i,r in enumerate([.022,.014,.009]):
    x=5.85-i*.045
    def service_z(y):return 1.35+(y-service_a_y)*(.175/.27)+i*.08
    for ya,yb in [(service_a_y,-31.62),(-31.92,service_b_y)]:
        a=(x,ya,service_z(ya));b=(x,yb,service_z(yb))
        rod('Above-rail conduit segment',a,b,r,'iron',16)
        axis=(Vector(b)-Vector(a)).normalized()
        for t in [.18,.70]:
            q=Vector(a).lerp(Vector(b),t)
            rod('Conduit sleeve coupling',q-axis*.015,q+axis*.015,r+.004,'iron',16)
            rod('Conduit wall stand-off',q,(5.895,q.y,q.z),.006,'iron')
        service_bounds.append({'source_start':a,'source_end':b,'radius_m':r+.004,'minimum_x':x-r-.004})
    # End returns visibly reach the east lining; these aren't orphan pipe cuts.
    for y in [service_a_y,service_b_y]:
        rod('Conduit terminal return',(x,y,service_z(y)),(5.90,y,service_z(y)),r,'iron',16)
# Small wall-mounted box with a separate cover and four actual fasteners.
# Same old-transformer narrative stock; moved up out of the tread envelope.
box('Wall-mounted dead transformer housing',(5.76,-31.92,.10),(5.90,-31.62,.60),'iron')
box('Transformer removable cover',(5.75,-31.915,.105),(5.76,-31.625,.595),'iron')
for y in [-31.88,-31.66]:
    for z in [.15,.55]:rod('Transformer cover fastener',(5.744,y,z),(5.752,y,z),.006,'iron',12)
# Door surround in original world frame; sides stay outside original .95 opening.
# Shared full-depth 45-degree joints; structural wall lintel remains separate.
liner=frame_parts(.95,plan['door']['clear_header_z']-(-2.80),.04,.26)
liner_seams=interface_points(liner) # Exact coincident caps and 45-degree check.
def liner_world(v):return (4.15+v[1],-34.425+v[0],-2.80+v[2])
for member,geometry in liner.items():
    solid('Mitred steel opening '+member,[liner_world(v) for v in geometry['vertices']],geometry['faces'],'iron')
liner_proof={'clear_width_m':.95,'clear_height_m':2.13,'board_width_m':.04,'depth_m':.26,
             'header_underside_source_z':plan['door']['clear_header_z'],
             'full_depth_45_degree_interfaces_source':{key:[liner_world(v) for v in points] for key,points in liner_seams.items()}}
# Separate door-local partitions: local x width, y thickness, z height.
# Godot conversion yields x width,y height,z negative depth. No world transform.
assembly='Leaf'
box('Red steel leaf skin',(.01,-.026,.02),(.89,.026,2.04),'red')
for x in [.045,.855]:box('Leaf reinforcement stile',(x-.018,-.034,.05),(x+.018,-.026,2.01),'iron')
for z in [.08,.73,1.98]:box('Leaf horizontal reinforcement',(.06,-.034,z-.018),(.84,-.026,z+.018),'iron')
# Below handle, readable stepped Deco relief, shallow enough for retained bounds.
for x in [.30,.60]:
    rod('Deco vertical relief',(x,-.030,.88),(x,-.030,1.30),.004,'brass',8)
    rod('Deco shoulder relief',(x,-.030,1.30),(.45,-.030,1.42),.004,'brass',8)
for x in [.045,.855]:
    for z in [.10,.47,.87,1.24,1.72,1.98]:rod('Rivet',(x,-.035,z),(x,-.038,z),.006,'iron')
box('Peephole dark backing',(.34,-.029,1.43),(.56,-.026,1.55),'iron')
for z in [1.425,1.555]:box('Peephole slide guide',(.32,-.037,z-.006),(.60,-.029,z+.006),'brass')
# Positive local Y is the stair-facing side after the actual marker rotation.
# Keep common knob/hinge regions clear; no duplicated mechanical hardware.
for x in [.045,.855]:
    box('Outer steel reinforcement stile',(x-.018,.026,.05),(x+.018,.034,2.01),'iron')
for z in [.08,.73,1.98]:
    box('Outer steel reinforcement rail',(.06,.026,z-.018),(.84,.034,z+.018),'iron')
for x in [.045,.855]:
    for z in [.10,.47,.87,1.24,1.72,1.98]:
        rod('Outer rivet',(x,.034,z),(x,.038,z),.006,'iron')
# Four distinct brass surround members around a dark, closed visual recess.
# This is a peephole appearance only; the plate does not cut the authority slab.
box('Outer peephole dark recess',(.34,.026,1.43),(.56,.029,1.55),'iron')
for x in [.332,.568]:
    box('Outer peephole surround side',(x-.006,.029,1.418),(x+.006,.037,1.562),'brass')
for z in [1.418,1.562]:
    box('Outer peephole surround rail',(.326,.029,z-.006),(.574,.037,z+.006),'brass')
for x in [.334,.566]:
    for z in [1.422,1.558]:
        rod('Outer surround fastener',(x,.037,z),(x,.040,z),.003,'brass')
# Restrained stepped crest gives the stair view a readable Deco silhouette.
for x0,x1,z in [(.30,.60,1.80),(.34,.56,1.83),(.39,.51,1.86)]:
    box('Outer stepped crest',(x0,.026,z),(x1,.032,z+.012),'red')
assembly='PeepholeCover'
box('Brass peephole sliding cover',(.335,-.035,1.434),(.565,-.030,1.546),'brass')
# Presentation-only distinct partition; root may animate only with explicit owner.
# Compact local fixture stocks. NO emission, live light or electrical authority.
# Source Z rotation -90 maps local depth Y to source X at each east-wall anchor.
fixture_clearance=[]
for fixture in plan['fixtures']:
    assembly=fixture['assembly'];magenta=assembly=='EntryMagenta'
    half=.25 if magenta else .22;height=.13 if magenta else .055
    box(assembly+' wall backplate',(-half,-.012,-height),(half,0,height),'iron')
    for x in [-half+.025,half-.025]:
        for z in [-height+.018,height-.018]:
            rod(assembly+' mounting screw',(x,-.019,z),(x,.002,z),.004,'iron')
    # Two tube terminals and their real stand-offs, continuous to the backplate.
    for x in [-.19,.19]:
        box(assembly+' terminal bearing',(x-.018,-.042,-.023),(x+.018,-.012,.023),'iron')
        rod(assembly+' ceramic socket',(x-.018,-.045,0),(x+.018,-.045,0),.018,'ceramic',16)
    rod(assembly+' plain tube',(-.19,-.045,0),(.19,-.045,0),.009,'tube',16)
    # Rear gland enters substrate; the hidden feed is a socket, not a new cable owner.
    rod(assembly+' feed gland',(.14,-.012,-.025),(.14,.002,-.025),.009,'ceramic',12)
    if magenta:
        frame=frame_parts(.48,.24,.02,.015)
        interface_points(frame)
        for member,g in frame.items():
            solid(assembly+' mitred vent '+member,[(x,y-.068,z-.13) for x,y,z in g['vertices']],g['faces'],'iron')
        for z in [-.085,-.045,-.005,.035,.075]:
            box(assembly+' protective grille blade',(-.24,-.075,z-.006),(.24,-.065,z+.006),'iron')
    else:
        for z in [-.043,.043]:
            rod(assembly+' tube guard',(-.20,-.070,z),(.20,-.070,z),.004,'iron',12)
            for x in [-.20,.20]:rod(assembly+' guard stand-off',(x,-.070,z),(x,-.012,z),.004,'iron',12)
    # Conservative source AABB against every retained storage/poster stock.
    local=[c for c in checks if c['assembly']==assembly]
    lows=[min(c['bounds_source'][0][j] for c in local) for j in range(3)]
    highs=[max(c['bounds_source'][1][j] for c in local) for j in range(3)]
    anchor=fixture['source_anchor'];lo=[anchor[0]+lows[1],anchor[1]-highs[0],anchor[2]+lows[2]];hi=[anchor[0]+highs[1],anchor[1]-lows[0],anchor[2]+highs[2]]
    assert lo[0]>5.28, ('Fixture narrows west circulation',assembly,lo)
    tested=[]
    for row in plan['retained_accumulation']:
        if 'rect' in row:
            q=row['rect'];low=[q[0],q[1],row['z0']];high=[q[2],q[3],row['z0']+row['h']]
        else:
            assert row.get('asm')=='pipe', ('Unknown retained envelope',row['id'])
            low=[min(row['p0'][j],row['p1'][j])-row['r'] for j in range(3)];high=[max(row['p0'][j],row['p1'][j])+row['r'] for j in range(3)]
        gaps=[max(low[j]-hi[j],lo[j]-high[j]) for j in range(3)]
        assert any(g>=0 for g in gaps), ('Fixture overlaps retained stock',assembly,row['id'])
        tested.append({'id':row['id'],'separating_axis_gap_m':max(gaps)})
    fixture_clearance.append({'id':fixture['id'],'local_bounds':[lows,highs],'source_bounds':[lo,hi],'retained_envelope_checks':tested,'scope':'source AABB checks only, not installed ray/capsule proof'})
parts=[];proofs={};families={'Static':'harukiya_entry','Door':'harukiya_entry_door','Fixtures':'harukiya_entry_fixtures'}
collections_out={}
for label,family in families.items():
    col=bpy.data.collections.new(family);bpy.context.scene.collection.children.link(col);collections_out[label]=col
    for (owner,key),objects in pieces.items():
        if (label=='Static' and owner!='Static') or (label=='Door' and owner not in ['Leaf','PeepholeCover']) or (label=='Fixtures' and owner not in ['EntryCyan','EntryMagenta']):continue
        obj=native.partition(col,owner+'__'+key,objects,plan['finishes'][key],materials[key],Matrix.Identity(4),catalog)
        parts.append({'name':obj.name,'family':family,'assembly':owner,'finish':key,'matkey':'entry_'+key,'triangles':len(obj.data.polygons),'bounds_source':[[min(v.co[i] for v in obj.data.vertices) for i in range(3)],[max(v.co[i] for v in obj.data.vertices) for i in range(3)]],'collision':'native static support' if owner=='Static' else ('NONE: retain DoorProp authority' if owner in ['Leaf','PeepholeCover'] else 'NONE: root-owned fixture mounting/collision policy')})
    # Reset absolute paths before EVERY export: no contextless second relpath.
    for image,path in image_paths.items():image.filepath=str(path)
    proofs[family]=native.export(OUT,family,col,material_names_only=True,save_native=False)
for part in parts:
    if part['assembly'] in ['EntryCyan','EntryMagenta']:
        fixture=next(f for f in plan['fixtures'] if f['assembly']==part['assembly'])
        part['fixture_id']=fixture['id'];part['is_emitter']=part['finish']=='tube'
# Set relative paths against the actual final blend directory exactly once.
blend_path=OUT/'art/blender/harukiya_entry.blend'
for image,path in image_paths.items():image.filepath=bpy.path.relpath(str(path),start=str(blend_path.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path),relative_remap=False)
image_bindings=[]
for image,path in image_paths.items():
    resolved=Path(bpy.path.abspath(image.filepath)).resolve()
    assert resolved==path and resolved.is_file(), ('Saved blend image path mismatch',image.name,str(resolved),str(path))
    image_bindings.append({'image':image.name,'blend_relative_path':image.filepath,'resolved_path':str(resolved)})
inputs=[args.plan,Path(__file__),ROOT/'game/data/runtime_material_sets.json',ROOT/'art/blender/scripts/frame_mitre_geometry.py',ROOT/'art/data/building_layout.json',ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf',ROOT/'game/assets/building/floor_01_cells/shop_bar.bin']
inputs.append(ROOT/'art/blender/scripts/harukiya_entry_schema.py')
report={'status':'BUILT_NOT_INSTALLED_OR_PLAYED','source_hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},'image_bindings':image_bindings,'liner_mitre_proof':liner_proof,'service_routes':service_bounds,'fixture_clearance':fixture_clearance,'parts':parts,'closed_stock_checks':checks,'strict_export_derivatives':proofs,'plan':plan,'limitations':['Retirement triangle map not generated: source records are only the requested set','No native collision, door sweep, clothing, FIFO or artistic acceptance','No neon/light actor authority or lettering exported']}
runtime=dict(plan);runtime['native_parts']=[x for x in parts if x['assembly']=='Static'];runtime['door_parts']=[x for x in parts if x['assembly'] in ['Leaf','PeepholeCover']];runtime['fixture_parts']=[x for x in parts if x['assembly'] in ['EntryCyan','EntryMagenta']];runtime['fixture_clearance']=fixture_clearance;runtime['status']='BUILT_NOT_QUALIFIED'
(OUT/'harukiya_entry_full.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8')
(OUT/'harukiya_entry.json').write_text(json.dumps(runtime_entry(runtime),indent=2)+'\n',encoding='utf-8')
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if args.render:
    # Review only static architecture; local leaf/cover are temporarily placed
    # with explicit original marker for presentation, not baked into exports.
    for label in ['Door']:
        for obj in collections_out[label].objects:
            obj.matrix_world=Matrix.Translation(Vector((4.15,-33.95,-2.8)))@Matrix.Rotation(-math.pi/2,4,'Z')
    for fixture in plan['fixtures']:
        frame=Matrix.Translation(Vector(fixture['source_anchor']))@Matrix.Rotation(math.radians(fixture['source_yaw_deg']),4,'Z')
        for obj in collections_out['Fixtures'].objects:
            if obj.name.startswith(fixture['assembly']+'__'):obj.matrix_world=frame
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
    scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
    for pos,power,size in [((3,-29,3),500,4),((5,-34,0),180,2)]:
        bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector((4.8,-32,-1))-light.location).to_track_quat('-Z','Y').to_euler()
    # Audit framing: complete door/header and street rim, not cropped details.
    views=[('descent',(4.8,-28.0,1.65),(4.8,-31.7,-.65),18,1280,960),
           ('lower_turn',(5.60,-34.425,-1.73),(4.15,-34.425,-1.73),24,960,1280),
           ('ascending',(4.8,-34.6,-1.15),(4.8,-29.2,.95),18,1280,960),
           ('street_rim',(4.8,-27.1,1.80),(4.8,-30.3,-.25),20,1280,960)]
    for name,pos,at,lens,width,height in views:
        scene.render.resolution_x=width;scene.render.resolution_y=height
        bpy.ops.object.camera_add(location=pos);camera=bpy.context.object;camera.data.lens=lens;camera.data.sensor_fit='HORIZONTAL';camera.rotation_euler=(Vector(at)-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera;scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
