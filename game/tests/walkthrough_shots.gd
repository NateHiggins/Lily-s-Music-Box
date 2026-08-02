extends Node
## Walkthrough still driver (not shipped). Generates one frame per room from
## building_layout.json — two diagonals for rooms >= 20 m² — so the
## room-by-room punchlist walk can happen from rendered evidence instead of
## curated doc shots. Placement only: run with SCREENSHOT_TEST_CAMERA_LIGHT=1
## so unlit units are judgeable; lighting mood belongs to LightingAudit.
##   SHOT_DIR=<abs>  output directory (required in practice)
##   WALK_FLOOR=F02  restrict to one floor id (optional)

const EYE := 1.62
const INSET := 0.6

var root: Node3D
var cam: Camera3D
var _dir := ""


func _ready() -> void:
	# Same discipline as Screenshot.tscn: never inherit or write the real save.
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false
	_run()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	root.show_all_floors = true
	Conductor.infection = 0.0  # placement pass: no seam interference
	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)
	cam.make_current()
	if OS.get_environment("SCREENSHOT_TEST_CAMERA_LIGHT") == "1":
		var test_light := OmniLight3D.new()
		test_light.light_energy = 6.0
		test_light.omni_range = 10.0
		test_light.shadow_enabled = false
		cam.add_child(test_light)

	var only_floor := OS.get_environment("WALK_FLOOR")
	var layout: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/building_layout.json"))
	for floor_data in layout["floors"]:
		var fid := str(floor_data["id"])
		if only_floor != "" and fid != only_floor:
			continue
		var fz := float(floor_data["z"])
		for room in floor_data["rooms"]:
			await _shoot_room(room, floor_data["rooms"], fz)
	get_tree().quit(0)


## Bath and office rects are carved out of MAIN rects, so a corner-inset
## camera can stand inside the nested room and photograph the wrong walls
## (the first walk's "D_MAIN renders a bathroom" artifact). A corner is
## only usable if its eye stands in THIS room and no other.
func _corner_clear(pt: Array, room: Dictionary, rooms: Array) -> bool:
	for other in rooms:
		if other == room:
			continue
		var r: Array = other["rect"]
		if pt[0] > float(r[0]) and pt[0] < float(r[2]) \
				and pt[1] > float(r[1]) and pt[1] < float(r[3]):
			return false
	return true


func _shoot_room(room: Dictionary, rooms: Array, fz: float) -> void:
	var rect: Array = room["rect"]
	var x0 := float(rect[0])
	var y0 := float(rect[1])
	var x1 := float(rect[2])
	var y1 := float(rect[3])
	var area := (x1 - x0) * (y1 - y0)
	# Inset never past the room centre, however narrow the room is.
	var ix: float = min(INSET, (x1 - x0) * 0.45)
	var iy: float = min(INSET, (y1 - y0) * 0.45)
	var corners := [
		[x0 + ix, y0 + iy], [x1 - ix, y0 + iy],
		[x1 - ix, y1 - iy], [x0 + ix, y1 - iy],
	]
	# Diagonal pairs first, then adjacent fallbacks — first pair whose eye
	# corner is clear of every other room wins.
	var pairs := [[0, 2], [2, 0], [1, 3], [3, 1]]
	var takes: int = 2 if area >= 20.0 else 1
	var shot := 0
	for pair in pairs:
		if shot >= takes:
			break
		var eye_from: Array = corners[pair[0]]
		var eye_to: Array = corners[pair[1]]
		if not _corner_clear(eye_from, room, rooms):
			continue
		var pos: Vector3 = GameBoot.b2g([eye_from[0], eye_from[1], fz + EYE])
		var look: Vector3 = GameBoot.b2g([eye_to[0], eye_to[1], fz + 1.0])
		var suffix := "" if takes == 1 else ("_a" if shot == 0 else "_b")
		await _grab(pos, look, "wt_%s%s" % [str(room["id"]), suffix])
		shot += 1
	if shot == 0:
		# Every corner is inside some carved-out sub-room: shoot from the
		# room centre toward the farthest corner instead of skipping it.
		var cx := (x0 + x1) * 0.5
		var cy := (y0 + y1) * 0.5
		await _grab(GameBoot.b2g([cx, cy, fz + EYE]),
				GameBoot.b2g([x1 - ix, y1 - iy, fz + 1.0]),
				"wt_%s" % str(room["id"]))


func _grab(pos: Vector3, look: Vector3, shot_name: String) -> void:
	# The runtime light budget follows the player, so the walkthrough camera
	# must move that focus too or remote floors are intentionally dormant.
	if root.player:
		root.player.global_position = pos
	cam.global_position = pos
	cam.look_at(look)
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	img.save_png(path)
	print("saved ", path)
