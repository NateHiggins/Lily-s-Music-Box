extends Node
## One continuous, reversible walk through all three M0.5 zones:
## ORISON lobby -> STREET -> PASSAGE -> a fitted customer floor. Focused shop
## and resident tests still cover every threshold; this prevents those green
## local proofs from concealing a broken join between them.
##
## This must use PlayerController rather than a flat capsule sweep. The route
## contains two authored kerb steps and a swinging landmark leaf; the fixed-
## height Check 1 probe correctly collides with both, but the player steps and
## slides through them in normal play.

var _fails := 0
var root: Node3D
var player: PlayerController


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _walk_to(target: Vector2, label: String) -> bool:
	var start := Vector2(player.global_position.x, player.global_position.z)
	var timeout := start.distance_to(target) / PlayerController.WALK + 3.0
	var elapsed := 0.0
	while elapsed < timeout:
		var here := Vector2(player.global_position.x, player.global_position.z)
		if here.distance_to(target) < 0.42:
			player.autopilot = Vector3.ZERO
			return true
		var direction := (target - here).normalized()
		player.autopilot = Vector3(direction.x, 0.0, direction.y)
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
	player.autopilot = Vector3.ZERO
	print("    %s stopped at %v, %.2f m short of %v" % [label,
			player.global_position, Vector2(player.global_position.x,
			player.global_position.z).distance_to(target), target])
	return false


func _walk_route(points: Array[Vector2], label: String) -> bool:
	var clear := true
	for i in points.size():
		if not await _walk_to(points[i], "%s leg %02d" % [label, i]):
			clear = false
			break
	return clear


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	player = root.player
	# Same simulation, less wall clock. This test walks roughly 110 metres and
	# remains under the mandatory 60-second process watchdog at 2x.
	Engine.time_scale = 2.0
	for cart in get_tree().get_nodes_in_group("passage_pushcarts"):
		cart.freeze = true

	var entry = root.find_child("F01_DOOR_06", true, false)
	var hardware = root.find_child(
			"SITE_SHOP_DOOR_HARDWARE_PAINT", true, false)
	_check("the Orison landmark entry owns the route start", entry is DoorProp)
	_check("HARDWARE PAINT owns the route destination", hardware is DoorProp)
	if entry is DoorProp:
		entry.interact(null)
	if hardware is DoorProp:
		hardware.npc_set_open(true)
	await get_tree().create_timer(0.9).timeout

	player.global_position = Vector3(0.0, 0.15, 9.0)
	player.velocity = Vector3.ZERO
	var outbound: Array[Vector2] = [
		# ORISON landmark entry to north pavement.
		Vector2(0.0, 12.5),
		# STREET: along the north pavement, over both kerbs, south pavement.
		Vector2(6.2, 12.4), Vector2(12.0, 12.6), Vector2(14.0, 12.6),
		Vector2(14.0, 16.0), Vector2(14.0, 22.5), Vector2(14.0, 26.2),
		# PASSAGE: portal, throat, exact aisle spine and customer threshold.
		Vector2(14.0, 29.2), Vector2(14.0, 34.0), Vector2(14.0, 38.9),
		Vector2(14.0, 58.425), Vector2(11.79, 58.425),
		Vector2(10.44, 58.425),
	]
	_check("the complete ORISON -> STREET -> PASSAGE route is walkable",
			await _walk_route(outbound, "outbound"))
	_check("the outbound route finishes on HARDWARE PAINT's customer floor",
			player.global_position.x < 10.9
			and absf(player.global_position.z - 58.425) < 0.6)

	var returning := outbound.duplicate()
	returning.pop_back()
	returning.reverse()
	returning.append(Vector2(0.0, 9.0))
	_check("the loaded return route uses the same map in reverse",
			await _walk_route(returning, "return"))
	_check("the return finishes inside the Orison lobby",
			player.global_position.z < 9.5 and absf(player.global_position.x) < 0.6)
	_check("the exact portal changes ownership in both directions",
			not root._point_is_in_passage(Vector3(14.0, 1.0, 28.316))
			and root._point_is_in_passage(Vector3(14.0, 1.0, 28.317)))
	_check("traffic preserves an authored walking gap inside eight seconds",
			StreetTraffic.GAP_SECONDS >= 3.0 and StreetTraffic.MAX_WAIT <= 8.0)
	_check("both complete street ends remain outside the route envelope",
			outbound.all(func(point):
				return point.x > -20.10 + PlayerController.BODY_RADIUS \
						and point.x < 20.60 - PlayerController.BODY_RADIUS))

	Engine.time_scale = 1.0
	print("[FINAL MAP ROUTE] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
