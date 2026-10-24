extends Node
## Transaction/save diagnostic; physical hand input is a separate contract.
const Shop := preload("res://scripts/game/v2_maintenance_shop_service.gd")
const BOTTLE := "fire_hose_rubber_protectant"
const GASKET := "fire_hose_spare_gasket"
var failures := 0
var checks := 0
var radio_on := true
var terminal_on := true

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var items := MaintenanceInventory.new()
	items.setup()
	add_child(items)
	var orders := WorkOrders.new()
	orders.setup(null)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	var shop := Shop.new()
	add_child(shop)
	shop.setup(items, orders)
	var economy:=preload("res://scripts/game/caretaker_economy.gd").new()
	add_child(economy)
	_check(economy.setup(orders), "existing cash owner binds")
	var network:=preload("res://scripts/game/radio_clearing_network.gd").new()
	_check(network.configure(economy,func():return radio_on,
		func(merchant: String):return terminal_on and merchant=="hardware_paint"), "radio clearing adapter binds")
	_check(not shop.purchase_supply(BOTTLE,"hardware_paint"), "no settlement network refuses delivery")
	shop.clearing=network
	_check(shop.is_valid(), "authored requisitions and service supplies validate")
	_check(shop.supply_ids() == ([BOTTLE, GASKET] as Array[String]), "two explicit fire-service products")
	_check(shop.pending_item("hardware_paint").is_empty(), "optional stock does not hijack the requisition counter")
	_check(not shop.purchase_supply(BOTTLE, "news_cigars"), "wrong shop refused")
	_check(not shop.purchase_supply("carbon_transmitter_capsule", "hardware_paint"), "job part cannot bypass its requisition")
	_check(not shop.purchase_supply("unknown", "hardware_paint"), "unknown product refused")
	var jobs_before: Dictionary = orders.serialize_jobs()
	radio_on=false
	_check(not shop.purchase_supply(BOTTLE,"hardware_paint") and not items.has_item(BOTTLE), "radio off cannot purchase or deliver")
	radio_on=true;terminal_on=false
	_check(not shop.purchase_supply(BOTTLE,"hardware_paint"), "unavailable merchant terminal refuses settlement")
	terminal_on=true
	_check(not network.settle("failed_delivery","hardware_paint","test",5,func():return false)
		and int(economy.book().cash)==100, "failed fulfillment restores cash")
	RealityState.save_path="user://tests/v2_fire_stock_%d.json" % OS.get_process_id()
	RealityState.persistence_enabled=true
	_check(shop.purchase_supply(BOTTLE, "hardware_paint"), "bottle can be bought without a fabricated work order")
	_check(shop.purchase_supply(GASKET, "hardware_paint"), "gasket can be bought independently")
	_check(items.has_item(BOTTLE) and items.has_item(GASKET), "inventory owns both acquisitions")
	_check(int(economy.book().cash)==65 and economy.book().purchases.size()==2, "one ledger debits exactly 35 cents with two receipts")
	economy.book().cash=999
	RealityState.load_game()
	_check(int(economy.book().cash)==65 and items.has_item(BOTTLE) and items.has_item(GASKET)
		and economy.book().purchases.size()==2, "delivery commit saves cash, receipt and items together on disk")
	RealityState.persistence_enabled=false
	_check(not shop.purchase_supply(BOTTLE, "hardware_paint"), "repeated grab cannot duplicate bottle")
	_check(orders.serialize_jobs() == jobs_before, "optional purchase never changes work-order lifecycle")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(items.serialize()))
	var saved_money: Dictionary=JSON.parse_string(JSON.stringify(economy.book()))
	RealityState.reset_campaign_for_tests()
	RealityState.data[economy.KEY]=saved_money
	_check(items.restore(saved), "inventory JSON save round trip")
	_check(items.has_item(BOTTLE) and items.has_item(GASKET), "bottle and gasket persist")
	_check(not shop.can_purchase_supply(BOTTLE, "hardware_paint"), "restored purchase cannot be minted again")
	_check(int(economy.book().cash)==65 and not network.settle("maintenance_supply:"+BOTTLE,"hardware_paint",BOTTLE,25,func():return true), "saved receipt rejects replay without another debit")
	var receipt: Dictionary=network.receipt("maintenance_supply:"+BOTTLE)
	_check(receipt=={"merchant":"hardware_paint","item":BOTTLE,"cents":25}, "lost acknowledgement can retrieve the saved receipt")
	receipt.cents=1
	_check(int(network.receipt("maintenance_supply:"+BOTTLE).cents)==25, "receipt query does not expose mutable authority")
	_check(not network.settle("overdrawn","hardware_paint","test",66,func():return true), "insufficient funds refused")
	RealityState.save_write_blocked=true
	_check(not network.settle("blocked_save","hardware_paint","test",1,func():return true), "blocked save refuses purchase")
	RealityState.save_write_blocked=false
	_check(items.consume(GASKET) and not items.consume(GASKET), "replacement gasket spent once through inventory")
	_check(items.has_item(BOTTLE), "reusable bottle survives fitting a gasket")
	_check(not shop.purchase_supply(GASKET, "hardware_paint"), "consumed campaign stock cannot resurrect")
	RealityState.save_path=RealityState.SAVE_PATH
	print("V2 FIRE MAINTENANCE STOCK: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
