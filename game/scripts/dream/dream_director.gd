class_name DreamDirector
extends Node
## N4's persistent scene-transition and dream-transaction owner.
##
## It receives the already-earned request from CoreLoopDirector, commits every
## transition before asking CampaignShell to replace a world, and reconciles a
## saved transaction forward. It owns no onset timing, topology, pursuit,
## hazard, case or work-order rules.

signal dream_armed(case_id: String, profile_id: String)
signal dream_entered(case_id: String, seed_hex: String)
signal dream_ended(case_id: String, outcome: String)
signal world_swap_requested(kind: String)

const CATALOG_PATH := "res://data/dream_module_catalog.json"
const PHASES: Array[String] = ["awake", "armed", "entered", "active",
		"return_pending"]
const OUTCOMES: Array[String] = ["capture", "fall", "contact"]

var core_loop: CoreLoopDirector


func setup(loop: CoreLoopDirector) -> void:
	core_loop = loop
	if not core_loop.dream_requested.is_connected(_on_dream_requested):
		core_loop.dream_requested.connect(_on_dream_requested)
	_state()


func phase() -> String:
	return str(_state().phase)


func dream_state() -> Dictionary:
	return _state().duplicate(true)


func context() -> Dictionary:
	var state := _state()
	return {
		"case_id": str(state.case_id),
		"profile_id": str(state.profile_id),
		"window": (state.window as Dictionary).duplicate(true),
		"seed_hex": str(state.seed_hex),
		"maze_revision": int(state.maze_revision),
		"outcome": str(state.outcome),
	}


## N5 will decide when an armed request may enter. N4 deliberately stops here
## in production until that owner calls enter_armed_dream().
func _on_dream_requested(case_id: String, profile_id: String,
		window: Dictionary) -> void:
	var state := _state()
	if str(state.phase) != "awake" or case_id.is_empty() \
			or profile_id.is_empty():
		return
	var revision := _catalog_revision()
	if revision <= 0:
		push_warning("dream module catalog has no valid revision")
		return
	var seed_hex := str(RealityState.data.get("dream_seed", ""))
	if not _valid_seed_hex(seed_hex):
		push_warning("campaign dream seed is not a nonzero 64-bit hex value")
		return
	state.phase = "armed"
	state.active = false
	state.case_id = case_id
	state.profile_id = profile_id
	state.window = window.duplicate(true)
	state.seed_hex = seed_hex
	state.maze_revision = revision
	state.outcome = ""
	RealityState.commit()
	dream_armed.emit(case_id, profile_id)


## Commit `entered` and the complete reconstruction identity before the waking
## world is touched. CampaignShell performs the swap on a deferred boundary.
func enter_armed_dream() -> bool:
	var state := _state()
	if str(state.phase) != "armed" or not _valid_seed_hex(str(state.seed_hex)) \
			or int(state.maze_revision) <= 0:
		return false
	state.phase = "entered"
	state.active = true
	RealityState.commit()
	world_swap_requested.emit("dream")
	return true


## Called only after DreamMazeRoot is the sole child of WorldSlot. Loading an
## active dream repeats this signal and restarts the run at D00 by contract;
## no live chase transform is restored.
func notify_dream_world_active() -> bool:
	var state := _state()
	if str(state.phase) not in ["entered", "active"]:
		return false
	if str(state.phase) == "entered":
		state.phase = "active"
		state.active = true
		RealityState.commit()
	dream_entered.emit(str(state.case_id), str(state.seed_hex))
	return true


## Outcome is committed while the dream is still the sole active world. The
## shell then rebuilds waking Orison; wake acceptance and residue happen there.
func end_dream(outcome: String) -> bool:
	var state := _state()
	if str(state.phase) != "active" or outcome not in OUTCOMES:
		return false
	state.phase = "return_pending"
	state.active = false
	state.outcome = outcome
	RealityState.commit()
	world_swap_requested.emit("waking")
	return true


## Clear return_pending last. A restored transaction may already have crossed
## the CoreLoop wake boundary; both paths reconcile to the same awake fact.
func complete_return() -> bool:
	var state := _state()
	if str(state.phase) != "return_pending" or core_loop == null:
		return false
	if core_loop.boundary() == "dream_pending":
		if not core_loop.notify_wake_complete():
			return false
	elif core_loop.boundary() != "wake_complete":
		return false
	state.phase = "awake"
	state.active = false
	RealityState.commit()
	dream_ended.emit(str(state.case_id), str(state.outcome))
	return true


func _catalog_revision() -> int:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is not Dictionary:
		return 0
	return int((parsed as Dictionary).get("meta", {}).get("version", 0))


func _valid_seed_hex(value: String) -> bool:
	return value.length() == 16 and value.is_valid_hex_number(false) \
			and value != "0000000000000000"


func _state() -> Dictionary:
	if not RealityState.data.has("dream") \
			or RealityState.data.dream is not Dictionary:
		RealityState.data.dream = {}
	var state: Dictionary = RealityState.data.dream
	state.merge({
		"phase": "awake",
		"active": false,
		"case_id": "",
		"profile_id": "",
		"window": {},
		"seed_hex": str(RealityState.data.get("dream_seed", "")),
		"maze_revision": 0,
		"outcome": "",
	})
	if str(state.phase) not in PHASES or state.window is not Dictionary:
		state.clear()
		state.merge({
			"phase": "awake", "active": false, "case_id": "",
			"profile_id": "", "window": {},
			"seed_hex": str(RealityState.data.get("dream_seed", "")),
			"maze_revision": 0, "outcome": "",
		})
	return state
