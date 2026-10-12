class_name StoveProp
extends FunctionalProp
## The landlord's cheap pre-war gas range: pressed sheet steel on an
## angle-iron stand, porcelain enamel where it can be wiped, open cast-
## iron grates where it cannot. It carries no signal. Under the Rule of
## Signal that makes it an ordinary 1920s object on a gas pipe, not an
## anachronistic electric cooker dressed in cream paint.
##
## The complete object lives here. The old split left a baked 1940s shell
## in the floor and only four hotplates plus a door in this prop; it looked
## whole in one installed view and became floating pieces in the warehouse.
## Burners, caps, jets, grates and both door cavities are geometry because
## the service activity asks the player to touch every one of them.

const W := 0.64
const D := 0.60
## Load-bearing plane, not the enamel deck. Tape and radios in 2C/5B are
## authored with their bottoms at 0.90 m; a 0.91 m grate left a visible
## centimetre of air under every object already living on the range.
const HOB_Y := 0.90
const OVEN_W := 0.44
const OVEN_H := 0.34
const OVEN_HINGE_Y := 0.34

const ENAMEL := Color(0.88, 0.87, 0.84)
const IRON := Color(0.20, 0.19, 0.18)
const IRON_DARK := Color(0.095, 0.09, 0.085)
const BAKELITE := Color(0.20, 0.12, 0.075)
const BRASS_DULL := Color(0.58, 0.45, 0.22)
const GREASE := Color(0.19, 0.15, 0.09, 0.82)

const BURNER_SPOTS := [
	Vector2(-0.17, -0.13), Vector2(0.17, -0.13),
	Vector2(-0.17, 0.14), Vector2(0.17, 0.14),
]

## Set from the marker before `_ready()`: wear and the permanently blocked
## jet belong to a household. One marker may also carry the deliberately
## retained ambient-burner beat; the other sixteen start honestly cold.
var unit := ""
var ambient_lit := false
## Exposed for the material-family gate. A stove is porcelain-enamel sheet;
## the old generic key remains only for consumers awaiting their own review.
var enamel_material_key := "enamel_appliance"

var blocked_burner := -1
var burner_grime: Array[float] = []

var _door: Node3D
var _broiler: Node3D
var _open := false
var _hand_part: Node3D
var _door_motion: Tween
signal manipulation_changed
var _possessed := false
var _burner_on: Array[bool] = []
var _gas_openings: Array[float] = []
var _knob_motions: Dictionary = {}
var _flame_motions: Dictionary = {}
var _grates: Array[Node3D] = []
var _grate_home: Array[Vector3] = []
var _caps: Array[Node3D] = []
var _cap_home: Array[Vector3] = []
var _jet_plugs: Array[MeshInstance3D] = []
var _grease: Array[MeshInstance3D] = []
var _flames: Array[Node3D] = []
var _dirty_flames: Array[MeshInstance3D] = []
var _burner_lights: Array[OmniLight3D] = []
var _knobs: Array[Node3D] = []
var _clunk: AudioStreamPlayer3D
var _burn: AudioStreamPlayer3D
var _burn_motion: Tween


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "stove / 1922 fired-enamel gas range",
			"properties": {"unit": "2B", "ambient_lit": false}}]


func _build_visual() -> void:
	blocked_burner = posmod(_unit_seed(), BURNER_SPOTS.size())
	for _i in BURNER_SPOTS.size():
		burner_grime.append(0.0)
		_burner_on.append(false)
		_gas_openings.append(0.0)

	var carcass := Node3D.new()
	carcass.name = "StaticCarcass"
	add_child(carcass)
	_build_carcass(carcass)
	_build_oven_door()
	_build_broiler_door()
	_build_controls()
	for i in BURNER_SPOTS.size():
		_build_burner(i, BURNER_SPOTS[i])

	var enamel_tint := _enamel_tint()
	retexture(self, [
		[ENAMEL, enamel_material_key, enamel_tint, 0.82],
		[IRON, "cast_iron", Color(0.42, 0.40, 0.38), 0.72],
		[IRON_DARK, "cast_iron", Color(0.20, 0.19, 0.18), 0.64],
		[BAKELITE, "bakelite", Color(0.56, 0.39, 0.28), 0.82],
		[BRASS_DULL, "brass_dull", Color(0.82, 0.74, 0.52), 0.72],
		[GREASE, "fx_grease", Color(1.0, 1.0, 1.0, 0.84), 1.0],
	])
	# Only the carcass is fixed. Doors, valves, caps and grates retain their
	# owner nodes because the hand and the haunting both move them. Their
	# primitives do not move relative to those owners, so keeping every spoke
	# as a draw was needless: eighteen ranges were carrying 1,764 meshes.
	merge_static(carcass)
	merge_static(_door)
	merge_static(_broiler)
	for knob in _knobs:
		merge_static(knob)
	for grate in _grates:
		merge_static(grate)
	for cap in _caps:
		merge_static(cap, _jet_plugs)
	for i in _flames.size():
		merge_static(_flames[i], [_dirty_flames[i]])
		for draw: Node in _flames[i].find_children("*", "MeshInstance3D", true, false):
			draw.set_meta("surface_role", "gas_flame")

	var seed := _unit_seed()
	for i in BURNER_SPOTS.size():
		var grime := 0.12 + float(posmod(seed + i * 37, 61)) / 100.0
		if unit == "3D":
			grime *= 0.18       # Rhea does not cook; the range is wiped anyway
		elif unit in ["2C", "5B"]:
			grime = 0.58 + i * 0.06  # dust and old film under the shelf-load
		elif unit == "5C":
			grime = minf(0.92, grime + 0.22)
		set_burner_grime(i, grime)
		set_jet_blocked(i, i == blocked_burner)

	_clunk = make_emitter("tick", -22.0)
	_burn = make_emitter("hum_loop", -60.0, true)
	_burn.max_distance = 7.0


func _build_carcass(parent: Node3D) -> void:
	# Four slim legs and their lower rails: the 1922 advertisements call out
	# an angle-iron base because the enamel panels are a skin, not a plinth.
	for x in [-0.275, 0.275]:
		for z in [-0.245, 0.245]:
			_cyl_on(parent, 0.018, 0.023, 0.17,
					Vector3(x, 0.085, z), IRON)
	for z in [-0.245, 0.245]:
		_tube_between(parent, Vector3(-0.275, 0.105, z),
				Vector3(0.275, 0.105, z), 0.011, IRON_DARK)

	# A real shell around a dark oven, rather than an opaque box with a
	# black rectangle pasted over its front. Open the leaf and the eye can
	# follow the liner to its back and find the rack inside.
	_box_on(parent, Vector3(W, 0.055, D), Vector3(0, 0.19, 0), ENAMEL)
	_box_on(parent, Vector3(0.065, 0.66, D),
			Vector3(-0.287, 0.525, 0), ENAMEL)
	_box_on(parent, Vector3(0.065, 0.66, D),
			Vector3(0.287, 0.525, 0), ENAMEL)
	_box_on(parent, Vector3(W - 0.13, 0.04, D),
			Vector3(0, 0.845, 0), ENAMEL)
	_box_on(parent, Vector3(W - 0.13, 0.075, 0.04),
			Vector3(0, 0.742, -0.278), ENAMEL)
	_box_on(parent, Vector3(W - 0.13, 0.035, 0.04),
			Vector3(0, 0.318, -0.278), IRON_DARK)

	# Oven liner: five planes, a usable depth and a rack. Its quoted cheap-
	# range depth was about 18 inches; 0.45 m here is measured from the 1922
	# Champion advertisement and still clears this building's 0.60 m run.
	_box_on(parent, Vector3(OVEN_W, OVEN_H, 0.025),
			Vector3(0, OVEN_HINGE_Y + OVEN_H * 0.5, 0.245), IRON_DARK)
	for x in [-OVEN_W * 0.5, OVEN_W * 0.5]:
		_box_on(parent, Vector3(0.018, OVEN_H, 0.45),
				Vector3(x, OVEN_HINGE_Y + OVEN_H * 0.5, 0.02), IRON)
	for y in [OVEN_HINGE_Y, OVEN_HINGE_Y + OVEN_H]:
		_box_on(parent, Vector3(OVEN_W, 0.018, 0.45),
				Vector3(0, y, 0.02), IRON)
	_build_oven_rack(parent, OVEN_HINGE_Y + 0.15)

	# Recessed enamel deck. Grates sit above it but their TOP is exactly
	# HOB_Y, the contract used by the two loaded ranges.
	_box_on(parent, Vector3(W, 0.028, D), Vector3(0, 0.858, 0), ENAMEL)
	_box_on(parent, Vector3(W - 0.04, 0.006, D - 0.04),
			Vector3(0, 0.875, 0), IRON_DARK)

	# Shallow splash panel and condiment shelf. A clock would turn this into
	# the 1930s–40s Chambers silhouette the old shell accidentally copied.
	_box_on(parent, Vector3(W - 0.03, 0.235, 0.028),
			Vector3(0, 1.005, 0.282), ENAMEL)
	_box_on(parent, Vector3(W - 0.02, 0.026, 0.22),
			Vector3(0, 1.126, 0.205), ENAMEL)
	_tube_between(parent, Vector3(-0.27, 1.145, 0.095),
			Vector3(0.27, 1.145, 0.095), 0.008, BRASS_DULL)

	# Exposed front gas rail and its five valve stems: four rings plus oven.
	_tube_between(parent, Vector3(-0.275, 0.785, -0.323),
			Vector3(0.275, 0.785, -0.323), 0.012, BRASS_DULL)


func _build_oven_rack(parent: Node3D, y: float) -> void:
	for x in [-0.19, -0.095, 0.0, 0.095, 0.19]:
		_tube_between(parent, Vector3(x, y, -0.19),
				Vector3(x, y, 0.20), 0.0045, IRON)
	for z in [-0.19, 0.20]:
		_tube_between(parent, Vector3(-0.20, y, z),
				Vector3(0.20, y, z), 0.006, IRON)


func _build_oven_door() -> void:
	_door = Node3D.new()
	_door.name = "OvenDoor"
	_door.position = Vector3(0, OVEN_HINGE_Y, -D * 0.5 - 0.018)
	add_child(_door)
	_box_on(_door, Vector3(OVEN_W, OVEN_H, 0.032),
			Vector3(0, OVEN_H * 0.5, 0), ENAMEL)
	# Inner heat shield is visible only when the door is open; the small
	# inset outer panel is pressed steel, not a modern glass window.
	_box_on(_door, Vector3(OVEN_W - 0.045, OVEN_H - 0.045, 0.012),
			Vector3(0, OVEN_H * 0.5, 0.022), IRON)
	_box_on(_door, Vector3(OVEN_W - 0.075, OVEN_H - 0.085, 0.008),
			Vector3(0, OVEN_H * 0.48, -0.021), ENAMEL)
	var handle := _cyl_on(_door, 0.010, 0.010, OVEN_W - 0.06,
			Vector3(0, OVEN_H - 0.035, -0.052), BRASS_DULL)
	handle.rotation_degrees.z = 90.0
	for x in [-OVEN_W * 0.43, OVEN_W * 0.43]:
		_cyl_on(_door, 0.012, 0.012, 0.055,
				Vector3(x, OVEN_H - 0.035, -0.026), BRASS_DULL)


func _build_broiler_door() -> void:
	_broiler = Node3D.new()
	_broiler.name = "BroilerDrawer"
	_broiler.position = Vector3(0, 0.205, -D * 0.5 - 0.016)
	add_child(_broiler)
	_box_on(_broiler, Vector3(OVEN_W, 0.095, 0.028),
			Vector3(0, 0.0475, 0), ENAMEL)
	_box_on(_broiler, Vector3(0.19, 0.025, 0.008),
			Vector3(0, 0.055, -0.019), IRON_DARK)


func _build_controls() -> void:
	for i in 5:
		var knob := Node3D.new()
		knob.name = "BurnerValve%d" % (i + 1) if i < 4 else "OvenValve"
		knob.position = Vector3(-0.235 + i * 0.1175, 0.785, -0.342)
		add_child(knob)
		var stem := _cyl_on(knob, 0.020, 0.026, 0.032,
				Vector3.ZERO, BAKELITE)
		stem.rotation_degrees.x = 90.0
		_box_on(knob, Vector3(0.010, 0.038, 0.012),
				Vector3(0, 0.018, -0.024), BRASS_DULL)
		if i < 4:
			_knobs.append(knob)


func _build_burner(index: int, spot: Vector2) -> void:
	var stain := _cyl_on(self, 0.105, 0.105, 0.003,
			Vector3(spot.x, 0.878, spot.y), GREASE)
	stain.name = "Grease%d" % (index + 1)
	_grease.append(stain)

	var grate := Node3D.new()
	grate.name = "Grate%d" % (index + 1)
	grate.position = Vector3(spot.x, HOB_Y, spot.y)
	add_child(grate)
	_ring_on(grate, 0.104, 0.012, Vector3(0, -0.012, 0), IRON)
	for angle in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
		var direction := Vector3(cos(angle), 0, sin(angle)) * 0.105
		_tube_between(grate, -direction + Vector3(0, -0.012, 0),
				direction + Vector3(0, -0.012, 0), 0.009, IRON)
	_grates.append(grate)
	_grate_home.append(grate.position)

	var cap := Node3D.new()
	cap.name = "BurnerCap%d" % (index + 1)
	cap.position = Vector3(spot.x, HOB_Y, spot.y)
	add_child(cap)
	_cyl_on(cap, 0.064, 0.070, 0.016, Vector3(0, -0.026, 0), IRON_DARK)
	_ring_on(cap, 0.057, 0.006, Vector3(0, -0.016, 0), IRON)
	var jet := _cyl_on(cap, 0.009, 0.009, 0.010,
			Vector3(0, -0.010, 0), GREASE)
	jet.name = "BlockedJet"
	_caps.append(cap)
	_cap_home.append(cap.position)
	_jet_plugs.append(jet)

	_build_flame(index, spot)


func _build_flame(index: int, spot: Vector2) -> void:
	var root := Node3D.new()
	root.name = "Flame%d" % (index + 1)
	root.position = Vector3(spot.x, HOB_Y, spot.y)
	add_child(root)
	var blue := _flame_mat(Color(0.12, 0.38, 1.0, 0.70), 2.8)
	var yellow := _flame_mat(Color(1.0, 0.52, 0.10, 0.82), 3.4)
	var ring := make_ring(0.058, 0.005, Vector3(0, 0.012, 0),
			Color(0.12, 0.38, 1.0, 0.70), 0.3, 0.0, root)
	ring.material_override = blue
	for i in 8:
		var a := TAU * float(i) / 8.0
		var tongue := make_cyl(0.002, 0.009, 0.032,
				Vector3(cos(a) * 0.058, 0.027, sin(a) * 0.058),
				Color.WHITE, 0.3, 0.0, root)
		tongue.material_override = blue
	var dirty := make_cyl(0.002, 0.010, 0.052,
			Vector3(0.035, 0.037, -0.035), Color.WHITE, 0.3, 0.0, root)
	dirty.material_override = yellow
	dirty.visible = false
	_dirty_flames.append(dirty)
	root.visible = false
	_flames.append(root)

	var glow := OmniLight3D.new()
	glow.name = "BurnerGlow%d" % (index + 1)
	glow.light_color = Color(0.32, 0.48, 1.0)
	glow.light_energy = 0.0
	glow.omni_range = 0.58
	glow.omni_attenuation = 1.35
	glow.shadow_enabled = false
	glow.position = Vector3(spot.x, HOB_Y + 0.06, spot.y)
	add_child(glow)
	_burner_lights.append(glow)


func _flame_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = energy
	return mat


func interact_prompt() -> String:
	return "[E]  %s the oven" % ("Close" if _open else "Open")


func interact(_player: Node) -> void:
	set_door_open(not _open)


## One path for hand and haunting, so the possessed leaf cannot disagree
## with the latch state reported by the prompt.
func set_door_open(open: bool, seconds := 0.50) -> void:
	if _door == null or _hand_part == _door:
		return
	_open = open
	if _clunk:
		_clunk.pitch_scale = 0.82 if open else 1.08
		_clunk.play()
	if _door_motion != null and _door_motion.is_valid(): _door_motion.kill()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	_door_motion = tween
	tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	tween.tween_property(_door, "rotation:x",
			deg_to_rad(-86.0) if open else 0.0, seconds)


## Compatibility name retained for the director and any existing activity
## call sites. It is a gas burner now, never an emissive electric hotplate.
func set_ring(index: int, on: bool, seconds := 0.45) -> void:
	set_burner_lit(index, on, seconds)


func set_burner_lit(index: int, on: bool, seconds := 0.45,
		force := false) -> bool:
	if index < 0 or index >= _flames.size() or _hand_part == _knobs[index]:
		return false
	_cancel_flame_motion(index)
	if on and index == blocked_burner and not force:
		# A blocked jet answers with a tiny yellow cough, then darkness. The
		# service game can deduce the fault without the range solving itself.
		_dirty_flames[index].visible = true
		_flames[index].visible = true
		_burner_lights[index].light_color = Color(1.0, 0.42, 0.12)
		_flame_motions[index] = create_tween()
		_flame_motions[index].tween_property(_burner_lights[index], "light_energy",
				0.025, minf(seconds, 0.12))
		_sputter_out(index)
		return false
	_burner_on[index] = on
	_flames[index].visible = on
	_dirty_flames[index].visible = on and index == blocked_burner
	_burner_lights[index].light_color = Color(0.32, 0.48, 1.0) \
			if index != blocked_burner else Color(1.0, 0.42, 0.12)
	_gas_openings[index] = 1.0 if on else 0.0
	_flames[index].scale.y = 1.0
	_flame_motions[index] = create_tween()
	_flame_motions[index].tween_property(_burner_lights[index], "light_energy",
			0.11 if on else 0.0, seconds)
	_knobs[index].rotation.z = deg_to_rad(-58.0) * _gas_openings[index]
	if _clunk:
		_clunk.pitch_scale = 1.20 if on else 0.96
		_clunk.play()
	_update_burn_bed()
	return true


func _sputter_out(index: int) -> void:
	await get_tree().create_timer(0.16, false).timeout
	if not is_inside_tree() or index >= _flames.size() or _burner_on[index]:
		return
	_flames[index].visible = false
	_dirty_flames[index].visible = false
	_cancel_flame_motion(index)
	_flame_motions[index] = create_tween()
	_flame_motions[index].tween_property(_burner_lights[index], "light_energy", 0.0, 0.12)


func set_burner_grime(index: int, amount: float) -> void:
	if index < 0 or index >= _grease.size():
		return
	amount = clampf(amount, 0.0, 1.0)
	burner_grime[index] = amount
	_grease[index].visible = amount > 0.02
	var spread := lerpf(0.52, 1.08, amount)
	_grease[index].scale = Vector3(spread, 1.0, spread)


func set_jet_blocked(index: int, blocked: bool) -> void:
	if index < 0 or index >= _jet_plugs.size():
		return
	_jet_plugs[index].visible = blocked
	if blocked:
		blocked_burner = index
	elif blocked_burner == index:
		blocked_burner = -1


func clear_jet(index: int) -> void:
	set_jet_blocked(index, false)
	set_burner_grime(index, burner_grime[index] * 0.25)


func set_grate_removed(index: int, removed: bool, seconds := 0.45) -> void:
	if index < 0 or index >= _grates.size():
		return
	var target := _grate_home[index]
	var target_rotation := Vector3.ZERO
	if removed:
		# Lean it against the shallow splashback. A first pass merely raised
		# the grate in mid-air, which proved the node moved and nothing else.
		target = Vector3(-0.20 if index % 2 == 0 else 0.20,
				HOB_Y + 0.095, 0.205)
		target_rotation = Vector3(deg_to_rad(-68.0), 0, 0)
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(
			_grates[index], "position", target, seconds)
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(
			_grates[index], "rotation", target_rotation, seconds)


func set_cap_removed(index: int, removed: bool, seconds := 0.35) -> void:
	if index < 0 or index >= _caps.size():
		return
	var target := _cap_home[index]
	if removed:
		target += Vector3(0.12 if index % 2 == 0 else -0.12, 0.018, -0.12)
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(
			_caps[index], "position", target, seconds)


func set_service_pose(index := 0) -> void:
	index = clampi(index, 0, BURNER_SPOTS.size() - 1)
	set_grate_removed(index, true, 0.01)
	set_cap_removed(index, true, 0.01)
	set_burner_grime(index, 0.92)


func _update_burn_bed() -> void:
	if _burn == null:
		return
	var amount := 0.0
	for index in _burner_on.size():
		if _burner_on[index]: amount += _gas_openings[index]
	if _burn_motion != null and _burn_motion.is_valid(): _burn_motion.kill()
	_burn_motion = create_tween()
	_burn_motion.tween_property(_burn, "volume_db",
		-38.0+linear_to_db(maxf(.08,minf(1.0,amount))) if amount>0 else -60.0, .15)


## The overt fit uses the same valves, jets and hinge as maintenance. It
## may force the permanently bad burner alight because that violation is
## the point: the range demonstrates it knows which rule it is breaking.
func possess_fit(beats := 4) -> void:
	if _possessed:
		return
	_possessed = true
	for i in _flames.size():
		set_burner_lit(i, true, 0.18 + i * 0.05, true)
	for i in range(beats):
		set_door_open(true, 0.14)
		await get_tree().create_timer(0.20, false).timeout
		if not is_inside_tree():
			return
		set_door_open(false, 0.12)
		await get_tree().create_timer(0.27 if i % 2 else 0.17, false).timeout
		if not is_inside_tree():
			return
	for i in _flames.size():
		set_burner_lit(i, false, 1.2, true)
	_possessed = false


func _start_normal_function() -> void:
	state = PState.OPERATING
	# One authored domestic hazard, not a six-flat random epidemic. 2B's
	# enormous borrowed-family cookware makes the steady low ring findable;
	# the marker chooses it, and the other sixteen are cold on every boot.
	if ambient_lit:
		set_burner_lit((blocked_burner + 1) % 4, true, 1.8, true)


func _perform_synced_event(index: int, accent: float, _pitch: float) -> void:
	var burner := posmod(index, maxi(1, _flames.size()))
	if _clunk:
		_clunk.pitch_scale = lerpf(0.90, 1.18, clampf(accent, 0.0, 1.0))
		_clunk.play()
	# Below overt possession the valve only tests its stop. A player who
	# looks back sees it where it began and can reasonably blame themselves.
	var knob := _knobs[burner]
	if _hand_part == knob: return
	_cancel_knob_motion(burner)
	var home := knob.rotation.z
	var twitch := home + deg_to_rad(-9.0 - 8.0 * accent)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	_knob_motions[burner] = tween
	tween.tween_property(knob, "rotation:z", twitch, 0.10)
	tween.tween_property(knob, "rotation:z", home, 0.22)


func _unit_seed() -> int:
	if unit == "":
		return 211
	var out := 0
	for i in unit.length():
		out += (i + 1) * unit.unicode_at(i)
	return out


func _enamel_tint() -> Color:
	# Same landlord order, different century of hands. These are restrained
	# oxide/cleaning shifts, not seventeen novelty colourways.
	var tones := [
		Color(1.00, 0.97, 0.89), Color(0.92, 0.95, 0.91),
		Color(0.96, 0.91, 0.82), Color(0.90, 0.88, 0.80),
	]
	return tones[posmod(_unit_seed(), tones.size())]


func _box_on(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var mi := make_box(size, at, color)
	remove_child(mi)
	parent.add_child(mi)
	mi.position = at
	return mi


func _cyl_on(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(top, bottom, height, at, color, 0.55, 0.0, parent)


func _ring_on(parent: Node3D, radius: float, tube: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_ring(radius, tube, at, color, 0.62, 0.0, parent)


func _tube_between(parent: Node3D, a: Vector3, b: Vector3,
		radius: float, color: Color) -> MeshInstance3D:
	var delta := b - a
	var mi := make_cyl(radius, radius, delta.length(), (a + b) * 0.5,
			color, 0.55, 0.0, parent)
	mi.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return mi


func _build_primary_interaction() -> void:
	for part: Node3D in [_door,_broiler]+_knobs:
		for child_name: String in ["ManipulationTarget","HandMovedCollision"]:
			var old := part.get_node_or_null(child_name)
			if old != null: old.free()
	for index in _knobs.size():
		preload("res://scripts/props/manipulation_area.gd").install(_knobs[index],func(): return gas_grip(index))
	for part: Node3D in [_door, _broiler]:
		preload("res://scripts/props/manipulation_area.gd").install(part, func(): return _range_grip(part))
		preload("res://scripts/props/mechanism_sweep.gd").install(part)

func manipulation_target(hit: Dictionary) -> Dictionary:
	for part: Node3D in [_door,_broiler]:
		if part.is_ancestor_of(hit.collider): return _range_grip(part)
	return {}

func _range_grip(part: Node3D) -> Dictionary:
	var sliding := part == _broiler
	return {"owner":self,"part":part,"frame":self,"kind":"slide" if sliding else "hinge",
		"axis":Vector3.FORWARD if sliding else Vector3.LEFT,"minimum":0.0,
		"maximum":.24 if sliding else deg_to_rad(86),
		"read":func(): return -D*.5-.016-part.position.z if sliding else -part.rotation.x,
		"write":func(value: float):
			if _hand_part != part: return
			var before := -D*.5-.016-part.position.z if sliding else -part.rotation.x
			value=preload("res://scripts/props/mechanism_sweep.gd").limited(self,part,Vector3.FORWARD if sliding else Vector3.LEFT,before,value,sliding)
			if sliding: part.position.z=-D*.5-.016-value
			else: part.rotation.x=-value;_open=value>.01,
		"owns":func(): return _hand_part == part,
		"begin":func():
			if _hand_part != null or _possessed: return false
			if part == _door and _door_motion != null and _door_motion.is_valid(): _door_motion.kill()
			_hand_part=part
			return true,
		"end":func(): _hand_part=null;manipulation_changed.emit()}

func _cancel_knob_motion(index: int) -> void:
	var motion: Tween = _knob_motions.get(index)
	if motion != null and motion.is_valid(): motion.kill()
	_knob_motions.erase(index)

func _cancel_flame_motion(index: int) -> void:
	var motion: Tween = _flame_motions.get(index)
	if motion != null and motion.is_valid(): motion.kill()
	_flame_motions.erase(index)

func _set_gas_opening(index: int, value: float) -> void:
	if index < 0 or index >= _gas_openings.size() or not is_finite(value): return
	_cancel_flame_motion(index)
	_gas_openings[index] = clampf(value,0.0,1.0)
	_knobs[index].rotation.z = -deg_to_rad(58.0)*_gas_openings[index]
	# The cock admits gas; it supplies no spark. Only an already lit ring burns.
	if _gas_openings[index] <= .0001: _burner_on[index] = false
	_flames[index].visible = _burner_on[index]
	_dirty_flames[index].visible = _burner_on[index] and index == blocked_burner
	_flames[index].scale.y = lerpf(.20,1.0,_gas_openings[index])
	_burner_lights[index].light_energy = .11*_gas_openings[index] if _burner_on[index] else 0.0
	_update_burn_bed()

func gas_grip(index: int) -> Dictionary:
	if index < 0 or index >= _knobs.size(): return {}
	var knob := _knobs[index]
	return {"owner":self,"part":knob,"frame":self,"kind":"hinge",
		"axis":Vector3.FORWARD,"minimum":0.0,"maximum":deg_to_rad(58),
		"read":func(): return _gas_openings[index]*deg_to_rad(58),
		"write":func(value: float):
			if _hand_part == knob: _set_gas_opening(index,value/deg_to_rad(58)),
		"owns":func(): return _hand_part == knob,
		"begin":func():
			if _hand_part != null or _possessed: return false
			_cancel_knob_motion(index)
			_hand_part = knob
			return true,
		"end":func(): _hand_part=null;manipulation_changed.emit()}

func mechanism_snapshot() -> Dictionary:
	return {"door":-_door.rotation.x,"broiler":-D*.5-.016-_broiler.position.z,
		"gas":_gas_openings.duplicate(),"lit":_burner_on.duplicate()}

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size() not in [2,4]: return false
	if value.size()==4:
		if value.get("gas") is not Array or value.get("lit") is not Array or value.gas.size()!=4 or value.lit.size()!=4: return false
		for i in 4:
			if typeof(value.gas[i]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value.gas[i])) or float(value.gas[i])<0 or float(value.gas[i])>1 or typeof(value.lit[i])!=TYPE_BOOL: return false
			if value.lit[i] and float(value.gas[i])<=.0001: return false
	for key: String in ["door","broiler"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])): return false
	return float(value.door)>=0 and float(value.door)<=deg_to_rad(86)+.00001 and float(value.broiler)>=0 and float(value.broiler)<=.24001

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	if _door_motion != null and _door_motion.is_valid(): _door_motion.kill()
	_hand_part=null
	_door.rotation.x=-float(value.door);_open=value.door>.01
	_broiler.position.z=-D*.5-.016-float(value.broiler)

	for i in 4:
		_cancel_knob_motion(i)
		if value.has("gas"):
			_burner_on[i] = value.lit[i]
			_set_gas_opening(i,float(value.gas[i]))
