"""First-person rubber-hose arm for Orison (Lily, 2026-11-24).

A black-and-white cartoon arm shown in first person while the player interacts:
a jointless black "hose" arm and a puffy white glove (cuff, palm, three fingers
and a thumb, three ink stitches on the back). The arm is a 24-bone chain so
the runtime can bend it as one smooth curve (Lily, 2026-11-25: eight bones
showed corners); each finger has two bones so the
runtime can curl the hand around what it holds.

Run:  blender -b -P art/blender/scripts/build_first_person_hose_arm.py -- [--review DIR]

Writes game/assets/characters/player_hose_arm/hose_arm.glb (Y-up, skinned) and,
with --review, Workbench renders of the rest pose and a gripping pose.
Coordinates are metres. In Blender the arm runs along +Y from the shoulder at the
origin; the palm faces -Z. glTF export turns +Y into Godot -Z (forward).
"""
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "game/assets/characters/player_hose_arm/hose_arm.glb"

ARM_LENGTH = 0.55
ARM_RADIUS = 0.030  # at the wrist; the runtime keeps this width on screen up the hose
ARM_BONES = 24
SIDES = 18
RINGS_PER_BONE = 3
INK = (0.02, 0.02, 0.02, 1.0)
GLOVE = (0.96, 0.96, 0.94, 1.0)

# Fingers: (name, x offset at the knuckle, two segment lengths, radius).
FINGERS = [
    ("Index", 0.026, (0.030, 0.026), 0.0125),
    ("Middle", 0.0, (0.033, 0.028), 0.013),
    ("Ring", -0.026, (0.029, 0.025), 0.0122),
]
KNUCKLE_Y = ARM_LENGTH + 0.078
THUMB_BASE = Vector((0.040, ARM_LENGTH + 0.030, -0.004))
THUMB_DIR = Vector((0.75, 0.55, -0.35)).normalized()
THUMB_SEGMENTS = (0.024, 0.022)
THUMB_RADIUS = 0.0128


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgba):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.9
    mat.diffuse_color = rgba
    return mat


def build_armature():
    data = bpy.data.armatures.new("HoseArmRig")
    rig = bpy.data.objects.new("HoseArmRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    step = ARM_LENGTH / ARM_BONES
    # The arm bones and the hand have no parents: the runtime sets each one's
    # global pose, stretching the arm bones along their length. A child of a
    # stretched bone would inherit a shear that a bone pose cannot hold, and its
    # rotation then breaks (the glove smeared across the view in a 24-bone film).
    for i in range(ARM_BONES):
        bone = data.edit_bones.new("Arm_%02d" % i)
        bone.head = Vector((0, i * step, 0))
        bone.tail = Vector((0, (i + 1) * step, 0))
        bone.roll = 0.0
    hand = data.edit_bones.new("Hand")
    hand.head = Vector((0, ARM_LENGTH, 0))
    hand.tail = Vector((0, KNUCKLE_Y, 0))
    for name, x, lengths, _radius in FINGERS:
        base = Vector((x, KNUCKLE_Y, 0))
        first = data.edit_bones.new(name + "_1")
        first.head = base
        first.tail = base + Vector((0, lengths[0], 0))
        first.parent = hand
        second = data.edit_bones.new(name + "_2")
        second.head = first.tail
        second.tail = first.tail + Vector((0, lengths[1], 0))
        second.parent = first
        second.use_connect = True
    first = data.edit_bones.new("Thumb_1")
    first.head = THUMB_BASE
    first.tail = THUMB_BASE + THUMB_DIR * THUMB_SEGMENTS[0]
    first.parent = hand
    second = data.edit_bones.new("Thumb_2")
    second.head = first.tail
    second.tail = first.tail + THUMB_DIR * THUMB_SEGMENTS[1]
    second.parent = first
    second.use_connect = True
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def new_object(name, mesh_builder, mat, groups):
    """mesh_builder(bm) fills a BMesh and returns per-vertex {group: weight} lists."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    weights = mesh_builder(bm)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for group in groups:
        obj.vertex_groups.new(name=group)
    for index, weight_map in enumerate(weights):
        for group, weight in weight_map.items():
            if weight > 0.0:
                obj.vertex_groups[group].add([index], weight, "REPLACE")
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def arm_tube(bm):
    weights = []
    step = ARM_LENGTH / ARM_BONES
    rings = ARM_BONES * RINGS_PER_BONE + 1
    ring_verts = []
    for r in range(rings):
        y = ARM_LENGTH * r / (rings - 1)
        # One even width all the way into the cuff (Lily, 2026-11-25: a taper
        # before the glove read as weak).
        radius = ARM_RADIUS
        verts = []
        for s in range(SIDES):
            a = 2 * math.pi * s / SIDES
            verts.append(bm.verts.new((radius * math.cos(a), y, radius * math.sin(a))))
            # Blend between the two nearest bone centres along the chain.
            f = min(max(y / step - 0.5, 0.0), ARM_BONES - 1.0)
            low = int(math.floor(f))
            high = min(low + 1, ARM_BONES - 1)
            t = f - low
            weight_map = {"Arm_%02d" % low: 1.0 - t}
            if high != low:
                weight_map["Arm_%02d" % high] = weight_map.get("Arm_%02d" % high, 0.0) + t
            weights.append(weight_map)
        ring_verts.append(verts)
    for r in range(rings - 1):
        for s in range(SIDES):
            a, b = ring_verts[r][s], ring_verts[r][(s + 1) % SIDES]
            c, d = ring_verts[r + 1][(s + 1) % SIDES], ring_verts[r + 1][s]
            bm.faces.new((a, b, c, d))
    # Close the shoulder end (it sits below the frame).
    cap = bm.verts.new((0, 0, 0))
    weights.append({"Arm_00": 1.0})
    for s in range(SIDES):
        bm.faces.new((cap, ring_verts[0][(s + 1) % SIDES], ring_verts[0][s]))
    return weights


def ellipsoid(bm, centre, radii, rotation=Matrix.Identity(3), segments=16, rings=10):
    verts = []
    grid = []
    for r in range(1, rings):
        phi = math.pi * r / rings
        row = []
        for s in range(segments):
            theta = 2 * math.pi * s / segments
            local = Vector((math.sin(phi) * math.cos(theta) * radii[0],
                            math.cos(phi) * radii[1],
                            math.sin(phi) * math.sin(theta) * radii[2]))
            v = bm.verts.new(centre + rotation @ local)
            row.append(v)
            verts.append(v)
        grid.append(row)
    top = bm.verts.new(centre + rotation @ Vector((0, radii[1], 0)))
    bottom = bm.verts.new(centre + rotation @ Vector((0, -radii[1], 0)))
    verts += [top, bottom]
    for r in range(len(grid) - 1):
        for s in range(segments):
            bm.faces.new((grid[r][s], grid[r][(s + 1) % segments], grid[r + 1][(s + 1) % segments], grid[r + 1][s]))
    for s in range(segments):
        bm.faces.new((top, grid[0][(s + 1) % segments], grid[0][s]))
        bm.faces.new((bottom, grid[-1][s], grid[-1][(s + 1) % segments]))
    return verts


GLOVE_SCALE = 1.6  # the runtime draws the glove this much larger (first_person_hose_arm.gd)
CUFF_THROAT = ARM_RADIUS / GLOVE_SCALE * 1.06
# (radius, y from the wrist) from the throat, over the bell, round the rolled rim
# and back in under the palm; glove space.
CUFF_PROFILE = [
    (CUFF_THROAT, -0.014), (CUFF_THROAT * 1.02, -0.006), (CUFF_THROAT * 1.12, 0.000),
    (0.023, 0.006), (0.029, 0.011), (0.034, 0.015), (0.037, 0.019), (0.0375, 0.023),
    (0.035, 0.026), (0.030, 0.027), (0.024, 0.026),
]


def cuff(bm, sides=24):
    rings = []
    for radius, y in CUFF_PROFILE:
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            # A touch flatter through the hand's thickness, like the palm.
            ring.append(bm.verts.new((radius * math.cos(a), ARM_LENGTH + y, radius * 0.92 * math.sin(a))))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for s in range(sides):
            bm.faces.new((rings[r][s], rings[r][(s + 1) % sides], rings[r + 1][(s + 1) % sides], rings[r + 1][s]))
    throat = bm.verts.new((0, ARM_LENGTH + CUFF_PROFILE[0][1], 0))
    inner = bm.verts.new((0, ARM_LENGTH + CUFF_PROFILE[-1][1], 0))
    for s in range(sides):
        bm.faces.new((throat, rings[0][(s + 1) % sides], rings[0][s]))
        bm.faces.new((inner, rings[-1][s], rings[-1][(s + 1) % sides]))
    verts = [v for ring in rings for v in ring] + [throat, inner]
    return verts


def glove(bm):
    weights = []

    def add(verts, group):
        for _ in verts:
            weights.append({group: 1.0})

    # Flared bell cuff: a sleeve that starts snug round the hose (the glove is
    # drawn GLOVE_SCALE larger, so CUFF_THROAT is the hose radius in glove space),
    # swells, and ends in a rolled rim under the palm. The hose runs up inside it,
    # so the junction reads as one clean collar.
    add(cuff(bm), "Hand")
    # Puffy palm, flattened through its thickness.
    add(ellipsoid(bm, Vector((0, ARM_LENGTH + 0.048, -0.002)), (0.046, 0.040, 0.026), segments=20, rings=12), "Hand")
    for name, x, lengths, radius in FINGERS:
        y0 = KNUCKLE_Y
        add(ellipsoid(bm, Vector((x, y0 + lengths[0] * 0.5, 0)), (radius, lengths[0] * 0.80, radius)), name + "_1")
        y1 = y0 + lengths[0]
        # Cartoon fingertips: the last segment is a little rounder.
        add(ellipsoid(bm, Vector((x, y1 + lengths[1] * 0.5, 0)), (radius * 1.08, lengths[1] * 0.78, radius * 1.08)), name + "_2")
    align = Vector((0, 1, 0)).rotation_difference(THUMB_DIR).to_matrix()
    add(ellipsoid(bm, THUMB_BASE + THUMB_DIR * THUMB_SEGMENTS[0] * 0.5, (THUMB_RADIUS, THUMB_SEGMENTS[0] * 0.80, THUMB_RADIUS), align), "Thumb_1")
    tip = THUMB_BASE + THUMB_DIR * THUMB_SEGMENTS[0]
    add(ellipsoid(bm, tip + THUMB_DIR * THUMB_SEGMENTS[1] * 0.5, (THUMB_RADIUS * 1.06, THUMB_SEGMENTS[1] * 0.78, THUMB_RADIUS * 1.06), align), "Thumb_2")
    return weights


def stitches(bm):
    """Three short ink stitches on the back of the glove (+Z face)."""
    weights = []
    for x in (-0.016, 0.0, 0.016):
        for v in ellipsoid(bm, Vector((x, ARM_LENGTH + 0.052, 0.0255)), (0.0026, 0.020, 0.0016), segments=8, rings=6):
            weights.append({"Hand": 1.0})
    return weights


def uv_unwrap(obj):
    bpy.context.view_layer.objects.active = obj
    for other in bpy.context.selected_objects:
        other.select_set(False)
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def bind(obj, rig):
    obj.parent = rig
    modifier = obj.modifiers.new("Rig", "ARMATURE")
    modifier.object = rig


def grip_pose(rig, curl):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for name, _x, _lengths, _r in FINGERS:
        rig.pose.bones[name + "_1"].rotation_mode = "XYZ"
        rig.pose.bones[name + "_1"].rotation_euler = (-1.1 * curl, 0, 0)
        rig.pose.bones[name + "_2"].rotation_mode = "XYZ"
        rig.pose.bones[name + "_2"].rotation_euler = (-1.25 * curl, 0, 0)
    rig.pose.bones["Thumb_1"].rotation_mode = "XYZ"
    rig.pose.bones["Thumb_1"].rotation_euler = (-0.5 * curl, 0, 0.6 * curl)
    bpy.ops.object.mode_set(mode="OBJECT")


def review(directory, objects, rig):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.display.shading.object_outline_color = (0, 0, 0)
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    world = bpy.data.worlds.new("Review")
    world.color = (0.55, 0.55, 0.55)
    scene.world = world
    cam_data = bpy.data.cameras.new("ReviewCam")
    cam_data.lens = 45
    cam = bpy.data.objects.new("ReviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((0, ARM_LENGTH + 0.04, 0))
    for label, curl, eye in (("rest", 0.0, Vector((0.42, ARM_LENGTH - 0.15, 0.30))),
                             ("grip", 1.0, Vector((0.42, ARM_LENGTH - 0.15, 0.30))),
                             ("rest_hand", 0.0, Vector((0.16, ARM_LENGTH + 0.04, 0.18))),
                             ("junction", 1.0, Vector((0.10, ARM_LENGTH - 0.16, 0.12)))):
        grip_pose(rig, curl)
        cam.location = eye
        cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(directory / ("hose_arm_%s.png" % label))
        bpy.ops.render.render(write_still=True)
    grip_pose(rig, 0.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    review_dir = argv[argv.index("--review") + 1] if "--review" in argv else ""
    reset()
    rig = build_armature()
    ink = material("HoseInk", INK)
    white = material("HoseGlove", GLOVE)
    bones = ["Arm_%02d" % i for i in range(ARM_BONES)] + ["Hand"]
    for name, *_rest in FINGERS:
        bones += [name + "_1", name + "_2"]
    bones += ["Thumb_1", "Thumb_2"]
    arm = new_object("HoseArm", arm_tube, ink, bones)
    hand = new_object("HoseGlove", glove, white, bones)
    ink_lines = new_object("HoseStitches", stitches, ink, bones)
    objects = [arm, hand, ink_lines]
    for obj in objects:
        uv_unwrap(obj)
        bind(obj, rig)
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
    print("HOSE ARM: bones=%d triangles=%d" % (len(rig.data.bones), triangles))
    if review_dir:
        review(review_dir, objects, rig)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=False,
                              export_yup=True, export_skins=True, export_animations=False,
                              export_apply=False, export_materials="EXPORT")
    print("HOSE ARM: wrote", OUT)


main()
