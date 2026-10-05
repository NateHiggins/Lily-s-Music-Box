"""Reopen actual masonry stocks and check their retained slab interfaces."""
from pathlib import Path
import json, hashlib, math, argparse, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
args=argparse.ArgumentParser()
args.add_argument('--out', required=True)
args.add_argument('--before', help='Immutable previous native file for exact occupied-cell comparison')
options=args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
out=Path(options.out);out.mkdir(parents=True,exist_ok=True)
fixture=json.loads((ROOT/'art/blender/exterior_masonry_slab_fit.json').read_bytes())
assert hashlib.sha256((ROOT/'game/data/orison_v2_blockout.json').read_bytes().replace(b'\r\n',b'\n')).hexdigest()==fixture['source_sha256_lf']
before=[]
if options.before:
    bpy.ops.wm.open_mainfile(filepath=options.before)
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH':continue
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        before.append([min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),
                       max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/exterior_masonry.blend'))
actual=[];triangles=0
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in bm.edges) and bm.calc_volume(signed=True)>0,obj.name
    bm.free()
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    bounds=[min(p.x for p in points),min(p.z for p in points),-max(p.y for p in points),
            max(p.x for p in points),max(p.z for p in points),-min(p.y for p in points)]
    expected=next(row for row in fixture['stocks'] if row['name']==obj.name)
    assert max(abs(a-b) for a,b in zip(bounds,expected['bounds']))<.00001,obj.name
    for ceiling in fixture['ceiling_volumes']:
        cut=ceiling['bounds']
        overlap=[min(bounds[i+3],cut[i+3])-max(bounds[i],cut[i]) for i in range(3)]
        assert min(overlap)<.00001,(obj.name,ceiling['owner'],overlap)
    obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
    actual.append(bounds)
assert len(actual)==len(fixture['stocks'])
cells=0
if before:
    old=np.asarray(before);new=np.asarray(actual);cuts=np.asarray([r['bounds'] for r in fixture['ceiling_volumes']]+[r['bounds'] for r in fixture.get('door_clearance_cuts',[])])
    # Partition each real stock at every intersecting old/new/slab boundary.
    # Midpoint occupancy then checks the entire orthogonal volume, including
    # both directions of the equality new = old minus retained ceilings.
    for bounds in np.concatenate((old,new)):
        candidates=[]
        for table in [old,new,cuts]:
            mask=np.all(np.minimum(table[:,3:],bounds[3:])-np.maximum(table[:,:3],bounds[:3])>1e-6,axis=1)
            candidates.append(table[mask])
        axes=[]
        for axis in range(3):
            stations=sorted({bounds[axis],bounds[axis+3],*[float(v) for table in candidates for v in table[:,[axis,axis+3]].ravel() if bounds[axis]+1e-5<v<bounds[axis+3]-1e-5]})
            axes.append([(a+b)*.5 for a,b in zip(stations,stations[1:]) if b-a>1e-5])
        points=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1).reshape(-1,3)
        def occupied(table):
            if not len(table):return np.zeros(len(points),dtype=bool)
            return np.any(np.all((points[:,None,:]>table[None,:,:3]-1e-6)&(points[:,None,:]<table[None,:,3:]+1e-6),axis=2),axis=1)
        was,present,slab=[occupied(table) for table in candidates]
        assert np.array_equal(present,was&~slab),points[present!=(was&~slab)][:5]
        cells+=len(points)
    removed=float(np.prod(old[:,3:]-old[:,:3],axis=1).sum()-np.prod(new[:,3:]-new[:,:3],axis=1).sum())
    expected_removed=fixture['removed_m3']+sum(row['removed_m3'] for row in fixture.get('door_corner_fits',[]))
    assert abs(removed-expected_removed)<.0001,(removed,expected_removed)

# The generated volume table is checked against actual native bounds, not used
# as a substitute for reopening the asset. The two previously competing lobby
# surfaces have a full slab-thickness separation after this fit.
for ceiling in fixture['ceiling_volumes']:
    if ceiling['owner']!='F01_LOBBY':continue
    bottom=ceiling['bounds'][1]
    assert not any(abs(b[1]-bottom)<.00001 and
                   min(b[3],ceiling['bounds'][3])-max(b[0],ceiling['bounds'][0])>.00001 and
                   min(b[5],ceiling['bounds'][5])-max(b[2],ceiling['bounds'][2])>.00001 for b in actual)

# Temporary retained ceiling context is never saved into the editable masonry.
mat=bpy.data.materials.new('RetainedCeilingContext');mat.diffuse_color=(.6,.57,.52,1)
for ceiling in fixture['ceiling_volumes']:
    if ceiling['owner'] not in ['F01_LOBBY','F04_B_MAIN']:continue
    a,y,b,c,top,d=ceiling['bounds']
    mesh=bpy.data.meshes.new('RetainedCeilingContext')
    mesh.from_pydata([(a,-b,y),(a,-d,y),(c,-d,y),(c,-b,y)],[],[(0,1,2,3)])
    obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(mat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1280;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('InspectionWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65
light=bpy.data.lights.new('InspectionArea','AREA');light.energy=800;light.shape='DISK';light.size=4
lamp=bpy.data.objects.new(light.name,light);scene.collection.objects.link(lamp)
data=bpy.data.cameras.new('InspectionCamera');camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera);scene.camera=camera;data.lens=18
for name,at,target in [('lobby',(3.67,4.71,1.44),(0,6.55,2.1)),('upper_home',(-8.846,-2.282,11.04),(-11.6,.2,12.3))]:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    lamp.location=at;lamp.rotation_euler=camera.rotation_euler
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'inspection.json').write_text(json.dumps(dict(evidence_class='INERT',closed_positive_stocks=len(actual),
    triangles=triangles,slab_interfaces=len(fixture['slab_fits']),removed_duplicate_volume_m3=fixture['removed_m3'],
    removed_door_corner_volume_m3=sum(row['removed_m3'] for row in fixture.get('door_corner_fits',[])),
    compared_occupied_cells=cells,previous_native_sha256=hashlib.sha256(Path(options.before).read_bytes()).hexdigest() if options.before else None,
    native_sha256=hashlib.sha256((ROOT/'art/blender/exterior_masonry.blend').read_bytes()).hexdigest(),
    asset_sha256=hashlib.sha256((ROOT/'game/assets/props/exterior_masonry.glb').read_bytes()).hexdigest()),indent=2)+'\n')
print('NATIVE MASONRY:',len(actual),'closed stocks;',triangles,'triangles; retained ceiling volumes clear')
