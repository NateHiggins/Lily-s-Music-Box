extends "res://tests/orison_v2_domestic_native_test.gd"
## All original wardrobe authorities and 42 fitted leaf sweeps in one world.
const Wardrobe := preload("res://scripts/building/orison_v2_wardrobe.gd")

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_household_wardrobes.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256,"wardrobe export matches native construction")
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_wardrobe_factory")
	factory_id = factory.get_instance_id()
	var variants: Dictionary = {}
	for row: Dictionary in fixture.runtime.assemblies: variants[str(row.id)] = row
	var anchors: Dictionary = {}
	var levels: Dictionary = {}
	for row: Dictionary in world.layout.anchors: anchors[str(row.id)] = row
	for row: Dictionary in world.layout.levels: levels[str(row.id)] = float(row.y)
	var actors: Array[Wardrobe] = []
	var original: Dictionary = {}
	var meshes: Dictionary = {}
	var count := 0
	var triangles := 0
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var body := world.adapter.resolve(identity) as Wardrobe
		check(body != null and body.native_ready,"original wardrobe owns native fitted visuals: "+identity)
		if body == null: continue
		actors.append(body); mounted_ids.append(body.get_instance_id())
		original[identity] = body._wardrobe_open
		var anchor: Dictionary = anchors[identity]
		var p: Array = anchor.position
		check(body.global_position.is_equal_approx(world.adapter.root.to_global(Vector3(p[0],float(p[1])+float(levels[str(anchor.level)]),p[2]))) and body.global_basis.is_equal_approx(world.adapter.root.global_basis*Basis(Vector3.UP,float(anchor.yaw))),"original wardrobe anchor and yaw retained")
		check(body.record_id==identity and body.owner_unit==identity.get_slice("_",0) and body.furniture_kind=="wardrobe","original household and private wardrobe identity retained")
		var shapes := body.find_children("*","CollisionShape3D",true,false)
		var collision := shapes[0] as CollisionShape3D if shapes.size()==1 else null
		check(collision != null and collision.shape is BoxShape3D and collision.position.is_equal_approx(Vector3(0,.98,0)) and (collision.shape as BoxShape3D).size.is_equal_approx(Vector3(1.42,2.02,.74)),"original broad wardrobe collider unchanged")
		for component: String in ["LeftLeaf","RightLeaf"]:
			var leaf := body.get_node(component) as Node3D
			mounted_ids.append(leaf.get_instance_id())
			var sign := -1. if component=="LeftLeaf" else 1.
			check(leaf.position.is_equal_approx(Vector3(sign*.615,.10,-.305)) and leaf.rotation.is_zero_approx(),"original closed hinge pivot retained")
		check(body._wardrobe_rattle==body.get_node("PrivateLeafRattle") and body._wardrobe_rattle.bus=="Interaction" and body._wardrobe_rattle.stream!=null,"original interaction audio owner remains")
		for part: Dictionary in variants[str(instance.variant)].parts:
			var parent: Node3D = body if part.component=="Body" else body.get_node(str(part.component))
			var draw := parent.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.owner==null and draw.get_meta("native_wardrobe_part","")==part.name,"native partition follows correct fixed or moving owner")
			if draw==null:continue
			count+=1
			var expected: Dictionary = factory._variants[str(instance.variant)].filter(func(row):return row.name==part.name)[0]
			var pose: Transform3D = draw.transform if parent==body else parent.transform*draw.transform
			check(pose.is_equal_approx(expected.pose),"original hinge rebase preserves native closed geometry")
			if meshes.has(str(part.name)):
				check(draw.mesh.get_instance_id()==meshes[str(part.name)],"source-equivalent wardrobes share immutable native meshes")
			else:
				meshes[str(part.name)]=draw.mesh.get_instance_id()
				_check_cap_mapping(draw.mesh,true)
				var spec: Dictionary = fixture.parts.filter(func(row):return row.name==part.name)[0]
				check(draw.mesh.get_faces().size()/3==int(spec.triangles),"exact native wardrobe partition")
				triangles+=draw.mesh.get_faces().size()/3
				var mat := draw.mesh.surface_get_material(0) as StandardMaterial3D
				var library := MatLib.get_mat(str(part.catalog_key))
				check(mat!=library and mat.albedo_texture==library.albedo_texture and mat.normal_texture==library.normal_texture and mat.roughness_texture==library.roughness_texture,"registered timber cloth and brass maps retained")
				check(not mat.uv1_triplanar and mat.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)) and is_equal_approx(mat.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(mat.roughness,float(part.finish.roughness)),"metre charts and local wardrobe finish retained")
		for probe: Dictionary in fixture.contacts:
			if probe.assembly!=instance.variant:continue
			var v: Array = probe.point
			var at := body.to_global(Vector3(v[0],v[1],v[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"wardrobe plinth meets actual source floor")
	check(actors.size()==21 and meshes.size()==fixture.parts.size() and triangles==int(fixture.triangles),"all 21 wardrobes and 13 source content variants accounted for")
	if capture_enabled:await _wardrobe_captures(world,fixture,"closed")
	for body: Wardrobe in actors:body.interact()
	await get_tree().create_timer(.65).timeout
	for body: Wardrobe in actors:
		check(body._wardrobe_open and is_equal_approx(body._wardrobe_left_leaf.rotation.y,deg_to_rad(92)) and is_equal_approx(body._wardrobe_right_leaf.rotation.y,deg_to_rad(-92)),"ordinary interaction reaches both original 92 degree stops")
		check(body.service_wire_card()==PropServiceWire.card("wardrobe",{"leaf_state":"OPEN","owner_state":"%s RESIDENT / PRIVATE" % body.owner_unit}),"original private service card reflects open state")
	if capture_enabled:await _wardrobe_captures(world,fixture,"open")
	for body: Wardrobe in actors:body.interact()
	await get_tree().create_timer(.65).timeout
	for body: Wardrobe in actors:
		check(not body._wardrobe_open and body._wardrobe_left_leaf.rotation.is_zero_approx() and body._wardrobe_right_leaf.rotation.is_zero_approx(),"ordinary interaction closes native leaves at original pivots")
		if bool(original[body.record_id]):body.interact()
	await _completion_workbench(world)
	return {"checks":checks,"actors":actors.size(),"parts":count,"unique_triangles":triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _completion_workbench(world: OrisonV2RuntimeRoot) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_work_tables.json"))
	var body := world.adapter.resolve("b1_repair_bench") as StaticBody3D
	var template := world.adapter.resolve("3B_workbench") as StaticBody3D
	check(body!=null and body.get_meta("v2_native_work_table","")=="b1_repair_bench","completion repair bench adopts its verified native template")
	if body==null:return
	mounted_ids.append(body.get_instance_id())
	var row: Dictionary = fixture.runtime.assemblies.filter(func(item):return item.id=="3B_workbench")[0]
	for part: Dictionary in row.parts:
		var draw := body.get_node_or_null(str(part.name)) as MeshInstance3D
		var reference := template.get_node(str(part.name)) as MeshInstance3D
		check(draw!=null and draw.get_parent()==body and draw.owner==null,"completion owner retains native repair-bench partition")
		if draw!=null:
			check(draw.transform.is_equal_approx(reference.transform) and draw.mesh.get_faces()==reference.mesh.get_faces(),"completion bench uses identical accepted native geometry")
			var mat := draw.mesh.surface_get_material(0) as StandardMaterial3D
			var source := reference.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat.albedo_texture==source.albedo_texture and mat.uv1_scale.is_equal_approx(source.uv1_scale),"completion bench retains reviewed metre material")
	var shapes := body.find_children("*","CollisionShape3D",false,false)
	check(shapes.size()==row.parts.size(),"completion bench replaces broad hull with exact native partitions")
	for shape: CollisionShape3D in shapes:check(shape.shape is ConcavePolygonShape3D,"completion bench exact collision")
	for probe: Dictionary in fixture.contacts:
		if probe.assembly!="3B_workbench":continue
		var p: Array = probe.point
		var at := body.to_global(Vector3(p[0],p[1],p[2]))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
		check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"completion repair bench has actual floor bearing")
	if not capture_enabled or not OS.get_environment("ORISON_FABRICATION_ACTORS").is_empty():return
	var bounds := AABB()
	for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):bounds=bounds.merge(draw.transform*draw.mesh.get_aabb())
	var station := Vector3.INF
	for scale in [1.,1.25,1.5,.85,2.]:
		for step in 24:
			var angle := deg_to_rad(ceilf(float(step)*.5)*15.*(1. if step%2 else -1.))
			var feet := body.to_global(Vector3(sin(angle),0,-cos(angle))*2.*float(scale)+Vector3.UP*.02)
			if _city_clear_station(world,feet) and _framed_at(world,body,bounds,feet):station=feet;break
		if station.is_finite():break
	check(station.is_finite(),"clear full completion workbench view")
	if station.is_finite():await _city_capture(world,station,body.to_global(bounds.get_center()),"b1_repair_bench_native","native completion repair bench","b1_repair_bench")

func _wardrobe_captures(world: OrisonV2RuntimeRoot,fixture: Dictionary,state: String) -> void:
	var representatives: Array[String] = []
	for row: Dictionary in fixture.assemblies:
		if state=="closed" and representatives.size()>=2:break
		representatives.append(str(row.source_record))
	if state=="open":representatives.append("1A_wardrobe")
	var requested := OS.get_environment("ORISON_FABRICATION_ACTORS").split(",",false)
	for identity: String in representatives:
		if not requested.is_empty() and not identity in requested:continue
		var body := world.adapter.resolve(identity) as Wardrobe
		var bounds := AABB()
		for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			bounds=bounds.merge(body.global_transform.affine_inverse()*draw.global_transform*draw.mesh.get_aabb())
		var radius := maxf(2.1,bounds.size.y*1.12)
		var station := Vector3.INF
		var original_fov := world.player.camera.fov
		# Prefer an unobstructed view into the open case. In compact bedrooms a
		# wider inspection lens fits the near leaf before resorting to side views.
		for step in 17:
			var angle := deg_to_rad(ceilf(float(step)*.5)*10.*(1. if step%2 else -1.))
			for fov: float in [original_fov,90.,100.]:
				world.player.camera.fov=fov
				for scale in [1.,1.25,1.5,.85,.65,.5,2.]:
					var feet := body.to_global(Vector3(sin(angle),0,-cos(angle))*radius*float(scale)+Vector3.UP*.02)
					if _city_clear_station(world,feet) and _framed_at(world,body,bounds,feet):station=feet;break
				if station.is_finite():break
			if station.is_finite():break
		check(station.is_finite(),"clear full wardrobe camera station: "+identity+" "+state)
		if station.is_finite():
			await _city_capture(world,station,body.to_global(bounds.get_center()),identity+"_"+state,"native private wardrobe",identity)
			discovery[-1]["inspection_fov"]=world.player.camera.fov
		world.player.camera.fov=original_fov
