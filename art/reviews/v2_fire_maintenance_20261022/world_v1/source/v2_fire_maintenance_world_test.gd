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
	hands.key(KEY_SPACE)
	if not _require(player.inspecting() and player.inspect_owner==counter,"held bottle enters supported static inspection"):return
	for frame in 125:await get_tree().physics_frame
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
	_phase="carry_out_of_shop"
	for point in [Vector3(9.7,.01,centre.z),Vector3(10.8,.01,centre.z),Vector3(14,.01,centre.z)]:
		if point.x==14 and not await _open_shop():return
		if not await _walk_world(point):return
	if not _require(bottle._held and bottle.get_parent()==counter,"held stock survives shop threshold under its persistent owner"):return
	# Drop onto the original arcade floor, then wait for real physical sleep.
	_phase="released_stock_settle"
	hands.click()
	for frame in 600:
		if bottle.sleeping:break
		await get_tree().physics_frame
	if not _require(bottle.sleeping and not bottle.freeze,"released bottle settles on actual arcade floor"):return
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
	for frame in 120:await get_tree().physics_frame
	var residency: Dictionary=world.passage_region.residency.snapshot()
	_require(residency.state=="DORMANT","actual departure retires shop geometry")
	_require(counter.mechanism_snapshot()==before,"dormant stock retains original physical save pose")
	_require(bottle.freeze,"dormant stock is suspended before floor retirement")
	var directory:=OS.get_environment("SHOT_DIR")
	var file:=FileAccess.open(directory.path_join("stock_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":interaction_checks,"residency":residency,"stock":before},"  "))

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
