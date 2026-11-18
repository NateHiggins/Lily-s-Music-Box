extends "res://tests/orison_v2_domestic_native_test.gd"
const Delta := preload("res://tests/harukiya_fixture_delta.gd")
const SEAM_CONTACT := "retail_bar_pipe2_Hanger2"
const SEAM_BACKING := ["Destination_Stair_floor", "Destination_Balcony_oak"]

## Actual retained bearings, original light authority and clear capture stations.
func _init() -> void:
	batch_mode = false

func _ready() -> void:
	# The fabrication batch sets batch_mode before adding this node.
	if not batch_mode: _standalone.call_deferred()

func _standalone() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await validate_in_world(world)
	world.shutdown_for_tests()
	world.free()
	await _retired_audio()
	await validate_after_teardown()
	print("BAR PIPE SUPPORTS STANDALONE: ", "PASS" if failures.is_empty() else "FAIL", "; checks=", checks, "; failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var delta_sources := Delta.source_snapshot(get_script().resource_path)
	check(not world.startup_failed and world.bar_region != null and not world.bar_region.startup_failed, "composed world has a working bar destination")
	if world.startup_failed or world.bar_region == null or world.bar_region.startup_failed:
		Delta.finish_sources(delta_sources, get_script().resource_path, check)
		return {"checks": checks, "failures": failures.duplicate()}
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var bar: OrisonV2BarRegion = world.bar_region
	var cell: Node3D=bar.get_node("RetainedBarGeometry");var model: Node3D=cell.get_node("BarPipeSupports")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_pipe_supports.json"))
	check(FileAccess.get_sha256("res://assets/props/bar_pipe_supports.glb")==fixture.asset_sha256,"installed mounts bind the native export")
	var destination_spec := Delta.read_layout()
	var retired := Delta.retired_parts(cell, fixture, destination_spec, "BarPipeSupports", check)
	var expected_parts: Array = fixture.parts.filter(func(row: Dictionary) -> bool: return not retired.has(str(row.name)))
	var expected_triangles := 0
	for part: Dictionary in expected_parts: expected_triangles += int(part.triangles)
	var parts:=0;var triangles:=0;var exclude: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):exclude.append(body.get_rid())
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
		var identity:=str(draw.get_meta("bar_pipe_support_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==identity)[0]
		check(count==int(expected.triangles),"native partition retains its triangle count: "+identity)
		_check_cap_mapping(draw.mesh,true)
		var material:=draw.mesh.surface_get_material(0) as StandardMaterial3D;var library:=MatLib.get_mat(str(expected.key))
		check(material!=null and material!=library and library.uv1_triplanar and not material.uv1_triplanar,"local metre chart leaves shared library policy intact: "+identity)
		check(material.albedo_texture==library.albedo_texture and material.roughness_texture==library.roughness_texture and material.normal_texture==library.normal_texture,"three unchanged catalogue maps reach the mount: "+identity)
		check(material.metallic==library.metallic and material.roughness==library.roughness and material.normal_scale==library.normal_scale,"mount retains the catalogue optical calibration: "+identity)
		var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native collision agrees with visible faces: "+identity)
	check(parts==expected_parts.size() and triangles==expected_triangles,"all native pipe supports have one physical owner")
	for original: Dictionary in fixture.original_pipes:
		var rows: Array=bar.source_layout.floors.filter(func(row):return row.id=="F01")[0].furniture.filter(func(row):return row.id==original.id)
		check(rows.size()==1 and rows[0]==original,"original pipe identity, endpoints, radius and finish remain: "+str(original.id))
	exclude = Delta.support_exclusions(cell, exclude, "Destination_PipeSupports")
	var bearing_samples:=0;var span_samples:=0
	for original_contact: Dictionary in fixture.contacts:
		var contact := Delta.contact(destination_spec, original_contact, check)
		var at:=_v(contact.bearing);var direction:=_v(contact.direction)
		var owner: MeshInstance3D
		if bool(contact.get("destination_replacement", false)): owner = Delta.backing(cell, at, direction, exclude)
		for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
			if not bool(contact.get("destination_replacement", false)) and str(draw.name).trim_suffix("-col")==str(contact.owner).trim_suffix("-col"):owner=draw
		check(owner!=null,"original fabric bearing exists: "+str(contact.id))
		if owner==null:continue
		var faces:=PackedVector3Array()
		for point: Vector3 in owner.mesh.get_faces():faces.append(cell.to_local(owner.to_global(point)))
		var seed:=Vector3.RIGHT if absf(direction.y)>.9 else Vector3.UP;var other:=direction.cross(seed)
		var points: Array[Vector3]=[]
		if contact.has("inline_source"):
			points.append(at)
			for i in 8:points.append(at+float(contact.bearing_radius_m)*.8*(seed*cos(i*TAU/8.)+other*sin(i*TAU/8.)))
		else:
			for u: float in [-.044,-.022,0.,.022,.044]:
				for v: float in [-.044,-.022,0.,.022,.044]:points.append(at+seed*u+other*v)
		if str(contact.id) == SEAM_CONTACT:
			var without_backing: Array[RID] = exclude.duplicate()
			var own_support: MeshInstance3D
			for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
				var part := str(draw.get_meta("harukiya_destination_part", ""))
				if part in SEAM_BACKING:
					for body: CollisionObject3D in draw.find_children("*", "CollisionObject3D", true, false): without_backing.append(body.get_rid())
				if part == "Destination_PipeSupports_pipe_iron": own_support = draw
			check(not _seam_backing_allowed(Delta.backing(cell, at, direction, without_backing)), "bearing cannot pass when both declared seam backings are excluded")
			check(own_support != null and not _seam_backing_allowed(own_support), "the actual hanger iron cannot count as its own backing")
		for point: Vector3 in points:
			var sample_faces := faces
			var sample_owner := owner
			if bool(contact.get("destination_replacement", false)):
				sample_owner = Delta.backing(cell, point, direction, exclude)
				var allowed := _seam_backing_allowed(sample_owner) if str(contact.id) == SEAM_CONTACT else sample_owner != null and sample_owner == owner
				check(allowed, "each replaced bearing sample has its declared actual backing " + str(contact.id))
				if not allowed: continue
				sample_faces = Delta.faces_in(sample_owner, cell)
			var distance:=_mesh_distance(sample_faces,point-direction*.004,direction)
			if not is_finite(distance) or absf(distance-.004)>=.00003:print("BEARING DETAIL: ",contact.id," point=",point," distance=",distance," owner=",sample_owner.name)
			check(is_finite(distance) and absf(distance-.004)<.00003,"actual retained face seats the entire bearing: "+str(contact.id));bearing_samples+=1
		var routes: Array=[[_v(contact.fixture_endpoint),at]]
		if contact.has("free_offset_riser"):routes.append([_v(contact.free_offset_riser[0]),_v(contact.free_offset_riser[1])])
		for route: Array in routes:
			var start: Vector3=route[0];var end: Vector3=route[1];var forward: Vector3=(end-start).normalized()
			var side:=Vector3.RIGHT if absf(forward.y)>.9 else Vector3.UP;var across:=forward.cross(side)
			for offset: Vector3 in [Vector3.ZERO,side*.006,-side*.006,across*.006,-across*.006]:
				var query:=PhysicsRayQueryParameters3D.create(cell.to_global(start+forward*.014+offset),cell.to_global(end-forward*.016+offset),1,exclude)
				check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"fitted stem clears retained physical fabric: "+str(contact.id));span_samples+=1
	var pipe_samples:=0;var owners: Dictionary={};var original_faces: Dictionary={};var band_faces: Dictionary={}
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):owners[str(draw.name)]=draw
	for contact: Dictionary in fixture.pipe_contacts:
		var identity:=str(contact.assembly);var owner_name:=str(contact.owner);var point:=_v(contact.point);var normal:=_v(contact.normal)
		var adapted := false
		for adaptation: Dictionary in destination_spec.pipe_support_adaptations:
			if str(adaptation.id) == identity:
				point += GameBoot.b2g(adaptation.translation)
				adapted = true
		if not original_faces.has(owner_name):
			var source_draw: MeshInstance3D=owners.get(owner_name)
			check(source_draw!=null,"actual original pipe surface exists: "+owner_name)
			if source_draw==null:continue
			var faces:=PackedVector3Array()
			for vertex: Vector3 in source_draw.mesh.get_faces():faces.append(cell.to_local(source_draw.to_global(vertex)))
			for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
				if str(draw.get_meta("harukiya_destination_part", "")) == "Destination_PipeOffset_pipe_metal":
					faces.append_array(Delta.faces_in(draw, cell))
			original_faces[owner_name]=faces
		if not band_faces.has(identity):
			var faces:=PackedVector3Array()
			for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				if str(draw.get_meta("bar_pipe_support_part"))==identity+"__iron_blackened":
					for vertex: Vector3 in draw.mesh.get_faces():faces.append(cell.to_local(draw.to_global(vertex)))
			if adapted:
				for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
					if str(draw.get_meta("harukiya_destination_part", "")) == "Destination_PipeSupports_pipe_iron":
						faces.append_array(Delta.faces_in(draw, cell))
			band_faces[identity]=faces
		var old_distance:=_mesh_distance(original_faces[owner_name],point-normal*.004,normal)
		var new_distance:=_mesh_distance(band_faces[identity],point-normal*.004,normal)
		check(is_finite(old_distance) and is_finite(new_distance) and absf(old_distance-.004)<.00003 and absf(new_distance-.004)<.00003,"actual split collar seats on the retained ten-facet pipe: "+identity);pipe_samples+=1
	if capture_enabled: await _mount_views(world,bar,model)
	Delta.finish_sources(delta_sources, get_script().resource_path, check)
	print("BAR PIPE SUPPORTS: checks=",checks," parts=",parts," triangles=",triangles," bearing_samples=",bearing_samples," span_samples=",span_samples," pipe_samples=",pipe_samples," failures=",failures.size())
	return {"checks": checks, "failures": failures.duplicate(), "source_bindings": delta_sources}

func _mount_views(world: OrisonV2RuntimeRoot, bar: Node3D, model: Node3D) -> void:
	var views: Array=[
		["pool_pipes",Vector3(-7.4,-2.775,33.25),Vector3(-7.4,-.28,31.25)],
		["wc_lintel_clearance",Vector3(-5.5,-2.775,32.0),Vector3(-9.5,-.28,36.2)],
		["well_pipe_drops",Vector3(-3.8,-2.775,33.5),Vector3(-4.4,1.2,34.1)],
		["east_pipe_grid",Vector3(-3.8,-2.775,33.5),Vector3(3.5,-.28,34.1)]]
	for view: Array in views:
		var station_id := "stage_front" if str(view[0]) == "well_pipe_drops" else "entrance"
		var feet:=bar.to_global(Delta.node_point(Delta.read_layout(), station_id));var shape:=CapsuleShape3D.new();shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
		var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=shape;capsule.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*shape.height*.5);capsule.collision_mask=1;capsule.exclude=[world.player.get_rid()]
		var clear:=world.get_world_3d().direct_space_state.intersect_shape(capsule,1).is_empty()
		check(clear,"ordinary standing capture clears mounted fabric: "+str(view[0]))
		if not clear:continue
		var floor_query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.02,feet-Vector3.UP*.15,1,[world.player.get_rid()])
		var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(floor_query)
		check(not floor_hit.is_empty() and bar.get_node("RetainedBarGeometry").is_ancestor_of(floor_hit.collider),"standing capture has retained floor support: "+str(view[0]))
		if floor_hit.is_empty():continue
		world.player.global_position=feet;world.player.face_world_point(bar.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(view[0])+"_fitted")
		model.hide()
		await _settled_optics();await shot(str(view[0])+"_original")
		model.show()

func validate_after_teardown() -> Dictionary:
	return {"checks": checks, "failures": failures.duplicate(), "additional_world_loads": 0}

func _seam_backing_allowed(owner: MeshInstance3D) -> bool:
	return owner != null and str(owner.get_meta("harukiya_destination_part", "")) in SEAM_BACKING
