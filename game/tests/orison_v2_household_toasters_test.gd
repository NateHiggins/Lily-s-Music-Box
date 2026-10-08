extends "res://tests/orison_v2_domestic_native_test.gd"
## One production world covers all ten original cycles and both service pans.
const Toaster := preload("res://scripts/building/orison_v2_toaster.gd")

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_household_toasters.json"))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/household_accessories.json"))
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_toaster_factory")
	factory_id = factory.get_instance_id()
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256, "native toaster export bound to construction")
	var actors: Array[Toaster] = []
	var unique := {}
	var triangles := 0
	var count := 0
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var prop := world.adapter.resolve(identity) as Toaster
		check(prop != null and prop.native_ready, "original toaster owns native stock: " + identity)
		if prop == null: continue
		actors.append(prop)
		mounted_ids.append(prop.get_instance_id())
		var record: Dictionary = source.accessories.filter(func(row): return row.id == identity)[0]
		var owner := world.adapter.resolve(str(record.support)) as Node3D
		check(prop.get_parent() == owner and prop.position.is_equal_approx(Vector3(0,.9,0)) and prop.rotation.is_zero_approx(), "original support and appliance pose retained")
		check(prop.unit == record.unit and prop.prop_type == "toaster" and prop.tray_axis == (Vector3.LEFT if record.unit == "4B" else Vector3.FORWARD), "original household and tray exit retained")
		check(prop._lever == prop.get_node("CarriageLever") and prop._lever.position.is_equal_approx(Vector3(.137,.137,.002)), "original hand lever owner and pivot")
		check(prop._carriage == prop.get_node("BreadCarrier") and prop._carriage.position.is_equal_approx(Vector3(0,.151,0)), "original bread carrier owner and pivot")
		check(prop._crumb_tray == prop.get_node("OrisonRetrofitCrumbTray") and prop._crumb_tray.position.is_equal_approx(Vector3(0,.027,0)), "original service pan owner and pivot")
		check(prop._hum != null and prop._click != null and prop._pop != null and prop._coil_mat.emission_enabled, "original audio and element material owners")
		var interaction := prop.get_node("Interaction") as Area3D
		var shape := interaction.get_child(0) as CollisionShape3D
		check(shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.is_equal_approx(Vector3(.30,.23,.22)) and shape.position.is_equal_approx(Vector3(0,.11,.025)), "original player interaction area retained")
		mounted_ids.append(interaction.get_instance_id())
		var assembly: Dictionary = fixture.runtime.assemblies.filter(func(row): return row.id == instance.variant)[0]
		for part: Dictionary in assembly.parts:
			var parent := prop.get_node("StaticCase" if part.component == "Body" else str(part.component)) as Node3D
			var draw := parent.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.get_meta("native_toaster_part", "") == part.name, "native stock follows its original fixed or moving owner")
			if draw == null: continue
			count += 1
			var expected: Dictionary = factory._variants[str(instance.variant)].filter(func(row): return row.name == part.name)[0]
			check((parent.transform * draw.transform).is_equal_approx(expected.pose), "component pivot rebase preserves native rest pose")
			if part.component == "ResistanceWire": check(draw.material_override == prop._coil_mat, "native resistance wire uses original dynamic glow")
			if unique.has(str(part.name)):
				check(draw.mesh.get_instance_id() == unique[str(part.name)], "toasters share immutable geometry")
			else:
				unique[str(part.name)] = draw.mesh.get_instance_id()
				_check_cap_mapping(draw.mesh, true)
				var spec: Dictionary = fixture.parts.filter(func(row): return row.name == part.name)[0]
				check(draw.mesh.get_faces().size()/3 == int(spec.triangles), "exact native partition triangles")
				triangles += draw.mesh.get_faces().size()/3
				var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
				var catalog := MatLib.get_mat(str(part.catalog_key))
				check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)), "native metre charts retained")
				check(material.albedo_texture == catalog.albedo_texture and material.roughness_texture == catalog.roughness_texture and material.normal_texture == catalog.normal_texture, "registered catalogue maps retained")
				check(is_equal_approx(material.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(material.roughness,float(part.finish.roughness)), "local physical finish retained")
		_check_crumbs(prop, factory)
		for contact: Dictionary in fixture.contacts:
			if contact.assembly != instance.variant: continue
			var p: Array = contact.point
			var at := prop.to_global(Vector3(p[0],p[1],p[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1))
			check(not hit.is_empty() and hit.collider == owner and hit.position.distance_to(at)<.00004 and hit.normal.y>.99, "actual native countertop bears toaster feet and loose plug")
		prop.set_crumb_tray_open(true, 0.)
		check(prop.is_crumb_tray_open() and prop._crumb_tray.position.is_equal_approx(Vector3(0,.027,0)+prop.tray_axis*.160), "original archaeology pan API and full stroke retained")
		if capture_enabled: await _capture_toaster(world,prop,record)
		prop.set_crumb_tray_open(false, 0.)
		check(not prop.is_crumb_tray_open() and prop._crumb_tray.position.is_equal_approx(Vector3(0,.027,0)), "original pan closes at source datum")
	check(actors.size() == 10, "all ten authored household toasters installed")
	var crumb_mesh: Mesh = factory._variants.ToasterCrumb[0].mesh
	_check_cap_mapping(crumb_mesh, true)
	triangles += crumb_mesh.get_faces().size()/3
	check(triangles == int(fixture.triangles), "all unique native toaster geometry accounted for")
	var saved_infection: float = Conductor.infection
	Conductor.infection = 0.
	for prop: Toaster in actors: prop.interact(world.player)
	var deadline := Time.get_ticks_msec()+3000
	while actors.any(func(prop): return prop.state == FunctionalProp.PState.STARTING) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	for prop: Toaster in actors:
		check(prop.state == FunctionalProp.PState.OPERATING and is_equal_approx(prop._lever.position.y,.091) and is_equal_approx(prop._carriage.position.y,.064), "ordinary interaction retains independent lever and carrier strokes")
		prop.interact(world.player)
	for prop: Toaster in actors:
		if prop._busy_tween.is_running(): await prop._busy_tween.finished
		check(is_equal_approx(prop._lever.position.x,Toaster.LEVER_HOME_X), "impatient control returns without sideways drift")
	await get_tree().create_timer(1.5).timeout
	for prop: Toaster in actors: check(prop._coil_mat.emission_energy_multiplier>0., "original clockwork cycle heats native resistance wire")
	deadline = Time.get_ticks_msec()+8000
	while actors.any(func(prop): return prop.cycles_completed == 0) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	for prop: Toaster in actors:
		check(prop.cycles_completed == 1 and prop.state == FunctionalProp.PState.IDLE and prop._lever.position.is_equal_approx(Vector3(.137,.137,.002)) and prop._carriage.position.is_equal_approx(Vector3(0,.151,0)), "original automatic release restores native moving stock")
	Conductor.infection = saved_infection
	return {"checks":checks,"actors":actors.size(),"parts":count,"unique_triangles":triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _check_crumbs(prop: Toaster, factory: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(prop.unit))
	var crumbs := prop._crumb_tray.get_children().filter(func(child): return child.has_meta("native_toaster_crumb"))
	check(crumbs.size() == 18, "original household crumb count")
	for i in crumbs.size():
		var sx := rng.randf_range(.005,.014)
		var sz := rng.randf_range(.004,.011)
		var dimensions := Vector3(sx,rng.randf_range(.002,.005),sz)
		var at := Vector3(rng.randf_range(-.088,.088),.006,rng.randf_range(-.038,.038))
		var yaw := rng.randf_range(-PI,PI)
		var crumb := crumbs[i] as MeshInstance3D
		var old: Transform3D = crumb.get_meta("source_crumb_transform")
		check(old.origin.is_equal_approx(at) and old.basis.is_equal_approx(Basis(Vector3.UP,yaw)) and dimensions.is_equal_approx(crumb.get_meta("source_crumb_dimensions")), "source RNG dimensions footprint and yaw retained")
		check(crumb.mesh == factory._variants.ToasterCrumb[0].mesh, "native crumbs share one closed prototype")
		var material := crumb.material_override as StandardMaterial3D
		check(material != null and material.albedo_color.is_equal_approx(Toaster.BURNT if i%7==0 else Toaster.CRUMB), "source burnt and fresh crumb colours retained")
		var bounds := crumb.transform * crumb.mesh.get_aabb()
		var expected_y := -.00115 if at.x>=-.082 and at.x<=.038 and at.z>=-.036 and at.z<=.024 else -.0013
		check(absf(bounds.position.y-expected_y)<.00002, "crumb bottom seated on actual pan or grease film")

func _capture_toaster(world: OrisonV2RuntimeRoot, prop: Toaster, record: Dictionary) -> void:
	var bounds := prop._visual_bounds()
	var station := Vector3.INF
	for distance: float in [.7,.85,1.,1.25,1.5,.55]:
		for step in 25:
			var angle := deg_to_rad(ceilf(float(step)*.5)*12.*(1. if step%2 else -1.))
			var feet := prop.to_global(Vector3(sin(angle)*distance,-.88,-cos(angle)*distance))
			if _city_clear_station(world,feet) and _toaster_framed(world,prop,bounds,feet): station=feet;break
		if station.is_finite():break
	check(station.is_finite(), "unobstructed installed toaster and withdrawn service pan: "+str(record.id))
	if station.is_finite(): await _city_capture(world,station,prop.to_global(bounds.get_center()),str(record.id)+"_native_open","native single-slot toaster and original service pan",str(record.id))

func _toaster_framed(world: OrisonV2RuntimeRoot, prop: Toaster, bounds: AABB, feet: Vector3) -> bool:
	world.player.global_position = feet
	world.player.face_world_point(prop.to_global(bounds.get_center()))
	var camera: Camera3D = world.player.camera
	var frame := camera.get_viewport().get_visible_rect().grow(-16)
	for corner in 8:
		var p := prop.to_global(bounds.get_endpoint(corner))
		if camera.is_position_behind(p) or not frame.has_point(camera.unproject_position(p)): return false
	for local: Vector3 in [Vector3(-.10,.12,-.062),Vector3(.10,.12,-.062),Vector3(0,.18,0),prop._crumb_tray.position]:
		var p := prop.to_global(local)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,p,1,[world.player.get_rid()]))
		if not hit.is_empty() and hit.position.distance_to(p)>.01: return false
	return true
