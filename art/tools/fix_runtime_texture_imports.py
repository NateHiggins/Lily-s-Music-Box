"""Give MatLib's runtime textures the import settings Godot never gives them.

THE BUG
-------
Godot decides a texture's import settings when it first sees the file. For a
texture used on a 3D surface it wants mipmaps and VRAM compression, so it ships
a default of `detect_3d/compress_to=1`, meaning "the first time you notice this
on a 3D material, re-import it properly".

That detection runs in the EDITOR. MatLib (game/scripts/material_library.gd)
never puts a texture on a material in the editor -- it calls `load()` at
runtime, from a generated table. So the editor never notices, `detect_3d` never
fires, and every texture the runtime prop materials use keeps the 2D defaults
it was born with: `mipmaps/generate=false`.

No mip chain is not a memory problem, it is a PICTURE problem. A 1024px albedo
sampled at any distance with no mips aliases, and on the triplanar-projected
surfaces MatLib builds -- corridor floors, the street -- that reads as crawling
shimmer whenever the camera moves. It also silently voids
`textures/default_filters/anisotropic_filtering_level=4` in game/project.godot:
anisotropic filtering selects between mip levels, so with no mips the 16x the
project believes it is spending does nothing at all.

WHAT THIS DOES, AND WHAT IT DELIBERATELY DOES NOT
-------------------------------------------------
Sets, on every texture the generated material table references:

    mipmaps/generate=true      the fix; kills the shimmer, makes 16x aniso real
    detect_3d/compress_to=0    stop Godot silently re-deciding this later

It deliberately leaves `compress/mode=0` (lossless) alone. An earlier audit
recommended mode=2 to recover ~223 MB of VRAM, which is true and which we are
NOT doing, on the owner's ruling of 2026-08-17: "dont worry about budget until
we hit performance issues on a desktop." Block compression is lossy, so at zero
budget pressure lossless is simply the better picture. Two consequences worth
knowing: this stays the memory-expensive choice, and it sidesteps the 27
referenced textures whose dimensions are not multiples of four (317, 322, 350
px) and which block compression cannot accept anyway -- a fix that flipped
mode=2 would appear to succeed and silently leave those 27 uncompressed.

If a desktop ever does show a problem, this file is where to reverse that.

The V2 owner direction of 2026-10-11 adds --v2: all shipped building surface
maps (including height/masks/wall finishes), high-quality GPU compression,
complete mip chains, preserved RGB normals. This supersedes lossless-only
for that scope. It leaves the original dream policy unchanged.

Run:  python art/tools/fix_runtime_texture_imports.py [--v2] [--check] [--json]

Then re-import, because editing a .import does nothing until Godot re-reads it:

    pwsh -File tools/lane.ps1 run -ExtraArgs --import -LogPath tmp/texture-import.log
"""
from __future__ import annotations

import re
import sys
import subprocess
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GDSCRIPT = ROOT / "game/scripts/generated/material_sets.gd"
TEXTURES = ROOT / "game/assets/building/textures"
# The dream's surfaces have the same disease for the same reason: they are bound
# at runtime by dream_maze_builder.gd, one per Klimt motif, so the editor never
# sees them on a 3D material either. Worse there than in the waking building --
# dream_klimt.gdshader declares filter_linear_mipmap on all three samplers, so
# it is explicitly asking for a mip chain that does not exist. It also blocks
# the stochastic/hex tiling on the coverage list, which needs textureGrad
# against real mips or it looks worse than the repetition it replaces.
DREAM = ROOT / "game/assets/dream"

# The settings this tool owns. Anything not named here is left as Godot wrote
# it -- this is a repair, not a second import-settings authority.
WANT = {
    "mipmaps/generate": "true",
    "detect_3d/compress_to": "0",
}

V2_WANT = {
    **WANT,
    "mipmaps/limit": "-1",
    "compress/mode": "2",
    "compress/high_quality": "true",
    # Existing custom shaders explicitly consume normal RGB. Preserve Z:
    # RGTC is safe only once those consumers reconstruct it from XY.
    "compress/normal_map": "2",
}

# Physical maps reached by the composed V2 world outside the building library.
# Sky projections and UI-only images retain their own sampling authority.
V2_EXTERNAL_MAPS = (
    "game/assets/characters/mina_vale/texture_0_metallic-texture_0_roughness.png",
    "game/assets/characters/mina_vale/texture_0_normal.png",
    "game/assets/ui/telegram/telegram_paper_stock_v1.png",
)


def v2_sidecars() -> list[Path]:
    """All shipped building images, including height, masks and wall finishes.

    Git source paths prevent generated glTF image extracts and local review
    inputs becoming accidental shipping authority. Sky is an environment
    projection, governed by its separate half-dome import recipe.
    """
    paths = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "game/assets/building/textures"],
        text=True, encoding="utf-8").splitlines()
    runtime_names=set(re.findall(r'"([^"]+\.png)"',GDSCRIPT.read_text(encoding="utf-8")))
    return sorted({ROOT / (name + ".import") for name in paths
                   if Path(name).suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
                   and "/sky/" not in name} |
                  {ROOT / (name + ".import") for name in V2_EXTERNAL_MAPS} |
                  {TEXTURES / (name + ".import") for name in runtime_names})


def sidecars() -> list[Path]:
    """Every .import this tool owns: the runtime prop set, plus the dream.

    The prop list is read out of the GENERATED material table rather than kept
    here, so a material added to RUNTIME_POLICY tomorrow is covered without
    anyone remembering this tool exists. The dream is taken wholesale because
    everything under it is bound at runtime by definition.
    """
    found: list[Path] = []
    text = GDSCRIPT.read_text(encoding="utf-8")
    for name in sorted(set(re.findall(r'"([^"]+\.png)"', text))):
        found.append(TEXTURES / (name + ".import"))
    if DREAM.is_dir():
        found.extend(sorted(DREAM.rglob("*.png.import")))
        found.extend(sorted(DREAM.rglob("*.jpg.import")))
    return found


def patch(path: Path, wanted: dict[str, str] | None = None) -> bool:
    """Set the wanted params. Returns True if the file changed."""
    text = path.read_text(encoding="utf-8")
    original = text
    for key, value in (WANT if wanted is None else wanted).items():
        pattern = re.compile(r"^%s=.*$" % re.escape(key), re.M)
        if pattern.search(text):
            text = pattern.sub("%s=%s" % (key, value), text)
        else:
            # Absent means Godot is using its own default, which is the very
            # thing that went wrong here. Append it to [params] explicitly.
            text = text.rstrip("\n") + "\n%s=%s\n" % (key, value)
    if text == original:
        return False
    path.write_text(text, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    check_only = "--check" in sys.argv
    v2 = "--v2" in sys.argv
    names = v2_sidecars() if v2 else sidecars()
    wanted = V2_WANT if v2 else WANT
    if not names:
        print("nothing to check -- has %s been generated?" % GDSCRIPT)
        return 1

    missing, wrong, fixed = [], [], []
    for sidecar in names:
        name = sidecar.name
        if not sidecar.is_file():
            source=Path(str(sidecar).removesuffix(".import"))
            if v2 and not check_only and source.is_file():
                resource="res://"+source.relative_to(ROOT/"game").as_posix()
                sidecar.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="'+resource+'"\n\n[params]\n',newline="\n")
            else:
                missing.append(name)
                continue
        text = sidecar.read_text(encoding="utf-8")
        if all(re.search(r"^%s=%s$" % (re.escape(k), re.escape(v)), text, re.M)
               for k, v in wanted.items()):
            continue
        wrong.append(name)
        if not check_only and patch(sidecar, wanted):
            fixed.append(name)

    if "--json" in sys.argv:
        print(json.dumps({"scope":"v2" if v2 else "runtime_and_dream",
                          "referenced":len(names),"missing":missing,
                          "wrong":wrong,"fixed":fixed}))
        return 1 if missing or (check_only and wrong) else 0

    print("runtime textures referenced: %d" % len(names))
    print("  already correct : %d" % (len(names) - len(wrong) - len(missing)))
    print("  needed repair   : %d" % len(wrong))
    if missing:
        print("  MISSING .import : %d  %s" % (len(missing), ", ".join(missing[:5])))
    if check_only:
        if wrong or missing:
            print("\ncheck failed: run without --check, then re-import")
            return 1
        print("\ncheck passed")
        return 0
    print("  repaired        : %d" % len(fixed))
    if fixed:
        print("\nNOW RE-IMPORT, or nothing above has taken effect:")
        print("  pwsh -File tools/lane.ps1 run -ExtraArgs --import -LogPath tmp/texture-import.log")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
