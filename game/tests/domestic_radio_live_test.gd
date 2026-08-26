extends Node

var failures := 0
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  [%s] %s" % ["radio live ok" if ok else "RADIO LIVE FAIL", label])
	if not ok:
		failures += 1


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root := scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var pass_node := root.find_child("DomesticRadioPass", true, false)
	_check(pass_node != null, "production builds the household receiver pass")
	if pass_node == null:
		_finish()
		return
	var radios: Array = pass_node.get("radios")
	_check(radios.size() == 18, "all 18 occupied apartments receive one authored set")
	var units := {}
	var all_off := true
	var bounded := true
	var all_reachable := true
	var no_blockers := true
	for radio in radios:
		units[str(radio.get("unit"))] = true
		var state: Dictionary = radio.call("public_state")
		all_off = all_off and not bool(state.powered)
		bounded = bounded and float(state.reach) <= 5.5
		all_reachable = all_reachable and radio.find_child(
				"PrimaryInteraction", true, false) is Area3D
		no_blockers = no_blockers and radio.find_children(
				"*", "StaticBody3D", true, false).is_empty()
		no_blockers = no_blockers and radio.find_children(
				"*", "CharacterBody3D", true, false).is_empty()
		no_blockers = no_blockers and radio.find_children(
				"*", "RigidBody3D", true, false).is_empty()
	_check(units.size() == 18, "no apartment is duplicated or omitted")
	_check(all_off, "the building does not boot eighteen simultaneous programmes")
	_check(bounded, "every programme is bounded to apartment scale")
	_check(all_reachable, "every receiver publishes one ray-reachable interaction area")
	_check(no_blockers, "receiver detail adds no body that can obstruct a resident route")
	var baked_ids := {}
	for old_radio in get_tree().get_nodes_in_group("baked_furniture_interactions"):
		if str(old_radio.get_meta("furniture_kind", "")) == "radio":
			baked_ids[str(old_radio.get_meta("furniture_record_id", ""))] = true
	for old_id in ["3B_radio", "5B_k_hob_radio0", "5B_k_hob_radio1",
			"5B_story_radio", "6C_story_old_radio"]:
		_check(baked_ids.has(old_id), "existing biography remains: %s" % old_id)

	var persistence_before := JSON.stringify(RealityState.data)
	var first: Node = radios[0]
	var second: Node = radios[1]
	var second_before: Dictionary = second.call("public_state")
	var result: Dictionary = first.call("interact")
	_check(bool(result.powered) and bool((first.call("public_state") as Dictionary).powered),
			"one household can switch its own receiver on")
	_check((second.call("public_state") as Dictionary) == second_before,
			"switching one receiver cannot tune or power its neighbour")
	_check(JSON.stringify(RealityState.data) == persistence_before,
			"local listening writes no persistent reality or investigation state")
	first.call("interact")
	_check(not bool((first.call("public_state") as Dictionary).powered),
			"the same physical switch returns the set to silence")
	_finish()


func _finish() -> void:
	print("[DOMESTIC RADIO LIVE] RESULT: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
