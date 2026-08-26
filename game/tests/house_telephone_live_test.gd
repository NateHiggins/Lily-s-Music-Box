extends Node

var failures := 0
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  [%s] %s" % ["telephone live ok" if ok else "TELEPHONE LIVE FAIL", label])
	if not ok: failures += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.8).timeout
	var line: Node = root.find_child("HouseTelephoneNetwork", true, false)
	var board: Node = root.find_child("F01_HOUSE_TELEPHONE_BOARD", true, false)
	_check(line != null and board != null, "production resolves one house line and lobby board")
	if line == null or board == null:
		print("[HOUSE TELEPHONE LIVE] RESULT: FAIL (%d/%d)" % [checks - failures, checks])
		get_tree().quit(1); return
	_check(line.get("endpoints").size() == 4, "the authored census reaches production once")
	var expected := GameBoot.b2g([-5.05, -6.62, 1.42])
	_check(board.global_position.distance_to(expected) < 0.01,
			"the board owns the measured west-wall gap")
	var bodies := 0
	for child in board.find_children("*", "PhysicsBody3D", true, false): bodies += 1
	_check(bodies == 0, "the wall instrument adds no movement-blocking body")
	var areas := board.find_children("*", "Area3D", true, false)
	_check(not areas.is_empty(), "the real working face publishes a reachable interaction area")
	var save_before := var_to_bytes(RealityState.data)
	var node_count: int = root.get_tree().get_node_count()
	_check(line.call("request", "apt_4b"), "the real 4B endpoint asks once")
	_check((board.call("interact") as Dictionary).accepted, "the real board answers once")
	_check((board.call("interact") as Dictionary).accepted, "the real cord carries once")
	_check((board.call("interact") as Dictionary).accepted, "the answering hand releases once")
	_check(str((line.call("snapshot") as Dictionary).state) == "IDLE",
			"production ordinary operation returns physically idle")
	_check(var_to_bytes(RealityState.data) == save_before,
			"ordinary production operation writes no save fact")
	_check(root.get_tree().get_node_count() == node_count,
			"operating the line adds no node, light, body or material owner")
	var source := FileAccess.get_file_as_string(
			"res://scripts/building/house_telephone_network.gd")
	_check(not source.contains("WorkOrders") and not source.contains("RealityCases")
			and not source.contains("DoorProp") and not source.contains("commit("),
			"the production router owns no job, case, access or persistence seam")
	print("[HOUSE TELEPHONE LIVE] RESULT: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
