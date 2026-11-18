extends Node3D
## Isolated native bath/input regression, not occupied-world or art acceptance.
const Bath = preload("res://scripts/props/clawfoot_bath_prop.gd")
const Carrier = preload("res://scripts/device/companion_world_carrier.gd")
const ErrorCapture = preload("res://tests/guide_bell_error_capture.gd")

class RouteHand extends "res://tests/orison_v2_4b_door_route_test.gd":
	var report: Callable
	func _ready() -> void:
		pass
	func _require(ok: bool, label: String) -> bool:
		return report.call(ok, label)

var player: PlayerController
var carrier: Carrier
var bath: TapProp
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var observations: Dictionary = {}
var foreign_frames := 0
var moving_contact_frames := 0
var shoulder_observed := false
var last_contact := Vector3.INF
var last_part: Node3D
var initial_sources: Dictionary
var completed := false
var started := 0
var finished := false
var timed_out := false

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func():
		if not finished:
			timed_out = true
			check(false, "fixture deadline")
			_finish([]))
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks.append({"name": label, "passed": ok})
	if not ok: failures.append(label)
	print("COMPANION WORK CLEARANCE CHECK: ", label, " = ", ok)
	return ok

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(carrier) or not player._grab.active(): return
	var target: Dictionary = player._grab.target
	if target.get("owner") != bath: return
	foreign_frames += 1
	var part: Node3D = target.part
	var point := part.to_global(player._grab.contact)
	if part == last_part and last_contact.is_finite() and point.distance_to(last_contact) > .000001:
		moving_contact_frames += 1
	last_contact = point
	last_part = part
	shoulder_observed = shoulder_observed or carrier.screen_frame._shoulder_center.is_finite()
	if carrier._hand.occlusion.collision_layer == 0:
		check(false, "foreign work never disables real fixed-stock occlusion")

func _run() -> void:
	started = Time.get_ticks_msec()
	var logger := ErrorCapture.new()
	OS.add_logger(logger)
	initial_sources = _sources()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if not check(DisplayServer.get_name() != "headless", "windowed real input/presentation fixture"):
		_finish(logger.errors); OS.remove_logger(logger); return
	# Exact minimal native setup from companion_bath_preflight01/valve_probe.gd.
	# Initial placement is setup, never a walking/passage claim.
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, .2, 8)
	collision.shape = box; collision.position.y = -.1
	floor_body.add_child(collision)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -32, 0)
	light.light_energy = 1.2
	add_child(light)
	bath = Bath.new()
	bath.prop_type = "shower"; bath.fixture = "shower"; bath.unit = "4B"
	add_child(bath)
	if not check(bath.native_ready and bath.mount_fixture_collision(), "real native shower and fixture collisions bind"):
		_finish(logger.errors); OS.remove_logger(logger); return
	player = PlayerController.new()
	player.position = Vector3(.0724155, .0009388, -1.1658154)
	add_child(player)
	player.set_physics_process(false)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	carrier = Carrier.new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	if not check(carrier.world_ready, "real companion rig and screen frame bind"):
		_finish(logger.errors); OS.remove_logger(logger); return
	# Only startup viewport readiness; no settling delay between work gestures.
	for frame in 8: await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in 2: await get_tree().physics_frame
	var hand := RouteHand.new()
	hand.player = player; hand.report = check
	add_child(hand)
	var route_ok: bool = await hand._drag_curtain(bath, 1.78, "immediate curtain open")
	for index in 2:
		route_ok = await hand._drag_valve(bath, index, PI * .5, "immediate valve open %d" % index) and route_ok
		route_ok = await hand._drag_valve(bath, index, 0.0, "immediate valve close %d" % index) and route_ok
	route_ok = await hand._drag_curtain(bath, 0.0, "immediate curtain close") and route_ok
	check(route_ok, "ordinary ray/click/motion/release completes consecutive native work")
	check(foreign_frames > 0 and moving_contact_frames > 0, "real foreign hand stays held while its native contact moves")
	check(shoulder_observed, "foreign held work actually engages shoulder clearance")
	check(_fixed_occlusion_hit(), "positive real ray still hits fixed instrument occlusion")
	observations["foreign_held_physics_frames"] = foreign_frames
	observations["moving_contact_frames"] = moving_contact_frames
	await _ownership_probes()
	completed = true
	check(logger.errors.is_empty(), "native route and ownership probes report no engine errors")
	_finish(logger.errors)
	OS.remove_logger(logger)

func _fixed_occlusion_hit() -> bool:
	var area: Area3D = carrier._hand.occlusion
	if area == null or area.collision_layer == 0 or area.get_child_count() != 1: return false
	var faces: PackedVector3Array = area.get_child(0).shape.get_faces()
	for triangle in range(0, mini(faces.size(), 180), 3):
		var center := (faces[triangle] + faces[triangle + 1] + faces[triangle + 2]) / 3.0
		var normal := (faces[triangle + 1] - faces[triangle]).cross(faces[triangle + 2] - faces[triangle]).normalized()
		if normal.length_squared() < .5: continue
		var query := PhysicsRayQueryParameters3D.create(area.to_global(center + normal * .5), area.to_global(center - normal * .5), area.collision_layer)
		query.collide_with_areas = true; query.collide_with_bodies = false
		if player.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == area: return true
	return false

func _seed_return() -> void:
	# Explicit transition-state API probe, not a second input-route claim.
	# Native rig supplies the center: no invented world station or collision bypass.
	carrier.screen_frame._shoulder_center = carrier.rig.to_global(carrier.screen_frame.stock_bounds.get_center())
	carrier.screen_frame._shoulder_turn = .5

func _ownership_probes() -> void:
	if player._grab.active(): player._grab.release()
	# Real recall input; readiness wait applies only to separate own-control probe.
	for pressed in [true, false]:
		var recall := InputEventKey.new()
		recall.keycode = KEY_E; recall.physical_keycode = KEY_E; recall.pressed = pressed
		Input.parse_input_event(recall)
		Input.flush_buffered_events()
		await RenderingServer.frame_post_draw
	for frame in 240:
		await get_tree().physics_frame
		if carrier.hand_is_enabled(): break
	if check(carrier.hand_is_enabled(), "real recall admits own-control descriptor"):
		_seed_return()
		var descriptor: Dictionary = carrier._hand.descriptor("lamp")
		# Direct acquisition tests ownership arbitration; production descriptor and
		# begin/end remain authoritative. It does not claim cursor selection.
		if not descriptor.is_empty(): descriptor.hit_position = descriptor.part.global_position
		if check(player._grab.acquire(descriptor), "ownership API acquires actual lamp during finite shoulder return"):
			carrier.screen_frame.advance(0.0, true)
			var part: Node3D = descriptor.part
			var before := part.global_transform
			var center: Vector3 = carrier.screen_frame._shoulder_center
			var turn: float = carrier.screen_frame._shoulder_turn
			for frame in 3:
				await get_tree().physics_frame
				await RenderingServer.frame_post_draw
			check(player._grab.active() and player._grab.target.get("owner") == carrier, "own control retains hand ownership")
			check(part.global_transform.is_equal_approx(before), "held own instrument does not move during shoulder return")
			check(carrier.screen_frame._shoulder_center == center and carrier.screen_frame._shoulder_turn == turn, "own hand freezes finite shoulder transition")
			player._grab.release()
	_seed_return()
	player.call_locked = true
	var camera_before := player.camera.global_transform
	var mode_before := Input.mouse_mode
	carrier.screen_frame.advance(1.0 / 60.0, false)
	check(not carrier.screen_frame._shoulder_center.is_finite() and is_zero_approx(carrier.screen_frame._shoulder_turn), "protected takeover clears stale shoulder transition")
	check(player.protected_input_active() and player.camera.global_transform == camera_before and Input.mouse_mode == mode_before, "protected successor retains camera and input authority")
	player.call_locked = false
	var story_owner := Node.new()
	add_child(story_owner)
	if check(player.acquire_text_input(story_owner) and carrier.set_story_pose(story_owner, Vector3(.03, 0, 0), Vector2.ZERO), "story successor acquires real lease and presentation API"):
		_seed_return()
		camera_before = player.camera.global_transform
		mode_before = Input.mouse_mode
		carrier.screen_frame.advance(1.0 / 60.0, true)
		check(not carrier.screen_frame._shoulder_center.is_finite(), "story takeover clears stale shoulder transition")
		check(player.text_input_owner == story_owner and carrier.story_pose_active() and carrier.story_attitude == Vector3(.03, 0, 0) and player.camera.global_transform == camera_before and Input.mouse_mode == mode_before, "story successor retains authored pose, camera and input lease")
	carrier.release_story_pose(story_owner)
	player.release_text_input(story_owner)
	story_owner.queue_free()
	if check(carrier.session.begin(), "typing successor acquires existing correspondence opening API"):
		_seed_return()
		camera_before = player.camera.global_transform
		mode_before = Input.mouse_mode
		carrier.screen_frame.advance(1.0 / 60.0, true)
		check(not carrier.screen_frame._shoulder_center.is_finite(), "typing opening clears stale shoulder transition")
		check(carrier.session.opening and player.text_input_owner == carrier.session and player.camera.global_transform == camera_before and Input.mouse_mode == mode_before, "typing successor retains opening, camera and input lease")
		carrier.session.close()

func _sources() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var digest: Array = []
	var head: Array = []
	check(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], digest) == 0 and not digest.is_empty(), "runtime digest available")
	check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "repository provenance available")
	var sources := {}
	for path: String in [get_script().resource_path, scene_file_path, "res://tests/guide_bell_error_capture.gd", "res://tests/orison_v2_4b_door_route_test.gd", "res://scripts/device/companion_screen_frame.gd", "res://scripts/device/companion_world_carrier.gd", "res://scripts/device/service_set_hand.gd", "res://scripts/device/companion_session.gd", "res://scripts/player/player_controller.gd", "res://scripts/player/constrained_grab.gd", "res://scripts/props/clawfoot_bath_prop.gd"]:
		check(FileAccess.file_exists(path), "source binding exists: " + path)
		sources["game/" + path.trim_prefix("res://")] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return {"runtime_inputs_sha256": str(digest[0]).strip_edges() if not digest.is_empty() else "", "repository_head": str(head[0]).strip_edges() if not head.is_empty() else "", "dependencies_lf_sha256": sources}

func _finish(engine_errors: Array[String]) -> void:
	if finished: return
	finished = true
	var final_sources := _sources()
	check(initial_sources == final_sources, "runtime and LF source bindings stable during fixture")
	var directory := OS.get_environment("SHOT_DIR")
	if check(not directory.is_empty(), "explicit fresh receipt directory supplied"):
		check(DirAccess.make_dir_recursive_absolute(directory) == OK, "receipt directory available")
		var path := directory.path_join("companion_work_clearance_contract.json")
		var pending := path + ".pending"
		if check(not FileAccess.file_exists(path) and not FileAccess.file_exists(pending), "receipt does not overwrite earlier evidence"):
			var file := FileAccess.open(pending, FileAccess.WRITE)
			if check(file != null, "receipt opens"):
				var sources: Dictionary = final_sources.dependencies_lf_sha256
				var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": false,
					"scope": "Isolated real native shower/player/companion ray-click-motion-release; direct transition-state and ownership API probes separately labelled. Initial placement copied from private valve reproduction; no occupied-world, passage, art or performance acceptance.",
					"execution": {"completed": completed, "exit_code": 0 if failures.is_empty() else 1, "timed_out": timed_out, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
					"source": {"test_path": "game/tests/companion_work_clearance_test.gd", "test_sha256": sources.get("game/tests/companion_work_clearance_test.gd", ""), "test_scene_path": "game/tests/CompanionWorkClearanceTest.tscn", "test_scene_lf_sha256": sources.get("game/tests/CompanionWorkClearanceTest.tscn", ""), "runtime_inputs_sha256": final_sources.runtime_inputs_sha256, "repository_head": final_sources.repository_head, "test_dependencies_lf_sha256": sources, "before": initial_sources, "after": final_sources},
					"contracts": {"companion_work_clearance": {"executed": completed, "status": "PASS" if completed and failures.is_empty() else "FAIL"}}, "checks": checks, "failures": failures, "observations": observations, "engine_errors": engine_errors}
				var serialized := JSON.stringify(result, "\t")
				file.store_string(serialized); file.flush()
				var error := file.get_error()
				file.close()
				if error != OK or FileAccess.get_file_as_string(pending) != serialized or DirAccess.rename_absolute(pending, path) != OK:
					check(false, "receipt publication failed; provisional evidence retained")
	print("COMPANION WORK CLEARANCE RESULT: ", "PASS" if completed and failures.is_empty() else "FAIL", " checks=", checks.size())
	get_tree().quit(0 if completed and failures.is_empty() else 1)
