"""Survey the near city's kerbs for street furniture (Lily's ruling city_complete_next_20261117).

Reads art/blender/city_streets.blend, casts a ray down every GRID metres over the near city and classifies
what is underfoot by the street part's finish (walk, curb, cap, road). Writes the kerb runs: chains of
points on the walk, KERB_SET metres in from the curb, in the Godot world frame (x = x_b, z = -y_b - 9.795,
y = the walk's height), each with the outward direction toward the road.

    blender -b art/blender/city_streets.blend -P art/blender/scripts/survey_city_near_kerbs.py

Output: art/blender/data/city_near_furniture/kerbs.json. Read-only on the blend.
"""
import json
import math
import os

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "blender", "data", "city_near_furniture", "kerbs.json")
GRID = 0.25
KERB_SET = 0.55        # metres in from the curb's road edge, onto the walk
FRAME_Z = 9.795        # Godot world z = -y_b - FRAME_Z


def finish(name):
    return name.split("__")[-1] if "__" in name else ""


def main():
    tris, kinds, heights = [], [], []
    verts = []
    for o in bpy.data.objects:
        if o.type != "MESH" or "_L0__" not in o.name or finish(o.name) not in ("walk", "curb", "cap", "road"):
            continue
        mw = o.matrix_world
        base = len(verts)
        verts.extend(mw @ v.co for v in o.data.vertices)
        o.data.calc_loop_triangles()
        for t in o.data.loop_triangles:
            tris.append([base + i for i in t.vertices])
            kinds.append(finish(o.name))
    tree = BVHTree.FromPolygons(verts, tris)
    xs = [v.x for v in verts]
    ys = [v.y for v in verts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    nx, ny = int((x1 - x0) / GRID) + 1, int((y1 - y0) / GRID) + 1
    code = {"walk": 1, "curb": 2, "cap": 2, "road": 3}
    grid = bytearray(nx * ny)
    top = {}
    for j in range(ny):
        y = y0 + j * GRID
        for i in range(nx):
            x = x0 + i * GRID
            hit = tree.ray_cast(Vector((x, y, 50.0)), Vector((0, 0, -1)), 100.0)
            if hit[0] is None:
                continue
            grid[j * nx + i] = code[kinds[hit[2]]]
            if code[kinds[hit[2]]] == 1:
                top[(i, j)] = hit[0].z

    def at(i, j):
        return grid[j * nx + i] if 0 <= i < nx and 0 <= j < ny else 0

    # A kerb point: walk, KERB_SET in from road across a curb. Look along the four axes for road within reach.
    reach = int(round((KERB_SET + 0.5) / GRID))
    inset = int(round(KERB_SET / GRID))
    points = []
    for (i, j), z in top.items():
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            # Exactly `inset` cells of walk/curb, then road within one more cell or two: the road-facing edge.
            if at(i + di * inset, j + dj * inset) in (2, 3) and all(at(i + di * k, j + dj * k) == 1 for k in range(1, inset - 1)) \
                    and any(at(i + di * k, j + dj * k) == 3 for k in range(inset, reach + 2)):
                points.append((i, j, di, dj, z))
                break
    # Chain points into runs: neighbours within 1.5 cells with the same outward direction.
    by = {(p[0], p[1]): p for p in points}
    seen = set()
    runs = []
    for p in points:
        if (p[0], p[1]) in seen:
            continue
        stack, run = [p], []
        seen.add((p[0], p[1]))
        while stack:
            q = stack.pop()
            run.append(q)
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    n = by.get((q[0] + a, q[1] + b))
                    if n and (n[0], n[1]) not in seen and (n[2], n[3]) == (q[2], q[3]):
                        seen.add((n[0], n[1]))
                        stack.append(n)
        if len(run) * GRID < 3.0:
            continue
        di, dj = run[0][2], run[0][3]
        # Order along the kerb (perpendicular to the outward axis).
        run.sort(key=lambda q: q[1] if di != 0 else q[0])
        world = [[round(x0 + q[0] * GRID, 3), round(q[4], 3), round(-(y0 + q[1] * GRID) - FRAME_Z, 3)] for q in run]
        # Outward (toward the road) in Godot frame: x stays, y_b flips to -z.
        runs.append({"out": [di, -dj], "points": world[::2]})
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump({"evidence_class": "INERT", "frame": "WORLD", "grid_m": GRID, "kerb_set_m": KERB_SET, "runs": runs},
              open(OUT, "w"), separators=(",", ":"))
    print("KERB SURVEY runs", len(runs), "points", sum(len(r["points"]) for r in runs), "grid", nx, ny)


main()
