extends Node
## K4 focused proof: the thin coordinator over the real owners — real
## WorkOrders/library, real MaintenanceInventory and shop service, the real
## RealityCases autoload and a real CoreLoopDirector. The only stand-in is
## a bare body carrying the production `call_locked` flag; every rule under
## test lives in a real owner. The production-scene loop is
## MaintenanceCounterTest's job.

const JOB := ChirpHunt.JOB_ID
const ITEM := "carbon_transmitter_capsule"
const SHOP := "hardware_paint"
const CASE := "mina_caption_crisis"

class StandInPlayer:
	extends CharacterBody3D
	var call_locked := false

var failures := 0
var trace: Array[String] = []
var conversation_requests := 0
var dream_requests := 0
var wakes := 0
var work_orders: WorkOrders
var inventory: MaintenanceInventory
var shop: MaintenanceShopService
var director: CoreLoopDirector
var player: StandInPlayer
var layout: Dictionary = {}


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	layout = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/building_layout.json"))
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
	player = StandInPlayer.new()
	add_child(player)
	_fresh_director()

	await _discovered_recognition()
	await _reported_golden_loop()

	print("BOUNDARY TRACE: ", " | ".join(trace))
	print("CORE LOOP TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _fresh_director() -> void:
	if director:
		director.free()
	director = CoreLoopDirector.new()
	add_child(director)
	director.setup(work_orders, player, layout)
	director.conversation_requested.connect(
			func(_c: String, _r: String) -> void: conversation_requests += 1)
	director.dream_requested.connect(
			func(_c: String, _p: String, _w: Dictionary) -> void:
				dream_requests += 1)
	director.wake_completed.connect(
			func(_a: String) -> void: wakes += 1)


func _mark(boundary: String) -> void:
	trace.append(boundary)


## Save/load through the same stringify/parse/merge steps load_game runs,
## then rebuild the coordinator the way a fresh boot would.
func _roundtrip() -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(RealityState.data))
	RealityState.reset_campaign_for_tests()
	RealityState.data.merge(saved, true)
	_fresh_director()


func _discovered_recognition() -> void:
	RealityState.ensure_case(CASE, "mina_vale")
	work_orders.issue_job(JOB, "discovered")
	work_orders.acknowledge_job(JOB)
	RealityCases.interact_with_resident("mina_vale")
	var state := work_orders.job_state(JOB)
	_check(str(state.origin) == "discovered"
			and str(state.stage) == "acknowledged",
			"Mina's complaint recognizes a discovered job without overwriting it")
	_check(director.boundary() == "job_open",
			"a discovered start enters the same coordinator flow")
	await get_tree().process_frame
	RealityState.reset_campaign_for_tests()
	_fresh_director()


func _reported_golden_loop() -> void:
	RealityState.ensure_case(CASE, "mina_vale")

	# B0: before issue.
	_check(director.boundary() == "idle", "the loop starts idle")
	_roundtrip()
	_check(director.boundary() == "idle"
			and work_orders.job_stage(JOB) == "missing",
			"save/load before issue resumes idle without issuing")
	_mark("idle")

	# Reported origin through the existing interaction event.
	RealityState.ensure_case(CASE, "mina_vale")
	RealityCases.interact_with_resident("mina_vale")
	_check(work_orders.job_stage(JOB) == "issued"
			and str(work_orders.job_state(JOB).origin) == "reported"
			and director.boundary() == "job_open",
			"Mina's complaint issues the job with reported origin")
	RealityCases.interact_with_resident("mina_vale")
	_check(work_orders.job_stage(JOB) == "issued",
			"a repeated complaint neither duplicates nor resets the job")
	_mark("job_open")

	# Unrelated case and dialogue events are ignored.
	RealityState.ensure_case("juno_feedback_tetris", "juno_kells")
	RealityCases.resident_interaction_requested.emit(
			"juno_feedback_tetris", "juno_kells")
	RealityCases.record_conversation("juno_feedback_tetris", "credit_was_taken")
	_check(director.boundary() == "job_open"
			and work_orders.job_stage(JOB) == "issued",
			"unrelated case and dialogue events are ignored")

	work_orders.acknowledge_job(JOB)
	_roundtrip()
	_check(director.boundary() == "job_open"
			and work_orders.job_stage(JOB) == "acknowledged",
			"save/load at issued/acknowledged resumes in place")

	work_orders.diagnose_job(JOB)
	work_orders.record_job_evidence(JOB, "no_battery_bay")
	work_orders.mark_job_awaiting_part(JOB)
	_roundtrip()
	_check(director.boundary() == "job_open"
			and work_orders.job_stage(JOB) == "awaiting_part",
			"save/load at awaiting_part resumes in place")
	_mark("awaiting_part")

	_check(shop.acquire(ITEM, SHOP)
			and work_orders.job_stage(JOB) == "repairable",
			"the real shop transaction still drives repairable")
	_roundtrip()
	_check(director.boundary() == "job_open" and inventory.has_item(ITEM)
			and work_orders.job_stage(JOB) == "repairable"
			and RealityState.data.maintenance_items.size() == 1
			and conversation_requests == 0,
			"save/load at repairable duplicates nothing and requests nothing")
	_mark("repairable")

	# Repair requests the conversation and does not close the job.
	inventory.consume(ITEM)
	work_orders.record_job_repair(JOB, {"quality": "good"})
	RealityCases.stabilize_case(CASE)
	_check(director.boundary() == "conversation_pending"
			and conversation_requests == 1
			and work_orders.job_stage(JOB) == "repaired",
			"repair requests the earned conversation without closing")
	_roundtrip()
	_check(director.boundary() == "conversation_pending"
			and conversation_requests == 1
			and bool(director.loop_state().conversation_requested),
			"save/load at conversation-pending does not re-request")
	_mark("conversation_pending")

	# An ordinary conversation is not the rule change.
	RealityState.ensure_case(CASE, "mina_vale")
	RealityCases.record_conversation(CASE, "small_talk")
	_check(work_orders.job_stage(JOB) == "repaired"
			and director.boundary() == "conversation_pending",
			"an ordinary conversation flag does not close the job")

	# Mina's first conversation and recurrence remain case-owned. The first
	# rule insight cannot close an only-half-integrated case.
	RealityCases.record_conversation(CASE, "first_silence_named")
	_check(RealityCases.reopen_case(CASE)
			and RealityCases.stabilize_case(CASE),
			"the case owner carries recurrence and its second stabilization")

	# The complete authoritative rule change closes the repaired job; final
	# integration, not the first insightful line, opens the dream window.
	player.call_locked = true
	RealityCases.record_conversation(CASE, "assumptions_are_not_facts")
	_check(work_orders.job_stage(JOB) == "repaired"
			and director.boundary() == "conversation_pending",
			"the first resolution flag cannot close an incomplete rule")
	RealityCases.record_conversation(CASE, "silence_can_be_blank")
	_check(work_orders.job_stage(JOB) == "closed"
			and director.boundary() == "conversation_complete"
			and bool(director.loop_state().conversation_complete),
			"the complete rule closes the job but still waits for integration")
	_mark("conversation_complete")
	_roundtrip()
	_check(work_orders.job_stage(JOB) == "closed"
			and director.boundary() == "conversation_complete"
			and bool(director.loop_state().conversation_complete)
			and dream_requests == 0,
			"save/load at conversation-complete waits for integration")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(dream_requests == 0,
			"conversation completion alone does not request a dream")
	_check(RealityCases.resolve_case(CASE)
			and director.boundary() == "dream_pending",
			"final case integration arms the dream window")
	await get_tree().process_frame
	_check(dream_requests == 0,
			"integration during protection still suppresses dream entry")
	player.call_locked = false
	await get_tree().process_frame
	_check(dream_requests == 1,
			"dream entry is requested once the protection lifts")
	_mark("dream_pending")

	_roundtrip()
	await get_tree().process_frame
	_check(director.boundary() == "dream_pending" and dream_requests == 2
			and work_orders.job_stage(JOB) == "closed",
			"save/load at dream-pending re-requests exactly once")

	# The wake boundary returns the player and erases no committed work.
	player.global_position = Vector3(50, 0, 50)
	_check(director.notify_wake_complete() and wakes == 1,
			"wake completion accepts the boundary")
	var anchor := director.resolve_return_anchor()
	_check(not anchor.is_empty()
			and player.global_position.distance_to(anchor.position) < 0.01,
			"wake returns the player to the authored 4B bedside anchor")
	var job := work_orders.job_state(JOB)
	_check(str(job.stage) == "closed" and job.evidence == ["no_battery_bay"]
			and str(job.repair_result.quality) == "good"
			and inventory.is_consumed(ITEM),
			"wake preserves repair, spent capsule, evidence and closed job")
	player.global_position = Vector3(50, 0, 50)
	_check(not director.notify_wake_complete()
			and player.global_position.distance_to(Vector3(50, 0, 50)) < 0.01
			and wakes == 1,
			"a duplicate wake is rejected without mutation")
	_mark("wake_complete")

	_roundtrip()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(director.boundary() == "wake_complete" and dream_requests == 2
			and work_orders.job_stage(JOB) == "closed"
			and inventory.is_consumed(ITEM)
			and not inventory.has_item(ITEM),
			"save/load after wake resurrects neither dream, item nor chirp")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [loop ok] ", label)
	else:
		failures += 1
		printerr("  [LOOP FAIL] ", label)
