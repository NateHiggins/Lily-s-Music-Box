extends Node
## Is the room actually visible once its light is on?
##
##     godot --path game res://tests/RoomLumaAudit.tscn
##
## MUST RUN WINDOWED. It reads pixels back off the viewport, and a headless run
## returns a black frame for every room, which reads as total failure.
##
## `LightingAudit` is the companion to this and answers a different question. It
## checks that every space has the fixtures the light map says it should and that
## the rig can assign them a shadow budget - COVERAGE. It never looks at a pixel.
## That is how twelve of twenty-eight rooms on F02 came to render as near-black
## frames, one of them 97.3% below luma 8, while the audit reported PASS across
## 127 spaces and had done for months.
##
## The measurement here is deliberately "lights on". A dark room the player has
## not lit yet is a mood decision and none of this test's business; a room that
## is still a void after somebody flips the switch is a defect. So every room's
## own switch is turned on before its frame is taken.

## Below this share of near-black pixels a lit room is not readable. Set from
## measurement, not taste: repaired rooms sit at 2-25%, and the broken ones sat
## at 64-97%. Anything above this is a room nobody can see the far wall of.
const MAX_NEAR_BLACK := 55.0
## Mean luma floor, as a second opinion for a room that is dim everywhere rather
## than black in one half.
const MIN_MEAN_LUMA := 9.0
const NEAR_BLACK_LEVEL := 8.0
const EYE := 1.62
const INSET := 0.6

## Spaces that are SUPPOSED to be dark, each with the reason. This list is how
## you declare intent; the test failing is how you find out you did not.
const INTENTIONALLY_DARK := {
	"2D": "the sealed apartment - gen_layout gives it no fixture at all",
	"5D": "sealed with 2D, same ruling",
}

## Rooms this audit found dark the day it was written, listed so the suite is
## green and any NEW dark room still fails. These are open defects, not
## exemptions - TASKS.md section L owns them. Delete a line when it is fixed;
## the test says so itself once a room is comfortably clear.
##
## Eighteen entries, but only three faults - the building repeats, so a single
## mistake shows up once per floor:
##
##   1. EVERY hall and EVERY utility room, on every floor, reports "no fixture".
##      ROOM_FIXTURE gives both of them one, so SwitchSystem cannot match those
##      room ids to their fixtures. They have only ever been lit by whatever was
##      burning in the next room.
##   2. C_BED2 is dark in every C apartment. C_BED1 is the same 13.8 m2 with the
##      same dome in the same relative spot and reads 20.1 against C_BED2's 2.9,
##      so this is not room size, not the fixture table and not the stack.
##   3. The B1 service rooms and ROOF_OPEN, which may simply want a decision
##      rather than a repair - a coal store is allowed to be dark.
const KNOWN_DARK := {
	# 1 - switch system finds no fixture for these room ids
	"F02_HALL": "8.0 mean", "F03_HALL": "7.5", "F04_HALL": "dark",
	"F05_HALL": "7.8", "F06_HALL": "7.5",
	"F02_UTILITY": "8.5", "F03_UTILITY": "dark", "F04_UTILITY": "8.7",
	"F05_UTILITY": "8.5", "F06_UTILITY": "dark",
	# 2 - lit, and still dark
	"F02_C_BED2": "2.9 mean, 93% near-black", "F04_C_BED2": "dark",
	"F05_C_BED2": "dark", "F06_C_BED2": "dark",
	"F02_A_BED": "7.2 mean, 65% near-black",
	"F03_C_MAIN": "9.0 mean", "F03_D_OFFICE": "8.5",
	# 3 - service spaces awaiting a ruling
	"B1_BOILER": "9.1", "B1_ELECTRICAL": "12.3", "B1_COAL": "8.4",
	"B1_STORAGE_CAGES": "dark", "ROOF_OPEN": "7.3",
}

var root: Node3D
var cam: Camera3D
var _rows: Array = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.0).timeout
	root.show_all_floors = true
	Conductor.infection = 0.0
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	cam = Camera3D.new()
	cam.fov = 72
	add_child(cam)
	cam.make_current()
	# Both the light budget and the moon fill follow this once it is set. Without
	# it the camera tours a building whose lighting is still arranged around a
	# player standing in the lobby.
	root.view_override = cam
	await _audit()


func _audit() -> void:
	var layout: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/building_layout.json"))
	var only_floor := OS.get_environment("WALK_FLOOR")
	for floor_data in layout["floors"]:
		var fid := str(floor_data["id"])
		if only_floor != "" and fid != only_floor:
			continue
		for room in floor_data["rooms"]:
			await _measure_room(room, float(floor_data["z"]))

	_rows.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	var failed: Array = []
	print("%-26s %8s %12s %s" % ["room", "mean", "near-black", "lit"])
	for r in _rows:
		var unreadable: bool = not bool(r[3]) and (
				float(r[2]) > MAX_NEAR_BLACK or float(r[1]) < MIN_MEAN_LUMA)
		var known: bool = KNOWN_DARK.has(String(r[0]))
		if unreadable and not known:
			failed.append(r[0])
		var tag := ""
		if unreadable:
			tag = "   <-- KNOWN, see TASKS L" if known else "   <-- UNREADABLE"
		elif known and float(r[2]) < MAX_NEAR_BLACK - 10.0 \
				and float(r[1]) > MIN_MEAN_LUMA + 3.0:
			# Fixing one and not deleting its line is how a guard rots - but only
			# say so once the room is CLEAR of the threshold, not sitting on it.
			# WSTOR measures 53.0% and 55.4% on consecutive runs against a 55%
			# limit; nagging about that would train everyone to ignore the line.
			tag = "   <-- reads fine now; delete it from KNOWN_DARK"
		print("%-26s %8.1f %11.1f%% %s%s" % [r[0], r[1], r[2],
				"yes" if r[4] else "no fixture", tag])

	print("\nROOM LUMA AUDIT: %d rooms, %d exempt, %s"
			% [_rows.size(), _rows.filter(func(r): return bool(r[3])).size(),
			   "PASS" if failed.is_empty() else "FAIL (%d unreadable: %s)"
					% [failed.size(), ", ".join(failed)]])
	get_tree().quit(0 if failed.is_empty() else 1)


func _measure_room(room: Dictionary, fz: float) -> void:
	var rect: Array = room["rect"]
	var x0 := float(rect[0])
	var y0 := float(rect[1])
	var x1 := float(rect[2])
	var y1 := float(rect[3])
	if (x1 - x0) * (y1 - y0) < 2.0:
		return  # closets and shafts are not rooms

	var room_id := str(room["id"])
	var unit := str(room.get("unit", ""))
	var exempt: bool = INTENTIONALLY_DARK.has(unit)

	# Flip the switch. toggle_room returns the state it moved to, so one more
	# call puts back a room that happened to start on.
	var lit := false
	if root.switch_system != null:
		lit = root.switch_system.toggle_room(room_id)
		if not lit:
			lit = root.switch_system.toggle_room(room_id)

	var ix: float = minf(INSET, (x1 - x0) * 0.45)
	var iy: float = minf(INSET, (y1 - y0) * 0.45)
	cam.global_position = GameBoot.b2g([x0 + ix, y0 + iy, fz + EYE])
	cam.look_at(GameBoot.b2g([x1 - ix, y1 - iy, fz + 1.0]))
	# The rig and the moon both ease toward their target, so a single frame
	# photographs the room mid-fade and reports it darker than it settles.
	for i in 26:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	# SHOT_DIR=<abs> keeps a frame per room. A number tells you a room failed;
	# only the picture tells you why, and "lit but still black" has several
	# very different causes that all produce the same statistic.
	var shot_dir := OS.get_environment("SHOT_DIR")
	if shot_dir != "":
		image.save_png("%s/luma_%s.png" % [shot_dir, room_id])
	var total := 0.0
	var dark := 0
	var count := 0
	# Every 4th pixel each way: 16x less work, same distribution.
	for py in range(0, image.get_height(), 4):
		for px in range(0, image.get_width(), 4):
			var c := image.get_pixel(px, py)
			var l: float = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			total += l
			if l < NEAR_BLACK_LEVEL:
				dark += 1
			count += 1
	_rows.append([room_id, total / maxf(1.0, count),
			100.0 * float(dark) / maxf(1.0, float(count)), exempt, lit])

	# Put the switch back. Leaving it on measures every later room with the
	# whole floor burning behind it, which flatters the end of the walk and
	# makes the order of `rooms` part of the result - the sealed 2D read 58.0
	# mean luma that way, brighter than any apartment anyone lives in.
	if lit and root.switch_system != null:
		root.switch_system.toggle_room(room_id)
