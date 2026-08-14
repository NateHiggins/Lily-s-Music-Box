extends Node
## K3 production-scene proof: the acquisition exists as a real interaction at
## HARDWARE PAINT, not only as a test API. The real player walks from the
## route-test-proven customer threshold to the counter, the ordinary 2.1 m
## interact ray finds the counter volume over the authored counter top, and
## the ordinary interact path performs the buy.

const JOB := "steam_hammer_2a"
const ITEM := "vent_orifice_no3"
const SHOP := "hardware_paint"

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
	print("    %s stopped at %v" % [label, player.global_position])
	return false


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	player = root.player
	for cart in get_tree().get_nodes_in_group("passage_pushcarts"):
		cart.freeze = true

	var counter: Area3D = root.shop_service.counter(SHOP)
	_check("the shop service builds the HARDWARE PAINT counter point",
			counter != null and root.shop_service.is_valid())
	if counter == null:
		_finish()
		return
	_check("the counter stands on the authored counter top",
			absf(counter.global_position.x - 9.9) < 0.05
			and absf(counter.global_position.z - 56.2) < 0.05
			and counter.global_position.y > 1.1)

	# The door the route test proved; enter from its proven customer threshold.
	var door = root.find_child("SITE_SHOP_DOOR_HARDWARE_PAINT", true, false)
	if door is DoorProp:
		door.npc_set_open(true)
	await get_tree().create_timer(0.6).timeout
	player.global_position = Vector3(10.44, 0.15, 58.425)
	player.velocity = Vector3.ZERO
	# The strip east of the counter is the display window; customers stand on
	# the floor south of the counter's end, just inside the door.
	_check("the customer floor reaches the counter on foot",
			await _walk_to(Vector2(10.0, 58.1), "counter approach"))

	# Aim the real camera at the counter volume and use the production ray.
	var eye := player.camera.global_position
	var at := counter.global_position
	player.camera.look_at(Vector3(at.x, minf(at.y, eye.y - 0.1), 57.2))
	_check("before any open job the counter shows no prompt",
			counter.interact_prompt() == "")
	player._try_interact()
	_check("an interact with no open job grants nothing",
			not root.maintenance_inventory.has_item(ITEM))

	var orders: WorkOrders = root.work_orders
	orders.issue_job(JOB, "reported")
	orders.acknowledge_job(JOB)
	orders.diagnose_job(JOB)
	orders.mark_job_awaiting_part(JOB)
	_check("awaiting_part lights the counter prompt",
			counter.interact_prompt() == "[E]  Buy: No. 3 air-vent orifice")
	player._try_interact()
	_check("the production interact performs the buy",
			root.maintenance_inventory.has_item(ITEM))
	_check("the buy drives the job to repairable",
			orders.job_stage(JOB) == "repairable")
	player._try_interact()
	_check("a second interact cannot duplicate the part",
			RealityState.data.maintenance_items.size() == 1
			and not root.maintenance_inventory.is_consumed(ITEM))
	_check("the satisfied counter goes quiet", counter.interact_prompt() == "")
	print("COUNTER TRACE: stage=%s item=%s consumed=%s" % [orders.job_stage(JOB),
			root.maintenance_inventory.has_item(ITEM),
			root.maintenance_inventory.is_consumed(ITEM)])
	_finish()


func _finish() -> void:
	print("[MAINTENANCE COUNTER] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
