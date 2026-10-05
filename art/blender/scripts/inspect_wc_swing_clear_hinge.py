"""Reopen saved native crank hardware; inspect solids, metric charts and motion."""
import argparse,hashlib,json,math
from pathlib import Path
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--out',required=True)
args=p.parse_args(__import__('sys').argv[__import__('sys').argv.index('--')+1:])
out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
native=ROOT/'art/blender/wc_swing_clear_hinge.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
meshes=[o for o in bpy.data.objects if o.type=='MESH'];triangles=0
for o in meshes:
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert bm.calc_volume(signed=True)>0,o.name
    bm.free();o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    assert o.get('hinge_half') in ('Fixed','Moving'),o.name
    assert len(o.data.uv_layers)==1 and o.data.uv_layers[0].name=='Metres',o.name
    assert all(math.isfinite(v) for uv in o.data.uv_layers[0].data for v in uv.uv),o.name
    for face in o.data.polygons:
        loops=list(face.loop_indices)
        for a,b in zip(loops,loops[1:]+loops[:1]):
            distance=(o.data.vertices[o.data.loops[a].vertex_index].co-o.data.vertices[o.data.loops[b].vertex_index].co).length
            chart=(o.data.uv_layers[0].data[a].uv-o.data.uv_layers[0].data[b].uv).length
            assert abs(distance-chart)<1e-6,(o.name,distance,chart)
    assert all(m.name=='iron_blackened' for m in o.data.materials),o.name
    if 'Knuckle' in o.name:
        centre=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
        assert abs(centre.x+.08)<1e-6 and abs(centre.y-.04)<1e-6,(o.name,centre)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('InspectionWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.6
light=bpy.data.lights.new('InspectionArea','AREA');light.energy=60;light.size=.25
lamp=bpy.data.objects.new(light.name,light);scene.collection.objects.link(lamp);lamp.location=(-.2,.3,.4)
camera=bpy.data.objects.new('InspectionCamera',bpy.data.cameras.new('InspectionCamera'));scene.collection.objects.link(camera)
scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=.23
camera.location=(-.25,.35,.22);camera.rotation_euler=(Vector((-.04,.03,0))-camera.location).to_track_quat('-Z','Y').to_euler()
axis=Vector((-.08,.04,0));turn=Matrix.Translation(axis)@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Translation(-axis)
for name in ['closed','open_90']:
    if name=='open_90':
        for o in meshes:
            if o['hinge_half']=='Moving':o.matrix_world=turn@o.matrix_world
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'inspection.json').write_text(json.dumps(dict(evidence_class='INERT',closed_positive_stocks=len(meshes),
    triangles=triangles,fixed_stocks=sum(o['hinge_half']=='Fixed' for o in meshes),moving_stocks=sum(o['hinge_half']=='Moving' for o in meshes),
    axis_godot=[-.08,0,-.04],native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),
    asset_sha256=hashlib.sha256((ROOT/'game/assets/props/wc_swing_clear_hinge.glb').read_bytes()).hexdigest()),indent=2)+'\n')
print('NATIVE WC HINGE:',len(meshes),'closed positive stocks;',triangles,'triangles; fixed and moving halves inspected')
