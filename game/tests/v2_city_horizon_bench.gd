extends Node
const Horizon := preload("res://scripts/building/orison_v2_city_horizon.gd")
var failures: Array[String] = []
var checks := 0
var roof_controls: Array[Dictionary] = []
var derivative_controls: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY HORIZON BENCH: " + label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
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
	var lower_counts: Dictionary={}
	for lower_proof: Dictionary in fixture.assets.values():
		if str(lower_proof.role)!="body_lod":continue
		var lower: Node3D=(load("res://"+str(lower_proof.asset).trim_prefix("game/")) as PackedScene).instantiate()
		for part: Dictionary in lower_proof.parts:
			check(not lower_counts.has(str(part.name)),"replacement part appears in only one block: "+str(part.name))
			lower_counts[str(part.name)]=int(part.triangles)
		var low_seen:=0
		for part: MeshInstance3D in lower.find_children("*","MeshInstance3D",true,false):
			metrics._check_cap_mapping(part.mesh,true)
			check(lower_counts.has(str(part.name)) and part.mesh.surface_get_array_index_len(0)==int(lower_counts.get(str(part.name),-1))*3,"actual complete imported industrial replacement: "+str(part.name))
			low_seen+=1
		check(low_seen==lower_proof.parts.size() and low_seen>0,"nonempty complete industrial replacement block roster")
		lower.free()
	var industrial_parts:=0
	for model: Node3D in horizon.get_children():
		for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			bodies[(draw.get_node("HorizonCollision") as StaticBody3D).get_rid()]=draw
			var identity := str(draw.get_meta("v2_city_horizon_building"))
			var box := draw.global_transform * draw.mesh.get_aabb()
			bounds[identity] = (bounds[identity] as AABB).merge(box) if bounds.has(identity) else box
			var key := str(model.name) + "/" + str(draw.name).split("__")[-1]
			var industrial: bool=draw.get_meta("v2_city_horizon_body_lod",false)
			if not mapped.has(key) or industrial:
				mapped[key] = true
				metrics._check_cap_mapping(draw.mesh, true)
			if industrial:
				industrial_parts+=1
				var surface:=RenderingServer.mesh_get_surface(draw.mesh.get_rid(),0)
				var lods: Array=surface.get("lods",[])
				var reduces: bool=int(lower_counts[str(draw.name)])*3<draw.mesh.surface_get_array_index_len(0)
				check(lods.size()==1 if reduces else lods.is_empty(),"authored replacement without automatic industrial tail: "+str(draw.name))
				var loaded: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
				if draw.has_meta("v2_window_source_material"):
					var optical := draw.material_override as ShaderMaterial
					var glazing := draw.get_meta("v2_window_source_material") as StandardMaterial3D
					check(optical != null and optical.shader == preload("res://shaders/v2_background_window_interior.gdshader"), "known background optical shader")
					if optical != null and glazing != null:
						for pair in [["albedo_tex", glazing.albedo_texture], ["rough_tex", glazing.roughness_texture], ["normal_tex", glazing.normal_texture]]:
							check(optical.get_shader_parameter(pair[0]) == pair[1], "optical glazing samples original catalogue map")
						check(optical.get_shader_parameter("physical_uv_scale") == Vector2(glazing.uv1_scale.x, glazing.uv1_scale.y), "optical glazing retains physical chart scale")
					loaded = glazing
				var stock:=loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
				check(stock!=null and not stock.uv1_triplanar,"industrial source-owned authored material: "+str(draw.name))
				if stock!=null:
					for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
						check(texture!=null and texture.get_image().has_mipmaps(),"actual loaded industrial PBR/mips: "+str(draw.name))
	check(industrial_parts==lower_counts.size(),"every industrial replacement part installed once")
	check(metrics.failures.is_empty(), "loaded metric charts and tangents across both asset/material families")
	# Reuse the reviewed scalar-double derivative implementation. Its detached
	# instance never enters the tree,so its survey/world _ready cannot run.
	var ground_metrics:=preload("res://tests/v2_city_western_street_review.gd").new()
	var derivative_targets:Array[Mesh]=[]
	var ground_parts := 0
	for draw: MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
		ground_parts += 1
		ground_metrics._check_cap_mapping(draw.mesh,true,true)
		if draw.mesh.resource_name in ["orison_ground_Court_soil_P34_N27","orison_ground_StreetCut_soil_P34_N4"]:derivative_targets.append(draw.mesh)
		var loaded := draw.material_override
		var material := loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
		check(material != null and not material.uv1_triplanar and not MatLib.is_shared_material(material),"local authored ground finish: "+str(draw.name))
		if material != null:
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				check(texture != null and texture.get_image().has_mipmaps(),"actual loaded ground PBR mip chain: "+str(draw.name))
	check(ground_parts>0 and ground_metrics.failures==0,"complete imported ground charts and derivatives")
	_ground_metric_negative_controls(derivative_targets)
	ground_metrics.free()
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
	var profiles: Dictionary={}
	for row: Dictionary in fixture.buildings:profiles[str(row.id)]=row
	for contact: Dictionary in fixture.parapet_contacts:
		var p: Array=contact.point
		var point:=Vector3(p[0],p[2],-p[1])
		var profile: Dictionary=profiles[str(contact.building)]
		var architecture: Dictionary=profile.get("architecture",{})
		var residential: bool=str(architecture.get("type",""))=="residential_front"
		var support:=point
		if residential:
			support.y=_residential_receiving_y(profile)
			check(is_finite(support.y),"receiving-wall schedule has a known authored roof construction")
			if not is_finite(support.y):continue
		for direction: float in [-1.,1.]:
			# A sheet rests on a receiving wall; it is not a parapet starting
			# at the sheet's top. Keep the original generic underside control.
			var at:=support if residential and direction<0. else point
			var ray_direction:=1. if residential else direction
			var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.025*ray_direction,at-Vector3.UP*.025*ray_direction,1)
			query.hit_back_faces=false
			var hit:=horizon.get_world_3d().direct_space_state.intersect_ray(query)
			var draw: MeshInstance3D=bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
			var expected_key: String=contact.wall_key if direction<0 else "galvanized_roof"
			check(draw!=null and str(draw.name)==str(contact.building)+"__"+expected_key and hit.position.distance_to(at)<.0001,"actual receiving wall/parapet and roof top: "+str(contact.building)+" "+expected_key+"; actual="+(str(draw.name) if draw!=null else "missing")+"; hit="+str(hit.get("position"))+"; expected="+str(at)+"; direction="+str(direction))
		if residential:
			# Independently reject a floating sheet: its underside must touch
			# the receiving plane, with the same front-face and 0.1 mm rule.
			var underside:=_roof_underside(horizon,bodies,support,str(contact.building))
			check(bool(underside.valid),"roof sheet underside meets its receiving wall: "+str(contact.building)+"; actual="+str(underside.actual)+"; hit="+str(underside.position)+"; expected="+str(support))
		var outside: Array=contact.outside_probe
		var probe:=Vector3(outside[0],outside[2],-outside[1])
		var query:=PhysicsRayQueryParameters3D.create(probe+Vector3.UP*.025,probe-Vector3.UP*.025,1)
		query.hit_back_faces=false
		var hit:=horizon.get_world_3d().direct_space_state.intersect_ray(query)
		var draw: MeshInstance3D=bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
		check(draw==null or str(draw.name)!=str(contact.building)+"__galvanized_roof","outside-wall control is not accepted as a structural roof bearing")
	await _roof_negative_controls(horizon,bodies,fixture,profiles)
	var eyes: Array[Vector3]=[]
	var excluded: Array[RID]=[]
	var view := preload("res://tests/v2_city_context_review.gd").capture_station(horizon.get_world_3d().direct_space_state,horizon,fixture.window_rows,bodies,eyes,excluded)
	check(not view.is_empty() and not view.get("retained_camera",true),"derived context camera has a genuine first-hit native pane")
	if OS.get_environment("CITY_STUDY_CAPTURE")=="1":await _study_reviews(fixture,horizon,ground)
	var retired_ground: WeakRef=weakref(ground)
	ground.free()
	var retired: WeakRef = weakref(horizon)
	horizon.free()
	await get_tree().physics_frame
	check(retired.get_ref()==null, "production horizon node retires")
	check(retired_ground.get_ref()==null,"production grade node retires")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file:=FileAccess.open(directory.path_join("family_outcome.json"),FileAccess.WRITE)
		check(file!=null,"write source-bound family diagnostic")
		if file!=null:
			file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Loaded family diagnostics and explicit mutations,not composed gameplay or runtime qualification","test_sha256":FileAccess.get_sha256(get_script().resource_path),"fixture_sha256":FileAccess.get_sha256("res://tests/fixtures/orison_city_horizon.json"),"checks":checks,"failures":failures,"roof_controls":roof_controls,"derivative_controls":derivative_controls},"\t"));file.close()
	print("CITY HORIZON BENCH: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _residential_receiving_y(profile:Dictionary)->float:
	var architecture:Dictionary=profile.get("architecture",{})
	var style:=str(architecture.get("style",""))
	# CivicRows overrides its inherited eave to the final floor plane. Only
	# the two pitched styles terminate the receiving walls one floor earlier.
	var flat:=style in ["italianate_2109","stone_2129","narrow_2141","neogrec_2122"]
	if not flat and style not in ["mansard_2153","gable_2136"]:return NAN
	var heights:Array=architecture.floor_heights_m
	var height:=float(profile.grade_datum_m)
	for index in (heights.size() if flat else heights.size()-1):height+=float(heights[index])
	return height

func _roof_underside(horizon:Node3D,bodies:Dictionary,support:Vector3,identity:String)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(support-Vector3.UP*.025,support+Vector3.UP*.025,1)
	query.hit_back_faces=false
	var hit:=horizon.get_world_3d().direct_space_state.intersect_ray(query)
	var sheet:MeshInstance3D=bodies.get(hit.collider.get_rid()) if not hit.is_empty() else null
	return {"valid":sheet!=null and str(sheet.name)==identity+"__galvanized_roof" and hit.position.distance_to(support)<.0001,"actual":str(sheet.name) if sheet!=null else "missing","position":hit.get("position")}

func _roof_negative_controls(horizon:Node3D,bodies:Dictionary,fixture:Dictionary,profiles:Dictionary)->void:
	check(is_nan(_residential_receiving_y({"architecture":{"style":"unregistered_roof"}})),"unregistered roof construction is refused")
	var covered:Dictionary={}
	for contact:Dictionary in fixture.parapet_contacts:
		var profile:Dictionary=profiles[str(contact.building)]
		var architecture:Dictionary=profile.get("architecture",{})
		var style:=str(architecture.get("style",""))
		if style not in ["italianate_2109","stone_2129","narrow_2141","neogrec_2122"] or covered.has(style):continue
		covered[style]=true
		# Independent flat-sheet control: the native contact names its upper
		# plane; all four inspected flat constructors have a140mm sheet.
		var support:=Vector3(contact.point[0],float(contact.point[2])-.14,-float(contact.point[1]))
		var identity:=str(contact.building)
		check(bool(_roof_underside(horizon,bodies,support,identity).valid),"original flat roof is accepted before mutation: "+style)
		var roof:=horizon.find_child(identity+"__galvanized_roof",true,false) as MeshInstance3D
		check(roof!=null,"roof mutation has actual native stock: "+style)
		if roof==null:continue
		var body:=roof.get_node("HorizonCollision") as StaticBody3D
		var original_pose:=roof.transform
		var original_layer:=body.collision_layer
		roof.global_position+=Vector3.UP*.01
		await get_tree().physics_frame;await get_tree().physics_frame
		var displaced_rejected:=not bool(_roof_underside(horizon,bodies,support,identity).valid)
		check(displaced_rejected,"ten-millimetre floating roof is rejected at original100um tolerance: "+style)
		roof.transform=original_pose;body.collision_layer=0
		await get_tree().physics_frame;await get_tree().physics_frame
		var missing_rejected:=not bool(_roof_underside(horizon,bodies,support,identity).valid)
		check(missing_rejected,"missing roof collision is rejected: "+style)
		body.collision_layer=original_layer
		await get_tree().physics_frame;await get_tree().physics_frame
		var restored:=bool(_roof_underside(horizon,bodies,support,identity).valid) and roof.transform==original_pose and body.collision_layer==original_layer
		check(restored,"actual roof pose/collision restored exactly: "+style)
		roof_controls.append({"building":identity,"style":style,"displaced_rejected":displaced_rejected,"missing_rejected":missing_rejected,"restored":restored})
	check(covered.size()==4 and roof_controls.size()==4,"all four installed flat-roof styles exercise the real mutation controls")

func _ground_metric_negative_controls(targets:Array[Mesh])->void:
	check(targets.size()==2,"both originally flagged imported ground meshes are exercised")
	for source:Mesh in targets:
		var accepted:=preload("res://tests/v2_city_western_street_review.gd").new()
		accepted._check_cap_mapping(source,true,true)
		check(accepted.failures==0,"unchanged imported thin-triangle source passes scalar-double derivatives: "+source.resource_name)
		accepted.free()
		var rejected:Array[bool]=[]
		for mutation:String in ["opposite_handedness","collapsed_uv"]:
			var broken:=ArrayMesh.new();broken.resource_name=mutation+"_"+source.resource_name
			for surface in source.get_surface_count():
				var arrays:=source.surface_get_arrays(surface)
				if mutation=="opposite_handedness":
					var tangents:PackedFloat32Array=(arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
					for index in range(3,tangents.size(),4):tangents[index]=-tangents[index]
					arrays[Mesh.ARRAY_TANGENT]=tangents
				else:
					var uv:PackedVector2Array=(arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
					uv.fill(Vector2.ZERO);arrays[Mesh.ARRAY_TEX_UV]=uv
				broken.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var control:=preload("res://tests/v2_city_western_street_review.gd").new()
			control._check_cap_mapping(broken,true,true)
			var refused:bool=control.failures>0
			check(refused,"scalar-double derivative checker rejects "+mutation+": "+source.resource_name)
			rejected.append(refused);control.free()
		derivative_controls.append({"mesh":source.resource_name,"unchanged_source_accepted":true,"opposite_handedness_rejected":rejected[0],"collapsed_uv_rejected":rejected[1]})

func _study_reviews(fixture: Dictionary,horizon: Node3D,ground: Node3D) -> void:
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
	var chosen:=OS.get_environment("CITY_STUDY_IDS").split(",",false)
	var draws: Array=horizon.find_children("*","MeshInstance3D",true,false)
	var visibility: Dictionary={}
	for draw: MeshInstance3D in draws:visibility[draw]=draw.visible
	for row: Dictionary in fixture.buildings:
		if not row.has("architecture"):continue
		if not chosen.is_empty() and str(row.id) not in chosen:continue
		for draw: MeshInstance3D in draws:draw.visible=str(draw.name).begins_with(str(row.id)+"__")
		var r: Array=row.rect;var center: float=(r[0]+r[2])*.5
		var width: float=r[2]-r[0];var height:=float(row.height_m)
		camera.position=Vector3(center+width*.25,height*.55,r[3]+maxf(20,width*1.35))
		camera.look_at(Vector3(center,height*.48,r[3]-1))
		if str(row.architecture.get("type",""))=="industrial_front":
			var box:=AABB();var first:=true
			for draw: MeshInstance3D in draws:
				if not draw.visible:continue
				box=draw.global_transform*draw.get_aabb() if first else box.merge(draw.global_transform*draw.get_aabb())
				first=false
			check(not first,"nonempty full industrial optical view")
			var aim:=box.get_center();var direction:=Vector3(1.,.12,.18).normalized()
			camera.global_position=aim+direction*box.size.length()*.5/sin(deg_to_rad(camera.fov*.5))*1.25
			camera.look_at(aim)
		await get_tree().create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		var saved:=get_viewport().get_texture().get_image().save_png(directory.path_join(str(row.id)+".png"))
		check(saved==OK,"imported native-resolution study render saved: "+str(row.id));captures+=1
	check(captures>0,"nonempty imported study render roster")
	print("CITY STUDY RENDERS: ",captures,"; neutral bench lighting, no composed-world or played-access acceptance")
	for draw: MeshInstance3D in draws:draw.visible=bool(visibility[draw])
	if OS.get_environment("CITY_INDUSTRIAL_PROFILE")=="1":await _profile_industrial(horizon,ground,camera,fixture,directory)
	if OS.get_environment("CITY_INDUSTRIAL_ENTRY")=="1":await _industrial_passage(horizon,ground,fixture,directory)
	camera.free();sun.free();environment.free()

func _profile_sha(path: String) -> String:
	if path.get_extension() in ["gd","json","gdshader","gdshaderinc","import"]:
		return FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return FileAccess.get_sha256(path)

func _industrial_sources(horizon: Node3D) -> Dictionary:
	var paths: Dictionary={}
	for path: String in ["res://tests/v2_city_horizon_bench.gd","res://scripts/building/orison_v2_city_horizon.gd","res://scripts/building/orison_v2_city_transport.gd","res://scripts/building/orison_v2_native_faces.gd","res://scripts/building/orison_v2_owner_finishes.gd","res://scripts/material_library.gd","res://data/runtime_material_sets.json","res://data/orison_v2/exterior/city_horizon.json","res://tests/fixtures/orison_city_horizon.json"]:
		paths[path]=_profile_sha(path)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Horizon.FINISHES))
	for asset: String in Horizon.asset_paths(source):
		for path: String in [asset,asset+".import"]:paths[path]=_profile_sha(path)
	for draw: MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
		var loaded: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		var stock:=loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
		if stock==null:continue
		for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
			if texture==null or texture.resource_path.is_empty():continue
			for path: String in [texture.resource_path,texture.resource_path+".import"]:
				if not paths.has(path) and FileAccess.file_exists(path):paths[path]=_profile_sha(path)
	return paths

func _industrial_optics() -> Dictionary:
	var result: Dictionary={"campaign_minute":CampaignClock.new().absolute_minutes()}
	for node: Node in get_children():
		if node is DirectionalLight3D:
			result["sun:"+str(node.name)]={"transform":str(node.global_transform),"color":str(node.light_color),"energy":node.light_energy,"shadows":node.shadow_enabled}
		elif node is WorldEnvironment:
			var state: Environment=node.environment
			result["environment:"+str(node.name)]={"background":str(state.background_color),"mode":state.background_mode,"ambient_color":str(state.ambient_light_color),"ambient_energy":state.ambient_light_energy}
	return result

func _industrial_materials(horizon: Node3D) -> Dictionary:
	var result: Dictionary={}
	for draw: MeshInstance3D in horizon.find_children("*","MeshInstance3D",true,false):
		if not draw.get_meta("v2_city_horizon_body_lod",false):continue
		var loaded: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		var stock:=loaded.get_meta("v2_weather_source",loaded) as StandardMaterial3D
		if stock==null:continue
		var maps: Dictionary={}
		for channel: String in ["albedo","roughness","normal"]:
			var texture: Texture2D=stock.get(channel+"_texture")
			if texture==null:continue
			var pixels:=texture.get_image()
			maps[channel]={"path":texture.resource_path,"dimensions":[pixels.get_width(),pixels.get_height()],"format":pixels.get_format(),"has_mipmaps":pixels.has_mipmaps(),"mipmap_count":pixels.get_mipmap_count()}
		result[str(draw.name)]={"texture_filter":stock.texture_filter,"triplanar":stock.uv1_triplanar,"metallic":stock.metallic,"roughness":stock.roughness,"normal_scale":stock.normal_scale,"maps":maps}
	return result

func _profile_industrial(horizon: Node3D,ground: Node3D,camera: Camera3D,fixture: Dictionary,directory: String) -> void:
	var sources:=_industrial_sources(horizon)
	var visibility: Dictionary={}
	var draws: Array=horizon.find_children("*","MeshInstance3D",true,false)
	for draw: MeshInstance3D in draws:visibility[draw]=draw.visible
	var ground_visible:=ground.visible;ground.visible=false
	var viewport:=get_viewport();var threshold:=viewport.mesh_lod_threshold;var taa:=viewport.use_taa
	var vsync:=DisplayServer.window_get_vsync_mode();var cap:=Engine.max_fps
	viewport.use_taa=false;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	var observations: Array[Dictionary]=[];var transitions: Dictionary={};var seen:=0
	for profile: Dictionary in fixture.buildings:
		if str(profile.get("architecture",{}).get("type",""))!="industrial_front":continue
		var identity:=str(profile.id);seen+=1
		var bounds:=AABB();var first:=true
		for draw: MeshInstance3D in draws:
			draw.visible=str(draw.name).begins_with(identity+"__")
			if draw.visible:
				bounds=draw.global_transform*draw.get_aabb() if first else bounds.merge(draw.global_transform*draw.get_aabb())
				first=false
		check(not first,"profile includes full authored industrial body: "+identity)
		var center:=bounds.get_center();var direction:=Vector3(1.,.12,.18).normalized()
		camera.fov=75.;camera.far=20000.
		camera.global_position=center+direction*bounds.size.length()*.5/sin(deg_to_rad(37.5))*1.25;camera.look_at(center)
		var family_rows: Array[Dictionary]=[]
		for spec: Dictionary in [{"id":"near","threshold":0.},{"id":"far","threshold":10000.},{"id":"natural","threshold":1.},{"id":"far_repeat","threshold":10000.},{"id":"near_repeat","threshold":0.}]:
			viewport.mesh_lod_threshold=float(spec.threshold)
			for frame in 12:await RenderingServer.frame_post_draw
			var samples: Array[Dictionary]=[];var previous:=Time.get_ticks_usec()
			for frame in 90:
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				samples.append({"wall_ms":(now-previous)/1000.,"viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())});previous=now
			var row: Dictionary={"building":identity,"id":spec.id,"threshold":spec.threshold,"frame_samples":samples,"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}
			family_rows.append(row);observations.append(row)
			if str(spec.id) in ["near","far"]:check(viewport.get_texture().get_image().save_png(directory.path_join(identity+"_profile_"+str(spec.id)+".png"))==OK,"industrial complete-body profile capture saved")
		check(int(family_rows[1].primitives)<int(family_rows[0].primitives),"actual industrial complete replacement reduces indices: "+identity)
		transitions[identity]=await _profile_natural(horizon,camera,draws,identity,str(profile.wall_key),directory)
	check(seen==3,"three explicitly authored industrial studies execute")
	for draw: MeshInstance3D in draws:draw.visible=bool(visibility[draw])
	ground.visible=ground_visible
	check(sources==_industrial_sources(horizon),"industrial loaded sources unchanged through measured frames")
	var record: Dictionary={"evidence_class":"INERT","scope":"Isolated current imported industrial bodies,90 warmed uncapped frames per case,repeated near/far and actual material-body LOD transitions. No matched baseline,wholeworld performance,played access or artistic acceptance. Ground hidden for isolated body timings;captures excluded from timing windows.","observations":observations,"natural_transitions":transitions,"loaded_materials":_industrial_materials(horizon),"source_hashes":sources,"checks":checks,"failures":failures,"settings":{"resolution":str(viewport.get_visible_rect().size),"msaa":viewport.msaa_3d,"taa":viewport.use_taa,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps}}
	var file:=FileAccess.open(directory.path_join("city_industrial_profile.json"),FileAccess.WRITE)
	check(file!=null,"industrial rendering diagnostic opens")
	if file!=null:
		file.store_string(JSON.stringify(record,"\t")+"\n")
		file.close()
	viewport.mesh_lod_threshold=threshold;viewport.use_taa=taa;DisplayServer.window_set_vsync_mode(vsync);Engine.max_fps=cap

func _drive_industrial(player: PlayerController,target_x: float,samples: Array) -> void:
	var direction:=signf(target_x-player.global_position.x)
	var action:="move_forward" if direction*(-player.global_basis.z.x)>0. else "move_back"
	Input.action_press(action)
	for frame in 900:
		await get_tree().physics_frame
		samples.append({"position":[player.global_position.x,player.global_position.y,player.global_position.z],"on_floor":player.is_on_floor(),"noclip":player.noclip})
		var remaining:=target_x-player.global_position.x
		if absf(remaining)<.025 or signf(remaining)!=direction:break
	Input.action_release(action)
	for frame in 12:await get_tree().physics_frame
	check(absf(player.global_position.x-target_x)<.08,"normal-input industrial passage target reached")

func _industrial_passage(horizon: Node3D,ground: Node3D,fixture: Dictionary,directory: String) -> void:
	var first_check:=checks;var first_failure:=failures.size()
	var portal: Dictionary={};var datum:=0.
	for study: Dictionary in fixture.industrial_checks:
		for entry: Dictionary in study.entries:
			if str(entry.kind)=="open_annex_passage":portal=entry
	check(not portal.is_empty(),"source-fitted open office-annex passage exists")
	if portal.is_empty():return
	for row: Dictionary in fixture.buildings:
		if str(row.id)==str(portal.building):datum=float(row.grade_datum_m)
	var p: Array=portal.point;var n: Array=portal.normal
	var front:=Vector3(p[0],datum+p[2],-p[1]);var outward:=Vector3(n[0],n[2],-n[1])
	check(outward.is_equal_approx(Vector3.RIGHT),"surveyed industrial passage faces the existing block along positive localX")
	var sources:=_industrial_entry_sources(horizon,ground)
	var player:=PlayerController.new();player.position=front+outward*2.5+Vector3.UP*.03
	add_child(player);player.look_at(player.global_position-outward,Vector3.UP);player.set_lamp_enabled(false);player.camera.make_current()
	for frame in 30:await get_tree().physics_frame
	check(player.is_on_floor() and absf(player.global_position.y-(datum-.02))<.002,"actual apron supports the standing approach")
	check(is_equal_approx(player._capsule.height,1.524) and is_equal_approx(player._capsule.radius,.33),"unmodified production standing capsule")
	var stages: Array=[];var samples: Array=[]
	for spec: Dictionary in [{"id":"middle","x":front.x-float(portal.depth_m)*.5,"foot":datum},{"id":"far_approach","x":front.x-float(portal.depth_m)-2.5,"foot":datum-.02},{"id":"return","x":front.x+2.5,"foot":datum-.02}]:
		await _drive_industrial(player,float(spec.x),samples)
		var at:=player.global_position
		check(player.is_on_floor() and absf(at.y-float(spec.foot))<.002,"continuous actual passage floor/approach: "+str(spec.id))
		check(absf(at.z-front.z)<.01,"full capsule remains inside measured passage corridor")
		stages.append({"id":spec.id,"position":[at.x,at.y,at.z]})
		for frame in 2:await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("industrial_passage_"+str(spec.id)+".png"))==OK,"actual standing passage eye saved")
	check(not player.noclip and not player._profile_disable_step_guard and not player._profile_disable_step_up,"passage retains gravity,collision and both production step guards")
	check(sources==_industrial_entry_sources(horizon,ground),"passage rendering/controller/ground inputs remain frozen")
	var record: Dictionary={"evidence_class":"INERT","scope":"Isolated actual production-controller roundtrip through the authored annex and retained ground;one initial placement,normal input thereafter,no rescue/noclip/step overrides. No occupied-world actors,authority,save or artistic acceptance.","building":portal.building,"checks":checks-first_check,"failures":failures.slice(first_failure),"stages":stages,"movement_samples":samples,"source_hashes":sources}
	var file:=FileAccess.open(directory.path_join("industrial_passage_diagnostic.json"),FileAccess.WRITE)
	check(file!=null,"passage diagnostic opens")
	if file!=null:file.store_string(JSON.stringify(record,"\t"))
	player.free()

func _industrial_entry_sources(horizon: Node3D,ground: Node3D) -> Dictionary:
	var sources:=_industrial_sources(horizon);sources.merge(_industrial_sources(ground),true)
	for path: String in ["res://scripts/player/player_controller.gd","res://scripts/building/orison_v2_ground.gd","res://data/orison_v2/ground_finish.json","res://data/orison_v2/exterior/city_ground_relief.json","res://assets/props/orison_ground.glb","res://assets/props/orison_ground.glb.import","res://assets/props/city_ground_apron.glb","res://assets/props/city_ground_apron.glb.import"]:sources[path]=_profile_sha(path)
	return sources

func _profile_probe(camera: Camera3D,center: Vector3,direction: Vector3,distance_m: float) -> Dictionary:
	camera.global_position=center+direction*distance_m
	camera.look_at(center)
	for frame in 4:await RenderingServer.frame_post_draw
	var viewport:=get_viewport()
	return {"distance_m":distance_m,"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}

func _profile_natural(_city: Node3D,camera: Camera3D,draws: Array,identity: String,key: String,directory: String) -> Dictionary:
	var focus: MeshInstance3D=null
	for draw: MeshInstance3D in draws:
		draw.visible=str(draw.name)==identity+"__"+key
		if draw.visible:focus=draw
	check(focus!=null,"industrial body material exists for natural LOD: "+identity)
	if focus==null:return {}
	var arrays: Array=focus.mesh.surface_get_arrays(0)
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var direction:=Vector3(1.,.12,.18).normalized()
	var bounds:=focus.get_aabb()
	var center:=focus.global_transform*bounds.get_center()
	var best:=INF
	for i in range(0,indices.size(),3):
		var a: int=indices[i];var b: int=indices[i+1];var c: int=indices[i+2]
		var area: float=(points[b]-points[a]).cross(points[c]-points[a]).length()*.5
		var normal: Vector3=(focus.global_basis*(normals[a]+normals[b]+normals[c])).normalized()
		if area<.2 or normal.dot(direction)<.5:continue
		var local_point: Vector3=(points[a]+points[b]+points[c])/3.
		var distance_sq: float=local_point.distance_squared_to(bounds.get_center())
		if distance_sq<best:
			best=distance_sq
			center=focus.global_transform*local_point
	check(is_finite(best),"natural LOD aims at broad actual surface stock: "+identity)
	var radius:=0.
	for corner in 8:radius=maxf(radius,center.distance_to(focus.global_transform*bounds.get_endpoint(corner)))
	camera.fov=75.;get_viewport().mesh_lod_threshold=1.
	var start:=maxf(2.,radius/sin(deg_to_rad(camera.fov*.5))*1.25)
	var probes: Array[Dictionary]=[]
	var before: Dictionary={};var after: Dictionary={}
	for i in 12:
		var row:=await _profile_probe(camera,center,direction,start*pow(1.5,i))
		probes.append(row)
		check(int(row.draws)==1 and int(row.primitives)>0,"natural probe retains complete isolated body part: "+identity)
		if not before.is_empty() and int(row.primitives)<int(before.primitives):after=row;break
		before=row
	check(not after.is_empty(),"actual distance selects a replacement body LOD: "+identity)
	var images: Array[Dictionary]=[]
	var controls: Array[Dictionary]=[]
	if not after.is_empty():
		for i in 12:
			var row:=await _profile_probe(camera,center,direction,(float(before.distance_m)+float(after.distance_m))*.5)
			if int(row.primitives)==int(before.primitives):before=row
			else:after=row
		check(int(after.primitives)<int(before.primitives),"bisected natural bracket retains an actual index reduction: "+identity)
		for spec: Dictionary in [{"id":"before","distance":before.distance_m,"fov":75.,"minimum":before.primitives},{"id":"after","distance":after.distance_m,"fov":75.,"minimum":after.primitives},{"id":"narrow","distance":after.distance_m,"fov":5.,"minimum":before.primitives},{"id":"return","distance":before.distance_m,"fov":75.,"minimum":before.primitives}]:
			camera.fov=float(spec.fov)
			var row:=await _profile_probe(camera,center,direction,float(spec.distance))
			var expected:=int(row.primitives)>=int(spec.minimum) if str(spec.id)=="narrow" else int(row.primitives)==int(spec.minimum)
			check(int(row.draws)==1 and expected,"natural transition, narrow optical recovery and inward return: "+identity+"/"+str(spec.id))
			var frame:=get_viewport().get_texture().get_image()
			var pose:=camera.global_transform;var fov:=camera.fov;var optics:=_industrial_optics()
			focus.visible=false
			for tick in 4:await RenderingServer.frame_post_draw
			var negative:=get_viewport().get_texture().get_image()
			check(camera.global_transform.is_equal_approx(pose) and is_equal_approx(camera.fov,fov),"hidden-target optical control retains the same camera pose and FOV")
			check(optics==_industrial_optics(),"hidden-target optical control retains the same campaign clock and fixed bench lighting")
			var background:=negative.get_pixel(negative.get_width()/2,negative.get_height()/2)
			var corner:=negative.get_pixel(0,0)
			check(Vector3(background.r-corner.r,background.g-corner.g,background.b-corner.b).length()<.00001,"hidden-target optical control contains uniform fixed bench background")
			var control_file:=identity+"_natural_"+str(spec.id)+"_background.png"
			check(negative.save_png(directory.path_join(control_file))==OK,"same-pose hidden-target background control saved")
			controls.append({"id":spec.id,"file":control_file,"distance_m":spec.distance,"fov":fov,"background_rgb":[background.r,background.g,background.b],"optics":optics})
			focus.visible=true
			var pixel:=frame.get_pixel(frame.get_width()/2,frame.get_height()/2)
			var contrast:=Vector3(pixel.r-background.r,pixel.g-background.g,pixel.b-background.b).length()
			check(contrast>.02,"physical structural stock remains at image center: "+identity+"/"+str(spec.id))
			row["file"]=identity+"_natural_"+str(spec.id)+".png";row["fov"]=camera.fov;row["center_contrast"]=contrast
			check(frame.save_png(directory.path_join(str(row.file)))==OK,"natural industrial image saved")
			images.append(row)
	return {"part":str(focus.name),"scope":"One whole material body part, default pixel threshold1, bisected first observed distance reduction, narrow-FOV recovery and inward return. Same-pose hidden-target background controls use fixed bench lighting with no weather or campaign clock. Not a whole-building/world LOD or artistic acceptance.","before":before,"after":after,"probes":probes,"images":images,"hidden_target_controls":controls}
