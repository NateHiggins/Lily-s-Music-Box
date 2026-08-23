"""H1 — BAKE THE HERO'S ANATOMY (§19 of the menagerie brief).

The hero had no baked maps at all. Everything visible was procedural from the
shared material stack — which is exactly what a generated margin palp also
has, so the hero could not be visually superior to one (ecology §36). The
owner put it plainly: "the texture is not great".

This bakes the three things a shader CANNOT know about a body, because they
are facts about its geometry rather than about a noise field:

    R  AMBIENT OCCLUSION   where light does not reach: under gold plates,
                           inside the orbit, in every fold and socket.
    G  CURVATURE           convex ridges vs concave creases, from pointiness.
                           Drives wear on the crests and wetness in the pits.
    B  THICKNESS           how much meat is behind this point, measured by
                           occlusion sampled INSIDE the mesh. Drives real
                           subsurface scattering instead of a guess from a
                           radius.

All three land in one RGB image, so the shader pays for one texture fetch.
Only the flesh cage is baked: it is the only mesh carrying UVs, and it is
most of what the player sees.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        art/blender/dream_tentacle.blend \
        -P art/blender/scripts/bake_dream_tentacle.py
"""

import bpy
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(REPO, "game", "assets", "dream", "tentacle",
                   "T_dream_hero_anatomy.png")
SIZE = int(os.environ.get("BAKE_SIZE", "1024"))
SAMPLES = int(os.environ.get("BAKE_SAMPLES", "24"))
CAGE = "TENTACLE_BODY_CAGE"


def log(msg):
    print("[bake] %s" % msg)


def build_bake_material():
    """One emission carrying AO, curvature and thickness in R, G and B.

    Baking three passes into three images would be three bakes and three
    fetches. The channels are independent, so they can ride together.
    """
    mat = bpy.data.materials.new("HERO_BAKE")
    mat.use_nodes = True
    nt = mat.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emit = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])

    combine = nt.nodes.new("ShaderNodeCombineColor")
    nt.links.new(combine.outputs["Color"], emit.inputs["Color"])

    # R: ambient occlusion, outward.
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = int(os.environ.get("BAKE_AO_SAMPLES", "64"))
    # Six centimetres found nothing: a mostly convex tube does not occlude
    # itself at close range, and the isolated bake came back 0.88-1.00, mean
    # 0.996 -- present but carrying nothing. The concavities that matter here
    # are large: the orbit bowl, the compressed neck, the ribbon pinch, the
    # membrane socket. So it samples at the scale those actually are.
    ao.inputs["Distance"].default_value = float(os.environ.get("BAKE_AO_DIST", "0.30"))
    nt.links.new(ao.outputs["AO"], combine.inputs[0])

    # G: curvature, from geometry pointiness. Pointiness sits around 0.5 for
    # flat, so it is remapped to use the range.
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    curve_map = nt.nodes.new("ShaderNodeMapRange")
    curve_map.inputs["From Min"].default_value = 0.42
    curve_map.inputs["From Max"].default_value = 0.58
    nt.links.new(geo.outputs["Pointiness"], curve_map.inputs["Value"])
    nt.links.new(curve_map.outputs["Result"], combine.inputs[1])

    # B: thickness. Occlusion sampled INSIDE the surface: a thin lid occludes
    # little, the muscular root occludes almost everything.
    thick = nt.nodes.new("ShaderNodeAmbientOcclusion")
    thick.samples = int(os.environ.get("BAKE_AO_SAMPLES", "64"))
    thick.inside = True
    thick.inputs["Distance"].default_value = 0.09
    invert = nt.nodes.new("ShaderNodeInvert")
    nt.links.new(thick.outputs["AO"], invert.inputs["Color"])
    nt.links.new(invert.outputs["Color"], combine.inputs[2])
    return mat


def main():
    cage = bpy.data.objects.get(CAGE)
    if cage is None:
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        if not meshes:
            log("FAIL: no meshes")
            sys.exit(1)
        cage = max(meshes, key=lambda o: len(o.data.vertices))
        log("cage by vertex count: %s" % cage.name)
    if not cage.data.uv_layers:
        log("FAIL: the cage has no UVs — nothing to bake into")
        sys.exit(1)
    # Bake the authored strip, not the mask UVs.
    for i, layer in enumerate(cage.data.uv_layers):
        if layer.name == "UVMap":
            cage.data.uv_layers.active_index = i
    log("baking into UV layer '%s'" % cage.data.uv_layers.active.name)

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = False
    try:
        scene.cycles.device = "CPU"
    except Exception:
        pass

    image = bpy.data.images.new("HERO_ANATOMY", width=SIZE, height=SIZE,
                                alpha=False, float_buffer=False)
    mat = build_bake_material()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image
    mat.node_tree.nodes.active = tex

    saved = [m.material for m in cage.data.materials] if cage.data.materials else []
    cage.data.materials.clear()
    cage.data.materials.append(mat)

    # THE RIDERS STAY IN, and it took two wrong turns to be sure of that.
    #
    # The first bake came out in hard blocks -- whole patches of AO at zero --
    # and raising samples eightfold changed nothing, which is what says a
    # result is structural rather than noisy. Hiding the riders cleaned it up
    # and produced AO of 0.88 to 1.00, mean 0.996: a channel carrying nothing,
    # because a mostly convex limb does not occlude itself. Widening the
    # sampling distance fivefold moved that mean by 0.002.
    #
    # Which settles it. This body's occlusion IS its riders. Those blocks are
    # rectangular in UV space because a gold plate spans a few ring segments
    # and a few rings, and a plate seated into flesh genuinely does black out
    # what is under it. The map only looked broken because I was expecting
    # soft AO from a shape that has none. BAKE_ISOLATE=1 keeps the old
    # behaviour for comparison.
    hidden = []
    if os.environ.get("BAKE_ISOLATE") == "1":
        for obj in bpy.data.objects:
            if obj.type == "MESH" and obj is not cage:
                hidden.append((obj, obj.hide_render))
                obj.hide_render = True
        log("isolated the cage: %d riders hidden" % len(hidden))

    bpy.ops.object.select_all(action="DESELECT")
    cage.select_set(True)
    bpy.context.view_layer.objects.active = cage

    scene.render.bake.use_selected_to_active = False
    scene.render.bake.margin = 8
    log("baking %dx%d at %d samples — this is the slow part" % (SIZE, SIZE, SAMPLES))
    bpy.ops.object.bake(type="EMIT")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    image.filepath_raw = OUT
    image.file_format = "PNG"
    image.save()
    log("wrote %s" % OUT)

    # Report what actually landed, because an all-black bake saves happily.
    px = list(image.pixels)
    n = len(px) // 4
    lo = [9.0, 9.0, 9.0]
    hi = [-9.0, -9.0, -9.0]
    acc = [0.0, 0.0, 0.0]
    step = max(1, n // 20000)
    counted = 0
    for i in range(0, n, step):
        for c in range(3):
            v = px[i * 4 + c]
            lo[c] = min(lo[c], v)
            hi[c] = max(hi[c], v)
            acc[c] += v
        counted += 1
    names = ["AO", "curvature", "thickness"]
    ok = True
    for c in range(3):
        span = hi[c] - lo[c]
        log("  %-10s %.3f .. %.3f  mean %.3f  %s"
            % (names[c], lo[c], hi[c], acc[c] / max(1, counted),
               "OK" if span > 0.05 else "FLAT — carries nothing"))
        if span <= 0.05:
            ok = False
    log("PASS" if ok else "FAIL: a channel baked flat")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
