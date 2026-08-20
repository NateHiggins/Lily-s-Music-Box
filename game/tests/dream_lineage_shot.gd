extends Node
## THE REPRODUCTIVE PATH, PHOTOGRAPHED IN THE PRODUCTION DREAM.
##
##     SHOT_DIR=<abs> godot --path game res://tests/DreamLineageShot.tscn
##
## No helper light, environment or geometry is added. The only staging is the
## real player body and service lamp aimed at one generated brood knot, then at
## the birth-frame shared with one child room.

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
	await _brood_shot()
	await _door_shot()
	print("[DREAM LINEAGE SHOT] 3 frames, findings=%d" % failures)
	get_tree().quit(failures)


func _build() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	root = scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print",
		"window": {},
		"seed_hex": SEED_HEX,
		"maze_revision": 1,
		"outcome": "",
		"night_index": 7,
		"spawn_anchor": 0,
	})
	add_child(root)
	await get_tree().process_frame
	# Keep the root's fixed update alive: it is what pushes the real lamp pose
	# into every Klimt material. `autonomous = false` already stops pursuit and
	# the run cap without freezing the surface system being photographed.
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.pursuer.visible = false
	root.player.camera.make_current()


func _brood_shot() -> void:
	var room: Dictionary = root.rooms.room_at_key(root._here_key)
	var body := _body_for(room)
	if body == null:
		failures += 1
		printerr("[DREAM LINEAGE SHOT] no waking-room lineage body")
		return
	var rect: Array = room.rect
	var centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	var width := float(rect[2]) - float(rect[0])
	var depth := float(rect[3]) - float(rect[1])
	var offset := Vector3.ZERO
	if width >= depth:
		offset.x = minf(1.45, maxf(0.72, width * 0.22))
	else:
		offset.z = minf(1.45, maxf(0.72, depth * 0.22))
	root.player.global_position = centre + offset
	_aim_at(body.global_position + Vector3(0.0, 2.34, 0.0))
	root.player.set_lamp_enabled(true)
	await _capture("01_brood_knot_lamp_on")
	root.player.set_lamp_enabled(false)
	await _capture("02_brood_knot_lamp_off")


func _door_shot() -> void:
	var room: Dictionary = root.rooms.room_at_key(root._here_key)
	var chosen: Dictionary = {}
	for door in room.doors:
		if not bool(door.sealed) and not str(door.leads_to).is_empty():
			chosen = door
			break
	if chosen.is_empty():
		failures += 1
		printerr("[DREAM LINEAGE SHOT] no open child aperture")
		return
	var inside: Array = chosen.inside
	var aperture: Array = chosen.aperture
	var mouth := Vector3(
			(float(aperture[0]) + float(aperture[2])) * 0.5, 2.12,
			(float(aperture[1]) + float(aperture[3])) * 0.5)
	var room_rect: Array = room.rect
	var room_centre := Vector3(
			(float(room_rect[0]) + float(room_rect[2])) * 0.5, 0.0,
			(float(room_rect[1]) + float(room_rect[3])) * 0.5)
	var sill := Vector3(float(inside[0]), 0.0, float(inside[1]))
	var back := (room_centre - sill)
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3.BACK
	root.player.global_position = sill + back.normalized() * 1.15
	_aim_at(mouth)
	root.player.set_lamp_enabled(true)
	await _capture("03_birth_frame_into_child")


func _body_for(room: Dictionary) -> MeshInstance3D:
	var key := str(room.get("key", ""))
	for node in root.find_children("LineageBody", "MeshInstance3D", true, false):
		var body := node as MeshInstance3D
		if str(body.get_meta("room_key", "")) == key:
			return body
	return null


func _aim_at(target: Vector3) -> void:
	var from := root.player.global_position
	var flat := target - from
	flat.y = 0.0
	if flat.length() > 0.01:
		root.player.rotation.y = atan2(flat.x, -flat.z)
	root.player.camera.look_at(target, Vector3.UP)


func _capture(file_name: String) -> void:
	for _frame in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[DREAM LINEAGE SHOT] failed to save %s (%d)" %
				[path, error])
	else:
		var pose: Dictionary = root.player.lamp_pose()
		print("[DREAM LINEAGE SHOT] saved %s dir=%s splash=%s" %
				[path, str(pose.get("dir", Vector3.ZERO)),
				str(pose.get("splash", Vector3.ZERO))])
