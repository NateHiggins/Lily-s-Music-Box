import bpy
import math
import os
import json
from mathutils import Vector

# Reproducible stylized production character. With no environment configuration
# this regenerates Mina; the cast orchestrator supplies one profile per resident.
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DEFAULT_PROFILE = {
    "slug": "mina_vale", "display": "Mina Vale", "prefix": "Mina",
    "palette": {
        "skin": [0.42, 0.225, 0.14], "hair": [0.018, 0.026, 0.035],
        "outer": [0.035, 0.16, 0.17], "shirt": [0.58, 0.34, 0.055],
        "trousers": [0.055, 0.06, 0.072], "shoes": [0.36, 0.055, 0.045],
    },
    "motion": {
        "sway": 1.0, "glance": 1.0, "hand": 1.0, "posture": 0.0,
        "stride": 1.0, "lift": 1.0, "bounce": 1.0, "arm": 1.0,
    },
    "body": {"height": 1.0, "width": 1.0, "head": 1.0}
}
PROFILE = json.loads(os.environ.get(
    "ORISON_CHARACTER_CONFIG", json.dumps(DEFAULT_PROFILE)))
SLUG = PROFILE["slug"]
DISPLAY = PROFILE["display"]
ANIM_PREFIX = PROFILE.get("prefix", DISPLAY.split()[0])
PALETTE = PROFILE["palette"]
MOTION = PROFILE["motion"]
BODY = PROFILE["body"]
OUT_DIR = os.path.join(ROOT, "game", "assets", "characters", SLUG)
os.makedirs(OUT_DIR, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def mat(name, color, roughness=0.72, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return material


SKIN = mat("M_Skin", tuple(PALETTE["skin"]), 0.78)
HAIR = mat("M_Hair", tuple(PALETTE["hair"]), 0.55)
CARDIGAN = mat("M_Outer", tuple(PALETTE["outer"]), 0.88)
SHIRT = mat("M_Shirt", tuple(PALETTE["shirt"]), 0.82)
TROUSERS = mat("M_Trousers", tuple(PALETTE["trousers"]), 0.9)
SHOES = mat("M_Shoes", tuple(PALETTE["shoes"]), 0.68)
GLASSES = mat("M_Glasses_Brass", (0.28, 0.17, 0.055), 0.4, 0.55)
EYE = mat("M_Eyes", (0.012, 0.009, 0.007), 0.5)


def create_armature():
    arm_data = bpy.data.armatures.new(f"{SLUG}_Rig")
    arm = bpy.data.objects.new(f"{SLUG}_Rig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, head, tail, parent=None, connected=False, deform=True):
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = head, tail
        b.use_deform = deform
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = connected
        return b

    bone("root", (0, 0, 0), (0, 0, 0.12), deform=False)
    bone("hips", (0, 0, 0.88), (0, 0, 1.02), "root")
    bone("spine", (0, 0, 1.0), (0, 0, 1.24), "hips")
    bone("chest", (0, 0, 1.24), (0, 0, 1.43), "spine", True)
    bone("neck", (0, 0, 1.43), (0, 0, 1.52), "chest", True)
    bone("head", (0, 0, 1.52), (0, 0, 1.72), "neck", True)
    for side, x in (("L", 1), ("R", -1)):
        sx = 0.18 * x
        bone(f"upper_arm.{side}", (sx, 0, 1.39), (0.43*x, 0, 1.25),
             "chest")
        bone(f"forearm.{side}", (0.43*x, 0, 1.25),
             (0.61*x, -0.01, 1.08), f"upper_arm.{side}", True)
        bone(f"hand.{side}", (0.61*x, -0.01, 1.08),
             (0.68*x, -0.04, 1.02), f"forearm.{side}", True)
        bone(f"thigh.{side}", (0.11*x, 0, 0.92),
             (0.12*x, 0.015, 0.52), "hips")
        bone(f"shin.{side}", (0.12*x, 0.015, 0.52),
             (0.12*x, 0, 0.13), f"thigh.{side}", True)
        bone(f"foot.{side}", (0.12*x, 0, 0.13),
             (0.12*x, -0.18, 0.055), f"shin.{side}", True)
        bone(f"foot_ik.{side}", (0.12*x, -0.18, 0.055),
             (0.12*x, -0.18, 0.18), deform=False)
        bone(f"hand_ik.{side}", (0.68*x, -0.04, 1.02),
             (0.68*x, -0.04, 1.14), deform=False)
    bpy.ops.object.mode_set(mode="POSE")
    for side in ("L", "R"):
        leg_ik = arm.pose.bones[f"shin.{side}"].constraints.new("IK")
        leg_ik.name = f"IK_Leg.{side}"
        leg_ik.target = arm
        leg_ik.subtarget = f"foot_ik.{side}"
        leg_ik.chain_count = 2
        arm_ik = arm.pose.bones[f"forearm.{side}"].constraints.new("IK")
        arm_ik.name = f"IK_Arm.{side}"
        arm_ik.target = arm
        arm_ik.subtarget = f"hand_ik.{side}"
        arm_ik.chain_count = 2
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.show_in_front = True
    return arm


ARM = create_armature()


def assign_to_bone(obj, bone_name):
    obj.parent = ARM
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = ARM
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def uv_sphere(name, loc, scale, material, bone, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    assign_to_bone(obj, bone)
    return obj


def cube(name, loc, scale, material, bone, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    beveler = obj.modifiers.new("Soft tailoring", "BEVEL")
    beveler.width = bevel
    beveler.segments = 2
    obj.data.materials.append(material)
    assign_to_bone(obj, bone)
    return obj


def limb(name, a, b, radius, material, bone):
    a, b = Vector(a), Vector(b)
    delta = b - a
    midpoint = (a + b) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12, radius=radius, depth=delta.length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(delta)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    assign_to_bone(obj, bone)
    return obj


# Strong, readable silhouette designed for the Orison's low light.
cube("CardiganTorso", (0, 0, 1.25),
     (0.225 * BODY["width"], 0.13 * BODY["width"], 0.24),
     CARDIGAN, "chest", 0.06)
cube("MustardShirt", (0, -0.136, 1.27), (0.13, 0.018, 0.17),
     SHIRT, "chest", 0.015)
cube("Hips", (0, 0, 0.94), (0.19, 0.12, 0.105),
     TROUSERS, "hips", 0.04)
uv_sphere("Head", (0, -0.01, 1.62),
          (0.145 * BODY["head"], 0.125 * BODY["head"], 0.17 * BODY["head"]),
          SKIN, "head")
uv_sphere("HairCap", (0, 0.025, 1.68),
          (0.158 * BODY["head"], 0.14 * BODY["head"], 0.17 * BODY["head"]),
          HAIR, "head")
cube("BobLeft", (0.145, 0.025, 1.55), (0.045, 0.105, 0.145),
     HAIR, "head", 0.035)
cube("BobRight", (-0.145, 0.025, 1.55), (0.045, 0.105, 0.145),
     HAIR, "head", 0.035)
for side, x in (("L", 1), ("R", -1)):
    limb(f"UpperArm_{side}", (0.18*x, 0, 1.39),
         (0.43*x, 0, 1.25), 0.075, CARDIGAN, f"upper_arm.{side}")
    limb(f"Forearm_{side}", (0.43*x, 0, 1.25),
         (0.61*x, -0.01, 1.08), 0.065, CARDIGAN, f"forearm.{side}")
    uv_sphere(f"Hand_{side}", (0.64*x, -0.025, 1.055),
              (0.065, 0.05, 0.075), SKIN, f"hand.{side}", 12, 6)
    limb(f"Thigh_{side}", (0.11*x, 0, 0.91),
         (0.12*x, 0.015, 0.52), 0.09, TROUSERS, f"thigh.{side}")
    limb(f"Shin_{side}", (0.12*x, 0.015, 0.52),
         (0.12*x, 0, 0.13), 0.075, TROUSERS, f"shin.{side}")
    cube(f"Shoe_{side}", (0.12*x, -0.075, 0.075),
         (0.09, 0.16, 0.065), SHOES, f"foot.{side}", 0.025)

# Face: heavy glasses and focused eyes make Mina readable from dialogue range.
for x in (-0.062, 0.062):
    bpy.ops.mesh.primitive_torus_add(
        major_segments=12, minor_segments=6, location=(x, -0.128, 1.65),
        major_radius=0.052, minor_radius=0.006,
        rotation=(math.pi/2, 0, 0))
    glasses = bpy.context.object
    glasses.name = "Glasses"
    glasses.data.materials.append(GLASSES)
    assign_to_bone(glasses, "head")
    uv_sphere("Eye", (x, -0.137, 1.65), (0.013, 0.008, 0.018),
              EYE, "head", 8, 4)
limb("GlassesBridge", (-0.012, -0.132, 1.65),
     (0.012, -0.132, 1.65), 0.005, GLASSES, "head")


def key_bone(bone_name, frame, loc=(0, 0, 0), rot=(0, 0, 0)):
    pb = ARM.pose.bones[bone_name]
    pb.rotation_mode = "XYZ"
    pb.location = loc
    pb.rotation_euler = rot
    pb.keyframe_insert("location", frame=frame)
    pb.keyframe_insert("rotation_euler", frame=frame)


def new_action(name):
    ARM.animation_data_create()
    action = bpy.data.actions.new(name)
    ARM.animation_data.action = action
    return action


def bake_action(name, start, end):
    action = ARM.animation_data.action
    action.name = name
    bpy.context.view_layer.objects.active = ARM
    ARM.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=start, frame_end=end, step=1,
                     only_selected=True, visual_keying=True,
                     clear_constraints=False, clear_parents=False,
                     use_current_action=True, clean_curves=True,
                     bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    action.use_fake_user = True


# Idle: breathing, weight shift, tiny furtive looks, hands never frozen.
new_action(f"{ANIM_PREFIX}_Idle")
for frame, sway, breath, glance in (
        (1, 0.0, 0.0, 0.0), (20, 0.012, 0.012, -0.10),
        (40, 0.0, 0.02, 0.05), (60, -0.012, 0.01, 0.12),
        (80, 0.0, 0.0, 0.0)):
    sway *= MOTION["sway"]
    glance *= MOTION["glance"]
    hand = MOTION["hand"]
    posture = MOTION["posture"]
    key_bone("hips", frame, (sway, 0, breath * 0.25))
    key_bone("chest", frame, (0, posture * 0.018, breath),
             (posture * 0.06, 0, -sway * 1.8))
    key_bone("head", frame, (0, 0, 0),
             (0.02 + posture * 0.05, glance, -sway))
    # Different hand amplitudes turn the same IK rig into correcting papers,
    # sewing, painting, listening, handling archives, or nervous fidgeting.
    key_bone("hand_ik.L", frame,
             (0, (-0.012 + breath) * hand, breath * 0.3 * hand))
    key_bone("hand_ik.R", frame,
             (0, (0.01 - breath) * hand, -breath * 0.2 * hand))
    key_bone("foot_ik.L", frame)
    key_bone("foot_ik.R", frame)
bake_action(f"{ANIM_PREFIX}_Idle", 1, 80)

# Walk: IK feet are explicitly planted during stance and lifted on the swing.
new_action(f"{ANIM_PREFIX}_Walk")
walk_keys = [
    (1, 0.00, 0.18, 0.0), (5, 0.11, 0.03, 0.07),
    (9, 0.18, -0.18, 0.0), (13, 0.03, -0.03, 0.0),
    (17, -0.18, 0.18, 0.0), (21, -0.03, 0.03, 0.07),
    (25, 0.18, -0.18, 0.0), (29, 0.03, -0.03, 0.0),
    (33, 0.00, 0.18, 0.0),
]
for frame, left_y, right_y, lift in walk_keys:
    phase = (frame - 1) / 32.0 * math.tau
    stride = MOTION["stride"]
    lift_scale = MOTION["lift"]
    bounce = MOTION["bounce"]
    arm_swing = MOTION["arm"]
    key_bone("hips", frame,
             (0, 0, (0.018 + abs(math.sin(phase))*0.018) * bounce),
             (0, 0, math.sin(phase)*0.045))
    key_bone("chest", frame, (0, 0, 0),
             (0.025, 0, -math.sin(phase)*0.07))
    key_bone("head", frame, (0, 0, 0),
             (-0.02, math.sin(phase)*0.025, math.sin(phase)*0.015))
    key_bone("foot_ik.L", frame,
             (0, -left_y * stride, lift * lift_scale if left_y > 0 else 0))
    key_bone("foot_ik.R", frame,
             (0, -right_y * stride, lift * lift_scale if right_y > 0 else 0))
    key_bone("hand_ik.L", frame, (0, right_y * 0.65 * arm_swing, 0))
    key_bone("hand_ik.R", frame, (0, left_y * 0.65 * arm_swing, 0))
bake_action(f"{ANIM_PREFIX}_Walk", 1, 33)

# Mark cyclic curves for clean Godot loops.
for action in bpy.data.actions:
    if action.name.startswith(ANIM_PREFIX + "_"):
        for curve in action.fcurves:
            curve.modifiers.new("CYCLES")

bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 80
bpy.context.scene.render.fps = 30

# Regenerable visual QA thumbnail.
camera_data = bpy.data.cameras.new("PreviewCamera")
camera = bpy.data.objects.new("PreviewCamera", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (2.65, -4.2, 2.05)
camera.rotation_euler = ((Vector((0, 0, 1.02)) - camera.location)
                         .to_track_quat("-Z", "Y").to_euler())
camera_data.lens = 58
bpy.context.scene.camera = camera
bpy.context.scene.render.engine = "BLENDER_WORKBENCH"
bpy.context.scene.display.shading.light = "STUDIO"
bpy.context.scene.display.shading.studio_light = "paint.sl"
bpy.context.scene.display.shading.show_shadows = True
bpy.context.scene.display.shading.show_cavity = True
bpy.context.scene.display.shading.cavity_type = "WORLD"
bpy.context.scene.render.resolution_x = 512
bpy.context.scene.render.resolution_y = 640
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.film_transparent = True
bpy.context.scene.render.filepath = os.path.join(OUT_DIR, f"{SLUG}_preview.png")
bpy.context.scene.frame_set(20)
bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(
    filepath=os.path.join(OUT_DIR, f"{SLUG}_rigged.blend"))

bpy.ops.object.select_all(action="DESELECT")
ARM.select_set(True)
for obj in bpy.context.scene.objects:
    if obj.type == "MESH" and obj.parent == ARM:
        obj.select_set(True)
bpy.context.view_layer.objects.active = ARM
bpy.ops.export_scene.gltf(
    filepath=os.path.join(OUT_DIR, f"{SLUG}_rigged.glb"),
    export_format="GLB",
    use_selection=True,
    export_skins=True,
    export_animations=True,
    export_frame_range=False,
    export_force_sampling=True,
    export_def_bones=False,
)
print("CHARACTER_EXPORT", DISPLAY,
      os.path.join(OUT_DIR, f"{SLUG}_rigged.glb"))
