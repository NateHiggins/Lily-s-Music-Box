"""Retarget the cast's animation clips onto the rebuilt cast's one skeleton.

blender -b --python retarget_cast_moves.py -- <person .blend> <out .glb> <source glb> [time scale] [<source glb> [time scale] ...]

The old bodies' skeletons differ in rest pose and bone frames, so nothing is
copied bone to bone. For every frame, each mapped bone of the new skeleton is
turned so that it points where the old bone points in the world: the old
bone's world turn from its rest, applied to the new bone's rest after lining
the two rest directions up. Hips travel is scaled by hip height. The result
depends only on where the old bones point, not on how they were rigged.

A time scale stretches a source's clips (the personal libraries were baked a
quarter fast; 1.25 puts them right).
"""
import bpy, sys, os, math
from mathutils import Matrix, Vector, Quaternion

ARGS = sys.argv[sys.argv.index("--") + 1:]
PERSON, OUT = ARGS[0], ARGS[1]
SOURCES = []
rest = ARGS[2:]
while rest:
    path = rest.pop(0)
    scale = 1.0
    if rest and not rest[0].lower().endswith((".glb", ".gltf")):
        scale = float(rest.pop(0))
    SOURCES.append((path, scale))

# new bone -> names an old skeleton may use for it
MAP = {
    "Hips": ["Hips", "spine"], "Spine": ["Spine02", "spine.001"], "Spine1": ["Spine01", "spine.002"], "Spine2": ["Spine", "spine.003"],
    "Neck": ["neck", "Neck", "spine.004"], "Head": ["Head", "spine.005"],
    "LeftShoulder": ["LeftShoulder", "shoulder.L"], "LeftArm": ["LeftArm", "upper_arm.L"], "LeftForeArm": ["LeftForeArm", "forearm.L"], "LeftHand": ["LeftHand", "hand.L"],
    "RightShoulder": ["RightShoulder", "shoulder.R"], "RightArm": ["RightArm", "upper_arm.R"], "RightForeArm": ["RightForeArm", "forearm.R"], "RightHand": ["RightHand", "hand.R"],
    "LeftUpLeg": ["LeftUpLeg", "thigh.L"], "LeftLeg": ["LeftLeg", "shin.L"], "LeftFoot": ["LeftFoot", "foot.L"], "LeftToeBase": ["LeftToeBase", "toe.L"],
    "RightUpLeg": ["RightUpLeg", "thigh.R"], "RightLeg": ["RightLeg", "shin.R"], "RightFoot": ["RightFoot", "foot.R"], "RightToeBase": ["RightToeBase", "toe.R"],
}

bpy.ops.wm.open_mainfile(filepath=PERSON)
target = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for obj in list(bpy.data.objects):
    if obj is not target:
        bpy.data.objects.remove(obj)
target.animation_data_clear()
scene = bpy.context.scene
scene.render.fps = 30
target_world = target.matrix_world.copy()
order = []


def walk(bone):
    if bone.name in MAP:
        order.append(bone.name)
    for child in bone.children:
        walk(child)


for bone in target.data.bones:
    if bone.parent is None:
        walk(bone)
target_rest = {name: (target_world @ target.data.bones[name].matrix_local).to_quaternion() for name in order}
target_dir = {name: (target_world.to_3x3() @ (target.data.bones[name].tail_local - target.data.bones[name].head_local)).normalized() for name in order}
target_hips = (target_world @ target.data.bones["Hips"].head_local)
made = []

for path, time_scale in SOURCES:
    before = set(bpy.data.objects)
    actions_before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    fresh = [o for o in bpy.data.objects if o not in before]
    source = [o for o in fresh if o.type == "ARMATURE"][0]
    actions = [a for a in bpy.data.actions if a not in actions_before]
    source_world = source.matrix_world.copy()
    names = {}
    for new_name, olds in MAP.items():
        for old in olds:
            if old in source.data.bones:
                names[new_name] = old
                break
    source_rest = {n: (source_world @ source.data.bones[o].matrix_local).to_quaternion() for n, o in names.items()}
    source_dir = {n: (source_world.to_3x3() @ (source.data.bones[o].tail_local - source.data.bones[o].head_local)).normalized() for n, o in names.items()}
    # Line the two rest directions up, bone by bone.
    align = {n: source_dir[n].rotation_difference(target_dir[n]).inverted() for n in names}
    # The hips are the body's own frame, not a limb: both bodies stand upright
    # facing the same way, so their turn carries across as it is. (Lining up
    # two hip bones that point opposite ways turned a forward lean into a
    # backward one.)
    align["Hips"] = Quaternion()
    source_hips = source_world @ source.data.bones[names["Hips"]].head_local
    travel = target_hips.z / max(source_hips.z, 1e-6)
    print("SOURCE", os.path.basename(path), "bones", len(names), "of", len(MAP), "actions", len(actions), "travel", round(travel, 3), "time", time_scale)
    for action in actions:
        if source.animation_data is None:
            source.animation_data_create()
        source.animation_data.action = action
        try:
            source.animation_data.action_slot = action.slots[0]
        except Exception:
            pass
        first, last = [int(round(v)) for v in action.frame_range]
        new_action = bpy.data.actions.new(action.name.split("|")[-1].replace("_" + os.path.basename(path).split("_moves")[0], ""))
        if target.animation_data is None:
            target.animation_data_create()
        target.animation_data.action = new_action
        for pose_bone in target.pose.bones:
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.matrix_basis = Matrix.Identity(4)
        previous = {}
        for frame in range(first, last + 1):
            scene.frame_set(frame)
            out_frame = 1 + (frame - first) * time_scale
            world_turn = {}
            for name in order:
                if name not in names:
                    continue
                pose = source.pose.bones[names[name]]
                now = (source_world @ pose.matrix).to_quaternion()
                # The old bone's world turn from rest, on the new bone's rest, rests lined up.
                world_turn[name] = now @ source_rest[name].inverted() @ align[name] @ target_rest[name]
            for name in order:
                if name not in world_turn:
                    continue
                pose_bone = target.pose.bones[name]
                parent = pose_bone.parent
                rest_local = target.data.bones[name].matrix_local
                if parent is not None:
                    parent_now = (target_world @ parent.matrix).to_quaternion()
                    parent_rest = (target_world @ target.data.bones[parent.name].matrix_local).to_quaternion()
                    rest_in_parent = parent_rest.inverted() @ target_rest[name]
                    local = (parent_now.inverted() @ world_turn[name])
                    basis = rest_in_parent.inverted() @ local
                else:
                    basis = target_rest[name].inverted() @ world_turn[name]
                if name in previous and previous[name].dot(basis) < 0:
                    basis = -basis
                previous[name] = basis.copy()
                pose_bone.rotation_quaternion = basis
                pose_bone.keyframe_insert("rotation_quaternion", frame=out_frame)
                if name == "Hips":
                    hips_now = source_world @ source.pose.bones[names[name]].head
                    moved = Vector(((hips_now.x - source_hips.x) * travel, (hips_now.y - source_hips.y) * travel, (hips_now.z - source_hips.z) * travel))
                    pose_bone.location = (target_world.to_3x3() @ target.data.bones[name].matrix_local.to_3x3()).inverted() @ moved
                    pose_bone.keyframe_insert("location", frame=out_frame)
                bpy.context.view_layer.update()
        made.append(new_action)
        print("CLIP", new_action.name, last - first + 1, "frames")
    for obj in fresh:
        bpy.data.objects.remove(obj)

# One library: every clip on its own track.
target.animation_data.action = None
for action in made:
    track = target.animation_data.nla_tracks.new()
    action.name = action.name.split(".")[0] if action.name.split(".")[0] not in bpy.data.actions else action.name
    track.name = action.name.split(".")[0]
    track.strips.new(action.name, 1, action)
for pose_bone in target.pose.bones:
    pose_bone.matrix_basis = Matrix.Identity(4)
bpy.ops.object.select_all(action="DESELECT")
target.select_set(True)
bpy.context.view_layer.objects.active = target
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS", export_yup=True,
                          export_force_sampling=True, export_optimize_animation_size=True)
print("EXPORTED", len(made), "clips", os.path.getsize(OUT))
print("DONE")
