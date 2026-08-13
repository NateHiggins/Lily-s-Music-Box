"""Strip the self-illumination Meshy bakes into every character export.

Each dumped character ships materials with `emissiveFactor: [1,1,1]` and
an emissiveTexture (the albedo again), so the figure glows at full
brightness with its own texture and scene lighting never touches it —
NPCs read fully lit in a pitch-dark corridor. Meshy also doubles
KHR_materials_specular (specularColorFactor 2.0), which blows out
highlights under the grade.

This zeroes emission and clamps specular in the shipped .gltf files.
The converter (convert_dump_characters.py) applies the same law at
export time for future dumps; this tool exists for models already in
the tree. Idempotent; prints what changed. Run godot --import after.

    python art/tools/strip_character_emissive.py
"""
import glob
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
PATTERNS = [
    os.path.join(ROOT, "game", "assets", "characters", "*", "*.gltf"),
    os.path.join(ROOT, "game", "assets", "creatures", "*", "*.gltf"),
]


def strip(path: str, keep_emission: bool = False) -> bool:
    with open(path, encoding="utf-8") as fh:
        doc = json.load(fh)
    changed = False
    for material in doc.get("materials", []):
        # keep_emission spares only the glow — the doubled specular is a
        # separate Meshy defect and is clamped for everyone.
        if not keep_emission:
            if material.pop("emissiveTexture", None) is not None:
                changed = True
            if material.pop("emissiveFactor", None) is not None:
                changed = True
        specular = material.get("extensions", {}).get(
            "KHR_materials_specular", {})
        factor = specular.get("specularColorFactor")
        if factor and any(c > 1.0 for c in factor):
            specular["specularColorFactor"] = [min(c, 1.0) for c in factor]
            changed = True
    if changed:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, separators=(",", ":"))
    return changed


def keep_emission_slugs() -> set:
    """Models whose glow is a decision, not a Meshy artifact. The mapping's
    `keep_emission` flag (owner-ruled 2026-08-13, mina_vale) is honoured by
    the converter at export and must be honoured here too, or one manual
    sweep of shipped files silently undoes it."""
    mapping_path = os.path.join(ROOT, "game", "data",
                                "resident_hero_models.json")
    with open(mapping_path, encoding="utf-8") as fh:
        mapping = json.load(fh)
    slugs = set()
    for section in ("residents", "creatures"):
        for slug, spec in mapping.get(section, {}).items():
            if spec.get("keep_emission"):
                slugs.add(slug)
    return slugs


def main() -> None:
    exempt = keep_emission_slugs()
    touched = 0
    for pattern in PATTERNS:
        for path in sorted(glob.glob(pattern)):
            slug = os.path.splitext(os.path.basename(path))[0]
            kept = slug in exempt
            if kept:
                print("glow kept (keep_emission)",
                      os.path.relpath(path, ROOT))
            if strip(path, keep_emission=kept):
                touched += 1
                print("stripped", os.path.relpath(path, ROOT))
    print("%d files de-glowed" % touched)


if __name__ == "__main__":
    main()
