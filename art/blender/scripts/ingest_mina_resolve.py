"""Ingest the owner's Gray Resolve FBX batch, with no donor animation library.

Run Blender --background --factory-startup --python this_file. Raw exports
live in the ignored art/blender/meshy directory; the manifest identifies
exactly twenty files. Produces a motion-free hero, a personal skeleton-only
library and a packed, editable Blender source with the same twenty actions.
Navigation owns travel. The bake removes horizontal hip travel and plants
the lowest shoe on the actor's floor, including stair clips. Loop tails blend
to their opening pose; discrete gestures remain one-shots at runtime.
"""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[3]
MANIFEST = ROOT / 'art/data/mina_resolve/clip_manifest.json'
OUT = ROOT / 'game/assets/characters/mina_vale'
BLEND = ROOT / 'art/blender/mina_resolve.blend'
STOCK_BONES = dict(zip(
    ['Hips','Spine02','Spine01','Spine','neck','Head','LeftShoulder',
     'LeftArm','LeftForeArm','LeftHand','RightShoulder','RightArm',
     'RightForeArm','RightHand','LeftUpLeg','LeftLeg','LeftFoot','LeftToeBase',
     'RightUpLeg','RightLeg','RightFoot','RightToeBase'],
    ['spine','spine.001','spine.002','spine.003','spine.004','spine.005',
     'shoulder.L','upper_arm.L','forearm.L','hand.L','shoulder.R',
     'upper_arm.R','forearm.R','hand.R','thigh.L','shin.L','foot.L','toe.L',
     'thigh.R','shin.R','foot.R','toe.R']))


def curves(action):
    result = {}
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path.startswith('pose.bones["'):
                        bone = fc.data_path.split('"')[1]
                        prop = fc.data_path.rsplit('.',1)[1]
                        result.setdefault(bone,{}).setdefault(prop,{})[fc.array_index] = fc
    return result


def rotation(entry, frame):
    channels = entry.get('rotation_quaternion',{})
    return Quaternion(tuple(channels[i].evaluate(frame) if i in channels
                            else float(i == 0) for i in range(4))).normalized()


def hierarchy(rig):
    ordered = []
    def visit(bone):
        ordered.append(bone.name)
        for child in bone.children: visit(child)
    for bone in rig.data.bones:
        if bone.parent is None: visit(bone)
    return ordered


def world_rotations(rig, data, frame):
    result = {}
    for n in hierarchy(rig):
        b=rig.data.bones[n]
        rest=((b.parent.matrix_local.inverted() @ b.matrix_local)
              if b.parent else b.matrix_local).to_quaternion()
        local=rest @ rotation(data.get(n,{}),frame)
        result[n]=result[b.parent.name] @ local if b.parent else rig.matrix_world.to_quaternion() @ local
    return result


def bake(target, source, action, spec, fps):
    ordered = hierarchy(target)
    source_order = hierarchy(source)
    mapping = {n:n if n in source.data.bones else STOCK_BONES.get(n,n)
               for n in ordered}
    data = curves(action)
    source_rest = {}
    for n in source_order:
        b = source.data.bones[n]
        source_rest[n] = ((b.parent.matrix_local.inverted() @ b.matrix_local)
                          if b.parent else b.matrix_local).to_quaternion()
    target_rest = {}
    delta = {}
    for n in ordered:
        b = target.data.bones[n]
        target_rest[n] = ((b.parent.matrix_local.inverted() @ b.matrix_local)
                          if b.parent else b.matrix_local).to_quaternion()
        sn = mapping[n]
        delta[n] = ((source.matrix_world @ source.data.bones[sn].matrix_local)
                    .to_quaternion().inverted()
                    @ (target.matrix_world @ b.matrix_local).to_quaternion())
    f0,f1 = action.frame_range
    if spec['clip'].endswith('_builtin'):
        # The stock FBXs carry a folded upper-body bind (and a differently
        # named Rigify rig). Align their opening upper body to this batch's
        # calm idle before transferring motion, rather than importing that
        # bind's permanent shoulder twist. Legs retain the supplied gait.
        neutral=world_rotations(target,curves(bpy.data.actions['mina_idle_calm']),0)
        opening=world_rotations(source,data,f0)
        for n in ordered:
            if any(part in n for part in ['Shoulder','Arm','Hand','Spine','neck','Head','head']):
                delta[n]=opening[mapping[n]].inverted() @ neutral[n]
    duration = (f1-f0) / fps
    frames = max(1, round(duration*30))
    poses = []
    for frame in range(frames+1):
        sf = f0 + (f1-f0)*frame/frames
        world = {}
        for n in source_order:
            b = source.data.bones[n]
            local = source_rest[n] @ rotation(data.get(n,{}),sf)
            world[n] = world[b.parent.name] @ local if b.parent else source.matrix_world.to_quaternion() @ local
        mapped = {n: target.matrix_world.to_quaternion().inverted() @ world[mapping[n]] @ delta[n] for n in ordered}
        pose = {}
        for n in ordered:
            b = target.data.bones[n]
            local = mapped[b.parent.name].inverted() @ mapped[n] if b.parent else mapped[n]
            pose[n] = (target_rest[n].inverted() @ local).normalized()
        poses.append(pose)
    if spec['loop']:
        tail = min(9,frames//5)
        for f in range(frames-tail,frames+1):
            weight=(f-(frames-tail))/tail
            weight=weight*weight*(3-2*weight)
            for n in ordered: poses[f][n] = poses[f][n].slerp(poses[0][n],weight)
    result = bpy.data.actions.new(spec['clip'])
    result.use_fake_user = True
    target.animation_data_create()
    target.animation_data.action = result
    last = {}
    scene = bpy.context.scene
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent == target]
    for frame,pose in enumerate(poses):
        scene.frame_set(frame)
        for n in ordered:
            pb = target.pose.bones[n]
            q=pose[n]
            if n in last and last[n].dot(q)<0: q=-q
            last[n]=q.copy()
            pb.rotation_mode='QUATERNION'; pb.rotation_quaternion=q
            pb.location=(0,0,0); pb.scale=(1,1,1)
            pb.keyframe_insert('rotation_quaternion',frame=frame)
        # Evaluate the actual decimated shoes. Keeping one sole on the floor
        # removes stair rise and generated jumps without guessing bone offsets.
        bpy.context.view_layer.update()
        depsgraph=bpy.context.evaluated_depsgraph_get()
        floor=math.inf
        for ob in meshes:
            evaluated=ob.evaluated_get(depsgraph)
            mesh=evaluated.to_mesh()
            floor=min(floor,min((evaluated.matrix_world @ v.co).z for v in mesh.vertices))
            evaluated.to_mesh_clear()
        if not math.isfinite(floor): raise ValueError('No skinned mesh for floor contact')
        hip=target.pose.bones['Hips']
        # Hips is the root; location is expressed in its bind rotation.
        hip.location=target.data.bones['Hips'].matrix_local.to_3x3().inverted() @ Vector((0,0,-floor))
        hip.keyframe_insert('location',frame=frame)
    print('BAKED',spec['clip'],frames/30,'seconds',flush=True)
    return result, {'clip':spec['clip'],'duration_seconds':frames/30,'source_fps':fps,'source_seconds':duration}


def main():
    manifest=json.loads(MANIFEST.read_text(encoding='utf-8'))
    if len(manifest['animations']) != 20 or manifest['limit'] != 20:
        raise ValueError('The first batch must contain exactly twenty animations')
    src=ROOT/'art/blender/meshy'/manifest['source_directory']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(src/(src.name+'_Character_output.fbx')))
    target=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    target.name='MinaResolve'
    target_objects=set(bpy.data.objects)
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    target.animation_data_clear()
    for o in target_objects:
        if o.type=='MESH':
            o.name='MinaResolveSkin'
            o.data.calc_loop_triangles()
            triangle_count=len(o.data.loop_triangles)
            if triangle_count>40000:
                bpy.context.view_layer.objects.active=o
                mod=o.modifiers.new('ResidentBudget','DECIMATE');mod.ratio=40000/triangle_count
                bpy.ops.object.modifier_apply(modifier=mod.name)
    points=[o.matrix_world @ Vector(c) for o in target_objects if o.type=='MESH' for c in o.bound_box]
    height=max(p.z for p in points)-min(p.z for p in points)
    for img in bpy.data.images:
        if img.source=='FILE':
            path=src/Path(img.filepath.replace('\\','/')).name
            if path.exists(): img.filepath=str(path);img.reload()
            if max(img.size)>1024: img.scale(1024,1024)
    for mat in bpy.data.materials:
        if not mat.use_nodes: continue
        for node in mat.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':
                node.inputs['Metallic'].default_value=0
                spec=node.inputs.get('Specular IOR Level')
                if spec: spec.default_value=min(.5,spec.default_value)
    OUT.mkdir(parents=True,exist_ok=True)
    # A prior Grey Elegance albedo grade is not provenance for this image.
    marker=OUT/'texture_0.png.graded'
    if marker.exists(): marker.unlink()
    bpy.context.scene.render.fps=30
    bpy.ops.export_scene.gltf(filepath=str(OUT/'mina_vale.gltf'),export_format='GLTF_SEPARATE',export_animations=False,export_skins=True,export_yup=True)
    kept=[];report=[]
    for spec in manifest['animations']:
        path=src/spec['source']
        if hashlib.sha256(path.read_bytes()).hexdigest()!=spec['sha256']: raise ValueError(str(path))
        previous=set(bpy.data.objects); actions=set(bpy.data.actions)
        bpy.ops.import_scene.fbx(filepath=str(path))
        fresh=set(bpy.data.objects)-previous
        source=next(o for o in fresh if o.type=='ARMATURE')
        action=max(set(bpy.data.actions)-actions,key=lambda a:a.frame_range[1]-a.frame_range[0])
        source_fps=bpy.context.scene.render.fps
        bpy.context.scene.render.fps=30
        result,info=bake(target,source,action,spec,source_fps)
        kept.append(result); report.append(info)
        for o in fresh: bpy.data.objects.remove(o,do_unlink=True)
        for a in list(bpy.data.actions):
            if a not in kept: bpy.data.actions.remove(a)
        # Orphan copies are never packed into the editable source.
        for collection in [bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.images]:
            for item in list(collection):
                if item.users==0: collection.remove(item)
    target.animation_data.action=None
    for pb in target.pose.bones:
        pb.location=(0,0,0);pb.rotation_quaternion=(1,0,0,0);pb.scale=(1,1,1)
    bpy.context.scene.frame_set(0)
    for action in kept:
        track=target.animation_data.nla_tracks.new();track.name=action.name
        track.strips.new(action.name,0,action)
        track.mute=True
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    bpy.ops.object.select_all(action='DESELECT');target.select_set(True)
    bpy.context.view_layer.objects.active=target
    for track in target.animation_data.nla_tracks: track.mute=False
    bpy.ops.export_scene.gltf(filepath=str(OUT/'mina_vale_moves.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True,export_force_sampling=True,export_frame_range=False)
    path=ROOT/'art/data/mina_resolve/bake_report.json'
    for o in target_objects:
        if o.type=='MESH': o.data.calc_loop_triangles()
    path.write_text(json.dumps({'schema_version':1,'batch':1,'clips':report,'triangle_count':sum(len(o.data.loop_triangles) for o in target_objects if o.type=='MESH'),'height_metres':height,'navigation_owns_translation':True},indent=2)+'\n',encoding='utf-8',newline='\n')


if __name__=='__main__': main()
