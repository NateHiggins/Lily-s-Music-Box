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
	return service.counter_prompt(shop_id) if service else ""


func interact(_player: Node) -> void:
	if service:
		service.acquire_pending(shop_id)
