"""Prepare diagnostic timing instrumentation from frozen candidate source.

No live game writes and no engine invocation. This is a measurement probe, not
a proposed shipping implementation or an assertion that any phase is slow.
"""
from pathlib import Path
import difflib
import hashlib
import json

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
FROZEN = ROOT / "design/astra/evidence/vulkan_composed/runs/candidate_v1_foundations_01/before_sources"


def one(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    rel = "game/scripts/building/building_root.gd"
    original = (FROZEN / rel).read_bytes()
    assert sha(original) == "cde44cd16b9ebdfedde0bcda34b404c2a675adffe106ba4ac0d576d26e8e1fd4"
    text = original.decode().replace("\r\n", "\n")
    text = one(text, "func _apply_visibility(p: Vector3) -> void:\n", """# Diagnostic-only phase instrumentation; all original work still executes.
var _astra_visibility_profile: Dictionary = {}
var _astra_visibility_profile_active := false


func _apply_visibility(p: Vector3) -> void:
	var profile_started := Time.get_ticks_usec()
	_astra_visibility_profile_active = true
	_astra_visibility_profile = {"from_passage": passage_visible,
		"to_passage": _point_is_in_passage(p), "mask_changes": 0,
		"rebind_us": 0, "layer_assign_us": 0}
""")
    text = one(text, "\t_set_street_core_visibility(not _point_is_low_street(p))\n\t_set_passage_visibility(in_passage)\n", """	var profile_phase := Time.get_ticks_usec()
	_set_street_core_visibility(not _point_is_low_street(p))
	_astra_visibility_profile["street_gate_us"] = Time.get_ticks_usec() - profile_phase
	profile_phase = Time.get_ticks_usec()
	_set_passage_visibility(in_passage)
	_astra_visibility_profile["passage_gate_us"] = Time.get_ticks_usec() - profile_phase
	profile_phase = Time.get_ticks_usec()
""")
    text = one(text, "\t\t\tif door.visible != should_show_door:\n\t\t\t\tdoor.visible = should_show_door\n", """			if door.visible != should_show_door:
				door.visible = should_show_door
	_astra_visibility_profile["remaining_owners_us"] = Time.get_ticks_usec() - profile_phase
	_astra_visibility_profile["total_us"] = Time.get_ticks_usec() - profile_started
	_astra_visibility_profile_active = false
""")
    text = one(text, "\t_index_late_f01_geometry()\n\tsurface_pass.apply_props(self)\n\tpassage_visible = should_show\n", """	var profile_phase := Time.get_ticks_usec()
	_index_late_f01_geometry()
	_astra_visibility_profile["passage_index_us"] = Time.get_ticks_usec() - profile_phase
	profile_phase = Time.get_ticks_usec()
	surface_pass.apply_props(self)
	_astra_visibility_profile["surface_and_callbacks_us"] = Time.get_ticks_usec() - profile_phase
	profile_phase = Time.get_ticks_usec()
	passage_visible = should_show
""")
    text = one(text, "\t\telse:\n\t\t\tactor.visible = should_show\n", """		else:
			actor.visible = should_show
	_astra_visibility_profile["passage_owner_changes_us"] = Time.get_ticks_usec() - profile_phase
""")
    text = one(text, "\t_index_street_core_geometry()\n\tstreet_core_visible = should_show\n", """	var profile_phase := Time.get_ticks_usec()
	_index_street_core_geometry()
	_astra_visibility_profile["street_index_us"] = Time.get_ticks_usec() - profile_phase
	profile_phase = Time.get_ticks_usec()
	street_core_visible = should_show
""")
    text = one(text, '\t\t\t_zone_toggle(geometry, should_show, "street_core")\n', """			_zone_toggle(geometry, should_show, "street_core")
	_astra_visibility_profile["street_owner_changes_us"] = Time.get_ticks_usec() - profile_phase
""")
    text = one(text, "\tsurface_pass.on_props_applied = func() -> void:\n\t\tif apartment_encroachment != null:\n\t\t\tapartment_encroachment.reach_props(self)\n\t\tif organism_incidents != null:\n\t\t\torganism_incidents.attach_props()\n", """	surface_pass.on_props_applied = func() -> void:
		var profile_phase := Time.get_ticks_usec()
		if apartment_encroachment != null:
			apartment_encroachment.reach_props(self)
		if _astra_visibility_profile_active:
			_astra_visibility_profile["encroachment_callback_us"] = Time.get_ticks_usec() - profile_phase
		profile_phase = Time.get_ticks_usec()
		if organism_incidents != null:
			organism_incidents.attach_props()
		if _astra_visibility_profile_active:
			_astra_visibility_profile["incidents_callback_us"] = Time.get_ticks_usec() - profile_phase
""")
    text = one(text, "\tif vi is GeometryInstance3D and vi.is_inside_tree():\n", "\tvar profile_rebind := Time.get_ticks_usec()\n\tif vi is GeometryInstance3D and vi.is_inside_tree():\n")
    text = one(text, "\tvi.layers = target_layers\n", """	var profile_assign := Time.get_ticks_usec()
	vi.layers = target_layers
	if _astra_visibility_profile_active:
		_astra_visibility_profile["mask_changes"] += 1
		_astra_visibility_profile["rebind_us"] += profile_assign - profile_rebind
		_astra_visibility_profile["layer_assign_us"] += Time.get_ticks_usec() - profile_assign
""")
    edits = [(rel, original, text.encode())]
    rel = "game/tests/vulkan_composed_root_test.gd"
    original = (FROZEN / rel).read_bytes()
    assert sha(original) == "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3"
    text = original.decode().replace("\r\n", "\n")
    text = one(text, "\tvar apply_usec := Time.get_ticks_usec() - started\n", "\tvar apply_usec := Time.get_ticks_usec() - started\n\tvar phase_profile: Dictionary = world._astra_visibility_profile.duplicate(true)\n")
    text = one(text, '\t\t"apply_usec": apply_usec, "repeated_scan_count": 16,', '\t\t"phase_profile": phase_profile, "apply_usec": apply_usec, "repeated_scan_count": 16,')
    edits.append((rel, original, text.encode()))
    patch = ""
    binding = {}
    for rel, before, after in edits:
        for folder, content in [("originals", before), ("proposed", after)]:
            path = BASE / folder / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists():
                assert path.read_bytes() == content, "refuse to overwrite previous preparation"
            else:
                path.write_bytes(content)
        patch += "".join(difflib.unified_diff(before.decode().replace("\r\n", "\n").splitlines(True),
            after.decode().splitlines(True), fromfile="a/" + rel, tofile="b/" + rel))
        binding[rel] = {"original_sha256": sha(before), "diagnostic_sha256": sha(after)}
    (BASE / "visibility_transition_profile.patch").write_text(patch, encoding="utf-8", newline="\n")
    (BASE / "preparation.json").write_text(json.dumps({"status": "PREPARED_UNRUN_NOT_INSTALLED",
        "frozen_source": str(FROZEN), "bindings": binding,
        "scope": "Diagnostic attribution only. All original calls, physics, actors, rendering settings and assertions retained. Per-mask timing bookkeeping adds overhead; compare broad phase attribution, never claim shipping frame cost from this instrumented source."}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
