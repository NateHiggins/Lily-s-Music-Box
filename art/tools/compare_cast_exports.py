#!/usr/bin/env python3
"""Compare two exports of the same cast model corner by corner. CPU only.

    python art/tools/compare_cast_exports.py <control.gltf> <candidate.gltf> [--report out.json]

Two exports of one source may index their points differently (one splits every corner, the other
shares them), so nothing is compared by point number. Each mesh is expanded to its triangle corners,
in triangle order, and these are compared corner for corner:

    position, normal, every UV set, colour, joints and weights (as a bone-name to weight table),
    and every morph target's position delta, matched by the target's NAME.

Skins are compared by joint name: the joint list, each inverse bind matrix, and each joint node's rest
translation, rotation and scale. Tangents are reported, not required to match: they are what the two
exports are allowed to differ in. Materials and pictures are outside this tool.

Exit 0 when everything but tangents matches within tolerance.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_cast_tangents import DTYPES, WIDTHS, Model  # noqa: E402

TOLERANCE = 2e-6


def accessor(model: Model, index: int) -> np.ndarray:
    """Like Model.array, but sparse accessors (morph targets) are expanded."""
    entry = model.doc["accessors"][index]
    if "sparse" not in entry:
        return model.array(index)
    dtype = np.dtype(DTYPES[entry["componentType"]])
    width = WIDTHS[entry["type"]]
    plain = dict(entry)
    plain.pop("sparse")
    model.doc["accessors"].append(plain)
    values = model.array(len(model.doc["accessors"]) - 1)
    model.doc["accessors"].pop()
    sparse = entry["sparse"]

    def block(view_index, offset, count, kind, columns):
        view = model.doc["bufferViews"][view_index]
        start = view.get("byteOffset", 0) + offset
        return np.frombuffer(model.buffers[view.get("buffer", 0)], dtype=kind, count=count * columns, offset=start).reshape(count, columns)

    where = block(sparse["indices"]["bufferView"], sparse["indices"].get("byteOffset", 0), sparse["count"], np.dtype(DTYPES[sparse["indices"]["componentType"]]), 1).ravel()
    values[where] = block(sparse["values"]["bufferView"], sparse["values"].get("byteOffset", 0), sparse["count"], dtype, width)
    return values


def expand(model: Model) -> dict:
    """Every mesh, by the name of the node that carries it, as per-corner arrays."""
    document = model.doc
    names = [node.get("name", "") for node in document.get("nodes", [])]
    out = {}
    for node in document.get("nodes", []):
        if "mesh" not in node:
            continue
        mesh = document["meshes"][node["mesh"]]
        joints = [names[j] for j in document["skins"][node["skin"]]["joints"]] if "skin" in node else []
        shapes = mesh.get("extras", {}).get("targetNames", [])
        corners: dict[str, list] = {}
        for primitive in mesh["primitives"]:
            index = model.array(primitive["indices"]).astype(int).ravel()
            for key, number in primitive["attributes"].items():
                values = accessor(model, number)
                if key.startswith("JOINTS_"):
                    continue
                if key.startswith("WEIGHTS_"):
                    bones = accessor(model, primitive["attributes"]["JOINTS_" + key[8:]]).astype(int)
                    table = np.zeros((len(values), max(len(joints), 1)))
                    for column in range(values.shape[1]):
                        np.add.at(table, (np.arange(len(values)), bones[:, column]), values[:, column])
                    corners.setdefault("weights", []).append(table[index])
                    continue
                corners.setdefault(key, []).append(values[index])
            for target_number, target in enumerate(primitive.get("targets", [])):
                label = shapes[target_number] if target_number < len(shapes) else "target_%d" % target_number
                for key, number in target.items():
                    corners.setdefault("morph %s %s" % (label, key), []).append(accessor(model, number)[index])
        out[node.get("name", mesh.get("name", "?"))] = {"joints": joints, "corners": {key: np.concatenate(parts) for key, parts in corners.items()},
                                                       "points": sum(document["accessors"][p["attributes"]["POSITION"]]["count"] for p in mesh["primitives"])}
    return out


def skins(model: Model) -> dict:
    document = model.doc
    out = {}
    for skin in document.get("skins", []):
        inverse = accessor(model, skin["inverseBindMatrices"]).reshape(-1, 16)
        for position, joint in enumerate(skin["joints"]):
            node = document["nodes"][joint]
            out[node.get("name", "")] = {"inverse_bind": inverse[position], "translation": np.array(node.get("translation", [0, 0, 0]), float),
                                         "rotation": np.array(node.get("rotation", [0, 0, 0, 1]), float), "scale": np.array(node.get("scale", [1, 1, 1]), float),
                                         "order": position, "children": sorted(document["nodes"][c].get("name", "") for c in node.get("children", []))}
    return out


def compare(control_path: str, candidate_path: str, ignore: tuple = ()) -> dict:
    control, candidate = Model(control_path), Model(candidate_path)
    a, b = expand(control), expand(candidate)
    problems = []
    rows = []
    for name in sorted(set(a) | set(b)):
        if name in ignore:
            continue
        if name not in a or name not in b:
            problems.append("%s: present in only one export" % name)
            continue
        left, right = a[name], b[name]
        row = {"mesh": name, "control_points": left["points"], "candidate_points": right["points"], "corners": int(len(left["corners"].get("POSITION", []))),
               "morph_targets": sorted({key.split(" ")[1] for key in left["corners"] if key.startswith("morph ")})}
        if left["joints"] != right["joints"]:
            problems.append("%s: joint lists differ" % name)
        for key in sorted(set(left["corners"]) | set(right["corners"])):
            if key not in left["corners"] or key not in right["corners"]:
                problems.append("%s: %s present in only one export" % (name, key))
                continue
            x, y = left["corners"][key], right["corners"][key]
            if x.shape != y.shape:
                problems.append("%s: %s has %s corners against %s" % (name, key, x.shape, y.shape))
                continue
            worst = float(np.max(abs(x - y))) if x.size else 0.0
            if key == "TANGENT":
                row["tangent_corners_changed"] = int(np.any(abs(x - y) > 1e-4, axis=1).sum())
                row["tangent_sign_flipped"] = int((np.sign(x[:, 3]) != np.sign(y[:, 3])).sum())
            elif worst > TOLERANCE:
                problems.append("%s: %s differs by up to %.3g" % (name, key, worst))
        rows.append(row)
    left, right = skins(control), skins(candidate)
    if sorted(left) != sorted(right):
        problems.append("skeletons name different joints")
    for joint in sorted(set(left) & set(right)):
        for key in ("inverse_bind", "translation", "rotation", "scale"):
            if float(np.max(abs(left[joint][key] - right[joint][key]))) > TOLERANCE:
                problems.append("joint %s: %s differs" % (joint, key))
        if left[joint]["order"] != right[joint]["order"] or left[joint]["children"] != right[joint]["children"]:
            problems.append("joint %s: order or children differ" % joint)
    return {"control": str(control_path), "candidate": str(candidate_path), "tolerance": TOLERANCE, "meshes": rows, "joints": len(left),
            "control_points": sum(row["control_points"] for row in rows), "candidate_points": sum(row["candidate_points"] for row in rows),
            "problems": problems, "status": "PASS" if not problems else "FAIL"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("control")
    parser.add_argument("candidate")
    parser.add_argument("--report")
    parser.add_argument("--ignore", nargs="*", default=[], help="mesh nodes left out of the comparison, by name")
    args = parser.parse_args()
    report = compare(args.control, args.candidate, tuple(args.ignore))
    report["ignored"] = list(args.ignore)
    if args.report:
        Path(args.report).write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("status", "joints", "control_points", "candidate_points")}))
    for problem in report["problems"][:40]:
        print("  " + problem)
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
