extends "res://tests/v2_fire_maintenance_hand_bench.gd"
## INERT nearby real input for paid bottle dressing through the existing owners.
const BaseHand := preload("res://tests/v2_fire_hand_bench.gd")
const Precision := preload("res://scripts/building/v2_contact_precision.gd")
const GestureHand := preload("res://tests/fixed_gesture_patrol_hand.gd")
const ToolID := "fire_hose_rubber_protectant"
const StationID := "F02_FIRE_LINE_STAIR"
const TipLocal := Vector3(0, .166, 0)
const CounterSite := Vector3(1.75, 1.12, .08)
const CabinetStance := Vector3(.11, 0, .96)

class NearbyAdapter extends BaseHand.FixtureAdapter:
	func mount_consumer(identity: String, actor: Node3D) -> bool:
		if not super.mount_consumer(identity, actor):
			return false
		if identity == "F02_FIRE_LINE_STAIR":
			actor.position = Vector3(0, 1.2, 0)
		return true

var precision := Precision.new()
var dressing_report: Dictionary = {"evidence_class": "INERT", "walk": [], "dressing_events": []}

func _exit_tree() -> void:
	precision.release()

func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if OS.get_environment("ORISON_HOSE_PROTECTANT_DRESSING") != "1" or output.is_empty() \
			or DirAccess.make_dir_recursive_absolute(output) != OK \
			or FileAccess.file_exists(output.path_join("protectant_dressing.json")):
		push_error("Protectant witness requires opt-in and a fresh SHOT_DIR")
		get_tree().quit(2)
		return
	var ok: bool = await _exercise_dressing(output)
	Input.action_release("move_forward")
	if is_instance_valid(player):
		player.cancel_manipulation()
	dressing_report.checks = observations
	dressing_report.failures = failures
	dressing_report.completed = ok and failures.is_empty()
	var file := FileAccess.open(output.path_join("protectant_dressing.json"), FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(dressing_report, "\t")):
		push_error("Protectant witness report write failed")
		get_tree().quit(2)
		return
	file.close()
	print("HOSE PROTECTANT: ", "PASS" if dressing_report.completed else "FAIL")
	get_tree().quit(0 if dressing_report.completed else 1)

func _exercise_dressing(output: String) -> bool:
	var viewport := get_viewport() as SubViewport
	if not check(viewport != null and viewport.size == Vector2i(3440, 1440), "detached native viewport"):
		return false
	if not check(precision.bind(get_world_3d()), "original V2 contact precision binds"):
		return false
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var adapter := NearbyAdapter.new()
	adapter.root = Node3D.new()
	add_child(adapter.root)
	var reserve := MeshInstance3D.new()
	reserve.name = "FIRE_SERVICE_RISER"
	adapter.root.add_child(reserve)
	var native := Native.new()
	if not check(native.mount(adapter, {"levels": [{"y": 0.0}]}), "native fire service mounts"):
		dressing_report.native_errors = native.errors
		return false
	var cabinet: Node3D = native.stations[StationID].get_ref()
	for id: String in native.stations.keys():
		if id != StationID:
			native.stations[id].get_ref().free()
			native.stations.erase(id)
	if not check(native.mount_hose_deployment(), "same F02 cabinet and hose owners bind"):
		return false

	var orders := WorkOrders.new()
	orders.setup(null)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	var items := MaintenanceInventory.new()
	items.setup()
	add_child(items)
	var economy := preload("res://scripts/game/caretaker_economy.gd").new()
	add_child(economy)
	if not check(economy.setup(orders), "real economy owner binds"):
		return false
	var merchant := preload("res://scripts/game/v2_maintenance_shop_service.gd").new()
	add_child(merchant)
	merchant.setup(items, orders)
	var clearing := preload("res://scripts/game/radio_clearing_network.gd").new()
	if not check(clearing.configure(economy, func(): return radio_on, func(id: String): return id == "hardware_paint"),
			"real radio clearing binds fixture merchant availability"):
		return false
	merchant.clearing = clearing
	var counter := Counter.new()
	counter.name = "FireMaintenanceCounter"
	counter.transform = Transform3D(Basis(Vector3.UP, PI), CounterSite)
	add_child(counter)
	if not check(counter.configure(merchant), "native sale terminal and physical bottle mount"):
		return false
	counter.fire_stations.append(weakref(cabinet))
	_box("StandingFloor", Vector3(1, -.10, .6), Vector3(6, .20, 5))
	_box("CounterWorktop", CounterSite - Vector3.UP * .05, Vector3(1.50, .10, .65))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.5
	add_child(light)

	player = PlayerController.new()
	player.position = CabinetStance
	add_child(player)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	viewport.notify_mouse_entered()
	var hand := GestureHand.new()
	hand.player = player
	add_child(hand)
	for tick in 8:
		await get_tree().physics_frame
	if not check(player.is_on_floor() and player.collision_mask != 0 and not player._shape.disabled,
			"actual capsule settles on physical support"):
		return false
	if not await _expose_washer(cabinet, hand):
		return false
	if not await _walk_local(Vector3(CounterSite.x, 0, CounterSite.z + .85)):
		return false

	var bottle: Node3D = counter.pickups[ToolID]
	var terminal: Node3D = counter.terminals[ToolID]
	var cash_before := int(economy.book().cash)
	var jobs_before: Dictionary = orders.serialize_jobs()
	var purchase_count := int(economy.book().get("purchases", {}).size())
	if not check(not items.has_item(ToolID) and await _stroke(terminal, .04),
			"actual primary pull settles the protectant sale"):
		return false
	var receipt := clearing.receipt("maintenance_supply:" + ToolID)
	if not check(items.has_item(ToolID) and int(economy.book().cash) == cash_before - 25
			and economy.book().purchases.size() == purchase_count + 1
			and receipt == {"merchant": "hardware_paint", "item": ToolID, "cents": 25},
			"exact paid bottle uses one 25-cent debit"):
		return false
	var payment_after: Dictionary = economy.book().duplicate(true)
	var custody_after: Dictionary = items.serialize()
	if not await _take_and_open_bottle(counter, bottle):
		return false
	if not await _walk_local(CabinetStance):
		return false
	if not check(player.held_stock_body() == bottle and is_equal_approx(bottle.cap_turn, bottle.CAP_TRAVEL),
			"same paid open bottle is physically carried to native F02"):
		return false

	var draw: MeshInstance3D = cabinet._spare_gasket
	var bounds := draw.mesh.get_aabb()
	var eye_local := draw.to_local(player.camera.global_position)
	var radial := Vector2(eye_local.x, eye_local.z).normalized()
	var outer := maxf(absf(bounds.position.x), absf(bounds.end.x))
	var inner: float = cabinet._joint_stock.data.dimensions.bore_radius_m
	var radius := (inner + outer) * .5
	var annulus := draw.to_global(Vector3(radial.x * radius, bounds.end.y + .001, radial.y * radius))
	var approach := annulus + Vector3.UP * .055
	dressing_report.receiver = {"path": str(cabinet._gasket_body.get_path()), "rid": str(cabinet._gasket_body.get_rid()),
		"instance_id": cabinet._gasket_body.get_instance_id(), "draw": str(draw.get_path()),
		"target": var_to_str(annulus), "approach": var_to_str(approach), "bottle_id": bottle.get_instance_id()}
	await aim(annulus)
	key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner == counter, "bottle returns to its real static grip owner"):
		return false
	for tick in 125:
		await get_tree().physics_frame
	if not await _turn_tip_down(bottle):
		return false
	var saved_before: Dictionary = cabinet.mechanism_snapshot()
	dressing_report.before = saved_before
	var bare_finish := draw.material_override as StandardMaterial3D
	if not check(bare_finish != null and cabinet.valid_mechanism(saved_before) and not cabinet.rubber_dressed,
			"exposed cabinet has a valid undressed payload"):
		return false
	var tip_offset: Vector3 = bottle.global_basis * TipLocal
	var bottle_pick := Vector3(0, .075, -.032)
	var outside_goal := counter.to_local(approach - tip_offset)
	if not check(await carry_path(counter, bottle, bottle.to_global(bottle_pick), [outside_goal], .002),
			"actual bottle grip moves tip to off-annulus approach"):
		return false
	dressing_report.off_annulus_tip = var_to_str(bottle.to_global(TipLocal))
	if not check(bottle.to_global(TipLocal).distance_to(approach) < .003 and not cabinet.rubber_dressed,
			"same paid open bottle leaves off-annulus rubber unchanged"):
		return false
	var observe_dressing := func() -> void:
		if cabinet.rubber_dressed:
			dressing_report.dressing_events.append({"tip": var_to_str(bottle.to_global(TipLocal)),
				"tip_receiver_local": var_to_str(draw.to_local(bottle.to_global(TipLocal))),
				"frame": Engine.get_physics_frames(), "held_body": bottle._held})
	cabinet.manipulation_changed.connect(observe_dressing)
	var contact_goal := counter.to_local(annulus - tip_offset)
	var dressed := func() -> bool: return cabinet.rubber_dressed
	var contact_reached := await carry_path(counter, bottle, bottle.to_global(bottle_pick), [contact_goal], .0002, dressed)
	cabinet.manipulation_changed.disconnect(observe_dressing)
	dressing_report.final_tip = var_to_str(bottle.to_global(TipLocal))
	dressing_report.final_tip_error_m = bottle.to_global(TipLocal).distance_to(annulus)
	dressing_report.stock_contact = var_to_str(bottle._last_motion)
	if not check(contact_reached, "actual primary, mouse and depth reach the native annulus"):
		return false
	if not check(cabinet.rubber_dressed and dressing_report.dressing_events.size() == 1
			and dressing_report.dressing_events[0].held_body, "the real held cap-tip dresses the original washer once"):
		return false
	var finish := draw.material_override as StandardMaterial3D
	if not check(finish != null and finish != bare_finish and is_equal_approx(finish.roughness, bare_finish.roughness * .85),
			"only receiver gets the existing dressed finish"):
		return false
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if not check(image.get_size() == Vector2i(3440, 1440) and image.save_png(output.path_join("dressed_annulus.png")) == OK,
			"native dressed annulus frame saved"):
		return false
	key(KEY_SPACE)
	if not check(not player.inspecting() and player.held_stock_body() == bottle, "same bottle returns through Space"):
		return false
	click()
	if not check(not player._grab.active() and not bottle._held, "normal next-click releases paid stock"):
		return false
	var saved_after: Dictionary = cabinet.mechanism_snapshot()
	var expected := saved_before.duplicate(true)
	expected.rubber_dressed = true
	dressing_report.after = saved_after
	dressing_report.settlement = {"cash_before": cash_before, "cash_after": economy.book().cash, "receipt": receipt}
	if not check(saved_after == expected and items.serialize() == custody_after and economy.book() == payment_after
			and orders.serialize_jobs() == jobs_before, "dressing changes only its durable fact and retains cash, stock and jobs"):
		return false
	return _check_restore(cabinet, counter, saved_before, saved_after)

func _expose_washer(cabinet: Node3D, hand: Node) -> bool:
	if not check(await hand.operate(cabinet._door_pivot.to_global(Vector3(-.4, .1, .015)), 1.78, cabinet),
			"actual door grip opens native cabinet"):
		return false
	await aim(cabinet._tag.to_global(Vector3(0, 0, .0035)))
	click()
	key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner == cabinet, "actual tag enters original cabinet view"):
		return false
	if not check(await inspect_operate(hand, cabinet._joint_nut, cabinet._coupling.to_global(Vector3(0, -.012, .032)),
			cabinet._maximum("joint")), "actual screw grip opens union"):
		return false
	if not check(await carry_union(cabinet, cabinet._loose_union.resting()), "actual depth and mouse clear union to authored rest"):
		return false
	key(KEY_ESCAPE)
	return check(not player.inspecting() and cabinet.door_open and not cabinet.coupling_made_up
			and absf(cabinet._wheel_angle) < .0001, "washer is exposed with supply shut")

func _take_and_open_bottle(counter: Node3D, bottle: Node3D) -> bool:
	await aim(bottle.to_global(Vector3(0, .08, -.034)))
	click()
	if not check(player.held_stock_body() == bottle, "actual ray acquires paid physical bottle"):
		return false
	for tick in 90:
		await get_tree().physics_frame
	key(KEY_SPACE)
	if not check(player.inspecting() and player.inspect_owner == counter, "actual Space supports paid bottle"):
		return false
	for tick in 125:
		await get_tree().physics_frame
	if not check(await acquire_surface(bottle.cap, bottle.cap.to_global(Vector3(0, .006, -.016))),
			"detached pointer resolves captive cap"):
		return false
	click()
	if not check(player._grab.active() and player._grab.target.part == bottle.cap, "actual primary grabs cap"):
		return false
	var reached := await _gesture_to(bottle.CAP_TRAVEL)
	click()
	var stock: Dictionary = counter.mechanism_snapshot()
	if not check(reached and is_equal_approx(bottle.cap_turn, bottle.CAP_TRAVEL)
			and counter.valid_mechanism(stock) and not stock[ToolID].parked and not stock[ToolID].stock.sleeping,
			"actual cap stop and original transient inspection save checks"):
		return false
	key(KEY_SPACE)
	return check(not player.inspecting() and player.held_stock_body() == bottle, "same open bottle returns through Space")

func _turn_tip_down(bottle: Node3D) -> bool:
	if not check(await acquire_surface(bottle, bottle.to_global(Vector3(0, .075, -.032))), "real bottle body ray before tilt"):
		return false
	click()
	if not check(player._grab.active() and player._grab.target.part == bottle, "actual bottle body grip"):
		return false
	var rotate := InputEventMouseButton.new()
	rotate.button_index = MOUSE_BUTTON_RIGHT
	rotate.pressed = true
	player._unhandled_input(rotate)
	for tick in 36:
		if not player._grab.active() or bottle.global_basis.y.dot(Vector3.DOWN) > .94:
			break
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, 20)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	rotate.pressed = false
	player._unhandled_input(rotate)
	var reached: bool = player._grab.active() and bottle.global_basis.y.dot(Vector3.DOWN) > .94
	if player._grab.active():
		click()
	return check(reached, "actual right drag turns bottle tip downward")

func _check_restore(cabinet: Node3D, counter: Node3D, before: Dictionary, after: Dictionary) -> bool:
	var stock: Dictionary = counter.mechanism_snapshot()
	# Use the production save writer's full precision at strict mechanical stops.
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(after, "\t", true, true))
	var stock_roundtrip: Dictionary = JSON.parse_string(JSON.stringify(stock, "\t", true, true))
	var cabinet_valid: bool = cabinet.valid_mechanism(roundtrip)
	var stock_valid: bool = counter.valid_mechanism(stock_roundtrip)
	dressing_report.snapshot_validation = {
		"live_cabinet": cabinet.valid_mechanism(after),
		"live_stock": counter.valid_mechanism(stock),
		"saved_cabinet": cabinet_valid,
		"saved_stock": stock_valid,
	}
	if not check(cabinet_valid and stock_valid,
			"original mechanism validators accept dressed and paid-stock JSON at save precision"):
		return false
	var legacy := before.duplicate(true)
	legacy.erase("rubber_dressed")
	if not check(cabinet.valid_mechanism(legacy), "older cabinet snapshot remains valid"):
		return false
	cabinet.restore_mechanism(legacy)
	if not check(not cabinet.rubber_dressed, "older payload defaults to bare rubber"):
		return false
	cabinet.restore_mechanism(roundtrip)
	counter.restore_mechanism(stock_roundtrip)
	return check(cabinet.rubber_dressed and cabinet.valid_mechanism(cabinet.mechanism_snapshot())
			and _same_saved_stock(counter.mechanism_snapshot(), stock),
			"original restore owners recover dressing, stock and open cap")

func _walk_local(goal: Vector3) -> bool:
	for tick in 300:
		var delta := goal - player.global_position
		delta.y = 0
		if delta.length() < .035:
			break
		player.rotation.y = atan2(-delta.x, -delta.z)
		player.camera.rotation = Vector3.ZERO
		Input.action_press("move_forward", clampf(delta.length() / .25, .65, 1.0))
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame
	var arrived := Vector2(player.global_position.x - goal.x, player.global_position.z - goal.z).length() < .055
	dressing_report.walk.append({"goal": var_to_str(goal), "actual": var_to_str(player.global_position), "arrived": arrived})
	return check(arrived and player.is_on_floor() and not player.noclip, "normal standing walk reaches nearby goal")

func _box(label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	add_child(body)
	var solid := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	solid.shape = shape
	body.add_child(solid)

func cursor_to(pixel: Vector2) -> bool:
	var viewport := get_viewport() as SubViewport
	if viewport == null:
		return false
	pixel = pixel.round()
	var motion := InputEventMouseMotion.new()
	motion.position = pixel
	motion.global_position = pixel
	viewport.push_input(motion, true)
	await get_tree().process_frame
	return viewport.get_mouse_position().distance_to(pixel) < .6
