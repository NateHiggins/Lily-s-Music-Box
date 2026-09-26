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
		camera.global_position = sample.to_global(Vector3(.55,.58,-.50))
		camera.look_at(sample.to_global(Vector3(0,.55,.07)))
		await capture("exposed_plumbing")
		light.queue_free()
		camera.queue_free()
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("lavatory.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.shutdown_for_tests()
	world.free()
	print("LAVATORY: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
