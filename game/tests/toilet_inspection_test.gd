extends Node3D
var failures: Array[String]=[]
var checks:=0
var player: PlayerController
var wc: Node3D

func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
	print("INSPECT CHECK: ",label," = ",ok)
func click() -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)
func key(action: String) -> void:
	var event:=InputEventAction.new()
	event.action=action;event.pressed=true
	player._unhandled_input(event)
func drag(relative: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.relative=relative
	player._unhandled_input(event)
func warp_cursor(position: Vector2) -> void:
	Input.warp_mouse(position)
	# The window backend publishes a warp asynchronously. A process-frame
	# signal can precede that update; verify the real cursor before clicking.
	for frame in 8:
		await RenderingServer.frame_post_draw
		if get_viewport().get_mouse_position().distance_to(position)<2.:return
	check(false,"free inspection pointer reaches requested window position")
func aim(at: Vector3,eye: Vector3) -> void:
	player.camera.global_position=eye
	player.camera.look_at(at)
func shot(label: String) -> void:
	var path:=OS.get_environment("SHOT_DIR")
	if path.is_empty(): return
	DirAccess.make_dir_recursive_absolute(path)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path+"/"+label+".png")
func review_native_form() -> void:
	var metrics:=preload("res://tests/orison_v2_roof_bulkhead_caps_test.gd").new()
	var stocks:=0
	for draw: MeshInstance3D in wc.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null:continue
		stocks+=1;metrics._check_cap_mapping(draw.mesh,true)
		var imported_arrays:=draw.mesh.surface_get_arrays(0)
		var imported_tangents: PackedFloat32Array=imported_arrays[Mesh.ARRAY_TANGENT]
		print("CASTING BASIS SIGN: ",draw.name," w=",imported_tangents[3] if imported_tangents.size()>3 else 0.)
		for surface in draw.mesh.get_surface_count():
			var finish:=draw.get_active_material(surface) as StandardMaterial3D
			check(finish!=null and not finish.uv1_triplanar,"native casting samples authored UV charts")
			if finish==null:continue
			for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:
				check(texture!=null and texture.get_image().get_mipmap_count()>0,"casting PBR map has loaded mip chain")
			check(finish.normal_enabled and finish.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,"casting normal map and mip filtering active")
	check(stocks==26,"all 26 batched casting and mechanism meshes are present")
	for failure: String in metrics.failures:check(false,"imported metric/derivative: "+failure)
	metrics.free()
	var throat:=PhysicsRayQueryParameters3D.create(wc.to_global(Vector3(0,.174,-.045)),wc.to_global(Vector3(0,.074,.052)))
	throat.exclude=[player.get_rid()]
	check(get_world_3d().direct_space_state.intersect_ray(throat).is_empty(),"imported drain throat remains physically open")
	var previous_fov:=player.camera.fov;player.camera.fov=42.
	for view: Array in [["toilet_form",Vector3(.8,1.1,-1.2),Vector3(0,.42,0)], ["seat_and_drain",Vector3(.18,1.35,-.60),Vector3(0,.25,-.10)], ["cistern_bottom",Vector3(.62,.28,-.55),Vector3(.04,.50,.19)]]:
		aim(view[2],view[1]);await shot(view[0])
	player.camera.fov=previous_fov
func move_hinge(part_name: String,at: Vector3,goal: float) -> void:
	aim(at,Vector3(.35,1.2,-.8))
	await get_tree().physics_frame
	player._update_prompt()
	check(player._target_dot.state=="available",part_name+" hover indicates actual movable part")
	click()
	player._update_prompt()
	check(player._target_dot.state=="grabbed",part_name+" latched hand indicator")
	check(player._grab.active() and player._grab.target.part==wc.parts[part_name],part_name+" visible part acquires")
	if not player._grab.active(): return
	var grip: Dictionary=player._grab.target
	for i in 80:
		var before: float=grip.read.call()
		if absf(before-goal)<.001: break
		var point: Vector3=grip.part.to_global(player._grab.contact)
		var axis: Vector3=grip.frame.global_basis*grip.axis
		var tangent:=axis.cross(point-grip.part.global_position)
		var gesture: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if gesture.length()<24 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
			gesture=Vector2(0,tangent.dot(player.camera.global_basis.z)*180)
		drag(gesture*signf(goal-before)*minf(.06,absf(goal-before)))
		await get_tree().physics_frame
	check(absf(float(grip.read.call())-goal)<.002,part_name+" mouse reaches physical stop")
	if absf(goal-float(grip.minimum))<.001 or absf(goal-float(grip.maximum))<.001:
		var point: Vector3=grip.part.to_global(player._grab.contact)
		var axis: Vector3=grip.frame.global_basis*grip.axis
		var tangent:=axis.cross(point-grip.part.global_position)
		var gesture: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
		if gesture.length()<24 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
			gesture=Vector2(0,tangent.dot(player.camera.global_basis.z)*180)
		drag(gesture*(-.08 if absf(goal-float(grip.minimum))<.001 else .08))
		await get_tree().physics_frame
		await get_tree().process_frame
		player._update_prompt()
		check(player._target_dot.state=="limit" and absf(float(grip.read.call())-goal)<.002,part_name+" travel limit feedback retains physical stop")
	click()

func _run() -> void:
	RealityState.persistence_enabled=false
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.10,.12,.14)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.55
	add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.2;add_child(light)
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	player.camera.current=true;player.set_beam_mask_enabled(false);player.set_lamp_enabled(false)
	player.position=Vector3(.4,0,-1)
	wc=load("res://scripts/building/orison_v2_water_closet.gd").new()
	wc.furniture_kind="toilet";wc.owner_unit="BENCH";wc.record_id="inspection_bench"
	add_child(wc)
	var floor_body:=StaticBody3D.new();floor_body.name="StandingFloor";floor_body.position.y=-.1;add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(8,.2,8);floor_shape.shape=floor_box;floor_body.add_child(floor_shape)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	await review_native_form()
	if OS.get_environment("ORISON_TOILET_FORM_ONLY")=="1":
		print("TOILET NATIVE FORM: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
		get_tree().quit(failures.size());return
	await move_hinge("RaisedLid",wc.parts.RaisedLid.to_global(Vector3(0,.015,-.30)),0.0)
	await move_hinge("RaisedLid",wc.parts.RaisedLid.to_global(Vector3(0,.015,-.30)),deg_to_rad(82))
	await move_hinge("SeatHinge",Vector3(.18,.43,-.18),deg_to_rad(82))
	await move_hinge("SeatHinge",wc.parts.SeatHinge.to_global(Vector3(.18,-.012,-.285)),0.0)
	aim(wc.get_node("CisternHandle/HandleTouchPoint").global_position,Vector3(.48,.83,-.25))
	click()
	check(player._grab.active(),"actual handle ray grabs")
	player._update_prompt()
	check(player._target_dot.inspectable,"inspection capability comes from selected mechanism")
	if player._grab.active():
		check(player._grab.target.part==wc.parts.CisternHandle,"handle selection is precise")
		check(is_zero_approx(wc._lever.rotation.z),"grab alone does not flush")
		var anchor_before: Vector3=wc.get_node("CisternHandle/LiftLeverAnchor").global_position
		var handle: Dictionary=player._grab.target
		for i in 30:
			var remaining: float=float(handle.minimum)-float(handle.read.call())
			if absf(remaining)<.001 or not player._grab.active():break
			var point: Vector3=handle.part.to_global(player._grab.contact)
			var tangent: Vector3=(handle.frame.global_basis*handle.axis).cross(point-handle.part.global_position)
			var gesture: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
			if gesture.length()<24 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:gesture=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.)
			drag(gesture*maxf(-.06,remaining))
			await get_tree().physics_frame
		check(wc._flush_stroke_completed,"mouse turns full handle stroke")
		check(wc._refilling,"handle lifts discharge and starts water flow")
		var anchor_after: Vector3=wc.get_node("CisternHandle/LiftLeverAnchor").global_position
		var eye: Vector3=wc.get_node("FlushBall/LiftEye").global_position
		check(anchor_after.y-anchor_before.y>.06 and wc.parts.FlushBall.position.y>.620,"pressed paddle moves inner lever and linked discharge lift rod")
		check(absf(anchor_after.distance_to(eye)-wc.CHAIN_LENGTH)<.0001,"lifted rod obeys authored chain length")
		check(wc._chain.get_child_count()==8 and not wc._chain.find_children("*","CollisionObject3D",true,false).size(),"chain presentation adds no environment collision or sweep")
		await shot("handle_pressed_linkage")
		click()
	await get_tree().create_timer(5).timeout
	check(not wc._refilling and wc.water_level>=.99,"float refills and stops water")
	# Lift the removable cover with the same actual camera ray and mouse path.
	aim(Vector3(0,.835,.235),Vector3(.15,1.4,-.3))
	player.set_physics_process(true)
	click()
	check(player._grab.active() and player._grab.target.part==wc.parts.CisternCover,"cover is separately targetable")
	if player._grab.active():
		check(player._grab.holding_pickup(),"removable cover uses the physical FPS hand")
		for i in 100:await get_tree().physics_frame
		print("HELD CISTERN COVER: ",wc.parts.CisternCover.position," feedback=",player._grab.feedback({}))
		for i in 40:drag(Vector2(-12,0));await get_tree().physics_frame
		for i in 80:await get_tree().physics_frame
		print("CARRIED CISTERN COVER: ",wc.parts.CisternCover.position," feedback=",player._grab.feedback({}))
		check(absf(wc.parts.CisternCover.position.x)>.45,"cover can clear cistern rim")
		check(player._grab.feedback({}).state=="blocked","held cover constraint remains visible in authoritative reticle feedback")
		click()
		check(not player._grab.active(),"next primary releases carried cistern cover")
	player.set_physics_process(false)
	await get_tree().create_timer(.8).timeout
	aim(wc.get_node("CisternHandle/HandleTouchPoint").global_position,Vector3(.48,.83,-.25));click()
	var eye:=player.camera.transform
	key("jump")
	check(player.inspecting(),"space while grabbed enters inspection")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not player._grab.active(),"inspection releases hand and exposes pointer")
	var fixed_eye:=player.camera.global_transform
	drag(Vector2(65,40))
	check(player.camera.global_transform.is_equal_approx(fixed_eye),"cursor motion leaves inspection camera static")
	if player.inspecting():
		var cursor:=player.camera.unproject_position(wc.parts.FloatArm.to_global(Vector3(.25,-.023,0)))
		await warp_cursor(cursor)
		click()
		check(player._grab.active() and player._grab.target.part==wc.parts.FloatArm,"free cursor selects internal float")
		if player._grab.active():
			var before: float=wc.parts.FloatArm.rotation.z
			for i in 8: drag(Vector2(0,12));await get_tree().physics_frame
			check(absf(wc.parts.FloatArm.rotation.z-before)>.04,"internal float follows mouse")
			click()
		await warp_cursor(player.camera.unproject_position(wc.parts.FlushBall.to_global(Vector3(.015,.018,0))))
		click()
		print("DISCHARGE picked=",player._grab.target.get("part"))
		check(player._grab.active() and player._grab.target.part==wc.parts.FlushBall,"cursor selects discharge ball and lift rod")
		if player._grab.active():
			for i in 10: drag(Vector2(0,-10));await get_tree().physics_frame
			check(wc.parts.FlushBall.position.y>.57 and wc._draining,"lifting discharge opens drain independently of handle")
			click()
		await shot("cistern_inspection")
		key("pause_services")
	check(not player.inspecting() and player.camera.transform.is_equal_approx(eye),"escape restores exact previous eye")
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"exit restores captured look")
	aim(wc.get_node("CisternHandle/HandleTouchPoint").global_position,Vector3(.48,.83,-.25))
	await get_tree().physics_frame
	click();key("jump")
	check(player.inspecting(),"inspection can be reentered")
	player.cancel_manipulation()
	check(not player.inspecting() and not player._grab.active() and player.camera.transform.is_equal_approx(eye),"save reconstruction cancellation restores eye and releases hand")
	var state: Dictionary=wc.mechanism_snapshot()
	check(wc.valid_mechanism(state),"all articulated parts have valid durable state")
	wc.restore_mechanism(state)
	check(wc.mechanism_snapshot()==state,"snapshot roundtrip retains mechanisms")
	var invalid:=state.duplicate(true);invalid.water=NAN
	check(not wc.valid_mechanism(invalid),"nonfinite water snapshot rejected")
	# A real locked leaf accepts the hand but rejects physical motion.
	var locked:=DoorProp.new();locked.leaf_state="locked";locked.position=Vector3(2,0,0)
	add_child(locked)
	player.position=Vector3(2.4,0,-1)
	aim(Vector3(2.4,1.1,0),Vector3(2.4,1.3,-1))
	await get_tree().physics_frame
	click()
	check(player._grab.active() and player._grab.target.owner==locked,"locked physical leaf can be gripped")
	drag(Vector2(0,30))
	await get_tree().physics_frame
	await get_tree().process_frame
	player._update_prompt()
	check(player._target_dot.state=="blocked" and is_zero_approx(locked._body.rotation.y),"rejected owner motion shows blocked without bypassing lock")
	await shot("locked_reticle")
	click();locked.free()
	var carrier:=ServiceSetCarrier.new()
	carrier.setup(player,player.camera,null)
	player.carried_device=carrier
	check(not "E: operate" in " ".join(carrier.device.teletype.pages) and not "T: raise" in " ".join(carrier.device.teletype.pages),"startup slip does not teach retired controls")
	await get_tree().process_frame
	await get_tree().process_frame
	carrier.device.teletype.printing=false
	carrier.device.teletype.ink.text="CISTERN / SERVICE WIRE\nSECOND LINE"
	await get_tree().process_frame
	await get_tree().process_frame
	check(carrier._message_line.visible and not carrier._device_rect.visible,"collapsed carry has only one HUD line")
	check(carrier._message_line.text=="CISTERN / SERVICE WIRE","HUD follows actual printed first line")
	await shot("handheld_collapsed")
	var e:=InputEventKey.new();e.physical_keycode=KEY_E;e.pressed=true
	carrier._unhandled_input(e)
	await get_tree().process_frame
	await get_tree().process_frame
	check(carrier.reading and carrier._device_rect.visible,"E expands message")
	check(is_equal_approx(carrier._device_rect.anchor_left,2.0/3.0),"device is confined to right third")
	await shot("handheld_expanded")
	carrier._unhandled_input(e)
	check(not carrier.reading,"E collapses message")
	check(not e.is_action_pressed("interact"),"E cannot operate a world object")
	var driver: Node=load("res://scripts/lamp/carried_lamp_optical_driver.gd").new()
	add_child(driver);driver.setup(player);driver.set_powered(true)
	for i in 120: driver.advance_frame(.1)
	var energy: float=player.flashlight.light_energy
	for i in 240:
		driver.state.apply_mechanical_shock(1)
		driver.advance_frame(.1)
	check(absf(player.flashlight.light_energy-energy)<.0001,"carried beam stays steady across chatter cycles and movement shocks")
	check(driver.state.instability==0,"carried optical observation reports stable output")
	driver.free();player.free();wc.free();light.free();env.free()
	await get_tree().process_frame
	print("TOILET INSPECTION: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
