extends "res://tests/v2_fire_hand_bench.gd"
## Small imported-surface and original-input bench before composed qualification.
func capture(label: String) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	for frame in 12:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func _run() -> void:
	preload("res://tests/v2_control_finish_review.gd").new().validate_material_contract(self)
	if not failures.is_empty():get_tree().quit(1);return
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-30,0);sun.light_energy=.12;add_child(sun)
	var floor_body:=StaticBody3D.new();var floor_shape:=CollisionShape3D.new()
	var floor_box:=BoxShape3D.new();floor_box.size=Vector3(25.,.2,5.);floor_shape.shape=floor_box
	floor_body.add_child(floor_shape);floor_body.position=Vector3(8.,-.1,0.);add_child(floor_body)
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.0}]}),"cabinet skin mounts on original production owners"):
		get_tree().quit(1);return
	var stock: RefCounted=native._skin_stock
	var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for identity: String in stock.meshes:metrics._check_cap_mapping(stock.meshes[identity],true)
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	for identity: String in stock.finishes:
		var mat: StandardMaterial3D=stock.finishes[identity]
		check(mat.normal_enabled and is_equal_approx(mat.normal_scale,1.) and not mat.uv1_triplanar,"construction relief and authored UV: "+identity)
		check(mat.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"anisotropic mip filter: "+identity)
		for texture: Texture2D in [mat.albedo_texture,mat.roughness_texture,mat.normal_texture]:
			check(texture!=null and texture.get_image().get_mipmap_count()>0,"loaded PBR mip chain: "+identity)
	if not failures.is_empty():get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	player=PlayerController.new();player.position=Vector3(-.1,.025,1.15);add_child(player)
	player.set_lamp_enabled(true);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(.02,.025,.03);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.34,.39,.46);environment.ambient_light_energy=.2
	var world_environment:=WorldEnvironment.new();world_environment.environment=environment;add_child(world_environment)
	var air:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new();add_child(air)
	check(air.setup(player,environment),"production carried voxel light initializes")
	for frame in 30:await get_tree().physics_frame
	check(air.field!=null and air.field.ready and air.field.failed.is_empty(),"live voxel field ready")
	check(player.flashlight.light_projector==null and player._light_mask == null,"legacy screen plate disabled")
	await aim(actor.to_global(Vector3(0,.42,.12)))
	await capture("cabinet_cut_normals_on")
	for mat: StandardMaterial3D in stock.finishes.values():mat.normal_enabled=false
	await capture("cabinet_cut_normals_off")
	for mat: StandardMaterial3D in stock.finishes.values():mat.normal_enabled=true
	var pane: MeshInstance3D
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if draw.get_meta("native_fire_part","")=="F069":pane=draw
	for style: String in ["glass_drawn_expressive","glass_reeded","glass_cut","glass_frosted"]:
		pane.material_override=stock.finishes[style];await capture("cabinet_"+style)
	pane.material_override=stock.finishes[stock.station_styles[actor.station_id]]
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	var fixed: Node3D=actor.get_node("HingeFixed0")
	var moving: Node3D=actor._door_pivot.get_node("HingeMoving0")
	var fixed_before:=fixed.global_transform;var moving_before:=moving.global_transform
	if not check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual grab motion release opens new leaf"):
		get_tree().quit(1);return
	check(fixed.global_transform.is_equal_approx(fixed_before) and not moving.global_transform.is_equal_approx(moving_before),"interleaved hinge retains fixed and moving owners")
	await aim(actor.to_global(Vector3(.20,.10,.14)))
	await capture("cabinet_open_parts_tray")
	await exercise_gasket(actor,hand)
	print("V2 FIRE CABINET SKIN BENCH: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
