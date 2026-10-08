extends "res://tests/orison_v2_domestic_native_test.gd"
## Original cabinet ownership, seeded household stock and live reflection.
const Cabinet := preload("res://scripts/building/orison_v2_medicine_cabinet.gd")
var unique_parts := {}
var unique_triangles := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_medicine_cabinets.json"))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/household_accessories.json"))
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_medicine_factory")
	factory_id = factory.get_instance_id()
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256, "native cabinet export bound to construction")
	var actors: Array[Cabinet] = []
	var kept_count := 0
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var prop := world.adapter.resolve(identity) as Cabinet
		check(prop != null and prop.native_ready, "original cabinet owns native stock: "+identity)
		if prop == null: continue
		actors.append(prop);mounted_ids.append(prop.get_instance_id())
		var record: Dictionary = source.accessories.filter(func(row): return row.id == identity)[0]
		var owner := world.adapter.resolve(str(record.support)) as Node3D
		check(prop.get_parent() == owner and prop.position.is_equal_approx(Vector3(record.position[0],record.position[1],record.position[2])) and prop.rotation.is_zero_approx(), "original sink attachment and fitted pose")
		check(prop.unit == record.unit and prop.hinge_side == record.hinge_side, "original household and hinge handedness")
		var side := 1. if prop.hinge_side == "left" else -1.
		check(prop._door.position.is_equal_approx(Vector3(side*.230,1.505,-.060)) and prop._door.rotation.is_zero_approx(), "original mirror hinge datum")
		var mirror := prop.mirror_surface()
		check(mirror == prop.get_node("CabinetDoor/MirrorGlass") and mirror.layers == 1<<19 and mirror.is_in_group("planar_mirror_surface"), "original mirror node path and reflection layer retained")
		check(prop.to_local(prop.mirror_center()).is_equal_approx(Vector3(0,1.505,-.070)) and mirror.get_meta("mirror_size") == Vector2(.420,.570), "original mirror plane and dimensions retained")
		mounted_ids.append(mirror.get_instance_id())
		var body := prop.get_node("CabinetDoor/CabinetLeafBody") as AnimatableBody3D
		var shape := body.get_child(0) as CollisionShape3D
		check(body.sync_to_physics and shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.is_equal_approx(Vector3(.46,.61,.030)) and shape.position.is_equal_approx(Vector3(-side*.230,0,-.003)), "original moving solid leaf collision")
		mounted_ids.append(body.get_instance_id())
		var reach := prop.get_node("CabinetReach") as Area3D
		var reach_shape := reach.get_child(0) as CollisionShape3D
		check((reach_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(.54,.69,.24)) and reach_shape.position.is_equal_approx(Vector3(0,1.505,-.08)), "original player cabinet reach")
		var assembly: Dictionary = fixture.runtime.assemblies.filter(func(row): return row.id == instance.variant)[0]
		for part: Dictionary in assembly.parts:
			var parent := prop.get_node("CabinetCarcass") as Node3D if part.component == "Body" else prop._door
			var draw := mirror if part.component == "Mirror" else parent.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.get_meta("native_cabinet_part", "") == part.name, "native stock remains under original fixed or moving owner")
			if draw == null: continue
			var expected: Dictionary = factory._variants[str(instance.variant)].filter(func(row): return row.name == part.name)[0]
			check((parent.transform*draw.transform).is_equal_approx(expected.pose), "native mirror/frame pivot rebase")
			_check_part(draw,part,fixture)
		for contact: Dictionary in fixture.contacts:
			if contact.assembly != instance.variant: continue
			var p: Array = contact.point
			var at := prop.to_global(Vector3(p[0],p[1],p[2]))
			var away := -prop.global_basis.z
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+away*.004,at-away*.004,1))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00005, "native back bears on actual bath wall including 4B extension")
		kept_count += _check_kept(prop,fixture,factory)
		# Explicit material handoff uses the same node the live renderer borrows.
		var fallback := prop._mirror_fallback
		var borrowed := ShaderMaterial.new();borrowed.shader=load("res://shaders/planar_mirror.gdshader")
		prop.set_live_mirror_material(borrowed)
		check(mirror.material_override == borrowed, "original mirror owner can lend native surface its live material")
		prop.set_live_mirror_material(null)
		check(mirror.material_override == fallback, "original mirror fallback restored")
		prop.interact(world.player)
		var deadline := Time.get_ticks_msec()+2000
		while prop._swing<1. and Time.get_ticks_msec()<deadline: await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(prop.is_door_open() and is_equal_approx(prop._door.rotation.y,-side*deg_to_rad(95.)), "ordinary interaction opens the original full hinge")
		check(body.get_parent() == prop._door and prop.mirror_surface() == mirror, "collision and live surface follow the same source hinge")
		check(body.global_transform.is_equal_approx(prop._door.global_transform), "actual solid leaf reaches the original open hinge pose")
		check(_leaf_in_physics(world,prop,body,shape), "physics ray finds the solid leaf at its open target")
		if capture_enabled: await _capture_cabinet(world,prop,record)
		prop.restore_open_state(false)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(not prop.is_door_open() and prop._door.rotation.is_zero_approx(), "existing save restoration closes native leaf")
		check(body.global_transform.is_equal_approx(prop._door.global_transform), "restored solid leaf reaches the closed hinge pose")
		check(_leaf_in_physics(world,prop,body,shape), "physics ray finds the solid leaf at its restored target")
	check(actors.size()==12 and kept_count==28, "all twelve cabinets and twenty-eight source household items")
	check(unique_triangles==int(fixture.triangles), "all unique native cabinet and kept geometry accounted for")
	return {"checks":checks,"actors":actors.size(),"kept_items":kept_count,"unique_triangles":unique_triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _check_part(draw: MeshInstance3D, part: Dictionary, fixture: Dictionary) -> void:
	var key := str(part.name)
	if unique_parts.has(key):
		check(draw.mesh.get_instance_id()==unique_parts[key], "households share immutable native cabinet partitions")
		return
	unique_parts[key]=draw.mesh.get_instance_id()
	_check_cap_mapping(draw.mesh,true)
	var spec: Dictionary = fixture.parts.filter(func(row):return row.name==key)[0]
	check(draw.mesh.get_faces().size()/3==int(spec.triangles), "exact native cabinet partition triangles")
	unique_triangles+=draw.mesh.get_faces().size()/3
	var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
	check(material!=null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)), "native cabinet metre charts")
	check(is_equal_approx(material.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(material.roughness,float(part.finish.roughness)), "native cabinet local finish")
	if part.has("catalog_key"):
		var catalog := MatLib.get_mat(str(part.catalog_key))
		check(material.albedo_texture==catalog.albedo_texture and material.roughness_texture==catalog.roughness_texture and material.normal_texture==catalog.normal_texture, "registered cabinet catalogue maps")

func _check_kept(prop: Cabinet, fixture: Dictionary, factory: RefCounted) -> int:
	var contents := prop.get_node("CabinetContents")
	var original: Array = Cabinet.KEPT[prop.unit]
	check(contents.get_child_count()==original.size() and prop.inventory_names().size()==original.size(), "original kept inventory count")
	var rng := RandomNumberGenerator.new();rng.seed=hash(prop.unit+"cab")
	var used := {0:0,1:0}
	var shelf_draw := prop.get_node("CabinetCarcass").get_node(str(prop.get_meta("v2_native_medicine_variant"))+"__Body_ON_glassish") as MeshInstance3D
	for i in original.size():
		var source: Array = original[i];var shelf := i%2;var n: int = used[shelf];used[shelf]=n+1
		var at := Vector3(-.155+n*.090+rng.randf_range(-.008,.008),float(Cabinet.SHELF_Y[shelf])+float(source[3])*.5+.008,.005+rng.randf_range(-.010,.010))
		var yaw := rng.randf_range(-.28,.28)
		var item := contents.get_child(i) as MeshInstance3D
		var old: Transform3D = item.get_meta("source_kept_transform")
		check(item.mesh==null and old.origin.is_equal_approx(at) and old.basis.is_equal_approx(Basis(Vector3.UP,yaw)), "original seeded item pose retained before shelf seating")
		check(item.get_meta("source_kept_name")==source[0] and prop.inventory_names()[i]==source[0], "original kept identity remains inventory authority")
		check(is_equal_approx(item.position.x,at.x) and is_equal_approx(item.position.z,at.z) and is_equal_approx(item.position.y,float(Cabinet.SHELF_Y[shelf])+.004), "original item footprint and yaw seated on glass")
		var variant := str(item.get_meta("native_kept_variant"))
		var assembly: Dictionary = fixture.runtime.assemblies.filter(func(row):return row.id==variant)[0]
		for part: Dictionary in assembly.parts:
			var draw := item.get_node(str(part.name)) as MeshInstance3D
			check(draw.get_meta("native_kept_part")==part.name, "native kept stock belongs to original household item")
			_check_part(draw,part,fixture)
			if part.key=="bottle" and source[0]!="QUELL TONIC":check(draw.material_override==item.get_meta("source_kept_material"), "original kept amber finish preserved")
		for contact: Dictionary in fixture.contacts:
			if contact.assembly!=variant:continue
			var p: Array = contact.point
			check(_shelf_hit(shelf_draw,item.to_global(Vector3(p[0],p[1],p[2]))), "native kept stock bears on actual native glass shelf")
		if source[0]=="QUELL TONIC":check((item.get_node("SourceTonicLabel") as Label3D).text=="QUELL\nTONIC", "source tonic lettering remains editable geometry")
	return original.size()

func _shelf_hit(draw: MeshInstance3D, target: Vector3) -> bool:
	var start := draw.to_local(target+Vector3.UP*.004)
	var direction := (draw.global_basis.inverse()*Vector3.DOWN).normalized()
	var faces := draw.mesh.get_faces()
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(start,direction,faces[i],faces[i+1],faces[i+2])
		if hit is Vector3 and draw.to_global(hit).distance_to(target)<.00004:return true
	return false

func _leaf_in_physics(world: OrisonV2RuntimeRoot, prop: Cabinet, body: AnimatableBody3D, shape: CollisionShape3D) -> bool:
	var center := prop._door.to_global(shape.position)
	var normal := prop._door.global_basis.z.normalized()
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center-normal*.04,center+normal*.04,1))
	return not hit.is_empty() and hit.collider==body

func _capture_cabinet(world: OrisonV2RuntimeRoot, prop: Cabinet, record: Dictionary) -> void:
	var requested := OS.get_environment("ORISON_FABRICATION_ACTORS").split(",",false)
	if not requested.is_empty() and str(record.id) not in requested: return
	# Let the original animatable leaf reach the physics server before ray QA.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var station := Vector3.INF
	var target := prop.to_global(Vector3(0,1.505,0))
	var bounds := prop._visual_bounds()
	var camera: Camera3D = world.player.camera
	var frame := camera.get_viewport().get_visible_rect().grow(-20)
	var blockers := {}
	var clear_feet := 0
	for distance: float in [1.2,1.45,1.7,1.,.85,2.]:
		for step in 17:
			var angle := deg_to_rad(ceilf(float(step)*.5)*10.*(1. if step%2 else -1.))
			var feet := prop.to_global(Vector3(sin(angle)*distance,-.02,-cos(angle)*distance))
			if not _city_clear_station(world,feet):continue
			clear_feet += 1
			world.player.global_position=feet;world.player.face_world_point(target)
			var blocked := false
			for corner in 8:
				var p := prop.to_global(bounds.get_endpoint(corner))
				if camera.is_position_behind(p) or not frame.has_point(camera.unproject_position(p)):blocked=true
			if blocked:continue
			for x in [-.185,0.,.185]:
				for y in [1.30,1.50,1.70]:
					var p := prop.to_global(Vector3(x,y,-.04))
					var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,p,1,[world.player.get_rid()]))
					if not hit.is_empty() and hit.position.distance_to(p)>.02:
						blocked=true
						var key := str(hit.collider.get_path())
						blockers[key] = {"hit":str(prop.to_local(hit.position)),"target":str(prop.to_local(p)),"camera":str(prop.to_local(camera.global_position))}
			if not blocked:station=feet;break
		if station.is_finite():break
	check(station.is_finite(), "clear view of installed cabinet contents: "+str(record.id))
	if not station.is_finite(): print("CABINET CAMERA: ",record.id," clear_feet=",clear_feet," blockers=",blockers)
	if station.is_finite():
		await _city_capture(world,station,target,str(record.id)+"_native_open","native cabinet and original household stock",str(record.id))
		prop.restore_open_state(false)
		await _city_capture(world,station,prop.mirror_center(),str(record.id)+"_native_mirror","native leaf and live source reflection",str(record.id))
		check(world.mirror_renderer.active_mirror()==prop and prop.mirror_surface().material_override is ShaderMaterial, "single original reflection owner borrows native mirror")
