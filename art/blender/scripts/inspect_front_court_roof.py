"""Reopen the saved roof frame, inspect actual stocks and render read-only fit."""
from pathlib import Path
import hashlib,json,math
import bpy,bmesh,numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
fixture=json.loads((ROOT/'art/blender/front_court_roof_inventory.json').read_bytes())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/front_court_roof.blend'))
for row in fixture['stocks']:
    bm=bmesh.new();bm.from_mesh(bpy.data.objects[row['name']].data)
    volume=bm.calc_volume(signed=True)
    assert volume>0 and all(e.is_manifold for e in bm.edges),row['name']
    assert abs(volume-row['volume_m3'])<max(1e-10,volume*1e-5),row['name']
    points=np.asarray([v.co[:] for v in bm.verts]);bounds=np.concatenate((points.min(axis=0),points.max(axis=0)))
    assert np.allclose(bounds,row['bounds'],atol=1e-7,rtol=0),row['name'];bm.free()
for image in bpy.data.images:
    if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
for group in ['source_bindings','retained_bindings']:
    for rel,h in fixture[group].items():assert hashlib.sha256((ROOT/rel).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==h,rel
assert hashlib.sha256((ROOT/'game/assets/props/front_court_roof.glb').read_bytes()).hexdigest()==fixture['asset_sha256']
for row in fixture['parts']:
    mesh=bpy.data.objects[row['name']].data;mesh.calc_loop_triangles();assert len(mesh.loop_triangles)==row['triangles']
    coords=np.asarray([v.co[:] for v in mesh.vertices]);assert (coords.max(axis=0)-coords.min(axis=0)).max()<=4.00002

# Actual production fabric is temporary context, never saved into the native.
fabric=json.loads((ROOT/'tmp/v2-facade/fabric-before.json').read_bytes())
brick=bpy.data.materials.new('ReadOnlyRetainedBrick');brick.diffuse_color=(.18,.065,.035,1)
slab=bpy.data.materials.new('ReadOnlyRetainedSlab');slab.diffuse_color=(.3,.28,.25,1)
for row in fabric['draws']:
    if 'ExteriorMasonry' not in row['path'] and not ('ROOF_DECK_' in row['path'] and '/Floor' in row['path']):continue
    points=[(p[0],-p[2],p[1]) for p in row['faces']]
    mesh=bpy.data.meshes.new('ReadOnlyContext');mesh.from_pydata(points,[],[(i,i+1,i+2) for i in range(0,len(points),3)]);mesh.update()
    obj=bpy.data.objects.new('ReadOnlyContext',mesh);bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(brick if 'ExteriorMasonry' in row['path'] else slab)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('InspectionWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.22,.28,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
for at,power,size in [((0,13,17),2000,6),((-3,9,17),1200,3),((7,12,17),1200,3)]:
    data=bpy.data.lights.new('InspectionArea','AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=at
    obj.rotation_euler=(Vector((1,8,18.7))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('InspectionCamera');camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera
out=ROOT/'tmp/v2-facade/roof-frame-native';out.mkdir(parents=True,exist_ok=True)
for name,at,target,lens in [('frame',(0,16,15.5),(1,8,18.4),24),('left_bearing',(-3.6,9.6,17.2),(-5.13,8.1,18.1),43),('front_right_bearing',(7.6,13.2,17.4),(9.02,12,18.2),43)]:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();data.lens=lens
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_positive_stocks':len(fixture['stocks']),'triangles':fixture['triangles'],
    'parts':len(fixture['parts']),'renders':3,'native_sha256':hashlib.sha256((ROOT/'art/blender/front_court_roof.blend').read_bytes()).hexdigest()},indent=2)+'\n')
print('NATIVE FRONT COURT ROOF:',len(fixture['stocks']),'closed stocks; source, maps and parts checked; three renders')
