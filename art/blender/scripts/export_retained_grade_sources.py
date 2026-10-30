"""Read current editable construction into a classified, inert grade survey.

Never apply this output as soil directly: the runtime box survey and occupied
rooms must also be reconciled. Complex mesh AABBs are clearances, not solids.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--survey',type=Path,required=True);parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
survey=json.loads(args.survey.read_text());assert survey['failures']==0
bpy.ops.wm.read_factory_settings(use_empty=True)
rows=[];bindings={}

def bind(relative):
    path=ROOT/relative;raw=path.read_bytes()
    bindings[relative]=hashlib.sha256(raw if path.suffix in ['.blend','.glb'] else raw.replace(b'\r\n',b'\n')).hexdigest()
    return path

def append(owner,identity,bounds,kind):
    if bounds[1]>=.050001 or bounds[4]<=-4.:return
    assert all(math.isfinite(v) for v in bounds) and all(bounds[i]<bounds[i+3] for i in range(3)),identity
    rows.append(dict(owner=owner,id=identity,bounds=bounds,kind=kind))

def bounds(obj):
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    return [min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]

def objects(relative,predicate):
    with bpy.data.libraries.load(str(bind(relative)),link=False) as (available,loaded):loaded.objects=[n for n in available.objects if predicate(n)]
    for obj in loaded.objects:
        bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    return loaded.objects

with bpy.data.libraries.load(str(bind('art/blender/exterior_masonry.blend')),link=False) as (available,loaded):
    assert 'PreServiceMasonry' in available.collections;loaded.collections=['PreServiceMasonry']
for obj in loaded.collections[0].objects:
    assert obj.type=='EMPTY' and obj.parent is None and max(abs(v) for v in obj.rotation_euler)<1e-7
    p=obj.location;s=obj.scale;center=[p.x,p.z,-p.y];extent=[s.x,s.z,s.y]
    append('ExteriorMasonry',obj.name,[center[i]-extent[i]/2 for i in range(3)]+[center[i]+extent[i]/2 for i in range(3)],'authored_original_box')

for name in ['ground_core_transfer','rear_wing_a_support','rear_wing_c_support']:
    data=json.loads(bind('art/blender/'+name+'_construction.json').read_text())
    components=data.get('components',data['source_plan'].get('components',[]));assert components
    for row in components:append(name,row['id'],row['bounds'],'authored_union_component')
    bind('art/blender/'+name+'.blend');bind('game/assets/props/'+name+'.glb')

plan=json.loads(bind('art/blender/orison_foundations_construction.json').read_text())['source_plan']
for family in ['stem','footing']:
    for index,(a,b,c,d) in enumerate(plan[family+'s']):
        low,high=plan[family+'_y'];append('Foundations',family+'_%03d'%index,[a,low,b,c,high,d],'authored_union_component')
bind('art/blender/orison_foundations.blend');bind('game/assets/props/orison_foundations.glb')

for obj in objects('art/blender/service_alley.blend',lambda n:n.startswith(('PavingFoundation','BoundaryMasonry','BondedPier'))):
    assert obj.parent is None and max(abs(v) for v in obj.rotation_euler)<1e-7
    if obj.get('source_box_components_json'):
        kind='retained_continuous_paving_substrate' if obj.name.startswith('PavingFoundation') else 'authored_fitted_box_component'
        for index,component in enumerate(json.loads(obj['source_box_components_json'])):append('ServiceAlley',obj.name+'_'+str(index),component,kind)
        continue
    kind='retained_continuous_paving_substrate' if obj.name.startswith('PavingFoundation') else 'authored_original_box' if obj.name.startswith('BoundaryMasonry') else 'worked_arris_clearance_bounds'
    append('ServiceAlley',obj.name,bounds(obj),kind)

# The shaft reservation covers its masonry, while this worked pad extends
# outside it. Its measured bounds are a footing clearance, never an exact
# replacement for the beveled native concrete volume.
if any(r['id']=='C_STOVE_FLUE' for r in json.loads((ROOT/'game/data/orison_v2_blockout.json').read_bytes())['risers']):
    for obj in objects('art/blender/c_stove_stack/c_stove_stack.blend',lambda n:n=='ContinuousStackFooting'):
        append('CStoveStack',obj.name,bounds(obj),'worked_arris_footing_clearance_bounds')
    bind('game/assets/props/c_stove_stack.glb')

pose=survey['poses']['receiving']
def registered(p):return [pose['origin'][i]+sum(p[j]*pose[k][i] for j,k in enumerate(['x_axis','y_axis','z_axis'])) for i in range(3)]
for obj in objects('art/blender/bodega_receiving.blend',lambda n:n.startswith('Receiving')):
    if obj.type!='MESH':continue
    points=[registered([p.x,p.z,-p.y]) for p in [obj.matrix_world@v.co for v in obj.data.vertices]]
    b=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
    append('BodegaReceiving',obj.name,b,'authored_original_box' if obj.name.startswith('ReceivingFoundation') else 'worked_arris_clearance_bounds')

# The saved front pavement is a closed union of exact rectangular top cells.
# Preserve each cell and its genuine bottom; never substitute its envelope.
source=bind('art/blender/front_pavement.blend');meta=json.loads(bind('art/blender/front_pavement_construction.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(source));obj=bpy.data.objects['FittedPavementClosedUnion']
bm=bmesh.new();bm.from_mesh(obj.data);assert all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
assert volume>0 and abs(volume-meta['volume_m3'])<1e-5
low,high=meta['y'];cells=[]
for face in obj.data.polygons:
    points=[obj.matrix_world@obj.data.vertices[i].co for i in face.vertices]
    if not all(abs(p.z-high)<1e-7 for p in points):continue
    xs=[p.x for p in points];zs=[-p.y for p in points]
    b=[min(xs),low,min(zs),max(xs),high,max(zs)]
    assert len(points)==4 and set(zip(xs,zs))=={(x,z) for x in [b[0],b[3]] for z in [b[2],b[5]]}
    cells.append(b);append('FrontPavement','RetainedSlabCell_%03d'%(len(cells)-1),b,'authored_union_component')
assert abs(sum((b[3]-b[0])*(b[5]-b[2])*(high-low) for b in cells)-volume)<1e-5
for p in ['game/assets/props/exterior_masonry.glb','game/assets/props/service_alley.glb','game/assets/props/bodega_receiving.glb','game/assets/props/front_pavement.glb','game/scripts/generated/v2_exterior_masonry.gd']:bind(p)

# Station ground stock is classified individually in its saved native source.
# The shared city pose supplies the building frame; a whole station AABB would
# incorrectly fill the public footways, carriageway and stairs with soil masks.
transport=json.loads(bind('art/blender/city_transport_construction.json').read_text())
ground={r['id']:r for r in transport['stocks'] if r['lod']==0 and r['role'] in ['footing','pedestal','public_paving','curb']}
city_pose=survey['poses']['city']
axes=[city_pose[k] for k in ['x_axis','y_axis','z_axis']]
assert all(sum(abs(v)>.00003 for v in axis)==1 and abs(sum(v*v for v in axis)-1)<.00006 for axis in axes)
def station_point(point):
    local=[point.x,point.z,-point.y]
    return [city_pose['origin'][i]+sum(local[j]*city_pose[k][i] for j,k in enumerate(['x_axis','y_axis','z_axis'])) for i in range(3)]
native_ground=objects('art/blender/city_transport.blend',lambda n:n in ground)
assert len(native_ground)==len(ground)>0
for obj in native_ground:
    record=ground[obj.name];points=[obj.matrix_world@v.co for v in obj.data.vertices]
    actual=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
    assert max(abs(a-b) for a,b in zip(actual,record['bounds']))<.00003,obj.name
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),obj.name
    volume=bm.calc_volume(signed=True);bm.free();assert volume>0,obj.name
    box_volume=math.prod(actual[i+3]-actual[i] for i in range(3))
    exact=len(obj.data.vertices)==8 and abs(volume-box_volume)<max(1e-8,box_volume*1e-5)
    if exact:
        local_lo=[min(v.co[i] for v in obj.data.vertices) for i in range(3)]
        local_hi=[max(v.co[i] for v in obj.data.vertices) for i in range(3)]
        assert all(all(abs(v.co[i]-local_lo[i])<.00003 or abs(v.co[i]-local_hi[i])<.00003 for i in range(3)) for v in obj.data.vertices),obj.name
    transformed=[station_point(p) for p in points]
    box=[min(p[i] for p in transformed) for i in range(3)]+[max(p[i] for p in transformed) for i in range(3)]
    append('CityTransport',obj.name,box,'authored_original_box' if exact else 'worked_arris_clearance_bounds')
for p in ['art/data/city_transport/source_plan.json','art/blender/scripts/build_city_transport.py','game/assets/props/city_transport.glb','game/assets/props/city_transport_lod1.glb','game/scripts/building/orison_v2_city_transport.gd']:bind(p)

# Street stock has a common native underside. Nonrectangular polygon bounds
# reserve worked clearances, never exact solid volume. Roads are lower than
# the old terrain: their explicit above-surface air clearances prevent the
# retained -0.02m asphalt from covering the -0.10m carriageway.
streets=json.loads(bind('art/blender/city_streets_construction.json').read_text())
street_rows={r['id']:r for r in streets['stocks'] if r['lod']==0}
street_objects=objects('art/blender/city_streets.blend',lambda n:n in street_rows)
assert len(street_objects)==len(street_rows)>0
for obj in street_objects:
    row=street_rows[obj.name];points=[obj.matrix_world@v.co for v in obj.data.vertices]
    actual=[min(p[i] for p in points) for i in range(3)]+[max(p[i] for p in points) for i in range(3)]
    assert max(abs(a-b) for a,b in zip(actual,row['bounds']))<.00003,obj.name
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),obj.name
    volume=bm.calc_volume(signed=True);bm.free();assert volume>0,obj.name
    exact=len(obj.data.vertices)==8 and abs(volume-math.prod(actual[i+3]-actual[i] for i in range(3)))<1e-7
    if exact:
        lo=[min(v.co[i] for v in obj.data.vertices) for i in range(3)];hi=[max(v.co[i] for v in obj.data.vertices) for i in range(3)]
        exact=all(all(abs(v.co[i]-lo[i])<.000003 or abs(v.co[i]-hi[i])<.000003 for i in range(3)) for v in obj.data.vertices)
    transformed=[station_point(p) for p in points]
    box=[min(p[i] for p in transformed) for i in range(3)]+[max(p[i] for p in transformed) for i in range(3)]
    append('CityStreets',obj.name,box,'authored_original_box' if exact else 'worked_arris_clearance_bounds')
    if row['physical_id'].startswith(('Road_','Walk_')):
        # Air above the lowest actual surface point removes the old flat
        # soil from graded paving. This is an air clearance, never a solid
        # support claim. The deep native body bridges the bounded cut.
        air=list(box);air[1]=station_point(Vector((0,0,row['surface_low_m'])))[1];air[4]=.05
        append('CityStreetsAirClearance',obj.name+'/AboveSurface',air,'native_surface_air_clearance')
for p in ['art/data/city_streets/source_plan.json','art/blender/scripts/build_city_streets.py','art/blender/scripts/city_street_geometry.py','game/assets/props/city_streets.glb','game/assets/props/city_streets_lod1.glb','game/scripts/building/orison_v2_city_streets.gd']:bind(p)
bind(Path(__file__).relative_to(ROOT).as_posix())
result=dict(evidence_class='INERT',records=rows,bindings=bindings,front_cells=len(cells),front_volume_m3=volume,receiving_registration=pose,
    note='Native original masonry/union components, pavement cells and explicitly classified worked-arris clearances. Original paving substrate bounds reserve construction ownership; current graded cuts/air have their separate reservations. No whole mesh AABB is an exact solid.')
args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print('CURRENT GRADE SOURCES:',len(rows),'classified records;',len(cells),'exact front cells')
