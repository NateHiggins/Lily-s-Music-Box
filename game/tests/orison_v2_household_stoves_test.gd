extends "res://tests/orison_v2_domestic_native_test.gd"
const Stove := preload("res://scripts/building/orison_v2_stove.gd")
var unique: Dictionary = {}
var triangles := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_household_stoves.json"))
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_stove_factory")
	factory_id = factory.get_instance_id()
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256,"native stove export bound")
	var actors: Array[Stove] = []
	var states: Dictionary = {}
	for instance: Dictionary in fixture.runtime.instances:
		var prop := world.adapter.resolve(str(instance.id)) as Stove
		check(prop != null and prop.native_ready,"original range owns native stock: "+str(instance.id))
		if prop == null:continue
		actors.append(prop);mounted_ids.append(prop.get_instance_id())
		var source: Dictionary = fixture.original_records.filter(func(row):return row.id==instance.id)[0]
		check(prop.unit==source.unit and prop.ambient_lit==source.properties.ambient_lit and prop.prop_type=="stove","household source properties retained")
		var anchor: Dictionary = world.layout.anchors.filter(func(row):return row.id==instance.id)[0]
		var level: Dictionary = world.layout.levels.filter(func(row):return row.id==anchor.level)[0]
		var p: Array = anchor.position
		check(prop.global_position.is_equal_approx(world.adapter.root.to_global(Vector3(p[0],float(p[1])+float(level.y),p[2]))) and prop.global_basis.is_equal_approx(world.adapter.root.global_basis*Basis(Vector3.UP,float(anchor.yaw))),"source stove anchor and yaw retained")
		check(prop._door==prop.get_node("OvenDoor") and prop._door.position.is_equal_approx(Vector3(0,.34,-.318)) and prop._broiler.position.is_equal_approx(Vector3(0,.205,-.316)),"original oven and lower leaf pivots")
		check(prop._clunk!=null and prop._burn!=null and prop._grates.size()==4 and prop._caps.size()==4 and prop._knobs.size()==4,"source service and audio owners retained")
		var body := prop.get_node("FixtureBody") as StaticBody3D
		check(prop.get_node_or_null("PrimaryInteraction") is Area3D and body!=null,"original functional interaction and fixture collision retained")
		for contact: Dictionary in fixture.contacts:
			var q: Array = contact.point
			var at := prop.to_global(Vector3(q[0],q[1],q[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"actual floor bears native range")
		# Each range walks its own assembly: owner finishes (dossier slice 36) are their own variants.
		var assembly: Dictionary = fixture.runtime.assemblies.filter(func(row):return row.id==instance.variant)[0]
		check(prop.get_meta("v2_native_stove_variant","")==instance.variant,"range installs its own source variant")
		for part: Dictionary in assembly.parts:
			var draw := prop.find_child(str(part.name),true,false) as MeshInstance3D
			check(draw!=null and draw.get_meta("native_stove_part","")==part.name,"native source partition retained")
			if draw==null:continue
			var expected: Dictionary = factory._variants[str(instance.variant)].filter(func(row):return row.name==part.name)[0]
			var expected_pose: Transform3D = expected.pose
			if str(part.component).begins_with("BurnerValve"):
				# Two source households boot with a lit ring; its live valve is
				# already turned by the original controller before this validator.
				var valve: Node3D = prop.get_node(str(part.component))
				expected_pose = valve.transform*Transform3D(Basis.IDENTITY,valve.position).affine_inverse()*expected_pose
			check((prop.global_transform.affine_inverse()*draw.global_transform).is_equal_approx(expected_pose),"partition follows current source owner frame")
			_check_part(draw,part,fixture)
			if part.key=="enamel":check((draw.material_override as StandardMaterial3D).albedo_color.is_equal_approx(prop._enamel_tint()),"original household enamel tone")
			elif str(part.key).begins_with("enamel_"):check(draw.material_override==null and draw.get_meta("material_key","")==part.key,"owner enamel finish replaces the household tone")
		states[prop.name] = {"blocked":prop.blocked_burner,"grime":prop.burner_grime.duplicate(),"on":prop._burner_on.duplicate()}
		for i in 4:
			check(prop._grates[i].position==prop._grate_home[i] and prop._caps[i].position==prop._cap_home[i],"source burner home retained")
			check(prop._jet_plugs[i].get_parent().get_parent()==prop._caps[i] and prop._grease[i].get_parent()==prop and prop._flames[i].get_parent()==prop,"live jet, grease and flame owners retained")
			check(prop._jet_plugs[i].visible==(i==prop.blocked_burner),"original blocked-jet state retained")
		prop.set_door_open(true,.01)
	await _settle(actors,-1,true)
	for prop: Stove in actors:
		check(prop._open and is_equal_approx(prop._door.rotation.x,deg_to_rad(-86.)),"original oven opens through full source travel")
		if capture_enabled and prop.unit in ["1A","2B","5B"]:await _capture_stove(world,prop,"open")
	for i in 4:
		for prop: Stove in actors:
			prop.set_grate_removed(i,true,.02);prop.set_cap_removed(i,true,.02)
		await _settle(actors,i,true)
		for prop: Stove in actors:
			check(prop._grates[i].position.is_equal_approx(Vector3(-.20 if i%2==0 else .20,.995,.205)) and is_equal_approx(prop._grates[i].rotation.x,deg_to_rad(-68.)),"source grate service transform remains authoritative")
			check(prop._caps[i].position.is_equal_approx(prop._cap_home[i]+Vector3(.12 if i%2==0 else -.12,.018,-.12)),"source cap service transform retained")
			var row: Dictionary = fixture.runtime.native_service.grate_parking[i]
			var p: Array = row.blender_center
			var presentation: Node3D = prop._grates[i].get_node("NativeServiceStock")
			var local := prop.global_transform.affine_inverse()*presentation.global_transform
			check(local.origin.is_equal_approx(Vector3(p[0],p[2],-p[1])) and local.basis.is_equal_approx(Basis(Vector3.RIGHT,deg_to_rad(row.angle_degrees))),"native grate seats at inspected parking contact")
			var delta: Array = fixture.runtime.native_service.cap_end_blender_delta[i]
			presentation=prop._caps[i].get_node("NativeServiceStock")
			local=prop.global_transform.affine_inverse()*presentation.global_transform
			check(local.origin.is_equal_approx(prop._cap_home[i]+Vector3(delta[0],delta[2],-delta[1])),"native loose cap rests on deck")
			if capture_enabled and prop.unit=="2B" and i in [0,2]:await _capture_stove(world,prop,"service"+str(i))
			prop.set_grate_removed(i,false,.02);prop.set_cap_removed(i,false,.02)
		await _settle(actors,i,false)
		for prop: Stove in actors:
			check((prop._grates[i].get_node("NativeServiceStock") as Node3D).transform.is_equal_approx(Transform3D.IDENTITY) and (prop._caps[i].get_node("NativeServiceStock") as Node3D).transform.is_equal_approx(Transform3D.IDENTITY),"source restoration leaves no visual drift")
	for prop: Stove in actors:
		var blocked := prop.blocked_burner
		check(not prop.set_burner_lit(blocked,true,.01),"original blocked jet refuses ignition")
	await get_tree().create_timer(.35).timeout
	for prop: Stove in actors:
		var blocked := int(states[prop.name].blocked)
		check(not prop._flames[blocked].visible,"source blocked-jet cough extinguishes")
		prop.clear_jet(blocked)
		check(prop.blocked_burner==-1 and not prop._jet_plugs[blocked].visible and is_equal_approx(prop.burner_grime[blocked],float(states[prop.name].grime[blocked])*.25),"original clearing activity retains grime and jet behavior")
		check(prop.set_burner_lit(blocked,true,.01),"serviced original burner lights")
		check(prop._flames[blocked].visible and is_equal_approx(prop._knobs[blocked].rotation.z,deg_to_rad(-58.)),"native knob follows original ignition owner")
		for i in 4:
			prop.set_burner_lit(i,bool(states[prop.name].on[i]),.01,true)
			prop.set_burner_grime(i,float(states[prop.name].grime[i]))
		prop.set_jet_blocked(blocked,true)
		prop.interact(world.player)
	await _settle(actors,-1,false)
	for prop: Stove in actors:
		check(not prop._open and is_zero_approx(prop._door.rotation.x),"ordinary interaction closes original oven")
		if capture_enabled and prop.unit in ["1A","2B","5B"]:await _capture_stove(world,prop,"closed")
	check(actors.size()==18 and triangles==int(fixture.triangles),"all source ranges and unique native triangles covered")
	_write_visual_census(world)
	return {"checks":checks,"actors":actors.size(),"unique_triangles":triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _write_visual_census(world: OrisonV2RuntimeRoot) -> void:
	var rows: Array = []
	for node: Node in world.find_children("*","Node3D",true,false):
		if node is not FunctionalProp:continue
		var prop := node as FunctionalProp
		var meshes: Array = []
		for draw: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
			if draw.mesh==null:continue
			meshes.append({"name":str(draw.name),"class":draw.mesh.get_class(),"resource":draw.mesh.resource_path,"visible":draw.is_visible_in_tree(),"triangles":draw.mesh.get_faces().size()/3})
		var tags: Dictionary = {}
		for key: StringName in prop.get_meta_list():
			if str(key).begins_with("v2_"):tags[str(key)]=str(prop.get_meta(key))
		rows.append({"id":str(prop.name),"kind":prop.prop_type,"script":prop.get_script().resource_path,"position":[prop.global_position.x,prop.global_position.y,prop.global_position.z],"native_tags":tags,"meshes":meshes})
	var file := FileAccess.open(OS.get_environment("SHOT_DIR").path_join("visual_census.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Live production FunctionalProp visual inventory for review planning; presence is not visual acceptance.","actors":rows},"\t"))

func _settle(actors: Array[Stove], index: int, opened: bool) -> void:
	var deadline := Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<deadline:
		var pending := false
		for prop: Stove in actors:
			if index<0:pending = pending or not is_equal_approx(prop._door.rotation.x,deg_to_rad(-86.) if opened else 0.)
			else:pending = pending or not is_equal_approx(prop._grates[index].rotation.x,deg_to_rad(-68.) if opened else 0.) or not is_equal_approx(prop._caps[index].position.y,prop._cap_home[index].y+(.018 if opened else 0.))
		if not pending:return
		await get_tree().process_frame

func _check_part(draw: MeshInstance3D, part: Dictionary, fixture: Dictionary) -> void:
	if unique.has(str(part.name)):
		check(draw.mesh.get_instance_id()==unique[str(part.name)], "native immutable geometry shared across households")
		return
	unique[str(part.name)] = draw.mesh.get_instance_id()
	_check_cap_mapping(draw.mesh,true)
	var spec: Dictionary = fixture.parts.filter(func(row): return row.name == part.name)[0]
	check(draw.mesh.get_faces().size()/3==int(spec.triangles), "exact native partition triangles")
	triangles += draw.mesh.get_faces().size()/3
	var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
	var catalog := MatLib.get_mat(str(part.catalog_key))
	check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)), "native metre charts retained")
	check(material.albedo_texture==catalog.albedo_texture and material.roughness_texture==catalog.roughness_texture and material.normal_texture==catalog.normal_texture, "registered material maps retained")
	check(is_equal_approx(material.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(material.roughness,float(part.finish.roughness)), "local finish calibration retained")

func _capture_stove(world: OrisonV2RuntimeRoot, prop: Stove, state: String) -> void:
	var requested := OS.get_environment("ORISON_FABRICATION_ACTORS").split(",",false)
	if not requested.is_empty() and str(prop.name) not in requested:return
	var bounds := prop._visual_bounds()
	var station := Vector3.INF
	var target := prop.to_global(Vector3(0,.62,0))
	var camera: Camera3D = world.player.camera
	var old_fov := camera.fov
	var frame := camera.get_viewport().get_visible_rect().grow(-20)
	var body := prop.get_node("FixtureBody") as StaticBody3D
	for fov: float in [72.,90.]:
		camera.fov=fov
		for step in 17:
			var angle := deg_to_rad(ceilf(float(step)*.5)*10.*(1. if step%2 else -1.))
			for distance: float in [1.6,1.9,2.2,1.35,1.15,2.5]:
				var feet := prop.to_global(Vector3(sin(angle)*distance,.02,-cos(angle)*distance))
				if not _city_clear_station(world,feet):continue
				world.player.global_position=feet
				world.player.face_world_point(target)
				var blocked := false
				for corner in 8:
					var p := prop.to_global(bounds.get_endpoint(corner))
					if camera.is_position_behind(p) or not frame.has_point(camera.unproject_position(p)):blocked=true
				if blocked:continue
				for x in [-.24,0.,.24]:
					for y in [.36,.52,.67]:
						var p := prop.to_global(Vector3(x,y,-.30))
						var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,p,1,[world.player.get_rid(),body.get_rid()]))
						if not hit.is_empty() and hit.position.distance_to(p)>.02:blocked=true
						if state != "closed" and _leaf_occludes(prop,camera.global_position,p):blocked=true
				if not blocked:station=feet;break
			if station.is_finite():break
		if station.is_finite():break
	check(station.is_finite(), "clear installed stove framing: "+str(prop.name)+" "+state)
	if station.is_finite():await _city_capture(world,station,target,str(prop.name)+"_native_"+state,"native gas range and original service controls",str(prop.name))
	camera.fov=old_fov

func _leaf_occludes(prop: Stove, eye: Vector3, target: Vector3) -> bool:
	for owner: Node3D in [prop._door,prop.get_node("StaticCarcass")]:
		for node: Node in owner.get_children():
			if node is not MeshInstance3D:continue
			var draw := node as MeshInstance3D
			var start := draw.to_local(eye)
			var end := draw.to_local(target)
			var direction := (end-start).normalized()
			var faces := draw.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(start,direction,faces[i],faces[i+1],faces[i+2])
				if hit is Vector3 and start.distance_to(hit)<start.distance_to(end)-.002:return true
	return false
