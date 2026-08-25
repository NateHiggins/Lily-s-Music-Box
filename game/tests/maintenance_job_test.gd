extends Node
## K2 focused proof: the data-authored maintenance-job contract.
##
## Exercises the real owners — the MaintenanceJobLibrary boundary, the real
## WorkOrders node and the real ObjectiveTracker over the RealityState
## autoload — with no mocks. Prints a deterministic lifecycle trace; the
## production-scene wiring is proven separately by WalkTest.

const JOB := ChirpHunt.JOB_ID

var failures := 0
var trace: Array[String] = []
var work_orders: WorkOrders
var tracker: ObjectiveTracker


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var library := MaintenanceJobLibrary.load_default()
	_check(library.is_valid(), "maintenance_jobs.json loads and validates")
	_check(library.job_ids() == ([ServiceRoundDirector.JOB_ID, JOB]
			as Array[String]),
			"the chirp and first Service Round are the two authored jobs (%s)"
			% [library.job_ids()])
	_check(not library.has_job("steam_hammer_2a"),
			"steam_hammer_2a is no longer the active graybox job")
	_check(library.requires_part(JOB)
			and str(library.job(JOB).required_item_id)
					== "carbon_transmitter_capsule"
			and str(library.job(JOB).repair_target_id)
					== "F02_A_MAIN_VANTRY_POINT"
			and str(library.job(JOB).case_id) == "mina_caption_crisis",
			"required item, 2A Vantry anchor and case binding are data-authored")
	_check(not str(library.job(JOB).required_item_id).contains("battery"),
			"the required part is a carbon capsule, never a battery")
	_check(str(library.job(JOB).dream_window.eligible_after_stage) == "repaired",
			"eligible dream window is metadata only")
	_check(not library.requires_part(ServiceRoundDirector.JOB_ID)
			and str(library.job(ServiceRoundDirector.JOB_ID).resident_id)
					== "lena_ortiz"
			and library.job(ServiceRoundDirector.JOB_ID).anchor_ids == [
				"F02_B_RADIATOR_01", "LobbyPorterBoard", "B1_BOILER_01"],
			"the resident-filed round authors Lena and all three travel anchors")

	tracker = ObjectiveTracker.new()
	add_child(tracker)
	work_orders = WorkOrders.new()
	work_orders.setup(tracker)
	work_orders.bind_job_library(library)
	add_child(work_orders)
	work_orders.job_stage_changed.connect(
			func(_id: String, from: String, to: String, _state: Dictionary) -> void:
				trace.append("%s->%s" % [from if from != "" else "(issue)", to]))

	_reported_lifecycle()
	var reported_trace := trace.duplicate()
	_discovered_convergence(reported_trace)
	_serialization_roundtrip()
	_legacy_migration_checks()
	_legacy_orders_unchanged()

	print("LIFECYCLE TRACE: ", " | ".join(reported_trace))
	print("MAINTENANCE JOB TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _reported_lifecycle() -> void:
	_check(not work_orders.issue_job(JOB, "telegram"),
			"unknown origin is rejected")
	_check(not work_orders.issue_job("missing_job", "reported"),
			"unauthored job id is rejected")
	_check(work_orders.issue_job(JOB, "reported"), "reported origin issues")
	_check(not work_orders.issue_job(JOB, "discovered"),
			"duplicate issue is rejected without mutation")
	_check(work_orders.job_stage(JOB) == "issued", "job opens at issued")
	var state := work_orders.job_state(JOB)
	_check(not state.has("title") and not state.has("objective")
			and not state.has("required_item_id"),
			"job state carries facts only; definition text stays in data")

	_check(not work_orders.diagnose_job(JOB)
			and not work_orders.mark_job_awaiting_part(JOB)
			and not work_orders.mark_job_repairable(JOB)
			and not work_orders.record_job_repair(JOB, {"quality": "good"})
			and not work_orders.close_job(JOB)
			and work_orders.job_stage(JOB) == "issued",
			"every skip from issued is rejected without mutation")

	_check(work_orders.acknowledge_job(JOB), "acknowledgement converges the origins")
	_check(not work_orders.acknowledge_job(JOB),
			"duplicate acknowledgement is safe")
	_check(work_orders.record_job_evidence(JOB, "chirping_point_located"),
			"declared evidence flag records")
	_check(not work_orders.record_job_evidence(JOB, "chirping_point_located"),
			"duplicate evidence is safe")
	_check(not work_orders.record_job_evidence(JOB, "poltergeist_seen"),
			"undeclared evidence flag is rejected")
	_check(work_orders.diagnose_job(JOB), "diagnosis follows acknowledgement")
	_check(not work_orders.diagnose_job(JOB), "duplicate diagnosis is safe")
	_check(not work_orders.acknowledge_job(JOB),
			"backwards transition is rejected")
	_check(not work_orders.mark_job_repairable(JOB),
			"a job that needs a part cannot skip awaiting_part")
	_check(work_orders.mark_job_awaiting_part(JOB), "part need opens awaiting_part")
	_check(work_orders.mark_job_repairable(JOB), "part arrival makes it repairable")
	_check(not work_orders.record_job_repair(JOB, {"quality": "heroic"}),
			"repair quality outside the vocabulary is rejected")
	_check(work_orders.record_job_repair(JOB,
			{"quality": "good", "note": "capsule seated; line tested"}),
			"repair records result and quality")
	_check(not work_orders.record_job_repair(JOB, {"quality": "good"}),
			"duplicate repair is safe")
	_check(str(work_orders.job_state(JOB).repair_result.quality) == "good",
			"practical repair result is stored")
	_check(work_orders.close_job(JOB), "repaired closes")
	_check(not work_orders.acknowledge_job(JOB)
			and not work_orders.record_job_evidence(JOB, "no_battery_bay")
			and not work_orders.record_job_repair(JOB, {"quality": "fair"})
			and work_orders.job_stage(JOB) == "closed",
			"a closed job accepts nothing further")
	var expected: Array[String] = ["(issue)->issued", "issued->acknowledged",
			"acknowledged->diagnosed", "diagnosed->awaiting_part",
			"awaiting_part->repairable", "repairable->repaired",
			"repaired->closed"]
	_check(trace == expected, "stage-change signal traces the full legal order")


func _discovered_convergence(reported_trace: Array[String]) -> void:
	RealityState.reset_campaign_for_tests()
	trace.clear()
	_check(work_orders.issue_job(JOB, "discovered"), "discovered origin issues")
	_check(work_orders.acknowledge_job(JOB), "discovered origin acknowledges")
	var state := work_orders.job_state(JOB)
	_check(str(state.origin) == "discovered" and str(state.stage) == "acknowledged",
			"origin survives as recorded history only")
	_check(work_orders.diagnose_job(JOB)
			and work_orders.mark_job_awaiting_part(JOB)
			and work_orders.mark_job_repairable(JOB)
			and work_orders.record_job_repair(JOB, {"quality": "fair"})
			and work_orders.close_job(JOB),
			"discovered origin runs the identical downstream lifecycle")
	_check(trace == reported_trace,
			"both beginnings converge on one stage machine, not two systems")


func _serialization_roundtrip() -> void:
	RealityState.reset_campaign_for_tests()
	trace.clear()
	work_orders.issue_job(JOB, "reported")
	work_orders.acknowledge_job(JOB)
	work_orders.record_job_evidence(JOB, "no_battery_bay")
	work_orders.diagnose_job(JOB)
	work_orders.mark_job_awaiting_part(JOB)
	var payload := work_orders.serialize_jobs()
	_check(not JSON.stringify(payload).contains("hardware counter"),
			"serialized contract carries no objective text")
	tracker.clear()
	RealityState.reset_campaign_for_tests()
	_check(work_orders.job_stage(JOB) == "missing",
			"fresh campaign forgets the job")
	_check(work_orders.restore_jobs(payload), "state contract restores")
	var state := work_orders.job_state(JOB)
	_check(str(state.stage) == "awaiting_part"
			and str(state.origin) == "reported"
			and state.evidence == ["no_battery_bay"]
			and (state.repair_result as Dictionary).is_empty(),
			"restoration preserves every authoritative K2 fact")
	_check(tracker._title.text == "WORK ORDER 001 — THE CHIRP"
			and tracker._objective.text.contains("carbon transmitter capsule"),
			"objective presentation is reconstructed from data, not persisted")
	_check(not work_orders.restore_jobs({"jobs": {"missing_job": state}}),
			"restore rejects a job the data does not author")
	_check(not work_orders.restore_jobs(
			{"jobs": {JOB: {"stage": "shipped", "origin": "reported",
				"evidence": [], "repair_result": {}}}}),
			"restore rejects an unknown stage")
	_check(work_orders.mark_job_repairable(JOB)
			and work_orders.record_job_repair(JOB, {"quality": "poor"})
			and work_orders.close_job(JOB),
			"a restored job continues its lifecycle")


func _legacy_migration_checks() -> void:
	const LEGACY := ChirpHunt.LEGACY_ORDER_ID
	# Legacy issued -> equivalent open authored job.
	RealityState.reset_campaign_for_tests()
	work_orders.issue(LEGACY, "T", "O", "Orison house circuit")
	ChirpHunt.migrate_legacy(work_orders)
	_check(work_orders.job_stage(JOB) == "issued"
			and work_orders.status(LEGACY) == "missing",
			"legacy issued migrates to an open authored job and retires")
	var before := work_orders.job_state(JOB)
	ChirpHunt.migrate_legacy(work_orders)
	_check(work_orders.job_state(JOB) == before,
			"migration is idempotent once the legacy record is gone")
	# Legacy active -> acknowledged.
	RealityState.reset_campaign_for_tests()
	work_orders.issue(LEGACY, "T", "O", "Orison house circuit")
	work_orders.activate(LEGACY)
	ChirpHunt.migrate_legacy(work_orders)
	_check(work_orders.job_stage(JOB) == "acknowledged"
			and work_orders.status(LEGACY) == "missing",
			"legacy active migrates to acknowledged")
	# Legacy closed: the player already opened the correct grille — that is
	# the diagnosis, not the repair.
	RealityState.reset_campaign_for_tests()
	work_orders.issue(LEGACY, "T", "O", "Orison house circuit")
	work_orders.activate(LEGACY)
	work_orders.close(LEGACY)
	ChirpHunt.migrate_legacy(work_orders)
	var state := work_orders.job_state(JOB)
	_check(str(state.stage) == "awaiting_part"
			and state.evidence == ["chirping_point_located", "no_battery_bay",
					"carbon_capsule_failed"]
			and work_orders.status(LEGACY) == "missing",
			"legacy closed-by-inspection migrates to awaiting_part, not repaired")
	# A stale legacy record beside an already-authored job is retired without
	# clobbering the job's progress.
	work_orders.mark_job_repairable(JOB)
	work_orders.issue(LEGACY, "T", "O", "Orison house circuit")
	ChirpHunt.migrate_legacy(work_orders)
	_check(work_orders.job_stage(JOB) == "repairable"
			and work_orders.status(LEGACY) == "missing",
			"migration never overwrites an existing authored job")


func _legacy_orders_unchanged() -> void:
	RealityState.reset_campaign_for_tests()
	_check(work_orders.issue("WO-TEST-001", "TEST ORDER", "Do the thing.")
			and work_orders.status("WO-TEST-001") == "issued"
			and work_orders.activate("WO-TEST-001")
			and work_orders.is_active("WO-TEST-001")
			and work_orders.close("WO-TEST-001")
			and work_orders.status("WO-TEST-001") == "closed"
			and not work_orders.activate("WO-TEST-001"),
			"the minimal order contract for the 4B clock remains unchanged")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [job ok] ", label)
	else:
		failures += 1
		printerr("  [JOB FAIL] ", label)
