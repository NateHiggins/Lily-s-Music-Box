extends Node
## LC-3A / LC-4A — addressable accelerated cohorts and visit-persistent stain
## memory, proved mechanically in the production Dream maze root.
##
##     godot --headless --path game res://tests/DreamFaunaLifecycleTest.tscn
##
## This suite deliberately makes NO visual claim. A packed flag changing is not
## evidence that a stage reads on screen; every assertion here is about
## identity, ordering, boundedness and ownership. The visible LC-4/LC-5 pass is
## Codex's after integration.
##
## Everything is CONSTRUCTED and driven. The room lifecycle is a slow clock --
## a full life is 45 to 150 seconds -- so waiting for a cohort to die on the
## simulation's own schedule would be an assertion about how long the test ran.
## The room's lifecycle progress is set directly and `refresh()` is called by
## hand, which is also what keeps the pocket from restreaming underneath it.

const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": "f123456789abcdef", "maze_revision": 1,
			"outcome": "", "night_index": 1, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	var fauna = root.fauna
	fauna.set_physics_process(false)
	fauna.refresh()

	# Everything the slice promises not to move.
	var plan_before := var_to_bytes(root.plan)
	var save_before := var_to_bytes(RealityState.data)
	var hazards_before := _hazard_signature(root.hazards)
	var nodes_before: int = fauna.find_children("*", "", true, false).size()
	var scene_nodes_before: int = root.find_children("*", "", true, false).size()

	_addresses(fauna)
	_stagger_and_stages(fauna)
	_reproduction_modes(fauna)
	await _stains(fauna, root)
	_eviction_determinism()
	_no_inherited_stains()
	_ownership(fauna, root, plan_before, save_before, hazards_before,
			nodes_before, scene_nodes_before)
	_finish()


# --- LC-3A ------------------------------------------------------------------

func _addresses(fauna) -> void:
	var batches := ["GildersButtons", "Tessellates", "WineAnemones",
			"Ribbonettes", "TheLoupe"]
	# EVERY REALIZED SLOT, not every family. Ribbonettes realize zero while
	# uptake is under 0.28 and TheLoupe realizes at most one, so demanding a
	# non-empty batch would be asserting the density model rather than the
	# addressing. The invariant is that addresses and derived lives line up
	# one-for-one with what was actually submitted, in every batch.
	var every_family := true
	var addressed := 0
	var realized_families := 0
	var per_batch: Array[String] = []
	for batch_name in batches:
		var addresses: PackedStringArray = fauna.addresses_for_batch(batch_name)
		var rows: Dictionary = fauna.get("_records").get(batch_name, {})
		var submitted: int = (rows.get("custom", []) as Array).size()
		var lives: int = (rows.get("life", []) as Array).size()
		addressed += addresses.size()
		per_batch.append("%s=%d/%d" % [batch_name, addresses.size(), submitted])
		if addresses.size() != submitted or lives != submitted:
			every_family = false
		if submitted > 0:
			realized_families += 1
	_check("every realized slot carries an address and a derived life (%s)"
			% " ".join(per_batch),
			every_family and addressed > 0 and realized_families >= 3)

	# Addresses parse back to exactly the four facts they encode.
	var sample: PackedStringArray = fauna.addresses_for_batch("Tessellates")
	var parsed_ok := not sample.is_empty()
	for address in sample:
		var parsed: Dictionary = DreamFaunaDirector.parse_cohort_address(address)
		parsed_ok = parsed_ok and not parsed.is_empty() \
				and int(parsed.motif) == 1 \
				and int(parsed.slot) >= 0 \
				and int(parsed.generation) >= 0 \
				and not str(parsed.room_key).is_empty() \
				and DreamFaunaDirector.cohort_address(str(parsed.room_key),
						int(parsed.motif), int(parsed.slot),
						int(parsed.generation)) == address
	_check("an address round-trips room, family, slot and generation",
			parsed_ok)

	# STABILITY. Two refreshes with no time advanced must produce the same
	# names for the same tissue.
	var before := {}
	for batch_name in batches:
		before[batch_name] = fauna.addresses_for_batch(batch_name)
	var realization_before: String = fauna.realization_signature()
	fauna.refresh()
	var stable: bool = fauna.realization_signature() == realization_before
	for batch_name in batches:
		stable = stable and fauna.addresses_for_batch(batch_name) 				== before[batch_name]
	_check("refresh preserves both realization and every address", stable)

	# Lookup and bounded enumeration.
	var one: String = sample[0] if not sample.is_empty() else ""
	var found: Dictionary = fauna.cohort_at(one)
	_check("an address resolves to its own live slot",
			not one.is_empty() and not found.is_empty()
			and str(found.address) == one
			and str(found.batch) == "Tessellates"
			and int(found.motif) == 1)
	_check("an unrealized address resolves to nothing rather than guessing",
			fauna.cohort_at("no/such/9#9").is_empty()
			and fauna.cohort_at("").is_empty())
	var room_key := str(DreamFaunaDirector.parse_cohort_address(one).room_key)
	var in_room: Array = fauna.cohorts_in_room(room_key)
	var of_family: Array = fauna.cohorts_of_family(1)
	var bounded: Array = fauna.cohorts_in_room(room_key, 2)
	var room_ok := not in_room.is_empty() and bounded.size() <= 2
	for row in in_room:
		room_ok = room_ok and str(row.room_key) == room_key
	var family_ok := not of_family.is_empty()
	for row in of_family:
		family_ok = family_ok and int(row.motif) == 1
	_check("enumeration is filtered and bounded (%d room, %d family, %d capped)"
			% [in_room.size(), of_family.size(), bounded.size()],
			room_ok and family_ok)


# --- accelerated staggered cohorts -----------------------------------------

func _stagger_and_stages(fauna) -> void:
	# NOT IN LOCKSTEP. Two slots of one family in one room must be able to
	# occupy different stages at the same instant.
	var densities: Dictionary = fauna.get("_densities")
	var room_key := ""
	for key in densities:
		room_key = str(key)
		break
	var life: Dictionary = (densities[room_key] as Dictionary).lifecycle
	var differing := false
	var pairs := 0
	for slot in 8:
		var a: Dictionary = DreamFaunaDirector.cohort_state(life, 1, slot)
		var b: Dictionary = DreamFaunaDirector.cohort_state(life, 1, slot + 1)
		pairs += 1
		if int(a.stage) != int(b.stage):
			differing = true
	_check("staggered slots occupy different stages (%d pairs sampled)" % pairs,
			differing)

	# ALL EIGHT STAGES REACHABLE, and none of them scales anatomy to zero.
	# The room clock is swept rather than waited on.
	var seen := {}
	var scale_ok := true
	var probe: Dictionary = life.duplicate(true)
	for step in 400:
		probe.progress = float(step) / 400.0
		for motif in 5:
			for slot in 6:
				var st: Dictionary = DreamFaunaDirector.cohort_state(
						probe, motif, slot)
				seen[int(st.stage)] = true
				scale_ok = scale_ok and float(st.anatomy_scale) == 1.0
	_check("all eight stages are mechanically reachable (%d/8)" % seen.size(),
			seen.size() == 8)
	_check("no stage scales anatomy from zero", scale_ok)

	# The two presentation flags are the landed ones, on the ruled stages.
	var flag_ok := DreamFaunaDirector.stage_flags(Lifecycle.Stage.BUD) \
					== DreamFaunaChannels.FLAG_BIRTHING \
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.JUVENILE) \
					== DreamFaunaChannels.FLAG_BIRTHING \
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.SHED) \
					== DreamFaunaChannels.FLAG_REABSORBING \
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.STAIN) \
					== DreamFaunaChannels.FLAG_REABSORBING \
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.MATURE) == 0 \
			and DreamFaunaDirector.stage_flags(Lifecycle.Stage.EXCHANGE) == 0
	_check("BUD/JUVENILE reuse BIRTHING and SHED/STAIN reuse REABSORBING",
			flag_ok)

	# Progress and generation stay continuous across a room wrap: a slot must
	# not jump backwards when the room it belongs to begins a new life.
	var late: Dictionary = life.duplicate(true)
	late.progress = 0.999
	late.generation = 4
	var wrapped: Dictionary = life.duplicate(true)
	wrapped.progress = 0.001
	wrapped.generation = 5
	var continuous := true
	for slot in 12:
		var before: Dictionary = DreamFaunaDirector.cohort_state(late, 1, slot)
		var after: Dictionary = DreamFaunaDirector.cohort_state(wrapped, 1, slot)
		continuous = continuous and int(after.generation) >= int(before.generation)
		if int(after.generation) == int(before.generation):
			continuous = continuous and float(after.progress) >= float(before.progress)
	_check("a room wrap never runs a slot's life backwards", continuous)


func _reproduction_modes(fauna) -> void:
	# All three modes must leave the receiving family's function untouched.
	# Only genome/affinity derivation may move.
	var densities: Dictionary = fauna.get("_densities")
	var room_key := ""
	for key in densities:
		room_key = str(key)
		break
	var base: Dictionary = (densities[room_key] as Dictionary).lifecycle
	var modes := [Lifecycle.Reproduction.ASEXUAL, Lifecycle.Reproduction.SEXUAL,
			Lifecycle.Reproduction.PANSEXUAL]
	var function_held := true
	var salt_moved := true
	for mode in modes:
		var probe: Dictionary = base.duplicate(true)
		probe.reproduction = mode
		for motif in 5:
			var st: Dictionary = DreamFaunaDirector.cohort_state(probe, motif, 2)
			var quiet: Dictionary = DreamFaunaDirector.cohort_state(base, motif, 2)
			# Function-bearing facts are identical across every mode.
			function_held = function_held \
					and int(st.stage) == int(quiet.stage) \
					and int(st.generation) == int(quiet.generation) \
					and int(st.flags) == int(quiet.flags) \
					and is_equal_approx(float(st.progress), float(quiet.progress)) \
					and float(st.anatomy_scale) == 1.0
		salt_moved = salt_moved and DreamFaunaDirector._genome_salt(1.0, mode) \
				!= DreamFaunaDirector._genome_salt(1.0,
						Lifecycle.Reproduction.QUIESCENT)
	_check("asexual, sexual and pansexual cohorts keep the receiving family's "
			+ "stage, generation, flags and scale", function_held)
	_check("reproduction moves only the cosmetic genome salt", salt_moved)


# --- LC-4A ------------------------------------------------------------------

func _stains(fauna, root) -> void:
	var empty_at_start: Dictionary = fauna.stain_census()
	var densities: Dictionary = fauna.get("_densities")
	var room_key := ""
	for key in densities:
		room_key = str(key)
		break

	# WITNESS A DEATH. Push this room's lifecycle one whole generation on and
	# refresh: every slot in it has completed a life, so each leaves one
	# impression and each address gains a generation.
	var before_addresses: PackedStringArray = fauna.addresses_for_batch("Tessellates")
	var state: Dictionary = densities[room_key]
	var life: Dictionary = state.lifecycle
	life.generation = int(life.generation) + 1
	state.lifecycle = life
	fauna.refresh()
	var after_addresses: PackedStringArray = fauna.addresses_for_batch("Tessellates")
	var generation_moved := false
	for i in mini(before_addresses.size(), after_addresses.size()):
		var was: Dictionary = DreamFaunaDirector.parse_cohort_address(
				before_addresses[i])
		var now: Dictionary = DreamFaunaDirector.parse_cohort_address(
				after_addresses[i])
		if str(was.lineage) == str(now.lineage) \
				and int(now.generation) > int(was.generation):
			generation_moved = true
	_check("a completed life renames the slot's cohort generation",
			generation_moved)

	var stains: Array = fauna.stains_in_room(room_key)
	var impression_ok := not stains.is_empty()
	for impression in stains:
		var parent: Dictionary = DreamFaunaDirector.parse_cohort_address(
				str(impression.parent))
		impression_ok = impression_ok \
				and str(impression.room_key) == room_key \
				and int(impression.motif) >= 0 and int(impression.motif) <= 4 \
				and impression.at is Vector3 \
				and impression.genome is Vector2 \
				and int(impression.deaths) >= 1 \
				and not parent.is_empty() \
				and str(parent.room_key) == room_key \
				and int(parent.motif) == int(impression.motif) \
				and int(parent.slot) == int(impression.slot)
	_check("a witnessed death records room, position, motif, parent address "
			+ "and a genome trace (%d impressions)" % stains.size(),
			int(empty_at_start.total) == 0 and impression_ok)

	# COALESCE. Many more deaths on the same lineages must not grow the record.
	var after_first: int = int(fauna.stain_census().total)
	for _round in 12:
		var s2: Dictionary = densities[room_key]
		var l2: Dictionary = s2.lifecycle
		l2.generation = int(l2.generation) + 1
		s2.lifecycle = l2
		fauna.refresh()
	var coalesced: Dictionary = fauna.stain_census()
	var deaths_counted := 0
	for impression in fauna.stains_in_room(room_key):
		deaths_counted += int(impression.deaths)
	_check("repeated deaths coalesce instead of growing corpse records "
			+ "(%d impressions carrying %d deaths)"
			% [int(coalesced.total), deaths_counted],
			int(coalesced.total) == after_first and deaths_counted > after_first)
	_check("caps are declared and never exceeded (%d <= %d total)"
			% [int(coalesced.total), int(coalesced.total_cap)],
			int(coalesced.total) <= int(coalesced.total_cap)
			and _per_room_within_cap(fauna))

	# SURVIVES STREAMING. The room leaves the live pocket; its impressions stay
	# and come back identically on revisit.
	var kept: Array = fauna.stains_in_room(room_key)
	var revisit := PackedInt32Array([2, 3, 1, 2, 0, 3])
	var architecture := root.get("_architecture") as Node3D
	root.rooms.advance(architecture, revisit)
	await get_tree().process_frame
	fauna.refresh()
	var still_live := false
	for room in root.rooms.live_rooms():
		still_live = still_live or str(room.get("key", "")) == room_key
	var survived: Array = fauna.stains_in_room(room_key)
	_check("stains survive the room leaving the live pocket (%d kept, room "
			% survived.size() + "live: %s)" % still_live,
			_same_impressions(kept, survived))
	_check("a revisit returns the same impressions deterministically",
			_same_impressions(fauna.stains_in_room(room_key), kept))

	# Densities for a dead room are dropped; the stain memory is not.
	_check("the density record forgets a dead room while the stain does not",
			(fauna.get("_densities") as Dictionary).has(room_key) == still_live
			and not fauna.stains_in_room(room_key).is_empty())


func _no_inherited_stains() -> void:
	# A NEW DIRECTOR IS A NEW VISIT. Constructed standalone: it owns no rooms,
	# so it realizes nothing, which is exactly the state a fresh visit starts
	# in. Nothing is added to the scene tree.
	var fresh = DreamFaunaDirector.new()
	var census: Dictionary = fresh.stain_census()
	var cohorts: Dictionary = fresh.cohort_census()
	_check("a newly constructed director inherits no stains and no lineages",
			int(census.total) == 0 and int(census.recorded) == 0
			and int(census.evicted) == 0 and int(cohorts.addressed) == 0
			and int(cohorts.lineages) == 0
			and fresh.stains_in_room("anything").is_empty())
	fresh.free()


func _eviction_determinism() -> void:
	# PER-ROOM CAP. Generations increase monotonically, so the total ordering
	# must discard exactly 0..5 and retain 6..29 regardless of array details.
	var room_limited := DreamFaunaDirector.new()
	for i in 30:
		room_limited._record_stain("overflow-room", i % 5, i,
				Vector3(float(i), 0.0, 0.0), "parent-%d" % i,
				Vector2(float(i) / 30.0, 0.5), 1, i)
	var room_rows := room_limited.stains_in_room("overflow-room")
	var room_census: Dictionary = room_limited.stain_census()
	var retained_generations: Array[int] = []
	for row in room_rows:
		retained_generations.append(int(row.generation))
	retained_generations.sort()
	_check("per-room overflow evicts the six oldest impressions by total key",
			room_rows.size() == DreamFaunaDirector.STAIN_PER_ROOM_CAP
			and int(room_census.evicted) == 6
			and retained_generations.front() == 6
			and retained_generations.back() == 29)
	room_limited.free()

	# GLOBAL CAP. Drive two fresh directors with the same over-cap sequence and
	# compare every retained room byte-for-byte. This exercises widest-room
	# selection, lexical room ties and each room's oldest-impression selection.
	var global_a := _overflow_stain_director()
	var global_b := _overflow_stain_director()
	var global_census: Dictionary = global_a.stain_census()
	_check("global overflow is capped and byte-deterministic across fresh owners",
			int(global_census.total) == DreamFaunaDirector.STAIN_TOTAL_CAP
			and int(global_census.evicted) == 24
			and _stain_ledger_bytes(global_a) == _stain_ledger_bytes(global_b))
	global_a.free()
	global_b.free()


func _overflow_stain_director() -> DreamFaunaDirector:
	var fauna := DreamFaunaDirector.new()
	for room_i in 5:
		var room_key := "overflow-%02d" % room_i
		for slot in 24:
			var generation := room_i * 100 + slot
			fauna._record_stain(room_key, slot % 5, slot,
					Vector3(float(slot), float(room_i), 0.0),
					"%s/0/%d#%d" % [room_key, slot, generation],
					Vector2(float(slot) / 24.0, float(room_i) / 5.0),
					1, generation)
	return fauna


func _stain_ledger_bytes(fauna: DreamFaunaDirector) -> PackedByteArray:
	var ledger := {}
	var keys: Array = (fauna.stain_census().by_room as Dictionary).keys()
	keys.sort()
	for room_key in keys:
		ledger[room_key] = fauna.stains_in_room(str(room_key))
	return var_to_bytes(ledger)


# --- ownership --------------------------------------------------------------

func _ownership(fauna, root, plan_before: PackedByteArray,
		save_before: PackedByteArray, hazards_before: String,
		nodes_before: int, _scene_nodes_before: int) -> void:
	var forbidden := 0
	for node in fauna.find_children("*", "", true, false):
		if node is CollisionObject3D or node is Light3D:
			forbidden += 1
	_check("cohorts and stains add no node, collision object or light to the "
			+ "fauna owner",
			fauna.find_children("*", "", true, false).size() == nodes_before
			and forbidden == 0)
	# The whole-scene count is measured around a REFRESH, not across the
	# deliberate `rooms.advance` above: streaming rooms in and out is the room
	# builder doing its own job and would swamp the only claim being made here,
	# which is that realizing cohorts and remembering stains instantiate
	# nothing at all.
	var scene_before_refresh: int = root.find_children("*", "", true, false).size()
	fauna.refresh()
	fauna.refresh()
	_check("a refresh that addresses cohorts and records stains instantiates "
			+ "nothing (%d nodes)" % scene_before_refresh,
			root.find_children("*", "", true, false).size()
					== scene_before_refresh
			and fauna.find_children("*", "", true, false).size() == nodes_before)
	_check("no RealityState byte moved",
			var_to_bytes(RealityState.data) == save_before
			and RealityState.persistence_enabled == false)
	_check("no plan, topology or hazard fact moved",
			var_to_bytes(root.plan) == plan_before
			and _hazard_signature(root.hazards) == hazards_before)
	# The stain memory must not have leaked into anything that persists.
	var leaked := false
	for key in RealityState.data.keys():
		var text := str(RealityState.data[key])
		if text.contains("#") and text.contains("/") and text.contains("stain"):
			leaked = true
	_check("stain memory never reaches RealityState", not leaked)
	_check("the 96-instance ceiling and five-batch ownership are unchanged",
			_total(fauna.census()) <= 96
			and fauna.find_children("*", "MultiMeshInstance3D", false,
					false).size() == 5)


# --- helpers ----------------------------------------------------------------

func _per_room_within_cap(fauna) -> bool:
	var census: Dictionary = fauna.stain_census()
	for room_key in (census.by_room as Dictionary):
		if int((census.by_room as Dictionary)[room_key]) \
				> int(census.per_room_cap):
			return false
	return true


func _same_impressions(a: Array, b: Array) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	for i in a.size():
		if var_to_bytes(a[i]) != var_to_bytes(b[i]):
			return false
	return true


func _hazard_signature(field: DreamHazardField) -> String:
	var rows: Array[String] = []
	for hazard in field.hazards:
		rows.append("%s:%s:%s:%s" % [hazard.id, hazard.tell_started_s,
				hazard.contacted, hazard.contact_s])
	return "|".join(rows)


func _total(c: Dictionary) -> int:
	return int(c.buttons) + int(c.tessellates) + int(c.anemones) \
			+ int(c.ribbonettes) + int(c.loupe)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[LIFECYCLE FAIL] " + label)
	else:
		print("[lifecycle ok] " + label)


func _finish() -> void:
	print("DREAM FAUNA LIFECYCLE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
