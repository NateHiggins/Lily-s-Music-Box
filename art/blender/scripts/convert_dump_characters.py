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
PROFILES = os.path.join(ROOT, "game", "data",
                        "resident_animation_profiles.json")
TRI_BUDGET = 40000
TEX_SIZE = 1024


def body_factors(slug: str):
    """Canon heights are BAKED into the model, UNIFORMLY (ruling
    2026-08-02, refined): the dump models already carry their authored
    proportions, so only relative height scales — one uniform factor,
    which armatures apply cleanly. Width factors are the generated-cast
    legacy and are ignored here."""
    with open(PROFILES, encoding="utf-8") as fh:
        for profile in json.load(fh):
            if profile.get("slug") == slug:
                return float(profile.get("body", {}).get("height", 1.0))
    return 1.0


def bake_body_scale(slug: str) -> None:
    """Multiply the canon factors onto the ROOT objects' scale and leave
    it unapplied: the glTF exporter converts axes (Blender Z-up: height
    is Z), and in Godot the skeleton and skin live under the scaled node,
    so shared-library clips play correctly with no track rescaling.
    Applying the scale into FBX child data was tried and fought parent
    inheritance and per-object axis conventions; this way the exporter
    owns the geometry problem it already solves."""
    h = body_factors(slug)
    if abs(h - 1.0) < 0.001:
        return
    # FBX imports carry a 0.01 armature scale with centimeter bone data.
    # Normalize that FIRST (bones and mesh to meters, scales to one), so
    # the uniform multiply and second apply operate in a clean domain —
    # multiplying the un-normalized 0.01 broke the exporter's own unit
    # normalization and shipped centimeter skeletons.
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = next(
        (o for o in bpy.data.objects if o.type == "ARMATURE"),
        bpy.data.objects[0] if bpy.data.objects else None)
    bpy.ops.object.transform_apply(location=False, rotation=False,
                                   scale=True)
    for o in bpy.data.objects:
        if o.parent is None:
            o.scale = (h, h, h)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False, rotation=False,
                                   scale=True)
    print("  baked body scale h=%.2f (uniform)" % h)


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


def strip_emission() -> None:
    """Meshy wires the albedo into every material's emission at full
    strength, so figures self-illuminate and scene lighting never lands
    (NPCs read fully lit in a dark corridor). Unhook emission and rein
    in the doubled specular before export; strip_character_emissive.py
    applies the same law to files already shipped."""
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        for node in mat.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            for name in ("Emission Color", "Emission Strength"):
                sock = node.inputs.get(name)
                if sock is None:
                    continue
                for link in list(sock.links):
                    mat.node_tree.links.remove(link)
            node.inputs["Emission Strength"].default_value = 0.0
            spec = node.inputs.get("Specular Tint")
            ior_level = node.inputs.get("Specular IOR Level")
            if ior_level is not None and ior_level.default_value > 0.5:
                ior_level.default_value = 0.5
            if spec is not None and not spec.links:
                spec.default_value = (1.0, 1.0, 1.0, 1.0)


def export_gltf(out_path: str) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path, export_format="GLTF_SEPARATE",
        export_animations=False, export_skins=True, export_yup=True)


def convert(source: str, out_dir: str, name: str,
            bake_body: bool = False) -> None:
    out_path = os.path.join(out_dir, name + ".gltf")
    if os.path.exists(out_path):
        print("skip (exists)", name)
        return
    clean_scene()
    if not import_base(source):
        return
    strip_animations()
    # Canon heights are applied as one uniform scale on the figure node
    # at load (resident_routines._upgrade) — Blender-side baking fought
    # FBX unit normalization twice and lost; the exports ship untouched.
    decimate_to_budget()
    shrink_textures()
    strip_emission()
    export_gltf(out_path)
    # Regenerated textures are ungraded; clear the grade markers so
    # grade_character_textures.py re-runs on them.
    for marker in glob.glob(os.path.join(out_dir, "*.graded")):
        os.remove(marker)
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
                os.path.join(ROOT, "game", "assets", "characters", slug),
                slug, bake_body=True)
    for name, spec in mapping["creatures"].items():
        out_dir = os.path.join(ROOT, "game", "assets", "creatures", name)
        convert(spec["source"], out_dir, name)
        export_creature_moves(spec["source"], out_dir, name)
    print("dump conversion complete")
