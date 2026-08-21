extends Node
## INC-V3 production-root proof. The only world, camera, lamp, materials,
## exposure owner and fauna owner are the shipped DreamMazeRoot's.

const SEED_HEX := "f123456789abcdef"
const BLENDS := [0.0, 0.25, 0.50, 0.75, 1.0]
const CASES := {
	"mina": ["mina_caption_crisis", "mina_release_print", 1,
			"blank_mercy", "palm", "still_palm_pressure"],
	"peter": ["peter_form_corridor", "peter_release_print", 2,
			"decision_route", "initial_pressure", "held_initial_pressure"],
	"juno": ["juno_feedback_tetris", "juno_release_print", 3,
			"standing_wave", "quiet_node", "held_quiet_node"],
	"mae": ["mae_contradictory_antiques", "mae_release_print", 4,
			"double_reflection", "shared_thumbprint", "held_shared_thumbprint"],
	"cal": ["cal_memory_radio", "cal_release_print", 5,
			"completed_phrase", "warm_handprint", "held_warm_handprint"],
	"omar": ["omar_unrepairable", "omar_release_print", 6,
			"honest_seam", "laid_down_tool", "held_laid_down_tool"],
}

var root: DreamMazeRoot
var out_dir := ""
var failures := 0
var incarnation := "mina"


func _ready() -> void:
	incarnation = OS.get_environment("DREAM_INCARNATION").to_lower()
	if incarnation.is_empty():
		incarnation = "mina"
	if not CASES.has(incarnation):
		printerr("[INCARNATION SHOT] unsupported case " + incarnation)
		get_tree().quit(2)
		return
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
	await _capture("01_%s_dark" % incarnation)
	_set_state(0.50, true)
	await _capture("02_%s_oblique" % incarnation)
	_set_state(1.0, true)
	var config: Array = CASES[incarnation]
	await _capture("03_%s_molten_%s" % [incarnation, str(config[3])])
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
	await _capture("06_%s_control_moving" % str(config[4]))
	root.player.velocity = Vector3.ZERO
	root.call("_update_molten")
	await _capture("06_%s" % str(config[5]))
	_stage_reflection_graze()
	await _capture("06_reflected_world_grazing")
	await _capture_fauna()
	print("[INCARNATION SHOT] %s frames complete, findings=%d" %
			[incarnation, failures])
	get_tree().quit(failures)


func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	var config: Array = CASES[incarnation]
	root.configure_dream({"case_id": str(config[0]),
			"profile_id": str(config[1]), "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": int(config[2]), "spawn_anchor": 1})
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
	root.player.global_position = target + Vector3(-1.8, 0.0, -2.4) \
			- root.player.camera.position
	root.player.camera.look_at(target, Vector3.UP)
	root.player.velocity = Vector3.ZERO
	_set_state(1.0, true)


func _capture_fauna() -> void:
	root.fauna.visible = true
	var room: Dictionary = root.rooms.room_at_key(str(root.get("_here_key")))
	var rect: Array = room.rect
	var room_centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5,
			0.9, (float(rect[1]) + float(rect[3])) * 0.5)
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
		var inward := room_centre - target
		inward.y = 0.0
		if inward.length_squared() < 0.01:
			inward = -front
		else:
			inward = inward.normalized()
		var distance := 0.34 if family_index == 0 else 1.15
		var lift := 0.08 if family_index == 0 else 0.28
		root.player.global_position = target + inward * distance \
				+ Vector3.UP * lift - root.player.camera.position
		root.player.camera.look_at(target + Vector3(0.0,
				0.035 if family_index == 0 else 0.16, 0.0), Vector3.UP)
		_set_state(1.0, true)
		await _capture("07_fauna_%02d_%s" % [family_index, child.name.to_snake_case()])
		family_index += 1
	if family_index != 5:
		failures += 1
		printerr("[INCARNATION SHOT] expected five fauna, got %d" % family_index)


func _set_incarnation(enabled: bool) -> void:
	for material in root.get("_molten_materials") as Array[ShaderMaterial]:
		var index := float(CASES[incarnation][2])
		material.set_shader_parameter("incarnation_id", index if enabled else 0.0)


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
		printerr("[INCARNATION SHOT] failed %s (%d)" % [path, error])
	else:
		print("[INCARNATION SHOT] saved " + path)
