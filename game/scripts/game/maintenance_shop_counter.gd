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
var _counter_tap: AudioStreamPlayer3D


func setup(owner_service: MaintenanceShopService, id: String) -> void:
	service = owner_service
	shop_id = id
	_counter_tap = AudioStreamPlayer3D.new()
	_counter_tap.stream = PropAudio.get_stream("tick")
	_counter_tap.volume_db = -15.0
	_counter_tap.unit_size = 3.0
	_counter_tap.max_distance = 18.0
	add_child(_counter_tap)


func interact_prompt() -> String:
	if service == null:
		return ""
	var transaction := service.counter_prompt(shop_id)
	return transaction if not transaction.is_empty() \
			else "[E]  Inspect hardware counter"


func interact(_player: Node) -> Dictionary:
	if service == null:
		return {}
	if _counter_tap:
		_counter_tap.pitch_scale = 1.12
		_counter_tap.play()
	var item_id := service.pending_item(shop_id)
	var item_name := "NONE AUTHORIZED"
	if not item_id.is_empty():
		item_name = str(service.stock_record(item_id).get(
				"display_name", item_id)).to_upper()
	var acquired := service.acquire_pending(shop_id)
	return PropServiceWire.card("hardware_counter", {
		"service_state": "PART ISSUED" if acquired \
				else "COUNTER ATTENDED / NO OPEN ORDER",
		"part_state": item_name,
	})
