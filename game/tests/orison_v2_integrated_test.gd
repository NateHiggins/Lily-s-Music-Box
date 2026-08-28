extends Node

const REVIEW := preload("res://scenes/building/orison_v2_integrated_review.tscn")
const Adapter := preload("res://scripts/building/orison_v2_anchor_adapter.gd")
const PROD_LAYOUT := "res://data/building_layout.json"
var failures := 0
var route_ms := 0.0

class ProbePlayer extends Node:
	var call_locked := false

func _ready() -> void:
	var production_hash := FileAccess.get_sha256(PROD_LAYOUT)
	var started := Time.get_ticks_usec()
	var world := REVIEW.instantiate()
	add_child(world)
	await get_tree().physics_frame
	var startup_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var root := world.get_node("Blockout") as Node3D
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	_gate(root.layout.get("layout_id", "") == "orison_v2_h_plan_blockout_01"
			and not bool(root.layout.get("production_default", true)),
			"01 deterministic v2 schema and generation selection")
	_gate(root.is_in_group("orison_v2_blockout") and root.get_child_count() > 0 \
			and world.get_node_or_null("ReadabilityCues/PUBLIC_ENTRANCE") != null \
			and world.get_node_or_null("ReadabilityCues/2A") != null \
			and world.get_node_or_null("ReadabilityCues/4B") != null \
			and world.get_node_or_null("ReadabilityCues/TerminalHomeContext") != null \
			and world.get_node_or_null("ReadabilityCues/BedHomeContext") != null,
			"02 generated construction and scene startup")
	var adapter = Adapter.new(root)
	_gate(adapter.resolves_required_uniquely(), "03 unique compatibility anchors")
	var consumer: Dictionary = await _consumer_checks(root, adapter)
	_gate(bool(consumer.f01), "05 F01 arrival and lobby interaction compatibility")
	_gate(bool(consumer.f02), "06 F02 Mina/chirp/job/case and acoustic compatibility")
	_gate(bool(consumer.f04), "07 F04 terminal/call/audio compatibility")
	_gate(bool(consumer.bed) and await _save_reconstruct_check(),
			"08 real save/reload reconstruction and separate v1 bed fallback")
	var route_started := Time.get_ticks_usec()
	player.position = Vector3(0.0, 0.0, -14.25)
	_gate(await _walk(player, _integrated_waypoints()),
			"04 continuous street-to-bedside controller traversal")
	route_ms = float(Time.get_ticks_usec() - route_started) / 1000.0
	_gate(root.get_node_or_null("WEST_WET_STACK") != null
			and root.get_node_or_null("HEAT_STACK") != null
			and root.get_node_or_null("TELEPHONE_MESSAGE_RISER") != null
			and root.get_node_or_null("SERVICE_LIFT_SHAFT") != null,
			"09 essential service stacks remain continuous")
	var nodes := _count_nodes(root)
	var collisions := root.find_children("*", "CollisionObject3D", true, false).size()
	print("[M08 PERF] startup_ms=%.3f route_ms=%.3f nodes=%d collisions=%d process_ms=%.3f physics_ms=%.3f" % [
		startup_ms, route_ms, nodes, collisions,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	_gate(nodes > 0 and collisions > 0 and startup_ms < 1000.0,
			"10 proportional startup/node/collision budget")
	_gate(FileAccess.get_sha256(PROD_LAYOUT) == production_hash,
			"production layout remains byte-stable")
	adapter.restore_all()
	_gate(adapter.is_restored(), "adapter/acoustic teardown restores global state")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("ORISON V2 M08 INTEGRATION: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)

func _consumer_checks(root: Node3D, adapter) -> Dictionary:
	var original_acoustic := AcousticGraphData.nodes.duplicate(true)
	var acoustic_ok: bool = adapter.with_acoustic_overrides([
		"F02_A_MONITOR_01", "F04_B_MONITOR_01"], func() -> bool:
		return AcousticGraphData.node_pos("F04_B_MONITOR_01").is_equal_approx(
				(adapter.resolve("F04_B_MONITOR_01") as Node3D).global_position))
	acoustic_ok = acoustic_ok and AcousticGraphData.nodes == original_acoustic

	# F01: production implementations mounted at v2 anchors, using public verbs.
	var porter := OtisProp.new()
	var porter_ok: bool = adapter.mount_consumer("LobbyPorterBoard", porter)
	await get_tree().process_frame
	porter_ok = porter_ok and porter.interact_prompt() == "[E]  Work the lift" \
			and porter.control_prompt("service").contains("annunciator") \
			and porter.global_position.is_equal_approx(
					(root.get_node("LobbyPorterBoard_Semantic") as Node3D).global_position)
	var porter_removed: Node3D = adapter.unmount_consumer("LobbyPorterBoard")
	if porter_removed: porter_removed.queue_free()
	var board := HouseSwitchboardProp.new()
	var board_ok: bool = adapter.mount_consumer("F01_HOUSE_TELEPHONE_BOARD", board)
	await get_tree().process_frame
	var board_action: Dictionary = board.interact(null)
	board_ok = board_ok and board.interact_prompt().contains("dead house board") \
			and str(board_action.get("action", "")) == "board_read" \
			and not bool(board_action.get("accepted", true))
	var board_removed: Node3D = adapter.unmount_consumer("F01_HOUSE_TELEPHONE_BOARD")
	if board_removed: board_removed.queue_free()
	var dumbwaiter := DumbwaiterProp.new()
	var dumb_ok: bool = adapter.mount_consumer("LobbyServiceDumbwaiter", dumbwaiter)
	await get_tree().process_frame
	dumb_ok = dumb_ok and dumbwaiter.control_prompt("brake").contains("holding brake") \
			and (dumbwaiter.maintenance_snapshot() as Dictionary).has("band_seated")
	var dumb_removed: Node3D = adapter.unmount_consumer("LobbyServiceDumbwaiter")
	if dumb_removed: dumb_removed.queue_free()

	# F02: real WorkOrders + ChirpHunt + VantryPointProp public inspection path.
	var saved_state := var_to_bytes(RealityState.data)
	var saved_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var orders := WorkOrders.new()
	var inventory := MaintenanceInventory.new()
	var network := VantryPointNetwork.new()
	var hunt := ChirpHunt.new()
	root.add_child(orders); root.add_child(inventory); root.add_child(network); root.add_child(hunt)
	orders.setup(null)
	var library := MaintenanceJobLibrary.load_default()
	orders.bind_job_library(library)
	inventory.setup()
	var point_anchor := adapter.resolve("F02_A_MAIN_VANTRY_POINT") as Node3D
	network.floor_nodes = {"F02": root}
	network.points = {ChirpHunt.JOB_ID: {}}
	network.points = {"F02_A_MAIN_VANTRY_POINT": {
		"pos": [point_anchor.global_position.x, -point_anchor.global_position.z,
				point_anchor.global_position.y], "floor": "F02", "room": "2A"}}
	network.point_order = ["F02_A_MAIN_VANTRY_POINT"]
	network.work_orders = orders
	var point := VantryPointProp.new()
	point.prop_type = "vantry_point"
	point.bind_order_spine(orders)
	network.active_owner = point
	network.add_child(point)
	await get_tree().process_frame
	hunt.setup(network, orders, inventory)
	var f02_ok: bool = library.is_valid() \
			and str(library.job(ChirpHunt.JOB_ID).get("case_id", "")) == "mina_caption_crisis" \
			and hunt.active_point_id == "F02_A_MAIN_VANTRY_POINT" \
			and hunt.report() and orders.acknowledge_job(ChirpHunt.JOB_ID)
	var before_stage := orders.job_stage(ChirpHunt.JOB_ID)
	point.interact(null)
	var after_stage := orders.job_stage(ChirpHunt.JOB_ID)
	f02_ok = f02_ok and before_stage == "acknowledged" \
			and after_stage == "awaiting_part" \
			and point.global_position.distance_to(point_anchor.global_position) < 0.02 \
			and point.interact_prompt().contains("carbon capsule") and acoustic_ok
	RealityState.data = bytes_to_var(saved_state)
	RealityState.persistence_enabled = saved_persistence
	for owner: Node in [hunt, point, network, inventory, orders]:
		if owner.get_parent() != null:
			owner.get_parent().remove_child(owner)
		owner.queue_free()
	await get_tree().process_frame

	# F04: real terminal body and the public call-console sequence.
	var terminal := SignalTerminalProp.new()
	terminal.prop_type = "signal_terminal"
	var old_origin: String = str(Conductor.origin_node)
	var old_mode: String = str(Conductor.propagation_mode)
	var old_infection: float = Conductor.infection
	var terminal_ok: bool = adapter.mount_consumer("F04_B_MONITOR_01", terminal)
	await get_tree().process_frame
	var calls := CallInterface.new()
	calls.world = root
	calls.fast = true
	calls.fast_factor = 0.001
	add_child(calls)
	await get_tree().process_frame
	calls.enter(null, terminal)
	calls.press_isolate(true)
	calls.press_capture()
	calls.press_route()
	await get_tree().create_timer(0.15).timeout
	var terminal_acoustic: bool = adapter.install_acoustic_overrides(["F04_B_MONITOR_01"])
	terminal_ok = terminal_ok and calls.stage >= CallInterface.Stage.TRANSMISSION \
			and str(terminal.get("_stage")) in ["route", "response", "outcome"] \
			and str(Conductor.origin_node) == "F04_B_MONITOR_01" \
			and terminal_acoustic and terminal.global_position.distance_to(
					AcousticGraphData.node_pos("F04_B_MONITOR_01")) < 0.02
	adapter.restore_acoustic_overrides()
	Conductor.origin_node = old_origin
	Conductor.propagation_mode = old_mode
	Conductor.infection = old_infection
	calls.leave()
	calls.queue_free()
	var terminal_removed: Node3D = adapter.unmount_consumer("F04_B_MONITOR_01")
	if terminal_removed: terminal_removed.queue_free()

	var explicit: Node3D = adapter.explicit_bed()
	var production: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROD_LAYOUT))
	var fallback: Dictionary = adapter.anonymous_bed_fallback(production as Dictionary)
	var f01_ok: bool = porter_ok and board_ok and dumb_ok \
			and adapter.resolve("LobbyMailBank") != null
	var f04_ok: bool = terminal_ok
	var bed_ok: bool = str(CoreLoopDirector.RETURN_ANCHOR_ID) == "F04_B_BED" \
			and explicit != null and not fallback.is_empty()
	return {"f01": f01_ok, "f02": f02_ok, "f04": f04_ok, "bed": bed_ok}

func _save_reconstruct_check() -> bool:
	var old_path := RealityState.save_path
	var old_persistence := RealityState.persistence_enabled
	var old_data := var_to_bytes(RealityState.data)
	var path := "user://tests/orison_v2_m08a_transaction.json"
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	RealityState.data = {"version": RealityState.SAVE_VERSION,
			"core_loop": {"safe_return_anchor": "F04_B_BED",
			"boundary": "wake_complete"}}
	var saved := RealityState.save_game()
	RealityState.data = {}
	RealityState.load_game()
	var rebuilt := REVIEW.instantiate()
	add_child(rebuilt)
	await get_tree().process_frame
	var selected := Adapter.new(rebuilt.get_node("Blockout"))
	var bed := selected.explicit_bed()
	var v2_ok := saved and bed != null \
			and str(RealityState.data.get("core_loop", {}).get(
					"safe_return_anchor", "")) == "F04_B_BED"
	rebuilt.queue_free()
	await get_tree().process_frame
	var production: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROD_LAYOUT))
	var v1_ok := not Adapter.new(null).anonymous_bed_fallback(
			production as Dictionary).is_empty()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = old_persistence
	RealityState.data = bytes_to_var(old_data)
	return v2_ok and v1_ok

func _integrated_waypoints() -> Array[Vector3]:
	var points: Array[Vector3] = [
		Vector3(0.0, 0.0, -11.0), Vector3(0.0, 0.0, -8.0),
		Vector3(0.0, 0.0, -5.0), Vector3(2.3, 0.0, -3.0)]
	_append_storey(points, 0.0)
	points.append_array([Vector3(-1.5, 3.2, 0.0), Vector3(-4.6, 3.2, 0.0),
		Vector3(-6.45, 3.2, 0.0), Vector3(-9.2, 3.2, 1.4),
		Vector3(-6.45, 3.2, 0.0), Vector3(-4.6, 3.2, 0.0),
		Vector3(-1.5, 3.2, 0.0), Vector3(1.4, 3.2, -2.5),
		Vector3(2.3, 3.2, -3.0)])
	_append_storey(points, 3.2)
	points.append_array([Vector3(1.4, 6.4, -2.5), Vector3(2.3, 6.4, -3.0)])
	_append_storey(points, 6.4)
	points.append_array([Vector3(-1.5, 9.6, 0.0), Vector3(-4.6, 9.6, 0.0),
		Vector3(-6.45, 9.6, -0.55), Vector3(-9.9, 9.6, 1.25),
		Vector3(-10.05, 9.6, 3.8), Vector3(-9.8, 9.6, 6.75),
		Vector3(-11.1, 9.6, 7.25), Vector3(-11.95, 9.6, 8.9)])
	return points

func _append_storey(points: Array[Vector3], base_y: float) -> void:
	for i in 10:
		points.append(Vector3(2.3, base_y + 0.16 * float(i + 1), -3.1 + 0.285 * (i + 0.5)))
	points.append(Vector3(2.3, base_y + 1.6, 1.25))
	points.append(Vector3(3.8, base_y + 1.6, 1.25))
	for i in 10:
		points.append(Vector3(3.8, base_y + 1.6 + 0.16 * float(i + 1), 1.03 - 0.285 * (i + 0.5)))
	points.append(Vector3(3.8, base_y + 3.2, -3.45))
	points.append(Vector3(1.4, base_y + 3.2, -3.45))
	points.append(Vector3(1.4, base_y + 3.2, -2.5))

func _walk(player: CharacterBody3D, waypoints: Array[Vector3]) -> bool:
	for target: Vector3 in waypoints:
		var frames := 0
		while Vector2(player.position.x - target.x, player.position.z - target.z).length() > 0.11:
			var offset := target - player.position
			offset.y = 0.0
			player.velocity = offset.normalized() * 3.2
			player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y - 18.0 / 60.0
			player.call("move_review_velocity", Vector3(player.velocity.x, 0.0,
					player.velocity.z), 1.0 / 60.0)
			await get_tree().physics_frame
			frames += 1
			if frames > 360:
				print("[M08 WALK BLOCKED] at=%s target=%s" % [player.position, target])
				return false
		if absf(player.position.y - target.y) > 0.65:
			print("[M08 LEVEL ERROR] at=%s target=%s" % [player.position, target])
			return false
		var station := _station_label(target)
		if not station.is_empty():
			print("[M08 STATION] name=%s cpu_ms=%.3f physics_ms=%.3f gpu_ms=unavailable_headless" % [
					station, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return true

func _station_label(point: Vector3) -> String:
	if point.is_equal_approx(Vector3(0, 0, -11)): return "street_approach"
	if point.is_equal_approx(Vector3(0, 0, -5)): return "f01_threshold_lobby"
	if point.is_equal_approx(Vector3(1.4, 3.2, -2.5)): return "primary_stair_f01_f02"
	if point.is_equal_approx(Vector3(-1.5, 3.2, 0)): return "f02_landing"
	if point.is_equal_approx(Vector3(-9.2, 3.2, 1.4)): return "2a_work_position"
	if point.is_equal_approx(Vector3(1.4, 6.4, -2.5)): return "primary_stair_f02_f03"
	if point.is_equal_approx(Vector3(1.4, 9.6, -2.5)): return "primary_stair_f03_f04"
	if point.is_equal_approx(Vector3(-1.5, 9.6, 0)): return "f04_landing"
	if point.is_equal_approx(Vector3(-9.9, 9.6, 1.25)): return "4b_terminal"
	if point.is_equal_approx(Vector3(-11.95, 9.6, 8.9)): return "bedside_return"
	return ""

func _count_nodes(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total

func _gate(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
