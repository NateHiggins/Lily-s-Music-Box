class_name FortuneAnswerProp
extends FunctionalProp
## A 1927 coin-controlled YES/NO answering head.
##
## Mechanism: John J. Scharli Jr., US 1,621,756 (filed 1925, granted 1927).
## A coin takes one of two troughs, its weight closes a leaf switch and one of
## two electromagnets positions a common striker. The hand plunger then strikes
## the selected pendulum, nodding or shaking the head. This object knows no
## question and owns no consequence; it publishes only what its visible iron
## just did.

signal answer_given(record: Dictionary)

const ANSWER_FIELDS := ["answer", "coin_path", "powered", "sequence"]
const REST_ROTATION := Vector3.ZERO
const YES_ROTATION := Vector3(-0.24, 0.0, 0.0)
const NO_ROTATION := Vector3(0.0, 0.34, 0.0)

var coin_loaded := false
var selected_path := ""
var sequence := 0
var last_answer := ""
var powered := true
var _head: Node3D
var _coin: MeshInstance3D
var _yes_plunger: Node3D
var _no_plunger: Node3D
var _handle: Node3D
var _plug: Node3D
var _striker: Node3D
var _balk_left := 0.0


func _process(delta: float) -> void:
	_balk_left = maxf(0.0, _balk_left - delta)
	if _balk_left <= 0.0 and _handle != null:
		_handle.rotation.z = 0.0


func load_coin(path: String) -> bool:
	if coin_loaded or not path in ["YES", "NO"]:
		_balk_left = 1.0
		return false
	coin_loaded = true
	selected_path = path
	_refresh()
	return true


func set_powered(value: bool) -> void:
	powered = value
	_refresh()


func work_machine() -> Dictionary:
	if not coin_loaded:
		_balk_left = 1.0
		if _handle != null:
			_handle.rotation.z = -0.22
		_refresh()
		return {"accepted": false, "reason": "NO COIN IN RACE"}
	if not powered:
		_balk_left = 1.0
		if _handle != null:
			_handle.rotation.z = -0.22
		_refresh()
		return {"accepted": false, "reason": "NO CURRENT AT MAGNETS"}
	sequence += 1
	var answer := selected_path
	last_answer = answer
	coin_loaded = false
	selected_path = ""
	_refresh_answer(answer)
	var record := {"answer": answer, "coin_path": answer,
			"powered": powered, "sequence": sequence}
	answer_given.emit(record.duplicate(true))
	return {"accepted": true, "answer": answer, "record": record}


func interact(_player: Node = null) -> Dictionary:
	if not coin_loaded:
		load_coin("YES" if sequence % 2 == 0 else "NO")
		return {"accepted": true, "action": "COIN SET IN %s RACE" % selected_path}
	return work_machine()


func interact_prompt() -> String:
	return "Work the answering head" if coin_loaded else "Set a penny in the race"


func balking() -> bool:
	return _balk_left > 0.0


func mechanism_snapshot() -> Dictionary:
	return {"coin_loaded": coin_loaded, "selected_path": selected_path,
			"sequence": sequence, "last_answer": last_answer,
			"powered": powered}


func restore_mechanism_snapshot(snapshot: Dictionary) -> void:
	coin_loaded = bool(snapshot.get("coin_loaded", false))
	selected_path = str(snapshot.get("selected_path", ""))
	sequence = int(snapshot.get("sequence", 0))
	last_answer = str(snapshot.get("last_answer", ""))
	powered = bool(snapshot.get("powered", true))
	_balk_left = 0.0
	if _head != null:
		_head.rotation = YES_ROTATION if last_answer == "YES" else (
				NO_ROTATION if last_answer == "NO" else REST_ROTATION)
	if _handle != null:
		_handle.rotation.z = 0.0
	_refresh()


func _build_visual() -> void:
	name = "OrisonFortuneAnswer"
	var iron := Color("#20201d")
	var enamel := Color("#ded1aa")
	var brass := Color("#8c692f")
	make_box(Vector3(0.68, 1.48, 0.34), Vector3(0, 0.74, 0), iron)
	make_box(Vector3(0.59, 0.08, 0.035), Vector3(0, 1.39, 0.19), brass)
	_label("THE HOUSE ANSWERS", Vector3(0, 1.39, 0.214), 0.055, enamel)
	_head = Node3D.new()
	_head.name = "AnsweringHead"
	_head.position = Vector3(0, 1.02, 0.22)
	add_child(_head)
	var face := make_cyl(0.18, 0.18, 0.12, Vector3.ZERO, enamel, 0.75, 0.0, _head)
	face.rotation.x = PI * 0.5
	make_box_under(_head, Vector3(0.22, 0.035, 0.04), Vector3(0, 0.045, -0.07), iron)
	make_box_under(_head, Vector3(0.12, 0.025, 0.035), Vector3(-0.07, -0.025, -0.075), iron)
	make_box_under(_head, Vector3(0.12, 0.025, 0.035), Vector3(0.07, -0.025, -0.075), iron)
	_label("YES", Vector3(-0.18, 0.70, 0.202), 0.075, enamel)
	_label("NO", Vector3(0.18, 0.70, 0.202), 0.075, enamel)
	_yes_plunger = _race(-0.17, brass)
	_no_plunger = _race(0.17, brass)
	# Scharli's common striker rests between the two pendulums. The weighted
	# trough and magnet move this ONE part toward the selected side; working
	# the plunger returns it to the visible neutral gap.
	_striker = Node3D.new()
	_striker.name = "CommonStriker"
	_striker.position = Vector3(0, 0.61, 0.255)
	add_child(_striker)
	make_box_under(_striker, Vector3(0.16, 0.025, 0.030), Vector3.ZERO,
			Color("#b6aa8e"))
	for x in [-0.105, 0.105]:
		var magnet := make_cyl(0.042, 0.042, 0.095,
				Vector3(x, 0.61, 0.235), Color("#4b2a20"), 0.62, 0.2)
		magnet.name = "SelectorMagnet"
		magnet.rotation.z = PI * 0.5
	_handle = Node3D.new()
	_handle.name = "OperatingHandle"
	_handle.position = Vector3(0.28, 0.47, 0.235)
	add_child(_handle)
	make_box_under(_handle, Vector3(0.045, 0.25, 0.045),
			Vector3(0, -0.09, 0), brass)
	make_cyl(0.045, 0.045, 0.10, Vector3(0, -0.23, 0),
			Color("#1a1712"), 0.7, 0.0, _handle)
	_label("ONE CENT / ASK PLAIN", Vector3(0, 0.20, 0.202), 0.045, enamel)
	_label("CURRENT", Vector3(-0.22, 0.16, 0.202), 0.035, enamel)
	var socket := make_box(Vector3(0.10, 0.10, 0.045),
			Vector3(-0.22, 0.08, 0.195), iron)
	socket.name = "PowerSocket"
	_plug = Node3D.new()
	_plug.name = "PowerPlug"
	add_child(_plug)
	make_box_under(_plug, Vector3(0.075, 0.060, 0.055), Vector3.ZERO, brass)
	make_box_under(_plug, Vector3(0.012, 0.070, 0.012),
			Vector3(-0.018, 0.055, 0), Color("#b79852"))
	make_box_under(_plug, Vector3(0.012, 0.070, 0.012),
			Vector3(0.018, 0.055, 0), Color("#b79852"))
	_coin = make_cyl(0.035, 0.035, 0.008, Vector3(0, 0.49, 0.225),
			Color("#9b622f"), 0.4, 0.75)
	_coin.rotation.x = PI * 0.5
	_refresh()


func make_box_under(parent: Node3D, size: Vector3, offset: Vector3,
		color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = _pmat(color)
	parent.add_child(mesh)
	return mesh


func _race(x: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "YesPlunger" if x < 0.0 else "NoPlunger"
	pivot.position = Vector3(x, 0.54, 0.215)
	add_child(pivot)
	make_box_under(pivot, Vector3(0.055, 0.30, 0.025), Vector3.ZERO, color)
	for i in 4:
		make_box_under(pivot, Vector3(0.045, 0.018, 0.032),
				Vector3((0.025 if i % 2 == 0 else -0.025), -0.11 + i * 0.073, 0.01),
				Color("#d7bd75"))
	return pivot


func _label(text: String, pos: Vector3, size: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = size / 64.0
	label.modulate = color
	label.position = pos
	label.outline_size = 0
	add_child(label)


func _refresh_answer(answer: String) -> void:
	if _head == null:
		return
	_head.rotation = YES_ROTATION if answer == "YES" else NO_ROTATION
	_refresh()


func _refresh() -> void:
	if _coin != null:
		_coin.visible = coin_loaded
		_coin.position.x = -0.17 if selected_path == "YES" else 0.17 if selected_path == "NO" else 0.0
	if _yes_plunger != null:
		_yes_plunger.position.z = 0.235 if selected_path == "YES" else 0.215
	if _no_plunger != null:
		_no_plunger.position.z = 0.235 if selected_path == "NO" else 0.215
	if _striker != null:
		_striker.position.x = (-0.060 if selected_path == "YES" else (
				0.060 if selected_path == "NO" else 0.0))
	var socket := find_child("PowerSocket", true, false) as MeshInstance3D
	if socket != null:
		socket.material_override = _pmat(
				Color("#6f5a2b") if powered else Color("#181713"), 0.65, 0.3)
	if _plug != null:
		_plug.position = Vector3(-0.22, 0.08, 0.235) if powered \
				else Vector3(-0.30, 0.015, 0.24)
		_plug.rotation.z = 0.0 if powered else -0.75
