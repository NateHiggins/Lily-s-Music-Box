extends "res://tests/annunciator_world_review.gd"
## One composed build for changed optical stock. This does not repeat disk
## qualification or grant a runtime contract for the whole building.
func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := await _world()
	if world.startup_failed or world.player==null:world.free();_finish_lamps();return
	var player := world.player;player.set_physics_process(false)
	var board := world.adapter.resolve("LobbyPorterBoard") as OtisProp
	check(board!=null and board._native_service!=null,"installed native board has lamp controller")
	if board==null or board._native_service==null:world.free();_finish_lamps();return
	check(not world.household_state._blocked,"new optical draws do not block household owner")
	player.global_position=board.to_global(Vector3(0,-1.4,.65));player.velocity=Vector3.ZERO
	player.call_locked=false;player.mouse_released=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var driver := preload("res://tests/radiator_cutover_review.gd").new()
	var input := preload("res://tests/annunciator_input_driver.gd").new(self,board,player,driver,check)
	await input.move(board._flag_arms[7],board._native_service.FLAG_HIGH)
	player.set_lamp_enabled(false)
	var deadline := Time.get_ticks_msec()+5000
	while player.flashlight.visible and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.05).timeout
	check(not player.lamp_is_enabled() and not player.flashlight.visible,"installed lamp-off capture waits on actual optical output")
	player.camera.global_position=board.to_global(Vector3(.12,.02,.60));player.camera.look_at(board.to_global(Vector3(0,0,.04)))
	await _shot_lamp("installed_lamp_bank_room_light")
	var lit := -1
	for i in board._lamps.size():
		if board._lamps[i].emission_enabled:lit=i
	check(lit>=0,"original installed car-indicator owner lights a lens")
	if lit>=0:
		# Source identities are metadata on the original mesh nodes, not a new
		# independently reconstructed lamp array.
		var lens: MeshInstance3D
		for draw: MeshInstance3D in board.find_children("*","MeshInstance3D",true,false):
			if draw.get_meta("native_service_instrument_part","")=="M01_P%03d"%(2+lit*3):lens=draw
		check(lens!=null and lens.get_active_material(0)==board._lamps[lit],"installed lens retains its original live material")
		if lens!=null:
			player.camera.global_position=lens.global_position+board.global_basis*Vector3(.065,.035,.17);player.camera.look_at(lens.global_position)
			await _shot_lamp("installed_opal_lens")
	player.set_lamp_enabled(true);await get_tree().create_timer(.7).timeout
	await _shot_lamp("installed_lamp_bank_flashlight")
	input=null;driver.free();world.free();_finish_lamps()

func _shot_lamp(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,label+" captured")

func _finish_lamps() -> void:
	FileAccess.open(out.path_join("annunciator_lamps_world.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Installed native lamp stock, original material ownership, one real flag gesture and lighting views. No disk/save reconstruction, full repair route or broad runtime contract."},"\t"))
	print("ANNUNCIATOR LAMPS WORLD: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
