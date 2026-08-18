"""Turn a raw Meshy export into a vehicle the street can actually carry.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        -P art/blender/scripts/build_traffic_vehicle.py

WHAT ARRIVES AND WHY IT CANNOT BE USED AS IT IS

The We Tuna Pianos truck came out of Meshy at 1,961,507 triangles, 1.902 m
long, with an 8192x8192 albedo and two 4096x4096 companions packed into the
blend. Every one of those three numbers has to change before it can go on the
road, and none of that is budget-trimming:

  TRIANGLES. The whole Orison draws 546,998. This one truck is 3.6x the entire
  building, and up to fourteen of them can be live at once -- 27 million
  triangles of delivery van in front of a 0.5 million triangle city. The owner's
  standing ruling is not to budget until a desktop shows a problem; shipping
  this raw is how you manufacture that problem. Decimated to ~12k it is still
  more detailed than anything else on the street and reads correctly at the
  5-50 m the player ever sees it from.

  SCALE. It arrives 1.9 m long, which is a large suitcase. The `piano_repair`
  entry in street_traffic.gd's KINDS table is authored at 5.8 x 2.05 x 2.30 m,
  and that number is load-bearing -- the traffic system uses it for lane
  placement, the shove test and the gap the player judges. So the mesh is
  scaled to the table rather than the table being edited to the mesh.

  TEXTURES. An 8K albedo is 256 MB unpacked for an object that is a few hundred
  pixels tall on screen. 2K albedo and 1K companions are already generous.

ORIGIN. Meshy centres its meshes on their bounding box. The traffic system
places vehicles by their footprint on the carriageway, so the origin is moved
to the centre of the base -- otherwise every truck floats half its height above
the road, which is the kind of thing that looks like a physics bug for a week
before someone checks the pivot.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if not os.path.isdir(os.path.join(ROOT, "art")):
    ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

SRC = os.path.join(ROOT, "art", "blender", "meshy",
                   "Meshy_AI_We_Tuna_Pianos_Delive_0818093858_texture.blend")
OUT_DIR = os.path.join(ROOT, "game", "assets", "vehicles")
TEX_DIR = os.path.join(ROOT, "game", "assets", "building", "textures", "traffic")
NAME = "piano_truck"

# From KINDS[8] in game/scripts/building/street_traffic.gd. The mesh is fitted
# to these; they are not fitted to the mesh.
TARGET_L, TARGET_W, TARGET_H = 5.8, 2.05, 2.30

TARGET_TRIS = 12000
ALBEDO_PX = 2048
COMPANION_PX = 1024


def log(msg):
    print("[VEHICLE] %s" % msg)


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if len(meshes) != 1:
        raise SystemExit("expected one mesh, found %d" % len(meshes))
    ob = meshes[0]
    ob.name = NAME
    me = ob.data
    me.calc_loop_triangles()
    log("source: %d tris, dims %.3f x %.3f x %.3f"
        % (len(me.loop_triangles), ob.dimensions.x, ob.dimensions.y,
           ob.dimensions.z))

    # --- decimate ---------------------------------------------------------
    bpy.context.view_layer.objects.active = ob
    before = len(me.loop_triangles)
    ratio = min(1.0, float(TARGET_TRIS) / float(before))
    mod = ob.modifiers.new("decimate", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = ratio
    # Meshy meshes are dense and uniform; collapse keeps the silhouette and the
    # UV layout, which matters because the sign lettering lives in the texture
    # and a reprojected unwrap would smear it.
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    me = ob.data
    me.calc_loop_triangles()
    log("decimated: %d -> %d tris (ratio %.5f)"
        % (before, len(me.loop_triangles), ratio))

    # --- scale to the authored vehicle size -------------------------------
    dim = ob.dimensions
    axes = sorted(((dim.x, 'X'), (dim.y, 'Y'), (dim.z, 'Z')), reverse=True)
    log("longest axis is %s at %.3f m" % (axes[0][1], axes[0][0]))
    if axes[0][1] != 'X':
        raise SystemExit("expected the length to run along X; got %s"
                         % axes[0][1])
    s = TARGET_L / dim.x
    ob.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    log("scaled x%.4f -> %.2f x %.2f x %.2f m (target %.2f x %.2f x %.2f)"
        % (s, ob.dimensions.x, ob.dimensions.y, ob.dimensions.z,
           TARGET_L, TARGET_W, TARGET_H))

    # --- origin to the centre of the footprint ----------------------------
    # Use the mesh transform API rather than writing v.co in a loop. The hand
    # written version left the mesh in a state the glTF exporter flagged as
    # "Mesh_0 is not valid, and may be exported wrongly" -- and an invalid mesh
    # exported wrongly is exactly how a truck ends up half through the road
    # with nobody able to say which step did it.
    from mathutils import Matrix
    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
    shift = Vector((-(lo[0] + hi[0]) * 0.5, -(lo[1] + hi[1]) * 0.5, -lo[2]))
    me.transform(Matrix.Translation(shift))
    me.update()
    me.validate(verbose=False)
    lo2 = min(v.co.z for v in me.vertices)
    hi2 = max(v.co.z for v in me.vertices)
    log("origin moved to base centre by (%.3f, %.3f, %.3f); z now %.4f..%.3f"
        % (shift.x, shift.y, shift.z, lo2, hi2))
    if abs(lo2) > 1e-4:
        raise SystemExit("base is not on z=0 after the move: %.5f" % lo2)

    # --- project the body, keep the sign as a plate -----------------------
    # Two findings forced this shape, and both were settled by rendering
    # rather than reasoning:
    #
    # 1. The Meshy atlas cannot be used. Its lettering is gibberish at EVERY
    #    triangle budget -- tested at 12 k, 120 k and 400 k, reading "...UN A O"
    #    in all three. So the body is projected from the drawn elevation
    #    instead, which lands every painted detail the art has: bonnet louvres,
    #    cab roundel, mudguards, the lot.
    #
    # 2. The elevation cannot supply the sign on BOTH flanks. Mirroring the
    #    plate to face the other way mirrors its lettering with it -- they are
    #    the same operation, which is why four combinations of plate and UV
    #    collapsed into two states, aligned-and-mirrored or readable-and-
    #    misaligned. A real signwritten truck reads forward on both sides
    #    because it is PAINTED, not reflected, and no flip of one image can
    #    imitate that.
    #
    # So: projection carries the body, and the box side keeps the composed
    # plate, which is already correct on both flanks because it is drawn per
    # side rather than mirrored. The plate is assigned last and wins.
    def _plate(name, filename, rough):
        img = bpy.data.images.load(os.path.join(TEX_DIR, filename),
                                   check_existing=True)
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.extension = 'EXTEND'
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = 0.0
        return mat

    me.materials.clear()
    me.materials.append(_plate("piano_truck_side", "T_piano_truck_side.png", 0.44))
    me.materials.append(_plate("piano_truck_rear", "T_piano_truck_rear.png", 0.44))
    me.materials.append(_plate("piano_truck_paint", "T_piano_truck_paint.png", 0.52))
    me.materials.append(_plate("piano_truck_panel", "T_piano_truck_panel.png", 0.38))
    MAT_SIDE, MAT_REAR, MAT_PAINT, MAT_PANEL = 0, 1, 2, 3

    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.active
    lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
    hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
    span = [max(1e-6, hi[i] - lo[i]) for i in range(3)]
    # The box side, measured off the mesh: this is the plate's territory.
    px0, px1 = -0.90, 2.70
    pz0, pz1 = 0.80, 2.05
    counts = {MAT_SIDE: 0, MAT_REAR: 0, MAT_PAINT: 0, MAT_PANEL: 0}
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        c = f.calc_center_median()
        sideways = ay >= ax and ay >= az
        if sideways and px0 <= c.x <= px1 and pz0 <= c.z <= pz1:
            f.material_index = MAT_PANEL
            for loop in f.loops:
                co = loop.vert.co
                u = (co.x - px0) / (px1 - px0)
                v = (co.z - pz0) / (pz1 - pz0)
                if n.y > 0.0:
                    u = 1.0 - u
                loop[uv].uv = (min(1.0, max(0.0, u)), min(1.0, max(0.0, v)))
        elif sideways:
            f.material_index = MAT_SIDE
            for loop in f.loops:
                co = loop.vert.co
                # build_piano_truck_projection.py mirrors the plate at source,
                # so its nose is at u=0 and the mesh's nose is at -X: the two
                # run the same way and u = t aligns them. Whichever flank ends
                # up with mirrored body detail no longer matters much, because
                # the one thing that must read -- the sign -- is the plate
                # above, drawn per side rather than reflected.
                u = (co.x - lo[0]) / span[0]
                if n.y > 0.0:
                    u = 1.0 - u
                v = (co.z - lo[2]) / span[2]
                loop[uv].uv = (min(1.0, max(0.0, u)), min(1.0, max(0.0, v)))
        elif ax >= az and n.x > 0.0:
            f.material_index = MAT_REAR
            for loop in f.loops:
                co = loop.vert.co
                u = (co.y - lo[1]) / span[1]
                v = (co.z - lo[2]) / span[2]
                loop[uv].uv = (min(1.0, max(0.0, u)), min(1.0, max(0.0, v)))
        else:
            f.material_index = MAT_PAINT
        counts[f.material_index] += 1
    bm.to_mesh(me)
    bm.free()
    me.update()
    me.validate(verbose=False)
    log("projected: %d side, %d rear, %d paint, %d sign plate"
        % (counts[MAT_SIDE], counts[MAT_REAR], counts[MAT_PAINT],
           counts[MAT_PANEL]))

    # --- textures ---------------------------------------------------------
    os.makedirs(TEX_DIR, exist_ok=True)
    written = []
    for img in list(bpy.data.images):
        if img.name == "Render Result" or img.size[0] == 0:
            continue
        # The panel is authored at 3.43:1 by build_piano_truck_panel.py and is
        # already on disk. This pass resizes everything it finds to a SQUARE,
        # which silently crushed the plate and re-exported it under a
        # generated name.
        if img.name.startswith("T_piano_truck_"):
            continue
        target = ALBEDO_PX if max(img.size) >= 8192 else COMPANION_PX
        if max(img.size) > target:
            img.scale(target, target)
        suffix = {0: "albedo", 1: "rough", 2: "metal"}.get(
            len(written), "map%d" % len(written))
        path = os.path.join(TEX_DIR, "T_%s_%s.png" % (NAME, suffix))
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        written.append(os.path.basename(path))
        log("texture %s -> %s at %dpx" % (img.name, os.path.basename(path),
                                          target))

    # --- export -----------------------------------------------------------
    os.makedirs(OUT_DIR, exist_ok=True)
    for o in bpy.data.objects:
        o.select_set(o is ob)
    bpy.context.view_layer.objects.active = ob
    out = os.path.join(OUT_DIR, "%s.glb" % NAME)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True)
    log("exported %s (%.2f MB)" % (out, os.path.getsize(out) / 1048576.0))
    log("textures: %s" % ", ".join(written))


main()
