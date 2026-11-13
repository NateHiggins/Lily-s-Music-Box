"""Game export of one built cast member. CPU only; the source files are opened and never saved.

    blender --factory-startup -b --python-exit-code 1 --python art/blender/scripts/export_cast_actor.py -- \
        <actor id> <build dir> <out dir>

<build dir> is what art/blender/scripts/build_cast_wardrobe.py wrote: <id>.blend (the body, face and
hair), <id>__parts.blend (every garment, each marked with its part) and one <id>__<part>.json a part.
<out dir> receives <id>.gltf, one <id>__<part>.gltf a part, their .bin files, the pictures they use,
the part notes, and <id>_EXPORT.json. Run art/tools/cast_intake.py rather than this by hand: it checks
the result, shares identical pictures between people and writes the material recipes.

What it does to the source, in memory only:
  - every material gets a colour, a roughness and a normal picture (a small constant one where the
    builder used a plain value), and a stable name, cast_<id>_<name>, for the material catalogue;
  - pictures larger than the game needs are scaled down (1024 on the body, 512 on garments);
  - meshes without a UV map (spectacles, buttons) get a box-projected one;
  - tangents are Blender's own (per point, the engine's handedness); only the few corners that come
    out wrong-handed or far from their triangle are given that triangle's own frame.

It changes no point, weight, shape key, bone or name of a mesh.
"""
import hashlib
import json
import os
import re
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from cast_export_derivatives import _read, _remap  # noqa: E402  (the accessor reader and writer are shared with the strict repair)

ARGS = sys.argv[sys.argv.index("--") + 1:]
WHO, BUILD, OUT = ARGS[0], Path(ARGS[1]).resolve(), Path(ARGS[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
SKIN_AREAS = ["arms", "chest", "feet", "hands", "head", "hips", "legs", "trunk"]
HAIR = ["Hair", "HairCap", "HatHair"]
BODY_PICTURE_LIMIT = 1024
PART_PICTURE_LIMIT = 512
MIN_AGREEMENT = 0.5        # the cosine of sixty degrees


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class SmoothTangentRepair:
    """Keep the exporter's per-point tangents; give a triangle its own frame only where a corner is
    wrong-handed (by the engine's convention: the binormal runs toward falling v) or further than the
    stated angle from that triangle's UV derivative. Only those triangles are split from their points."""
    reports = []
    errors = []        # the exporter swallows what a hook raises, so refusals are kept here and read afterwards

    def gather_mesh_hook(self, mesh, *unused):
        try:
            self.repair(mesh)
        except Exception as error:
            type(self).errors.append("%s: %s" % (mesh.name, error))

    def repair(self, mesh):
        for primitive in mesh.primitives:
            attributes = primitive.attributes
            if primitive.mode not in (None, 4) or primitive.indices is None:
                raise ValueError("cast export supports indexed triangles only")
            if any(key not in attributes for key in ("POSITION", "NORMAL", "TEXCOORD_0", "TANGENT")):
                raise ValueError("cast mesh lacks position, normal, UV or tangent")
            arrays = {key: _read(accessor) for key, accessor in attributes.items()}
            count = len(arrays["POSITION"])
            indices = _read(primitive.indices).astype(np.int64).reshape(-1, 3)
            # A tangent lies in the surface. Where the normals were set by hand (hair cards, rounded seams) the
            # exporter's tangent can lean out of it; each is laid back square to its normal. Codex's review of
            # cast_r11 asked for this to be a check; the stricter checker then found 54 meshes that leaned.
            normal_ = arrays["NORMAL"].astype(float)
            along_ = arrays["TANGENT"][:, :3].astype(float)
            lean = np.sum(normal_ * along_, axis=1)
            squared_ = along_ - normal_ * lean[:, None]
            size_ = np.linalg.norm(squared_, axis=1)
            lost = size_ < 1e-6
            if np.any(lost):
                # A tangent that ran along its normal has no direction in the surface. It is given one square to the
                # normal; the corner check below then turns it to its triangle's own UV direction where that differs.
                spare = np.cross(normal_[lost], np.where(abs(normal_[lost, :1]) < 0.9, [[1.0, 0.0, 0.0]], [[0.0, 1.0, 0.0]]))
                squared_[lost] = spare
                size_[lost] = np.linalg.norm(spare, axis=1)
            leaning = int((abs(lean) > 1e-4).sum())
            if leaning:
                arrays["TANGENT"] = arrays["TANGENT"].copy()
                arrays["TANGENT"][:, :3] = (squared_ / size_[:, None]).astype(arrays["TANGENT"].dtype)
            p = arrays["POSITION"][indices].astype(float)
            n = arrays["NORMAL"][indices].astype(float)
            uv = arrays["TEXCOORD_0"][indices].astype(float)
            a, b = uv[:, 1] - uv[:, 0], uv[:, 2] - uv[:, 0]
            det = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
            flat = ~np.isfinite(det) | (abs(det) <= 1e-12)
            # RUL-012: a triangle with real area has UV area. One that has none is a fault in the built source
            # (art/blender/scripts/build_cast_wardrobe.py repairs them there); it is refused here, not skipped.
            real = np.linalg.norm(np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=1) * 0.5 > 1e-10
            if np.any(flat & real):
                raise ValueError("%d triangles with real area have no UV area" % int((flat & real).sum()))
            safe = np.where(flat, 1.0, det)
            du = ((p[:, 1] - p[:, 0]) * b[:, 1, None] - (p[:, 2] - p[:, 0]) * a[:, 1, None]) / safe[:, None]
            dv = ((p[:, 2] - p[:, 0]) * a[:, 0, None] - (p[:, 1] - p[:, 0]) * b[:, 0, None]) / safe[:, None]
            expected = du[:, None, :] - n * np.sum(du[:, None, :] * n, axis=2)[:, :, None]
            length = np.linalg.norm(expected, axis=2)
            usable = (~flat)[:, None] & (length > 1e-12)
            expected = expected / np.where(length > 1e-12, length, 1.0)[:, :, None]
            tangent = arrays["TANGENT"][indices].copy()
            agreement = np.sum(expected * tangent[:, :, :3], axis=2)
            handed = -np.sum(np.cross(n, tangent[:, :, :3]) * dv[:, None, :], axis=2) * tangent[:, :, 3]
            # A corner is judged only where its triangle has a UV derivative to judge it by.
            bad = np.any(usable & ((agreement < MIN_AGREEMENT) | (handed <= 0) | ~np.isfinite(agreement)), axis=1)
            row = {"mesh": str(mesh.name), "triangles": int(len(indices)), "vertices_before": int(count), "repaired_triangles": int(bad.sum()),
                   "degenerate_triangles": int(flat.sum()), "tangents_squared": leaning, "morph_targets": len(primitive.targets or [])}
            if np.any(bad):
                fix = bad[:, None] & usable
                tangent[..., :3] = np.where(fix[..., None], expected.astype("<f4"), tangent[..., :3])
                sign = np.where(np.sum(np.cross(n, tangent[..., :3].astype(float)) * dv[:, None, :], axis=2) < 0, 1, -1)
                tangent[..., 3] = np.where(fix, sign, tangent[..., 3])
                if not np.isfinite(tangent).all():
                    raise ValueError("a repaired tangent is not finite")
                keys = np.empty(indices.size, dtype=[("vertex", "<u4"), ("frame", "<u4", (4,))])
                keys["vertex"] = indices.ravel()
                keys["frame"] = tangent.reshape(-1, 4).astype("<f4").view("<u4")
                # A point keeps one copy for each distinct frame its corners now carry: untouched corners
                # share the exporter's frame, so only the repaired triangles gain points.
                _, first, inverse = np.unique(keys, return_index=True, return_inverse=True)
                origin = indices.ravel()[first]
                for key, accessor in list(attributes.items()):
                    values = tangent.reshape(-1, 4)[first].astype("<f4") if key == "TANGENT" else arrays[key][origin]
                    attributes[key] = _remap(accessor, values, sparse=accessor.sparse is not None)
                for target in primitive.targets or []:
                    for key, accessor in list(target.items()):
                        values = _read(accessor)
                        if len(values) != count:
                            raise ValueError("a morph target disagrees with its mesh")
                        values = values[origin]
                        target[key] = _remap(accessor, values, sparse=accessor.sparse is not None or not np.any(values))
                primitive.indices = _remap(primitive.indices, inverse.reshape(-1, 1).astype("<u4"), element=True)
                primitive.indices.component_type = 5125
                row["vertices_after"] = int(len(origin))
            else:
                if leaning:
                    attributes["TANGENT"] = _remap(attributes["TANGENT"], arrays["TANGENT"].astype("<f4"), sparse=False)
                row["vertices_after"] = int(count)
            type(self).reports.append(row)


def principled(material):
    tree = material.node_tree if material and material.use_nodes else None
    return next((node for node in tree.nodes if node.type == "BSDF_PRINCIPLED"), None) if tree else None


def constant_picture(name, rgb, colour_space):
    image = bpy.data.images.new(name, 16, 16, alpha=False)
    image.colorspace_settings.name = colour_space
    image.pixels.foreach_set(np.tile(np.array([rgb[0], rgb[1], rgb[2], 1.0], np.float32), 256))
    image.pack()
    return image


def linear_to_srgb(value):
    return value * 12.92 if value <= 0.0031308 else 1.055 * value ** (1 / 2.4) - 0.055


def finish_material(material, slug, limit, completed):
    """Colour, roughness and normal each from a picture; pictures within the limit."""
    shader = principled(material)
    if shader is None:
        raise ValueError("material has no Principled shader: " + material.name)
    tree = material.node_tree
    made = []
    colour = shader.inputs["Base Color"]
    if not colour.is_linked:
        value = colour.default_value[:3]
        # The picture is stored sRGB; the socket's value is linear.
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = constant_picture(slug + "_albedo", [linear_to_srgb(c) for c in value], "sRGB")
        tree.links.new(node.outputs["Color"], colour)
        colour.default_value = (1.0, 1.0, 1.0, 1.0)
        made.append("albedo")
    rough = shader.inputs["Roughness"]
    if not rough.is_linked:
        value = float(rough.default_value)
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = constant_picture(slug + "_roughness", [value, value, value], "Non-Color")
        tree.links.new(node.outputs["Color"], rough)
        rough.default_value = 1.0
        made.append("roughness")
    normal = shader.inputs["Normal"]
    if not normal.is_linked:
        node = tree.nodes.new("ShaderNodeTexImage")
        node.image = constant_picture(slug + "_normal", [0.5, 0.5, 1.0], "Non-Color")
        bump = tree.nodes.new("ShaderNodeNormalMap")
        tree.links.new(node.outputs["Color"], bump.inputs["Color"])
        tree.links.new(bump.outputs["Normal"], normal)
        made.append("normal")
    alpha = shader.inputs["Alpha"]
    if alpha.is_linked:
        # A picture with no see-through part makes an opaque material. Left "blended", skin and cloth were
        # drawn with the glass: unsorted, without depth, and through each other.
        source = alpha.links[0].from_node
        image = source.image if source.type == "TEX_IMAGE" else None
        if image is not None and image.size[0]:
            pixels = np.empty(image.size[0] * image.size[1] * 4, np.float32)
            image.pixels.foreach_get(pixels)
            if float(pixels[3::4].min()) > 0.996:
                tree.links.remove(alpha.links[0])
                alpha.default_value = 1.0
                made.append("opaque")
    metal = shader.inputs["Metallic"]
    if metal.is_linked:
        raise ValueError("a metal picture is not expected on a cast material: " + material.name)
    for node in tree.nodes:
        if node.type == "TEX_IMAGE" and node.image and max(node.image.size) > limit:
            image = node.image
            smaller = image.copy()
            width, height = image.size
            scale = limit / max(width, height)
            smaller.scale(max(1, round(width * scale)), max(1, round(height * scale)))
            smaller.pack()
            node.image = smaller
    if made:
        completed[slug] = made


def box_uv(obj):
    """A UV map for a small mesh that has none: each face laid flat along its own best axis."""
    mesh = obj.data
    # Tangents are only made for triangles and quads.
    cut = bmesh.new()
    cut.from_mesh(mesh)
    bmesh.ops.triangulate(cut, faces=[face for face in cut.faces if len(face.verts) > 4])
    cut.to_mesh(mesh)
    cut.free()
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        axis = max(range(3), key=lambda k: abs(polygon.normal[k]))
        u, v = [k for k in range(3) if k != axis]
        for loop in polygon.loop_indices:
            co = mesh.vertices[mesh.loops[loop].vertex_index].co
            layer.data[loop].uv = (co[u] * 4.0 + 0.5 + 0.013 * (loop % 7), co[v] * 4.0 + 0.5 + 0.017 * (loop % 5))


def prepare(objects, limit, renamed, completed):
    for obj in objects:
        if obj.type != "MESH":
            continue
        if not obj.data.uv_layers:
            box_uv(obj)
        if not obj.material_slots or any(slot.material is None for slot in obj.material_slots):
            raise ValueError("mesh without a material: " + obj.name)
        for slot in obj.material_slots:
            material = slot.material
            if material.name.startswith("cast_" + WHO + "_"):
                continue
            slug = "cast_%s_%s" % (WHO, re.sub("[^a-z0-9]+", "_", material.name.lower()).strip("_"))
            if slug in bpy.data.materials:
                raise ValueError("two materials come to the same catalogue name: " + slug)
            # A material may ask for more picture than its kind gets (embroidery does), up to the body's own limit.
            finish_material(material, slug, min(BODY_PICTURE_LIMIT, max(limit, int(material.get("picture_limit", 0)))), completed)
            renamed[material.name] = slug
            material.name = slug


def export(rig, objects, stem):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig] + objects:
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=str(OUT / (stem + ".gltf")), export_format="GLTF_SEPARATE", use_selection=True, export_morph=True,
                              export_morph_normal=False, export_animations=False, export_yup=True, export_tangents=True,
                              export_vertex_color="ACTIVE", export_extras=False, export_keep_originals=False)


def worn(obj):
    return obj.type == "MESH" and any(m.type == "ARMATURE" for m in obj.modifiers) and not obj.name.endswith("_collider")


import io_scene_gltf2  # noqa: E402
io_scene_gltf2.glTF2ExportUserExtension = SmoothTangentRepair
if os.environ.get("CAST_TANGENTS") == "strict":
    # A control only: the strict per-triangle repair, for comparing against the export above.
    from cast_export_derivatives import CastDerivativeExportExtension  # noqa: E402
    io_scene_gltf2.glTF2ExportUserExtension = CastDerivativeExportExtension
report = {"actor": WHO, "tangents_mode": os.environ.get("CAST_TANGENTS", "smooth"), "sources": {}, "renamed_materials": {}, "completed_channels": {}, "parts": {}}

# ---------------------------------------------------------------- the body
body_source = BUILD / (WHO + ".blend")
report["sources"][body_source.name] = sha(body_source)
bpy.ops.wm.open_mainfile(filepath=str(body_source))
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
if len(rig.data.bones) != 76:
    raise ValueError("the body does not carry the 76-bone skeleton")
skin = [o for o in bpy.data.objects if worn(o) and o.name.startswith("Skin_")]
if sorted(o.name[5:] for o in skin) != SKIN_AREAS:
    raise ValueError("the body must carry the eight named skin parts exactly once: " + str(sorted(o.name for o in skin)))
face = [o for o in bpy.data.objects if worn(o) and o.name.startswith("Face_")]
hair = [bpy.data.objects[name] for name in HAIR if name in bpy.data.objects]
if [o.name for o in hair][:2] != ["Hair", "HairCap"]:
    raise ValueError("the body must carry Hair and HairCap")
# Anything else the person always wears (spectacles, a hair clip) goes with the body.
extra = [o for o in bpy.data.objects if worn(o) and o.name != "Skin" and o not in skin + face + hair and not o.get("part")]
base = skin + face + hair + extra
prepare(base, BODY_PICTURE_LIMIT, report["renamed_materials"], report["completed_channels"])
export(rig, base, WHO)
look_file = BUILD / (WHO + "_hair_look.json")
if look_file.is_file():
    shutil.copyfile(look_file, OUT / look_file.name)
report["body"] = {"hair_look": look_file.is_file(), "skin": len(skin), "face": [o.name for o in face], "hair": [o.name for o in hair], "also": [o.name for o in extra],
                  "shape_keys": {o.name: len(o.data.shape_keys.key_blocks) - 1 for o in base if o.data.shape_keys}}
assert sha(body_source) == report["sources"][body_source.name]

# ---------------------------------------------------------------- the garments, one file a part
parts_source = BUILD / (WHO + "__parts.blend")
report["sources"][parts_source.name] = sha(parts_source)
bpy.ops.wm.open_mainfile(filepath=str(parts_source))
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
if len(rig.data.bones) != 76:
    raise ValueError("the garments do not carry the 76-bone skeleton")
by_part = {}
for obj in bpy.data.objects:
    if worn(obj) and obj.get("part"):
        by_part.setdefault(str(obj["part"]), []).append(obj)
notes = sorted(BUILD.glob(WHO + "__*.json"))
wanted = [path.stem.split("__", 1)[1] for path in notes if path.stem.split("__", 1)[1] != "parts"]
if sorted(by_part) != sorted(wanted):
    raise ValueError("garments and their notes disagree: %s against %s" % (sorted(by_part), sorted(wanted)))
for part in sorted(by_part):
    prepare(by_part[part], PART_PICTURE_LIMIT, report["renamed_materials"], report["completed_channels"])
for part in sorted(by_part):
    export(rig, by_part[part], "%s__%s" % (WHO, part))
    shutil.copyfile(BUILD / ("%s__%s.json" % (WHO, part)), OUT / ("%s__%s.json" % (WHO, part)))
    report["parts"][part] = sorted(o.name for o in by_part[part])
assert sha(parts_source) == report["sources"][parts_source.name]

# ---------------------------------------------------------------- what was written
recipes = {}
bindings = []
for path in sorted(OUT.glob("*.gltf")):
    document = json.loads(path.read_text(encoding="utf-8"))
    for material in document.get("materials", []):
        spec = material.get("pbrMetallicRoughness", {})
        recipe = {"base_color": spec.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]), "roughness": spec.get("roughnessFactor", 1.0), "metallic": spec.get("metallicFactor", 1.0)}
        if recipes.setdefault(material["name"], recipe) != recipe:
            raise ValueError("one material, two recipes: " + material["name"])
        channels = {}
        for channel, entry in (("albedo", spec.get("baseColorTexture")), ("roughness_metallic", spec.get("metallicRoughnessTexture")), ("normal", material.get("normalTexture"))):
            if entry is None:
                raise ValueError("%s: %s has no %s picture" % (path.name, material["name"], channel))
            channels[channel] = document["images"][document["textures"][entry["index"]]["source"]].get("uri", "")
        bindings.append({"asset": path.name, "material": material["name"], "channels": channels, "alpha_mode": material.get("alphaMode", "OPAQUE"),
                         "double_sided": bool(material.get("doubleSided", False))})
report["materials"] = recipes
report["bindings"] = bindings
report["tangents"] = SmoothTangentRepair.reports
if SmoothTangentRepair.errors:
    raise ValueError("tangent repair refused: " + "; ".join(SmoothTangentRepair.errors))
report["files"] = {path.name: {"bytes": path.stat().st_size, "sha256": sha(path)} for path in sorted(OUT.iterdir()) if path.is_file() and path.name != WHO + "_EXPORT.json"}
(OUT / (WHO + "_EXPORT.json")).write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
print("CAST EXPORT COMPLETE", WHO, len(recipes), "materials", len(report["parts"]), "parts")
