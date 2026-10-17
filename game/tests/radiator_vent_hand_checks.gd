extends RefCounted
## Actual cap/needle gestures, not setter-only interaction evidence.
func run(bench: Node3D,prop: Node3D,player: Node3D,driver: Node3D,codec: Node,failures: Array) -> void:
	prop.set_supply_position(0.0,0.0)
	var cap: RigidBody3D=prop.native_vent_cap
	var grade: int=prop.vent_grade
	var contact: Vector3=cap.to_global(Vector3(0,.018,-.015))
	player.camera.global_position=contact+prop.global_basis*Vector3(.04,.10,-.18)
	player.camera.look_at(contact)
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame
	var found: Dictionary=player._grab.find_target()
	if found.get("part")!=cap:
		failures.append("cursor acquires actual vent cap")
		return
	driver._click(player)
	if not player._grab.active() or prop._native_held!="vent_cap": failures.append("grab vent cap");return
	driver._drag_to(player,cap.TURN_END*.45)
	var partial := cap.global_transform
	var saved: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	driver._drag_to(player,cap.TURN_END)
	driver._click(player)
	if not cap.loose: failures.append("full cap thread travel frees actual cap")
	# Reacquire before gravity moves the small cap out of the current ray.
	driver._click(player)
	if not player._grab.active() or prop._native_held!="vent_cap": failures.append("regrab unthreaded cap");return
	var away: Vector3=prop.to_local(cap.home().origin)+Vector3(.12,.10,-.08)
	await bench._carry_to(player,away)
	driver._click(player)
	if not cap.chamber_exposed() or prop.vent_grade!=grade: failures.append("cap removal exposes chamber without cycling grade")
	# A partial-thread save must restore actual changed geometry.
	if not codec.validate(saved,codec._kinds): failures.append("partial cap household codec validation")
	codec._restore(saved)
	if cap.loose or not cap.global_transform.is_equal_approx(partial): failures.append("partial cap physical restoration")
	var legacy := saved.duplicate(true)
	legacy.records.F02_B_RADIATOR_01.value.vent_cap={"loose":false,"turn":TAU*.9}
	if not codec.validate(legacy,codec._kinds):failures.append("legacy coarse cap state validates for depth migration")
	codec._restore(legacy)
	# Compare in the receiving axis; a rotated installed radiator may lean.
	var depth: float=(cap.home().affine_inverse()*cap.global_position).y
	if cap.loose or absf(depth-.0063)>.000001 or not cap.snapshot().has("thread_version"):
		failures.append("legacy cap preserves withdrawal depth with matched new thread phase")
	legacy.records.F02_B_RADIATOR_01.value.vent_cap={"loose":false,"turn":TAU*2}
	codec._restore(legacy)
	if not cap.loose or absf((cap.home().affine_inverse()*cap.global_position).y-.014)>.000001:
		failures.append("legacy cap beyond new engagement becomes free at its original depth")
	var malformed := saved.duplicate(true)
	malformed.records.F02_B_RADIATOR_01.value.vent_cap.thread_version=true
	if codec.validate(malformed,codec._kinds):failures.append("cap thread version rejects booleans")
	codec._restore(saved)
	# Repeat removal, carry clear and leave the cap in the hand while invoking
	# the ordinary Space inspection action. The camera must reach the chamber.
	contact=cap.to_global(Vector3(0,.018,-.015))
	player.camera.global_position=contact+prop.global_basis*Vector3(.04,.10,-.18)
	player.camera.look_at(contact)
	await bench.get_tree().physics_frame
	driver._click(player)
	driver._drag_to(player,cap.TURN_END)
	driver._click(player)
	driver._click(player)
	if not player._grab.active(): failures.append("cap removal after partial restore");return
	await bench._carry_to(player,away)
	var space := InputEventKey.new()
	space.keycode=KEY_SPACE
	space.physical_keycode=KEY_SPACE
	space.pressed=true
	print("VENT INSPECT SPACE ",space.is_action_pressed("jump")," HELD ",prop._native_held," CAP CLEAR ",cap.chamber_exposed())
	player._unhandled_input(space)
	if not player.inspecting(): failures.append("Space inspection reaches vent chamber");return
	await bench.get_tree().physics_frame
	var float_part: Node3D=prop.native_rig.vent.get_node("FloatAndNeedle")
	var float_contact: Vector3=prop.native_rig.vent.to_global(Vector3(.043,.055,0))
	var cursor: Vector2=player.camera.unproject_position(float_contact)
	Input.warp_mouse(cursor)
	await bench.get_tree().process_frame
	var target: Dictionary=player._grab.find_target()
	if target.get("part")!=float_part: failures.append("inspection cursor reaches exposed needle")
	driver._click(player)
	if not player._grab.active() or prop._native_held!="vent_float": failures.append("grab exposed needle");player.end_inspection();return
	var before_camera: Transform3D=player.camera.global_transform
	driver._drag_to(player,.0050)
	if absf(float_part.position.y-.0050)>.0001 or not player.camera.global_transform.is_equal_approx(before_camera): failures.append("needle moves in static inspection camera")
	driver._click(player)
	await bench.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty() and bench.get_viewport().get_texture().get_image().save_png(directory.path_join("vent_open_chamber.png"))!=OK:
		failures.append("vent inspection capture write")
	player.end_inspection()
	var loose_saved: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	var loose_pose: Transform3D=cap.transform
	cap.position+=Vector3(.3,.1,.1)
	codec._restore(loose_saved)
	if not cap.loose or not cap.transform.is_equal_approx(loose_pose): failures.append("loose cap pose restores through household codec")
	if prop.vent_grade!=grade or prop.native_pressure_leak()<.999: failures.append("open cap preserves insert grade and causes physical pressure loss")
	# Real free carry to the mouth only catches the thread. Sealing still
	# requires two reverse turns, with the existing insert retained.
	contact=cap.to_global(Vector3(0,.018,-.015))
	player.camera.global_position=contact+prop.global_basis*Vector3(.04,.10,-.18)
	player.camera.look_at(contact)
	await bench.get_tree().physics_frame
	contact=cap.to_global(Vector3(0,.018,-.015))
	player.camera.look_at(contact)
	driver._click(player)
	if not player._grab.active() or prop._native_held!="vent_cap": failures.append("loose cap pickup after restore");return
	await bench._carry_to(player,prop.to_local(cap.home().origin+cap.home().basis*Vector3.UP*cap.THREAD_TRAVEL))
	driver._click(player)
	if cap.loose or absf(cap.turn-cap.TURN_END)>.0001: failures.append("cap catches receiving thread without auto sealing");return
	contact=cap.to_global(Vector3(0,.018,-.015))
	player.camera.global_position=contact+prop.global_basis*Vector3(.04,.10,-.18)
	player.camera.look_at(contact)
	await bench.get_tree().physics_frame
	driver._click(player)
	driver._drag_to(player,0.0)
	driver._click(player)
	if cap.loose or cap.turn>.0001 or prop.vent_grade!=grade:
		print("CAP RESEAT ACTUAL loose=",cap.loose," turn=",cap.turn," grade=",prop.vent_grade," held=",prop._native_held)
		failures.append("reverse cap turns seal original grade")
	await _supply_observations(bench,prop,player,driver,failures)
	await _thermal_float(bench,prop,failures)
	print("VENT HAND PASS COMPLETE")

func _thermal_float(bench: Node3D,prop: Node3D,failures: Array) -> void:
	var original: Dictionary=prop.mechanism_snapshot()
	var original_balance: Variant=prop._balance
	var original_id: String=prop.graph_node_id
	var fixture := original.duplicate(true)
	fixture.supply_position=1.0
	fixture.service_progress=0.0
	fixture.packing_spread=0.0
	fixture.packing_out=0.0
	fixture.packing={"station":0}
	fixture.vent_cap={"loose":false,"turn":0.0}
	var balance := HeatBalance.new()
	balance.configure({"floors":[{"markers":[{"kind":"radiator","id":original_id,"unit":"2B"}]}]})
	prop.bind_heat_balance(balance)
	prop.restore_mechanism(fixture)
	await bench.get_tree().create_timer(3.0).timeout
	var float_part: Node3D=prop.native_rig.vent.get_node("FloatAndNeedle")
	if absf(float_part.position.y-.0055)>.0001 or balance.result_for(original_id).heat<=0: failures.append("shared steam heat closes actual vent needle")
	prop.set_supply_position(0.0,0.0)
	await bench.get_tree().create_timer(3.0).timeout
	if absf(float_part.position.y)>.0001: failures.append("cold vent needle returns without grade change")
	prop._balance=original_balance
	prop.graph_node_id=original_id
	prop.restore_mechanism(original)

func _supply_observations(bench: Node3D,prop: Node3D,player: Node3D,driver: Node3D,failures: Array) -> void:
	var events: Array=[]
	var observer := func(action: String,value: Dictionary):
		if action=="turn_valve": events.append(value.duplicate(true))
	prop.physical_action.connect(observer)
	var original: Dictionary=prop.mechanism_snapshot()
	var condition: String=prop.open_shift_condition
	prop.open_shift_condition="sounding"
	prop.set_supply_position(1.0,0.0)
	var contact: Vector3=prop._wheel.global_position+prop.global_basis*Vector3(0,0,-.055)
	player.camera.global_position=contact+prop.global_basis*Vector3(0,.15,-.35)
	player.camera.look_at(contact)
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame
	driver._click(player)
	if not player._grab.active(): failures.append("supply cursor for physical observations");prop.physical_action.disconnect(observer);return
	driver._click(player)
	if not events.is_empty(): failures.append("unchanged supply grab emits no intervention")
	driver._click(player)
	driver._drag_to(player,TAU*3.5*.42)
	driver._click(player)
	if events.size()!=1 or events[0].condition!="sounding" or not events[0].supply_partial or prop.open_shift_condition!="wrong_valve_partial": failures.append("real partial valve turn reports original case and interference")
	prop.open_shift_condition="repaired"
	driver._click(player)
	driver._drag_to(player,TAU*3.5)
	driver._click(player)
	if events.size()!=2 or events[1].condition!="repaired" or prop.open_shift_condition!="repaired": failures.append("physical valve observation preserves repaired authority")
	prop.physical_action.disconnect(observer)
	prop.restore_mechanism(original)
	prop.open_shift_condition=condition
