extends "res://tests/orison_v2_city_sweep.gd"
## Shared checks for source-equivalent native furniture variants and all copies.
var batch_mode := true
var capture_enabled := true
var mounted_ids: Array[int] = []
var factory_id := 0
func _ready() -> void: pass
func _family() -> String: return ""

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var family := _family()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_"+family+".json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256,"native export matches construction: "+family)
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_domestic_factory")
	factory_id = factory.get_instance_id()
	var variants: Dictionary = {}
	for row: Dictionary in fixture.runtime.assemblies: variants[str(row.id)] = row
	var shared_meshes: Dictionary = {}
	var shared_shapes: Dictionary = {}
	var first_actors: Dictionary = {}
	var anchors: Dictionary = {}
	var levels: Dictionary = {}
	for anchor: Dictionary in world.layout.anchors: anchors[str(anchor.id)] = anchor
	for level: Dictionary in world.layout.levels: levels[str(level.id)] = float(level.y)
	var count := 0
	var unique_triangles := 0
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var variant := str(instance.variant)
		var row: Dictionary = variants[variant]
		var body := world.adapter.resolve(identity) as StaticBody3D
		check(body != null and body.get_meta("v2_furniture_id","") == identity and body.get_meta("v2_native_domestic_variant","") == variant,"original furniture actor owns native variant: "+identity)
		if body == null: continue
		mounted_ids.append(body.get_instance_id())
		var anchor: Dictionary = anchors[identity]
		var position: Array = anchor.position
		var expected_position: Vector3 = world.adapter.root.to_global(Vector3(position[0],float(position[1])+float(levels[str(anchor.level)]),position[2]))
		check(body.global_position.is_equal_approx(expected_position) and body.global_basis.is_equal_approx(world.adapter.root.global_basis*Basis(Vector3.UP,float(anchor.yaw))),"original furniture placement preserved: "+identity)
		var first := not first_actors.has(variant)
		if first: first_actors[variant] = identity
		var shapes := body.find_children("*","CollisionShape3D",false,false)
		check(shapes.size() == row.parts.size(),"native actor has exact collision partitions: "+identity)
		for i in row.parts.size():
			var part: Dictionary = row.parts[i]
			var draw := body.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.get_parent() == body and draw.owner == null,"native part remains under its original owner")
			if draw == null: continue
			count += 1
			var shape := shapes[i] as CollisionShape3D
			check(shape.shape is ConcavePolygonShape3D and shape.transform.is_equal_approx(draw.transform),"native collision matches draw frame")
			if first:
				shared_meshes[str(part.name)] = draw.mesh.get_instance_id()
				shared_shapes[str(part.name)] = shape.shape.get_instance_id()
				var expected: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
				var triangles := draw.mesh.get_faces().size()/3
				check(triangles == int(expected.triangles),"exact native variant partition")
				unique_triangles += triangles
				_check_cap_mapping(draw.mesh,true)
				var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
				check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"native metre charts retained")
				if part.has("catalog_key"):
					var library := MatLib.get_mat(str(part.catalog_key))
					check(material != library and material.albedo_texture == library.albedo_texture and material.normal_texture == library.normal_texture and material.roughness_texture == library.roughness_texture,"local finish retains registered maps")
				if part.has("finish"):
					check(is_equal_approx(material.roughness,float(part.finish.roughness)) and is_equal_approx(material.normal_scale,float(part.finish.normal_scale)),"local finish parameters retained")
				if part.has("tint"):
					var tint: Array = part.tint
					check(material.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3]).linear_to_srgb()),"source colour retained")
				if part.key == "glassish":
					var optics := draw.material_override as ShaderMaterial
					check(optics != null and optics.shader.resource_path == fixture.runtime.optics.shader and is_equal_approx(float(optics.get_shader_parameter("surface_roughness")),float(fixture.runtime.optics.surface_roughness)),"existing clear glazing owner applied locally")
			else:
				check(draw.mesh.get_instance_id() == shared_meshes[str(part.name)] and shape.shape.get_instance_id() == shared_shapes[str(part.name)],"identical variants share immutable mesh and shape, including completion homes")
		for probe: Dictionary in fixture.contacts:
			if probe.assembly != variant: continue
			var point: Array = probe.point
			var at := body.to_global(Vector3(point[0],point[1],point[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"actual world floor meets native bearing: "+identity+" / "+str(probe.label))
	check(first_actors.size() == fixture.runtime.assemblies.size() and unique_triangles == int(fixture.triangles),"all shared native variants accounted for")
	check(mounted_ids.size() == fixture.runtime.instances.size(),"all original and completion actors accounted for")
	if family == "domestic_tables":
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_surface_props.json"))
		var stock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_surface_stock.json"))
		var ids: Array = fixture.runtime.instances.map(func(row): return row.id)
		for row: Dictionary in source.props:
			if not row.support in ids: continue
			var support := world.adapter.resolve(str(row.support)) as StaticBody3D
			var prop := support.get_node_or_null(str(row.id)) as Node3D
			check(prop != null,"passive stock retains its native table owner")
			if prop == null: continue
			check(prop.position.is_equal_approx(Vector3(row.position[0],row.position[1],row.position[2])) and is_equal_approx(prop.rotation.y,float(row.yaw)),"passive stock retains its pose")
			for contact: Dictionary in stock.contacts:
				if contact.assembly != row.id: continue
				var p: Array = contact.point
				var at := prop.to_global(Vector3(p[0],p[1],p[2]))
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1))
				check(not hit.is_empty() and hit.collider == support and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"actual native table supports retained stock: "+str(row.id))
	if capture_enabled:
		for variant: String in first_actors:
			var identity: String = first_actors[variant]
			var body := world.adapter.resolve(identity) as StaticBody3D
			var bounds := AABB()
			for part: Dictionary in variants[variant].parts:
				var draw := body.get_node(str(part.name)) as MeshInstance3D
				bounds = bounds.merge(draw.transform * draw.mesh.get_aabb())
			var radius := maxf(1.15,maxf(bounds.size.x,bounds.size.z)*.9)
			var station := Vector3.INF
			for scale in [1.,1.25,.85]:
				for direction in [Vector3(0,0,-1),Vector3(.7,0,-.7),Vector3(-.7,0,-.7),Vector3(1,0,0),Vector3(-1,0,0),Vector3(.7,0,.7),Vector3(-.7,0,.7),Vector3(0,0,1)]:
					var feet: Vector3 = body.to_global(direction*radius*float(scale)+Vector3.UP*.02)
					if _city_clear_station(world,feet): station=feet; break
				if station.is_finite(): break
			check(station.is_finite(),"clear standing camera station: "+identity)
			if station.is_finite(): await _city_capture(world,station,body.to_global(Vector3(0,bounds.end.y*.65,0)),identity+"_native","native apartment furniture",identity)
	return {"checks":checks,"parts":count,"variants":first_actors.size(),"actors":mounted_ids.size(),"unique_triangles":unique_triangles,"shared_validator_sha256":FileAccess.get_sha256("res://tests/orison_v2_domestic_native_test.gd"),"failures":failures.duplicate()}

func validate_after_teardown() -> Dictionary:
	for id: int in mounted_ids: check(not is_instance_id_valid(id),"native furniture actor retires with original owner")
	check(not is_instance_id_valid(factory_id),"world-owned shared variant library retires with the world")
	return {"checks":checks,"failures":failures.duplicate()}
