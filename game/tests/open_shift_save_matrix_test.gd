extends Node

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")
const Selector := preload("res://scripts/building/building_root_selector.gd")
const DISPOSITIONS := ["work", "ignore", "abandon", "meddle"]
const DIRECTIONS := [["v1", "v1"], ["v2", "v2"], ["v1", "v2"],
		["v2", "v1"]]

var failures := 0
var passes := 0
var minute := 700.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	var original_path := RealityState.save_path
	for disposition: String in DISPOSITIONS:
		for direction: Array in DIRECTIONS:
			await _exercise(disposition, str(direction[0]), str(direction[1]))
	RealityState.save_path = original_path
	RealityState.persistence_enabled = false
	Selector.reset_for_tests()
	_check(Selector.selected_id() == "v1", "committed selector default remains v1")
	print("OPEN SHIFT SAVE MATRIX: %d/%d PASS" % [passes,
			DISPOSITIONS.size() * DIRECTIONS.size() + 1])
	get_tree().quit(failures)


func _exercise(disposition: String, from_root: String, to_root: String) -> void:
	RealityState.reset_campaign_for_tests()
	var radiator := RadiatorProp.new()
	add_child(radiator)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(null, radiator, null, func(): return minute)
	ecosystem.situation.offer(ServiceRoundDirector.RESIDENT_ID)
	match disposition:
		"work":
			ecosystem._on_route_beat("call")
			ecosystem._on_route_beat("radiator_evidence")
			ecosystem._on_route_beat("diagnosis")
			ecosystem._on_route_beat("repair")
			ecosystem._on_route_beat("resident_return")
		"ignore":
			minute += 20.0
			ecosystem.advance_autonomy()
		"abandon":
			ecosystem.abandon_after("opened_uncommitted")
		"meddle":
			ecosystem.meddle_wrong_valve()
	var expected := ecosystem.situation.state()
	var save_path := "user://tests/open_shift_%s_%s_%s.json" % [
		disposition, from_root, to_root]
	RealityState.save_path = save_path
	RealityState.persistence_enabled = true
	Selector.reset_for_tests(from_root)
	var saved := RealityState.save_game()
	ecosystem.queue_free()
	radiator.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	Selector.reset_for_tests(to_root)
	var restored: Dictionary = RealityState.data.open_shift_situations.get(
			Ecosystem.SITUATION_ID, {})
	var semantic_ok: bool = restored.get("resolution_kind") \
			== expected.get("resolution_kind") \
			and restored.get("abandonment_boundary") \
			== expected.get("abandonment_boundary") \
			and restored.get("observed_interference") \
			== expected.get("observed_interference") \
			and restored.get("residue") == expected.get("residue") \
			and not RealityState.data.has("building_selector")
	_check(saved and semantic_ok and Selector.selected_id() == to_root,
			"%s survives %s -> %s reconstruction" % [
			disposition.to_upper(), from_root, to_root])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	RealityState.persistence_enabled = false


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
