extends Node
## Installed production switches: model clearance, physical ray, circuit and reload.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const State := preload("res://scripts/building/orison_v2_household_state.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("SWITCH MODEL: " + label)

func _ready() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	var path := OS.get_environment("SHOT_DIR")
	if path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(path)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path.path_join(label+".png"))

func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	check(not world.startup_failed, "V2 starts")
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	await get_tree().create_timer(.5).timeout
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/room_lighting.json"))
	var completion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	var shared: Mesh
	for record: Dictionary in source.switches + completion.lighting.switches:
		var plate = world.adapter.resolve(record.id)
		check(plate != null and plate.has_node("SwitchModel"), "model at " + str(record.id))
		if plate == null or not plate.has_node("SwitchModel"): continue
		check(plate._toggle != null, "independent toggle pivot")
		check(plate.find_children("*", "CollisionShape3D", true, false).size() == 1, "original single interaction collision")
		check(plate.find_children("*", "Light3D", true, false).is_empty(), "no extra emitter")
		for mesh: MeshInstance3D in plate.get_node("SwitchModel").find_children("*", "MeshInstance3D", true, false):
			check(mesh.get_active_material(0) != null, "catalogue finish")
			var transform: Transform3D = plate.global_transform.affine_inverse() * mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var at := transform * vertex
					if absf(at.x) > .0801 or absf(at.y) > .1201 or at.z > -.0078 or at.z < -.0751:
						check(false, "mesh outside original plate/collision envelope: " + str(record.id))
						break
			if mesh.name == "MouldedPlate":
				if shared == null: shared = mesh.mesh
				check(shared == mesh.mesh, "shared Blender geometry")
	# Use the authored physical approach, not an assumed wall direction.
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_lighting_probes.json"))
	var probe: Dictionary = probes.rooms[0]
	var plate = world.adapter.resolve(probe.switch)
	var fixture = world.adapter.resolve(probe.fixture)
	var y := 12.8 if probe.level == "F05" else 16.0
	var origin: Vector3 = world.adapter.root.to_global(Vector3(probe.stance[0],y+1.41,probe.stance[1]))
	var ray := PhysicsRayQueryParameters3D.create(origin, plate.global_position, 1, [world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == plate, "real eye ray hits switch")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.near = .02
	camera.fov = 48
	camera.global_position = plate.to_global(Vector3(.16,.075,-.32))
	camera.look_at(plate.global_position)
	camera.make_current()
	world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var light := OmniLight3D.new()
	world.add_child(light)
	light.global_position = plate.to_global(Vector3(-.3,.25,-.4))
	light.omni_range = 1.3
	light.light_energy = .6
	var before: bool = fixture.powered
	check(is_equal_approx(plate._toggle.rotation.x, deg_to_rad(22.0 if before else -22.0)), "initial pose follows restored fixture")
	await capture("switch_initial")
	plate.interact(world.player)
	await get_tree().create_timer(.16).timeout
	check(fixture.powered != before, "real circuit changes")
	check(is_equal_approx(plate._toggle.rotation.x, deg_to_rad(-22.0 if before else 22.0)), "toggle reaches other detent")
	check(RealityState.data[State.KEY].records[probe.fixture].value == fixture.powered, "existing save owner records circuit")
	await capture("switch_thrown")
	# Live load/reset goes through the production state owner and must update pose.
	RealityState.data[State.KEY].records[probe.fixture].value = before
	RealityState.state_changed.emit()
	await get_tree().process_frame
	check(fixture.powered == before and is_equal_approx(plate._toggle.rotation.x, deg_to_rad(22.0 if before else -22.0)), "live restore resets circuit and pose")
	plate.interact(world.player)
	plate.interact(world.player)
	await get_tree().create_timer(.16).timeout
	check(fixture.powered == before and is_equal_approx(plate._toggle.rotation.x, deg_to_rad(22.0 if before else -22.0)), "rapid reversal settles correctly")
	var ref: WeakRef = weakref(plate)
	world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	check(ref.get_ref() == null, "switch and subscriptions retire with world")
	print("SWITCH MODEL: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
