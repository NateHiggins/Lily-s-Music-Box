extends Node
## K3 focused proof: the maintenance errand contract, on the real owners.
##
## Real MaintenanceInventory, real MaintenanceShopService with the shipped
## stock data, real WorkOrders with the shipped job library, over the
## RealityState autoload. No mocks. The production-scene interaction at the
## hardware counter is MaintenanceCounterTest's job.

const JOB := "steam_hammer_2a"
const ITEM := "vent_orifice_no3"
const SHOP := "hardware_paint"

var failures := 0
var acquired_events: Array[String] = []
var consumed_events: Array[String] = []
var work_orders: WorkOrders
var inventory: MaintenanceInventory
var shop: MaintenanceShopService


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	work_orders = WorkOrders.new()
	work_orders.setup(null)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(work_orders)
	inventory = MaintenanceInventory.new()
	inventory.setup()
	add_child(inventory)
	shop = MaintenanceShopService.new()
	add_child(shop)
	shop.setup(inventory, work_orders)
	inventory.part_acquired.connect(
			func(item_id: String, shop_id: String) -> void:
				acquired_events.append("%s@%s" % [item_id, shop_id]))
	inventory.part_consumed.connect(
			func(item_id: String) -> void: consumed_events.append(item_id))

	_stock_checks()
	_gate_checks()
	_transaction_checks()
	_persistence_checks()
	_consumption_checks()
	_k2_unchanged_checks()

	print("ERRAND TRACE: acquired=%s consumed=%s job=%s item_held=%s" %
			[acquired_events, consumed_events,
			work_orders.job_stage(JOB), inventory.has_item(ITEM)])
	print("MAINTENANCE ERRAND TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _stock_checks() -> void:
	_check(shop.is_valid(), "shop_inventory.json loads and validates")
	_check(shop.stock_ids() == ([ITEM] as Array[String]),
			"exactly one stock record is authored, for %s" % ITEM)
	var record := shop.stock_record(ITEM)
	_check(str(record.shop_id) == SHOP
			and str(record.acquisition_verb) == "buy"
			and str(record.kind) == "part"
			and str(record.counter_anchor_id)
					== "storm_shop_hardware_paint_counter_top",
			"the record binds the item to HARDWARE PAINT, verb buy, "
			+ "on the authored counter anchor")


func _gate_checks() -> void:
	_check(not shop.acquire("valve_no9", SHOP),
			"unknown item is refused")
	_check(not shop.acquire(ITEM, "news_cigars"),
			"the wrong shop is refused")
	_check(not shop.acquire(ITEM, SHOP),
			"no open job: the counter refuses")
	work_orders.issue_job(JOB, "reported")
	work_orders.acknowledge_job(JOB)
	_check(not shop.acquire(ITEM, SHOP) and shop.pending_item(SHOP) == "",
			"wrong job stage (acknowledged): refused, no prompt")
	work_orders.diagnose_job(JOB)
	_check(not shop.acquire(ITEM, SHOP),
			"wrong job stage (diagnosed): refused")
	_check(inventory.item_state(ITEM).is_empty()
			and work_orders.job_stage(JOB) == "diagnosed",
			"refused transactions mutate nothing")


func _transaction_checks() -> void:
	work_orders.mark_job_awaiting_part(JOB)
	_check(shop.pending_item(SHOP) == ITEM
			and shop.counter_prompt(SHOP) == "[E]  Buy: No. 3 air-vent orifice",
			"awaiting_part opens the counter and its prompt")
	_check(shop.acquire(ITEM, SHOP), "the valid transaction succeeds")
	_check(inventory.has_item(ITEM)
			and RealityState.data.maintenance_items.size() == 1,
			"exactly one item is added")
	_check(work_orders.job_stage(JOB) == "repairable",
			"acquisition drives the job to repairable through WorkOrders")
	_check(acquired_events == (["%s@%s" % [ITEM, SHOP]] as Array[String]),
			"part_acquired fired exactly once")
	_check(not shop.acquire(ITEM, SHOP)
			and not inventory.grant(ITEM, SHOP)
			and RealityState.data.maintenance_items.size() == 1,
			"repeating the transaction cannot duplicate the part")
	_check(shop.pending_item(SHOP) == "" and shop.counter_prompt(SHOP) == "",
			"a satisfied counter goes quiet")


func _persistence_checks() -> void:
	# The production save path is RealityState's own JSON file; persistence is
	# disabled under test, so round-trip through the identical stringify/parse
	# /merge steps load_game performs.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(RealityState.data))
	RealityState.reset_campaign_for_tests()
	_check(not inventory.has_item(ITEM) and work_orders.job_stage(JOB) == "missing",
			"fresh campaign forgets item and job")
	RealityState.data.merge(saved, true)
	_check(inventory.has_item(ITEM) and not inventory.is_consumed(ITEM)
			and str(inventory.item_state(ITEM).shop_id) == SHOP
			and work_orders.job_stage(JOB) == "repairable",
			"save/load preserves acquired-but-unconsumed and the job stage")
	var contract := inventory.serialize()
	RealityState.reset_campaign_for_tests()
	_check(inventory.restore(contract) and inventory.has_item(ITEM),
			"the explicit inventory contract restores the same fact")
	_check(not inventory.restore({"items": {ITEM: {"consumed": true}}}),
			"restore rejects a record with no provenance")
	RealityState.data.merge(saved, true)


func _consumption_checks() -> void:
	_check(inventory.consume(ITEM), "consumption succeeds once")
	_check(not inventory.consume(ITEM), "consumption cannot repeat")
	_check(not inventory.has_item(ITEM) and inventory.is_consumed(ITEM),
			"a consumed part is spent, not deleted")
	_check(consumed_events == ([ITEM] as Array[String]),
			"part_consumed fired exactly once")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(RealityState.data))
	RealityState.reset_campaign_for_tests()
	RealityState.data.merge(saved, true)
	_check(not inventory.has_item(ITEM) and inventory.is_consumed(ITEM)
			and not inventory.grant(ITEM, SHOP),
			"save/load after consumption does not resurrect the item")


func _k2_unchanged_checks() -> void:
	RealityState.reset_campaign_for_tests()
	_check(work_orders.issue("WO-TEST-001", "TEST", "Do the thing.")
			and work_orders.activate("WO-TEST-001")
			and work_orders.close("WO-TEST-001"),
			"the minimal order contract the chirp hunt uses is unchanged")
	_check(work_orders.issue_job(JOB, "discovered")
			and not work_orders.mark_job_repairable(JOB)
			and work_orders.acknowledge_job(JOB)
			and work_orders.diagnose_job(JOB)
			and work_orders.mark_job_awaiting_part(JOB),
			"the K2 lifecycle still enforces its ruled order")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [errand ok] ", label)
	else:
		failures += 1
		printerr("  [ERRAND FAIL] ", label)
