extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Real wall contact and front-side use; fixture placements come from the layout.
func _route() -> void:
	route_label="V2 WALL MOUNTS"
	var specs := [
		["LobbyMailBank",-1.0,0.0,.65,.56,1.91,Vector3(-.155,1.41,-.078)],
		["F01_HOUSE_TELEPHONE_BOARD",-1.0,.08,.30,.04,.64,Vector3(0,.35,-.12)],
		["LobbyPorterBoard",1.0,-.03,.12,-.29,.29,Vector3(-.06,0,.075)],
		["LobbyServiceDumbwaiter",1.0,0.0,.40,-.08,.68,Vector3(.04,.90,.36)]]
	for spec in specs:
		var prop := world.adapter.resolve(spec[0]) as Node3D
		if not _require(prop!=null,"mounted fixture "+spec[0]): return
		var front: Vector3=prop.global_basis.z*float(spec[1])
		# Four points on each cabinet's actual back must meet real solid wall.
		for x in [-float(spec[3]),float(spec[3])]:
			for y in [float(spec[4]),float(spec[5])]:
				var back := prop.to_global(Vector3(x,y,float(spec[2])))
				var ray := PhysicsRayQueryParameters3D.create(back+front*.004,back-front*.03,1)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				var body := hit.get("collider") as Node
				if not _require(body!=null and str(body.get_parent().name).begins_with("Wall") and hit.position.distance_to(back)<.006,spec[0]+" cabinet back meets solid wall"): return
		var stance := prop.global_position+front*.75
		stance.y=world.adapter.root.global_position.y+.02
		player.global_position=stance+prop.global_basis.x*.30
		player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		stance.y-=.02
		if not await _walk_world(stance): return
		if prop is HouseSwitchboardProp:
			var line: Node=prop.network
			if not _require(line.request(str(line.endpoints.keys()[0])),"real subscriber asks for the line"): return
			for expected in ["ANSWERED","CARRYING","IDLE"]:
				var before_serial: int=player.telegram_hud.serial
				if not await _use(prop,prop.to_global(spec[6]),"telephone_"+expected): return
				if not _require(line.snapshot().state==expected,"front-side phone operation "+expected): return
				var card: Dictionary=player.telegram_hud.last_card
				if not _require(player.telegram_hud.serial==before_serial+1 and card.title=="HOUSE TELEPHONE" and card.condition=="LINE / "+expected,"one correctly identified phone status reaches the shared presenter"): return
				var paper: String=" ".join(world.service_set_carrier.device.teletype.pages)
				if not _require("HOUSE TELEPHONE" in paper and expected in paper and "RADIATOR" not in paper,"physical paper carries the current line state"): return
				if expected!="IDLE" and not _require("2A" in paper,"paper names the actual calling extension"): return
			await _printed_phone_capture()
		else:
			var before_serial: int=player.telegram_hud.serial
			if not await _use(prop,prop.to_global(spec[6]),spec[0]): return
			if prop is MailBankProp:
				if not _require(prop.door_open,"4B mailbox opens through actual player ray"): return
				prop._panel.close()
			elif prop is OtisProp:
				if not _require(is_instance_valid(prop._panel),"lift dispatch panel is usable"): return
				if not _require(player.telegram_hud.serial==before_serial,"dispatch modal suppresses unsolicited paper"): return
				prop._panel.close()
				var before: Dictionary=prop.maintenance_snapshot()
				var saved: PackedByteArray=var_to_bytes(RealityState.data)
				var card: Dictionary=prop.service_wire_card()
				if not _require(card.title=="LIFT ANNUNCIATOR" and "sticking" in card.body and card.condition=="SERVICE REQUIRED","annunciator report identifies its real sticking flag"): return
				if not _require(prop.maintenance_snapshot()==before and saved==var_to_bytes(RealityState.data),"reading the annunciator report changes no mechanism or save fact"): return
			else:
				if not _require(is_instance_valid(prop._service_panel),"dumbwaiter brake is reachable"): return
				if not _require(player.telegram_hud.serial==before_serial,"brake modal suppresses unsolicited paper"): return
				prop.preview_maintenance_step({"id":"take_strain"},.6)
				var before: Dictionary=prop.maintenance_snapshot()
				var saved: PackedByteArray=var_to_bytes(RealityState.data)
				var card: Dictionary=prop.service_wire_card()
				if not _require(card.title=="SERVICE DUMBWAITER" and "60%" in card.body and card.condition=="BRAKE SERVICE REQUIRED","live rope strain does not masquerade as a completed repair"): return
				if not _require(prop.maintenance_snapshot()==before and saved==var_to_bytes(RealityState.data),"reading the brake report changes no mechanism or save fact"): return
				prop._service_panel._close(true)
				if not _require("Rope strain: 0%" in prop.service_wire_card().body and not prop.band_seated,"cancelled service reports restored mechanism without completing it"): return
		await get_tree().process_frame
		# Oblique view makes a floating back or an embedded face visible.
		player.global_position=stance+prop.global_basis.x*.25
		player.face_world_point(prop.to_global(spec[6])+prop.global_basis.x*float(spec[1])*.45)
		var directory := OS.get_environment("SHOT_DIR")
		if not directory.is_empty():
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join(spec[0]+"_oblique.png"))

func _printed_phone_capture() -> void:
	var printer=world.service_set_carrier.device.teletype
	var started := Time.get_ticks_msec()
	while printer.printing and Time.get_ticks_msec()-started<15000:
		await get_tree().process_frame
	if not _require(not printer.printing,"physical line-status copy finishes printing"): return
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("telephone_printed.png"))
