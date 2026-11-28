extends "res://tests/orison_v2_vertical_route_test.gd"
## INERT installed-world pictures of the 4B shower spray and the steam it makes,
## over time, from the room and from inside the tub. Valves are set directly:
## this run reviews the picture, not the hand. No optical or artistic acceptance.
var out := ""

func _init() -> void:
	route_label="BATH STEAM CAPTURE"

func _look(from: Vector3,at: Vector3) -> void:
	player.global_position=from;player.velocity=Vector3.ZERO
	for frame in 4:await get_tree().physics_frame
	player.face_world_point(at)
	for frame in 4:await get_tree().physics_frame
	player.face_world_point(at)

func _shot(label: String) -> void:
	if out.is_empty() or DisplayServer.get_name()=="headless":return
	for frame in 8:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))

func _route() -> void:
	out=OS.get_environment("SHOT_DIR")
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	var tap:=world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	if tap==null or not tap.get("model") is Node3D:
		failures.append("the prologue bath is installed in 4B");return
	var model: Node3D=tap.get("model")
	var curtain: Variant=tap.get("_curtain_hand")
	if curtain!=null:curtain.set_travel(curtain.TRAVEL)
	if player.carried_device!=null:player.carried_device.set_capture_hidden(true)
	var room: Vector3=model.to_global(Vector3(0,0,-1.05))
	var tub: Vector3=model.to_global(Vector3(0,.239,0))
	var head: Vector3=tap._stream.global_position
	var fall: Vector3=head+Vector3.DOWN*.75
	await _look(room,fall)
	await _shot("00_dry_room")
	tap.set_valve_opening(0,1.);tap.set_valve_opening(1,.35)
	var moisture: Node=world.bathroom_moisture
	var state: Dictionary=moisture._rooms[moisture._sources.filter(func(source: Dictionary)->bool:return source.tap==tap)[0].room]
	var started:=Time.get_ticks_msec()
	for mark: Array in [[2.,"01_spray_2s"],[8.,"02_steam_8s"],[18.,"03_steam_18s"],[32.,"04_steam_32s"],[50.,"05_steam_50s"]]:
		while float(Time.get_ticks_msec()-started)/1000.<float(mark[0]):await get_tree().process_frame
		print("BATH STEAM ",mark[1]," humidity=",state.humidity," flow=",tap.get_flow_state().flow," temperature=",tap.get_flow_state().temperature)
		await _look(room,fall)
		await _shot(str(mark[1])+"_room")
		await _look(tub,head+Vector3.DOWN*.25)
		await _shot(str(mark[1])+"_tub")
	await _look(model.to_global(Vector3(.9,0,-1.6)),model.to_global(Vector3(0,1.9,0)))
	await _shot("06_steam_ceiling")
	if tap.has_method("set_shower_fraction"):
		tap.call("set_shower_fraction",0.)
		await get_tree().create_timer(1.5).timeout
		await _look(room,tap.get("filler").global_position+Vector3.DOWN*.2)
		await _shot("07_faucet_running")
		tap.call("set_shower_fraction",1.)
	tap.set_valve_opening(0,0.);tap.set_valve_opening(1,0.)
	await get_tree().create_timer(12.).timeout
	print("BATH STEAM after shutoff humidity=",state.humidity)
	await _look(room,fall)
	await _shot("08_shut_12s_room")
