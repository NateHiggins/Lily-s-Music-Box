extends "res://tests/v2_street_film_profile.gd"
## Played-world diagnostic, not runtime qualification. One initial placement;
## ordinary standing locomotion, exact part targeting and actual mouse input.
const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const PAID_GASKET := "fire_hose_spare_gasket"
const PAID_STATION := "F02_FIRE_LINE_STAIR"
var hands: Node3D
var counter: Node3D
var door: DoorProp

func _init() -> void:
	route_label="V2 HARDWARE STOCK WORLD"

func _ready() -> void:
	var viewport := get_viewport()
	if viewport is SubViewport:
		var window := get_tree().root
		viewport.msaa_3d=window.msaa_3d
		viewport.scaling_3d_scale=window.scaling_3d_scale
		viewport.use_taa=window.use_taa
		viewport.notify_mouse_entered()
	super._ready()

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
	if OS.get_environment("V2_INSTALLED_PAID_GASKET") == "1":
		await _paid_gasket_case(centre.z)
		return
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
	await get_tree().create_timer(world.passage_region.residency.DORMANCY_GRACE_SECONDS+.1).timeout
	var residency: Dictionary=world.passage_region.residency.snapshot()
	_require(residency.state=="DORMANT","actual departure retires shop geometry")
	_require(counter.mechanism_snapshot()==before,"dormant stock retains original physical save pose")
	_require(bottle.freeze,"dormant stock is suspended before floor retirement")
	if failures.is_empty():await _save_reload(before)
	var directory:=OS.get_environment("SHOT_DIR")
	var file:=FileAccess.open(directory.path_join("stock_checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","checks":interaction_checks,"residency":residency,"stock":before},"  "))


func _paid_gasket_case(door_z: float) -> void:
	var report := {"evidence_class":"INERT", "station":PAID_STATION, "item":PAID_GASKET}
	var original_path: String = RealityState.save_path
	var original_persistence: bool = RealityState.persistence_enabled
	var path := "user://v2_paid_gasket_%d.json" % Time.get_ticks_usec()
	var appdata := OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	var expected := OS.get_environment("V2_PAID_GASKET_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path()
	if _require(not appdata.is_empty() and appdata == expected and user_dir.begins_with(appdata.trim_suffix("/") + "/")
			and not FileAccess.file_exists(path), "paid gasket disk case uses an explicitly matched fresh isolated profile"):
		RealityState.save_path = path
		RealityState.persistence_enabled = true
		await _paid_gasket_route(door_z, path, report)
		RealityState.flush_background_saves()
		RealityState.persistence_enabled = original_persistence
		RealityState.save_path = original_path
	report["checks"] = interaction_checks
	report["failures"] = failures
	var file := FileAccess.open(OS.get_environment("SHOT_DIR").path_join("paid_gasket_checks.json"), FileAccess.WRITE)
	_require(file != null, "paid gasket report opens")
	if file != null: file.store_string(JSON.stringify(report, "\t", true, true))


func _paid_gasket_route(door_z: float, path: String, report: Dictionary) -> void:
	var washer: Node3D = counter.pickups[PAID_GASKET]
	var terminal: Node3D = counter.terminals[PAID_GASKET]
	var economy: Node = world.get_node("CaretakerEconomy")
	var inventory: Node = world.maintenance_inventory
	var using_case := OS.get_environment("V2_PAID_GASKET_VALISE") == "1"
	var cash: int = int(economy.book().cash)
	if not world.service_set_carrier.radio_is_powered(): await _radio_key()
	await get_tree().create_timer(.6).timeout
	if not _require(await hands._stroke(terminal, .04), "actual hardware sale stroke reaches the paid washer terminal"): return
	if not _require(inventory.has_item(PAID_GASKET) and not inventory.is_consumed(PAID_GASKET)
			and int(economy.book().cash) == cash - 10, "washer purchase grants its one original item and charges exactly 10c"): return
	if not await _paid_take(washer): return
	if using_case and not await _paid_pack_in_case(washer, path): return
	for x: float in [9.7, 10.8, 14.0]:
		if x == 14. and not door.is_ready_for_passage():
			if not using_case and not await _paid_park(washer): return
			if not await _open_shop(): return
			if not using_case and not await _paid_take(washer): return
		if not await _walk_world(Vector3(x, .01, door_z)): return
		if not _require(_paid_in_transit(washer, using_case), "same paid washer crosses the hardware threshold"): return
	for z: float in [32., 27.5, 20., 17.3]:
		if not await _walk_world(Vector3(14., .01, z)): return
	for point: Vector3 in [Vector3(14,0,15), Vector3(14,-.1,13.6), Vector3(14,-.1,8),
			Vector3(14,0,4.2), Vector3(14,0,3), Vector3(0,0,3)]:
		if not await _walk_world(point): return
	if not await _walk(Vector3(0,0,-13.15)): return
	if not using_case and not await _paid_park(washer): return
	if not await _open_front_entrance(): return
	if not using_case and not await _paid_take(washer): return
	for point: Vector3 in [Vector3(0,0,-10.2), Vector3(0,0,-8.5), Vector3(1.925,0,-6.5),
			Vector3(1.925,0,-3.5), Vector3(1.925,1.6,1.3), Vector3(3.975,1.6,1.3),
			Vector3(3.975,3.2,-2.4), Vector3(3.65,3.2,-3.), Vector3(4.5,3.2,-2.95)]:
		if not await _walk(point): return
		if not _require(_paid_in_transit(washer, using_case) and player.is_on_floor() and not player.crouched
				and is_equal_approx(player._capsule.height, 1.524) and is_equal_approx(player._capsule.radius, .33),
				"standing capsule and same paid washer reach " + str(point)): return
	if not using_case and not await _paid_park(washer): return
	var actor := _paid_station()
	if not _require(actor != null and actor.has_method("preview_purchased_gasket_fit"), "installed F02 replacement receiver is present"): return
	var driver := preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new()
	driver.player = player
	add_child(driver)
	if not _require(await driver.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)), 1.78, actor),
			"actual primary and motion open the cabinet"): return
	await hands.aim(actor._tag.to_global(Vector3(0,0,.0035)))
	hands.click()
	hands.key(KEY_SPACE)
	if not _require(player.inspecting() and player.inspect_owner == actor, "actual tag enters cabinet inspection"): return
	if not _require(await hands.inspect_operate(driver, actor._joint_nut, actor._coupling.to_global(Vector3(0,-.012,.032)),
			actor._maximum("joint")), "actual native union fully unthreads"): return
	if not _require(await hands.carry_union(actor, actor._loose_union.resting()), "actual union rests at its exposed loose stop"): return
	hands.key(KEY_SPACE)
	driver.queue_free()
	if not _require(actor.door_open and actor._loose_union.active and not actor.coupling_made_up and not actor.gasket_seated
			and absf(actor._wheel_angle) <= .0001 and actor._gasket_body.position.is_equal_approx(actor._gasket_body.home_position),
			"receiver is vacant with supply shut and native washer still parked"): return
	if using_case:
		await hands.aim(player.camera.global_position - actor.global_basis.z)
		if not await _paid_return_from_case(washer, path): return
	elif not await _paid_take(washer): return
	# Existing static stock inspection enables free XYZ without changing the body pose.
	await hands.aim(player.camera.global_position - actor.global_basis.z)
	hands.key(KEY_SPACE)
	if not _require(player.inspecting() and player.inspect_owner == counter, "Space transfers the paid washer to its existing static stock view"): return
	for frame in 125: await get_tree().physics_frame
	if not await _paid_take(washer): return
	var seat: Vector3 = actor.to_global(actor._gasket_body.seat_position())
	var draw := washer.get_node("Gasket") as MeshInstance3D
	if not _require(absf(draw.mesh.get_aabb().position.y - .003) < .000001, "loaded paid washer has the expected +3mm sealing face"): return
	var face := func() -> Vector3: return draw.to_global(Vector3(0,.003,0))
	var off_seat_distance: float = face.call().distance_to(seat)
	if not _require(off_seat_distance > .025, "negative starts beyond the real receiving radius"): return
	hands.click()
	await get_tree().physics_frame
	if not _require(not player._grab.active() and inventory.has_item(PAID_GASKET) and not inventory.is_consumed(PAID_GASKET)
			and not actor.gasket_seated and not counter.mechanism_snapshot()[PAID_GASKET].has("fitted_station")
			and int(economy.book().cash) == cash - 10, "explicit primary release off seat transfers no custody and debits no extra cash"): return
	if not await _paid_take(washer): return
	for goal: Vector3 in [seat + actor.global_basis * Vector3(0,.065,.13), seat + actor.global_basis.y * .006]:
		if not await _paid_move_face(washer, face, goal): return
	var distance: float = face.call().distance_to(seat)
	var alignment := draw.global_basis.y.normalized().dot(actor.global_basis.y.normalized())
	report["contact"] = {"distance_m":distance, "up_dot":alignment, "off_seat_distance_m":off_seat_distance,
		"face_world":str(face.call()), "seat_world":str(seat)}
	var fit: Dictionary = actor.preview_purchased_gasket_fit(washer)
	if fit.is_empty() and distance <= .025 and alignment >= .99:
		report["clearance_probe"] = _paid_fit_clearance_probe(actor, washer, face.call(), seat)
	if not _require(distance <= .025 and alignment >= .99 and not fit.is_empty(),
			"actual paid sealing face has native snap reach, alignment and real swept clearance"): return
	var pre_hash: String = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var seen_before: bool = actor.gasket_seen
	hands.click()
	# Inspect the bytes committed by the release before any explicit save or rebuild.
	var raw := FileAccess.get_file_as_bytes(path)
	var committed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	var new_hash: String = FileAccess.get_sha256(path)
	if not _require(not raw.is_empty() and new_hash != pre_hash and committed is Dictionary,
			"explicit primary release itself commits the isolated disk document"): return
	var installed: Dictionary = actor.mechanism_snapshot().get("replacement_gasket", {})
	var stock: Dictionary = counter.mechanism_snapshot()[PAID_GASKET]
	var spent: Dictionary = committed.get("maintenance_items", {}).get(PAID_GASKET, {})
	var records: Dictionary = committed.get("v2_household_controls", {}).get("records", {})
	var disk_installed: Dictionary = records.get(PAID_STATION, {}).get("value", {}).get("replacement_gasket", {})
	var disk_stock: Dictionary = records.get(str(counter.name), {}).get("value", {}).get(PAID_GASKET, {})
	if not _require(actor.gasket_seated and actor.gasket_seen == seen_before and not actor.coupling_made_up and not actor.tag_signed
			and installed.get("item_id") == PAID_GASKET and installed.get("seated") == true and installed.get("dressed") == false
			and stock.get("fitted_station") == PAID_STATION and spent.get("consumed") == true
			and inventory.is_consumed(PAID_GASKET) and not inventory.has_item(PAID_GASKET)
			and int(economy.book().cash) == cash - 10, "one paid fitted seat owns the spent item without inventing inspection, tightening, dressing or rebilling"): return
	report["disk_sha256"] = new_hash
	report["spent"] = spent
	report["installed"] = installed
	report["counter"] = stock
	if not _require(_paid_same_replacement(disk_installed, installed)
			and disk_stock.get("fitted_station") == PAID_STATION
			and hands._same_saved_stock({PAID_GASKET:disk_stock}, {PAID_GASKET:stock})
			and committed.get("caretaker_economy", {}).get("cash") == cash - 10,
			"same raw disk document contains paired household records, spent custody and exact cash"): return
	hands.key(KEY_SPACE)
	if not _require(not player.inspecting() and not player._grab.active() and washer.freeze and not washer.visible
			and washer.collision_layer == 0 and washer.collision_mask == 0, "normal Space exit cannot revive the retired washer body"): return
	world.shutdown_for_tests()
	world.free()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if not _require(not world.startup_failed and RealityState.load_status().status == "loaded", "actual isolated disk world reconstructs"): return
	player = world.player
	hands.player = player
	player.camera.make_current()
	counter = world.fire_maintenance_counter
	var restored := _paid_station()
	var restored_washer: Node3D = counter.pickups[PAID_GASKET]
	var restored_stock: Dictionary = counter.mechanism_snapshot()[PAID_GASKET]
	_require(restored != null and restored.valid_mechanism(restored.mechanism_snapshot())
		and _paid_same_replacement(restored.mechanism_snapshot().get("replacement_gasket", {}), disk_installed)
		and restored_stock.get("fitted_station") == PAID_STATION
		and hands._same_saved_stock({PAID_GASKET:restored_stock}, {PAID_GASKET:disk_stock})
		and restored_washer.freeze and not restored_washer.visible
		and restored_washer.collision_layer == 0 and restored_washer.collision_mask == 0
		and RealityState.data.maintenance_items.get(PAID_GASKET) == spent
		and world.maintenance_inventory.is_consumed(PAID_GASKET)
		and not world.shop_service.can_purchase_supply(PAID_GASKET, "hardware_paint")
		and int(world.get_node("CaretakerEconomy").book().cash) == cash - 10,
		"disk rebuild restores fitted pose, spent row and exact cash without repurchase or counter duplication")


func _paid_same_replacement(actual: Dictionary, wanted: Dictionary) -> bool:
	for field: String in ["item_id", "seated", "dressed"]:
		if not actual.has(field) or actual.get(field) != wanted.get(field): return false
	var left: Dictionary = actual.get("pose", {})
	var right: Dictionary = wanted.get("pose", {})
	var gasket := preload("res://scripts/props/fire_line_gasket.gd")
	if not gasket.valid(left) or not gasket.valid(right): return false
	var a := Vector3(left.position[0], left.position[1], left.position[2])
	var b := Vector3(right.position[0], right.position[1], right.position[2])
	var qa := Basis(Quaternion(left.rotation[0], left.rotation[1], left.rotation[2], left.rotation[3]))
	var qb := Basis(Quaternion(right.rotation[0], right.rotation[1], right.rotation[2], right.rotation[3]))
	return a.distance_to(b) < .00001 and qa.is_equal_approx(qb)


func _paid_in_transit(washer: Node3D, using_case: bool) -> bool:
	if not using_case:
		return player.held_stock_body() == washer
	return CarriedCase.washer_is_packed(RealityState.data) and player.held_stock_body() == null \
		and not washer.visible and washer.collision_layer == 0 and washer.collision_mask == 0


func _paid_case_tab() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.physical_keycode = KEY_TAB
	key.pressed = true
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	key = key.duplicate()
	key.pressed = false
	get_viewport().push_input(key, true)
	await get_tree().create_timer(.65).timeout


func _paid_pack_in_case(washer: Node3D, path: String) -> bool:
	if not _require(get_viewport() is SubViewport, "valise uses the detached actual input viewport"): return false
	await _paid_case_tab()
	var view: Node = world.carried_case_view
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _require(view.opened and view.settled and view._stacks.has(PAID_GASKET)
			and _paid_in_transit(washer, true) and saved is Dictionary
			and CarriedCase.washer_is_packed(saved),
			"Tab packs the same paid washer into one valise cell and saves its custody"): return false
	await _picture("paid_washer_in_valise")
	await _paid_case_tab()
	return _require(not view.opened and not player.call_locked and _paid_in_transit(washer, true),
		"closing the valise keeps the washer packed and frees normal movement")


func _paid_return_from_case(washer: Node3D, path: String) -> bool:
	await _paid_case_tab()
	var view: Node = world.carried_case_view
	if not _require(view.opened and view.settled and view._stacks.has(PAID_GASKET),
			"the same paid washer remains on its saved square after the walk"): return false
	var place := CarriedCase.place_of(PAID_GASKET)
	var start: Vector3 = view._centre(float(place.x), float(place.y), Vector2i.ONE)
	var edge: Vector3 = view._centre(4.5, float(CarriedCase.grid().y) + .8, Vector2i.ONE)
	for at: Vector3 in [start, edge]:
		var pixel: Vector2 = view._camera.unproject_position(at)
		var click := InputEventMouseButton.new()
		click.position = pixel
		click.global_position = pixel
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		get_viewport().push_input(click, true)
		await get_tree().process_frame
		click = click.duplicate()
		click.pressed = false
		get_viewport().push_input(click, true)
		await get_tree().process_frame
	await get_tree().create_timer(.5).timeout
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _require(not view.opened and player.held_stock_body() == washer and washer.visible
		and washer.collision_layer != 0 and not CarriedCase.washer_is_packed(RealityState.data)
		and saved is Dictionary and not CarriedCase.washer_is_packed(saved),
		"actual valise click and carry out returns the same paid physical washer and saves world custody")


func _paid_fit_clearance_probe(actor: Node3D, washer: Node3D, face: Vector3, seat: Vector3) -> Dictionary:
	var basis: Basis = washer.global_basis.orthonormalized()
	var receiver: Basis = actor.global_basis.orthonormalized()
	var local_face := washer.to_local(face)
	var steps := maxi(1, ceili(basis.get_rotation_quaternion().angle_to(receiver.get_rotation_quaternion()) / .025))
	var space := washer.get_world_3d().direct_space_state
	var aligned: Transform3D = washer.global_transform
	for index in range(1, steps + 1):
		aligned.basis = basis.slerp(receiver, float(index) / steps)
		aligned.origin = face - aligned.basis * local_face
		for solid: CollisionShape3D in washer._solids:
			var query: PhysicsShapeQueryParameters3D = washer._shape_query(solid, aligned)
			query.margin = .00001
			var hits := space.intersect_shape(query, 1)
			if not hits.is_empty():
				return _paid_fit_probe_hit("rotate", hits[0], {"step":index, "steps":steps})
	var raised := Transform3D(receiver, seat - receiver * local_face + receiver.y * .0001)
	for solid: CollisionShape3D in washer._solids:
		var query: PhysicsShapeQueryParameters3D = washer._shape_query(solid, aligned)
		var motion := raised.origin - aligned.origin
		var rest := space.get_rest_info(query)
		if not rest.is_empty() and motion.dot(rest.normal) < -.0000001:
			return _paid_fit_probe_hit("start_rest", rest, {"normal":str(rest.normal)})
		query.motion = motion
		var fraction := space.cast_motion(query)
		if fraction.size() == 2 and fraction[0] < 1.:
			query.motion = Vector3.ZERO
			query.transform = query.transform.translated(motion * fraction[1])
			var hits := space.intersect_shape(query, 1)
			return _paid_fit_probe_hit("translate", hits[0] if not hits.is_empty() else {},
				{"fractions":str(fraction), "motion":str(motion)})
		query.motion = Vector3.ZERO
		query.transform = raised * solid.transform
		query.margin = .00001
		var hits := space.intersect_shape(query, 1)
		if not hits.is_empty():
			return _paid_fit_probe_hit("raised_end", hits[0], {})
	return {"stage":"no_geometry_failure", "door":actor.door_open, "coupled":actor.coupling_made_up,
		"seated":actor.gasket_seated, "wheel":actor._wheel_angle, "hand":actor._hand}


func _paid_fit_probe_hit(stage: String, hit: Dictionary, detail: Dictionary) -> Dictionary:
	var collider := instance_from_id(int(hit.get("collider_id", 0))) as Node
	detail.merge({"stage":stage, "path":str(collider.get_path()) if collider != null else "",
		"rid":str(hit.get("rid", RID())), "shape":hit.get("shape", -1)})
	return detail


func _paid_station() -> Node3D:
	var stock: RefCounted = world.adapter.root.get_meta("v2_native_fire_service")
	return stock.stations[PAID_STATION].get_ref()


func _paid_take(washer: Node3D) -> bool:
	var point := Vector3.INF
	if player.inspecting():
		point = await hands.pick_washer(washer)
	else:
		for sample in 16:
			var angle := TAU * float(sample) / 16.
			await hands.aim(washer.to_global(Vector3(.020 * cos(angle),.004,.020 * sin(angle))))
			var target: Dictionary = player._grab.find_target()
			if target.get("part") == washer:
				point = target.hit_position
				break
	if not _require(point.is_finite(), "actual native annulus ray reaches the paid washer"): return false
	hands.click()
	if not _require(player._grab.active() and player._grab.target.part == washer and washer._held, "primary grabs the exact paid body"): return false
	if not player.inspecting():
		for frame in 90:
			if _in_hand(washer): break
			await get_tree().physics_frame
		print("PAID WASHER WITHDRAWAL ", JSON.stringify({
			"lifted":washer._pickup_lifted, "extracted":washer._pickup_extracted,
			"lift_goal":str(washer._pickup_lift_goal), "exit":str(washer._pickup_exit),
			"position":str(washer.global_position), "contact":str(washer._last_motion),
			"held":player.held_stock_body()==washer, "settled":_in_hand(washer)}))
		if not _in_hand(washer) and washer._last_motion.get("unresolved_native_impact", false):
			_observe_paid_washer_impact(washer)
		return _require(_in_hand(washer), "paid washer settles into the real FPS hold")
	return true


func _observe_paid_washer_impact(washer: Node3D) -> void:
	var motion: Vector3 = washer._last_motion.motion
	var unsafe: float = washer._last_motion.unsafe
	var pose: Transform3D = washer.global_transform
	var space := washer.get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = []
	for solid: CollisionShape3D in washer._solids:
		for fraction: float in [0., unsafe, 1., 1.5, 2., 3.]:
			var probe: Transform3D = pose.translated(motion * fraction)
			var query: PhysicsShapeQueryParameters3D = washer._shape_query(solid, probe)
			for hit: Dictionary in space.intersect_shape(query, 8):
				var collider := hit.get("collider") as Node
				overlaps.append({"solid":str(solid.name), "fraction":fraction,
					"path":str(collider.get_path()) if collider != null else "",
					"rid":str(hit.rid), "shape":hit.shape})
	var support: Array[Dictionary] = []
	for axis: Vector3 in [Vector3.UP, Vector3.DOWN]:
		var point := pose.origin
		var ray := PhysicsRayQueryParameters3D.create(point + axis * .03, point - axis * .03,
			washer.collision_mask, washer._query_exclusions())
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var collider := hit.get("collider") as Node
			support.append({"axis":str(axis), "position":str(hit.position), "normal":str(hit.normal),
				"path":str(collider.get_path()) if collider != null else "", "rid":str(hit.rid), "shape":hit.shape})
	print("PAID WASHER IMPACT WITNESS ", JSON.stringify({"pose":var_to_str(pose),
		"motion":str(motion), "unsafe":unsafe, "overlaps":overlaps, "support":support}))


func _paid_park(washer: Node3D) -> bool:
	if not _require(player.held_stock_body() == washer, "explicit floor release starts with the paid washer in hand"): return false
	hands.click()
	for frame in 240:
		if washer.sleeping: break
		await get_tree().physics_frame
	return _require(not player._grab.active() and washer.sleeping and not washer.freeze, "paid washer parks on original floor support while the hand opens the next fitting")


func _paid_move_face(washer: Node3D, face: Callable, goal: Vector3) -> bool:
	# Same projection and wheel delivery as the original fire hand bench,
	# with release kept separate so only the verified explicit click can commit.
	var samples: Array[Dictionary] = []
	for step in 120:
		if not player._grab.active() or player._grab.target.part != washer: break
		var delta: Vector3 = goal - face.call()
		if delta.length() < .003: return true
		var point: Vector3 = washer.to_global(player._grab.contact)
		var depth: float = delta.dot((point - player.camera.global_position).normalized())
		if absf(depth) > .0001:
			var wheel := InputEventMouseButton.new()
			wheel.pressed = true
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if depth > 0. else MOUSE_BUTTON_WHEEL_UP
			wheel.factor = minf(.025, absf(depth)) / .025
			player._unhandled_input(wheel)
		point = washer.to_global(player._grab.contact)
		delta = goal - face.call()
		var motion := InputEventMouseMotion.new()
		motion.relative = (player.camera.unproject_position(point + delta) - player.camera.unproject_position(point)).limit_length(30.)
		player._unhandled_input(motion)
		await get_tree().physics_frame
		if step < 3 or step % 15 == 14:
			samples.append({"step":step, "face":str(face.call()), "wheel_depth":depth,
				"relative":str(motion.relative), "contact":str(washer._last_motion)})
	print("PAID WASHER APPROACH FAILURE ", JSON.stringify({
		"goal":str(goal), "face":str(face.call()), "camera":var_to_str(player.camera.global_transform),
		"pose":var_to_str(washer.global_transform), "held":player._grab.active(), "samples":samples}))
	if washer._last_motion.get("unresolved_native_impact", false):
		_observe_paid_washer_impact(washer)
	return _require(false, "actual paid washer cannot reach the approach point through existing motion and clearance")


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

func _move_front_entrance(identity: String,want_open: bool) -> bool:
	var anchor:=world.adapter.resolve(identity) as Node3D
	var leaf:=anchor.get_node_or_null(identity+"_Leaf") as DoorProp if anchor!=null else null
	if not _require(leaf!=null,"production front entrance leaf exists: "+identity):return false
	var goal: float=leaf.motion_target_angle(want_open)
	if absf(leaf._body.rotation.y-goal)<.001:return true
	player.set_mouse_released(false)
	await hands.aim(leaf._body.to_global(Vector3(leaf.width/3.,1.1,leaf._hinge_offset)))
	hands.click()
	if not _require(player._grab.active() and player._grab.target.owner==leaf,"primary click identifies entrance leaf: "+identity):return false
	var moved: bool=await hands._gesture_to(goal)
	if player._grab.active():hands.click()
	return _require(moved and absf(leaf._body.rotation.y-goal)<.001,"fixed mouse travel reaches entrance stop: "+identity)

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
