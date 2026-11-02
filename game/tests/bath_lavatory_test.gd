extends Node
## Live V2 fixture: imported pivots, actual control rays and retained water verbs.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var checks := 0
var failures: Array[String] = []
var service_contacts: Array[Dictionary] = []

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

class ValidationAdapter extends RefCounted:
	# The validator only needs resolution here. This stub does not mount a world.
	var anchor := Node3D.new()
	func resolve(_identity: String) -> Node3D: return anchor

func _check_profile_validation() -> void:
	var loader := preload("res://scripts/building/orison_v2_domestic_fittings.gd").new()
	var adapter := ValidationAdapter.new()
	var record := {"id":"TEST_LAVATORY", "kind":"sink", "unit":"4B",
		"properties":{"fixture":"bath_sink", "lavatory_profile":"WallService_2755"}}
	var source := {"schema_version":1, "fittings":[record]}
	check(loader.validate(source, adapter), "surveyed bath profile passes pre-mount validation")
	for invalid: Variant in ["WallService_9999", "", 2755, null]:
		record.properties.lavatory_profile = invalid
		check(not loader.validate(source, adapter), "unsupported profile rejected before mounting: " + str(invalid))
	record.properties.erase("lavatory_profile")
	check(not loader.validate(source, adapter), "V2 bath requires its surveyed service selection")
	record.properties.fixture = "kitchen_sink"
	check(loader.validate(source, adapter), "ordinary kitchen sink needs no lavatory profile")
	record.properties.lavatory_profile = "WallService_2755"
	check(not loader.validate(source, adapter), "lavatory profile rejected on kitchen subtype")
	adapter.anchor.free()

func _check_service_models() -> void:
	_check_profile_validation()
	# Check the imported selector before static batching destroys source names.
	# Each alternative is real geometry; hiding five sets would still retain cost.
	var sink_script := preload("res://scripts/building/orison_v2_kitchen_sink.gd")
	for profile: String in ["WallService_2555", "WallService_2755", "WallService_2855",
			"WallService_2955", "WallService_3455", "WallService_4455"]:
		var owner := sink_script.new()
		owner.lavatory_profile = profile
		var model: Node3D = owner._bath_lavatory_model()
		check(model != null, "imported fitted model selects " + profile)
		if model != null:
			var groups: Array[Node3D] = []
			for node: Node3D in model.find_children("WallService_*", "Node3D", true, false):
				if not node is MeshInstance3D: groups.append(node)
			check(groups.size() == 1 and str(groups[0].name) == profile,
					"only selected service geometry remains: " + profile)
			if groups.size() == 1:
				var triangles := 0
				for draw: MeshInstance3D in groups[0].find_children("*", "MeshInstance3D", true, false):
					for surface in draw.mesh.get_surface_count():
						var arrays := draw.mesh.surface_get_arrays(surface)
						var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
						var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
						var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
						var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
						triangles += indices.size() / 3
						check(uv.size() == vertices.size() and tangents.size() == vertices.size()*4,
								"import retains service UV and tangent arrays: " + profile)
				check(triangles == 4128, "selected services retain 4128 source triangles: " + profile)
			model.free()
		owner.free()
	var legacy := TapProp.new()
	var old_model: Node3D = legacy._bath_lavatory_model()
	check(old_model != null and old_model.find_child("WallService_*", true, false) == null,
			"base TapProp retains the separate V1 lavatory")
	if old_model != null: old_model.free()
	legacy.free()

func _check_service_contacts(world: OrisonV2RuntimeRoot, sink: TapProp) -> void:
	var profile := str(sink.get("lavatory_profile"))
	var face := float(profile.trim_prefix("WallService_"))/10000.0
	var skin: float = preload("res://scripts/building/orison_v2_bathroom_finishes.gd").SKIN
	var excluded: Array[RID] = [world.player.get_rid()]
	for body: CollisionObject3D in sink.find_children("*", "CollisionObject3D", true, false):
		excluded.append(body.get_rid())
	for port: Vector3 in [Vector3(-.09,.30,face),Vector3(.09,.30,face),Vector3(0,.55,face)]:
		var ray := PhysicsRayQueryParameters3D.create(sink.to_global(port-Vector3.BACK*.04),
				sink.to_global(port+Vector3.BACK*.06),1,excluded)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		var row := {"sink":str(sink.name),"profile":profile,"port":[port.x,port.y,port.z],"missing":hit.is_empty()}
		if not hit.is_empty():
			var local: Vector3 = sink.to_local(hit.position)
			row["hit"] = [local.x,local.y,local.z]
			row["collider"] = str(hit.collider.get_path())
			row["bare_wall_error_m"] = absf(local.z-face-skin)
		service_contacts.append(row)
		check(not hit.is_empty() and float(row.get("bare_wall_error_m",INF)) < .0002,
				"installed wall meets service seat plus finish skin: " + str(row))

func _played_lavatory(world: OrisonV2RuntimeRoot, sink: TapProp) -> void:
	var player: PlayerController = world.player
	check(not player.protected_input_active() and player.text_input_owner == null,
			"installed lavatory route starts without protected input ownership")
	if player.protected_input_active() or player.text_input_owner != null: return
	var original_pose := player.global_transform
	var original_view := player.camera.global_transform
	var original_physics := player.is_physics_processing()
	var original_mouse := Input.mouse_mode
	var initial := sink.mechanism_snapshot()
	var stance := sink.to_global(Vector3(0,.025,-.85))
	var floor_ray := PhysicsRayQueryParameters3D.create(stance+Vector3.UP*.03,
			stance-Vector3.UP*.08,1,[player.get_rid()])
	var support := world.get_world_3d().direct_space_state.intersect_ray(floor_ray)
	check(not support.is_empty() and support.normal.y > .99, "test-only sink stance has actual floor support")
	if support.is_empty() or support.normal.y <= .99: return
	stance.y = support.position.y+.025
	var capsule := PhysicsShapeQueryParameters3D.new()
	capsule.shape = player._capsule
	capsule.transform = Transform3D(player.global_basis,stance)*player._shape.transform
	capsule.exclude = [player.get_rid()]
	var blockers := world.get_world_3d().direct_space_state.intersect_shape(capsule,4)
	check(blockers.is_empty(), "installed lavatory approach clears full standing capsule: " + str(blockers))
	if not blockers.is_empty(): return
	player.cancel_manipulation();player.set_physics_process(false)
	player.global_position = stance;player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hand := preload("res://tests/fixed_gesture_patrol_hand.gd").new()
	add_child(hand);hand.player = player
	for index in 2:
		var point: Vector3 = sink._handles[index].to_global(Vector3(.025,0,-.04))
		check(await hand.operate(point,PI*.5*(.31 if index == 0 else .64),sink),
				"actual mouse acquires, turns and releases installed lavatory valve " + str(index))
	check(is_equal_approx(sink._valve_openings.x,.31) and is_equal_approx(sink._valve_openings.y,.64),
			"installed lavatory retains two independent released partial openings")
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(), "campaign reload fixture has an isolated external output directory")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var original_path: String = RealityState.save_path
		RealityState.save_path = directory.path_join("installed_lavatory_campaign.json")
		world.household_state.capture_now()
		var wrote := RealityState.save_game()
		check(wrote, "installed lavatory writes through validated campaign save owner")
		if wrote:
			sink.set_hot(false);sink.set_cold(false)
			RealityState.load_game()
			check(RealityState.can_continue(), "validated lavatory campaign reload remains continuable")
			check(is_equal_approx(sink._valve_openings.x,.31) and is_equal_approx(sink._valve_openings.y,.64),
					"campaign reload restores installed partial hot and cold settings")
			check(not player._grab.active() and sink._held_valve == -1, "reload has no stale lavatory hand ownership")
		RealityState.save_path = original_path
	player.cancel_manipulation();sink.restore_mechanism(initial)
	world.household_state.capture_now();hand.free()
	player.global_transform = original_pose;player.camera.global_transform = original_view
	player.set_physics_process(original_physics);Input.mouse_mode = original_mouse

func run() -> void:
	_check_service_models()
	if OS.get_environment("ORISON_LAVATORY_MODELS_ONLY") == "1":
		print("LAVATORY IMPORT SELECTOR: %d checks, %d failures; no composed world or interaction claimed" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	var deadline := Time.get_ticks_msec()+600000
	while world.startup_ms <= 0 and not world.startup_failed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not world.startup_failed and world.startup_ms > 0, "production V2 finishes startup")
	if world.startup_failed or world.startup_ms <= 0:
		_finish(world)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
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
	var checked_textures: Dictionary = {}
	for tap in sinks:
		check(tap._bath_plug != null and tap._bath_chain != null,
				"complete plug and chain at " + str(tap.name))
		check(tap._handles.size() == 2 and tap._handles[0].get_parent() == tap,
				"independent valve pivots at " + str(tap.name))
		_check_service_contacts(world,tap)
		check(not str(tap.get("lavatory_profile")).is_empty(), "installed sink has a surveyed service profile: " + str(tap.name))
		for handle: Node3D in tap._handles:
			for draw: MeshInstance3D in handle.find_children("*", "MeshInstance3D", true, false):
				for surface in draw.mesh.get_surface_count():
					var material := draw.get_active_material(surface) as StandardMaterial3D
					check(material != null and not material.uv1_triplanar and not MatLib.is_shared_material(material),
							"post-batch valve samples private native UV finish: " + str(tap.name))
					if material == null: continue
					check(material.normal_enabled, "native lavatory finish keeps calibrated normal sampling")
					for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
						check(texture != null, "native lavatory finish retains every PBR texture")
						if texture == null or checked_textures.has(texture.get_instance_id()): continue
						checked_textures[texture.get_instance_id()] = true
						var image := texture.get_image()
						check(image != null and image.has_mipmaps() and image.get_mipmap_count() == int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.0))),
								"loaded lavatory PBR texture retains the full mip chain")
		if tap.unit == "4B": sample = tap
	check(sample != null, "player lavatory exists")
	if sample != null:
		await _played_lavatory(world,sample)
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
	if OS.get_environment("ORISON_LAVATORY_ONLY") == "1":
		_finish(world)
		return
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
		for height: float in [.5,.65,.95]:
			for side: int in [-1,1]:
				var origin := wc.to_global(Vector3(0,height,-.13))
				var clearance := PhysicsRayQueryParameters3D.create(origin,origin+wc.global_basis.x*side*.64,1)
				clearance.exclude = [wc.get_rid(),world.player.get_rid()]
				check(world.get_world_3d().direct_space_state.intersect_ray(clearance).is_empty(),
					"4B toilet has 64 cm centerline side clearance at height %s, side %s" % [height,side])
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
				var pose:=Transform3D(Basis(Vector3.UP,float(record.yaw)),Vector3(record.position[0],record.position[1],record.position[2]))
				var low:=Vector3(record.bounds[0][0],record.bounds[0][1],record.bounds[0][2])
				var high:=Vector3(record.bounds[1][0],record.bounds[1][1],record.bounds[1][2])
				var fitted:=pose*AABB(low,high-low)
				check(fitted.end.x<-.27 and fitted.position.y>.45,
						"paper stays outside seat opening and knee space: " + str(record.id))
		camera.global_position = wc.to_global(Vector3(0,1.02,-.12))
		camera.look_at(paper.to_global(Vector3(0,-.04,-.075)))
		await capture("paper_from_seat")
		camera.queue_free()
	_finish(world)

func _finish(world: OrisonV2RuntimeRoot) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("lavatory.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"service_contacts":service_contacts,"scope":"lavatory_only" if OS.get_environment("ORISON_LAVATORY_ONLY")=="1" else "full_bathroom"},"\t"))
	world.shutdown_for_tests()
	world.free()
	print("LAVATORY: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _mesh_bounds(root: Node3D,part: MeshInstance3D) -> AABB:
	return (root.global_transform.affine_inverse()*part.global_transform)*part.mesh.get_aabb()
