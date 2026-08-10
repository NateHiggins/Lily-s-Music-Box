class_name MedicineCabinetProp
extends FunctionalProp
## The bathroom mirror is the door of a cheap white-enamel cabinet.
##
## A 1926 hardware advertisement offers exactly that object. The expensive
## patent alternative hid its hinges behind beveled Venetian glass; the
## Orison bought the older tell-tale rectangle with two visible pins and a
## friction catch. It carries no signal and receives no electrical indulgence.
##
## Compatibility cannot reflect the room. `mirror_aged` therefore records
## only what belongs to the glass in every room: damp clouding, cleaning marks
## and failed silver. `glassish` is a Blender-only architectural material and
## naming it here would silently turn this GDScript prop back into flat colour.

const W := 0.46
const H := 0.61
const DEPTH := 0.095
## The lower edge sits at 1.20 m: high enough that the two valves and central
## spout read as plumbing rather than disappearing behind a mirror, while the
## five-foot worker still sees the centre of the glass almost straight on.
const CENTER_Y := 1.505
const DOOR_ANGLE := deg_to_rad(95.0)
const SHELF_Y := [1.40, 1.59]

var unit := ""
var hinge_side := "left"
var warehouse_open := false

## Explicit means explicit. The previous fallback put 4B's aspirin, iodine
## and razor in two vacant flats, a sealed flat, the landlord's store and the
## lobby lavatory whenever their keys were absent.
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
	"2D": [],
	"3A": [["razor", Color(0.72, 0.74, 0.76), 0.09, 0.02],
			["shaving stick", Color(0.88, 0.86, 0.78), 0.034, 0.08]],
	"3B": [["iodine", Color(0.38, 0.18, 0.10), 0.028, 0.07],
			["plasters", Color(0.80, 0.72, 0.56), 0.055, 0.03]],
	"3C": [],
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
	"5D": [["landlord salve tin", Color(0.55, 0.50, 0.36), 0.050, 0.025]],
	"6A": [["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05],
			["shaving stick", Color(0.88, 0.86, 0.78), 0.034, 0.08]],
	"6B": [["QUELL TONIC", Color(0.24, 0.46, 0.50), 0.036, 0.11],
			["brown bottle", Color(0.35, 0.22, 0.12), 0.034, 0.09]],
	"6C": [["iodine", Color(0.38, 0.18, 0.10), 0.028, 0.07],
			["thimble tin", Color(0.62, 0.56, 0.34), 0.042, 0.03],
			["aspirin", Color(0.86, 0.84, 0.78), 0.030, 0.05]],
	"6D": [],
	"F01WC": [["carbolic soap", Color(0.69, 0.61, 0.43), 0.075, 0.028],
			["plasters", Color(0.80, 0.72, 0.56), 0.055, 0.03]],
}

var _door: Node3D
var _open := false
var _swing := 0.0
var _squeak: AudioStreamPlayer3D


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "medicine cabinet / closed",
			"properties": {"unit": "4B", "hinge_side": "right"}},
		{"label": "medicine cabinet / open",
			"properties": {"unit": "1D", "hinge_side": "left",
				"warehouse_open": true}},
	]


## Its gameplay front is local -Z. Turn only the shed copy so the generic
## backing wall sits behind the cabinet rather than in front of its mirror.
func warehouse_rotation_y() -> float:
	return PI


func _build_visual() -> void:
	hinge_side = "right" if hinge_side == "right" else "left"
	var enamel := smat("enamel", Color(0.86, 0.85, 0.79), 0.72)
	var nickel := smat("nickel_plated", Color(0.88, 0.86, 0.80), 0.55)

	var carcass := Node3D.new()
	carcass.name = "CabinetCarcass"
	add_child(carcass)
	_build_carcass(carcass, enamel)
	merge_static(carcass)

	_build_door(enamel, nickel)
	_build_kept()
	_build_interaction()

	_squeak = make_emitter("door_squeak", -24.0)
	if _squeak:
		_squeak.max_distance = 7.0


func _build_carcass(parent: Node3D, enamel: StandardMaterial3D) -> void:
	# Wall plane is local Z=0. The old back sat at -0.225, farther into the
	# room than the trim, and remained a white lid after the door opened.
	# This folded box goes INTO the wall; its contents live between the real
	# back and the leaf where a viewer can actually see them.
	_box_mat(parent, Vector3(W - 0.025, H - 0.025, 0.012),
			Vector3(0, CENTER_Y, 0.052), enamel)
	for x in [-W * 0.5 + 0.009, W * 0.5 - 0.009]:
		_box_mat(parent, Vector3(0.018, H, DEPTH),
				Vector3(x, CENTER_Y, 0.006), enamel)
	for y in [CENTER_Y - H * 0.5 + 0.009, CENTER_Y + H * 0.5 - 0.009]:
		_box_mat(parent, Vector3(W, 0.018, DEPTH),
				Vector3(0, y, 0.006), enamel)
	# Rolled flange and four screw heads are the visible evidence that this is
	# a cabinet fitted into plaster, not a glowing picture laid over it.
	for x in [-W * 0.5 - 0.012, W * 0.5 + 0.012]:
		_box_mat(parent, Vector3(0.024, H + 0.045, 0.018),
				Vector3(x, CENTER_Y, -0.044), enamel)
	for y in [CENTER_Y - H * 0.5 - 0.012, CENTER_Y + H * 0.5 + 0.012]:
		_box_mat(parent, Vector3(W + 0.048, 0.024, 0.018),
				Vector3(0, y, -0.044), enamel)
	for x in [-W * 0.5 - 0.012, W * 0.5 + 0.012]:
		for y in [CENTER_Y - H * 0.5 - 0.012,
				CENTER_Y + H * 0.5 + 0.012]:
			_cyl_mat(parent, 0.007, 0.007, 0.006,
					Vector3(x, y, -0.056), enamel, Vector3(PI * 0.5, 0, 0))

	var shelf_mat := StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.67, 0.73, 0.72, 0.34)
	shelf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shelf_mat.roughness = 0.16
	for y in SHELF_Y:
		_box_mat(parent, Vector3(W - 0.055, 0.008, DEPTH - 0.025),
				Vector3(0, y, 0.004), shelf_mat)
		# The shelf's bright front lip does the visual work of four microscopic
		# clips for a fraction of their silhouette and draw cost.
		_box_mat(parent, Vector3(W - 0.045, 0.010, 0.009),
				Vector3(0, y - 0.004, -0.038), enamel)


func _build_door(enamel: StandardMaterial3D,
		nickel: StandardMaterial3D) -> void:
	# Side names are from the resident's view at the basin. Facing local +Z
	# reverses model X, so a visually left hinge is local +X.
	var side := 1.0 if hinge_side == "left" else -1.0
	_door = Node3D.new()
	_door.name = "CabinetDoor"
	_door.position = Vector3(side * W * 0.5, CENTER_Y, -0.060)
	add_child(_door)
	var centre_x := -side * W * 0.5

	# Steel backing is indispensable in the open pose: without it a mirror is
	# a one-sided card and vanishes when it should become a physical door.
	_box_mat(_door, Vector3(W - 0.012, H - 0.012, 0.012),
			Vector3(centre_x, 0, 0.004), enamel)
	var mirror := smat("mirror_aged", Color(0.78, 0.79, 0.76), 0.60)
	_box_mat(_door, Vector3(W - 0.040, H - 0.040, 0.008),
			Vector3(centre_x, 0, -0.010), mirror)

	for x in [centre_x - W * 0.5 + 0.012, centre_x + W * 0.5 - 0.012]:
		_box_mat(_door, Vector3(0.024, H, 0.018),
				Vector3(x, 0, -0.006), nickel)
	for y in [-H * 0.5 + 0.012, H * 0.5 - 0.012]:
		_box_mat(_door, Vector3(W, 0.024, 0.018),
				Vector3(centre_x, y, -0.006), nickel)
	# Two honest hinge barrels, a friction catch and the small pull opposite.
	for y in [-H * 0.30, H * 0.30]:
		_cyl_mat(_door, 0.008, 0.008, 0.070,
				Vector3(0, y, -0.001), nickel)
	var far_x := -side * (W - 0.030)
	_cyl_mat(_door, 0.012, 0.012, 0.026,
			Vector3(far_x, 0, -0.026), nickel, Vector3(PI * 0.5, 0, 0))
	_box_mat(_door, Vector3(0.025, 0.030, 0.018),
			Vector3(far_x, -0.13, 0.010), nickel)
	merge_static(_door)


func _build_kept() -> void:
	var contents := Node3D.new()
	contents.name = "CabinetContents"
	add_child(contents)
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.34, 0.20, 0.095)
	amber.roughness = 0.38
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var paper := smat("paper", Color(0.86, 0.80, 0.66), 0.20)
	var quell := StandardMaterial3D.new()
	quell.albedo_color = Color.WHITE
	quell.roughness = 0.58
	quell.albedo_texture = load(FridgeProp.LABEL_SHEET)
	var items: Array = KEPT.get(unit, [])
	var random := RandomNumberGenerator.new()
	random.seed = hash(unit + "cab") if unit != "" else 9
	var used := {0: 0, 1: 0}
	for i in items.size():
		var item: Array = items[i]
		var item_name := String(item[0])
		var wide := float(item[2])
		var tall := float(item[3])
		var shelf := i % 2
		var n: int = used[shelf]
		used[shelf] = n + 1
		var material: StandardMaterial3D = paper
		if item_name == "QUELL TONIC":
			material = quell
		elif tall > wide:
			material = amber
		var mi := MeshInstance3D.new()
		if tall > wide:
			var cyl := CylinderMesh.new()
			cyl.top_radius = wide * 0.43
			cyl.bottom_radius = wide * 0.5
			cyl.height = tall
			cyl.radial_segments = 9
			mi.mesh = cyl
		else:
			var box := BoxMesh.new()
			box.size = Vector3(wide, tall, wide * 0.68)
			mi.mesh = box
		mi.material_override = material
		mi.position = Vector3(-0.155 + n * 0.090
				+ random.randf_range(-0.008, 0.008),
				SHELF_Y[shelf] + tall * 0.5 + 0.008,
				0.005 + random.randf_range(-0.010, 0.010))
		mi.rotation.y = random.randf_range(-0.28, 0.28)
		contents.add_child(mi)
	merge_static(contents)


func _build_interaction() -> void:
	var area := Area3D.new()
	area.name = "CabinetReach"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W + 0.08, H + 0.08, 0.24)
	collision.shape = shape
	collision.position = Vector3(0, CENTER_Y, -0.08)
	area.add_child(collision)
	add_child(area)


func _box_mat(parent: Node3D, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var node := make_box(size, at, Color.WHITE)
	remove_child(node)
	parent.add_child(node)
	node.position = at
	node.material_override = material
	return node


func _cyl_mat(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, material: StandardMaterial3D,
		rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := make_cyl(rt, rb, height, at, Color.WHITE, 0.5, 0.0, parent)
	node.material_override = material
	node.rotation = rotation
	return node


func inventory_names() -> Array[String]:
	var out: Array[String] = []
	for item in KEPT.get(unit, []):
		out.append(String(item[0]))
	return out


func interact_prompt() -> String:
	return "[E]  %s the cabinet" % ("Close" if _open else "Open")


func interact(_player: Node) -> void:
	set_door_open(not _open)


func set_door_open(open: bool, duration := 0.35) -> void:
	_open = open
	if _squeak and not _squeak.playing:
		_squeak.pitch_scale = 1.05 + randf_range(-0.06, 0.06)
		_squeak.play()
	if duration <= 0.0:
		_swing = 1.0 if _open else 0.0
		_apply_swing()


func is_door_open() -> bool:
	return _open


func _apply_swing() -> void:
	if _door:
		var side := 1.0 if hinge_side == "left" else -1.0
		# The far edge must move toward local -Z, the room, for either hand.
		# Reversing this opens a perfectly plausible leaf into the wall.
		var direction := -side
		_door.rotation.y = _swing * DOOR_ANGLE * direction


## World samples through the whole leaf, not just its tip. WalkTest probes
## them against real collision so a door legal by marker footprint cannot
## still carve through the return wall when opened.
func door_sweep_samples() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var side := 1.0 if hinge_side == "left" else -1.0
	var hinge := Vector3(side * W * 0.5, CENTER_Y, -0.060)
	for fraction in [0.25, 0.50, 0.75, 1.0]:
		var angle: float = DOOR_ANGLE * float(fraction) * -side
		var basis := Basis(Vector3.UP, angle)
		for reach in [W * 0.50, W * 0.94]:
			for y in [-H * 0.42, 0.0, H * 0.42]:
				var local := hinge + basis * Vector3(-side * reach, y, -0.015)
				out.append(to_global(local))
	return out


func standing_point() -> Vector3:
	# Feet stand beyond the 0.50 m pedestal basin, not at its waste pipe. The
	# old 0.62 m probe put a torso inside the real ninety-five-degree leaf.
	return to_global(Vector3(0, CENTER_Y - 0.12, -0.82))


func _start_normal_function() -> void:
	state = PState.IDLE
	if warehouse_open:
		set_door_open(true, 0.0)


func _process(delta: float) -> void:
	var want := 1.0 if _open else 0.0
	if is_equal_approx(_swing, want):
		return
	_swing = move_toward(_swing, want, delta * 2.4)
	_apply_swing()
