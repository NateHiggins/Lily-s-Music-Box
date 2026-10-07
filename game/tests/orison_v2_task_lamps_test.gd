extends "res://tests/orison_v2_city_sweep.gd"
## Native library parity plus the existing production bench lamp and support.
const NativeLamp := preload("res://scripts/props/native_task_lamp.gd")
var batch_mode := true
var capture_enabled := true

func _ready() -> void: pass

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_task_lamps.json"))
	check(FileAccess.get_sha256("res://assets/props/task_lamps.glb") == fixture.asset_sha256, "native export matches the five-variant fixture")
	var count := 0
	var triangles := 0
	for row: Dictionary in fixture.runtime.variants:
		var source: Dictionary = fixture.original_records.filter(func(m): return m.variant == row.id)[0]
		var reference_holder := Node3D.new()
		var native_holder := Node3D.new()
		world.add_child(reference_holder); world.add_child(native_holder)
		reference_holder.position = Vector3(1000, 0, 1000)
		native_holder.position = Vector3(1002, 0, 1000)
		var reference := LampProp.new()
		var lamp := NativeLamp.new()
		for actor: LampProp in [reference, lamp]:
			actor.variant = str(row.id); actor.prop_type = "lamp"; actor.name = str(source.id)
		reference_holder.add_child(reference); native_holder.add_child(lamp)
		reference.set_process(false); lamp.set_process(false)
		check(lamp.light.position.is_equal_approx(reference.light.position) and lamp.light.rotation.is_equal_approx(reference.light.rotation), "original emitter and cone direction retained: " + str(row.id))
		check(is_equal_approx(lamp.light.spot_range, reference.light.spot_range) and is_equal_approx(lamp.light.spot_angle, reference.light.spot_angle) and lamp.light.light_color.is_equal_approx(reference.light.light_color), "original lighting specification retained: " + str(row.id))
		check(is_equal_approx(lamp._base_energy, reference._base_energy) and is_equal_approx(lamp._drift_depth, reference._drift_depth) and is_equal_approx(lamp._phase, reference._phase), "source identity retains personality and electrical output")
		check(lamp.profile == reference.profile and lamp.graph_node_id == reference.graph_node_id and lamp.state == reference.state, "nonvisual mechanical profile and default state unchanged")
		check(lamp.native_parts.size() == row.parts.size() and lamp.find_children("*", "SpotLight3D", true, false).size() == 1, "native partitions retain one original light owner")
		for part: Dictionary in row.parts:
			var draw: MeshInstance3D = lamp.native_parts[str(part.name)]
			var expected: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
			var faces := draw.mesh.get_faces()
			count += 1; triangles += faces.size() / 3
			check(faces.size() / 3 == int(expected.triangles), "exact imported native triangles: " + str(part.name))
			check(draw.owner == null and draw.mesh is ArrayMesh, "unowned native geometry survives actor reparenting")
			_check_cap_mapping(draw.mesh, true)
			var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
			var library := MatLib.get_mat(str(part.catalog_key))
			check(material != null and material != library and not material.uv1_triplanar and library.uv1_triplanar, "per-actor catalogue material keeps metre UVs without changing library")
			if material != null:
				check(material.albedo_texture == library.albedo_texture and material.roughness_texture == library.roughness_texture and material.normal_texture == library.normal_texture and material.uv1_scale.is_equal_approx(library.uv1_scale), "registered maps and metre scale reach every partition")
			if part.has("finish"): check(is_equal_approx(material.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(material.roughness,float(part.finish.roughness)),"native/runtime lamp finishing agrees")
			check(draw.get_parent() == lamp._switch_key if part.key == "switch_bakelite" else draw.get_parent() == lamp, "only the original switch key moves")
			if part.key == "bulb_opal": check(draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "opal bulb cannot block its own internal source")
		check(lamp._switch_key.position.is_equal_approx(reference._switch_key.position), "source switch pivot retained")
		lamp.set_local_enabled(false, false); lamp.set_budget(.8, true, true); lamp._process(0.)
		check(not lamp.is_locally_enabled() and not lamp.light.visible and lamp.light.light_energy == 0. and lamp._opal.emission_energy_multiplier == 0., "budget cannot relight a locally disabled lamp or its bulb")
		lamp.set_local_enabled(true, false); lamp.set_budget(0., false, false); lamp._process(0.)
		check(lamp.is_locally_enabled() and not lamp.light.visible and lamp._opal.emission_energy_multiplier == 0., "budget standby retains local switch state")
		lamp.set_budget(1., false, true); lamp._process(0.)
		check(lamp.light.visible and lamp.light.light_energy > 0. and is_equal_approx(lamp._opal.emission_energy_multiplier, lamp.light.light_energy), "visible bulb follows the sole original electrical light")
		var card: Dictionary = lamp.interact()
		await lamp._switch_tween.finished
		check(not lamp.is_locally_enabled() and is_equal_approx(lamp._switch_key.rotation.y, deg_to_rad(-32.)) and not card.is_empty(), "original interaction toggles state, animates key and returns service card")
		check(lamp.find_children("*", "Area3D", true, false).size() == 1, "inherited interaction area exposes the native silhouette")
		reference_holder.free(); native_holder.free()
	check(count == fixture.parts.size() and triangles == int(fixture.triangles), "all five native variants and every exported triangle checked")
	var installed := world.adapter.resolve("F03_B_LAMP_01") as LampProp
	check(installed != null and installed.get_script() == NativeLamp, "existing V2 bench actor adopts native body")
	if installed == null: return {"checks":checks, "failures":failures.duplicate()}
	var support := world.adapter.resolve("3B_workbench") as StaticBody3D
	check(support != null and support.to_local(installed.global_position).is_equal_approx(Vector3(.60, .91, .18)), "original bench-local lamp datum retained")
	for probe: Dictionary in fixture.contacts:
		if probe.assembly != "TaskLamp_bench_friction": continue
		var at := installed.to_global(Vector3(probe.point[0], probe.point[1], probe.point[2]))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP*.004, at - Vector3.UP*.004, 1))
		check(not hit.is_empty() and hit.collider == support and hit.position.distance_to(at) < .00003 and hit.normal.y > .9, "lamp foot bears on the corrected visible workbench plane")
	var original_enabled := installed.is_locally_enabled()
	installed.interact(world.player)
	check(installed.is_locally_enabled() != original_enabled, "production lamp retains its actual interaction")
	installed.set_local_enabled(original_enabled, false)
	if capture_enabled:
		var target := installed.global_position + Vector3.UP*.32
		var feet: Vector3 = world.adapter.root.to_global(Vector3(13.65, 6.42, -1.35))
		check(_city_clear_station(world, feet), "bench inspection station has a real floor and standing clearance")
		await _city_capture(world, feet, target, "bench_context", "task lamps", str(installed.name))
		# Fixed detail camera retains the same production lights and geometry.
		var camera := Camera3D.new(); world.add_child(camera)
		camera.global_position = installed.global_position + Vector3(.70, .65, .82)
		camera.look_at(target); camera.fov = 48.; camera.make_current()
		await _settled_optics(); await shot("bench_detail")
		world.player.set_lamp_enabled(false)
		installed.set_process(false)
		for enabled: bool in [false, true]:
			installed.set_local_enabled(enabled, false); installed.set_budget(1., false, true); installed._process(0.)
			await RenderingServer.frame_post_draw
			await shot("bench_practical_on" if enabled else "bench_practical_off")
		installed.set_local_enabled(original_enabled, false); installed.set_process(true)
		world.player.camera.make_current(); camera.free()
	var result := {"checks":checks, "parts":count, "triangles":triangles, "production_actors":1, "library_variants":5, "failures":failures.duplicate()}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("task_lamps.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("TASK LAMPS: ", result)
	return result
