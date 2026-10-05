class_name OrisonV2FittedDoor
extends DoorProp
## Retained room jambs admit a quarter turn. Roof weather owners keep 100 degrees.
var open_stop_degrees := 90.0

func _ready() -> void:
	super._ready()
	if open:
		_body.sync_to_physics=false
		_body.rotation.y=motion_target_angle(true)
		_body.force_update_transform()
		_body.sync_to_physics=true

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-open_stop_degrees if swing_out else open_stop_degrees) if want_open else 0.0
