class_name MedicineCabinetProp
extends FunctionalProp
## The bathroom mirror, which is a door.
##
## There is no planar reflection on gl_compatibility, so a mirror here
## cannot actually reflect the room. Pretending otherwise gets you a flat
## grey rectangle that everyone reads as a broken mirror.
##
## So this leans the other way: a 1926 mirror that nobody has replaced is
## silvered glass gone slightly warm and blotchy at the edges, with the
## silver failing where the damp gets behind it. That reads as an old
## mirror at a glance and does not owe the renderer anything. What makes
## it FUNCTIONAL is that it opens. This prop owns the carcass and its two
## glass shelves too: the deleted pedestal-sink assembly used to own those
## fixed pieces, which left a perfect door opening onto literal empty air in
## the warehouse. Behind it is whatever this tenant keeps in the dark.
##
## Left open, the door hangs. It also means the mirror is no longer
## facing the room, which is a cheap and very old trick and this building
## is welcome to it.

var unit := ""

## What is behind each door. Small, personal, and mostly medicinal -
## the cabinet is the one place a person keeps things they would not put
## out on a shelf.
const KEPT := {
	"1A": [["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.036, 0.11],
		   ["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05],
		   ["reading glasses", Color(0.18, 0.16, 0.14), 0.10, 0.02]],
	"1D": [["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.036, 0.11],
		   ["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.036, 0.11],
		   ["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09]],
	"2A": [["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05],
		   ["cold cream", Color(0.90, 0.88, 0.80), 0.048, 0.04]],
	"2B": [["thimble tin", Color(0.62, 0.56, 0.34), 0.042, 0.03],
		   ["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05],
		   ["iodine", Color(0.38, 0.18, 0.10), 0.028, 0.07]],
	"2C": [["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09],
		   ["razor", Color(0.72, 0.74, 0.76), 0.09, 0.02]],
	"3A": [["razor", Color(0.72, 0.74, 0.76), 0.09, 0.02],
		   ["shaving stick", Color(0.88, 0.86, 0.78), 0.034, 0.08]],
	"3B": [["iodine", Color(0.38, 0.18, 0.10), 0.028, 0.07],
		   ["plasters", Color(0.80, 0.72, 0.56), 0.055, 0.03]],
	"3D": [["cold cream", Color(0.90, 0.88, 0.80), 0.048, 0.04],
		   ["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.036, 0.11]],
	"4A": [["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09],
		   ["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09],
		   ["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09]],
	"4B": [["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05],
		   ["iodine", Color(0.38, 0.18, 0.10), 0.028, 0.07],
		   ["razor", Color(0.72, 0.74, 0.76), 0.09, 0.02]],
	"4C": [["razor", Color(0.72, 0.74, 0.76), 0.09, 0.02],
		   ["plasters", Color(0.80, 0.72, 0.56), 0.055, 0.03],
		   ["cold cream", Color(0.90, 0.88, 0.80), 0.048, 0.04]],
	"4D": [["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05]],
	"5A": [["cold cream", Color(0.90, 0.88, 0.80), 0.048, 0.04],
		   ["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05]],
	"5B": [["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09],
		   ["razor", Color(0.72, 0.74, 0.76), 0.09, 0.02]],
	"5C": [["turpentine", Color(0.62, 0.58, 0.34), 0.036, 0.10],
		   ["cold cream", Color(0.90, 0.88, 0.80), 0.048, 0.04]],
	"6A": [["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05],
		   ["shaving stick", Color(0.88, 0.86, 0.78), 0.034, 0.08]],
	"6B": [["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.036, 0.11],
		   ["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09]],
	"6C": [["iodine", Color(0.38, 0.18, 0.10), 0.028, 0.07],
		   ["thimble tin", Color(0.62, 0.56, 0.34), 0.042, 0.03],
		   ["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05]],
}
const SHELF_Y := [1.22, 1.37]

var _door: Node3D
var _open := false
var _swing := 0.0
var _squeak: AudioStreamPlayer3D


func _build_visual() -> void:
	var carcass := Node3D.new()
	carcass.name = "CabinetCarcass"
	add_child(carcass)
	_build_carcass(carcass)
	retexture(carcass, [
		[Color(0.83, 0.82, 0.77), "enamel", Color(0.82, 0.81, 0.75), 0.65],
		[Color(0.70, 0.70, 0.67), "nickel_plated", Color(0.88, 0.86, 0.79), 0.42],
	])
	merge_static(carcass)
	_build_kept()
	# The door: mirror glass in a slim frame, hinged on the left stile so
	# it opens away from whoever is standing at the basin.
	_door = Node3D.new()
	_door.name = "CabinetDoor"
	_door.position = Vector3(-0.225, 1.30, -0.150)
	add_child(_door)

	var silver := StandardMaterial3D.new()
	# Warm, blotchy, and not quite reflective. An optically perfect
	# mirror in a room this old would be the least convincing thing in it.
	silver.albedo_color = Color(0.66, 0.67, 0.65)
	silver.metallic = 0.86
	silver.roughness = 0.16
	silver.rim_enabled = true
	silver.rim = 0.35
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.74, 0.75, 0.77)
	frame.metallic = 0.70
	frame.roughness = 0.38

	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.42, 0.48, 0.010)
	glass.mesh = gm
	glass.material_override = silver
	glass.position = Vector3(0.225, 0.0, -0.008)
	_door.add_child(glass)
	# slim frame: two stiles and two rails
	for sx in [0.012, 0.438]:
		var st := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.024, 0.50, 0.016)
		st.mesh = sm
		st.material_override = frame
		st.position = Vector3(sx, 0.0, -0.004)
		_door.add_child(st)
	for sy in [-0.244, 0.244]:
		var ra := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.45, 0.024, 0.016)
		ra.mesh = rm
		ra.material_override = frame
		ra.position = Vector3(0.225, sy, -0.004)
		_door.add_child(ra)
	# the little knob, and the two hinges it turns against
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.013
	km.height = 0.026
	km.radial_segments = 7
	km.rings = 4
	knob.mesh = km
	knob.material_override = frame
	knob.position = Vector3(0.412, 0.0, -0.022)
	_door.add_child(knob)

	_squeak = make_emitter("door_squeak", -24.0)
	if _squeak:
		_squeak.max_distance = 7.0


func _build_carcass(parent: Node3D) -> void:
	var enamel := Color(0.83, 0.82, 0.77)
	var nickel := Color(0.70, 0.70, 0.67)
	# Recessed 440 x 500 mm pressed-steel box. Its shallow depth is why the
	# kept bottles sit so close to the mirror when the leaf swings shut.
	_box_on(parent, Vector3(0.44, 0.50, 0.020),
			Vector3(0, 1.30, -0.225), enamel)
	for x in [-0.21, 0.21]:
		_box_on(parent, Vector3(0.020, 0.50, 0.085),
				Vector3(x, 1.30, -0.1925), enamel)
	for y in [1.06, 1.54]:
		_box_on(parent, Vector3(0.44, 0.020, 0.085),
				Vector3(0, y, -0.1925), enamel)
	for y in SHELF_Y:
		var shelf := _box_on(parent, Vector3(0.40, 0.008, 0.075),
				Vector3(0, y, -0.1925), Color(0.72, 0.76, 0.75, 0.42))
		var mat: StandardMaterial3D = shelf.material_override
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.14
	for x in [-0.23, 0.23]:
		_box_on(parent, Vector3(0.018, 0.54, 0.018),
				Vector3(x, 1.30, -0.148), nickel)
	for y in [1.04, 1.56]:
		_box_on(parent, Vector3(0.48, 0.018, 0.018),
				Vector3(0, y, -0.148), nickel)


func _box_on(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := make_box(size, at, color)
	node.get_parent().remove_child(node)
	parent.add_child(node)
	node.position = at - parent.position
	return node


## What this tenant keeps where they can reach it in the dark.
func _build_kept() -> void:
	var items: Array = KEPT.get(unit, KEPT.get("4B", []))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(unit + "cab") if unit != "" else 9
	var used := {0: 0, 1: 0}
	for i in items.size():
		var item: Array = items[i]
		var tint: Color = item[1]
		var wide: float = item[2]
		var tall: float = item[3]
		var shelf := i % 2
		var n: int = used[shelf]
		used[shelf] = n + 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.62
		# QUELL TONIC is the one thing kept in both the icebox and the
		# cabinet, so it wears the same printed label in both. A brand a
		# player has already seen downstairs is what makes it a brand.
		var cell: int = FridgeProp.LABEL_CELL.get(item[0], -1)
		if cell >= 0:
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = load(FridgeProp.LABEL_SHEET)
			mat.uv1_scale = Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0)
			mat.uv1_offset = Vector3((cell % 3) / 3.0, (cell / 3) / 3.0, 0.0)
		var mi := MeshInstance3D.new()
		if tall > wide:
			var cyl := CylinderMesh.new()
			cyl.top_radius = wide * 0.5
			cyl.bottom_radius = wide * 0.5
			cyl.height = tall
			cyl.radial_segments = 7
			mi.mesh = cyl
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3(wide, tall, wide * 0.7)
			mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(-0.16 + n * 0.085 + rng.randf_range(-0.01, 0.01),
				SHELF_Y[shelf] + tall * 0.5 + 0.008,
				-0.195 + rng.randf_range(-0.012, 0.012))
		mi.rotation.y = rng.randf_range(-0.3, 0.3)
		add_child(mi)


func interact_prompt() -> String:
	return "[E]  %s the cabinet" % ("Close" if _open else "Open")


func interact(_player: Node) -> void:
	set_door_open(not _open)


## Inspection/minigame API. A zero duration puts the leaf directly in its
## measured sweep pose so a screenshot proves clearance rather than catching
## an arbitrary animation frame.
func set_door_open(open: bool, duration := 0.35) -> void:
	_open = open
	if _squeak and not _squeak.playing:
		_squeak.pitch_scale = 1.05 + randf_range(-0.06, 0.06)
		_squeak.play()
	if duration <= 0.0:
		_swing = 1.0 if _open else 0.0
		if _door:
			_door.rotation.y = _swing * -1.9


func _start_normal_function() -> void:
	state = PState.IDLE


func _process(delta: float) -> void:
	var want := 1.0 if _open else 0.0
	if is_equal_approx(_swing, want):
		return
	_swing = move_toward(_swing, want, delta * 2.4)
	if _door:
		_door.rotation.y = _swing * -1.9
