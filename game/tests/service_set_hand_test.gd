extends Node3D
## Actual-input bench; composed-world qualification is a separate run.
var player: PlayerController
var carrier: ServiceSetCarrier
var failures: Array[String]=[]
var checks:=0
var directory: String
var observations: Array=[]
var standalone:=true

func check(ok: bool,label: String) -> bool:
	checks+=1;print("SERVICE HAND: ",label," = ",ok)
	if not ok:failures.append(label)
	return ok

func key(code: Key) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame

func click() -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=get_viewport().get_mouse_position()
		Input.parse_input_event(event)
	await get_tree().physics_frame
	await get_tree().process_frame

func drag(amount: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.relative=amount;event.position=get_viewport().get_mouse_position()
	Input.parse_input_event(event)
	await get_tree().physics_frame
	await get_tree().process_frame

func aim(part: Node3D) -> bool:
	var points: Array[Vector3]=[part.global_position]
	for draw: MeshInstance3D in part.find_children("*","MeshInstance3D",true,false):points.append(draw.to_global(draw.get_aabb().get_center()))
	if part is MeshInstance3D:points.append(part.to_global(part.get_aabb().get_center()))
	var rect:=carrier._device_rect.get_global_rect()
	for point in points:
		var projected:=carrier._pass_cam.unproject_position(point)
		for offset in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3),Vector2(6,0),Vector2(-6,0),Vector2(0,6),Vector2(0,-6)]:
			var pixel: Vector2=rect.position+(projected+offset)/Vector2(carrier._pass_view.size)*rect.size
			Input.warp_mouse(pixel)
			await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var target: Dictionary=player._grab.find_target()
			if target.get("part")==part:return true
		if part==carrier.device.teletype.lamp_switch or part==carrier.device.teletype.feed_wheels[1]:
			var hit: Dictionary=carrier._hand.last_hit
			print("PICK DIAGNOSTIC: part=",part.name," point=",point," projected=",projected," mouse=",get_viewport().get_mouse_position()," rect=",rect," hit=",hit," parent=",hit.collider.get_parent().name if hit.has("collider") else "none")
	return false

func _ready() -> void:
	if standalone:_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	Engine.max_fps=120
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	carrier=ServiceSetCarrier.new();carrier.setup(player,player.camera,null);player.carried_device=carrier
	await get_tree().physics_frame;await get_tree().physics_frame
	await exercise()
	finish()

func exercise() -> void:
	await key(KEY_E)
	print("E STATE: reading=",carrier.reading," inspecting=",player.inspecting()," pointer=",Input.mouse_mode)
	check(carrier.reading and not player.inspecting(),"E raises physical UI without entering inspection")
	await key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner==carrier,"Space explicitly frees pointer for carried mechanisms"):
		return
	var pose:=player.camera.global_transform
	for name: String in ["lamp","radio","cover","focus","feed0","feed1"]:
		var part: Node3D=carrier._hand.controls[name]
		if not check(await aim(part),"free cursor targets specific "+name):continue
		var before: float=carrier._hand.read(name)
		var count:=carrier.device.printed_count
		await click()
		if not check(player._grab.active() and player._grab.target.part==part,"primary click acquires "+name):continue
		var acquired: float=carrier._hand.read(name)
		check(is_equal_approx(acquired,before) or name.begins_with("feed"),"acquire does not move "+name)
		var old_page: int=carrier.device.teletype.page
		var child: MeshInstance3D=part.find_children("*","MeshInstance3D",true,false)[0] if name.begins_with("feed") else null
		var child_basis: Basis=child.basis if child!=null else Basis.IDENTITY
		await drag(Vector2(0,-20 if name.begins_with("feed") else 20))
		if name.begins_with("feed"):
			# Real window input may coalesce a small pointer correction with the
			# requested motion. Continue the actual gesture through the detent;
			# twenty nominal pixels alone do not establish a completed quarter turn.
			for step in 6:
				if carrier.device.teletype.page != old_page: break
				await drag(Vector2(0,-4))
		var partial: float=carrier._hand.read(name)
		check(not is_equal_approx(partial,acquired),"actual mouse produces partial "+name+" travel")
		if name.begins_with("feed"):
			check(carrier.device.teletype.page==posmod(old_page+1,carrier.device.teletype.pages.size()) and not carrier.device.teletype.printing,"feed detent reviews next complete page without reprinting")
			check(child.basis.is_equal_approx(child_basis),"feed rotates pivot once without rotating its material child again")
		await click()
		check(not player._grab.active() and carrier.device.teletype.hand_control==null,"next click releases "+name)
		check(is_equal_approx(partial,carrier._hand.read(name)),"release retains "+name+" position")
		check(carrier.device.printed_count==count,"operating "+name+" does not create a received report")
		observations.append({"part":name,"before":before,"partial":partial})
	for name: String in ["lamp","radio","cover","focus"]:
		var part: Node3D=carrier._hand.controls[name]
		if not check(await aim(part),"reacquire "+name+" for full travel"):continue
		await click()
		if not player._grab.active():check(false,"full travel owns "+name);continue
		var high: float=player._grab.target.maximum
		for i in 12:await drag(Vector2(0,20))
		check(is_equal_approx(carrier._hand.read(name),high),name+" stops at physical maximum")
		player._update_prompt()
		check(player._target_dot.state=="limit",name+" shared reticle reports travel limit")
		if name=="lamp":check(not player.lamp_is_enabled() and not carrier.device.lamp_enabled,"lamp contact reaches original player power authority")
		if name=="radio":check(not carrier.radio_is_powered() and not carrier.device.teletype.powered,"radio contact gates original printer authority")
		await click()
		check(not player._grab.active(),"full travel releases "+name)
	check(player.camera.global_transform.is_equal_approx(pose),"all device gestures retain world camera")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("physical_controls.png"))
	await key(KEY_SPACE)
	check(not player.inspecting() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Space restores walking pointer")
	await key(KEY_SPACE)
	var cover: Node3D=carrier._hand.controls.cover
	if await aim(cover):
		await click();await drag(Vector2(0,-10));await key(KEY_ESCAPE)
		check(not player.inspecting() and not player._grab.active() and carrier.device.teletype.hand_control==null,"Escape releases grabbed control and restores world")
	await key(KEY_SPACE)
	await key(KEY_E)
	check(not carrier.reading and not player.inspecting(),"E collapses device and exits its inspection")

func finish() -> void:
	FileAccess.open(directory.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"observations":observations},"\t"))
	print("SERVICE HAND: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
