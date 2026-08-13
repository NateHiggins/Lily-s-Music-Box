"""Stage two: take a mass's probe pixel back to the generator record.

    python tools/street_provenance.py rays  <log> <masses.txt> [layout.json]
    python tools/street_provenance.py check <log> <dir> <layout.json> <id>...

The id pass names a merged buffer and stops there — a buffer's AABB spans
wherever its category appears on the floor, so merged AABB size is not
provenance. `rays` casts the camera's own ray through a mass and restricts
the source records by coordinate: the nearest record the ray actually
enters, whose material matches the buffer, is the record that drew the
pixel. `check` runs the test backwards, projecting a named record's box
into screen space to confirm it lands on the mass it is supposed to explain.

The ray builder reimplements Camera3D.project_ray_normal, so it is checked
against the five rays the engine printed before it is used for anything. If
that assertion fires, no answer below it is worth reading.

masses.txt is "<px>,<py><TAB><buffer name>" per line.

NOTE ON WHICH LAYOUT TO PASS. The records must be the ones Blender actually
built from, not merely the current ones. If game/assets/building/*.gltf is
older than game/data/building_layout.json, pass the as-built revision:

    git show <gltf-commit>:game/data/building_layout.json > asbuilt.json
"""
import json
import math
import sys

import numpy as np

sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from street_ownership import load, name  # noqa: E402

DEFAULT_LAYOUT = "game/data/building_layout.json"


def read_camera(log):
    cam, engine = {}, {}
    for line in open(log, encoding="utf-8", errors="replace"):
        if line.startswith("[IDCAM] "):
            body = line[8:].strip()
            if body.startswith("fov="):
                for kv in body.split():
                    k, v = kv.split("=")
                    cam[k] = v
            else:
                k, v = body.split("\t")
                cam[k] = np.array([float(x) for x in v.split(",")])
        elif line.startswith("[IDRAY] "):
            px, _o, d = line[8:].strip().split("\t")
            engine[px] = np.array([float(x) for x in d.split(",")])
    return cam, engine


class Camera:
    def __init__(self, cam):
        self.W, self.H = (int(v) for v in cam["size"].split(","))
        self.near = float(cam["near"])
        self.origin = cam["origin"]
        self.bx, self.by, self.bz = (cam["basis_x"], cam["basis_y"],
                                     cam["basis_z"])
        # keep_aspect = 1 is KEEP_HEIGHT, so fov is the vertical angle.
        self.tan_h = math.tan(math.radians(float(cam["fov"])) / 2.0)
        self.tan_w = self.tan_h * (self.W / self.H)

    def ray(self, px, py):
        ax = ((px / self.W) * 2.0 - 1.0) * self.near * self.tan_w
        ay = ((1.0 - py / self.H) * 2.0 - 1.0) * self.near * self.tan_h
        v = ax * self.bx + ay * self.by - self.near * self.bz
        return v / np.linalg.norm(v)

    def project(self, p):
        v = p - self.origin
        lx, ly, lz = v @ self.bx, v @ self.by, v @ self.bz
        if lz >= -1e-6:
            return None                       # behind the camera
        return ((lx / (-lz) / self.tan_w + 1.0) * 0.5 * self.W,
                (1.0 - (ly / (-lz) / self.tan_h + 1.0) * 0.5) * self.H)

    def verify(self, engine):
        worst = max(float(np.abs(self.ray(*(int(v) for v in k.split(","))) - d)
                          .max()) for k, d in engine.items())
        print(f"ray builder vs engine: worst component error {worst:.2e}")
        assert worst < 1e-4, "ray reconstruction does not match the engine"


def read_records(path):
    """b2g maps Blender [x, y, z] -> Godot (x, z, -y). Everything is Godot."""
    layout = json.load(open(path))
    boxes, pipes, others = [], [], []
    for fl in layout["floors"]:
        for key in ("furniture", "walls", "slabs", "ceilings"):
            for r in fl.get(key, []):
                if "rect" in r and "z0" in r and "h" in r:
                    x0, y0, x1, y1 = r["rect"]
                    boxes.append((
                        np.array([min(x0, x1), r["z0"], -max(y0, y1)], float),
                        np.array([max(x0, x1), r["z0"] + r["h"],
                                  -min(y0, y1)], float),
                        fl["id"], key, r.get("mat", "-"), r["id"],
                        r.get("batch", "")))
                elif key == "furniture" and r.get("asm") == "pipe" \
                        and "p0" in r:
                    p0, p1 = r["p0"], r["p1"]
                    pipes.append((np.array([p0[0], p0[2], -p0[1]], float),
                                  np.array([p1[0], p1[2], -p1[1]], float),
                                  float(r["r"]), fl["id"], r.get("mat", "-"),
                                  r["id"]))
                elif key == "furniture" and "asm" in r and "at" in r:
                    at = r["at"]
                    z = float(r.get("z0", 0.0)) + fl.get("z", 0.0)
                    others.append((np.array([at[0], z, -at[1]], float),
                                   fl["id"], r["asm"], r["id"]))
    print(f"records from {path}: {len(boxes)} boxes, {len(pipes)} pipe "
          f"capsules, {len(others)} other assemblies")
    return boxes, pipes, others


def ray_segment(o, d, a, b):
    """Closest approach between ray and segment -> (gap, t along ray)."""
    u = b - a
    w0 = o - a
    aa, bb, cc = d @ d, d @ u, u @ u
    dd, ee = d @ w0, u @ w0
    den = aa * cc - bb * bb
    if abs(den) < 1e-12:
        s, t = 0.0, max(0.0, -dd / aa)
    else:
        s = min(1.0, max(0.0, (aa * ee - bb * dd) / den))
        t = max(0.0, float(d @ (a + s * u - o)))
    return float(np.linalg.norm(o + t * d - (a + s * u))), float(t)


def rays(log, masses_path, layout=DEFAULT_LAYOUT):
    cam_raw, engine = read_camera(log)
    cam = Camera(cam_raw)
    cam.verify(engine)
    boxes, pipes, others = read_records(layout)
    lo = np.array([b[0] for b in boxes])
    hi = np.array([b[1] for b in boxes])

    for line in open(masses_path, encoding="utf-8"):
        if not line.strip():
            continue
        xy, owner = line.strip().split("\t")
        px, py = (int(v) for v in xy.split(","))
        d = cam.ray(px, py)
        want = owner.rsplit("_", 1)[-1]
        print(f"\n=== pixel {px},{py}   buffer {owner}  (want mat={want}) ===")

        inv = 1.0 / np.where(np.abs(d) < 1e-12, 1e-12, d)
        t1, t2 = (lo - cam.origin) * inv, (hi - cam.origin) * inv
        tmin = np.maximum.reduce(np.minimum(t1, t2), axis=1)
        tmax = np.minimum.reduce(np.maximum(t1, t2), axis=1)
        cand = []
        for i in np.nonzero(tmax >= np.maximum(tmin, 0.0))[0]:
            b = boxes[i]
            batch = f" [batch {b[6]}]" if b[6] else ""
            cand.append((float(max(tmin[i], 0.0)),
                         f"{b[2]}/{b[3]} mat={b[4]:16s} {b[5]}{batch}", b[4]))
        for a, b, r, fid, mat, rid in pipes:
            gap, t = ray_segment(cam.origin, d, a, b)
            if gap <= r:
                cand.append((t, f"{fid}/pipe     mat={mat:16s} {rid} "
                                f"(r={r:.3f})", mat))
        cand.sort(key=lambda c: c[0])
        if not cand:
            print("   nothing with explicit geometry on this ray")
        for t, txt, mat in cand[:6]:
            mark = "  <== material matches buffer" if mat == want else ""
            print(f"   t={t:7.2f} m  {txt}{mark}")

        if not (cand and cand[0][2] == want):
            near = sorted(((float(np.linalg.norm(np.cross(d, p - cam.origin))),
                            float(d @ (p - cam.origin)), fid, asm, rid)
                           for p, fid, asm, rid in others), key=lambda c: c[0])
            print("   nearest non-pipe assemblies (candidates only — their "
                  "shape lives in the Blender builder):")
            for gap, t, fid, asm, rid in [n for n in near if n[1] > 0][:5]:
                print(f"      offset {gap:5.2f} m at t={t:6.2f}  "
                      f"{fid}/{asm:20s} {rid}")


def check(log, d_dir, layout, want_ids):
    cam_raw, _ = read_camera(log)
    cam = Camera(cam_raw)
    beauty, idx, legend = load(log, d_dir)
    luma = (beauty[:, :, 0] * 299 + beauty[:, :, 1] * 587
            + beauty[:, :, 2] * 114) // 1000
    for fl in json.load(open(layout))["floors"]:
        for r in fl.get("furniture", []):
            if r["id"] not in want_ids or "rect" not in r:
                continue
            x0, y0, x1, y1 = r["rect"]
            pts = [cam.project(np.array([x, z, -y], float))
                   for x in (x0, x1) for y in (y0, y1)
                   for z in (r["z0"], r["z0"] + r["h"])]
            pts = [p for p in pts if p]
            if not pts:
                print(f"{r['id']}: entirely behind the camera")
                continue
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            bx0, by0 = max(0, int(min(xs))), max(0, int(min(ys)))
            bx1 = min(cam.W - 1, int(max(xs)))
            by1 = min(cam.H - 1, int(max(ys)))
            box = idx[by0:by1 + 1, bx0:bx1 + 1]
            dk = luma[by0:by1 + 1, bx0:bx1 + 1] < 16
            u, c = np.unique(box[dk], return_counts=True)
            print(f"\n{r['id']}  mat={r.get('mat')}  predicted bbox "
                  f"{bx0},{by0}..{bx1},{by1}  ({box.size} px, "
                  f"{100.0 * dk.mean():.0f}% of it black)")
            for i in np.argsort(-c)[:3]:
                print(f"   {100.0 * c[i] / max(1, dk.sum()):6.2f}% of that "
                      f"black area  {name(legend, u[i])}")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "rays":
        rays(sys.argv[2], sys.argv[3],
             sys.argv[4] if len(sys.argv) > 4 else DEFAULT_LAYOUT)
    elif cmd == "check":
        check(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:])
    else:
        sys.exit(__doc__)
