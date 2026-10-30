extends Node3D
## Imported isolated station diagnostics. This does not qualify the composed city.
var failures: Array[String] = []
var checks := 0
var observations: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("TRANSPORT BENCH: " + label)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled = false
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "writable diagnostic output directory")
	var family := OS.get_environment("CITY_BENCH_FAMILY")
	if family.is_empty(): family = "city_transport"
	assert(family in ["city_transport", "city_streets"])
	var bench_scope:=OS.get_environment("CITY_BENCH_SCOPE")
	if bench_scope.is_empty():bench_scope="all"
	if bench_scope not in ["all","hampton"] or (bench_scope=="hampton" and family!="city_streets"):
		push_error("Unknown or incompatible CITY_BENCH_SCOPE: "+bench_scope)
		get_tree().quit(64);return
	var initial_sources := _bench_sources(family)
	var mount_started := Time.get_ticks_usec()
	var station: Node3D = preload("res://scripts/building/orison_v2_city_streets.gd").mount(self) if family == "city_streets" else preload("res://scripts/building/orison_v2_city_transport.gd").mount(self)
	var mount_ms := (Time.get_ticks_usec() - mount_started) / 1000.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/"+family+".json"))
	if family == "city_streets":
		for frame in 3: await get_tree().physics_frame
		for reference: Array in [[-92.,-.9855],[-69.6,-.6495],[-32.3,-.09],[-28.3,-.04],[-24.3,-.01],[-20.3,0.],[0.,0.],[68.8,0.],[114.,0.]]:
			var x := float(reference[0]); var grade := float(reference[1])
			check(is_equal_approx(preload("res://scripts/building/orison_v2_city_streets.gd").surface_height(x),grade), "authored grade anchor " + str(x))
			# The isolated family omits the retained central road. Its existing
			# owner is exercised in the composed route, not a fabricated bench floor.
			if x > -92. and (x < -20.3 or x > 20.8):
				var query := PhysicsRayQueryParameters3D.create(Vector3(x,1.,19.3),Vector3(x,-2.5,19.3))
				var hit := get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and absf(float(hit.position.y)-(grade-.1))<.002, "loaded graded carriageway collision " + str(x))
		if bench_scope=="hampton":
			for point: Array in [[-75.4,24.8,-.7365],[-75.4,25.2,-.7365],[-75.4,26.6,-.7365],[-93.7,26.6,-1.011],[-80.3,26.6,-.81],[-65.,26.6,-.5805],[ -80.,27.74,-.67125],[-80.,28.02,-.537],[-80.,28.30,-.40275],[-80.,28.58,-.2685],[-80.,28.86,-.13425],[-80.,29.5,0.]]:
				var query:=PhysicsRayQueryParameters3D.create(Vector3(float(point[0]),1.,-float(point[1])),Vector3(float(point[0]),-2.5,-float(point[1])),1)
				var hit:=get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty() and absf(float(hit.position.y)-float(point[2]))<.0001 and hit.normal.y>.99,"actual Hampton public floor/tread station "+str(point))
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var low_source := (load("res://assets/props/"+family+"_lod1.glb") as PackedScene).instantiate()
	var low_counts: Dictionary = {}
	for draw: MeshInstance3D in low_source.find_children("*", "MeshInstance3D", true, false):
		metrics._check_cap_mapping(draw.mesh, true)
		low_counts[str(draw.name)] = draw.mesh.surface_get_array_index_len(0)
	low_source.free()
	var parts := 0
	var lod_parts := 0
	var focus: MeshInstance3D
	var transition_focus: MeshInstance3D
	var hampton_parts: Array[String]=[]
	for draw: MeshInstance3D in station.find_children("*", "MeshInstance3D", true, false):
		parts += 1
		var mesh := draw.mesh as ArrayMesh
		var surface := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
		var lods: Array = surface.get("lods", [])
		var replacement_reduces := int(low_counts[str(draw.name).replace("_L0__", "_L1__")]) < mesh.surface_get_array_index_len(0)
		check((lods.size() == 1 and is_equal_approx(float(lods[0].edge_length), float(data.lod_error_m))) if replacement_reduces else lods.is_empty(), "replacement LOD where it reduces geometry: " + str(draw.name))
		if replacement_reduces: lod_parts += 1
		if replacement_reduces and (transition_focus == null or draw.get_aabb().size.length() < transition_focus.get_aabb().size.length()): transition_focus = draw
		if str(draw.name).begins_with("Street_Hampton_"):hampton_parts.append(str(draw.name))
		if family == "city_streets" and replacement_reduces and str(draw.name).ends_with("__walk") and focus == null and (bench_scope!="hampton" or str(draw.name).begins_with("Street_Hampton_")): focus = draw
		metrics._check_cap_mapping(mesh, true)
		var loaded := draw.material_override
		var material := loaded.get_meta("v2_weather_source", loaded) as StandardMaterial3D
		check(material != null and not MatLib.is_shared_material(material) and not material.uv1_triplanar, "local authored UV finish: " + str(draw.name))
		var alias := str(draw.name).split("__")[-1]
		for finish: Dictionary in data.finishes:
			if str(finish.alias) == alias and finish.has("metallic"):
				check(is_equal_approx(material.metallic, float(finish.metallic)), "loaded coating/substrate metallic response: " + str(draw.name))
		if family == "city_streets": check(loaded is ShaderMaterial and is_equal_approx(float(loaded.get_shader_parameter("weather_exposure")),1.), "existing exterior weather adapter is bound: " + str(draw.name))
		for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
			check(texture != null and texture.get_image().has_mipmaps(), "loaded PBR mip chain: " + str(draw.name))
		var shape := draw.get_node("SourceCollision/NearSurface") as CollisionShape3D
		check((shape.shape as ConcavePolygonShape3D).get_faces() == mesh.get_faces(), "near-only visible collision: " + str(draw.name))
	check(parts == data.parts.size() and parts > 0, "nonempty source roster")
	check(lod_parts > 0, "nonempty replacement body roster")
	if bench_scope=="hampton":
		hampton_parts.sort()
		check(hampton_parts==["Street_Hampton_-5_L0__curb","Street_Hampton_-5_L0__walk","Street_Hampton_-6_L0__walk"],"three explicit loaded public-footway and stoop partitions")
		transition_focus=focus
	check(metrics.failures.is_empty(), "imported metre charts and tangent metrics: " + str(metrics.failures))
	metrics.free()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.24, .3, .36)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7, .8, 1.)
	environment.environment.ambient_light_energy = .7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 2.
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var target := Vector3(65, 9, 10)
	camera.position = Vector3(65, 90, 240)
	camera.look_at(target)
	var viewport := get_viewport()
	var original_threshold := viewport.mesh_lod_threshold
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for row: Dictionary in [{"id":"forced_near", "threshold":0., "fov":75.}, {"id":"forced_far", "threshold":10000., "fov":75.}, {"id":"wide", "threshold":1., "fov":75.}, {"id":"narrow", "threshold":1., "fov":5.}, {"id":"forced_far_repeat", "threshold":10000., "fov":75.}, {"id":"forced_near_repeat", "threshold":0., "fov":75.}]:
		var focused := family == "city_streets" and str(row.id) in ["wide", "narrow"]
		if family == "city_streets":
			for draw: MeshInstance3D in station.find_children("*", "MeshInstance3D", true, false): draw.visible = (draw==focus) if focused else (bench_scope!="hampton" or str(draw.name).begins_with("Street_Hampton_"))
			if focused:
				assert(focus != null)
				var center := focus.global_transform * focus.get_aabb().get_center()
				camera.position = center + Vector3(0,60,280)
				camera.look_at(center)
			else:
				camera.position = Vector3(-80,8,-1) if bench_scope=="hampton" else Vector3(0,65,220)
				camera.look_at(Vector3(-80,-.4,-27) if bench_scope=="hampton" else Vector3(0,0,17))
		viewport.mesh_lod_threshold = float(row.threshold)
		camera.fov = float(row.fov)
		for frame in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var times: Array = []
		var previous := Time.get_ticks_usec()
		for frame in 90:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			times.append({"wall_ms":(now-previous)/1000.,"viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())})
			previous = now
		var primitives := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var calls := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		observations.append({"id":row.id,"fov":camera.fov,"lod_threshold":viewport.mesh_lod_threshold,"visible_primitives":primitives,"visible_draw_calls":calls,"resolution":str(viewport.get_visible_rect().size),"frame_samples":times,"focused_lod_part":str(focus.name) if focused else "whole family"})
		var out := OS.get_environment("SHOT_DIR")
		if not out.is_empty() and not str(row.id).ends_with("_repeat"):
			check(viewport.get_texture().get_image().save_png(out.path_join(str(row.id)+".png")) == OK, "render saved: " + str(row.id))
	check(int(observations[1].visible_primitives) < int(observations[0].visible_primitives), "forced far actually renders fewer triangles")
	check(int(observations[3].visible_primitives) > int(observations[2].visible_primitives), "narrow FOV selects more detail at the same distance")
	var transitions: Dictionary = await _natural_transitions(station,camera,transition_focus,low_counts,directory)
	viewport.mesh_lod_threshold = 1.
	camera.fov = 72.
	var views: Array = [{"id":"public_stair", "eye":Vector3(27, 1.41, -8), "target":Vector3(35, 3.3, -5)}, {"id":"lower_platform", "eye":Vector3(45, 12.79, 20), "target":Vector3(86, 12.38, 20)}]
	if family == "city_streets": views = [{"id":"east_crossing", "eye":Vector3(68.8,1.41,30), "target":Vector3(69,0,9)}, {"id":"curb_grazing", "eye":Vector3(-55,.45,16), "target":Vector3(-65,0,14.75)}]
	if bench_scope=="hampton":views=[{"id":"hampton_public_footway","eye":Vector3(-100,7,-18),"target":Vector3(-80,0,-27)},{"id":"hampton_level_stoop","eye":Vector3(-83,1.4,-24),"target":Vector3(-80,-.2,-29)}]
	for view: Dictionary in views:
		camera.position = view.eye
		camera.look_at(view.target)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(directory.path_join(str(view.id)+".png")) == OK, "near finish inspection capture: " + str(view.id))
	viewport.mesh_lod_threshold = original_threshold
	var output := OS.get_environment("SHOT_DIR")
	var sources := _bench_sources(family)
	check(initial_sources == sources, "executed benchmark sources remain frozen")
	var file: FileAccess
	if not output.is_empty():
		file = FileAccess.open(output.path_join("transport_bench.json"), FileAccess.WRITE)
		check(file != null, "diagnostic record opens")
	var result := {"evidence_class":"INERT", "scope":"Isolated imported geometry, collision, PBR maps, per-view LOD and repeated uncapped 90-frame viewport timings after warmup. Timings exclude captures. No composed route, whole-world performance or artistic acceptance.", "checks":checks,"failures":failures,"observations":observations,"source_hashes":sources,"draw_parts":parts,"replacement_parts":lod_parts,"mount_cpu_ms":mount_ms,"settings":{"msaa":viewport.msaa_3d,"taa":viewport.use_taa,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}}
	result["family"] = family
	result["bench_scope"]=bench_scope
	result["natural_transitions"] = transitions
	if file != null:
		file.store_string(JSON.stringify(result,"\t")+"\n")
		file.close()
	station.free()
	await get_tree().process_frame
	print("TRANSPORT BENCH: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _natural_probe(camera: Camera3D, center: Vector3, direction: Vector3, distance_m: float) -> Dictionary:
	camera.position = center+direction*distance_m
	camera.look_at(center)
	for frame in 4: await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	return {"distance_m":distance_m,"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draws":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}

func _natural_transitions(station: Node3D,camera: Camera3D,focus: MeshInstance3D,low_counts: Dictionary,directory: String) -> Dictionary:
	check(focus != null,"a reducing body is available for natural-distance LOD inspection")
	if focus == null: return {}
	for draw: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false): draw.visible = draw == focus
	var direction := Vector3(.3,.6,1.).normalized()
	var arrays: Array = focus.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bounds: AABB = focus.get_aabb()
	var center: Vector3 = focus.global_transform*bounds.get_center()
	var best := INF
	# A material partition can contain separated curbs or tracks. Its AABB
	# centre need not be physical stock, especially through a narrow lens.
	for i in range(0,indices.size(),3):
		var a: int=indices[i];var b: int=indices[i+1];var c: int=indices[i+2]
		var normal: Vector3=(focus.global_basis*(normals[a]+normals[b]+normals[c])).normalized()
		if normal.dot(direction)<=.05: continue
		var local_point: Vector3=(points[a]+points[b]+points[c])/3.
		var distance_sq: float=local_point.distance_squared_to(bounds.get_center())
		if distance_sq<best:
			best=distance_sq;center=focus.global_transform*local_point
	check(is_finite(best),"natural optical target is an actual camera-facing native triangle")
	var radius := 0.
	for i in 8: radius=maxf(radius,center.distance_to(focus.global_transform*bounds.get_endpoint(i)))
	camera.fov = 75.
	camera.far = 20000.
	var start := maxf(2.,radius/sin(deg_to_rad(camera.fov*.5))*1.2)
	var near_count: int = focus.mesh.surface_get_array_index_len(0)/3
	var far_count: int = int(low_counts[str(focus.name).replace("_L0__","_L1__")])/3
	var viewport := get_viewport()
	viewport.mesh_lod_threshold = 1.
	var rows: Array[Dictionary] = []
	var last_near := 0.
	var first_far := 0.
	var background := Color.BLACK
	for i in 24:
		var row: Dictionary = await _natural_probe(camera,center,direction,start*pow(1.4,i))
		if i==0: background=viewport.get_texture().get_image().get_pixel(0,0)
		rows.append(row)
		check(int(row.draws)==1 and int(row.primitives) in [near_count,far_count],"natural-distance probe keeps the complete isolated body in view")
		if int(row.primitives)==near_count: last_near=float(row.distance_m)
		elif int(row.primitives)==far_count:
			first_far=float(row.distance_m)
			break
	check(last_near>0. and first_far>last_near,"default pixel threshold switches a complete body as distance increases")
	var images: Array[Dictionary] = []
	if last_near>0. and first_far>last_near:
		for i in 16:
			var distance_m := (last_near+first_far)*.5
			var row: Dictionary = await _natural_probe(camera,center,direction,distance_m)
			rows.append(row)
			check(int(row.draws)==1 and int(row.primitives) in [near_count,far_count],"transition bracket contains complete near or replacement indices")
			if int(row.primitives)==near_count: last_near=distance_m
			else: first_far=distance_m
		for spec: Dictionary in [{"id":"natural_before","distance_m":last_near,"fov":75.,"expected":near_count},{"id":"natural_after","distance_m":first_far,"fov":75.,"expected":far_count},{"id":"natural_narrow","distance_m":first_far,"fov":5.,"expected":near_count},{"id":"natural_return","distance_m":last_near,"fov":75.,"expected":near_count}]:
			camera.fov=float(spec.fov)
			var row: Dictionary = await _natural_probe(camera,center,direction,float(spec.distance_m))
			check(int(row.primitives)==int(spec.expected),"actual natural transition, optical detail and inward return: "+str(spec.id))
			row["file"]=str(spec.id)+".png";row["fov"]=camera.fov
			var frame: Image=viewport.get_texture().get_image()
			var pixel: Color=frame.get_pixel(frame.get_width()/2,frame.get_height()/2)
			var coverage: float=Vector3(pixel.r-background.r,pixel.g-background.g,pixel.b-background.b).length()
			check(coverage>.02,"actual physical stock covers the transition image centre: "+str(spec.id))
			row["centre_background_contrast"]=coverage
			check(frame.save_png(directory.path_join(str(row.file)))==OK,"natural transition capture saved: "+str(spec.id))
			images.append(row)
	for draw: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false): draw.visible=true
	return {"scope":"Actual rendered complete body at default pixel threshold1, increasing distance, bisected switch bracket, narrow-FOV near recovery at the far pose, and inward return. Physical triangle aim and rendered centre coverage required. Isolated representative body; no whole-family/world transition or artistic acceptance.","part":str(focus.name),"physical_aim_world":[center.x,center.y,center.z],"near_triangles":near_count,"far_triangles":far_count,"pixel_threshold":1.,"last_near_distance_m":last_near,"first_far_distance_m":first_far,"probes":rows,"images":images}

func _bench_sources(family: String) -> Dictionary:
	var sources: Dictionary = {}
	for path: String in ["res://tests/v2_city_transport_bench.gd", "res://scripts/building/orison_v2_city_transport.gd", "res://scripts/building/orison_v2_"+family+".gd", "res://assets/props/"+family+".glb", "res://assets/props/"+family+"_lod1.glb", "res://data/orison_v2/exterior/"+family+".json", "res://data/runtime_material_sets.json", "res://scripts/material_library.gd", "res://scripts/building/surface_pass.gd", "res://shaders/orison_surface.gdshader"]:
		sources[path] = FileAccess.get_sha256(path)
	return sources
