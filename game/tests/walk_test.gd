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
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	root.show_all_floors = true

	var levels: Dictionary = root.layout["meta"]["levels"]
	for fid in levels:
		var z: float = levels[fid]
		var p := Vector3(4.3, z + 1.5, 0.0) if fid != "ROOF" \
				else Vector3(0.0, z + 1.5, 8.0)
		_check(_floor_below(p), "%s has walkable floor" % fid)
	_check(_floor_below(Vector3(-9.5, 11.2, -4.8)), "apartment 4B has a slab")
	_check(_floor_below(Vector3(9.5, 11.2, -4.8)), "apartment 4C has a slab")
	_check(_floor_below(Vector3(0.0, -1.3, 5.0)), "basement corridor floor")

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
	_check(lst.full == mini(eligible, root.light_rig.ACTIVE_N),
			"the working set is the nearest %d of %d eligible fixtures" %
			[lst.full, eligible])
	# Shadows are budgeted separately from light and far more tightly: an
	# omni's shadow is a cube, so each caster re-renders the visible set
	# six times. Casters are the nearest few of the lit set, never more.
	_check(casting_unlit == 0,
			"no unlit fixture wastes a shadow map (%d casters)" % lst.shadows)
	_check(lst.shadows == mini(eligible, root.light_rig.SHADOW_N),
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
	_check(ProjectSettings.get_setting(
			"rendering/occlusion_culling/use_occlusion_culling", false),
			"occlusion culling is enabled for the project")

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
	Conductor.infection = 0.15
	Conductor.origin_node = "B1_BOILER_01"


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


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [ok] %s" % label)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % label)
