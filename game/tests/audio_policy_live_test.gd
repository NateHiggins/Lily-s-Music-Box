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
	await _prove_standard_doors(root)
	_prove_legacy_helper_routing(root)
	_prove_production_bus_census(get_tree().root)
	_finish()


func _prove_standard_doors(root: Node) -> void:
	var standard: Array[DoorProp] = []
	var closed: DoorProp
	var locked: DoorProp
	for candidate in root.find_children("*", "DoorProp", true, false):
		var door := candidate as DoorProp
		if door == null or door.get_script().resource_path \
				!= "res://scripts/props/door_prop.gd":
			continue
		standard.append(door)
		if closed == null and door.leaf_state == "closed" and not door.open:
			closed = door
		if locked == null and door.leaf_state == "locked":
			locked = door
	_check("production owns %d ordinary door leaves" % standard.size(),
			standard.size() >= 100)
	var private_players := 0
	for door in standard:
		for child in door.get_children():
			if child is AudioStreamPlayer3D:
				private_players += 1
	_check("%d ordinary doors carry %d private audio players" % [
			standard.size(), private_players],
			private_players == 0)
	_check("closed and locked production leaves exist", closed != null and locked != null)
	if closed == null or locked == null:
		return
	AudioPolicy.clear_diagnostics()
	closed.interact(root.get("player"))
	await get_tree().create_timer(0.65).timeout
	closed.interact(root.get("player"))
	await get_tree().create_timer(0.65).timeout
	var movement := AudioPolicy.event_history()
	_check("open, close and latch are three ordered physical answers",
			movement.size() == 3
			and str(movement[0].cue_id) == "interaction.door_move"
			and str(movement[1].cue_id) == "interaction.door_move"
			and str(movement[2].cue_id) == "interaction.door_latch")
	_check("the door is restored shut", not closed.open)
	AudioPolicy.clear_diagnostics()
	locked.interact(root.get("player"))
	await get_tree().create_timer(0.35).timeout
	var refusal := AudioPolicy.event_history()
	var only_locked := true
	for event in refusal:
		only_locked = only_locked \
				and str(event.cue_id) == "interaction.door_locked"
	_check("a locked leaf answers with three rattles and never moves",
			refusal.size() == 3 and not locked.open
			and only_locked)


func _prove_legacy_helper_routing(root: Node) -> void:
	var routed := 0
	var on_master := 0
	var bad_bus := 0
	for node in root.find_children("*", "AudioStreamPlayer3D", true, false):
		if str(node.get_meta("audio_route", "")) != "legacy_helper":
			continue
		routed += 1
		if node.bus == "Master":
			on_master += 1
		if AudioServer.get_bus_index(node.bus) < 0:
			bad_bus += 1
	_check("%d legacy helper emitters are explicitly marked" % routed,
			routed >= 50)
	_check("legacy helper debt no longer bypasses policy on Master",
			on_master == 0 and bad_bus == 0)


func _prove_production_bus_census(root: Node) -> void:
	var players: Array[Node] = []
	_collect_audio_players(root, players)
	var census: Dictionary = {}
	var master_paths: Array[String] = []
	for node in players:
		var bus := str(node.get("bus"))
		census[bus] = int(census.get(bus, 0)) + 1
		if bus == "Master":
			master_paths.append(str(root.get_path_to(node)))
	var buses := census.keys()
	buses.sort()
	var entries: Array[String] = []
	for bus in buses:
		entries.append("%s=%d" % [bus, int(census[bus])])
	print("[AUDIO POLICY LIVE] BUS CENSUS %s" % ", ".join(entries))
	if not master_paths.is_empty():
		print("[AUDIO POLICY LIVE] MASTER PATHS %s" % ", ".join(master_paths))
	_check("all %d production audio players declare a bus" % players.size(),
			master_paths.is_empty())
	_check("processed ambience rejoins the canonical World mix",
			AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience"))
			== "World")
	_check("processed ghost radio rejoins canonical diegetic music",
			AudioServer.get_bus_send(AudioServer.get_bus_index("GhostRadio"))
			== "Diegetic")


func _collect_audio_players(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D \
				or child is AudioStreamPlayer3D:
			out.append(child)
		_collect_audio_players(child, out)


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
