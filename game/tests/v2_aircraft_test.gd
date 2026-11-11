extends Node
## The airmail aircraft over V2 (v1r_period_layer_20261109, the aircraft
## only): V1's seeded 7-to-13-minute schedule, its 18-second pass with arc and
## heading, its refusal to fly a pass the weather hides, and its radial, on a
## Blender-built Mailwing high over V2's city. With SHOT_DIR set (windowed),
## also photographs a pass.
const Aircraft := preload("res://scripts/building/orison_v2_aircraft.gd")

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
	var blockout: Node3D = _world.get("_blockout")
	var node: Node = _world.get_node_or_null("PeriodAircraft")
	var fresh := node == null
	if fresh:
		node = Aircraft.mount(_world, blockout, _world.layout, _world.adapter)
	_check(node.errors.is_empty(), "the mount reports no errors: %s" % [node.errors])
	_check(node.get_script() == Aircraft and node is PeriodRealityLayer, "the V2 aircraft is V1's period layer, extended")
	if not node.errors.is_empty():
		_finish()
		return
	# V1's schedule: the first wait is the first draw of V1's seed.
	var reference := RandomNumberGenerator.new()
	reference.seed = 19280501
	var first := reference.randf_range(Aircraft.AIR_PASS_MIN, Aircraft.AIR_PASS_MAX)
	reference.randf_range(Aircraft.TRAIN_MIN, Aircraft.TRAIN_MAX)
	if fresh:
		_check(is_equal_approx(node.seconds_until_pass(), first), "the first pass is due by V1's seeded draw (%.1f s)" % first)
	_check(first >= 420.0 and first <= 780.0, "that is 7 to 13 minutes out")
	# From here the test turns the clock by hand.
	node.set_process(false)
	node.follow_weather = false
	node.set_live_conditions({})
	await _settle(node)
	_world.player.set_physics_process(false)
	_stand = _world.player.global_position
	_look = _stand + Vector3.FORWARD
	_framing = true
	_stock_checks(node)
	await _pass_checks(node, blockout, reference)
	_weather_checks(node)
	if not OS.get_environment("SHOT_DIR").is_empty():
		await _photograph(node)
	_finish()


func _process(_delta: float) -> void:
	if _framing and _world != null and _world.player != null:
		_world.player.global_position = _stand
		_world.player.camera.look_at(_look)


func _settle(_node: Node) -> void:
	var calm := 0
	var last := Time.get_ticks_usec()
	for i in 1800:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		calm = calm + 1 if now - last < 250000 else 0
		last = now
		if calm >= 60:
			return
	_check(false, "the world settles")


func _stock_checks(node: Node) -> void:
	var seen: Dictionary = node.diagnostic_snapshot()
	_check(node.parts.size() == 4 and int(seen.aircraft_draws) == 4, "four draws: body, planes, metal, propeller disc (%d)" % node.parts.size())
	_check(int(seen.aircraft_collision_bodies) == 0 and int(seen.aircraft_shadow) == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and not bool(seen.persistent), "no collision, no shadow, nothing saved, as V1")
	_check(int(seen.audio_streams) == 1 and node.get_node_or_null("DistantRadialEngine") != null
		and node.get_node_or_null("DistantFlushingLine") == null, "V1's radial is carried; V1's distant train is not")
	_check(not node.trigger_train_pass(), "no train pass can be triggered")
	var triangles := 0
	for draw: MeshInstance3D in node.parts:
		var bad: Array[String] = []
		var mesh := draw.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() != 1:
			bad.append("not one authored surface")
		else:
			var arrays := mesh.surface_get_arrays(0)
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if uvs == null or (uvs as PackedVector2Array).is_empty() or arrays[Mesh.ARRAY_TANGENT] == null:
				bad.append("no authored UVs or tangents")
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var finish := draw.material_override as StandardMaterial3D
		if finish == null or finish.albedo_texture == null or finish.roughness_texture == null \
				or finish.normal_texture == null or finish.uv1_triplanar:
			bad.append("not a catalogue finish on its own UVs")
		if draw.visibility_range_end <= 0.0:
			bad.append("no visibility range")
		_check(bad.is_empty(), "%s is Blender stock in a catalogue finish %s" % [draw.name, bad])
	print("  [V2 AIRCRAFT] %d draws, %d triangles during a pass, none between passes" % [node.parts.size(), triangles])
	var span: float = (node.parts[1] as MeshInstance3D).mesh.get_aabb().size.x
	_check(span > 9.5 and span < 10.5, "the upper plane spans a Mailwing's 10 m (%.2f m)" % span)
	_check(node.propeller != null and node.propeller != node.parts[0] and absf(node.propeller.position.z + 3.12) < 0.01
		and absf(node.propeller.position.x) < 0.001 and absf(node.propeller.position.y) < 0.001,
		"the propeller disc is its own part, on the shaft at the nose")


func _pass_checks(node: Node, blockout: Node3D, reference: RandomNumberGenerator) -> void:
	var craft: MeshInstance3D = node.parts[0]
	var track: Vector3 = node.track_finish - node.track_start
	var pace := track.length() / Aircraft.AIR_DURATION
	_check(is_equal_approx(Aircraft.AIR_DURATION, 18.0) and pace > 40.0 and pace < 60.0,
		"a pass is V1's 18 s, at a Mailwing's pace over the enlarged track (%.0f m/s over %.0f m)" % [pace, track.length()])
	_check(not craft.visible and node.pass_progress() < 0.0, "no aircraft before its time")
	var due: float = node.seconds_until_pass()
	node._process(due - 1.0)
	_check(not craft.visible, "none a second early")
	node._process(1.5)
	_check(craft.visible and node.pass_progress() >= 0.0, "the pass begins when V1's wait runs out")
	_check(node.get_node("DistantRadialEngine").playing, "the radial is heard with it")
	_check(craft.global_position.distance_to(node.track_start) < 30.0, "it comes in at the start of the track")
	var lowest := INF
	var nearest := INF
	var spin: Basis = node.propeller.transform.basis
	var turned := false
	var heading_ok := true
	var middle := Vector3.ZERO
	while node.pass_progress() >= 0.0 and node.pass_progress() < 0.999:
		node._process(0.25)
		if not craft.visible:
			break
		var local := blockout.to_local(craft.global_position)
		lowest = minf(lowest, local.y)
		nearest = minf(nearest, craft.global_position.distance_to(_world.player.global_position))
		turned = turned or not spin.is_equal_approx(node.propeller.transform.basis)
		heading_ok = heading_ok and (-craft.global_transform.basis.z).dot(track.normalized()) > 0.999
		if absf(node.pass_progress() - 0.5) < 0.008:
			middle = craft.global_position
	_check(lowest > 150.0, "it stays high over the roofs (lowest %.0f m above the ground floor)" % lowest)
	_check(nearest > 120.0, "and never near the player (nearest %.0f m)" % nearest)
	_check(heading_ok, "nose along the track for the whole pass")
	_check(turned, "the propeller disc turns")
	var chord: Vector3 = node.track_start.lerp(node.track_finish, 0.5)
	_check(middle != Vector3.ZERO and absf((middle.y - chord.y) - 5.0 * node.enlargement) < 1.0 * node.enlargement,
		"V1's arc lifts the middle of the pass (%.1f m, V1's 5 m enlarged %.2f times)" % [middle.y - chord.y, node.enlargement])
	_check(absf(blockout.to_local(middle).x) < 60.0 and absf(blockout.to_local(middle).z) < 60.0,
		"the track crosses over the house, as V1's did")
	_check(not craft.visible and node.pass_progress() < 0.0 and not node.get_node("DistantRadialEngine").playing,
		"after 18 s it is gone and silent")
	var next := reference.randf_range(Aircraft.AIR_PASS_MIN, Aircraft.AIR_PASS_MAX)
	_check(is_equal_approx(node.seconds_until_pass(), next) and next >= 420.0 and next <= 780.0,
		"the next pass is 7 to 13 minutes on, by V1's seed (%.1f s)" % node.seconds_until_pass())


func _weather_checks(node: Node) -> void:
	var craft: MeshInstance3D = node.parts[0]
	node.set_live_conditions({"cloud_low": 1.0, "precipitation_intensity": 4.0})
	_check(not node.start_airmail_pass() and not craft.visible, "no pass is staged under a closed, raining ceiling (V1's rule)")
	node.set_live_conditions({"cloud_low": 0.5, "wind_speed_kmh": 36.0, "wind_direction_degrees": 270.0})
	var seen: Dictionary = node.diagnostic_snapshot()
	_check(is_equal_approx(float(seen.aircraft_contrast), 0.61) and is_equal_approx(node.propeller.transparency, 0.39)
		and is_equal_approx(craft.transparency, 0.39), "half cloud thins every part by V1's contrast (%.2f)" % float(seen.aircraft_contrast))
	_check(float(seen.air_filter_hz) < 14500.0 and (seen.wind_mps as Vector3).length() > 9.9, "cloud muffles the engine; the wind is read")
	_check(node.start_airmail_pass() and craft.visible, "a pass can fly under half cloud")
	_check(not node.start_airmail_pass(), "one aircraft at a time")
	node._process(9.0)
	var drift: Vector3 = craft.global_position - node.track_start.lerp(node.track_finish, 0.5)
	_check(Vector2(drift.x, drift.z).length() > 3.0, "a crosswind carries the middle of the pass off the track (%.1f m)" % Vector2(drift.x, drift.z).length())
	node._process(9.5)
	node.set_live_conditions({})
	_check(not craft.visible and is_zero_approx(craft.transparency), "clear again")


func _photograph(node: Node) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	for layer in _world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	if _world.service_set_carrier != null:
		_world.service_set_carrier.visible = false
	_world.player.set_lamp_enabled(false)
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 10, 13 * 60)
	var craft: MeshInstance3D = node.parts[0]
	node.start_airmail_pass()
	node._process(4.5)
	# From the pavement by the nearest street lamp.
	var clock: Node = get_tree().get_nodes_in_group("v2_street_lamp_clocks")[0]
	var lamp: Vector3 = (clock.lights[0] as OmniLight3D).global_position
	_stand = Vector3(lamp.x, lamp.y - 3.86, lamp.z)
	_look = craft.global_position
	await _shoot(dir + "/aircraft_from_street.png")
	var fov: float = _world.player.camera.fov
	_world.player.camera.fov = 6.0
	await _shoot(dir + "/aircraft_from_street_long_lens.png")
	_world.player.camera.fov = fov
	# Alongside, in the air, to see the surfaces.
	var side := craft.global_transform.basis.x * 14.0 - craft.global_transform.basis.z * 12.0 + Vector3.UP * 2.0
	_stand = craft.global_position + side - Vector3.UP * 1.6
	await _shoot(dir + "/aircraft_alongside.png")
	side = -craft.global_transform.basis.x * 10.0 + craft.global_transform.basis.z * 14.0 - Vector3.UP * 5.0
	_stand = craft.global_position + side - Vector3.UP * 1.6
	await _shoot(dir + "/aircraft_from_below.png")
	node._process(14.0)


func _shoot(path: String) -> void:
	for i in 40:
		await get_tree().process_frame
	for i in 10:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _finish() -> void:
	var ok := _fails == 0
	print("[V2 AIRCRAFT] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	_framing = false
	if _world != null:
		if _world.has_method("shutdown_for_tests"):
			_world.shutdown_for_tests()
		remove_child(_world)
		_world.free()
		_world = null
	get_tree().quit(0 if ok else 1)
