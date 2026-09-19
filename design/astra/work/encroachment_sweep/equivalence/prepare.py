"""Prepare exact production-method copies; never write into the live game."""
from __future__ import annotations

import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
REVISION = ROOT / "design/astra/work/encroachment_sweep/revisions/ownership_69e28e_01"
REL = Path("game/scripts/reality/apartment_encroachment.gd")
ORIGINAL_HASH = "69e28e38740f122fe5bfd47b9f8bc6194fd5e52dda2eae085163deee30977860"
START = "func reach_props(root: Node) -> int:\n"
END = "\n\nfunc _apply_prop_states"
CLASS = "class_name ApartmentEncroachment\n"
PRIORITY = "\t\tfor case_id in units:\n\t\t\tvar unit: Dictionary = units[case_id]\n"
CENSUS = '\tfor node in root.find_children("*", "MeshInstance3D", true, false):\n'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def method_parts(text: str) -> tuple[str, str, str]:
    assert text.count(START) == 1
    a = text.index(START)
    b = text.index(END, a)
    return text[:a], text[a:b], text[b:]


def adapted(text: str) -> str:
    assert text.startswith(CLASS)
    # The only other class-name spelling is a node-name string in build().
    assert text.count("ApartmentEncroachment") == 2
    return text.removeprefix(CLASS)


def variant_source(candidate: str, variant: str) -> str:
    before, method, after = method_parts(candidate)
    if variant == "candidate":
        return candidate
    if variant == "priority":
        assert method.count(PRIORITY) == 1
        method = method.replace(PRIORITY,
            "\t\tvar reversed_cases: Array = units.keys()\n"
            "\t\treversed_cases.reverse()\n"
            "\t\tfor case_id in reversed_cases:\n"
            "\t\t\tvar unit: Dictionary = units[case_id]\n", 1)
    elif variant == "drop_late":
        assert method.count(CENSUS) == 1
        method = method.replace(CENSUS,
            "\tif not has_meta(\"equivalence_first_census\"):\n"
            "\t\tset_meta(\"equivalence_first_census\", root.find_children(\"*\", \"MeshInstance3D\", true, false))\n"
            "\tfor node in get_meta(\"equivalence_first_census\"):\n", 1)
    else:
        raise ValueError(variant)
    return before + method + after


def main() -> None:
    old_path = REVISION / "originals" / REL
    new_path = REVISION / "proposed" / REL
    old_bytes, new_bytes = old_path.read_bytes(), new_path.read_bytes()
    assert sha(old_bytes) == ORIGINAL_HASH, "reviewed ownership source changed"
    old = old_bytes.decode().replace("\r\n", "\n")
    new = new_bytes.decode().replace("\r\n", "\n")
    old_parts, new_parts = method_parts(old), method_parts(new)
    assert old_parts[0] == new_parts[0] and old_parts[2].lstrip("\n") == new_parts[2].lstrip("\n")
    assert "static func _living_candidate(mi: MeshInstance3D, scope: Node) -> bool:" in new
    fixture_dir = HERE / "proposed/game/tests/fixtures/encroachment_sweep"
    fixture_dir.mkdir(parents=True, exist_ok=True)
    artifacts = {}
    for label in ("baseline", "candidate", "priority", "drop_late"):
        source = old if label == "baseline" else variant_source(new, label)
        out = fixture_dir / (label + ".gd")
        out.write_bytes(adapted(source).encode())
        artifacts[str(out.relative_to(HERE)).replace("\\", "/")] = sha(out.read_bytes())
        if label not in ("baseline", "candidate"):
            patch = "".join(difflib.unified_diff(new.splitlines(True), source.splitlines(True),
                fromfile="candidate/apartment_encroachment.gd", tofile=label + "/apartment_encroachment.gd"))
            (HERE / (label + ".patch")).write_bytes(patch.encode())
    binding = {
        "status": "PREPARED_ONLY_NO_ENGINE_RUN_OR_LIVE_INSTALL",
        "original_source": str(old_path.relative_to(ROOT)).replace("\\", "/"),
        "candidate_source": str(new_path.relative_to(ROOT)).replace("\\", "/"),
        "original_sha256": sha(old_bytes), "candidate_sha256": sha(new_bytes),
        "comparison": "same ownership repair; only reach_props method differs",
        "adapter": "Normalize CRLF to LF; remove the single global class_name declaration so exact production methods can coexist. No method or preload adaptation.",
        "scope": "Deterministic actual-method material/ownership equivalence under authored fixture bounds; production build and composed rendering remain separate.",
        "artifacts": artifacts,
    }
    (HERE / "preparation.json").write_text(json.dumps(binding, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(binding, indent=2))


if __name__ == "__main__":
    main()
