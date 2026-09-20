extends Node
## Actual V2, real player input/prompt/physics ray, existing call and audio owners.
## The actor is placed at its authored stance; this is not a traversal test.

const Selector := preload("res://scripts/building/building_root_selector.gd")
var checks: Array = []
var diagnostics: Dictionary = {}
var world_events: Array = []
var failed := 0
var output := ""
var shell: CampaignShell
var world: OrisonV2RuntimeRoot
var player: PlayerController
var desk: DeskZone

func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("V2 TERMINAL ACCESS requires writable SHOT_DIR")
		get_tree().quit(2)
		return
	CampaignTime.set_frozen_for_tests(true)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	_check("authored campaign calendar is valid", CampaignClock.new().configure_date(1928, 11, 10, 180.0))
	Selector.reset_for_tests("v2")
	var acoustic_before: Dictionary = AcousticGraphData.nodes.duplicate(true)
	var default_desk := DeskZone.new()
	add_child(default_desk)
	var default_box: BoxShape3D = _box(default_desk)
	_check("V1 default desk footprint and height remain unchanged", default_box != null
			and default_box.size.is_equal_approx(Vector3(1.6, 1.6, 1.8)))
	default_desk.queue_free()
	await get_tree().process_frame
	shell = CampaignShell.new()
	shell.sleep_manual_clock = true
	add_child(shell)
	world = shell.active_world as OrisonV2RuntimeRoot
	_check("CampaignShell composes the actual V2 root", world != null
			and world.scene_file_path == Selector.path_for("v2"))
	_check("actual V2 startup succeeds", world != null and not world.startup_failed)
	if world == null or world.startup_failed:
		await _finish(acoustic_before)
		return
	player = world.player
	_check("actual production player and camera are present", player != null and player.camera != null)
	if player == null or player.camera == null:
		await _finish(acoustic_before)
		return
	player.set_physics_process(false)
	player.world_modified.connect(func(where: Vector3, identity: String) -> void:
		world_events.append({"position": _vec(where), "identity": str(identity)}))
	var terminal := world.adapter.resolve("F04_B_MONITOR_01") as SignalTerminalProp
	var semantic := world.adapter.resolve("F04_B_MONITOR_01_Semantic") as Node3D
	var operator := world.adapter.resolve("F04_B_MONITOR_STANCE") as Node3D
	var reservation := world.adapter.resolve("F04_B_TERMINAL_USE") as MeshInstance3D
	_check("terminal operator and semantic identities resolve uniquely", terminal != null
			and semantic != null and operator != null and reservation != null)
	if terminal == null or semantic == null or operator == null or reservation == null:
		await _finish(acoustic_before)
		return
	var scope := terminal.find_child("SignalScope", true, false) as MeshInstance3D
	_check("actual SignalScope retains its authored cylinder axis", scope != null
			and scope.mesh is CylinderMesh
			and scope.rotation_degrees.is_equal_approx(Vector3(0, 0, 90)))
	if scope == null:
		await _finish(acoustic_before)
		return
	var authored_basis := Basis(Vector3.UP, -1.5707963)
	_check("original semantic terminal transform remains exact", semantic.global_position.is_equal_approx(Vector3(-9.05, 10.35, 1.25))
			and semantic.global_basis.is_equal_approx(authored_basis))
	_check("mounted terminal keeps semantic position scale and stable identity", terminal.name == &"F04_B_MONITOR_01"
			and terminal.global_position.is_equal_approx(semantic.global_position)
			and terminal.global_basis.get_scale().is_equal_approx(semantic.global_basis.get_scale()))
	_check("operator anchor remains the authored stance", operator.global_position.is_equal_approx(Vector3(-9.9, 9.6, 1.25))
			and operator.global_basis.is_equal_approx(Basis(Vector3.UP, 1.5707963)))
	# CylinderMesh's local +Y cap turns toward local -X at authored Z=90.
	# The exposed front cap is -scope.global_basis.y; measure actual geometry.
	var front: Vector3 = -scope.global_basis.y
	front.y = 0.0
	var to_operator: Vector3 = operator.global_position - terminal.global_position
	to_operator.y = 0.0
	var front_dot: float = front.normalized().dot(to_operator.normalized())
	_check("actual scope front faces the operator", front_dot >= 0.99)
	var desks: Array[Node] = []
	var calls: Array[Node] = []
	for node in world.find_children("*", "", true, false):
		if node is DeskZone: desks.append(node)
		if node is CallInterface: calls.append(node)
	desk = desks[0] as DeskZone if desks.size() == 1 else null
	var ci: CallInterface = world.call_interface
	_check("V2 owns exactly one actual DeskZone", desk != null)
	_check("desk reuses the sole production call owner", ci != null and calls.size() == 1
			and calls[0] == ci and desk != null and desk.call_interface == ci)
	_check("call owner retains terminal and acoustic identity", ci != null and ci.world == terminal.get_parent()
			and ci.world.get_node_or_null("F04_B_MONITOR_01") == terminal
			and AcousticGraphData.node_pos("F04_B_MONITOR_01").is_equal_approx(terminal.global_position))
	var box: BoxShape3D = _box(desk)
	var use_bounds: AABB = reservation.global_transform * reservation.get_aabb()
	_check("desk target uses the authored footprint and ordinary height", box != null
			and box.size.is_equal_approx(Vector3(use_bounds.size.x, 1.6, use_bounds.size.z)))
	_check("desk target is at the terminal use area on the operator floor", desk != null
			and desk.global_position.is_equal_approx(Vector3(reservation.global_position.x,
				operator.global_position.y, reservation.global_position.z)))
	player.global_position = operator.global_position
	player.camera.global_position = player.global_position + Vector3.UP * player.STANDING_EYE
	player.camera.look_at(scope.global_position)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await _frames(3)
	var first_ray: Dictionary = _ray_witness()
	_check("ordinary player ray acquires the actual desk Area", bool(first_ray.target_is_desk))
	_check("actual player prompt offers the support desk", player._prompt_panel.visible
			and player._prompt.text.contains("support desk"))
	_check("desk line is silent before occupancy", ci != null and not ci._murmur.playing and not ci._panel.visible)
	var original_position: Vector3 = player.global_position
	var clock_before: Dictionary = RealityState.data.campaign_clock.duplicate(true)
	# Existing test hook compresses narrative delays only. Input, physics, modal
	# ownership and audio playback still use the actual runtime implementations.
	ci.fast = true
	ci.fast_factor = 0.05
	await _interact_action()
	var first_entered: bool = desk != null and desk.seated_player == player \
		and player.seated_interaction == desk and ci._player == player \
		and ci._seat_owner == desk and player.call_locked
	_check("real interact input acquires reciprocal seated ownership", first_entered)
	_check("real entry opens the call panel and starts the first case", ci._panel.visible
			and ci.stage == CallInterface.Stage.CALL and ci._started and ci.case_index == 0
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_check("real call owner updates the actual terminal stage", terminal._stage == "call")
	_check("occupied line plays on the existing Telephone owner", ci._murmur.playing
			and ci._murmur.stream != null and ci._murmur.bus == &"Telephone")
	_check("entry does not teleport the authored operator", first_entered and player.global_position.is_equal_approx(original_position))
	var first_run: int = ci._run_id
	# Look away deliberately: seated E must use its retained owner, not a new ray.
	player.camera.look_at(player.camera.global_position + Vector3.LEFT)
	if first_entered: await _interact_action()
	_check("seated E releases player desk and call ownership", first_entered and _released(ci))
	_check("seated E hides the modal and stops the line", first_entered and not ci._panel.visible
			and not ci._murmur.playing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	player.camera.look_at(scope.global_position)
	await get_tree().physics_frame
	await _frames(2)
	var second_ray: Dictionary = _ray_witness()
	_check("standing player can reacquire the same physical desk", bool(second_ray.target_is_desk))
	if first_entered: await _interact_action()
	var reentered: bool = first_entered and desk != null and desk.seated_player == player \
		and ci._player == player and ci._seat_owner == desk and player.call_locked \
		and ci._panel.visible and ci._run_id == first_run and ci.case_index == 0
	_check("ray reentry resumes the same live case and owner", reentered)
	# Without real entry, Escape would open unrelated pause UI. Missing entry
	# remains a failed prerequisite; do not claim an exit that was never run.
	if reentered: await _escape_key()
	_check("actual Escape key releases reciprocal ownership", reentered and _released(ci))
	_check("Escape restores world input and stops the line", reentered and not ci._panel.visible
			and not ci._murmur.playing and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	_check("exactly two real ray entries emitted desk interactions", world_events.size() == 2
			and world_events[0].identity == "F04_B_DESK_ZONE" and world_events[1].identity == "F04_B_DESK_ZONE")
	var until: int = Time.get_ticks_msec() + 5000
	while ci._started and ci._isolate_btn.disabled and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	_check("opening sequence settles through its actual owner", ci._started and not ci._isolate_btn.disabled)
	_check("entry and exit do not complete a case or advance campaign time", ci.case_index == 0
			and ci.closed_outcomes.is_empty() and not ci._closed
			and RealityState.data.campaign_clock == clock_before)
	await get_tree().create_timer(0.65).timeout
	diagnostics = {"complete": true, "scope_front": _vec(front), "operator_direction": _vec(to_operator),
		"front_dot": front_dot, "terminal_position": _vec(terminal.global_position),
		"terminal_basis": _basis(terminal.global_basis), "semantic_position": _vec(semantic.global_position),
		"semantic_basis": _basis(semantic.global_basis), "scope_position": _vec(scope.global_position),
		"scope_basis": _basis(scope.global_basis), "desk_count": desks.size(), "call_count": calls.size(),
		"desk_size": _vec(box.size) if box != null else [], "first_ray": first_ray, "second_ray": second_ray,
		"world_events": world_events, "case_open_delay_factor": ci.fast_factor,
		"first_interact_action_dispatched": true, "seated_E_action_dispatched": first_entered,
		"reentry_action_dispatched": first_entered, "escape_key_dispatched": reentered,
		"scope": "actual input and physics acquisition at a controlled authored pose; no traversal or completed case proof"}
	await _finish(acoustic_before)

func _released(ci: CallInterface) -> bool:
	return desk != null and desk.seated_player == null and player.seated_interaction == null \
		and not player.call_locked and ci._player == null and ci._seat_owner == null

func _box(owner: DeskZone) -> BoxShape3D:
	if owner == null: return null
	var children: Array[Node] = owner.find_children("*", "CollisionShape3D", true, false)
	if children.size() != 1: return null
	return (children[0] as CollisionShape3D).shape as BoxShape3D

func _ray_witness() -> Dictionary:
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from + player.camera.global_transform.basis * Vector3(0, 0, -2.1)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node
	return {"from": _vec(from), "to": _vec(to), "hit_from_inside": query.hit_from_inside,
		"collider": str(collider.get_path()) if collider != null else "",
		"target_is_desk": collider != null and collider == desk,
		"hit_position": _vec(hit.position) if not hit.is_empty() else []}

func _interact_action() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)

func _escape_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)

func _frames(count: int) -> void:
	for _index in count: await get_tree().process_frame

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _basis(value: Basis) -> Array:
	return [_vec(value.x), _vec(value.y), _vec(value.z)]

func _check(label: String, okay: bool) -> void:
	checks.append({"label": label, "passed": okay})
	print("[V2 TERMINAL ACCESS] %s %s" % ["PASS" if okay else "FAIL", label])
	if not okay: failed += 1

func _finish(acoustic_before: Dictionary) -> void:
	Input.action_release("interact")
	var world_weak: WeakRef = weakref(world) if world != null else null
	var shell_weak: WeakRef = weakref(shell) if shell != null else null
	if shell != null: shell.queue_free()
	await _frames(4)
	await get_tree().create_timer(0.2).timeout
	_check("actual V2 world retires", world_weak != null and world_weak.get_ref() == null)
	_check("actual CampaignShell retires", shell_weak != null and shell_weak.get_ref() == null)
	_check("retirement restores original acoustic records", AcousticGraphData.nodes == acoustic_before)
	var file := FileAccess.open(output.path_join("terminal_access.json"), FileAccess.WRITE)
	if file == null:
		push_error("V2 TERMINAL ACCESS receipt write failed")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify({"schema": "astra.v2-terminal-access.probe.v1", "pid": OS.get_process_id(),
		"root": "v2", "renderer": RenderingServer.get_current_rendering_method(),
		"checks": checks, "failures": failed, "diagnostics": diagnostics,
		"scope": "real player action and call ownership from controlled operator placement; delayed narrative compressed"}, "\t"))
	file.close()
	print("[V2 TERMINAL ACCESS] checks=%d failures=%d" % [checks.size(), failed])
	get_tree().quit(0 if failed == 0 else 1)
