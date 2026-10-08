extends "res://tests/orison_v2_owner_service_finish_test.gd"
## Shared-world optical deployment and the existing authorized-copy transaction.
func _init() -> void:
	contract_key = "owner_shop_finish"
	contract_scope = "Scoped shop optical overrides, preserved source mesh materials, loaded mip chains, one authorized key-copy keyboard transaction, duplicate refusal and owner teardown. Native fit has independent batch validators. The original Radio Service receiver is temporarily enabled for two keyboard sessions across one passage geometry unload/reload. Save reconstruction is not exercised; default cabinet policy remains unchanged."

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started = Time.get_ticks_msec()
	var owners := 0
	var maps := {}
	for cell: Node3D in world.passage_region.cell_nodes.values():
		for model: Node in cell.get_children():
			if str(model.get_meta("v2_owner_finish_group","")) != "shop": continue
			if model.name=="PawnDisplay":check(int(model.get_meta("v2_local_shop_wear_slots",0))==2,"both original case access rails have bounded touch wear")
			owners += 1
			retained.append(weakref(model))
			for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				if draw.mesh == null: continue
				for surface in draw.mesh.get_surface_count():
					var source := draw.mesh.surface_get_material(surface) as StandardMaterial3D
					var active := draw.get_active_material(surface)
					if active == null or not active.has_meta("v2_owner_finish"): continue
					changed_slots += 1
					check(source != null and source != active,"scoped finish keeps imported source resource")
					check(not source.emission_enabled and source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"glazing and lit actors remain with original optical owners")
					if active is ShaderMaterial:
						for parameter in ["albedo_tex","normal_tex","rough_tex"]:
							var texture: Texture2D = active.get_shader_parameter(parameter)
							if texture != null: maps[texture.resource_path] = texture
	check(owners >= 20 and changed_slots > 100,"shop finishes deployed across native families")
	for texture: Texture2D in maps.values(): check(texture.get_image().has_mipmaps(),"scoped shop map has actual mips: "+texture.resource_path.get_file())
	var counter: Area3D = world.passage_region._actors.get_node("AuthorizedKeyCopies")
	retained.append(weakref(counter))
	for layer: CanvasLayer in counter.find_children("*","CanvasLayer",true,false): layer.show()
	var originals: Dictionary = DoorKeyring.book().originals.duplicate(true)
	check(not DoorKeyring.request_copy("mina_vale").is_empty(),"existing resident permission permits this isolated copy-input regression")
	var feet := Vector3(counter.global_position.x,.03,counter.global_position.z+1.85)
	check(_city_clear_station(world,feet),"copy counter station remains floor-supported and clear")
	world.player.global_position = feet
	world.player.velocity = Vector3.ZERO
	world.player.face_world_point(counter.global_position+Vector3(0,-.09,.85))
	world.player.set_mouse_released(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(world.player.camera.global_position,world.player.camera.global_position-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()])
	ray.collide_with_areas = true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.get("collider") == counter,"ordinary standing interaction ray reaches retained copy counter")
	if hit.get("collider") == counter:
		await _shop_key(KEY_E)
		check(counter.opened and world.player.call_locked,"ordinary E opens existing copy menu")
		if counter.opened:
			await _shop_key(KEY_E)
			check(DoorKeyring.book().copies.get("2A") == "mina_vale" and DoorKeyring.book().originals == originals,"focused E creates authorized spare and preserves resident originals")
			check(not DoorKeyring.make_copy("2A"),"duplicate spare refused by original authority")
			await _shop_key(KEY_ESCAPE)
			check(not counter.opened and not world.player.call_locked,"copy menu releases player")
	for layer: CanvasLayer in counter.find_children("*","CanvasLayer",true,false): layer.hide()
	await _receiver_reload(world,owners)
	validation_completed = true
	return {"checks":checks,"failures":failures,"owners":owners,"changed_slots":changed_slots,"loaded_texture_maps":maps.size()}

func _shop_key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame

func _receiver_reload(world: OrisonV2RuntimeRoot, original_owners: int) -> void:
	var passage := world.passage_region
	var prop := passage._actors.get_node_or_null("Arcade_storm_shopcab_radio_service0") as ArcadeCabinetProp
	check(prop != null,"temporary receiving regression has original Radio Service owner")
	if prop == null:return
	retained.append(weakref(prop))
	var programme: Dictionary = prop.cabinet.duplicate(true)
	await _receiver_input(world,prop,"before_reload")
	var old_models: Array[WeakRef] = []
	for cell: Node3D in passage.cell_nodes.values():
		for model: Node in cell.get_children():
			if model.has_meta("v2_owner_finish_group"):old_models.append(weakref(model))
	world.player.global_position=world.adapter.root.to_global(Vector3(1.925,.03,-3.5))
	for frame in 120:
		await get_tree().physics_frame
		if passage.residency.state=="DORMANT":break
	await get_tree().process_frame
	check(passage.residency.state=="DORMANT" and old_models.all(func(r):return r.get_ref()==null),"normal core station retires all scoped shop models")
	check(not prop.machine.is_booted() and not world.player.call_locked,"dormancy unloads programme and leaves player free")
	var vestibule: Dictionary=world.layout.spaces.filter(func(r):return r.id=="F01_VESTIBULE")[0]
	var rect: Array=vestibule.rect
	world.player.global_position=world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5,.03,(rect[1]+rect[3])*.5))
	for frame in 900:
		await get_tree().process_frame
		if passage.residency.state=="RESIDENT":break
	check(passage.residency.state=="RESIDENT","normal vestibule prefetch reloads shop geometry")
	if passage.residency.state!="RESIDENT":return
	var count := 0
	for cell: Node3D in passage.cell_nodes.values():
		for model: Node in cell.get_children():
			if str(model.get_meta("v2_owner_finish_group",""))=="shop":
				count+=1
				retained.append(weakref(model))
	check(count==original_owners,"all calibrated shop finishes survive staged reload")
	check(passage._actors.get_node("Arcade_storm_shopcab_radio_service0")==prop and prop.cabinet==programme,"reload retains original receiving actor and assigned programme")
	await _receiver_input(world,prop,"after_reload")

func _receiver_input(world: OrisonV2RuntimeRoot,prop: ArcadeCabinetProp,label: String) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service
	world.player.global_position=cell.to_global(Vector3(19.45,.03,57.5))
	world.player.velocity=Vector3.ZERO
	world.player.face_world_point(prop._screen.global_position)
	world.player.set_mouse_released(false)
	await _settled_optics()
	check(_city_clear_station(world,world.player.global_position),"receiver station retains actual clearance: "+label)
	var ray:=PhysicsRayQueryParameters3D.create(world.player.camera.global_position,world.player.camera.global_position-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()])
	ray.collide_with_areas=true
	var hit: Node=world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")
	var reached := false
	while hit!=null:
		reached=reached or hit==prop
		hit=hit.get_parent()
	check(reached,"ordinary receiver ray reaches original owner: "+label)
	if not reached:return
	await _shop_key(KEY_E)
	check(prop._playing() and world.player.call_locked and prop.machine.is_booted(),"ordinary E enters original programme: "+label)
	if capture_enabled:await shot("radio_input_"+label)
	await _shop_key(KEY_ESCAPE)
	check(not prop._playing() and not world.player.call_locked,"ordinary Escape releases programme: "+label)
