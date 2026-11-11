extends "res://scripts/props/domestic_witness_clock.gd"
## A witness clock in V2: the V1 clock keeps the time, the haunt, the tells,
## the restore and the inspection; this replaces only its procedural case and
## printed dial with the Blender-authored assembly for its style, and points
## V1's hands, face rig, tell and reading at the native parts.
const Native := preload("res://scripts/building/orison_v2_native_witness_clocks.gd")
const READING_STYLES := ["nixie", "split_flap", "writer", "travel_alarm"]

var native: RefCounted
## The waking organism finds a flat's beachhead by this property
## (apartment_encroachment.gd _find_beachhead).
var case_ids: Array = []
var _spec: Dictionary = {}
var _numerals: Array[Label3D] = []
var _odd: Node3D
var _odd_home := Transform3D.IDENTITY
var _odd_wrong := Transform3D.IDENTITY


func configure(spec: Dictionary) -> void:
	super.configure(spec)
	case_ids = [case_id]


func _build_visual() -> void:
	_face = Node3D.new()
	_face.name = "FaceRig"
	add_child(_face)
	if native == null:
		native = Native.new()
	var mounted: Dictionary = native.mount_on(self, style, accent, _face) if native.prepare() else {}
	if mounted.is_empty():
		push_error("V2 witness clock stock refused: %s (%s)" % [case_id, style])
		_tell_mark = Node3D.new()
		add_child(_tell_mark)
		_display = Label3D.new()
		_face.add_child(_display)
	else:
		_spec = mounted.spec
		var pivots: Dictionary = mounted.pivots
		_hour = pivots.get("HourHand")
		_minute = pivots.get("MinuteHand")
		_second = pivots.get("SecondHand")
		_tell_mark = pivots.get("TellMark")
		_numerals = mounted.numerals
		_display = mounted.display
		_odd = pivots.get("OddMark")
		_prepare_odd_mark()
	_tell_mark.visible = false
	# The reading is V1's: accent ink with a dark edge, shown on the four
	# figure-reading styles and only during a tell on the others.
	_display.modulate = accent.lightened(0.18)
	_display.outline_size = 8
	_display.outline_modulate = Color(0, 0, 0, 0.85)
	_display.text = frozen_time if style in READING_STYLES else ""
	if _hour != null:
		_set_hand_time(frozen_time)
	_build_collision()
	_tick = make_emitter("tick", -31.0)
	_tick.max_distance = 5.5
	_inspect_tap = make_emitter("tick", -20.0)
	_inspect_tap.max_distance = 3.2


## V1 swapped the printed dial for a twin with one detail moved. Here the
## detail is a real part or numeral: the builder names it and where it goes.
func _prepare_odd_mark() -> void:
	var wrong: Dictionary = _spec.get("possessed", {})
	if _odd == null or str(wrong.get("kind", "")) != "part":
		return
	_odd_home = _odd.transform
	var centre: Array = _spec.dial_center
	var angle := deg_to_rad(float(wrong.angle_deg))
	var radius := float(wrong.radius)
	_odd_wrong = Transform3D(
			Basis(Vector3.BACK, -deg_to_rad(float(wrong.spin_deg))) * _odd_home.basis,
			Vector3(float(centre[0]) + sin(angle) * radius, float(centre[1]) + cos(angle) * radius,
				_odd_home.origin.z))


func _set_dial_possessed(wrong: bool) -> void:
	var detail: Dictionary = _spec.get("possessed", {})
	match str(detail.get("kind", "")):
		"part":
			if _odd != null:
				_odd.transform = _odd_wrong if wrong else _odd_home
		"label":
			var index := int(detail.index)
			if index < _numerals.size():
				_numerals[index].text = str(detail.text) if wrong \
						else str(_spec.labels[index].text)


## True while the dial shows its wrong detail (styles V1 gave a printed dial).
func dial_possessed() -> bool:
	var detail: Dictionary = _spec.get("possessed", {})
	match str(detail.get("kind", "")):
		"part":
			return _odd != null and not _odd.transform.is_equal_approx(_odd_home)
		"label":
			var index := int(detail.index)
			return index < _numerals.size() and _numerals[index].text == str(detail.text)
	return false


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WitnessBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var extent := Native.bounds(_spec) if not _spec.is_empty() \
			else AABB(Vector3(-0.22, -0.17, 0.0), Vector3(0.44, 0.34, 0.08))
	box.size = extent.size
	shape.shape = box
	shape.position = extent.get_center()
	body.add_child(shape)
	add_child(body)
