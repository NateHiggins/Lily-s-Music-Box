extends Node
## INERT review capture of the V2 street lamps (design/V2_STREET_LAMPS_2026-10-24.md).
## Windowed only. Checks the posts, the retired placeholders, the moved
## authored lights and the finishes, then captures the street at night. Not
## runtime proof and no acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
const Lamps := preload("res://scripts/building/orison_v2_street_lamps.gd")
var directory: String
var world: OrisonV2RuntimeRoot
var failures := 0
var summary := {"checks": [], "captures": []}

class BenchStreet extends RefCounted:
	var street: Node3D
	func instance_node(_identity: String) -> Node3D: return street

class BenchHost extends Node3D:
	var exterior_cell := BenchStreet.new()


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	summary.checks.append({"label": label, "ok": ok})
	print("STREET LAMP CHECK: ", label, " = ", ok)


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" \
			or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Street lamp review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	var scope := OS.get_environment("ORISON_STREET_LAMP_SCOPE")
	if scope == "isolated":
		await _isolated()
		return
	if not scope.is_empty():
		push_error("Unknown ORISON_STREET_LAMP_SCOPE: " + scope)
		get_tree().quit(64);return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 20, 1260)
	Selector.reset_for_tests("v2")
	world = (load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.startup_failed:
		push_error("Production world failed")
		get_tree().quit(1)
		return
	await _review()
	var file := FileAccess.open(directory.path_join("street_lamps_review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, " ", false) + "\n")
	file.close()
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("STREET LAMP REVIEW: %d failures; no acceptance grant" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _review() -> void:
	var data := Lamps.load_table()
	var street := world.exterior_cell.instance_node(str(data.street_instance))
	var root := street.get_node_or_null("StreetLamps") as Node3D
	check(root != null, "production V2 mounts the street lamps in the street frame")
	if root == null:
		return
	var globe: Array = data.globe_local
	for lamp: Dictionary in data.lamps:
		var post := root.get_node_or_null(str(lamp.id)) as MeshInstance3D
		check(post != null and post.visible, "post stands: " + str(lamp.id))
		if post == null:
			continue
		var ok := true
		for surface in post.mesh.get_surface_count():
			var mat := post.mesh.surface_get_material(surface) as StandardMaterial3D
			ok = ok and mat != null and not mat.uv1_triplanar and mat.albedo_texture != null \
					and mat.normal_texture != null and mat.roughness_texture != null and mat.normal_enabled \
					and post.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV] != null \
					and mat.albedo_texture.get_image().has_mipmaps()
		check(ok, "every lamp surface samples authored UVs with catalogue maps and mips: " + str(lamp.id))
		for draw: MeshInstance3D in post.get_meta("original_draws", []):
			check(not draw.visible, "placeholder retired: " + str(draw.get_meta("authored_record_id", "")))
		var want := street.to_global(post.transform * Vector3(globe[0], globe[1], globe[2]))
		var found := false
		for light: OmniLight3D in street.find_children("*", "OmniLight3D", true, false):
			if light.global_position.distance_to(want) < 0.05:
				found = true
		check(found, "the lamp's light sits in its globe: " + str(lamp.id))

	var clock := root.get_node_or_null("LampClock")
	check(clock != null, "the lamps keep their own clock")
	if clock != null:
		clock.clock_override = {"valid": true, "month": 11, "minute_of_day": 720.0}
		clock.refresh()
		var dark := true
		for light: OmniLight3D in clock.lights:
			dark = dark and not light.visible
		check(dark and clock.lit == 0.0, "street lamps are out at noon")
		clock.clock_override = {"valid": true, "month": 11, "minute_of_day": 1260.0}
		clock.refresh()
		var lit: bool = clock.lights.size() == (data.lamps as Array).size()
		for light: OmniLight3D in clock.lights:
			lit = lit and light.visible and light.light_energy > 0.0
		check(lit and clock.lit == 1.0, "and lit at nine at night")
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	var traffic := world.period_traffic as OrisonV2StreetTraffic
	if traffic != null:
		traffic.stage([{"id": "ice_wagon", "lane_west": true, "x": 1.0, "travel": 0.4},
				{"id": "model_a_tudor", "lane_west": false, "x": 10.0}])
	world.player.camera.make_current()
	await _view(street, "pavement_east", Vector3(-6.0, 1.62, 2.6), Vector3(12.0, 2.6, 5.0))
	await _view(street, "pavement_west", Vector3(19.0, 1.62, 2.8), Vector3(-6.0, 2.4, 6.0))
	await _view(street, "from_arcade_side", Vector3(-9.5, 1.62, 16.2), Vector3(2.0, 2.4, 6.0))
	await _view(street, "signal_box", Vector3(12.2, 1.6, 2.5), Vector3(13.3, 1.6, 4.1))
	await _view(street, "crook_and_globe", Vector3(5.6, 1.7, 2.2), Vector3(8.1, 3.9, 4.8))
	if traffic != null:
		traffic.frozen = false


func _view(street: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var camera := world.player.camera
	camera.global_position = street.to_global(at)
	camera.look_at(street.to_global(target))
	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	summary.captures.append(label + ".png")


func _isolated() -> void:
	RealityState.persistence_enabled = false
	var fixture := BenchHost.new()
	var street := Node3D.new()
	fixture.exterior_cell.street = street
	fixture.add_child(street);add_child(fixture)
	var data := Lamps.load_table()
	check(not data.is_empty(), "generated lamp table loads")
	for lamp: Dictionary in data.lamps:
		for identity: String in lamp.replaces:
			var placeholder := MeshInstance3D.new()
			placeholder.mesh = BoxMesh.new()
			placeholder.set_meta("authored_record_id", identity)
			street.add_child(placeholder)
		if not str(lamp.authored_light).is_empty():
			var light := OmniLight3D.new()
			light.set_meta("authored_record_id", str(lamp.authored_light))
			street.add_child(light)
	var mounted := Lamps.mount(fixture)
	check(mounted != null, "actual lamp owner mounts on isolated placeholder interface")
	if mounted == null:
		fixture.queue_free();get_tree().quit(1);return
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var source := (load(str(data.lod_stock)) as PackedScene).instantiate()
	for draw: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		metrics._check_cap_mapping(draw.mesh, true)
	source.free()
	var focus: MeshInstance3D
	var parts := 0
	var lod_surfaces := 0
	for lamp: Dictionary in data.lamps:
		var post := mounted.get_node(str(lamp.id)) as MeshInstance3D
		check(post.position.is_equal_approx(Vector3(lamp.at[0],lamp.at[1],lamp.at[2])), "retained placement " + str(lamp.id))
		var collider := post.get_node("Collision/" + str(post.get_node("Collision").get_child(0).name)) as CollisionShape3D
		check(collider.shape is CylinderShape3D and is_equal_approx(collider.shape.radius,.22) and is_equal_approx(collider.shape.height,2.4), "retained cylinder " + str(lamp.id))
		metrics._check_cap_mapping(post.mesh, true)
		for surface in post.mesh.get_surface_count():
			parts += 1
			var mesh_surface := RenderingServer.mesh_get_surface(post.mesh.get_rid(), surface)
			var lods: Array = mesh_surface.get("lods", [])
			check(lods.size() == (1 if str(lamp.stock)=="bishops_crook" else 0), "replacement body only on plain gaslamp " + str(lamp.id) + "/" + str(surface))
			lod_surfaces += lods.size()
			var mat := post.mesh.surface_get_material(surface) as StandardMaterial3D
			var maps := [mat.albedo_texture,mat.normal_texture,mat.roughness_texture]
			check(not mat.uv1_triplanar and mat.normal_enabled and mat.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "authored UV and anisotropic normal finish")
			for texture: Texture2D in maps:
				check(texture != null and texture.get_image().has_mipmaps(), "loaded physical map has mip chain")
			if str(mat.get_meta("v2_street_lamp_finish")) == "gas_glass":
				check(mat.refraction_enabled and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and is_zero_approx(mat.metallic), "registered clear expressive envelope")
			if str(mat.get_meta("v2_street_lamp_finish")) == "gas_paint":
				check(is_zero_approx(mat.metallic), "local dielectric paint")
		if str(lamp.id)=="lamp_orison_mid":focus=post
	check(parts==26 and lod_surfaces==18, "four retained posts,26 surfaces,18 complete replacement surfaces")
	check(metrics.failures.is_empty(), "loaded near/lower UV metric and derivative checks " + str(metrics.failures))
	metrics.free()
	var clock := mounted.get_node("LampClock")
	for minute: int in [720,1260]:
		clock.clock_override={"valid":true,"month":11,"minute_of_day":float(minute)}
		clock.refresh()
		check(clock.lights.size()==4 and clock.globe!=null and clock.mantle!=null, "retained light and emission owners")
		for light: OmniLight3D in clock.lights:
			check(light.visible==(minute==1260), "existing day/night light gating")
		check(is_zero_approx(clock.mantle.emission_energy_multiplier) if minute==720 else clock.mantle.emission_energy_multiplier>0., "mantle follows existing lamp clock")
	for draw: MeshInstance3D in street.find_children("*","MeshInstance3D",true,false): draw.visible=draw==focus
	var camera := Camera3D.new();fixture.add_child(camera);camera.make_current()
	var center := focus.global_transform*focus.get_aabb().get_center()
	camera.position=center+Vector3(5,0,8);camera.look_at(center)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.08,.1,.14)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy=.6
	fixture.add_child(environment)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);fixture.add_child(sun)
	var viewport := get_viewport()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	var observations: Array = []
	for row: Dictionary in [{"id":"near","threshold":0.},{"id":"lower","threshold":10000.},{"id":"near_repeat","threshold":0.},{"id":"lower_repeat","threshold":10000.}]:
		viewport.mesh_lod_threshold=float(row.threshold)
		for frame in 12: await RenderingServer.frame_post_draw
		var samples: Array=[]
		var previous := Time.get_ticks_usec()
		for frame in 90:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append([(now-previous)/1000.,RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()),RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])
			previous=now
		row["samples"]=samples;observations.append(row)
		check(viewport.get_texture().get_image().save_png(directory.path_join(str(row.id)+".png"))==OK,"actual imported body capture")
	viewport.mesh_lod_threshold=1.
	camera.fov=75.
	var direction := Vector3(.3,.05,1.).normalized()
	var probes: Array=[]
	var last_near := 0.
	var first_far := 0.
	for distance_m: float in [2.,4.,8.,12.,16.,24.,32.,48.,64.,96.]:
		camera.position=center+direction*distance_m;camera.look_at(center)
		for frame in 4: await RenderingServer.frame_post_draw
		var primitives := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		probes.append({"distance_m":distance_m,"primitives":primitives})
		if primitives==22444:last_near=distance_m
		if primitives==7502:
			first_far=distance_m;break
	check(last_near>0. and first_far>last_near,"natural distance chooses both complete replacement bodies")
	if last_near>0. and first_far>last_near:
		for iteration in 10:
			var distance_m := (last_near+first_far)*.5
			camera.position=center+direction*distance_m;camera.look_at(center)
			for frame in 4:await RenderingServer.frame_post_draw
			var primitives := RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			probes.append({"distance_m":distance_m,"primitives":primitives})
			if primitives==22444:last_near=distance_m
			elif primitives==7502:first_far=distance_m
			else:check(false,"natural LOD selects a complete source body")
		for spec: Dictionary in [{"id":"natural_before","distance":last_near,"fov":75.,"triangles":22444},{"id":"natural_after","distance":first_far,"fov":75.,"triangles":7502},{"id":"natural_narrow_recovery","distance":first_far,"fov":5.,"triangles":22444},{"id":"natural_inward_return","distance":last_near*.8,"fov":75.,"triangles":22444}]:
			camera.position=center+direction*float(spec.distance);camera.look_at(center);camera.fov=float(spec.fov)
			if str(spec.id)=="natural_narrow_recovery":
				# Keep the same far observer position; aim the narrow lens at
				# physical head stock rather than cropping it above the shaft.
				camera.look_at(focus.to_global(Vector3(0,3.86,.84)))
			for frame in 4:await RenderingServer.frame_post_draw
			check(RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)==int(spec.triangles),"natural full-body selection "+str(spec.id))
			check(viewport.get_texture().get_image().save_png(directory.path_join(str(spec.id)+".png"))==OK,"natural body image "+str(spec.id))
	camera.fov=65.;viewport.mesh_lod_threshold=0.
	camera.global_position=focus.to_global(Vector3(.9,4.05,2.))
	camera.look_at(focus.to_global(Vector3(0,3.86,.84)))
	for minute: int in [720,1260]:
		clock.clock_override={"valid":true,"month":11,"minute_of_day":float(minute)};clock.refresh()
		for frame in 6:await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(directory.path_join("head_day.png" if minute==720 else "head_night.png"))==OK,"loaded clear-envelope and mantle close view")
	var record := {"evidence_class":"INERT","scope":"Isolated actual lamp mount, imported near/lower metrics/maps/mips, clock gating, original cylinder parameters, natural-distance/narrow-FOV replacement bodies and repeated90frame timings; no composed access/save or artistic acceptance.","checks":summary.checks,"failures":failures,"observations":observations,"natural_transition":{"last_near_m":last_near,"first_far_m":first_far,"probes":probes}}
	var file := FileAccess.open(directory.path_join("isolated_lamps.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t")+"\n");file.close()
	fixture.free();await get_tree().process_frame
	print("ISOLATED STREET LAMPS: ",summary.checks.size()," checks; ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
