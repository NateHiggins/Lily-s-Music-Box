"""Author/check Teresa's raw-source kneel contact fit, without Godot or Blender.

Default is read-only verification. See tools/TERESA_YARD_KNEEL.md for the
deliberately separate imported-skin, transition and installed gameplay gates.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

import numpy as np

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.audit_glb_surface_uvs import DTYPES, WIDTHS

ROOT = Path(__file__).resolve().parents[1]
ASSET = Path("game/assets/characters/cast/teresa_vale")
PRESENTATION = Path("game/scripts/characters/teresa_yard_kneel.gd")
SIDES = ("Left", "Right")
CONTACT = .001  # Source soles and knee skin: one millimetre above source floor.
KNEE_RADIUS = .09
LIFT_INTERVALS = 32
THIGH_FORWARD_DEGREES = 20.0


def require(condition, message):
    if not condition:
        raise ValueError(message)


def rotation(quaternion):
    x, y, z, w = quaternion
    return np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)],
    ])


def arc(before, after):
    before = before / np.linalg.norm(before)
    after = after / np.linalg.norm(after)
    cross = np.cross(before, after)
    dot = float(before @ after)
    if np.linalg.norm(cross) < 1e-9:
        require(dot > 0, "antiparallel limb direction needs an authored bend axis")
        return np.eye(3)
    x, y, z = cross
    skew = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return np.eye(3) + skew + skew @ skew / (1 + dot)


class Gltf:
    """Small source reader; reuse the existing UV auditor's type/stride ABI.

    Fail on unsupported sparse/normalized data rather than silently skinning
    different geometry. This tool reads external-buffer glTF and the existing shared motion GLB.
    """

    def __init__(self, path):
        self.path = path
        raw = path.read_bytes()
        binary = None
        if raw[:4] == b"glTF":
            require(struct.unpack_from("<II", raw, 4) == (2, len(raw)), "invalid source GLB header")
            chunks, offset = {}, 12
            while offset < len(raw):
                size, kind = struct.unpack_from("<II", raw, offset)
                offset += 8
                require(kind not in chunks and offset+size <= len(raw), "invalid source GLB chunk")
                chunks[kind] = raw[offset:offset+size]
                offset += size
            self.doc = json.loads(chunks[0x4E4F534A])
            binary = chunks.get(0x004E4942)
        else:
            self.doc = json.loads(raw)
        self.sources = [path]
        self.buffers = []
        for spec in self.doc["buffers"]:
            if "uri" not in spec:
                require(binary is not None and len(binary) >= spec["byteLength"], "missing GLB binary")
                self.buffers.append(binary)
                continue
            relative = Path(spec["uri"])
            require(not relative.is_absolute() and ".." not in relative.parts
                    and ":" not in spec["uri"], "external buffer leaves asset folder")
            target = path.parent / relative
            self.sources.append(target)
            data = target.read_bytes()
            require(len(data) == spec["byteLength"], "buffer length changed")
            self.buffers.append(data)

    def accessor(self, index):
        spec = self.doc["accessors"][index]
        require(not spec.get("sparse") and not spec.get("normalized"),
                "sparse/normalized accessor needs explicit support")
        view = self.doc["bufferViews"][spec["bufferView"]]
        dtype = np.dtype(DTYPES[spec["componentType"]])
        width = WIDTHS[spec["type"]]
        start = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
        stride = view.get("byteStride", width * dtype.itemsize)
        end = start + (spec["count"] - 1) * stride + width * dtype.itemsize
        require(spec["count"] > 0 and stride >= width * dtype.itemsize
                and end <= view.get("byteOffset", 0) + view["byteLength"],
                "invalid accessor bounds/stride")
        result = np.ndarray((spec["count"], width), dtype=dtype,
                            buffer=self.buffers[view["buffer"]], offset=start,
                            strides=(stride, dtype.itemsize)).copy()
        require(np.isfinite(result).all(), "nonfinite source accessor")
        return result


class Rig:
    def __init__(self, asset):
        self.asset = asset
        self.nodes = asset.doc["nodes"]
        self.ids = {node["name"]: i for i, node in enumerate(self.nodes)}
        require(len(self.ids) == len(self.nodes), "ambiguous source node names")
        self.parents = {}
        for i, node in enumerate(self.nodes):
            for child in node.get("children", []):
                require(child not in self.parents, "multiple node parents")
                self.parents[child] = i
        self.local, self.rest = {}, {}
        for i in range(len(self.nodes)):
            self._rest(i, set())
        self.joints = asset.doc["skins"][0]["joints"]
        require(len(self.joints) == 76, "Teresa shared skeleton changed")
        self.feet = [self.ids[side + "Foot"] for side in SIDES]

    def _rest(self, index, visiting):
        if index in self.rest:
            return self.rest[index]
        require(index not in visiting, "cyclic source graph")
        visiting.add(index)
        node = self.nodes[index]
        require("matrix" not in node, "matrix node needs explicit rest support")
        local = np.eye(4)
        local[:3, :3] = rotation(node.get("rotation", [0, 0, 0, 1])) @ np.diag(node.get("scale", [1, 1, 1]))
        local[:3, 3] = node.get("translation", [0, 0, 0])
        self.local[index] = local
        parent = self.parents.get(index)
        self.rest[index] = local if parent is None else self._rest(parent, visiting) @ local
        visiting.remove(index)
        return self.rest[index]

    def out_angles(self):
        result = {}
        for side in SIDES:
            result[side] = {}
            for name, first, second in (("thigh", "UpLeg", "Leg"), ("shin", "Leg", "Foot")):
                vector = self.rest[self.ids[side+second]][:3, 3] - self.rest[self.ids[side+first]][:3, 3]
                result[side][name] = float(np.degrees(np.arcsin(abs(vector[0]) / np.linalg.norm(vector))))
        return result

    def pose(self, amount, profile):
        """Independent rest-frame FK of Stand's lower-body direction recipe."""
        globals_, turns = {}, {}

        def visit(index):
            if index in globals_:
                return globals_[index]
            node = self.nodes[index]
            parent = self.parents.get(index)
            if parent is not None:
                visit(parent)
            before = np.eye(3) if parent is None else turns[parent]
            turn = before
            label = node["name"]
            for side in SIDES:
                part = label.removeprefix(side)
                if label.startswith(side) and part in ("UpLeg", "Leg"):
                    segment = "thigh" if part == "UpLeg" else "shin"
                    out = np.radians(profile["out"][side][segment])
                    angle = np.radians((THIGH_FORWARD_DEGREES if part == "UpLeg" else profile["shin_degrees"]) * amount)
                    wanted = np.array([(1 if side == "Left" else -1)*np.sin(out),
                                       -np.cos(out)*np.cos(angle), np.cos(out)*np.sin(angle)])
                    child = self.ids[side + ("Leg" if part == "UpLeg" else "Foot")]
                    direction = self.rest[child][:3, 3] - self.rest[index][:3, 3]
                    turn = arc(before @ direction, wanted) @ before
                elif label.startswith(side) and part in ("Foot", "ToeBase"):
                    turn = np.eye(3)
            if label == "Hips":
                turn = np.eye(3)
            turns[index] = turn
            posed = np.eye(4)
            posed[:3, :3] = turn @ self.rest[index][:3, :3]
            posed[:3, 3] = (self.local[index][:3, 3] if parent is None else
                           globals_[parent][:3, 3] + globals_[parent][:3, :3] @ self.local[index][:3, 3])
            globals_[index] = posed
            return posed

        for index in range(len(self.nodes)):
            visit(index)
        shift = np.mean([self.rest[i][:3, 3] - globals_[i][:3, 3] for i in self.feet], axis=0)
        for index in self.joints:
            globals_[index][:3, 3] += shift
        return globals_


class Skin:
    def __init__(self, asset, rig, only=None):
        self.parts = []
        for node in asset.doc["nodes"]:
            if "mesh" not in node or "skin" not in node or (only and node["name"] not in only):
                continue
            mesh = asset.doc["meshes"][node["mesh"]]
            require(not any(node.get("weights", mesh.get("weights", []))), "active source morph is uncalibrated")
            skin = asset.doc["skins"][node["skin"]]
            inverse = asset.accessor(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
            joints = [rig.ids[asset.doc["nodes"][i]["name"]] for i in skin["joints"]]
            for primitive in mesh["primitives"]:
                attributes = primitive["attributes"]
                require("JOINTS_1" not in attributes, "extra skin influences need explicit support")
                vertices = asset.accessor(attributes["POSITION"])
                ids = asset.accessor(attributes["JOINTS_0"]).astype(int)
                weights = asset.accessor(attributes["WEIGHTS_0"])
                require(ids.shape == weights.shape and len(ids) == len(vertices)
                        and ids.min() >= 0 and ids.max() < len(joints)
                        and np.all(weights >= 0) and np.allclose(weights.sum(axis=1), 1, atol=1e-5), "invalid source skin weights")
                self.parts.append((np.c_[vertices, np.ones(len(vertices))], ids, weights, joints, inverse))
        require(self.parts, "required skinned source mesh missing")

    def points(self, globals_):
        parts = []
        for vertices, ids, weights, joints, inverse in self.parts:
            matrices = np.array([globals_[joint] @ inverse[i] for i, joint in enumerate(joints)])
            posed = np.zeros((len(vertices), 4))
            for slot in range(ids.shape[1]):
                posed += np.einsum("nij,nj->ni", matrices[ids[:, slot]], vertices) * weights[:, slot, None]
            parts.append(posed[:, :3])
        return np.concatenate(parts)


class Calibration:
    def __init__(self, root=ROOT, feet="a_feet", bottom="a_bottom"):
        self.root = Path(root)
        folder = Path(root) / ASSET
        assets = [Gltf(folder / f"teresa_vale{suffix}.gltf") for suffix in ("", "__"+feet, "__"+bottom)]
        self.sources = [path for asset in assets for path in asset.sources]
        self.rig = Rig(assets[0])
        self.legs = Skin(assets[0], self.rig, {"Skin_legs"})
        self.shoes = Skin(assets[1], self.rig)
        self.skirt = Skin(assets[2], self.rig)

    def sample(self, amount, profile, lift=None):
        globals_ = self.rig.pose(amount, profile)
        if lift is None:
            lift = CONTACT - float(self.shoes.points(globals_)[:, 1].min())
        for index in self.rig.joints:
            globals_[index][1, 3] += lift
        knees = [globals_[self.rig.ids[side+"Leg"]][:3, 3] for side in SIDES]
        legs = self.legs.points(globals_)
        knee_minima = []
        for knee in knees:
            points = legs[np.linalg.norm(legs-knee, axis=1) < KNEE_RADIUS]
            require(len(points), "no source knee skin within declared sampling radius")
            knee_minima.append(float(points[:, 1].min()))
        return globals_, lift, knee_minima

    def generate(self):
        profile = {"out": self.rig.out_angles(), "shin_degrees": -90.0}
        low, high = -105.0, -90.0
        for angle, below in ((low, True), (high, False)):
            profile["shin_degrees"] = angle
            require((min(self.sample(1, profile)[2]) < CONTACT) == below,
                    "no knee contact solution in authored shin-angle bracket")
        for _ in range(25):
            profile["shin_degrees"] = (low+high)/2
            if min(self.sample(1, profile)[2]) < CONTACT:
                low = profile["shin_degrees"]
            else:
                high = profile["shin_degrees"]
        profile["shin_degrees"] = round((low+high)/2, 6)
        profile["out"] = {side: {key: round(value, 6) for key, value in values.items()}
                          for side, values in profile["out"].items()}
        profile["lifts"] = [round(self.sample(i/LIFT_INTERVALS, profile)[1], 7)
                            for i in range(LIFT_INTERVALS+1)]
        return profile

    def verify_contact(self, profile):
        require(len(profile["lifts"]) == LIFT_INTERVALS+1, "wrong lift sample count")
        minima = {"shoe": float("inf"), "leg_skin": float("inf"), "skirt": float("inf")}
        drift = 0.0
        for index in range(129):
            amount = index/128
            at = amount*LIFT_INTERVALS
            left = min(int(at), LIFT_INTERVALS-1)
            lift = np.interp(at, [left, left+1], profile["lifts"][left:left+2])
            globals_, _, knees = self.sample(amount, profile, lift)
            for name, skin in (("shoe", self.shoes), ("leg_skin", self.legs), ("skirt", self.skirt)):
                minima[name] = min(minima[name], float(skin.points(globals_)[:, 1].min()))
            for foot in self.rig.feet:
                drift = max(drift, float(np.linalg.norm((globals_[foot][:3, 3]-self.rig.rest[foot][:3, 3])[[0, 2]])))
            if index == 128:
                require(all(CONTACT-.0001 <= value <= CONTACT+.0002 for value in knees), "endpoint knee skin contact changed")
        require(minima["shoe"] > .0008 and minima["leg_skin"] > .0008,
                f"shoe/leg penetrates source floor: {minima}")
        require(minima["skirt"] >= 0, f"skirt penetrates source floor: {minima['skirt']:.6f} m")
        require(drift < .000001, "individual shoe footprint slides horizontally")
        return {"samples": 129, "minimum_y_m": {key: round(value, 6) for key, value in minima.items()},
                "maximum_individual_ankle_horizontal_drift_m": round(drift, 9)}

    def verify_handoff(self, profile):
        """Both actual shared idle clips, nine phases and thirteen blend weights.

        This includes the originally failing source pose and the endpoint/seam
        sides, but deliberately does not claim every possible clip crossfade.
        """
        moves = Gltf(self.root / "game/assets/characters/cast/shared/cast_moves.glb")
        self.sources.extend(path for path in moves.sources if path not in self.sources)
        target = self.rig.pose(0, profile)
        for index in self.rig.joints:
            target[index][1, 3] += profile["lifts"][0]
        target_local = {i: value if i not in self.rig.parents else
                        np.linalg.inv(target[self.rig.parents[i]]) @ value
                        for i, value in target.items()}
        original_low, corrected_low, maximum_ankle_move = float("inf"), float("inf"), 0.0
        samples = 0
        for name in ("clip_02", "clip_03"):
            animation = next(row for row in moves.doc["animations"] if row["name"] == name)
            duration = max(float(moves.accessor(row["input"])[-1, 0]) for row in animation["samplers"])
            for seconds in np.linspace(0, duration, 9):
                live = clip_locals(self.rig, moves, name, seconds)
                for weight in np.linspace(0, 1, 13):
                    before = blend_handoff(self.rig, live, target_local, weight)
                    original_low = min(original_low, float(self.shoes.points(before)[:, 1].min()))
                    after = support_handoff(self, before)
                    corrected_low = min(corrected_low, float(self.shoes.points(after)[:, 1].min()))
                    for side in SIDES:
                        chain = [self.rig.ids[side+part] for part in ("UpLeg", "Leg", "Foot")]
                        for first, second in zip(chain, chain[1:]):
                            old = np.linalg.norm(before[first][:3, 3]-before[second][:3, 3])
                            new = np.linalg.norm(after[first][:3, 3]-after[second][:3, 3])
                            require(abs(old-new) < 1e-8, "handoff stretched a leg")
                        foot = chain[-1]
                        require(np.linalg.norm((after[foot][:3, 3]-before[foot][:3, 3])[[0, 2]]) < 1e-9,
                                "handoff slid a shoe horizontally")
                        maximum_ankle_move = max(maximum_ankle_move, float(np.linalg.norm(after[foot][:3, 3]-before[foot][:3, 3])))
                    require(np.array_equal(before[self.rig.ids["Hips"]], after[self.rig.ids["Hips"]]), "support changed pelvis")
                    samples += 1
        return {"clips": ["clip_02", "clip_03"], "phase_samples_per_clip": 9,
                "blend_samples_per_phase": 13, "samples": samples,
                "uncorrected_source_minimum_y_m": round(original_low, 6),
                "supported_source_minimum_y_m": round(corrected_low, 6),
                "maximum_ankle_vertical_correction_m": round(maximum_ankle_move, 6)}


def quaternion(matrix):
    """Unit quaternion from a rotation matrix (symmetric eigen formulation)."""
    m = matrix / np.linalg.norm(matrix, axis=0)
    x, y, z = m
    k = np.array([[x[0]-y[1]-z[2], y[0]+x[1], z[0]+x[2], y[2]-z[1]],
                  [y[0]+x[1], y[1]-x[0]-z[2], z[1]+y[2], z[0]-x[2]],
                  [z[0]+x[2], z[1]+y[2], z[2]-x[0]-y[1], x[1]-y[0]],
                  [y[2]-z[1], z[0]-x[2], x[1]-y[0], x[0]+y[1]+z[2]]]) / 3
    _, vectors = np.linalg.eigh(k)
    q = vectors[:, -1]
    # k uses row-vector signs; convert back to the column-vector ABI above.
    q[:3] *= -1
    return q


def slerp(first, second, amount):
    first, second = first / np.linalg.norm(first), second / np.linalg.norm(second)
    dot = float(first @ second)
    if dot < 0:
        second, dot = -second, -dot
    if dot > .9995:
        result = first + amount*(second-first)
        return result / np.linalg.norm(result)
    angle = np.arccos(np.clip(dot, -1, 1))
    return (np.sin((1-amount)*angle)*first + np.sin(amount*angle)*second) / np.sin(angle)


def compose(rig, locals_):
    result = {}
    def visit(index):
        if index not in result:
            parent = rig.parents.get(index)
            result[index] = locals_[index] if parent is None else visit(parent) @ locals_[index]
        return result[index]
    for index in range(len(rig.nodes)):
        visit(index)
    return result


def clip_locals(rig, moves, name, seconds):
    """ResidentMovesLibrary's actual cast rest rebase, with no Godot import."""
    animation = next(row for row in moves.doc["animations"] if row["name"] == name)
    result = {i: value.copy() for i, value in rig.local.items()}
    for channel in animation["channels"]:
        target = channel["target"]
        node = moves.doc["nodes"][target["node"]]
        label, kind = node["name"], target["path"]
        if kind == "scale" or (kind == "translation" and label != "Hips") or label.startswith("Skirt"):
            continue
        sampler = animation["samplers"][channel["sampler"]]
        interpolation = sampler.get("interpolation", "LINEAR")
        require(interpolation in ("LINEAR", "STEP"), "unsupported cast motion interpolation")
        times = moves.accessor(sampler["input"]).ravel()
        values = moves.accessor(sampler["output"])
        index = min(max(int(np.searchsorted(times, seconds, side="right"))-1, 0), len(times)-1)
        next_index = min(index+1, len(times)-1)
        amount = 0 if index == next_index or interpolation == "STEP" else float(np.clip((seconds-times[index])/(times[next_index]-times[index]), 0, 1))
        own = rig.ids[label]
        if kind == "rotation":
            sampled = rotation(slerp(values[index], values[next_index], amount))
            donor = rotation(node.get("rotation", [0, 0, 0, 1]))
            rest = rig.local[own][:3, :3]
            rest = rest / np.linalg.norm(rest, axis=0)
            result[own][:3, :3] = rest @ donor.T @ sampled
        else:
            donor = np.array(node["translation"])
            at = (1-amount)*values[index] + amount*values[next_index]
            own_rest = rig.local[own][:3, 3]
            result[own][:3, 3] = own_rest + (at-donor)*(own_rest[1]/donor[1])
    return result


def blend_handoff(rig, live, kneel, weight):
    result = {i: value.copy() for i, value in live.items()}
    for label in ("Hips",) + tuple(side+part for side in SIDES for part in ("UpLeg", "Leg", "Foot", "ToeBase")):
        index = rig.ids[label]
        posed = np.eye(4)
        posed[:3, 3] = (1-weight)*live[index][:3, 3] + weight*kneel[index][:3, 3]
        posed[:3, :3] = rotation(slerp(quaternion(live[index][:3, :3]), quaternion(kneel[index][:3, :3]), weight))
        result[index] = posed
    return compose(rig, result)


def leg_goal(globals_, ids, target):
    thigh, knee, foot, toe = [globals_[index] for index in ids]
    a, b, c = thigh[:3, 3], knee[:3, 3], foot[:3, 3]
    upper, lower = np.linalg.norm(b-a), np.linalg.norm(c-b)
    reach = target-a
    distance = np.linalg.norm(reach)
    require(abs(upper-lower)+.000001 < distance < upper+lower-.000001, "handoff leg cannot reach floor")
    direction = reach/distance
    bend = b-a-direction*((b-a) @ direction)
    if bend @ bend < .000001:
        bend = np.array([0., 0., 1.])-direction*direction[2]
    require(bend @ bend >= .000001, "unmeasured handoff bend axis")
    along = (upper*upper-lower*lower+distance*distance)/(2*distance)
    wanted = a+direction*along+bend/np.linalg.norm(bend)*np.sqrt(max(0, upper*upper-along*along))
    first = arc(b-a, wanted-a)
    moved = wanted+first @ (c-b)
    second = arc(moved-wanted, target-wanted)
    posed_thigh, posed_knee, posed_foot = thigh.copy(), knee.copy(), foot.copy()
    posed_thigh[:3, :3] = first @ thigh[:3, :3]
    posed_knee[:3, :3] = second @ first @ knee[:3, :3]
    posed_knee[:3, 3], posed_foot[:3, 3] = wanted, target
    return dict(zip(ids, (posed_thigh, posed_knee, posed_foot, posed_foot @ np.linalg.inv(foot) @ toe)))


def support_handoff(calibration, globals_):
    """Independent full-shoe oracle for the bounded per-leg runtime solve."""
    rig, shoes = calibration.rig, calibration.shoes
    masks = {}
    for side in SIDES:
        groups = []
        for _vertices, ids, weights, joints, _inverse in shoes.parts:
            own = np.array([rig.nodes[j]["name"].startswith(side) for j in joints])
            groups.append(np.sum(own[ids]*weights, axis=1) >= .5)
        masks[side] = np.concatenate(groups)
    proposed = {}
    for side in SIDES:
        ids = [rig.ids[side+part] for part in ("UpLeg", "Leg", "Foot", "ToeBase")]
        target = globals_[ids[2]][:3, 3].copy()
        poses = {}
        for _ in range(3):
            low = float(shoes.points(globals_ | poses)[masks[side], 1].min())
            error = CONTACT-low
            if .0008 <= low <= .0058:
                break
            if error < 0:
                error = .0055-low
            target[1] += error
            require(np.linalg.norm(target-globals_[ids[2]][:3, 3]) <= .02, "handoff exceeds measured range")
            poses = leg_goal(globals_, ids, target)
        low = float(shoes.points(globals_ | poses)[masks[side], 1].min())
        require(.0008 <= low <= .006, "source handoff sole did not converge")
        proposed.update(poses)
    return globals_ | proposed


def read_fit(path):
    source = path.read_text(encoding="utf-8")
    for name, expected in (("THIGH_FORWARD_DEGREES", THIGH_FORWARD_DEGREES),
                           ("LIFT_INTERVALS", LIFT_INTERVALS), ("HANDOFF_CLEARANCE", CONTACT),
                           ("HANDOFF_LIMIT", .02)):
        declaration = re.search(r"^const " + name + r" := ([\d.]+)$", source, re.MULTILINE)
        require(declaration is not None and float(declaration[1]) == expected,
                f"runtime {name} differs from calibration recipe")
    match = re.search(r"^const FIT := (\{.*?\})\s*\nconst LOWER:", source, re.MULTILINE | re.DOTALL)
    require(match is not None, "cannot locate authored FIT dictionary")
    return source, match, json.loads(match[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--feet", default="a_feet")
    parser.add_argument("--bottom", default="a_bottom")
    parser.add_argument("--write", action="store_true", help="replace only the current work FIT after source checks pass")
    parser.add_argument("--out", type=Path, help="optional INERT source-only report")
    args = parser.parse_args()
    try:
        require(re.fullmatch(r"[abc]_feet", args.feet) and re.fullmatch(r"[abc]_bottom", args.bottom), "unsupported part name")
        calibration = Calibration(args.root, args.feet, args.bottom)
        profile = calibration.generate()
        contact = calibration.verify_contact(profile)
        source, match, baked = read_fit(args.root/PRESENTATION)
        expected = {args.feet: profile}
        handoff = calibration.verify_handoff(profile)
        if args.write:
            require((args.feet, args.bottom) == ("a_feet", "a_bottom"), "new outfit admission requires separate runtime/native review")
            replacement = json.dumps(expected, indent="\t")
            (args.root/PRESENTATION).write_text(source[:match.start(1)]+replacement+source[match.end(1):], encoding="utf-8", newline="\n")
        else:
            require(baked == expected, "baked FIT differs from source calibration; inspect --write diff and renew native proof")
            calibration.verify_contact(baked[args.feet])
        report = {"evidence_class": "INERT", "status": "PASS_SOURCE_ONLY", "feet": args.feet, "bottom": args.bottom,
                  "scope": "raw-source LBS; not imported morph/cloth, live-clip handoff, native contact or gameplay proof",
                  "contact": contact, "handoff": handoff, "profile": expected,
                  "sources": [{"path": path.relative_to(args.root).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                              for path in calibration.sources]}
        if args.out:
            args.out.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8", newline="\n")
        print("Teresa kneel: PASS_SOURCE_ONLY; 129 samples;", contact["minimum_y_m"])
        return 0
    except (ValueError, KeyError, OSError) as error:
        print("Teresa kneel: FAIL:", error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
