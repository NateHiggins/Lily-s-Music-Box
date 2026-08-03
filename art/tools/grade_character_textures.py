"""Grade the hero-cast albedos into the Orison's palette, in place.

Meshy albedos arrive bright and washed out — daylight-catalog colors in
a building lit by 25-watt warmth. The grade: pull exposure down, mute
saturation, a gentle contrast set, and a warm brown lean so cloth and
skin sit inside the night palette instead of on top of it. Albedo only;
normal/metallic/roughness are untouched.

Idempotence: a graded file gains a `.graded` sidecar marker and is
skipped on re-runs, so the pass can run after every conversion without
compounding.

    python art/tools/grade_character_textures.py
"""
import glob
import os

from PIL import Image, ImageEnhance

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXPOSURE = 0.84
SATURATION = 0.80
CONTRAST = 1.06
WARM = (1.00, 0.965, 0.905)   # per-channel lean toward lamplight


def grade(path: str) -> None:
    marker = path + ".graded"
    if os.path.exists(marker):
        return
    img = Image.open(path).convert("RGB")
    img = ImageEnhance.Brightness(img).enhance(EXPOSURE)
    img = ImageEnhance.Color(img).enhance(SATURATION)
    img = ImageEnhance.Contrast(img).enhance(CONTRAST)
    r, g, b = img.split()
    r = r.point(lambda v: min(255, int(v * WARM[0])))
    g = g.point(lambda v: min(255, int(v * WARM[1])))
    b = b.point(lambda v: min(255, int(v * WARM[2])))
    Image.merge("RGB", (r, g, b)).save(path)
    with open(marker, "w") as fh:
        fh.write("graded EXPOSURE=%.2f SAT=%.2f CON=%.2f WARM=%s\n"
                 % (EXPOSURE, SATURATION, CONTRAST, str(WARM)))
    print("graded", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    patterns = [
        os.path.join(ROOT, "game", "assets", "characters", "*",
                     "*texture_0.png"),
        os.path.join(ROOT, "game", "assets", "characters", "*",
                     "texture_0.png"),
        os.path.join(ROOT, "game", "assets", "creatures", "*",
                     "*texture_0.png"),
        os.path.join(ROOT, "game", "assets", "creatures", "*",
                     "texture_0.png"),
    ]
    seen = set()
    for pattern in patterns:
        for path in glob.glob(pattern):
            if path in seen or "evelyn_marsh" in path:
                continue  # Evelyn's original stays as shipped
            seen.add(path)
            grade(path)
    print("grade pass complete: %d textures" % len(seen))
