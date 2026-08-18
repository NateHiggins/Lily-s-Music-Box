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

Run:  python art/tools/fix_runtime_texture_imports.py [--check]

Then re-import, because editing a .import does nothing until Godot re-reads it:

    C:/devkit/bin/godot.cmd --headless --path game --import
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GDSCRIPT = ROOT / "game/scripts/generated/material_sets.gd"
TEXTURES = ROOT / "game/assets/building/textures"

# The settings this tool owns. Anything not named here is left as Godot wrote
# it -- this is a repair, not a second import-settings authority.
WANT = {
    "mipmaps/generate": "true",
    "detect_3d/compress_to": "0",
}


def referenced_textures() -> list[str]:
    """Every PNG the generated material table names.

    Derived from the generated file rather than a list kept here, so a material
    added to RUNTIME_POLICY tomorrow is covered without anyone remembering to
    update this tool.
    """
    text = GDSCRIPT.read_text(encoding="utf-8")
    return sorted(set(re.findall(r'"([^"]+\.png)"', text)))


def patch(path: Path) -> bool:
    """Set the wanted params. Returns True if the file changed."""
    text = path.read_text(encoding="utf-8")
    original = text
    for key, value in WANT.items():
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
    names = referenced_textures()
    if not names:
        print("no textures referenced by %s -- has it been generated?" % GDSCRIPT)
        return 1

    missing, wrong, fixed = [], [], []
    for name in names:
        sidecar = TEXTURES / (name + ".import")
        if not sidecar.is_file():
            missing.append(name)
            continue
        text = sidecar.read_text(encoding="utf-8")
        if all(re.search(r"^%s=%s$" % (re.escape(k), re.escape(v)), text, re.M)
               for k, v in WANT.items()):
            continue
        wrong.append(name)
        if not check_only and patch(sidecar):
            fixed.append(name)

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
        print("  C:/devkit/bin/godot.cmd --headless --path game --import")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
