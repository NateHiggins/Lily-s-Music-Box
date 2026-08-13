"""Bake the shared biped clip set onto ONE hero model's own rig.

Why this exists: the runtime graft (ResidentMovesLibrary.apply) copies
rotation tracks between rigs verbatim, which is only correct while every
rig carries the same bone axes. The 2026-08-02 dump generation does;
Meshy's newer exports do not — mina_vale/Grey_Elegance measured 9-34° of
rest-orientation delta per bone against Evelyn, so every borrowed clip
corseted (fixed separately: position tracks), then leaned, hunched and
knee-hiked her.

Why it is NOT a constraint bake: with an identity bone map, a
world-space Copy Rotation bake is mathematically the SAME as the local
copy — a bone's world orientation is the product of the chain's local
rotations, translations never enter it — so the first version of this
script reproduced the defect frame-perfectly. (The 22-joint bake in
retarget_resident_moves.py escapes this only because its bone map FOLDS
joints, which breaks the identity.)

The correct transfer is rest-relative: per bone,
    target_world_pose = (target_rest_world @ source_rest_world^-1)
                        @ source_world_pose
so when the source stands in her rest pose, the target stands in HER
OWN rest pose — which is the definition of proportions surviving a
borrowed clip. Locals are then derived analytically down the hierarchy
and keyed directly; nothing depends on constraint evaluation order.

Output: <slug>_moves.glb beside the model (the creature convention).
ResidentMovesLibrary.apply prefers it over the shared library.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P \
        art/blender/scripts/bake_model_moves.py -- mina_vale
"""
import os
import sys

import bpy
from mathutils import Quaternion

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SLUG = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "mina_vale"
TARGET = os.path.join(ROOT, "game", "assets", "characters", SLUG,
                      SLUG + ".gltf")
## Same two sources the runtime graft uses for the biped family.
SOURCES = [
    os.path.join(ROOT, "game", "assets", "characters", "evelyn_marsh",
                 "evelyn_marsh.gltf"),
    os.path.join(ROOT, "game", "assets", "characters", "shared",
                 "biped_gestures.glb"),
]
OUT = os.path.join(ROOT, "game", "assets", "characters", SLUG,
                   SLUG + "_moves.glb")


def import_scene(path):
    before = set(bpy.data.objects)
    if path.endswith(".gltf") or path.endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def action_curves(action):
    """bone name -> {"rot": [4 fcurves], "loc": [3 fcurves]}.

    Sampled directly, never through pose evaluation: Blender's evaluation
    of the gesture library's imported layered actions is not
    frame-accurate (a clip whose curves swing 100° read 0.4° of movement
    ten frames in), and every statue/lean defect this file has produced
    traced back to trusting an evaluated pose. The curves are the data;
    read the data."""
    out = {}
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    path = fc.data_path
                    if not path.startswith('pose.bones["'):
                        continue
                    bone = path.split('"')[1]
                    entry = out.setdefault(bone, {"rot": [None] * 4,
                                                  "loc": [None] * 3})
                    if path.endswith("rotation_quaternion"):
                        entry["rot"][fc.array_index] = fc
                    elif path.endswith("location"):
                        entry["loc"][fc.array_index] = fc
    return out


def sample_rot(entry, rest_q, frame):
    fcs = entry["rot"] if entry else None
    if not fcs or any(fc is None for fc in fcs):
        return rest_q.copy()
    return Quaternion((fcs[0].evaluate(frame), fcs[1].evaluate(frame),
                       fcs[2].evaluate(frame), fcs[3].evaluate(frame))) \
        .normalized()


def armature_of(objects):
    for o in objects:
        if o.type == "ARMATURE":
            return o
    return None


## ARMATURE space, deliberately not world: each file carries its own
## armature-object transform (the gesture library's is pitched relative to
## Evelyn's hero export), and composing through matrix_world leaked that
## difference into every gesture clip as a permanent forward lean while
## Evelyn's own clips baked clean. Inside the armature the bone conventions
## are the family's, which is the frame the transfer math wants.
def world_rest_q(arm, name):
    return arm.data.bones[name].matrix_local.to_quaternion()


def world_pose_q(arm, name):
    return arm.pose.bones[name].matrix.to_quaternion()


def bake_sources(target):
    """-> list of baked target actions."""
    scene = bpy.context.scene
    baked = []
    # Hierarchy order, so a parent's world pose is always computed before
    # its children need it.
    ordered = []
    def walk(bone):
        ordered.append(bone.name)
        for child in bone.children:
            walk(child)
    for bone in target.data.bones:
        if bone.parent is None:
            walk(bone)

    # Target rest quantities, armature space (matrix_world is identity on
    # these imports, but compose it anyway rather than assume).
    t_rest_w = {n: world_rest_q(target, n) for n in ordered}
    t_rest_local = {}
    t_rest_loc = {}
    for n in ordered:
        bone = target.data.bones[n]
        if bone.parent:
            m = bone.parent.matrix_local.inverted() @ bone.matrix_local
        else:
            m = bone.matrix_local
        t_rest_local[n] = m.to_quaternion()
        t_rest_loc[n] = bone.matrix_local.translation.copy()

    # The convention reference. The clips are ABSOLUTE poses for the
    # 2026-08-02 rig convention, not motion relative to their file's
    # rest — biped_gestures.glb's armature rests near a mid-walk pose,
    # so "world motion vs that file's rest" measures almost nothing
    # (casual_walk read 2° on the arms). The bridge between conventions
    # must be measured at a pose BOTH rigs are known to share: the
    # A-pose bind of the hero models. Evelyn's hero rig carries the old
    # convention's A-pose; the target carries the new one's.
    ref_rest = {}

    for source_path in SOURCES:
        actions_before = set(bpy.data.actions)
        source_objects = import_scene(source_path)
        source = armature_of(source_objects)
        if source is None:
            print("SKIP source with no armature:", source_path)
            continue
        source_actions = [a for a in bpy.data.actions
                          if a not in actions_before]
        common = [n for n in ordered if n in source.pose.bones]
        if not ref_rest:
            # SOURCES[0] is Evelyn's hero gltf: A-pose, old convention.
            ref_rest = {n: world_rest_q(source, n) for n in common}

        # Right-hand delta at the shared A-pose:
        #   target_world = clip_world @ (evelyn_A_rest^-1 @ target_A_rest)
        # i.e. the same world pose, re-expressed in the new generation's
        # bone axes. A left-hand delta transfers source-LOCAL motion and
        # any roll difference converts swing into twist (measured: a walk
        # whose thigh moved 40° by quaternion while the leg barely
        # scissored); a right-hand delta against the CLIP FILE's own rest
        # measures no motion at all when that rest is not the A-pose.
        #
        # Per-bone right-delta in ARMATURE space:
        #     W_target(b) = W_clip(b) @ (R_evelyn(b)^-1 @ R_target(b))
        # This is the vertex map made explicit: whatever transform the
        # family skin receives (W @ R_f^-1), the target bone reproduces
        # from its own bind, so at the shared A-pose the target renders
        # exactly its own bind — upright — and every clip pose lands as
        # the same world posture through the target's skin. The
        # root-relative variant (hips delta forced to identity) was
        # tried and bent every near-A-pose clip forward by the ~17°
        # hips-frame difference between the two generations' binds:
        # that difference is convention, and conventions must be mapped,
        # not skipped. Both rests are armature-space, so neither file's
        # armature-object transform can contaminate the map (the earlier
        # world-space form leaked exactly that).
        delta = {n: ref_rest[n].inverted() @ t_rest_w[n]
                 for n in common if n in ref_rest}
        common = [n for n in common if n in delta]
        src_hip_rest = source.data.bones["Hips"].matrix_local \
            .translation.copy()
        dst_hip_rest = t_rest_loc["Hips"]
        hip_scale = (dst_hip_rest.z / src_hip_rest.z) if src_hip_rest.z \
            else 1.0
        print("%s: %d actions, %d/%d bones mapped, hip scale %.3f"
              % (os.path.basename(source_path), len(source_actions),
                 len(common), len(ordered), hip_scale))

        # Source rest quantities for recomposing curve data: the imported
        # basis curves are rest-relative, so rest_parentrel @ basis
        # recovers the file's true node locals exactly, no matter how
        # strange the fold-state rest of the rig itself is.
        s_parent = {}
        s_pr = {}
        s_rest_R = {}
        for n in common:
            bone = source.data.bones[n]
            s_parent[n] = bone.parent.name if bone.parent else None
            if bone.parent:
                m = bone.parent.matrix_local.inverted() @ bone.matrix_local
            else:
                m = bone.matrix_local
            s_pr[n] = m.to_quaternion()
            s_rest_R[n] = bone.matrix_local.to_quaternion()

        for action in source_actions:
            curves = action_curves(action)
            new_action = bpy.data.actions.new("baked_" + action.name)
            new_action.use_fake_user = True
            target.animation_data_create()
            target.animation_data.action = new_action
            if new_action.slots and hasattr(target.animation_data,
                                            "action_slot"):
                target.animation_data.action_slot = new_action.slots[0]

            f0, f1 = int(action.frame_range[0]), \
                max(1, int(action.frame_range[1]))
            # q and -q are the same rotation AT a key, and opposite ends
            # of the long way round BETWEEN keys: without sign continuity
            # every interpolated frame collapses toward rest.
            last_q = {}
            for frame in range(f0, f1 + 1):
                world_q = {}
                for n in common:
                    basis = sample_rot(curves.get(n), Quaternion(), frame)
                    local = s_pr[n] @ basis
                    p = s_parent[n]
                    world_q[n] = (world_q[p] @ local) if p in world_q \
                        else local
                for n in common:
                    world_q[n] = world_q[n] @ delta[n]
                for n in common:
                    pb = target.pose.bones[n]
                    parent = pb.parent.name if pb.parent else None
                    if parent is None:
                        local_q = world_q[n]
                    elif parent in world_q:
                        local_q = world_q[parent].inverted() @ world_q[n]
                    else:
                        local_q = t_rest_local[n]
                    pb.rotation_mode = "QUATERNION"
                    basis_q = t_rest_local[n].inverted() @ local_q
                    if n in last_q and last_q[n].dot(basis_q) < 0.0:
                        basis_q.negate()
                    last_q[n] = basis_q.copy()
                    pb.rotation_quaternion = basis_q
                    # Re-based to start at 0: a first key at source frame
                    # 1 exports as t=0.04s and Godot pads t=0 with rest.
                    pb.keyframe_insert("rotation_quaternion",
                                       frame=frame - f0)
                # Hips carry the one position that IS motion; scaled to
                # this body's own hip height, expressed in the bone's
                # rest frame as pose channels are.
                loc_fcs = (curves.get("Hips") or {}).get("loc")
                if loc_fcs and all(fc is not None for fc in loc_fcs):
                    from mathutils import Vector
                    basis_loc = Vector((loc_fcs[0].evaluate(frame),
                                        loc_fcs[1].evaluate(frame),
                                        loc_fcs[2].evaluate(frame)))
                else:
                    from mathutils import Vector
                    basis_loc = Vector((0.0, 0.0, 0.0))
                travel = (s_rest_R["Hips"] @ basis_loc) * hip_scale
                pb = target.pose.bones["Hips"]
                pb.location = t_rest_local["Hips"].inverted() @ travel
                pb.keyframe_insert("location", frame=frame - f0)
            baked.append(new_action)
            print("  baked", new_action.name, "frames", f1 - f0 + 1)

        for o in source_objects:
            try:
                bpy.data.objects.remove(o, do_unlink=True)
            except ReferenceError:
                pass
        for action in list(bpy.data.actions):
            if action not in baked:
                bpy.data.actions.remove(action)
    return baked


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    target_objects = import_scene(TARGET)
    target = armature_of(target_objects)
    if target is None:
        print("BAKE FAILED: no armature in", TARGET)
        sys.exit(1)
    for o in target_objects:
        if o is not target and o.parent in (None, target):
            bpy.data.objects.remove(o, do_unlink=True)
    target.name = SLUG + "_moves"

    baked = bake_sources(target)
    if not baked:
        print("BAKE FAILED: nothing baked")
        sys.exit(1)

    # Rename AFTER deleting originals, or the collision dodge adds .001
    # suffixes and the ROLES lookups never match.
    for action in baked:
        action.name = action.name.replace("baked_", "")
    target.animation_data_create()
    target.animation_data.action = None
    for action in bpy.data.actions:
        track = target.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)

    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_skins=True, export_yup=True)
    print("wrote", OUT, "with", len(bpy.data.actions), "actions")


if __name__ == "__main__":
    main()
