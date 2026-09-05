class_name LobbyBulletinBoard
extends Node3D
## The building's own notice board, on the walk from the street door to
## the stairs.
##
## What was here before was a flat paper-material panel in a wooden frame,
## and five more blank slabs hung separately on the far side of the lobby.
## Nothing was written on any of them, so the board read as a rectangle and
## the loose slips read as boxes floating in space. They were the same
## object all along - a board and its overflow - and they are reassembled
## here.
##
## Everything pinned to it is a real notice with real text (see
## art/tools/build_lobby_notices.py): rent, heat, the exterminator, what
## you may not do in the halls. Two are long out of date and still up,
## which is the detail that says nobody is really minding this building.
##
## Notices are pinned at their top edge only, so they curl and hang
## crooked; a notice squared up on all four corners looks printed onto
## the wall rather than put there by a person.

const ATLAS := "res://assets/building/textures/notices/lobby_notices.png"
const WirelessNotice := preload("res://scripts/game/historical_radio_notice.gd")
const ControlArea := preload("res://scripts/props/prop_control_area.gd")
const COLS := 4
const ROWS := 2
## Which notice goes where, and how far past its date it is.
const PINNED := [
	{"cell": [0, 0], "at": Vector2(-0.255, 0.175), "tilt": -0.030},
	{"cell": [1, 0], "at": Vector2(0.010, 0.185), "tilt": 0.021},
	{"cell": [2, 0], "at": Vector2(0.268, 0.168), "tilt": -0.014},
	{"cell": [3, 0], "at": Vector2(-0.262, -0.135), "tilt": 0.034},
	{"cell": [0, 1], "at": Vector2(0.004, -0.128), "tilt": -0.023},
	{"cell": [1, 1], "at": Vector2(0.262, -0.142), "tilt": 0.017},
]
## The two that would not fit on the cork and went on the wall beside it.
const SPILLED := [
	{"cell": [2, 1], "at": Vector2(0.640, 0.095), "tilt": 0.052},
	{"cell": [3, 1], "at": Vector2(0.655, -0.185), "tilt": -0.041},
]

const NOTE_W := 0.205
const NOTE_H := 0.256

var _inspection_sheet: MeshInstance3D
var _inspection_sheet_rest_z := 0.0
var _inspection_tap: AudioStreamPlayer3D
var _inspection_tween: Tween
var _wireless_notice = WirelessNotice.new()
var _clock_reader := CampaignClock.new()
var _civil_time_provider: Callable


func _ready() -> void:
	name = "LobbyBulletinBoard"
	var oak := _finish(Color(0.24, 0.15, 0.09), 0.66, 0.0)
	var cork := _finish(Color(0.50, 0.355, 0.20), 0.93, 0.0)
	var brass := _finish(Color(0.46, 0.32, 0.11), 0.36, 0.86)
	var W := 0.92
	var H := 0.68

	_slab(Vector3(W - 0.09, H - 0.09, 0.016), Vector3(0, 0, 0.0), cork)
	for sy in [-1.0, 1.0]:
		_slab(Vector3(W, 0.050, 0.040),
				Vector3(0, sy * (H * 0.5 - 0.025), 0.006), oak)
	for sx in [-1.0, 1.0]:
		_slab(Vector3(0.050, H - 0.10, 0.040),
				Vector3(sx * (W * 0.5 - 0.025), 0, 0.006), oak)
	# brass legend on the head rail
	_slab(Vector3(0.26, 0.036, 0.005), Vector3(0, H * 0.5 - 0.025, 0.026),
			brass)
	var plate := Label3D.new()
	plate.text = "NOTICES"
	plate.font_size = 64
	plate.pixel_size = 0.00040
	plate.modulate = Color(0.94, 0.87, 0.63)
	plate.outline_size = 6
	plate.outline_modulate = Color(0.06, 0.045, 0.02, 0.9)
	plate.position = Vector3(0, H * 0.5 - 0.025, 0.031)
	add_child(plate)

	for spec in PINNED:
		_notice(spec, 0.024, brass)
	for spec in SPILLED:
		_notice(spec, 0.008, brass)
	_build_inspection_owner(Vector3(1.42, 0.78, 0.20))
	_build_wireless_notice()
	if not _civil_time_provider.is_valid():
		# A read-only handle onto the same durable campaign state used by the
		# world's clock. Inspection never advances or resamples that clock.
		_civil_time_provider = Callable(_clock_reader, "day_info")


func bind_civil_time_provider(provider: Callable) -> void:
	_civil_time_provider = provider


func _exit_tree() -> void:
	# The inspection tap can still be queued when a building is replaced.
	# Release this owner's decoder and matching cache entry at the same boundary.
	if _inspection_tween and _inspection_tween.is_valid():
		_inspection_tween.kill()
	_inspection_tween = null
	if _inspection_tap:
		var stream := _inspection_tap.stream
		_inspection_tap.stop()
		_inspection_tap.stream = null
		if stream != null:
			PropAudio.release_stream("tick", stream)
	_civil_time_provider = Callable()


func _build_wireless_notice() -> void:
	# A separate tenant hand-copy, alongside the old board rather than over
	# its existing notices. Both dated columns remain on this fixed paper.
	var sheet := MeshInstance3D.new()
	sheet.name = "WirelessLicenseNotice"
	var paper := QuadMesh.new()
	paper.size = Vector2(0.44, 0.50)
	sheet.mesh = paper
	sheet.material_override = _finish(Color(0.85, 0.79, 0.65), 0.94, 0.0)
	sheet.position = Vector3(-0.80, 0.0, 0.025)
	sheet.rotation.z = -0.018
	add_child(sheet)
	var text := Label3D.new()
	text.name = "WirelessLicenseText"
	text.text = _wireless_notice.printed_text()
	text.font = preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
	text.font_size = 32
	text.pixel_size = 0.00062
	text.outline_size = 0
	text.modulate = Color(0.12, 0.085, 0.055)
	text.shaded = true
	text.position.z = 0.004
	sheet.add_child(text)
	var pin := MeshInstance3D.new()
	var pin_mesh := CylinderMesh.new()
	pin_mesh.top_radius = 0.006
	pin_mesh.bottom_radius = 0.004
	pin_mesh.height = 0.009
	pin_mesh.radial_segments = 6
	pin.mesh = pin_mesh
	pin.material_override = _finish(Color(0.46, 0.32, 0.11), 0.36, 0.86)
	pin.rotation_degrees.x = 90.0
	pin.position = Vector3(0.0, 0.235, 0.009)
	sheet.add_child(pin)
	var area := ControlArea.new()
	area.name = "WirelessNoticeInspection"
	area.configure("wireless_notice")
	# The right paper edge overlaps the board's broad inspection rectangle;
	# keep this target slightly forward so the printed notice owns that ray.
	area.position = Vector3(-0.80, 0.0, 0.13)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.44, 0.50, 0.05)
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)


func control_prompt(control_id: String) -> String:
	return "Read wireless tuning notice" if control_id == "wireless_notice" else ""


func interact_control(control_id: String, _player: Node = null) -> Dictionary:
	if control_id != "wireless_notice":
		return {}
	if _inspection_tap:
		_inspection_tap.play()
	var info: Variant = _civil_time_provider.call() if _civil_time_provider.is_valid() else {}
	return _wireless_notice.copy_at(info if info is Dictionary else {})


## One pinned sheet. The pin is a real head above the paper, because the
## eye reads the pin before it reads the notice.
func _notice(spec: Dictionary, depth: float,
		brass: StandardMaterial3D) -> void:
	var cell: Array = spec["cell"]
	var at: Vector2 = spec["at"]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(ATLAS)
	mat.uv1_scale = Vector3(1.0 / COLS, 1.0 / ROWS, 1.0)
	mat.uv1_offset = Vector3(float(cell[0]) / COLS, float(cell[1]) / ROWS,
			0.0)
	mat.roughness = 0.95
	mat.texture_filter = \
			BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(NOTE_W, NOTE_H)
	sheet.mesh = quad
	sheet.material_override = mat
	sheet.position = Vector3(at.x, at.y, depth)
	sheet.rotation.z = float(spec["tilt"])
	add_child(sheet)
	if _inspection_sheet == null:
		_inspection_sheet = sheet
		_inspection_sheet_rest_z = depth
	var pin := MeshInstance3D.new()
	var head := CylinderMesh.new()
	head.top_radius = 0.007
	head.bottom_radius = 0.005
	head.height = 0.008
	head.radial_segments = 6
	pin.mesh = head
	pin.material_override = brass
	pin.rotation_degrees.x = 90
	pin.position = Vector3(at.x, at.y + NOTE_H * 0.5 - 0.014, depth + 0.006)
	add_child(pin)


func _build_inspection_owner(size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "NoticeBoardInspection"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)
	_inspection_tap = AudioStreamPlayer3D.new()
	_inspection_tap.bus = "Interaction"
	_inspection_tap.stream = PropAudio.get_stream("tick")
	_inspection_tap.volume_db = -19.0
	_inspection_tap.max_distance = 3.5
	add_child(_inspection_tap)


func interact_prompt() -> String:
	return "[E]  Inspect lobby notices"


func interact(_player: Node = null) -> Dictionary:
	_inspection_tap.pitch_scale = 1.12
	_inspection_tap.play()
	if _inspection_tween and _inspection_tween.is_valid():
		_inspection_tween.kill()
	if _inspection_sheet:
		_inspection_sheet.position.z = _inspection_sheet_rest_z
		_inspection_tween = create_tween()
		_inspection_tween.tween_property(_inspection_sheet, "position:z",
				_inspection_sheet_rest_z + 0.006, 0.08)
		_inspection_tween.tween_property(_inspection_sheet, "position:z",
				_inspection_sheet_rest_z, 0.18)
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("notice_board", {
		"notice_state": "SIX PINNED / TWO OVERFLOW",
		"board_state": "CORK DRY / OLD NOTICES RETAINED",
	})


func _finish(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _slab(size: Vector3, at: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	add_child(mi)
