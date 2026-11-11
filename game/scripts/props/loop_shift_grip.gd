extends Node
## A thing the hand lifts out of the way during a visit (RUL-013): grab it,
## move it, let go. It will not move unless the loop says this is its room and
## its hour. Carried all the way, it reports once; let go short of that, it
## sinks back. `put_back` returns it exactly.

const Manipulation := preload("res://scripts/props/manipulation_area.gd")
const GESTURE_PIXELS := 220.0

var part: Node3D
var axis := Vector3.UP
var reach := 0.15
var travel := 0.0
## False keeps the thing where it is, as any other furniture.
var live := Callable()
## Called once when the thing has been carried its whole reach.
var carried := Callable()
var area: Area3D
var _held := false
var _fired := false
var _origin := Vector3.ZERO
var _shown := true


func configure(moving: Node3D, direction: Vector3, distance: float) -> void:
	part = moving
	axis = direction.normalized()
	reach = distance
	_origin = part.position
	_shown = part.visible
	area = Manipulation.install(part, grip)


func grip() -> Dictionary:
	if part == null or _fired or (live.is_valid() and not bool(live.call())):
		return {}
	return {"owner": self, "part": part, "frame": part.get_parent(), "kind": "slide", "axis": axis,
		"minimum": 0.0, "maximum": reach, "gesture_travel_px": GESTURE_PIXELS, "gesture_screen_axis": Vector2.UP,
		"read": func(): return travel,
		"write": func(value: float):
			if _held:
				move(value),
		"begin": func():
			if _held:
				return false
			_held = true
			return true,
		"owns": func(): return _held,
		"end": func(): _held = false}


func move(value: float) -> void:
	if not is_finite(value) or _fired:
		return
	travel = clampf(value, 0.0, reach)
	part.position = _origin + axis * travel
	if travel >= reach - 0.000001:
		_fired = true
		_held = false
		if carried.is_valid():
			carried.call()


## Set aside: out of the way and out of sight until the room is put back.
func set_aside() -> void:
	part.visible = false


func put_back() -> void:
	travel = 0.0
	_fired = false
	_held = false
	part.position = _origin
	part.visible = _shown


func _physics_process(delta: float) -> void:
	if _held or _fired or travel <= 0.0:
		return
	travel = move_toward(travel, 0.0, delta * 0.3)
	part.position = _origin + axis * travel
