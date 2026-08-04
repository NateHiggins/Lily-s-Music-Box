"""Generate the wall-finish source library with FLUX.1-schnell.

Sixteen AI-generated source images — albedo tiles, damage masks, relief
maps, stain overlays — that build_wall_finish_textures.py composites
into 81 unique per-wall finishes. Prompt vocabulary comes from period
building pathology: calcimine/distemper paint failure (chalk-based
paint that sheds every later coat), plaster delaminating off its lath
keys, rising damp tide marks with salt efflorescence, nicotine and
soot veiling.

Uses the public Hugging Face space (keyless, rate-limited); each image
lands in art/textures/wall_sources/<name>.png with its prompt in
<name>.txt beside it. Already-present images are skipped, so re-running
fills gaps after rate-limit failures.

    python art/tools/fetch_wall_sources.py
"""
import os
import shutil
import time

from gradio_client import Client

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "textures", "wall_sources")

FLAT = ("photographed perfectly flat and frontal, even diffuse lighting, "
        "no shadows cast, full-frame surface fills the whole image, "
        "documentary architectural photography, sharp focus")

SOURCES = {
    # --- plaster albedo -------------------------------------------------
    "plaster_calcimine": (
        "hyperrealistic close texture of a 100 year old lime plaster "
        "tenement wall, failing white calcimine paint shedding in brittle "
        "flakes, hairline craquelure, faint nicotine yellowing, " + FLAT),
    "plaster_distemper_green": (
        "hyperrealistic texture of aged tenement wall plaster painted with "
        "pale institutional green distemper, worn and chalky, decades of "
        "scuffs and grime, subtle water staining, " + FLAT),
    "plaster_tide": (
        "hyperrealistic texture of old lime plaster wall damaged by rising "
        "damp, brown tide marks and salt efflorescence blooming near the "
        "bottom, flaking whitewash above, " + FLAT),
    "plaster_parchment": (
        "hyperrealistic texture of century old plaster wall the color of "
        "aged parchment, fine cracks, trowel undulations, patches of older "
        "paint colors ghosting through, " + FLAT),
    # --- wallpaper ------------------------------------------------------
    "paper_damask": (
        "hyperrealistic texture of 1910s damask wallpaper on a tenement "
        "wall, faded burgundy pattern on tan ground, water stained, "
        "sun-bleached unevenly, edges lifting, " + FLAT),
    "paper_stripe": (
        "hyperrealistic texture of early 1900s striped wallpaper, narrow "
        "faded olive and cream vertical stripes, foxing spots, aged paste "
        "stains bleeding through, " + FLAT),
    "paper_floral": (
        "hyperrealistic texture of victorian floral sprig wallpaper aged "
        "100 years, small faded rose motifs on grey-green ground, "
        "water damaged corners, " + FLAT),
    "paper_anaglypta": (
        "hyperrealistic texture of painted-over embossed anaglypta "
        "wallpaper, thick cream paint filling a raised victorian pattern, "
        "chips revealing older layers, " + FLAT),
    # --- damage masks ---------------------------------------------------
    "mask_delamination": (
        "high contrast black and white silhouette mask of plaster "
        "delamination loss on an old wall, large connected organic black "
        "regions with torn crumbling edges, white intact areas, binary "
        "stencil, no gradients, no shading, flat graphic"),
    "mask_peel": (
        "high contrast black and white stencil of peeling paint and "
        "plaster loss, scattered ragged black islands and channels, "
        "crumbled irregular coastline edges, binary mask, flat graphic, "
        "no gradients"),
    "mask_paper_tear": (
        "high contrast black and white stencil of torn wallpaper sheets, "
        "long vertical ripped strips, curling torn edges, black torn-away "
        "regions, binary mask, flat graphic, no gradients"),
    # --- relief ---------------------------------------------------------
    "relief_plaster": (
        "grayscale displacement height map of crumbling plaster over "
        "brick, raised plaster crust in light gray, recessed exposed brick "
        "courses in dark gray, torn stepped edges between, technical "
        "heightmap, no lighting, no color"),
    "relief_brick": (
        "grayscale displacement height map of an old common brick wall "
        "with raked lime mortar joints, bricks light, mortar recessed "
        "dark, slight per-brick height variation, technical heightmap, "
        "no lighting"),
    # --- overlays -------------------------------------------------------
    "stain_tide": (
        "watercolor-like brown water stain tide marks and mineral salt "
        "efflorescence on a pure white background, horizontal banded "
        "staining, isolated overlay texture, " + FLAT),
    "stain_leak": (
        "long vertical water leak stains running down on a pure white "
        "background, brown and grey drip trails, rust streak, isolated "
        "overlay texture, " + FLAT),
    "stain_soot": (
        "soft grey soot and smoke staining cloud on a pure white "
        "background, heavier at the top, isolated overlay texture, "
        + FLAT),
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    client = Client("black-forest-labs/FLUX.1-schnell")
    done = failed = 0
    for name, prompt in SOURCES.items():
        target = os.path.join(OUT, name + ".png")
        if os.path.exists(target):
            continue
        for attempt in range(3):
            try:
                result = client.predict(
                    prompt=prompt, seed=hash(name) % 100000,
                    randomize_seed=False, width=1024, height=1024,
                    num_inference_steps=4, api_name="/infer")
                path = result[0] if isinstance(result, (list, tuple)) \
                    else result
                if isinstance(path, dict):
                    path = path.get("path")
                shutil.copy(path, target)
                with open(os.path.join(OUT, name + ".txt"), "w",
                          encoding="utf-8") as fh:
                    fh.write(prompt + "\n")
                print("generated", name)
                done += 1
                break
            except Exception as exc:
                print("  retry %d for %s: %s" % (attempt + 1, name,
                                                 str(exc)[:120]))
                time.sleep(20)
        else:
            failed += 1
        time.sleep(4)   # be polite to the public queue
    print("%d generated, %d failed" % (done, failed))


if __name__ == "__main__":
    main()
