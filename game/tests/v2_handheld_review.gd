extends Node
## INERT: same occupied-world view, actual E input, held-pass and frame samples.
var world: Node3D
var failures: Array=[]
var samples: Array=[]
func check(ok: bool,label: String) -> void:
	print("HANDHELD REVIEW: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(1.).timeout
	var player: PlayerController=world.player
	player.global_position=world.adapter.root.to_global(Vector3(-8.5,3.2,0))
	player.face_world_point(world.adapter.root.to_global(Vector3(-13.4,4.3,.75)))
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var carrier: ServiceSetCarrier=world.service_set_carrier
	carrier.print_telegram_card({"title":"HOT WATER / FIELD REPORT","body":"The hot valve turns freely. Water warms steadily; the drain clears without backing up.\n\nClean the strainer and oil the cabinet hinge before the next call.\n\nThe tenant mentioned a knocking pipe after midnight. Listen again when the upstairs shower stops.","condition":"SERVICE COPY / NORTH STACK"})
	await get_tree().create_timer(8.).timeout
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var metrics: Array=[]
	for mode in ["collapsed","deployed"]:
		if mode=="deployed":
			var event:=InputEventKey.new();event.physical_keycode=KEY_E;event.keycode=KEY_E;event.pressed=true
			carrier._unhandled_input(event)
		check(carrier.reading==(mode=="deployed"),"actual E selects "+mode)
		for frame in 8:await get_tree().process_frame
		var before: int=Time.get_ticks_usec()
		for frame in 48:
			if frame>=16:
				var motion:=InputEventMouseMotion.new();motion.relative=Vector2(1. if frame<32 else -1.,0)
				player._unhandled_input(motion)
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();samples.append({"mode":mode,"wall_ms":(now-before)/1000.,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.});before=now
		var image: Image=carrier._pass_view.get_texture().get_image()
		var count:=0;var bounds:=Rect2i()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a>.1:
					count+=1;bounds=Rect2i(Vector2i(x,y),Vector2i.ONE) if count==1 else bounds.expand(Vector2i(x,y))
		var printer: Node3D=carrier.device.teletype
		var meshes: Array=carrier.device.find_children("*","MeshInstance3D",true,false)
		var row: Dictionary={"mode":mode,"pass_size":[image.get_width(),image.get_height()],"opaque_pixels":count,"alpha_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"geometry_nodes":meshes.size(),"columns":printer.COLUMNS,"rows":printer.ROWS,"pages":printer.pages.size(),"ink":printer.ink.text,"screen_rect":str(carrier._device_rect.get_global_rect())}
		var a: Vector3=printer.ink.global_position
		var b: Vector3=a+printer.ink.global_basis*Vector3.UP*printer.ink.pixel_size*printer.ink.font_size
		row.font_em_pixels=carrier._pass_cam.unproject_position(a).distance_to(carrier._pass_cam.unproject_position(b));metrics.append(row)
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(mode+".png"))==OK,"captured occupied-world "+mode)
		check(image.save_png(directory.path_join(mode+"_pass.png"))==OK,"captured alpha mask "+mode)
	FileAccess.open(directory.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","metrics":metrics,"samples":samples,"failures":failures},"\t"))
	print("HANDHELD REVIEW: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(failures.size())
