class_name WayfindingSignagePass
extends Node3D
## Period brass wayfinding with modern life-safety information nested inside.
## Unit assignments come from case definitions and doors from live geometry;
## the sign system therefore cannot drift away from the playable layout.

const BRASS_TEXTURE := preload("res://assets/building/textures/signage/aged_brass_quadrants_v1.png")
## Engraved legends, baked into the metal by build_signage_plates.py.
## Unit numbers used to be Label3D floating in front of a brass
## rectangle, which is why they read as a debug overlay: no engraving,
## no depth, and a baseline answering to Godot rather than the plate.
const PLATE_ATLAS := preload("res://assets/building/textures/signage/engraved_plates.png")
const PLATE_COLS := 6
const PLATE_ROWS := 6
var _plate_index: Dictionary = {}


## One plate off the atlas, as its own small textured quad.
func _plate(parent: Node3D, legend: String, at: Vector3,
		size: Vector2) -> MeshInstance3D:
	if _plate_index.is_empty():
		var f := FileAccess.open("res://data/signage_plates.json",
				FileAccess.READ)
		if f:
			var doc: Dictionary = JSON.parse_string(f.get_as_text())
			_plate_index = doc.get("index", {})
	if not _plate_index.has(legend):
		return null
	var cell: Array = _plate_index[legend]
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PLATE_ATLAS
	mat.uv1_scale = Vector3(1.0 / PLATE_COLS, 1.0 / PLATE_ROWS, 1.0)
	mat.uv1_offset = Vector3(float(cell[0]) / PLATE_COLS,
			float(cell[1]) / PLATE_ROWS, 0.0)
	mat.roughness = 0.38
	mat.metallic = 0.65
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
const LEVELS := {"B1":-2.8, "F01":0.0, "F02":3.2, "F03":6.4,
	"F04":9.6, "F05":12.8, "F06":16.0, "ROOF":19.2}

var _brass: StandardMaterial3D
var _dark_brass: StandardMaterial3D
var _enamel: StandardMaterial3D
var _luminous: StandardMaterial3D
var _bell: AudioStreamPlayer3D
var _bell_button: MeshInstance3D
var _bell_button_rest := Vector3.ZERO
var _bell_tween: Tween
var _last_bell_state := "READY"
var apartment_numbers := 0
var floor_directories := 0
var fire_signs := 0
var spine_plates := 0
var stair_pairs := 0
var landing_plates := 0
var _numbered_doors := {}


func build(world: Node3D) -> Dictionary:
	name = "WayfindingSignage"
	_build_materials()
	_build_apartment_numbers(world)
	_build_floor_directories()
	_build_fire_directions()
	_build_front_directory()
	_build_service_spine_plate()
	_build_stair_pair_plates()
	_build_landing_plates()
	print("[WAYFINDING] %d brass unit numbers, %d directories, %d fire signs, "
			% [apartment_numbers, floor_directories, fire_signs]
			+ "%d spine plates, %d stair pairs, %d landing plates"
					% [spine_plates, stair_pairs, landing_plates])
	return {"numbers":apartment_numbers, "directories":floor_directories,
			"fire_signs":fire_signs, "spine_plates":spine_plates,
			"stair_pairs":stair_pairs, "landing_plates":landing_plates}


func _build_materials() -> void:
	_brass = _metal(Color(0.72, 0.49, 0.18), 0.76, 0.35)
	_brass.albedo_texture = _quadrant(Rect2(0, 0, 628, 628))
	_dark_brass = _metal(Color(0.30, 0.21, 0.11), 0.68, 0.52)
	_dark_brass.albedo_texture = _quadrant(Rect2(628, 628, 628, 628))
	_enamel = _metal(Color(0.055, 0.075, 0.068), 0.08, 0.46)
	_luminous = _metal(Color(0.76, 0.88, 0.58), 0.0, 0.7)
	_luminous.emission_enabled = true
	_luminous.emission = Color(0.22, 0.44, 0.14)
	_luminous.emission_energy_multiplier = 0.22


func _quadrant(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = BRASS_TEXTURE
	atlas.region = region
	return atlas


func _build_apartment_numbers(world: Node3D) -> void:
	var used := {}
	for case_id in RealityCases.definitions:
		var definition := RealityCases.definition(case_id)
		var unit: String = definition.get("unit", "")
		if unit.is_empty() or used.has(unit):
			continue
		used[unit] = true
		var controller: ApartmentRealityController = world.reality_controllers.get(case_id)
		if controller == null:
			continue
		var door := _nearest_apartment_door(controller)
		if door == null:
			continue
		_add_unit_plaque(door, unit)
		_numbered_doors[door] = unit
		door.set_meta("apartment_unit", unit)
		apartment_numbers += 1


func _nearest_apartment_door(controller: ApartmentRealityController) -> DoorProp:
	var center := (controller.room_min + controller.room_max) * 0.5
	var nearest: DoorProp
	var best := 999.0
	for candidate in get_tree().get_nodes_in_group("apartment_doors"):
		if not candidate is DoorProp:
			continue
		var door := candidate as DoorProp
		if _numbered_doors.has(door):
			continue
		if absf(door.global_position.y - center.y) > 1.6:
			continue
		var distance := door.global_position.distance_to(center)
		if distance < best:
			best = distance
			nearest = door
	return nearest


func _add_unit_plaque(door: DoorProp, unit: String) -> void:
	var root := Node3D.new()
	root.name = "BrassApartmentNumber_" + unit
	root.position = Vector3(door.width + 0.13, 1.48, 0.0)
	door.add_child(root)
	_box(root, Vector3(0.19, 0.13, 0.018), Vector3.ZERO, _dark_brass)
	_add_screws(root, 0.075, 0.045)
	# The number IS the plate now, not a caption in front of one.
	if _plate(root, unit, Vector3(0, 0, 0.0102),
			Vector2(0.155, 0.105)) == null:
		_label(root, unit, Vector3(0, 0, 0.013), 46, 0.00125,
				Color(0.94, 0.74, 0.30), true)
	# Smoke-level responder marking: intentionally newer and less elegant.
	var low := Node3D.new()
	low.position = Vector3(door.width + 0.065, 0.19, 0.0)
	door.add_child(low)
	_box(low, Vector3(0.09, 0.065, 0.008), Vector3.ZERO, _luminous)
	_label(low, unit, Vector3(0, 0, 0.008), 25, 0.0010,
			Color(0.05, 0.09, 0.035), true)
	# Four screw heads and a backplate used to remain five separate shadow
	# submissions on every entry door. The typed face keeps its own atlas
	# material; the fixed brass behind it is one surface.
	StaticMeshBatcher.merge(root)


func _build_floor_directories() -> void:
	var residents := _resident_rows()
	for floor_index in range(1, 7):
		var fid := "F%02d" % floor_index
		var rows: Array = residents.get(str(floor_index), [])
		var panel := Node3D.new()
		panel.name = "FloorDirectory_" + fid
		panel.position = GameBoot.b2g([-4.94, 5.56, LEVELS[fid] + 1.42])
		panel.rotation.y = PI
		add_child(panel)
		_directory_panel(panel, "FLOOR %d" % floor_index, rows, false)
		floor_directories += 1
	# Cellar directory belongs to workers and firefighters, not tenants.
	var cellar := Node3D.new()
	cellar.name = "FloorDirectory_B1"
	cellar.position = GameBoot.b2g([-4.94, 5.56, LEVELS.B1 + 1.42])
	cellar.rotation.y = PI
	add_child(cellar)
	_directory_panel(cellar, "CELLAR", [["BOILER", "EAST"],
			["LAUNDRY", "WEST"], ["MAINT.", "LOBBY"]], false)
	floor_directories += 1


func _resident_rows() -> Dictionary:
	var rows := {}
	for case_id in RealityCases.definitions:
		var d := RealityCases.definition(case_id)
		var unit: String = d.get("unit", "")
		if unit.is_empty():
			continue
		var floor := unit.left(1)
		if not rows.has(floor): rows[floor] = []
		rows[floor].append([unit, str(d.get("resident", "OCCUPIED")).to_upper()])
	for floor in rows:
		rows[floor].sort_custom(func(a, b): return a[0] < b[0])
	return rows


func _directory_panel(root: Node3D, title: String, rows: Array,
		with_buttons: bool) -> void:
	var height := 0.23 + rows.size() * 0.072
	_box(root, Vector3(0.66, height, 0.035), Vector3.ZERO, _dark_brass)
	_box(root, Vector3(0.57, height - 0.10, 0.012), Vector3(0, -0.015, 0.026), _enamel)
	_label(root, title, Vector3(0, height * 0.5 - 0.052, 0.038), 24,
			0.00115, Color(0.91, 0.73, 0.37))
	var top := height * 0.5 - 0.125
	for index in rows.size():
		var row: Array = rows[index]
		var y := top - index * 0.072
		_box(root, Vector3(0.49, 0.052, 0.008), Vector3(-0.018, y, 0.038),
				_metal(Color(0.74, 0.70, 0.58), 0.0, 0.82))
		_label(root, "%s   %s" % [row[0], row[1]], Vector3(-0.23, y, 0.044),
				15, 0.00088, Color(0.10, 0.085, 0.06), false,
				HORIZONTAL_ALIGNMENT_LEFT)
		if with_buttons:
			var button := _cylinder(root, 0.015, 0.018,
					Vector3(0.275, y, 0.052), _brass)
			# One assembly-level interaction owns the call circuit. Keep one
			# actual button separate as its physical response instead of adding
			# eighteen duplicate gameplay targets to the directory.
			if index == rows.size() / 2:
				_bell_button = button
				_bell_button_rest = button.position
	_add_screws(root, 0.295, height * 0.5 - 0.025)


func _build_fire_directions() -> void:
	for fid in LEVELS:
		var level: float = LEVELS[fid]
		var sign := Node3D.new()
		sign.name = "FireDirection_" + fid
		sign.position = GameBoot.b2g([4.98, 2.92, level + 1.45])
		sign.rotation.y = -PI * 0.5
		add_child(sign)
		_box(sign, Vector3(0.62, 0.34, 0.022), Vector3.ZERO, _dark_brass)
		_box(sign, Vector3(0.55, 0.27, 0.010), Vector3(0, 0, 0.017), _enamel)
		var floor_text := "ROOF LANDING" if fid == "ROOF" else \
				("CELLAR" if fid == "B1" else "FLOOR %d" % int(fid.right(2)))
		_label(sign, floor_text, Vector3(0, 0.105, 0.031), 18, 0.0010,
				Color(0.90, 0.74, 0.40))
		# K2-D: THE ARROW WAS POINTING AWAY FROM THE ONLY ROUTE.
		#
		# This plate hangs at b(4.98, 2.92) and its readable face looks WEST, so
		# a reader stands in the corridor facing EAST and their LEFT is NORTH.
		# It said "←", i.e. north. Measured at body height on every residential
		# floor, THE EAST CORRIDOR'S WEST WALL IS UNBROKEN FROM y +4.4 TO
		# y -6.8 AND OPENS ONLY AT y -9.2..-7.2 -- six open samples per floor,
		# all south of this plate, none north of it. The stair could only ever
		# be reached by going the other way.
		#
		# A reader facing east has SOUTH on their right, so the glyph is "→".
		# This is a correction to a sign that was already here, not a new claim.
		_label(sign, "FIRE EXIT — STAIRS  →", Vector3(0, 0.025, 0.031), 21,
				0.0010, Color(0.86, 0.93, 0.72))
		# K2-E: "STREET LEVEL ↓" IS FALSE ON FLOOR 1, and K2-D reported it.
		# Street level IS floor 1, and a body walked out of the F01 stair
		# landing in six directions without descending a single centimetre —
		# lowest z reached +0.00 every time. Pointing a man downstairs to the
		# street from the street is the same class of error as the arrow this
		# plate carried before K2-D. On every floor above it the line is true
		# and is left alone.
		var street := "STREET LEVEL ↓" if fid != "F01" else "STREET LEVEL — THIS FLOOR"
		_label(sign, street, Vector3(0, -0.055, 0.031), 17,
				0.0010, Color(0.86, 0.93, 0.72))
		_label(sign, "DO NOT USE ELEVATOR", Vector3(0, -0.115, 0.031), 13,
				0.0009, Color(0.76, 0.30, 0.24))
		fire_signs += 1


## K2-A: the plate this building was missing.
##
## THE MEASUREMENT THAT ASKED FOR IT. The east wall of the ground floor is the
## Orison's entire working spine, in order, from the front wall northward: the
## lobby clock, the post tray, the mail chute, the porter's board, the service
## dumbwaiter, the signal register, the tour-key guard, the night register and
## the watchman's detector at the head of it. Standing just inside the front
## door and looking east, ALL of it is on one clear 7.5 m axis -- the sightline
## opens at x +3.00 and holds to x +5.00.
##
## And a fresh player has no reason on earth to turn that way. The opening
## objective names "the watchman's detector", an object they have never seen;
## of 831 walkable ground-floor places the detector's face is visible from 112,
## and not one of those is in the entrance hall. On the direct walk from door to
## desk the first clear sight of it comes at 2.60 m -- barely ahead of the
## player's own 2.10 m prompt ray. The building was not hiding the desk. It
## simply never said which way it was.
##
## SO IT SAYS SO, THE WAY A 1912 BUILDING SAYS THINGS. This is the same
## brass-and-enamel plate as the fire directions twenty lines above, in the same
## vocabulary, hung on a real measured wall: the south face of the entrance
## hall's north wall at y -6.84, which is dead ahead of anyone who has just come
## through the front door. It names what is down there in the order they will
## pass it and points right. It is a sign. It knows nothing, owns nothing,
## mutates nothing, and it is as true at the end of the game as at the start.
func _build_service_spine_plate() -> void:
	var plate := Node3D.new()
	plate.name = "ServiceSpineDirection"
	# MEASURED, AND THE FIRST GUESS WAS WRONG. The entrance hall's north wall at
	# y -6.84 is not continuous: it is solid across x 0.8..1.2 and x 2.4..3.2 and
	# OPEN between, because the elevator stands in the gap. A plate at x 2.20 --
	# where this went first -- hung in the lift doorway with nothing behind it.
	# The pier at x 2.8 carries it: solid wall, 4.05 m from the door, and inside
	# the forward view of anyone who has just come through it.
	#
	# The face is at y -6.84 and the plate stands 60 mm proud of it, facing south
	# into the hall. rotation.y 0 puts local +z on building -y, which is south --
	# the same convention the fire directions use to face west with -PI/2.
	plate.position = GameBoot.b2g([2.80, -6.90, 1.62])
	add_child(plate)
	# THE FIELD IS PAINTED BOARD, AND BOTH EARLIER VERSIONS ARE WHY.
	#
	# Built in the fire signs' vitreous `_enamel` -- Color(0.055, 0.075, 0.068)
	# at roughness 0.08 -- it photographed against warm lobby plaster as a black
	# glossy rectangle and read as a flat screen hung on a 1912 wall. Rebuilt in
	# `_brass`, it went darker still: this pier is a dim corner, and a metallic
	# material with nothing to reflect renders black, taking the engraved
	# letters with it. Enamel is right for a fire direction in a lit stair and
	# brass is right for a unit number at arm's length; a lobby directory read
	# from four metres in low light is a PAINTED BOARD with pale lettering, and
	# roughness is what stops it looking like a screen.
	var board := _metal(Color(0.085, 0.062, 0.048), 0.62, 0.04)
	_box(plate, Vector3(0.64, 0.30, 0.020), Vector3.ZERO, _dark_brass)
	_box(plate, Vector3(0.57, 0.23, 0.008), Vector3(0, 0, 0.014), board)
	_label(plate, "NIGHT WATCHMAN", Vector3(0, 0.078, 0.020), 19, 0.0010,
			Color(0.92, 0.78, 0.44))
	_label(plate, "POST AND REGISTER  →", Vector3(0, 0.000, 0.020), 23, 0.0010,
			Color(0.94, 0.92, 0.84))
	_label(plate, "PORTER · MAILS · SERVICE LIFT", Vector3(0, -0.076, 0.020),
			14, 0.0009, Color(0.80, 0.76, 0.66))
	spine_plates += 1


## K2-D: the plate's pair, on the other wall of the same corridor.
##
## WHY A SECOND ONE AT ALL. The fire plate above hangs at the corridor's NORTH
## end, on its EAST wall, and is read facing east. The night watchman's desk is
## 5.19 m south of it and FACES that same east wall -- so from the pose where a
## man takes his first report, the only stair sign in the building is edge-on,
## behind his shoulder, and 88.5 degrees off his line of sight. It was correct
## for one approach and invisible from the one that matters.
##
## A corridor with a desk in the middle of it carries the direction on BOTH
## walls. This is that pair: the corridor's WEST wall, directly opposite the
## register, facing EAST so it is read head-on the moment a man turns round
## from the desk. It is 1.29 m from the acceptance pose.
##
## A reader facing WEST has SOUTH on their left, and south is where the corridor
## opens -- so this one carries "←" while its partner across the corridor
## carries "→". Both point at the same opening from opposite sides, which is
## what a paired plate IS.
##
## It is permanent building fabric: no state, no script, no save key, and as
## true on the last night of the game as on the first.
func _build_stair_pair_plates() -> void:
	for fid in LEVELS:
		if fid in ["B1", "ROOF"]:
			continue
		var level: float = LEVELS[fid]
		var plate := Node3D.new()
		plate.name = "StairDirectionPair_" + fid
		# The corridor's west wall face is at x 3.52; the plate stands proud.
		plate.position = GameBoot.b2g([3.56, -2.10, level + 1.55])
		# +PI/2 puts the readable face on building +x, i.e. looking EAST at a
		# man who has turned round from the desk. Its partner uses -PI/2.
		plate.rotation.y = PI * 0.5
		add_child(plate)
		# PAINTED BOARD, NOT VITREOUS ENAMEL, and K2-A already paid for this
		# lesson on this exact wall: `_enamel` is Color(0.055, 0.075, 0.068) at
		# roughness 0.08, and against warm lobby plaster it photographs as a
		# black glossy rectangle that reads as a flat screen hung on a 1912
		# wall. Enamel is right for a fire direction in a lit stair; a corridor
		# plate read at conversational distance in low light is a painted board,
		# and roughness is what stops it looking like a screen.
		var board := _metal(Color(0.085, 0.062, 0.048), 0.62, 0.04)
		_box(plate, Vector3(0.64, 0.30, 0.022), Vector3.ZERO, _dark_brass)
		_box(plate, Vector3(0.57, 0.23, 0.010), Vector3(0, 0, 0.017), board)
		var floor_text := "FLOOR %d" % int(fid.right(2))
		_label(plate, floor_text, Vector3(0, 0.078, 0.031), 19, 0.0010,
				Color(0.92, 0.78, 0.44))
		_label(plate, "←  STAIRS", Vector3(0, -0.004, 0.031), 32, 0.0010,
				Color(0.94, 0.92, 0.84))
		_label(plate, "ALL FLOORS", Vector3(0, -0.082, 0.031), 14, 0.0009,
				Color(0.80, 0.76, 0.66))
		stair_pairs += 1


func _build_front_directory() -> void:
	var rows: Array = []
	var resident_rows := _resident_rows()
	for floor in resident_rows:
		rows.append_array(resident_rows[floor])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var panel := Node3D.new()
	panel.name = "FrontResidentDirectoryAndBuzzer"
	panel.position = GameBoot.b2g([-1.13, -9.91, 1.38])
	add_child(panel)
	panel.scale = Vector3(0.82, 0.82, 0.82)
	_directory_panel(panel, "RESIDENTS — RING ONCE", rows, true)
	var area := Area3D.new()
	area.name = "DirectoryDoorbellArea"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.68, 1.60, 0.10)
	shape_node.shape = shape
	area.add_child(shape_node)
	panel.add_child(area)
	_bell = AudioStreamPlayer3D.new()
	_bell.bus = "Navigation"
	_bell.stream = PropAudio.get_stream("bell")
	_bell.volume_db = -16.0
	_bell.max_distance = 18.0
	panel.add_child(_bell)


func interact_area(area: Area3D) -> Dictionary:
	if area.name != "DirectoryDoorbellArea" or _bell == null:
		return {}
	_press_directory_button()
	if not _bell.playing:
		_bell.pitch_scale = 0.88
		_bell.play()
		_last_bell_state = "SOUNDED"
	else:
		_last_bell_state = "STILL RINGING"
	return service_wire_card()


func interact_prompt() -> String:
	return "[E]  Ring directory buzzer"


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("buzzer", {
		"button_state": "RETURNING" if _bell_tween \
				and _bell_tween.is_running() else "READY",
		"bell_state": _last_bell_state,
	})


func _press_directory_button() -> void:
	if _bell_button == null:
		return
	if _bell_tween and _bell_tween.is_valid():
		_bell_tween.kill()
	_bell_button.position = _bell_button_rest
	_bell_tween = create_tween()
	_bell_tween.tween_property(_bell_button, "position:z",
			_bell_button_rest.z - 0.009, 0.055)
	_bell_tween.tween_property(_bell_button, "position:z",
			_bell_button_rest.z, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## --- K2-E ------------------------------------------------------------------
## This lives BELOW `_build_front_directory` on purpose. K2-D's focused suite
## proves its own builder owns no player by scanning the source between
## `_build_stair_pair_plates` and `_build_front_directory`; dropping this
## function into that gap tripped it on a COMMENT that says "the player
## arriving from the entrance hall". K2-D's builder was untouched -- its anchor
## was not -- and the right answer is to move the new code out of an existing
## test's window rather than widen the window. Second time this exact trap has
## been paid for in this series; see the ledger notes.

## K2-E: the plate that tells a landing which way is up.
##
## MEASURED, BY WALKING, NOT BY READING THE MESH. From the F01 landing at
## b(0.00, -2.60) a body under production collision is BLOCKED STRAIGHT AHEAD
## at y -1.88 by the well guard, and must go round it. Going west then north
## climbs 0.15 -> 1.60 to the half-landing; crossing east and walking south then
## climbs 1.60 -> 2.90 toward F02's floor at 3.20. That is the whole route:
## WEST ARM UP, TURN, EAST ARM UP.
##
## DOWN IS DELIBERATELY UNCLAIMED ON FLOOR ONE. Six walks out of that landing
## all ended at +0.00, but repeating them from 0.8 m further south sends one
## long diagonal into the open well and down to -1.40 — mid-well, not the cellar
## floor at -2.80. I could not separate "a flight down" from "a body falling
## into an open well" robustly, so floor one's plate asserts only what is
## certain: street level IS this floor, and up is 2-6. Floors above it carry a
## DOWN line because the flight this suite walks IS their way down.
##
## WHY A PLATE AND NOT A LIGHT OR AN ARROW IN THE AIR. The flight itself is
## plainly visible from the choice point — the frame shows it climbing away to
## the left past the balustrade. What the stair cannot say for itself is WHICH
## FLOOR it arrives at, and that is the only thing a man carrying a work order
## for 2A actually needs. So the plate names floors and nothing else.
##
## The glyphs are ↑ and ↓, which have no handedness. K2-D lost a pass to a
## left/right arrow whose meaning depended on which way the reader faced; a
## vertical arrow cannot be inverted by standing somewhere else.
##
## Hung on the south face of the well guard the arriving player walks into, so
## it is read head-on from the choice point without turning.
func _build_landing_plates() -> void:
	for fid in LEVELS:
		if fid in ["B1", "ROOF"]:
			continue
		var level: float = LEVELS[fid]
		var number := int(fid.right(2))
		var plate := Node3D.new()
		plate.name = "LandingPlate_" + fid
		# The guard the walk stopped against is at y -1.88; the plate stands
		# just south of it, facing the arriving player. rotation.y 0 puts the
		# readable face on building -y, which is south.
		# MEASURED HEIGHT, and the first guess was 0.55 m too high. Casting
		# north across the guard from the arrival shows it SOLID from z 0.4 to
		# 1.0 across x -1.5..+1.5 and OPEN above 1.2: a dwarf wall with an open
		# balustrade over it. A plate at 1.30 hung in the air above the rail,
		# which is what the first frame showed. It goes on the solid panel.
		# x -0.80, not 0.00: dead centre puts the plate behind the device the
		# player carries in the lower middle of the frame, and off-centre it
		# also sits on the half of the guard nearer the arm that actually
		# climbs. z 0.95 is the top of the solid band, just under the handrail,
		# which is where a plate gets screwed to a closed string.
		# x -0.35, MEASURED: at -0.80 the plate stood 51 degrees off the
		# direction of travel, outside a 70 degree frustum's +-35, so a man
		# walking in never had it on screen. 0.65 m of approach allows
		# 0.65*tan(35) = 0.46 m of offset; -0.35 keeps it in frame and still
		# clear of the device carried in the lower right.
		plate.position = GameBoot.b2g([-0.35, -1.95, level + 0.95])
		add_child(plate)
		_box(plate, Vector3(0.62, 0.30, 0.020), Vector3.ZERO, _dark_brass)
		var board := _metal(Color(0.085, 0.062, 0.048), 0.62, 0.04)
		_box(plate, Vector3(0.55, 0.23, 0.008), Vector3(0, 0, 0.014), board)
		var head := "FLOOR 1 — STREET" if number == 1 else "FLOOR %d" % number
		_label(plate, head, Vector3(0, 0.082, 0.026), 16, 0.0010,
				Color(0.92, 0.78, 0.44))

		# K2-F: WHICH WAY THE APARTMENTS LIE.
		#
		# A floor number is not an apartment. Measured at the real F02 stair
		# arrival, b(2.50, -2.26): the 2A door is 7.95 m away and BLOCKED, its
		# brass number is blocked, and so is every other unit plate, the floor
		# directory, the fire plate and K2-D's corridor pair. THE ONLY CLEAR CUE
		# IS THIS PLATE, and until now it named the floor and nothing else.
		#
		# The sides are read off the doors this pass has already numbered, so
		# the line cannot drift from the building: `_numbered_doors` is filled
		# by `_build_apartment_numbers`, which runs first. Measured recurrence —
		# A and B west, C and D east, every door at x +-5.33, on all six floors
		# — is a fact this derives rather than a rule it asserts.
		#
		# HANDEDNESS, derived and then tested. This plate faces SOUTH, so its
		# reader faces NORTH; a north-facing reader's right is building +x,
		# which is EAST. West units therefore take the left glyph and east units
		# the right. The focused suite asserts that against the doors' actual x
		# rather than trusting this comment.
		var west: Array[String] = []
		var east: Array[String] = []
		for door in _numbered_doors:
			if not is_instance_valid(door):
				continue
			if absf(door.global_position.y - level) > 1.2:
				continue
			if door.global_position.x < 0.0:
				west.append(str(_numbered_doors[door]))
			else:
				east.append(str(_numbered_doors[door]))
		west.sort()
		east.sort()
		# TWO LABELS, ONE PER SIDE, and the first version was one. A single
		# line reading "←  2A  2B        2C  →" is unreadable to a parser and
		# only just readable to a person: everything after the first arrow looks
		# like it belongs to it, and the focused suite duly reported seven east
		# units as pointing west. Each side now carries its own glyph beside its
		# own units, which is unambiguous on the plate and unambiguous in a test.
		if not west.is_empty():
			_label(plate, "←  " + "  ".join(PackedStringArray(west)),
					Vector3(-0.135, 0.008, 0.026), 20, 0.0010,
					Color(0.94, 0.92, 0.84))
		if not east.is_empty():
			_label(plate, "  ".join(PackedStringArray(east)) + "  →",
					Vector3(0.135, 0.008, 0.026), 20, 0.0010,
					Color(0.94, 0.92, 0.84))

		# The vertical line, which has no handedness to get wrong.
		var vertical := ""
		if number < 6:
			vertical = "↑  2 — 6" if number == 1 else "↑  %d — 6" % (number + 1)
		else:
			vertical = "TOP FLOOR"
		if number > 1:
			vertical += "        "
			vertical += "↓  STREET" if number == 2 					else "↓  %d — STREET" % (number - 1)
		_label(plate, vertical, Vector3(0, -0.078, 0.026), 15, 0.0009,
				Color(0.80, 0.76, 0.66))
		landing_plates += 1


func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = at
	node.rotation_degrees.x = 90
	node.material_override = material
	parent.add_child(node)
	return node


func _add_screws(root: Node3D, x: float, y: float) -> void:
	for corner in [Vector2(-x, -y), Vector2(x, -y), Vector2(-x, y), Vector2(x, y)]:
		_cylinder(root, 0.009, 0.009, Vector3(corner.x, corner.y, 0.032), _brass)


func _label(parent: Node3D, text: String, at: Vector3, font_size: int,
		pixel_size: float, color: Color, double_sided := false,
		alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 1
	label.outline_modulate = Color(0.025, 0.02, 0.012, 0.8)
	label.horizontal_alignment = alignment
	label.double_sided = double_sided
	parent.add_child(label)
	return label
