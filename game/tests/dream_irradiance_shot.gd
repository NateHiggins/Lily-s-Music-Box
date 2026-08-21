extends Node
## IR-V1/IR-V2 production-root visual proof. No helper world, light or material.

const SEED_HEX := "f123456789abcdef"
const BLEND_VALUES := [0.0, 0.25, 0.50, 0.75, 1.0]

var root: DreamMazeRoot
var out_dir := ""
var failures := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	_prepare_ecology()
	_stage_wall()
	root.fauna.visible = false
	_set_state(0.50, true)
	await _capture("00_control_a")
	await _capture("00_control_a_repeat")
	await _capture_states("wall")
	for i in BLEND_VALUES.size():
		_set_state(float(BLEND_VALUES[i]), i > 0)
		await _capture("02_wall_blend_%02d" % i)

	var tess := root.fauna.get_node("Tessellates") as MultiMeshInstance3D
	if tess == null or tess.multimesh.instance_count == 0:
		failures += 1
		printerr("[IRRADIANCE SHOT] Tessellates absent")
	else:
		_stage_tessellate(tess)
		await _capture_states("tessellate")
		for i in BLEND_VALUES.size():
			_set_state(float(BLEND_VALUES[i]), i > 0)
			await _capture("04_tessellate_blend_%02d" % i)

	_stage_wall()
	root.pursuer.visible = true
	_set_state(1.0, true)
	await _capture("05_long_shadow_steady")
	_set_state(PlayerController.LAMP_GUTTER_FLOOR, true)
	await _capture("05_long_shadow_gutter")
	await _write_luma_trace()
	await _capture_trunk_floor_pair()
	print("[IRRADIANCE SHOT] 22 frames + trace, findings=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "juno_feedback_tetris",
			"profile_id": "juno_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": 3, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.player.set_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.fauna.visible = false
	root.fauna.set_physics_process(false)
	root.player.camera.make_current()


func _prepare_ecology() -> void:
	for _i in 16:
		root.fauna.advance_fixed()
	root.fauna.refresh()
	root.call("_collect_molten_materials")


func _stage_wall() -> void:
	root.fauna.visible = false
	var room: Dictionary = root.rooms.room_at_key(str(root.get("_here_key")))
	var r: Array = room.rect
	var z := (float(r[1]) + float(r[3])) * 0.5
	var wall_x := float(r[2]) - 0.11
	var target := Vector3(wall_x, 1.42, z)
	root.player.global_position = target + Vector3(-3.2, 0.0, 0.0) \
			- root.player.camera.position
	root.player.camera.look_at(target, Vector3.UP)
	root.player.call("_carry_service_light", 1.0)


func _stage_tessellate(batch: MultiMeshInstance3D) -> void:
	root.fauna.visible = true
	for child in root.fauna.get_children():
		child.visible = child == batch
	var instance_transform := batch.multimesh.get_instance_transform(0)
	var target := batch.global_transform * instance_transform.origin
	var world_basis := batch.global_transform.basis * instance_transform.basis
	var front := (world_basis * Vector3(0.0, 0.0, 1.0)).normalized()
	root.player.global_position = target + front * 2.1 - root.player.camera.position
	root.player.camera.look_at(target + Vector3(0.0, 0.18, 0.0), Vector3.UP)
	root.player.call("_carry_service_light", 1.0)


func _capture_states(slug: String) -> void:
	_set_state(0.0, false)
	await _capture("01_%s_dark" % slug)
	_set_state(0.50, true)
	await _capture("01_%s_oblique" % slug)
	_set_state(1.0, true)
	await _capture("01_%s_molten" % slug)


func _set_state(response: float, lamp_on: bool) -> void:
	root.exposure.pin_irradiance_for_proof(response)
	root.exposure.upload(root.get("_exposure_tex"))
	root.player.set_lamp_enabled(lamp_on)
	root.player.pin_lamp_gutter_for_proof(maxf(
			PlayerController.LAMP_GUTTER_FLOOR, response))
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.flashlight.visible = lamp_on
	root.player.call("_advance_lamp", 0.0)
	root.player.call("_carry_service_light", 1.0)
	root.call("_update_molten")


func _capture(file_name: String) -> void:
	for _frame in 24:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1
		printerr("[IRRADIANCE SHOT] failed %s (%d)" % [path, error])
	else:
		print("[IRRADIANCE SHOT] saved " + path)


func _write_luma_trace() -> void:
	_stage_wall()
	root.fauna.visible = false
	var file := FileAccess.open(out_dir.path_join("gutter_luma_trace.csv"),
			FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_line("seconds,multiplier,range_m,mean_luma")
	root.player.pin_lamp_gutter_for_proof(-1.0)
	for i in 433:
		var seconds := float(i) * 0.25
		root.player.set_lamp_gutter_clock(seconds)
		root.exposure.pin_irradiance_for_proof(
				root.player.lamp_delivered_multiplier())
		root.exposure.upload(root.get("_exposure_tex"))
		root.call("_update_molten")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(32, 18, Image.INTERPOLATE_BILINEAR)
		var luma := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				luma += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
		luma /= float(image.get_width() * image.get_height())
		file.store_csv_line(PackedStringArray([str(seconds),
				str(root.player.lamp_delivered_multiplier()),
				str(root.player.flashlight.spot_range), str(luma)]))
	file.close()


## The doctrine's hazard stop gate: at the deepest legal sag the existing
## Vantry arc must still say why light makes this conduit dangerous. A second
## production profile is built only after the Juno root is freed; there is
## never more than one world, camera or service lamp in the tree.
func _capture_trunk_floor_pair() -> void:
	root.queue_free()
	await get_tree().process_frame
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": ""})
	add_child(root)
	await get_tree().process_frame
	root.player.set_physics_process(false)
	root.player.set_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.player.camera.make_current()
	var trunk: DreamHazard = await _ensure_trunk()
	if trunk == null:
		failures += 1
		printerr("[IRRADIANCE SHOT] Vantry trunk absent")
		return
	var rect: Array = []
	for module in root.plan.modules:
		if str(module.id) == trunk.module:
			rect = module.rect
			break
	if rect.size() < 4:
		failures += 1
		return
	var distance := trunk.tell_radius * 0.75
	var span_x := float(rect[2]) - float(rect[0])
	var span_z := float(rect[3]) - float(rect[1])
	var axis := Vector3.RIGHT if span_x >= span_z else Vector3.FORWARD
	var forward_room := float(rect[2]) - trunk.position.x if span_x >= span_z \
			else float(rect[3]) - trunk.position.z
	if forward_room < distance + 0.6:
		axis = -axis
	root.player.position = trunk.position + axis * distance
	root.player.position.y = 0.0
	var forward := trunk.position - root.player.position
	forward.y = 0.0
	root.player.rotation.y = atan2(forward.x, -forward.z)
	root.player.camera.look_at(Vector3(trunk.position.x, 0.72,
			trunk.position.z), Vector3.UP)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(PlayerController.LAMP_GUTTER_FLOOR)
	for _frame in 20:
		await get_tree().physics_frame
	var arc: MeshInstance3D
	for entry in root.get("_arcs"):
		if entry.hazard == trunk:
			arc = entry.arc
			break
	if arc == null or not arc.visible:
		failures += 1
		var arc_names: Array[String] = []
		for node in root.find_children("DreamArc_*", "MeshInstance3D", true, false):
			arc_names.append(node.name)
		printerr("[IRRADIANCE SHOT] Vantry arc hidden at gutter floor: "
				+ "arc=%s names=%s id=%s contacted=%s lamp=%s distance=%.3f tell=%.3f clear=%.3f"
				% [str(arc), str(arc_names), trunk.id,
				str(trunk.contacted),
				str(root.player.lamp_is_enabled()),
				Vector2(root.player.position.x - trunk.position.x,
				root.player.position.z - trunk.position.z).length(),
				trunk.tell_radius, trunk.clearance_radius])
		return
	root.player.camera.look_at(arc.global_position, Vector3.UP)
	await _capture("06_vantry_arc_gutter_floor")
	root.player.set_lamp_enabled(false)
	await _capture("06_vantry_arc_lamp_off")


func _ensure_trunk(hops: int = 30) -> DreamHazard:
	for hop in hops + 1:
		for hazard in root.hazards.hazards:
			if hazard.socket == "vantry_signal_trunk" \
					or hazard.id == "vantry_signal_trunk":
				return hazard
		if hop == hops:
			break
		var here := root.rooms.room_at(root.player.position.x,
				root.player.position.z)
		if here.is_empty():
			break
		var onward: Array = []
		for door in DreamRoomBuilder.passable_doors(here):
			if int(door.index) != 0:
				onward.append(door)
		if onward.is_empty():
			break
		var door: Dictionary = onward[hop % onward.size()]
		var point: Array = door.point
		var inside: Array = door.inside
		var out := Vector2(point[0] - inside[0],
				point[1] - inside[1]).normalized()
		root.player.position = Vector3(point[0] + out.x * 0.6, 0.0,
				point[1] + out.y * 0.6)
		await get_tree().physics_frame
		await get_tree().process_frame
	return null
