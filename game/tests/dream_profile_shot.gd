extends Node
## PETER'S FIRST SHARED-PROFILE CONSEQUENCE, PHOTOGRAPHED IN PRODUCTION SPACE.
##
##     SHOT_DIR=<abs> godot --path game res://tests/DreamProfileShot.tscn
##
## No helper camera, environment, light or room is added. The production body
## stands in a real Peter-salted pocket and aims its real service lamp at the
## wall where a ruled junction reversal deals the duplicated corridor another
## door.

const SEED_HEX := "f123456789abcdef"

var root: DreamMazeRoot
var out_dir := ""
var failures := 0


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	var pair := _find_junction_pair()
	if pair.is_empty():
		printerr("[DREAM PROFILE SHOT] no deterministic junction reversal")
		get_tree().quit(1)
		return
	var from_key := str(pair.from)
	var to_key := str(pair.to)
	var before: Dictionary = root.rooms.room_at_key(to_key)
	var future := _future_door(before)
	if future.is_empty():
		printerr("[DREAM PROFILE SHOT] corridor cannot receive another door")
		get_tree().quit(1)
		return
	_stage_camera(to_key, before, future)
	_settle_lamp(true)
	await _capture("00_pending_corridor_before")
	# The Klimt and tissue surfaces continue moving while the camera is still.
	# This second unchanged frame is the negative control for any pixel A/B;
	# without it a shader-time delta could be credited to Peter's room rule.
	await _capture("00b_pending_corridor_control")
	var event := root.rooms.apply_profile_transition(
			root.get("_architecture") as Node3D, from_key, to_key)
	if event.is_empty():
		printerr("[DREAM PROFILE SHOT] profile event refused")
		get_tree().quit(1)
		return
	# The production root rolls the pocket immediately after accepting the
	# threshold event. That resolves the new opening to a real neighbour or a
	# sealed false door before any player can see it; photograph that state,
	# never the one-frame unresolved hole between the two owners.
	root.rooms.advance(root.get("_architecture") as Node3D,
			root.rooms.path_of(to_key))
	root.rooms.write_plan(root.plan, to_key)
	root.call("_rebuild_practicals")
	root.call("_collect_molten_materials")
	root.pursuer.notify_profile_event(str(event.event))
	var stamp := (root.get("_architecture") as Node3D).find_child(
			"ProceedUncertainStamp", true, false) as MultiMeshInstance3D
	if stamp != null:
		print("[DREAM PROFILE SHOT] stamp aabb=%s world=%s screen=%s" % [
				str(stamp.get_aabb()), str(stamp.global_position),
				str(root.player.camera.unproject_position(
						stamp.to_global(stamp.get_aabb().get_center())))])
	await _capture("01_reversal_stamps_another_door")
	_settle_lamp(false)
	await _capture("02_form_door_lamp_off")
	print("[DREAM PROFILE SHOT] 4 frames, findings=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "peter_form_corridor",
		"profile_id": "peter_release_print",
		"window": {},
		"seed_hex": SEED_HEX,
		"maze_revision": 1,
		"outcome": "",
		"night_index": 3,
		"spawn_anchor": 1,
	})
	add_child(root)
	await get_tree().process_frame
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.player.camera.make_current()


func _find_junction_pair() -> Dictionary:
	var path: PackedInt32Array = root.get("_here_path")
	for _step in 96:
		_stage_path(path)
		var here_key := DreamRoomBuilder.key_of(path)
		var here: Dictionary = root.rooms.room_at_key(here_key)
		var chosen: Dictionary = {}
		for door in DreamRoomBuilder.passable_doors(here):
			if int(door.get("index", -1)) == 0:
				continue
			var next_key := str(door.get("leads_to", ""))
			if not next_key.is_empty() \
					and not root.rooms.room_at_key(next_key).is_empty():
				chosen = door
				break
		if chosen.is_empty():
			return {}
		var prior_key := here_key
		var next_key := str(chosen.leads_to)
		path = root.rooms.path_of(next_key)
		_stage_path(path)
		var current: Dictionary = root.rooms.room_at_key(next_key)
		var prior: Dictionary = root.rooms.room_at_key(prior_key)
		if not current.is_empty() and not prior.is_empty() \
				and DreamRoomBuilder.passable_doors(current).size() >= 3 \
				and (prior.doors as Array).size() < DreamAtlas.MAX_DOORS:
			return {"from": next_key, "to": prior_key}
	return {}


func _stage_path(path: PackedInt32Array) -> void:
	var key := DreamRoomBuilder.key_of(path)
	root.rooms.advance(root.get("_architecture") as Node3D, path)
	root.rooms.write_plan(root.plan, key)
	root.set("_here_path", path)
	root.set("_here_key", key)
	root.hazards.rearm(root.plan, root.profile_hazards)
	root.call("_rebuild_hazard_growth")
	root.call("_rebuild_practicals")
	root.call("_collect_molten_materials")


func _future_door(room: Dictionary) -> Dictionary:
	var before := (room.doors as Array).size()
	var entry_offset := root.rooms._entry_offset(int(room.id), room.size)
	var doors := root.rooms._door_layout(int(room.id), room.size, before + 1,
			entry_offset, int(room.rot), room.origin,
			(room.path as PackedInt32Array).size() > 0)
	return doors[before] if doors.size() > before else {}


func _stage_camera(room_key: String, room: Dictionary,
		door: Dictionary) -> void:
	var rect: Array = room.rect
	var room_centre := Vector3(
			(float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	var point: Array = door.point
	var target := Vector3(float(point[0]), 1.20, float(point[1]))
	root.player.global_position = room_centre.lerp(
			Vector3(target.x, 0.0, target.z), 0.30)
	# This A frame is the room before the reversal changes it. Tell the normal
	# fixed update the same truth so it may keep feeding the production lamps
	# and surfaces without interpreting the staged camera as a second crossing.
	root.set("_here_key", room_key)
	root.set("_here_path", root.rooms.path_of(room_key))
	var flat := target - root.player.global_position
	flat.y = 0.0
	if flat.length() > 0.01:
		root.player.look_at(root.player.global_position + flat, Vector3.UP)
	root.player.camera.rotation.x = 0.0
	root.call("_update_practical")
	print(("[DREAM PROFILE SHOT] room=%s source=%s rect=%s door=%s "
			+ "stand=%s forward=%s") % [room_key, str(room.source), str(rect),
			str(door), str(root.player.global_position), str(flat.normalized())])


func _settle_lamp(on: bool) -> void:
	# The proof does not need the half-second switch transient. Put the real
	# carried lamp at the stable endpoint its own process reaches, retaining its
	# production pose, range, cone and energy budget.
	root.player.set_lamp_enabled(on)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.flashlight.visible = on
	root.player.flashlight.light_energy = float(root.player.get(
			"_lamp_base_energy")) if on else 0.0
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")


func _capture(file_name: String) -> void:
	for _frame in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[DREAM PROFILE SHOT] failed to save %s (%d)" % [path, error])
	else:
		print("[DREAM PROFILE SHOT] saved %s" % path)
