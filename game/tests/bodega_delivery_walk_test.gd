extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Cam's dawn delivery walked in the real world (cam_restock_run_20261124). After
## the 03:30 counter meal, the 03:50 work block takes Cam through the bodega's
## transit holds to the receiving stop by the back-alcove handcart: never a queue
## place, never the service stance again, door and clearance checks as authored.
## At 04:10 Cam leaves by the same holds. The clock is the production clock.
const Admission := preload("res://scripts/building/bodega_admission.gd")
const Delivery := preload("res://scripts/building/orison_v2_bodega_delivery.gd")
const WALK_LIMIT := 240.0
const SERVICE_STANCE := "service_stance"

var _cam: Node3D
var _guide: RefCounted

func _init() -> void:
	route_label = "BODEGA DELIVERY WALK"


func _route() -> void:
	_cam = world.resident_routes.get("cam_ortiz")
	if not _require(_cam != null and _cam.get("_bodega_route") != null, "Cam's route has the bodega guide"):
		return
	_guide = _cam._bodega_route
	var clock: CampaignClock = world.campaign_clock
	var info: Dictionary = clock.day_info()
	_require(int(info.get("doy", 0)) != 84, "an ordinary day, not the Triangle fire date")
	world.player.set_lamp_enabled(false)
	# The counter meal first, as the timetable has it.
	await _jump_to(210.0)
	await _until(func(): return str(_guide._station) == SERVICE_STANCE or not str(_guide._holding).is_empty(), 180.0)
	print("[DELIVERY WALK] at 03:30 station=", _guide._station, " holding=", _guide._holding)
	# 03:50: the delivery.
	await _jump_to(230.0)
	_require(str(_cam.destination) == "bodega" and str(_cam.activity) == "work", "at 03:50 Cam's block is the bodega delivery: %s/%s" % [_cam.destination, _cam.activity])
	# A request held over from the counter meal is dropped on the first tick; what
	# must never happen is a new queue request once it has gone.
	var queued_again := {"seen": false, "dropped": false, "inherited": str(_guide._holding)}
	var watch := func() -> bool:
		var holding := str(_guide._holding)
		if holding.is_empty():
			queued_again.dropped = true
		elif queued_again.dropped and str(_guide._station) != Admission.RECEIVING_STOP:
			queued_again.seen = true
		return str(_guide._station) == Admission.RECEIVING_STOP and _guide._leg.is_empty()
	var arrived: bool = await _until(watch, WALK_LIMIT)
	var receiving := int(_guide._nodes[Admission.RECEIVING_STOP])
	_require(arrived and int(_cam.current_id) == receiving, "Cam reaches the receiving stop by the handcart: station %s, blocked '%s'" % [_guide._station, _cam.blocked_reason])
	print("[DELIVERY WALK] inherited request at 03:50: '", queued_again.inherited, "'")
	_require(not queued_again.seen and str(_guide._holding).is_empty(), "and takes no new queue place on the way")
	var snapshot: Dictionary = world.bodega_admission.debug_snapshot()
	var stance: Dictionary = snapshot.service_owner
	_require(stance.is_empty() or str(stance.get("resident", "")) != "cam_ortiz", "nor holds the service stance at the handcart")
	var queue: Array = snapshot.service.queue
	_require(queue.all(func(entry): return str(entry.get("resident", "")) != "cam_ortiz"), "and is nowhere in the service queue")
	_require(_guide.errors.is_empty(), "the guide raised no faults: %s" % [_guide.errors])
	# 04:00: the delivery lands on the handcart while Cam stands there.
	await _jump_to(240.0)
	var handcart: Node3D = world.exterior_cell.instance_node("SHOP_BODEGA").get_node("BodegaDeliveryLoad")
	handcart.refresh()
	_require(handcart.load_node.visible, "at 04:00 the handcart holds the delivery")
	var shop: Node3D = world.exterior_cell.instance_node("SHOP_BODEGA")
	var camera: Camera3D = world.player.camera
	world.player.set_physics_process(false)
	camera.global_position = shop.to_global(Vector3(0.9, 1.65, -6.6))
	camera.look_at(shop.to_global(Vector3(-0.3, 0.9, -9.0)))
	camera.make_current()
	for frame in 20:
		await RenderingServer.frame_post_draw
	await _capture_interaction("cam_at_the_handcart")
	world.player.set_physics_process(true)
	# 04:10: the stairs, by the same holds and out through the storefront.
	await _jump_to(250.0)
	var left: bool = await _until(func(): return str(_guide._station).is_empty() and _guide._leg.is_empty(), WALK_LIMIT)
	_require(left and str(_cam.destination) != "bodega", "at 04:10 Cam leaves the shop: station '%s', blocked '%s'" % [_guide._station, _cam.blocked_reason])
	_require(_guide.errors.is_empty() and not world.bodega_admission.has_active_service_or_transit("cam_ortiz", _cam.actor),
			"and leaves no claim behind")


func _jump_to(minute_of_day: float) -> void:
	var clock: CampaignClock = world.campaign_clock
	var ahead := fposmod(minute_of_day - clock.minute_of_day(), 1440.0)
	_require(clock.advance_to(clock.elapsed_minutes() + ahead), "the clock reaches %02d:%02d" % [floori(minute_of_day / 60.0), floori(fmod(minute_of_day, 60.0))])
	await get_tree().create_timer(1.0).timeout


func _until(condition: Callable, limit: float) -> bool:
	var waited := 0.0
	while waited < limit:
		if bool(condition.call()):
			return true
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	return bool(condition.call())
