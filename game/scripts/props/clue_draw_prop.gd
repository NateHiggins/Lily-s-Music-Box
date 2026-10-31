extends Node3D
## A part the hand draws out to find something: a notebook off a stack, a plug out of a
## drain. It won't move before its date, and it goes back when let go. Drawing it all the
## way out the first time grants its flag and prints what was found.

const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const GESTURE_PIXELS := 220.0

var part: Node3D
var axis := Vector3.BACK
var reach := 0.1
var from_date := ""
var flag := ""
var note: Dictionary = {}
var goods: Dictionary = {}
var travel := 0.0
var _held := false
var _origin := Vector3.ZERO
var _clock := CampaignClock.new()


func configure(moving: Node3D) -> void:
	part = moving
	_origin = part.position
	Manipulation.install(part, grip)


func due() -> bool:
	if from_date == "":
		return true
	if not _clock.bind_state():
		return false
	var local := _clock.local_datetime()
	return not local.is_empty() and "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)] >= from_date


func grip() -> Dictionary:
	if part == null or not due():
		return {}
	return {"owner": self, "part": part, "frame": self, "kind": "slide", "axis": axis,
		"minimum": 0.0, "maximum": reach, "gesture_travel_px": GESTURE_PIXELS, "gesture_screen_axis": Vector2.DOWN,
		"read": func(): return travel,
		"write": func(value: float):
			if _held:
				_move(value),
		"begin": func():
			if _held:
				return false
			_held = true
			return true,
		"owns": func(): return _held,
		"end": func(): _held = false}


func _move(value: float) -> void:
	if not is_finite(value):
		return
	travel = clampf(value, 0.0, reach)
	part.position = _origin + axis * travel
	if travel >= reach - 0.000001:
		_found()


func _found() -> void:
	if flag == "" or not RealityState.grant_knowledge(flag):
		return
	if not goods.is_empty():
		PersonInventory.carry_goods(PersonInventory.PLAYER, str(goods.id), str(goods.name), str(goods.form))
	RealityState.commit()
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player != null and not note.is_empty():
		player.present_service_note(self, note)


func _physics_process(delta: float) -> void:
	if _held or travel <= 0.0:
		return
	travel = move_toward(travel, 0.0, delta * 0.16)
	part.position = _origin + axis * travel
