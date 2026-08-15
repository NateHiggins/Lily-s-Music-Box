class_name LampProp
extends FunctionalProp
## Five task lamps, and not one of them is the same object.
##
## This was a single articulated shape used by all five owners, which put a
## sprung mid-century desk lamp on a 1927 architect's drafting table and gave
## the building's best reading corner the same tin shade as the flat the
## landlord furnished. The silhouette is now the characterisation: what a
## person has a lamp *for* is most of what you learn from their desk.
##
## Rule of Signal: a lamp carries no signal, so every one of these is 1927 and
## second-hand and probably a bit broken (§VIII.2, §VIII.6). None of them is
## advanced. Nadia's is merely *new*, which is its own kind of statement, and
## Accord 9 marks it anyway.
##
## A hand-reachable lamp owns its own key switch.  Room plates still own fixed
## fixtures; this local contact only interrupts the task lamp and survives the
## LightRig's budget passes.

## Set from the marker before `_ready()`. Every marker carries one explicitly;
## the fallback is the cheap one, because an unmarked lamp in this building is
## a lamp nobody chose.
@export var variant := "landlord_enamel"

var light: SpotLight3D

var _base_energy := 1.1
var _target_scale := 1.0
var _phase := 0.0
var _drift_depth := 0.015
var _drift_speed := 0.71
var _spec: Dictionary = {}
var _local_enabled := true
var _switch_key: Node3D
var _switch_click: AudioStreamPlayer3D
var _switch_tween: Tween
## Where the bulb actually ended up, filled in by the articulated builds. The
## upright shades leave it at zero and fall back to the spec.
var _head := Vector3.ZERO

## Per silhouette: the light's height, how far it leans over the work, the cone
## it throws and its warmth. A deep steel bench shade is a tight hot circle; a
## cased-glass reading lamp is a wide soft one.
const _SPECS := {
	"emeralite": {
		"height": 0.40, "reach": 0.10, "angle": 62.0, "range": 4.2,
		"tone": Color(1.0, 0.87, 0.62), "gain": 1.05,
		"label": "emeralite · the good reading lamp",
	},
	"office_green": {
		"height": 0.33, "reach": 0.08, "angle": 55.0, "range": 3.6,
		"tone": Color(1.0, 0.85, 0.60), "gain": 0.95,
		"label": "office green · squared to the desk",
	},
	"bench_friction": {
		"height": 0.62, "reach": 0.34, "angle": 38.0, "range": 4.8,
		"tone": Color(1.0, 0.93, 0.78), "gain": 1.35,
		"label": "friction joint · the bench lamp",
	},
	"landlord_enamel": {
		"height": 0.42, "reach": 0.16, "angle": 48.0, "range": 3.8,
		"tone": Color(1.0, 0.80, 0.55), "gain": 0.88,
		"label": "stamped enamel · landlord supplied",
	},
	"architect_counterweight": {
		"height": 0.70, "reach": 0.40, "angle": 44.0, "range": 5.0,
		"tone": Color(1.0, 0.90, 0.72), "gain": 1.20,
		"label": "buquet pattern · counterweighted",
	},
}

const _BRASS := Color(0.62, 0.50, 0.24)
const _NICKEL := Color(0.72, 0.74, 0.76)
const _IRON := Color(0.19, 0.19, 0.20)
const _BAKELITE := Color(0.11, 0.09, 0.08)
const _GREEN_GLASS := Color(0.16, 0.34, 0.22)
const _CORD := Color(0.30, 0.26, 0.22)


## Everything the variant implies. Split out because the prop warehouse builds a
## display by constructing the script and *setting properties* - it never calls
## a setup method, so anything derived only on a marker path shows an empty
## plinth in the inspection shed.
func _derive() -> void:
	if not _SPECS.has(variant):
		push_warning("LampProp: unknown variant '%s'; falling back" % variant)
		variant = "landlord_enamel"
	_spec = _SPECS[variant]


func _build_visual() -> void:
	_derive()
	var seed := absi(str(name).hash())
	_phase = float(seed & 4095) * 0.013
	_base_energy = 1.1 * float(_spec["gain"]) * lerpf(0.90, 1.08,
			float((seed >> 8) & 1023) / 1023.0)
	_drift_depth = lerpf(0.006, 0.022,
			float((seed >> 18) & 255) / 255.0)

	match variant:
		"emeralite": _build_emeralite()
		"office_green": _build_office_green()
		"bench_friction": _build_bench_friction()
		"architect_counterweight": _build_architect()
		_: _build_landlord()

	_build_key_switch()
	# The body never articulates during play.  Keep the key independent, but
	# repay its one moving draw by batching every unchanged finish beneath it.
	merge_static(_switch_key)
	merge_static(self, [_switch_key])
	_install_light(seed)
	_switch_click = make_emitter("tick", -20.0)
	add_to_group("floor_lights")


# ------------------------------------------------------------------ silhouettes


## Cased green glass on brass. The nicest object in the basement, and house
## property — somebody carried it down there on purpose.
func _build_emeralite() -> void:
	make_cyl(0.085, 0.095, 0.022, Vector3(0, 0.011, 0), _BRASS, 0.35, 0.75)
	make_cyl(0.030, 0.030, 0.020, Vector3(0, 0.032, 0), _BRASS, 0.3, 0.8)
	make_cyl(0.011, 0.011, 0.30, Vector3(0, 0.19, 0), _BRASS, 0.28, 0.8)
	# The shade is a half-cylinder of cased glass; a box reads as one at this
	# size and costs a fraction of a lathe.
	var shade := make_box(Vector3(0.26, 0.075, 0.13), Vector3(0, 0.375, 0),
			_GREEN_GLASS)
	var glass := shade.material_override as StandardMaterial3D
	glass.roughness = 0.18
	glass.metallic = 0.0
	# Brass rim: the edge you actually see against the glass.
	make_box(Vector3(0.268, 0.010, 0.138), Vector3(0, 0.338, 0), _BRASS)
	_socket_and_cord(Vector3(0, 0.345, 0), true)


## The same idea, smaller and squarer, because she squares everything.
func _build_office_green() -> void:
	make_cyl(0.070, 0.078, 0.020, Vector3(0, 0.010, 0), _BRASS, 0.35, 0.7)
	make_cyl(0.010, 0.010, 0.24, Vector3(0, 0.150, 0), _BRASS, 0.28, 0.8)
	var shade := make_box(Vector3(0.20, 0.062, 0.105), Vector3(0, 0.300, 0),
			_GREEN_GLASS)
	(shade.material_override as StandardMaterial3D).roughness = 0.18
	make_box(Vector3(0.207, 0.009, 0.112), Vector3(0, 0.271, 0), _BRASS)
	_socket_and_cord(Vector3(0, 0.278, 0), true)


## Faries / O.C. White pattern: a cast-iron foot, two arms and the big knurled
## friction knuckles that are the whole point of the object. It reaches the work
## from the corner of the bench, which is why it lives in the corner.
func _build_bench_friction() -> void:
	make_cyl(0.098, 0.110, 0.030, Vector3(0, 0.015, 0), _IRON, 0.55)
	make_cyl(0.036, 0.040, 0.045, Vector3(0, 0.052, 0), _IRON, 0.5)

	var hip := Vector3(0, 0.080, 0)
	_friction_knuckle(hip)
	var elbow := _strut(hip, 26.0, 0.30, 0.011, _NICKEL, 0.34)
	_friction_knuckle(elbow)
	var wrist := _strut(elbow, -34.0, 0.28, 0.010, _NICKEL, 0.34)
	_friction_knuckle(wrist)

	# Deep spun shade hanging off the wrist, tipped down at the work.
	var shade := make_cyl(0.030, 0.115, 0.150,
			wrist + Vector3(0.012, -0.062, 0), Color(0.22, 0.23, 0.22), 0.42)
	shade.rotation_degrees = Vector3(0, 0, 8)
	var rim := make_cyl(0.116, 0.116, 0.008,
			wrist + Vector3(0.022, -0.132, 0), _NICKEL, 0.3, 0.6)
	rim.rotation_degrees = Vector3(0, 0, 8)
	_socket_and_cord(wrist + Vector3(0.0, -0.020, 0), false)
	_head = wrist + Vector3(0.016, -0.100, 0)


## Whatever the last superintendent left behind. One joint, a stamped shade,
## and a repaint that did not go all the way into the crimp.
func _build_landlord() -> void:
	var paint := Color(0.17, 0.18, 0.16)
	make_cyl(0.072, 0.082, 0.018, Vector3(0, 0.009, 0), paint, 0.45)
	make_cyl(0.052, 0.066, 0.016, Vector3(0, 0.026, 0), paint, 0.45)

	var hip := Vector3(0, 0.034, 0)
	var elbow := _strut(hip, 14.0, 0.34, 0.008, paint, 0.40, 0.10)
	_friction_knuckle(elbow, 0.020, paint)
	# One joint is all it has, and the shade hangs straight off it.
	var shade := make_cyl(0.026, 0.090, 0.112,
			elbow + Vector3(0.014, -0.052, 0), paint, 0.5)
	shade.rotation_degrees = Vector3(0, 0, 10)
	var rim := make_cyl(0.091, 0.091, 0.006,
			elbow + Vector3(0.024, -0.104, 0), Color(0.53, 0.53, 0.50), 0.62)
	rim.rotation_degrees = Vector3(0, 0, 10)
	_socket_and_cord(elbow + Vector3(0.0, -0.016, 0), false)
	_head = elbow + Vector3(0.018, -0.078, 0)
	retexture(self, [
		[paint, "enamel", Color(0.34, 0.37, 0.32), 0.4],
	])


## Buquet pattern, 1927. **Nickel-plated brass on a weighted wooden base** —
## explicitly not the aluminium version, which §VIII.4 forbids outright. The
## counterweight in the arm is the mechanism and is worth showing.
func _build_architect() -> void:
	# Weighted wooden base.
	make_cyl(0.105, 0.112, 0.034, Vector3(0, 0.017, 0),
			Color(0.29, 0.20, 0.13), 0.62)
	make_cyl(0.038, 0.038, 0.012, Vector3(0, 0.040, 0), _NICKEL, 0.25, 0.85)

	var hip := Vector3(0, 0.052, 0)
	_ball_joint(hip)
	var elbow := _strut(hip, 24.0, 0.34, 0.009, _NICKEL, 0.24, 0.90)
	# The counterweight rides the short end, below the hip, and is the mechanism.
	var a := deg_to_rad(24.0)
	make_cyl(0.026, 0.026, 0.052,
			hip - Vector3(sin(a), cos(a), 0.0) * 0.048, _NICKEL, 0.22, 0.9)
	_ball_joint(elbow)
	var wrist := _strut(elbow, -30.0, 0.30, 0.008, _NICKEL, 0.24, 0.90)
	_ball_joint(wrist)

	# The Buquet head is modest; the arm is the object.
	var shade := make_cyl(0.022, 0.078, 0.098,
			wrist + Vector3(0.010, -0.046, 0), _NICKEL, 0.26, 0.85)
	shade.rotation_degrees = Vector3(0, 0, 10)
	# Accord 9: weeks old and already scarred where the arm swings into the
	# board. She is not precious about it, which is the interesting part.
	make_box(Vector3(0.050, 0.004, 0.010),
			wrist + Vector3(-0.020, -0.030, 0.048), Color(0.44, 0.45, 0.46))
	_socket_and_cord(wrist + Vector3(0.0, -0.014, 0), false)
	_head = wrist + Vector3(0.014, -0.072, 0)


# ------------------------------------------------------------------- mechanisms



## A strut from `start`, `length` long, leaning `deg` away from vertical in the
## XY plane. **Returns the far end**, so the next joint starts exactly where this
## one stops.
##
## Articulated lamps were first built by placing each arm and then guessing the
## joint positions by hand. A CylinderMesh runs along +Y and rotates about its
## own centre, so every guess was wrong by half a length and the shades came off
## the arms entirely. Chain the returned point instead of estimating it.
func _strut(start: Vector3, deg: float, length: float, radius: float,
		colour: Color, rough := 0.30, metal := 0.70) -> Vector3:
	var a := deg_to_rad(deg)
	var dir := Vector3(sin(a), cos(a), 0.0)
	var bar := make_cyl(radius, radius, length,
			start + dir * (length * 0.5), colour, rough, metal)
	bar.rotation_degrees = Vector3(0, 0, -deg)
	return start + dir * length


## The knurled screw you actually loosen to move the arm. Visible on every
## period bench lamp and the reason they look like machines rather than lamps.
func _friction_knuckle(at: Vector3, radius := 0.024,
		colour := Color(0.20, 0.21, 0.21)) -> void:
	var body := make_cyl(radius, radius, 0.028, at, colour, 0.45)
	body.rotation_degrees = Vector3(90, 0, 0)
	var screw := make_cyl(radius * 0.62, radius * 0.62, 0.014,
			at + Vector3(0, 0, radius * 0.9), _NICKEL, 0.3, 0.8)
	screw.rotation_degrees = Vector3(90, 0, 0)


## Buquet's articulation is a ball and socket, not a knuckle.
func _ball_joint(at: Vector3) -> void:
	make_cyl(0.019, 0.019, 0.026, at, _NICKEL, 0.22, 0.9)
	make_cyl(0.013, 0.013, 0.034, at + Vector3(0, 0.014, 0),
			_NICKEL, 0.22, 0.9)


## Socket collar and the cloth cord leaving it. §VIII.4: cloth-braided flex is
## status, and a lamp with no visible cord is a lamp nobody wired.
func _socket_and_cord(at: Vector3, upright: bool) -> void:
	make_cyl(0.017, 0.019, 0.024, at + Vector3(0, -0.014, 0),
			_BAKELITE, 0.42)
	# One drop of cord to the surface. Two segments so it reads as hanging
	# rather than as a rod.
	var drop := 0.16 if upright else 0.22
	var cord := make_cyl(0.0035, 0.0035, drop,
			at + Vector3(0.0, -drop * 0.5 - 0.03, 0.022), _CORD, 0.9)
	cord.rotation_degrees = Vector3(9, 0, 4)


## One small Bakelite key at the base.  It is intentionally independent of
## the five silhouettes: different owners chose different lamps, but each
## reachable local contact has the same single honest job.
func _build_key_switch() -> void:
	_switch_key = Node3D.new()
	_switch_key.name = "LocalKeySwitch"
	_switch_key.position = Vector3(0.060, 0.037, -0.045)
	add_child(_switch_key)
	var stem := make_cyl(0.010, 0.010, 0.026, Vector3.ZERO,
			_BAKELITE, 0.46, 0.0, _switch_key)
	stem.rotation_degrees.x = 90.0
	var key := make_box(Vector3(0.045, 0.012, 0.018),
			Vector3(0, 0, -0.018), _BAKELITE)
	key.reparent(_switch_key, false)


func _install_light(seed: int) -> void:
	light = SpotLight3D.new()
	var tone: Color = _spec["tone"]
	var hue := (float((seed >> 4) & 255) / 255.0 - 0.5) * 0.030
	light.light_color = Color.from_hsv(
			fposmod(tone.h + hue, 1.0), tone.s, tone.v)
	light.light_energy = _base_energy
	# Under the shade, aimed at the work surface rather than the wall. A
	# downward spot is also one shadow map instead of a cube's six.
	# Under the shade the arms actually reached, not where the spec guessed.
	light.position = _head if _head != Vector3.ZERO else Vector3(
			float(_spec["reach"]), float(_spec["height"]), 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.spot_range = float(_spec["range"])
	light.spot_angle = float(_spec["angle"])
	light.spot_angle_attenuation = 1.15
	light.shadow_bias = 0.014
	light.shadow_normal_bias = 0.06
	add_child(light)

	set_meta("light_personality", {
		"tone": light.light_color, "gain": _base_energy / 1.1,
		"flicker_profile": 1, "flicker_depth": _drift_depth,
		"flicker_speed": 0.71,
	})


# -------------------------------------------------------------------- warehouse


## Five silhouettes behind one marker kind, which is exactly the comparison the
## inspection shed exists to make.
func warehouse_variants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in ["emeralite", "office_green", "bench_friction",
			"landlord_enamel", "architect_counterweight"]:
		out.append({
			"label": String(_SPECS[key]["label"]),
			"properties": {"variant": key},
		})
	return out


# ---------------------------------------------------------------------- runtime


func _start_normal_function() -> void:
	state = PState.OPERATING if _local_enabled else PState.OFF


func interact_prompt() -> String:
	return "[E] Turn task lamp off" if _local_enabled \
			else "[E] Turn task lamp on"


func interact(_player: Node = null) -> Dictionary:
	set_local_enabled(not _local_enabled)
	return service_wire_card()


func set_local_enabled(enabled: bool, animate := true) -> void:
	_local_enabled = enabled
	state = PState.OPERATING if enabled else PState.OFF
	if light != null:
		light.visible = enabled and _target_scale > 0.001
		light.light_energy = _base_energy * _target_scale if enabled else 0.0
	if _switch_click != null:
		_switch_click.pitch_scale = 1.04 if enabled else 0.94
		_switch_click.play()
	if _switch_tween and _switch_tween.is_valid():
		_switch_tween.kill()
	var target := deg_to_rad(32.0 if enabled else -32.0)
	if not animate:
		_switch_key.rotation.y = target
		return
	_switch_tween = create_tween()
	_switch_tween.tween_property(_switch_key, "rotation:y", target, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func is_locally_enabled() -> bool:
	return _local_enabled


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("lamp", {
		"switch_state": "ON" if _local_enabled else "OFF",
		"lamp_state": "LIT" if light != null and light.visible else (
				"BUDGET STANDBY" if _local_enabled else "DARK"),
	})


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if not _local_enabled or _target_scale <= 0.0 or light == null:
		return
	light.light_energy = _base_energy * (1.0 + accent * 0.9)
	create_tween().tween_property(light, "light_energy", _base_energy, 0.25)


func set_budget(scale: float, _with_bounce: bool, with_shadow: bool) -> void:
	_target_scale = scale
	if light == null:
		return
	light.visible = _local_enabled and scale > 0.001
	light.shadow_enabled = with_shadow
	light.light_energy = _base_energy * scale if _local_enabled else 0.0


func _process(_delta: float) -> void:
	if light == null or not _local_enabled or _target_scale <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001 + _phase
	var filament := 1.0 + sin(t * _drift_speed) * _drift_depth \
			+ sin(t * _drift_speed * 3.0) * _drift_depth * 0.35
	light.light_energy = _base_energy * _target_scale * filament
