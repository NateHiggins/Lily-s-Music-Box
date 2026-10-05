extends DoorProp
## The retained vestibule jamb admits a quarter-turn leaf, not an overtravel.

func _ready() -> void:
	super._ready()
	if open: _body.rotation.y=motion_target_angle(true)

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-90.0 if swing_out else 90.0) if want_open else 0.0
