extends Node3D
## INERT local collision/input diagnostic. Not occupied V2 or frame-time proof.
const Motion := preload("res://scripts/device/companion_motion.gd")
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")
var player: PlayerController
var rig: Mechanism
var motion: Motion
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var phase := "setup"
var rate := 60
var directory := ""
var finished := false
var old_fps := 0
var old_sensitivity: Variant
var had_sensitivity := false

func check(ok: bool, label: String) -> void:
	checks.append({"name":label, "passed":ok})
	if not ok: failures.append(label); push_error(label)

func _ready() -> void:
	get_tree().create_timer(130.0).timeout.connect(func():
		if not finished:
			check(false, "motion diagnostic exceeded its own deadline")
			_finish())
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	old_fps = Engine.max_fps
	had_sensitivity = GameBoot.settings.has("look_sensitivity")
	old_sensitivity = GameBoot.settings.get("look_sensitivity")
	GameBoot.settings["look_sensitivity"] = 1.0
	_fixture()
	player = PlayerController.new()
	add_child(player)
	player.camera.make_current()
	player.set_lamp_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rig = Mechanism.new()
	add_child(rig)
	if not rig.build():
		check(false, "native companion binds before motion")
		_finish(); return
	for draw: GeometryInstance3D in rig.find_children("*", "GeometryInstance3D", true, false): draw.layers = 1
	player.set_physics_process(false)
	var radius := _manufactured_radius()
	check(radius <= .31, "travel, intermediate and open keyboard fit the authored movement hull")
	for cap in [30, 60, 144]:
		rate = cap; Engine.max_fps = cap
		_key(KEY_W, false); _key(KEY_SHIFT, false)
		player.global_position = Vector3(0, .02, 2.4)
		player.rotation = Vector3.ZERO; player.camera.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
		if rig.get_parent() != self: rig.reparent(self, false)
		rig.transform = Transform3D.IDENTITY
		if is_instance_valid(motion):
			motion.queue_free()
			await get_tree().physics_frame
		motion = Motion.new()
		add_child(motion)
		rig.reparent(motion, false)
		if not await motion.setup(player, player.camera, rig):
			check(false, "safe motion placement at " + str(rate)); break
		check(motion.collision_layer == 0 and player in motion.get_collision_exceptions(), "companion cannot obstruct the player at " + str(rate))
		player.set_physics_process(true)
		await _frames(15, "settle")
		var first := samples.size()
		var queries := motion.query_count
		_key(KEY_W, true)
		await _frames(100, "walk_door")
		_key(KEY_W, false)
		await _frames(150, "door_catch_up")
		check(player.global_position.z < -2.0, "actual W input crosses the narrow doorway at " + str(rate))
		check(motion.global_position.z < -.35, "companion crosses the same doorway at " + str(rate))
		_turn(PI * .5)
		await _frames(4, "turn")
		_key(KEY_W, true)
		await _frames(80, "walk_corner")
		_key(KEY_W, false)
		await _frames(120, "corner_catch_up")
		check(player.global_position.x < -3.0 and motion.global_position.x < -1.2, "actual turn and W input carry both actors around the corner at " + str(rate))
		var routed := false
		for index in range(first, samples.size()): routed = routed or bool(samples[index].routing)
		check(routed, "full-hull obstruction activates the recorded-player route at " + str(rate))
		rig.request_keyboard(true)
		await _frames(25, "keyboard_safety_setup")
		_key(KEY_SHIFT, true); _key(KEY_W, true)
		await _frames(50, "sprint")
		check(motion.behavior == &"travel" and not rig.keyboard_requested, "actual sprint folds vulnerable keyboard at " + str(rate))
		_key(KEY_W, false); _key(KEY_SHIFT, false)
		await _frames(110, "sprint_catch_up")
		check(motion.global_position.distance_to(player.camera.global_position) < 2.4, "pursuit catches the sprint without accumulating separation at " + str(rate))
		var ticks := samples.size() - first
		check(motion.query_count - queries <= int(ceil(float(ticks) / Engine.physics_ticks_per_second / motion.probe_interval)) * 4 + 16, "proximity query work remains bounded at " + str(rate))
		_aim(motion.global_position)
		await _frames(110, "sustained_attention")
		check(motion.behavior == &"present" and motion.steady_for_input(), "sustained actual mouse attention yields a stable reading pose at " + str(rate))
		await _shot("reading_" + str(rate))
		_turn(PI)
		await _frames(15, "glance_away")
		check(motion.behavior == &"present", "brief glance does not flap attention state at " + str(rate))
		await _frames(90, "attention_release")
		check(motion.behavior == &"accompany", "looking away releases attention without orbiting after the gaze at " + str(rate))
		motion.recall()
		await _frames(150, "explicit_recall")
		check(motion.steady_for_input(), "explicit public recall presents a stable readable pose at " + str(rate))
		var before := motion.global_position
		check(not motion.recover_unobserved(before + Vector3.RIGHT, Callable()), "missing recovery visibility authority refuses relocation at " + str(rate))
		check(not motion.recover_unobserved(before + Vector3.RIGHT, func(_point: Vector3, _radius: float): return true), "observed recovery refuses relocation at " + str(rate))
		check(not motion.recover_unobserved(before + Vector3.RIGHT, func(_point: Vector3, _radius: float): return null), "nonboolean visibility result refuses relocation at " + str(rate))
		check(motion.global_position == before and motion.recovery_count == 0, "refused recoveries leave the actual body unchanged at " + str(rate))
		await _shot("recall_" + str(rate))
		player.set_physics_process(false)
	_finish()

func _frames(count: int, label: String) -> void:
	phase = label
	for tick in count:
		await get_tree().physics_frame
		if is_instance_valid(motion) and motion.initialized:
			samples.append({"rate":rate, "phase":phase, "player":_point(player.global_position), "companion":_point(motion.global_position), "velocity":_point(motion.velocity), "behavior":str(motion.behavior), "routing":motion._routing, "queries":motion.query_count})

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)

func _turn(angle: float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-angle / PlayerController.MOUSE_SENS, 0)
	Input.parse_input_event(event)

func _aim(point: Vector3) -> void:
	var direction := point - player.camera.global_position
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := atan2(direction.y, Vector2(direction.x, direction.z).length())
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-angle_difference(player.rotation.y, yaw), -(pitch - player.camera.rotation.x)) / PlayerController.MOUSE_SENS
	Input.parse_input_event(event)

func _manufactured_radius() -> float:
	var result := 0.0
	for fraction in [0.0, .13, .30]:
		rig.request_keyboard(false); rig._process(.3)
		if fraction > 0.0: rig.request_keyboard(true); rig._process(fraction)
		for draw: GeometryInstance3D in rig.find_children("*", "GeometryInstance3D", true, false):
			if not draw.is_visible_in_tree(): continue
			if draw is MeshInstance3D and draw.mesh != null:
				for point: Vector3 in draw.mesh.get_faces(): result = maxf(result, rig.to_local(draw.to_global(point)).length())
			elif draw is MultiMeshInstance3D:
				for index in 8: result = maxf(result, rig.to_local(draw.to_global(draw.get_aabb().get_endpoint(index))).length())
		rig.request_keyboard(false); rig._process(.3)
	return result

func _shot(name: String) -> void:
	for frame in 5: await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK, "rendered actual motion pose " + name)

func _fixture() -> void:
	_box(Vector3(0,-.15,0), Vector3(26,.3,20))
	_box(Vector3(-.9,1.4,.5), Vector3(.2,2.8,5.0))
	_box(Vector3(.9,1.4,.5), Vector3(.2,2.8,5.0))
	_box(Vector3(-.59,1.4,0), Vector3(.42,2.8,.18))
	_box(Vector3(.59,1.4,0), Vector3(.42,2.8,.18))
	_box(Vector3(0,2.5,0), Vector3(.76,.9,.18))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.13,.15,.17)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7,.68,.63)
	environment.environment.ambient_light_energy = .7
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0); light.light_energy = .8
	add_child(light)

func _box(point: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new(); body.position = point
	var collision := CollisionShape3D.new(); collision.shape = BoxShape3D.new(); collision.shape.size = size
	body.add_child(collision)
	var draw := MeshInstance3D.new(); draw.mesh = BoxMesh.new(); draw.mesh.size = size
	body.add_child(draw); add_child(body)

func _point(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func _finish() -> void:
	if finished: return
	finished = true
	_key(KEY_W, false); _key(KEY_SHIFT, false)
	Engine.max_fps = old_fps
	if had_sensitivity: GameBoot.settings["look_sensitivity"] = old_sensitivity
	else: GameBoot.settings.erase("look_sensitivity")
	if not directory.is_empty():
		FileAccess.open(directory.path_join("motion_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Local actual-player-input/collision/geometry diagnostic only. No normal V2 integration, autonomous campaign behavior, save or frame-time qualification.", "checks":checks, "failures":failures, "samples":samples}, "\t"))
	print("COMPANION MOTION: ", checks.size(), " checks; ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
