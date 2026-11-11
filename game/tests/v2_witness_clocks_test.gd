extends Node
## The eighteen witness clocks and the two honest clocks in V2
## (v1r_witness_tells_20261109, v1r_small_props_20261109): each witness clock
## is in its resident's flat on a real wall or support, keeps campaign time,
## reads wrong when its haunt is staged and comes back honest by V1's own
## restore; the honest clocks keep time and have no haunt; every mounted
## surface is Blender geometry with authored UVs in a catalogue finish.
## With SHOT_DIR set (windowed), also photographs every clock in its room.
const Clocks := preload("res://scripts/building/orison_v2_witness_clocks.gd")
const Native := preload("res://scripts/building/orison_v2_native_witness_clocks.gd")
const READING := ["nixie", "split_flap", "writer", "travel_alarm"]
const SIGNAL := ["vantry_modular", "nixie", "split_flap"]
const TOL := 0.003

var _fails := 0
var _checks := 0
var _world: Node
var _stand := Vector3.ZERO
var _look := Vector3.ZERO
var _framing := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(_world)
	while not _world.startup_failed and _world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not _world.startup_failed, "the V2 world starts")
	if _world.startup_failed:
		_finish()
		return
	CampaignTime.set_frozen_for_tests(true)
	var blockout: Node3D = _world.get("_blockout")
	var mounted: Dictionary = _world.witness_clocks
	var clocks: Dictionary = mounted.clocks
	var honest: Array = mounted.honest
	_check((mounted.errors as Array).is_empty(), "the mount reports no errors: %s" % [mounted.errors])
	_check(clocks.size() == 18, "eighteen witness clocks are mounted (%d)" % clocks.size())
	_check(honest.size() == 2, "two honest clocks are mounted (%d)" % honest.size())
	if clocks.size() != 18 or honest.size() != 2:
		_finish()
		return
	await _settle(clocks.values()[0])
	var profiles: Dictionary = {}
	for spec: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(Clocks.PROFILES)).profiles:
		profiles[str(spec.case_id)] = spec
	var everything: Array = clocks.values() + honest
	_place_checks(clocks, honest, profiles)
	_surface_checks(everything)
	await _time_checks(clocks, honest)
	await _haunt_checks(clocks, profiles, mounted.node)
	await _honest_checks(honest)
	if not OS.get_environment("SHOT_DIR").is_empty():
		await _photograph(clocks, honest)
	_finish()


func _process(_delta: float) -> void:
	if _framing and _world != null and _world.player != null:
		_world.player.global_position = _stand
		_world.player.camera.look_at(_look)


func _settle(node: Node) -> void:
	var calm := 0
	var last := Time.get_ticks_usec()
	for i in 1800:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		calm = calm + 1 if now - last < 250000 else 0
		last = now
		if calm >= 60 and node.can_process():
			return
	_check(false, "the world settles and the clocks process")


# -- placement -------------------------------------------------------------
func _place_checks(clocks: Dictionary, honest: Array, profiles: Dictionary) -> void:
	for case_id: String in clocks:
		var clock: Node3D = clocks[case_id]
		var unit := str(profiles[case_id].unit)
		var inside := clock.global_position + clock.global_transform.basis.z * 0.12 + Vector3.UP * 0.04
		_check(_world.unit_at_world(inside) == unit, "%s is in flat %s (found '%s')" % [case_id, unit, _world.unit_at_world(inside)])
		_check(clock.mounting == ("table" if clock.style in ["mantel", "travel_alarm"] else "wall"),
			"%s is mounted as V1 rules (%s)" % [case_id, clock.mounting])
		_support_check(clock, clock._spec, clock.mounting, case_id)
	_check(_world.room_at_world(honest[0].global_position + honest[0].global_transform.basis.z * 0.12) == "F01_LOBBY",
		"the Vantry reference clock is in the lobby")
	_check(_world.room_at_world(honest[1].global_position + honest[1].global_transform.basis.z * 0.12) == "F04_B_MAIN",
		"the drop octagon is in 4B's main room")
	for clock: Node3D in honest:
		_support_check(clock, clock._spec, "wall", str(clock.name))


## Short rays from inside the clock to what carries it: the wall behind a
## hung clock, the furniture under a standing one. All within 3 cm.
func _support_check(clock: Node3D, spec: Dictionary, mounting: String, who: String) -> void:
	var space := clock.get_world_3d().direct_space_state
	var extent := Native.bounds(spec)
	var exclude: Array[RID] = []
	for body in clock.find_children("*", "CollisionObject3D", true, false):
		exclude.append((body as CollisionObject3D).get_rid())
	var points: Array[Vector3] = []
	var toward := Vector3.ZERO
	if mounting == "table":
		toward = Vector3.DOWN
		for dx in [-0.6, 0.0, 0.6]:
			points.append(Vector3(extent.get_center().x + dx * extent.size.x * 0.5, 0.0, 0.0))
	else:
		toward = Vector3.FORWARD
		points = [Vector3.ZERO, Vector3(extent.position.x * 0.6, 0, 0), Vector3(extent.end.x * 0.6, 0, 0),
			Vector3(0, extent.position.y * 0.8, 0), Vector3(0, extent.end.y * 0.8, 0)]
	var worst := 0.0
	var missed := 0
	for point: Vector3 in points:
		var from := clock.global_transform * (point - toward * 0.05)
		var to := clock.global_transform * (point + toward * 0.05)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			missed += 1
			continue
		worst = maxf(worst, absf((hit.position as Vector3).distance_to(from) - 0.05))
	_check(missed == 0 and worst <= 0.03, "%s rests on a real %s (%d of %d rays missed, worst gap %.1f mm)" % [
		who, "support" if mounting == "table" else "wall", missed, points.size(), worst * 1000.0])


# -- surfaces --------------------------------------------------------------
func _surface_checks(everything: Array) -> void:
	var draws := 0
	var triangles := 0
	for clock: Node3D in everything:
		var bad: Array[String] = []
		for node in clock.find_children("*", "MeshInstance3D", true, false):
			var draw := node as MeshInstance3D
			draws += 1
			if not (draw.mesh is ArrayMesh) or draw.mesh.get_surface_count() != 1:
				bad.append("%s is not one authored surface" % draw.name)
				continue
			var arrays := draw.mesh.surface_get_arrays(0)
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			if uvs == null or (uvs as PackedVector2Array).is_empty() or arrays[Mesh.ARRAY_TANGENT] == null:
				bad.append("%s has no authored UVs or tangents" % draw.name)
			var material := draw.material_override
			if str(draw.get_meta("v2_witness_clock_part", "")) == "Glass":
				if not (material is ShaderMaterial):
					bad.append("%s is not on the glass route" % draw.name)
				continue
			var finish := material as StandardMaterial3D
			if finish == null or finish.albedo_texture == null or finish.roughness_texture == null \
					or finish.normal_texture == null or finish.uv1_triplanar:
				bad.append("%s is not a catalogue finish on its own UVs" % draw.name)
		_check(bad.is_empty(), "%s: every surface is authored geometry in a catalogue finish %s" % [clock.name, bad])
	print("  [V2 WITNESS CLOCKS] %d mesh draws, %d triangles mounted" % [draws, triangles])


# -- timekeeping -----------------------------------------------------------
func _set_time(hour: int, minute: int, second: float) -> float:
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 10, hour * 60 + minute)
	clock.advance_to(second / 60.0)
	return clock.minute_of_day()


func _near(a: float, b: float) -> bool:
	return absf(angle_difference(a, b)) < TOL


func _reads(clock: Node, total: float) -> bool:
	var hour := int(total / 60.0)
	var minute := int(total) % 60
	var second := fposmod(total * 60.0, 60.0)
	if clock.style in READING:
		if clock._display.text != "%02d:%02d" % [hour % 12 if hour % 12 else 12, minute]:
			return false
	if clock._hour == null:
		return clock.style in READING
	return _near(clock._hour.rotation.z, -TAU * (float(hour % 12) + minute / 60.0) / 12.0) \
		and _near(clock._minute.rotation.z, -TAU * (minute + second / 60.0) / 60.0) \
		and _near(clock._second.rotation.z, -TAU * second / 60.0)


func _honest_reads(clock: Node, total: float) -> bool:
	total += clock.displayed_offset_minutes()
	return _near(clock._hour.rotation.z, -TAU * fmod(total / 60.0, 12.0) / 12.0) \
		and _near(clock._minute.rotation.z, -TAU * fmod(total, 60.0) / 60.0) \
		and _near(clock._second.rotation.z, -TAU * fmod(total * 60.0, 60.0) / 60.0)


func _time_checks(clocks: Dictionary, honest: Array) -> void:
	for at: Array in [[9, 41, 30.0], [15, 7, 15.0]]:
		var total := _set_time(at[0], at[1], at[2])
		_check(is_equal_approx(total, at[0] * 60 + at[1] + at[2] / 60.0), "campaign time is set to %02d:%02d:%02d" % at)
		for i in 3:
			await get_tree().process_frame
		for case_id: String in clocks:
			var clock: Node = clocks[case_id]
			_check(_reads(clock, total), "%s (%s) reads campaign time %02d:%02d:%02d" % [case_id, clock.style, at[0], at[1], at[2]])
		_check(_honest_reads(honest[0], total), "the Vantry reference clock reads campaign time plus its four minutes")
		_check(_honest_reads(honest[1], total), "the drop octagon reads campaign time")
	_check(clocks["jonah_sentence_insects"]._display.text == "03:07", "the writer's sheet reads 03:07 for 15:07")
	_check(clocks["cal_memory_radio"]._hour == null and clocks["evelyn_paper_jam"]._hour != null,
		"figure-reading styles carry no hands; dial styles do")


# -- the haunt -------------------------------------------------------------
func _haunt_checks(clocks: Dictionary, profiles: Dictionary, holder: Node) -> void:
	var total := _set_time(9, 41, 30.0)
	for i in 3:
		await get_tree().process_frame
	var turn := deg_to_rad(6.0 + 2 * 4.0)
	for case_id: String in clocks:
		var clock: Node = clocks[case_id]
		var tell := str(profiles[case_id].tell)
		var minute_before: float = clock._minute.rotation.z if clock._minute != null else 0.0
		_check(clock.service_wire_card().condition.contains("READING LIVE"), "%s reports a live reading before the haunt" % case_id)
		_check(not clock.stage_haunt(0, null), "%s ignores a tier 0 haunt" % case_id)
		_check(clock.stage_haunt(2, null), "%s takes a tier 2 haunt" % case_id)
		_check(clock._possessed and clock.state == FunctionalProp.PState.INFECTED, "%s is possessed" % case_id)
		_check(not clock.stage_haunt(2, null), "%s refuses a second haunt while possessed" % case_id)
		_check(clock.service_wire_card().condition.contains("VISIBLY DISTURBED"), "%s reports a disturbed reading" % case_id)
		if clock._spec.has("possessed"):
			_check(clock.dial_possessed(), "%s shows its wrong dial detail (%s)" % [case_id, clock._spec.possessed.note])
		var text: String = clock._display.text
		var wrong := false
		match tell:
			"correction", "pending":
				wrong = _near(clock._minute.rotation.z, minute_before + TAU * 5.0 / 60.0)
			"call_bell":
				wrong = _near(clock._minute.rotation.z, minute_before + PI)
			"label_time":
				wrong = text == "YOU: NOW" and clock._tell_mark.visible
			"loose_second":
				wrong = _near(clock._second.rotation.z, PI * 0.92)
			"sample_skip":
				wrong = _near(clock._minute.rotation.z, minute_before + TAU * 4.0 / 60.0)
			"last_minute":
				wrong = text == "05:42" and _near(clock._minute.rotation.z, minute_before + TAU / 60.0)
			"new_fault":
				wrong = clock._tell_mark.visible and is_equal_approx(clock.rotation.z, turn * 0.25)
			"listen_back":
				wrong = _near(clock._minute.rotation.z, minute_before + TAU * 3.0 / 60.0)
			"level":
				wrong = is_equal_approx(clock.rotation.z, turn)
			"untouched":
				wrong = clock._tell_mark.visible and is_equal_approx(clock._face.rotation.y, PI)
			"checkout":
				wrong = text == "11:00" and clock._tell_mark.visible
			"egress":
				wrong = text == "NO EXIT" and is_equal_approx(clock.rotation.z, -turn)
			"broadcast":
				wrong = text == "11:57" and clock._tell_mark.visible
			"audience":
				wrong = clock._tell_mark.visible and is_equal_approx(clock._face.scale.x, 1.05)
			"delay":
				wrong = text == "-00:07"
			"unfinished":
				wrong = text == "09:__"
			"two_histories":
				wrong = text == "03:16 / 04:17" and is_equal_approx(clock.rotation.z, turn * 0.35)
		_check(wrong, "%s performs its tell '%s' (reading '%s')" % [case_id, tell, text])
	# A possessed clock stops following the hour: move the campaign on and
	# only V1's own restore (9 + 2.5 s a tier) may bring the reading back.
	total = _set_time(9, 55, 10.0)
	for i in 5:
		await get_tree().process_frame
	var still := 0
	for case_id: String in clocks:
		if clocks[case_id]._possessed and not _reads(clocks[case_id], total):
			still += 1
	_check(still == 18, "all eighteen keep their wrong reading while possessed (%d)" % still)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30000:
		await get_tree().process_frame
		var held := 0
		for case_id: String in clocks:
			if clocks[case_id]._possessed:
				held += 1
		if held == 0:
			break
	var waited := (Time.get_ticks_msec() - started) / 1000.0
	_check(waited > 9.0 and waited < 25.0, "V1's restore releases the clocks after its own interval (%.1f s)" % waited)
	for i in 3:
		await get_tree().process_frame
	for case_id: String in clocks:
		var clock: Node = clocks[case_id]
		var calm: bool = not clock._possessed and clock.state == FunctionalProp.PState.OPERATING \
			and not clock._tell_mark.visible and is_zero_approx(clock.rotation.z) \
			and clock._face.transform.is_equal_approx(Transform3D.IDENTITY) and not clock.dial_possessed()
		_check(calm and _reads(clock, total), "%s comes back honest and reads campaign time again" % case_id)
		var card: Dictionary = clock.interact(null)
		var title := "VANTRY SIGNAL CLOCK" if clock.style in SIGNAL \
			else ("DOMESTIC TABLE CLOCK" if clock.mounting == "table" else "DOMESTIC WALL CLOCK")
		_check(str(card.get("title", "")) == title and str(card.get("card_id", "")) == "winding_clock",
			"%s answers inspection with V1's card (%s)" % [case_id, card.get("title", "")])
		# The waking organism's lookup: a node under the witnesses whose
		# case_ids holds the case.
		var found: Node = null
		for node in holder.find_children("*", "", true, false):
			if "case_ids" in node and (node.get("case_ids") as Array).has(case_id):
				found = node
				break
		_check(found == clock, "%s is found by case_ids, as the waking organism looks" % case_id)
	_check(get_tree().get_nodes_in_group("domestic_witness_clocks").size() == 18, "the clocks are in V1's group")


# -- the honest clocks -----------------------------------------------------
func _honest_checks(honest: Array) -> void:
	var master: Node = honest[0]
	var octagon: Node = honest[1]
	for clock: Node in honest:
		_check(not clock.has_method("stage_haunt") and not clock.is_in_group("domestic_witness_clocks"),
			"%s has no haunt" % clock.name)
	_check(is_equal_approx(master.displayed_offset_minutes(), 4.0) and is_zero_approx(octagon.displayed_offset_minutes()),
		"the reference clock is four minutes fast; the octagon is true")
	var swing_a: float = octagon._pendulum.rotation.z
	for i in 9:
		await get_tree().process_frame
	_check(not is_equal_approx(swing_a, octagon._pendulum.rotation.z) and absf(octagon._pendulum.rotation.z) <= 0.0751,
		"the octagon's pendulum swings on its pivot")
	_check(is_equal_approx(octagon.spring_reserve, 0.18) or octagon.spring_reserve < 0.18, "the octagon starts on V1's low spring")
	var card: Dictionary = octagon.interact(null)
	_check(is_equal_approx(octagon.spring_reserve, 1.0) and str(card.get("card_id", "")) == "winding_clock",
		"winding the octagon charges the spring")
	_check(octagon.winding_point().distance_to(octagon.global_position) > 0.05, "the octagon keeps its winding reach")
	var rest: Vector3 = master._master_cover.position
	card = master.interact(null)
	_check(str(card.get("title", "")) == "VANTRY REFERENCE CLOCK", "the reference clock answers with its sealed-cover card")
	var moved := false
	for i in 12:
		await get_tree().process_frame
		moved = moved or not master._master_cover.position.is_equal_approx(rest)
	for i in 30:
		await get_tree().process_frame
	_check(moved and master._master_cover.position.is_equal_approx(rest), "the sealed setting cover rattles and settles")
	var total := _set_time(21, 30, 45.0)
	for i in 3:
		await get_tree().process_frame
	_check(_honest_reads(master, total) and _honest_reads(octagon, total), "both honest clocks follow the campaign to 21:30:45")


# -- photographs -----------------------------------------------------------
func _photograph(clocks: Dictionary, honest: Array) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	if _world.service_set_carrier != null:
		_world.service_set_carrier.visible = false
	_world.player.set_physics_process(false)
	_world.player.set_lamp_enabled(false)
	_set_time(10, 9, 36.0)
	var subjects: Array = []
	for case_id: String in clocks:
		subjects.append([clocks[case_id], "%s_%s" % [clocks[case_id].style, case_id]])
	subjects.append([honest[0], "honest_vantry_master"])
	subjects.append([honest[1], "honest_drop_octagon"])
	var only := OS.get_environment("SHOT_ONLY")
	for subject: Array in subjects:
		var clock: Node3D = subject[0]
		if not only.is_empty() and not str(subject[1]).contains(only):
			continue
		var extent := Native.bounds(clock._spec)
		var out := clock.global_transform.basis.z
		var centre := clock.global_transform * extent.get_center()
		var floor_y := floorf((clock.global_position.y + 0.3) / 3.2) * 3.2
		for view: Array in [["room", 2.1], ["close", 0.62]]:
			_look = centre
			_stand = centre + out * float(view[1])
			_stand.y = floor_y + 0.02
			_framing = true
			for i in 40:
				await get_tree().process_frame
			await _shoot("%s/%s_%s.png" % [dir, subject[1], view[0]])
		if clock.has_method("stage_haunt"):
			clock.stage_haunt(2, null)
			for i in 12:
				await get_tree().process_frame
			await _shoot("%s/%s_tell.png" % [dir, subject[1]])
	_framing = false


func _shoot(path: String) -> void:
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 WITNESS CLOCKS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_framing = false
	if _world != null:
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
		_world = null
	get_tree().quit(0 if ok else 1)
