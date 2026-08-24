extends Node
## N9: PETER PROVES THE SHARED PROFILE SEAM.
##
## This is deliberately not a second-case campaign. It proves the narrower
## production claim the queue asks for: one additional data profile can change
## onset, release print, run ceiling, deterministic building, a navigation
## consequence, Tenant attention and the case's sentence while every owner and
## save boundary remains the one Mina shipped.

const SEED_HEX := "f123456789abcdef"
const PETER_CASE := "peter_form_corridor"
const PETER_PROFILE := "peter_release_print"
const MINA_CASE := "mina_caption_crisis"
const MINA_PROFILE := "mina_release_print"
const JUNO_CASE := "juno_feedback_tetris"
const JUNO_PROFILE := "juno_release_print"
const MAE_CASE := "mae_contradictory_antiques"
const MAE_PROFILE := "mae_release_print"
const CAL_CASE := "cal_memory_radio"
const CAL_PROFILE := "cal_release_print"
const OMAR_CASE := "omar_unrepairable"
const OMAR_PROFILE := "omar_release_print"
const PROFILE_PATH := "res://data/dream_profiles.json"
const CASE_PATH := "res://data/reality_cases.json"

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[N9 PROFILE] START")
	var profiles := _profile_book()
	_data_contract(profiles)
	await _root_contract()
	await _grammar_contract(profiles)
	print("[N9 PROFILE] CHECKS: %d/%d fails=%d" %
			[checks - failures, checks, failures])
	print("DREAM PROFILE TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _data_contract(profiles: Dictionary) -> void:
	var peter: Dictionary = profiles.get(PETER_PROFILE, {})
	var mina: Dictionary = profiles.get(MINA_PROFILE, {})
	var juno: Dictionary = profiles.get(JUNO_PROFILE, {})
	var mae: Dictionary = profiles.get(MAE_PROFILE, {})
	var cal: Dictionary = profiles.get(CAL_PROFILE, {})
	var omar: Dictionary = profiles.get(OMAR_PROFILE, {})
	_check("the shared book contains six ruled profiles",
			not mina.is_empty() and not peter.is_empty() and not juno.is_empty()
			and not mae.is_empty() and not cal.is_empty() and not omar.is_empty())
	_check("Peter is the second campaign profile",
			str(peter.get("case_id", "")) == PETER_CASE
			and int(peter.get("campaign_slot", 0)) == 2)
	var onset: Dictionary = peter.get("onset", {})
	var forms: Array = onset.get("allowed_forms", [])
	_check("Peter may arrive suddenly but accessibility can still force gradual",
			"sudden" in forms and "gradual" in forms
			and float(onset.get("sudden_seconds", 0.0)) > 0.0
			and float(onset.get("gradual_seconds", 0.0)) > 0.0)
	_check("the release print is Peter rather than the next unresolved resident",
			str((peter.get("pursuit", {}) as Dictionary).get(
					"silhouette_resident", "")) == "peter_wren")
	_check("Mina carries no accidental form-corridor rule",
			(mina.get("maze", {}) as Dictionary).is_empty())
	var truth: Dictionary = peter.get("truth", {})
	var cases := _json_dictionary(CASE_PATH)
	var peter_case: Dictionary = cases.get(PETER_CASE, {})
	_check("Peter's dream sentence is the case's authored portal rule",
			str(truth.get("statement", "")) == str(
					peter_case.get("portal_rule", ""))
			and str(truth.get("rule_id", "")) == "proceed_uncertain")
	_check("Peter does not inherit Mina's three armed hazards",
			(peter.get("hazards", {}) as Dictionary).get("allow", []).is_empty())
	var juno_maze: Dictionary = juno.get("maze", {})
	var juno_pursuit: Dictionary = juno.get("pursuit", {})
	var juno_case: Dictionary = cases.get(JUNO_CASE, {})
	_check("Juno is slot three and carries the ruled sentence without theft",
			str(juno.get("case_id", "")) == JUNO_CASE
			and int(juno.get("campaign_slot", 0)) == 3
			and str((juno.get("truth", {}) as Dictionary).get("statement", ""))
					== str(juno_case.get("portal_rule", "")))
	_check("Juno's shared attention names her generic spatial event",
			str(juno_pursuit.get("attention_event", ""))
					== str(juno_maze.get("channel_echo_event", ""))
			and not str(juno_maze.get("channel_echo_event", "")).is_empty())
	_check("Juno adds no form corridor and inherits no Mina hazards",
			not juno_maze.has("junction_reverse_event")
			and (juno.get("hazards", {}) as Dictionary).get("allow", []).is_empty())
	var mae_maze: Dictionary = mae.get("maze", {})
	_check("Mae is slot four with the case's exact non-adjudicating truth",
			str(mae.get("case_id", "")) == MAE_CASE
			and int(mae.get("campaign_slot", 0)) == 4
			and str((mae.get("truth", {}) as Dictionary).get("statement", ""))
					== str((cases.get(MAE_CASE, {}) as Dictionary).get("portal_rule", "")))
	_check("Mae requests one generic convergence and no earlier grammar",
			mae_maze.has("convergence_return_event")
			and not mae_maze.has("junction_reverse_event")
			and not mae_maze.has("channel_echo_event")
			and (mae.get("hazards", {}) as Dictionary).get("allow", []).is_empty())
	var cal_maze: Dictionary = cal.get("maze", {})
	_check("Cal is slot five with the waking case's exact presence truth",
			str(cal.get("case_id", "")) == CAL_CASE
			and int(cal.get("campaign_slot", 0)) == 5
			and str((cal.get("truth", {}) as Dictionary).get("statement", ""))
					== str((cases.get(CAL_CASE, {}) as Dictionary).get("portal_rule", "")))
	_check("Cal requests only a bounded generic threshold handoff",
			str(cal_maze.get("broadcast_handoff_event", "")).is_empty() == false
			and int(cal_maze.get("broadcast_max_handoffs", 0)) == 4
			and not cal_maze.has("junction_reverse_event")
			and not cal_maze.has("channel_echo_event")
			and not cal_maze.has("convergence_return_event")
			and (cal.get("hazards", {}) as Dictionary).get("allow", []).is_empty())
	var omar_maze: Dictionary = omar.get("maze", {})
	_check("Omar is slot six with the waking case's exact unrepairable truth",
			str(omar.get("case_id", "")) == OMAR_CASE
			and int(omar.get("campaign_slot", 0)) == 6
			and str((omar.get("truth", {}) as Dictionary).get("statement", ""))
					== str((cases.get(OMAR_CASE, {}) as Dictionary).get("portal_rule", "")))
	_check("Omar requests only the generic revisit-fault presentation",
			str(omar_maze.get("revisit_fault_event", ""))
					== "impossible_fault_revealed"
			and not omar_maze.has("junction_reverse_event")
			and not omar_maze.has("channel_echo_event")
			and not omar_maze.has("convergence_return_event")
			and not omar_maze.has("broadcast_handoff_event")
			and (omar.get("hazards", {}) as Dictionary).get("allow", []).is_empty())


func _root_contract() -> void:
	var peter := await _spawn_root(PETER_CASE, PETER_PROFILE)
	_check("Peter builds through the production DreamMazeRoot", peter.maze_built)
	_check("slot two reads the authored 38-second ceiling",
			is_equal_approx(peter.run_cap_s, 38.0))
	_check("the shared pursuer borrows Peter's release print",
			peter.pursuer != null
			and peter.pursuer.silhouette_source == "peter_wren")
	_check("the active case truth is data, not a Peter branch",
			str(peter.active_case_truth().get("statement", ""))
					== "Uncertainty does not prevent action")
	_check("Peter's pocket arms no Mina hazard by accident",
			peter.hazards != null and peter.hazards.hazards.is_empty())
	var peter_path: PackedInt32Array = peter.get("_here_path")
	var peter_room_id := int(peter.rooms.atlas.room_id(peter_path))
	var shared_root_script: Script = peter.get_script()
	var old_last := peter.pursuer.last_known_position
	peter.player.position += Vector3(1.25, 0.0, -0.75)
	_check("an unrelated event cannot change Peter's pursuit",
			not peter.pursuer.notify_profile_event("wrong_event")
			and peter.pursuer.last_known_position == old_last)
	_check("the authored hesitation event refreshes the same last-known owner",
			peter.pursuer.notify_profile_event("junction_reverse")
			and peter.pursuer.last_known_position.is_equal_approx(
					Vector3(peter.player.position.x, 0.0,
							peter.player.position.z))
			and int(peter.pursuer.run_parameters().profile_event_count) == 1)
	# Exercise the production bridge as movement, not as another direct unit
	# call: the shared root must notice the body re-entering its parent, ask the
	# room owner for the consequence, then forward only the event to pursuit.
	peter.set_physics_process(false)
	var bridge_pair := _find_junction_pair(peter.rooms,
			peter.get("_architecture") as Node3D,
			peter.get("_here_path") as PackedInt32Array)
	var bridge_ok := not bridge_pair.is_empty()
	if bridge_ok:
		var bridge_from := str(bridge_pair.from)
		var bridge_to := str(bridge_pair.to)
		var target: Dictionary = peter.rooms.room_at_key(bridge_to)
		var rect: Array = target.rect
		peter.set("_here_key", bridge_from)
		peter.set("_here_path", peter.rooms.path_of(bridge_from))
		peter.player.position = Vector3(
				(float(rect[0]) + float(rect[2])) * 0.5, 0.0,
				(float(rect[1]) + float(rect[3])) * 0.5)
		peter.call("_follow_player")
		var crossed: Dictionary = peter.rooms.room_at_key(bridge_to)
		bridge_ok = int(crossed.get("form_stamps", 0)) == 1 \
				and int(peter.pursuer.run_parameters().profile_event_count) == 2
	_check("the production threshold bridge stamps space and informs pursuit",
			bridge_ok)
	peter.queue_free()
	await get_tree().process_frame

	var mina := await _spawn_root(MINA_CASE, MINA_PROFILE)
	var mina_path: PackedInt32Array = mina.get("_here_path")
	var mina_room_id := int(mina.rooms.atlas.room_id(mina_path))
	_check("one seed plus another attachment makes another deterministic building",
			mina_room_id != peter_room_id)
	_check("Mina uses the same owner and ignores Peter's event",
			mina.get_script() == shared_root_script
			and not mina.pursuer.notify_profile_event("junction_reverse"))
	_check("Mina's first passage remains the authored 28 seconds",
			is_equal_approx(mina.run_cap_s, 28.0))
	mina.queue_free()
	await get_tree().process_frame

	var juno := await _spawn_root(JUNO_CASE, JUNO_PROFILE)
	_check("slot three reads the authored 50-second ceiling",
			is_equal_approx(juno.run_cap_s, 50.0))
	_check("the shared pursuer borrows Juno and arms no foreign hazard",
			juno.pursuer.silhouette_source == "juno_kells"
			and juno.hazards.hazards.is_empty())
	var event_count_before := int(juno.pursuer.run_parameters().profile_event_count)
	juno.advance_profile_grammar(4.2, true)
	_check("the first open channel congeals one shared partition",
			juno.rooms.channel_partition_count() == 1
			and int(juno.pursuer.run_parameters().profile_event_count)
					== event_count_before + 1)
	juno.advance_profile_grammar(4.2, true)
	_check("one sustained channel releases the oldest partition without attention",
			juno.rooms.channel_partition_count() == 0
			and int(juno.pursuer.run_parameters().profile_event_count)
					== event_count_before + 1)
	juno.queue_free()
	await get_tree().process_frame

	var mae := await _spawn_root(MAE_CASE, MAE_PROFILE)
	_check("slot four reads the authored 62-second ceiling",
			is_equal_approx(mae.run_cap_s, 62.0))
	_check("the shared pursuer borrows Mae and arms no foreign hazard",
			mae.pursuer.silhouette_source == "mae_kessler"
			and mae.hazards.hazards.is_empty())
	mae.queue_free()
	await get_tree().process_frame

	var cal := await _spawn_root(CAL_CASE, CAL_PROFILE)
	_check("slot five reads the authored 76-second ceiling",
			is_equal_approx(cal.run_cap_s, 76.0))
	_check("the shared pursuer borrows Cal and arms no foreign hazard",
			cal.pursuer.silhouette_source == "cal_dwyer"
			and cal.hazards.hazards.is_empty())
	_check("Cal's ruled truth passes through the same downstream owner",
			str(cal.active_case_truth().get("statement", ""))
					== "Presence is not preservation")
	cal.queue_free()
	await get_tree().process_frame

	var omar := await _spawn_root(OMAR_CASE, OMAR_PROFILE)
	_check("slot six reads the authored 90-second ceiling",
			is_equal_approx(omar.run_cap_s, 90.0))
	_check("the shared pursuer borrows Omar and arms no foreign hazard",
			omar.pursuer.silhouette_source == "omar_bell"
			and omar.hazards.hazards.is_empty())
	_check("a revealed fault does not refresh pursuit; inspecting costs ordinary time",
			not omar.pursuer.notify_profile_event("impossible_fault_revealed")
			and int(omar.pursuer.run_parameters().profile_event_count) == 0)
	omar.queue_free()
	await get_tree().process_frame


func _grammar_contract(profiles: Dictionary) -> void:
	var peter: Dictionary = profiles.get(PETER_PROFILE, {})
	var grammar: Dictionary = peter.get("maze", {})
	var atlas := DreamAtlas.new()
	atlas.setup(SEED_HEX, 3, PETER_CASE)
	var builder := DreamRoomBuilder.new()
	builder.setup(atlas, [], grammar)
	var plot := Node3D.new()
	plot.name = "PeterPocket"
	add_child(plot)
	var pair := _find_junction_pair(builder, plot)
	_check("the deterministic Peter pocket contains a testable reversal",
			not pair.is_empty())
	if pair.is_empty():
		plot.queue_free()
		return
	var from_key := str(pair.from)
	var to_key := str(pair.to)
	var before: Dictionary = builder.room_at_key(to_key).duplicate(true)
	var before_source := str(before.source)
	var before_rect: Array = before.rect.duplicate()
	var before_size: Vector2 = before.size
	var before_doors := (before.doors as Array).size()
	var event := builder.apply_profile_transition(plot, from_key, to_key)
	var after: Dictionary = builder.room_at_key(to_key)
	_check("reversing at a junction emits only the profile's generic event",
			str(event.get("event", "")) == "junction_reverse")
	_check("the pending corridor returns from the exact same Orison source",
			str(after.source) == before_source and after.rect == before_rect
			and (after.size as Vector2).is_equal_approx(before_size))
	_check("the returned corridor is marked as a profile duplicate",
			bool(after.get("profile_duplicate", false))
			and str(after.get("duplicated_from", "")) == from_key
			and int(after.get("form_stamps", 0)) == 1)
	_check("the form grammar deals one additional door",
			(after.doors as Array).size() == before_doors + 1)
	_check("dealing the demand does not move any door the player remembers",
			_door_prefix_unchanged(before.doors as Array,
					after.doors as Array))
	_check("the new demand is visible even if overlap seals its opening",
			plot.find_child("ProceedUncertainStamp", true, false) != null)
	var papers := plot.find_child("FormPaperStack", true, false) \
			as MultiMeshInstance3D
	_check("the period forms are one repeated production batch",
			papers != null and papers.multimesh != null
			and papers.multimesh.instance_count >= 21)
	_check("one threshold crossing cannot stamp twice",
			builder.apply_profile_transition(plot, from_key, to_key).is_empty()
			and int(builder.room_at_key(to_key).get("form_stamps", 0)) == 1)

	builder.profile_grammar = {}
	builder.apply_profile_transition(plot, "", "")
	_check("an empty profile grammar is a true no-op",
			builder.apply_profile_transition(plot, from_key, to_key).is_empty()
			and int(builder.room_at_key(to_key).get("form_stamps", 0)) == 1)
	plot.queue_free()
	await get_tree().process_frame

	var juno: Dictionary = profiles.get(JUNO_PROFILE, {})
	var juno_atlas := DreamAtlas.new()
	juno_atlas.setup(SEED_HEX, 3, JUNO_CASE)
	var juno_builder := DreamRoomBuilder.new()
	juno_builder.setup(juno_atlas, [], juno.get("maze", {}))
	var juno_plot := Node3D.new()
	add_child(juno_plot)
	juno_builder.advance(juno_plot, PackedInt32Array())
	var player_key := DreamRoomBuilder.key_of(PackedInt32Array())
	var live := juno_builder.live_rooms()
	var pursuer_key := str(live[-1].key)
	if pursuer_key == player_key and live.size() > 1:
		pursuer_key = str(live[0].key)
	var player_room := juno_builder.room_at_key(player_key)
	var rect: Array = player_room.rect
	var player_position := Vector3((float(rect[0]) + float(rect[2])) * 0.5,
			0.0, (float(rect[1]) + float(rect[3])) * 0.5)
	var partition := juno_builder.congeal_channel_partition(juno_plot,
			player_key, player_position, pursuer_key, 1)
	_check("Juno seals one deterministic reciprocal joint",
			not partition.is_empty() and juno_builder.channel_partition_count() == 1
			and _joint_partitioned_both(juno_builder, str(partition.from),
					str(partition.to)))
	var temporal_receptors := juno_plot.find_child(
			"ChannelTemporalReceptors", true, false) as MultiMeshInstance3D
	var temporal_tips := juno_plot.find_child(
			"ChannelTemporalTips", true, false) as MultiMeshInstance3D
	_check("T4-2 delayed feedback grows one fixed twenty-one-receptor array",
			temporal_receptors != null and temporal_receptors.multimesh != null
			and temporal_receptors.multimesh.instance_count == 21
			and temporal_tips != null and temporal_tips.multimesh != null
			and temporal_tips.multimesh.instance_count == 21)
	_check("T4-2 the array holds three delayed response groups without zero scale",
			temporal_receptors != null
			and float(temporal_receptors.get_meta(
					"minimum_receptor_length", 0.0)) > 0.28
			and float(temporal_receptors.get_meta(
					"maximum_receptor_length", 0.0)) > 0.43)
	juno_builder.advance(juno_plot, juno_builder.path_of(player_key))
	_check("ordinary pocket advance cannot reopen load-bearing feedback",
			_joint_partitioned_both(juno_builder, str(partition.get("from", "")),
					str(partition.get("to", ""))))
	var released := juno_builder.release_oldest_channel_partition()
	_check("sustained release clears both sides of only the partitioned joint",
			not released.is_empty() and juno_builder.channel_partition_count() == 0
			and _joint_open_both(juno_builder, str(released.from), str(released.to)))
	juno_plot.queue_free()
	await get_tree().process_frame

	var mae: Dictionary = profiles.get(MAE_PROFILE, {})
	var mae_atlas := DreamAtlas.new()
	mae_atlas.setup(SEED_HEX, 4, MAE_CASE)
	var mae_builder := DreamRoomBuilder.new()
	mae_builder.setup(mae_atlas, [], mae.get("maze", {}))
	var mae_plot := Node3D.new()
	add_child(mae_plot)
	var convergence := _find_junction_pair(mae_builder, mae_plot)
	var target_key := str(convergence.get("to", ""))
	mae_builder.advance(mae_plot, mae_builder.path_of(target_key))
	var branches: Array[String] = []
	for door in DreamRoomBuilder.passable_doors(mae_builder.room_at_key(target_key)):
		var child := str(door.get("leads_to", ""))
		if int(door.get("index", -1)) > 0 and not child.is_empty():
			branches.append(child)
	var first := mae_builder.apply_profile_transition(mae_plot, branches[0], target_key) \
			if branches.size() >= 2 else {}
	var first_object := str(first.get("object_id", ""))
	var second := mae_builder.apply_profile_transition(mae_plot, branches[1], target_key) \
			if branches.size() >= 2 else {}
	_check("two physical branches return to one stable antique identity",
			branches.size() >= 2 and not first.is_empty() and not second.is_empty()
			and first_object == str(second.get("object_id", "")))
	_check("the two approaches retain incompatible provenance together",
			str(first.get("provenance", "")) != str(second.get("provenance", ""))
			and int(second.get("accounts", 0)) == 2
			and bool(mae_builder.room_at_key(target_key).get(
					"contradiction_complete", false)))
	_check("only the first account informs pursuit and revisits are no-ops",
			not str(first.get("event", "")).is_empty()
			and str(second.get("event", "")).is_empty()
			and mae_builder.apply_profile_transition(
					mae_plot, branches[0], target_key).is_empty())
	_check("one object and two provenance plaques share the production room",
			mae_plot.find_child("ContradictoryAntique", true, false) != null
			and (mae_plot.find_child("ContradictoryProvenance", true, false)
					as MultiMeshInstance3D).multimesh.instance_count == 2)
	mae_plot.queue_free()
	await get_tree().process_frame

	var cal: Dictionary = profiles.get(CAL_PROFILE, {})
	var cal_atlas := DreamAtlas.new()
	cal_atlas.setup(SEED_HEX, 5, CAL_CASE)
	var cal_builder := DreamRoomBuilder.new()
	cal_builder.setup(cal_atlas, [], cal.get("maze", {}))
	var cal_plot := Node3D.new()
	add_child(cal_plot)
	var walk := _broadcast_walk(cal_builder, cal_plot, 5)
	var keys: Array[String] = walk.get("keys", [])
	var cal_events: Array[Dictionary] = walk.get("events", [])
	var state := cal_builder.broadcast_state()
	_check("Cal hands one broadcast through four existing thresholds",
			cal_events.size() >= 5
			and cal_events.slice(0, 4).all(func(event: Dictionary) -> bool:
				return str(event.get("state", "")) == "held")
			and int(state.get("handoffs", 0)) == 4)
	_check("only Cal's first handoff names pursuit attention",
			str(cal_events[0].get("event", "")) == "broadcast_handoff"
			and cal_events.slice(1, 4).all(func(event: Dictionary) -> bool:
				return str(event.get("event", "")).is_empty()))
	_check("the next threshold drains once and the broadcast cannot restart",
			str(cal_events[4].get("state", "")) == "drained"
			and bool(state.get("drained", false))
			and cal_builder.apply_profile_transition(
				cal_plot, keys[0], keys[1]).is_empty())
	_check("Cal's handoff leaves every door fact untouched",
			bool(walk.get("doors_unchanged", false))
			and cal_builder.channel_partition_count() == 0)
	cal_plot.queue_free()
	await get_tree().process_frame

	var omar: Dictionary = profiles.get(OMAR_PROFILE, {})
	var omar_atlas := DreamAtlas.new()
	omar_atlas.setup(SEED_HEX, 6, OMAR_CASE)
	var omar_builder := DreamRoomBuilder.new()
	omar_builder.setup(omar_atlas, [], omar.get("maze", {}))
	var omar_plot := Node3D.new()
	add_child(omar_plot)
	omar_builder.advance(omar_plot, PackedInt32Array())
	var home_key := DreamRoomBuilder.key_of(PackedInt32Array())
	var child_key := ""
	for door in DreamRoomBuilder.passable_doors(omar_builder.room_at_key(home_key)):
		if int(door.get("index", -1)) > 0:
			child_key = str(door.get("leads_to", ""))
			if not child_key.is_empty():
				break
	var first_cross := omar_builder.apply_profile_transition(
			omar_plot, home_key, child_key)
	var before_home_doors: Array = (omar_builder.room_at_key(home_key).doors
			as Array).duplicate(true)
	var first_fault := omar_builder.apply_profile_transition(
			omar_plot, child_key, home_key)
	var machine_id := str(first_fault.get("object_id", ""))
	var child_fault := omar_builder.apply_profile_transition(
			omar_plot, home_key, child_key)
	var second_fault := omar_builder.apply_profile_transition(
			omar_plot, child_key, home_key)
	_check("a first visit creates no fault and every revisit adds one",
			first_cross.is_empty() and not first_fault.is_empty()
			and not child_fault.is_empty() and not second_fault.is_empty()
			and int(first_fault.get("fault_count", 0)) == 1
			and int(second_fault.get("fault_count", 0)) == 2)
	_check("new faults remain on one stable room-machine identity",
			not machine_id.is_empty()
			and machine_id == str(second_fault.get("object_id", ""))
			and omar_plot.find_child("StableRepairMachine", true, false) != null
			and _max_profile_instances(omar_plot, "ImpossibleFault") == 2)
	_check("fault revelation changes no existing threshold or door fact",
			before_home_doors == omar_builder.room_at_key(home_key).doors
			and omar_builder.channel_partition_count() == 0)
	omar_plot.queue_free()
	await get_tree().process_frame


func _max_profile_instances(root: Node, node_name: String) -> int:
	var maximum := 0
	for node in root.find_children(node_name, "MultiMeshInstance3D", true, false):
		var instance := node as MultiMeshInstance3D
		if instance.multimesh != null:
			maximum = maxi(maximum, instance.multimesh.instance_count)
	return maximum


func _broadcast_walk(builder: DreamRoomBuilder, plot: Node3D,
		count: int) -> Dictionary:
	var keys: Array[String] = [DreamRoomBuilder.key_of(PackedInt32Array())]
	var events: Array[Dictionary] = []
	var doors_unchanged := true
	var path := PackedInt32Array()
	builder.advance(plot, path)
	for _step in count:
		var room := builder.room_at_key(keys[-1])
		var next_key := ""
		for door in DreamRoomBuilder.passable_doors(room):
			if int(door.get("index", -1)) > 0:
				next_key = str(door.get("leads_to", ""))
				if not next_key.is_empty() and next_key not in keys:
					break
		if next_key.is_empty() or next_key in keys:
			break
		var before_from: Array = (builder.room_at_key(keys[-1]).get(
				"doors", []) as Array).duplicate(true)
		var before_to: Array = (builder.room_at_key(next_key).get(
				"doors", []) as Array).duplicate(true)
		events.append(builder.apply_profile_transition(
				plot, keys[-1], next_key))
		doors_unchanged = doors_unchanged \
				and before_from == builder.room_at_key(keys[-1]).get("doors", []) \
				and before_to == builder.room_at_key(next_key).get("doors", [])
		keys.append(next_key)
		path = builder.path_of(next_key)
		builder.advance(plot, path)
	return {"keys": keys, "events": events,
			"doors_unchanged": doors_unchanged}


func _joint_partitioned_both(builder: DreamRoomBuilder, a: String, b: String) -> bool:
	var first: Dictionary = builder.call("_door_to_any", a, b)
	var second: Dictionary = builder.call("_door_to_any", b, a)
	return not first.is_empty() and not second.is_empty() \
			and bool(first.get("sealed", false)) and bool(second.get("sealed", false)) \
			and bool(first.get("partitioned", false)) \
			and bool(second.get("partitioned", false))


func _joint_open_both(builder: DreamRoomBuilder, a: String, b: String) -> bool:
	var first: Dictionary = builder.call("_door_to_any", a, b)
	var second: Dictionary = builder.call("_door_to_any", b, a)
	return not first.is_empty() and not second.is_empty() \
			and not bool(first.get("sealed", true)) and not bool(second.get("sealed", true)) \
			and not bool(first.get("partitioned", true)) \
			and not bool(second.get("partitioned", true))


func _door_prefix_unchanged(before: Array, after: Array) -> bool:
	if after.size() < before.size():
		return false
	for i in before.size():
		for field in ["local_side", "side", "axis", "aperture", "point",
				"inside", "sealed", "leads_to"]:
			if before[i].get(field) != after[i].get(field):
				return false
	return true


## Walk actual pocket ancestry until the current room is a junction and the
## corridor behind it has room in its four-wall vocabulary for one more door.
func _find_junction_pair(builder: DreamRoomBuilder,
		plot: Node3D, start_path := PackedInt32Array()) -> Dictionary:
	var path: PackedInt32Array = start_path.duplicate()
	builder.advance(plot, path)
	for _step in 96:
		var here_key := DreamRoomBuilder.key_of(path)
		var here: Dictionary = builder.room_at_key(here_key)
		if here.is_empty():
			return {}
		var chosen: Dictionary = {}
		for door in DreamRoomBuilder.passable_doors(here):
			if int(door.get("index", -1)) == 0:
				continue
			var next_key := str(door.get("leads_to", ""))
			if not next_key.is_empty() \
					and not builder.room_at_key(next_key).is_empty():
				chosen = door
				break
		if chosen.is_empty():
			return {}
		var prior_key := here_key
		var next_key := str(chosen.leads_to)
		path = builder.path_of(next_key)
		builder.advance(plot, path)
		var current: Dictionary = builder.room_at_key(next_key)
		var prior: Dictionary = builder.room_at_key(prior_key)
		if not current.is_empty() and not prior.is_empty() \
				and DreamRoomBuilder.passable_doors(current).size() >= 3 \
				and (prior.doors as Array).size() < DreamAtlas.MAX_DOORS:
			return {"from": next_key, "to": prior_key}
	return {}


func _spawn_root(case_id: String, profile_id: String) -> DreamMazeRoot:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	var root := scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": case_id,
		"profile_id": profile_id,
		"window": {},
		"seed_hex": SEED_HEX,
		"maze_revision": 1,
		"outcome": "",
		"night_index": 3,
		"spawn_anchor": 1,
	})
	add_child(root)
	await get_tree().process_frame
	return root


func _profile_book() -> Dictionary:
	return _json_dictionary(PROFILE_PATH).get("profiles", {})


func _json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [profile ok] %s" % label)
	else:
		failures += 1
		printerr("  [PROFILE FAIL] %s" % label)
