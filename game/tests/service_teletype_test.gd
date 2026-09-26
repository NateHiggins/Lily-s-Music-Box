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
	printer.turn_page(1)
	await get_tree().create_timer(9).timeout
	await shot("03_next_page")
	check(printer.page==1 and printer.ink.text==printer.pages[1],"next page prints complete remaining copy")
	device.set_radio_powered(false,false)
	check(not carrier.print_telegram_card("POWER OFF"),"radio-off refuses new output")
	check(printer.ink.text==printer.pages[1],"power off retains physical paper")
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
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var dir := OS.get_environment("SHOT_DIR")
	if dir.is_empty(): return
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(label+".png"))
