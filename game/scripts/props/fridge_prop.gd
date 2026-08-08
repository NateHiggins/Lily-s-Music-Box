class_name FridgeProp
extends FunctionalProp
## The building's cold boxes, governed by the Rule of Signal rather than
## by a century-wide appliance mood board.
##
## Four flats own expensive 1927 electric monitor-tops. The other fourteen
## have second-hand oak-and-zinc iceboxes: no wire, compressor, relay,
## thermostat or interior lamp. Both models live here in full. Splitting the
## carcass into Blender and the moving parts into Godot left the warehouse
## displaying a floating door and 4B with no cabinet at all.

const ICE_W := 0.70
const ICE_D := 0.58
const ICE_H := 1.24
const MON_W := 0.72
const MON_D := 0.64
const MON_H := 1.66

const OAK := Color(0.52, 0.34, 0.19)
const ZINC := Color(0.66, 0.67, 0.67)
const ENAMEL := Color(0.88, 0.87, 0.82)
const COPPER := Color(0.55, 0.33, 0.21)
const BRASS_DULL := Color(0.62, 0.48, 0.22)
const CHROME := Color(0.80, 0.82, 0.85)
const DARK := Color(0.12, 0.10, 0.085)
const WATER_STAIN := Color(0.19, 0.105, 0.055)

var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _drip: AudioStreamPlayer3D
var _running := false
## Every leaf has its own hinge. The food door remains the primary E
## interaction; the ice door and drip tray are public mechanisms for the
## maintenance minigame and the director, not painted-on promises.
var _door: Node3D
var _ice_door: Node3D
var _tray: Node3D
var _lamp: OmniLight3D
var _open := false
var _ice_open := false
var _tray_open := false
var _tray_closed_z := 0.0
var _possessed := false

## Which flat this is, so the contents can be somebody's rather than
## generic, and whether it is one of the four 1927 monitor-tops.
var unit := ""
var monitor_top := false

## What is in the building's cold boxes. Brands are invented because a
## real one drags a real world in with it; these are the names a Queens
## grocery carried between the wars and never stopped carrying.
const LARDER := {
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

const LABEL_SHEET := "res://assets/building/textures/larder/larder_labels.png"
const LABEL_CELL := {
	"MERIDIAN MILK": 0, "HOLLOWAY'S": 1, "CROWN & VALE": 2,
	"PEERLESS LAGER": 3, "KESSLER'S PICKLES": 4, "ASTORIA CREAM": 5,
	"QUELL TONIC": 6, "WREN'S BUTTER": 7, "BELL BROS.": 8,
}


## The warehouse asks the prop for displays before any node enters the tree.
## Without this, its one `fridge` kind can only prove one of two silhouettes.
func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "fridge / oak icebox",
		 "properties": {"unit": "4B", "monitor_top": false}},
		{"label": "fridge / 1927 monitor-top",
		 "properties": {"unit": "1A", "monitor_top": true}},
	]


func _build_visual() -> void:
	var carcass := Node3D.new()
	carcass.name = "StaticCarcass"
	add_child(carcass)
	var half_w: float
	var shelves: Array[float]
	if monitor_top:
		half_w = MON_W * 0.5
		shelves = [0.38, 0.67, 0.94]
		_build_monitor_top(carcass)
		_build_monitor_door()
		_build_monitor_lamp()
	else:
		half_w = ICE_W * 0.5
		shelves = [0.30, 0.52, 0.74]
		_build_icebox(carcass)
		_build_icebox_leaves()
	_build_contents(half_w, shelves)

	var oak_tint := _oak_tint()
	var enamel_tint := _enamel_tint()
	retexture(self, [
		[OAK, "oak_quartered", oak_tint, 0.88],
		[ZINC, "zinc_liner", Color.WHITE],
		[ENAMEL, "enamel", enamel_tint],
		[COPPER, "copper_aged", Color.WHITE],
		[BRASS_DULL, "brass_dull", Color.WHITE],
		[CHROME, "chrome", Color.WHITE],
	])
	# Forty-odd cabinet primitives become one draw per finish. Leaves, tray,
	# food and lamp remain outside this subtree because each has a different
	# mechanical life.
	merge_static(carcass)

	_click = make_emitter("tick", -19.0)
	_creak = make_emitter("creak", -30.0)
	if monitor_top:
		_hum = make_emitter("hum_loop", -24.0, true)
		_running = true
	else:
		_drip = make_emitter("water_droplets", -33.0)


func _build_icebox(carcass: Node3D) -> void:
	var front := -ICE_D * 0.5
	var back := ICE_D * 0.5
	# A cabinet, not a box primitive: every board terminates in another
	# board, and opening a leaf reveals a zinc chamber rather than its own
	# exterior backface.
	_box_on(carcass, Vector3(ICE_W, 0.065, ICE_D),
			Vector3(0, 1.207, 0), OAK)
	_box_on(carcass, Vector3(ICE_W, 0.07, ICE_D),
			Vector3(0, 0.085, 0), OAK)
	_box_on(carcass, Vector3(0.075, 1.12, ICE_D),
			Vector3(-0.312, 0.64, 0), OAK)
	_box_on(carcass, Vector3(0.075, 1.12, ICE_D),
			Vector3(0.312, 0.64, 0), OAK)
	_box_on(carcass, Vector3(ICE_W, 1.12, 0.045),
			Vector3(0, 0.64, back - 0.023), OAK)
	for rail_y in [0.22, 0.955]:
		_box_on(carcass, Vector3(ICE_W, 0.055, 0.075),
				Vector3(0, rail_y, front + 0.038), OAK)
	# Feet and a recessed kick make the load reach the floor without turning
	# the bottom into one modern moulded plinth.
	for x in [-0.29, 0.29]:
		for z in [front + 0.055, back - 0.055]:
			_box_on(carcass, Vector3(0.055, 0.08, 0.055),
					Vector3(x, 0.04, z), OAK)
	_box_on(carcass, Vector3(0.54, 0.055, 0.04),
			Vector3(0, 0.07, front - 0.005), WATER_STAIN)

	# Zinc liner: back, cheeks, floor and the ice-compartment divider. The
	# front is absent because that is the hole the door exists to close.
	_box_on(carcass, Vector3(0.54, 0.70, 0.018),
			Vector3(0, 0.59, back - 0.052), ZINC)
	for x in [-0.268, 0.268]:
		_box_on(carcass, Vector3(0.018, 0.70, 0.47),
				Vector3(x, 0.59, 0.015), ZINC)
	for y in [0.245, 0.93]:
		_box_on(carcass, Vector3(0.54, 0.018, 0.47),
				Vector3(0, y, 0.015), ZINC)
	# The upper ice chamber gets its own small liner and drain cup. It is
	# thermally connected to the food chamber, not one tall modern cavity.
	_box_on(carcass, Vector3(0.54, 0.22, 0.018),
			Vector3(0, 1.075, back - 0.052), ZINC)
	for x in [-0.268, 0.268]:
		_box_on(carcass, Vector3(0.018, 0.22, 0.47),
				Vector3(x, 1.075, 0.015), ZINC)
	for shelf_y in [0.30, 0.52, 0.74]:
		_build_wire_shelf(carcass, shelf_y, 0.50, 0.42, ZINC)


func _build_icebox_leaves() -> void:
	var front := -ICE_D * 0.5
	_door = Node3D.new()
	_door.name = "FoodDoor"
	_door.position = Vector3(-ICE_W * 0.5, 0, front)
	add_child(_door)
	_box_on(_door, Vector3(ICE_W, 0.69, 0.035),
			Vector3(ICE_W * 0.5, 0.595, -0.018), OAK)
	_box_on(_door, Vector3(0.55, 0.51, 0.012),
			Vector3(ICE_W * 0.5, 0.595, -0.043), OAK)
	_box_on(_door, Vector3(0.57, 0.57, 0.008),
			Vector3(ICE_W * 0.5, 0.595, 0.006), ZINC)
	_cyl_on(_door, 0.014, 0.014, 0.18,
			Vector3(ICE_W - 0.075, 0.62, -0.070), BRASS_DULL)
	_box_on(_door, Vector3(0.085, 0.055, 0.045),
			Vector3(ICE_W - 0.075, 0.52, -0.047), BRASS_DULL)
	for y in [0.32, 0.86]:
		_cyl_on(_door, 0.014, 0.014, 0.08,
				Vector3(0.022, y, -0.050), BRASS_DULL)

	_ice_door = Node3D.new()
	_ice_door.name = "IceDoor"
	_ice_door.position = Vector3(-ICE_W * 0.5, 0, front)
	add_child(_ice_door)
	_box_on(_ice_door, Vector3(ICE_W, 0.235, 0.035),
			Vector3(ICE_W * 0.5, 1.085, -0.018), OAK)
	_box_on(_ice_door, Vector3(0.55, 0.13, 0.012),
			Vector3(ICE_W * 0.5, 1.085, -0.043), OAK)
	_cyl_on(_ice_door, 0.012, 0.012, 0.12,
			Vector3(ICE_W - 0.072, 1.085, -0.067), BRASS_DULL)

	_tray = Node3D.new()
	_tray.name = "DripTray"
	_tray_closed_z = front + 0.045
	_tray.position = Vector3(0, 0, _tray_closed_z)
	add_child(_tray)
	_box_on(_tray, Vector3(0.50, 0.014, 0.22),
			Vector3(0, 0.14, 0.09), ZINC)
	for x in [-0.245, 0.245]:
		_box_on(_tray, Vector3(0.014, 0.055, 0.22),
				Vector3(x, 0.165, 0.09), ZINC)
	_box_on(_tray, Vector3(0.52, 0.11, 0.025),
			Vector3(0, 0.15, -0.035), OAK)
	_cyl_on(_tray, 0.010, 0.010, 0.22,
			Vector3(0, 0.15, -0.060), BRASS_DULL)
	# make_cyl is vertical; the pull belongs horizontal across the tray.
	var pull := _tray.get_child(_tray.get_child_count() - 1) as Node3D
	pull.rotation_degrees.z = 90.0


func _build_monitor_top(carcass: Node3D) -> void:
	var front := -MON_D * 0.5
	var back := MON_D * 0.5
	for x in [-0.30, 0.30]:
		for z in [front + 0.055, back - 0.055]:
			_cyl_on(carcass, 0.018, 0.014, 0.17,
					Vector3(x, 0.085, z), CHROME)
	# Pressed cabinet shell around a real opening. Corner posts soften the
	# silhouette without hiding the liner behind one giant box.
	_box_on(carcass, Vector3(MON_W, 0.055, MON_D),
			Vector3(0, 0.205, 0), ENAMEL)
	_box_on(carcass, Vector3(MON_W, 0.055, MON_D),
			Vector3(0, 1.275, 0), ENAMEL)
	_box_on(carcass, Vector3(0.055, 1.04, MON_D),
			Vector3(-0.332, 0.75, 0), ENAMEL)
	_box_on(carcass, Vector3(0.055, 1.04, MON_D),
			Vector3(0.332, 0.75, 0), ENAMEL)
	_box_on(carcass, Vector3(MON_W, 1.04, 0.045),
			Vector3(0, 0.75, back - 0.023), ENAMEL)
	for x in [-0.315, 0.315]:
		for z in [front + 0.040, back - 0.040]:
			_cyl_on(carcass, 0.045, 0.045, 1.03,
					Vector3(x, 0.75, z), ENAMEL)
	# Porcelain liner and three wire shelves.
	_box_on(carcass, Vector3(0.57, 0.96, 0.018),
			Vector3(0, 0.75, back - 0.052), ENAMEL)
	for x in [-0.286, 0.286]:
		_box_on(carcass, Vector3(0.018, 0.96, 0.52),
				Vector3(x, 0.75, 0.015), ENAMEL)
	for y in [0.235, 1.245]:
		_box_on(carcass, Vector3(0.57, 0.018, 0.52),
				Vector3(0, y, 0.015), ENAMEL)
	for shelf_y in [0.38, 0.67, 0.94]:
		_build_wire_shelf(carcass, shelf_y, 0.54, 0.47, CHROME)
	# Small freezing box below the mechanism, built as a shelf and hood so
	# it remains a compartment rather than a solid block in the opening.
	_box_on(carcass, Vector3(0.43, 0.022, 0.35),
			Vector3(0, 1.13, 0.035), ENAMEL)
	_box_on(carcass, Vector3(0.43, 0.15, 0.020),
			Vector3(0, 1.205, back - 0.072), ENAMEL)

	# DR-series monitor: broad low machinery, open copper condenser rings,
	# service pipes and a shallow cap. The previous three-storey black drum
	# had the height but not the object class.
	_cyl_on(carcass, 0.25, 0.27, 0.075,
			Vector3(0, 1.337, 0), ENAMEL)
	_cyl_on(carcass, 0.18, 0.20, 0.19,
			Vector3(0, 1.455, 0), DARK)
	for y in [1.385, 1.455, 1.525]:
		_ring_on(carcass, 0.225, 0.011, Vector3(0, y, 0), COPPER)
	for x in [-0.205, 0.205]:
		_tube_between(carcass, Vector3(x, 1.31, 0.02),
				Vector3(x, 1.56, 0.02), 0.010, COPPER)
	_cyl_on(carcass, 0.075, 0.17, 0.075,
			Vector3(0, 1.622, 0), DARK)
	_box_on(carcass, Vector3(0.18, 0.08, 0.018),
			Vector3(0, 1.28, front - 0.018), BRASS_DULL)


func _build_monitor_door() -> void:
	var front := -MON_D * 0.5
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(-MON_W * 0.5, 0, front)
	add_child(_door)
	_box_on(_door, Vector3(MON_W, 1.035, 0.040),
			Vector3(MON_W * 0.5, 0.745, -0.020), ENAMEL)
	_box_on(_door, Vector3(0.59, 0.90, 0.014),
			Vector3(MON_W * 0.5, 0.745, -0.047), ENAMEL)
	_cyl_on(_door, 0.016, 0.016, 0.27,
			Vector3(MON_W - 0.075, 0.79, -0.083), CHROME)
	_box_on(_door, Vector3(0.095, 0.065, 0.050),
			Vector3(MON_W - 0.075, 0.64, -0.052), CHROME)
	for y in [0.31, 1.17]:
		_cyl_on(_door, 0.015, 0.015, 0.09,
				Vector3(0.023, y, -0.055), CHROME)
	# Two restrained edge chips expose the dark steel precisely where the
	# latch strike and lower boot meet it; not a uniform apocalypse filter.
	_box_on(_door, Vector3(0.045, 0.018, 0.006),
			Vector3(MON_W - 0.12, 0.285, -0.066), DARK)
	_box_on(_door, Vector3(0.030, 0.025, 0.006),
			Vector3(MON_W - 0.05, 0.635, -0.067), DARK)


func _build_monitor_lamp() -> void:
	_lamp = OmniLight3D.new()
	_lamp.name = "InteriorLamp"
	_lamp.light_color = Color(1.0, 0.94, 0.78)
	_lamp.light_energy = 0.0
	# A 1927 cabinet lamp illuminates the liner, not the kitchen. The first
	# pass used 0.85 over 1.35 m; with the player's torch on it clipped the
	# whole cavity to white and erased the shelves in the required render.
	_lamp.omni_range = 0.90
	_lamp.position = Vector3(0, 1.08, 0.08)
	_lamp.shadow_enabled = false
	add_child(_lamp)


func _build_wire_shelf(parent: Node3D, y: float, w: float, d: float,
		color: Color) -> void:
	for i in 7:
		var x := -w * 0.5 + i * w / 6.0
		_tube_between(parent, Vector3(x, y, -d * 0.5),
				Vector3(x, y, d * 0.5), 0.0045, color)
	for z in [-d * 0.42, d * 0.42]:
		_tube_between(parent, Vector3(-w * 0.5, y, z),
				Vector3(w * 0.5, y, z), 0.0055, color)


## INSIDE THE LINER, NOT INSIDE THE CARCASS. This was measured off
## `half_w`, which is half the CABINET — 0.36 on a monitor-top, 0.35 on
## an icebox. The liner cheeks stand at 0.286 and 0.268 and are 18 mm
## thick, so their inner faces are at 0.277 and 0.259: the first item on
## every shelf of every refrigerator in the building was starting 38 mm
## inside the side wall and punching through it. Perfectly invisible in
## the source and perfectly obvious the moment a torch is pointed at an
## open one, which is how it was found.
const LINER_HALF := {true: 0.277, false: 0.259}   # keyed by monitor_top


func _build_contents(half_w: float, shelves: Array[float]) -> void:
	var items: Array = LARDER.get(unit, LARDER.get("4B", []))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = hash(unit) if unit != "" else 4
	var inner: float = LINER_HALF[monitor_top]
	# Counted first so a shelf's items can be SPREAD across it rather than
	# marched from one wall. Two bottles shoved into the left corner of an
	# otherwise bare shelf read as a packing error; the same two spaced
	# across it read as somebody's shopping.
	var per_shelf := {}
	for item in items:
		var s: int = clampi(int(item[4]), 0, shelves.size() - 1)
		per_shelf[s] = int(per_shelf.get(s, 0)) + 1
	var used := {0: 0, 1: 0, 2: 0}
	for item in items:
		var label: String = item[0]
		var tint: Color = item[1]
		var wide: float = item[2]
		var tall: float = item[3]
		var shelf: int = clampi(int(item[4]), 0, shelves.size() - 1)
		var n: int = used.get(shelf, 0)
		used[shelf] = n + 1
		var count: int = maxi(1, int(per_shelf.get(shelf, 1)))
		var span := inner * 2.0
		var x := -inner + (float(n) + 0.5) * span / float(count) \
				+ local_rng.randf_range(-0.012, 0.012)
		# Whatever the spread says, the item's own edge stays off the
		# zinc. A wide carton on a crowded shelf would otherwise put the
		# clipping back where it started.
		var lim: float = maxf(0.0, inner - wide * 0.5 - 0.006)
		x = clampf(x, -lim, lim)
		var z := local_rng.randf_range(-0.055, 0.045)
		var y: float = shelves[shelf] + tall * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.78
		# AtlasTexture does not crop a 3D material: the whole sheet lands on
		# every carton. Select its cell with a UV window; unbranded food keeps
		# its own tint because not everything in an icebox is an advert.
		var cell: int = LABEL_CELL.get(label, -1)
		if cell >= 0:
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = load(LABEL_SHEET)
			mat.uv1_scale = Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0)
			mat.uv1_offset = Vector3((cell % 3) / 3.0,
					(cell / 3) / 3.0, 0.0)
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
		mi.rotation.y = local_rng.randf_range(-0.25, 0.25)
		add_child(mi)


func _oak_tint() -> Color:
	# Four restrained second-hand finishes, deterministic by flat. This is
	# provenance, not a random colourizer: neighbouring cabinets stop being
	# clones while remaining the same species and price point.
	var tones := [
		Color(0.67, 0.61, 0.53), Color(0.58, 0.54, 0.48),
		Color(0.52, 0.50, 0.46), Color(0.63, 0.55, 0.46),
	]
	return tones[absi(hash(unit)) % tones.size()]


func _enamel_tint() -> Color:
	match unit:
		"1A": return Color(1.0, 0.99, 0.95)  # Evelyn keeps the new thing new.
		"3A": return Color(0.94, 0.97, 0.91)
		"5B": return Color(0.91, 0.87, 0.78)
		"6C": return Color(0.88, 0.91, 0.84)
	return Color.WHITE


func _box_on(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var mi := make_box(size, at, color)
	remove_child(mi)
	parent.add_child(mi)
	mi.position = at
	return mi


func _cyl_on(parent: Node3D, rt: float, rb: float, h: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, h, at, color, 0.55, 0.0, parent)


func _ring_on(parent: Node3D, radius: float, tube: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_ring(radius, tube, at, color, 0.55, 0.0, parent)


func _tube_between(parent: Node3D, a: Vector3, b: Vector3,
		radius: float, color: Color) -> MeshInstance3D:
	var delta := b - a
	var mi := make_cyl(radius, radius, delta.length(), (a + b) * 0.5,
			color, 0.55, 0.0, parent)
	mi.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return mi


func interact_prompt() -> String:
	var noun := "monitor-top" if monitor_top else "icebox"
	return "[E]  %s the %s" % ["Close" if _open else "Open", noun]


func interact(_player: Node) -> void:
	set_door_open(not _open)


## One path for hand and haunting, so a possessed leaf cannot disagree
## with the latch state the prompt reports.
func set_door_open(open: bool, seconds := 0.55) -> void:
	if _door == null:
		return
	_open = open
	if _click:
		_click.pitch_scale = 0.82 if open else 1.12
		_click.play()
	if not monitor_top and _creak:
		_creak.pitch_scale = 0.88 if open else 1.02
		_creak.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	# The front is local -Z, matching StoveProp and the Blender facing
	# convention. Positive Y rotation carries the leaf toward the player.
	tween.tween_property(_door, "rotation:y",
			deg_to_rad(105.0) if open else 0.0, seconds)
	if _lamp:
		create_tween().tween_property(_lamp, "light_energy",
				0.22 if open else 0.0, seconds * 0.6)


func set_ice_door_open(open: bool, seconds := 0.45) -> void:
	if monitor_top or _ice_door == null:
		return
	_ice_open = open
	if _click:
		_click.pitch_scale = 1.05
		_click.play()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_ice_door, "rotation:y",
			deg_to_rad(98.0) if open else 0.0, seconds)


func set_tray_open(open: bool, seconds := 0.38) -> void:
	if monitor_top or _tray == null:
		return
	_tray_open = open
	if _click:
		_click.pitch_scale = 1.22 if open else 0.94
		_click.play()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_tray, "position:z",
			_tray_closed_z - 0.30 if open else _tray_closed_z, seconds)


## The electric cabinet can knock and flare. The passive icebox does less:
## its tray comes out a few centimetres and is found shut on the next look.
## Either can still be blamed on a loose latch or a sloping floor.
func possess_fit(beats := 4) -> void:
	if _possessed or _door == null:
		return
	_possessed = true
	if monitor_top:
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
	else:
		for i in range(maxi(2, int(ceil(float(beats) / 2.0)))):
			set_tray_open(true, 0.18)
			await get_tree().create_timer(0.36 + i * 0.11, false).timeout
			if not is_inside_tree():
				return
			set_tray_open(false, 0.22)
			await get_tree().create_timer(0.52, false).timeout
			if not is_inside_tree():
				return
	_possessed = false


func _start_normal_function() -> void:
	state = PState.OPERATING
	if monitor_top:
		_thermostat_loop()
	else:
		_icebox_ambient_loop()


func _thermostat_loop() -> void:
	while is_inside_tree() and monitor_top:
		await get_tree().create_timer(rng.randf_range(38.0, 86.0), false).timeout
		if not is_inside_tree() or not monitor_top:
			return
		_running = not _running
		_click.pitch_scale = 0.9
		_click.play()
		create_tween().tween_property(_hum, "volume_db",
				-24.0 if _running else -50.0, 1.2)


func _icebox_ambient_loop() -> void:
	while is_inside_tree() and not monitor_top:
		await get_tree().create_timer(rng.randf_range(58.0, 150.0), false).timeout
		if not is_inside_tree() or monitor_top:
			return
		if rng.randf() < 0.58:
			_drip.pitch_scale = rng.randf_range(0.86, 1.08)
			_drip.play()
		else:
			_creak.pitch_scale = rng.randf_range(0.72, 0.92)
			_creak.play()


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if monitor_top:
		_click.pitch_scale = rng.randf_range(0.85, 0.95)
		_click.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_click.play()
		if not _running:
			_running = true
			create_tween().tween_property(_hum, "volume_db", -24.0, 0.6)
	elif _tray and not _tray_open:
		_click.pitch_scale = rng.randf_range(0.78, 0.90)
		_click.volume_db = -23.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_click.play()
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_tray, "position:z", _tray_closed_z - 0.035, 0.12)
		tween.tween_property(_tray, "position:z", _tray_closed_z, 0.22)
