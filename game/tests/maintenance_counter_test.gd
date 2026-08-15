extends Node
## Amended K2/K3 production-scene proof: the complete graybox maintenance
## loop on the real building. The failed Vantry head in 2A chirps, the real
## inspection diagnoses the dead carbon capsule, the real player walks the
## proven customer threshold at HARDWARE PAINT and buys the replacement
## through the ordinary interact ray, and the real point interaction
## performs the repair — which stops the chirp and does NOT close the job.

const JOB := ChirpHunt.JOB_ID
const ITEM := "carbon_transmitter_capsule"
const SHOP := "hardware_paint"
const POINT := "F02_A_MAIN_VANTRY_POINT"

var _fails := 0
var root: Node3D
var player: PlayerController
var _dream_requests := 0


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
	var orders: WorkOrders = root.work_orders
	var hunt: ChirpHunt = root.chirp_hunt
	var network: VantryPointNetwork = root.vantry_points
	var inventory: MaintenanceInventory = root.maintenance_inventory

	_check("the chirp hunt sources the authored 2A anchor",
			hunt.active_point_id == POINT
			and network.active_point_id == POINT)
	_check("the fault chirps before any paperwork exists",
			orders.job_stage(JOB) == "missing" and hunt.fault_active())

	# Repair is impossible without the item: force the repairable stage with
	# an empty inventory through the public API, then interact.
	orders.issue_job(JOB, "reported")
	orders.acknowledge_job(JOB)
	orders.diagnose_job(JOB)
	orders.mark_job_awaiting_part(JOB)
	orders.mark_job_repairable(JOB)
	network.active_owner.interact(player)
	_check("repair is impossible without the capsule",
			orders.job_stage(JOB) == "repairable"
			and not inventory.is_consumed(ITEM))
	RealityState.reset_campaign_for_tests()

	# Only the correct chirping point advances the fault.
	network.activate("F02_A_BED_VANTRY_POINT")
	network.active_owner.interact(player)
	_check("a wrong grille is an ordinary inspection, not a diagnosis",
			orders.job_stage(JOB) == "missing")
	network.activate(POINT)

	# Reported origin, then the real inspection reveal.
	_check("Mina's report issues the job", hunt.report()
			and orders.job_stage(JOB) == "issued")
	network.active_owner.interact(player)
	var state := orders.job_state(JOB)
	_check("inspection converges, diagnoses and enters awaiting_part",
			orders.job_stage(JOB) == "awaiting_part"
			and state.evidence == ["chirping_point_located", "no_battery_bay",
					"carbon_capsule_failed"])
	_check("inspection no longer closes the job",
			orders.job_stage(JOB) != "closed" and hunt.fault_active())

	# The errand: proven customer threshold, production interact ray.
	var counter: Area3D = root.shop_service.counter(SHOP)
	_check("the shop counter stands ready", counter != null
			and counter.interact_prompt()
					== "[E]  Buy: Carbon transmitter capsule")
	var door = root.find_child("SITE_SHOP_DOOR_HARDWARE_PAINT", true, false)
	if door is DoorProp:
		door.npc_set_open(true)
	await get_tree().create_timer(0.6).timeout
	player.global_position = Vector3(10.44, 0.15, 58.425)
	player.velocity = Vector3.ZERO
	_check("the customer floor reaches the counter on foot",
			await _walk_to(Vector2(10.0, 58.1), "counter approach"))
	var eye := player.camera.global_position
	var at := counter.global_position
	player.camera.look_at(Vector3(at.x, minf(at.y, eye.y - 0.1), 57.2))
	player._try_interact()
	_check("the production buy acquires the capsule",
			inventory.has_item(ITEM))
	_check("acquisition advances awaiting_part to repairable",
			orders.job_stage(JOB) == "repairable")
	player._try_interact()
	_check("a second buy cannot duplicate the capsule",
			RealityState.data.maintenance_items.size() == 1
			and not inventory.is_consumed(ITEM))

	# Return to the point and perform the repair.
	_check("the point offers the replacement",
			network.active_owner.interact_prompt()
					== "[E]  Replace the carbon transmitter capsule")
	network.active_owner.interact(player)
	state = orders.job_state(JOB)
	_check("the repair enters repaired with recorded quality",
			orders.job_stage(JOB) == "repaired"
			and str(state.repair_result.quality) == "good")
	_check("the repair consumes the capsule exactly once",
			inventory.is_consumed(ITEM) and not inventory.has_item(ITEM))
	_check("the repaired point is quiet and secured",
			not hunt.fault_active()
			and network.active_owner.is_repaired()
			and float(network.active_owner.get_service_state().grille_open) == 0.0)
	_check("the job does not close automatically",
			orders.job_stage(JOB) == "repaired")
	_check("the repaired objective directs the player back to Mina",
			orders.job_library.stage_objective(JOB, "repaired").contains("Mina"))
	network.active_owner.interact(player)
	_check("a duplicate repair is rejected without mutation",
			orders.job_stage(JOB) == "repaired"
			and RealityState.data.maintenance_items.size() == 1)

	# The repaired state survives save/load.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(RealityState.data))
	RealityState.reset_campaign_for_tests()
	RealityState.data.merge(saved, true)
	state = orders.job_state(JOB)
	_check("repaired state, evidence, inventory and consumption survive save/load",
			orders.job_stage(JOB) == "repaired"
			and state.evidence.size() == 3
			and inventory.is_consumed(ITEM)
			and not hunt.fault_active())

	# K4: the coordinator carries the shift from repaired to wake on the
	# same production owners.
	var director: CoreLoopDirector = root.core_loop
	director.dream_requested.connect(
			func(_c: String, _p: String, _w: Dictionary) -> void:
				_dream_requests += 1)
	_check("the repair left the coordinator at conversation-pending",
			director.boundary() == "conversation_pending"
			and RealityState.case_state("mina_caption_crisis").repair_count == 1)
	RealityState.ensure_case("mina_caption_crisis", "mina_vale")
	RealityCases.record_conversation("mina_caption_crisis", "small_talk")
	_check("an ordinary conversation does not close the job",
			orders.job_stage(JOB) == "repaired")
	RealityCases.record_conversation(
			"mina_caption_crisis", "first_silence_named")
	_check("Mina's recurrence accepts a second stabilization",
			RealityCases.reopen_case("mina_caption_crisis")
			and RealityCases.stabilize_case("mina_caption_crisis"))
	player.call_locked = true
	RealityCases.record_conversation(
			"mina_caption_crisis", "assumptions_are_not_facts")
	_check("one resolution flag does not close an incomplete rule",
			orders.job_stage(JOB) == "repaired"
			and director.boundary() == "conversation_pending")
	RealityCases.record_conversation(
			"mina_caption_crisis", "silence_can_be_blank")
	_check("the complete rule closes the repaired job",
			orders.job_stage(JOB) == "closed"
			and director.boundary() == "conversation_complete")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("conversation alone cannot request the dream",
			_dream_requests == 0)
	_check("final integration arms the dream window",
			RealityCases.resolve_case("mina_caption_crisis")
			and director.boundary() == "dream_pending")
	await get_tree().process_frame
	_check("a protected integration suppresses dream entry",
			_dream_requests == 0)
	player.call_locked = false
	await get_tree().process_frame
	_check("the dream request follows once protection lifts",
			_dream_requests == 1)
	_check("wake completion accepts the boundary",
			director.notify_wake_complete())
	var anchor := director.resolve_return_anchor()
	_check("wake returns the real player to the authored 4B bedside",
			not anchor.is_empty()
			and player.global_position.distance_to(anchor.position) < 0.5)
	_check("wake preserves the committed shift and the quiet point",
			orders.job_stage(JOB) == "closed"
			and inventory.is_consumed(ITEM)
			and not hunt.fault_active()
			and network.active_owner.is_repaired())

	print("LOOP TRACE: origin=%s stage=%s boundary=%s evidence=%s repair=%s consumed=%s" % [
			state.get("origin"), orders.job_stage(JOB), director.boundary(),
			state.evidence, state.repair_result, inventory.is_consumed(ITEM)])
	print("[MAINTENANCE COUNTER] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
