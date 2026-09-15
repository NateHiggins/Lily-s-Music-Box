extends Node
## Prepared real-save/reconstruction regression; never uses the player's save.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Owner := preload("res://scripts/building/orison_v2_household_state.gd")
const Prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("HOUSEHOLD STATE: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var original_path: String = RealityState.save_path
	var test_path := "user://v2_household_state_%d.json" % Time.get_ticks_usec()
	RealityState.save_path = test_path
	await exercise()
	RealityState.save_path = original_path
	for suffix: String in ["", ".bak", ".tmp", ".txn"]:
		var path := ProjectSettings.globalize_path(test_path + suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("HOUSEHOLD STATE: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func exercise() -> void:
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	check(not world.startup_failed, "fresh household state binds")
	if world.startup_failed:
		world.shutdown_for_tests()
		world.free()
		return
	var owner = world.household_state
	var defaults: Dictionary = owner.snapshot()
	check(defaults.records.size() == 98, "81 circuits, five ordinary valves and twelve cabinet doors")
	check(not defaults.records.has("F02_B_RADIATOR_01"), "Lena's case keeps sole restoration authority")
	check(not RealityState.data.has(Owner.KEY), "binding fresh defaults does not write a save")
	await get_tree().physics_frame
	for identity: String in defaults.records:
		var record: Dictionary = defaults.records[identity]
		var prop: Node = world.adapter.resolve(identity)
		match record.kind:
			"light": prop.call("set_powered", not record.value)
			"radiator": prop.call("set_supply_position", .35, 0.0)
			"prep": prop.call("interact", world.player)
			"mirror": prop.call("set_door_open", true)
	# Direct light changes have no interaction event; snapshot_preparing must
	# still capture them on the actual save path, without recursively committing.
	var wanted: Dictionary = owner.snapshot()
	check(RealityState.save_game(), "household controls serialize through real save storage")
	check(RealityState.data[Owner.KEY] == wanted, "snapshot includes every live control")
	var owner_ref: WeakRef = weakref(owner)
	world.shutdown_for_tests()
	world.free()
	check(owner_ref.get_ref() == null, "first world's save owner is freed")
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	# JSON represents the integer schema version as a float after parsing.
	var serialized_wanted: Variant = JSON.parse_string(JSON.stringify(wanted, "", true, true))
	check(RealityState.data.get(Owner.KEY) == serialized_wanted, "control payload round-trips through disk")
	world = Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	check(not world.startup_failed, "saved household state reconstructs")
	if world.startup_failed:
		world.shutdown_for_tests()
		world.free()
		return
	owner = world.household_state
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(owner.snapshot() == wanted, "all 98 settings restore onto new physical owners")
	# Saves made before the upper circuits existed keep their lower-household
	# facts. Newly installed circuits inherit fresh construction defaults.
	var legacy := wanted.duplicate(true)
	var expanded := wanted.duplicate(true)
	for identity: String in wanted.records:
		if identity.begins_with("F05_") or identity.begins_with("F06_"):
			legacy.records.erase(identity)
			expanded.records[identity] = defaults.records[identity].duplicate(true)
	RealityState.data[Owner.KEY] = legacy
	RealityState.state_changed.emit()
	check(owner.snapshot() == expanded, "pre-upper save restores lower facts and defaults new circuits")
	check(RealityState.data[Owner.KEY] == legacy, "loading old circuit roster does not eagerly rewrite saved facts")
	RealityState.data[Owner.KEY] = wanted.duplicate(true)
	RealityState.state_changed.emit()
	check(owner.snapshot() == wanted, "complete circuit save can replace the legacy roster")
	for identity: String in wanted.records:
		var prop: Node = world.adapter.resolve(identity)
		if wanted.records[identity].kind == "mirror":
			var audio := prop.get("_squeak") as AudioStreamPlayer3D
			check(not audio.playing, "restoring a cabinet does not replay its squeak")
		elif wanted.records[identity].kind == "prep":
			var panel := prop.get("_slide") as AnimatableBody3D
			var expected := Transform3D(Basis.IDENTITY, Vector3(Prep.TRAVEL,0,0))
			check(panel.transform.is_equal_approx(expected), "saved kitchen panel restores its full local transform")
			var physical: Transform3D = PhysicsServer3D.body_get_state(panel.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
			check(physical.is_equal_approx(panel.global_transform), "saved panel collision agrees with its visual")
	var kinds: Dictionary = owner.get("_kinds")
	var invalids: Array = [null, {"schema_version":2,"records":{}}, {"schema_version":true,"records":{}},
		{"schema_version":"1","records":{}}, {"schema_version":NAN,"records":{}},
		{"schema_version":1,"records":[],}, {"schema_version":1,"records":{"2A_prep_cabinet":{"kind":false,"value":true}}}]
	var unknown := wanted.duplicate(true)
	unknown.records["UNKNOWN"] = {"kind":"mirror","value":true}
	invalids.append(unknown)
	var wrong_type := wanted.duplicate(true)
	wrong_type.records["2A_prep_cabinet"].value = 1
	invalids.append(wrong_type)
	var nonfinite := wanted.duplicate(true)
	nonfinite.records["F03_A_RADIATOR_01"].value = NAN
	invalids.append(nonfinite)
	var out_of_range := wanted.duplicate(true)
	out_of_range.records["F03_A_RADIATOR_01"].value = 1.01
	invalids.append(out_of_range)
	var raw_transform := wanted.duplicate(true)
	raw_transform.records["2A_prep_cabinet"].position = [0,0,0]
	invalids.append(raw_transform)
	for invalid: Variant in invalids:
		check(not owner.validate(invalid, kinds), "malformed control payload rejected")
	# A corrupt sibling must never partially apply otherwise valid records.
	RealityState.data[Owner.KEY] = unknown
	RealityState.state_changed.emit()
	check(owner.snapshot() == wanted and not owner.capture_now(), "invalid load neither mutates props nor gets overwritten")
	check(RealityState.data[Owner.KEY] == unknown, "invalid saved bytes remain represented for recovery")
	RealityState.data[Owner.KEY] = defaults.duplicate(true)
	RealityState.state_changed.emit()
	check(owner.snapshot() == defaults, "valid mid-session load recovers from blocked payload")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for unit_id: String in Owner.UNITS:
		var cabinet: Node = world.adapter.resolve(unit_id + "_prep_cabinet")
		check((cabinet.get("_slide") as Node3D).transform.is_equal_approx(Transform3D.IDENTITY),
			"mid-session load returns the entire panel to its closed transform")
	var before: Dictionary = RealityState.data[Owner.KEY].duplicate(true)
	RealityState.save_write_blocked = true
	(world.adapter.resolve("2A_prep_cabinet") as Node).call("interact", world.player)
	check(RealityState.data[Owner.KEY] == before, "protected save is not mutated by controls")
	RealityState.save_write_blocked = false
	# Reset must clear a live preview change even when the old on-disk payload
	# was never changed. Omitted records inherit newly constructed defaults.
	RealityState.data.erase(Owner.KEY)
	RealityState.state_changed.emit()
	check(owner.snapshot() == defaults, "legacy/missing control block restores fresh defaults")
	check(owner.capture_now(), "legacy save can acquire the complete new control block")
	check(not owner.capture_now(), "unchanged capture is idempotent")
	world.shutdown_for_tests()
	var preserved: Dictionary = RealityState.data[Owner.KEY].duplicate(true)
	RealityState.snapshot_preparing.emit()
	check(RealityState.data[Owner.KEY] == preserved, "retired owner cannot write after shutdown")
	world.free()
