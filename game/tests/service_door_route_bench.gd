extends "res://tests/radiator_hand_bench.gd"
## INERT external candidate. Requires integration owner's two public test seams.
## Production insert/player/door/closer; one explicit initial player placement.
var _door_trace: Array[Dictionary]=[]
var _door_checks: Array[Dictionary]=[]
var _door_failures: Array[String]=[]
var _door_leaf: DoorProp
var _helper: Node
var _part: Node3D
var _bank: Node3D
var _walker: PlayerController
var _record: Dictionary
var _initial_stock: Dictionary

func _insert_route_probe(prop: RadiatorProp,stock: Node3D,player: PlayerController) -> void:
	_bank=stock;_walker=player
	_helper=preload("res://tests/orison_v2_first_slice_contract_test.gd").new()
	_helper.service_bench_only=true;add_child(_helper)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	for row: Dictionary in source.doors:
		if row.id=="F02_B_ENTRY_DOOR":_record=row.duplicate(true);break
	if _check_door(not _record.is_empty(),"actual authored 2B opening record resolves"):
		_door_leaf=_mount_door(source)
	if _check_door(_door_leaf!=null,"actual domestic fitted door factory mounts 2B stock") and _check_door(_helper.has_method("_service_leaf") and _helper.has_method("_walk_service_player"),"integration owner's service-leaf and player-walk seams exist"):
		var row: Dictionary=stock.active(prop)
		_part=row.body
		_initial_stock=JSON.parse_string(JSON.stringify(stock.mechanism_snapshot()))
		# One initial placement on the inherited floor. No later player teleport.
		player.global_position=Vector3(-.30,0,1.0)
		await _door_programme(prop)
	_finish_door_report()

func _mount_door(source: Dictionary) -> DoorProp:
	# Translate authored F02 coordinates only. Preserve yaw, dimensions, hinge,
	# swing, native meshes, undercut, production collision and closer settings.
	var frame:=Node3D.new();frame.name="TranslatedF02DoorFrame";add_child(frame)
	frame.add_to_group("orison_v2_blockout")
	frame.position=Vector3(.80-float(_record.center[0]),-3.2,1.0-float(_record.center[1]))
	var opening:=Node3D.new();opening.name=str(_record.id)
	opening.position=Vector3(float(_record.center[0]),3.2,float(_record.center[1]))
	opening.rotation.y=float(_record.yaw);frame.add_child(opening)
	var placeholder:=Node3D.new();placeholder.name="Hinge";opening.add_child(placeholder)
	var adapter:=OrisonV2AnchorAdapter.new(frame)
	var factory:=preload("res://scripts/building/orison_v2_domestic_doors.gd").new()
	var spec: Dictionary=factory.SPECS[str(_record.id)].duplicate(true)
	if not factory.mount_specs(adapter,source,{str(_record.id):spec}):return null
	return opening.get_node_or_null(str(_record.id)+"_Leaf") as DoorProp

func _door_programme(prop: RadiatorProp) -> void:
	var identity: String=_part.identity
	var original_instance: int=_part.get_instance_id()
	if not await _helper._service_move_new(_walker,prop,_part,Vector3(0,.004,0),Vector3(.03,.10,-.08),_bank.THREAD_END):return
	if not _check_door(_bank.active(prop).is_empty(),"actual insert unthreads without replacing finite stock"):return
	if not await _helper._pick_service_part(_walker,_part,prop,Vector3(.03,.10,-.08)):return
	var park: Vector3=prop.native_rig.to_global(Vector3(-.30,.12,-.55))
	if not await _helper._deliver_service_part(_walker,_part,park):return
	_click_door_input()
	_state("actual_insert_parked")
	# Root helper handles real Space return and controller physics; no direct
	# pose/collision changes to the part or player follow this initial setup.
	if not await _walk_door(Vector3(-.30,0,1.0)):return
	if not await _open_door("first_empty_open"):return
	if not await _walk_door(Vector3(1.65,0,1.0)):return
	await _door_picture("first_passage_open")
	if not await _wait_natural_close("first_natural_close"):return
	await _door_picture("naturally_closed_from_inside")
	if not await _open_door("empty_return_reopen"):return
	if not await _walk_door(Vector3(-.30,0,1.0)):return
	if not await _wait_natural_close("second_natural_close"):return
	if not await _helper._pick_service_part(_walker,_part,_bank,Vector3(.03,.10,.08)):return
	if not await _walk_door(Vector3(-.50,0,1.0)):return
	_state("same_insert_before_occupied_reopen")
	if not await _open_door("same_insert_setdown_open_reacquire"):return
	if not _check_door(_walker._grab.holding_pickup() and _walker._grab.target.get("part")==_part,"service leaf reopens and returns the exact finite insert to hand"):return
	if not await _walk_door(Vector3(1.65,0,1.0)):return
	await _door_picture("same_insert_across_open_leaf")
	# Return promptly through the same still-open owner, then exercise the
	# original receiving gesture. Do not force its closer or move loose stock.
	if not await _open_door("same_insert_return_leaf"):return
	if not await _walk_door(Vector3(-.50,0,1.0)):return
	var receiving: Transform3D=_bank._thread_pose(prop,_bank.THREAD_END)
	_walker.camera.global_position=receiving.origin+prop.global_basis*Vector3(.02,.15,-.35)
	_walker.camera.look_at(receiving.origin)
	if not await _helper._deliver_service_part(_walker,_part,receiving.origin):return
	_state("same_insert_at_receiving_thread")
	await _door_picture("actual_receiving_view")
	_check_door(_part.get_instance_id()==original_instance and _part.identity==identity and _bank.rows[identity].body==_part,"door route preserves actual insert object and finite identity")
	var now: Dictionary=_bank.mechanism_snapshot()
	_check_door(_bank.valid_mechanism(now),"played stock retains original validated save schema")
	var unchanged:=true
	for old: Dictionary in _initial_stock.parts:
		if old.id==identity:continue
		var matches: Array=now.parts.filter(func(item: Dictionary):return item.id==old.id)
		if matches.size()!=1 or not _same_payload(old,matches[0]):unchanged=false
	_check_door(unchanged and now.parts.size()==_initial_stock.parts.size(),"unrelated finite insert stock and count remain exact")
	_click_door_input() # Normal actual release may catch the real receiving thread.
	_state("final_actual_release")
	_check_door(_helper.failures==0,"original helper assertions retain their full verdict")

func _walk_door(target: Vector3) -> bool:
	var result: bool=await _helper._walk_service_player(_walker,self,target)
	_state("walk_"+str(target))
	return _check_door(result,"original real-capsule controller route reaches "+str(target))

func _open_door(label: String) -> bool:
	_state(label+"_before")
	var result: bool=await _helper._service_leaf(_walker,_door_leaf)
	_state(label+"_after")
	return _check_door(result and _door_leaf.is_ready_for_passage(),"actual root helper opens ready production leaf: "+label)

func _wait_natural_close(label: String) -> bool:
	var deadline: int=Time.get_ticks_msec()+16000
	var previous: float=_door_leaf._body.rotation.y
	var slow:=true
	while Time.get_ticks_msec()<deadline and _door_leaf.open:
		await get_tree().physics_frame
		var current: float=_door_leaf._body.rotation.y
		if absf(previous)-absf(current)>.20*get_physics_process_delta_time()+.0001:slow=false
		previous=current
	_state(label)
	return _check_door(not _door_leaf.open and not _door_leaf.is_ready_for_passage() and slow,"normal delayed .20rad/s closer shuts without forced angle: "+label)

func _state(label: String) -> void:
	var contacts: Array=[]
	for index in _walker.get_slide_collision_count():
		var other: Object=_walker.get_slide_collision(index).get_collider()
		contacts.append(str(other.get_path()) if other is Node else str(other))
	var closer: Variant=_door_leaf._easy if _door_leaf!=null else null
	_door_trace.append({"label":label,"player":var_to_str(_walker.global_transform),"camera":var_to_str(_walker.camera.global_transform),"physics_enabled":_walker.is_physics_processing(),"noclip":_walker.noclip,"collision_layer":_walker.collision_layer,"collision_mask":_walker.collision_mask,"contacts":contacts,"hand_active":_walker._grab.active(),"holding_pickup":_walker._grab.holding_pickup(),"held_part":str(_walker._grab.target.get("part")),"inspection":_walker.inspecting(),"body_identity":_part.identity if _part!=null else "","body_instance":_part.get_instance_id() if _part!=null else 0,"body_pose":var_to_str(_part.global_transform) if _part!=null else "","freeze":_part.get("freeze") if _part!=null else null,"stock_valid":_bank.valid_mechanism(_bank.mechanism_snapshot()),"door_angle":_door_leaf._body.rotation.y if _door_leaf!=null else null,"door_open":_door_leaf.open if _door_leaf!=null else false,"door_ready":_door_leaf.is_ready_for_passage() if _door_leaf!=null else false,"closer_closing":closer.closing if closer!=null else null,"closer_remaining":closer.remaining if closer!=null else null})

func _click_door_input() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	_walker._unhandled_input(event)

func _check_door(ok: bool,label: String) -> bool:
	_door_checks.append({"ok":ok,"label":label})
	if not ok:_door_failures.append(label)
	print("SERVICE DOOR BENCH: ",label," = ",ok)
	return ok

func _door_picture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var output: String=OS.get_environment("SHOT_DIR")
	_check_door(get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"actual diagnostic frame saved: "+label)

func _finish_door_report() -> void:
	var passed: bool=_door_failures.is_empty() and _helper!=null and _helper.failures==0 and _door_trace.any(func(row: Dictionary):return row.label=="final_actual_release")
	var output: String=OS.get_environment("SHOT_DIR")
	var file:=FileAccess.open(output.path_join("service_door_route.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"evidence_class":"INERT","passed":passed,"checks":_door_checks,"failures":_door_failures,"original_helper_failures":_helper.failures if _helper!=null else -1,"travel":_helper.service_travel if _helper!=null else [],"trace":_door_trace,"authored_opening_record":_record,"scope":"Production isolated radiator/stock/player and translated actual2B fitted-door factory. One initial player placement, real slow closer/input/walking; no walls/NPC/full-world/save reconstruction, runtime_contract or artistic acceptance."},"\t"));file.close()
	else:passed=false
	_terminal=true
	get_tree().quit(0 if passed else 1)
