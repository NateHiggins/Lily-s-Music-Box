extends "res://tests/orison_v2_vertical_route_test.gd"
## INERT installed-world pictures of the reticle on the prologue bath in 4B and
## on whatever else can be worked from there, under real click and mouse input.
## A picture run for the owner; the bench ReticleValveBench carries the checks.
var out := ""
var shots := 0

func _init() -> void:
	route_label="RETICLE WORLD CAPTURE"

func _need(ok: bool,label: String) -> bool:
	print("RETICLE WORLD ","PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
	return ok

func _click() -> void:
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	player._unhandled_input(event)
	await _settle()

func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

func _drag(pixels: Vector2) -> void:
	var steps:=maxi(1,ceili(pixels.length()/12.))
	for step in steps:
		var motion:=InputEventMouseMotion.new()
		motion.relative=pixels/float(steps)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	await get_tree().process_frame

func _aim(point: Vector3) -> void:
	player.velocity=Vector3.ZERO
	player.face_world_point(point)
	await _settle()
	player.face_world_point(point)
	await _settle()

func _shot(label: String) -> void:
	if out.is_empty() or DisplayServer.get_name()=="headless":return
	for frame in 6:await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	shots+=1
	var stem:="%02d_%s"%[shots,label]
	image.save_png(out.path_join(stem+".png"))
	var mark: Vector2=player._target_dot.position
	var side:=mini(420,mini(image.get_width(),image.get_height()))
	var corner:=Vector2i(clampi(int(mark.x)-side/2,0,image.get_width()-side),clampi(int(mark.y)-side/2,0,image.get_height()-side))
	var detail:=image.get_region(Rect2i(corner,Vector2i(side,side)))
	detail.resize(side*2,side*2,Image.INTERPOLATE_LANCZOS)
	detail.save_png(out.path_join(stem+"_detail.png"))

func _route() -> void:
	out=OS.get_environment("SHOT_DIR")
	if not out.is_empty():DirAccess.make_dir_recursive_absolute(out)
	var tap:=world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	if not _need(tap!=null and tap.get("model") is Node3D,"the prologue bath is installed in 4B"):return
	var model: Node3D=tap.get("model")
	# The opening has her draw the curtain back before she reaches the valves.
	var curtain: Variant=tap.get("_curtain_hand")
	if curtain!=null:curtain.set_travel(curtain.TRAVEL)
	player.global_position=model.to_global(Vector3(0,.239,0));player.velocity=Vector3.ZERO
	for frame in 40:await get_tree().physics_frame
	_need(player._target_dot.is_visible_in_tree(),"the aiming mark is drawn in the occupied world")
	for index in 2:
		var word:="hot" if index==0 else "cold"
		var handle: Node3D=tap._handles[index]
		var grip: Dictionary=tap.valve_grip(index)
		var cap: Vector3=handle.global_position+((grip.frame as Node3D).global_basis*(grip.axis as Vector3)).normalized()*.06
		await _aim(cap)
		if not _need(player._grab.find_target().get("part")==handle and player._target_dot.guide.get("archetype")=="dial","standing in the tub, the aim reads the "+word+" valve as a dial: hit="+str(player._grab.last_hit.get("collider"))+" eye="+str(model.to_local(player.camera.global_position))+" cap="+str(model.to_local(cap))):continue
		await _shot("hover_"+word)
		await _click()
		if not _need(player._grab.active() and tap._held_valve==index,"click takes the "+word+" valve"):continue
		await _drag(Vector2(120,0))
		_need(absf(tap._valve_openings[index]-.5)<.01,"120 px right half opens the "+word+" valve")
		await _shot("grab_"+word)
		await _drag(Vector2(300,0))
		for push in 3:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(12,0)
			player._unhandled_input(motion)
			await get_tree().physics_frame;await get_tree().physics_frame;await get_tree().process_frame
		_need(is_equal_approx(tap._valve_openings[index],1.),"right runs the "+word+" valve to its stop")
		await _shot("stop_"+word)
		await _drag(Vector2(-84,0))
		await _click()
		_need(not player._grab.active() and tap._valve_openings[index]>.6 and bool(tap.get_flow_state().hot if index==0 else tap.get_flow_state().cold),"release leaves the "+word+" water running")
	# Both valves are open: the water itself.
	await get_tree().create_timer(1.2).timeout
	await _aim(tap._stream.global_position.lerp(tap._handles[0].global_position,.55))
	await _shot("water_running")
	for index in 2:
		var handle: Node3D=tap._handles[index]
		var grip: Dictionary=tap.valve_grip(index)
		await _aim(handle.global_position+((grip.frame as Node3D).global_basis*(grip.axis as Vector3)).normalized()*.06)
		await _click()
		await _drag(Vector2(-400,0))
		if index==1:await _shot("stop_off_cold")
		await _click()
	_need(is_zero_approx(float(tap.get_flow_state().flow)),"left on both valves shuts the water off")
	# Everything else within reach of the bathroom: what does the mark say about it?
	var seen: Dictionary={}
	for stance: Vector3 in [model.to_global(Vector3(0,.239,0)),model.to_global(Vector3(0,0,-1.05))]:
		player.global_position=stance;player.velocity=Vector3.ZERO
		for frame in 30:await get_tree().physics_frame
		for area: Node in get_tree().get_nodes_in_group("functional_interaction_areas"):
			if not area is Area3D or not (area as Area3D).is_inside_tree() or seen.size()>=8:continue
			var shape:=area.get_child(0) as Node3D if area.get_child_count()>0 else null
			if shape==null or shape.global_position.distance_to(player.camera.global_position)>1.9:continue
			await _aim(shape.global_position)
			var guide: Dictionary=player._target_dot.guide
			var part: Variant=guide.get("part")
			if not part is Node3D or (part as Node3D) in tap._handles:continue
			var key:=str(guide.get("archetype"))+":"+str((part as Node3D).get_path())
			if seen.has(key) or seen.values().count(guide.get("archetype"))>=3:continue
			seen[key]=guide.get("archetype")
			print("RETICLE WORLD HOVER ",key," direction=",guide.get("direction")," fraction=",guide.get("fraction"))
			await _shot("hover_%s_%s"%[guide.get("archetype"),str((part as Node3D).name).to_snake_case().left(24)])
	_need(not seen.is_empty(),"other workable parts near the bath show a mark")
