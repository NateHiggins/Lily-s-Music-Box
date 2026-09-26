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
	check(defaults.records.size() == 182, "133 circuits, seventeen ordinary valves, twenty-four cabinet doors and eight book orders")
	var switch_owners := 0
	for child: Node in world.get_children():
		if child is SwitchSystem: switch_owners += 1
	check(switch_owners == 1, "original and added rooms share one circuit and save-event owner")
	check(not defaults.records.has("F02_B_RADIATOR_01"), "Lena's case keeps sole restoration authority")
	check(not RealityState.data.has(Owner.KEY), "binding fresh defaults does not write a save")
	await get_tree().physics_frame
	var switches := world.get_node("V2RoomSwitches") as SwitchSystem
	for room: String in ["F04_B_BATH", "F01_A_BATH"]:
		check(not switches.toggle_room(room) and owner.snapshot() != defaults, "circuit switches off: " + room)
		check(RealityState.data.get(Owner.KEY) == owner.snapshot(), "original and added switch events save immediately: " + room)
		switches.toggle_room(room)
	for identity: String in defaults.records:
		var record: Dictionary = defaults.records[identity]
		var prop: Node = world.adapter.resolve(identity)
		match record.kind:
			"light": prop.call("set_powered", not record.value)
			"radiator": prop.call("set_supply_position", .35, 0.0)
			"prep": prop.call("interact", world.player)
			"mirror": prop.call("set_door_open", true)
			"books":
				prop.get("sorter").touch(0)
				prop.get("sorter").touch(record.value.size()-1)
				prop.call("rebuild_books")
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
	check(owner.snapshot() == wanted, "all 182 settings restore onto new physical owners")
	# Saves made before the upper circuits existed keep their lower-household
	# facts. Newly installed circuits inherit fresh construction defaults.
	var legacy := wanted.duplicate(true)
	var expanded := wanted.duplicate(true)
	var completion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	var added_circuits := {}
	for fixture: Dictionary in completion.lighting.fixtures: added_circuits[fixture.id] = true
	for unit: String in ["1A","1D","2C","3D","4C","4D"]:
		added_circuits["F0"+unit[0]+"_"+unit[1]+"_RADIATOR_01"] = true
	for identity: String in wanted.records:
		if added_circuits.has(identity) or wanted.records[identity].kind == "books" or identity.begins_with("F05_") or identity.begins_with("F06_") or identity[0] in ["5", "6"]:
			legacy.records.erase(identity)
			expanded.records[identity] = defaults.records[identity].duplicate(true)
	check(legacy.records.size() == 56, "legacy roster contains only the original household controls")
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
			var leaf := prop.get_node("CabinetDoor/CabinetLeafBody") as AnimatableBody3D
			var physical: Transform3D = PhysicsServer3D.body_get_state(leaf.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
			check(physical.is_equal_approx(leaf.global_transform), "saved medicine-cabinet collider agrees with restored hinge")
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
	var shelf_id := "F06_6C_BOOKSHELF_01"
	for bad_order: Variant in [true, [], ["foreign_book"], wanted.records[shelf_id].value.slice(1), wanted.records[shelf_id].value + [wanted.records[shelf_id].value[0]]]:
		var bad := wanted.duplicate(true)
		bad.records[shelf_id].value = bad_order
		invalids.append(bad)
	var duplicate := wanted.duplicate(true)
	duplicate.records[shelf_id].value[0] = duplicate.records[shelf_id].value[1]
	invalids.append(duplicate)
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
	for identity: String in defaults.records:
		if defaults.records[identity].kind != "prep": continue
		var cabinet: Node = world.adapter.resolve(identity)
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
