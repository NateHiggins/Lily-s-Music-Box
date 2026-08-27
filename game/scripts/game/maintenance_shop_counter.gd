class_name MaintenanceShopCounter
extends Area3D
## The physical acquisition point over a shop's authored counter. A thin
## interaction adapter: it owns no stock, no items and no job state — it asks
## MaintenanceShopService for its prompt and hands the interact through. The
## player's ordinary 2.1 m interact ray hits this volume above the counter
## top and gets a prompt only when the counter actually has something for an
## open job.

var service: MaintenanceShopService
var shop_id := ""


func setup(owner_service: MaintenanceShopService, id: String) -> void:
	service = owner_service
	shop_id = id


func interact_prompt() -> String:
	if service == null:
		return ""
	var transaction := service.counter_prompt(shop_id)
	return transaction if not transaction.is_empty() \
			else "[E]  Inspect hardware counter"


func interact(_player: Node) -> Dictionary:
	if service == null:
		return {}
	var item_id := service.pending_item(shop_id)
	var item_name := "NONE AUTHORIZED"
	if not item_id.is_empty():
		item_name = str(service.stock_record(item_id).get(
				"display_name", item_id)).to_upper()
	var acquired := service.acquire_pending(shop_id)
	AudioPolicy.present_3d(
			&"interaction.counter_issue" if acquired \
			else &"interaction.counter_empty",
			global_position, 1.0, StringName("counter:%s" % shop_id))
	return PropServiceWire.card("hardware_counter", {
		"service_state": "PART ISSUED" if acquired \
				else "COUNTER ATTENDED / NO OPEN ORDER",
		"part_state": item_name,
	})
