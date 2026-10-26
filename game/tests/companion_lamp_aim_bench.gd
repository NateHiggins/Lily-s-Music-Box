extends Node3D
## Local optical diagnostic, not occupied-world qualification.
var checks: Array[Dictionary] = []
var player: PlayerController
var carrier: Node
var directory := ""

func check(ok: bool, label: String) -> void:
	checks.append({"name":label, "passed":ok})
	print("COMPANION LAMP: ", label, " = ", ok)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	player = PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.camera.make_current()
	carrier = preload("res://scripts/device/companion_world_carrier.gd").new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	check(carrier.world_ready, "native flying instrument binds")
	if not carrier.world_ready: _finish(); return
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(20, 20, .2)
	collision.shape = box; wall.add_child(collision); add_child(wall)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = box.size; visual.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = Color(.35, .38, .32)
	visual.material_override = material; wall.add_child(visual)
	# Power is exercised through the original input action, not a second lamp.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if carrier.device.lamp_enabled: await _lamp_key()
	check(not carrier.device.lamp_enabled, "actual L switches off the original lamp")
	var disabled_queries: int = carrier.lamp_target_queries
	carrier.world_lamp_transform(); carrier.world_lamp_transform()
	check(carrier.lamp_target_queries == disabled_queries, "disabled lamp performs no aiming queries")
	await _lamp_key()
	check(carrier.device.lamp_enabled, "existing L control powers the original lamp")
	for distance in [.8, 3.5, 6.0]:
		player.camera.rotation = Vector3(.25, .4, 0) if distance == 3.5 else Vector3.ZERO
		wall.global_transform = player.camera.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -distance))
		await get_tree().physics_frame
		await get_tree().process_frame
		# A stale interaction hit must not steer a working lamp.
		player._grab.last_hit = {"position":Vector3(100, 100, 100)}
		carrier._lamp_target_frame = -1
		var pose: Transform3D = carrier.world_lamp_transform()
		var expected := player.camera.global_position - player.camera.global_basis.z * (distance - .1)
		check(carrier.motion.light_target.distance_to(expected) < .002, "centre ray finds surface at %.1f m independently of hand reach" % distance)
		var lens: MeshInstance3D = carrier.device.teletype.torch_lens
		check(pose.origin.distance_to(lens.to_global(lens.mesh.get_aabb().get_center())) < .00001, "beam originates at manufactured bot lens %.1f" % distance)
		check((-pose.basis.z).dot((expected-pose.origin).normalized()) > .9999, "beam converges on viewed surface %.1f" % distance)
		var count: int = carrier.lamp_target_queries
		carrier.world_lamp_transform(); carrier.world_lamp_transform()
		check(count == carrier.lamp_target_queries, "repeated reads reuse physics-tick optical query %.1f" % distance)
		player._carry_service_light(.016)
		check(player.flashlight.global_position.distance_to(pose.origin) < .00001 and player.flashlight.get_parent() == player._hand,
			"existing player light follows the bot aperture %.1f" % distance)
	wall.position.x = 100
	await get_tree().physics_frame
	await get_tree().process_frame
	carrier._lamp_target_frame = -1
	var empty: Transform3D = carrier.world_lamp_transform()
	check(carrier.motion.light_target.distance_to(player.camera.global_position - player.camera.global_basis.z * player.flashlight.spot_range) < .002,
		"empty sky aims forward at lamp range")
	check(empty.is_finite(), "empty-space aim remains finite")
	wall.position = player.camera.global_position + Vector3(0, 0, -3.5)
	await get_tree().physics_frame
	await get_tree().process_frame
	player._carry_service_light(.016)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("bot_surface_beam.png"))
	_finish()

func _lamp_key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_L; event.physical_keycode = KEY_L; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
		await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	await get_tree().process_frame

func _finish() -> void:
	var failed := checks.any(func(row: Dictionary): return not row.passed)
	FileAccess.open(directory.path_join("observations.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT", "scope":"Local native lamp/input diagnostic; no occupied-world or save qualification",
		"checks":checks, "passed":not failed}, "\t"))
	get_tree().quit(1 if failed else 0)
