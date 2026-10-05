"""Reopen the saved façade; inspect its actual stocks and render fitted source."""
from pathlib import Path
import hashlib,json,math,os
import bpy,bmesh,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
fixture=json.loads((ROOT/'art/blender/front_facade_inventory.json').read_bytes())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/front_facade.blend'))
checks=[]
for row in fixture['stocks']:
    obj=bpy.data.objects[row['name']];bm=bmesh.new();bm.from_mesh(obj.data)
    assert all(e.is_manifold for e in bm.edges),row['name']
    volume=bm.calc_volume(signed=True);assert volume>0 and abs(volume-row['volume_m3'])<max(1e-10,volume*1e-5),(row['name'],volume)
    points=np.array([v.co[:] for v in bm.verts]);bounds=np.concatenate((points.min(axis=0),points.max(axis=0)))
    assert np.allclose(bounds,row['bounds'],atol=1e-7,rtol=0),row['name'];bm.free();checks.append(row['name'])
for image in bpy.data.images:
    if image.source=='FILE':assert image.filepath.startswith('//') and Path(bpy.path.abspath(image.filepath)).is_file(),image.filepath
for group in ['source_bindings','retained_bindings']:
    for rel,h in fixture[group].items():assert hashlib.sha256((ROOT/rel).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==h,rel
assert hashlib.sha256((ROOT/'game/assets/props/front_facade.glb').read_bytes()).hexdigest()==fixture['asset_sha256']
for row in fixture['parts']:
    obj=bpy.data.objects[row['name']];obj.data.calc_loop_triangles();assert len(obj.data.loop_triangles)==row['triangles']
leaf=bpy.data.objects['EntryLeaf'];leaf.location=(fixture['door']['width']/2,-.035,0);leaf.rotation_euler.z=math.pi
# Temporary read-only fabric from the production discovery, never resaved.
fabric=json.loads((ROOT/'tmp/v2-facade/fabric-before.json').read_bytes())
stone=bpy.data.materials.new('ReadOnlyRetainedBrick');stone.diffuse_color=(.18,.065,.035,1)
front=fixture['facade_root_z']
for row in fabric['draws']:
    if not any(s in row['path'] for s in ['ExteriorMasonry','F01_VESTIBULE/Wall','F01_LOBBY/Wall']):continue
    points=[(-p[0],p[2]-front,p[1]) for p in row['faces']]
    mesh=bpy.data.meshes.new('ReadOnlyContext');mesh.from_pydata(points,[],[(i,i+1,i+2) for i in range(0,len(points),3)]);mesh.update()
    obj=bpy.data.objects.new('ReadOnlyContext',mesh);bpy.context.scene.collection.objects.link(obj);mesh.materials.append(stone)
bpy.ops.mesh.primitive_plane_add(size=50,location=(0,0,-.003));bpy.context.object.data.materials.append(stone)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('NativeInspectionWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.15,.18,.24,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
for location,power,size in [((2,-5,6),1000,4),((-4,-3,4),600,3),((0,-.8,3.30),35,.5)]:
    data=bpy.data.lights.new('NativeInspectionArea','AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=location;obj.rotation_euler=(Vector((0,-.3,1.6))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('NativeInspectionCamera');camera=bpy.data.objects.new('NativeInspectionCamera',data);scene.collection.objects.link(camera);scene.camera=camera
out=ROOT/'tmp/v2-facade/native';out.mkdir(parents=True,exist_ok=True)
for name,at,target,lens in [('entrance',(3,-6,2.2),(0,-.2,1.9),45),('canopy',(2,-3,2.1),(0,-.8,3.25),44),('leaf',(.7,-1.6,1.6),(0,-.04,1.1),48)]:
    camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();data.lens=lens
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','closed_positive_stocks':len(checks),'triangles':fixture['triangles'],'renders':3,'source_file_sha256':hashlib.sha256((ROOT/'art/blender/front_facade.blend').read_bytes()).hexdigest()},indent=2)+'\n')
print('NATIVE FRONT FACADE INSPECTION:',len(checks),'positive closed stocks; all bounds, volumes, maps and bindings checked; three renders')
