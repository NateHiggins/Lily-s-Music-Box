class_name LampOpticalState
extends RefCounted
## Deterministic electrical/thermal state for the carried 1928 service lamp.
## Inputs are facts; outputs are presentation and sensory observations.

const VERSION := 1
const NOMINAL_VOLTAGE := 110.0
const MAX_STEP_S := 1.0 / 120.0
const CONTACT_PERIOD_S := 7.25
const RAPID_CONTRAST_FLOOR := 0.62

var seed: int = 0x28A11CE
var simulation_time_s := 0.0
var switched_on := true
var supplied_voltage := 0.0
var contact_resistance := 0.18
var filament_temperature_k := 293.0
var reflector_alignment := 0.985
var lens_alignment := 0.98
var instability := 0.0
var mechanical_shock := 0.0
var thermal_inertia := 0.0
var contact_event_remaining_s := 0.0
var contact_event_depth := 0.0
var limited_intensity := 0.0
var intensity_rate := 0.0


func configure(p_seed: int, on := true) -> void:
	seed = p_seed
	switched_on = on
	supplied_voltage = NOMINAL_VOLTAGE if on else 0.0
	filament_temperature_k = 293.0
	limited_intensity = 0.0
	intensity_rate = 0.0


func advance(delta: float, voltage_input := NOMINAL_VOLTAGE,
		shock_input := 0.0) -> void:
	var left := maxf(0.0, delta)
	while left > 0.0:
		var dt := minf(left, MAX_STEP_S)
		_step(dt, voltage_input, shock_input)
		left -= dt


func _step(dt: float, voltage_input: float, shock_input: float) -> void:
	simulation_time_s += dt
	mechanical_shock = maxf(mechanical_shock * exp(-dt * 5.2),
			clampf(shock_input, 0.0, 1.0))
	var drift := _low_frequency_drift(simulation_time_s)
	var requested := clampf(voltage_input, 0.0, 128.0) if switched_on else 0.0
	var sag := 1.0 - 0.055 * drift - 0.16 * mechanical_shock
	supplied_voltage = move_toward(supplied_voltage, requested * sag,
			dt * (310.0 if switched_on else 520.0))
	_update_contact_event(dt)
	var chatter := contact_event_depth * _contact_envelope()
	var target_resistance := 0.18 + 0.20 * maxf(0.0, drift) \
			+ 1.35 * chatter + 0.75 * mechanical_shock
	contact_resistance = lerpf(contact_resistance, target_resistance,
			1.0 - exp(-dt * 18.0))
	var delivered_voltage := supplied_voltage * (0.18 / maxf(0.18, contact_resistance))
	var normalized_power := pow(clampf(delivered_voltage / NOMINAL_VOLTAGE,
			0.0, 1.12), 2.0)
	var target_temperature := 293.0 + 2480.0 * normalized_power
	var thermal_rate := 3.1 if target_temperature > filament_temperature_k else 1.55
	filament_temperature_k = lerpf(filament_temperature_k, target_temperature,
			1.0 - exp(-dt * thermal_rate))
	thermal_inertia = clampf((filament_temperature_k - 293.0) / 2480.0, 0.0, 1.0)
	instability = clampf(0.28 * absf(drift) + chatter + mechanical_shock * 0.55,
			0.0, 1.0)
	reflector_alignment = clampf(0.985 - mechanical_shock * 0.055
			+ 0.006 * _signed_noise(seed ^ 0x51A7), 0.88, 1.0)
	lens_alignment = clampf(0.98 - mechanical_shock * 0.04
			+ 0.004 * _signed_noise(seed ^ 0x1E45), 0.90, 1.0)
	var previous := limited_intensity
	var electrical_output := clampf(supplied_voltage / NOMINAL_VOLTAGE, 0.0, 1.12)
	var raw_intensity := thermal_inertia * thermal_inertia \
			* maxf(electrical_output, thermal_inertia * 0.32) \
			* (1.0 - instability * 0.34)
	# Bound both contrast and frequency in simulation time, independent of render FPS.
	var fall_rate := 1.45 if switched_on else 0.82
	limited_intensity = move_toward(limited_intensity,
			clampf(raw_intensity, 0.0, 1.12), dt * fall_rate)
	intensity_rate = (limited_intensity - previous) / maxf(dt, 0.00001)


func _update_contact_event(dt: float) -> void:
	if contact_event_remaining_s > 0.0:
		contact_event_remaining_s = maxf(0.0, contact_event_remaining_s - dt)
		return
	var event_index := int(floor(simulation_time_s / CONTACT_PERIOD_S))
	var local := fposmod(simulation_time_s, CONTACT_PERIOD_S)
	var trigger := 1.15 + 2.6 * _unit_noise(seed + event_index * 7919)
	if local >= trigger and local < trigger + dt * 1.5:
		contact_event_remaining_s = 0.18 + 0.34 * _unit_noise(seed ^ event_index * 3571)
		contact_event_depth = 0.16 + 0.34 * _unit_noise(seed + event_index * 104729)


func _contact_envelope() -> float:
	if contact_event_remaining_s <= 0.0:
		return 0.0
	# Chatter has three bounded lobes; thermal inertia prevents a strobe.
	var phase := simulation_time_s * 9.0
	return clampf(0.55 + 0.25 * sin(phase * TAU)
			+ 0.20 * sin(phase * 1.7 * TAU + 0.8), 0.0, 1.0)


func output() -> Dictionary:
	var hot := thermal_inertia
	var electrical := clampf(supplied_voltage / NOMINAL_VOLTAGE, 0.0, 1.12)
	var kelvin := lerpf(1250.0, 2850.0, pow(hot, 0.58))
	return {
		"intensity": clampf(limited_intensity, 0.0, 1.12),
		"color": _blackbody_approx(kelvin),
		"color_temperature_k": kelvin,
		"cone_angle_deg": lerpf(41.0, 35.0,
				reflector_alignment * lens_alignment),
		"volumetric_multiplier": lerpf(limited_intensity,
				sqrt(maxf(0.0, limited_intensity)), 0.72),
		"filament_emission": 7.5 * hot * hot,
		"temporal_stability": 1.0 - instability,
		"heat": hot,
	}


func observation(origin: Vector3, direction: Vector3,
		occlusion_confidence := 1.0) -> Dictionary:
	var o := output()
	return {
		"origin": origin,
		"direction": direction.normalized(),
		"incident_intensity": o.intensity,
		"spectral_bands": Vector3(1.0, 0.72, 0.38).lerp(
				Vector3(1.0, 0.86, 0.66), thermal_inertia),
		"temporal_stability": o.temporal_stability,
		"heat_contribution": o.heat * 0.22,
		"occlusion_confidence": clampf(occlusion_confidence, 0.0, 1.0),
		"rate_of_change": absf(intensity_rate),
	}


func apply_mechanical_shock(strength: float) -> void:
	mechanical_shock = maxf(mechanical_shock, clampf(strength, 0.0, 1.0))


func save_state() -> Dictionary:
	return {
		"version": VERSION, "seed": seed, "simulation_time_s": simulation_time_s,
		"switched_on": switched_on, "supplied_voltage": supplied_voltage,
		"contact_resistance": contact_resistance,
		"filament_temperature_k": filament_temperature_k,
		"reflector_alignment": reflector_alignment, "lens_alignment": lens_alignment,
		"instability": instability, "mechanical_shock": mechanical_shock,
		"thermal_inertia": thermal_inertia,
		"contact_event_remaining_s": contact_event_remaining_s,
		"contact_event_depth": contact_event_depth,
		"limited_intensity": limited_intensity, "intensity_rate": intensity_rate,
	}


func restore_state(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != VERSION:
		return false
	seed = int(data.seed)
	simulation_time_s = float(data.simulation_time_s)
	switched_on = bool(data.switched_on)
	supplied_voltage = float(data.supplied_voltage)
	contact_resistance = float(data.contact_resistance)
	filament_temperature_k = float(data.filament_temperature_k)
	reflector_alignment = float(data.reflector_alignment)
	lens_alignment = float(data.lens_alignment)
	instability = float(data.instability)
	mechanical_shock = float(data.mechanical_shock)
	thermal_inertia = float(data.thermal_inertia)
	contact_event_remaining_s = float(data.contact_event_remaining_s)
	contact_event_depth = float(data.contact_event_depth)
	limited_intensity = float(data.get("limited_intensity", 0.0))
	intensity_rate = float(data.get("intensity_rate", 0.0))
	return true


func _low_frequency_drift(t: float) -> float:
	var p0 := _unit_noise(seed ^ 0x7135) * TAU
	var p1 := _unit_noise(seed ^ 0xBEEF) * TAU
	return sin(t * 0.47 + p0) * 0.62 + sin(t * 0.113 + p1) * 0.38


static func _unit_noise(value: int) -> float:
	var x := value & 0x7fffffff
	x = int((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff
	x = int((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff
	x = x ^ (x >> 16)
	return float(x & 0x00ffffff) / float(0x00ffffff)


static func _signed_noise(value: int) -> float:
	return _unit_noise(value) * 2.0 - 1.0


static func _blackbody_approx(kelvin: float) -> Color:
	var t := clampf(kelvin / 100.0, 10.0, 66.0)
	var r := 1.0 if t <= 66.0 else clampf(1.292936 * pow(t - 60.0, -0.133205), 0.0, 1.0)
	var g := clampf((0.390082 * log(t) - 0.631841) if t <= 66.0
			else (1.129891 * pow(t - 60.0, -0.075515)), 0.0, 1.0)
	var b := 0.0 if t <= 19.0 else clampf(0.543207 * log(t - 10.0) - 1.196254, 0.0, 1.0)
	return Color(r, g, b)
