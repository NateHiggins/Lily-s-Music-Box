extends Node
## DEV-COMP-1: the v2 root binds a TRUTHFUL presence provider to the
## observation ledger, and the beliefs it gates reconstruct across roots.
##
## Before this composition the ledger ran on its assume-home default
## (npc_observation_ledger.gd:107-110): every resident counted as standing
## in their own flat at the instant of every visible event, so Lena could
## earn a durable `in_home_sight` belief while her own authored timetable
## had her out on a corridor round. This suite exists to prove the gate is
## REAL — that it admits what she could see and refuses what she could not
## — rather than a provider that is bound but always says yes.
##
## The two clock positions below are authored facts, not test fixtures:
## res://data/resident_schedules.json puts lena_ortiz in `unit:bedroom`
## across 0-270 and on `corridor` across 300-345.

const Selector := preload("res://scripts/building/building_root_selector.gd")
const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")
const LENA := "lena_ortiz"
const OMAR := "omar_bell"
const RADIATOR_NODE := "F02_B_RADIATOR_01"
## Explicit campaign civil times; event provenance uses absolute minutes.
const HOME_MINUTE := 180.0
const CORRIDOR_MINUTE := 320.0
const RETURN_MINUTE := 350.0

var failures := 0
var passes := 0


func _ready() -> void:
	var old_clock_frozen := bool(CampaignTime.get("_frozen_for_tests"))
	CampaignTime.set_frozen_for_tests(true)
	var saved_persistence := RealityState.persistence_enabled
	var old_path := RealityState.save_path
	var save_path := "user://tests/v2_presence_ledger_save.json"
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://tests"))
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 10, int(HOME_MINUTE))
	var absolute_home := clock.absolute_minutes()
	RealityCases._ready()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}

	Selector.reset_for_tests("v2")
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	_check(not world.startup_failed, "v2 root starts with the ledger composed")

	# --- the composition itself -------------------------------------
	_check(world.observation_ledger != null
			and world.find_children("ObservationLedger", "", true, false).size() == 1,
			"exactly one observation ledger is composed under explicit v2")
	_check(world.resident_presence != null
			and not world.resident_presence.data.is_empty(),
			"the presence timetable loaded its authored resident data")
	_check(world.open_shift_ecosystem.ledger == world.observation_ledger,
			"the ecosystem adopts the root's ledger rather than minting its own")
	# The dispatch half must stay inert: v2 has no resident bodies, and a
	# timetable that tried to move them would be composing an absence.
	_check(world.resident_presence.routines == null,
			"the timetable is composed as a data authority, not a body dispatcher")

	# --- the gate does its real job ---------------------------------
	var situation = world.open_shift_ecosystem.situation
	_check(float(situation.state().offered_at) < 0.0,
			"ledger event proof starts with no active radiator situation")
	_check(absf(float(world.open_shift_ecosystem.now_minutes()) - absolute_home) < 0.00001,
			"the shared provider reads the configured absolute campaign minute")
	_check(world.resident_is_home(LENA),
			"Lena is home at 03:00, where her timetable puts her in bed")
	var seen_home := world.observation_ledger.witness_visible_state("2B",
			"saw_open_union", {"source_unit": "2B"})
	_check(seen_home == [LENA] and world.observation_ledger.has_learned(
			LENA, "saw_open_union"),
			"a change made while she is home is learned by in-home sight")

	# Advance the SAME durable clock the belief timestamps read, into her
	# authored corridor round. Nothing here teleports or mutates her.
	clock.advance_to(CORRIDOR_MINUTE - HOME_MINUTE)
	_check(absf(float(world.open_shift_ecosystem.now_minutes())
			- absolute_home - CORRIDOR_MINUTE + HOME_MINUTE) < 0.00001,
			"the campaign clock advanced to her corridor round")
	_check(not world.resident_is_home(LENA),
			"Lena is NOT home while her timetable has her on the corridor")
	var seen_out := world.observation_ledger.witness_visible_state("2B",
			"saw_tool_marks", {"source_unit": "2B"})
	_check(seen_out.is_empty() and not world.observation_ledger.has_learned(
			LENA, "saw_tool_marks"),
			"a change made while she is out is NOT learned by sight")

	# The acoustic fabric reaches flats; their residents must be there.
	_check(world.resident_is_home(OMAR), "Omar is home to hear the riser at 05:20")
	var heard := world.observation_ledger.witness_audible_event(
			RADIATOR_NODE, "riser_hammer_worsening",
			{"source_unit": "2B", "source": RADIATOR_NODE})
	_check(heard.has(OMAR) and world.observation_ledger.has_learned(
			OMAR, "heard_riser_hammer_worsening"),
			"the riser still reaches the present resident of 3B")

	# Provenance survives the gate: what she did learn by sight is stamped
	# with the minute at which she was actually there.
	var sight := _belief(world.observation_ledger.beliefs(LENA),
			"saw_open_union")
	_check(str(sight.get("channel", "")) == "in_home_sight"
			and str(sight.get("where", "")) == "2B"
			and absf(float(sight.get("at_minutes", -1.0)) - absolute_home) < 0.00001,
			"the sight belief is dated to the minute she was present")

	_check(not heard.has(LENA) and not world.observation_ledger.has_learned(
			LENA, "heard_riser_hammer_worsening"),
			"the absent resident gains no in-home hearing belief")
	clock.advance_to(RETURN_MINUTE - HOME_MINUTE)
	_check(world.resident_is_home(LENA), "Lena is back in her flat at 05:50")
	_check(not world.observation_ledger.has_learned(LENA, "heard_riser_hammer_worsening"),
			"coming home does not retroactively reveal the missed event")
	var returned := world.observation_ledger.witness_audible_event(
			RADIATOR_NODE, "hammer_after_return",
			{"source_unit": "2B", "source": RADIATOR_NODE})
	var hearing := _belief(world.observation_ledger.beliefs(LENA), "heard_hammer_after_return")
	_check(returned.has(LENA) and str(hearing.get("channel", "")) == "in_home_hearing"
			and str(hearing.get("where", "")) == "2B"
			and str(hearing.get("clock_basis", "")) == "campaign_absolute_minutes"
			and absf(float(hearing.get("at_minutes", -1.0))
					- absolute_home - RETURN_MINUTE + HOME_MINUTE) < 0.00001,
			"a new sound after return earns a correctly dated local hearing belief")

	# --- the facts reconstruct across BOTH roots --------------------
	RealityState.persistence_enabled = true
	RealityState.save_path = save_path
	var saved := RealityState.save_game()
	var expected := world.observation_ledger.beliefs(LENA)
	var omar_expected := world.observation_ledger.beliefs(OMAR)
	var shifted := expected.duplicate(true)
	shifted[0].at_minutes = float(shifted[0].at_minutes) + 1.0
	_check(not _same_beliefs(shifted, expected),
			"reconstruction comparison rejects even one minute of timestamp drift")
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	packed = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	PropAudio.clear_cache()

	_check(saved and await _reconstructs_under("v2", expected, omar_expected),
			"v2 save reconstructs the earned beliefs under v2")
	_check(await _reconstructs_under("v1", expected, omar_expected),
			"the same beliefs reconstruct under a v1 rollback")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = saved_persistence
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests()
	CampaignTime.set_frozen_for_tests(old_clock_frozen)
	_check(Selector.DEFAULT_ID == "v1", "committed selector remains v1")
	print("ORISON V2 PRESENCE LEDGER: %s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures,
			passes + failures])
	get_tree().quit(failures)


## Instantiate each real root after reload and read its actual ledger.
## The previous helper accepted root_id but never used it to compose a world.
func _reconstructs_under(root_id: String, lena_expected: Array,
		omar_expected: Array) -> bool:
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	Selector.reset_for_tests(root_id)
	var packed := load(Selector.scene_path()) as PackedScene
	var rebuilt := packed.instantiate() as Node3D
	add_child(rebuilt)
	await get_tree().physics_frame
	var rebuilt_ecosystem := rebuilt.get("open_shift_ecosystem") as Ecosystem
	var ledger: NpcObservationLedger
	if root_id == "v2":
		ledger = rebuilt.get("observation_ledger") as NpcObservationLedger
	else:
		var ecosystem: Object = rebuilt.get("open_shift_ecosystem")
		if ecosystem != null:
			ledger = ecosystem.get("ledger") as NpcObservationLedger
	var valid := not bool(rebuilt.get("startup_failed")) and is_instance_valid(ledger)
	valid = valid and rebuilt.scene_file_path == Selector.path_for(root_id)
	valid = valid and rebuilt_ecosystem != null \
			and float(rebuilt_ecosystem.situation.state().offered_at) < 0.0
	var lena_back: Array = ledger.beliefs(LENA) if valid else []
	var omar_back: Array = ledger.beliefs(OMAR) if valid else []
	valid = valid and _same_beliefs(lena_back, lena_expected) \
			and _same_beliefs(omar_back, omar_expected) \
			and not _has(lena_back, "saw_tool_marks") \
			and not _has(lena_back, "heard_riser_hammer_worsening")
	if rebuilt.has_method("shutdown_for_tests"):
		rebuilt.call("shutdown_for_tests")
	remove_child(rebuilt)
	rebuilt.free()
	packed = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	PropAudio.clear_cache()
	return valid


func _same_beliefs(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in range(actual.size()):
		for key in ["learned", "channel", "where", "clock_basis", "clock_schema_version"]:
			if actual[i].get(key) != expected[i].get(key):
				return false
		if absf(float(actual[i].get("at_minutes", -1))
				- float(expected[i].get("at_minutes", -2))) > 0.000001:
			return false
		if actual[i].get("evidence", {}) != expected[i].get("evidence", {}):
			return false
	return true


func _belief(beliefs: Array, learned: String) -> Dictionary:
	for belief in beliefs:
		if str(belief.get("learned", "")) == learned:
			return belief
	return {}


func _has(beliefs: Array, learned: String) -> bool:
	for belief in beliefs:
		if str(belief.get("learned", "")) == learned:
			return true
	return false


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("  PASS  ", label)
	else:
		failures += 1
		printerr("  FAIL  ", label)
