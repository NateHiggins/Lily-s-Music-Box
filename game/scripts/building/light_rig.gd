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

var active_floor := "F01"
var _accum := 0.0
## Global grading is deliberately separate from authored light reach. Cutting
## energy must not make shadows vanish sooner: omni_range and the moon's
## directional_shadow_max_distance are never derived from this value.
var fixture_gain := 0.50
# Moonlit floor (ruled 2026-08-04): shadows read midnight blue against
# the warm fixtures and the blue phone torch. Keep in step with
# building_root._build_environment.
var ambient_energy := 0.08
var moon_energy := 0.052
var glow_intensity := 0.42
var fog_density := 0.014
var shadow_opacity := 1.0
var _environment: Environment
var _moon: DirectionalLight3D
## Resolved once: OS.has_feature is a string lookup, not something to do
## per fixture per tick. Writable so the budget can be tuned on the device
## it has to run on, with the frame counter visible next to it.
@onready var _active_budget: int = \
		ACTIVE_N_MOBILE if OS.has_feature("mobile") else ACTIVE_N
@onready var _shadow_budget: int = \
		SHADOW_N_MOBILE if OS.has_feature("mobile") else SHADOW_N


func _ready() -> void:
	_bind_environment()
	call_deferred("_report_authored_lights")


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
		occupied_height = (players[0] as Node3D).global_position.y
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
		eligible[i][1].set_budget(fixture_gain if on else 0.0, false,
				i < _shadow_budget)
		var source: Light3D = eligible[i][1].light
		if source:
			source.shadow_opacity = shadow_opacity
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
