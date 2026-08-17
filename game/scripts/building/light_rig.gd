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
## So within the active floor we used to keep only the nearest ACTIVE_N,
## ranking circulation fixtures ahead of room fixtures at equal distance.
## DESKTOP NO LONGER RATIONS: the budget came off once the frame proved
## submission-bound rather than light-bound, and desktop takes UNLIMITED.
## The ranking still runs, because mobile still has a budget to spend and
## the order is what decides who gets it.
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
## Desktop no longer reads this — it is the HISTORICAL desktop budget, kept
## because `LIGHT_BUDGET=14 SHADOW_BUDGET=8` reproduces the pre-removal rig
## exactly, which is how the removal was measured and how a regression would
## be re-measured. Delete it only if that sweep goes too.
const ACTIVE_N := 14
## Shadows are priced separately from light, and far higher: an omni's
## shadow is a CUBE, so every caster re-renders the visible set six times.
## Fourteen casters cost more than everything else in the frame put
## together. The nearest few carry the modelling that sells a room — the
## balustrade shadows down the stair, furniture contact — and the rest
## contribute nothing an eye can find, so they light without casting.
##
## ALL OF WHICH WAS REASONING, AND IT WAS WRONG. Measured 2026-08-08 by
## sweeping this value against the perf probe: 0, 8, 24 and 64 casters
## produce the same frame time to within noise, and the same object count
## to within 200. The six-renders-per-caster argument is correct about
## the GPU and irrelevant to this frame, which is CPU-bound on draw call
## submission and has been the whole time — so shadow work lands in time
## that was being spent anyway.
##
## Raised to 32. Not to UNLIMITED, and this one IS a judgement rather than
## a measurement: the shadow atlas is a fixed budget that subdivides per
## caster, so past some count every shadow in the frame gets blurrier in
## exchange for shadows nobody was going to look at. 32 with an 8192
## atlas is 1448 px a side each, which still models a room.
const SHADOW_N := 32
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
## The occupied Orison shell, including the streaming margin. When the player
## is out in STREET, these sources may still illuminate windows and the open
## door, but their shadow maps mostly re-render a sealed interior into an
## exterior frame. The light survives; only that off-zone caster work stops.
const ORISON_CORE_HALF_X := 15.2
const ORISON_CORE_HALF_Z := 11.2
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
# Raised again to 0.80 (ruled 2026-08-08) on the brief that the TORCH was
# doing too much of the work and the building's own fixtures too little.
# The other half of that ruling is in phone_light_mask.gd, which was
# multiplying every fixture in the frame down to a fifth of itself.
var fixture_gain := 0.80
## HOW LIT THE ROOM AROUND THE CAMERA ACTUALLY IS, 0..1. Recomputed each
## tick from the fixtures that are genuinely on, and read by the torch:
## walk into a lit bar and the beam's screen-space vignette gets out of
## the way, walk into a black corridor and it closes back down.
##
## This exists because "the building lights you" and "the torch lights
## you" were two systems that had never been introduced. The torch
## crushed the frame by a constant amount whatever room you were in, so
## the most expensive thing in the building — 215 authored fixtures —
## was competing with a screen-space multiply and losing.
var room_light := 0.0
## What room_light calls fully lit. Standing under a bar pendant at a
## metre sums to about 0.5 across the near fixtures; a corridor with one
## dome four metres off sums to under 0.02, which is the separation this
## is calibrated against. Measured, not guessed — see stats().
const ROOM_LIT_FULL := 0.45
# DayNightDirector owns the absolute sky values. These debug controls are
# dimensionless grading gains, so changing the hour cannot be overwritten by
# the next LightRig tick.
var ambient_gain := 1.0
var sky_key_gain := 1.0
# A bulb should bloom. The threshold used to sit above what the
# fixtures actually emit, so nothing ever crossed it and the glow
# system was running with nothing to do.
var glow_intensity := 0.68
var fog_gain := 1.0
var shadow_opacity := 1.0
var _environment: Environment
var _moon: DirectionalLight3D
var _day_night: DayNightDirector
var _fixture_tuning: Dictionary = {}
var debug_inspect_enabled := false
var selected_debug_fixture: Node
var _debug_handles: Dictionary = {}
var _provenance: Dictionary = {}
## Same-build A/B only. Ordinary play never sets this; forcing core shadows on
## outside reproduces the pre-T7b submission set without reverting production.
var _street_core_shadow_gate_enabled := \
		OS.get_environment("PERF_STREET_CORE_SHADOWS_ON") != "1"
## THE BUDGET IS OFF ON DESKTOP (2026-08-08). Every fixture that passes
## the storey gate is lit, and the ranking below now only decides which
## ones get SHADOWS. The constants above are kept because they are the
## mobile path and because they record what the ceiling was.
##
## The reason it could come off is that the thing it was working around
## was a project setting: limits/opengl/max_lights_per_object was 16, and
## with a whole storey's walls merged into one mesh, 16 was reached by an
## arbitrary subset. Raised to 128, which is past what any storey
## authors, so the subset is no longer arbitrary because it is no longer
## a subset.
##
## Mobile keeps its budget. This is not timidity about a number — a tiler
## pays for lights per fragment and there is no device here to measure on,
## so the honest position is that the desktop figure is measured and the
## mobile one is not, and the unmeasured one keeps its guard rail until
## somebody puts a phone in front of it. See #20.
const UNLIMITED := 4096
@onready var _active_budget: int = \
		ACTIVE_N_MOBILE if OS.has_feature("mobile") else UNLIMITED
@onready var _shadow_budget: int = \
		SHADOW_N_MOBILE if OS.has_feature("mobile") else SHADOW_N


func _ready() -> void:
	# Sweepable from the shell so the ceiling is found by measuring rather
	# than by argument: LIGHT_BUDGET=14 SHADOW_BUDGET=8 reproduces the old
	# rationed rig exactly, which is what any "is this actually costing
	# anything?" question needs on the other side of it.
	var lit := OS.get_environment("LIGHT_BUDGET")
	var shad := OS.get_environment("SHADOW_BUDGET")
	if lit != "":
		_active_budget = maxi(1, int(lit))
	if shad != "":
		_shadow_budget = clampi(int(shad), 0, _active_budget)
	if not _street_core_shadow_gate_enabled:
		print("PERF STREET CORE SHADOW CONTROL: production gate disabled")
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
	_day_night = get_parent().get_node_or_null("DayNightDirector") \
			as DayNightDirector
	if world:
		_environment = world.environment
	apply_tuning()


func set_tuning(parameter: String, value: float) -> void:
	match parameter:
		"fixture_gain": fixture_gain = clampf(value, 0.0, 1.5)
		"ambient_gain": ambient_gain = clampf(value, 0.0, 2.0)
		"sky_key_gain": sky_key_gain = clampf(value, 0.0, 2.0)
		"glow_intensity": glow_intensity = clampf(value, 0.0, 1.5)
		"fog_gain": fog_gain = clampf(value, 0.0, 2.0)
		"shadow_opacity": shadow_opacity = clampf(value, 0.0, 1.0)
	apply_tuning()


func apply_tuning() -> void:
	if _environment:
		_environment.glow_intensity = glow_intensity
	if _day_night:
		_day_night.set_tuning_offsets(ambient_gain, fog_gain, sky_key_gain)
	if _moon:
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
		"ambient_gain": ambient_gain,
		"sky_key_gain": sky_key_gain,
		"glow_intensity": glow_intensity,
		"fog_gain": fog_gain,
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


## AN EXPLICIT SWEEP BEATS THE HARDCODED DEFAULT, and it did not until
## 2026-08-16. `_ready` reads LIGHT_BUDGET/SHADOW_BUDGET, but BuildingRoot
## calls this immediately after `add_child`, so the env values were read and
## then silently discarded on every run. The documented way to answer "is
## this budget actually costing anything?" therefore did nothing at all —
## which is the reason nobody ever re-derived the 16/16, and the reason the
## comment justifying it still cites a per-object ceiling of sixteen that
## has since become 128. A measurement tool that quietly no-ops is worse
## than no tool. The sweep now wins; production, which sets no env, is
## unchanged.
func set_budgets(lights: int, shadows: int) -> void:
	var lit := OS.get_environment("LIGHT_BUDGET")
	var shad := OS.get_environment("SHADOW_BUDGET")
	if lit != "" or shad != "":
		_active_budget = maxi(1, int(lit)) if lit != "" else _active_budget
		_shadow_budget = clampi(int(shad), 0, _active_budget) \
				if shad != "" else mini(_shadow_budget, _active_budget)
		print("[LIGHT RIG] sweep override: %d active / %d shadow"
				% [_active_budget, _shadow_budget])
		return
	_active_budget = maxi(1, lights)
	_shadow_budget = clampi(shadows, 0, _active_budget)
	# TASKS.md P4: a wrong budget number survived in three documents because
	# nothing ever printed the one actually in force. Every caller and every
	# perf log now gets the resolved pair on the record.
	print("[LIGHT RIG] budgets resolved: %d active / %d shadow"
			% [_active_budget, _shadow_budget])


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
		"range": _light_reach(source) if source != null else 8.0,
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
			# PARAM_RANGE is the same parameter on an omni and a spot, so the
			# debug sliders reach a desk lamp as well as a ceiling dome.
			tuning[parameter] = clampf(value, 1.5, 16.0)
			if source != null:
				source.set_param(Light3D.PARAM_RANGE, tuning[parameter])
		"attenuation":
			tuning[parameter] = clampf(value, 0.8, 3.2)
			if source != null:
				source.set_param(Light3D.PARAM_ATTENUATION, tuning[parameter])
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
	var occupied := Vector3(eye.x, occupied_height, eye.z)
	var building := get_parent()
	var street_exterior := _street_core_shadow_gate_enabled \
			and occupied_height >= -0.45 \
			and occupied_height <= 2.25 \
			and building.has_method("weather_exposure_at") \
			and bool(building.call("weather_exposure_at", occupied))
	# Gate by storey, then rank the survivors so a BUDGET is spent on what the
	# camera is actually standing among. Desktop no longer has one to spend
	# (see the header: cap 128, UNLIMITED) and the ranking is inert there;
	# mobile still rations and the order is what decides who gets it.
	var eligible: Array = []
	var off: Array = []
	for fixture in _controlled_lights():
		# A local task-lamp key is an authoritative open contact, not a request
		# to draw a black light.  Do not spend a mobile budget slot on it
		# (this said "one of the sixteen slots" before the cap went to 128);
		# set_budget(0) below still keeps the LightRig's side of the contract.
		if fixture.has_method("is_locally_enabled") \
				and not bool(fixture.call("is_locally_enabled")):
			off.append(fixture)
			continue
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
				var reach: float = _light_reach(fixture.light)
				if d2 < reach * reach * 0.55:
					d2 *= 0.04
			eligible.append([d2, fixture])
		else:
			off.append(fixture)
	eligible.sort_custom(func(a, b): return a[0] < b[0])
	var lit := 0.0
	for i in range(eligible.size()):
		var on := i < _active_budget
		var fixture: Node = eligible[i][1]
		var tuning := _ensure_fixture_tuning(fixture)
		var local_gain := float(tuning.energy_multiplier)
		var source: Light3D = fixture.light
		var source_in_core := source != null \
				and absf(source.global_position.x) <= ORISON_CORE_HALF_X \
				and absf(source.global_position.z) <= ORISON_CORE_HALF_Z
		# A fixture may decline the shadow slot its rank would have bought it.
		# Read defensively: not everything in this list is a LightFixtureProp,
		# and a missing property must mean "casts", never "silently stops".
		var declared: Variant = fixture.get("wants_shadow")
		var wants_shadow: bool = declared == null or bool(declared)
		fixture.set_budget(fixture_gain * local_gain if on else 0.0, false,
				i < _shadow_budget and wants_shadow \
				and not (street_exterior and source_in_core))
		if source:
			source.shadow_opacity = shadow_opacity \
					* float(tuning.shadow_opacity)
		# Sum what is actually landing on the camera. Read AFTER set_budget
		# and off the LIGHT rather than off the authored energy on purpose:
		# a fixture that is off, dimmed to standby, or mid-flicker should
		# count for what it is emitting this instant, not for what it was
		# authored at. It answers one tick stale because the fixture applies
		# its own scale in its own _process — 0.12 s, beneath noticing.
		# Any lit fixture counts, not only the omnis. Gating this on
		# OmniLight3D meant a desk lamp two feet from the camera contributed
		# nothing to the measured exposure it was plainly providing.
		if on and source != null and source.visible:
			var d: float = fixture.global_position.distance_to(eye)
			var reach: float = _light_reach(source)
			if d < reach:
				lit += source.light_energy * pow(1.0 - d / reach,
						source.get_param(Light3D.PARAM_ATTENUATION))
	room_light = clampf(lit / ROOM_LIT_FULL, 0.0, 1.0)
	for fixture in off:
		fixture.set_budget(0.0, false, false)



## How far a fixture's light actually reaches, whatever kind of light it is.
##
## This rig was written when every fixture in the building was an OmniLight3D,
## and read `omni_range` directly in three places. The first SpotLight3D to
## arrive - the desk lamps, which point down at the work rather than filling the
## room - threw `Invalid access to property or key 'omni_range'` and aborted the
## budget loop partway through, so every fixture sorted after a lamp silently
## kept its shadows off. The lighting audit went from PASS to 77 failures and
## the cause was three property reads.
##
## `Light3D.PARAM_RANGE` is the same parameter under both names.
static func _light_reach(source: Light3D) -> float:
	if source == null:
		return 0.0
	return source.get_param(Light3D.PARAM_RANGE)


func _is_vertical(fixture: Node) -> bool:
	# vertical_zone meta: a venue that genuinely spans storeys (the
	# Harukiya's street-to-basement shaft) opts its fixtures out of the
	# storey gate; distance ranking already keeps them from stealing
	# budget anywhere else in the building.
	return fixture.has_meta("vertical_zone") \
			or ("prop_type" in fixture
			and fixture.prop_type in VERTICAL_FIXTURES)


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
		# Exposed so the torch's backing-off can be checked by number
		# instead of by squinting: stand in the bar and this should read
		# near 1, stand in a basement corridor and near 0.
		"room_light": room_light,
	}
