#!/usr/bin/env python3
"""Paint a face: a transparent picture of lips, eye shadow, liner and rouge in a cast head's own texture space.

    python art/tools/cast_makeup.py <actor folder> <id> <name> [--lips r,g,b] [--shadow r,g,b] [--rouge r,g,b]
                                    [--liner r,g,b] [--lip-strength 0.85] [--shadow-strength 0.55] [--rouge-strength 0.28]

Reads <actor folder>/<id>.gltf and writes <actor folder>/<id>_makeup_<name>.png. The game lays that picture over
the head (cast_model_presentation.gd set_makeup), on the same mesh, so it moves with every expression.

Nothing is drawn by hand and no reference picture is used. Where the paint goes is read from the head itself:
  - lips: the points the lip-closing shape moves most;
  - eyelids: the points the two blink shapes move, strongest along the lash line (the liner);
  - rouge: on the cheek between the eye and the corner of the mouth.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

COMPONENT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
SIZE = 1024


class Model:
    def __init__(self, path: Path):
        self.path = path
        self.doc = json.loads(path.read_text(encoding="utf-8"))
        self.buffers = [(path.parent / buffer["uri"]).read_bytes() for buffer in self.doc["buffers"]]

    def array(self, index: int) -> np.ndarray:
        accessor = self.doc["accessors"][index]
        dtype = np.dtype("<" + COMPONENT[accessor["componentType"]])
        width = WIDTH[accessor["type"]]
        values = np.zeros((accessor["count"], width), dtype=np.float64)
        if "bufferView" in accessor:
            view = self.doc["bufferViews"][accessor["bufferView"]]
            start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            stride = view.get("byteStride", width * dtype.itemsize)
            values = np.ndarray((accessor["count"], width), dtype=dtype, buffer=self.buffers[view["buffer"]], offset=start, strides=(stride, dtype.itemsize)).astype(np.float64)
        if "sparse" in accessor:
            sparse = accessor["sparse"]
            index_view = self.doc["bufferViews"][sparse["indices"]["bufferView"]]
            index_type = np.dtype("<" + COMPONENT[sparse["indices"]["componentType"]])
            where = np.frombuffer(self.buffers[index_view["buffer"]], dtype=index_type, count=sparse["count"], offset=index_view.get("byteOffset", 0) + sparse["indices"].get("byteOffset", 0))
            value_view = self.doc["bufferViews"][sparse["values"]["bufferView"]]
            moved = np.frombuffer(self.buffers[value_view["buffer"]], dtype=dtype, count=sparse["count"] * width, offset=value_view.get("byteOffset", 0) + sparse["values"].get("byteOffset", 0))
            values = values.copy()
            values[where] = moved.reshape(sparse["count"], width)
        return values


def head_of(model: Model):
    for node in model.doc["nodes"]:
        if node.get("name") == "Skin_head" and "mesh" in node:
            mesh = model.doc["meshes"][node["mesh"]]
            names = (mesh.get("extras") or {}).get("targetNames", [])
            return mesh, names
    raise SystemExit("no Skin_head mesh in " + str(model.path))


def rasterise(uv: np.ndarray, triangles: np.ndarray, fields: np.ndarray) -> np.ndarray:
    """Per-point values laid into the picture, triangle by triangle."""
    out = np.zeros((SIZE, SIZE, fields.shape[1]), dtype=np.float32)
    pixel = uv * SIZE
    for a, b, c in triangles:
        pa, pb, pc = pixel[a], pixel[b], pixel[c]
        low = np.floor(np.minimum(np.minimum(pa, pb), pc)).astype(int) - 1
        high = np.ceil(np.maximum(np.maximum(pa, pb), pc)).astype(int) + 1
        low = np.clip(low, 0, SIZE - 1)
        high = np.clip(high, 0, SIZE - 1)
        if high[0] <= low[0] or high[1] <= low[1]:
            continue
        xs, ys = np.meshgrid(np.arange(low[0], high[0] + 1) + 0.5, np.arange(low[1], high[1] + 1) + 0.5)
        det = (pb[1] - pc[1]) * (pa[0] - pc[0]) + (pc[0] - pb[0]) * (pa[1] - pc[1])
        if abs(det) < 1e-9:
            continue
        wa = ((pb[1] - pc[1]) * (xs - pc[0]) + (pc[0] - pb[0]) * (ys - pc[1])) / det
        wb = ((pc[1] - pa[1]) * (xs - pc[0]) + (pa[0] - pc[0]) * (ys - pc[1])) / det
        wc = 1.0 - wa - wb
        inside = (wa >= -0.02) & (wb >= -0.02) & (wc >= -0.02)
        if not inside.any():
            continue
        value = wa[..., None] * fields[a] + wb[..., None] * fields[b] + wc[..., None] * fields[c]
        region = out[low[1]:high[1] + 1, low[0]:high[0] + 1]
        region[inside] = np.maximum(region[inside], value[inside])
    return out


def soften(layer: np.ndarray, radius: float) -> np.ndarray:
    picture = Image.fromarray(np.clip(layer * 255.0, 0, 255).astype(np.uint8))
    return np.asarray(picture.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255.0


def colour(text: str) -> np.ndarray:
    return np.array([float(part) for part in text.split(",")], dtype=np.float32)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("person")
    parser.add_argument("name")
    parser.add_argument("--lips", default="0.55,0.04,0.09")
    parser.add_argument("--shadow", default="0.12,0.1,0.12")
    parser.add_argument("--rouge", default="0.8,0.3,0.32")
    parser.add_argument("--liner", default="0.03,0.025,0.03")
    parser.add_argument("--lip-strength", type=float, default=0.85)
    parser.add_argument("--shadow-strength", type=float, default=0.55)
    parser.add_argument("--rouge-strength", type=float, default=0.28)
    parser.add_argument("--liner-strength", type=float, default=0.8)
    args = parser.parse_args()
    folder = Path(args.folder)
    model = Model(folder / (args.person + ".gltf"))
    mesh, names = head_of(model)
    lip_shape = next((name for name in ("viseme_PP", "mouthClose", "mouthPucker") if name in names), None)
    if lip_shape is None or "eyeBlinkLeft" not in names or "eyeBlinkRight" not in names:
        raise SystemExit("the head lacks the shapes the paint is placed by")
    layers = np.zeros((SIZE, SIZE, 4), dtype=np.float32)        # lips region, lid, lash line, rouge
    skin_picture = None
    for primitive in mesh["primitives"]:
        attributes = primitive["attributes"]
        points = model.array(attributes["POSITION"])
        uv = model.array(attributes["TEXCOORD_0"])[:, :2]
        triangles = model.array(primitive["indices"]).astype(int).reshape(-1, 3)
        targets = primitive.get("targets", [])

        def moved(name: str) -> np.ndarray:
            return np.linalg.norm(model.array(targets[names.index(name)]["POSITION"]), axis=1)

        lip_move = moved(lip_shape)
        # Every shape that works the lips, each as a share of its own largest movement: together they cover the
        # whole mouth, corner to corner, where one alone covers its middle.
        lip_any = np.zeros(len(points))
        for name in ("viseme_PP", "viseme_U", "viseme_O", "viseme_FF", "mouthPucker", "mouthFunnel"):
            if name in names:
                this = moved(name)
                lip_any = np.maximum(lip_any, this / max(this.max(), 1e-9))
        # Only the outside of the face: the head's mesh also holds the inside of the mouth and the eye sockets,
        # which the same shapes move and which are drawn on patches of their own. They lie behind the surface.
        lip_front = points[lip_move > 0.5 * lip_move.max(), 2].max()
        lips_near = np.clip(lip_any / 0.3, 0.0, 1.0) * (points[:, 2] > lip_front - 0.014)
        lids = np.zeros(len(points))
        for name in ("eyeBlinkLeft", "eyeBlinkRight"):
            blink = moved(name)
            most = blink > 0.5 * blink.max()
            eye_height = points[most, 1].mean()
            eye_front = points[most, 2].max()
            # The upper lid, from the lashes up toward the brow; not the lower lid, and not the socket behind.
            upper = np.clip((points[:, 1] - (eye_height - 0.003)) / 0.004, 0.0, 1.0) * (points[:, 2] > eye_front - 0.012)
            lids = np.maximum(lids, blink / max(blink.max(), 1e-9) * upper)
        lid = np.clip(lids / 0.18, 0.0, 1.0)
        lash = np.clip((lids - 0.6) / 0.4, 0.0, 1.0) ** 2
        # The cheek: between the eye and the mouth, out toward the side of the face. glTF: +X the left, +Y up, +Z the front.
        rouge = np.zeros(len(points))
        mouth = points[lip_move > 0.5 * lip_move.max()].mean(axis=0)
        for name, side in (("eyeBlinkLeft", 1.0), ("eyeBlinkRight", -1.0)):
            blink = moved(name)
            eye = points[blink > 0.5 * blink.max()].mean(axis=0)
            centre = eye + 0.52 * (mouth - eye)
            centre[0] = eye[0] * 1.28
            reach = np.linalg.norm((points - centre) * np.array([1.0, 1.25, 0.6]), axis=1)
            rouge = np.maximum(rouge, np.exp(-(reach / 0.021) ** 2) * (np.sign(points[:, 0]) == side))
        layers = np.maximum(layers, rasterise(uv, triangles, np.stack([lips_near, lid, lash, rouge], axis=1)))
        material = model.doc["materials"][primitive["material"]]
        texture = model.doc["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
        skin_picture = folder / model.doc["images"][texture["source"]]["uri"]
    skin = np.asarray(Image.open(skin_picture).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS), dtype=np.float32) / 255.0
    # Lips: inside the part of the face the lip shapes move, the skin picture's own lip colour (redder than the
    # skin round it) says where the lips are. Only the outside of the face is looked at: the inside of the mouth
    # is redder still and is drawn on a patch of its own.
    near = soften(layers[..., 0], 4.0) > 0.22
    redness = skin[..., 0] - 0.5 * (skin[..., 1] + skin[..., 2])
    if near.any():
        around = float(np.percentile(redness[near], 30))
        top = float(np.percentile(redness[near], 97))
        spread = max(top - around, 0.02)
        lips = np.clip((redness - around - 0.12 * spread) / (0.22 * spread), 0.0, 1.0) * near
    else:
        lips = np.zeros((SIZE, SIZE), dtype=np.float32)
    lips = soften(lips, 1.2)
    lid = soften(layers[..., 1], 3.0)
    lash = soften(layers[..., 2], 1.0)
    rouge = soften(layers[..., 3], 9.0)
    out = np.zeros((SIZE, SIZE, 4), dtype=np.float32)

    def lay(mask: np.ndarray, tint: np.ndarray, strength: float) -> None:
        alpha = np.clip(mask * strength, 0.0, 1.0)
        total = alpha + out[..., 3] * (1.0 - alpha)
        safe = np.where(total > 1e-6, total, 1.0)
        out[..., :3] = (tint * alpha[..., None] + out[..., :3] * (out[..., 3] * (1.0 - alpha))[..., None]) / safe[..., None]
        out[..., 3] = total

    lay(rouge, colour(args.rouge), args.rouge_strength)
    lay(lid, colour(args.shadow), args.shadow_strength)
    lay(lash, colour(args.liner), args.liner_strength)
    lay(lips, colour(args.lips), args.lip_strength)
    target = folder / ("%s_makeup_%s.png" % (args.person, args.name))
    # The engine reads the picture as sRGB: the tints are given as they should look.
    Image.fromarray(np.clip(out * 255.0, 0, 255).astype(np.uint8), "RGBA").save(target)
    covered = {name: round(float((mask > 0.2).mean()) * 100.0, 3) for name, mask in (("lips", lips), ("lids", lid), ("lash line", lash), ("rouge", rouge))}
    print("wrote", target, "percent of the picture painted:", covered)
    if covered["lips"] <= 0.0 or covered["lids"] <= 0.0:
        print("WARNING: lips or lids found nothing to paint", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
