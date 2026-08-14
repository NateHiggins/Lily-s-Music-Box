class_name ChirpHunt
extends Node
## The one authored maintenance job's live customer: the failed Vantry
## fire/flood/listening head in 2A.
##
## Owner amendment (2026-08-14): inspection begins the repair loop rather
## than ending it. The no-battery discovery remains canonical — the grille
## drops, there is no battery bay, the Handbook is wrong — and what the
## opened interior actually shows is a failed carbon transmitter capsule.
## The replacement comes from the hardware counter in the Passage.
##
## Ownership: this node owns source selection, attributed chirping and
## fault-specific reactions, and drives the job exclusively through
## WorkOrders' public lifecycle contract. The prop owns its own service
## mechanism and repaired state; the shop and inventory own the errand.
##
## The fault is physical and predates its paperwork: the point chirps from
## the first minute whether or not a job is open, and falls silent only
## when the capsule is actually replaced.

const JOB_ID := "vantry_chirp_2a"
const LEGACY_ORDER_ID := "WO-VANTRY-001"
const REPAIR_NOTE := "capsule seated; contacts secured; line tested"

var network: VantryPointNetwork
var work_orders: WorkOrders
var inventory: MaintenanceInventory
var active_point_id := ""
var _running := false


func setup(points: VantryPointNetwork, spine: WorkOrders,
		items: MaintenanceInventory) -> void:
	network = points
	work_orders = spine
	inventory = items
	ChirpHunt.migrate_legacy(spine)
	active_point_id = _job_point()
	if active_point_id == "" \
			or network.point_spec(active_point_id).is_empty():
		push_warning("chirp job anchor missing: '%s'" % active_point_id)
		return
	network.activate(active_point_id)
	network.active_owner.bind_chirp_hunt(self)
	network.active_owner.inspected.connect(_on_inspected)
	if fault_active():
		_running = true
		_chirp_loop()
	else:
		network.active_owner.set_repaired()


## Saves from before the amendment carry the legacy simple order. Its three
## states map onto the authored lifecycle without losing progress: a closed
## legacy order means the player already found and opened the correct
## grille, which is the diagnosis — not the repair. Idempotent: once the
## legacy record is retired there is nothing left to migrate, and an
## existing authored job is never overwritten.
static func migrate_legacy(spine: WorkOrders) -> void:
	var status := spine.status(LEGACY_ORDER_ID)
	if status == "missing":
		return
	var stage: String = {"issued": "issued", "active": "acknowledged",
			"closed": "awaiting_part"}.get(status, "")
	var evidence: Array = []
	if stage == "awaiting_part" and spine.job_library:
		evidence = spine.job_library.job(JOB_ID).get(
				"evidence_flags", []).duplicate()
	if stage == "" \
			or not spine.adopt_job(JOB_ID, "reported", stage, evidence):
		if spine.job_stage(JOB_ID) == "missing":
			return
	spine.retire_order(LEGACY_ORDER_ID)


## Mina's reported origin. K4 routes her actual complaint; the entry point
## exists now so both beginnings share one stage machine.
func report() -> bool:
	return work_orders.issue_job(JOB_ID, "reported")


func fault_active() -> bool:
	return work_orders.job_stage(JOB_ID) not in ["repaired", "closed"]


func required_item() -> String:
	if work_orders.job_library == null:
		return ""
	return str(work_orders.job_library.job(JOB_ID).get("required_item_id", ""))


func prompt_for(point_id: String) -> String:
	if point_id != active_point_id:
		return "[E]  Inspect Vantry point"
	match work_orders.job_stage(JOB_ID):
		"missing", "issued", "acknowledged":
			return "[E]  Inspect the chirping Vantry point"
		"awaiting_part":
			return "[E]  Inspect Vantry point — it needs a carbon capsule"
		"repairable":
			if inventory and inventory.has_item(required_item()):
				return "[E]  Replace the carbon transmitter capsule"
			return "[E]  Inspect Vantry point — it needs a carbon capsule"
		_:
			return "[E]  Inspect Vantry point"


func force_chirp() -> void:
	if _running and fault_active():
		network.active_owner.play_chirp(1.0)


func relocate(point_id: String) -> bool:
	if not _running or not network.relocate_unseen(point_id):
		return false
	active_point_id = point_id
	return true


func _job_point() -> String:
	if work_orders.job_library == null:
		return ""
	return str(work_orders.job_library.job(JOB_ID).get("repair_target_id", ""))


func _chirp_loop() -> void:
	while _running and is_inside_tree():
		await get_tree().create_timer(
				network.active_owner.rng.randf_range(50.0, 95.0), false).timeout
		if _running and fault_active():
			network.active_owner.play_chirp(1.0)
			AcousticGraphData.propagate(active_point_id, 0, 1.0, 0.0)


func _on_inspected(point_id: String) -> void:
	# Only the correct chirping point advances the fault; every other grille
	# is an ordinary inspection.
	if point_id != active_point_id:
		return
	match work_orders.job_stage(JOB_ID):
		"missing":
			# Discovered origin: the player followed the chirp here first.
			if work_orders.issue_job(JOB_ID, "discovered") \
					and work_orders.acknowledge_job(JOB_ID):
				_diagnose()
		"issued":
			if work_orders.acknowledge_job(JOB_ID):
				_diagnose()
		"acknowledged":
			_diagnose()
		"repairable":
			_repair()


func _diagnose() -> void:
	# The reveal: no battery bay, and the mundane fault underneath it. The
	# evidence vocabulary is data-declared; recording is idempotent.
	if not work_orders.diagnose_job(JOB_ID):
		return
	for flag in work_orders.job_library.job(JOB_ID).get("evidence_flags", []):
		work_orders.record_job_evidence(JOB_ID, str(flag))
	work_orders.mark_job_awaiting_part(JOB_ID)


func _repair() -> void:
	# Open grille, remove the dead capsule, seat the new one, secure the
	# contacts, close and test. Impossible without the part; the part is
	# consumed exactly once; the job stops at repaired — closure is earned
	# in conversation, which K4 coordinates.
	var part := required_item()
	if inventory == null or not inventory.has_item(part):
		return
	if not inventory.consume(part):
		return
	if work_orders.record_job_repair(JOB_ID,
			{"quality": "good", "note": REPAIR_NOTE}):
		_running = false
		network.active_owner.set_repaired()
