"""Fold the merged Meshy animation packs into one shared gesture library.

The packs ship as `*_Meshy_Merged_Animations.fbx` — many clips, one rig,
the same 24-joint Meshy biped skeleton the hero cast and creatures ride.
Everything is stripped to an animations-only GLB with cleaned names
(`Armature|Agree_Gesture_without_skin.fbx` -> `agree_gesture`), deduped
across packs, and shipped as shared/biped_gestures.glb for
ResidentMovesLibrary to graft.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P \
        art/blender/scripts/build_gesture_library.py
"""
import glob
import os
import re

import bpy

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PACKS = [
    os.path.join(ROOT, "art", "blender", "meshy", "athletic_pack_a"),
    os.path.join(ROOT, "art", "blender", "meshy", "athletic_pack_b"),
]
OUT = os.path.join(ROOT, "game", "assets", "characters", "shared",
                   "biped_gestures.glb")


def clean_name(raw: str) -> str:
    name = raw.split("|")[-1]
    name = re.sub(r"_without_skin\.fbx$", "", name)
    name = re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_").lower()
    return name


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    keeper = None
    seen = set()
    for pack in PACKS:
        fbx = glob.glob(os.path.join(pack, "**", "*Merged_Animations.fbx"),
                        recursive=True)
        if not fbx:
            print("no merged fbx in", pack)
            continue
        before_objects = set(bpy.data.objects)
        before_actions = set(bpy.data.actions)
        bpy.ops.import_scene.fbx(filepath=fbx[0])
        new_objects = [o for o in bpy.data.objects if o not in before_objects]
        armature = next(o for o in new_objects if o.type == "ARMATURE")
        if keeper is None:
            keeper = armature
            keeper.name = "biped_gestures"
        # Rename this pack's actions; drop duplicates across packs.
        for action in [a for a in bpy.data.actions
                       if a not in before_actions]:
            name = clean_name(action.name)
            if name in seen:
                bpy.data.actions.remove(action)
                continue
            action.name = name
            action.use_fake_user = True
            seen.add(name)
        # The keeper armature carries everything; later packs' objects go.
        if armature is not keeper:
            for o in new_objects:
                bpy.data.objects.remove(o, do_unlink=True)
        else:
            for o in new_objects:
                if o.type == "MESH":
                    bpy.data.objects.remove(o, do_unlink=True)
    keeper.animation_data_create()
    keeper.animation_data.action = None
    for action in bpy.data.actions:
        track = keeper.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUT, export_format="GLB", export_animations=True,
        export_animation_mode="ACTIONS", export_skins=True, export_yup=True)
    print("wrote %s with %d clips: %s"
          % (OUT, len(bpy.data.actions), sorted(seen)))


if __name__ == "__main__":
    main()
