extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var world: OrisonV2RuntimeRoot
var player: PlayerController
var checks := 0
var failures: Array[String] = []
var trace: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("DOMESTIC ROUTE: " + label)

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().create_timer(0.5).timeout
	_check(not world.startup_failed, "runtime starts")
	if not world.startup_failed:
		player = world.player
		# One initial placement; every subsequent room is reached by normal input.
		player.global_position = _point(8.85, -3.25) + Vector3.UP * 0.02
		player.velocity = Vector3.ZERO
		player.camera.make_current()
		player.set_lamp_enabled(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await get_tree().physics_frame
		await _door("F03_DOOR_03", Vector2(9.5, -3.25))
		await _walk(10.95, -3.25)
		await _walk(10.95, -2.5)
		await _walk(12.5, -2.5)
		await _walk(12.5, -1.35)
		await _walk(13.65, -1.35)
		await _use("F03_B_LAMP_01", Vector3(14.25, 7.4, -0.02), "task lamp")
		var lamp := world.find_child("F03_B_LAMP_01", true, false) as LampProp
		_check(not lamp.is_locally_enabled(), "bench lamp switches off through player input")
		await _use("F03_B_LAMP_01", Vector3(14.25, 7.4, -0.02), "task lamp")
		_check(lamp.is_locally_enabled(), "bench lamp switches back on")
		# The meal group occupies the centre; use the west-side aisle.
		await _walk(12.5, -1.35)
		await _walk(12.5, -2.5)
		await _walk(12.6, -3.55)
		await _walk(12.6, -4.45)
		await _walk(14.2, -4.45)
		await _walk(14.2, -6.8)
		await _walk(11.8, -6.8)
		await _walk(14.2, -6.8)
		await _walk(14.2, -9.15)
		await _walk(13.75, -9.15)
		await _door("F03_B_ALCOVE_DOOR", Vector2(13, -9.15))
		await _walk(11.7, -9.15)
		await _use("3B_aw_wardrobe", Vector3(10.4, 7.5, -8.5), "wardrobe")
		var wardrobe: Node = world.adapter.resolve("3B_aw_wardrobe")
		_check("Close" in wardrobe.interact_prompt(), "wardrobe opens through player input")
		await _walk(13.8, -9.15)
		await _walk(14.2, -9.0)
		await _door("F03_B_BATH_DOOR", Vector2(14.2, -9.8))
		await _walk(14.2, -10.6)
		await _walk(15.05, -11.02)
		await _use("3B_wc", Vector3(15.05, 7.2, -11.9), "water closet")
		var wc: Node = world.adapter.resolve("3B_wc")
		_check("refilling" in wc.interact_prompt(), "WC flushes through player input")
		await _walk(14.2, -10.6)
		await _walk(14.2, -6.8)
		await _walk(10.25, -6.8)
		await _door("F03_B_SERVICE_DOOR", Vector2(9.5, -6.8))
		await _walk(8.9, -6.8)
		await _walk(8.9, -3.25)
		_check(not player.noclip and player.collision_mask == 1 and player.is_physics_processing(),
				"ordinary controller and collision remain active")
	Input.action_release("move_forward")
	Input.action_release("interact")
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("route.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "trace": trace}, "  "))
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().create_timer(0.25).timeout
	print("DOMESTIC ROUTE: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _point(x: float, z: float) -> Vector3:
	return world.adapter.root.to_global(Vector3(x, 6.4, z))

func _walk(x: float, z: float) -> void:
	var target := _point(x, z)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 4500:
		var delta := target - player.global_position
		delta.y = 0
		if delta.length() < 0.12: break
		player.rotation.y = atan2(-delta.x, -delta.z)
		player.camera.rotation = Vector3.ZERO
		Input.action_press("move_forward", minf(1.0, delta.length() / 0.35))
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	var actual: Vector3 = world.adapter.root.to_local(player.global_position)
	trace.append({"target": [x, z], "actual": [actual.x, actual.y, actual.z]})
	_check(Vector2(actual.x - x, actual.z - z).length() < 0.18 and absf(actual.y - 6.4) < 0.12,
			"walk reaches (%s, %s), actual %s" % [x, z, actual])

func _door(identity: String, center: Vector2) -> void:
	var anchor := world.adapter.resolve(identity) as Node3D
	var door := anchor.get_node(identity + "_Leaf") as DoorProp
	_check(not door.open, "door starts closed: " + identity)
	await _use(identity, Vector3(center.x, 7.5, center.y), "Open door")
	_check(door.open, "door opens through input: " + identity)
	await get_tree().create_timer(0.6).timeout

func _use(identity: String, target: Vector3, prompt: String) -> void:
	player.camera.look_at(world.adapter.root.to_global(target))
	await get_tree().process_frame
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	var owner_node := hit.get("collider") as Node
	var matched := false
	while owner_node != null:
		if str(owner_node.name) == identity: matched = true
		owner_node = owner_node.get_parent()
	_check(matched, "physical ray reaches intended owner: " + identity)
	player._update_prompt()
	_check(prompt.to_lower() in player._prompt.text.to_lower(), "player prompt for " + identity + ": " + player._prompt.text)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(identity + ".png"))
		await get_tree().process_frame
	Input.action_press("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().create_timer(0.15).timeout
