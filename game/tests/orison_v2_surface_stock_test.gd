extends "res://tests/orison_v2_city_sweep.gd"
## All passive records retain their support, pose, stock and retirement owner.
var batch_mode := true
var capture_enabled := true
var mounted_ids: Array[int] = []
func _ready() -> void: pass

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_surface_stock.json"))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_surface_props.json"))
	check(FileAccess.get_sha256("res://assets/props/surface_stock.glb") == fixture.asset_sha256,"passive stock matches native export")
	var count := 0
	var triangles := 0
	for row: Dictionary in source.props:
		var support := world.adapter.resolve(str(row.support)) as Node3D
		var prop := support.get_node_or_null(str(row.id)) as Node3D if support != null else null
		check(prop != null and prop.get_meta("v2_native_surface_stock","") == row.id,"native surface actor: " + str(row.id))
		if prop == null: continue
		mounted_ids.append(prop.get_instance_id())
		check(prop.get_parent() == support and prop.position.is_equal_approx(Vector3(row.position[0],row.position[1],row.position[2])) and is_equal_approx(prop.rotation.y,float(row.yaw)),"original support-local pose: " + str(row.id))
		check(prop.get_meta("v2_surface_prop","") == row.kind and prop.get_meta("support_id","") == row.support,"original passive identity: " + str(row.id))
		check(prop.find_children("*","CollisionObject3D",true,false).is_empty() and prop.find_children("*","CollisionShape3D",true,false).is_empty(),"passive stock adds no collision owner")
		var native: Dictionary = fixture.runtime.assemblies.filter(func(a): return a.id == row.id)[0]
		check(prop.get_child_count() == native.parts.size(),"source primitives replaced once")
		for part: Dictionary in native.parts:
			var draw := prop.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.owner == null,"unbound native partition: " + str(part.name))
			if draw == null: continue
			var expected: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
			var faces := draw.mesh.get_faces()
			check(faces.size()/3 == int(expected.triangles),"exact passive stock triangles")
			count += 1; triangles += faces.size()/3
			_check_cap_mapping(draw.mesh,true)
			var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"native metre charts retained")
			if part.has("catalog_key"):
				var library := MatLib.get_mat(str(part.catalog_key))
				check(material != library and material.albedo_texture == library.albedo_texture and material.normal_texture == library.normal_texture and material.roughness_texture == library.roughness_texture,"catalogue maps retained on local material")
			if part.has("finish"):
				check(is_equal_approx(material.roughness,float(part.finish.roughness)) and is_equal_approx(material.normal_scale,float(part.finish.normal_scale)),"native/runtime finishing parameters agree")
			if part.key == "glassish":
				check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,"original clear glass source retained")
				var optical := draw.material_override as ShaderMaterial
				check(optical != null and optical.shader.resource_path == fixture.runtime.optics.shader and is_equal_approx(float(optical.get_shader_parameter("surface_roughness")),.06),"registered clear dielectric replaces diffuse milkiness")
	check(count == fixture.parts.size() and triangles == int(fixture.triangles),"all 55 props and their native partitions accounted for")
	# Most legacy furniture has a broad collision hull. Exact visual bearings
	# for every prop are proven by the linked native inspector; only the four
	# rebuilt work tables have mesh-exact runtime support collision here.
	for contact: Dictionary in fixture.contacts:
		var row: Dictionary = source.props.filter(func(p): return p.id == contact.assembly)[0]
		if not row.support in preload("res://scripts/building/orison_v2_work_tables.gd").IDS: continue
		var support := world.adapter.resolve(str(row.support)) as StaticBody3D
		var prop := support.get_node(str(row.id)) as Node3D
		var point: Array = contact.point
		var at := prop.to_global(Vector3(point[0],point[1],point[2]))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1))
		check(not hit.is_empty() and hit.collider == support and hit.position.distance_to(at)<.00004,"native table supports passive stock: " + str(row.id))
	if capture_enabled:
		var stations := {"2A_desk":Vector3(-12.3,3.22,6.75),"3B_workbench":Vector3(13.65,6.42,-1.35),"5A_plantable":Vector3(-11,12.82,-4.6)}
		for identity: String in ["2A_desk","3B_workbench","5A_plantable","6A_deskwall"]:
			var support := world.adapter.resolve(identity) as Node3D
			var feet: Vector3 = world.adapter.root.to_global(stations[identity]) if stations.has(identity) else support.to_global(Vector3(-1.35,.02,-.65))
			check(_city_clear_station(world,feet),"surface stock standing station clears furniture")
			await _city_capture(world,feet,support.to_global(Vector3(0,.92,0)),identity+"_stock","native passive surface stock",identity)
		# ORISON_STOCK_CAPTURE_IDS (comma-separated record ids) replaces the default close-ups.
		var close_ups: Array = Array(OS.get_environment("ORISON_STOCK_CAPTURE_IDS").split(",", false))
		if close_ups.is_empty(): close_ups = ["2A_k_kdishrack","3A_story_cuttings","5A_model","6C_story_oddments"]
		for identity: String in close_ups:
			var row: Dictionary = source.props.filter(func(p): return p.id == identity)[0]
			var support := world.adapter.resolve(str(row.support)) as Node3D
			var prop := support.get_node(identity) as Node3D
			var station := Vector3.INF
			for local: Vector3 in [Vector3(0,0,-1.0),Vector3(1.0,0,0),Vector3(-1.0,0,0),Vector3(0,0,1.0),Vector3(.7,0,-.7),Vector3(-.7,0,-.7)]:
				var candidate: Vector3 = prop.global_position + support.global_basis * local
				candidate.y = support.global_position.y + .02
				if _city_clear_station(world,candidate): station = candidate; break
			check(station.is_finite(),"additional stock capture station: " + identity)
			if station.is_finite(): await _city_capture(world,station,prop.global_position+Vector3.UP*.09,identity+"_stock","native passive surface stock",identity)
	return {"checks":checks,"parts":count,"triangles":triangles,"failures":failures.duplicate()}

func validate_after_teardown() -> Dictionary:
	for id: int in mounted_ids: check(not is_instance_id_valid(id),"passive native actor retires with support")
	return {"checks":checks,"failures":failures.duplicate()}
