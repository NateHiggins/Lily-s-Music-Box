#!/usr/bin/env python3
"""Author a seated drape for a gown part (Omni order w39b8516474ec; Lily's ruling seated_gowns_next_20261116).

    python art/tools/build_seated_drape.py <person.gltf folder> <person id> <part>   e.g. ... adela_voss p_top

Reads <id>__<part>.gltf and writes <id>__<part>_seated.gltf/.bin beside it: the part's own skirt meshes (every mesh
skinned to the skirt chains), with the same triangles, UVs and materials, laid as a seated cloth and skinned to the
hips, thighs and shins instead of the skirt chains. The game shows it in place of the standing skirt while the wearer
sits (cast_model_presentation.gd), so the print keeps its place and nothing is simulated.

The seated shape. A standing skirt hangs down a straight path from the waist. Seated, the same cloth follows a bent
path: a short drop at the waist, forward along the lap to the knees, then down the shins to wherever its length
ends. Every skirt point keeps its place across the cloth (its sideways offset and its front or back offset from the
skirt's middle) and its distance down the cloth; only the path it hangs from changes. Over the lap the cloth is
spread to cover both thighs and its underside is pressed flat to the seat; below the knees it keeps the standing
skirt's own section. The points are then taken back to the bind pose through the same blend of joints that will
carry them, so in the authored pose (thighs level, shins upright) the cloth is exactly as laid, and in any other
seated pose it follows the legs.

No appearance is accepted here: look at the wearer seated in the engine.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import numpy as np

CT = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4), 5121: ("B", 1)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
THIGH_R = 0.085          # a thigh's radius under the cloth, metres
EASE = 0.012             # cloth off the leg
SEAT_PRESS = 0.004       # the underside lies this far below the thigh's underside
FILLET = 0.07            # the bends at the hip and the knee
SIDE_BLEND = 0.05        # half-width across the middle where the two legs share the cloth


def read_accessor(doc, blob, index):
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    fmt, size = CT[a["componentType"]]
    n = NC[a["type"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", size * n)
    out = np.zeros((a["count"], n), dtype=np.float64 if fmt == "f" else np.int64)
    for k in range(a["count"]):
        out[k] = struct.unpack_from("<%d%s" % (n, fmt), blob, start + k * stride)
    return out


def rot_x(angle):
    c, s = np.cos(angle), np.sin(angle)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def about(point, rotation):
    m = np.eye(4)
    m[:3, :3] = rotation
    m[:3, 3] = point - rotation @ point
    return m


def smooth(lo, hi, x):
    t = np.clip((x - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class ClothPath:
    """Waist down, forward along the lap, down the shins, in the body's middle plane (y up, z forward), with round
    bends. at(l) gives the point at arc length l, and the angle the cloth has turned from hanging straight down
    (0 hanging, 90 degrees lying forward)."""

    def __init__(self, waist, hip_y, knee_z):
        r = FILLET
        self.pieces = []  # (length, kind, data)
        y0, z0 = waist
        drop = max(0.0, (y0 - hip_y) - r)
        self.pieces.append((drop, "line", (np.array([y0, z0]), np.array([-1.0, 0.0]), 0.0)))
        # Quarter turn forward, centre in front of and level with the end of the drop.
        self.pieces.append((r * np.pi / 2, "arc", (np.array([y0 - drop, z0 + r]), r, 0.0, +1)))
        lap = max(0.0, (knee_z - (z0 + r)) - r)
        self.pieces.append((lap, "line", (np.array([hip_y, z0 + r]), np.array([0.0, 1.0]), np.pi / 2)))
        self.pieces.append((r * np.pi / 2, "arc", (np.array([hip_y - r, z0 + r + lap]), r, np.pi / 2, -1)))
        self.pieces.append((1e9, "line", (np.array([hip_y - r, z0 + r + lap + r]), np.array([-1.0, 0.0]), 0.0)))
        self.lap_from = drop + r * np.pi / 4
        self.knee_at = drop + r * np.pi / 2 + lap + r * np.pi / 4

    def at(self, length):
        run = length
        for size, kind, data in self.pieces:
            if run <= size:
                if kind == "line":
                    start, direction, turned = data
                    return start + direction * run, turned
                centre, r, turned0, sign = data
                swept = run / r
                if sign > 0:
                    # Down turning forward: from directly behind the centre round to directly above it.
                    return centre + np.array([-r * np.sin(swept), -r * np.cos(swept)]), swept
                # Forward turning down: from directly above the centre round to directly in front of it.
                return centre + np.array([r * np.cos(swept), r * np.sin(swept)]), turned0 - swept
            run -= size
        raise ValueError("path ran out")


def main():
    folder, person, part = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    source = folder / ("%s__%s.gltf" % (person, part))
    doc = json.loads(source.read_text(encoding="utf-8"))
    blob = (folder / doc["buffers"][0]["uri"]).read_bytes()
    names = [n.get("name", "") for n in doc["nodes"]]
    skin = doc["skins"][0]
    joint_names = [names[j] for j in skin["joints"]]
    ibm = read_accessor(doc, blob, skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    rest = {name: np.linalg.inv(ibm[k])[:3, 3] for k, name in enumerate(joint_names)}
    index_of = {name: k for k, name in enumerate(joint_names)}

    # The authored seated pose: both thighs turned level about their own joints, the shins left upright.
    turn = rot_x(-np.pi / 2)
    pose = {"Hips": np.eye(4)}
    knees = {}
    for side in ("Left", "Right"):
        thigh = about(rest[side + "UpLeg"], turn)
        pose[side + "UpLeg"] = thigh
        knee = (thigh @ np.append(rest[side + "Leg"], 1.0))[:3]
        knees[side] = knee
        shin = np.eye(4)
        shin[:3, 3] = knee - rest[side + "Leg"]
        pose[side + "Leg"] = shin
    hip_y = (rest["LeftUpLeg"][1] + rest["RightUpLeg"][1]) / 2
    knee_z = (knees["Left"][2] + knees["Right"][2]) / 2
    knee_x = (abs(knees["Left"][0]) + abs(knees["Right"][0])) / 2

    skirt_nodes = []
    for node_index, node in enumerate(doc["nodes"]):
        if "mesh" not in node:
            continue
        prim = doc["meshes"][node["mesh"]]["primitives"][0]
        joints = read_accessor(doc, blob, prim["attributes"]["JOINTS_0"]).astype(int)
        weights = read_accessor(doc, blob, prim["attributes"]["WEIGHTS_0"])
        used = {joint_names[j] for j in np.unique(joints[weights > 0.01])}
        if any(name.startswith("Skirt") for name in used):
            skirt_nodes.append(node_index)
    if not skirt_nodes:
        raise SystemExit("no mesh of %s is skinned to the skirt chains" % source.name)

    # The standing skirt's own measure, from every skirt mesh together: its top, its middle line and half-width by height.
    every = np.concatenate([read_accessor(doc, blob, doc["meshes"][doc["nodes"][n]["mesh"]]["primitives"][0]["attributes"]["POSITION"]) for n in skirt_nodes])
    top = every[:, 1].max()
    bins = np.linspace(every[:, 1].min(), top, 25)
    mids = (bins[:-1] + bins[1:]) / 2
    centre_z = np.zeros(len(mids))
    half_w = np.zeros(len(mids))
    for b in range(len(mids)):
        ring = every[(every[:, 1] >= bins[b] - 1e-6) & (every[:, 1] <= bins[b + 1] + 1e-6)]
        centre_z[b] = (ring[:, 2].min() + ring[:, 2].max()) / 2
        half_w[b] = np.abs(ring[:, 0]).max()
    path = ClothPath((top, float(np.interp(top, mids, centre_z))), hip_y, knee_z)

    out_blob = bytearray()
    out_views = []
    out_accessors = []

    def add(array, component, kind, target=None):
        fmt, size = CT[component]
        data = b"".join(struct.pack("<%d%s" % (array.shape[1], fmt), *row) for row in array.tolist()) if array.ndim == 2 \
            else b"".join(struct.pack("<" + fmt, v) for v in array.tolist())
        while len(out_blob) % 4:
            out_blob.append(0)
        view = {"buffer": 0, "byteOffset": len(out_blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        out_blob.extend(data)
        out_views.append(view)
        accessor = {"bufferView": len(out_views) - 1, "componentType": component, "count": int(array.shape[0]), "type": kind}
        if kind == "VEC3" and component == 5126:
            accessor["min"] = [float(v) for v in array.min(0)]
            accessor["max"] = [float(v) for v in array.max(0)]
        out_accessors.append(accessor)
        return len(out_accessors) - 1

    new_nodes = []
    new_meshes = []
    report = []
    for node_index in skirt_nodes:
        node = doc["nodes"][node_index]
        prim = doc["meshes"][node["mesh"]]["primitives"][0]
        attributes = prim["attributes"]
        position = read_accessor(doc, blob, attributes["POSITION"])
        normal = read_accessor(doc, blob, attributes["NORMAL"])
        tangent = read_accessor(doc, blob, attributes["TANGENT"])
        uv = read_accessor(doc, blob, attributes["TEXCOORD_0"])
        indices = read_accessor(doc, blob, prim["indices"]).astype(int).reshape(-1)
        count = len(position)
        posed = np.zeros((count, 3))
        turned = np.zeros(count)
        new_joints = np.zeros((count, 4), dtype=int)
        new_weights = np.zeros((count, 4))
        for k in range(count):
            x, y, z = position[k]
            length = top - y
            dz = z - float(np.interp(y, mids, centre_z))
            point, angle = path.at(length)
            lap = smooth(path.lap_from - 0.03, path.lap_from + 0.06, length) * (1.0 - smooth(path.knee_at - 0.05, path.knee_at + 0.05, length))
            # Over the lap: wide enough to cover both thighs, the top clear of them, the underside pressed to the seat.
            need = knee_x + THIGH_R * 0.75 + EASE
            have = max(float(np.interp(y, mids, half_w)), 1e-4)
            wide = 1.0 + lap * max(0.0, need / have - 1.0)
            off = dz
            if lap > 0.0:
                up = THIGH_R + EASE + max(0.0, dz) * 0.35
                down = -(THIGH_R + SEAT_PRESS)
                target = up if dz >= 0 else down * min(1.0, -dz / 0.03)
                off = dz * (1.0 - lap) + target * lap
            front = np.array([np.sin(angle), np.cos(angle)])  # (y, z) of the cloth's front normal at this turn
            py, pz = point + front * off
            posed[k] = (x * wide, py, pz)
            turned[k] = angle
            # Who carries it: the hips above the lap, the thighs along it, the shins below the knee; left and right
            # share the middle.
            hips = 1.0 - smooth(path.lap_from - 0.03, path.lap_from + 0.07, length)
            shins = smooth(path.knee_at - 0.05, path.knee_at + 0.05, length)
            thighs = max(0.0, 1.0 - hips - shins)
            left = float(smooth(-SIDE_BLEND, SIDE_BLEND, x))
            carriers = [("Hips", hips), ("LeftUpLeg", thighs * left), ("RightUpLeg", thighs * (1 - left)),
                        ("LeftLeg", shins * left), ("RightLeg", shins * (1 - left))]
            carriers = sorted([c for c in carriers if c[1] > 1e-4], key=lambda c: -c[1])[:4]
            total = sum(w for _, w in carriers)
            for slot, (name, weight) in enumerate(carriers):
                new_joints[k, slot] = index_of[name]
                new_weights[k, slot] = weight / total
        # Back to the bind pose through the blend that will carry each point.
        bound = np.zeros((count, 3))
        bound_normal = np.zeros((count, 3))
        bound_tangent = np.zeros((count, 4))
        for k in range(count):
            blend = np.zeros((4, 4))
            for slot in range(4):
                if new_weights[k, slot] > 0:
                    blend += new_weights[k, slot] * pose[joint_names[new_joints[k, slot]]]
            inverse = np.linalg.inv(blend)
            bound[k] = (inverse @ np.append(posed[k], 1.0))[:3]
            # The cloth's own frame turned with the path (down toward forward is a turn about x), then unposed.
            frame = inverse[:3, :3] @ rot_x(-turned[k])
            n = frame @ normal[k]
            t = frame @ tangent[k, :3]
            bound_normal[k] = n / max(np.linalg.norm(n), 1e-9)
            bound_tangent[k, :3] = t / max(np.linalg.norm(t), 1e-9)
            bound_tangent[k, 3] = tangent[k, 3]
        primitive = {"attributes": {
            "POSITION": add(bound.astype(np.float32), 5126, "VEC3", 34962),
            "NORMAL": add(bound_normal.astype(np.float32), 5126, "VEC3", 34962),
            "TANGENT": add(bound_tangent.astype(np.float32), 5126, "VEC4", 34962),
            "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
            "JOINTS_0": add(new_joints, 5123, "VEC4", 34962),
            "WEIGHTS_0": add(new_weights.astype(np.float32), 5126, "VEC4", 34962)},
            "indices": add(indices, 5125, "SCALAR", 34963), "mode": 4}
        if "material" in prim:
            primitive["material"] = prim["material"]
        new_meshes.append({"name": doc["meshes"][node["mesh"]].get("name", node["name"]) + "_seated", "primitives": [primitive]})
        new_nodes.append(node_index)
        report.append({"mesh": node["name"], "points": count, "hem_y": float(posed[:, 1].min()), "front_z": float(posed[:, 2].max())})

    # The same document with only the skirt meshes, their data replaced; the skeleton, skin, materials and pictures as they were.
    ibm_index = add(read_accessor(doc, blob, skin["inverseBindMatrices"]).astype(np.float32), 5126, "MAT4")
    result = json.loads(json.dumps(doc))
    result["accessors"] = out_accessors
    result["bufferViews"] = out_views
    result["skins"][0]["inverseBindMatrices"] = ibm_index
    result["meshes"] = new_meshes
    kept = {}
    for node_index, node in enumerate(result["nodes"]):
        if "mesh" in node:
            if node_index in new_nodes:
                node["mesh"] = new_nodes.index(node_index)
                kept[node_index] = True
            else:
                del node["mesh"]
                node.pop("skin", None)
    target = folder / ("%s__%s_seated" % (person, part))
    result["buffers"] = [{"uri": target.name + ".bin", "byteLength": len(out_blob)}]
    result.pop("animations", None)
    target.with_suffix(".bin").write_bytes(bytes(out_blob))
    target.with_suffix(".gltf").write_text(json.dumps(result, separators=(",", ":")), encoding="utf-8", newline="\n")
    print("SEATED DRAPE", target.name, json.dumps(report), "lap from %.3f knee at %.3f length %.3f" % (path.lap_from, path.knee_at, top - every[:, 1].min()))


if __name__ == "__main__":
    main()
