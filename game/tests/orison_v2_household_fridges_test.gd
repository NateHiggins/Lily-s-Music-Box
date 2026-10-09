extends "res://tests/orison_v2_domestic_native_test.gd"
## Shared production-world QA; all original refrigerator authorities stay live.
const Fridge := preload("res://scripts/building/orison_v2_fridge.gd")
var unique: Dictionary = {}
var triangles := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_household_fridges.json"))
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_fridge_factory")
	factory_id = factory.get_instance_id()
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256, "refrigerator export bound to native construction")
	var actors: Array[Fridge] = []
	# In a long shared review the thermostat may already have cycled, and a
	# conductor event can be moving a closed tray. Gate only event reception
	# during the dimensional/control assay and restore each owner's state.
	var before_states := {}
	for instance: Dictionary in fixture.runtime.instances:
		var prop := world.adapter.resolve(str(instance.id)) as Fridge
		if prop==null:continue
		before_states[prop]=[prop.state,prop._open,prop._ice_open,prop._tray_open]
		prop.state=FunctionalProp.PState.OFF
	await get_tree().create_timer(.7).timeout
	for prop: Fridge in before_states:
		prop.set_door_open(false,.01);prop.set_ice_door_open(false,.01);prop.set_tray_open(false,.01)
	await _settled_controls(before_states.keys(),false)
	var inventory_count := 0
	var monitors := 0
	for instance: Dictionary in fixture.runtime.instances:
		var identity := str(instance.id)
		var prop := world.adapter.resolve(identity) as Fridge
		check(prop != null and prop.native_ready, "source refrigerator owns native stock: "+identity)
		if prop == null: continue
		actors.append(prop)
		mounted_ids.append(prop.get_instance_id())
		var source: Dictionary = fixture.original_records.filter(func(row): return row.id == identity)[0]
		check(prop.unit == source.unit and prop.monitor_top == source.properties.monitor_top and prop.prop_type == "fridge", "source household and appliance class retained")
		var anchor: Dictionary = world.layout.anchors.filter(func(row): return row.id == identity)[0]
		var level: Dictionary = world.layout.levels.filter(func(row): return row.id == anchor.level)[0]
		var p: Array = anchor.position
		check(prop.global_position.is_equal_approx(world.adapter.root.to_global(Vector3(p[0],float(p[1])+float(level.y),p[2]))) and prop.global_basis.is_equal_approx(world.adapter.root.global_basis*Basis(Vector3.UP,float(anchor.yaw))), "original semantic placement retained")
		check(prop._door == prop.get_node("Door" if prop.monitor_top else "FoodDoor") and prop._door.position.is_equal_approx(Vector3(-.36,0,-.32) if prop.monitor_top else Vector3(-.35,0,-.29)), "original door owner and hinge retained")
		check(prop._click != null and prop._creak != null, "original latch and creak owners retained")
		if prop.monitor_top:
			monitors += 1
			check(prop._hum != null and prop._hum.stream != null and prop._drip == null and prop._lamp == prop.get_node("InteriorLamp"), "monitor motor and original lamp retained")
			check(prop._lamp.position.is_equal_approx(Vector3(0,1.08,.08)) and is_equal_approx(prop._lamp.omni_range,.9), "original interior illumination anchor retained")
		else:
			check(prop._hum == null and prop._lamp == null and prop._drip != null and prop._ice_door == prop.get_node("IceDoor") and prop._tray == prop.get_node("DripTray"), "icebox retains separate ice hatch and service pan without electric owners")
			check(prop._ice_door.position.is_equal_approx(Vector3(-.35,0,-.29)) and prop._tray.position.is_equal_approx(Vector3(0,0,-.245)), "source service pivots retained")
		var body := prop.get_node("FixtureBody") as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		check(shape.shape is BoxShape3D and (shape.shape as BoxShape3D).size.is_equal_approx(prop._visual_bounds().size), "existing fixture collision remains sized to visible closed case")
		check(prop.get_node_or_null("PrimaryInteraction") is Area3D, "original functional interaction area retained")
		for contact: Dictionary in fixture.contacts:
			if contact.assembly != instance.variant: continue
			var c: Array = contact.point
			var at := prop.to_global(Vector3(c[0],c[1],c[2]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,[body.get_rid()]))
			check(not hit.is_empty() and hit.position.distance_to(at)<.00004 and hit.normal.y>.99, "actual room floor bears original refrigerator feet")
		var assembly: Dictionary = fixture.runtime.assemblies.filter(func(row): return row.id == instance.variant)[0]
		for part: Dictionary in assembly.parts:
			var parent := prop._door if part.component == "Door" else prop.get_node("StaticCarcass" if part.component == "Body" else str(part.component)) as Node3D
			var draw := parent.get_node(str(part.name)) as MeshInstance3D
			var expected: Dictionary = factory._variants[str(instance.variant)].filter(func(row): return row.name == part.name)[0]
			check(draw.get_meta("native_fridge_part","") == part.name and (parent.transform*draw.transform).is_equal_approx(expected.pose), "native partition correctly rebased under source mechanism")
			_check_part(draw,part,fixture)
			if part.key == "oak": check((draw.material_override as StandardMaterial3D).albedo_color.is_equal_approx(prop._oak_tint()), "original household oak tone retained")
			if part.key == "enamel": check((draw.material_override as StandardMaterial3D).albedo_color.is_equal_approx(prop._enamel_tint()), "original household enamel tone retained")
		inventory_count += _check_inventory(prop,fixture)
		if identity == MinaCaptionManifestation.RESIDUE_ANCHOR_ID:
			var residue := prop._door.get_node_or_null(MinaCaptionManifestation.RESIDUE_SOCKET_ID) as Node3D
			check(residue != null and residue.position.is_equal_approx(Vector3(FridgeProp.MON_W*.5,.85,-.075)), "Mina residue remains attached to original moving door socket")
		prop.set_door_open(true,.01)
		prop.set_ice_door_open(true,.01)
		prop.set_tray_open(true,.01)
	# SceneTreeTimer resumes before this frame's Tween update. Wait for the
	# original moving owners, rather than testing the first actor a frame early.
	var deadline := Time.get_ticks_msec()+2000
	while actors.any(func(prop): return not is_equal_approx(prop._door.rotation.y,deg_to_rad(105.)) or (prop.monitor_top and not is_equal_approx(prop._lamp.light_energy,.22))) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	for prop: Fridge in actors:
		check(prop._open and is_equal_approx(prop._door.rotation.y,deg_to_rad(105.)), "source door API reaches full 105 degree swing")
		if prop.monitor_top:
			check(is_equal_approx(prop._lamp.light_energy,.22), "source lamp responds to native open door")
		else:
			check(prop._ice_open and prop._tray_open and is_equal_approx(prop._ice_door.rotation.y,deg_to_rad(98.)) and is_equal_approx(prop._tray.position.z,-.545), "source ice hatch and pan retain independent full travel")
		if capture_enabled and (prop.unit in ["1A","2A","3B","4B","6B"]): await _capture_fridge(world,prop,"open")
		prop.interact(world.player)
		prop.set_ice_door_open(false,.01)
		prop.set_tray_open(false,.01)
	await _settled_controls(actors,false)
	for prop: Fridge in actors:
		check(not prop._open and is_zero_approx(prop._door.rotation.y), "source door closes without native transform drift")
		if prop.monitor_top:check(is_zero_approx(prop._lamp.light_energy), "original lamp extinguishes")
		else:check(not prop._ice_open and not prop._tray_open and is_zero_approx(prop._ice_door.rotation.y) and is_equal_approx(prop._tray.position.z,-.245), "source ice hatch and pan close at original datums")
		if capture_enabled and (prop.unit in ["1A","2A","3B","4B","6B"]): await _capture_fridge(world,prop,"closed")
	for prop: Fridge in before_states:
		var before: Array=before_states[prop]
		prop.set_door_open(before[1],.01);prop.set_ice_door_open(before[2],.01);prop.set_tray_open(before[3],.01)
	await get_tree().create_timer(.05).timeout
	for prop: Fridge in before_states:
		prop.state=before_states[prop][0]
		check([prop.state,prop._open,prop._ice_open,prop._tray_open]==before_states[prop],"original household event/control states restored")
	check(actors.size()==18 and monitors==4 and inventory_count==50, "all source installations and fifty household items covered")
	check(triangles==int(fixture.triangles), "all unique native refrigerator and larder geometry accounted for")
	return {"checks":checks,"actors":actors.size(),"monitors":monitors,"inventory_items":inventory_count,"unique_triangles":triangles,"views":discovery.duplicate(true),"failures":failures.duplicate()}

func _settled_controls(actors: Array, opened: bool) -> void:
	var deadline:=Time.get_ticks_msec()+2000
	while Time.get_ticks_msec()<deadline:
		var settled:=true
		for prop: Fridge in actors:
			settled=settled and is_equal_approx(prop._door.rotation.y,deg_to_rad(105.) if opened else 0.)
			if prop.monitor_top: settled=settled and is_equal_approx(prop._lamp.light_energy,.22 if opened else 0.)
			else: settled=settled and is_equal_approx(prop._ice_door.rotation.y,deg_to_rad(98.) if opened else 0.) and is_equal_approx(prop._tray.position.z,-.545 if opened else -.245)
		if settled:return
		await get_tree().process_frame
	check(false,"source door, hatch, tray and lamp tweens settle")

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

func _check_inventory(prop: Fridge, fixture: Dictionary) -> int:
	var original: Array = FridgeProp.LARDER[prop.unit]
	var items := prop.get_children().filter(func(child): return child.has_meta("source_larder_item"))
	check(items.size()==original.size(), "household inventory count retained")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prop.unit)
	var count := {0:0,1:0,2:0}
	var used := {0:0,1:0,2:0}
	for source: Array in original: count[int(source[4])] += 1
	var inner: float = FridgeProp.LINER_HALF[prop.monitor_top]
	var old_shelves := [.38,.67,.94] if prop.monitor_top else [.30,.52,.74]
	var shelves: Array = fixture.runtime.visual_fit.monitor_shelves if prop.monitor_top else fixture.runtime.visual_fit.icebox_shelves
	for i in items.size():
		var item := items[i] as MeshInstance3D
		var source: Array = original[i]
		var s := int(source[4])
		var lim := maxf(0.,inner-float(source[2])*.5-.006)
		var x := clampf(-inner+(float(used[s])+.5)*inner*2./float(count[s])+rng.randf_range(-.012,.012),-lim,lim)
		used[s] += 1
		var z := rng.randf_range(-.055,.045)
		var yaw := rng.randf_range(-.25,.25)
		var old: Transform3D = item.get_meta("source_larder_transform")
		check(old.origin.is_equal_approx(Vector3(x,float(old_shelves[s])+float(source[3])*.5,z)) and old.basis.is_equal_approx(Basis(Vector3.UP,yaw)), "original RNG position and yaw retained before shelf seating")
		check(item.mesh==null and is_equal_approx(item.position.x,x) and is_equal_approx(item.position.z,z) and is_equal_approx(item.position.y,float(shelves[s])+.0045) and item.basis.is_equal_approx(old.basis), "source item identity and footprint seated on fitted rack")
		var variant := str(item.get_meta("native_larder_variant"))
		var assembly: Dictionary = fixture.runtime.assemblies.filter(func(row): return row.id == variant)[0]
		for part: Dictionary in assembly.parts:
			var draw := item.get_node(str(part.name)) as MeshInstance3D
			check(draw.get_meta("native_larder_part","")==part.name, "native food follows original inventory owner")
			_check_part(draw,part,fixture)
			if part.key in ["food","paper","bottle"]:
				check((draw.material_override as StandardMaterial3D).albedo_color.is_equal_approx(source[1]), "source household food tint retained")
		if FridgeProp.LABEL_CELL.has(str(source[0])):
			check((item.get_node("SourceBrand") as Label3D).text==str(source[0]).replace(" ","\n"), "source brand is editable lettering")
	return original.size()

func _capture_fridge(world: OrisonV2RuntimeRoot, prop: Fridge, state: String) -> void:
	var requested := OS.get_environment("ORISON_FABRICATION_ACTORS").split(",",false)
	if not requested.is_empty() and str(prop.name) not in requested:return
	var bounds := prop._visual_bounds()
	var station := Vector3.INF
	var target := prop.to_global(Vector3(0,.84 if prop.monitor_top else .65,0))
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
					for y in [.35,.65,.98]:
						var p := prop.to_global(Vector3(x,y,-.315 if prop.monitor_top else -.285))
						var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,p,1,[world.player.get_rid(),body.get_rid()]))
						if not hit.is_empty() and hit.position.distance_to(p)>.02:blocked=true
						if state == "open" and _leaf_occludes(prop,camera.global_position,p):blocked=true
				if not blocked:station=feet;break
			if station.is_finite():break
		if station.is_finite():break
	check(station.is_finite(), "clear installed refrigerator framing: "+str(prop.name)+" "+state)
	if station.is_finite():await _city_capture(world,station,target,str(prop.name)+"_native_"+state,"native refrigerator and source household inventory",str(prop.name))
	camera.fov=old_fov

func _leaf_occludes(prop: Fridge, eye: Vector3, target: Vector3) -> bool:
	var leaves: Array[Node3D] = [prop._door,prop.get_node("StaticCarcass")]
	if not prop.monitor_top:leaves.append(prop._ice_door)
	for leaf: Node3D in leaves:
		for draw: Node in leaf.get_children():
			if draw is not MeshInstance3D:continue
			if leaf.name == "StaticCarcass" and draw.get_meta("material_key","") not in ["oak","enamel","liner"]:continue
			var mesh_draw := draw as MeshInstance3D
			var start := mesh_draw.to_local(eye)
			var end := mesh_draw.to_local(target)
			var direction := (end-start).normalized()
			var faces := mesh_draw.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(start,direction,faces[i],faces[i+1],faces[i+2])
				if hit is Vector3 and start.distance_to(hit)<start.distance_to(end)-.002:return true
	return false
