extends Node
## AU-3 production proof: pooled semantic switch sound removes hundreds of
## permanent players without taking circuit truth away from SwitchSystem.

var checks := 0
var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	var switches: SwitchSystem = root.get("switch_system") as SwitchSystem
	_check("production switch system exists with its full plate family",
			switches != null and switches.switches >= 200)
	_check("no switch carries a private audio player",
			switches.find_children("*", "AudioStreamPlayer3D", true, false).is_empty())
	var plate: Node3D
	for child in switches.get_children():
		if child.has_method("interact") \
				and str(child.get_meta("room_id", "")) in switches._room_fixtures:
			plate = child as Node3D
			break
	_check("one real wired plate is available", plate != null)
	if plate != null:
		AudioPolicy.clear_diagnostics()
		var room_id := str(plate.get_meta("room_id", ""))
		var before := _powered_snapshot(room_id, switches)
		plate.call("interact", root.get("player"))
		var after_first := _powered_snapshot(room_id, switches)
		plate.call("interact", root.get("player"))
		var after_second := _powered_snapshot(room_id, switches)
		var history := AudioPolicy.event_history()
		_check("two physical throws publish two semantic answers",
				history.size() == 2
				and str(history[0].cue_id) != str(history[1].cue_id)
				and str(history[0].source_id) == plate.name
				and str(history[1].source_id) == plate.name)
		_check("the two answers are exactly on and off",
				{str(history[0].cue_id):true, str(history[1].cue_id):true}.keys().has(
						"interaction.switch_on")
				and {str(history[0].cue_id):true,
						str(history[1].cue_id):true}.keys().has(
						"interaction.switch_off"))
		_check("first throw changes the circuit and second restores it",
				before != after_first and before == after_second)
		_check("semantic presentation writes no save key",
				not RealityState.data.has("audio_policy")
				and not RealityState.data.has("audio_cues"))
	_finish()


func _powered_snapshot(room_id: String, switches: SwitchSystem) -> Array[bool]:
	var ids: Dictionary = {}
	for ident in switches._room_fixtures.get(room_id, []):
		ids[str(ident)] = true
	var state: Array[bool] = []
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if ids.has(str(fixture.name)) and "powered" in fixture:
			state.append(bool(fixture.powered))
	return state


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[AUDIO POLICY LIVE] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[AUDIO POLICY LIVE] RESULT: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
