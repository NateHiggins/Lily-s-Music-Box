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

On top of the physics, the phone is CHARACTERIZED — it belongs to the 4B
night tech, and the beam says so:

- a hairline crack in the screen protector crosses the flash window: a
  faint dark seam with a brighter diffraction streak hugging it;
- a thumb-grease smudge low-left, where the phone is always gripped the
  same tired way: light scatters there, darks lift, the hotspot dulls;
- the work case's lip overhangs the flash and bites a soft arc out of
  the beam's upper-left;
- pocket lint: a few soft motes drifting in the fringe.

Every blemish is sub-10%% amplitude: the beam must read as a beam first
and a biography second.

    python art/tools/build_phone_light_mask.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

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
    img = characterize(img)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print("wrote", OUT, img.size)


def characterize(img: Image.Image) -> Image.Image:
    """The 4B tech's phone, specifically: crack, thumb grease, case lip,
    pocket lint. All applied in beam space so they ride the mask."""
    rng = random.Random(4471)  # the desk's first case number, for repeat

    # -- thumb-grease smudge, low-left of the hotspot: scattering, not
    # shadow. Local blur pulls detail out; a lift raises the darks and a
    # multiply dulls the brights, exactly what grease does to a beam.
    blurred = img.filter(ImageFilter.GaussianBlur(26.0))
    smudge = Image.new("L", img.size, 0)
    sd = ImageDraw.Draw(smudge)
    sd.ellipse((int(W * 0.13), int(H * 0.62), int(W * 0.44), int(H * 1.00)),
               fill=52)
    sd.ellipse((int(W * 0.20), int(H * 0.70), int(W * 0.38), int(H * 0.93)),
               fill=84)
    smudge = smudge.filter(ImageFilter.GaussianBlur(30.0))
    img = Image.composite(blurred, img, smudge)
    px = img.load()
    sm = smudge.load()
    for j in range(H):
        for i in range(W):
            s = sm[i, j] / 255.0
            if s <= 0.0:
                continue
            r, g, b = px[i, j]
            # lift shadows toward hazy gray-blue, dull the highlights
            px[i, j] = (
                int(r + (108 - r) * 0.16 * s),
                int(g + (116 - g) * 0.16 * s),
                int(b + (134 - b) * 0.16 * s))

    # -- case lip: a soft dark arc biting the upper-left of the beam.
    lip = Image.new("L", img.size, 0)
    ld = ImageDraw.Draw(lip)
    ld.arc((int(-W * 0.28), int(-H * 0.52), int(W * 0.88), int(H * 0.92)),
           start=150, end=262, fill=255, width=int(H * 0.085))
    lip = lip.filter(ImageFilter.GaussianBlur(22.0))
    lp = lip.load()
    for j in range(H):
        for i in range(W):
            s = lp[i, j] / 255.0
            if s <= 0.0:
                continue
            r, g, b = px[i, j]
            k = 1.0 - 0.30 * s
            px[i, j] = (int(r * k), int(g * k), int(b * (1.0 - 0.24 * s)))

    # -- the crack: one hairline seam wandering across the upper beam,
    # dark where the break shadows, with a bright diffraction streak
    # running alongside where the broken edge catches the LED.
    seam = Image.new("L", img.size, 0)
    glint = Image.new("L", img.size, 0)
    seam_draw = ImageDraw.Draw(seam)
    glint_draw = ImageDraw.Draw(glint)
    pts = []
    x, y = W * 0.22, H * 0.16
    heading = 0.42
    while x < W * 0.86 and 0 < y < H:
        pts.append((x, y))
        heading += rng.uniform(-0.33, 0.33)
        step = rng.uniform(28, 52)
        x += math.cos(heading) * step
        y += math.sin(heading) * step * 0.55
    seam_draw.line(pts, fill=150, width=2, joint="curve")
    glint_draw.line([(p[0] + 2.0, p[1] + 2.5) for p in pts],
                    fill=150, width=5, joint="curve")
    # one short branch off a mid vertex, the way real cracks fork
    if len(pts) > 5:
        bx, by = pts[len(pts) // 2]
        seam_draw.line([(bx, by), (bx + 34, by + 46), (bx + 44, by + 88)],
                       fill=110, width=2)
    seam = seam.filter(ImageFilter.GaussianBlur(1.1))
    glint = glint.filter(ImageFilter.GaussianBlur(3.5))
    sp = seam.load()
    gp = glint.load()
    for j in range(H):
        for i in range(W):
            dark = sp[i, j] / 255.0
            lite = gp[i, j] / 255.0
            if dark <= 0.0 and lite <= 0.0:
                continue
            r, g, b = px[i, j]
            # A crack only exists where light crosses it: scale both the
            # shadow and the glint by how bright the beam is right here,
            # so the seam melts away in the fringe instead of floating
            # over the dark like a hair on the camera.
            lum = (0.30 * r + 0.55 * g + 0.15 * b) / 255.0
            beam = smoothstep(0.18, 0.55, lum)
            k = 1.0 - 0.34 * dark * beam
            r, g, b = r * k, g * k, b * k
            # the diffraction streak leans blue: LED straight through glass
            r = min(255.0, r + 52 * lite * beam)
            g = min(255.0, g + 66 * lite * beam)
            b = min(255.0, b + 86 * lite * beam)
            px[i, j] = (int(r), int(g), int(b))

    # -- pocket lint: soft dim motes only where the fringe already lives.
    lint = Image.new("L", img.size, 0)
    lint_draw = ImageDraw.Draw(lint)
    for _ in range(9):
        angle = rng.uniform(0.0, math.tau)
        radius = rng.uniform(0.24, 0.40)
        lx = (CX + math.cos(angle) * radius) * W
        ly = (CY + math.sin(angle) * radius * 0.8) * H
        if not (0 < lx < W and 0 < ly < H):
            continue
        size = rng.uniform(3.0, 8.0)
        lint_draw.ellipse((lx - size, ly - size * 0.6,
                           lx + size, ly + size * 0.6), fill=90)
    lint = lint.filter(ImageFilter.GaussianBlur(4.0))
    lnp = lint.load()
    for j in range(H):
        for i in range(W):
            s = lnp[i, j] / 255.0
            if s <= 0.0:
                continue
            r, g, b = px[i, j]
            k = 1.0 - 0.22 * s
            px[i, j] = (int(r * k), int(g * k), int(b * k))
    return img


if __name__ == "__main__":
    main()
