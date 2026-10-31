extends Node3D
## The carriage on the Keys Cut bench. With a blank paid for, the hand draws it past the
## wheel from one stop to the other, and the spare is cut. DoorKeyring makes the key. A
## partial pass cuts nothing, and the carriage springs back. The bench is shut with the
## arcade, so a closed shop can't cut.

const Library := preload("res://scripts/props/fire_maintenance_stock_library.gd")
const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const TRAVEL := 0.12
const GESTURE_PIXELS := 220.0

var carriage: Node3D
var hours: Node
var travel := 0.0
var _held := false
var _cut_this_pass := false
var _origin := Vector3.ZERO
var _tag: Label3D


func configure(shop_hours: Node) -> bool:
	var stock := Library.new()
	if not stock.load_stock():
		return false
	hours = shop_hours
	carriage = Node3D.new()
	carriage.name = "Carriage"
	add_child(carriage)
	stock.draw(carriage, "TerminalLever")
	_origin = carriage.position
	Manipulation.install(carriage, grip)
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.font = FONT
	_tag.font_size = 40
	_tag.pixel_size = 0.016 / 40.0
	_tag.position = Vector3(0.06, 0.125, -0.03)
	_tag.rotation.y = PI
	_tag.outline_size = 8
	_tag.outline_modulate = Color(.04, .025, .015)
	_tag.modulate = Color(.84, .8, .68)
	add_child(_tag)
	refresh()
	return true


func refresh() -> void:
	var waiting := KeysSales.waiting()
	_tag.text = "BLANK: %s" % waiting[0] if not waiting.is_empty() else ""


func _closed() -> bool:
	return hours != null and is_instance_valid(hours) and hours.has_method("is_after_hours") and bool(hours.call("is_after_hours"))


func grip() -> Dictionary:
	refresh()
	if carriage == null or KeysSales.waiting().is_empty() or _closed():
		return {}
	return {"owner": self, "part": carriage, "frame": self, "kind": "slide", "axis": Vector3.RIGHT,
		"minimum": 0.0, "maximum": TRAVEL, "gesture_travel_px": GESTURE_PIXELS, "gesture_screen_axis": Vector2.LEFT,
		"read": func(): return travel,
		"write": func(value: float):
			if _held:
				_move(value),
		"begin": func():
			if _held:
				return false
			_held = true
			_cut_this_pass = false
			return true,
		"owns": func(): return _held,
		"end": func(): _held = false}


func _move(value: float) -> void:
	if not is_finite(value):
		return
	travel = clampf(value, 0.0, TRAVEL)
	carriage.position = _origin + Vector3.RIGHT * travel
	if travel >= TRAVEL - 0.000001 and not _cut_this_pass:
		_cut_this_pass = true
		_finish_cut()


func _finish_cut() -> void:
	var waiting := KeysSales.waiting()
	if waiting.is_empty():
		return
	var unit := str(waiting[0])
	if not DoorKeyring.make_copy(unit):
		return
	KeysSales.book().paid.erase(unit)
	RealityState.commit()
	refresh()
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player != null:
		player.present_service_note(self, {"title": "KEYS CUT", "body": "SPARE FOR %s ON YOUR RING" % unit,
			"condition": "CUT", "stamp": "COUNTER COPY"})


func _physics_process(delta: float) -> void:
	if _held or travel <= 0.0:
		return
	travel = move_toward(travel, 0.0, delta * 0.10)
	carriage.position = _origin + Vector3.RIGHT * travel
