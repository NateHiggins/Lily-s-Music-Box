"""Tangent check for skinned cast models. CPU only; reads .gltf (with its .bin) or .glb.

    python art/tools/check_cast_tangents.py <model.gltf|model.glb> [...] [--min-agreement 0.5] [--report out.json]

Props are held to art/blender/scripts/check_exported_tangents.py: every corner's
tangent must match its own triangle's UV derivative almost exactly, which only a
mesh split at every corner can do. A body is a smooth, skinned, morphing surface;
split that way it carries four times the points (measured: 34,745 against
144,717 on one body) for no change a viewer can see. The rule here is the one a
smooth surface can meet and a normal map needs:

  - every normal and tangent finite and of unit length;
  - handedness right at every corner, by the engine's own convention: the binormal
    cross(normal, tangent) * w points up the picture, toward falling v. That is what
    Godot's tangent generator makes (game/tests/tangent_convention_test.gd holds it)
    and what Blender's exporter writes. A wrong sign lights a normal map as if from
    below. (The props' checker accepts the opposite sign; that is its owner's to settle.)
  - each corner's tangent within a stated angle of its triangle's UV derivative
    (--min-agreement is the cosine; 0.5 is sixty degrees).

It reports how far the tangents sit from the strict rule, so a reviewer sees
what was traded. It accepts nothing about appearance.
"""
import argparse
import base64
import json
import struct
from pathlib import Path

import numpy as np

DTYPES = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Model:
    def __init__(self, path):
        self.path = Path(path)
        raw = self.path.read_bytes()
        if self.path.suffix.lower() == ".glb":
            magic, version, size = struct.unpack_from("<III", raw)
            if (magic, version, size) != (0x46546C67, 2, len(raw)):
                raise ValueError("not a GLB: %s" % path)
            chunks = {}
            offset = 12
            while offset < len(raw):
                length, kind = struct.unpack_from("<II", raw, offset)
                chunks[kind] = raw[offset + 8:offset + 8 + length]
                offset += 8 + length
            self.doc = json.loads(chunks[0x4E4F534A])
            self.buffers = [chunks.get(0x004E4942, b"")]
        else:
            self.doc = json.loads(raw)
            self.buffers = []
            for buffer in self.doc.get("buffers", []):
                uri = buffer.get("uri", "")
                if uri.startswith("data:"):
                    self.buffers.append(base64.b64decode(uri.split(",", 1)[1]))
                else:
                    self.buffers.append((self.path.parent / uri).read_bytes())

    def array(self, index):
        accessor = self.doc["accessors"][index]
        dtype = np.dtype(DTYPES[accessor["componentType"]])
        width = WIDTHS[accessor["type"]]
        count = accessor["count"]
        if "bufferView" in accessor:
            view = self.doc["bufferViews"][accessor["bufferView"]]
            start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", width * dtype.itemsize)
            values = np.ndarray((count, width), dtype=dtype, buffer=self.buffers[view.get("buffer", 0)], offset=start,
                                strides=(stride, dtype.itemsize)).astype(float)
        else:
            values = np.zeros((count, width))
        if "sparse" in accessor:
            raise ValueError("sparse base attributes are not expected on a cast model")
        return values


def check(path, min_agreement):
    model = Model(path)
    rows = []
    failures = []
    for mesh in model.doc.get("meshes", []):
        for number, primitive in enumerate(mesh["primitives"]):
            attributes = primitive["attributes"]
            name = "%s[%d]" % (mesh.get("name", "?"), number)
            missing = [key for key in ("POSITION", "NORMAL", "TEXCOORD_0", "TANGENT") if key not in attributes]
            if missing or "indices" not in primitive or primitive.get("mode", 4) != 4:
                failures.append("%s: needs indexed triangles with position, normal, UV and tangent (missing %s)" % (name, missing))
                continue
            p, n, uv, t = (model.array(attributes[key]) for key in ("POSITION", "NORMAL", "TEXCOORD_0", "TANGENT"))
            index = model.array(primitive["indices"]).astype(int).reshape(-1, 3)
            if not all(np.isfinite(a).all() for a in (p, n, uv, t)):
                failures.append(name + ": a value is not finite")
                continue
            if np.max(abs(np.linalg.norm(n, axis=1) - 1)) > 0.001 or np.max(abs(np.linalg.norm(t[:, :3], axis=1) - 1)) > 0.001:
                failures.append(name + ": a normal or tangent is not of unit length")
                continue
            points, tex = p[index], uv[index]
            a, b = tex[:, 1] - tex[:, 0], tex[:, 2] - tex[:, 0]
            det = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
            flat = abs(det) <= 1e-12
            safe = np.where(flat, 1.0, det)
            du = ((points[:, 1] - points[:, 0]) * b[:, 1, None] - (points[:, 2] - points[:, 0]) * a[:, 1, None]) / safe[:, None]
            dv = ((points[:, 2] - points[:, 0]) * a[:, 0, None] - (points[:, 1] - points[:, 0]) * b[:, 0, None]) / safe[:, None]
            normals, actual = n[index], t[index, :3]
            expected = du[:, None, :] - normals * np.sum(du[:, None, :] * normals, axis=2)[:, :, None]
            length = np.linalg.norm(expected, axis=2)
            usable = (~flat)[:, None] & (length > 1e-12)
            expected = expected / np.where(length > 1e-12, length, 1.0)[:, :, None]
            agreement = np.where(usable, np.sum(expected * actual, axis=2), 1.0)
            # Positive when the binormal points toward falling v (up the picture), the engine's convention.
            handed = np.where(usable, -np.sum(np.cross(normals, actual) * dv[:, None, :], axis=2) * t[index, 3], 1.0)
            row = {"primitive": name, "vertices": int(len(p)), "triangles": int(len(index)), "corners_per_vertex": round(index.size / max(len(p), 1), 3),
                   "collapsed_uv_triangles": int(flat.sum()), "wrong_handed_corners": int((handed < -1e-9).sum()),
                   # Neither sign is right where the binormal has no component along the picture's height.
                   "undetermined_handed_corners": int((abs(handed) <= 1e-9).sum()),
                   "minimum_agreement": round(float(agreement.min()), 5), "agreement_1st_percentile": round(float(np.percentile(agreement, 1)), 5),
                   "median_agreement": round(float(np.median(agreement)), 5), "corners_below_strict_0_999": int((agreement <= 0.999).sum()),
                   "corners_below_minimum": int((agreement < min_agreement).sum()), "morph_targets": len(primitive.get("targets", []))}
            rows.append(row)
            if row["wrong_handed_corners"]:
                failures.append("%s: %d corners have the wrong handedness" % (name, row["wrong_handed_corners"]))
            if row["corners_below_minimum"]:
                failures.append("%s: %d corners are further than the allowed angle from their triangle's UV derivative (worst %.3f)"
                                % (name, row["corners_below_minimum"], row["minimum_agreement"]))
    return {"asset": str(path), "minimum_agreement_required": min_agreement, "primitives": rows,
            "vertices": sum(row["vertices"] for row in rows), "triangles": sum(row["triangles"] for row in rows),
            "failures": failures, "status": "PASS" if not failures else "FAIL"}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("models", nargs="+")
    parser.add_argument("--min-agreement", type=float, default=0.5)
    parser.add_argument("--report")
    args = parser.parse_args()
    reports = [check(path, args.min_agreement) for path in args.models]
    if args.report:
        Path(args.report).write_text(json.dumps(reports, indent=1) + "\n", encoding="utf-8")
    for report in reports:
        print(json.dumps({key: report[key] for key in ("asset", "vertices", "triangles", "status")}))
        for failure in report["failures"]:
            print("  " + failure)
    return 1 if any(report["status"] != "PASS" for report in reports) else 0


if __name__ == "__main__":
    raise SystemExit(main())
