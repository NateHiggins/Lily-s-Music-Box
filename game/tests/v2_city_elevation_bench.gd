extends Node
## Imported production owner and support diagnostics, not whole-world acceptance.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY NATIVE BENCH: "+label)
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	for path: String in ["res://tests/v2_city_horizon_review.gd","res://tests/v2_city_elevation_review.gd","res://tests/orison_v2_surface_inventory.gd","res://tests/orison_v2_city_closure_test.gd","res://tests/orison_v2_city_composition_test.gd"]:
		var source := load(path) as Script
		check(source!=null and source.can_instantiate(),"dependent city source parses: "+path)
	var city := Node3D.new()
	city.set_script(load("res://scripts/building/orison_v2_city_shells.gd"))
	add_child(city)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var shells: Dictionary={}
	var draws := 0
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		draws += 1
		var stock: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		if stock is StandardMaterial3D:
			check(not stock.uv1_triplanar,"authored charts: "+str(draw.name))
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				check(texture!=null and texture.get_image().has_mipmaps(),"loaded PBR/mips: "+str(draw.name))
		else: check(false,"unhandled city finish: "+str(draw.name))
		if draw.get_meta("retained_city_shell",false):
			var body := draw.get_parent().get_node(str(draw.name)+"Collision") as StaticBody3D
			shells[body.get_rid()]=str(draw.name)
			var shape := body.get_child(0) as CollisionShape3D
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"identical visible/collision stock: "+str(draw.name))
	var apron := (load("res://assets/props/city_ground_apron.glb") as PackedScene).instantiate() as Node3D
	var apron_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_ground_apron.json"))
	var apron_parts := 0
	for draw: MeshInstance3D in apron.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		apron_parts+=1
	check(apron_parts==int(apron_data.export_check.primitives) and apron_parts>=4,"retained apron geometry roster")
	apron.free()
	check(metrics.failures.is_empty(),"imported UV/normal/tangent checks")
	metrics.free()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in city.find_children("*","CollisionObject3D",true,false):
		if not shells.has(body.get_rid()):exclude.append(body.get_rid())
	var contacts := 0
	for family: String in ["elevations","masts","aerials","tanks","beacons"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_"+family+".json"))
		check(FileAccess.get_sha256("res://assets/props/city_"+family+".glb")==data.asset_sha256,"installed source hash: "+family)
		if family not in ["masts","aerials","tanks"]:continue
		for contact: Dictionary in data.contacts:
			var n := Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
			for sample: Array in [contact.point]+contact.footprint:
				var p := city.to_global(Vector3(sample[0],sample[2],-sample[1]))
				var hit := city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+n*.03,p-n*.03,1,exclude))
				check(not hit.is_empty() and shells.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"real roof bearing: "+str(contact.id))
				contacts+=1
	check(contacts>=1205 and shells.size()==fixture.parts.size() and draws>600,"nonempty complete family inventory")
	# A wrong old roof height cannot satisfy the repaired building's actual solid.
	var roof := city.to_global(Vector3(-6,16.51,-48))
	var roof_hit := city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(roof+Vector3.UP*.03,roof-Vector3.UP*.03,1,exclude))
	check(not roof_hit.is_empty() and str(shells.get(roof_hit.collider.get_rid(),"")).begins_with("site_far_n__"),"lowered north roof physically present")
	var old := city.to_global(Vector3(-6,44.26,-48))
	check(city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(old+Vector3.UP*.03,old-Vector3.UP*.03,1,exclude)).is_empty(),"old tower roof rejected")
	if not OS.get_environment("SHOT_DIR").is_empty():
		check(DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))==OK,"capture directory available")
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color(.24,.30,.38)
		environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color=Color(.65,.73,.85)
		environment.environment.ambient_light_energy=.7
		add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.light_energy=2.5;sun.rotation_degrees=Vector3(-35,-35,0);sun.shadow_enabled=true
		add_child(sun)
		var camera := Camera3D.new()
		add_child(camera);camera.make_current();camera.fov=45
		for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
			draw.visible=str(draw.name).begins_with("site_far_n__")
		var building: Dictionary=fixture.buildings.filter(func(row):return row.id=="site_far_n")[0]
		var bounds: Array=building.main_rect
		var target := Vector3((bounds[0]+bounds[2])*.5,float(building.roof_height)*.55,-(bounds[1]+bounds[3])*.5)
		var span := maxf(float(bounds[2]-bounds[0]),float(bounds[3]-bounds[1]))
		camera.global_position=city.to_global(target+Vector3(span*.7,float(building.roof_height)*.45,span*1.05))
		camera.look_at(city.to_global(target))
		await get_tree().create_timer(.6).timeout
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("north_five_storeys.png"))==OK,"actual optical capture saved")
	city.free()
	await get_tree().process_frame
	print("CITY NATIVE BENCH: %d checks, %d roof samples, %d draws, %d failures" % [checks,contacts,draws,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
