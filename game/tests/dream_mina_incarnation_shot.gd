extends Node
## INC-V3 production-root proof. The only world, camera, lamp, materials,
## exposure owner and fauna owner are the shipped DreamMazeRoot's.

const SEED_HEX := "f123456789abcdef"
const BLENDS := [0.0, 0.25, 0.50, 0.75, 1.0]

var root: DreamMazeRoot
var out_dir := ""
var failures := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	_stage_wall(false)
	_set_state(0.50, true)
	_set_incarnation(false)
	await _capture("00_control_a")
	await _capture("00_control_a_repeat")
	_set_incarnation(true)
	_set_state(0.0, false)
	await _capture("01_mina_dark")
	_set_state(0.50, true)
	await _capture("02_mina_oblique")
	_set_state(1.0, true)
	await _capture("03_mina_molten_blank_mercy")
	for i in BLENDS.size():
		_set_state(float(BLENDS[i]), i > 0)
		await _capture("04_blend_%02d" % i)
	_stage_wall(true)
	root.player.velocity = Vector3(0.4, 0.0, 0.0)
	_set_state(1.0, true)
	await _capture("05_long_sightline_antitile")
	_stage_wall(false)
	root.player.velocity = Vector3(0.4, 0.0, 0.0)
	_set_state(1.0, true)
	await _capture("06_palm_control_moving")
	root.player.velocity = Vector3.ZERO
	root.call("_update_molten")
	await _capture("06_still_palm_pressure")
	_stage_reflection_graze()
	await _capture("06_reflected_world_grazing")
	await _capture_fauna()
	print("[MINA INCARNATION SHOT] frames complete, findings=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": 1, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.player.camera.make_current()
	for _i in 16:
		root.fauna.advance_fixed()
	root.fauna.refresh()
	root.call("_collect_molten_materials")


func _stage_wall(long_view: bool) -> void:
	root.fauna.visible = false
	var room: Dictionary = root.rooms.room_at_key(str(root.get("_here_key")))
	var r: Array = room.rect
	var z := (float(r[1]) + float(r[3])) * 0.5
	var target := Vector3(float(r[2]) - 0.11, 1.42, z)
	var distance := 6.8 if long_view else 1.8
	root.player.global_position = target + Vector3(-distance, 0.0, 0.0) \
			- root.player.camera.position
	root.player.camera.look_at(target, Vector3.UP)
	root.player.call("_carry_service_light", 1.0)


func _stage_reflection_graze() -> void:
	root.fauna.visible = false
	var room: Dictionary = root.rooms.room_at_key(str(root.get("_here_key")))
	var r: Array = room.rect
	var target := Vector3(float(r[2]) - 0.11, 1.35,
			(float(r[1]) + float(r[3])) * 0.5)
	root.player.global_position = target + Vector3(-1.35, 0.0, -1.25) \
			- root.player.camera.position
	root.player.camera.look_at(target, Vector3.UP)
	root.player.velocity = Vector3.ZERO
	_set_state(1.0, true)


func _capture_fauna() -> void:
	root.fauna.visible = true
	var family_index := 0
	for child in root.fauna.get_children():
		if child is not MultiMeshInstance3D:
			continue
		for sibling in root.fauna.get_children():
			if sibling is MultiMeshInstance3D:
				sibling.visible = sibling == child
		var batch := child as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.instance_count == 0:
			continue
		var instance_transform := batch.multimesh.get_instance_transform(0)
		var target := batch.global_transform * instance_transform.origin
		var basis := batch.global_transform.basis * instance_transform.basis
		var front := (basis * Vector3(0.0, 0.0, 1.0)).normalized()
		root.player.global_position = target + front * 1.15 - root.player.camera.position
		root.player.camera.look_at(target + Vector3(0.0, 0.16, 0.0), Vector3.UP)
		_set_state(0.85, true)
		await _capture("07_fauna_%02d_%s" % [family_index, child.name.to_snake_case()])
		family_index += 1
	if family_index != 5:
		failures += 1
		printerr("[MINA INCARNATION SHOT] expected five fauna, got %d" % family_index)


func _set_incarnation(enabled: bool) -> void:
	for material in root.get("_molten_materials") as Array[ShaderMaterial]:
		material.set_shader_parameter("incarnation_id", 1.0 if enabled else 0.0)


func _set_state(response: float, lamp_on: bool) -> void:
	root.exposure.pin_irradiance_for_proof(response)
	root.exposure.upload(root.get("_exposure_tex"))
	root.player.set_lamp_enabled(lamp_on)
	root.player.pin_lamp_gutter_for_proof(maxf(
			PlayerController.LAMP_GUTTER_FLOOR, response))
	root.player.flashlight.visible = lamp_on
	root.player.call("_advance_lamp", 0.0)
	root.player.call("_carry_service_light", 1.0)
	root.call("_update_molten")


func _capture(file_name: String) -> void:
	for _frame in 16:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1
		printerr("[MINA INCARNATION SHOT] failed %s (%d)" % [path, error])
	else:
		print("[MINA INCARNATION SHOT] saved " + path)
