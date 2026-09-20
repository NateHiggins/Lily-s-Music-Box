extends RefCounted
## Validate before passing a disk record to the preserved state controller.
const State := preload("res://scripts/lamp/lamp_optical_state.gd")
const BOUNDS := {
	"simulation_time_s": [0.0,1.0e12], "supplied_voltage": [0.0,128.0],
	"contact_resistance": [0.0,3.0], "filament_temperature_k": [0.0,5000.0],
	"reflector_alignment": [.88,1.0], "lens_alignment": [.9,1.0],
	"instability": [0.0,1.0], "mechanical_shock": [0.0,1.0],
	"thermal_inertia": [0.0,1.0], "contact_event_remaining_s": [0.0,1.0],
	"contact_event_depth": [0.0,1.0], "limited_intensity": [0.0,1.12],
	"intensity_rate": [-1.46,1.46]}

static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != State.new().save_state().size(): return false
	if typeof(value.get("switched_on")) != TYPE_BOOL: return false
	for key in ["version","seed"]:
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) \
				or float(number) != floorf(float(number)) or absf(float(number)) > 9007199254740991.0: return false
	if int(value.version) != 1: return false
	for key: String in BOUNDS:
		var number: Variant = value.get(key)
		if typeof(number) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(number)) \
				or float(number) < BOUNDS[key][0] or float(number) > BOUNDS[key][1]: return false
	return true
