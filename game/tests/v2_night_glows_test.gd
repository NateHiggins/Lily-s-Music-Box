extends Node
## Night glows in V2 (v1r_night_glows_20261109): light spills under a closed
## door when the room behind it has a lamp on, on the hall side and nowhere
## else; it goes when the room's switch is thrown or the door is opened; and
## the moon fill follows the eye through rooms with a window, at the strength
## the day-night director gives it.
const Glows := preload("res://scripts/building/orison_v2_night_glows.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _until(ready: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if ready.call():
			return true
		await get_tree().process_frame
	return bool(ready.call())


## The world goes on loading for a while after it reports ready, and the glows
## poll on their own clock: wait until frames are short and the node is live.
func _settle(node: Node) -> float:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while (quiet < 60 or not node.can_process()) and Time.get_ticks_msec() - began < 60000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0
	return (Time.get_ticks_msec() - began) / 1000.0


static func _inside(rect: Array, at: Vector3, slack: float) -> bool:
	return at.x >= float(rect[0]) - slack and at.x <= float(rect[2]) + slack \
			and at.z >= float(rect[1]) - slack and at.z <= float(rect[3]) + slack


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 20, 1380)
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	var glows: Node3D = world.get("night_glows")
	_check(glows != null and glows.get_script() == Glows, "V2 composes the night glows")
	if glows == null:
		_finish(world)
		return
	var blockout: Node3D = glows.blockout
	var layout: Dictionary = world.layout
	var rects: Dictionary = {}
	var levels: Dictionary = {}
	var space_level: Dictionary = {}
	for level: Dictionary in layout.levels:
		levels[str(level.id)] = float(level.y)
	for space: Dictionary in layout.spaces:
		rects[str(space.id)] = space.rect
		space_level[str(space.id)] = str(space.level)
	var settled: float = await _settle(glows)
	_check(glows.can_process(), "the glows are live once the world has settled (%.1f s)" % settled)
	var stats: Dictionary = glows.stats()
	print("[V2 NIGHT GLOWS] ", stats, " skipped ", glows.skipped)
	_check(int(stats.doors) >= 40, "the doors between a lit room and its hall are bound (%d)" % int(stats.doors))
	_check(int(stats.lit_rooms) > 0 and int(stats.leaking) > 0, "rooms with a lamp on spill at startup (%d rooms, %d doors)" % [int(stats.lit_rooms), int(stats.leaking)])
	var switches := world.get_node_or_null("V2RoomSwitches") as SwitchSystem
	_check(switches != null and glows.switches == switches, "the awake authority is V2's own switch system")

	# Every spill lies in its own hall, on the floor, and never in the room.
	var to_plan := blockout.global_transform.affine_inverse() * glows.global_transform
	var misplaced := 0
	var counted := 0
	for hall: String in glows._batches:
		var batch: MeshInstance3D = glows._batches[hall]
		if batch.mesh == null:
			continue
		var floor_y: float = levels[space_level[hall]]
		for vertex: Vector3 in batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var at := to_plan * vertex
			counted += 1
			if not _inside(rects[hall], at, 0.02) or at.y < floor_y or at.y > floor_y + 2.4:
				misplaced += 1
	_check(counted > 0 and misplaced == 0, "every spill vertex lies inside its own hall (%d of %d outside)" % [misplaced, counted])

	# One door, followed through its lamp and its leaf.
	var door_id := "F04_B_BATH_DOOR"
	if not glows.spills.has(door_id):
		door_id = str(glows.spills.keys()[0])
	var spill: Dictionary = glows.spills[door_id]
	var door: DoorProp = spill.door
	var room := str(spill.room)
	var hall := str(spill.hall)
	print("[V2 NIGHT GLOWS] following %s: %s spills into %s" % [door_id, room, hall])
	door.restore_mechanism({"angle": 0.0})
	if not glows.is_lit(room):
		switches.toggle_room(room)
	_check(await _until(func() -> bool: return glows.leaking(door_id), 2.0), "a closed door with a lit room behind it spills")
	var batch: MeshInstance3D = glows._batches.get(hall)
	_check(batch != null and batch.mesh != null and str(batch.get_meta("surface_role", "")) == "door_light_spill",
		"the hall carries one spill mesh, marked as an optical effect")
	if batch == null or batch.mesh == null:
		_finish(world)
		return
	var material := batch.material_override as StandardMaterial3D
	_check(material != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			and material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and material.albedo_texture == null,
		"it is unshaded additive light with no texture")
	# This door's own vertices, picked out in the door's frame.
	var to_door := (spill.anchor as Node3D).global_transform.affine_inverse() * glows.global_transform
	var arrays := batch.mesh.surface_get_arrays(0)
	var mine := 0
	var in_room := 0
	var on_floor := 0
	var brightest := 0.0
	var floor_y: float = levels[space_level[hall]]
	for index in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var vertex: Vector3 = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[index]
		var local: Vector3 = to_door * vertex
		var out: float = local.z * float(spill.side)
		if absf(local.x) > float(spill.width) * 0.5 + 0.02 or out < 0.1 or out > 0.4 \
				or local.y < -0.01 or local.y > float(spill.height) + 0.02:
			continue
		var at: Vector3 = to_plan * vertex
		mine += 1
		if _inside(rects[room], at, -0.01):
			in_room += 1
		if absf(at.y - floor_y - Glows.FLOOR_CLEAR) < 0.002:
			on_floor += 1
		var tone: Color = (arrays[Mesh.ARRAY_COLOR] as PackedColorArray)[index]
		brightest = maxf(brightest, maxf(tone.r, maxf(tone.g, tone.b)))
	_check(mine == Glows.SPILL_STEPS * 6 + 18, "the door has its floor bar and its three hairlines (%d vertices)" % mine)
	_check(in_room == 0, "none of it is inside the lit room")
	_check(on_floor == Glows.SPILL_STEPS * 6, "the bar lies just above the hall floor (%d vertices)" % on_floor)
	_check(brightest > 0.4 and brightest < 0.8, "it is dimmer than a window (%.2f)" % brightest)

	# The room's own switch, thrown as the plate throws it.
	var before := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	switches.toggle_room(room)
	_check(not glows.is_lit(room), "the switch puts the room's lamps out")
	_check(await _until(func() -> bool: return not glows.leaking(door_id), 2.0), "and the spill goes with them")
	var after := 0 if batch.mesh == null else (batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_check(after == before - (Glows.SPILL_STEPS * 6 + 18), "the hall's mesh loses that door and keeps the rest (%d to %d vertices)" % [before, after])
	switches.toggle_room(room)
	_check(await _until(func() -> bool: return glows.leaking(door_id), 2.0), "the lamp back on brings it back")

	# The leaf: an open door has no gap to leak through.
	door.restore_mechanism({"angle": door.motion_target_angle(true) * 0.5})
	_check(await _until(func() -> bool: return not glows.leaking(door_id), 2.0), "a door standing half open does not spill")
	door.restore_mechanism({"angle": 0.0})
	_check(await _until(func() -> bool: return glows.leaking(door_id), 2.0), "closed again, it does")

	# The moon fill follows the eye, in windowed rooms only.
	var moon: OmniLight3D = world.get("moon_fill")
	_check(moon != null and moon == glows.moon_fill and not moon.shadow_enabled, "the world has one shadowless moon fill")
	var director: Node = world.get("day_night_director")
	var eye := Camera3D.new()
	world.add_child(eye)
	world.view_override = eye
	var windowed := ""
	var blind := ""
	for space_id: String in rects:
		if not space_id.begins_with("F04_"):
			continue
		if glows._windowed.has(space_id) and windowed == "":
			windowed = space_id
		elif not glows._windowed.has(space_id) and blind == "" and space_id.contains("BATH"):
			blind = space_id
	_check(windowed != "" and blind != "", "a windowed room and a windowless one are found (%s, %s)" % [windowed, blind])
	if windowed != "" and blind != "" and moon != null:
		eye.global_position = _centre(blockout, rects[windowed], levels["F04"])
		_check(str(world.room_at_world(eye.global_position)) == windowed, "the eye stands in %s" % windowed)
		_check(await _until(func() -> bool: return moon.visible and moon.light_energy > 0.05, 4.0),
			"at eleven at night the fill comes up in a windowed room (%.3f)" % moon.light_energy)
		_check(is_equal_approx(float(moon.get("energy_scale")), float(director.resolved_profile().get("fill", -1.0))),
			"at the strength the day-night director gives it (%.2f)" % float(moon.get("energy_scale")))
		_check(moon.global_position.distance_to(eye.global_position + Vector3(0, 1.6, 0)) < 0.05, "and hangs above the eye")
		eye.global_position = _centre(blockout, rects[blind], levels["F04"])
		_check(await _until(func() -> bool: return not moon.visible, 6.0), "it goes out where there is no window")
	world.view_override = null
	eye.queue_free()
	_finish(world)


static func _centre(blockout: Node3D, rect: Array, floor_y: float) -> Vector3:
	return blockout.to_global(Vector3((float(rect[0]) + float(rect[2])) * 0.5, floor_y + 1.5,
			(float(rect[1]) + float(rect[3])) * 0.5))


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 NIGHT GLOWS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	CampaignTime.set_frozen_for_tests(false)
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
