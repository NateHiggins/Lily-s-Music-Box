extends DoorProp
## The retained 700 mm WC opening needs the leaf past the clear jamb line.
## Keep its hinge, width, collision, input and existing motion owner.

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-145.0 if swing_out else 145.0) if want_open else 0.0
