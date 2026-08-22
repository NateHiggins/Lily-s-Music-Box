"""TB-15 / §23 — ANIMATION CLEARANCE, MEASURED.

    "Before finishing detail, test S curve, hard distal curl, figure-eight
     contact, 90 degree bend, 180 degree tip curl, axial twist, sucker-side
     rotation, root extension, flinch coil. Watch for gold plates colliding,
     crystals entering flesh, eye deformation, cilia penetrating the cornea,
     sucker overlap, membrane collapse. Fix before final polish."

Eyeballing nine poses across ninety-five parts is not a review, it is a
hope. This drives the rig through the poses and measures the two failures
that actually matter:

  SINKING     a rider's vertices ending up INSIDE the flesh -- the crystal
              entering flesh, the sucker swallowed by its own bulge.
  COLLISION   two riders from different systems overlapping in space --
              gold plates colliding, sucker overlap.

Rest pose is measured first and every pose is judged against it, because a
piece that is seated 3 mm into the flesh by design has not failed; a piece
that sinks 3 mm FURTHER when the limb curls has.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender" -b \
        art/blender/dream_tentacle.blend \
        -P art/blender/scripts/check_dream_tentacle_clearance.py

Exit code is the number of (pose, part) failures.
"""

import bpy
import math
import os
import sys
from mathutils import Vector

SINK_TOLERANCE_MM = 6.0
COLLIDE_TOLERANCE_MM = 1.5
SAMPLES_PER_RIDER = 48

# name -> (per-bone x rot, per-bone z rot, region weighting)
# region: "all", "distal" (last third), "tip" (last quarter), "proximal".
POSES = [
    ("s_curve", 3.4, 2.8, "all", True),
    ("bend_90", 7.0, 0.0, "proximal", False),
    ("distal_curl", 6.5, 1.2, "distal", False),
    ("tip_curl_180", 11.0, 0.0, "tip", False),
    ("axial_twist", 0.0, 0.0, "all", False),      # roll only, applied below
    ("flinch_coil", 5.2, 4.4, "all", False),
    ("figure_eight", 4.0, 4.0, "all", True),
]


def deform_bones(arm):
    bones = [pb for pb in arm.pose.bones if pb.name.startswith("DEF_")]
    bones.sort(key=lambda pb: arm.data.bones[pb.name].head_local.y)
    return bones


def clear_pose(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def apply_pose(arm, name, x_deg, z_deg, region, alternate):
    clear_pose(arm)
    bones = deform_bones(arm)
    n = len(bones)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for i, pb in enumerate(bones):
        t = i / float(max(1, n - 1))
        if region == "distal":
            gain = max(0.0, (t - 0.62) / 0.38)
        elif region == "tip":
            gain = max(0.0, (t - 0.75) / 0.25)
        elif region == "proximal":
            gain = max(0.0, 1.0 - t / 0.45)
        else:
            gain = 1.0
        z = z_deg
        if alternate:
            z = z_deg if (i % 8) < 4 else -z_deg * 1.15
        roll = math.radians(6.0) * gain if name == "axial_twist" else 0.0
        pb.rotation_euler = (math.radians(x_deg * gain), roll,
                             math.radians(z * gain))
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()


def sampled_points(obj, deps):
    ev = obj.evaluated_get(deps)
    mesh = ev.to_mesh()
    if not mesh.vertices:
        ev.to_mesh_clear()
        return []
    step = max(1, len(mesh.vertices) // SAMPLES_PER_RIDER)
    pts = [ev.matrix_world @ mesh.vertices[i].co
           for i in range(0, len(mesh.vertices), step)]
    ev.to_mesh_clear()
    return pts


def deepest_inside(cage_ev, cage_inv, pts):
    """How far the deepest sampled vertex sits INSIDE the flesh, in metres."""
    worst = 0.0
    for p in pts:
        ok, loc, nrm, _idx = cage_ev.closest_point_on_mesh(cage_inv @ p)
        if not ok:
            continue
        local = cage_inv @ p
        if (local - loc).dot(nrm) < 0.0:
            worst = max(worst, (local - loc).length)
    return worst


def system_of(name):
    for tag in ("EYE", "LID", "CILIUM", "SUCKER", "GOLD", "CRYSTAL",
                "MEMBRANE", "DENDRITE"):
        if name.upper().startswith(tag) or tag in name.upper():
            return tag
    return "OTHER"


def bounds(pts):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for p in pts:
        for i in range(3):
            lo[i] = min(lo[i], p[i])
            hi[i] = max(hi[i], p[i])
    return lo, hi


def collisions(points_by_name):
    """Pairs from DIFFERENT systems whose sampled points interpenetrate.

    Cheap on purpose: bounding boxes first, and only then point distances.
    A pair is reported when points from two systems come closer than the
    tolerance, which for hard mineral pieces means they are inside one
    another.
    """
    names = list(points_by_name.keys())
    boxes = {n: bounds(points_by_name[n]) for n in names}
    out = []
    tol = COLLIDE_TOLERANCE_MM / 1000.0
    for i in range(len(names)):
        for j in range(i + 1, len(names)):
            a, b = names[i], names[j]
            if system_of(a) == system_of(b):
                continue
            (alo, ahi), (blo, bhi) = boxes[a], boxes[b]
            if (ahi.x < blo.x - tol or bhi.x < alo.x - tol
                    or ahi.y < blo.y - tol or bhi.y < alo.y - tol
                    or ahi.z < blo.z - tol or bhi.z < alo.z - tol):
                continue
            best = 1e9
            for p in points_by_name[a]:
                for q in points_by_name[b]:
                    d = (p - q).length
                    if d < best:
                        best = d
            if best < tol:
                out.append((best * 1000.0, a, b))
    return out


def main():
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    cage = max(meshes, key=lambda o: len(o.data.vertices))
    arm = bpy.data.objects.get("TENTACLE_RIG")
    if arm is None:
        print("[clear] FAIL: no rig")
        sys.exit(1)
    riders = [o for o in meshes if o is not cage]
    print("[clear] cage %s, %d riders" % (cage.name, len(riders)))
    # NORMALS FIRST. Every measurement below asks "is this point inside the
    # flesh", which is decided by the sign of a surface normal -- so if the
    # cage is wound inside-out the whole report is exactly backwards, and
    # says PASS while doing it. It was. Godot culls back faces, so this is
    # also a shipping bug in its own right, not merely a test dependency.
    cage.data.calc_loop_triangles()
    vol = 0.0
    for tri in cage.data.loop_triangles:
        a, b, c = [cage.data.vertices[i].co for i in tri.vertices]
        vol += a.dot(b.cross(c)) / 6.0
    if vol <= 0.0:
        print("[clear] FAIL: cage normals point INWARD (signed volume %.6f)" % vol)
        sys.exit(1)
    print("[clear] cage normals outward (signed volume %.6f)" % vol)

    def snapshot():
        deps = bpy.context.evaluated_depsgraph_get()
        deps.update()
        cage_ev = cage.evaluated_get(deps)
        cage_inv = cage_ev.matrix_world.inverted()
        pts = {}
        sink = {}
        for obj in riders:
            p = sampled_points(obj, deps)
            if not p:
                continue
            pts[obj.name] = p
            sink[obj.name] = deepest_inside(cage_ev, cage_inv, p)
        return pts, sink

    clear_pose(arm)
    rest_pts, rest_sink = snapshot()
    # SELF-TEST. A clean pass on the first run is when to doubt the
    # instrument, not the model. CLEAR_SELFTEST=1 shoves one rider 20 mm
    # toward the limb's axis AFTER the rest baseline is taken; if the run
    # still says PASS, the check is measuring nothing and its silence means
    # nothing either.
    if os.environ.get("CLEAR_SELFTEST") == "1":
        victim = next((o for o in riders if o.name.startswith("CRYSTAL")), riders[0])
        deps0 = bpy.context.evaluated_depsgraph_get()
        deps0.update()
        pts0 = sampled_points(victim, deps0)
        here = sum(pts0, Vector((0.0, 0.0, 0.0))) / max(1, len(pts0))
        # Put its centroid ON the limb axis: unambiguously inside the flesh,
        # whatever the piece's own stand-off happens to be.
        victim.location = victim.location + Vector((-here.x, 0.0, -here.z))
        bpy.context.view_layer.update()
        print("[clear] SELF-TEST: sank %s by 20 mm after the baseline" % victim.name)

    # The aperture's rest gap, so a collar seated 2 mm off the flesh by
    # design is not read as torn.
    membrane_rest_gap = {}
    _deps = bpy.context.evaluated_depsgraph_get()
    _cage_ev = cage.evaluated_get(_deps)
    _cage_inv = _cage_ev.matrix_world.inverted()
    for obj in riders:
        if system_of(obj.name) != "MEMBRANE" or obj.name not in rest_pts:
            continue
        radii = [(math.hypot(p.x, p.z), p) for p in rest_pts[obj.name]]
        radii.sort(key=lambda rp: rp[0])
        g = 0.0
        for _r, p in radii[:max(3, len(radii) // 6)]:
            ok, loc, _n, _i = _cage_ev.closest_point_on_mesh(_cage_inv @ p)
            if ok:
                g = max(g, ((_cage_ev.matrix_world @ loc) - p).length)
        membrane_rest_gap[obj.name] = g
        print("[clear] aperture %s rests %.1f mm from the flesh" % (obj.name, g * 1000.0))

    rest_hits = collisions(rest_pts)
    print("[clear] rest: %d pre-existing contacts" % len(rest_hits))
    rest_pairs = set((a, b) for _d, a, b in rest_hits)

    failures = 0
    for (name, x_deg, z_deg, region, alt) in POSES:
        apply_pose(arm, name, x_deg, z_deg, region, alt)
        pts, sink = snapshot()
        sank = []
        for rname, d in sink.items():
            # THE MEMBRANE IS NOT MEASURED THIS WAY, and four attempted fixes
            # went by before I accepted it. It reported exactly 112 mm of
            # "sinking" in every pose that bends sideways, and did not move by
            # more than 0.3 mm when the membrane was re-bound three different
            # ways or when the root was given a rotation limit. A number that
            # insensitive to the thing it claims to measure is not measuring
            # it.
            #
            # What it was actually seeing: a 1.66 m limb curled into an S
            # comes back down and touches its own collar. That is CONTACT,
            # and for the one part that wraps the limb, "vertices inside the
            # flesh" says nothing about collapse. The membrane gets its own
            # metric below.
            if system_of(rname) == "MEMBRANE":
                continue
            extra = (d - rest_sink.get(rname, 0.0)) * 1000.0
            if extra > SINK_TOLERANCE_MM:
                sank.append((extra, rname))
        sank.sort(reverse=True)
        # MEMBRANE COLLAPSE, measured properly: the aperture's INNER edge must
        # stay against the flesh. If it tears away, a hole opens around the
        # limb and the creature stops reading as coming through the surface.
        for obj in riders:
            if system_of(obj.name) != "MEMBRANE" or obj.name not in pts:
                continue
            deps2 = bpy.context.evaluated_depsgraph_get()
            cage_ev = cage.evaluated_get(deps2)
            cage_inv = cage_ev.matrix_world.inverted()
            radii = [(math.hypot(p.x, p.z), p) for p in pts[obj.name]]
            radii.sort(key=lambda rp: rp[0])
            inner = [p for _r, p in radii[:max(3, len(radii) // 6)]]
            gap = 0.0
            for p in inner:
                ok, loc, _n, _i = cage_ev.closest_point_on_mesh(cage_inv @ p)
                if ok:
                    gap = max(gap, ((cage_ev.matrix_world @ loc) - p).length)
            gap_mm = gap * 1000.0
            base_mm = membrane_rest_gap.get(obj.name, 0.0) * 1000.0
            if gap_mm - base_mm > SINK_TOLERANCE_MM:
                print("[clear]   %-14s APERTURE TEARS %5.1f mm from the flesh  %s"
                      % (name, gap_mm - base_mm, obj.name))
                sank.append((gap_mm - base_mm, obj.name))

        hits = [h for h in collisions(pts) if (h[1], h[2]) not in rest_pairs]
        hits.sort()
        if os.environ.get("CLEAR_SELFTEST") == "1":
            vn = next((o.name for o in riders if o.name.startswith("CRYSTAL")),
                      riders[0].name)
            print("[clear]   %-14s self-test victim %s: rest %.1f mm, now %.1f mm"
                  % (name, vn, rest_sink.get(vn, 0.0) * 1000.0,
                     sink.get(vn, 0.0) * 1000.0))
        for extra, rname in sank[:6]:
            print("[clear]   %-14s SINKS %5.1f mm further  %s"
                  % (name, extra, rname))
        for d, a, b in hits[:6]:
            print("[clear]   %-14s COLLIDE %4.1f mm  %s <-> %s" % (name, d, a, b))
        print("[clear] %-14s %d sinking, %d new collisions"
              % (name, len(sank), len(hits)))
        failures += len(sank) + len(hits)
    clear_pose(arm)
    print("[clear] %s (%d failures)" % ("PASS" if failures == 0 else "FAIL", failures))
    sys.exit(failures)


if __name__ == "__main__":
    main()
