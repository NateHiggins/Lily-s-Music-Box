"""The residents' memory-art frames, authored in Blender (v1r_found_art_20261109:
the residents' memory art only).

V1's CharacterMemoryArt hung a 0.72 m square picture in a four-bar BoxMesh
frame (0.045 m bars), or stood a 0.34 m one on a table on a bar foot. The
pictures themselves were quadrants of five generated image atlases; those are
not carried into V2 (RUL-007, RUL-008), so each frame holds a blank mount.

  MemoryWall   the hung frame: four mitred rails of a moulded section whose
               back rim lies on the wall, and the mount card in its rebate.
  MemoryTable  the standing frame: the same construction at V1's tabletop
               size, leaning on a hinged back strut that reaches the surface.

Runtime frame: +X right, +Y up, +Z out of the picture. The hung frame's origin
is the picture's centre on the wall plane (z = 0 is the wall). The standing
frame's origin is the centre of its footprint on the supporting surface.

Deterministic: no randomness.

  blender -b --python-exit-code 1 -P art/blender/scripts/build_memory_art_frames.py -- <review_dir>
Writes game/assets/props/memory_art_frames.glb, art/blender/memory_art_frames.blend
and review renders under <review_dir>.
"""
import bpy, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import v1r_small_stock as kit

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else ROOT / "tmp/memory_art_frames"
(OUT / "review").mkdir(parents=True, exist_ok=True)
LEAN = math.radians(-12.0)  # the standing frame leans back on its strut


def moulding(s, half, border, depth, m=None):
    """Four mitred rails round a square sight of half-size `half`. The section
    runs (distance from centre, height off the back): a rebate at the sight
    edge, a cove up to the crest, a bead at the outer edge, a flat back."""
    b, d = border, depth
    profile = [(half, d * 0.14), (half, d * 0.52), (half + b * 0.28, d * 0.68), (half + b * 0.55, d),
               (half + b * 0.84, d), (half + b, d * 0.76), (half + b, 0.0), (half + b * 0.20, 0.0)]
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    n = len(profile)
    for side in range(4):
        a, c = corners[side], corners[(side + 1) % 4]
        along = (c[0] - a[0], c[1] - a[1], 0)
        for i in range(n):
            (r0, z0), (r1, z1) = profile[i], profile[(i + 1) % n]
            s.poly([(a[0] * r0, a[1] * r0, z0), (c[0] * r0, c[1] * r0, z0),
                    (c[0] * r1, c[1] * r1, z1), (a[0] * r1, a[1] * r1, z1)], grain=along, m=m)


def mount(s, half, z, m=None):
    r = half + 0.004
    s.poly([(-r, -r, z), (r, -r, z), (r, r, z), (-r, r, z)], grain=(1, 0, 0), m=m)


def wall_frame():
    frame, card = kit.Stock(), kit.Stock()
    moulding(frame, 0.36, 0.045, 0.045)
    # The hanging plate: a brass tongue from the top rail's back up the wall.
    plate = kit.Stock()
    plate.box((0.0, 0.36 + 0.045 + 0.012, 0.0015), (0.030, 0.036, 0.003))
    plate.box((0.0, 0.36 + 0.045 + 0.020, 0.0045), (0.008, 0.008, 0.004))
    mount(card, 0.36, 0.045 * 0.14 + 0.0005)
    return [frame.finish("MemoryWall__Moulding_ON_wood", grain_v=True), card.finish("MemoryWall__Mount_ON_paper", outward=False),
            plate.finish("MemoryWall__Hanger_ON_brass_dull")]


def table_frame():
    half, border, depth = 0.17, 0.025, 0.028
    # Stand the square on its bottom rail, then lean it back about that edge.
    up = Matrix.Rotation(LEAN, 4, "X") @ Matrix.Translation((0, half + border, 0))
    frame, card = kit.Stock(), kit.Stock()
    moulding(frame, half, border, depth, m=up)
    mount(card, half, depth * 0.14 + 0.0005, m=up)
    # The back strut: hinged two thirds up the back, foot on the surface behind.
    top = up @ Vector((0, half * 0.38, 0.0))
    foot = Vector((0, 0.0, top.z - 0.105))
    axis = foot - top
    rot = Vector((0, 1, 0)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    frame.box((0, 0, 0), (0.07, axis.length, 0.006), grain=(0, 1, 0), m=Matrix.Translation((top + foot) / 2) @ rot)
    centre = Vector((0, 0, foot.z / 2))  # footprint centre: between the rail and the strut foot
    return [frame.finish("MemoryTable__Moulding_ON_wood", pivot=centre, grain_v=True),
            card.finish("MemoryTable__Mount_ON_paper", pivot=centre, outward=False)]


kit.reset()
objs = wall_frame() + table_frame()
for o in objs:
    key = o.name.split("_ON_")[1]
    kit.preview_material(o, key, {"wood": (0.17, 0.10, 0.055), "paper": (0.86, 0.82, 0.70), "brass_dull": (0.52, 0.42, 0.22)}[key])
    print("[MEMORY ART FRAMES] %s: %d triangles" % (o.name, kit.tri_count(o)))
    lo = [min((o.matrix_world @ v.co)[i] for v in o.data.vertices) for i in range(3)]
    hi = [max((o.matrix_world @ v.co)[i] for v in o.data.vertices) for i in range(3)]
    print("   bounds (Blender) %s .. %s" % ([round(v, 4) for v in lo], [round(v, 4) for v in hi]))
(ROOT / "game/assets/props").mkdir(parents=True, exist_ok=True)
rest = [o.location.copy() for o in objs]
for o in objs[3:]:
    o.location.x += 0.75
    o.location.z -= 0.40
kit.review(OUT / "review" / "frames_front.png", objs, (0.55, -2.0, 0.25), (0.3, 0, -0.05), lens=50)
kit.review(OUT / "review" / "frames_oblique.png", objs, (1.9, -1.1, 0.3), (0.35, 0, -0.15), lens=60, floor_z=-0.40)
for o, at in zip(objs, rest):
    o.location = at
bpy.context.view_layer.update()
kit.export(objs, ROOT / "game/assets/props/memory_art_frames.glb", ROOT / "art/blender/memory_art_frames.blend")
print("[MEMORY ART FRAMES] %d triangles in all" % sum(kit.tri_count(o) for o in objs))
