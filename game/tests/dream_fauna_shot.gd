extends Node
## F1: harmless dream fauna photographed in the production dream root.

const SEED_HEX := "f123456789abcdef"
var root: DreamMazeRoot
var out_dir := ""
var failures := 0
var room: Dictionary
var frame := Vector3.ZERO
var inward := Vector3.ZERO

func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty(): out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	if not _stage_birth_frame():
		get_tree().quit(1); return
	# Equal-interval A/A proves the live shader gait is below the comparison's
	# noise floor before any ecosystem state changes.
	root.fauna.visible = false
	await _capture("00_control_a")
	await _capture("00_control_a_repeat")
	root.fauna.visible = true
	root.fauna.refresh()
	await _capture("01_birth_frame_low_exposure")
	_feed_room()
	root.fauna.refresh()
	await _capture("02_lamp_gathering_ab")
	_stage_tenant_hush()
	root.fauna.refresh()
	await _capture("03_tenant_hush_reabsorption")
	print("[DREAM FAUNA SHOT] 5 frames, findings=%d census=%s" %
			[failures, root.fauna.census()])
	get_tree().quit(failures)

func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id":"mina_caption_crisis",
			"profile_id":"mina_release_print", "window":{},
			"seed_hex":SEED_HEX, "maze_revision":1, "outcome":"",
			"night_index":3, "spawn_anchor":1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.fauna.set_physics_process(false)
	root.pursuer.visible = false
	root.player.camera.make_current()

func _stage_birth_frame() -> bool:
	room = root.rooms.room_at_key(root.get("_here_key"))
	var key := str(room.get("key", ""))
	for body in get_tree().get_nodes_in_group("dream_lineage_bodies"):
		if str(body.get_meta("room_key", "")) != key: continue
		var frames: Array = body.get_meta("birth_frames", [])
		if frames.is_empty(): continue
		frame = frames[0]
		break
	if frame == Vector3.ZERO:
		failures += 1; printerr("[DREAM FAUNA SHOT] no real birth-frame")
		return false
	var rect: Array = room.rect
	var centre := Vector3((float(rect[0])+float(rect[2]))*0.5, 0.0,
			(float(rect[1])+float(rect[3]))*0.5)
	inward = centre-frame; inward.y=0.0
	root.player.global_position = frame + inward.normalized()*2.0
	root.player.camera.look_at(frame + Vector3(0.0,0.42,0.0),Vector3.UP)
	root.player.set_lamp_enabled(true)
	root.player.set("_lamp_phase",0.0); root.player.set("_lamp_phase_total",0.0)
	root.player.call("_advance_lamp",0.0)
	root.call("_update_molten")
	return true

func _feed_room() -> void:
	# Same production exposure writer and real service-lamp pose the root uses;
	# repeated fixed samples stand in for holding the beam on the crop.
	for _i in 24:
		root.call("_update_exposure",0.25)
	for _i in 10: root.fauna.advance_fixed()
	root.call("_update_molten")

func _stage_tenant_hush() -> void:
	root.pursuer.global_position = frame + inward.normalized()*0.62
	root.pursuer.visible = true

func _capture(file_name: String) -> void:
	for _frame in 60: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name+".png")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		failures += 1; printerr("[DREAM FAUNA SHOT] failed %s (%d)"%[path,error])
	else: print("[DREAM FAUNA SHOT] saved "+path)
