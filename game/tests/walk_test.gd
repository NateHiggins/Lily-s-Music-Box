extends Node
## Headless building validation — not shipped gameplay. Run:
##   godot --headless --path game res://tests/WalkTest.tscn
## The normal command is the iteration gate: it builds the complete Orison
## and checks layout, systems and the current prop family in about one boot.
## WALKTEST_FULL=1 adds the slow physical walks, elevator rides and case
## simulations for release gates. Making every mesh edit wait for those
## authored performances trained people to stop running the test at all.
## Exits with the failure count as exit code.

var root: Node3D
var _failures := 0
var _arrivals := {}
var _full := OS.get_environment("WALKTEST_FULL") == "1"
## HOW FAST THE CLOCK RUNS. The FULL pass is gated on a body physically
## walking the building at 2.8 m/s — up the stair, round two flats, into
## the lift and back — and every metre of that was wall-clock time
## nobody got back. 208 seconds of it.
##
## Engine.time_scale multiplies delta, so the player covers four times
## the ground per real second AND every create_timer in here fires four
## times sooner, because those are scaled too. The _goto timeouts are in
## the same scaled seconds, so their budgets stay exactly as authored.
##
## PHYSICS TICKS RISE WITH IT, and that is the part that matters. Scaling
## time alone would quadruple how far the capsule moves per physics step,
## which is how a collision test starts tunnelling through the walls it
## exists to prove are solid — and a walk test that walks through a wall
## does not fail, it PASSES for the wrong reason. At 240 Hz the
## displacement per step is identical to 60 Hz at normal speed, so the
## contact solver sees exactly the run it always saw, four times sooner.
##
## WALKTEST_SCALE overrides it; 1.0 restores real time if a result ever
## looks scale-dependent, which is the first thing to try if this test
## starts disagreeing with itself.
const BASE_TICKS := 60
@onready var _scale: float = maxf(1.0, float(
		OS.get_environment("WALKTEST_SCALE")) if
		OS.get_environment("WALKTEST_SCALE") != "" else 4.0)


func _record_arrival(node_id: String, i: int, _a: float, _p: float,
		_s: float) -> void:
	if i != 0:
		return  # compare like with like: only the motif's downbeat
	if not _arrivals.has(node_id):
		_arrivals[node_id] = []
	# RECORDED IN SIM MILLISECONDS, NOT WALL ONES. Time.get_ticks_msec is
	# wall clock and does not care about Engine.time_scale, but the thing
	# being measured — a motif propagating up a riser through the acoustic
	# graph — runs on scaled delta. At 4x, a 117 ms sweep arrives 26 ms
	# apart on the wall and the assertion below (30..600) failed a
	# perfectly healthy building.
	#
	# It failed LOUDLY, which is the only reason this is a footnote rather
	# than a bug hunt: the number in the message was a quarter of what it
	# should have been and said so. A timing assertion that had been
	# written as "> 0" would have passed at any speed and quietly stopped
	# testing anything.
	_arrivals[node_id].append(int(Time.get_ticks_msec() * _scale))


## Same-loop delta: first F02 downbeat, then the next F05 downbeat at or
## after it. Sampling mid-loop otherwise pairs arrivals from different
## loops and produces a bogus negative delta.
func _riser_delta_ms() -> int:
	var a2: Array = _arrivals.get("F02_B_RADIATOR_01", [])
	var a5: Array = _arrivals.get("F05_B_RADIATOR_01", [])
	if a2.is_empty() or a5.is_empty():
		return -99999
	var t2: int = a2[0]
	for t5 in a5:
		if t5 >= t2:
			return t5 - t2
	return -99999


func _both_radiators_reached() -> bool:
	return _riser_delta_ms() > -99999


## Smallest positive gap from any a-arrival to the next b-arrival: pairs
## the same emission across two paths regardless of sampling phase.
func _paired_gap_ms(a_id: String, b_id: String) -> int:
	var a: Array = _arrivals.get(a_id, [])
	var b: Array = _arrivals.get(b_id, [])
	var best := 999999
	for ta in a:
		for tb in b:
			if tb >= ta and tb - ta < best:
				best = tb - ta
	return best if best < 999999 else -1


func _ready() -> void:
	# BEFORE the building is built, not after. The campaign persists to a
	# user save and the suite was silently inheriting it: on a machine that
	# had ever opened Mina's case, her evidence interactables came up with
	# collision enabled and one of them — the redaction pencil — stands in
	# the 2A living room on the exact line the bedroom walk takes. A fresh
	# clone passed and this machine failed, which is the worst kind of flake.
	# Case gameplay reads the campaign once in _ready(), so resetting after
	# instantiation is far too late to matter.
	OS.set_environment("DAYNIGHT", "0")   # tests live at the canonical 03:00
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	# Emptying the case table is NOT the same as a first launch, and the
	# difference is load-bearing: MinaCaseGameplay._refresh() early-returns
	# on an empty state, which leaves her evidence interactables at their
	# default `enabled` — solid — instead of switching them off for an
	# unseen case. Seed every case the way a first run does, or the reset
	# lands somewhere worse than the save it was escaping.
	for case_id in RealityCases.definitions:
		var definition: Dictionary = RealityCases.definitions[case_id]
		RealityState.ensure_case(case_id,
				str(definition.get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	Engine.time_scale = _scale
	Engine.physics_ticks_per_second = int(round(BASE_TICKS * _scale))
	print("[WALKTEST] %s mode, sim x%.1f (%d Hz physics)"
			% ["FULL" if _full else "FAST", _scale,
			Engine.physics_ticks_per_second])
	await get_tree().create_timer(0.6).timeout
	root.show_all_floors = true
	# The sanity director moves furniture and rewrites light energies on its
	# own schedule, which is exactly what the lighting and prop assertions
	# below measure. It gets stood down for the deterministic pass and is
	# driven explicitly in _sanity_checks() at the end.
	if root.sanity:
		root.sanity.stand_down()

	var levels: Dictionary = root.layout["meta"]["levels"]
	for fid in levels:
		var z: float = levels[fid]
		var p := Vector3(4.3, z + 1.5, 0.0) if fid != "ROOF" \
				else Vector3(0.0, z + 1.5, 8.0)
		_check(_floor_below(p), "%s has walkable floor" % fid)
	_check(_floor_below(Vector3(-9.5, 11.2, -4.8)), "apartment 4B has a slab")
	_check(_floor_below(Vector3(9.5, 11.2, -4.8)), "apartment 4C has a slab")
	_check(_floor_below(Vector3(0.0, -1.3, 5.0)), "basement corridor floor")
	# B1 once had two coincident corridor walls: the authored wall carried
	# four door cuts, while a generic solid wall behind it made every room
	# unreachable. Probe through each opening at chest height so the duplicate
	# can never return unnoticed.
	var basement_space := get_viewport().world_3d.direct_space_state
	var basement_doors := [
		[Vector3(-4.55, -1.75, 5.05), Vector3(-6.05, -1.75, 5.05),
				"storage cages"],
		[Vector3(-4.55, -1.75, -6.16), Vector3(-6.05, -1.75, -6.16),
				"laundry"],
		[Vector3(4.55, -1.75, 5.325), Vector3(6.05, -1.75, 5.325),
				"electrical room"],
		[Vector3(4.55, -1.75, -4.385), Vector3(6.05, -1.75, -4.385),
				"boiler room"],
	]
	for probe in basement_doors:
		var doorway_ray := PhysicsRayQueryParameters3D.create(probe[0], probe[1])
		_check(basement_space.intersect_ray(doorway_ray).is_empty(),
				"B1 %s doorway is physically open" % probe[2])

	var props := 0
	for c in root.get_children():
		if c is FunctionalProp:
			props += 1
	_check(props >= 25, "functional props spawned (%d)" % props)

	var beat_before: int = Conductor._beat_i
	await get_tree().create_timer(2.0).timeout
	_check(Conductor._beat_i > beat_before, "conductor clock is beating")

	# --- lighting model: every fixture on the active floor is enabled
	var fixtures := 0
	for c2 in root.get_children():
		if c2 is LightFixtureProp:
			fixtures += 1
	_check(fixtures >= 100,
			"light fixtures spawned across the building (%d)" % fixtures)
	var residents := get_tree().get_nodes_in_group("resident_placeholders")
	_check(residents.size() == 18,
			"all resident NPC placeholders spawned (%d)" % residents.size())
	var hq: MaintenanceHeadquarters = root.maintenance_headquarters
	_check(hq != null, "Reality Maintenance headquarters placed")
	_check(hq != null and hq.trophy_slot_count() == 18,
			"headquarters has one trophy slot per resident case")
	_check(hq != null and hq.unlocked_gear_count() >= 1,
			"headquarters issues the starting inspection tool")
	var exterior: ExteriorDetailPass = root.exterior_detail_pass
	_check(exterior != null and exterior.detail_count >= 250,
			"exterior finish details stay batched (%d)" %
			[exterior.detail_count if exterior else 0])
	_check(exterior != null and exterior.puddle_count == 8,
			"reflective street puddles placed")
	_check(exterior != null and exterior.decal_count == 11,
			"exterior damage decals placed")
	_check(exterior != null and exterior.faulty_lamp_count == 1,
			"one street lamp carries the intermittent fault")
	_check(root.weather != null
			and root.weather.get_node_or_null("DistantLightning") != null,
			"distant lightning source is active")
	await _plumbing_checks()
	_laundry_checks()
	_toaster_checks()
	_kettle_fast_checks()
	_radiator_checks()
	_vantry_checks()
	await _boxfan_checks()
	_exhaust_fan_checks()
	_flue_breast_checks()
	_prop_mesh_and_boiler_checks()
	_medicine_cabinet_checks()
	_story_board_checks()
	_clock_checks()
	_mail_bank_checks()
	_shop_static_checks()
	if not _full:
		await _finish("FAST")
		return
	# Placeholders land at the centre of each resident's main room, which is
	# where the door-to-bedroom route runs. Solid ones block it, and the
	# generator's movement audit — which authors those clearances — cannot
	# see actors added in Godot. They stay walk-through until a person is
	# placed by the same pass that proves the route.
	var blocking := 0
	for npc in residents:
		for part in npc.get_children():
			if part is StaticBody3D and part.collision_layer != 0:
				blocking += 1
	_check(blocking == 0,
			"resident placeholders do not obstruct audited routes")
	await get_tree().create_timer(1.2).timeout  # let the rig settle
	var lst: Dictionary = root.light_rig.stats()
	# The rig gates by storey and then spends a bounded working set on the
	# nearest fixtures, because GL compatibility caps lights PER OBJECT and
	# each floor's walls are one merged mesh: enabling a whole storey hands
	# that cap to an arbitrary subset and corridors go black mid-run.
	var eligible := 0
	var stray_floor := 0
	var casting_unlit := 0
	var lit_circulation := 0
	for fixture in root.light_rig._controlled_lights():
		var vertical: bool = root.light_rig._is_vertical(fixture)
		if vertical or root.light_rig._fixture_floor(fixture) == "F01":
			eligible += 1
		var src: Light3D = fixture.light
		var lit: bool = src != null and src.visible and src.light_energy > 0.05
		# A shadow map on an unlit fixture is pure waste: six cube faces
		# rendered for a light contributing nothing.
		if src != null and src.shadow_enabled and not lit:
			casting_unlit += 1
		if not lit:
			continue
		if not vertical and root.light_rig._fixture_floor(fixture) != "F01":
			stray_floor += 1
		if "navigation_light" in fixture and fixture.navigation_light:
			lit_circulation += 1
	_check(lst.active_floor == "F01" and stray_floor == 0 and lst.off > 0,
			"floor lighting: nothing off-storey is lit (%d lit, %d dark)" %
			[lst.full, lst.off])
	# Compare against the RESOLVED budgets, not the desktop constants: a
	# mobile build deliberately runs a smaller working set and one caster.
	_check(lst.full == mini(eligible, root.light_rig._active_budget),
			"the working set is the nearest %d of %d eligible fixtures" %
			[lst.full, eligible])
	# Shadows are budgeted separately from light and far more tightly: an
	# omni's shadow is a cube, so each caster re-renders the visible set
	# six times. Casters are the nearest few of the lit set, never more.
	_check(casting_unlit == 0,
			"no unlit fixture wastes a shadow map (%d casters)" % lst.shadows)
	_check(lst.shadows == mini(eligible, root.light_rig._shadow_budget),
			"shadow casters capped at the nearest %d" % lst.shadows)
	# the complaint this rig exists to answer: a corridor lit end to end
	_check(lit_circulation >= 4,
			"circulation fixtures hold the budget (%d lit)" % lit_circulation)
	var moon := root.get_node_or_null("ExteriorMoon") as DirectionalLight3D
	_check(moon != null and moon.shadow_enabled,
			"exterior moon casts directional shadows")

	_check(ProjectSettings.get_setting(
			"rendering/occlusion_culling/use_occlusion_culling", false),
			"occlusion culling is enabled for the project")

	# --- night occupancy: the building has to read as lived in from the
	# street, where the storey gate means at most one floor's fixtures burn
	var glow := root.get_node_or_null("WindowGlow")
	var glow_stats: Dictionary = glow.stats() if glow else {}
	_check(int(glow_stats.get("lit", 0)) > 20,
			"windows glow from outside at night (%d lit, %d dark)" %
			[glow_stats.get("lit", 0), glow_stats.get("dark", 0)])
	# The Orison's own windows no longer carry lit panels at all (ruled
	# 2026-08-05: they were opaque quads pasted over the glass, and the
	# facade read as a grid of rectangles). The lit/dark census now
	# describes the NEIGHBOURS across the street, which is where panels
	# still earn their keep - so "dark" counts nothing here, and the
	# check that matters is that the city outside is not uniformly lit.
	_check(int(glow_stats.get("lit", 0)) > 20
			and not OrisonWindowGlow.OWN_WINDOW_PANELS,
			"neighbour windows carry the night, the Orison shows its own rooms")
	var one_sided := true
	var casts := false
	if glow:
		for g in glow.get_children():
			if g is MeshInstance3D:
				var gm: StandardMaterial3D = g.material_override
				if gm == null or gm.cull_mode != BaseMaterial3D.CULL_BACK:
					one_sided = false
				if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					casts = true
	# Single-sided is what keeps the glow out of the room it belongs to:
	# from inside you see its culled back face and the real night sky.
	_check(one_sided, "window glows are single-sided (unseen from inside)")
	_check(not casts, "window glows cast no shadows")

	# --- touch controls: the phone HUD has to drive the same player the
	# keyboard does, or the Android build is a slideshow you cannot steer
	var tc: TouchControls = root.touch
	_check(tc != null, "touch HUD present")
	if tc:
		tc.set_enabled(true)
		root.player.touch_input = true
		await get_tree().process_frame
		var scr := Vector2(get_viewport().get_visible_rect().size)
		# thumb lands in the left zone, then pushes forward (screen -Y)
		var origin := Vector2(scr.x * 0.18, scr.y * 0.72)
		tc._press(0, origin)
		tc._drag(0, origin + Vector2(0, -scr.y * 0.20))
		_check(Input.get_action_strength("move_forward") > 0.5,
				"stick drives move_forward (%.2f)" %
				Input.get_action_strength("move_forward"))
		tc._drag(0, origin + Vector2(scr.x * 0.20, 0))
		_check(Input.get_action_strength("move_right") > 0.5
				and Input.get_action_strength("move_forward") == 0.0,
				"stick steers right and releases forward")
		tc._release(0)
		_check(Input.get_action_strength("move_right") == 0.0
				and Input.get_action_strength("move_left") == 0.0,
				"lifting the thumb stops the player")
		# a drag on the right half looks, and must not also walk
		var before_yaw: float = root.player.rotation.y
		tc._press(1, Vector2(scr.x * 0.75, scr.y * 0.5))
		tc._drag(1, Vector2(scr.x * 0.75 + 120.0, scr.y * 0.5))
		await get_tree().process_frame
		_check(absf(root.player.rotation.y - before_yaw) > 0.05,
				"right-side drag turns the camera")
		_check(Input.get_action_strength("move_forward") == 0.0,
				"looking does not also walk")
		tc._release(1)
		# the action cluster: momentary fires and releases, toggles latch
		var e_btn: Dictionary = tc._buttons[0]
		tc._press(2, e_btn["centre"])
		_check(Input.is_action_pressed("interact"),
				"interact button presses its action")
		tc._release(2)
		_check(not Input.is_action_pressed("interact"),
				"interact releases with the finger")
		var run_btn: Dictionary = tc._buttons[2]
		tc._press(3, run_btn["centre"])
		tc._release(3)
		_check(Input.is_action_pressed("run"),
				"run latches on (nobody holds a thumb down to jog)")
		tc._press(3, run_btn["centre"])
		tc._release(3)
		_check(not Input.is_action_pressed("run"), "run latches off again")
		# The HUD must take only what the UI did not want. Handling touches
		# in _input instead swallows every tap before Controls see it, and
		# on a phone the debug panel and the call interface stop responding
		# entirely — with nothing on screen to suggest why.
		_check(not tc.has_method("_input"),
				"the HUD sits on _unhandled_input, behind the UI")
		tc.set_enabled(false)
		root.player.touch_input = false
		_check(Input.get_action_strength("move_forward") == 0.0,
				"disabling the HUD releases everything it held")
	# The mobile budget is adjustable at runtime because its first values
	# were reasoned about rather than measured, and read too dark on a real
	# device. Clamped so shadows can never exceed the lights that cast them.
	var rig: LightRig = root.light_rig
	var keep_a: int = rig._active_budget
	var keep_s: int = rig._shadow_budget
	rig.set_budgets(10, 99)
	_check(rig._shadow_budget == 10,
			"shadow budget cannot exceed the light budget (%d)"
			% rig._shadow_budget)
	rig.set_budgets(0, 0)
	_check(rig._active_budget >= 1, "light budget never reaches zero")
	rig.set_budgets(keep_a, keep_s)
	_check(rig._active_budget == keep_a and rig._shadow_budget == keep_s,
			"budgets restore")

	# --- the reading nook at the foot of the light tree is a PLACE, so it
	# has to be reachable on foot like everything else: basement corridor,
	# through the hall arch, onto the court floor, in past the bench.
	var pl0: PlayerController = root.player
	pl0.global_position = Vector3(0.0, -2.65, 7.6)   # B1 inner hall
	pl0.velocity = Vector3.ZERO
	await _goto(pl0, Vector2(-1.2, 5.0), 5.0)        # hall arch
	await _goto(pl0, Vector2(-0.5, 2.6), 4.0)        # court arch
	await _goto(pl0, Vector2(-0.48, 0.35), 4.0)      # into the nook
	pl0.autopilot = Vector3.ZERO
	_check(pl0.global_position.z < 1.1 and pl0.global_position.y < -2.0,
			"reading nook reached on foot at the tree's base (z=%.2f)"
			% pl0.global_position.z)

	# --- south corridor -> elevator hall -> atrium deck -> up the west
	# flight to the north landing -> east flight onto the F02 deck
	var pl: PlayerController = root.player
	pl.global_position = Vector3(0.0, 0.15, 7.6)  # inner lobby
	pl.velocity = Vector3.ZERO
	await _goto(pl, Vector2(-1.2, 5.0), 5.0)    # through the hall arch
	await _goto(pl, Vector2(-0.5, 2.6), 4.0)    # court arch, onto the deck
	await _goto(pl, Vector2(-2.31, 2.4), 3.0)   # west flight foot
	await _goto(pl, Vector2(-2.31, -2.31), 7.0) # up to the north landing
	await _goto(pl, Vector2(2.31, -2.31), 4.0)  # across the landing
	await _goto(pl, Vector2(2.31, 2.5), 7.0)    # east flight to F02 deck
	await _goto(pl, Vector2(0.3, 5.0), 4.0)     # out into the F02 hall
	pl.autopilot = Vector3.ZERO
	_check(pl.global_position.y > 2.9,
			"atrium stair climbed corridor-to-corridor (y=%.2f)"
			% pl.global_position.y)

	# --- physical movement sweep: corridor ring loop on F02, then into
	# 2A and through the RELOCATED bedroom door (the audit's biggest find)
	pl.global_position = Vector3(4.38, 3.35, 6.0)
	pl.velocity = Vector3.ZERO
	for wp in [Vector2(4.38, -6.0), Vector2(4.38, -8.3),
			Vector2(0.0, -8.3), Vector2(-4.38, -8.3), Vector2(-4.38, -6.0),
			Vector2(-4.38, 6.0), Vector2(-4.38, 8.3), Vector2(0.0, 8.3),
			Vector2(4.38, 8.3), Vector2(4.38, 6.0)]:
		await _goto(pl, wp, 8.0)
	_check(Vector2(pl.global_position.x, pl.global_position.z)
			.distance_to(Vector2(4.38, 6.0)) < 0.6,
			"F02 corridor ring walked full loop")
	var entry2a: DoorProp = null
	for c3 in root.get_children():
		if c3 is DoorProp and c3.global_position.distance_to(
				Vector3(-5.33, 3.2, 2.105)) < 0.9:
			entry2a = c3
	if entry2a and entry2a.leaf_state == "locked":
		# The opening lockdown seals every unit but 4B; the architecture
		# audit carries the maintenance master key.
		entry2a.leaf_state = "closed"
	if entry2a and not entry2a.open:
		entry2a.interact(null)
		await get_tree().create_timer(0.7).timeout
	pl.global_position = Vector3(-4.7, 3.35, 1.65)
	pl.velocity = Vector3.ZERO
	await _goto(pl, Vector2(-7.0, 1.65), 5.0)   # through 2A entry
	await _goto(pl, Vector2(-9.8, 2.2), 5.0)    # west of the dining table
	await _goto(pl, Vector2(-9.8, 5.2), 5.0)
	await _goto(pl, Vector2(-8.5, 5.3), 4.0)    # clear of the door swing
	var bed2a: DoorProp = null
	for c4 in root.get_children():
		if c4 is DoorProp and c4.global_position.distance_to(
				Vector3(-9.215, 3.2, 6.25)) < 0.6:
			bed2a = c4
	_check(bed2a != null, "2A bedroom door found at relocated position")
	if bed2a and not bed2a.open:
		bed2a.interact(null)
		await get_tree().create_timer(0.7).timeout
	# Budgets, not deadlines. _goto gives up silently when its timer runs
	# out, so a slow frame turned into "2A bedroom reached through its own
	# door" FAILING at z=6.70 against a 6.8 threshold - 10 cm short, on an
	# assertion that is about whether the doorway is passable, not about
	# how fast the walk is. It failed roughly one run in eight, which is
	# the worst rate there is: often enough to waste a build, rare enough
	# to train you to dismiss it. These legs are ~1.6 m; 7 s is slack.
	await _goto(pl, Vector2(-8.62, 6.55), 7.0)  # east lane past the leaf
	await _goto(pl, Vector2(-9.5, 7.9), 7.0)    # to the bedside
	pl.autopilot = Vector3.ZERO
	_check(pl.global_position.z > 6.8,
			"2A bedroom reached through its own door (z=%.2f)"
			% pl.global_position.z)

	# every fixture must hang from its own storey's ceiling — a fixture
	# low over its floor means it punched through into the level above
	var lvls2: Array = [-2.8, 0.0, 3.2, 6.4, 9.6, 12.8, 16.0, 19.2]
	var low_fix := []
	for f5 in get_tree().get_nodes_in_group("light_fixtures"):
		# Two families have no ceiling to hang from: street lamps stand on
		# the pavement on a mast, and the court's lights are fruit on the
		# branches of the light tree. "Too low for its storey" cannot mean
		# anything for either.
		if f5.prop_type in ["street_lamp", "eye_pendant"]:
			continue
		# Same reasoning, one rung more general: anything the layout
		# flagged as exterior is mounted to the facade or to a canopy,
		# so its height above the storey datum means nothing.
		if f5.is_in_group("exterior_fixtures"):
			continue
		var gy: float = f5.global_position.y
		var own: float = lvls2[0]
		for lz in lvls2:
			if lz <= gy + 0.01:
				own = lz
		if gy - own < 1.8:
			low_fix.append(f5.name)
	_check(low_fix.is_empty(),
			"all fixtures ceiling-mounted in their own storey (low: %s)"
			% [low_fix])

	# --- atrium sightline: from a stair landing the open eye shows every
	# storey, so the whole floor stack must render there
	root.show_all_floors = false
	pl.global_position = Vector3(0.0, 8.15, -2.31)  # F03 half landing
	pl.velocity = Vector3.ZERO
	await get_tree().create_timer(0.4).timeout
	var hidden := []
	for fid2 in root.floor_nodes:
		if not root.floor_nodes[fid2].visible:
			hidden.append(fid2)
	_check(hidden.is_empty(),
			"all floors render from the atrium eye (hidden: %s)" % [hidden])
	var hidden_atrium_props := []
	for floor_id in root.functional_props_by_floor:
		for streamed_prop in root.functional_props_by_floor[floor_id]:
			if not streamed_prop.visible:
				hidden_atrium_props.append(streamed_prop.name)
	_check(hidden_atrium_props.is_empty(),
			"all functional props render across the open atrium eye")
	var hidden_atrium_doors := []
	for floor_id in root.doors_by_floor:
		for streamed_door in root.doors_by_floor[floor_id]:
			if not streamed_door.visible:
				hidden_atrium_doors.append(streamed_door.name)
	_check(hidden_atrium_doors.is_empty(),
			"all doors render across the open atrium eye")
	pl.global_position = Vector3(4.3, 3.35, 0.0)  # corridor: streaming back
	pl.velocity = Vector3.ZERO
	await get_tree().create_timer(0.4).timeout
	_check(not root.floor_nodes["F06"].visible,
			"floor streaming resumes outside the eye")
	# The slab above belongs to the floor above and is correctly hidden here.
	# The active floor must therefore carry its own downward ceiling buffer.
	# This is the regression screenshot_run concealed by forcing every storey
	# visible: a green screenshot could never exercise this state.
	# gen_layout's area-subtraction audit proves room coverage.  Here we prove
	# the imported surface obeys the live floor gate: the owning floor remains,
	# while the slab and ceiling owned by a distant storey both leave the tree.
	var active_ceiling := root.floor_nodes["F02"].find_child(
			"F02_ceiling_plaster", true, false) as VisualInstance3D
	var hidden_upper_ceiling := root.floor_nodes["F06"].find_child(
			"F06_ceiling_plaster", true, false) as VisualInstance3D
	_check(active_ceiling != null and active_ceiling.is_visible_in_tree(),
			"active storey retains its own plaster ceiling buffer")
	_check(hidden_upper_ceiling != null \
			and not hidden_upper_ceiling.is_visible_in_tree(),
			"inactive upper-storey ceiling leaves the render pass")
	for ceiling_floor_id in ["F01", "F02", "F03", "F04", "F05", "F06"]:
		var plaster_buffers: Array[Node] = root.floor_nodes[ceiling_floor_id].find_children(
				"%s_ceiling_plaster" % ceiling_floor_id,
				"VisualInstance3D", true, false)
		_check(plaster_buffers.size() == 1,
				"%s owns one batched plaster ceiling draw (%d)" % [
					ceiling_floor_id, plaster_buffers.size()])
	var f02_props: Array = root.functional_props_by_floor.get("F02", [])
	var f06_props: Array = root.functional_props_by_floor.get("F06", [])
	_check(not f02_props.is_empty() and f02_props.all(
			func(streamed_prop): return streamed_prop.visible),
			"active-storey functional props remain visible")
	_check(not f06_props.is_empty() and f06_props.all(
			func(streamed_prop): return not streamed_prop.visible),
			"closed-storey functional props leave the render and shadow passes")
	var f02_doors: Array = root.doors_by_floor.get("F02", [])
	var f06_doors: Array = root.doors_by_floor.get("F06", [])
	_check(not f02_doors.is_empty() and f02_doors.all(
			func(streamed_door): return streamed_door.visible),
			"active-storey doors remain visible")
	_check(not f06_doors.is_empty() and f06_doors.all(
			func(streamed_door): return not streamed_door.visible),
			"closed-storey doors leave the render and shadow passes")
	root.show_all_floors = true

	# --- elevator travel across full range
	# Residents roam from boot now and share the car; the inspection takes
	# the independent-service key (hall calls refused), waits out any trip
	# in progress, and parks the car at F01 so the sequence is its own.
	var ele: OrisonElevator = root.elevator
	ele.service_mode = true
	await _until(func(): return not ele.moving, 30.0)
	if ele.current != "F01":
		ele.travel_to("F01")
		await _until(func(): return not ele.moving, 30.0)
	_check(ele._doors.size() == ele.stop_order.size(),
			"every elevator stop has landing doors (%d)" % ele._doors.size())
	_check(ele._doors[ele.current]["t"] > 0.99,
			"the doors at the car's own landing stand open")
	for lvl in ele.stop_order:
		if lvl != ele.current:
			_check(ele._doors[lvl]["t"] < 0.01,
					"landing %s is closed off while the car is elsewhere" % lvl)
			break
	ele.travel_to("F06")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(ele._doors["F01"]["t"] < 1.0,
			"doors start closing before the car leaves")
	await _until(func(): return not ele.moving, 30.0)
	_check(ele.current == "F06", "elevator reached F06")
	_check(ele._doors["F06"]["t"] > 0.99, "doors reopen on arrival at F06")
	_check(ele._doors["F01"]["t"] < 0.01,
			"the landing it left is sealed behind it")
	# a rider standing in the cab is carried, not left on the slab
	var pl2: PlayerController = root.player
	pl2.global_position = ele._cabin.global_position + Vector3(0, 0.9, 0)
	pl2.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var rode_from := pl2.global_position.y
	ele.travel_to("B1")
	await _until(func(): return not ele.moving, 30.0)
	_check(ele.current == "B1", "elevator reached B1")
	_check(pl2.global_position.y < rode_from - 12.0,
			"a rider in the cab travels with it (%.1f m)" %
			(rode_from - pl2.global_position.y))
	ele.service_mode = false  # hand the car back to the building

	_check(AcousticGraphData.nodes.size() >= 25,
			"acoustic graph loaded (%d nodes)" % AcousticGraphData.nodes.size())
	_check(not AcousticGraphData.neighbors("F04_B_RADIATOR_01").is_empty(),
			"4B radiator connected to heating network")

	await _vertical_slice_checks()

	await _finish("FULL")


func _finish(mode: String) -> void:
	print("WALKTEST RESULT: %s [%s]" % [
			"PASS" if _failures == 0 else "FAIL (%d)" % _failures, mode])
	# Let the dynamically assembled building release its meshes, materials,
	# timers, signal callables and audio players before the headless engine
	# tears down its ObjectDB. Immediate quit previously stranded a small,
	# deterministic set of test-only instances and printed a false leak alarm.
	_arrivals.clear()
	_stop_audio(root)
	root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	PropAudio.clear_cache()
	await get_tree().process_frame
	get_tree().quit(_failures)


func _plumbing_checks() -> void:
	# The plumbing scripts own complete fixtures now, not handles hovering
	# over Blender geometry. Count the semantic silhouettes, then operate the
	# player's compact sink through the same public API maintenance uses.
	var counts := {"bath_sink": 0, "kitchen_sink": 0, "shower": 0}
	var player_sink: TapProp = null
	var incomplete := []
	for child in root.get_children():
		if child is not TapProp:
			continue
		var tap := child as TapProp
		if counts.has(tap.fixture):
			counts[tap.fixture] += 1
		if tap._handles.size() != 2 or tap._stream == null:
			incomplete.append(tap.name)
		if tap.fixture == "kitchen_sink" and tap.unit == "4B":
			player_sink = tap
	_check(counts.bath_sink == 24,
			"24 complete bath lavatories, including the retail WC")
	_check(counts.kitchen_sink == 19,
			"19 complete kitchen sinks, including 4B and common kitchen")
	_check(counts.shower == 23, "23 complete shower receptors")
	_check(incomplete.is_empty(),
			"every water fixture owns two valves and a stream (%s)" % [incomplete])

	var water_markers := 0
	var wrong_network := []
	for floor_data in root.layout["floors"]:
		for marker in floor_data.get("markers", []):
			if str(marker.get("kind", "")) not in ["sink", "shower"]:
				continue
			water_markers += 1
			if str(marker.get("network", "")) != "water":
				wrong_network.append(str(marker.get("id", "?")))
	_check(water_markers == 66 and wrong_network.is_empty(),
			"all 66 plumbing markers remain on the water network")
	_check(player_sink != null and player_sink.compact_kitchen
			and not player_sink.has_drainboard,
			"4B keeps its compact basin beside the replanned gas range")
	if player_sink:
		player_sink.set_service_pose()
		await get_tree().process_frame
		var flowing := player_sink.get_flow_state()
		_check(flowing.hot and flowing.cold and flowing.stopper
				and player_sink._stream.visible,
				"4B hot valve, cold valve, stopper and stream operate independently")
		player_sink.set_running(false)
		player_sink.set_stopper(false)


func _toaster_checks() -> void:
	var expected := {
		"1A": true, "1D": true, "2A": true, "2B": true,
		"3A": true, "3B": true, "3D": true, "4A": true,
		"4B": true, "4C": true, "5A": true, "6A": true,
		"6B": true, "6C": true,
	}
	var found := {}
	var sample: ToasterProp = null
	for child in root.get_children():
		if child is not ToasterProp:
			continue
		var toaster := child as ToasterProp
		found[toaster.unit] = true
		if toaster.unit == "2A":
			sample = toaster
	_check(found.size() == 14 and found == expected,
			"fourteen intended flats own period single-slot toasters (%s)" % [found.keys()])
	_check(sample != null, "standard 2A kitchen owns a toaster")
	if sample:
		var closed_position: Vector3 = sample._crumb_tray.position
		sample.set_crumb_tray_open(true, 0.0)
		_check(sample.is_crumb_tray_open()
				and is_equal_approx(sample._crumb_tray.position.distance_to(
						closed_position),
						ToasterProp.TRAY_TRAVEL),
				"Orison retrofit crumb tray exposes its full service travel")
		sample.set_crumb_tray_open(false, 0.0)


func _kettle_fast_checks() -> void:
	var units := {}
	var total_meshes := 0
	var maximum_meshes := 0
	for child in root.get_children():
		if child is KettleProp:
			var kettle := child as KettleProp
			units[kettle.unit] = true
			var meshes := _count_meshes(kettle)
			total_meshes += meshes
			maximum_meshes = maxi(maximum_meshes, meshes)
	_check(units.keys().size() == 6
			and ["1A", "1D", "3D", "4B", "4C", "6C"].all(
					func(u): return units.has(u)),
			"six authored households own kettles")
	_check(maximum_meshes <= 8 and total_meshes <= 48,
			"kettles stay at eight meshes each / 48 family total (%d / %d)" %
			[maximum_meshes, total_meshes])
	var evidence := root.get_node_or_null("F04_4C_KETTLE_01") as KettleProp
	_check(evidence != null and evidence.case_id == "4519",
			"4C kettle remains evidence for case 4519")
	var player_kettle := root.get_node_or_null("F04_B_KETTLE_01") as KettleProp
	_check(player_kettle != null
			and player_kettle.get_node_or_null("HandleReach") is Marker3D
			and player_kettle.get_node_or_null("LidReach") is Marker3D
			and player_kettle.get_node_or_null("WhistleReach") is Marker3D
			and player_kettle.get_node_or_null("PlugReach") is Marker3D,
			"kettle handle, lid, whistle and plug remain serviceable")
	if player_kettle:
		player_kettle.set_service_pose()
		var service := player_kettle.get_service_state()
		_check(bool(service.lid_open) and bool(service.whistle_open)
				and bool(service.lifted),
				"kettle service pose opens both caps and lifts the vessel")
		player_kettle.set_lid_open(false, 0.0)
		player_kettle.set_whistle_open(false, 0.0)
		player_kettle.set_lifted(false, 0.0)
		# Deterministic version of the real regression: cycle one leaves a
		# SceneTreeTimer behind, cycle two is OPERATING when it arrives. Calling
		# that old generation must not whistle the new water early.
		player_kettle.heat_time = 999.0
		player_kettle.interact(null)
		var stale_generation: int = player_kettle.get_service_state().cycle_generation
		player_kettle.interact(null)
		player_kettle.interact(null)
		player_kettle._request_whistle(stale_generation)
		_check(player_kettle.state == player_kettle.PState.OPERATING,
				"interrupted boil timer cannot whistle in a later cycle")
		player_kettle.interact(null)
func _laundry_checks() -> void:
	var washers: Array[WasherProp] = []
	var airers: Array[LaundryAirerProp] = []
	for child in root.get_children():
		if child is WasherProp:
			washers.append(child as WasherProp)
		elif child is LaundryAirerProp:
			airers.append(child as LaundryAirerProp)
	_check(washers.size() == 2 and airers.size() == 1,
			"laundry owns two wringers and one rinse-tub/airer ensemble")
	_check(root.get_node_or_null("B1_DRYER_01") == null,
			"the anachronistic automatic dryer is gone")
	if washers.size() != 2 or airers.size() != 1:
		return
	var first := washers[0]
	var second := washers[1]
	_check(absf(first.global_position.z - second.global_position.z) >= 1.10,
			"wringer centres leave at least 1.10 m for swinging heads")
	var required := ["LidReach", "ReleaseReach", "FeedReach",
			"CocksReach", "DrainReach"]
	var missing := []
	for area_name in required:
		if first.get_node_or_null(area_name) is not Area3D:
			missing.append(area_name)
	_check(missing.is_empty(),
			"lid, safety release, feed, cocks and drain remain reachable")
	first.set_service_pose()
	var state := first.get_service_state()
	_check(bool(state.lid_open) and absf(float(state.wringer_angle)) > 30.0
			and float(state.roller_gap) > 0.02,
			"wringer service pose opens the vessel, head and safety gap")
	airers[0].set_service_pose()
	_check(airers[0].is_airer_lowered(),
			"ceiling airer lowers into the Matching-game work zone")
	var washer_meshes := _count_meshes(washers[0]) + _count_meshes(washers[1])
	_check(washer_meshes < 30,
			"both moving wringers stay below 30 meshes total (%d)" % washer_meshes)
	_check(_count_meshes(airers[0]) < 9,
			"paired rinse tubs and airer stay merged (%d meshes)" %
			_count_meshes(airers[0]))
	var graph_nodes: Dictionary = AcousticGraphData.nodes
	_check(graph_nodes.has("B1_WATER_MAIN")
			and str(graph_nodes["B1_WATER_MAIN"].get("network", "")) == "water",
			"laundry terminates at a real water-main graph node")
	var bad_steam_edge := false
	for washer in washers:
		if "BASEMENT_HEADER_WEST" in AcousticGraphData.neighbors(washer.name):
			bad_steam_edge = true
	_check(not bad_steam_edge,
			"laundry water no longer propagates through the steam header")


func _radiator_checks() -> void:
	var radiators := get_tree().get_nodes_in_group("radiators")
	_check(radiators.size() == 23,
			"all 23 one-pipe radiators own working fittings")
	var sample := root.get_node_or_null("F06_C_RADIATOR_01") as RadiatorProp
	var neighbor := root.get_node_or_null("F02_B_RADIATOR_01") as RadiatorProp
	_check(sample != null and neighbor != null,
			"heat balance has radiators on separate floors and risers")
	if sample == null or neighbor == null:
		return
	_check(sample.get_node_or_null("WorkingAssembly/SupplyHandwheel") != null
			and sample.get_node_or_null(
					"WorkingAssembly/CastSections/ReplaceableAirVent") != null,
			"radiator handwheel and replaceable far-end vent remain service parts")
	var total_before: float = root.heat_balance.total_delivered_heat()
	var neighbor_before := float(neighbor.get_heat_state().get("heat", 0.0))
	sample.set_supply_position(0.50, 0.0)
	_check(bool(sample.get_heat_state().get("hammer", false)),
			"partly shut one-pipe supply traps condensate and hammers")
	sample.set_supply_open(true, 0.0)
	sample.set_vent_grade(0)
	var slow_heat := float(sample.get_heat_state().get("heat", 0.0))
	sample.set_vent_grade(4)
	var fast_heat := float(sample.get_heat_state().get("heat", 0.0))
	var neighbor_after := float(neighbor.get_heat_state().get("heat", 0.0))
	_check(fast_heat > slow_heat and neighbor_after < neighbor_before,
			"faster fixed vent warms one flat by cooling another")
	_check(is_equal_approx(root.heat_balance.total_delivered_heat(), total_before),
			"vent changes redistribute a fixed boiler heat cycle")
	sample.set_vent_grade(2)


func _vantry_checks() -> void:
	var network: VantryPointNetwork = root.vantry_points
	var orders: WorkOrders = root.work_orders
	var expected := 0
	for floor in root.layout.get("floors", []):
		for room in floor.get("rooms", []):
			if str(room.get("kind", "")) not in ["roof", "atrium"]:
				expected += 1
	_check(network != null and network.points.size() == expected,
			"every enclosed room owns one Vantry point (%d)" % expected)
	_check(network != null and network.floor_batch_count() == 7
			and network.static_draws_per_floor() == 3,
			"Vantry network stays at three static draws on seven visible floors")
	_check(network != null and network.active_mesh_count() <= 6,
			"movable Vantry owner stays within six meshes (%d)" %
			[network.active_mesh_count() if network else -1])
	_check(orders != null and orders.status(ChirpHunt.ORDER_ID) == "active",
			"minimal WorkOrders spine issues and activates the chirp hunt")
	_check(root.chirp_hunt != null
			and root.chirp_hunt.active_point_id == "F06_D_BED_VANTRY_POINT",
			"chirp hunt caches its authored starting point")
	var graph_ok := network != null
	if network:
		for point_id in network.cached_point_ids():
			var node: Dictionary = AcousticGraphData.nodes.get(point_id, {})
			if str(node.get("network", "")) != "signal" \
					or not (str(network.point_spec(point_id).floor)
							+ "_VANTRY_TRUNK") in AcousticGraphData.neighbors(point_id):
				graph_ok = false
				break
	_check(graph_ok, "all Vantry points terminate on the dedicated signal trunk")
	if network == null:
		return
	var old_id := network.active_point_id
	const TEST_POINT := "F04_B_MAIN_VANTRY_POINT"
	var moved := network.activate(TEST_POINT)
	var old_restored := network.static_instance_visible(old_id)
	var destination_suppressed := not network.static_instance_visible(TEST_POINT)
	_check(moved and old_restored and destination_suppressed,
			"owner handoff restores old face and suppresses destination in one frame "
			+ "(moved=%s old=%s new_hidden=%s)" %
			[moved, old_restored, destination_suppressed])
	network.active_owner.set_service_pose()
	_check(float(network.active_owner.get_service_state().grille_open) == 1.0,
			"Vantry grille exposes its no-battery service interior")
	_check(network.stage_haunt("teresa_call_bells", 1, root.player)
			and network.teresa_telltale_visible(),
			"Teresa closes the mechanical telltale before the room answers")
	_check(PropAudio.get_stream("vantry_chirp") != null,
			"chirp uses an attributed recorded source")
	# Return the sole owner to the point cached by ChirpHunt. Moving it directly
	# above tested the network handoff; the director must still reject a grille
	# that is not its current audio source.
	network.activate(old_id)
	network.active_owner.interact(root.player)
	_check(orders.status(ChirpHunt.ORDER_ID) == "closed",
			"inspecting the active grille closes the first work order")


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children(true):
		_stop_audio(child)


func _vertical_slice_checks() -> void:
	# 4B detailed plan present in the shared model
	var ids := {}
	for fl in root.layout["floors"]:
		for r in fl["rooms"]:
			ids[r["id"]] = true
	for rid in ["F04_B_VESTIBULE", "F04_B_BATH", "F04_B_CLOSET",
			"F04_B_KITCHEN", "F04_B_ALCOVE"]:
		_check(ids.has(rid), "%s in layout" % rid)
	var player_furniture := {}
	for fl in root.layout["floors"]:
		if str(fl.id) != "F04":
			continue
		for item in fl.get("furniture", []):
			var item_id := str(item.get("id", ""))
			if item_id.begins_with("4B"):
				player_furniture[item_id] = item
	_check(player_furniture.has("4B_couch"), "4B has a real couch")
	_check(player_furniture.has("4B_coffee"), "4B has a coffee table")
	_check(player_furniture.has("4B_tv") \
			and str(player_furniture["4B_tv"].get("asm", "")) == "tv",
			"4B has a broadcast television facing the couch")
	_check(root.domestic_witnesses.home_relays.size() == 3,
			"4B has three selective possession relays")
	# bathroom wall physically separates main room from the service band
	var space := get_viewport().world_3d.direct_space_state
	var p := PhysicsRayQueryParameters3D.create(
			Vector3(-9.0, 10.9, -5.5), Vector3(-5.6, 10.9, -5.5))
	var hit := space.intersect_ray(p)
	_check(not hit.is_empty() and hit.position.x < -7.5,
			"4B bath wall present (hit x=%.2f)" %
			(hit.position.x if hit else 99.0))
	_check(_floor_below(Vector3(-12.8, 11.2, -8.0)), "4B alcove has a slab")
	# per-stack archetypes present across the building
	for rid2 in ["F02_A_BED", "F03_C_BED2", "F05_D_OFFICE", "F02_WSTOR"]:
		_check(ids.has(rid2), "%s in layout" % rid2)
	# lobby support program from the polish pass
	for rid3 in ["F01_OFFICE", "F01_PACKAGE", "F01_RESTROOM"]:
		_check(ids.has(rid3), "%s in layout" % rid3)
	await _door_checks()


func _door_checks() -> void:
	var doors: Array = []
	var locked: DoorProp = null
	var closed: DoorProp = null
	for c in root.get_children():
		if c is DoorProp:
			doors.append(c)
			if c.leaf_state == "locked" and locked == null:
				locked = c
			elif c.leaf_state == "closed" and closed == null:
				closed = c
	_check(doors.size() >= 80, "hinged doors spawned (%d)" % doors.size())
	if closed:
		closed.interact(null)
		await get_tree().create_timer(0.8).timeout
		_check(closed.open and absf(closed._body.rotation.y) > 1.0,
				"door swings open on interact")
		closed.interact(null)
		await get_tree().create_timer(0.8).timeout
		_check(not closed.open, "door closes and latches")
	else:
		_check(false, "found a closed door to test")

	# --- E actually opens a door FROM THE PLAYER. Everything above calls
	# interact() straight on the prop, which proves the door works and says
	# nothing about whether a keypress reaches it. That gap hid a real bug:
	# the on-screen button sets the action through Input.action_press(),
	# which never manufactures an InputEvent, so an _unhandled_input
	# handler is unreachable from a touchscreen and E did nothing on the
	# phone build. This drives the same route a player's finger does.
	var target: DoorProp = null
	for c5 in root.get_children():
		if c5 is DoorProp and c5.leaf_state == "closed" and not c5.open:
			target = c5
			break
	if target:
		var pl3: PlayerController = root.player
		# stand square to the leaf, a pace back, eyes on the middle of it
		var face: Vector3 = target.global_transform.basis * Vector3(0, 0, 1)
		var mid: Vector3 = target.global_position \
				+ target.global_transform.basis \
				* Vector3(target.width * 0.5, target.height * 0.5, 0.0)
		pl3.global_position = mid + face * 1.1 \
				- Vector3(0, PlayerController.STANDING_EYE, 0)
		pl3.velocity = Vector3.ZERO
		await get_tree().physics_frame
		pl3.camera.look_at(mid, Vector3.UP)
		# The prompt is suppressed unless the pointer is captured, which
		# never happens headlessly OR on a phone — so this checks the touch
		# path, where touch_input is what unlocks it. Without that flag the
		# phone build would never tell you an interaction exists.
		pl3.touch_input = true
		# _update_prompt runs inside _process, so the camera has to have
		# been re-aimed for a full frame before the label means anything.
		for _i in 3:
			await get_tree().process_frame
		_check(pl3._prompt.text.contains("[E]"),
				"the door is under the crosshair (prompt: '%s')"
				% pl3._prompt.text)
		pl3.touch_input = false
		Input.action_press("interact")
		await get_tree().process_frame
		Input.action_release("interact")
		await get_tree().create_timer(0.9).timeout
		_check(target.open, "pressing E opens the door the player faces")
	else:
		_check(false, "found a closed door to face")
	if locked:
		locked.interact(null)
		await get_tree().create_timer(0.4).timeout
		_check(not locked.open and absf(locked._body.rotation.y) < 0.01,
				"locked door rattles but holds")
	else:
		_check(false, "found a locked door to test")
	# window glazing closes what used to be an open hole in the shell
	var space := get_viewport().world_3d.direct_space_state
	var p := PhysicsRayQueryParameters3D.create(
			Vector3(-14.5, 11.2, 6.89), Vector3(-13.0, 11.2, 6.89))
	_check(not space.intersect_ray(p).is_empty(),
			"window glazing blocks the A-stack opening")

	# enter apartment 4B from the corridor through its real entry door
	var pl: PlayerController = root.player
	pl.global_position = Vector3(-4.7, 9.75, -3.87)  # west corridor at 4B
	pl.velocity = Vector3.ZERO
	var hinge := Vector3(-5.51, 9.6, -3.415)
	var entry: DoorProp = null
	for c in root.get_children():
		if c is DoorProp and c.global_position.distance_to(hinge) < 0.8:
			entry = c
	_check(entry != null, "found 4B entry door from corridor")
	if entry:
		if not entry.open:
			entry.interact(null)
			await get_tree().create_timer(0.8).timeout
		await _goto(pl, Vector2(-6.9, -3.87), 5.0)
		pl.autopilot = Vector3.ZERO
		_check(pl.global_position.x < -6.0 and pl.global_position.y < 10.2,
				"walked through the doorway into 4B (x=%.2f)"
				% pl.global_position.x)

	# hero toaster: full mechanical cycle latch -> coils -> pop
	var toaster: ToasterProp = root.get_node_or_null("F04_B_TOASTER_01")
	_check(toaster != null, "toaster spawned in 4B kitchen")
	if toaster:
		toaster.start_cycle()
		await _until(func(): return toaster.cycles_completed >= 1, 12.0)
		_check(toaster.cycles_completed >= 1, "toaster completed a full cycle")
		_check(toaster.state == toaster.PState.IDLE,
				"toaster returned to IDLE")

	# Six kettles are household evidence, not a kitchen default. 4C is also
	# the first clause of case 4519, so losing it breaks a call, not dressing.
	var kettle_units := {}
	var kettle_meshes := 0
	var kettle_max := 0
	for child in root.get_children():
		if child is KettleProp:
			var family_kettle := child as KettleProp
			kettle_units[family_kettle.unit] = true
			var meshes := _count_meshes(family_kettle)
			kettle_meshes += meshes
			kettle_max = maxi(kettle_max, meshes)
	_check(kettle_units.keys().size() == 6
			and ["1A", "1D", "3D", "4B", "4C", "6C"].all(
					func(u): return kettle_units.has(u)),
			"six authored households own kettles")
	_check(kettle_max <= 8 and kettle_meshes <= 48,
			"kettles stay at eight meshes each / 48 family total (%d / %d)" %
			[kettle_max, kettle_meshes])
	var case_kettle := root.get_node_or_null("F04_4C_KETTLE_01") as KettleProp
	_check(case_kettle != null and case_kettle.case_id == "4519",
			"4C kettle remains evidence for case 4519")
	var kettle: KettleProp = root.get_node_or_null("F04_B_KETTLE_01")
	_check(kettle != null, "kettle on the 4B counter")
	if kettle:
		_check(kettle.get_node_or_null("HandleReach") is Marker3D
				and kettle.get_node_or_null("LidReach") is Marker3D
				and kettle.get_node_or_null("WhistleReach") is Marker3D
				and kettle.get_node_or_null("PlugReach") is Marker3D,
				"kettle handle, lid, whistle and plug remain serviceable")
		Conductor.infection = 0.1  # below quantize threshold: boil is honest
		# Interrupt cycle one, restart, then wait past the OLD due time but not
		# the new one. State-only guards whistle early here; generation does not.
		kettle.heat_time = 1.2
		kettle.interact(null)
		await get_tree().create_timer(0.30).timeout
		kettle.interact(null)
		await get_tree().create_timer(0.05).timeout
		kettle.interact(null)
		await get_tree().create_timer(0.95).timeout
		_check(kettle.state == kettle.PState.OPERATING,
				"interrupted kettle timer cannot whistle in a later cycle")
		var okk: bool = await _until(func(): return kettle.state == kettle.PState.COMPLETING, 8.0)
		_check(okk, "kettle reaches the whistle")
		kettle.interact(null)
		_check(kettle.cycles_completed == 1 and kettle.state == kettle.PState.IDLE,
				"kettle switched off cleanly")
		kettle.set_service_pose()
		var kettle_service := kettle.get_service_state()
		_check(bool(kettle_service.lid_open)
				and bool(kettle_service.whistle_open)
				and bool(kettle_service.lifted),
				"kettle service pose opens cap and lid and lifts the vessel")
	# Eight generator-authored hero shelves replace the repeated baked cases.
	# Covers and pages remain two surfaces regardless of how many colours the
	# resident owns; sectionals pay exactly one retained mesh per lifting tier.
	var shelf_units := {}
	var shelf_styles := {}
	var shelf_meshes := 0
	var mae_shelf: BookshelfProp = null
	for child in root.get_children():
		if child is BookshelfProp:
			var family_shelf := child as BookshelfProp
			var shelf_state := family_shelf.inspection_state()
			shelf_units[family_shelf.unit] = true
			shelf_styles[family_shelf.case_style] = true
			shelf_meshes += int(shelf_state.mesh_count)
			_check(int(shelf_state.book_mesh_count) == 2,
					"%s shelf keeps book variation in two vertex-colour batches" %
					family_shelf.unit)
			_check(int(shelf_state.mesh_count) <= 10 + int(shelf_state.door_count),
					"%s shelf meets static cap plus moving tiers" % family_shelf.unit)
			if family_shelf.unit == "6C":
				mae_shelf = family_shelf
	_check(shelf_units.size() == 8,
			"eight residents have exactly one functional bookshelf")
	_check(shelf_styles.has("plain") and shelf_styles.has("repaired")
			and shelf_styles.has("sectional"),
			"bookshelf family exposes all three silhouettes in situ")
	_check(shelf_meshes <= 64,
			"eight hero shelves remain at or below 64 meshes (%d)" % shelf_meshes)
	_check(mae_shelf != null and mae_shelf.sorter.order.has("prospectus"),
			"Mae's glass sectional retains the covenant prospectus")
	var clock: ClockProp = root.get_node_or_null("F04_B_CLOCK_01")
	_check(clock != null, "wall clock hung in 4B")
	if clock:
		Conductor.infection = 1.0
		Conductor.bpm = 100.0
		await get_tree().create_timer(3.0).timeout
		_check(clock.interval < 0.98,
				"clock tick drifting toward the building's tempo (%.2f s)"
				% clock.interval)
		Conductor.bpm = 72.0
		Conductor.infection = 0.15

	# networked propagation: same event reaches F05 later than F02 on H-B
	Conductor.propagation_mode = "network"
	Conductor.origin_node = "B1_BOILER_01"
	Conductor.infection = 1.0
	_arrivals.clear()
	AcousticGraphData.network_event.connect(_record_arrival)
	await _until(_both_radiators_reached, 8.0)
	AcousticGraphData.network_event.disconnect(_record_arrival)
	if _both_radiators_reached():
		var dt := _riser_delta_ms()
		_check(dt > 30 and dt < 600,
				"motif sweeps up riser H-B (F05 %d ms after F02)" % dt)
	else:
		_check(false, "propagation reached B-stack radiators")
	# the flue is the fast path: the chimney breast on F05 must sound
	# BEFORE the same floor's radiator for the same emission
	_check(not AcousticGraphData.neighbors("F05_FLUE").is_empty(),
			"flue column connected")
	_check(not AcousticGraphData.neighbors("F04_PORCH_DECK").is_empty(),
			"porch deck coupled to the structure")
	var race := _paired_gap_ms("F05_FLUE_BREAST", "F05_B_RADIATOR_01")
	_check(race > 20 and race < 500,
			"flue beats the riser to F05 (radiator %d ms later)" % race)

	# the impossible door manifests only at severe infection
	var anomaly: DoorAnomalyProp = root.get_node_or_null("F04_B_DOOR_ANOMALY")
	_check(anomaly != null, "door anomaly spawned")
	if anomaly:
		await get_tree().create_timer(2.5).timeout
		_check(anomaly.is_manifest(), "door seam manifests at infection 1.0")
	Conductor.infection = 0.15

	await _call_case_checks(anomaly)


## Case 01 driven end-to-end through the in-building call interface.
func _call_case_checks(anomaly: DoorAnomalyProp) -> void:
	var ci: CallInterface = root.call_interface
	_check(ci != null, "call interface present")
	if ci == null:
		return
	ci.fast = true
	ci.enter(root.player)
	_check(root.player.call_locked, "player locked to desk during call")
	var ok: bool = await _until(func(): return not ci._isolate_btn.disabled, 15.0)
	_check(ok, "call: isolate unlocks after dialogue")
	ci.press_isolate(true)
	_check(ci.stage == CallInterface.Stage.ISOLATION, "call: stage ISOLATION")
	ok = await _until(func(): return not ci._capture_btn.disabled, 20.0)
	_check(ok, "call: capture unlocks after hearing breathing")
	ci.press_capture()
	ci.press_route()
	_check(Conductor.origin_node == "F04_B_MONITOR_01",
			"call: routing moves conductor origin to the 4B desk")
	ok = await _until(func(): return ci.stage == CallInterface.Stage.RESPONSE, 25.0)
	_check(ok, "call: reaches RESPONSE")
	ci.press_respond("complete")
	_check(ci.outcome == "complete", "call: outcome latched")
	ci.press_respond("interrupt")
	_check(ci.outcome == "complete", "call: second response rejected")
	ok = await _until(func(): return Conductor.infection >= 0.8, 15.0)
	_check(ok, "call: Complete raises building infection to 0.85")
	if anomaly:
		await get_tree().create_timer(2.5).timeout
		_check(anomaly.is_manifest(),
				"call: door anomaly manifests after Complete")
	ci.leave()
	_check(not root.player.call_locked, "player released after leaving desk")

	# out the front door: lobby -> street door -> stoop -> sidewalk
	var pl2: PlayerController = root.player
	pl2.global_position = Vector3(0.0, 0.15, 9.0)  # inside the street door
	pl2.velocity = Vector3.ZERO
	var street_door: DoorProp = null
	for c2 in root.get_children():
		if c2 is DoorProp and c2.global_position.z > 9.5 \
				and absf(c2.global_position.x) < 1.0 \
				and c2.global_position.y < 1.0:
			street_door = c2
	_check(street_door != null, "street door found")
	if street_door:
		if not street_door.open:
			street_door.interact(null)
			await get_tree().create_timer(0.8).timeout
		var sp3 := get_viewport().world_3d.direct_space_state
		for hy in [0.2, 0.6, 1.1, 1.6]:
			var q3 := PhysicsRayQueryParameters3D.create(
					Vector3(0.0, hy, 8.6), Vector3(0.0, hy, 12.5))
			q3.exclude = [pl2.get_rid()]
			var h3 := sp3.intersect_ray(q3)
			if h3.is_empty():
				print("HPROBE y=%.1f clear" % hy)
			else:
				var pr3: Node = h3.collider.get_parent()
				print("HPROBE y=%.1f hit z=%.2f %s/%s" % [hy,
						h3.position.z, pr3.name if pr3 else "?",
						h3.collider.name])
		await _goto(pl2, Vector2(0.0, 12.5), 6.0)
		pl2.autopilot = Vector3.ZERO
		_check(pl2.global_position.z > 11.0 and pl2.global_position.y < 1.5,
				"walked out onto the sidewalk (z=%.1f)" % pl2.global_position.z)
	_check(_floor_below(Vector3(0.0, 1.0, 12.5)), "sidewalk is solid")
	_check(_floor_below(Vector3(0.0, 1.0, -11.5)), "rear alley is solid")
	# roof egress: the last exterior door — up from the F06 deck through
	# the monitor door onto the open roof
	pl2.global_position = Vector3(-0.5, 19.35, 2.6)  # roof-level deck
	pl2.velocity = Vector3.ZERO
	var roof_door: DoorProp = null
	for c5 in root.get_children():
		if c5 is DoorProp and c5.global_position.y > 19.0 				and absf(c5.global_position.z - 3.25) < 0.5:
			roof_door = c5
	_check(roof_door != null, "roof monitor door found")
	if roof_door and not roof_door.open:
		roof_door.interact(null)
		await get_tree().create_timer(0.8).timeout
	await _goto(pl2, Vector2(-0.85, 4.6), 6.0)
	pl2.autopilot = Vector3.ZERO
	_check(pl2.global_position.z > 3.8 and pl2.global_position.y > 19.0,
			"walked out the monitor door onto the roof (z=%.1f)"
			% pl2.global_position.z)

	var cab: DoorProp = root.get_node_or_null("F04_CAB_UPPER_1")
	_check(cab != null, "kitchen cabinet doors spawned")
	if cab:
		cab.interact(null)
		await get_tree().create_timer(0.7).timeout
		_check(cab.open, "cabinet door swings")

	# Room 0: enter through the manifested seam, then let the room collapse
	if anomaly and anomaly.room0:
		var pl: PlayerController = root.player
		var before := pl.global_position
		anomaly.interact(pl)
		_check(pl.global_position.y > 50.0, "Room 0 entered through the seam")
		_check(_floor_below(pl.global_position + Vector3(0, 1.0, 0)),
				"Room 0 has a walkable floor")
		var bpm_before: float = Conductor.bpm
		Conductor.infection = 0.3  # the hum falters
		await get_tree().create_timer(0.5).timeout
		_check(pl.global_position.distance_to(before) < 2.0,
				"collapse ejects occupant back to 4B")
		_check(Conductor.bpm > bpm_before,
				"ejection leaves the building's tempo slightly wrong")
		Conductor.bpm = 72.0
	else:
		_check(false, "Room 0 reachable from anomaly")
	# Cases 02 and 03 run last, after Case 01's own consequences (the seam,
	# Room 0) have been checked against the state Case 01 left. They move
	# infection around freely, and an earlier version of this ordering
	# quietly un-manifested the seam before the Room 0 walk reached it.
	await _case_network_checks(ci)
	_wall_art_report()
	_door_glow_checks()
	await _broadcast_checks()
	await _evelyn_checks()
	await _sanity_checks()
	Conductor.infection = 0.15
	Conductor.origin_node = "B1_BOILER_01"


## The first character mesh — Evelyn, upgraded in place on her 1A resident
## node now that the lobby test figure is retired. The checks that matter
## are not "is it pretty" but the ways a character can quietly break this
## build: standing in a route the generator's movement audit believes is
## clear, costing more geometry than the room it stands in, and the merge
## silently dropping a clip.
func _evelyn_checks() -> void:
	var figure: Node3D = null
	for resident in get_tree().get_nodes_in_group("resident_placeholders"):
		if "resident_id" in resident and str(resident.get(
				"resident_id")) == "evelyn_marsh":
			figure = resident
			break
	_check(figure != null, "Evelyn's 1A resident placed")
	if figure == null:
		return
	# On her floor and standing ON it rather than buried in it — Meshy's
	# rigged exports put the origin between the feet.
	var p := figure.global_position
	_check(absf(p.y - 0.03) < 0.35,
			"Evelyn stands on F01, not through it (y=%.2f)" % p.y)
	# Non-colliding, like every resident. The audit authors clearances the
	# generator can see; actors added in Godot are invisible to it, so a
	# solid one is a route that passes on paper and fails underfoot.
	# (Interaction Area3Ds are fine — they never block movement.)
	var solid := 0
	for node in _descendants(figure):
		if node is PhysicsBody3D and node.collision_layer != 0:
			solid += 1
	_check(solid == 0,
			"Evelyn does not obstruct her routes (%d colliders)" % solid)
	var tris := 0
	for node in _descendants(figure):
		if node is MeshInstance3D and node.mesh:
			for surface in node.mesh.get_surface_count():
				tris += node.mesh.surface_get_arrays(surface)[
						Mesh.ARRAY_INDEX].size() / 3
	_check(tris > 0 and tris < 60000,
			"Evelyn's geometry stays within budget (%d tris)" % tris)
	# --- pathfinding. The one assertion that matters: a planned route never
	# crosses masonry except at a doorway. Proven with physics, not by
	# trusting the graph — raycast every leg at torso height and demand any
	# wall hit be within arm's reach of a door node on the path. Closed door
	# LEAVES are legal to pass (residents are non-colliding by design; the
	# audit owns clearances), so DoorProp hits are excused.
	var routines = root.resident_routines
	_check(routines != null and routines.nav != null,
			"resident nav graph built")
	if routines != null and routines.nav != null:
		var nav = routines.nav
		_check(nav.floors.size() >= 7,
				"nav covers the storeys (%d)" % nav.floors.size())
		# 1A living room to the brass mail bank — Evelyn's actual errand.
		var from := GameBoot.b2g([-9.6, -3.0, 0.0])
		var to := GameBoot.b2g([4.55, -8.85, 0.0])
		var path: PackedVector3Array = nav.route(from, to)
		_check(path.size() >= 4,
				"route 1A -> mail runs the graph (%d waypoints)" % path.size())
		var door_nodes: Array = []
		for pt in nav.floors["F01"].points:
			if str(pt.tag).begins_with("door:"):
				door_nodes.append(GameBoot.b2g([pt.at.x, pt.at.y,
						nav.floors["F01"].z]))
		var space := get_viewport().world_3d.direct_space_state
		var breaches := 0
		for i in range(path.size() - 1):
			var a: Vector3 = path[i] + Vector3(0, 1.0, 0)
			var b: Vector3 = path[i + 1] + Vector3(0, 1.0, 0)
			var q := PhysicsRayQueryParameters3D.create(a, b)
			var guard := 0
			while guard < 8:
				guard += 1
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					break
				var owner: Node = hit.collider.get_parent() \
						if hit.collider is Node else null
				var excused := owner is DoorProp
				for dn in door_nodes:
					if Vector3(hit.position.x, dn.y + 1.0, hit.position.z) \
							.distance_to(dn + Vector3(0, 1.0, 0)) < 0.9:
						excused = true
				if not excused:
					breaches += 1
					print("  [NAV BREACH] leg %d hits %s at %s" % [i,
							owner.name if owner else hit.collider,
							hit.position])
				q = PhysicsRayQueryParameters3D.create(
						hit.position + (b - a).normalized() * 0.05, b)
		_check(breaches == 0,
				"route passes only through doorways (%d breaches)" % breaches)

	# Meshy ships one animation per file, each with a full copy of the skin.
	# The merge folds them onto a single rig, and the failure mode is silent:
	# the exporter drops whichever action is assigned as active, so a clip
	# goes missing without anything erroring.
	var anim: AnimationPlayer = null
	for node in _descendants(figure):
		if node is AnimationPlayer:
			anim = node
			break
	_check(anim != null, "Evelyn has an AnimationPlayer")
	if anim == null:
		return
	# Her own ten from the merge, plus whatever the gesture library grafts
	# on top (biped family gets biped_gestures.glb too) — so count her
	# originals by name rather than capping the list.
	var evelyn_own := ["clip_01", "clip_02", "clip_03", "clip_04",
			"clip_05", "clip_06", "clip_07", "clip_08", "walk", "run"]
	var own_present := 0
	for clip_name in evelyn_own:
		if anim.has_animation(clip_name):
			own_present += 1
	_check(own_present == 10,
			"all ten clips survived the merge (%d/10, %d total)" %
			[own_present, anim.get_animation_list().size()])
	_check(anim.is_playing(), "Evelyn is animating, not frozen in bind pose")
	# Root motion would fight the navigation; the clips were authored in
	# place and have to stay that way. Measured on the mesh child's LOCAL
	# transform: routines legitimately move the resident node itself, so
	# global drift is her errand, not the clip.
	var walker: Node = anim
	while walker.get_parent() != figure and walker.get_parent() != null:
		walker = walker.get_parent()
	var mesh_root := walker as Node3D
	if mesh_root == null:
		return
	var before: Vector3 = mesh_root.position
	var resumed := anim.current_animation
	if anim.has_animation("walk"):
		anim.play("walk")
		await get_tree().create_timer(1.1).timeout
	_check(mesh_root.position.distance_to(before) < 0.05,
			"walk cycle does not translate Evelyn inside her node")
	if resumed != "":
		anim.play(resumed)


func _descendants(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child in node.get_children():
		found.append(child)
		found.append_array(_descendants(child))
	return found


## The station. What matters: sets are OFF until someone wants them on, one
## decode serves the building and stops when nobody watches, the player
## switch works, cards arrive on cadence, the shader receives the faults,
## and possession takes every set and gives them back.
func _broadcast_checks() -> void:
	var station: BroadcastDirector = root.broadcast
	_check(station != null, "broadcast director present")
	if station == null:
		return
	var st: Dictionary = station.stats()
	_check(int(st.clips) == 37, "all 37 clips catalogued (%d)" % st.clips)
	_check(int(st.sets) >= 12, "televisions spawned (%d)" % st.sets)
	# Residents watching their own sets legitimately power them at boot —
	# that is the feature — so boot state is reported, not asserted.
	print("  [STATION] %d of %d sets on at boot (residents watching)"
			% [int(st.on), int(st.sets)])
	var tv: TVProp = station.sets[0]
	tv.interact(null)
	_check(tv.powered, "pressing E turns a set on")
	_check(station.any_powered() and station._viewport \
			.render_target_update_mode == SubViewport.UPDATE_ALWAYS,
			"first viewer puts the station on air")
	await get_tree().create_timer(0.8).timeout
	# The station may legitimately be mid-card-break at this instant (the
	# video pauses under cards), so "on air" means either state.
	_check(station._video.is_playing() or station._card.visible,
			"a clip is rolling or a card is up")
	_check(tv.glass.material_override is ShaderMaterial,
			"lit glass carries the shared feed")
	_check(tv.glow.visible, "a lit set casts its glow")
	# cards every third programme
	station.programmes_since_card = 2
	station._next_programme()
	_check(station._card.visible and station._video.paused,
			"third programme break shows a card")
	station._card_left = 0.0
	# every fault in the vocabulary reaches the shader and clears again
	var faults := {"static": "static_amount", "roll": "roll_speed",
			"ghost": "ghost_offset", "dropout": "dropout",
			"chroma": "chroma", "tear": "tear", "flicker": "flicker",
			"warp": "warp"}
	var dead: Array[String] = []
	for kind in faults:
		station.disturb(kind, 0.3)
		if float(station._shared.get_shader_parameter(faults[kind])) <= 0.01:
			dead.append(kind)
		station._clear_fx()
	_check(dead.is_empty(),
			"all eight picture faults reach the shader (dead: %s)" % [dead])
	var residue := 0.0
	for p in faults.values():
		residue += absf(float(station._shared.get_shader_parameter(p)))
	_check(residue < 0.01, "faults clear back to a clean signal")
	# possession takes every set, then gives them back
	station.possess(0.6)
	var all_on := true
	for candidate in station.sets:
		if not candidate.powered:
			all_on = false
	_check(all_on, "possession takes every set in the building")
	await get_tree().create_timer(1.4).timeout
	# Watcher counts drift while we wait (residents wander), so the
	# invariant is residue, not a headcount: nothing stays possessed, and
	# the player-latched set survives.
	var residue_sets := 0
	for candidate in station.sets:
		if candidate.possessed:
			residue_sets += 1
	_check(residue_sets == 0 and tv.powered,
			"release leaves no possession residue (%d)" % residue_sets)
	tv.interact(null)
	_check(not tv.player_on, "E again releases the player latch")


## Light under the closed doors. The interesting assertions are not "does it
## exist" but "is it in one draw call" and "does it agree with the windows" —
## a per-door light would starve the corridor fixtures the LightRig protects,
## and a door that leaks light from a room whose windows are dark is the
## building caught lying about who is awake.
func _door_glow_checks() -> void:
	var glow: OrisonDoorGlow = root.door_glow
	_check(glow != null, "door spill pass present")
	if glow == null:
		return
	var stats: Dictionary = glow.stats()
	_check(int(stats.doors) > 50,
			"every closed door considered (%d)" % stats.doors)
	_check(int(stats.lit) > 0 and int(stats.lit) < int(stats.doors),
			"some doors leak and most do not (%d of %d)"
			% [stats.lit, stats.doors])
	var meshes := 0
	for child in glow.get_children():
		if child is MeshInstance3D:
			meshes += 1
	_check(meshes == 1,
			"all door spill batched into one mesh (%d)" % meshes)
	# The bar has to sit above the 12 mm terrazzo finish, not on the slab:
	# below it the light is under the floor and invisible, which is exactly
	# where the first version of this put it.
	for child in glow.get_children():
		if child is MeshInstance3D:
			var box: AABB = child.get_aabb()
			_check(box.position.y > 0.012,
					"spill clears the floor finish (y=%.3f)" % box.position.y)


## The sanity system. Three things need proving and none of them are "does
## it scare you": that the safety net catches a player the world has dropped,
## that a poltergeist borrows the building rather than damaging it, and that
## nothing the meta layer does can strand someone.
func _sanity_checks() -> void:
	var net: SafetyNet = root.safety_net
	_check(net != null, "safety net attached to the player")
	var director: SanityDirector = root.sanity
	_check(director != null, "sanity director present")
	if net == null or director == null:
		return

	# --- the net. Put the player somewhere real, let it take an anchor,
	# then throw them out of the world and prove they come back.
	net.enabled = true
	root.player.global_position = Vector3(4.3, 0.15, 0.0)  # F01 corridor
	root.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.9).timeout
	var anchor := net.anchor
	_check(anchor.y > -6.0, "net anchored somewhere standable (y=%.2f)" % anchor.y)
	var before := net.recoveries
	net.drop_test()
	await get_tree().create_timer(0.4).timeout
	_check(net.recoveries == before + 1, "net catches a fall out of the world")
	_check(root.player.global_position.y > -6.0,
			"recovered player is back in the building (y=%.2f)"
			% root.player.global_position.y)
	# A NaN transform fails every range comparison silently, so it needs its
	# own path or a corrupted player falls forever while the checks pass.
	before = net.recoveries
	root.player.global_position = Vector3(NAN, NAN, NAN)
	await get_tree().create_timer(0.4).timeout
	_check(net.recoveries == before + 1, "net catches a non-finite position")

	# --- the cast. Every poltergeist must be a real resident with a
	# complete ladder, or the director can pick someone who cannot speak.
	var ids := PoltergeistLibrary.ids()
	_check(ids.size() == 18, "eighteen poltergeists authored (%d)" % ids.size())
	var incomplete := 0
	var orphans := 0
	for case_id in ids:
		if not RealityCases.definitions.has(case_id):
			orphans += 1
		for tier in [1, 2, 3, 4]:
			if PoltergeistLibrary.rung(case_id, tier).is_empty():
				incomplete += 1
	_check(orphans == 0,
			"every poltergeist maps to a real resident case (%d orphaned)"
			% orphans)
	_check(incomplete == 0,
			"every poltergeist has all four rungs (%d missing)" % incomplete)

	# --- borrowing, not damaging. Force a rung that possesses props, then
	# prove the building goes back exactly as it was.
	root.player.global_position = Vector3(-9.5, 11.25, -4.8)  # 4B, dressed
	root.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	var sample: Array = []
	for child in root.get_children():
		if child is FunctionalProp and not (child is LightFixtureProp):
			if child.global_position.distance_to(
					root.player.global_position) < 9.0:
				sample.append([child, child.transform])
	_check(sample.size() >= 3,
			"props within reach of the test position (%d)" % sample.size())
	var fired := director.intrusion_count
	director.force("mina_caption_crisis", 3)
	_check(director.intrusion_count == fired + 1,
			"forcing a rung performs an intrusion")
	director.intrusions.restore_all()
	var moved := 0
	for entry in sample:
		if not entry[0].transform.is_equal_approx(entry[1]):
			moved += 1
	_check(moved == 0,
			"possessed props restore exactly (%d left displaced)" % moved)
	_check(director.intrusions.held_count() == 0,
			"nothing is still held after a restore")

	# --- the meta layer never strands anyone.
	var meta: FourthWallLayer = root.fourth_wall
	_check(meta != null, "fourth-wall layer present")
	if meta:
		_check(meta.play("save_corrupt"), "a meta effect can be played")
		_check(meta.is_busy(), "meta effect holds the screen while it runs")
		_check(not meta.play("session_time"),
				"meta effects never overlap each other")
		meta.force_finish()
		_check(not meta.is_busy(), "meta effect always clears itself")
		# Every effect named by a poltergeist has to actually exist, or a
		# rung-four address silently does nothing at all.
		var missing: Array[String] = []
		for case_id in ids:
			for act in PoltergeistLibrary.rung(case_id, 4):
				if str(act[0]) != "fourth_wall":
					continue
				if not meta.play(str(act[1])):
					missing.append(str(act[1]))
				meta.force_finish()
		_check(missing.is_empty(),
				"every authored meta effect is implemented (missing %s)"
				% [missing])

	# --- attention. The director watches what the player looks at, and an
	# intrusion nobody sees has to be made again. Both halves are asserted
	# because "the building gets louder when ignored" is the rule that
	# decides whether a careless player has a worse time than a careful one.
	director.enabled = true
	var ignored_before: int = director._ignored_streak
	director.force("noel_domestic_museum", 2)
	_check(not director.intrusions.last_targets.is_empty(),
			"an intrusion reports what it touched (%d targets)"
			% director.intrusions.last_targets.size())
	_check(not director._watching.is_empty(),
			"firing arms the notice window")
	director._watch_deadline = 0.0          # pretend the window elapsed
	director._observe_gaze(0.1)
	_check(director._ignored_streak == ignored_before + 1,
			"an unwitnessed intrusion makes the building insist")
	# Now the other way: looking at what moved closes the loop.
	director.force("noel_domestic_museum", 2)
	var target: Node3D = director.intrusions.last_targets[0]
	director._watching = [target]
	director._noticed()
	_check(director._ignored_streak == 0,
			"noticing what moved resets the insistence")
	_check(director._watching.is_empty(), "the notice window closes on notice")
	# Vanishing only ever takes things the player cannot see, and gives them
	# back — a prop left invisible is lost scenery, not a haunting.
	director.intrusions.perform("prop_vanish", 2)
	director.intrusions.restore_all()
	var invisible := 0
	for child in root.get_children():
		if child is FunctionalProp and not child.visible:
			invisible += 1
	_check(invisible == 0,
			"vanished props come back (%d still hidden)" % invisible)
	# Campaign memory: an address is remembered past this session.
	var witnessed_before: int = int(
			RealityState.data.get(SanityDirector.WITNESS_KEY, 0))
	director.force("teresa_call_bells", 4)
	_check(int(RealityState.data.get(SanityDirector.WITNESS_KEY, 0))
			== witnessed_before + 1,
			"an address is recorded against the campaign")
	director.intrusions.restore_all()

	# --- and it stays invisible. Pressure is readable by tooling and tests,
	# never by the shipped HUD.
	_check(director.pressure >= 0.0 and director.pressure <= 1.0,
			"pressure stays normalised (%.2f)" % director.pressure)
	director.stand_down()
	_check(director.intrusions.held_count() == 0,
			"standing down leaves the building clean")


## Art is single-sided now, so a piece hung facing its own wall is invisible
## rather than mirrored. Better, but silent — hence this sweep.
##
## It REPORTS and does not assert, deliberately. Neither probe measures
## cleanly enough to fail a build on: a hit in front of a picture is just as
## likely to be a wardrobe standing against the same wall as it is a
## backwards hang, and "nothing behind" fires on anything hung over an
## archway or a cased opening, which may well be intentional dressing. The
## lists are here so the next person to touch the art catalogs has the
## leads; turning either into a real invariant needs the placement rules
## pinned down first, and that is a job of its own.
func _wall_art_report() -> void:
	var space := get_viewport().world_3d.direct_space_state
	var blocked: Array[String] = []
	var unbacked: Array[String] = []
	var total := 0
	for group in ["character_memories", "character_wall_art", "hallway_art"]:
		for art in get_tree().get_nodes_in_group(group):
			if not (art is Node3D):
				continue
			total += 1
			var node: Node3D = art
			var origin: Vector3 = node.global_position
			# The quad faces local +Z, so this is the side you must stand
			# on to see the picture at all.
			var out: Vector3 = node.global_transform.basis.z.normalized()
			var front := PhysicsRayQueryParameters3D.create(
					origin + out * 0.05, origin + out * 0.34)
			if not space.intersect_ray(front).is_empty():
				blocked.append(str(node.name))
			var back := PhysicsRayQueryParameters3D.create(
					origin, origin - out * 0.40)
			if space.intersect_ray(back).is_empty():
				unbacked.append(str(node.name))
	_check(total >= 40, "wall art spawned (%d pieces)" % total)
	print("[ART] %d pieces; %d with something close in front, %d with "
			% [total, blocked.size(), unbacked.size()] +
			"nothing solid behind")
	if not blocked.is_empty():
		print("[ART] close in front: %s" % [blocked])
	if not unbacked.is_empty():
		print("[ART] nothing behind: %s" % [unbacked])


## Cases 02 and 03, driven through the same console the player uses. The
## point of these checks is not the dialogue — it is that a case is data now,
## and that closing one leaves the building measurably different: Case 02
## puts a door in the third-floor corridor, Case 03 puts someone else in the
## player's chair.
func _case_network_checks(ci: CallInterface) -> void:
	_check(CaseLibrary.count() == 8,
			"case network holds the full batch plus convergence")
	_check(ci.case_index == 1,
			"leaving a closed case brings up the next caller")
	_check(ci.closed_outcomes == ["complete"], "case 01 outcome recorded")

	# --- Case 02: the route in the pipes, answered with the player's feet.
	# Nothing below presses a response button: the case is resolved by
	# leaving the desk mid-call and being in the corridor when it ends.
	ci.enter(root.player)
	var ok: bool = await _drive_to_response(ci, "case 02")
	if ok:
		_check(ci._case.id == "4482", "case 02 is the one on the line")
		_check(ci._field_live, "case 02: field phase goes live with the window")
		var door: CaseDoorProp = root.get_node_or_null("F03_UTILITY_ANOMALY")
		_check(door != null, "case 02: utility door spawned on F03")
		ci.leave()
		_check(not root.player.call_locked,
				"case 02: the player is free to walk during the window")
		_check(ci._field_banner.visible,
				"case 02: the route banner follows you off the desk")
		_check(ci.outcome == "", "case 02: leaving the desk is not an answer")
		if door:
			# Down two floors, into the west corridor run, where the door
			# is about to be.
			root.player.global_position = door.global_position \
					+ Vector3(0.9, 0.1, 0.0)
			root.player.velocity = Vector3.ZERO
			ok = await _until(func(): return ci.outcome != "", 8.0)
			_check(ok, "case 02: standing where the route ends answers the call")
			_check(ci.outcome == "walk",
					"case 02: walking there scores apart from sitting it out (got %s)"
					% ci.outcome)
			ok = await _until(func(): return ci._closed, 30.0)
			_check(ok, "case 02: case closes")
			_check(door.is_revealed(),
					"case 02: closing the case puts the door in the wall")
			_check(door.interact_prompt() != "",
					"case 02: the door can be examined once it exists")
			door.interact(root.player)
			_check(root.player.global_position.y < 20.0,
					"case 02: the door does not open on the first night")
	ci.leave()
	_check(ci.case_index == 2, "case 02 closed and the queue advanced")

	# --- Case 03: matching the imitation exactly is the one that costs you
	ci.enter(root.player)
	ok = await _drive_case(ci, "reinforce", "case 03")
	if ok:
		_check(ci.flags.has("desk_double"),
				"case 03: matching the model exactly leaves it at your desk")
		var desk: DeskZone = root.get_node_or_null("F04_B_DESK_ZONE")
		_check(desk != null, "desk zone present")
		if desk:
			_check(desk.interact_prompt().contains("your voice"),
					"case 03: the desk prompt reports who is sitting there")
	ci.leave()
	_check(ci.case_index == 3, "case 03 closed and the queue advanced")
	_check(ci.closed_outcomes.size() == 3, "first three outcomes recorded")

	# --- Cases 04-07 and the convergence: authored as data, driven by the
	# same three verbs. One response each — the checks are that each case is
	# the one on the line, closes, and leaves its distinctive mark on the
	# desk's flags. The convergence is answered the way the whole network
	# taught: by protecting the empty slot.
	var later := [
		["case 04", "4508", "hand_over", "juno_loop"],
		["case 05", "4519", "delay_cue", "mercers_speak"],
		["case 06", "4531", "own_hum", "room0_keyed_to_desk"],
		["case 07", "4544", "preserve_all", "version_chorus"],
		["convergence", "4600", "protect_silence", "the_empty_slot"],
	]
	for spec in later:
		ci.enter(root.player)
		ok = await _drive_case(ci, str(spec[2]), str(spec[0]))
		if ok:
			_check(ci._case.id == spec[1],
					"%s is the one on the line" % spec[0])
			_check(ci.flags.has(spec[3]),
					"%s leaves its mark (%s)" % [spec[0], spec[3]])
		ci.leave()
	_check(ci.case_index == 8, "the queue ends after the convergence")
	_check(ci.closed_outcomes.size() == 8, "all eight outcomes recorded")
	# Conditional beats: giving Juno the loop in case 04 changes what the
	# convergence's protected silence contains four cases later.
	_check(ci.flags.has("chorus_kept_the_sister"),
			"the convergence remembers what case 04 decided")
	# The desk is not offering a ninth call it does not have.
	var desk2: DeskZone = root.get_node_or_null("F04_B_DESK_ZONE")
	if desk2:
		_check(desk2.interact_prompt() != "", "desk still interactable when quiet")


## The three verbs, in order, on whichever case is loaded. Every case answers
## to this because every case IS this — which is the whole reason the runner
## stopped being Case 01 with the serial numbers filed off.
func _drive_case(ci: CallInterface, respond: String, label: String) -> bool:
	var ok: bool = await _drive_to_response(ci, label)
	if not ok:
		return false
	ci.press_respond(respond)
	_check(ci.outcome == respond, "%s: outcome latched (%s)" % [label, respond])
	# The timeout id is always a real outcome for its case, so this probes
	# the one-outcome-per-case latch rather than the unknown-id guard.
	ci.press_respond(ci._case.timeout)
	_check(ci.outcome == respond, "%s: second response rejected" % label)
	ok = await _until(func(): return ci._closed, 30.0)
	_check(ok, "%s: case closes" % label)
	return ok


## Everything up to the point where the case is waiting on the player: the
## three verbs, in order, on whichever case is loaded.
func _drive_to_response(ci: CallInterface, label: String) -> bool:
	var ok: bool = await _until(func(): return not ci._isolate_btn.disabled, 15.0)
	_check(ok, "%s: isolate unlocks after the caller's opening" % label)
	if not ok:
		return false
	ci.press_isolate(true)
	_check(ci.stage == CallInterface.Stage.ISOLATION,
			"%s: stage ISOLATION" % label)
	ok = await _until(func(): return not ci._capture_btn.disabled, 20.0)
	_check(ok, "%s: capture unlocks once the pattern registers" % label)
	if not ok:
		return false
	ci.press_capture()
	ci.press_route()
	ok = await _until(func(): return ci.stage == CallInterface.Stage.RESPONSE, 30.0)
	_check(ok, "%s: reaches RESPONSE" % label)
	return ok


func _boxfan_checks() -> void:
	var fans: Array[BoxFanProp] = []
	var units := {}
	var total_meshes := 0
	var max_meshes := 0
	for child in root.get_children():
		if child is BoxFanProp:
			var fan := child as BoxFanProp
			fans.append(fan)
			units[fan.unit] = true
			var meshes := _count_meshes(fan)
			total_meshes += meshes
			max_meshes = maxi(max_meshes, meshes)
	_check(fans.size() == 4 and ["2C", "4B", "5C", "6A"].all(
			func(unit): return units.has(unit)),
			"four ruled households own portable fans")
	_check(max_meshes <= 9 and total_meshes <= 36,
			"fans cost at most nine meshes each / 36 family total (%d / %d)" %
			[max_meshes, total_meshes])
	var room_owned := true
	var serviceable := true
	for fan in fans:
		room_owned = room_owned and fan.room_id != "" \
				and root.room_at_world(fan.global_position) == fan.room_id
		serviceable = serviceable \
				and fan.get_node_or_null("SelectorReach") is Marker3D \
				and fan.get_node_or_null("HandleReach") is Marker3D \
				and fan.get_node_or_null("PlugReach") is Marker3D \
				and fan.get_node_or_null("Interaction") is Area3D
	_check(room_owned,
			"every fan is seated in the room that gates its unseen plug swap")
	_check(serviceable,
			"selector, handle, plug and interaction remain physically reachable")

	var player_fan := root.get_node_or_null("F04_B_BOXFAN_01") as BoxFanProp
	_check(player_fan != null, "4B keeps its landlord-supplied fan")
	if player_fan:
		player_fan.set_speed_step(0, true)
		player_fan._perform_synced_event(1, 1.0, 1.0)
		_check(player_fan.speed_step() == 0 and player_fan.state == FunctionalProp.PState.OFF,
				"motif accents cannot start a fan whose selector is at zero")
		player_fan.interact(null)
		_check(player_fan.speed_step() == 1,
				"one interaction advances the mechanical selector")

	# The impossible state is room-gated, not camera-guessed: leave, return to
	# find exposed prongs and a live rotor, then leave again before cleanup.
	var evidence := root.get_node_or_null("F06_A_BOXFAN_01") as BoxFanProp
	_check(evidence != null, "6A evidence fan remains case-addressable")
	if evidence:
		root.player.global_position = GameBoot.b2g([-6.8, -8.4, 16.1])
		await get_tree().process_frame
		_check(root.room_at_world(root.player.global_position) == "F06_A_BED",
				"player starts the possession check inside Sacha's fan room")
		evidence.set_speed_step(0, true)
		evidence.possess_fit(1)
		_check(evidence.possession_phase() == 1 and evidence.is_plugged(),
				"possession waits while the player remains in the room")
		root.player.global_position = GameBoot.b2g([4.3, 0.0, 16.1])
		await get_tree().process_frame
		_check(evidence.possession_phase() == 2 and not evidence.is_plugged(),
				"first room exit moves the plug and starts the impossible rotor")
		root.player.global_position = GameBoot.b2g([-6.8, -8.4, 16.1])
		await get_tree().process_frame
		_check(evidence.possession_phase() == 3 and not evidence.is_plugged(),
				"returning player finds the fan running unplugged")
		await get_tree().create_timer(0.9).timeout
		_check(evidence.possession_phase() == 4 and not evidence.is_plugged(),
				"exposed plug remains until another room exit")
		root.player.global_position = GameBoot.b2g([4.3, 0.0, 16.1])
		await _until(func(): return evidence.possession_phase() == 0, 1.0)
		_check(evidence.possession_phase() == 0 and evidence.is_plugged(),
				"second room exit restores the ordinary appliance unseen")
		root.teleport_player("F01")


func _exhaust_fan_checks() -> void:
	var fans: Array[ExhaustFanProp] = []
	var risers := {}
	var total_meshes := 0
	var max_meshes := 0
	var duct_mouths := 0
	var serviceable := true
	for child in root.get_children():
		if child is ExhaustFanProp:
			var fan := child as ExhaustFanProp
			fans.append(fan)
			risers[fan.riser] = true
			var meshes := _count_meshes(fan)
			total_meshes += meshes
			max_meshes = maxi(max_meshes, meshes)
			duct_mouths += fan.duct_emitter_count()
			serviceable = serviceable \
					and fan.get_node_or_null("ServicePlateReach") is Marker3D \
					and fan.get_node_or_null("BeltGuardReach") is Marker3D
	_check(fans.size() == 4 and ["V-A", "V-B", "V-C", "V-D"].all(
			func(riser): return risers.has(riser)),
			"four roof ventilators own the bathroom risers")
	_check(max_meshes <= 8 and total_meshes <= 32,
			"central ventilators stay at eight meshes each / 32 total (%d / %d)" %
			[max_meshes, total_meshes])
	_check(fans.all(func(fan): return fan.global_position.y > 19.0),
			"all ventilation motors remain on the roof")
	_check(serviceable, "roof belt guards and service plates remain findable")
	_check(root.get_node_or_null("F04_B_EXHFAN_01") == null,
			"4B no longer owns an anachronistic private extractor")

	var registers := []
	var network_clean := true
	for node_id in AcousticGraphData.nodes:
		var data: Dictionary = AcousticGraphData.nodes[node_id]
		if str(node_id).ends_with("_VENT_REGISTER"):
			registers.append(node_id)
			network_clean = network_clean \
					and str(data.get("network", "")) == "ventilation"
	_check(registers.size() == 23 and duct_mouths == 23,
			"all twenty-three bathrooms own a passive audible register")
	_check(network_clean, "every bathroom register stays on the ventilation graph")
	var isolated := true
	for fan in fans:
		var reachable := _graph_reachable(String(fan.name))
		for node_id in registers:
			var data: Dictionary = AcousticGraphData.nodes[node_id]
			if str(data.get("riser", "")) == fan.riser:
				isolated = isolated and reachable.has(node_id)
			else:
				isolated = isolated and not reachable.has(node_id)
	_check(isolated,
			"each motor reaches its own bathrooms without crossing another riser")
	if not fans.is_empty():
		fans[0].set_running(false, true)
		fans[0]._perform_synced_event(1, 1.0, 1.0)
		_check(not fans[0].is_running(),
				"a motif cannot start central plant that is between cycles")
		fans[0].set_running(true, true)
		_check(fans[0].is_running(),
				"roof motor opens its gravity louver with the running cycle")
		fans[0].set_running(false, true)


func _flue_breast_checks() -> void:
	var fittings: Array[FlueBreastProp] = []
	var total_meshes := 0
	var max_meshes := 0
	var ids_unchanged := true
	var metadata_clean := true
	var seated := true
	for child in root.get_children():
		if child is FlueBreastProp:
			var fitting := child as FlueBreastProp
			fittings.append(fitting)
			var meshes := _count_meshes(fitting)
			total_meshes += meshes
			max_meshes = maxi(max_meshes, meshes)
			var fid := "F0%s" % fitting.unit.left(1)
			var expected_id := "%s_FLUE_BREAST" % fid
			ids_unchanged = ids_unchanged and String(fitting.name) == expected_id
			var graph_data: Dictionary = AcousticGraphData.nodes.get(
					expected_id, {})
			metadata_clean = metadata_clean \
					and String(graph_data.get("room", "")) == fitting.unit \
					and String(graph_data.get("network", "")) == "flue" \
					and AcousticGraphData.neighbors(expected_id).has("%s_FLUE" % fid)
			var floor_y := float(root.layout.meta.levels.get(fid, 0.0))
			var expected := GameBoot.b2g([10.0, 9.10, floor_y])
			seated = seated and fitting.global_position.distance_to(expected) < 0.012
	_check(fittings.size() == 5,
			"five C-stack bedrooms retain sealed chimney thimbles")
	_check(ids_unchanged,
			"flue marker ids remain the unchanged acoustic binding keys")
	_check(metadata_clean,
			"flue graph carries real 2C-6C metadata on the unchanged ids")
	_check(seated, "every thimble is seated on the masonry breast face")
	_check(max_meshes <= 3 and total_meshes <= 15,
			"sealed thimbles stay at three meshes each / 15 total (%d / %d)" %
			[max_meshes, total_meshes])
	if not fittings.is_empty():
		var cap := fittings[0].get_node_or_null("ClosurePlate") as Node3D
		fittings[0].set_knock_pose(0.0)
		var rest_z := cap.position.z if cap else 0.0
		fittings[0].set_knock_pose(1.0)
		var moved_z := cap.position.z if cap else 0.0
		_check(cap != null and absf(moved_z - rest_z - -0.003) < 0.0001,
				"knock settle retains its render-ruled three-millimetre evidence pose")
		fittings[0].set_knock_pose(0.0)


func _graph_reachable(origin: String) -> Dictionary:
	var seen := {origin: true}
	var frontier := [origin]
	while not frontier.is_empty():
		var current: String = frontier.pop_back()
		for neighbor in AcousticGraphData.neighbors(current):
			if not seen.has(neighbor):
				seen[neighbor] = true
				frontier.append(neighbor)
	return seen


func _prop_mesh_and_boiler_checks() -> void:
	# Props are modelled as heaps of primitives; keeping the mechanism rigged
	# does not excuse keeping every spoke and section as its own draw call.
	var rad_meshes := 0
	var rad_props := 0
	for child in root.get_children():
		if child is RadiatorProp:
			rad_props += 1
			rad_meshes += _count_meshes(child)
	var rad_average := float(rad_meshes) / maxf(1.0, rad_props)
	_check(rad_props == 23 and rad_average < 8.0,
			"radiators stay merged (%.1f meshes each across %d)" %
			[rad_average, rad_props])

	# DoorProp stays outside FunctionalProp on purpose, but not outside the
	# performance budget. The old 120-leaf family cost roughly 4,489 meshes and
	# was absent from the census; subtype batching must keep the replacement
	# below six hundred without merging the collision/animation owner away.
	var door_total := 0
	var door_max := 0
	var door_count := 0
	var door_kinds := {}
	var entry_units := {}
	for child in root.get_children():
		if child is DoorProp:
			door_count += 1
			var family_door := child as DoorProp
			var meshes := _count_meshes(family_door)
			door_total += meshes
			door_max = maxi(door_max, meshes)
			door_kinds[family_door.door_kind] = \
					int(door_kinds.get(family_door.door_kind, 0)) + 1
			if family_door.door_kind == "apartment_entry":
				entry_units[family_door.unit] = true
	_check(door_count == 120,
			"all 120 layout doors use the semantic family")
	_check(door_total <= 600,
			"door family stays below 600 meshes (%d, max leaf %d)" %
			[door_total, door_max])
	_check(entry_units.size() == 23 and not entry_units.has(""),
			"all non-landmark apartment entries carry an explicit unit")
	_check(door_kinds.get("storefront", 0) == 13
			and door_kinds.get("exterior_service", 0) == 2
			and door_kinds.get("cabinet", 0) == 3,
			"storefront, exterior-service and cabinet classes remain distinct")

	# These five families were already merged, but until now only radiators
	# and Vantry points had assertions. A family can quietly regain hundreds
	# of primitive draws while its own interaction test remains green.
	var family_counts := {
		"fridge": [0, 0], "stove": [0, 0], "tap": [0, 0], "toaster": [0, 0],
	}
	var fired_enamel_stoves := 0
	var fired_porcelain_lavatories: Array[String] = []
	for child in root.get_children():
		var key := ""
		if child is FridgeProp:
			key = "fridge"
		elif child is StoveProp:
			key = "stove"
			if (child as StoveProp).enamel_material_key == "enamel_appliance":
				fired_enamel_stoves += 1
		elif child is TapProp:
			key = "tap"
			var tap := child as TapProp
			if tap.fixture == "bath_sink" \
					and tap.porcelain_material_key == "porcelain_fixture":
				fired_porcelain_lavatories.append(tap.unit)
		elif child is ToasterProp:
			key = "toaster"
		if key != "":
			family_counts[key][0] += 1
			family_counts[key][1] += _count_meshes(child)
	for spec in [
		["fridge", 18, 14.0], ["stove", 18, 47.0],
		["tap", 66, 16.0], ["toaster", 14, 14.0],
	]:
		var key: String = spec[0]
		var count: int = family_counts[key][0]
		var total: int = family_counts[key][1]
		var average := float(total) / maxf(1.0, count)
		_check(count == int(spec[1]) and average <= float(spec[2]),
				"%s family stays merged (%.1f meshes each across %d)" %
				[key, average, count])
	_check(fired_enamel_stoves == 18,
			"all eighteen ranges use the approved fired-enamel plate")
	_check(fired_porcelain_lavatories == ["4B"],
			"only 4B's lavatory uses the calm fired-glaze approval plate")

	var plant := root.get_node_or_null("B1_BOILER_01") as BoilerProp
	_check(plant != null, "one functional 1912 coal boiler owns the plant")
	if plant == null:
		return
	_check(plant.global_position.distance_to(Vector3(9.05, -2.8, -1.55)) < 0.02,
			"boiler marker and physical plant share one position")
	_check(_count_meshes(plant) < 20,
			"boiler's long parts list stays merged (%d meshes)" %
			_count_meshes(plant))
	_check(plant.get_node_or_null("BoilerCollision") is StaticBody3D,
			"boiler has a physical service footprint")
	_check(plant.get_node_or_null("FireDoorReach") is Area3D
			and plant.get_node_or_null("AshDoorReach") is Area3D
			and plant.get_node_or_null("WaterGlassReach") is Area3D
			and plant.get_node_or_null("DraftReach") is Area3D,
			"coal, ash, water glass and draft remain reachable")
	plant.set_service_pose()
	var service := plant.get_boiler_state()
	_check(bool(service.fire_door_open) and bool(service.ash_door_open),
			"both tended doors retain independent service poses")
	var heat_before: float = root.heat_balance.total_delivered_heat()
	plant.set_water_level(0.05)
	var heat_starved: float = root.heat_balance.total_delivered_heat()
	plant.set_water_level(0.62)
	_check(heat_starved < heat_before * 0.10,
			"low water at the boiler starves the shared radiator cycle")
	_check(root.boiler_tend != null,
			"boiler tending clock feeds heat and domestic hot water")


func _story_board_checks() -> void:
	# Lena's runtime story collage once inferred a wall from the living-room
	# rectangle.  In 2B that edge is occupied by the bathroom, so the quad
	# floated on the shower glass.  Its cork backing also shared an id with the
	# loose papers on her table.  Guard both owners and the join between them.
	var board: Dictionary = {}
	var old_id_count := 0
	var board_count := 0
	var living_rect: Array = []
	var bath_rect: Array = []
	var floor_z := 0.0
	for floor in root.layout.get("floors", []):
		if str(floor.get("id", "")) != "F02":
			continue
		floor_z = float(floor.get("z", 0.0))
		for room in floor.get("rooms", []):
			if str(room.get("id", "")) == "F02_B_MAIN":
				living_rect = room.get("rect", [])
			elif str(room.get("id", "")) == "F02_B_BATH":
				bath_rect = room.get("rect", [])
		for item in floor.get("furniture", []):
			var item_id := str(item.get("id", ""))
			if item_id == "2B_story_patterns":
				old_id_count += 1
			elif item_id == "2B_story_pattern_board":
				board = item
				board_count += 1
	_check(board_count == 1 and old_id_count == 1,
			"Lena's board and loose patterns have unique assembly ids")
	if board.is_empty() or living_rect.size() < 4 or bath_rect.size() < 4:
		_check(false, "Lena's pattern-board placement data is complete")
		return
	var at := Vector2(float(board.at[0]), float(board.at[1]))
	var in_living := at.x >= float(living_rect[0]) \
			and at.x <= float(living_rect[2]) \
			and at.y >= float(living_rect[1]) \
			and at.y <= float(living_rect[3])
	var in_bath := at.x >= float(bath_rect[0]) \
			and at.x <= float(bath_rect[2]) \
			and at.y >= float(bath_rect[1]) \
			and at.y <= float(bath_rect[3])
	_check(in_living and not in_bath,
			"Lena's pattern board stays in her dry living/work room")
	_check(absf(at.x - float(living_rect[0])) < 0.02 \
			and at.y > 5.90 and at.y < 6.35 \
			and absf(float(board.get("yaw", 0.0)) + 90.0) < 0.01,
			"pattern board occupies Lena's clear west-wall pier")
	var story := root.find_child("ResidentStory_2B", true, false) as StoryDecal
	var yaw := deg_to_rad(float(board.get("yaw", 0.0)))
	var front := Vector2(-sin(yaw), cos(yaw))
	var board_center := float(board.get("z0", 1.0)) \
			+ float(board.get("H", 0.66)) * 0.5
	var expected := GameBoot.b2g(
			[at.x + front.x * 0.033, at.y + front.y * 0.033,
			floor_z + board_center])
	_check(story != null and story.global_position.distance_to(expected) < 0.02,
			"Lena's story collage is seated on its authored cork backing")
	var memory := root.find_child("MemoryArt_lena_visible_mend", true, false) \
			as CharacterMemoryArt
	_check(story != null and memory != null \
			and story.global_position.distance_to(memory.global_position) > 1.0,
			"Lena's pattern board clears her existing wall-art composition")


func _medicine_cabinet_checks() -> void:
	var cabinets: Array[MedicineCabinetProp] = []
	for child in root.get_children():
		if child is MedicineCabinetProp:
			cabinets.append(child)
	_check(cabinets.size() == 23,
			"all twenty-three bathroom mirrors are functional cabinets")

	var total_meshes := 0
	var every_cabinet_under_cap := true
	var every_reach_exists := true
	var every_sweep_clear := true
	var every_stand_clear := true
	var every_fixture_clear := true
	var every_tap_revealed := true
	for cabinet in cabinets:
		var meshes := _count_meshes(cabinet)
		total_meshes += meshes
		every_cabinet_under_cap = every_cabinet_under_cap and meshes <= 8
		every_reach_exists = every_reach_exists \
				and cabinet.get_node_or_null("CabinetReach") is Area3D
		var standing := cabinet.standing_point()
		for point in cabinet.door_sweep_samples():
			every_stand_clear = every_stand_clear \
					and point.distance_to(standing) > 0.22
			if not _cabinet_sweep_point_clear(cabinet, point):
				every_sweep_clear = false
			if not _cabinet_fixture_point_clear(cabinet, point):
				every_fixture_clear = false
		var cabinet_box := _world_visual_aabb(cabinet)
		for child in root.get_children():
			if child is TapProp and child.unit == cabinet.unit \
					and child.fixture == "bath_sink":
				var tap_box := _world_visual_aabb(child)
				every_tap_revealed = every_tap_revealed \
						and cabinet_box.position.y - tap_box.end.y >= 0.10
	_check(every_cabinet_under_cap,
			"each medicine cabinet stays at or below eight visible meshes")
	_check(total_meshes <= 184,
			"medicine-cabinet family stays within its independent mesh budget (%d)"
			% total_meshes)
	_check(every_reach_exists,
			"every medicine cabinet exposes one player interaction volume")
	_check(every_sweep_clear,
			"all twenty-three cabinet leaves clear real room collision")
	_check(every_fixture_clear,
			"all cabinet leaves clear their basin fittings and sconces")
	_check(every_stand_clear,
			"every cabinet opens clear of the worker's basin standing point")
	_check(every_tap_revealed,
			"every raised mirror leaves at least 100 mm above visible tapwork")

	var marker_count := 0
	var structural_count := 0
	var side_sconces := {}
	var mirror_markers := {}
	var hinge_sides := {}
	for floor in root.layout.get("floors", []):
		for marker in floor.get("markers", []):
			if String(marker.get("kind", "")) == "sconce_globe" \
					and String(marker.get("unit", "")) != "":
				var relative_height := float(marker.pos[2]) - float(floor.z)
				if absf(relative_height - 1.62) < 0.001:
					side_sconces[String(marker.unit)] = Vector2(
							float(marker.pos[0]), float(marker.pos[1]))
			if String(marker.get("kind", "")) != "mirror":
				continue
			marker_count += 1
			mirror_markers[String(marker.unit)] = Vector2(
					float(marker.pos[0]), float(marker.pos[1]))
			if String(marker.get("network", "")) == "structural":
				structural_count += 1
			hinge_sides[String(marker.get("hinge_side", ""))] = true
	_check(marker_count == 23 and structural_count == 23,
			"mirror metadata names wall structure, not a fictitious water path")
	var every_sconce_spaced := side_sconces.size() == 23
	for unit in mirror_markers:
		if not side_sconces.has(unit):
			every_sconce_spaced = false
			continue
		var separation: float = mirror_markers[unit].distance_to(
				side_sconces[unit])
		every_sconce_spaced = every_sconce_spaced \
				and separation >= 0.43 and separation <= 0.47
	_check(every_sconce_spaced,
			"all 23 lavatory sconces occupy the measured roomward side position")
	_check(hinge_sides.has("left") and hinge_sides.has("right")
			and hinge_sides.size() == 2,
			"cabinet markers choose one of both geometry-derived hinge sides")
	var graph_mirrors := 0
	for node_id in AcousticGraphData.nodes:
		if String(node_id).contains("_MIRROR_"):
			graph_mirrors += 1
	_check(graph_mirrors == 0,
			"structural mirror metadata does not invent an acoustic graph feature")

	var by_unit := {}
	for cabinet in cabinets:
		by_unit[cabinet.unit] = cabinet
	var no_player_fallback := by_unit.has("2D") and by_unit.has("3C") \
			and by_unit.has("5D") and by_unit.has("6D") and by_unit.has("F01WC")
	if no_player_fallback:
		no_player_fallback = (by_unit["2D"].inventory_names().is_empty()
				and by_unit["3C"].inventory_names().is_empty()
				and by_unit["6D"].inventory_names().is_empty()
				and by_unit["5D"].inventory_names() == ["landlord salve tin"]
				and by_unit["F01WC"].inventory_names()
						== ["carbolic soap", "plasters"])
	_check(no_player_fallback,
			"sealed, vacant, landlord and public cabinets never inherit 4B")

	var player_cabinet := by_unit.get("4B") as MedicineCabinetProp
	_check(player_cabinet != null and player_cabinet.hinge_side == "left",
			"4B's leaf hinges away from its close return wall")
	if player_cabinet:
		player_cabinet.set_door_open(true, 0.0)
		var leaf := player_cabinet.get_node_or_null("CabinetDoor") as Node3D
		_check(leaf != null and absf(rad_to_deg(leaf.rotation.y) + 95.0) < 0.1,
				"left-hinged cabinet reaches the ruled ninety-five-degree pose")
		player_cabinet.set_door_open(false, 0.0)
		_check(leaf != null and absf(leaf.rotation.y) < 0.001,
				"cabinet door returns to its measured shut pose")


func _clock_checks() -> void:
	var owners: Array[ClockProp] = []
	for child in root.get_children():
		if child is ClockProp:
			owners.append(child)
	var witnesses: Array = get_tree().get_nodes_in_group(
			"domestic_witness_clocks")
	_check(owners.size() == 2 and witnesses.size() == 18,
			"two building clocks and eighteen case witnesses are present")
	var total_meshes := 0
	var individual_cap := true
	var mesh_report := []
	for clock in owners + witnesses:
		var meshes := _count_meshes(clock)
		total_meshes += meshes
		individual_cap = individual_cap and meshes <= 10
		mesh_report.append("%s=%d" % [clock.name, meshes])
	_check(individual_cap,
			"every clock remains at or below ten visible meshes (%s)"
			% ", ".join(mesh_report))
	_check(total_meshes <= 160,
			"clock family stays within its independent 160-mesh budget (%d)"
			% total_meshes)

	var by_variant := {}
	for clock in owners:
		by_variant[clock.clock_variant] = clock
	var apartment := by_variant.get("drop_octagon") as ClockProp
	var master := by_variant.get("vantry_master") as ClockProp
	_check(apartment != null and master != null,
			"warehouse variants also exist as distinct installed clocks")
	_check(apartment != null and apartment.get_node_or_null("ClockReach") is Area3D
			and apartment.get_node_or_null("WindingReach") is Marker3D,
			"4B clock exposes its winding point and one interaction volume")
	_check(master != null and master.get_node_or_null("WindingReach") == null
			and absf(master.displayed_offset_minutes() - 4.0) < 0.01,
			"sealed lobby master is authoritative and four minutes fast")
	if apartment:
		var apartment_box := _world_visual_aabb(apartment).grow(0.015)
		var clears_doors := true
		for child in root.get_children():
			if child is DoorProp and apartment_box.intersects(
					_world_visual_aabb(child)):
				clears_doors = false
		_check(clears_doors, "4B drop clock clears every door leaf and frame")
		apartment.set_spring_reserve(0.0)
		_check(apartment.state == FunctionalProp.PState.OFF,
				"spent eight-day spring stops the mechanical hands")
		apartment.interact(null)
		_check(apartment.spring_reserve >= 0.95
				and root.work_orders.status(ClockProp.ORDER_ID) == "closed",
				"winding restores the movement and closes its work order")

	var marker_networks := {}
	for floor in root.layout.get("floors", []):
		for marker in floor.get("markers", []):
			if String(marker.get("kind", "")) == "wall_clock":
				marker_networks[String(marker.id)] = String(marker.network)
	_check(marker_networks.size() == 2
			and marker_networks.get("F04_B_CLOCK_01") == "structural"
			and marker_networks.get("F01_LOBBY_CLOCK_01") == "signal",
			"mechanical 4B clock is structural while the Vantry master carries signal")
	_check(AcousticGraphData.nodes.has("F04_B_CLOCK_01")
			and AcousticGraphData.nodes.has("F01_LOBBY_CLOCK_01")
			and String(AcousticGraphData.nodes["F04_B_CLOCK_01"].network)
					== "structural"
			and String(AcousticGraphData.nodes["F01_LOBBY_CLOCK_01"].network)
					== "signal",
			"both honest clocks enter the correct propagation graph")

	var placements: Dictionary = root.domestic_witnesses.placements
	var readable := placements.size() == 18
	var corrected := {}
	for placed in placements.values():
		readable = readable and float(placed.height) <= 1.95
		corrected[String(placed.style)] = true
	_check(readable,
			"all witness faces are readable below the five-foot worker's sight limit")
	_check(corrected.has("vantry_modular") and corrected.has("sunray_1920")
			and corrected.has("travel_alarm") and corrected.has("split_flap")
			and corrected.has("nixie"),
			"all five period and signal rulings are instantiated")
	_check(String(placements["cam_tilted_room"].mounting) == "wall"
			and String(placements["noel_domestic_museum"].mounting) == "table",
			"4C's two residents spend separate wall and furniture budgets (%s/%s)"
			% [placements["cam_tilted_room"].mounting,
			placements["noel_domestic_museum"].mounting])


func _mail_bank_checks() -> void:
	var bank := root.find_child("LobbyMailBank", true, false) as MailBankProp
	var tray := root.find_child("LobbyPostTray", true, false) as Node3D
	var master := root.get_node_or_null("F01_LOBBY_CLOCK_01") as ClockProp
	_check(bank != null and tray != null and master != null,
			"mail bank, post tray and measured lobby master all exist")
	if bank == null or tray == null or master == null:
		return
	var state := bank.inspection_state()
	_check(int(state.address_count) == 24 and int(state.card_count) == 18
			and int(state.empty_slot_count) == 6,
			"mail elevation keeps six residentless apartments visibly empty")
	_check(absf(bank.global_position.z - 7.88) < 0.01,
			"Couch bank occupies its measured east-wall centre")
	_check(absf(tray.global_position.z - 7.40) < 0.01,
			"post tray derives from and follows the bank centre")
	_check(absf(float(state.player_center_y) - 1.41) < 0.001,
			"4B box stays readable at the five-foot player's eye line")
	_check(int(state.mesh_count) <= 16,
			"batched closed bank stays at or below sixteen meshes (%d)" %
			int(state.mesh_count))
	var bank_box := _world_visual_aabb(bank)
	var master_box := _world_visual_aabb(master)
	_check(bank_box.grow(0.015).intersects(master_box) == false,
			"wider bank clears the Vantry master clock")
	# Non-intersection is not enough: these owners live in different systems,
	# so either can drift until the brass nearly kisses while this check stays
	# green. Preserve the measured 175 mm composition with 25 mm tolerance.
	var clock_gap := master_box.position.z - bank_box.end.z
	_check(clock_gap >= 0.150,
			"mail bank retains 150 mm minimum from lobby master (%.3f m)"
			% clock_gap)
	var local_sweep: AABB = state.open_sweep
	var sweep: AABB = bank.global_transform * local_sweep
	_check(not sweep.intersects(_world_visual_aabb(master).grow(0.02)),
			"4B's wider open leaf clears the master clock")
	_check(not sweep.intersects(_world_visual_aabb(tray).grow(0.02)),
			"4B's wider open leaf clears the sorting tray")
	# A 0.70 m-deep standing lane remains in front of the sweep; checking the
	# open pose matters because the new leaf reaches 70 mm farther than its
	# predecessor even though the closed elevation is shallower.
	var stand := bank.global_position + Vector3(-0.80, 1.41, 0.0)
	_check(not sweep.grow(0.05).has_point(stand),
			"open box leaves a full worker standing lane in the lobby")


func _cabinet_sweep_point_clear(cabinet: MedicineCabinetProp,
		point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.018
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collide_with_areas = false
	var hits := get_viewport().world_3d.direct_space_state.intersect_shape(
			query, 8)
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider != null and not cabinet.is_ancestor_of(collider):
			return false
	return true


func _cabinet_fixture_point_clear(cabinet: MedicineCabinetProp,
		point: Vector3) -> bool:
	for child in root.get_children():
		var relevant := false
		if child is TapProp:
			relevant = child.unit == cabinet.unit and child.fixture == "bath_sink"
		elif child is LightFixtureProp:
			relevant = child.name == "%s_LT_SCONCE" % cabinet.unit
		if relevant:
			var bounds := _world_visual_aabb(child)
			if bounds.size.length_squared() > 0.0 and bounds.grow(0.012).has_point(point):
				return false
	return true


func _world_visual_aabb(node: Node) -> AABB:
	var found := false
	var bounds := AABB()
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D and current.mesh != null:
			var mi := current as MeshInstance3D
			var box: AABB = mi.global_transform * mi.get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
		for child in current.get_children():
			pending.append(child)
	return bounds if found else AABB()


func _floor_below(from: Vector3) -> bool:
	var params := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.2, 0))
	return not get_viewport().world_3d.direct_space_state \
			.intersect_ray(params).is_empty()


## Waypoint steering: drive toward an XZ target until close or timed out,
## so the climb follows the actual stair geometry instead of blind timing.
func _goto(pl: PlayerController, target: Vector2, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		var pos := Vector2(pl.global_position.x, pl.global_position.z)
		if pos.distance_to(target) < 0.3:
			break
		var dir := (target - pos).normalized()
		pl.autopilot = Vector3(dir.x, 0, dir.y)
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	pl.autopilot = Vector3.ZERO


func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	return cond.call()


func _count_meshes(n: Node) -> int:
	var total := 1 if n is MeshInstance3D else 0
	for c in n.get_children():
		total += _count_meshes(c)
	return total


func _shop_static_checks() -> void:
	var f01: Dictionary = {}
	for floor in root.layout.get("floors", []):
		if String(floor.get("id", "")) == "F01":
			f01 = floor
			break
	var boxes: Array = []
	var batches := {}
	var material_buckets := {}
	var heroes := {}
	var ledgers := 0
	for entry in f01.get("furniture", []):
		var batch := String(entry.get("batch", ""))
		if not batch.begins_with("shop_"):
			continue
		boxes.append(entry)
		batches[batch] = true
		material_buckets["%s|%s" % [batch, String(entry.get("mat", "trim"))]] = true
		if String(entry.get("hero", "")) != "":
			heroes[String(entry.hero)] = true
		var eid := String(entry.get("id", ""))
		if eid.ends_with("_ledger") or eid.ends_with("_book"):
			ledgers += 1
	_check(boxes.size() <= 1080 and batches.size() == 11,
			"eleven owned shop batches stay below 1080 static boxes (%d)"
			% boxes.size())
	_check(heroes.size() == 10,
			"ten isolatable heroes plus the in-situ funeral arrangement exist")
	_check(ledgers == 11, "every shop keeps one account book")

	# Imported mesh names, not source assumptions. Every local material bucket
	# must remain smaller than a shop; the old floor-wide mesh was 220 x 148 m
	# and silently lost its own lamps to GL Compatibility's per-object cap.
	var shop_meshes: Array[MeshInstance3D] = []
	var floor_node: Node = root.floor_nodes.get("F01")
	if floor_node:
		_collect_named_shop_meshes(floor_node, shop_meshes)
	var local_aabbs := not shop_meshes.is_empty()
	for mesh in shop_meshes:
		var size := mesh.get_aabb().size
		local_aabbs = local_aabbs and size.x <= 8.0 and size.z <= 8.0
	_check(shop_meshes.size() == material_buckets.size() and shop_meshes.size() <= 190,
			"shop geometry imports as bounded local material buckets (%d meshes)"
			% shop_meshes.size())
	_check(local_aabbs,
			"no shop bucket regresses to the block-wide lighting AABB")


func _collect_named_shop_meshes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and String(node.name).contains("retail_shop_"):
		into.append(node)
	for child in node.get_children():
		_collect_named_shop_meshes(child, into)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [ok] %s" % label)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % label)
