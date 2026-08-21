extends Node
const SEED_HEX := "f123456789abcdef"
var root: DreamMazeRoot
var out_dir := ""
var failures := 0

func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	var pair := _find_junction_pair()
	if pair.is_empty():
		get_tree().quit(1); return
	var target := str(pair.to)
	_stage(target)
	var branches: Array[String] = []
	for door in DreamRoomBuilder.passable_doors(root.rooms.room_at_key(target)):
		if int(door.get("index", -1)) > 0 and not str(door.get("leads_to", "")).is_empty():
			branches.append(str(door.leads_to))
	if branches.size() < 2:
		get_tree().quit(1); return
	_aim_at_room_centre(target)
	await _capture("00_one_object_before")
	await _capture("00b_one_object_control")
	var first := root.rooms.apply_profile_transition(root.get("_architecture"), branches[0], target)
	root.call("_refresh_profile_topology")
	root.pursuer.notify_profile_event(str(first.get("event", "")))
	await _capture("01_first_provenance")
	root.rooms.apply_profile_transition(root.get("_architecture"), branches[1], target)
	root.call("_refresh_profile_topology")
	await _capture("02_same_object_two_histories")
	root.player.set_lamp_enabled(false)
	await _capture("03_contradiction_lamp_off")
	print("[MAE PROFILE SHOT] 5 frames findings=%d" % failures)
	get_tree().quit(failures)

func _build() -> void:
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id":"mae_contradictory_antiques", "profile_id":"mae_release_print",
			"window":{}, "seed_hex":SEED_HEX, "maze_revision":1, "outcome":"",
			"night_index":4, "spawn_anchor":1})
	add_child(root); await get_tree().process_frame
	root.player.set_physics_process(false); root.pursuer.set_physics_process(false)
	root.pursuer.visible = false; root.player.camera.make_current()

func _find_junction_pair() -> Dictionary:
	var path: PackedInt32Array = root.get("_here_path")
	for _step in 96:
		_stage(DreamRoomBuilder.key_of(path))
		var key := DreamRoomBuilder.key_of(path)
		var room := root.rooms.room_at_key(key)
		var chosen := {}
		for door in DreamRoomBuilder.passable_doors(room):
			if int(door.get("index", -1)) > 0 and not str(door.get("leads_to", "")).is_empty():
				chosen = door; break
		if chosen.is_empty(): return {}
		var prior := key
		path = root.rooms.path_of(str(chosen.leads_to))
		_stage(DreamRoomBuilder.key_of(path))
		if DreamRoomBuilder.passable_doors(root.rooms.room_at_key(prior)).size() >= 3:
			return {"to":prior}
	return {}

func _stage(key: String) -> void:
	var path := root.rooms.path_of(key)
	root.rooms.advance(root.get("_architecture"), path)
	root.set("_here_key", key); root.set("_here_path", path)
	root.call("_refresh_profile_topology")

func _aim_at_room_centre(key: String) -> void:
	var r: Array = root.rooms.room_at_key(key).rect
	var target := Vector3((r[0]+r[2])*0.5, 0.0, (r[1]+r[3])*0.5)
	root.player.position = Vector3(target.x, 0.0, float(r[1])+0.42)
	var flat := target - root.player.position
	flat.y = 0.0
	root.player.look_at(root.player.position + flat, Vector3.UP)
	root.player.camera.rotation.x = -0.28
	root.player.set_lamp_enabled(true)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.flashlight.visible = true
	root.player.flashlight.light_energy = float(root.player.get("_lamp_base_energy"))
	root.player.call("_advance_lamp", 0.0)

func _capture(name: String) -> void:
	for _i in 60: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(out_dir.path_join(name+".png"))
	if err != OK: failures += 1
