extends "res://tests/orison_v2_domestic_native_test.gd"
## Five source actors share stock while retaining their original mechanisms.
const Radio := preload("res://scripts/building/orison_v2_specialist_radio.gd")

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_household_radios.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"radio native export bound to construction")
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_radio_factory")
	factory_id = factory.get_instance_id()
	var actors: Array[Radio] = []
	var meshes: Dictionary = {}
	var anchors: Dictionary = {}
	var levels: Dictionary = {}
	for anchor: Dictionary in world.layout.anchors:anchors[str(anchor.id)]=anchor
	for level: Dictionary in world.layout.levels:levels[str(level.id)]=float(level.y)
	var count := 0
	var triangles := 0
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var body := world.adapter.resolve(identity) as Radio
		check(body!=null and body.native_ready,"original radio owns native cabinet: "+identity)
		if body==null:continue
		actors.append(body);mounted_ids.append(body.get_instance_id());mounted_ids.append(body._radio_knob.get_instance_id())
		var anchor: Dictionary = anchors[identity]
		var p: Array = anchor.position
		check(body.global_position.is_equal_approx(world.adapter.root.to_global(Vector3(p[0],float(p[1])+float(levels[str(anchor.level)]),p[2]))) and body.global_basis.is_equal_approx(world.adapter.root.global_basis*Basis(Vector3.UP,float(anchor.yaw))),"original radio anchor and yaw retained")
		check(body.record_id==identity and body.owner_unit==identity.get_slice("_",0) and body.furniture_kind=="radio","original identity and household retained")
		check(body._radio_knob==body.get_node("PowerTuningKnob") and body._radio_knob.position.is_equal_approx(Vector3(.14,.062,-.139)),"original tuning owner and pivot retained")
		check(not body._powered and body._radio_knob.rotation.is_zero_approx(),"original initial radio state retained")
		var shapes := body.find_children("*","CollisionShape3D",true,false)
		var collision := shapes[0] as CollisionShape3D if shapes.size()==1 else null
		check(collision!=null and collision.shape is BoxShape3D and (collision.shape as BoxShape3D).size.is_equal_approx(Vector3(.48,.34,.34)) and collision.position.is_equal_approx(Vector3(0,.14,-.02)),"original broad interaction collision retained")
		check(body._radio_bed==body.get_node("ValveProgramme") and body._radio_bed.bus=="Broadcast" and body._control_click==body.get_node("RadioSwitchClick") and body._control_click.bus=="Interaction","original audio owners retained")
		for part: Dictionary in fixture.runtime.assemblies[0].parts:
			var parent: Node3D = body if part.component=="Body" else body._radio_knob
			var draw := parent.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw!=null and draw.owner==null and draw.get_meta("native_radio_part","")==part.name,"native geometry stays under fixed or moving original owner")
			if draw==null:continue
			count+=1
			var expected: Dictionary = factory._variants[str(instance.variant)].filter(func(row):return row.name==part.name)[0]
			var pose: Transform3D = draw.transform if parent==body else parent.transform*draw.transform
			check(pose.is_equal_approx(expected.pose),"tuning pivot rebase preserves native rest pose")
			if meshes.has(str(part.name)):
				check(draw.mesh.get_instance_id()==meshes[str(part.name)],"five radios share immutable native partitions")
			else:
				meshes[str(part.name)]=draw.mesh.get_instance_id()
				_check_cap_mapping(draw.mesh,true)
				var spec: Dictionary = fixture.parts.filter(func(row):return row.name==part.name)[0]
				check(draw.mesh.get_faces().size()/3==int(spec.triangles),"exact native radio partition")
				triangles+=draw.mesh.get_faces().size()/3
				var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
				check(material!=null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"radio metre charts retained")
				check(is_equal_approx(material.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(material.roughness,float(part.finish.roughness)),"radio finish parameters retained")
				if part.has("catalog_key"):
					var source := MatLib.get_mat(str(part.catalog_key))
					check(material!=source and material.albedo_texture==source.albedo_texture and material.roughness_texture==source.roughness_texture and material.normal_texture==source.normal_texture,"local radio finish retains registered maps")
				if part.has("tint"):
					var tint: Array = part.tint
					check(material.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3]).linear_to_srgb()),"radio source finish colour retained")
				if part.key=="glassish":
					var glass := draw.material_override as ShaderMaterial
					check(glass!=null and glass.shader.resource_path==fixture.runtime.optics.shader and is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),float(fixture.runtime.optics.surface_roughness)),"existing dielectric owner supplies dial glazing")
		for contact: Dictionary in fixture.contacts:
			var point: Array = contact.point
			var at := body.to_global(Vector3(point[0],point[1],point[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99,"actual native furniture supports radio: "+identity)
	check(actors.size()==5 and triangles==int(fixture.triangles),"all five source radios and shared native geometry accounted for")
	for body: Radio in actors:body.interact()
	for body: Radio in actors:
		if body._control_tween.is_running():await body._control_tween.finished
	for body: Radio in actors:
		check(body._powered and is_equal_approx(body._radio_knob.rotation.z,deg_to_rad(42.)) and body._radio_bed.playing,"ordinary radio interaction powers audio and turns native knob: %s power=%s angle=%s audio=%s" % [body.record_id,body._powered,body._radio_knob.rotation.z,body._radio_bed.playing])
		check(body.interact_prompt().contains("off"),"original prompt follows powered state")
	if capture_enabled:await _radio_captures(world,actors,anchors,levels)
	for body: Radio in actors:body.interact()
	for body: Radio in actors:
		if body._control_tween.is_running():await body._control_tween.finished
	for body: Radio in actors:check(not body._powered and body._radio_knob.rotation.is_zero_approx() and not body._radio_bed.playing,"ordinary interaction switches audio off and restores native knob")
	return {"checks":checks,"actors":actors.size(),"parts":count,"unique_triangles":triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _radio_captures(world: OrisonV2RuntimeRoot,actors: Array[Radio],anchors: Dictionary,levels: Dictionary) -> void:
	var requested := OS.get_environment("ORISON_FABRICATION_ACTORS").split(",",false)
	for identity: String in requested:check(actors.any(func(body):return body.record_id==identity),"requested radio capture exists")
	for body: Radio in actors:
		if not requested.is_empty() and not body.record_id in requested:continue
		var bounds := AABB()
		for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):bounds=bounds.merge(body.global_transform.affine_inverse()*draw.global_transform*draw.mesh.get_aabb())
		var station := Vector3.INF
		for step in 17:
			var angle := deg_to_rad(ceilf(float(step)*.5)*10.*(1. if step%2 else -1.))
			for distance: float in [.8,1.,1.25,1.5,.65,2.]:
				var feet := body.to_global(Vector3(sin(angle),0,-cos(angle))*distance)
				feet.y=world.adapter.root.global_position.y+float(levels[str(anchors[body.record_id].level)])+.02
				if _city_clear_station(world,feet) and _framed_at(world,body,bounds,feet):station=feet;break
			if station.is_finite():break
		check(station.is_finite(),"unobstructed installed radio view: "+body.record_id)
		if station.is_finite():await _city_capture(world,station,body.to_global(bounds.get_center()),body.record_id+"_native","native household radio with original power control",body.record_id)

func _framed_at(world: OrisonV2RuntimeRoot,body: Node3D,bounds: AABB,feet: Vector3) -> bool:
	world.player.global_position=feet
	world.player.face_world_point(body.to_global(bounds.get_center()))
	var camera: Camera3D = world.player.camera
	var frame := camera.get_viewport().get_visible_rect().grow(-16)
	for corner in 8:
		var point := body.to_global(bounds.get_endpoint(corner))
		if camera.is_position_behind(point) or not frame.has_point(camera.unproject_position(point)):return false
	# Check the actual grille and controls. A high shelf correctly occludes rear
	# underside corners; those are not a defect in a frontal cabinet inspection.
	var local_eye := body.to_local(camera.global_position)
	if local_eye.z>=-.16:return false
	for x in [-.14,0.,.14]:
		for y in [.062,.18,.255]:
			var target := body.to_global(Vector3(x,y,-.119))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,target,1,[world.player.get_rid(),(body as CollisionObject3D).get_rid()]))
			if not hit.is_empty() and hit.position.distance_to(target)>.01:return false
	return true
