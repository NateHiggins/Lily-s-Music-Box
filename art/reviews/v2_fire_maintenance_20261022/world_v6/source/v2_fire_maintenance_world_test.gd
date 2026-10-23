extends "res://tests/v2_street_film_profile.gd"
## Played-world diagnostic, not runtime qualification. One initial placement;
## ordinary standing locomotion, exact part targeting and actual mouse input.
const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
var hands: Node3D
var counter: Node3D
var door: DoorProp

func _init() -> void:
	route_label="V2 HARDWARE STOCK WORLD"

func _prepare_player_start() -> void:
	door=world.passage_region.doors.get("SITE_SHOP_DOOR_HARDWARE_PAINT")
	if door==null:return
	var centre: Vector3=door.to_global(Vector3(door.width*.5,0,0))
	player.global_position=Vector3(14,.03,centre.z)
	player.velocity=Vector3.ZERO

func _route() -> void:
	await super._route()
	# A failed diagnostic may still own a part. Release while both its owner
	# and the player remain in the tree, before the inherited world teardown.
	if is_instance_valid(player) and player.is_inside_tree():player.cancel_manipulation()

func _street_route() -> void:
	counter=world.fire_maintenance_counter
	if not _require(counter!=null and door!=null,"production counter mounts at the retained shop"):return
	hands=Hands.new();hands.set_meta("shared_world_validation",true);add_child(hands);hands.player=player
	var centre: Vector3=door.to_global(Vector3(door.width*.5,0,0))
	_phase="hardware_entry"
	if not await _walk_world(Vector3(12.4,.01,centre.z)):return
	if not await _open_shop():return
	for point in [Vector3(10.8,.01,centre.z),Vector3(9.7,.01,centre.z)]:
		if not await _walk_world(point):return
	var front: Vector3=counter.to_global(Vector3(0,-counter.global_position.y+.01,-.95))
	if not await _walk_world(front):return
	await hands.aim(counter.to_global(Vector3(0,.10,0)))
	await _picture("counter_approach")
	var economy: Node=world.get_node("CaretakerEconomy")
	var bottle: Node3D=counter.pickups.fire_hose_rubber_protectant
	var terminal: Node3D=counter.terminals.fire_hose_rubber_protectant
	var initial_cash: int=int(economy.book().cash)
	_phase="radio_off_pull"
	if world.service_set_carrier.radio_is_powered():await _radio_key()
	if not _require(not world.service_set_carrier.radio_is_powered(),"real handheld radio switch is off"):return
	if not _require(await hands._stroke(terminal,.04),"actual ray and full mouse stroke reach mounted sale lever"):return
	if not _require(int(economy.book().cash)==initial_cash and not world.maintenance_inventory.has_item("fire_hose_rubber_protectant"),"radio-off refusal preserves money and stock custody"):return
	await _radio_key()
	await get_tree().create_timer(.6).timeout
	_phase="settlement_pull"
	if not _require(world.service_set_carrier.radio_is_powered(),"same handheld radio switch supplies settlement carrier"):return
	if not _require(await hands._stroke(terminal,.04),"actual full pull settles bottle purchase"):return
	if not _require(world.maintenance_inventory.has_item("fire_hose_rubber_protectant") and int(economy.book().cash)==initial_cash-25,"original inventory and cash ledger record exactly25c"):return
	await hands.aim(bottle.to_global(Vector3(0,.08,-.034)))
	hands.click()
	if not _require(player._grab.active() and player._grab.target.part==bottle,"paid native bottle is picked up through its specific target"):return
	_phase="held_stock_follow"
	for frame in 90:await get_tree().physics_frame
	if not _require(_in_hand(bottle),"picked bottle reaches the real FPS hand pose without obstruction"):
		_stock_diagnostic(bottle);return
	hands.key(KEY_SPACE)
	if not _require(player.inspecting() and player.inspect_owner==counter,"held bottle enters supported static inspection"):return
	for frame in 125:await get_tree().physics_frame
	if not _require(player.camera.to_local(bottle.to_global(bottle.pickup_centre())).distance_to(Vector3(0,-.035,-.45))<.025,"supported inspection actually presents bottle at reading distance"):
		_stock_diagnostic(bottle);return
	await _picture("bottle_inspection")
	_phase="cap_input"
	if not _require(await hands.acquire_surface(bottle.cap,bottle.cap.to_global(Vector3(0,.006,-.016))),"inspection free cursor identifies cap rather than bottle"):return
	hands.click()
	if not _require(player._grab.active() and player._grab.target.part==bottle.cap,"primary click takes the cap mechanism"):return
	if not _require(await hands._gesture_to(1.9),"actual mouse motion opens cap to its stop"):return
	hands.click()
	await _picture("bottle_cap_open")
	hands.key(KEY_SPACE)
	if not _require(not player.inspecting() and player._grab.holding_pickup(),"leaving inspection returns bottle to hand"):return
	await get_tree().physics_frame;await get_tree().physics_frame
	if not _require(bottle.get_collision_exceptions().has(door._body),"unlocked door grants the carrier's held stock the same passage priority"):return
	_phase="carry_out_of_shop"
	for point in [Vector3(9.7,.01,centre.z),Vector3(10.8,.01,centre.z),Vector3(14,.01,centre.z)]:
		if point.x==14 and not await _open_shop():return
		if not await _walk_world(point):return
	if not _require(_in_hand(bottle) and bottle.get_parent()==counter,"held stock physically follows through the shop threshold"):
		_stock_diagnostic(bottle);return
	# Drop onto the original arcade floor, then wait for real physical sleep.
	_phase="released_stock_settle"
	hands.click()
	await get_tree().physics_frame;await get_tree().physics_frame
	if not _require(not bottle.get_collision_exceptions().has(door._body),"release restores ordinary stock collision with the door"):return
	for frame in 600:
		if bottle.sleeping:break
		await get_tree().physics_frame
	if not _require(bottle.sleeping and not bottle.freeze and absf(bottle.global_position.y)<.20,"released bottle settles on actual arcade floor"):
		_stock_diagnostic(bottle);return
	var before: Dictionary=counter.mechanism_snapshot()
	world.household_state.capture_now()
	var household: Dictionary=world.household_state.snapshot()
	if not _require(household.records.has(str(counter.name)) and household.records[str(counter.name)].value==before,"sole household owner captures dropped pose and cap"):return
	await _picture("bottle_on_arcade_floor")
	# Actual walking to the street must retire the arcade; its sleeping loose
	# stock must suspend before the original floor is removed.
	_phase="walk_to_street"
	for z in [32.,27.5,20.,17.3]:
		if not await _walk_world(Vector3(14,.01,z)):return
	for point in [Vector3(14,0,15),Vector3(14,-.1,13.6),Vector3(14,-.1,8),Vector3(14,0,4.2),Vector3(14,0,3),Vector3(0,0,3)]:
		if not await _walk_world(point):return
	_phase="return_to_building_core"
	if not await _enter_front_entrance():return
	for point in [Vector3(1.925,0,-6.5),Vector3(1.925,0,-3.5)]:
		if not await _walk(point):return
	for frame in 120:await get_tree().physics_frame
	var residency: Dictionary=world.passage_region.residency.snapshot()
	_require(residency.state=="DORMANT","actual departure retires shop geometry")
	_require(counter.mechanism_snapshot()==before,"dormant stock retains original physical save pose")
	_require(bottle.freeze,"dormant stock is suspended before floor retirement")
	if failures.is_empty():await _save_reload(before)
	var directory:=OS.get_environment("SHOT_DIR")
	var file:=FileAccess.open(directory.path_join("stock_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":interaction_checks,"residency":residency,"stock":before},"  "))

func _save_reload(wanted: Dictionary) -> void:
	_collect=false
	var original_path: String=RealityState.save_path
	var test_path: String="user://v2_fire_stock_%d.json" % Time.get_ticks_usec()
	RealityState.save_path=test_path
	var saved: bool=RealityState.save_game()
	_require(saved,"real save storage captures purchased stock through household owner")
	if saved:
		world.shutdown_for_tests();world.free()
		RealityState.reset_campaign_for_tests();RealityState.load_game()
		world=Runtime.instantiate();add_child(world)
		if _require(not world.startup_failed,"purchased stock reconstructs in the production world"):
			player=world.player;hands.player=player;counter=world.fire_maintenance_counter
			player.camera.make_current()
			await get_tree().physics_frame;await get_tree().physics_frame
			var actual: Dictionary=counter.mechanism_snapshot()
			for identity: String in wanted:
				var a: Dictionary=actual[identity];var b: Dictionary=wanted[identity]
				var pa:=Vector3(a.stock.position[0],a.stock.position[1],a.stock.position[2])
				var pb:=Vector3(b.stock.position[0],b.stock.position[1],b.stock.position[2])
				var qa:=Basis(Quaternion(a.stock.rotation[0],a.stock.rotation[1],a.stock.rotation[2],a.stock.rotation[3]))
				var qb:=Basis(Quaternion(b.stock.rotation[0],b.stock.rotation[1],b.stock.rotation[2],b.stock.rotation[3]))
				_require(pa.distance_to(pb)<.00001 and qa.is_equal_approx(qb) and is_equal_approx(float(a.cap),float(b.cap)) and a.parked==b.parked and a.stock.sleeping==b.stock.sleeping,"disk rebuild restores physical stock and cap: "+identity)
			var economy: Node=world.get_node("CaretakerEconomy")
			_require(world.maintenance_inventory.has_item("fire_hose_rubber_protectant") and int(economy.book().cash)==75,"rebuild retains acquisition and original75c cash without rebilling")
	RealityState.save_path=original_path
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path:=ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)

func _in_hand(body: Node3D) -> bool:
	return body._held and not body._hold_blocked and player.camera.to_local(body.to_global(body.pickup_centre())).distance_to(Vector3(.17,-.16,-.48))<.035

func _stock_diagnostic(body: Node3D) -> void:
	print("STOCK WORLD DIAGNOSTIC ",JSON.stringify({"position":str(body.global_position),"camera":str(player.camera.global_position),"held":body._held,"freeze":body.freeze,"sleeping":body.sleeping,"velocity":str(body.linear_velocity),"blocked":body._hold_blocked,"contact":str(body._last_motion),"inspection":player.inspecting()}))

func _open_shop() -> bool:
	if door.open and not door._moving:return true
	await hands.aim(door._body.to_global(Vector3(door.width*.35,1.1,door._hinge_offset)))
	hands.click()
	if not _require(player._grab.active() and player._grab.target.owner==door,"primary click reaches hardware door part"):return false
	if not await hands._gesture_to(door.motion_target_angle(true)):return _require(false,"hardware door gesture reaches open stop")
	hands.click()
	return _require(door.is_ready_for_passage(),"hardware door allows immediate player passage")

func _radio_key() -> void:
	Input.action_press("radio_toggle")
	await get_tree().physics_frame;await get_tree().physics_frame
	Input.action_release("radio_toggle")
	await get_tree().physics_frame

func _picture(label: String) -> void:
	# Do not include synchronous readback/PNG time in the frame samples.
	_collect=false
	await RenderingServer.frame_post_draw
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	await get_tree().process_frame;_previous_usec=0;_collect=true
