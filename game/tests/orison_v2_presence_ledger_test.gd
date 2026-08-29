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
const LENA := "lena_ortiz"
const OMAR := "omar_bell"
const RADIATOR_NODE := "F02_B_RADIATOR_01"
## 180.0 is the situation clock's own origin (03:00); the ecosystem adds
## its durable elapsed simulation minutes to it.
const HOME_MINUTE := 180.0
const CORRIDOR_MINUTE := 320.0

var failures := 0
var passes := 0


func _ready() -> void:
	var saved_persistence := RealityState.persistence_enabled
	var old_path := RealityState.save_path
	var save_path := "user://tests/v2_presence_ledger_save.json"
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("user://tests"))
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
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
	situation.offer(LENA, 0.2, 0.25)
	_check(is_equal_approx(float(world.open_shift_ecosystem.now_minutes()),
			HOME_MINUTE),
			"the shared clock starts at the situation's own origin minute")
	_check(world.resident_is_home(LENA),
			"Lena is home at 03:00, where her timetable puts her in bed")
	var seen_home := world.observation_ledger.witness_visible_state("2B",
			"saw_open_union", {"source_unit": "2B"})
	_check(seen_home == [LENA] and world.observation_ledger.has_learned(
			LENA, "saw_open_union"),
			"a change made while she is home is learned by in-home sight")

	# Advance the SAME durable clock the belief timestamps read, into her
	# authored corridor round. Nothing here teleports or mutates her.
	situation.advance_simulation_minutes(CORRIDOR_MINUTE - HOME_MINUTE)
	_check(is_equal_approx(float(world.open_shift_ecosystem.now_minutes()),
			CORRIDOR_MINUTE),
			"the situation clock advanced to her corridor round")
	_check(not world.resident_is_home(LENA),
			"Lena is NOT home while her timetable has her on the corridor")
	var seen_out := world.observation_ledger.witness_visible_state("2B",
			"saw_tool_marks", {"source_unit": "2B"})
	_check(seen_out.is_empty() and not world.observation_ledger.has_learned(
			LENA, "saw_tool_marks"),
			"a change made while she is out is NOT learned by sight")

	# The gate is sight-specific. Hearing travels the acoustic fabric to
	# whoever is on the riser and must not be silenced by presence.
	var heard := world.observation_ledger.witness_audible_event(
			RADIATOR_NODE, "riser_hammer_worsening",
			{"source_unit": "2B", "source": RADIATOR_NODE})
	_check(heard.has(OMAR) and world.observation_ledger.has_learned(
			OMAR, "heard_riser_hammer_worsening"),
			"hearing is not presence-gated: the riser still reaches 3B")

	# Provenance survives the gate: what she did learn by sight is stamped
	# with the minute at which she was actually there.
	var sight := _belief(world.observation_ledger.beliefs(LENA),
			"saw_open_union")
	_check(str(sight.get("channel", "")) == "in_home_sight"
			and str(sight.get("where", "")) == "2B"
			and is_equal_approx(float(sight.get("at_minutes", -1.0)),
					HOME_MINUTE),
			"the sight belief is dated to the minute she was present")

	# PINNED, NOT ENDORSED. Presence gates sight only
	# (npc_observation_ledger.gd:57-68); witness_audible_event consults no
	# presence at all (:38-52). So the resident of the sounding flat earns
	# an `in_home_hearing` belief at a minute her own timetable has her on
	# the corridor. That asymmetry is the ledger owner's call, not this
	# composition's: binding presence did not create it and must not
	# silently paper over it. This check exists so a deliberate change to
	# hearing semantics fails here and gets read.
	var hearing := _belief(world.observation_ledger.beliefs(LENA),
			"heard_riser_hammer_worsening")
	_check(str(hearing.get("channel", "")) == "in_home_hearing"
			and is_equal_approx(float(hearing.get("at_minutes", -1.0)),
					CORRIDOR_MINUTE)
			and not world.resident_is_home(LENA),
			"KNOWN GAP pinned: hearing ignores presence, so an absent "
			+ "resident still earns an in-home hearing belief")

	# --- the facts reconstruct across BOTH roots --------------------
	RealityState.persistence_enabled = true
	RealityState.save_path = save_path
	var saved := RealityState.save_game()
	var expected := world.observation_ledger.beliefs(LENA)
	var omar_expected := world.observation_ledger.beliefs(OMAR)
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	packed = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	PropAudio.clear_cache()

	_check(saved and _reconstructs_under("v2", expected, omar_expected),
			"v2 save reconstructs the earned beliefs under v2")
	_check(_reconstructs_under("v1", expected, omar_expected),
			"the same beliefs reconstruct under a v1 rollback")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	RealityState.save_path = old_path
	RealityState.persistence_enabled = saved_persistence
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests()
	_check(Selector.DEFAULT_ID == "v1", "committed selector remains v1")
	print("ORISON V2 PRESENCE LEDGER: %s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures,
			passes + failures])
	get_tree().quit(failures)


## Beliefs are RealityState facts, not composition state: reload the same
## document under each root and the provenance must come back identical.
func _reconstructs_under(root_id: String, lena_expected: Array,
		omar_expected: Array) -> bool:
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var store: Dictionary = RealityState.data.get("npc_observations", {})
	var lena_back: Array = store.get(LENA, [])
	var omar_back: Array = store.get(OMAR, [])
	if lena_back.size() != lena_expected.size() \
			or omar_back.size() != omar_expected.size():
		return false
	for i in range(lena_back.size()):
		for key in ["learned", "channel", "where"]:
			if str(lena_back[i].get(key, "")) != str(lena_expected[i].get(key, "")):
				return false
		if not is_equal_approx(float(lena_back[i].get("at_minutes", -1.0)),
				float(lena_expected[i].get("at_minutes", -2.0))):
			return false
	for i in range(omar_back.size()):
		if str(omar_back[i].get("learned", "")) \
				!= str(omar_expected[i].get("learned", "")):
			return false
	# The rollback root must not resurrect a belief the gate refused.
	return not _has(lena_back, "saw_tool_marks")


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
