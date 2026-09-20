"""Read authored F01 collision triangles; write a new static-only receipt.

No Godot import, execution or live source mutation. Triangle AABB rejection is
conservative: zero overlaps proves only this exported collision mesh is clear,
not dynamically spawned props or a runtime physics result.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent


def inspect():
    paths = [ROOT / "game/data/building_layout.json",
             ROOT / "game/assets/building/floor_01.gltf",
             ROOT / "game/assets/building/floor_01.bin",
             ROOT / "game/scripts/characters/npc_placeholder.gd",
             ROOT / "game/scripts/characters/animated_resident.gd"]
    raw = {p: p.read_bytes() for p in paths}
    layout = json.loads(raw[paths[0]])
    gltf = json.loads(raw[paths[1]])
    binary = raw[paths[2]]
    assert gltf["buffers"] == [{"byteLength": len(binary), "uri": "floor_01.bin"}]
    floor = next(f for f in layout["floors"] if f["id"] == "F01")
    lobby = next(r for r in floor["rooms"] if r["id"] == "F01_LOBBY")
    x, z = 2.2, 8.3
    foot_y, radius, height, margin = 0.03, 0.28, 1.55, 0.05
    low = [x - radius - margin, foot_y, z - radius - margin]
    high = [x + radius + margin, foot_y + height, z + radius + margin]

    def values(index):
        accessor = gltf["accessors"][index]
        view = gltf["bufferViews"][accessor["bufferView"]]
        assert view.get("buffer", 0) == 0 and "sparse" not in accessor
        width = {"SCALAR": 1, "VEC3": 3}[accessor["type"]]
        fmt = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[accessor["componentType"]]
        size = struct.calcsize("<" + fmt * width)
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", size)
        return [struct.unpack_from("<" + fmt * width, binary, start + i * stride)
                for i in range(accessor["count"])]

    overlaps, support = [], []
    triangle_count = 0
    for node in gltf["nodes"]:
        # Current exporter uses flat identity scene nodes. Refuse silently
        # ignoring a future parent or transform rather than invent world data.
        assert not any(k in node for k in ["translation", "rotation", "scale", "matrix", "children"])
        if "-col" not in node.get("name", ""):
            continue
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            assert primitive.get("mode", 4) == 4
            vertices = values(primitive["attributes"]["POSITION"])
            indices = ([item[0] for item in values(primitive["indices"])]
                       if "indices" in primitive else list(range(len(vertices))))
            assert len(indices) % 3 == 0
            for i in range(0, len(indices), 3):
                a, b, c = [vertices[j] for j in indices[i:i + 3]]
                triangle_count += 1
                if all(max(t[k] for t in (a, b, c)) >= low[k]
                       and min(t[k] for t in (a, b, c)) <= high[k] for k in range(3)):
                    overlaps.append({"node": node["name"], "triangle_index": i // 3})
                denominator = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
                if abs(denominator) < 1e-8:
                    continue
                u = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / denominator
                v = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / denominator
                w = 1 - u - v
                y = u * a[1] + v * b[1] + w * c[1]
                if min(u, v, w) >= -1e-6 and -0.5 < y < 0.5:
                    support.append({"node": node["name"], "triangle_index": i // 3, "height": y})
    rect = lobby["rect"]
    footprint_in_lobby = (rect[0] < low[0] and high[0] < rect[2]
                          and rect[1] < -high[2] and -low[2] < rect[3])
    shaft = layout["elevator"]["shaft"]
    old_in_shaft = shaft[0] < 2.2 < shaft[2] and shaft[1] < -6.2 < shaft[3]
    return {
        "schema": "astra.resident-f01-haunt.static-geometry.v1",
        "scope": "Authored/exported geometry only; runtime collision and lifecycle remain UNRUN",
        "inputs": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[p]).hexdigest() for p in paths},
        "candidate_blender_xy": [x, -z], "candidate_godot": [x, foot_y, z],
        "lobby": lobby, "slabs": floor["slabs"], "shaft": shaft,
        "actual_body_source_dimensions": {"radius": radius, "height": height, "center_y": 0.775},
        "audit_box_extra_horizontal_margin": margin, "box_min": low, "box_max": high,
        "collision_triangles_examined": triangle_count, "triangle_aabb_overlaps": overlaps,
        "support_triangles": support, "whole_footprint_inside_lobby": footprint_in_lobby,
        "original_haunt_inside_shaft": old_in_shaft,
        "static_candidate_clear": footprint_in_lobby and not overlaps
        and any(s["node"] == "F01_slabs-col" and abs(s["height"]) < 1e-6 for s in support),
        "remaining": "Actual spawned prop/body queries, closed-landing F01 swept body path, real arrival/dwell/return and exact old-haunt omission",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", help="New receipt filename in this preparation directory")
    args = parser.parse_args()
    if Path(args.output).name != args.output:
        parser.error("use a plain new filename")
    result = inspect()
    with (BASE / args.output).open("x", encoding="utf-8") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print(json.dumps({key: result[key] for key in ["static_candidate_clear", "collision_triangles_examined",
        "triangle_aabb_overlaps", "support_triangles", "remaining"]}, indent=2))
    raise SystemExit(0 if result["static_candidate_clear"] else 1)
