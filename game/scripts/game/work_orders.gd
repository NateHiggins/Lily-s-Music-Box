class_name WorkOrders
extends Node
## Smallest honest version of the maintenance spine.
##
## One customer is enough to establish ownership: systems issue named orders,
## this node persists their state, and the objective tracker only presents it.
## Case modules must not grow private "work-order-like" booleans around it.

signal order_issued(order_id: String, order: Dictionary)
signal order_activated(order_id: String, order: Dictionary)
signal order_closed(order_id: String, order: Dictionary)

var tracker: ObjectiveTracker


func setup(objective_tracker: ObjectiveTracker) -> void:
	tracker = objective_tracker
	if not RealityState.data.has("work_orders"):
		RealityState.data.work_orders = {}


func issue(order_id: String, title: String, objective: String,
		source := "building") -> bool:
	var orders: Dictionary = RealityState.data.get("work_orders", {})
	if orders.has(order_id):
		return false
	orders[order_id] = {
		"title": title, "objective": objective, "source": source,
		"status": "issued", "issued_at": Time.get_unix_time_from_system(),
	}
	RealityState.data.work_orders = orders
	RealityState.commit()
	order_issued.emit(order_id, orders[order_id].duplicate(true))
	return true


func activate(order_id: String) -> bool:
	var order := _order(order_id)
	if order.is_empty() or str(order.get("status", "")) == "closed":
		return false
	order.status = "active"
	RealityState.commit()
	_show(order)
	order_activated.emit(order_id, order.duplicate(true))
	return true


func close(order_id: String, closing_note := "WORK ORDER CLOSED") -> bool:
	var order := _order(order_id)
	if order.is_empty() or str(order.get("status", "")) == "closed":
		return false
	order.status = "closed"
	order.closed_at = Time.get_unix_time_from_system()
	RealityState.commit()
	if tracker:
		tracker.show_objective(str(order.title), closing_note)
	order_closed.emit(order_id, order.duplicate(true))
	return true


func status(order_id: String) -> String:
	return str(_order(order_id).get("status", "missing"))


func is_active(order_id: String) -> bool:
	return status(order_id) == "active"


func _order(order_id: String) -> Dictionary:
	var orders: Dictionary = RealityState.data.get("work_orders", {})
	return orders.get(order_id, {})


func _show(order: Dictionary) -> void:
	if tracker:
		tracker.show_objective(str(order.title), str(order.objective))
