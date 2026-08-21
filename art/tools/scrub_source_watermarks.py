"""Find and remove the generator's sparkle watermark from AI source photos.

    python art/tools/scrub_source_watermarks.py --report     # detect only, list scores
    python art/tools/scrub_source_watermarks.py --preview    # write before/after crops
    python art/tools/scrub_source_watermarks.py --apply      # rewrite the sources in place

WHY. Generated sources carry a four-point sparkle glyph, a ~40 % white
overlay about 96 px across, inset from the bottom-right corner. The ingest
makes each source seamless by a half-roll crossfade and derives height,
normal and roughness from the albedo, so the glyph lands on every tile of
every surface built from it, in all four maps (seen 2026-08-21 on the 2A
bedroom brick). Fixing the SOURCE and re-ingesting fixes everything at once.

HOW. The glyph is a known shape, so it is synthesised (a concave four-point
star) and located by normalised cross-correlation against the band-passed
luminance of a window at the generator's fixed inset, at three scales. Where
it is found, the overlay's opacity is MEASURED per pixel: a smooth background
is fitted from the ring around the glyph, and alpha = (observed - background)
/ (white - background), smoothed and confined to the dilated star. The glyph
is then UNBLENDED - the texture underneath is recovered, not painted over:
original = (observed - alpha*white) / (1 - alpha). A measured alpha map that
is too faint or does not look like the star means no glyph; the file is left
alone rather than guessed at.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "textures", "ai_sources")
PREVIEW_DIR = os.path.join(ROOT, "art", "textures", "ai_sources", "_scrub_preview")

GLYPH_PX = 96            # bounding size of the sparkle at native scale
SCALES = (0.8, 1.0, 1.25)
NCC_THRESHOLD = 0.45     # below this the corner holds no sparkle
# The generator places the glyph at a fixed inset from the bottom-right
# corner (about 190 px on every source measured, 1024 and 2048 alike), so
# the search is a small window around that inset rather than a corner quadrant.
INSET_PX = 190
INSET_SLACK = 34
ALPHA_RANGE = (0.12, 0.75)
SHAPE_MIN = 0.55         # correlation between measured alpha and the star
# Named sources confirmed by eye to carry the glyph although a busy ground
# (lime blotches, stains) spoils the shape correlation under it.
KNOWN_CARRIERS = {"common_brick_interior.png"}


def sparkle(size, exponent=0.58):
    """Concave four-point star: a superellipse with exponent < 1."""
    r = size / 2.0
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    u = (x - r + 0.5) / r
    v = (y - r + 0.5) / r
    d = np.abs(u) ** exponent + np.abs(v) ** exponent
    # soft edge over ~1.5 px
    edge = 1.5 / r
    return np.clip((1.0 - d) / edge + 1.0, 0.0, 1.0)


def bandpass(gray):
    """Keep the glyph's broad shape, drop brick edges and the lighting gradient."""
    g = Image.fromarray(gray.astype(np.uint8))
    fine = np.asarray(g.filter(ImageFilter.GaussianBlur(3)), dtype=np.float32)
    broad = np.asarray(g.filter(ImageFilter.GaussianBlur(40)), dtype=np.float32)
    return fine - broad


def ncc_search(hp, template):
    """Brute-force NCC of template over hp (both small). Returns (score, y, x)."""
    th, tw = template.shape
    t = template - template.mean()
    tn = np.sqrt((t * t).sum()) + 1e-6
    H, W = hp.shape
    best = (-1.0, 0, 0)
    step = 2
    for y in range(0, H - th, step):
        for x in range(0, W - tw, step):
            patch = hp[y:y + th, x:x + tw]
            p = patch - patch.mean()
            pn = np.sqrt((p * p).sum()) + 1e-6
            s = float((p * t).sum() / (pn * tn))
            if s > best[0]:
                best = (s, y, x)
    # refine at step 1 around the best
    s0, y0, x0 = best
    for y in range(max(0, y0 - 2), min(H - th, y0 + 3)):
        for x in range(max(0, x0 - 2), min(W - tw, x0 + 3)):
            patch = hp[y:y + th, x:x + tw]
            p = patch - patch.mean()
            pn = np.sqrt((p * p).sum()) + 1e-6
            s = float((p * t).sum() / (pn * tn))
            if s > best[0]:
                best = (s, y, x)
    return best


def detect(gray):
    """Search a window around the generator's fixed inset. Returns dict or None."""
    H, W = gray.shape
    bp = bandpass(gray)
    found = None
    for scale in SCALES:
        size = max(24, int(round(GLYPH_PX * scale)))
        x_lo = max(0, W - INSET_PX - size - INSET_SLACK)
        y_lo = max(0, H - INSET_PX - size - INSET_SLACK)
        x_hi = min(W, W - INSET_PX + INSET_SLACK)
        y_hi = min(H, H - INSET_PX + INSET_SLACK)
        region = bp[y_lo:y_hi, x_lo:x_hi]
        if size >= min(region.shape):
            continue
        tmpl = sparkle(size)
        score, y, x = ncc_search(region, tmpl)
        if found is None or score > found["score"]:
            found = {"score": score, "x": x_lo + x, "y": y_lo + y, "size": size, "scale": scale}
    if found is None or found["score"] < NCC_THRESHOLD:
        return None
    return found


def period_along_x(gray, y0, y1, lo=60, hi=700):
    band = gray[y0:y1].mean(axis=0)
    band = band - band.mean()
    ac = np.correlate(band, band, mode="full")[band.size - 1:]
    ac /= max(1e-6, ac[0])
    hi = min(hi, band.size // 2)
    if hi <= lo:
        return lo, 0.0
    p = lo + int(np.argmax(ac[lo:hi]))
    return p, float(ac[p])


def clone_estimate(arr, gray, x0, y0, x1, y1):
    """Course-aligned clone of the box from one period left (or right)."""
    H, W = gray.shape
    period, _ = period_along_x(gray, y0, y1)
    shift = -period if x0 - period >= 0 else period
    if x1 + shift > W or x0 + shift < 0:
        shift = -min(period, x0)
    return arr[y0:y1, x0 + shift:x1 + shift]


def ring_background(arr, x0, y0, x1, y1, T):
    """Per-channel plane fitted to the pixels around the star, inside the box."""
    h, w = T.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ring = T < 0.02
    A = np.stack([np.ones(ring.sum()), xx[ring], yy[ring]], axis=1)
    bg = np.empty((h, w, 3), dtype=np.float32)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(A, arr[y0:y1, x0:x1, c][ring], rcond=None)
        bg[..., c] = coef[0] + coef[1] * xx + coef[2] * yy
    return bg


def unblend(path, apply, preview):
    im = Image.open(path).convert("RGB")
    arr = np.asarray(im).astype(np.float32)
    gray = arr.mean(axis=2)
    hit = detect(gray)
    name = os.path.basename(path)
    if hit is None:
        return None
    size = hit["size"]
    pad = max(8, size // 6)
    H, W = gray.shape
    x0, y0 = max(0, hit["x"] - pad), max(0, hit["y"] - pad)
    x1, y1 = min(W, hit["x"] + size + pad), min(H, hit["y"] + size + pad)
    T = np.zeros((y1 - y0, x1 - x0), dtype=np.float32)
    ty, tx = hit["y"] - y0, hit["x"] - x0
    star = sparkle(size)
    T[ty:ty + size, tx:tx + size] = star[:y1 - y0 - ty, :x1 - x0 - tx]
    obs = arr[y0:y1, x0:x1]
    bg = ring_background(arr, x0, y0, x1, y1, T)
    # Measured alpha per pixel, confined to the dilated star.
    dil = np.asarray(Image.fromarray((T * 255).astype(np.uint8)).filter(
            ImageFilter.MaxFilter(9)), dtype=np.float32) / 255.0
    lum_o = obs.mean(axis=2)
    lum_b = bg.mean(axis=2)
    alpha = np.clip((lum_o - lum_b) / np.maximum(20.0, 255.0 - lum_b), 0.0, 0.6)
    alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
    alpha *= (dil > 0.05)
    core = T > 0.6
    a_est = float(np.median(alpha[core])) if core.any() else 0.0
    # Does the MEASURED alpha look like the star? Judged before any flooring,
    # so a texture with no glyph cannot be talked into one.
    sel = dil > 0.05
    a_sel, t_sel = alpha[sel] - alpha[sel].mean(), T[sel] - T[sel].mean()
    shape = float((a_sel * t_sel).sum() / (np.sqrt((a_sel * a_sel).sum() * (t_sel * t_sel).sum()) + 1e-6))
    # The glyph is always the same shape in the same place, so a hit at the
    # fixed inset with a plausible opacity IS the glyph; the shape test only
    # decides borderline hits. Sources without it read alpha ~ 0 and fail here.
    # The generator's own files always carry the glyph, same shape, same place:
    # for them the pinned position plus a plausible opacity is proof and the
    # shape test is not asked. Anything else (ChatGPT drops, dream plates)
    # must also look like the star, so a bright feature at the inset is not
    # mistaken for it.
    generator_named = name.startswith("Gemini_Generated_Image") or name in KNOWN_CARRIERS
    plausible = ALPHA_RANGE[0] <= a_est <= ALPHA_RANGE[1]             and (shape >= SHAPE_MIN or generator_named)
    # On dark grounds the per-pixel read under-estimates inside the star; a
    # fraction of the measured core opacity over the star's soft silhouette
    # lifts the residue without stamping a full star where the read was low.
    # ... and only INSIDE the star: the measured alpha owns the edge, so the
    # floor is the template eroded by a few pixels and softened, never wider.
    t_inner = np.asarray(Image.fromarray((T * 255).astype(np.uint8)).filter(
            ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(1.5)),
            dtype=np.float32) / 255.0
    alpha = np.maximum(alpha, np.clip(0.7 * a_est, 0.0, 0.6) * t_inner)
    result = {"file": name, "score": round(hit["score"], 3), "x": hit["x"], "y": hit["y"],
              "size": size, "alpha": round(a_est, 3), "shape": round(shape, 3), "plausible": plausible}
    if not plausible:
        return result
    a = alpha[..., None]
    recovered = (obs - a * 255.0) / (1.0 - a)
    # Whatever opacity error remains shows as a faint coarse star; match the
    # recovered region's low frequencies to the fitted background inside the
    # dilated star so only genuine texture survives there. Fine detail (under
    # ~6 px) is untouched, and so is everything outside the star.
    wide = np.asarray(Image.fromarray((dil * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(3.0)), dtype=np.float32) / 255.0
    rec_low = np.asarray(Image.fromarray(np.clip(recovered.mean(axis=2), 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(6.0)), dtype=np.float32)
    bg_low = np.asarray(Image.fromarray(np.clip(lum_b, 0, 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(6.0)), dtype=np.float32)
    recovered = recovered + ((bg_low - rec_low) * wide)[..., None]
    out = arr.copy()
    out[y0:y1, x0:x1] = np.clip(recovered, 0.0, 255.0)
    fixed = Image.fromarray(out.astype(np.uint8))
    if preview or apply:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        W, H = im.size
        box = (max(0, cx - 160), max(0, cy - 160), min(W, cx + 160), min(H, cy + 160))
        sheet = Image.new("RGB", (648, 320), (10, 10, 10))
        sheet.paste(im.crop(box).resize((320, 320)), (0, 0))
        sheet.paste(fixed.crop(box).resize((320, 320)), (328, 0))
        sheet.save(os.path.join(PREVIEW_DIR, name + ".png"))
    if apply:
        fixed.save(path)
        result["applied"] = True
    return result


def main(argv):
    apply = "--apply" in argv
    preview = "--preview" in argv
    only = [a for a in argv if not a.startswith("--")]
    files = sorted(p for p in glob.glob(os.path.join(SRC, "*"))
                   if p.lower().endswith((".png", ".jpg", ".jpeg"))
                   and "_scrub_preview" not in p)
    if only:
        files = [p for p in files if os.path.basename(p) in only]
    found, fixed, skipped = 0, 0, []
    for p in files:
        try:
            r = unblend(p, apply, preview)
        except Exception as exc:  # one bad file must not stop the sweep
            print("ERROR %s: %s" % (os.path.basename(p), exc))
            continue
        if r is None:
            continue
        found += 1
        flag = "applied" if r.get("applied") else ("ok" if r["plausible"] else "not a glyph, left alone")
        print("%-44s ncc %.3f at (%d,%d) size %d alpha %.2f shape %.2f  %s" % (
                r["file"][:44], r["score"], r["x"], r["y"], r["size"], r["alpha"], r.get("shape", 0.0), flag))
        if r["plausible"]:
            fixed += 1
        else:
            skipped.append(r["file"])
    print("scanned %d sources: %d carry the sparkle, %d %s, %d left alone" % (
            len(files), found, fixed, "rewritten" if apply else "fixable", len(skipped)))


if __name__ == "__main__":
    main(sys.argv[1:])
