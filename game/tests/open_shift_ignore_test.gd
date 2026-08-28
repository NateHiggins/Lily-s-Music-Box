extends Node
## IGNORE disposition: neglect produces continued world state through the
## real chain of authorities. The mechanism worsens itself, the acoustic
## fabric decides who heard it, the porter actor forms an intention,
## travels, inspects and performs the shutoff himself, and every belief
## carries provenance. Elapsed time only ever makes actors eligible.

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 300.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var orders := WorkOrders.new()
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	_close_previous(orders)
	var radiator := RadiatorProp.new()
	radiator.name = ServiceRoundDirector.RADIATOR_ID
	radiator.prop_type = "radiator"
	add_child(radiator)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(orders, radiator, null, func(): return minute)
	ecosystem._process(0.0)
	var offered_at := float(ecosystem.situation.state().offered_at)
	_check(offered_at >= 0.0, "closed prior work lets the situation offer")
	_check(not ecosystem.ledger.has_learned("omar_bell",
			"heard_riser_hammer_worsening"),
			"knowledge is absent before any observable event")
	minute = 306.0
	ecosystem.advance_autonomy()
	_check(radiator.open_shift_condition == "worsening_hammer",
			"the mechanism owns its own degradation")
	_check(ecosystem.ledger.has_learned("omar_bell",
			"heard_riser_hammer_worsening"),
			"the riser neighbor hears through the acoustic fabric")
	var omar := ecosystem.ledger.beliefs("omar_bell")
	_check(not omar.is_empty() and
			str(omar[0].channel) == "heating_riser" and
			str(omar[0].where) == "3B",
			"the neighbor's belief carries channel and place provenance")
	minute = 313.0
	ecosystem.advance_autonomy()
	var porter := ecosystem.porter.state()
	_check(str(porter.intent) == "riser_complaint",
			"elapsed time makes the porter ELIGIBLE, nothing more")
	_check(float(porter.acted_at) < 0.0 and
			radiator.open_shift_condition == "worsening_hammer",
			"eligibility alone performs no intervention")
	minute = 316.0
	ecosystem.advance_autonomy()
	porter = ecosystem.porter.state()
	_check(float(porter.departed_at) >= 0.0 and
			float(porter.arrived_at) < 0.0,
			"the porter departs after finishing his board round")
	minute = 321.0
	ecosystem.advance_autonomy()
	porter = ecosystem.porter.state()
	_check(float(porter.arrived_at) ==
			float(porter.departed_at) + PorterActor.TRAVEL_MINUTES,
			"arrival lands exactly at the scheduled transit time")
	_check(ecosystem.ledger.has_learned(PorterActor.NPC_ID,
			"found_unresolved_fault"),
			"the porter's knowledge comes from his own inspection")
	minute = 323.0
	ecosystem.advance_autonomy()
	porter = ecosystem.porter.state()
	var state := ecosystem.situation.state()
	_check(radiator.open_shift_condition == "porter_temporary_shutoff",
			"the porter performs the shutoff through the mechanism")
	_check(state.resolution_kind == "porter_temporary_shutoff" and
			state.residue.evidence == "porter_tag_on_valve",
			"the situation records the actor's reported outcome")
	_check(state.compensator == "porter",
			"compensation intent was recorded at dispatch")
	_check(ecosystem.ledger.has_learned(
			ServiceRoundDirector.RESIDENT_ID, "porter_shut_heat_off"),
			"the resident learns from the tag in her own flat")
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "missing",
			"no job was invented on the player's behalf")
	_check(not state.has("npc_knowledge"),
			"no coordinator-authored belief exists anywhere")
	# Reconstruction: a fresh mechanism rebind reapplies the durable
	# outcome without the porter acting twice.
	var acted_once := float(porter.acted_at)
	var rebuilt := RadiatorProp.new()
	rebuilt.prop_type = "radiator"
	add_child(rebuilt)
	var second := Ecosystem.new()
	add_child(second)
	second.setup(orders, rebuilt, null, func(): return minute)
	_check(rebuilt.open_shift_condition == "porter_temporary_shutoff",
			"reconstruction reapplies the porter's durable outcome")
	_check(float(second.porter.state().acted_at) == acted_once,
			"the porter never re-performs his action")
	print("OPEN SHIFT IGNORE TEST: %s" %
			("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)


func _close_previous(orders: WorkOrders) -> void:
	var job := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(job, "reported")
	orders.acknowledge_job(job)
	orders.diagnose_job(job)
	orders.mark_job_awaiting_part(job)
	orders.mark_job_repairable(job)
	orders.record_job_repair(job, {"quality": "good", "note": "done"})
	orders.close_job(job)
