class_name ChirpHunt
extends Node
## First WorkOrders customer: one line-test chirp, somewhere in the building.

const ORDER_ID := "WO-VANTRY-001"
const TITLE := "WORK ORDER 001 — THE CHIRP"
const OBJECTIVE := "One Vantry point is issuing a line-test tone. Find it by ear and inspect the grille."

var network: VantryPointNetwork
var work_orders: WorkOrders
var active_point_id := ""
var _running := false


func setup(points: VantryPointNetwork, spine: WorkOrders) -> void:
	network = points
	work_orders = spine
	work_orders.issue(ORDER_ID, TITLE, OBJECTIVE, "Orison house circuit")
	# Until the lobby terminal becomes a real dispatcher, this first order is
	# issued and accepted together. It is live, not a TODO-shaped silent game.
	if work_orders.status(ORDER_ID) != "closed":
		work_orders.activate(ORDER_ID)
	active_point_id = _initial_point()
	if active_point_id != "" and work_orders.is_active(ORDER_ID):
		network.activate(active_point_id)
		network.active_owner.inspected.connect(_on_inspected)
		_running = true
		_chirp_loop()


func _initial_point() -> String:
	const PREFERRED := "F06_D_BED_VANTRY_POINT"
	if not network.point_spec(PREFERRED).is_empty():
		return PREFERRED
	var ids := network.cached_point_ids()
	return ids[ids.size() - 1] if not ids.is_empty() else ""


func _chirp_loop() -> void:
	while _running and is_inside_tree():
		await get_tree().create_timer(
				network.active_owner.rng.randf_range(50.0, 95.0), false).timeout
		if _running and work_orders.is_active(ORDER_ID):
			network.active_owner.play_chirp(1.0)
			AcousticGraphData.propagate(active_point_id, 0, 1.0, 0.0)


func force_chirp() -> void:
	if _running and work_orders.is_active(ORDER_ID):
		network.active_owner.play_chirp(1.0)


func relocate(point_id: String) -> bool:
	if not _running or not network.relocate_unseen(point_id):
		return false
	active_point_id = point_id
	return true


func _on_inspected(point_id: String) -> void:
	if point_id != active_point_id or not work_orders.is_active(ORDER_ID):
		return
	_running = false
	network.active_owner.set_chirping(false)
	work_orders.close(ORDER_ID,
			"NO BATTERY FOUND. The line stopped when it knew you were listening.")
