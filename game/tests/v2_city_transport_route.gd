extends "res://tests/v2_city_west_frontage.gd"
## Continuous installed street-to-station access with the actual five-foot body.
## The retained crossing/frontage/door programme runs first in the same world.
var programme_before: Dictionary = {}
var _exploration_samples: Array = []
var _collect_exploration := false
var _previous_exploration_usec := 0
# Independent expected AU soil datums, in the registered building frame.
# These are route assertions, not a runtime terrain/movement authority.
const WESTERN_SOIL_PROFILE := [[20.3,-.02],[24.3,-.03],[28.3,-.06],[32.3,-.11],[92.,-1.0055],[140.,-1.7255],[290.,-3.9755],[330.,-4.2],[365.,-4.6],[390.,-4.8],[395.,-8.],[500.,-8.]]

func _ready() -> void:
	super._ready()
	route_label = "V2 CITY EXTERIOR"

func _process(_delta: float) -> void:
	if not _collect_exploration: return
	var now := Time.get_ticks_usec()
	if _previous_exploration_usec > 0:
		var viewport := get_viewport().get_viewport_rid()
		_exploration_samples.append([(now-_previous_exploration_usec)/1000.,RenderingServer.viewport_get_measured_render_time_cpu(viewport),RenderingServer.viewport_get_measured_render_time_gpu(viewport),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	_previous_exploration_usec = now

func _programme_sources() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://tests/v2_city_transport_route.gd", "res://tests/v2_city_west_frontage.gd", "res://tests/orison_v2_street_crossing_test.gd", "res://tests/orison_v2_vertical_route_test.gd", "res://tests/orison_v2_first_slice_contract_test.gd", "res://tests/fixtures/orison_city_transport.json", "res://assets/props/city_transport.glb", "res://assets/props/city_transport_lod1.glb", "res://assets/props/orison_ground.glb", "res://assets/props/city_foundations.glb", "res://assets/props/city_elevations.glb"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text() if path.get_extension() in ["gd", "json"] else FileAccess.get_sha256(path)
	for path: String in ["res://assets/props/construction_shed.glb","res://assets/props/city_ground_apron.glb","res://assets/props/city_horizon_near.glb","res://assets/props/city_horizon_far.glb"]:
		result[path] = FileAccess.get_sha256(path)
	for path: String in ["res://assets/props/city_streets.glb","res://assets/props/city_streets_lod1.glb","res://tests/fixtures/orison_city_streets.json"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func _run() -> void:
	programme_before = _programme_sources()
	city_observations["programme_sources"] = programme_before
	await super._run()

func _evidence_scope() -> String:
	return "Production controller through open frontage, retained crossing/door hands, native scaffold, both station levels/islands, both new street junctions/sidewalks and a wider street tour. Separate explicit airborne controller fixtures test the450m temporary radius and restored negative control; they are not continuous walking routes. No train service, sleep/bed event, save reconstruction, whole city or artistic acceptance."

func _evidence_file() -> String:
	return "city_exterior_contract.json"

func _city_walk(point: Vector3) -> bool:
	var city := world.get_node("CityShells") as Node3D
	if is_zero_approx(point.z):
		point.z = preload("res://scripts/building/orison_v2_city_streets.gd").surface_height(point.x)
	print("CITY STATION WALK: source target ",point)
	var reached := await _walk(world.adapter.root.to_local(city.to_global(GameBoot.b2g([point.x, point.y, point.z]))))
	print("CITY STATION WALK: reached=",reached," actual world=",player.global_position)
	return reached

func _station_view(label: String, target: Vector3) -> void:
	var city := world.get_node("CityShells") as Node3D
	player.face_world_point(city.to_global(GameBoot.b2g([target.x,target.y,target.z])))
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png")) == OK, "actual standing station capture: " + label)

func _stairs(route: Dictionary, up: bool) -> bool:
	var from: Array = route.from_m
	var to: Array = route.to_m
	var lane := lane_from_route(route)
	var x := float(from[0])
	var y := float(from[1])
	var low := float(from[2])
	var high := float(to[2])
	var count := roundi((high - low) / (2. * float(route.riser_m)))
	var run := count * float(route.tread_m)
	# Land well inside each real landing before reversing direction. The run
	# itself is traversed under continuous controller input, never by teleport.
	var points: Array[Vector3] = [Vector3(x-.5,y,low), Vector3(x+run+.65,y,(low+high)/2.), Vector3(x+run+.65,y+lane,(low+high)/2.), Vector3(x-.5,y+lane,high)]
	if not up: points.reverse()
	for point: Vector3 in points:
		if not await _city_walk(point): return false
	return true

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	# This is a third use of the live leaf, whose closer may leave it partly
	# open. Approach the actual hinge-side contact before grabbing again.
	for point: Vector3 in [Vector3(1.925,0,-6.5),Vector3(0,0,-7.65),Vector3(0,0,-10.2),Vector3(0,0,-10.8)]:
		if not await _walk(point): return
	if not await _open_front_entrance(): return
	if not await _walk(Vector3(0,0,-12.2)): return
	# Exercise the newly constructed block before the longer retained station
	# and distant tours, so a new street obstruction fails without spending
	# those unchanged route legs first.
	await _street_block_tour()
	if not failures.is_empty(): return
	# Walk through the actual reopened scaffold, including the former closure.
	for point: Vector3 in [Vector3(0,0,3),Vector3(14,0,3),Vector3(19.5,0,3),Vector3(24,0,3),Vector3(24,0,-4),Vector3(30,0,-4),Vector3(30,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	await _station_view("plaza_approach",Vector3(65,-10,8))
	for point: Vector3 in [Vector3(40,-12.8,0),Vector3(40,8,0),Vector3(31,8,0),Vector3(31.5,4.2,0)]:
		if not await _city_walk(point): return
	await _station_view("public_entry",Vector3(38,5,4))
	var station := world.get_node("CityShells/EasternPlazaStation") as Node3D
	var checked_materials: Dictionary = {}
	for draw: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false):
		var material := draw.material_override as StandardMaterial3D
		check(material != null and not material.uv1_triplanar, "composed station keeps authored maps: " + str(draw.name))
		if material != null and not checked_materials.has(material.get_instance_id()):
			checked_materials[material.get_instance_id()] = true
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				check(texture != null and texture.get_image().has_mipmaps(), "composed station PBR mip chain")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_transport.json"))
	var routes: Dictionary = {}
	for row: Dictionary in fixture.stair_routes: routes[str(row.id)] = row
	check(routes.size() == 5, "one public entry and four platform stair connections")
	if not await _stairs(routes.PublicEntry, true): return
	var before := trace.size()
	for island in 2:
		var lower: Dictionary = routes["PlatformStair_0_"+str(island)]
		var upper: Dictionary = routes["PlatformStair_1_"+str(island)]
		var base: Array = lower.from_m
		for point: Vector3 in [Vector3(30.8,5.75,6.2),Vector3(30.8,float(base[1]),6.2)]:
			if not await _city_walk(point): return
		if not await _stairs(lower, true): return
		await _station_view("lower_platform_"+str(island),Vector3(86,float(lower.to_m[1]),float(lower.to_m[2])+1))
		var upper_base: Array = upper.from_m
		var bypass := float(base[1]) - 1.8
		var lower_top := float(lower.to_m[2])
		var upper_top := float(upper.to_m[2])
		for point: Vector3 in [Vector3(31.5,bypass,lower_top),Vector3(50,bypass,lower_top),Vector3(61.5,bypass,lower_top),Vector3(61.5,float(upper_base[1]),lower_top)]:
			if not await _city_walk(point): return
		if not await _stairs(upper, true): return
		await _station_view("upper_platform_"+str(island),Vector3(90,float(upper.to_m[1]),float(upper.to_m[2])+1))
		var end: Array = upper.to_m
		if not await _city_walk(Vector3(55,float(end[1]),upper_top)): return
		if not await _stairs(upper, false): return
		for point: Vector3 in [Vector3(61.5,bypass,lower_top),Vector3(50,bypass,lower_top),Vector3(31.5,bypass,lower_top),Vector3(31.5,float(base[1])+lane_from_route(lower),lower_top)]:
			if not await _city_walk(point): return
		if not await _stairs(lower, false): return
	if not await _city_walk(Vector3(30.8,5.75,6.2)): return
	if not await _stairs(routes.PublicEntry, false): return
	for point: Vector3 in [Vector3(31,8,0),Vector3(40,8,0),Vector3(40,-12.8,0)]:
		if not await _city_walk(point): return
	for point: Vector3 in [Vector3(30,0,3),Vector3(24,0,3),Vector3(19.5,0,3),Vector3(14,0,3),Vector3(0,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	city_observations["station_route"] = {"completed":true,"platform_connections":4,"waypoints":trace.size()-before}
	await _wide_street_tour()
	if not failures.is_empty(): return
	await _radius_controller_fixtures()
	check(not player.noclip and not player.crouched and is_equal_approx(player.STANDING_HEIGHT,1.524), "actual standing production body remained active")
	check(programme_before == _programme_sources(), "executed route sources and physical station/ground bodies remain frozen")

func lane_from_route(route: Dictionary) -> float:
	return float(route.to_m[1]) - float(route.from_m[1])

func _street_block_tour() -> void:
	var start := trace.size()
	var recoveries_before := world.safety_net.recoveries
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for point: Vector3 in [Vector3(0,-13,0),Vector3(-55,-13,0),Vector3(-76,-13,0),Vector3(-75.4,24,0),Vector3(-63.8,24,0),Vector3(-63.8,-13,0),Vector3(-55,-13,0),Vector3(0,-13,0),Vector3(40,-13,0),Vector3(64.3,-13,0),Vector3(64.3,24,0),Vector3(74.6,24,0),Vector3(74.6,8,0),Vector3(80,8,0),Vector3(80,-13,0),Vector3(110,-13,0),Vector3(110,-26.5,0),Vector3(80,-26.5,0),Vector3(68.8,-35,0),Vector3(64.3,-35,0),Vector3(64.3,-26.5,0),Vector3(40,-26.5,0),Vector3(20,-26.5,0),Vector3(20,-24.5,0),Vector3(-2,-24.5,0),Vector3(-2,-26.5,0),Vector3(-40,-26.5,0),Vector3(-70,-26.5,0),Vector3(-70,-35,0),Vector3(-75.4,-35,0),Vector3(-75.4,-26.5,0),Vector3(-85,-26.5,0),Vector3(-85,-13,0),Vector3(-55,-13,0),Vector3(0,-13,0)]:
		_previous_exploration_usec = 0
		_collect_exploration = true
		var reached := await _city_walk(point)
		_collect_exploration = false
		if not reached: break
		if point == Vector3(-76,-13,0): await _station_view("street_west_junction",Vector3(-68,-22,1))
		if point == Vector3(64.3,24,0): await _station_view("street_east_narrow_walk",Vector3(66,-13,1))
		if point == Vector3(80,-26.5,0): await _station_view("street_pier_islands",Vector3(73,-27.45,1))
	check(world.safety_net.recoveries == recoveries_before,"new street block walking uses actual floors without rescue")
	city_observations["street_block"] = {"waypoints":trace.size()-start,"samples":_exploration_samples.duplicate(),"scope":"Actual controller through both junctions, north/south street walks, both cross-street ends and east1.62m pinch; unchanged live traffic. Captures excluded from timings. No matched before/after speed claim."}
	_exploration_samples.clear()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)

func _wide_street_tour() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var start := trace.size()
	var recoveries_before := world.safety_net.recoveries
	# Physical blocks occupy the old straight sightline at150m. Follow the
	# genuine north street gap around them rather than removing city buildings.
	for point: Vector3 in [Vector3(-30,0,3),Vector3(-80,0,3),Vector3(-140,0,3),Vector3(-140,0,-10),Vector3(-226,0,-2),Vector3(-250,0,36),Vector3(-252,0,38),Vector3(-272,0,38),Vector3(-274,0,36),Vector3(-280,0,-10),Vector3(-274,0,36),Vector3(-272,0,38),Vector3(-252,0,38),Vector3(-250,0,36),Vector3(-226,0,-2),Vector3(-140,0,-10),Vector3(-140,0,3),Vector3(0,0,3),Vector3(60,0,3),Vector3(140,0,3),Vector3(140,0,-10),Vector3(226,0,-2),Vector3(250,0,36),Vector3(252,0,38),Vector3(272,0,38),Vector3(274,0,36),Vector3(280,0,-10),Vector3(274,0,36),Vector3(272,0,38),Vector3(252,0,38),Vector3(250,0,36),Vector3(226,0,-2),Vector3(140,0,-10),Vector3(140,0,3),Vector3(60,0,3),Vector3(0,0,3)]:
		_previous_exploration_usec = 0
		_collect_exploration = true
		print("CITY EXTERIOR TOUR: target ",point)
		var local_target: Vector3 = world.adapter.root.to_local(point)
		local_target.y = _expected_western_soil_height(local_target.x)
		var reached := await _walk(local_target)
		_collect_exploration = false
		if not reached: break
		if point.x in [-280.,280.]:
			player.face_world_point(Vector3(0,8,0))
			await get_tree().create_timer(.25).timeout
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("street_%d.png"%int(point.x))) == OK,"actual wider street view")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
	check(world.safety_net.recoveries == recoveries_before,"wide real-floor walk is not limited by safety-net rescue")
	city_observations["wider_street"] = {"waypoints":trace.size()-start,"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"samples":_exploration_samples,"scope":"Normal controller walking to280m east and west, using existing street gaps around physical blocks. Captures excluded; live NPC/traffic uncontrolled; counters are global and GPU timers cover the main viewport. No matched before/after speed claim."}

func _expected_western_soil_height(x: float) -> float:
	if x <= float(WESTERN_SOIL_PROFILE[0][0]): return -.02
	for i in WESTERN_SOIL_PROFILE.size()-1:
		var a: Array = WESTERN_SOIL_PROFILE[i]
		var b: Array = WESTERN_SOIL_PROFILE[i+1]
		if x <= float(b[0]):
			return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
	return float(WESTERN_SOIL_PROFILE[-1][1])

func _radius_controller_fixtures() -> void:
	var boundary := world.get_node("StreetBoundaries") as Node3D
	var limit := boundary.get_node("TemporaryExteriorLimit") as StaticBody3D
	var radius := float(limit.get_meta("radius_m"))
	var prior := player.global_transform
	var prior_camera := player.camera.rotation
	var prior_layer := limit.collision_layer
	var recoveries_before := world.safety_net.recoveries
	var results: Array = []
	# Explicit component fixtures above occupied stock. Gravity and the actual
	# standing controller stay active; no floor, noclip or reach exemption is added.
	for angle: float in [0.,.71,PI/2,PI,3*PI/2]:
		var local_direction := Vector3(cos(angle),0,sin(angle))
		var direction := boundary.global_basis*local_direction
		player.global_position = boundary.to_global(local_direction*(radius-1.)+Vector3.UP*150.)
		player.velocity = Vector3.ZERO
		player.face_world_point(player.global_position+direction*10.)
		var touched := false
		var maximum := 0.
		Input.action_press("move_forward")
		for frame in 90:
			await get_tree().physics_frame
			var local := boundary.to_local(player.global_position)
			maximum = maxf(maximum,Vector2(local.x,local.z).length())
			for index in player.get_slide_collision_count(): touched = touched or player.get_slide_collision(index).get_collider() == limit
		Input.action_release("move_forward")
		check(touched and maximum <= radius+.01 and maximum > radius-.6 and not player.noclip,"normal controller cannot cross the distant radial wall")
		results.append({"angle":angle,"maximum_center_distance_m":maximum,"touched_limit":touched})
	limit.collision_layer = 0
	await get_tree().physics_frame
	player.global_position = boundary.to_global(Vector3(radius-1.,150,0))
	player.velocity = Vector3.ZERO
	player.face_world_point(player.global_position+boundary.global_basis.x*10.)
	Input.action_press("move_forward")
	for frame in 90: await get_tree().physics_frame
	Input.action_release("move_forward")
	var outside := boundary.to_local(player.global_position)
	var control_distance := Vector2(outside.x,outside.z).length()
	check(control_distance > radius+1.,"disabling only the temporary wall admits the same controller beyond the limit")
	limit.collision_layer = prior_layer
	player.global_transform = prior
	player.camera.rotation = prior_camera
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(limit.collision_layer == prior_layer,"negative control restores the exact temporary boundary")
	check(world.safety_net.recoveries == recoveries_before,"registered exterior reaches the radius without safety-net travel teleports")
	var zones_before: Array[AABB] = world.safety_net.exempt_zones.duplicate()
	var exterior_zone: AABB = boundary._exterior_ground_zone
	boundary._unregister_exterior_ground()
	check(not world.safety_net.exempt_zones.has(exterior_zone) and world.safety_net.exempt_zones.size() == zones_before.size()-1,"city owner cleanup removes only its safety-net footprint")
	boundary._register_exterior_ground()
	boundary._register_exterior_ground()
	var restored := world.safety_net.exempt_zones.size() == zones_before.size()
	for zone: AABB in zones_before: restored = restored and world.safety_net.exempt_zones.has(zone)
	check(restored,"registration restores original safety exemptions without duplicate ownership")
	city_observations["radius_limit"] = {"radius_m":radius,"fixtures":results,"disabled_control_distance_m":control_distance,"scope":"Explicit airborne controller fixtures at150m, not continuous city walks or roof access. Exact original pose and boundary layer restored."}
