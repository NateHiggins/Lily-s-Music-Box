extends Node
var failures: Array[String]=[]
func _ready() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	print("TELETYPE ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(.7).timeout
	var player: PlayerController=world.player
	var carrier: ServiceSetCarrier=world.service_set_carrier
	var device: ServiceSetProp=carrier.device
	var printer=device.teletype
	for light in carrier._pass_view.find_children("*","Light3D",true,false):
		check(bool(light.layers & carrier._pass_cam.cull_mask),"held camera includes its illumination layers")
	player.set_physics_process(false)
	player.global_position=world.adapter.root.to_global(Vector3(-8.5,3.2,0))
	player.camera.make_current()
	player.face_world_point(world.adapter.root.to_global(Vector3(-13.4,4.3,.75)))
	check(carrier.beam_xform.origin.length()<.05,"beam begins within five centimetres of eye")
	var card := {"title":"HOT WATER / FIELD REPORT","body":"The hot valve turns freely. Water warms steadily; the drain clears without backing up. Clean the strainer and oil the cabinet hinge before the next call.\n\nThe tenant mentioned a knocking pipe after midnight. Listen again when the upstairs shower stops.","condition":"PREVENTATIVE SERVICE COMPLETE"}
	check(carrier.print_telegram_card(card),"full field report accepted")
	await get_tree().create_timer(.5).timeout
	check(printer.printing and printer.printed_characters>0,"ink prints progressively")
	check(absf(printer.carriage.position.x)>0.001,"physical carriage traverses")
	await shot("01_printing")
	await get_tree().create_timer(9).timeout
	check(not printer.printing and printer.ink.text==printer.pages[0],"first page remains readable")
	check(printer.pages.size()>1 and "PREVENTATIVE" in " ".join(printer.pages),"long report retained across paper pages")
	var read_event := InputEventAction.new()
	read_event.action="teletype_read"; read_event.pressed=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	carrier._unhandled_input(read_event)
	check(not carrier.reading,"released pointer retains input ownership")
	player.set_mouse_released(false)
	carrier._unhandled_input(read_event)
	check(carrier.reading,"T raises the actual reading pose")
	await get_tree().create_timer(.3).timeout
	await shot("02_reading")
	var wheel := InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true
	for step in range(12): carrier._unhandled_input(wheel)
	await get_tree().create_timer(.3).timeout
	check(is_equal_approx(carrier.reading_distance,carrier.READING_NEAR),"wheel brings paper close with a safe near limit")
	await shot("02b_close_reading")
	var focus_before: float=carrier.reading_distance
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	carrier._unhandled_input(wheel)
	check(is_equal_approx(carrier.reading_distance,focus_before),"released pointer owns scrolling")
	player.set_mouse_released(false)
	for step in range(20): carrier._unhandled_input(wheel)
	check(is_equal_approx(carrier.reading_distance,carrier.READING_FAR),"reading distance has a far limit")
	printer.toggle_service_cover()
	await get_tree().create_timer(.4).timeout
	check(printer.service_open and absf(printer.service_cover.rotation.x)>1.7,"service cover opens on its physical hinge")
	await shot("02c_service_access")
	printer.toggle_service_cover()
	carrier.adjust_reading_distance(-.085)
	check(printer._gears.size()==4 and printer.focus_wheel!=null,"Blender transmission and reading wheel exported")
	player._prompt.text="[E] TEST VALVE"
	carrier._process(.01)
	check("TEST VALVE" in printer.footer.text and not player._interaction_hud.visible,"interaction cue lives on physical paper without an aiming dot")
	printer.turn_page(1)
	await get_tree().create_timer(9).timeout
	await shot("03_next_page")
	check(printer.page==1 and printer.ink.text==printer.pages[1],"next page prints complete remaining copy")
	device.set_radio_powered(false,false)
	check(not carrier.print_telegram_card("POWER OFF"),"radio-off refuses new output")
	check(printer.ink.text==printer.pages[1],"power off retains physical paper")
	await get_tree().create_timer(.3).timeout
	check(printer.radio_switch.rotation.z>0 and printer.lamp_switch.rotation.z<0,"physical switches show independent live circuits")
	device.set_radio_powered(true,false)
	carrier.reading=false
	# Actual close wall: ray from delivered lamp must still hit the surface ahead.
	var origin := player.camera.global_position
	var facing := -player.camera.global_basis.z
	var wall := StaticBody3D.new(); add_child(wall)
	wall.global_position=origin+facing*.22
	wall.global_basis=player.camera.global_basis
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size=Vector3(.8,.8,.02); shape.shape=box; wall.add_child(shape)
	var wall_mesh := MeshInstance3D.new()
	var slab := BoxMesh.new(); slab.size=box.size; wall_mesh.mesh=slab
	wall_mesh.material_override=MatLib.get_mat("plaster_stained")
	wall.add_child(wall_mesh)
	await get_tree().physics_frame
	await get_tree().create_timer(.3).timeout
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.flashlight.global_position,origin+facing*.4,1))
	check(not hit.is_empty() and hit.collider==wall,"real lamp remains in front of a wall 22cm from eye")
	await shot("04_close_wall")
	wall.free()
	var serial: int=device.printed_count
	player.telegram_hud.present({"title":"WIRE DELIVERY","body":"Full message through the shared presenter."})
	check(device.printed_count==serial+1 and "Full message" in " ".join(printer.pages),"shared service-wire presenter prints complete physical copy")
	serial=device.printed_count
	var history_key := InputEventKey.new()
	history_key.physical_keycode=KEY_BRACKETLEFT
	history_key.pressed=true; history_key.shift_pressed=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var current_report: int=printer.report_index
	carrier._unhandled_input(history_key)
	check(printer.report_index==current_report,"released pointer blocks report browsing")
	player.set_mouse_released(false)
	carrier._unhandled_input(history_key)
	check("HOT WATER" in printer.ink.text and not printer.printing,"shift bracket recalls complete previous report")
	history_key.echo=true
	carrier._unhandled_input(history_key)
	check("HOT WATER" in printer.ink.text,"held key does not skip reports")
	device.set_radio_powered(false,false)
	printer.turn_page(1)
	check("PREVENTATIVE" in printer.ink.text and not printer.printing,"unpowered archive pages remain readable")
	check(device.printed_count==serial,"browsing does not receive or replay output")
	carrier.reading=true
	await get_tree().create_timer(.4).timeout
	check(not player.telegram_hud.visible,"raised paper suppresses overlapping HUD copy")
	await shot("05_retained_report")
	carrier.reading=false
	await get_tree().process_frame
	await get_tree().process_frame
	check(not player.telegram_hud.visible and not player._interaction_hud.visible,"lowering paper keeps all ordinary HUD overlays removed")
	device.set_radio_powered(true,false)
	for index in range(26): carrier.print_telegram_card({"title":"COPY %02d" % index,"body":"Retained field copy."})
	check(printer.reports.size()==24 and "COPY 02" in printer.reports[0].pages[0],"history bounded to newest 24 reports")
	printer.browse_report(1)
	check("COPY 02" in printer.ink.text,"history wraps to oldest retained copy")
	# Equal elapsed time must advance the same glyphs and feed at different FPS.
	printer.set_process(false)
	var cadence_card := {"title":"CADENCE","body":"First line.\nSecond line.\nThird line continues across the paper."}
	printer.present(cadence_card,0)
	var platen_start: Basis=printer.platen.basis
	printer._process(2.017)
	var slow_count: int=printer.printed_characters
	var slow_feed: Basis=platen_start.inverse()*printer.platen.basis
	printer.present(cadence_card,0)
	platen_start=printer.platen.basis
	for frame in range(200): printer._process(.01)
	printer._process(.017)
	check(printer.printed_characters==slow_count and (platen_start.inverse()*printer.platen.basis).is_equal_approx(slow_feed),"glyph and platen advance independent of frame rate")
	device.set_radio_powered(false,false)
	printer._process(3.0)
	check(printer.printed_characters==slow_count,"power loss freezes printing progress")
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var dir := OS.get_environment("SHOT_DIR")
	if dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(label+".png"))
