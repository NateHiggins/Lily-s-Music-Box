"""Select exact shipping faces for the entrance rebuild; never rewrite a cell.

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
from types import SimpleNamespace

import numpy as np
from mathutils.kdtree import KDTree

# --root permits review from a private report folder; installed use discovers root.
import argparse
import sys
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--root", type=Path)
parser.add_argument("--out", type=Path)
parser.add_argument("--spec", type=Path)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
args = parser.parse_args(argv)
ROOT = args.root.resolve() if args.root else next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
assert (ROOT / "game/project.godot").is_file(), ROOT
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
    spec_path = args.spec.resolve() if args.spec else ROOT / "game/data/orison_v2/harukiya_entry.json"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    layout_path = ROOT / "game/data/building_layout.json"
    layout = json.loads(layout_path.read_text(encoding="utf-8"))
    floor = next(f for f in layout["floors"] if f["id"] == "F01")
    rows = {r["id"]: r for r in floor["furniture"]}
    assert spec.get("schema_version") == 1
    assert spec["retire_ids"] and all(isinstance(k, str) for k in spec["retire_ids"])
    assert len(set(spec["retire_ids"])) == len(spec["retire_ids"])
    assert not spec.get("retire_components"), "Entry selector permits only whole explicitly named stocks"
    assert len(rows) == len(floor["furniture"]), "Duplicate F01 source identities"
    assert [rows[k] for k in spec["retire_ids"]] == spec["source_records"]
    gltf_path = ROOT / "game/assets/building/floor_01_cells/shop_bar.gltf"
    bin_path = gltf_path.with_suffix(".bin")
    doc = json.loads(gltf_path.read_text(encoding="utf-8"))
    binary = bin_path.read_bytes()
    assert len(doc["buffers"]) == 1 and doc["buffers"][0]["uri"] == bin_path.name
    assert int(doc["buffers"][0]["byteLength"]) == len(binary)
    assert all(not any(k in n for k in ["translation", "rotation", "scale", "matrix"]) for n in doc["nodes"]), "Shipping cell must stay in its original flat source frame"

    def values(index):
        a = doc["accessors"][index]
        assert not a.get("sparse") and not a.get("normalized"), "Unsupported shipping accessor"
        view = doc["bufferViews"][a["bufferView"]]
        assert view.get("buffer", 0) == 0, "Shipping cell must use its pinned buffer"
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
        assert p.get("mode", 4) == 4 and not p.get("targets"), "Static triangle cell expected"
        assert node["name"] not in draws, "Duplicate shipping draw name"
        vertices = values(p["attributes"]["POSITION"])
        indices = values(p["indices"]).astype(int).reshape((-1, 3))
        draws[node["name"]] = {"vertices": vertices, "indices": indices,
                               "selected": np.zeros(len(indices), dtype=bool), "owners": {}}

    requests = [{"id": k} for k in spec["retire_ids"]]
    stock_counts = {}
    for request in requests:
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
            expected = sum(len(face) - 2 for face in buffer.faces)
            if expected == 0: counts[key] = 0; continue
            kd = KDTree(len(buffer.verts))
            for i, (x, y, z) in enumerate(buffer.verts): kd.insert((x, z, -y), i)
            kd.balance()
            tokens = [tuple((x, z, -y)) for x, y, z in buffer.verts]
            polygons = {}
            for face in buffer.faces:
                polygon = frozenset(tokens[i] for i in face)
                assert len(polygon) == len(face), ("Degenerate source polygon", row["id"], key)
                polygons[polygon] = polygons.get(polygon, 0) + len(face) - 2
            polygon_counts = {polygon: 0 for polygon in polygons}
            matches = []
            for name, draw in draws.items():
                wanted = "furnish" if assembly and not row.get("batch") else (
                    source.furniture_batch_prefix(row["batch"]) if row.get("batch") else "retail_bar")
                suffix = "hull-colonly" if key == "hull" else key
                if not name.endswith("_" + wanted + "_" + suffix) and not name.endswith("_" + wanted + "_" + suffix + "-col"):
                    continue
                nearest = [kd.find(v) for v in draw["vertices"]]
                selected = np.array([found[2] < .00003 for found in nearest])
                hit = selected[draw["indices"]].all(axis=1)
                for triangle_index in np.flatnonzero(hit):
                    corners = frozenset(tokens[nearest[int(i)][1]] for i in draw["indices"][triangle_index])
                    possible = [polygon for polygon in polygons if corners <= polygon]
                    assert len(corners) == 3 and len(possible) == 1, (
                        "Ambiguous reconstructed polygon", row["id"], key, name, int(triangle_index))
                    polygon_counts[possible[0]] += 1
                if hit.any(): matches.append((name, hit))
            assert polygon_counts == polygons, ("Reconstructed polygon multiplicity mismatch", row["id"], key)
            actual = sum(int(mask.sum()) for _, mask in matches)
            assert actual == expected, (row["id"], key, expected, actual)
            for name, hit in matches:
                draw = draws[name]
                assert not np.any(draw["selected"] & hit), ("duplicate stock selection", row["id"], name)
                draw["selected"] |= hit
                draw["owners"][row["id"]] = int(hit.sum())
            counts[key] = actual
        assert sum(counts.values()) > 0, ("Empty stock", row["id"])
        stock_counts[row["id"]] = counts

    retirement = []
    for name, draw in draws.items():
        if not draw["selected"].any(): continue
        triangles = draw["vertices"][draw["indices"][draw["selected"]]]
        retirement.append({"name": name.removesuffix("-colonly").removesuffix("-col"),
                           "source_name": name, "hull_only": name.endswith("-colonly"),
                           "colliding": name.endswith("-col"), "source_triangles": len(draw["indices"]),
                           "count": len(triangles), "owners": draw["owners"], "triangles": triangles.tolist(),
                           "retained_triangles": int((~draw["selected"]).sum()),
                           "retained_position_stream_sha256": hashlib.sha256(
                               np.asarray(draw["vertices"][draw["indices"][~draw["selected"]]], dtype="<f4").tobytes()).hexdigest()})
    out = {"schema_version": 1, "source_records": [rows[r["id"]] for r in requests],
           "geometry_source_sha256": hashlib.sha256(GEOMETRY_SOURCE.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
           "source_cell_sha256": hashlib.sha256(gltf_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
           "source_buffer_sha256": hashlib.sha256(binary).hexdigest(),
           "spec_sha256": hashlib.sha256(spec_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
           "layout_sha256": hashlib.sha256(layout_path.read_bytes().replace(b"\r\n", b"\n")).hexdigest(),
           "stock_counts": stock_counts, "retirement": retirement,
           "unchanged_draws": [{"name": name, "source_triangles": len(draw["indices"])}
                               for name, draw in draws.items() if not draw["selected"].any()]}
    assert sum(sum(counts.values()) for counts in stock_counts.values()) == sum(r["count"] for r in retirement)
    assert retirement and len({r["name"] for r in retirement}) == len(retirement), "Ambiguous loaded node names"
    target = args.out.resolve() if args.out else ROOT / "game/data/orison_v2/harukiya_entry_retirement.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    assert not target.exists(), "Use a fresh --out and review before replacing existing retirement evidence"
    target.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("HARUKIYA ENTRY SOURCE", len(requests), "stocks", len(retirement), "draws",
          sum(r["count"] for r in retirement), "exact triangles")



if __name__ == "__main__": build()
