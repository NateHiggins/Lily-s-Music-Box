extends "res://tests/orison_v2_domestic_native_test.gd"
## Shared production-world proof of mounted stock and retained light ownership.

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_fixed_lighting.json"))
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/light_provenance.json"))
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_fixed_lighting_factory")
	factory_id = factory.get_instance_id()
	var former: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_fixture_mounts.json"))
	var former_names: Array = former.parts.filter(func(p):return str(p.name).begins_with("F01_BAR_LT_")).map(func(p):return str(p.name))
	check(factory.superseded_bar_mounts.size()==former_names.size(), "superseded bar mounts removed once")
	for identity: String in factory.superseded_bar_mounts: check(identity in former_names,"only superseded light mount stock removed")
	var remaining := 0
	for draw: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if draw.has_meta("bar_fixture_mount_part"):
			check(str(draw.get_meta("bar_fixture_mount_part")).begins_with("CanopyStay"),"canopy stays retained without duplicate lamp supports")
			remaining+=1
	check(remaining==8,"all original independent canopy stay partitions retained")
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256, "fixed-light native export bound")
	var variants := {}
	var unique := {}
	var triangles := 0
	var parts := 0
	var captures: Array[LightFixtureProp] = []
	for row: Dictionary in fixture.runtime.instances:
		var identity := str(row.id)
		var prop: LightFixtureProp = factory.installed[identity].get_ref()
		check(prop != null and str(prop.name) == identity and prop.get_script().resource_path == "res://scripts/props/light_fixture_prop.gd", "original fixed-light authority: " + identity)
		if prop == null: continue
		mounted_ids.append(prop.get_instance_id())
		var source: Dictionary = prop.get_meta("v2_source_light_snapshot")
		# The original LightRig applies maintenance-card tuning after fabrication mounts.
		var expected_range := clampf(float(provenance.fixtures.get(identity,{}).get("tuning",{}).get("range",source.range)),1.5,16.)
		check(prop.transform.is_equal_approx(source.actor_pose) and prop.graph_node_id == source.graph_node_id, "source anchor and acoustic identity retained")
		check(prop.light.get_instance_id() == source.light and prop.bounce.get_instance_id() == source.bounce and prop._halo.get_instance_id() == source.halo and prop._swing_node.get_instance_id() == source.swing, "original emitter, bounce, halo and swing owners retained")
		check(prop._bulb_mat.get_instance_id() == source.bulb_material and prop._bulb_mat.emission_enabled, "original dynamic envelope material retained")
		if not (prop.light.transform.is_equal_approx(source.light_pose) and is_equal_approx(prop._base_energy,float(source.base_energy)) and is_equal_approx(prop.light.omni_range,expected_range) and prop.navigation_light == source.navigation and is_equal_approx(prop.standby_scale,float(source.standby))):
			print("LIGHT SETTINGS ",identity," pose=",prop.light.transform," before=",source.light_pose," energy=",prop._base_energy,"/",source.base_energy," range=",prop.light.omni_range,"/",source.range," navigation=",prop.navigation_light,"/",source.navigation," standby=",prop.standby_scale,"/",source.standby)
		check(prop.light.transform.is_equal_approx(source.light_pose) and is_equal_approx(prop._base_energy,float(source.base_energy)) and is_equal_approx(prop.light.omni_range,expected_range) and prop.navigation_light == source.navigation and is_equal_approx(prop.standby_scale,float(source.standby)), "original emission frame and photometric settings retained")
		check(prop.bounce.position.is_equal_approx(source.bounce_pose.origin+factory._offsets[identity]), "original bounce follows explicit fixture fitting offset")
		check(prop._swing_node.position.is_equal_approx(factory._offsets[identity]), "explicit visual fitting offset applied only once")
		var variant := str(row.variant)
		if not variants.has(variant): captures.append(prop)
		variants[variant] = true
		for part: Dictionary in factory._variants[variant]:
			var owner := prop if part.component == "Mount" else prop._swing_node
			var draw := owner.get_node_or_null(str(part.name)) as MeshInstance3D
			check(draw != null and draw.get_meta("native_fixed_light_part", "") == part.name and draw.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "native part retains source shadow exclusion")
			if draw == null: continue
			parts += 1
			var expected: Transform3D = part.pose
			if part.component == "Mount": expected.origin += factory._offsets[identity]
			check(draw.transform.is_equal_approx(expected), "fixed ceiling stock and moving fixture use correct owners")
			if part.component == "Bulb": check(draw.material_override == prop._bulb_mat, "native opal envelope follows original powered state")
			if unique.has(str(part.name)):
				check(draw.mesh.get_instance_id() == unique[str(part.name)], "identical lights share immutable native mesh")
			else:
				unique[str(part.name)] = draw.mesh.get_instance_id()
				_check_cap_mapping(draw.mesh,true)
				var record: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
				check(draw.mesh.get_faces().size()/3 == int(record.triangles), "exact native lighting partition")
				triangles += draw.mesh.get_faces().size()/3
				var spec: Dictionary = fixture.runtime.assemblies.filter(func(a): return a.id == variant)[0].parts.filter(func(p): return p.name == part.name)[0]
				var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
				var catalog := MatLib.get_mat(str(spec.catalog_key))
				check(material != null and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(spec.tile)), "lighting metre charts retained")
				check(material.albedo_texture == catalog.albedo_texture and material.normal_texture == catalog.normal_texture and material.roughness_texture == catalog.roughness_texture, "registered lighting maps retained")
				check(is_equal_approx(material.normal_scale,float(spec.finish.normal_scale)) and is_equal_approx(material.roughness,float(spec.finish.roughness)), "local material calibration retained")
		for contact: Dictionary in fixture.contacts:
			if contact.assembly != variant: continue
			var p: Array = contact.point
			var d: Array = contact.direction
			var at := prop.to_global(Vector3(p[0],p[1],p[2])+factory._offsets[identity])
			var direction: Vector3 = prop.global_basis * Vector3(d[0],d[1],d[2])
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+direction*.004,at-direction*.004,1))
			var retained_face := false
			if identity in ["F01_BAR_LT_WELL","F01_BAR_LT_TAB1","F01_BAR_LT_TAB2"]:
				retained_face = _retained_face_contact(world,identity,at,direction)
			if not retained_face and (hit.is_empty() or hit.position.distance_to(at)>=.00005):
				var nearby := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+direction*.2,at-direction*.2,1))
				print("LIGHT CONTACT ",identity," at=",at," direction=",direction," hit=",hit," nearby=",nearby)
			check(retained_face or (not hit.is_empty() and hit.position.distance_to(at)<.00005 and hit.normal.dot(direction)>.99), "actual retained-surface light attachment: "+identity)
	check(mounted_ids.size() == fixture.runtime.instances.size() and variants.size() == fixture.runtime.assemblies.size() and triangles == int(fixture.triangles), "every installed native lighting actor and variant accounted for")
	var switches := world.get_node("V2RoomSwitches") as SwitchSystem
	for room: String in switches._room_fixtures:
		var before := switches.room_snapshot(room)
		check(not before.is_empty(), "room circuit resolves original fixed lights")
		switches.toggle_room(room)
		var after := switches.room_snapshot(room)
		for identity: String in before: check(after[identity] != before[identity], "existing room switch controls native fixture")
		check(switches.restore_room(room,before) and switches.room_snapshot(room) == before, "existing circuit restore retains native fixture state")
	var sconce: LightFixtureProp = factory.installed["3B_LT_SCONCE"].get_ref()
	check((sconce._halo.mesh as QuadMesh).size.is_equal_approx(Vector2(.205,.205)), "sconce halo fitted to source globe beside mirror")
	var sconce_bounds := _light_bounds(sconce)
	var clearance_shape := BoxShape3D.new()
	clearance_shape.size = sconce_bounds.size-Vector3.ONE*.0002
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = clearance_shape
	clearance.transform = sconce.global_transform*Transform3D(Basis.IDENTITY,sconce_bounds.get_center())
	clearance.collision_mask = 1
	check(world.get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty(),"3B sconce envelope clears bath fittings and opening trim")
	var basement: LightFixtureProp = factory.installed["B1_SERVICE_CORE_LT"].get_ref()
	if basement not in captures: captures.append(basement)
	var well_pendant: LightFixtureProp = factory.installed["F01_BAR_LT_TAB2"].get_ref()
	if well_pendant not in captures: captures.append(well_pendant)
	var bar_sconce: LightFixtureProp=factory.installed["F01_BAR_LT_WEST1"].get_ref()
	if bar_sconce not in captures:captures.append(bar_sconce)
	var bounds := _light_bounds(basement)
	check(absf(world.adapter.root.to_local(basement.to_global(bounds.position)).y-1.14)<.0001, "basement fixture bottom clears lower stair landing by 2.74 metres")
	if capture_enabled:
		var requested := OS.get_environment("ORISON_FIXED_LIGHTING_CAPTURE_IDS").split(",",false)
		for identity: String in requested:
			if factory.installed.has(identity):
				var selected: LightFixtureProp=factory.installed[identity].get_ref()
				if selected not in captures:captures.append(selected)
		for prop: LightFixtureProp in captures:
			if requested.is_empty() or str(prop.name) in requested: await _capture_light(world,prop)
	return {"checks":checks,"actors":mounted_ids.size(),"variants":variants.size(),"parts":parts,"unique_triangles":triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _light_bounds(prop: LightFixtureProp) -> AABB:
	var result := AABB()
	var first := true
	for node: Node in prop.find_children("*","MeshInstance3D",true,false):
		if not node.has_meta("native_fixed_light_part"): continue
		var draw := node as MeshInstance3D
		var bounds := prop.global_transform.affine_inverse()*draw.global_transform*draw.mesh.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result

func _capture_light(world: OrisonV2RuntimeRoot, prop: LightFixtureProp) -> void:
	var bounds := _light_bounds(prop)
	var identity := str(prop.name)
	var floor_y := 0.
	var anchor: Array = world.layout.anchors.filter(func(a): return a.id == identity)
	if not anchor.is_empty():
		floor_y = float(world.layout.levels.filter(func(a): return a.id == anchor[0].level)[0].y)
		if identity == "B1_SERVICE_CORE_LT": floor_y = -1.6
		floor_y = world.adapter.root.to_global(Vector3(0,floor_y,0)).y
	elif identity.begins_with("F01_BAR_"): floor_y = 0. if identity == "F01_BAR_LT_LOBBY" else -2.8
	if identity.begins_with("F01_BAR_LT_DECK"): floor_y = -2.62
	var camera_fov := world.player.camera.fov
	if identity == "F01_BAR_LT_WC": world.player.camera.fov = 100.
	var target := prop.to_global(bounds.get_center())
	var station := Vector3.INF
	for radius: float in [1.1,1.5,2.,2.6,3.2,.8,3.8,.6,.4]:
		for step in 24:
			var angle := float(step)*TAU/24.
			var at := prop.global_position+Vector3(sin(angle)*radius,0,cos(angle)*radius)
			at.y = floor_y+.015
			if not _city_clear_station(world,at): continue
			world.player.global_position=at
			world.player.face_world_point(target)
			var camera: Camera3D = world.player.camera
			var frame := camera.get_viewport().get_visible_rect().grow(-14)
			var visible := true
			for corner in 8:
				var point := prop.to_global(bounds.get_endpoint(corner))
				if camera.is_position_behind(point) or not frame.has_point(camera.unproject_position(point)): visible=false;break
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,prop.light.global_position,1,[world.player.get_rid()]))
			if visible and (hit.is_empty() or hit.position.distance_to(prop.light.global_position)<.015): station=at;break
		if station.is_finite():break
	check(station.is_finite(), "unobstructed standing view of native fixture: "+identity)
	if station.is_finite():
		var original_power: bool=prop.powered
		for powered: bool in [true,false]:
			prop.set_powered(powered)
			await _city_capture(world,station,target,identity+("_powered" if powered else "_off"),"same fitted fixture/camera; original power control; carried service lamp remains",identity)
		prop.set_powered(original_power)
		check(prop.powered==original_power,"paired fixture capture restores original power")
	world.player.camera.fov = camera_fov

func _retained_face_contact(world: OrisonV2RuntimeRoot, identity: String, at: Vector3, direction: Vector3) -> bool:
	# These original narrow rods/leads are visible source stock without colliders.
	# Probe their actual triangles; never invent a collision owner to pass a ray.
	var expected := "F01_OWN_SHOP_BAR_furnish_"+("rubber_aged" if identity=="F01_BAR_LT_WELL" else "metal")
	for draw: MeshInstance3D in world.bar_region.get_node("RetainedBarGeometry").find_children("*","MeshInstance3D",true,false):
		if str(draw.name)!=expected:continue
		var faces := draw.mesh.get_faces()
		var origin := draw.to_local(at+direction*.004)
		var ray := draw.global_basis.inverse()*-direction
		for i in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
			if hit!=null and draw.to_global(hit).distance_to(at)<.00005:
				var normal := draw.global_basis*((faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized())
				if absf(normal.dot(direction))>.99:return true
	return false
