"""Cast intake tools on small made-up models: the tangent rule, the corner-by-corner comparison, shared pictures."""
import base64
import json
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "art/tools"))
import cast_intake  # noqa: E402
import check_cast_tangents  # noqa: E402
import compare_cast_exports  # noqa: E402

POINTS = np.array([[-0.5, -0.5, 0], [0.5, -0.5, 0], [0.5, 0.5, 0], [-0.5, 0.5, 0]], "<f4")
# u runs right and v runs DOWN the picture, as in the engine.
UVS = np.array([[0, 1], [1, 1], [1, 0], [0, 0]], "<f4")
TRIANGLES = np.array([[0, 1, 2], [0, 2, 3]])


def model(path, sign=1.0, split=False, nudge=0.0, morph=None, material="cast_someone_cloth", pictures=("a.png", "b.png", "c.png")):
    """A unit quad facing +z. `split` writes one point per corner instead of sharing them."""
    order = TRIANGLES.ravel() if split else np.arange(4)
    position = POINTS[order].copy()
    position[0, 0] += nudge
    normal = np.tile(np.array([[0, 0, 1]], "<f4"), (len(order), 1))
    uv = UVS[order]
    tangent = np.tile(np.array([[1, 0, 0, sign]], "<f4"), (len(order), 1))
    index = (np.arange(6) if split else TRIANGLES.ravel()).astype("<u2")
    blocks = [position.tobytes(), normal.tobytes(), uv.tobytes(), tangent.tobytes(), index.tobytes()]
    accessors = [{"componentType": 5126, "count": len(order), "type": "VEC3", "min": position.min(0).tolist(), "max": position.max(0).tolist()},
                 {"componentType": 5126, "count": len(order), "type": "VEC3"}, {"componentType": 5126, "count": len(order), "type": "VEC2"},
                 {"componentType": 5126, "count": len(order), "type": "VEC4"}, {"componentType": 5123, "count": 6, "type": "SCALAR"}]
    primitive = {"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2, "TANGENT": 3}, "indices": 4, "material": 0}
    mesh = {"name": "Quad", "primitives": [primitive]}
    if morph is not None:
        delta = np.zeros((4, 3), "<f4")
        delta[2] = morph
        blocks.append(delta[order].tobytes())
        accessors.append({"componentType": 5126, "count": len(order), "type": "VEC3", "min": delta.min(0).tolist(), "max": delta.max(0).tolist()})
        primitive["targets"] = [{"POSITION": 5}]
        mesh["extras"] = {"targetNames": ["jawOpen"]}
    views = []
    offset = 0
    for number, block in enumerate(blocks):
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(block)})
        accessors[number]["bufferView"] = number
        offset += len(block) + (-len(block)) % 4
    data = b"".join(block + b"\0" * ((-len(block)) % 4) for block in blocks)
    document = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "Quad"}], "meshes": [mesh],
                "buffers": [{"byteLength": len(data), "uri": "data:application/octet-stream;base64," + base64.b64encode(data).decode()}],
                "bufferViews": views, "accessors": accessors,
                "materials": [{"name": material, "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicRoughnessTexture": {"index": 1}},
                               "normalTexture": {"index": 2}}],
                "textures": [{"source": 0}, {"source": 1}, {"source": 2}], "images": [{"uri": name} for name in pictures]}
    Path(path).write_text(json.dumps(document), encoding="utf-8")


def picture(path, shade):
    row = b"\x00" + bytes([shade, shade, shade]) * 4

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * 4)) + chunk(b"IEND", b""))


class CastTangents(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)

    def tearDown(self):
        self.folder.cleanup()

    def test_the_engine_sign_passes_and_the_opposite_sign_fails(self):
        model(self.root / "plus.gltf", sign=1.0)
        model(self.root / "minus.gltf", sign=-1.0)
        self.assertEqual(check_cast_tangents.check(self.root / "plus.gltf", 0.5)["status"], "PASS")
        minus = check_cast_tangents.check(self.root / "minus.gltf", 0.5)
        self.assertEqual(minus["status"], "FAIL")
        self.assertEqual(minus["primitives"][0]["wrong_handed_corners"], 6)

    def test_shared_points_are_not_a_failure(self):
        model(self.root / "shared.gltf")
        report = check_cast_tangents.check(self.root / "shared.gltf", 0.5)
        self.assertEqual((report["vertices"], report["triangles"], report["status"]), (4, 2, "PASS"))


class CompareExports(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)

    def tearDown(self):
        self.folder.cleanup()

    def test_a_split_export_equals_a_shared_one_corner_for_corner(self):
        model(self.root / "split.gltf", split=True, sign=-1.0, morph=[0, 0.25, 0])
        model(self.root / "shared.gltf", split=False, sign=1.0, morph=[0, 0.25, 0])
        report = compare_cast_exports.compare(self.root / "split.gltf", self.root / "shared.gltf")
        self.assertEqual(report["status"], "PASS", report["problems"])
        self.assertEqual((report["control_points"], report["candidate_points"]), (6, 4))
        self.assertEqual(report["meshes"][0]["tangent_sign_flipped"], 6)
        self.assertEqual(report["meshes"][0]["morph_targets"], ["jawOpen"])

    def test_a_moved_point_or_a_changed_face_shape_is_caught(self):
        model(self.root / "control.gltf", morph=[0, 0.25, 0])
        model(self.root / "moved.gltf", nudge=0.001, morph=[0, 0.25, 0])
        model(self.root / "reshaped.gltf", morph=[0, 0.26, 0])
        self.assertEqual(compare_cast_exports.compare(self.root / "control.gltf", self.root / "moved.gltf")["status"], "FAIL")
        problems = compare_cast_exports.compare(self.root / "control.gltf", self.root / "reshaped.gltf")["problems"]
        self.assertTrue(any("morph jawOpen POSITION" in problem for problem in problems), problems)


class SharedPictures(unittest.TestCase):
    def test_identical_pictures_are_kept_once_and_models_follow(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            for who, shade in (("ann", 10), ("bob", 20)):
                (out / who).mkdir()
                model(out / who / (who + ".gltf"), material="cast_%s_cloth" % who, pictures=("teeth.png", "own.png", "flat.png"))
                picture(out / who / "teeth.png", 200)          # the same for both
                picture(out / who / "flat.png", 128)           # the same for both
                picture(out / who / "own.png", shade)          # each their own
            result = cast_intake.share_pictures(out, ["ann", "bob"])
            self.assertEqual(result, {"pictures_kept_once": 2, "copies_removed": 4})
            for who in ("ann", "bob"):
                uris = [image["uri"] for image in json.loads((out / who / (who + ".gltf")).read_text(encoding="utf-8"))["images"]]
                self.assertTrue(uris[0].startswith("../shared/") and uris[2].startswith("../shared/") and uris[1] == "own.png", uris)
                self.assertTrue((out / who / uris[0]).resolve().is_file())
                self.assertFalse((out / who / "teeth.png").exists())
            self.assertEqual(sorted(cast_intake.recipes(out)), ["cast_ann_cloth", "cast_bob_cloth"])


if __name__ == "__main__":
    unittest.main()
