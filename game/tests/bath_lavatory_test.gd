extends Node
## Live V2 fixture: imported pivots, actual control rays and retained water verbs.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var checks := 0
var failures: Array[String] = []
var service_contacts: Array[Dictionary] = []
var loaded_finishes: Array[Dictionary] = []
var bath_recipes: Dictionary = {}
var reconstruction_save := ""
var reconstruction_plug := Vector3.ZERO
var reconstruction_executed := false
var closet_contacts: Array[Dictionary] = []

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

func _check_loaded_finish(material: Material, identity: String, checked: Dictionary) -> void:
	check(material != null and not MatLib.is_shared_material(material), "native finish is private: " + identity)
	if material == null: return
	var finish := str(material.get_meta("v2_owner_finish", ""))
	var key := finish.get_slice("/",1)
	var recipe: Dictionary = bath_recipes.get(key,{})
	check(finish.begins_with("bath/") and not recipe.is_empty(), "installed bath finish retains its registered owner profile: " + identity)
	if recipe.is_empty(): return
	var expected := MatLib.get_mat(str(recipe.get("catalog",key)))
	var maps: Array = []
	var scale: Variant
	if material is StandardMaterial3D:
		check(not material.uv1_triplanar and not material.uv2_triplanar and material.normal_enabled, "standard finish uses native UV and normal sampling")
		check(is_equal_approx(material.normal_scale,float(recipe.normal)) and is_equal_approx(material.roughness,float(recipe.roughness)) and is_equal_approx(material.metallic,float(recipe.metallic)), "standard finish preserves owner calibration")
		scale = Vector2(material.uv1_scale.x,material.uv1_scale.y)
		maps = [material.albedo_texture,material.roughness_texture,material.normal_texture]
	elif material is ShaderMaterial:
		check(material.shader != null and material.shader.resource_path == "res://shaders/orison_surface.gdshader", "layered finish uses the actual owner surface shader")
		check(int(material.get_shader_parameter("uv_mode")) == 0 and material.get_shader_parameter("has_normal_tex") == true and material.get_shader_parameter("has_rough_tex") == true, "layered finish uses native UV and complete normal/rough sampling")
		check(is_equal_approx(float(material.get_shader_parameter("normal_scale")),float(recipe.normal)) and is_equal_approx(float(material.get_shader_parameter("roughness_mul")),float(recipe.roughness)) and is_equal_approx(float(material.get_shader_parameter("metallic")),float(recipe.metallic)), "layered finish preserves owner calibration")
		scale = material.get_shader_parameter("mesh_uv_scale")
		maps = [material.get_shader_parameter("albedo_tex"),material.get_shader_parameter("rough_tex"),material.get_shader_parameter("normal_tex")]
	else:
		check(false,"unsupported native finish type: " + material.get_class())
		return
	check(scale is Vector2 and scale.is_equal_approx(Vector2(expected.uv1_scale.x,expected.uv1_scale.y)), "native finish keeps catalogue metric UV scale")
	var expected_maps := [expected.albedo_texture,expected.roughness_texture,expected.normal_texture]
	for index in 3:
		var texture := maps[index] as Texture2D
		check(texture != null and texture == expected_maps[index], "native finish retains exact catalogue PBR texture " + str(index))
		if texture == null or checked.has(texture.get_instance_id()): continue
		checked[texture.get_instance_id()] = true
		var image := texture.get_image()
		check(image != null and image.has_mipmaps() and image.get_mipmap_count() == int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.0))), "loaded native PBR texture retains full mip chain")
	loaded_finishes.append({"owner":identity,"class":material.get_class(),"profile":finish,"uv_scale":[scale.x,scale.y] if scale is Vector2 else [],"shader":material.shader.resource_path if material is ShaderMaterial and material.shader != null else ""})

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
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/owner_finish_profiles.json"))
	for group: Dictionary in profiles.groups:
		if group.id == "bath":
			for recipe: Dictionary in group.recipes: bath_recipes[str(recipe.source_key)] = recipe
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
	# Reproduce the real finish conversion without composing another world.
	var actor := sink_script.new()
	actor.fixture = "bath_sink";actor.lavatory_profile = "WallService_2755"
	add_child(actor)
	var finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	finishes.apply_actor(actor,"bath")
	var uv_policy := preload("res://scripts/building/orison_v2_uv_material_policy.gd").new()
	uv_policy.inspect_branch(actor)
	var checked: Dictionary = {}
	for handle: Node3D in actor._handles:
		for draw: MeshInstance3D in handle.find_children("*","MeshInstance3D",true,false):
			for surface in draw.mesh.get_surface_count():
				_check_loaded_finish(draw.get_active_material(surface),"isolated finish pipeline",checked)
	uv_policy.free();actor.free()

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
	# Start with a seated fixture, then use the real controller to lift and
	# release it. This does not claim that seating was performed with the mouse.
	sink.set_stopper(true)
	player.camera.look_at(sink._bath_plug.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player._grab.find_target().get("part") == sink._bath_plug,
			"standing lavatory ray selects the actual drain plug")
	hand.click()
	var acquired: bool = player._grab.active() and sink._plug_hand.held
	check(acquired, "primary acquires installed lavatory plug without toggling it")
	if acquired:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0,-32)
		player._unhandled_input(motion)
		player.set_physics_process(true)
		for frame in 8: await get_tree().physics_frame
		check(player._grab.active() and sink._plug_hand.held and not sink._stopper,
				"real mouse and standing controller lift the plug clear of the drain")
		if player._grab.active(): hand.click()
		player.set_physics_process(false)
		await get_tree().create_timer(.5).timeout
		check(not sink._plug_hand.held and sink._plug_hand.resting and not sink._stopper,
				"released lavatory plug settles without stale hand ownership")
		check(sink._bath_chain_instances.get_instance_transform(0).origin.distance_to(
				sink._bath_plug.position+Vector3(0,.018,0)) < .001,
				"installed chain follows the mouse-released plug eye")
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
			reconstruction_save = RealityState.save_path
			reconstruction_plug = sink._bath_plug.position
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

func _reconstruct_lavatory(world: OrisonV2RuntimeRoot) -> OrisonV2RuntimeRoot:
	if reconstruction_save.is_empty(): return world
	var old_owner: WeakRef = weakref(world.household_state)
	world.shutdown_for_tests()
	world.free()
	check(old_owner.get_ref() == null, "original household save owner is freed before disk rebuild")
	var original_path: String = RealityState.save_path
	RealityState.reset_campaign_for_tests()
	RealityState.save_path = reconstruction_save
	RealityState.load_game()
	check(RealityState.can_continue(), "isolated campaign file validates before fresh-world construction")
	var rebuilt := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(rebuilt)
	var deadline := Time.get_ticks_msec()+600000
	while rebuilt.startup_ms <= 0 and not rebuilt.startup_failed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not rebuilt.startup_failed and rebuilt.startup_ms > 0, "fresh V2 world completes saved campaign reconstruction")
	RealityState.save_path = original_path
	if rebuilt.startup_failed or rebuilt.startup_ms <= 0: return rebuilt
	reconstruction_executed = true
	await get_tree().physics_frame
	var found := false
	for sink: TapProp in rebuilt.boiler_tend.taps:
		if sink.fixture != "bath_sink" or sink.unit != "4B": continue
		found = true
		check(is_equal_approx(sink._valve_openings.x,.31) and is_equal_approx(sink._valve_openings.y,.64),
				"fresh physical sink restores both independently released partial valves")
		check(Vector2(sink._bath_plug.position.x,sink._bath_plug.position.z).distance_to(
				Vector2(reconstruction_plug.x,reconstruction_plug.z)) < .0001,
				"fresh physical plug restores its released basin position from disk")
		check(not sink._plug_hand.held and sink._held_valve == -1 and not rebuilt.player._grab.active(),
				"fresh world never reconstructs transient plug, valve or player hand ownership")
		check(sink.get("lavatory_profile") == "WallService_2755", "fresh sink retains the surveyed 4B service selection")
	check(found, "fresh campaign contains the installed 4B lavatory")
	_check_installed_closet_services(rebuilt)
	return rebuilt

func _check_closet_models() -> void:
	var script := preload("res://scripts/building/orison_v2_water_closet.gd")
	var sweep := preload("res://scripts/props/mechanism_sweep.gd")
	for profile: String in script.SERVICE_PROFILES:
		var actor := script.new()
		actor.setup({"id":"service_profile_bench","asm":"toilet"})
		actor.service_profile = profile
		add_child(actor)
		var groups := actor.find_children("WCService_*","Node3D",true,false)
		var selected: Array[Node] = []
		for group in groups:
			if not group is MeshInstance3D: selected.append(group)
		check(selected.size() == 1 and selected[0].name == profile,
				"closet retains exactly one fixed service profile: " + profile)
		var triangles := 0
		if selected.size() == 1:
			var extras: Dictionary = selected[0].get_meta("extras",{})
			check(is_equal_approx(float(extras.get("wall_depth_godot_m",-1)),float(script.SERVICE_PROFILES[profile])),
					"loaded closet depth metadata agrees with its registered selector: " + profile)
			var draws := selected[0].find_children("*","MeshInstance3D",true,false)
			check(draws.size() == 3, "closet service kit has three fixed material partitions: " + profile)
			for draw: MeshInstance3D in draws:
				for surface in draw.mesh.get_surface_count():
					var arrays := draw.mesh.surface_get_arrays(surface)
					triangles += arrays[Mesh.ARRAY_INDEX].size()/3
					check(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size()
							and arrays[Mesh.ARRAY_TANGENT].size() == arrays[Mesh.ARRAY_VERTEX].size()*4,
							"loaded fixed service kit retains UV/tangent arrays: " + profile)
			check(triangles == (8152 if profile.ends_with("_Bypass") else 5720),
					"selected closet kit retains its measured source triangle budget: " + profile)
		await get_tree().physics_frame
		var cover: Node3D = actor.parts.CisternCover
		var clear_pose := cover.transform
		clear_pose.origin = Vector3(.6,1.12,-.08)
		check(sweep.clear(actor,cover,clear_pose,actor._service_collision_rids),
				"cover has an unobstructed removal position: " + profile)
		# Put the cover's collision centre on a real fixed-hardware triangle.
		# This negative control must fail even though the blocker belongs to actor.
		if selected.size() == 1:
			var draw := selected[0].find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
			var faces := draw.mesh.get_faces()
			var point := actor.to_local(draw.to_global((faces[0]+faces[1]+faces[2])/3.0))
			var shape := cover.find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
			var centre := cover.to_local(shape.to_global(shape.shape.get_debug_mesh().get_aabb().get_center()))
			var blocked := cover.transform
			blocked.origin = point-cover.basis*centre
			check(not sweep.clear(actor,cover,blocked,actor._service_collision_rids),
					"owned service hardware blocks an intersecting cover: " + profile)
		actor.free()

func _check_installed_closet_services(world: OrisonV2RuntimeRoot) -> void:
	var count := 0
	for node in world.adapter.root.find_children("*","Node3D",true,false):
		if node.get_script() != preload("res://scripts/building/orison_v2_water_closet.gd"): continue
		count += 1
		check(not str(node.service_profile).is_empty() and node._service_collision_rids.size() == 1,
				"installed closet owns one selected fixed hardware collider: " + str(node.name))
		check(node.parts.size() == 7 and node.parts.has("CisternCover") and node._chain != null,
				"fixed hardware preserves existing six mechanisms, water and chain: " + str(node.name))
		var exclude: Array[RID] = [world.player.get_rid(),node.get_rid()]
		for body: CollisionObject3D in node.find_children("*","CollisionObject3D",true,false):
			exclude.append(body.get_rid())
		var depth: float = node.SERVICE_PROFILES[node.service_profile]
		var selected := node.find_child(str(node.service_profile),true,false) as Node3D
		check(selected != null, "installed selected closet group remains identifiable for wall seating")
		if selected == null: continue
		for marker: String in ["SupplyHouse_godot","LeftWall_godot","RightWall_godot"]:
			var coordinate: Variant = selected.get_meta("extras",{}).get(marker)
			check(coordinate is Array and coordinate.size() == 3,
					"native closet profile carries its authored contact marker: " + marker)
			if coordinate is not Array or coordinate.size() != 3: continue
			var port := Vector2(float(coordinate[0]),float(coordinate[1]))
			var ray := PhysicsRayQueryParameters3D.create(node.to_global(Vector3(port.x,port.y,.32)),
					node.to_global(Vector3(port.x,port.y,depth+.08)),1,exclude)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			var row := {"id":str(node.name),"profile":str(node.service_profile),
					"port":[port.x,port.y],"expected_bare_wall_depth":depth+.0045}
			if not hit.is_empty():
				row["actual_depth"] = node.to_local(hit.position).z
				row["collider"] = str(hit.collider.get_path())
			closet_contacts.append(row)
			check(not hit.is_empty() and absf(node.to_local(hit.position).z-depth-.0045)<.0002,
					"installed closet service meets surveyed wall and finish skin: " + str(row))
	check(count == 13, "twelve domestic and one templated staff water closet retain fitted service kits")

func _played_closet(world: OrisonV2RuntimeRoot) -> void:
	var closet: Node3D
	for node in world.adapter.root.find_children("*","Node3D",true,false):
		if node.get_script() == preload("res://scripts/building/orison_v2_water_closet.gd") and node.unit == "4B":
			closet = node
	check(closet != null, "installed 4B closet is available for the combined input route")
	if closet == null: return
	var player: PlayerController = world.player
	check(not player.protected_input_active() and player.text_input_owner == null, "closet route respects protected input ownership")
	if player.protected_input_active() or player.text_input_owner != null: return
	var old_pose := player.global_transform
	var old_view := player.camera.global_transform
	var old_physics := player.is_physics_processing()
	var old_mouse := Input.mouse_mode
	var saved: Dictionary = closet.mechanism_snapshot()
	var stance: Vector3 = closet.to_global(Vector3(0,.025,-.85))
	var support := world.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(stance+Vector3.UP*.03,stance-Vector3.UP*.08,1,[player.get_rid()]))
	check(not support.is_empty() and support.normal.y > .99, "closet input stance has real floor support")
	if support.is_empty() or support.normal.y <= .99: return
	stance.y = support.position.y+.025
	var capsule := PhysicsShapeQueryParameters3D.new()
	capsule.shape = player._capsule
	capsule.transform = Transform3D(player.global_basis,stance)*player._shape.transform
	capsule.exclude = [player.get_rid()]
	var blockers := world.get_world_3d().direct_space_state.intersect_shape(capsule,4)
	check(blockers.is_empty(), "closet approach clears the full standing capsule: " + str(blockers))
	if not blockers.is_empty(): return
	player.cancel_manipulation();player.set_physics_process(false)
	player.global_position = stance;player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hand := preload("res://tests/fixed_gesture_patrol_hand.gd").new()
	add_child(hand);hand.player = player
	var touch := closet.parts.CisternHandle.get_node("HandleTouchPoint") as Node3D
	check(await hand.operate(touch.global_position,deg_to_rad(-35),closet),
			"actual mouse turns and releases the installed closet flush handle")
	await get_tree().create_timer(.3).timeout
	check(closet.water_level < .98 and closet._held.is_empty(), "existing flush water owner drains after released input")
	# The raised lid legitimately occludes the cistern from this standing stance.
	# Close it through its real control before trying to reach over it.
	var lid: Node3D = closet.parts.RaisedLid
	var lid_draw := lid.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	check(await hand.operate(lid_draw.to_global(lid_draw.mesh.get_aabb().get_center()),0,closet),
			"actual mouse lowers the raised lid to expose the cistern cover")
	player.camera.look_at(closet.parts.CisternCover.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hand.click()
	var acquired: bool = player._grab.active() and player._grab.target.get("part") == closet.parts.CisternCover
	var picked := str(player._grab.target.get("part")) if player._grab.active() else "none"
	check(acquired, "actual primary selects the removable cover with the new hardware installed; picked=" + picked)
	if acquired:
		var motion := InputEventMouseMotion.new();motion.relative = Vector2(0,-32)
		player._unhandled_input(motion)
		player.set_physics_process(true)
		for frame in 8: await get_tree().physics_frame
		check(player._grab.active() and closet._held == "CisternCover", "cover mouse motion retains its existing hand owner")
		player.set_physics_process(false)
	# A failed acquisition must still release any different part actually picked.
	if player._grab.active(): hand.click()
	check(closet._held.is_empty() and not player._grab.active(), "cover release leaves no transient input owner")
	await RenderingServer.frame_post_draw
	await capture("installed_closet_services")
	player.cancel_manipulation();closet.restore_mechanism(saved)
	world.household_state.capture_now();hand.free()
	player.global_transform = old_pose;player.camera.global_transform = old_view
	player.set_physics_process(old_physics);Input.mouse_mode = old_mouse

func run() -> void:
	RealityState.persistence_enabled = false
	_check_service_models()
	await _check_closet_models()
	if OS.get_environment("ORISON_LAVATORY_MODELS_ONLY") == "1":
		print("BATHROOM IMPORT SELECTORS: %d checks, %d failures; no composed world or interaction claimed" % [checks, failures.size()])
		_finish(null)
		return
	if not failures.is_empty():
		print("LAVATORY: isolated pipeline failed; occupied world not started")
		_finish(null)
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
					_check_loaded_finish(draw.get_active_material(surface),str(tap.name),checked_textures)
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
		_check_installed_closet_services(world)
		await _played_closet(world)
		# Failed first-world interfaces cannot be accepted by a second startup.
		# Repair those first; the final passing programme must still rebuild.
		if not failures.is_empty():
			_finish(world)
			return
		world = await _reconstruct_lavatory(world)
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
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("lavatory.json"), FileAccess.WRITE)
		if file == null:
			check(false, "diagnostic output could not be opened: " + directory)
		else:
			file.store_string(JSON.stringify({"checks":checks,"failures":failures,"service_contacts":service_contacts,"loaded_finishes":loaded_finishes,"closet_contacts":closet_contacts,"reconstruction_executed":reconstruction_executed,"scope":"lavatory_and_closet_services" if OS.get_environment("ORISON_LAVATORY_ONLY")=="1" else "full_bathroom"},"\t"))
	if world != null:
		world.shutdown_for_tests()
		world.free()
	print("LAVATORY: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _mesh_bounds(root: Node3D,part: MeshInstance3D) -> AABB:
	return (root.global_transform.affine_inverse()*part.global_transform)*part.mesh.get_aabb()
