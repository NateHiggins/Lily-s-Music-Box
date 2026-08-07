class_name FridgeProp
extends FunctionalProp
## Kitchen refrigerator. Normal: compressor hum cycling on/off on a slow
## thermostat. Synced: compressor relay clicks land on motif events.

var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _running := true
## The door is a hinge, not a face: everything that swings hangs off
## `_door`, so both the player's hand and the poltergeist move one node.
var _door: Node3D
var _lamp: OmniLight3D
var _open := false
var _possessed := false


## Which flat this is, so the contents can be somebody's rather than
## generic, and whether it is one of the four 1927 monitor-tops.
var unit := ""
var monitor_top := false

## What is in the building's refrigerators.
##
## Brands are invented, because a real one drags a real world in with it
## and this building is not in that world. They are the sort of name a
## Queens grocery carried between the wars and never stopped carrying:
## a family surname, a virtue, or a place.
const LARDER := {
	# unit: [ [label, tint, wide, tall, shelf] ... ]
	"1A": [["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["HOLLOWAY'S", Color(0.42, 0.16, 0.14), 0.07, 0.11, 1],
		   ["eggs", Color(0.86, 0.82, 0.70), 0.16, 0.06, 1],
		   ["wrapped", Color(0.80, 0.78, 0.66), 0.13, 0.07, 0]],
	"1D": [["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["one lemon", Color(0.86, 0.78, 0.24), 0.05, 0.05, 0]],
	"2A": [["CROWN & VALE", Color(0.88, 0.80, 0.36), 0.10, 0.07, 2],
		   ["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["jars", Color(0.32, 0.44, 0.26), 0.06, 0.13, 1],
		   ["jars", Color(0.36, 0.24, 0.18), 0.06, 0.12, 1]],
	"2B": [["KESSLER'S PICKLES", Color(0.46, 0.52, 0.24), 0.08, 0.17, 1],
		   ["ASTORIA CREAM", Color(0.90, 0.87, 0.78), 0.06, 0.10, 2],
		   ["wrapped", Color(0.78, 0.76, 0.64), 0.14, 0.08, 0]],
	"2C": [["PEERLESS LAGER", Color(0.30, 0.42, 0.22), 0.06, 0.19, 1],
		   ["PEERLESS LAGER", Color(0.30, 0.42, 0.22), 0.06, 0.19, 1],
		   ["carton", Color(0.84, 0.72, 0.48), 0.15, 0.09, 0]],
	"3A": [["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["BELL BROS.", Color(0.34, 0.30, 0.52), 0.08, 0.12, 1]],
	"3B": [["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.05, 0.20, 2],
		   ["wrapped", Color(0.80, 0.78, 0.66), 0.12, 0.07, 1]],
	"3D": [["ASTORIA CREAM", Color(0.90, 0.87, 0.78), 0.06, 0.10, 2],
		   ["HOLLOWAY'S", Color(0.42, 0.16, 0.14), 0.07, 0.11, 1],
		   ["eggs", Color(0.86, 0.82, 0.70), 0.16, 0.06, 0]],
	"4A": [["furred", Color(0.44, 0.48, 0.36), 0.09, 0.09, 1],
		   ["furred", Color(0.40, 0.44, 0.34), 0.07, 0.08, 0]],
	"4B": [["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["PEERLESS LAGER", Color(0.30, 0.42, 0.22), 0.06, 0.19, 1],
		   ["wrapped", Color(0.80, 0.78, 0.66), 0.13, 0.07, 0]],
	"4C": [["WREN'S BUTTER", Color(0.88, 0.78, 0.34), 0.09, 0.06, 2],
		   ["PEERLESS LAGER", Color(0.30, 0.42, 0.22), 0.06, 0.19, 1],
		   ["carton", Color(0.84, 0.72, 0.48), 0.14, 0.09, 1],
		   ["jars", Color(0.36, 0.24, 0.18), 0.06, 0.12, 0]],
	"4D": [["carton", Color(0.84, 0.72, 0.48), 0.15, 0.09, 1]],
	"5A": [["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["CROWN & VALE", Color(0.88, 0.80, 0.36), 0.10, 0.07, 1]],
	"5B": [["PEERLESS LAGER", Color(0.30, 0.42, 0.22), 0.06, 0.19, 2],
		   ["PEERLESS LAGER", Color(0.30, 0.42, 0.22), 0.06, 0.19, 2],
		   ["carton", Color(0.84, 0.72, 0.48), 0.15, 0.09, 0]],
	"5C": [["jars", Color(0.32, 0.44, 0.26), 0.06, 0.13, 2],
		   ["jars", Color(0.52, 0.30, 0.16), 0.06, 0.13, 2],
		   ["ASTORIA CREAM", Color(0.90, 0.87, 0.78), 0.06, 0.10, 1],
		   ["wrapped", Color(0.78, 0.76, 0.64), 0.13, 0.08, 0]],
	"6A": [["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 2],
		   ["eggs", Color(0.86, 0.82, 0.70), 0.16, 0.06, 1]],
	"6B": [["HOLLOWAY'S", Color(0.42, 0.16, 0.14), 0.07, 0.11, 2],
		   ["wrapped", Color(0.80, 0.78, 0.66), 0.12, 0.07, 1],
		   ["furred", Color(0.44, 0.48, 0.36), 0.08, 0.08, 0]],
	"6C": [["KESSLER'S PICKLES", Color(0.46, 0.52, 0.24), 0.08, 0.17, 2],
		   ["KESSLER'S PICKLES", Color(0.46, 0.52, 0.24), 0.08, 0.17, 2],
		   ["MERIDIAN MILK", Color(0.92, 0.91, 0.86), 0.09, 0.24, 1]],
}
## Shelf heights inside the liner, low to high.
const SHELF_Z := [0.54, 0.80, 1.06]

## The label sheet, built by art/tools/build_larder_labels.py. Cell order
## is row-major across the 3x3 atlas and must match NAMES in that script.
const LABEL_SHEET := "res://assets/building/textures/larder/larder_labels.png"
const LABEL_CELL := {
	"MERIDIAN MILK": 0, "HOLLOWAY'S": 1, "CROWN & VALE": 2,
	"PEERLESS LAGER": 3, "KESSLER'S PICKLES": 4, "ASTORIA CREAM": 5,
	"QUELL TONIC": 6, "WREN'S BUTTER": 7, "BELL BROS.": 8,
}


func _build_visual() -> void:
	## The CABINET is Blender's (asm_fridge50 / asm_fridge_monitor); this
	## builds only what moves, lights, or can be eaten. Building the body
	## here too put two refrigerators in the same square metre.
	var body := Color(0.88, 0.87, 0.84)
	var face_y := 0.30 if monitor_top else 0.33
	var top_z := 1.27 if monitor_top else 1.46
	var bot_z := 0.28 if monitor_top else 0.16
	var half_w := 0.25 if monitor_top else 0.29

	# The lamp lives in the cabinet, dark until the door is off its seal.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.96, 0.86)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 1.5
	_lamp.position = Vector3(0, (top_z + bot_z) * 0.5, 0.02)
	add_child(_lamp)

	_build_contents(half_w)

	# Hinge on the LEFT stile, so the door swings away from the handle
	# the way a real one does.
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(-half_w - 0.02, 0.0, face_y)
	add_child(_door)
	var mid := (top_z + bot_z) * 0.5
	var h := top_z - bot_z
	var swinging: Array[MeshInstance3D] = [
		make_box(Vector3(half_w * 2.0 + 0.04, h, 0.028),
				Vector3(0, mid, face_y + 0.014), body),
		make_box(Vector3(half_w * 2.0 - 0.04, h - 0.08, 0.012),
				Vector3(0, mid, face_y + 0.033), body),
		make_cyl(0.016, 0.016, h * 0.32,
				Vector3(half_w - 0.05, mid + 0.04, face_y + 0.075),
				Color(0.80, 0.82, 0.85), 0.12, 1.0),
		make_box(Vector3(0.08, 0.06, 0.05),
				Vector3(half_w - 0.05, mid - 0.10, face_y + 0.042),
				Color(0.80, 0.82, 0.85)),
		make_box(Vector3(0.18, 0.06, 0.008),
				Vector3(0, top_z - 0.14, face_y + 0.040),
				Color(0.62, 0.55, 0.30)),
	]
	# door racks on the inside face, with a bottle in the tall one
	for rz in [mid - h * 0.28, mid + h * 0.10]:
		swinging.append(make_box(Vector3(half_w * 1.7, 0.018, 0.055),
				Vector3(0, rz, face_y - 0.030),
				Color(0.80, 0.82, 0.85)))
	for hz in [bot_z + h * 0.18, top_z - h * 0.18]:
		swinging.append(make_box(Vector3(0.03, 0.02, 0.045),
				Vector3(half_w - 0.05, hz, face_y + 0.055),
				Color(0.80, 0.82, 0.85)))
	for piece in swinging:
		var keep := piece.position
		remove_child(piece)
		_door.add_child(piece)
		piece.position = keep - _door.position
	retexture(self, [
		[Color(0.88, 0.87, 0.84), "appliance", Color.WHITE],
		[Color(0.80, 0.82, 0.85), "chrome", Color.WHITE],
		[Color(0.62, 0.55, 0.30), "brass", Color.WHITE],
	])
	_hum = make_emitter("hum_loop", -22.0, true)
	_click = make_emitter("tick", -12.0)


## Somebody's food, on the shelves the cabinet already built. Nothing in
## here is interactive - it is here so that opening a door tells you who
## lives with it.
func _build_contents(half_w: float) -> void:
	var items: Array = LARDER.get(unit, LARDER.get("4B", []))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(unit) if unit != "" else 4
	var used := {0: 0, 1: 0, 2: 0}
	for item in items:
		var label: String = item[0]
		var tint: Color = item[1]
		var wide: float = item[2]
		var tall: float = item[3]
		var shelf: int = clampi(int(item[4]), 0, SHELF_Z.size() - 1)
		var n: int = used.get(shelf, 0)
		used[shelf] = n + 1
		var x := -half_w + 0.07 + n * 0.115 + rng.randf_range(-0.01, 0.01)
		var z := rng.randf_range(-0.04, 0.06)
		var y: float = SHELF_Z[shelf] + tall * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.78
		# A branded item wears its label. AtlasTexture does not crop on a
		# 3D material - it hands the mesh the whole sheet - so the cell is
		# selected with a UV window, the same way the clock dials and the
		# mail cards are. Unbranded things (eggs, a carton, whatever has
		# furred over) stay as their tint: not everything in an icebox has
		# a printed face, and giving them one would be worse than nothing.
		var cell: int = LABEL_CELL.get(label, -1)
		if cell >= 0:
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = load(LABEL_SHEET)
			mat.uv1_scale = Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0)
			mat.uv1_offset = Vector3((cell % 3) / 3.0, (cell / 3) / 3.0, 0.0)
		var mi := MeshInstance3D.new()
		if label.begins_with("MERIDIAN") or label.begins_with("QUELL") \
				or label.begins_with("PEERLESS"):
			var cyl := CylinderMesh.new()
			cyl.top_radius = wide * 0.5
			cyl.bottom_radius = wide * 0.5
			cyl.height = tall
			cyl.radial_segments = 8
			mi.mesh = cyl
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(wide, tall, wide * 0.8)
			mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(x, y, z)
		mi.rotation.y = rng.randf_range(-0.25, 0.25)
		add_child(mi)


func interact_prompt() -> String:
	return "[E]  %s the refrigerator" % ("Close" if _open else "Open")


func interact(_player: Node) -> void:
	set_door_open(not _open)


## One path for the hand and the haunting, so a possessed door cannot
## desync from the latch state the prompt reports.
func set_door_open(open: bool, seconds := 0.55) -> void:
	if _door == null:
		return
	_open = open
	_click.pitch_scale = 0.8 if open else 1.15
	_click.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	tween.tween_property(_door, "rotation:y",
			deg_to_rad(-105.0) if open else 0.0, seconds)
	create_tween().tween_property(_lamp, "light_energy",
			1.1 if open else 0.0, seconds * 0.6)


## Possession: the door keeps the motif. Short, hard beats with the
## lamp stuttering behind them - a fridge cannot speak, so it knocks.
func possess_fit(beats := 4) -> void:
	if _possessed or _door == null:
		return
	_possessed = true
	for i in range(beats):
		set_door_open(true, 0.16)
		await get_tree().create_timer(0.22, false).timeout
		if not is_inside_tree():
			return
		set_door_open(false, 0.13)
		await get_tree().create_timer(0.30 if i % 2 else 0.18,
				false).timeout
		if not is_inside_tree():
			return
	_possessed = false

func _start_normal_function() -> void:
	state = PState.OPERATING
	_thermostat_loop()


func _thermostat_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(35.0, 80.0), false).timeout
		if not is_inside_tree():
			return
		_running = not _running
		_click.pitch_scale = 0.9
		_click.play()
		create_tween().tween_property(_hum, "volume_db",
				-22.0 if _running else -50.0, 1.2)


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_click.pitch_scale = rng.randf_range(0.85, 0.95)
	_click.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_click.play()
	if not _running:
		_running = true
		create_tween().tween_property(_hum, "volume_db", -22.0, 0.6)
