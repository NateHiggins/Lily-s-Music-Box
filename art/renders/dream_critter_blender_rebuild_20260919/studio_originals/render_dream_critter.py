"""Matched studio renders of evaluated anatomy; never saves/exports the source.

blender --background --factory-startup --disable-autoexec --python SCRIPT --
    --blend specimen.blend --out-dir NEW_DIRECTORY --resolution 768 --samples 32

Modes share camera/light/pose and union-of-all-poses framing. Cutaway removes
the camera-facing half of Skin with a diagnostic clipping material; it is
uncapped and does not prove normal-view translucency or runtime optics.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
import math
from pathlib import Path
import sys


def checker_module():
    path = Path(__file__).with_name("check_dream_critter_anatomy.py")
    spec = importlib.util.spec_from_file_location("dream_critter_anatomy", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def arguments():
    args = sys.argv
    return args[args.index("--") + 1:] if "--" in args else args[1:]


def choices(value, allowed, parser, label):
    values = value.split(",")
    if not values or len(values) != len(set(values)) or any(v not in allowed for v in values):
        parser.error("invalid/duplicate " + label + "; choose " + ",".join(allowed))
    return values


def display_scale(value):
    try:
        values = tuple(float(v) for v in value.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("display scale requires three positive finite numbers") from error
    if len(values) != 3 or not all(math.isfinite(v) and v > 0 for v in values):
        raise argparse.ArgumentTypeError("display scale requires three positive finite numbers")
    return values


def scale_specimen(objects, scale):
    """One temporary parent transforms mesh and armature together, without save."""
    import bpy
    from mathutils import Matrix
    parent = bpy.data.objects.new("DIAGNOSTIC_DISPLAY_SCALE", None)
    bpy.context.scene.collection.objects.link(parent)
    members = set(objects.values())
    for obj in objects.values():
        if obj.parent in members:
            continue
        matrix = obj.matrix_world.copy()
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_world = matrix
    parent.scale = scale
    bpy.context.view_layer.update()


def grey_material():
    import bpy
    material = bpy.data.materials.new("DIAGNOSTIC_NEUTRAL_CLAY")
    if material.node_tree is None: material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (.38, .38, .38, 1)
    bsdf.inputs["Roughness"].default_value = .72
    bsdf.inputs["Metallic"].default_value = 0
    return material


def clipping_material(center, direction):
    import bpy
    material = grey_material()
    material.name = "DIAGNOSTIC_UNCAPPED_HALF_SECTION"
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    output = nodes.get("Material Output")
    geometry = nodes.new("ShaderNodeNewGeometry")
    subtract = nodes.new("ShaderNodeVectorMath")
    subtract.operation = "SUBTRACT"
    subtract.inputs[1].default_value = center
    links.new(geometry.outputs["Position"], subtract.inputs[0])
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = direction
    links.new(subtract.outputs["Vector"], dot.inputs[0])
    front = nodes.new("ShaderNodeMath")
    front.operation = "GREATER_THAN"
    front.inputs[1].default_value = 0.0
    links.new(dot.outputs["Value"], front.inputs[0])
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(front.outputs[0], mix.inputs[0])
    links.new(bsdf.outputs[0], mix.inputs[1])
    links.new(transparent.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])
    return material


def studio(scene, center, size, engine, resolution, samples):
    import bpy
    from mathutils import Vector
    scene.render.engine = engine
    scene.render.resolution_x = scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    if engine == "CYCLES":
        scene.cycles.samples = samples
        scene.cycles.use_adaptive_sampling = False
        scene.cycles.use_denoising = False
        scene.cycles.seed = 73203
        scene.cycles.transparent_max_bounces = 16
    elif hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = samples
    else:
        raise RuntimeError("Selected engine cannot honor explicit sample count")
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    world = bpy.data.worlds.new("DIAGNOSTIC_STUDIO_WORLD")
    if world.node_tree is None: world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (.12, .12, .12, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .35
    scene.world = world
    light_records = []
    for name, offset, energy, area in (
            ("KEY", (2.4, -3.0, 3.2), 500, 2.0),
            ("FILL", (-3.0, -1.0, 1.3), 180, 2.8),
            ("RIM", (.6, 2.6, 2.7), 380, 1.5)):
        light = bpy.data.lights.new("DIAGNOSTIC_" + name, "AREA")
        light.energy, light.shape, light.size = energy * size * size, "DISK", area * size
        obj = bpy.data.objects.new(light.name, light)
        scene.collection.objects.link(obj)
        obj.location = center + Vector(offset) * size
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()
        light_records.append({"name": name, "position": list(obj.location), "energy": light.energy, "size": light.size})
    camera_data = bpy.data.cameras.new("DIAGNOSTIC_MATCHED_CAMERA")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new(camera_data.name, camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera, light_records


def frame_camera(camera, lo, hi, direction):
    from mathutils import Vector
    direction = Vector(direction).normalized()
    center, size = (lo + hi) * .5, max(hi - lo)
    camera.location = center + direction * size * 4
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    rotation = camera.rotation_euler.to_matrix()
    right, up = rotation.col[0], rotation.col[1]
    corners = [Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    extent = max(max(abs((p - center).dot(right)), abs((p - center).dot(up))) for p in corners)
    camera.data.ortho_scale = max(extent * 2.24, 1e-4)
    camera.data.clip_start = max(size * .001, 1e-5)
    camera.data.clip_end = size * 12
    return {"position": list(camera.location), "rotation": list(camera.rotation_euler),
            "orthographic_scale": camera.data.ortho_scale, "clip_start": camera.data.clip_start,
            "clip_end": camera.data.clip_end, "direction": list(direction), "center": list(center)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--blend", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--resolution", type=int, default=768)
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--engine", choices=("CYCLES", "BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"), default="CYCLES")
    parser.add_argument("--poses", default="neutral,law_half,law_full")
    parser.add_argument("--views", default="front,side,three_quarter")
    parser.add_argument("--modes", default="neutral,material,cutaway")
    parser.add_argument("--display-scale", type=display_scale, default=(1.0, 1.0, 1.0),
                        help="render-only Blender XYZ scale; default1,1,1 preserves normalized source")
    args = parser.parse_args(arguments() if argv is None else argv)
    if not 128 <= args.resolution <= 4096: parser.error("resolution must be 128..4096")
    if not 1 <= args.samples <= 4096: parser.error("samples must be 1..4096")
    if args.out_dir.exists(): parser.error("output directory exists; use a new comparison directory")
    view_directions = {"front": (0, -1, .15), "side": (1, 0, .15),
                       "three_quarter": (1, -1.3, .8), "top": (0, .001, 1)}
    views = choices(args.views, list(view_directions), parser, "views")
    modes = choices(args.modes, ["neutral", "material", "cutaway"], parser, "modes")
    checker = checker_module()
    import bpy
    report = {"schema": "dream_critter_studio_render.v1", "evidence_class": "INERT", "status": "ERROR",
              "images": [], "limitations": ["Studio Blender renders, not native shared-RG8/material/runtime acceptance.",
                  "Cutaway is an uncapped diagnostic half-section; not ordinary-view internal visibility.",
                  "Framing is shared across all authored poses and modes; pixel differences are not quality scores."]}
    source, before = None, None
    args.out_dir.mkdir(parents=True, exist_ok=False)
    try:
        source, before, c, objects, rig = checker.load_source(args.blend)
        report["source"] = checker.provenance(source, before, c)
        report["renderer_sha256"] = checker.sha256(__file__)
        report["render_settings"] = {"engine": args.engine, "resolution": args.resolution, "samples": args.samples,
                                     "view_transform": "AgX", "look": "None", "seed": 73203,
                                     "display_scale_blender_xyz": list(args.display_scale)}
        report["limitations"].append("Display scale is an explicit presentation transform, not a measurement or biological claim.")
        scale_specimen(objects, args.display_scale)
        samples = checker.pose_samples(c)
        pose_names = [p["name"] for p in samples]
        selected = pose_names if args.poses == "all" else choices(args.poses, pose_names, parser, "poses")
        meshes = [objects[p["object"]] for p in c["parts"]]
        # Render only the declared specimen and a new, fully specified studio.
        for obj in list(bpy.context.scene.objects):
            if obj.name not in objects: obj.hide_render = True
        for obj in meshes: obj.hide_render = False
        originals = {obj.name: [slot.material for slot in obj.material_slots] for obj in meshes}
        checker.need(all(originals.values()) and all(m is not None for mats in originals.values() for m in mats),
                     "material mode requires authored material slots on every mesh")
        union_lo, union_hi = None, None
        pose_bounds = {}
        for pose in samples:
            checker.apply_pose(c, objects, rig, pose)
            deps = bpy.context.evaluated_depsgraph_get()
            deps.update()
            lo, hi = checker.bounds_of([checker.evaluated_geometry(obj, deps) for obj in meshes])
            pose_bounds[pose["name"]] = {"min": list(lo), "max": list(hi)}
            if union_lo is None: union_lo, union_hi = lo.copy(), hi.copy()
            else:
                for i in range(3):
                    union_lo[i], union_hi[i] = min(union_lo[i], lo[i]), max(union_hi[i], hi[i])
        report["all_pose_bounds"] = pose_bounds
        report["framing_bounds"] = {"min": list(union_lo), "max": list(union_hi)}
        center, size = (union_lo + union_hi) * .5, max(union_hi - union_lo)
        camera, lights = studio(bpy.context.scene, center, size, args.engine, args.resolution, args.samples)
        report["lights"] = lights
        grey = grey_material()
        for view in views:
            frame = frame_camera(camera, union_lo, union_hi, view_directions[view])
            cutaway = clipping_material(frame["center"], frame["direction"])
            for pose in samples:
                if pose["name"] not in selected: continue
                checker.apply_pose(c, objects, rig, pose)
                for mode in modes:
                    for obj in meshes:
                        materials = originals[obj.name]
                        obj.data.materials.clear()
                        for material in materials:
                            use = grey if mode == "neutral" else material
                            if mode == "cutaway" and obj.name == c["body"]: use = cutaway
                            obj.data.materials.append(use)
                    filename = pose["name"] + "__" + view + "__" + mode + ".png"
                    path = args.out_dir / filename
                    bpy.context.scene.render.filepath = str(path.resolve())
                    bpy.ops.render.render(write_still=True)
                    checker.need(path.exists() and path.stat().st_size > 0, "render did not write " + filename)
                    report["images"].append({"file": filename, "sha256": checker.sha256(path),
                        "pose": pose, "view": view, "mode": mode, "camera": frame,
                        "diagnostic_cutaway": mode == "cutaway"})
                    print("[DREAM CRITTER RENDER]", filename)
        report["status"] = "COMPLETE"
    except Exception as error:
        report["error"] = type(error).__name__ + ": " + str(error)
    finally:
        if source is not None:
            report["source_unchanged"] = checker.sha256(source) == before
            if not report["source_unchanged"]: report["status"] = "ERROR"
    checker.write_report(args.out_dir / "render_manifest.json", report)
    print("[DREAM CRITTER RENDER]", report["status"], "images=" + str(len(report["images"])))
    return 0 if report["status"] == "COMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
