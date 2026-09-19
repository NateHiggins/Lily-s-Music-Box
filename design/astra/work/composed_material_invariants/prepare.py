"""Fixture-only offline revision. Existing source/measurements are preserved."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
REL = Path("game/tests/vulkan_composed_root_test.gd")
ORIGINAL_SHA = "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def once(text, anchor, replacement):
    assert text.count(anchor) == 1, anchor
    return text.replace(anchor, replacement, 1)


def proposed(text, helper):
    text = once(text, '\tawait _capture_actual_arcade("actual_arcade_before_passage", true)\n',
                '\tawait _capture_actual_arcade("actual_arcade_before_passage", true)\n'
                '\t_observe_material_ownership("before_measured", true)\n')
    text = once(text, '\t\t\tawait _transition(STATIONS[index], cycle, false)\n',
                '\t\t\tawait _transition(STATIONS[index], cycle, false)\n'
                '\t\t_observe_material_ownership("cycle_%d" % cycle, false)\n')
    text = once(text, '\tawait _transition(STATIONS[1], CYCLES, true)\n',
                '\tawait _transition(STATIONS[1], CYCLES, true)\n'
                '\t_observe_material_ownership("before_retirement", true)\n')
    text = once(text, '\t_phase("after_retirement")\n',
                '\t_check_material_retirement()\n\t_phase("after_retirement")\n')
    text = once(text, '\t\t"native_diagnostics_accepted": false}\n',
                '\t\t"native_diagnostics_accepted": false,\n'
                '\t\t"material_contract": "actual_build_ownership_v1",\n'
                '\t\t"material_observations": material_observations, "material_retirement": material_retirement}\n')
    return text.rstrip() + "\n\n" + helper


def main():
    raw = (ROOT / REL).read_bytes()
    assert sha(raw) == ORIGINAL_SHA, "live fixture drift; rebase explicitly"
    text = raw.decode().replace("\r\n", "\n")
    helper = (HERE / "material_helpers.gdfragment").read_text()
    generated = proposed(text, helper)
    old_dest = HERE / "originals" / REL
    new_dest = HERE / "proposed" / REL
    old_dest.parent.mkdir(parents=True, exist_ok=True)
    new_dest.parent.mkdir(parents=True, exist_ok=True)
    if old_dest.exists(): assert old_dest.read_bytes() == raw
    else: old_dest.write_bytes(raw)
    new_dest.write_bytes(generated.replace("\n", "\r\n").encode())
    patch = "".join(difflib.unified_diff(text.splitlines(True), generated.splitlines(True),
                                       fromfile="a/" + REL.as_posix(), tofile="b/" + REL.as_posix()))
    (HERE / "fixture.patch").write_bytes(patch.encode())
    binding = {"status": "PREPARED_ONLY_NO_GAME_INSTALL_OR_ENGINE_RUN",
               "original_fixture_sha256": sha(raw), "proposed_fixture_sha256": sha(new_dest.read_bytes()),
               "helper_sha256": sha((HERE / "material_helpers.gdfragment").read_bytes()),
               "independent_unit_contract": {"path": "game/data/reality_cases.json",
                                             "sha256": sha((ROOT / "game/data/reality_cases.json").read_bytes()),
                                             "peter_form_corridor": "4A"},
               "ownership_revision_dependency": "7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db",
               "dependency_status": "focused clean candidate reported; final live handoff must be reverified",
               "planned_observations": ["before_measured"] + [f"cycle_{i}" for i in range(6)] + ["before_retirement"],
               "original_assertions_and_timers": "retained; only five anchored insertions and appended helpers",
               "game_changes": [REL.as_posix()], "scene_file": "existing VulkanComposedRootTest.tscn unchanged"}
    (HERE / "preparation.json").write_text(json.dumps(binding, indent=2) + "\n")
    print(json.dumps(binding, indent=2))


if __name__ == "__main__":
    main()
