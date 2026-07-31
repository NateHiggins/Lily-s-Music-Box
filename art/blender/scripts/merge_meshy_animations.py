"""Fold a Meshy character and its animation exports into one rigged glTF.

Meshy exports every animation as a complete character: the same 266k-triangle
skin, the same four 2K maps, the same 24-bone rig, with one clip attached.
Eleven files, 82 MB each, ~900 MB of which about 890 MB is the same mesh over
and over. This takes the skin once from the character export and lifts only
the ACTIONS off the rest.

Two things it has to fix on the way through:

- Every custom clip arrives named `rigify_clip`. All of them. Names have to
  be assigned from the file they came from or they collapse into each other.
- Every file also carries a one-frame `...|clip0|baselayer` action, which is
  the bind pose wearing an animation's clothes. Exported, it becomes a clip
  that snaps the character to rest, and something will eventually play it.
"""
import bpy
import os
import sys
import glob

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, RATIO = argv[0], argv[1], float(argv[2])

# Provisional names, in sorted-filename order, overridden by NAMES below once
# the clips have been identified on screen.
NAMES = {
    "Animation_Walking_withSkin": "walk",
    "Animation_Running_withSkin": "run",
}


def only_rig():
    return [o for o in bpy.data.objects if o.type == "ARMATURE"][0]


bpy.ops.wm.read_factory_settings(use_empty=True)

# --- the skin, once
character = os.path.join(SRC, os.path.basename(SRC) + "_Character_output.glb")
bpy.ops.import_scene.gltf(filepath=character)
rig = only_rig()
rig.name = "Armature"
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
before = sum(len(m.data.polygons) for m in meshes)
if RATIO < 1.0:
    for m in meshes:
        bpy.context.view_layer.objects.active = m
        mod = m.modifiers.new(name="decimate", type="DECIMATE")
        mod.ratio = RATIO
        # Collapse keeps vertex groups, which on a skinned mesh is the whole
        # ballgame — lose them and the character detaches from its rig.
        bpy.ops.object.modifier_apply(modifier=mod.name)
after = sum(len(m.data.polygons) for m in meshes)
print("TRIS %d -> %d across %d meshes" % (before, after, len(meshes)))

# The character export's own bind-pose action is not a clip.
for act in list(bpy.data.actions):
    act.use_fake_user = False
    bpy.data.actions.remove(act)

# --- the clips, without their skins
kept = []
for path in sorted(glob.glob(os.path.join(SRC, "*.glb"))):
    stem = os.path.basename(path).replace(".glb", "")
    if stem.endswith("_Character_output"):
        continue
    label = stem.replace(os.path.basename(SRC) + "_", "")
    existing = set(bpy.data.actions.keys())
    keep_objects = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=path)
    fresh = [a for a in bpy.data.actions if a.name not in existing]
    # Drop the imported duplicate character immediately; only actions stay.
    for ob in [o for o in bpy.data.objects if o.name not in keep_objects]:
        bpy.data.objects.remove(ob, do_unlink=True)
    real = None
    for act in fresh:
        # The bind-pose passenger: one or two frames, and it would export as
        # a clip that yanks the character back to rest.
        if act.frame_range[1] - act.frame_range[0] <= 2:
            bpy.data.actions.remove(act)
            continue
        real = act
    if real is None:
        print("SKIP %s (no clip longer than 2 frames)" % label)
        continue
    real.name = NAMES.get(label, "clip_%02d" % (len(kept) + 1))
    real.use_fake_user = True
    kept.append((real.name, label,
                 int(real.frame_range[1] - real.frame_range[0])))

print("CLIPS:")
for name, label, length in kept:
    print("   %-12s %-58s %d frames (%.2f s)"
          % (name, label, length, length / 30.0))

# The armature needs animation_data for ACTIONS-mode export to consider it,
# but it must NOT have an action assigned: whichever action is active gets
# treated as already-handled and is silently dropped from the export. Ten
# clips in, nine clips out, and the missing one is always the first.
if rig.animation_data is None:
    rig.animation_data_create()
rig.animation_data.action = None

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLTF_SEPARATE",
    export_yup=True,
    export_apply=False,          # never apply modifiers on a skinned mesh
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_bake_animation=True,
    export_optimize_animation_size=False,
    export_image_format="JPEG",
    export_jpeg_quality=88,
    export_skins=True,
)
size = sum(os.path.getsize(os.path.join(os.path.dirname(OUT), f))
           for f in os.listdir(os.path.dirname(OUT)))
print("EXPORTED %s (%d clips, %.1f MB total)"
      % (OUT, len(kept), size / 1048576.0))
