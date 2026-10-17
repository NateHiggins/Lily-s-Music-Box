extends RefCounted

func _aim(bench: Node3D,player: Node3D,body: Node3D) -> void:
	var at := body.to_global(Vector3(0,.004,0))
	player.camera.global_position=at+Vector3(.03,.10,.08)
	player.camera.look_at(at)
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame
	player.camera.look_at(body.to_global(Vector3(0,.004,0)))

func _carry_between(bench: Node3D,player: Node3D,stock: Node3D,body: Node3D,goal: Vector3,failures: Array) -> bool:
	var contact: Vector3=body.to_global(player._grab.contact)
	player.camera.global_position=(contact+stock.to_global(goal))*.5+Vector3(0,.5,1.1)
	player.camera.look_at(contact)
	await bench._carry_to(player,goal)
	if not player._grab.active() or body.position.distance_to(goal)>.001:
		failures.append("free insert stays acquired throughout visible transfer")
		return false
	return true

func run(bench: Node3D,prop: Node3D,stock: Node3D,player: Node3D,driver: Node3D,codec: Node,failures: Array) -> void:
	prop.set_supply_position(0.0,0.0)
	var original: Dictionary=stock.active(prop)
	var original_id: String=original.body.identity
	var grade: int=prop.vent_grade
	var grade_events: Array=[]
	var grade_observer := func(value: int): grade_events.append(value)
	prop.vent_changed.connect(grade_observer)
	prop.set_vent_grade((grade+1)%5)
	if prop.vent_grade!=grade: failures.append("grade setter cannot replace a physical insert")
	await _aim(bench,player,original.body)
	var target: Dictionary=player._grab.find_target()
	if target.get("part")!=original.body: failures.append("cursor finds physical installed orifice");return
	driver._click(player)
	if not player._grab.active() or stock.held!=original_id: failures.append("grab installed orifice");return
	driver._drag_to(player,stock.THREAD_END)
	driver._click(player)
	if not stock.active(prop).is_empty(): failures.append("unthreading removes real insert from cap");return
	await _aim(bench,player,original.body)
	driver._click(player)
	if not player._grab.active(): failures.append("regrab withdrawn orifice");return
	if not await _carry_between(bench,player,stock,original.body,Vector3(.35,.12,.05),failures): return
	print("OLD INSERT CARRY active=",player._grab.active()," held=",stock.held," at=",original.body.position)
	driver._click(player)
	var replacement: Dictionary=stock.rows.VENT_SPARE_2
	player.global_position=Vector3(1.0,0,1.15)
	await _aim(bench,player,replacement.body)
	print("SPARE BEFORE CLICK active=",player._grab.active()," target=",player._grab.find_target()," inspecting=",player.inspecting()," locked=",player.call_locked," mouse_released=",player.mouse_released)
	driver._click(player)
	if not player._grab.active() or stock.held!="VENT_SPARE_2":
		var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,replacement.body.global_position)
		query.collide_with_areas=true
		print("SPARE RAY ",bench.get_world_3d().direct_space_state.intersect_ray(query)," BODY ",replacement.body.global_transform," DRAW ",replacement.draw.global_transform," AABB ",replacement.draw.get_aabb())
		print("SPARE TARGET ",player._grab.target," STOCK HELD ",stock.held," RAD HELD ",prop._native_held)
		failures.append("grab actual workshop spare");return
	if not await _carry_between(bench,player,stock,replacement.body,replacement.body.position+Vector3.UP*.02,failures): return
	var player_before: Vector3=player.global_position
	var part_before: Vector3=replacement.body.global_position
	player.autopilot=Vector3(.15,0,0)
	player.set_physics_process(true)
	await bench.get_tree().create_timer(.25).timeout
	player.set_physics_process(false)
	player.autopilot=Vector3.ZERO
	player.velocity=Vector3.ZERO
	var travelled: Vector3=player.global_position-player_before
	if not player._grab.active() or travelled.length()<.02 or (replacement.body.global_position-part_before).distance_to(travelled)>.003:
		failures.append("actual player locomotion carries acquired loose insert")
	var receiving: Transform3D=stock._thread_pose(prop,stock.THREAD_END)
	if not await _carry_between(bench,player,stock,replacement.body,stock.to_local(receiving.origin),failures): return
	driver._click(player)
	if replacement.slot!=prop.graph_node_id or absf(replacement.turn-stock.THREAD_END)>.0001: failures.append("spare catches cap thread without auto seating");return
	await _aim(bench,player,replacement.body)
	driver._click(player)
	driver._drag_to(player,0.0)
	driver._click(player)
	if absf(replacement.turn)>.0001 or prop.vent_grade!=2 or stock.active(prop).body!=replacement.body or original.body.identity!=original_id or stock.rows.size()!=6:
		failures.append("physical replacement preserves both identities and publishes actual grade")
	if grade_events!=[2]: failures.append("actual physical replacement preserves grade-change observations")
	prop.vent_changed.disconnect(grade_observer)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	if not codec.validate(saved,codec._kinds): failures.append("combined radiator/stock household validation")
	var wrong := saved.duplicate(true)
	wrong.records.F02_B_RADIATOR_01.value.vent_grade=4
	if codec.validate(wrong,codec._kinds): failures.append("household rejects cache/physical insert mismatch")
	var duplicate: Dictionary=stock.mechanism_snapshot().duplicate(true)
	var bad_version := duplicate.duplicate(true)
	bad_version.version=true
	if stock.valid_mechanism(bad_version): failures.append("stock rejects boolean version")
	duplicate.parts[1]={"id":"VENT_SPARE_0","grade":0,"slot":prop.graph_node_id,"turn":0.0}
	if stock.valid_mechanism(duplicate): failures.append("stock rejects duplicate socket occupancy")
	var moved: Dictionary=stock.mechanism_snapshot().duplicate(true)
	for part: Dictionary in moved.parts:
		if part.id=="VENT_SPARE_2":
			part.erase("slot");part.erase("turn")
			part.position=[.2,.1,.1];part.rotation=[0,0,0,1]
	stock.restore_mechanism(moved)
	codec._restore(saved)
	if stock.active(prop).body!=replacement.body or replacement.turn>.0001 or stock.rows.size()!=6: failures.append("restoration retains exchanged physical identities")
	for part: Dictionary in saved.records.B1_VENT_SERVICE_STOCK.value.parts:
		if part.id==original_id and part.has("position"):
			if original.body.position.distance_to(Vector3(part.position[0],part.position[1],part.position[2]))>.000001: failures.append("loose original insert restores its measured pose")
	var legacy := saved.duplicate(true)
	legacy.records.erase("B1_VENT_SERVICE_STOCK")
	legacy.records.F02_B_RADIATOR_01.value.vent_grade=1
	if not codec.validate(legacy,codec._kinds): failures.append("legacy pre-stock household accepted for migration")
	codec._restore(legacy)
	if stock.active(prop).body.identity!=original_id or stock.active(prop).grade!=1 or stock.rows.size()!=6: failures.append("legacy migration preserves roster and original identity")
	codec._restore(saved)
	await _aim(bench,player,replacement.body)
	driver._click(player)
	if stock.held!="VENT_SPARE_2" or prop._native_held!="vent_orifice": failures.append("restoration fixture acquires mounted insert through actual cursor")
	stock.restore_mechanism(JSON.parse_string(JSON.stringify(stock.mechanism_snapshot())))
	player._grab.validate()
	if player._grab.active() or not stock.held.is_empty() or not prop._native_held.is_empty(): failures.append("direct stock restoration revokes both part and radiator hand custody")
	player.camera.global_position=stock.to_global(Vector3(.02,.18,.30))
	player.camera.look_at(stock.to_global(Vector3(0,.025,0)))
	await bench.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		if bench.get_viewport().get_texture().get_image().save_png(directory.path_join("orifice_workshop_stock.png"))!=OK: failures.append("stock capture write")
		var view_at: Vector3=prop.native_rig.vent.to_global(Vector3(.043,.035,0))
		player.camera.global_position=view_at+prop.global_basis*Vector3(.10,.07,-.18)
		player.camera.look_at(view_at)
		var lamp_was_on: bool=player.lamp_is_enabled()
		for enabled: bool in [false,true]:
			player.set_lamp_enabled(enabled)
			await bench.get_tree().create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			if bench.get_viewport().get_texture().get_image().save_png(directory.path_join("vent_exterior_lamp_"+("on" if enabled else "off")+".png"))!=OK: failures.append("vent exterior capture write")
		player.set_lamp_enabled(lamp_was_on)
	print("ORIFICE HAND PASS COMPLETE; identities ",stock.rows.size())
