class_name LightRig
extends Node3D
## Floor-switched lighting. A fixture must be on the camera's current storey
## to be lit at all; every other storey is electrically dark. That gate is
## what makes the model predictable — you are never lit by a room you cannot
## be standing in.
##
## The gate alone is not sufficient, though, because of the renderer. GL
## compatibility caps how many lights may affect any ONE object, and the
## build merges each floor's walls into a single mesh. Enabling all ~40
## fixtures on a storey therefore hands that cap to an arbitrary subset —
## in practice apartment lights sitting behind walls, which is exactly how
## a lit corridor ends up black at its far end while its own domes glow.
## So within the active floor we also keep the nearest ACTIVE_N, ranking
## circulation fixtures ahead of room fixtures at equal distance: the lights
## you are walking under always own the budget.
##
## The light court is exempt from the floor gate entirely. The atrium is a
## single open volume seven storeys tall: from the lobby deck you look
## directly at F06's pendant. Switching it off with "its" floor would black
## out the top of the stair while you stand under it, so the eye pendants
## stay lit at every height and keep casting through the balustrades.

const INTERVAL := 0.12
## The renderer's cap (16) is per OBJECT, not global, and the seven atrium
## pendants are permanently eligible (see below), so the working set can run
## a little past it: what matters is that no single mesh is in range of more
## than 16 of these at once.
const ACTIVE_N := 14
## Shadows are priced separately from light, and far higher: an omni's
## shadow is a CUBE, so every caster re-renders the visible set six times.
## Fourteen casters cost more than everything else in the frame put
## together. The nearest few carry the modelling that sells a room — the
## balustrade shadows down the stair, furniture contact — and the rest
## contribute nothing an eye can find, so they light without casting.
const SHADOW_N := 8
## Mobile still pays more for a cube shadow than desktop does — six passes
## over the visible set, on a tiler's bandwidth — so it runs a smaller
## budget than the 8/14 above. The FIRST values here (1 caster, 8 lights)
## were picked from that reasoning alone, with no device to check against,
## and on real hardware the building read flat and half-lit: one caster is
## not enough shadow to model a room, and eight lights leaves a corridor's
## far pools dark. Raised, and made adjustable at runtime so the ceiling
## comes from a measurement on the phone in your hand rather than from an
## argument about tilers. Debug panel > Light budget / Shadow budget.
const SHADOW_N_MOBILE := 4
const ACTIVE_N_MOBILE := 12
## Circulation fixtures beat room fixtures for the budget well before a tie.
## The dome at the far end of a corridor is worth more to someone walking it
## than a bedroom fixture 5 m away through a wall, so nav distances count for
## a fraction — enough for a whole corridor run to hold the budget at once.
## Room fixtures still win inside their own room, where they are metres away
## and the nearest corridor dome is not.
const NAV_WEIGHT := 0.15
## Fixtures that belong to no single storey and so cannot be gated by one.
## The atrium pendants hang in a seven-floor volume; the street lamps stand
## outside the building altogether and are visible from every window on the
## street elevation. Gating either by "its" floor switches off a light you
## are plainly looking at.
const VERTICAL_FIXTURES := ["eye_pendant", "street_lamp"]
const LEVELS := {
	"B1": -2.8, "F01": 0.0, "F02": 3.2, "F03": 6.4,
	"F04": 9.6, "F05": 12.8, "F06": 16.0, "ROOF": 19.2,
}

signal debug_fixture_selected(fixture: Node)

var active_floor := "F01"
var _accum := 0.0
## Global grading is deliberately separate from authored light reach. Cutting
## energy must not make shadows vanish sooner: omni_range and the moon's
## directional_shadow_max_distance are never derived from this value.
# Raised 20% (ruled 2026-08-05). The pools were reading correct but
# thin; the building is meant to be dark, not dim.
var fixture_gain := 0.60
# Moonlit floor (ruled 2026-08-04): shadows read midnight blue against
# the warm fixtures and the blue phone torch. Keep in step with
# building_root._build_environment.
var ambient_energy := 0.08
var moon_energy := 0.052
# A bulb should bloom. The threshold used to sit above what the
# fixtures actually emit, so nothing ever crossed it and the glow
# system was running with nothing to do.
var glow_intensity := 0.68
var fog_density := 0.014
var shadow_opacity := 1.0
var _environment: Environment
var _moon: DirectionalLight3D
var _fixture_tuning: Dictionary = {}
var debug_inspect_enabled := false
var selected_debug_fixture: Node
var _debug_handles: Dictionary = {}
var _provenance: Dictionary = {}
## Resolved once: OS.has_feature is a string lookup, not something to do
## per fixture per tick. Writable so the budget can be tuned on the device
## it has to run on, with the frame counter visible next to it.
@onready var _active_budget: int = \
		ACTIVE_N_MOBILE if OS.has_feature("mobile") else ACTIVE_N
@onready var _shadow_budget: int = \
		SHADOW_N_MOBILE if OS.has_feature("mobile") else SHADOW_N


func _ready() -> void:
	_bind_environment()
	_load_provenance()
	call_deferred("_build_debug_handles")
	call_deferred("_report_authored_lights")


func _load_provenance() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/light_provenance.json"))
	if parsed is Dictionary:
		_provenance = parsed.get("fixtures", {})


func _build_debug_handles() -> void:
	for fixture in _controlled_lights():
		if _debug_handles.has(fixture):
			continue
		var handle := LightDebugHandle.new()
		handle.setup(self, fixture)
		fixture.add_child(handle)
		_debug_handles[fixture] = handle


func set_debug_inspection(enabled: bool) -> void:
	debug_inspect_enabled = enabled
	if enabled and _debug_handles.is_empty():
		_build_debug_handles()
	for handle in _debug_handles.values():
		handle.set_inspection_enabled(enabled)
	if not enabled:
		selected_debug_fixture = null
		debug_fixture_selected.emit(null)


func select_debug_fixture(fixture: Node) -> void:
	if not debug_inspect_enabled or fixture == null:
		return
	selected_debug_fixture = fixture
	for candidate in _debug_handles:
		_debug_handles[candidate].set_selected(candidate == fixture)
	debug_fixture_selected.emit(fixture)


func fixture_provenance(fixture: Node) -> Dictionary:
	if fixture == null:
		return {}
	return _provenance.get(str(fixture.name), {
		"room": "unmapped practical",
		"provenance": "No maintenance card survives for this fitting.",
		"quirk": "Its behavior is currently unclassified.",
	})


func _bind_environment() -> void:
	var world := get_parent().get_node_or_null("WorldEnvironment") \
			as WorldEnvironment
	_moon = get_parent().get_node_or_null("ExteriorMoon") \
			as DirectionalLight3D
	if world:
		_environment = world.environment
	apply_tuning()


func set_tuning(parameter: String, value: float) -> void:
	match parameter:
		"fixture_gain": fixture_gain = clampf(value, 0.0, 1.5)
		"ambient_energy": ambient_energy = clampf(value, 0.0, 0.20)
		"moon_energy": moon_energy = clampf(value, 0.0, 0.30)
		"glow_intensity": glow_intensity = clampf(value, 0.0, 1.5)
		"fog_density": fog_density = clampf(value, 0.0, 0.08)
		"shadow_opacity": shadow_opacity = clampf(value, 0.0, 1.0)
	apply_tuning()


func apply_tuning() -> void:
	if _environment:
		_environment.ambient_light_energy = ambient_energy
		_environment.glow_intensity = glow_intensity
		_environment.fog_density = fog_density
	if _moon:
		_moon.light_energy = moon_energy
		# Intentionally fixed: lowering energy cannot shorten visible shadows.
		_moon.directional_shadow_max_distance = 48.0
		_moon.shadow_opacity = shadow_opacity
	for fixture in _controlled_lights():
		var source: Light3D = fixture.light if "light" in fixture else null
		if source:
			source.shadow_opacity = shadow_opacity


func tuning_snapshot() -> Dictionary:
	var fixtures := {}
	for fixture in debug_fixtures():
		var card := fixture_provenance(fixture).duplicate(true)
		card["tuning"] = fixture_tuning(fixture)
		fixtures[str(fixture.name)] = card
	return {
		"fixture_gain": fixture_gain,
		"ambient_energy": ambient_energy,
		"moon_energy": moon_energy,
		"glow_intensity": glow_intensity,
		"fog_density": fog_density,
		"shadow_opacity": shadow_opacity,
		"light_budget": _active_budget,
		"shadow_budget": _shadow_budget,
		"directional_shadow_max_distance": 48.0,
		"fixtures": fixtures,
		"note": "Fixture brightness is independent of authored light/shadow range."
	}


func export_tuning() -> String:
	var text := JSON.stringify(tuning_snapshot(), "\t") + "\n"
	var path := "user://orison_lighting_settings.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
	DisplayServer.clipboard_set(text)
	var absolute := ProjectSettings.globalize_path(path)
	print("[LIGHTING] exported tuning: " + absolute)
	return absolute


func _report_authored_lights() -> void:
	var fixtures := _controlled_lights()
	for fixture in fixtures:
		_ensure_fixture_tuning(fixture)
	var profiles := [0, 0, 0, 0, 0]
	var individualized := 0
	for fixture in fixtures:
		if fixture.has_meta("light_personality"):
			var profile: Dictionary = fixture.get_meta("light_personality")
			var index := int(profile.get("flicker_profile", 0))
			profiles[clampi(index, 0, profiles.size() - 1)] += 1
			individualized += 1
	print("[LIGHTING] %d sources active in system; %d full personalities; "
			% [fixtures.size(), individualized] +
			"profiles steady/breathe/mains/beat/dropout=%s" % [profiles])


func set_budgets(lights: int, shadows: int) -> void:
	_active_budget = maxi(1, lights)
	_shadow_budget = clampi(shadows, 0, _active_budget)


func debug_fixtures() -> Array:
	var fixtures := _controlled_lights()
	fixtures.sort_custom(func(a, b): return str(a.name) < str(b.name))
	for fixture in fixtures:
		_ensure_fixture_tuning(fixture)
	return fixtures


func _ensure_fixture_tuning(fixture: Node) -> Dictionary:
	var key := str(fixture.name)
	if _fixture_tuning.has(key):
		return _fixture_tuning[key]
	var source: Light3D = fixture.light
	var personality: Dictionary = fixture.get_meta("light_personality", {})
	var tuning := {
		"energy_multiplier": 1.0,
		"range": source.omni_range if source is OmniLight3D else 8.0,
		"attenuation": source.omni_attenuation if source is OmniLight3D else 1.0,
		"temperature": _estimate_temperature(source.light_color),
		"source_size": source.light_size,
		"shadow_opacity": source.shadow_opacity,
		"flicker_depth": float(personality.get("flicker_depth", 0.0)),
		"flicker_rate": float(personality.get("flicker_speed", 1.0)),
	}
	_fixture_tuning[key] = tuning
	var authored: Dictionary = _provenance.get(key, {}).get("tuning", {})
	for parameter in authored:
		set_fixture_tuning(fixture, str(parameter), float(authored[parameter]))
	return tuning


func fixture_tuning(fixture: Node) -> Dictionary:
	return _ensure_fixture_tuning(fixture).duplicate(true)


func set_fixture_tuning(fixture: Node, parameter: String, value: float) -> void:
	if fixture == null or not is_instance_valid(fixture):
		return
	var tuning := _ensure_fixture_tuning(fixture)
	var source: Light3D = fixture.light
	match parameter:
		"energy_multiplier": tuning[parameter] = clampf(value, 0.0, 2.0)
		"range":
			tuning[parameter] = clampf(value, 1.5, 16.0)
			if source is OmniLight3D:
				source.omni_range = tuning[parameter]
		"attenuation":
			tuning[parameter] = clampf(value, 0.8, 3.2)
			if source is OmniLight3D:
				source.omni_attenuation = tuning[parameter]
		"temperature":
			tuning[parameter] = clampf(value, 1800.0, 6500.0)
			source.light_color = _temperature_color(tuning[parameter])
			if "_bulb_mat" in fixture and fixture._bulb_mat:
				fixture._bulb_mat.emission = source.light_color
		"source_size":
			tuning[parameter] = clampf(value, 0.02, 0.50)
			source.light_size = tuning[parameter]
		"shadow_opacity": tuning[parameter] = clampf(value, 0.0, 1.0)
		"flicker_depth":
			tuning[parameter] = clampf(value, 0.0, 0.30)
			_set_flicker_property(fixture, "depth", tuning[parameter])
		"flicker_rate":
			tuning[parameter] = clampf(value, 0.10, 4.0)
			_set_flicker_property(fixture, "rate", tuning[parameter])
	_fixture_tuning[str(fixture.name)] = tuning


func _set_flicker_property(fixture: Node, kind: String, value: float) -> void:
	var candidates := ["_flicker_depth", "_drift_depth"] if kind == "depth" \
			else ["_flicker_speed", "_drift_speed"]
	for property_name in candidates:
		for property in fixture.get_property_list():
			if str(property.name) == property_name:
				fixture.set(property_name, value)
				return


func _temperature_color(kelvin: float) -> Color:
	# Perceptual art-direction ramp, bounded to plausible practical lamps.
	if kelvin <= 3200.0:
		return Color(1.0, 0.36, 0.10).lerp(
				Color(1.0, 0.80, 0.58), (kelvin - 1800.0) / 1400.0)
	return Color(1.0, 0.80, 0.58).lerp(
			Color(0.88, 0.94, 1.0), (kelvin - 3200.0) / 3300.0)


func _estimate_temperature(color: Color) -> float:
	# Stable initialization is more important than laboratory inversion.
	var cool := clampf((color.b - 0.10) / 0.90, 0.0, 1.0)
	return lerpf(2000.0, 5200.0, cool)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < INTERVAL:
		return
	_accum = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Use the controller's feet, not an assumed adult eye height. This remains
	# correct for the five-foot player, crouching and camera-bob cinematics.
	var players := get_tree().get_nodes_in_group("player_controller")
	var occupied_height := cam.global_position.y - PlayerController.STANDING_EYE
	if not players.is_empty():
		var body := players[0] as Node3D
		# ...but only when the camera is actually ON the controller. A
		# detached camera - the free camera, a cinematic, anything that
		# sets view_override - leaves the body parked where it was, and
		# reading the floor off a parked body gates every fixture around
		# the camera OFF as "another storey". Fly to the fourth floor
		# with the body still in the lobby and the fourth floor is dark:
		# the fixtures are there, they are simply switched off by a
		# storey test answering about somewhere else.
		if body.is_ancestor_of(cam):
			occupied_height = body.global_position.y
	active_floor = _floor_at_height(occupied_height)
	var eye := cam.global_position
	# gate by storey, then rank the survivors so the per-object cap is spent
	# on what the camera is actually standing among
	var eligible: Array = []
	var off: Array = []
	for fixture in _controlled_lights():
		if _is_vertical(fixture) or _fixture_floor(fixture) == active_floor:
			var d2: float = fixture.global_position.distance_squared_to(eye)
			if "navigation_light" in fixture and fixture.navigation_light:
				d2 *= NAV_WEIGHT
			elif fixture.light != null:
				# The room you are STANDING IN owns its light. Without
				# this, the two dozen nav-weighted circulation fixtures
				# (domes, eye pendants) outrank an apartment's own pendant
				# from inside the apartment, and the moment corridors were
				# dimmed to mood the flats went black — the oasis rule
				# inverted by its own budget arithmetic.
				var reach: float = fixture.light.omni_range
				if d2 < reach * reach * 0.55:
					d2 *= 0.04
			eligible.append([d2, fixture])
		else:
			off.append(fixture)
	eligible.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(eligible.size()):
		var on := i < _active_budget
		var fixture: Node = eligible[i][1]
		var tuning := _ensure_fixture_tuning(fixture)
		var local_gain := float(tuning.energy_multiplier)
		fixture.set_budget(fixture_gain * local_gain if on else 0.0, false,
				i < _shadow_budget)
		var source: Light3D = fixture.light
		if source:
			source.shadow_opacity = shadow_opacity \
					* float(tuning.shadow_opacity)
	for fixture in off:
		fixture.set_budget(0.0, false, false)


func _is_vertical(fixture: Node) -> bool:
	return "prop_type" in fixture and fixture.prop_type in VERTICAL_FIXTURES


func _controlled_lights() -> Array:
	var result := get_tree().get_nodes_in_group("light_fixtures")
	result.append_array(get_tree().get_nodes_in_group("floor_lights"))
	return result


func _floor_at_height(height: float) -> String:
	var closest := "F01"
	var distance := INF
	for floor_id in LEVELS:
		var candidate := absf(height - float(LEVELS[floor_id]))
		if candidate < distance:
			distance = candidate
			closest = floor_id
	return closest


func _fixture_floor(fixture: Node) -> String:
	var fixture_name := str(fixture.name)
	for floor_id in LEVELS:
		if fixture_name.begins_with(floor_id + "_"):
			return floor_id
	# Fallback for any future unnamed fixture: its authored transform still
	# identifies the storey, after subtracting a typical ceiling offset.
	return _floor_at_height(fixture.global_position.y - 2.2)


func stats() -> Dictionary:
	var full := 0
	var off := 0
	var shadows := 0
	for fixture in _controlled_lights():
		var source: Light3D = fixture.light
		if source and source.visible and source.light_energy > 0.05:
			full += 1
		else:
			off += 1
		if source and source.shadow_enabled:
			shadows += 1
	return {
		"full": full, "half": 0, "off": off, "shadows": shadows,
		"active_floor": active_floor,
	}
