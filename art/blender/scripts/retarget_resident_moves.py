"""Retarget Evelyn's Meshy animation set onto the shared resident skeleton.

All eighteen generated residents (`<slug>_rigged.glb`) share one 22-joint
armature, so ONE bake makes the whole Meshy library — walk, run, and the
eight identified role clips — playable by the entire cast. The result is a
committed artifact (`game/assets/characters/shared/resident_moves.glb`)
because this repo gitignores `.import` files: Godot-side BoneMap retargets
would silently die on every fresh clone.

Method: world-space Copy Rotation constraints from each mapped Meshy bone
onto the generated deform bone (plus hip location, scaled by rest-height
ratio), baked per action with visual keying. Crude next to a real
retargeting rig, but both skeletons are simple upright stylized humanoids
— judge the result from ClipSheet contact sheets, not from theory.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P \
        art/blender/scripts/retarget_resident_moves.py
"""
import os

import bpy

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOURCE = os.path.join(ROOT, "game", "assets", "characters", "evelyn_marsh",
                      "evelyn_marsh.gltf")
TARGET = os.path.join(ROOT, "game", "assets", "characters", "teresa_vale",
                      "teresa_vale_rigged.glb")
OUT = os.path.join(ROOT, "game", "assets", "characters", "shared",
                   "resident_moves.glb")

## Meshy bone -> shared resident deform bone. Shoulders, the middle spine
## link, and toes have no counterpart and fold into their neighbours.
BONE_MAP = {
    "Hips": "hips",
    "Spine02": "spine",
    "Spine": "chest",
    "neck": "neck",
    "Head": "head",
    "LeftArm": "upper_arm.L", "LeftForeArm": "forearm.L",
    "LeftHand": "hand.L",
    "RightArm": "upper_arm.R", "RightForeArm": "forearm.R",
    "RightHand": "hand.R",
    "LeftUpLeg": "thigh.L", "LeftLeg": "shin.L", "LeftFoot": "foot.L",
    "RightUpLeg": "thigh.R", "RightLeg": "shin.R", "RightFoot": "foot.R",
}


## Blender 5.x stores fcurves inside layered-action channelbags; the old
## flat Action.fcurves is gone.
def action_fcurves(action):
    if getattr(action, "fcurves", None):
        return list(action.fcurves)
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    return curves


def import_scene(path):
    before = set(bpy.data.objects)
    if path.endswith(".gltf") or path.endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def armature_of(objects):
    for o in objects:
        if o.type == "ARMATURE":
            return o
    return None


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    target_objects = import_scene(TARGET)
    target = armature_of(target_objects)
    # The mesh objects only weigh the export down; the skeleton carries
    # the animation. Keep the armature, drop teresa's body.
    for o in target_objects:
        if o is not target and o.parent in (None, target):
            bpy.data.objects.remove(o, do_unlink=True)
    target.name = "resident_moves"

    # Teresa's own Idle/Walk import with her rig; baking them through the
    # constraint setup would freeze the source in rest pose and write junk.
    # Only actions that arrive WITH the Meshy import get retargeted.
    actions_before = set(bpy.data.actions)
    source_objects = import_scene(SOURCE)
    source = armature_of(source_objects)
    source_actions = [a for a in bpy.data.actions if a not in actions_before]

    # Rest hip heights, for scaling the copied root motion.
    src_hip = (source.matrix_world @
               source.pose.bones["Hips"].bone.head_local).z
    dst_hip = (target.matrix_world @
               target.pose.bones["hips"].bone.head_local).z
    hip_scale = dst_hip / src_hip if src_hip else 1.0
    print("hip heights: src %.3f dst %.3f scale %.3f"
          % (src_hip, dst_hip, hip_scale))

    # Constraints: rotation for every mapped bone, location for the hips.
    for src_name, dst_name in BONE_MAP.items():
        pb = target.pose.bones.get(dst_name)
        if pb is None or src_name not in source.pose.bones:
            print("SKIP unmapped:", src_name, "->", dst_name)
            continue
        rot = pb.constraints.new("COPY_ROTATION")
        rot.target = source
        rot.subtarget = src_name
        rot.target_space = "WORLD"
        rot.owner_space = "WORLD"
    loc = target.pose.bones["hips"].constraints.new("COPY_LOCATION")
    loc.target = source
    loc.subtarget = "Hips"
    loc.target_space = "WORLD"
    loc.owner_space = "WORLD"

    baked = []
    for action in source_actions:
        source.animation_data_create()
        source.animation_data.action = action
        if action.slots and hasattr(source.animation_data, "action_slot"):
            source.animation_data.action_slot = action.slots[0]
        frame_end = max(1, int(action.frame_range[1]))
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.nla.bake(frame_start=int(action.frame_range[0]),
                         frame_end=frame_end, only_selected=False,
                         visual_keying=True, clear_constraints=False,
                         use_current_action=False, bake_types={"POSE"})
        bpy.ops.object.mode_set(mode="OBJECT")
        new_action = target.animation_data.action
        new_action.name = "baked_" + action.name
        # Root motion scale: the source stands taller, so her hip travel
        # must shrink to the resident rig's proportions.
        for fc in action_fcurves(new_action):
            if fc.data_path == 'pose.bones["hips"].location':
                for kp in fc.keyframe_points:
                    kp.co.y *= hip_scale
                    kp.handle_left.y *= hip_scale
                    kp.handle_right.y *= hip_scale
        new_action.use_fake_user = True
        baked.append(new_action)
        print("baked", new_action.name, "frames", int(action.frame_range[1]))

    # Strip constraints and the source rig; rename actions to clip ids.
    for pb in target.pose.bones:
        for constraint in list(pb.constraints):
            pb.constraints.remove(constraint)
    for o in source_objects:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except ReferenceError:
            pass
    # Delete the originals BEFORE renaming, or Blender dodges the name
    # collision with a .001 suffix and the ROLES lookups never match.
    for action in list(bpy.data.actions):
        if action not in baked:
            bpy.data.actions.remove(action)
    for action in baked:
        action.name = action.name.replace("baked_", "")

    # Stash every action on the NLA so the exporter writes them all.
    target.animation_data_create()
    target.animation_data.action = None
    for action in bpy.data.actions:
        track = target.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True, export_yup=True)
    print("wrote", OUT, "with", len(bpy.data.actions), "actions")


if __name__ == "__main__":
    main()
