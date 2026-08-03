"""Render the phone-torch light mask.

A cell phone flash is a blue LED die under a yellow phosphor cap behind a
tiny plastic lens, held low in one hand. That physical stack decides the
whole picture:

- an elliptical hotspot (rectangular die smeared by the lens), sitting
  below and right of screen center because the hand does;
- phosphor fringe: the center is near-neutral cool white, but light
  leaving at steep angles misses phosphor, so the rim of the beam always
  slides toward blue;
- a faint bright ring partway out (total-internal-reflection artifact of
  the flat lens window), and a soft second lobe below the hotspot;
- corners that never reach black — a torch scatters off dust and walls,
  it does not cut a stencil.

The PNG multiplies over the rendered frame (gl_compatibility ignores
light_projector, and a screen-space mask is also how a hand-held beam
reads on camera): white center leaves the SpotLight3D's work alone, the
falloff swallows the periphery, and the blue fringe cools everything the
beam barely reaches.

    python art/tools/build_phone_light_mask.py
"""
import math
import os

from PIL import Image, ImageFilter

W, H = 960, 540
OUT = os.path.normpath(os.path.join(
    os.path.dirname(__file__), "..", "..",
    "game", "assets", "ui", "phone_light_mask.png"))

# Beam center: below and right of screen center — the phone hand.
CX, CY = 0.54, 0.60
# Channel response along the beam radius. Each entry: (radius where the
# channel starts dying, softness). Red dies first and fastest, blue
# lingers — that ordering IS the phosphor fringe.
CHANNELS = {
    "r": (0.155, 0.30),
    "g": (0.170, 0.32),
    "b": (0.195, 0.37),
}
FLOOR = {"r": 0.105, "g": 0.12, "b": 0.15}    # scattered ambient, cool-ish
RING_R, RING_W, RING_GAIN = 0.21, 0.022, 0.06
LOBE_CY, LOBE_GAIN = 0.80, 0.13               # spill on the floor ahead


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def main() -> None:
    img = Image.new("RGB", (W, H))
    px = img.load()
    for j in range(H):
        for i in range(W):
            x = i / (W - 1.0)
            y = j / (H - 1.0)
            # Ellipse: the die is wider than tall, and holding the phone
            # low tips the beam so the top edge falls off faster.
            dx = (x - CX) / 1.00
            dy = (y - CY) / 0.82
            if dy < 0.0:
                dy *= 1.22
            radius = math.hypot(dx, dy)
            # TIR ring and the floor-spill lobe brighten locally.
            ring = RING_GAIN * math.exp(
                -((radius - RING_R) / RING_W) ** 2)
            lobe = LOBE_GAIN * math.exp(
                -(((x - CX) / 0.34) ** 2 + ((y - LOBE_CY) / 0.16) ** 2))
            value = {}
            for ch, (start, soft) in CHANNELS.items():
                v = 1.0 - smoothstep(start, start + soft, radius)
                v = v + ring + lobe * (0.75 if ch == "r" else 1.0)
                v = FLOOR[ch] + (1.0 - FLOOR[ch]) * min(1.0, v)
                value[ch] = v
            px[i, j] = (int(value["r"] * 255 + 0.5),
                        int(value["g"] * 255 + 0.5),
                        int(value["b"] * 255 + 0.5))
    # One soft pass so the ring and lobe fuse into the falloff the way a
    # smudged plastic window would, not like painted geometry.
    img = img.filter(ImageFilter.GaussianBlur(3.0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
