extends Node
## Headless building validation — not shipped gameplay. Run:
##   godot --headless --path game res://tests/WalkTest.tscn
## Asserts: every level has walkable floor, apartments have slabs, the
## front stair is physically climbable by the real player controller, the
## elevator travels B1..F06, and props/conductor are alive.
## Exits with the failure count as exit code.

var root: Node3D
var _failures := 0
var _arrivals := {}


func _record_arrival(node_id: String, i: int, _a: float, _p: float,
		_s: float) -> void:
	if i != 0:
		return  # compare like with like: only the motif's downbeat
	if not _arrivals.has(node_id):
		_arrivals[node_id] = []
	_arrivals[node_id].append(Time.get_ticks_msec())


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

	# --- occlusion culling: the masonry is what stops the renderer drawing
	# four storeys of furniture through the facade
	var occ := root.get_node_or_null("Occluders")
	var occ_boxes := 0
	if occ:
		for c3 in occ.get_children():
			if c3 is OccluderInstance3D and c3.occluder is BoxOccluder3D:
				occ_boxes += 1
	_check(occ_boxes > 500, "occluders built from wall data (%d)" % occ_boxes)
	# Props are modelled as heaps of primitives; the column radiator alone
	# was 62 MeshInstance3Ds, more than half of all prop geometry in the
	# building. merge_static() bakes fixed sub-trees down to one mesh per
	# finish — this guards the win, since the cost is invisible until
	# something profiles it.
	var rad_meshes := 0
	var rad_props := 0
	for c4 in root.get_children():
		if c4 is RadiatorProp:
			rad_props += 1
			rad_meshes += _count_meshes(c4)
	_check(rad_props > 0 and float(rad_meshes) / rad_props < 8.0,
			"radiators stay merged (%.1f meshes each across %d)" %
			[float(rad_meshes) / maxf(1.0, rad_props), rad_props])
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
	_check(int(glow_stats.get("dark", 0)) > 0,
			"some windows stay dark (sealed 2D, burnt 5D, and sleepers)")
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
	await _goto(pl, Vector2(-8.62, 6.55), 4.0)  # east lane past the leaf
	await _goto(pl, Vector2(-9.5, 7.9), 4.0)    # to the bedside
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
	pl.global_position = Vector3(4.3, 3.35, 0.0)  # corridor: streaming back
	pl.velocity = Vector3.ZERO
	await get_tree().create_timer(0.4).timeout
	_check(not root.floor_nodes["F06"].visible,
			"floor streaming resumes outside the eye")
	root.show_all_floors = true

	# --- elevator travel across full range
	var ele: OrisonElevator = root.elevator
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

	_check(AcousticGraphData.nodes.size() >= 25,
			"acoustic graph loaded (%d nodes)" % AcousticGraphData.nodes.size())
	_check(not AcousticGraphData.neighbors("F04_B_RADIATOR_01").is_empty(),
			"4B radiator connected to heating network")

	await _vertical_slice_checks()

	print("WALKTEST RESULT: %s" %
			("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
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

	# 4B detail: kettle boils and its whistle can be taken off; the wall
	# clock's tick drifts toward the conductor's tempo under infection
	var kettle: KettleProp = root.get_node_or_null("F04_B_KETTLE_01")
	_check(kettle != null, "kettle on the 4B counter")
	if kettle:
		Conductor.infection = 0.1  # below quantize threshold: boil is honest
		kettle.heat_time = 1.0
		kettle.interact(null)
		var okk: bool = await _until(func(): return kettle.state == kettle.PState.COMPLETING, 8.0)
		_check(okk, "kettle reaches the whistle")
		kettle.interact(null)
		_check(kettle.cycles_completed == 1 and kettle.state == kettle.PState.IDLE,
				"kettle switched off cleanly")
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
	_check(anim.get_animation_list().size() == 10,
			"all ten clips survived the merge (%d)" %
			anim.get_animation_list().size())
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


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [ok] %s" % label)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % label)
