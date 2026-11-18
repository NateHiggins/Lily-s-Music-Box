"""Select exact shipping faces for the destination rebuild; never rewrite a cell.

Run with Blender Python, definitions only. Geometry is recovered from each named
source stock, then matched to the immutable exported cell. Missing/ambiguous
stocks refuse rather than turning a spatial box into permission to erase faces.
"""
from pathlib import Path
import hashlib
import json
import ast
import math
import zlib
import re
from collections import Counter
from types import SimpleNamespace

import numpy as np
from mathutils.kdtree import KDTree

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
GEOMETRY_SOURCE = ROOT / "art/blender/scripts/build_orison.py"
# Extract the existing geometry definitions as other native builders do. This
# job emits no materials, imports no scene and does not run the obsolete global
# material validator/build. Every recovered face still has to match shipping
# geometry exactly; new surfaces use the separate current catalogue pipeline.
tree = ast.parse(GEOMETRY_SOURCE.read_text(encoding="utf-8"))
namespace = {"math": math, "zlib": zlib}
definitions = [n for n in tree.body if isinstance(n, (ast.ClassDef, ast.FunctionDef))]
exec(compile(ast.Module(body=definitions, type_ignores=[]), str(GEOMETRY_SOURCE), "exec"), namespace)
namespace["ASM"] = {k.removeprefix("asm_"): v for k, v in namespace.items() if k.startswith("asm_")}
source = SimpleNamespace(**namespace)


def build():
    spec_path = ROOT / "game/data/orison_v2/harukiya_destination_layout.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    layout_path = ROOT / "game/data/building_layout.json"
    layout = json.loads(layout_path.read_text(encoding="utf-8"))
    floor = next(f for f in layout["floors"] if f["id"] == "F01")
    rows = {r["id"]: r for r in floor["furniture"]}
    assert len(set(spec["retire_ids"])) == len(spec["retire_ids"])
    assert [rows[k] for k in spec["retire_ids"]] == spec["source_records"]
    gltf_path = ROOT / "game/assets/building/floor_01_cells/shop_bar.gltf"
    bin_path = gltf_path.with_suffix(".bin")
    doc = json.loads(gltf_path.read_text(encoding="utf-8"))
    binary = bin_path.read_bytes()

    def values(index):
        a = doc["accessors"][index]; view = doc["bufferViews"][a["bufferView"]]
        dtype = np.dtype({5123: "<u2", 5125: "<u4", 5126: "<f4"}[a["componentType"]])
        width = {"SCALAR": 1, "VEC3": 3}[a["type"]]
        return np.ndarray((a["count"], width), dtype=dtype, buffer=binary,
                          offset=view.get("byteOffset", 0) + a.get("byteOffset", 0),
                          strides=(view.get("byteStride", dtype.itemsize * width), dtype.itemsize)).copy()

    draws = {}
    for node in doc["nodes"]:
        if "mesh" not in node: continue
        assert not any(k in node for k in ["translation", "rotation", "scale", "matrix"]), node["name"]
        mesh = doc["meshes"][node["mesh"]]
        assert len(mesh["primitives"]) == 1
        p = mesh["primitives"][0]
        vertices = values(p["attributes"]["POSITION"])
        indices = values(p["indices"]).astype(int).reshape((-1, 3))
        draws[node["name"]] = {"vertices": vertices, "indices": indices,
                               "selected": np.zeros(len(indices), dtype=bool), "owners": {}}

    requests = [{"id": k} for k in spec["retire_ids"]]
    requests.extend(spec.get("retire_components", []))
    support_seats = [s for s in spec["seats"] if re.fullmatch(r"retail_bar_stool\d+_seat", s["support"])]
    assert len(support_seats) == 5 and len({s["support"] for s in support_seats}) == 5
    support_requests = [{"id": s["support"], "seat_id": s["id"], "support_only": True} for s in support_seats]
    for seat in support_seats:
        row = rows[seat["support"]]
        assert row["asm"] == "pipe" and not row.get("local") and row["p1"] == seat["at"]
        assert row["id"] not in {r["id"] for r in requests}
    seat_supports = []
    support_selected = {}
    stock_counts = {}
    for request in requests + support_requests:
        row = rows[request["id"]]
        buffers = {}
        assembly = "asm" in row
        def buf(key):
            if key not in buffers: buffers[key] = source.MeshBuf("Probe_" + key, key if key != "hull" else "slab")
            return buffers[key]
        if assembly:
            frame = source.Frame(buf, lambda: buf("hull"), row["at"][0], row["at"][1],
                                 float(floor["z"]) + row.get("z0", 0), row.get("yaw", 0), 0.)
            source.ASM[row["asm"]](frame, row)
        else:
            r = row["rect"]; z = float(floor["z"]) + row.get("z0", 0)
            buf(row["mat"]).add_box((r[0], r[1], z), (r[2], r[3], z + row["h"]))
        counts = {}
        for key, buffer in buffers.items():
            keys = request.get("keys")
            if request.get("component") == "collision_hull_only": keys = ["hull"]
            if keys is not None and key not in keys: continue
            expected = sum(len(face) - 2 for face in buffer.faces)
            if expected == 0: counts[key] = 0; continue
            kd = KDTree(len(buffer.verts))
            for i, (x, y, z) in enumerate(buffer.verts): kd.insert((x, z, -y), i)
            kd.balance()
            matches = []
            for name, draw in draws.items():
                wanted = "furnish" if assembly and not row.get("batch") else (
                    source.furniture_batch_prefix(row["batch"]) if row.get("batch") else "retail_bar")
                suffix = "hull-colonly" if key == "hull" else key
                if not name.endswith("_" + wanted + "_" + suffix) and not name.endswith("_" + wanted + "_" + suffix + "-col"):
                    continue
                selected = np.array([kd.find(v)[2] < .00003 for v in draw["vertices"]])
                hit = selected[draw["indices"]].all(axis=1)
                if hit.any(): matches.append((name, hit))
            actual = sum(int(mask.sum()) for _, mask in matches)
            assert actual == expected, (row["id"], key, expected, actual)
            for name, hit in matches:
                draw = draws[name]
                assert not np.any(draw["selected"] & hit), ("duplicate stock selection", row["id"], name)
                if request.get("support_only"):
                    assert key != "hull" and not name.endswith(("-col", "-colonly")), ("support already collides", name)
                    selected = support_selected.setdefault(name, np.zeros(len(hit), dtype=bool))
                    assert not np.any(selected & hit), ("duplicate support faces", row["id"])
                    selected |= hit
                    triangles = draw["vertices"][draw["indices"][hit]]
                    edges = Counter()
                    for triangle in triangles:
                        corners = [tuple(float(v) for v in p) for p in triangle]
                        for a, b in zip(corners, corners[1:] + corners[:1]):
                            assert a != b
                            edges[tuple(sorted((a, b)))] += 1
                    assert edges and all(count == 2 for count in edges.values()), ("support is not closed", row["id"])
                    seat_supports.append({"id": row["id"], "seat_id": request["seat_id"],
                                          "name": name, "count": len(triangles), "closed": True,
                                          "triangles": triangles.tolist()})
                else:
                    draw["selected"] |= hit
                    draw["owners"][row["id"]] = int(hit.sum())
            counts[key] = actual
        if not request.get("support_only"): stock_counts[row["id"]] = counts
    assert len(seat_supports) == 5

    retirement = []
    for name, draw in draws.items():
        if not draw["selected"].any(): continue
        triangles = draw["vertices"][draw["indices"][draw["selected"]]]
        retirement.append({"name": name.removesuffix("-colonly").removesuffix("-col"),
                           "source_name": name, "hull_only": name.endswith("-colonly"),
                           "colliding": name.endswith("-col"), "source_triangles": len(draw["indices"]),
                           "count": len(triangles), "owners": draw["owners"], "triangles": triangles.tolist()})
    out = {"schema_version": 1, "source_records": [rows[r["id"]] for r in requests],
           "geometry_source_sha256": hashlib.sha256(GEOMETRY_SOURCE.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
           "source_cell_sha256": hashlib.sha256(gltf_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
           "source_buffer_sha256": hashlib.sha256(binary).hexdigest(),
           "stock_counts": stock_counts, "retirement": retirement,
           "support_source_records": [rows[r["id"]] for r in support_requests],
           "seat_supports": seat_supports}
    target = ROOT / "game/data/orison_v2/harukiya_destination_retirement.json"
    target.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("HARUKIYA DESTINATION SOURCE", len(requests), "stocks", len(retirement), "draws",
          sum(r["count"] for r in retirement), "exact triangles")
    print("HARUKIYA RETAINED SEAT SUPPORTS", len(seat_supports), "closed source stocks",
          sum(r["count"] for r in seat_supports), "exact matching rendered triangles; no visible geometry added")


if __name__ == "__main__": build()
