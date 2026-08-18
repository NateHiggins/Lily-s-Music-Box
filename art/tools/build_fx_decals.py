"""Generate the building's decal masks: wear, stains, shadows, damage.

These nine images were orphans. They sat in art/textures/generated/fx/
dated to a single afternoon in July with no script that could rebuild
them, so nothing could be retuned without hand-painting a PNG, and
nobody could see them side by side. The result was a set whose opacity
ran from 8.6% to 86.7% - a seventeenfold spread - in which every decal
doing quiet work was invisible and the loudest one read as a hole
punched through the wall:

    fx_traffic   8.6%   the path worn across a floor      - unseeable
    fx_grease   12.9%   the wall behind a range           - unseeable
    fx_drip     15.7%   condensation under a window       - unseeable
    fx_scuff    16.1%   scuffing at shoe height           - unseeable
    fx_burn     86.7%   scorching                         - a black hole

A decal is a lie told at a specific strength. Getting the strength wrong
is not a small error: at 9% the building loses a century of use, and at
87% a scorch mark stops being scorching and becomes a void.

So the strengths live in one table, ALPHA, where they can be compared
and argued with. They are deliberately compressed into roughly a 2x
range: everything here is dirt on a surface, and dirt does not vary by
seventeen times. Ordering within that range carries the meaning - a
plaster patch is a repair somebody made and reads strongest; a traffic
path is a century of feet and reads softest but must still read.

    python art/tools/build_fx_decals.py

Alpha does all the work. RGB stays near-black for the darkening decals
because they are multiplied over whatever they land on; the grease and
patch decals carry a colour because they are deposits, not shadows.
"""
import os
import zlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "textures", "generated", "fx")
PX = 512                       # was 256, over surfaces up to 2.6 m wide

# Peak opacity per decal. The whole point of this file.
ALPHA = {
    "wear_traffic": 0.28,      # a century of feet: softest, but present
    "wear_scuff":   0.30,
    "wear_grease":  0.32,      # behind the range
    "wear_drip":    0.34,      # condensation below a window
    "ao_strip":     0.38,      # wall/floor junction, on every wall
    "age_damp":     0.42,
    "shadow_blob":  0.50,      # contact shadow under furniture
    "wear_burn":    0.55,      # scorching, NOT a hole
    "age_patch":    0.62,      # somebody repaired this: reads strongest
}

# Deposits carry colour; darkeners stay near-black and multiply.
RGB = {
    "wear_grease": (48, 38, 22),
    "age_patch":   (150, 132, 116),
    "wear_burn":   (18, 14, 12),
    "age_damp":    (44, 46, 38),
}
DEFAULT_RGB = (10, 9, 11)

# ===================================================== MATTER VS LIGHTING ===
# Owner, 2026-08-18: "i want to replace the shader only textures with full
# ones."
#
# These plates were flat colour plus an alpha mask: a grease stain was one
# uniform brown, and — the part that actually mattered — a deposit could not
# change the ROUGHNESS of the surface it sat on. That is most of why they read
# as stickers. Grease and damp are the glossiest things in a room; scorch and
# a plaster repair are the mattest; a century of feet POLISHES a floor. All of
# that is roughness, and none of it was expressible.
#
# So each deposit now ships a roughness and a normal beside its albedo.
#
# TWO PLATES ARE DELIBERATELY EXCLUDED. `ao_strip` and `shadow_blob` are not
# matter, they are fake lighting — a wall/floor junction darkener and a contact
# shadow. Giving those a normal would emboss a surface that has nothing on it,
# and giving them a roughness would make a shadow change how the floor
# reflects, which is exactly the tell that gives painted-on lighting away. They
# stay pure multiply. The rule is: if you could scrape it off with a knife it
# gets maps, and if you could not, it does not.
ROUGH = {
    # Deposits that are WETTER than the wall they sit on.
    "wear_grease": 0.18,   # rendered fat, the glossiest thing in the building
    "age_damp":    0.34,   # water in plaster, dark and slightly sheened
    # Feet do not roughen a floor, they burnish it.
    "wear_traffic": 0.30,
    # Deposits that are DRIER than the wall.
    "wear_drip":   0.52,   # mineral run, chalky where it has dried
    "wear_scuff":  0.68,   # abraded, broken surface
    "age_patch":   0.88,   # unpainted repair plaster, the mattest thing here
    "wear_burn":   0.94,   # char scatters light in every direction
}

# How far the deposit stands off the wall, in normal-map strength. A repair is
# trowelled proud of the plaster; grease is a film with almost no thickness.
RELIEF = {
    "age_patch":   1.00,
    "wear_burn":   0.55,   # blistered, but scorch is mostly IN the surface
    "wear_drip":   0.45,   # runs stand off a little
    "age_damp":    0.20,   # swelling, barely
    "wear_scuff":  0.30,
    "wear_traffic": 0.10,  # worn INTO the floor, not onto it
    "wear_grease": 0.12,
}

# How much the albedo varies across the deposit. A flat colour is the other
# half of the sticker problem: real deposits are denser at their centre and
# thinner at the edge, and blotchy throughout.
MOTTLE = 0.45


def rng(seed):
    return np.random.default_rng(seed)


def noise(seed, size, octaves=4):
    """Value noise in 0..1, built by upsampling coarse grids."""
    out = np.zeros((size, size), dtype=np.float64)
    amp = 1.0
    total = 0.0
    r = rng(seed)
    for o in range(octaves):
        n = max(2, 2 ** (o + 2))
        grid = r.random((n, n))
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (size, size), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= 0.5
    return out / total


def radial(size, cx=0.5, cy=0.5, r=0.5, soft=1.0):
    y, x = np.mgrid[0:size, 0:size] / float(size - 1)
    d = np.sqrt(((x - cx) / r) ** 2 + ((y - cy) / r) ** 2)
    return np.clip(1.0 - d ** soft, 0.0, 1.0)


def _normal_from_height(height, strength):
    """Tangent-space normal from a height field, OpenGL +Y convention.

    +Y because that is what every other map in this project uses and what
    Godot expects without `normal_map_invert_y`; an audit confirmed all 988
    importers agree, and this must not be the one file that disagrees.
    """
    # np.gradient returns d/drow, d/dcol. Row is +V, which points DOWN in
    # image space, so the row gradient is negated to get +Y up.
    gy, gx = np.gradient(height.astype(np.float64))
    nx = -gx * strength * 8.0
    ny = gy * strength * 8.0
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / length, ny / length, nz / length])


def write(name, alpha01, size=None):
    """Alpha in 0..1, scaled to this decal's entry in ALPHA.

    Deposits also get a roughness and a normal; see the MATTER VS LIGHTING
    note above for why `ao_strip` and `shadow_blob` do not.
    """
    a = np.clip(alpha01, 0.0, 1.0) * ALPHA[name]
    h, w = a.shape
    os.makedirs(OUT, exist_ok=True)

    base = np.array(RGB.get(name, DEFAULT_RGB), dtype=np.float64)
    is_deposit = name in ROUGH
    if is_deposit:
        # Mottle the colour so the deposit is not one flat value. Seeded from
        # a CRC of the name, NOT Python's hash(): string hashing is salted per
        # process, so hash() would repaint every deposit differently on every
        # run and leave a diff nobody could explain.
        mottle = noise(zlib.crc32(name.encode()) % 9973, max(h, w),
                       octaves=5)[:h, :w]
        gain = 1.0 + (mottle - 0.5) * 2.0 * MOTTLE
        rgb = np.clip(base[None, None, :] * gain[:, :, None], 0, 255)
    else:
        rgb = np.broadcast_to(base, (h, w, 3))
    img = np.dstack([rgb.astype(np.uint8), (a * 255).astype(np.uint8)])
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name + ".png"))

    if not is_deposit:
        print("  %-14s %-10s peak %.0f%%  (lighting, no maps)"
              % (name, "%dx%d" % (w, h), ALPHA[name] * 100))
        return

    # ROUGHNESS. White is the surface's own roughness untouched, so the plate
    # only says what it changes: it drives toward the deposit's value in
    # proportion to how present the deposit is. Where the decal is
    # transparent, the wall keeps whatever roughness it already had.
    coverage = np.clip(alpha01, 0.0, 1.0)
    rough = 1.0 - coverage * (1.0 - ROUGH[name])
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(
        os.path.join(OUT, name + "_rough.png"))

    # NORMAL, from the coverage field read as thickness, blurred once so the
    # relief is the deposit's FORM rather than the noise's pixel grain.
    smooth = np.asarray(
        Image.fromarray((coverage * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(1.6)), dtype=np.float64) / 255.0
    n = _normal_from_height(smooth, RELIEF.get(name, 0.4))
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, name + "_normal.png"))

    print("  %-14s %-10s peak %.0f%%  rough %.2f  relief %.2f"
          % (name, "%dx%d" % (w, h), ALPHA[name] * 100,
             ROUGH[name], RELIEF.get(name, 0.4)))


def build_ao_strip():
    """Corner darkening: a gradient, dark at the junction, gone by the top."""
    h, w = 256, 16
    g = np.linspace(1.0, 0.0, h) ** 1.9
    write("ao_strip", np.repeat(g[:, None], w, axis=1))


def build_shadow_blob():
    n = noise(11, PX, 3)
    write("shadow_blob", radial(PX, soft=1.6) * (0.75 + 0.25 * n))


def build_wear_traffic():
    """A path, made of the feet that made it.

    A Gaussian band is not a worn path - it is a smudge, and it read as
    one. A real path is an ACCUMULATION: hundreds of overlapping
    footfalls, densest along a centre line that wanders, thinning
    raggedly at the edges where fewer people strayed. So build it out of
    foot-sized smears rather than drawing the average of them.
    """
    r = rng(3)
    yy, xx = np.mgrid[0:PX, 0:PX].astype(float)
    a = np.zeros((PX, PX))
    for _ in range(420):
        t = r.random()
        cx = t * PX
        # the centre line wanders, and strays fall off it normally
        drift = np.sin(t * 4.2 + 1.1) * 0.06 * PX
        cy = PX * 0.5 + drift + r.normal(0.0, PX * 0.085)
        fw = r.uniform(PX * 0.022, PX * 0.055)      # a shoe, roughly
        fh = fw * r.uniform(0.45, 0.7)
        th = r.normal(0.0, 0.25)
        dx, dy = np.cos(th), np.sin(th)
        px = (xx - cx) * dx + (yy - cy) * dy
        py = -(xx - cx) * dy + (yy - cy) * dx
        a += np.exp(-((px / fw) ** 2 + (py / fh) ** 2)) * r.uniform(.25, .6)
    a = np.clip(a, 0, 1) ** 0.8
    write("wear_traffic", a * (0.7 + 0.3 * noise(4, PX, 5)))


def build_wear_scuff():
    """Short arcs at shoe height, scattered, never a uniform smear."""
    r = rng(7)
    a = np.zeros((PX, PX))
    yy, xx = np.mgrid[0:PX, 0:PX]
    for _ in range(90):
        cx, cy = r.random() * PX, r.random() * PX
        ln = r.uniform(PX * 0.03, PX * 0.10)
        th = r.uniform(-0.5, 0.5)
        dx, dy = np.cos(th), np.sin(th)
        px = (xx - cx) * dx + (yy - cy) * dy
        py = -(xx - cx) * dy + (yy - cy) * dx
        a = np.maximum(a, np.exp(-((px / ln) ** 2 + (py / 2.2) ** 2)))
    write("wear_scuff", a * (0.6 + 0.4 * noise(8, PX, 4)))


def build_wear_drip():
    """Condensation running DOWN: streaks that start at the top and taper."""
    r = rng(13)
    a = np.zeros((PX, PX))
    yy, xx = np.mgrid[0:PX, 0:PX]
    for _ in range(26):
        cx = r.random() * PX
        length = r.uniform(0.35, 1.0) * PX
        wid = r.uniform(1.5, 4.5)
        run = np.clip(1.0 - yy / length, 0.0, 1.0) ** 0.7
        a = np.maximum(a, run * np.exp(-(((xx - cx) / wid) ** 2)))
    top = np.clip(1.0 - yy / (PX * 0.12), 0, 1) * 0.5
    write("wear_drip", np.clip(a + top, 0, 1) * (0.6 + 0.4 * noise(5, PX, 4)))


def build_wear_grease():
    """Spatter, film, and the runs where it got wiped and missed.

    A radial blob is a stain of any kind; it said nothing about a range.
    Grease behind a hob has three distinct parts and needs all of them:
    airborne FILM that settles evenly, discrete SPATTER thrown from the
    pan in a size range, and vertical RUNS where somebody wiped at it and
    dragged it downward without lifting it.
    """
    r = rng(21)
    yy, xx = np.mgrid[0:PX, 0:PX].astype(float)
    # 1. film: heaviest at hob height, fading up the wall
    yn = yy / float(PX - 1)
    film = np.clip(1.0 - ((yn - 0.68) / 0.55) ** 2, 0, 1) * 0.42
    film *= 0.55 + 0.45 * noise(22, PX, 5)
    # 2. spatter: many small, few large, thrown from a point low-centre
    spat = np.zeros((PX, PX))
    for _ in range(260):
        ang = r.uniform(0, np.pi)
        dist = abs(r.normal(0.0, PX * 0.26))
        cx = PX * 0.5 + np.cos(ang) * dist
        cy = PX * 0.72 - abs(np.sin(ang)) * dist * 0.8
        rad = r.uniform(1.2, 3.0) ** 2.1          # size distribution
        spat = np.maximum(spat, np.exp(
            -(((xx - cx) ** 2 + (yy - cy) ** 2) / (2.0 * rad ** 2))))
    # 3. wipe runs: downward drags that smear rather than clean
    runs = np.zeros((PX, PX))
    for _ in range(7):
        cx = r.random() * PX
        top = r.uniform(0.35, 0.70) * PX
        ln = r.uniform(0.16, 0.34) * PX
        w = r.uniform(11.0, 26.0)   # a cloth is wide; 3-9 px read as scratches
        prof = np.clip((yy - top) / ln, 0, 1)
        prof = np.where((yy > top) & (yy < top + ln), 1.0 - prof, 0.0)
        runs = np.maximum(runs, prof * np.exp(-(((xx - cx) / w) ** 2)))
    # Fade to nothing at the border.
    #
    # The film term is a function of height only, so it ran to full
    # strength off the left, right and bottom edges - and a decal that
    # does not reach zero at its own boundary reads as a pasted
    # RECTANGLE stuck on the wall, which is worse than no decal. The
    # shaped decals (patch, shadow) get this free from being radial;
    # anything built from a gradient has to be told.
    xn = xx / float(PX - 1)
    edge = (np.clip(np.minimum(xn, 1.0 - xn) / 0.18, 0, 1)
            * np.clip(np.minimum(yn, 1.0 - yn) / 0.14, 0, 1))
    a = (film + spat * 0.85 + runs * 0.5) * edge
    write("wear_grease", np.clip(a, 0, 1))


def build_wear_burn():
    """Scorching: dense at the seat, fingers licking upward, never opaque."""
    y, x = np.mgrid[0:PX, 0:PX] / float(PX - 1)
    seat = np.exp(-(((x - 0.5) / 0.34) ** 2 + ((y - 0.86) / 0.26) ** 2))
    # Soot rises FROM the seat and thins going up. The first version had
    # this exactly backwards - (1 - y) is strongest at the top of the
    # image, so the mark was densest far from its own source and ran off
    # the top edge at 56/255. A scorch that is heaviest where the fire
    # was not is not a scorch.
    tongues = (np.exp(-(((x - 0.5) / 0.42) ** 2))
               * np.clip(y / 0.86, 0, 1) ** 1.4)
    n = noise(31, PX, 5)
    a = np.clip(seat + tongues * 0.75, 0, 1) * (0.35 + 0.85 * n)
    a *= np.clip(np.minimum(x, 1.0 - x) / 0.16, 0, 1)      # sides end
    a *= np.clip(y / 0.10, 0, 1)                           # top ends
    write("wear_burn", np.clip(a, 0, 1))


def build_age_patch():
    """A skim of filler, with the blade marks still in it.

    The patch had an edge but its inside was glass-smooth, which is the
    one thing wet filler never is. A trowelled repair carries ARCS from
    the blade - overlapping curved ridges left by the sweep of a wrist -
    and it is proudest in the middle where the most material went. The
    ridges are what make it read as somebody's hand rather than a shape.
    """
    r = rng(41)
    yy, xx = np.mgrid[0:PX, 0:PX].astype(float)
    n = noise(42, PX, 3)
    blob = radial(PX, cx=0.48, cy=0.52, r=0.52, soft=2.4)
    body = np.clip((blob * (0.7 + 0.6 * n) - 0.34) * 4.0, 0, 1)
    # trowel arcs: wide, shallow, struck from a pivot off to one side
    arcs = np.zeros((PX, PX))
    pivx, pivy = -0.35 * PX, 0.55 * PX
    rad = np.sqrt((xx - pivx) ** 2 + (yy - pivy) ** 2)
    for _ in range(9):
        rr = r.uniform(0.55, 1.35) * PX
        w = r.uniform(6.0, 16.0)
        arcs += np.exp(-(((rad - rr) / w) ** 2)) * r.uniform(0.35, 0.9)
    arcs = np.clip(arcs, 0, 1)
    # ridges only inside the patch, and strongest where it is thickest
    write("age_patch", np.clip(body * (0.78 + 0.34 * arcs), 0, 1))


def build_age_damp():
    """A ceiling water stain: concentric tide rings, fading on all sides.

    This was built as a vertical tide line, which is what rising damp
    does on a WALL - but fx_damp is overwhelmingly a ceiling decal (old
    plumbing announcing itself overhead), and a ceiling has no up. Worse,
    a one-axis gradient ran live off two edges and pasted on as a band.

    What water actually does on a ceiling is spread and dry repeatedly,
    and each time it stops it leaves a darker ring at the high-water
    mark. So: an irregular blob with several concentric edges inside it,
    each one a place the stain paused. That reads correctly overhead and
    is still plausible on a wall.
    """
    r = rng(51)
    yy, xx = np.mgrid[0:PX, 0:PX] / float(PX - 1)
    warp = 0.16 * (noise(53, PX, 3) - 0.5)
    d = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) + warp
    body = np.clip(1.0 - d / 0.42, 0, 1) ** 0.7
    rings = np.zeros((PX, PX))
    for _ in range(4):
        rr = r.uniform(0.12, 0.38)
        rings += np.exp(-(((d - rr) / 0.022) ** 2)) * r.uniform(0.4, 0.9)
    a = np.clip(body * (0.55 + 0.45 * noise(52, PX, 5)) + rings * 0.35, 0, 1)
    write("age_damp", a * np.clip(body / 0.05, 0, 1))


def build_authored_companions():
    """Derive maps for the FX plates that are PAINTED rather than generated.

    `fx_ceiling_soffit_failed` is the only one: its albedo is an authored
    ai_sources image, so there is no alpha field here to read thickness from
    and nothing above builds it. It appears on seven of the eight floors, which
    makes it the most widespread untextured surface left in the building.

    A failed soffit is lath and broken plaster hanging out of a ceiling. It is
    the roughest thing in the Orison and it has real depth, so both maps are
    derived from the plate's own luminance: dark is a hole and light is intact
    plaster still keyed to the lath.
    """
    src = os.path.join(ROOT, "art", "textures", "ai_sources",
                       "ceiling_soffit_failed_v1.png")
    if not os.path.exists(src):
        print("  ceiling_soffit_failed  SKIPPED, plate not found")
        return
    img = Image.open(src).convert("RGB")
    lum = np.asarray(img, dtype=np.float64) @ np.array([0.299, 0.587, 0.114])
    lum /= 255.0
    # Blur before differentiating, or the normal is the JPEG grain rather than
    # the broken edges of the plaster.
    smooth = np.asarray(
        Image.fromarray((lum * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(2.0)), dtype=np.float64) / 255.0
    n = _normal_from_height(smooth, 0.9)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "ceiling_soffit_failed_v1_normal.png"))
    # 0.72 where the plaster survives up to 0.98 in the exposed cavity: nothing
    # about a hole in a ceiling is glossy, and the darkest part is the deepest.
    rough = 0.98 - 0.26 * np.clip(smooth, 0.0, 1.0)
    Image.fromarray((rough * 255).astype(np.uint8), "L").save(
        os.path.join(OUT, "ceiling_soffit_failed_v1_rough.png"))
    print("  %-22s %-10s rough 0.72-0.98  relief 0.90 (authored plate)"
          % ("ceiling_soffit", "%dx%d" % img.size))


def main():
    print("fx decals -> %s" % os.path.relpath(OUT, ROOT))
    build_ao_strip()
    build_shadow_blob()
    build_wear_traffic()
    build_wear_scuff()
    build_wear_drip()
    build_wear_grease()
    build_wear_burn()
    build_age_patch()
    build_age_damp()
    build_authored_companions()
    lo, hi = min(ALPHA.values()), max(ALPHA.values())
    print("opacity range %.0f%%-%.0f%% (spread %.1fx, was 17x)"
          % (lo * 100, hi * 100, hi / lo))


if __name__ == "__main__":
    main()
