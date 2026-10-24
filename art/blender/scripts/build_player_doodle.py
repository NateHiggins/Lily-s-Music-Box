"""Preserve the supplied idle rig in a lighter, true-scale native player asset."""
from pathlib import Path
import bpy,json,math,hashlib
from mathutils import Vector
root=Path(__file__).resolve().parents[3]
source=root/'art/source/player_doodle_20261023/Meshy_AI_Smiling_Stick_Figure_biped'
review=root/'art/reviews/v2_player_doodle_20261023';review.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
path=next(source.glob('*Animation*.fbx'));bpy.ops.import_scene.fbx(filepath=str(path))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
action=rig.animation_data.action;action.name='Idle'
channels=[]
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in list(bag.fcurves):
                channels.append(curve.data_path)
                if curve.data_path in ['location','rotation_euler','rotation_quaternion','scale']:bag.fcurves.remove(curve)
rig.rotation_mode='XYZ';rig.rotation_euler=(0,0,0);rig.location=(0,0,0);rig.scale=(1,1,1)
scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=1;scene.frame_end=300;scene.frame_set(1)
before=len(mesh.data.polygons)
bpy.context.view_layer.objects.active=mesh;mesh.select_set(True)
modifier=mesh.modifiers.new('Mirror silhouette LOD','DECIMATE');modifier.ratio=.10
bpy.ops.object.modifier_move_to_index(modifier=modifier.name,index=0)
bpy.ops.object.modifier_apply(modifier=modifier.name)
mesh.data.calc_loop_triangles()
uv=mesh.data.uv_layers.active;assert uv is not None
bad=0
for triangle in mesh.data.loop_triangles:
    points=[uv.data[i].uv.copy() for i in triangle.loops]
    if abs((points[1]-points[0]).cross(points[2]-points[0]))<1e-12:bad+=1
assert bad==0,('degenerate supplied/decimated UV triangles',bad)
material=bpy.data.materials.new('player_doodle');material.use_nodes=True
node=material.node_tree.nodes['Principled BSDF'];node.inputs['Metallic'].default_value=0
for channel,target in [('albedo','Base Color'),('rough','Roughness'),('normal','Normal')]:
    image=bpy.data.images.load(str(root/('game/assets/building/textures/T_library_player_doodle_'+channel+'.png')))
    image.filepath=bpy.path.relpath(image.filepath,start=str(root/'art/blender'))
    if channel!='albedo':image.colorspace_settings.name='Non-Color'
    texture=material.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image
    if channel=='normal':
        normal=material.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.45
        material.node_tree.links.new(texture.outputs['Color'],normal.inputs['Color']);material.node_tree.links.new(normal.outputs[0],node.inputs[target])
    else:material.node_tree.links.new(texture.outputs['Color'],node.inputs[target])
mesh.data.materials.clear();mesh.data.materials.append(material)
bpy.context.view_layer.update();evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
points=[evaluated.matrix_world@v.co for v in evaluated.data.vertices]
head=rig.matrix_world@rig.pose.bones['smartrig:Head'].head
hips=rig.matrix_world@rig.pose.bones['smartrig:Hips'].head
up=head-hips;axis=max(range(3),key=lambda i:abs(up[i]));source_up=Vector((0,0,0));source_up[axis]=1 if up[axis]>0 else -1
orientation=source_up.rotation_difference(Vector((0,0,1)))
points=[orientation@v for v in points]
low=min(v.z for v in points);high=max(v.z for v in points);assert high-low>1.,('orientation',low,high)
scale=1.524/(high-low)
frame=bpy.data.objects.new('DoodleAvatar',None);scene.collection.objects.link(frame)
rig.parent=frame;frame.rotation_mode='QUATERNION';frame.rotation_quaternion=orientation
frame.scale=(scale,scale,scale);frame.location.z=-low*scale
mesh.name='DoodleBody';rig.name='DoodleRig'
bpy.context.view_layer.update()
native=root/'art/blender/player_doodle.blend';asset=root/'game/assets/characters/player_doodle/player_doodle.glb';asset.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(native))
bpy.ops.object.select_all(action='DESELECT')
for obj in [frame,rig,mesh]:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=True,export_skins=True,export_tangents=True,export_materials='NONE',export_apply=False)
report={'evidence_class':'INERT','source':path.relative_to(root).as_posix(),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'native':native.relative_to(root).as_posix(),'asset':asset.relative_to(root).as_posix(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_triangles':before,'runtime_triangles':len(mesh.data.loop_triangles),'vertices':len(mesh.data.vertices),'bones':len(rig.data.bones),'fps':30,'frames':[1,300],'clip':'Idle','scale':scale,'source_height_m':high-low,'uv_degenerate_triangles':bad,'removed_object_transform_channels':[s for s in channels if not s.startswith('pose.bones')],'limits':'Native preservation/LOD build. Loaded maps, deformation, orientation, loop continuity and mirror appearance require runtime review.'}
(review/'native_build.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(report))
