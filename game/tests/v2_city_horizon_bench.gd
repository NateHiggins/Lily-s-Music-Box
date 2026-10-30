extends Node
const Horizon := preload("res://scripts/building/orison_v2_city_horizon.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY HORIZON BENCH: " + label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
	for asset: Dictionary in fixture.assets.values():
		check(FileAccess.get_sha256("res://"+str(asset.asset).trim_prefix("game/"))==str(asset.sha256),"installed horizon asset matches its native source binding")
	var horizon := Horizon.new()
	add_child(horizon)
	var ground := preload("res://scripts/building/orison_v2_ground.gd").new()
	add_child(ground)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bounds: Dictionary = {}
	var mapped: Dictionary = {}
	var bodies: Dictionary = {}
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for model: Node3D in horizon.get_children():
		for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			bodies[(draw.get_node("HorizonCollision") as StaticBody3D).get_rid()]=draw
			var identity := str(draw.get_meta("v2_city_horizon_building"))
			var box := draw.global_transform * draw.mesh.get_aabb()
			bounds[identity] = (bounds[identity] as AABB).merge(box) if bounds.has(identity) else box
			var key := str(model.name) + "/" + str(draw.name).split("__")[-1]
			if not mapped.has(key):
				mapped[key] = true
				metrics._check_cap_mapping(draw.mesh, true)
	check(metrics.failures.is_empty(), "loaded metric charts and tangents across both asset/material families")
	var ground_parts := 0
	for draw: MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
		ground_parts += 1
		metrics._check_cap_mapping(draw.mesh,true,true)
		var loaded := draw.material_override
		var material := loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
		check(material != null and not material.uv1_triplanar and not MatLib.is_shared_material(material),"local authored ground finish: "+str(draw.name))
		if material != null:
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				check(texture != null and texture.get_image().has_mipmaps(),"actual loaded ground PBR mip chain: "+str(draw.name))
	check(ground_parts>0 and metrics.failures.is_empty(),"complete imported ground charts and derivatives")
	metrics.free()
	check(bounds.size() == fixture.buildings.size(), "all authored building identities loaded once")
	for row: Dictionary in fixture.buildings:
		var b: Array = row.native_stock_bounds
		var lo := Vector3(b[0],b[2],-b[4])
		var hi := Vector3(b[3],b[5],-b[1])
		var expected := AABB(lo,hi-lo)
		var actual: AABB = bounds.get(str(row.id), AABB())
		check(actual.position.distance_to(expected.position)<.0001 and actual.end.distance_to(expected.end)<.0001, "actual imported building/grade frame: "+str(row.id)+" actual="+str(actual)+" expected="+str(expected))
	for window: Dictionary in fixture.window_rows:
		var p: Array = window.point
		var n: Array = window.normal
		var point := Vector3(p[0],p[2],-p[1])
		var normal := Vector3(n[0],n[2],-n[1])
		var expected := point - normal * float(window.recess_m)
		var hit := horizon.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.03,point-normal*.25,1))
		var valid: bool = not hit.is_empty() and horizon.is_ancestor_of(hit.collider) and hit.position.distance_to(expected)<.0001
		if valid:
			var draw := hit.collider.get_parent() as MeshInstance3D
			valid = draw != null and str(draw.get_meta("v2_city_horizon_building"))==str(window.building) and str(draw.name).ends_with("__mirror_aged")
		check(valid, "actual fitted opaque pane: "+str(window.building)+" "+str(point))
	var grade: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_ground_apron.json"))
	for strip: Dictionary in grade.boxes:
		var samples: Array=strip.exposed_samples
		check(samples.size()==9,"source-spanning exposed ground roster: "+str(strip.id))
		for sample: Array in samples:
			var point:=Vector3(sample[0],sample[1],sample[2])
			var hit := horizon.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.03,point-Vector3.UP*.03,1))
			check(not hit.is_empty() and ground.is_ancestor_of(hit.collider) and hit.position.distance_to(point)<.0001,"actual exposed grade beside new foundations: "+str(strip.id))
	# Independent intended elevations, including submerged beds. Water must not
	# become a solid platform above them.
	for point: Vector3 in [Vector3(450,-8,0),Vector3(-400,-3.5,0),Vector3(0,-8,-360),Vector3(112,-1.3055,0),Vector3(140,-1.7255,60),Vector3(180,-2.3255,60),Vector3(280,-3.8255,60),Vector3(-108,-.02,0)]:
		var hit:=ground.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*12,point-Vector3.UP*.1,1))
		check(not hit.is_empty() and ground.is_ancestor_of(hit.collider) and hit.position.distance_to(point)<.0001,"actual retained datum, rail cut or submerged bed: "+str(point))
	var relief_parts:=0
	for draw: MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
		if not str(draw.name).contains("__"):continue
		relief_parts+=1
		if str(draw.name).ends_with("__water_clear"):
			check(not draw.has_node("GroundCollision"),"river/canal water has no walkable collision slab")
	check(relief_parts==grade.parts.size(),"complete imported relief and water inventory")
	check(float(ground.get_meta("city_street_asl_m"))==6.0 and float(ground.get_meta("city_water_scene_y_m"))==-6.0,"one scene-to-ASL datum")
	var court:=Vector3(-95,30,-151.5)
	var court_hit:=ground.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(court,Vector3(court.x,-.2,court.z),1))
	check(not court_hit.is_empty() and ground.is_ancestor_of(court_hit.collider) and absf(court_hit.position.y+.02)<.0001,"recessed entrance court is genuinely open above the ground, without a rectangular roof crossing it")
	for contact: Dictionary in fixture.parapet_contacts:
		var p: Array=contact.point
		var point:=Vector3(p[0],p[2],-p[1])
		for direction: float in [-1.,1.]:
			var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.025*direction,point-Vector3.UP*.025*direction,1)
			query.hit_back_faces=false
			var hit:=horizon.get_world_3d().direct_space_state.intersect_ray(query)
			var draw: MeshInstance3D=bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
			var expected_key: String=contact.wall_key if direction<0 else "galvanized_roof"
			check(draw!=null and str(draw.name)==str(contact.building)+"__"+expected_key and hit.position.distance_to(point)<.0001,"actual parapet bottom and roof top meet over the bearing wall: "+str(contact.building)+" "+expected_key)
		var outside: Array=contact.outside_probe
		var probe:=Vector3(outside[0],outside[2],-outside[1])
		var query:=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.025,probe-Vector3.UP*.025,1)
		query.hit_back_faces=false
		var hit:=horizon.get_world_3d().direct_space_state.intersect_ray(query)
		var draw: MeshInstance3D=bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
		check(draw==null or str(draw.name)!=str(contact.building)+"__galvanized_roof","outside-wall control is not accepted as a structural roof bearing")
	var eyes: Array[Vector3]=[]
	var excluded: Array[RID]=[]
	var view := preload("res://tests/v2_city_context_review.gd").capture_station(horizon.get_world_3d().direct_space_state,horizon,fixture.window_rows,bodies,eyes,excluded)
	check(not view.is_empty() and not view.get("retained_camera",true),"derived context camera has a genuine first-hit native pane")
	if OS.get_environment("CITY_STUDY_CAPTURE")=="1":await _study_reviews(fixture)
	var retired_ground: WeakRef=weakref(ground)
	ground.free()
	var retired: WeakRef = weakref(horizon)
	horizon.free()
	await get_tree().physics_frame
	check(retired.get_ref()==null, "production horizon node retires")
	check(retired_ground.get_ref()==null,"production grade node retires")
	print("CITY HORIZON BENCH: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _study_reviews(fixture: Dictionary) -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DisplayServer.get_name()!="headless","study render requires the graphical backend and SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":return
	DirAccess.make_dir_recursive_absolute(directory)
	var environment:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.32,.38,.44)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color(.62,.72,.8);settings.ambient_light_energy=.7
	environment.environment=settings;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);sun.light_energy=2.8;sun.shadow_enabled=true;add_child(sun)
	var camera:=Camera3D.new();camera.fov=48;camera.far=1500;add_child(camera);camera.make_current()
	var captures:=0
	for row: Dictionary in fixture.buildings:
		if not row.has("architecture"):continue
		var r: Array=row.rect;var center: float=(r[0]+r[2])*.5
		var width: float=r[2]-r[0];var height:=float(row.height_m)
		camera.position=Vector3(center+width*.25,height*.55,r[3]+maxf(20,width*1.35))
		camera.look_at(Vector3(center,height*.48,r[3]-1))
		await get_tree().create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		var saved:=get_viewport().get_texture().get_image().save_png(directory.path_join(str(row.id)+".png"))
		check(saved==OK,"imported native-resolution study render saved: "+str(row.id));captures+=1
	check(captures>0,"nonempty imported study render roster")
	print("CITY STUDY RENDERS: ",captures,"; neutral bench lighting, no composed-world or played-access acceptance")
	camera.free();sun.free();environment.free()
