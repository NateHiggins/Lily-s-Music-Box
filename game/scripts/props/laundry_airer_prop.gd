class_name LaundryAirerProp
extends FunctionalProp
## The thing the obsolete dryer marker should always have been: two rinse
## tubs and a ceiling pulley airer. It is one authored ensemble because the
## Matching game moves laundry through all three, and because one merged prop
## is cheaper than teaching three decorative assemblies to agree about state.

const METAL := Color(0.55, 0.56, 0.58)
const WOOD := Color(0.28, 0.20, 0.14)
const BRASS := Color(0.62, 0.48, 0.22)
const LINEN := Color(0.86, 0.85, 0.81)

var _fixed: Node3D
var _rack: Node3D
var _rack_tween: Tween
var _lowered := false
var _settle: AudioStreamPlayer3D


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "laundry / rinse tubs + pulley airer"}]


func _build_visual() -> void:
	_fixed = Node3D.new()
	_fixed.name = "StaticRinseStand"
	add_child(_fixed)
	# Two galvanized tubs: wash comes through the wringer into rinse one,
	# through it again into rinse two, then up. Open shells, never grey boxes.
	for cx in [-0.32, 0.32]:
		for z in [-0.245, 0.245]:
			_box(_fixed, Vector3(0.59, 0.36, 0.028),
					Vector3(cx, 0.61, z), METAL)
		for xoff in [-0.285, 0.285]:
			_box(_fixed, Vector3(0.028, 0.36, 0.47),
					Vector3(cx + xoff, 0.61, 0), METAL)
		_box(_fixed, Vector3(0.56, 0.025, 0.47),
				Vector3(cx, 0.44, 0), METAL)
		for xoff in [-0.25, 0.25]:
			for zoff in [-0.20, 0.20]:
				_box(_fixed, Vector3(0.045, 0.43, 0.045),
						Vector3(cx + xoff, 0.215, zoff), WOOD)
		# Oval-ish rolled lip from four inexpensive straight lengths.
		for z in [-0.265, 0.265]:
			_box(_fixed, Vector3(0.62, 0.03, 0.035),
					Vector3(cx, 0.80, z), METAL)
		for xoff in [-0.305, 0.305]:
			_box(_fixed, Vector3(0.035, 0.03, 0.50),
					Vector3(cx + xoff, 0.80, 0), METAL)
	# Shared drain cock and floor tail make the pair part of the room's water
	# work, not two basins placed from a furniture catalogue.
	for cx in [-0.32, 0.32]:
		var tail := _cyl(_fixed, 0.025, 0.025, 0.26,
				Vector3(cx, 0.31, 0.20), BRASS)
		tail.rotation_degrees.x = 90.0
		_box(_fixed, Vector3(0.12, 0.018, 0.022),
				Vector3(cx, 0.31, 0.345), BRASS)

	# Ceiling tackle remains fixed; the wood-lath rack and its damp evidence
	# travel together. At its normal height a 1.41 m player sees beneath it.
	for x in [-0.52, 0.52]:
		_cyl(_fixed, 0.055, 0.055, 0.045, Vector3(x, 2.42, 0), METAL)
		_box(_fixed, Vector3(0.12, 0.07, 0.16),
				Vector3(x, 2.44, 0), METAL)
	_box(_fixed, Vector3(0.06, 0.30, 0.10), Vector3(0.72, 1.15, 0.26), WOOD)
	for y in [1.06, 1.15, 1.24]:
		_cyl(_fixed, 0.010, 0.010, 0.16, Vector3(0.72, y, 0.20), BRASS)

	_rack = Node3D.new()
	_rack.name = "PulleyAirer"
	_rack.position.y = 1.98
	add_child(_rack)
	for z in [-0.22, -0.11, 0.0, 0.11, 0.22]:
		_box(_rack, Vector3(1.14, 0.035, 0.045), Vector3(0, 0, z), WOOD)
	for x in [-0.56, 0.56]:
		_box(_rack, Vector3(0.05, 0.12, 0.56), Vector3(x, 0.015, 0), METAL)
		# Rope is kept chunky enough to survive the basement light.
		_cyl(_rack, 0.009, 0.009, 0.43, Vector3(x, 0.23, 0), LINEN)
	# A few anonymous pieces make the Matching game's subject visible without
	# turning the airer into a curtain that hides its own mechanism.
	_box(_rack, Vector3(0.32, 0.34, 0.018), Vector3(-0.31, -0.19, -0.12), LINEN)
	_box(_rack, Vector3(0.20, 0.24, 0.018), Vector3(0.20, -0.14, 0.11), LINEN)
	_box(_rack, Vector3(0.12, 0.18, 0.018), Vector3(0.43, -0.11, -0.11), LINEN)

	retexture(self, [
		# These tubs and fittings are dull galvanised steel.  The zinc response
		# lets their form survive the basement's grazing light; generic metal
		# reflected the room away and made the whole rinse station read black.
		[METAL, "zinc_liner", Color(0.80, 0.82, 0.80), 0.72],
		[WOOD, "wood_dark", Color(0.74, 0.64, 0.50), 0.50],
		[BRASS, "brass_dull", Color(0.74, 0.67, 0.48), 0.70],
		[LINEN, "linen", Color(0.83, 0.80, 0.72), 0.45],
	])
	merge_static(_fixed)
	merge_static(_rack)

	var body := StaticBody3D.new()
	body.name = "RinseTubCollision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.24, 0.82, 0.58)
	collision.shape = shape
	collision.position = Vector3(0, 0.41, 0)
	body.add_child(collision)
	add_child(body)
	_service_area("RinseReach", Vector3(0, 0.80, -0.42), Vector3(1.24, 0.36, 0.34))
	_service_area("AirerReach", Vector3(0.72, 1.20, -0.10), Vector3(0.35, 0.55, 0.50))
	_settle = make_emitter("tick", -24.0)


func _start_normal_function() -> void:
	state = PState.IDLE


func set_airer_lowered(lowered: bool, duration := 0.55) -> void:
	_lowered = lowered
	if _rack_tween and _rack_tween.is_valid():
		_rack_tween.kill()
	var target := 1.38 if lowered else 1.98
	if duration <= 0.0:
		_rack.position.y = target
		return
	_rack_tween = create_tween()
	_rack_tween.tween_property(_rack, "position:y", target, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func set_service_pose() -> void:
	set_airer_lowered(true, 0.0)


func is_airer_lowered() -> bool:
	return _lowered


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	# The rack settles one centimetre without being commanded. At low infection
	# it is exactly the kind of movement a player can blame on wet rope.
	_settle.volume_db = -27.0 + linear_to_db(clampf(accent, 0.3, 1.0))
	_settle.play()
	var target := _rack.position.y - 0.012
	var tween := create_tween()
	tween.tween_property(_rack, "position:y", target, 0.10)
	tween.tween_property(_rack, "position:y",
			1.38 if _lowered else 1.98, 0.45)


func _service_area(area_name: String, at: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = area_name
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	area.add_child(collision)
	add_child(area)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _pmat(color, 0.62, 0.16)
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, height, at, color, 0.62, 0.16, parent)
