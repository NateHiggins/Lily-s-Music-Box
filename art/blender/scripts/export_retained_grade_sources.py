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
    kind='retained_continuous_paving_substrate' if obj.name.startswith('PavingFoundation') else 'authored_original_box' if obj.name.startswith('BoundaryMasonry') else 'worked_arris_clearance_bounds'
    append('ServiceAlley',obj.name,bounds(obj),kind)

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
bind(Path(__file__).relative_to(ROOT).as_posix())
result=dict(evidence_class='INERT',records=rows,bindings=bindings,front_cells=len(cells),front_volume_m3=volume,receiving_registration=pose,
    note='Native original masonry/union components, pavement cells and explicitly classified worked-arris clearances. Original paving substrate bounds reserve construction ownership; current graded cuts/air have their separate reservations. No whole mesh AABB is an exact solid.')
args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print('CURRENT GRADE SOURCES:',len(rows),'classified records;',len(cells),'exact front cells')
