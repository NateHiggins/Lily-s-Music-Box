"""Convert the Meshy character dump into game-ready hero models.

Driven by game/data/resident_hero_models.json (the committed mapping).
For every mapped resident and creature:

- import the base `_Character_output.fbx` (rig + skin, no animations —
  Meshy ships each clip as its own fbx, so the base is already clean);
- strip any actions that somehow arrived (the "strip all animations"
  contract: motion comes from shared libraries, never from the model);
- decimate to the background budget (~40k tris, character_budget.md);
- downscale textures to 1K;
- export residents to game/assets/characters/<slug>/<slug>.gltf (the hero
  slot ResidentRoutines._upgrade already prefers) and creatures to
  game/assets/creatures/<name>/<name>.gltf.

Each creature's Walking fbx is additionally baked out unchanged as
<name>_moves.glb next to its model — its indexed animation library.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P \
        art/blender/scripts/convert_dump_characters.py
"""
import glob
import json
import os

import bpy

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
MESHY = os.path.join(ROOT, "art", "blender", "meshy")
MAPPING = os.path.join(ROOT, "game", "data", "resident_hero_models.json")
TRI_BUDGET = 40000
TEX_SIZE = 1024


def clean_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_base(source: str) -> bool:
    base = glob.glob(os.path.join(MESHY, source, "*_Character_output.fbx"))
    if not base:
        print("MISSING base fbx:", source)
        return False
    bpy.ops.import_scene.fbx(filepath=base[0])
    return True


def strip_animations() -> None:
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for o in bpy.data.objects:
        if o.animation_data:
            o.animation_data_clear()


def decimate_to_budget() -> None:
    total = sum(len(o.data.polygons) for o in bpy.data.objects
                if o.type == "MESH")
    if total <= TRI_BUDGET:
        print("  tris", total, "within budget")
        return
    ratio = TRI_BUDGET / float(total)
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new(name="decimate", type="DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
    after = sum(len(o.data.polygons) for o in bpy.data.objects
                if o.type == "MESH")
    print("  tris %d -> %d (ratio %.3f)" % (total, after, ratio))


def shrink_textures() -> None:
    for img in bpy.data.images:
        if img.size[0] > TEX_SIZE:
            img.scale(TEX_SIZE, TEX_SIZE)


def export_gltf(out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLTF_SEPARATE",
        export_animations=False, export_skins=True, export_yup=True)


def convert(source: str, out_dir: str, name: str) -> None:
    out_path = os.path.join(out_dir, name + ".gltf")
    if os.path.exists(out_path):
        print("skip (exists)", name)
        return
    clean_scene()
    if not import_base(source):
        return
    strip_animations()
    decimate_to_budget()
    shrink_textures()
    export_gltf(out_path)
    print("converted", name)


def export_creature_moves(source: str, out_dir: str, name: str) -> None:
    """The creature's own clips, kept on its own skeleton, as a library."""
    out_path = os.path.join(out_dir, name + "_moves.glb")
    if os.path.exists(out_path):
        return
    clips = glob.glob(os.path.join(MESHY, source, "*_Animation_*_withSkin.fbx"))
    if not clips:
        print("  no animation fbx for", name)
        return
    clean_scene()
    for clip in clips:
        bpy.ops.import_scene.fbx(filepath=clip)
    # Drop the duplicate skins: keep one armature, all actions.
    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    for extra in armatures[1:]:
        bpy.data.objects.remove(extra, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    keeper = armatures[0]
    keeper.animation_data_create()
    keeper.animation_data.action = None
    for action in bpy.data.actions:
        # Meshy fbx actions arrive as "Armature|Armature|...|walking_man|
        # baselayer"; the index wants a name a director can ask for.
        lowered = action.name.lower()
        if "walk" in lowered:
            action.name = "walk"
        elif "run" in lowered:
            action.name = "run"
        elif "idle" in lowered:
            action.name = "idle"
        action.use_fake_user = True
        track = keeper.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLB",
        export_animations=True, export_animation_mode="ACTIONS",
        export_skins=True, export_yup=True)
    print("  moves library:", os.path.basename(out_path),
          len(bpy.data.actions), "clips")


if __name__ == "__main__":
    with open(MAPPING, encoding="utf-8") as fh:
        mapping = json.load(fh)
    for slug, spec in mapping["residents"].items():
        convert(spec["source"],
                os.path.join(ROOT, "game", "assets", "characters", slug), slug)
    for name, spec in mapping["creatures"].items():
        out_dir = os.path.join(ROOT, "game", "assets", "creatures", name)
        convert(spec["source"], out_dir, name)
        export_creature_moves(spec["source"], out_dir, name)
    print("dump conversion complete")
