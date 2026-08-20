extends Node
## N12: Juno's delayed feedback wall in the production dream body.

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
	var player_key: String = root.get("_here_key")
	var pursuer_key := root.rooms.nav_room_at(root.pursuer.position.x,
			root.pursuer.position.z)
	var probe := root.rooms.congeal_channel_partition(
			root.get("_architecture") as Node3D, player_key,
			root.player.position, pursuer_key, 1)
	if probe.is_empty():
		printerr("[JUNO PROFILE SHOT] no deterministic safe joint")
		get_tree().quit(1)
		return
	root.rooms.release_oldest_channel_partition()
	root.call("_refresh_profile_topology")
	var from_key := str(probe.from)
	var to_key := str(probe.to)
	var door: Dictionary = root.rooms.call("_door_to_any", from_key, to_key)
	_stage_camera(from_key, door)
	_settle_lamp(true)
	await _capture("00_open_channel_before")
	await _capture("00b_open_channel_control")
	var event := root.rooms.congeal_channel_partition(
			root.get("_architecture") as Node3D, player_key,
			root.player.position, pursuer_key, 1)
	root.call("_refresh_profile_topology")
	root.pursuer.notify_profile_event(str(event.get("event", "")))
	await _capture("01_delayed_echo_partition")
	_settle_lamp(false)
	await _capture("02_partition_lamp_off")
	_settle_lamp(true)
	root.rooms.release_oldest_channel_partition()
	root.call("_refresh_profile_topology")
	await _capture("03_sustained_channel_reopens")
	print("[JUNO PROFILE SHOT] 5 frames, findings=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({"case_id": "juno_feedback_tetris",
			"profile_id": "juno_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": 3, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.player.camera.make_current()


func _stage_camera(room_key: String, door: Dictionary) -> void:
	var room := root.rooms.room_at_key(room_key)
	var rect: Array = room.rect
	var point: Array = door.point
	var target := Vector3(float(point[0]), 1.15, float(point[1]))
	var centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	root.player.global_position = centre.lerp(Vector3(target.x, 0.0, target.z), 0.22)
	var flat := target - root.player.global_position
	flat.y = 0.0
	root.player.look_at(root.player.global_position + flat, Vector3.UP)
	root.player.camera.rotation.x = 0.0
	root.call("_update_practical")
	print("[JUNO PROFILE SHOT] joint=%s>%s stand=%s" % [room_key,
			str(door.leads_to), str(root.player.global_position)])


func _settle_lamp(on: bool) -> void:
	root.player.set_lamp_enabled(on)
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
	var path := out_dir.path_join(file_name + ".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1
		printerr("[JUNO PROFILE SHOT] failed %s (%d)" % [path, error])
	else:
		print("[JUNO PROFILE SHOT] saved %s" % path)
