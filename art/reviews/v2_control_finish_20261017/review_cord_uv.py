from pathlib import Path
import json,sys,math
import bpy,numpy as np
from mathutils import Vector,Matrix
T=Path(__file__).resolve().parent;R=T.parent.parent
sys.path.insert(0,str(T));from compare_geometry import read
before=T/'family_before/game/assets/props/task_lamp_supply.glb'
doc,values=read(before);best=None
for mesh in doc['meshes']:
    if 'B1_NOOK_LAMP_ClothFlex' not in mesh['name']:continue
    for primitive in mesh['primitives']:
        ids=values(primitive['indices']).reshape((-1,3)).astype(int)
        p=values(primitive['attributes']['POSITION']);uv=values(primitive['attributes']['TEXCOORD_0']);normals=values(primitive['attributes']['NORMAL'])
        for edge in range(3):
            a=ids[:,edge];b=ids[:,(edge+1)%3];length=np.linalg.norm(p[b]-p[a],axis=1);ratio=np.linalg.norm(uv[b]-uv[a],axis=1)/np.maximum(length,1e-20);ratio[length<.00005]=0
            i=int(np.argmax(ratio))
            if best is None or ratio[i]>best[0]:best=(float(ratio[i]),(p[a[i]]+p[b[i]])*.5,(normals[a[i]]+normals[b[i]])*.5)
assert best is not None
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)));target=C@Vector(best[1]);normal=(C@Vector(best[2])).normalized()
side=normal.cross(Vector((0,0,1)))
if side.length<.01:side=normal.cross(Vector((1,0,0)))
side.normalize();O=T/'cord_uv_review';O.mkdir(exist_ok=True)
for label,path in [('before',T/'family_before/art/blender/task_lamp_supply.blend'),('after',R/'art/blender/task_lamp_supply.blend')]:
    bpy.ops.wm.open_mainfile(filepath=str(path))
    for image in bpy.data.images:
        if image.source=='FILE':
            canonical=R/'game/assets/building/textures'/Path(image.filepath).name
            if canonical.exists():image.filepath=str(canonical);image.reload()
    for obj in bpy.data.objects:
        if obj.type=='MESH':obj.hide_render=True
    subject=next(obj for obj in bpy.data.objects if obj.type=='MESH' and obj.name.startswith('B1_NOOK_LAMP_ClothFlex') and obj.name.endswith('_review'))
    subject.hide_render=False
    for collection in subject.users_collection:collection.hide_render=False
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
    scene.render.resolution_x=1100;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Cord review');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.35,.4,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    for offset,power,size in [(normal*.055+side*.035,.4,.06),(normal*.03-side*.03,.12,.06)]:
        bpy.ops.object.light_add(type='AREA',location=target+offset);light=bpy.context.object
        light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=target+normal*.08);camera=bpy.context.object;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=.04;camera.data.clip_start=.0001;scene.camera=camera
    scene.render.filepath=str(O/(label+'.png'));bpy.ops.render.render(write_still=True)
(O/'diagnostic.json').write_text(json.dumps({'evidence_class':'INERT','old_maximum_edge_stretch':best[0],'target_godot':best[1].tolist(),'scope':'Same native cord, camera and light; UV-only local bend review, not route clearance or game acceptance.'},indent=2)+'\n',newline='\n')
