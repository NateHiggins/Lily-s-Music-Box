extends "res://tests/orison_v2_roof_membrane_test.gd"
var roof_draws: Array[MeshInstance3D] = []
var roof_materials: Array[Material] = []

func _city_material(draw: MeshInstance3D, key: String) -> void:
	var source: Material = draw.get_meta("v2_city_roof_source",draw.material_override)
	var material := source as StandardMaterial3D
	var shared := MatLib.get_mat(key)
	check(material!=null and material!=shared and not material.uv1_triplanar and shared.uv1_triplanar,"native charts are local and shared catalogue projection remains intact")
	check(material.albedo_texture==shared.albedo_texture and material.roughness_texture==shared.roughness_texture and material.normal_texture==shared.normal_texture,"all three original catalogue maps remain with the local source")
	if key != "galvanized_roof":
		check(draw.material_override==source,"unselected city materials unchanged")
		return
	roof_draws.append(draw);roof_materials.append(draw.material_override)
	var tuned := draw.material_override as ShaderMaterial
	check(tuned!=null and tuned.shader==SurfacePass.OPAQUE,"existing opaque roof finish deployed")
	if tuned==null:return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/owner_finish_profiles.json"))
	var recipe: Dictionary = {}
	for group: Dictionary in profile.groups:
		if group.id=="roof":
			for row: Dictionary in group.recipes:
				if row.source_key==key:recipe=row
	var maps := MatLib.get_mat(str(recipe.catalog))
	for pair: Array in [["albedo_tex",maps.albedo_texture],["rough_tex",maps.roughness_texture],["normal_tex",maps.normal_texture]]:
		check(tuned.get_shader_parameter(pair[0])==pair[1] and pair[1].get_image().has_mipmaps(),"exact zinc catalogue maps and mip chains")
	check(is_equal_approx(float(tuned.get_shader_parameter("normal_scale")),float(recipe.normal)) and is_equal_approx(float(tuned.get_shader_parameter("roughness_mul")),float(recipe.roughness)) and is_equal_approx(float(tuned.get_shader_parameter("metallic")),float(recipe.metallic)),"exact existing roof response")
	check(is_equal_approx(float(tuned.get_shader_parameter("pigment_variation")),float(recipe.pigment)),"existing zinc pigment calibration")
	var tint: Array = recipe.color
	check((tuned.get_shader_parameter("albedo_color") as Color).is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"exact existing roof tint")
	check((tuned.get_shader_parameter("mesh_uv_scale") as Vector2).is_equal_approx(Vector2.ONE/float(MatLib.SETS[str(recipe.catalog)][3])),"replacement preserves physical tile size")
	var uv_mode: Variant = tuned.get_shader_parameter("uv_mode")
	check(uv_mode==null or int(uv_mode)==0,"native metric charts retained")

func _city_shot(label: String) -> void:
	var selected := OS.get_environment("ORISON_CITY_FINISH_VIEWS")
	if not selected.is_empty() and label not in selected.split(",",false):return
	for before: bool in [true,false]:
		for i in roof_draws.size():roof_draws[i].material_override=roof_draws[i].get_meta("v2_city_roof_source") if before else roof_materials[i]
		await _settled_optics();await shot(label+("_before" if before else "_after"))

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"actual composed city starts with joined source parapets")
	if world.startup_failed:world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var city: Node3D=world.get_node("CityShells")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_closure.json"))
	check(FileAccess.get_sha256("res://assets/props/city_shells.glb")==fixture.asset_sha256,"installed city shell binds its native closure export")
	var parts:=0;var triangles:=0;var bodies: Dictionary={};var expected: Dictionary={}
	for part: Dictionary in fixture.parts:expected[part.name]=int(part.triangles)
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		if not draw.get_meta("retained_city_shell",false):continue
		parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
		var name:=str(draw.name).trim_prefix("city_shells_")
		check(expected.has(name) and expected.get(name)==count,"each original building/material partition binds exact generated triangles")
		_check_cap_mapping(draw.mesh,true)
		_city_material(draw,str(draw.name).split("__")[-1])
		var body: StaticBody3D=draw.get_parent().get_node(str(draw.name)+"Collision")
		var shape: CollisionShape3D=body.get_child(0)
		var physical:=shape.shape as ConcavePolygonShape3D
		check(physical!=null and physical.get_faces()==draw.mesh.get_faces(),"each installed city face has identical physical triangles")
		check(shape.global_transform.is_equal_approx(draw.global_transform),"visible and physical city faces share their actual world pose")
		bodies[body.get_rid()]=true
	check(parts==84 and parts==fixture.parts.size() and triangles==int(fixture.triangles),"original 84 building/material batches retain the native inventory")
	check(int(fixture.source_parapet_stocks)==100 and fixture.closed_joined_parapets.size()==25 and fixture.original_records.size()==335,"original city sources and all 25 joined wall rings remain explicit")
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not bodies.has(body.get_rid()):exclude.append(body.get_rid())
	var support_samples:=0
	for asset: String in ["masts","aerials","tanks"]:
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_"+asset+".json"))
		for contact: Dictionary in original.contacts:
			var n: Vector3=city.global_basis*Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
			for sample: Array in [contact.point]+contact.footprint:
				var p:=city.to_global(Vector3(sample[0],sample[2],-sample[1]))
				var ray:=PhysicsRayQueryParameters3D.create(p+n*.03,p-n*.03,1,exclude)
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and bodies.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"existing complete hardware footprint bears on the joined city shell within its original tolerance")
				support_samples+=1
	check(roof_draws.size()==11,"exact eleven galvanized city partitions receive the existing roof recipe")
	for joint: Dictionary in fixture.corner_stations:
		var offset: Array=fixture.capture_offsets_godot.corner
		var low:=Vector2(INF,INF);var high:=Vector2(-INF,-INF)
		for row: Dictionary in fixture.original_records:
			if not str(row.id).begins_with(str(joint.group)+"_par_"):continue
			low=low.min(Vector2(row.rect[0]+row.registration_offset_x,row.rect[1]))
			high=high.max(Vector2(row.rect[2]+row.registration_offset_x,row.rect[3]))
		var found:=false
		for sign_pair: Vector2 in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			var p:=city.to_global(Vector3(high.x if sign_pair.x>0 else low.x,joint.point[2],-(high.y if sign_pair.y>0 else low.y)))
			var eye:=p+Vector3(offset[0]*sign_pair.x,offset[1],offset[2]*sign_pair.y)
			var target:=p-Vector3(.12*sign_pair.x,.12,-.15*sign_pair.y)
			var sight:=PhysicsRayQueryParameters3D.create(eye,target,1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(sight)
			if hit.is_empty() or not hit.collider.get_meta("retained_city_shell",false):continue
			if not str(hit.collider.name).contains(str(joint.group)+"__") or hit.position.distance_to(target)>.35:continue
			world.player.global_position=eye-Vector3.UP*world.player.STANDING_EYE
			world.player.face_world_point(target);found=true;break
		check(found,"each building corner capture has a clear sightline to its own parapet")
		world.player.set_lamp_enabled(true)
		await _city_shot(str(joint.group)+"_corner")
	for view: Dictionary in fixture.skyline_views_godot:
		var at: Array=view.at;var target: Array=view.target;var root: Node3D=world.adapter.root
		world.player.global_position=root.to_global(Vector3(at[0],at[1],at[2]));world.player.face_world_point(root.to_global(Vector3(target[0],target[1],target[2])))
		await _city_shot(view.id)
	print("CITY CLOSURE: checks=",checks," parts=",parts," triangles=",triangles," joined_parapets=",fixture.closed_joined_parapets.size()," retained_hardware_footprint_samples=",support_samples," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
