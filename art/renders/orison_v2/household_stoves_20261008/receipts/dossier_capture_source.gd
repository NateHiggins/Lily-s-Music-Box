extends "res://tests/orison_v2_city_sweep.gd"
## Read-only current-world model plates. Studio lighting is explicitly separate.
var plates: Array = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"dossier production world initializes")
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	var entry: Dictionary = world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")[0]
	var rect: Array = entry.rect
	world.player.global_position = world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5,0.,(rect[1]+rect[3])*.5))
	for frame in 600:
		if world.passage_region.residency.state=="RESIDENT":break
		await get_tree().process_frame
	check(world.passage_region.residency.state=="RESIDENT","dossier uses resident production passage")
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var validator: Node = load("res://tests/orison_v2_household_stoves_test.gd").new()
	validator.capture_enabled = false
	add_child(validator)
	var stove_result: Dictionary = await validator.validate_in_world(world)
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ORISON_DOSSIER_PLAN")))
	var inventory: Array = []
	for node: Node in world.find_children("*","Node3D",true,false):
		if node is MeshInstance3D:continue
		inventory.append({"name":str(node.name),"path":str(world.get_path_to(node)),"script":node.get_script().resource_path if node.get_script()!=null else ""})
	FileAccess.open(directory.path_join("node_inventory.json"),FileAccess.WRITE).store_string(JSON.stringify(inventory,"\t"))
	for row: Dictionary in plan.models:
		var actor: Node3D = null
		if row.has("name"):actor=world.find_child(str(row.name),true,false) as Node3D
		elif row.has("script"):
			for node: Node in world.find_children("*","Node3D",true,false):
				if node.get_script()!=null and node.get_script().resource_path==row.script:
					actor=node as Node3D;break
		if actor==null:
			plates.append({"id":row.id,"status":"not_found","selector":row});continue
		await _plate(actor,row,directory)
	var source_result := {"checks":stove_result.checks,"failures":stove_result.failures,"fixture_sha256":FileAccess.get_sha256("res://tests/fixtures/orison_household_stoves.json"),"factory_sha256":FileAccess.get_sha256("res://scripts/building/orison_v2_native_household_stoves.gd"),"validator_sha256":FileAccess.get_sha256("res://tests/orison_v2_household_stoves_test.gd")}
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	var post: Dictionary = validator.validate_after_teardown()
	source_result.checks=post.checks
	source_result.failures=post.failures
	validator.free()
	FileAccess.open(directory.path_join("dossier_capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Current production geometry/materials copied into neutral isolated review lighting; not an in-situ photoreal or runtime-contract acceptance.","plates":plates,"stove_verification":source_result,"failures":failures},"\t"))
	await get_tree().process_frame
	print("DOSSIER: plates=",plates.size()," stove_checks=",post.checks," stove_failures=",post.failures.size())
	get_tree().quit(0 if failures.is_empty() and post.failures.is_empty() else 1)

func _plate(actor: Node3D,row: Dictionary,directory: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,1050)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var studio := Node3D.new()
	viewport.add_child(studio)
	var bounds := AABB()
	var count := 0
	var source_meshes: Array = []
	var origin := actor.global_transform.affine_inverse()
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null or not draw.is_visible_in_tree():continue
		if actor is LightFixtureProp and draw==actor._halo:continue
		var clone := MeshInstance3D.new()
		clone.mesh = draw.mesh
		clone.material_override = draw.material_override
		clone.material_overlay = draw.material_overlay
		clone.cast_shadow = draw.cast_shadow
		for index in draw.get_surface_override_material_count():clone.set_surface_override_material(index,draw.get_surface_override_material(index))
		studio.add_child(clone)
		clone.transform = origin*draw.global_transform
		var box: AABB = clone.transform*clone.get_aabb()
		bounds = box if count==0 else bounds.merge(box)
		count+=1
		source_meshes.append({"name":str(draw.name),"mesh":draw.mesh.resource_path,"class":draw.mesh.get_class()})
	for label: Label3D in actor.find_children("*","Label3D",true,false):
		if not label.is_visible_in_tree():continue
		var clone := Label3D.new()
		clone.text=label.text;clone.font=label.font;clone.font_size=label.font_size
		clone.pixel_size=label.pixel_size;clone.modulate=label.modulate
		clone.outline_size=label.outline_size;clone.outline_modulate=label.outline_modulate
		clone.billboard=label.billboard;clone.no_depth_test=label.no_depth_test
		studio.add_child(clone);clone.transform=origin*label.global_transform
	if count==0:
		plates.append({"id":row.id,"status":"no_visible_meshes","selector":row});viewport.free();return
	var environment := WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.24,.28,.32)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.87,.91,1.)
	environment.environment.ambient_light_energy=.65
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	studio.add_child(environment)
	for spec: Vector3 in [Vector3(-.65,-.55,2.2),Vector3(-.3,2.,.8)]:
		var light := DirectionalLight3D.new()
		light.light_energy=spec.z
		light.shadow_enabled=true
		studio.add_child(light);light.rotation=Vector3(spec.x,spec.y,0.)
	var camera := Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.far=1000.
	studio.add_child(camera);camera.current=true
	var images: Array = []
	var angles: Array = row.get("angles",[25.,-25.,155.])
	for index in angles.size():
		var angle := deg_to_rad(float(angles[index]))
		var direction := Vector3(sin(angle),.25,-cos(angle)).normalized()
		camera.position=bounds.get_center()+direction*maxf(bounds.size.length()*2.,2.)
		camera.look_at(bounds.get_center())
		var half_y := 0.
		var half_x := 0.
		for corner in 8:
			var point := camera.to_local(bounds.get_endpoint(corner))
			half_y=maxf(half_y,absf(point.y));half_x=maxf(half_x,absf(point.x))
		camera.size=maxf(half_y*2.,half_x*2.*1050./1280.)*1.16
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var filename := str(row.id)+"_"+str(index)+".png"
		check(viewport.get_texture().get_image().save_png(directory.path_join(filename))==OK,"dossier image saved "+filename)
		images.append(filename)
	plates.append({"id":row.id,"status":"captured_pending_review","actor":str(actor.name),"script":actor.get_script().resource_path if actor.get_script()!=null else "","images":images,"meshes":source_meshes,"size":[bounds.size.x,bounds.size.y,bounds.size.z],"note":"Existing visible meshes and label text; neutral review lighting. Original material resources retained. LightFixtureProp additive halo omitted from isolated model bounds."})
	viewport.free()
