"""TB-13 — DOES THE CREATURE HOLD TOGETHER WHEN IT MOVES?

A grey render in rest pose cannot tell a creature from a pile of parts
resting in the same place. This poses the rig hard and MEASURES, for every
rigid rider, how far it sits from the flesh before and after.

A rider correctly bound to the bone under it keeps its distance to the
surface exactly. One bound to the wrong bone -- or to none -- drifts, and
past a few millimetres it is visibly floating in mid-air.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        art/blender/dream_tentacle.blend \
        -P art/blender/scripts/check_dream_tentacle_bind.py

Exit code is the number of riders that drift past TOLERANCE_MM.
"""

import bpy
import math
import sys
from mathutils import Vector

TOLERANCE_MM = 4.0
CAGE = "TENTACLE_FLESH"


def evaluated(obj, deps):
    """The object as the modifier stack actually leaves it."""
    return obj.evaluated_get(deps)


def median_surface_gap(cage_obj, obj, deps, limit=160):
    """The median distance from this rider's own vertices to the flesh.

    Not the centroid: a dendrite tree or a membrane skirt spans a big region,
    so its centroid sits tens of millimetres off a curved surface and MOVES
    when the limb bends even though every vertex is welded correctly. That
    measured the shape, not the binding, and reported two false failures.
    A median over the rider's own vertices measures the binding.
    """
    ev = obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    if not mesh.vertices:
        ev.to_mesh_clear()
        return None
    cage_ev = cage_obj.evaluated_get(deps)
    cage_inv = cage_ev.matrix_world.inverted()
    step = max(1, len(mesh.vertices) // limit)
    gaps = []
    for i in range(0, len(mesh.vertices), step):
        world = ev.matrix_world @ mesh.vertices[i].co
        ok, loc, _n, _idx = cage_ev.closest_point_on_mesh(cage_inv @ world)
        if ok:
            gaps.append(((cage_ev.matrix_world @ loc) - world).length)
    ev.to_mesh_clear()
    if not gaps:
        return None
    gaps.sort()
    return gaps[len(gaps) // 2]


def centroid(obj, deps):
    ev = evaluated(obj, deps)
    mesh = ev.to_mesh()
    if not mesh.vertices:
        ev.to_mesh_clear()
        return None
    acc = Vector((0.0, 0.0, 0.0))
    for v in mesh.vertices:
        acc += v.co
    acc /= len(mesh.vertices)
    out = ev.matrix_world @ acc
    ev.to_mesh_clear()
    return out


def surface_distance(cage_obj, deps, point):
    """Distance from a point to the deformed flesh."""
    ev = evaluated(cage_obj, deps)
    ok, loc, _nrm, _idx = ev.closest_point_on_mesh(ev.matrix_world.inverted() @ point)
    if not ok:
        return None
    return ((ev.matrix_world @ loc) - point).length


def pose_bend(arm, amount):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    n = 0
    for pb in arm.pose.bones:
        if not pb.name.startswith("DEF_"):
            continue
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (math.radians(3.4 * amount), 0.0,
                             math.radians((2.6 if n % 8 < 4 else -3.1) * amount))
        n += 1
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    return n


def measure(cage_obj, riders):
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    out = {}
    for obj in riders:
        d = median_surface_gap(cage_obj, obj, deps)
        if d is not None:
            out[obj.name] = d
    return out


def main():
    cage_obj = bpy.data.objects.get(CAGE)
    if cage_obj is None:
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        cage_obj = max(meshes, key=lambda o: len(o.data.vertices))
        print("[bind] cage by vertex count: %s" % cage_obj.name)
    arm = bpy.data.objects.get("TENTACLE_RIG")
    if arm is None:
        print("[bind] FAIL: no rig")
        sys.exit(1)
    riders = [o for o in bpy.data.objects
              if o.type == "MESH" and o is not cage_obj]
    unbound = [o.name for o in riders if not o.vertex_groups]
    print("[bind] %d riders, %d with no vertex group" % (len(riders), len(unbound)))
    for name in unbound[:10]:
        print("[bind]   UNBOUND %s" % name)
    rest = measure(cage_obj, riders)
    n = pose_bend(arm, 1.0)
    bent = measure(cage_obj, riders)
    print("[bind] posed %d deform bones" % n)
    drifted = []
    for name, d0 in rest.items():
        d1 = bent.get(name)
        if d1 is None:
            continue
        drift_mm = abs(d1 - d0) * 1000.0
        if drift_mm > TOLERANCE_MM:
            drifted.append((drift_mm, name, d0 * 1000.0, d1 * 1000.0))
    drifted.sort(reverse=True)
    for drift_mm, name, a, b in drifted[:20]:
        print("[bind]   DRIFT %6.1f mm  %-28s  %.1f -> %.1f mm from flesh"
              % (drift_mm, name, a, b))
    print("[bind] %d/%d riders drift past %.1f mm"
          % (len(drifted), len(rest), TOLERANCE_MM))
    print("[bind] %s" % ("PASS" if not drifted and not unbound else "FAIL"))
    sys.exit(len(drifted) + len(unbound))


if __name__ == "__main__":
    main()
