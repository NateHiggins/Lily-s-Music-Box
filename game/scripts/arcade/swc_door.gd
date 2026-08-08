class_name SwcDoor
extends Node

## An interactive door.
##
## Every number here comes from the semantic scene: the hinge position, which side
## it swings, how far, how long it takes. A World Package can make this a carved
## marble slab, a pressure hatch or a curtain of glowing organisms; it cannot
## change any of the above, and the aperture it leaves behind stays the same width.

signal state_changed(is_open: bool)

var entity: SwcEntity
var open_angle_deg: float = 95.0
var open_time_s: float = 0.9
var locked: bool = false

var _is_open: bool = false
var _progress: float = 0.0
var _swing_sign: float = 1.0
var _pivot: Node3D


func configure(owner_entity: SwcEntity) -> void:
	entity = owner_entity
	_pivot = owner_entity.motion_root
	open_angle_deg = float(owner_entity.param("open_angle_deg", 95.0))
	open_time_s = maxf(0.05, float(owner_entity.param("open_time_s", 0.9)))
	locked = bool(owner_entity.param("locked", false))
	_swing_sign = -1.0 if String(owner_entity.param("hinge_side", "left")) == "right" else 1.0
	_is_open = bool(owner_entity.param("starts_open", false))
	_progress = 1.0 if _is_open else 0.0
	_apply()


func interact(_by: Node) -> bool:
	if locked:
		return false
	_is_open = not _is_open
	entity.play_sound("move")
	state_changed.emit(_is_open)
	return true


func prompt() -> String:
	if locked:
		return "Locked"
	return "Close" if _is_open else "Open"


func is_open() -> bool:
	return _is_open


func _process(delta: float) -> void:
	var target := 1.0 if _is_open else 0.0
	if is_equal_approx(_progress, target):
		return
	var step := delta / open_time_s
	_progress = move_toward(_progress, target, step)
	_apply()


func _apply() -> void:
	if _pivot == null:
		return
	# Smoothstep so the swing reads as weight rather than as a linear lerp.
	var eased := _progress * _progress * (3.0 - 2.0 * _progress)
	_pivot.rotation_degrees.y = open_angle_deg * _swing_sign * eased
