extends Node
## Live V2 fixture: imported pivots, actual control rays and retained water verbs.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("LAVATORY: " + label)

func _ready() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().create_timer(.5).timeout
	check(not world.startup_failed, "production V2 starts")
	# Exercise the existing apartment suite's complete bath contract directly;
	# its unrelated historic wall/heating cardinality checks remain untouched.
	var category := preload("res://tests/orison_v2_apartment_batch_test.gd").new()
	var refs: Array[WeakRef] = []
	category._check_bath_details(world, refs)
	checks += category.checks
	for failure in category.failures: failures.append("bath contract: " + failure)
	category.free()
	var sinks: Array[TapProp] = []
	for tap in world.boiler_tend.taps:
		if tap.fixture == "bath_sink": sinks.append(tap)
	var expected: Array[String] = []
	for path in ["res://data/orison_v2/domestic_fittings.json", "res://data/orison_v2/completion_interiors.json"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for fitting: Dictionary in source.fittings:
			if fitting.properties.get("fixture") == "bath_sink": expected.append(fitting.id)
	check(sinks.size() == expected.size(), "bathroom model deployed throughout V2 roster")
	for identity in expected:
		check(world.adapter.resolve(identity) in sinks, "live model at " + identity)
	var sample: TapProp
	for tap in sinks:
		check(tap._bath_plug != null and tap._bath_chain != null,
				"complete plug and chain at " + str(tap.name))
		check(tap._handles.size() == 2 and tap._handles[0].get_parent() == tap,
				"independent valve pivots at " + str(tap.name))
		if tap.unit == "4B": sample = tap
	check(sample != null, "player lavatory exists")
	if sample != null:
		sample.set_process(false)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 55
		camera.global_position = sample.to_global(Vector3(.45,1.38,-.95))
		camera.look_at(sample.to_global(Vector3(0,.70,0)))
		camera.make_current()
		world.player.set_lamp_enabled(false)
		for child in world.player.carried_device.get_children():
			if child is CanvasLayer: child.hide()
		# Local neutral inspection light supplements the actual installed room.
		var light := OmniLight3D.new()
		world.add_child(light)
		light.global_position = sample.to_global(Vector3(-.45,1.4,-.7))
		light.omni_range = 2.5
		light.light_energy = .65
		await get_tree().create_timer(.3).timeout
		await capture("installed_lavatory")
		for index in 2:
			var control := sample.get_node("HotValveControl" if index == 0 else "ColdValveControl") as Area3D
			var origin := sample.to_global(Vector3(0,1.35,-.8))
			var ray := PhysicsRayQueryParameters3D.create(origin, control.global_position)
			ray.collide_with_areas = true
			ray.exclude = [world.player.get_rid()]
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(hit.get("collider") == control, "physical reach to " + str(control.name))
			control.interact(null)
			sample._process(.4)
			check(absf(sample._handles[index].rotation.z) > 1.5,
					"Blender cross rotates with valve " + str(index))
		sample.set_stopper(true)
		sample._process(4.0)
		check(sample._bath_plug.position.distance_to(Vector3(0,.696,-.02)) < .001,
				"rubber stopper seats in real drain throat")
		check(sample.get_flow_state().water_level > .29, "closed plug retains flowing water")
		await capture("water_and_seated_plug")
		sample.set_hot(false)
		sample.set_cold(false)
		sample.set_stopper(false)
		sample._process(4.0)
		check(sample.get_flow_state().water_level == 0, "open waste empties basin")
		check(sample._bath_plug.position.x > .10, "open plug visibly clears throat")
		check(sample._bath_chain_instances.get_instance_transform(0).origin.distance_to(
				sample._bath_plug.position+Vector3(0,.018,0)) < .001, "chain follows plug eye")
		check(sample._bath_chain_instances.get_instance_transform(
				sample._bath_chain_instances.instance_count-1).origin.distance_to(
				Vector3(.04,.898,.082)) < .001, "chain ends at faucet attachment eye")
		camera.global_position = sample.to_global(Vector3(.55,.58,-.50))
		camera.look_at(sample.to_global(Vector3(0,.55,.07)))
		await capture("exposed_plumbing")
		light.queue_free()
		camera.queue_free()
	var shower: TapProp
	for tap in world.boiler_tend.taps:
		if tap.fixture == "shower" and tap.unit == "4B": shower = tap
	check(shower != null, "player shower exists")
	if shower != null:
		check(shower.find_child("ShowerCasting", true, false) != null, "Blender shower casting installed")
		var rim := shower.find_child("ShowerCasting_enamel",true,false) as MeshInstance3D
		check(rim != null,"imported receptor enamel available for clearance measurement")
		if rim != null:
			var rim_bounds := _mesh_bounds(shower,rim)
			for curtain: Node3D in [shower._curtain_closed,shower._curtain_gathered]:
				var lowest := INF
				for part: MeshInstance3D in curtain.find_children("*","MeshInstance3D",true,false):
					lowest = minf(lowest,_mesh_bounds(shower,part).position.y)
				check(is_finite(lowest) and lowest-rim_bounds.end.y>=.024,
					str(curtain.name)+" imported hem clears actual basin rim by at least 24 mm")
				check(lowest<.17,str(curtain.name)+" remains a full-length shower curtain")
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 90
		camera.global_position = shower.to_global(Vector3(-.35,1.10,-1.2))
		camera.look_at(shower.to_global(Vector3(0,1.05,0)))
		camera.make_current()
		shower.set_curtain_open(false)
		await get_tree().create_timer(.2).timeout
		await capture("shower_drawn")
		shower.set_curtain_open(true)
		check(shower._curtain_gathered.visible and not shower._curtain_closed.visible, "Blender curtain opens through existing owner")
		var curtain_shape := shower._curtain_area.get_node("CollisionShape3D") as CollisionShape3D
		check(curtain_shape.position.distance_to(Vector3(.34,1.18,.23)) < .001,
				"curtain interaction follows its gathered mesh")
		await capture("shower_open")
		var hem_light := OmniLight3D.new()
		world.add_child(hem_light)
		hem_light.global_position = shower.to_global(Vector3(-.45,.6,-.6))
		hem_light.omni_range = 2
		hem_light.light_energy = .65
		camera.global_position = shower.to_global(Vector3(-.55,.36,-.85))
		camera.look_at(shower.to_global(Vector3(0,.16,0)))
		shower.set_curtain_open(false)
		await capture("shower_hem_drawn")
		shower.set_curtain_open(true)
		await capture("shower_hem_gathered")
		hem_light.queue_free()
		camera.fov = 60
		camera.global_position = shower.to_global(Vector3(-.18,1.72,-.42))
		camera.look_at(shower.to_global(Vector3(0,1.84,.23)))
		await capture("shower_head")
		for node in get_tree().get_nodes_in_group("planar_mirror_surface"):
			var cabinet := node.get_parent().get_parent() as MedicineCabinetProp
			if cabinet == null or cabinet.unit != "4B": continue
			world.mirror_renderer._main_camera = camera
			camera.global_position = cabinet.to_global(Vector3(.12,1.5,-.9))
			camera.look_at(cabinet.mirror_center())
			await get_tree().create_timer(.3).timeout
			check(world.mirror_renderer.active_mirror() == cabinet, "installed mirror borrows one live view")
			await capture("installed_mirror")
		world.mirror_renderer._main_camera = world.player.camera
		camera.queue_free()
	var wc: BakedFurnitureInteraction
	for node in get_tree().get_nodes_in_group("baked_furniture_interactions"):
		if node.furniture_kind == "toilet" and node.owner_unit == "4B": wc = node
	check(wc != null, "player water closet retains flush owner")
	if wc != null:
		check(wc.find_child("WaterClosetCasting", true, false) != null, "Blender toilet installed")
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 65
		camera.global_position = wc.to_global(Vector3(-.65,1.15,-.9))
		camera.look_at(wc.to_global(Vector3(0,.47,0)))
		camera.make_current()
		await capture("toilet_approach")
		var query := PhysicsRayQueryParameters3D.create(camera.global_position,wc._lever.global_position)
		query.exclude = [world.player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(hit.get("collider") == wc, "physical approach reaches toilet flush owner")
		wc.interact(world.player)
		wc._flush_tween.pause()
		wc._flush_tween.custom_step(.08)
		check(wc._refilling and absf(wc._lever.rotation.z) > .3, "Blender lever actuates production flush")
		wc._flush_tween.play()
		await get_tree().create_timer(2.6).timeout
		check(not wc._refilling and absf(wc._lever.rotation.z) < .01, "existing refill completes and returns handle")
		var paper := wc.find_child("4B_toilet_roll", true, false)
		check(paper != null, "paper holder remains attached to its toilet support")
		var detail_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://data/orison_v2/bath_details.json"))
		for record: Dictionary in detail_data.props:
			if record.kind == "toilet_roll":
				check(float(record.bounds[1][0]) < -.21 and float(record.bounds[0][2]) > .14,
						"paper stays outside seat opening and knee space: " + str(record.id))
		camera.global_position = wc.to_global(Vector3(0,1.02,-.12))
		camera.look_at(wc.to_global(Vector3(-.305,.625,.235)))
		await capture("paper_from_seat")
		camera.queue_free()
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("lavatory.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.shutdown_for_tests()
	world.free()
	print("LAVATORY: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _mesh_bounds(root: Node3D,part: MeshInstance3D) -> AABB:
	return (root.global_transform.affine_inverse()*part.global_transform)*part.mesh.get_aabb()
