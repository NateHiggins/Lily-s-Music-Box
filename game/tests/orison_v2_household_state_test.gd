extends Node
## Prepared real-save/reconstruction regression; never uses the player's save.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Owner := preload("res://scripts/building/orison_v2_household_state.gd")
const Prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
## What each apparatus's own hand repair publishes on completion
## (fuse_panel_plugs.gd, roof_tank_hand_controls.gd, boiler_prop.gd).
const HAND_RESULTS := {
	"fuse_service": {"activity_id": "fuse_panel_rating_service", "quality": "good",
		"note": "isolated main, replaced plug by hand, and restored protected load", "mechanism_patch": {"panel_safe": true}},
	"tank_service": {"activity_id": "roof_tank_ballcock_service", "quality": "good",
		"note": "drained float, set lever weight and observed the open supply holding", "mechanism_patch": {"ballcock_serviced": true}},
	"boiler_service": {"activity_id": "boiler_water_column_test", "quality": "good",
		"note": "water column emptied, returned and witnessed", "mechanism_patch": {"column_proved": true}},
}
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
	failures.append("exercise interrupted before completion")
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
	# The household domain grew with the hands-on fittings (RUL-013) and the
	# upper floors; its roster is the owner's, not a frozen number.
	check(defaults.records.size() == owner._kinds.size() and defaults.records.size() > 210,
		"every household control is saved (%d), the 210 originals and the fittings added since" % defaults.records.size())
	var hall_lights := 0
	var sconces := 0
	for id: String in defaults.records:
		if id.contains("_EAST_HALL_LT") or id.contains("_WEST_HALL_LT"): hall_lights += 1
		if id.ends_with("_LANDING_LT_SCONCE"): sconces += 1
	check(hall_lights == 12 and sconces == 5, "the twelve public hall lights and five landing sconces are saved (%d, %d)" % [hall_lights, sconces])
	for id: String in ["B1_BOILER_AIR_E", "B1_FUSE_PANEL", "ROOF_TANK_BALLCOCK", "B1_BOILER_01"]:
		check(defaults.records.has(id), "the boiler window and the three service results are saved: " + id)
	var switch_owners := 0
	for child: Node in world.get_children():
		if child is SwitchSystem: switch_owners += 1
	check(switch_owners == 1, "original and added rooms share one circuit and save-event owner")
	# Since the native radiator (10-17) this domain saves the radiator's physical
	# part positions; Lena's case keeps condition, work-order and packing authority.
	var lena: Dictionary = defaults.records.get("F02_B_RADIATOR_01", {})
	check(str(lena.get("kind", "")) == "radiator" and lena.value is Dictionary and not lena.value.has("condition"),
		"Lena's radiator saves only physical part positions; her case keeps its condition authority")
	check(not RealityState.data.has(Owner.KEY), "binding fresh defaults does not write a save")
	await get_tree().physics_frame
	var switches := world.get_node("V2RoomSwitches") as SwitchSystem
	for room: String in ["F04_B_BATH", "F01_A_BATH"]:
		check(not switches.toggle_room(room) and owner.snapshot() != defaults, "circuit switches off: " + room)
		check(RealityState.data.get(Owner.KEY) == owner.snapshot(), "original and added switch events save immediately: " + room)
		switches.toggle_room(room)
	for identity: String in defaults.records:
		var record: Dictionary = defaults.records[identity]
		var prop: Node = owner._subjects[identity]
		match record.kind:
			"fuse_service", "tank_service", "boiler_service":
				var before_service: Dictionary = prop.call("maintenance_snapshot")
				_open_service(prop, world.player)
				var panel: MaintenanceActivityPanel = prop.get("_service_panel")
				if panel == null:
					# RUL-013: this apparatus is repaired by hand; the panel is retired.
					# Its hand tests prove the grabbing. Here, complete it through the
					# exact result the hand path publishes and prove it persists.
					check(not world.player.call_locked, "physical repair opens no panel and holds no movement: " + identity)
					var result: Dictionary = HAND_RESULTS[record.kind].duplicate(true)
					if record.kind == "fuse_service":
						# The hand repair's physical outcome: the found plug swapped for one
						# that protects the conductor, main closed, plug home.
						prop.set("fitted_rating", FusePanelProp.CONDUCTOR_RATING)
						prop.set("plug_out", false)
						prop.set("main_open", false)
					elif record.kind == "tank_service":
						# The hand repair's physical outcome: the float drained, the lever
						# weight slid along until the cock seats, the supply left open.
						prop.set("float_waterlogged", false)
						prop.set("riser_open", true)
						for step in 51:
							prop.set("weight_set", float(step) / 50.0)
							if (prop as RoofTankBallcockProp).valve_holds(): break
						(prop as RoofTankBallcockProp)._refresh_mechanism()
					elif record.kind == "boiler_service":
						result.mechanism_patch.water_level = float(prop.get("water_level"))
					if prop is FusePanelProp: (prop as FusePanelProp).apply_maintenance_result(result)
					elif prop is RoofTankBallcockProp: (prop as RoofTankBallcockProp).apply_maintenance_result(result)
					elif prop is BoilerProp: (prop as BoilerProp).apply_maintenance_result(result)
					if record.kind == "boiler_service":
						# The glass keeps finding its level after the test; let it settle.
						for frame in 600:
							if absf(float(prop.get("_glass_level")) - float(prop.get("water_level"))) < 1e-4: break
							await get_tree().physics_frame
					await get_tree().create_timer(0.3).timeout
					check(RealityState.data[Owner.KEY].records[identity].value and not world.player.call_locked,
						"completed hand repair is saved and releases movement: " + identity)
					continue
				var step: Dictionary = panel._director.active_run.current_step()
				prop.call("preview_maintenance_step", step, float(step.target))
				check(RealityState.save_game(), "saving a live repair preview succeeds")
				check(not RealityState.data[Owner.KEY].records[identity].value, "unfinished work is not published")
				panel._director.abort()
				check(prop.call("maintenance_snapshot") == before_service, "cancel restores the mechanism captured at service entry")
				await get_tree().process_frame
				_open_service(prop, world.player)
				panel = prop.get("_service_panel")
				for service_step: Dictionary in panel._director.active_run.profile.steps:
					prop.call("preview_maintenance_step", service_step, float(service_step.target))
					check(panel._director.submit(str(service_step.verb),float(service_step.target),float(service_step.get("hold_min_seconds",0))+.4), "director accepts " + str(service_step.id))
				await get_tree().create_timer(1.0).timeout
				check(RealityState.data[Owner.KEY].records[identity].value and not world.player.call_locked, "completed repair is saved and releases movement")
			"light": prop.call("set_powered", not record.value)
			"radiator": prop.call("set_supply_position", .35, 0.0)
			"prep": prop.call("interact", world.player)
			"window":
				# The window saves its sash mechanism; let the swing finish first.
				prop.call("interact_handle", world.player)
				for frame in 240:
					if not prop.get("moving"): break
					await get_tree().physics_frame
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
	var restored: Dictionary = owner.snapshot()
	var drifted: Array = []
	for id: String in wanted.records:
		var where := _differs(wanted.records[id], restored.records.get(id, null), id)
		if not where.is_empty():
			drifted.append(id)
			printerr("HOUSEHOLD STATE: drift at ", where)
	check(drifted.is_empty(), "every household setting restores onto new physical owners (%d drifted)" % drifted.size())
	var window: Node3D = owner._subjects["B1_BOILER_AIR_E"]
	check(window.opened and not window.moving and is_equal_approx(window.angle_degrees,35.0), "saved open window reconstructs its fitted physical sash and stay position")
	var fuse := world.adapter.resolve("B1_FUSE_PANEL") as FusePanelProp
	var tank := world.adapter.resolve("ROOF_TANK_BALLCOCK") as RoofTankBallcockProp
	check(fuse.panel_safe and fuse.protects_conductor() and fuse.load_proved, "reload reconstructs the correct fuse and proved load")
	check(tank.ballcock_serviced and tank.valve_holds() and not tank.overflow_running(), "reload reconstructs the holding tank valve")
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	check(boiler.column_proved and not boiler.column_isolated, "reload reconstructs the proved water column in service")
	var previous_roster := wanted.duplicate(true)
	previous_roster.records.erase("B1_BOILER_01")
	RealityState.data[Owner.KEY] = previous_roster
	RealityState.state_changed.emit()
	var expected_previous := wanted.duplicate(true)
	expected_previous.records["B1_BOILER_01"] = defaults.records["B1_BOILER_01"].duplicate(true)
	check(_same(owner.snapshot(), expected_previous) and not boiler.column_proved,
			"209-record saves retain all existing repairs and default only the new boiler record")
	# Saves made before the upper circuits existed keep their lower-household
	# facts. Newly installed circuits inherit fresh construction defaults.
	var legacy := wanted.duplicate(true)
	var expanded := wanted.duplicate(true)
	var completion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	var added_circuits := {}
	for fixture: Dictionary in completion.lighting.fixtures: added_circuits[fixture.id] = true
	for row: Dictionary in completion.furniture: added_circuits[row.id] = true
	# The public hall domes (dossier slice 3) and landing sconces (slice 83) postdate the legacy roster too.
	var room_lighting: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/room_lighting.json"))
	for fixture: Dictionary in room_lighting.fixtures:
		if fixture.id.begins_with("F0") and (fixture.id.contains("_EAST_HALL_LT") or fixture.id.contains("_WEST_HALL_LT") or fixture.id.ends_with("_LANDING_LT_SCONCE")): added_circuits[fixture.id] = true
	for unit: String in ["1A","1D","2C","3D","4C","4D"]:
		added_circuits["F0"+unit[0]+"_"+unit[1]+"_RADIATOR_01"] = true
	for identity: String in wanted.records:
		if added_circuits.has(identity) or wanted.records[identity].kind in ["books", "fuse_service", "tank_service", "boiler_service", "window", "mechanism", "blind"] or identity.begins_with("F05_") or identity.begins_with("F06_") or identity[0] in ["5", "6"]:
			legacy.records.erase(identity)
			expanded.records[identity] = defaults.records[identity].duplicate(true)
	var legacy_ok: bool = not legacy.records.is_empty()
	for identity: String in legacy.records:
		legacy_ok = legacy_ok and legacy.records[identity].kind in ["light", "radiator", "prep", "mirror"] 				and not identity.begins_with("F05_") and not identity.begins_with("F06_")
	check(legacy_ok, "legacy roster contains only the original kinds of household control, below the upper floors (%d)" % legacy.records.size())
	RealityState.data[Owner.KEY] = legacy
	RealityState.state_changed.emit()
	check(_same(owner.snapshot(), expanded), "pre-upper save restores lower facts and defaults new circuits")
	check(not fuse.panel_safe and tank.overflow_running(), "old saves inherit the original apparatus faults")
	check(RealityState.data[Owner.KEY] == legacy, "loading old circuit roster does not eagerly rewrite saved facts")
	RealityState.data[Owner.KEY] = wanted.duplicate(true)
	RealityState.state_changed.emit()
	check(_same(owner.snapshot(), wanted), "complete circuit save can replace the legacy roster")
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
	# Cabinets save partial travel 0..1 (PR 221), so 1 is valid; past full travel is not.
	wrong_type.records["2A_prep_cabinet"].value = 1.5
	invalids.append(wrong_type)
	for identity: String in Owner.SERVICE_KINDS:
		var malformed := wanted.duplicate(true)
		malformed.records[identity].value = 1
		invalids.append(malformed)
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
	# Readable shelves save a library dictionary; a bare order is still checked
	# against the shelf's own book order.
	var shelf_value: Variant = wanted.records[shelf_id].value
	var order: Array = shelf_value.order if shelf_value is Dictionary else shelf_value
	for bad_order: Variant in [true, [], ["foreign_book"], order.slice(1), order + [order[0]]]:
		var bad := wanted.duplicate(true)
		bad.records[shelf_id].value = bad_order
		invalids.append(bad)
	var duplicate := wanted.duplicate(true)
	var doubled: Array = order.duplicate()
	doubled[0] = doubled[1]
	duplicate.records[shelf_id].value = doubled
	invalids.append(duplicate)
	for index in invalids.size():
		check(not owner.validate(invalids[index], kinds), "malformed control payload rejected (case %d)" % index)
	# A corrupt sibling must never partially apply otherwise valid records. (A
	# well-formed record for a fitting the world no longer has is not corrupt: since
	# PR 180 it is set aside, so the unknown-identity case is not the one used here.)
	RealityState.data[Owner.KEY] = wrong_type
	RealityState.state_changed.emit()
	check(_same(owner.snapshot(), wanted) and not owner.capture_now(), "invalid load neither mutates props nor gets overwritten")
	check(RealityState.data[Owner.KEY] == wrong_type, "invalid saved bytes remain represented for recovery")
	tank.interact(world.player)
	tank.preview_maintenance_step({"id":"shut_the_riser"},0.0)
	RealityState.data[Owner.KEY] = defaults.duplicate(true)
	RealityState.state_changed.emit()
	check(_same(owner.snapshot(), defaults), "valid mid-session load recovers from blocked payload")
	check(tank._service_panel == null and not world.player.call_locked and tank.overflow_running(), "loading closes old preview before restoring the new mechanism")
	RealityState.data[Owner.KEY] = wanted.duplicate(true)
	RealityState.state_changed.emit()
	_open_service(boiler,world.player)
	boiler.preview_maintenance_step({"id":"isolate_column"},1.0)
	RealityState.data[Owner.KEY] = defaults.duplicate(true)
	RealityState.state_changed.emit()
	check(boiler._service_panel == null and not boiler.column_proved and not boiler.column_isolated
			and not world.player.call_locked,"loading cancels boiler preview before restoring the new water-column state")
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
	check(_same(owner.snapshot(), defaults), "legacy/missing control block restores fresh defaults")
	check(owner.capture_now(), "legacy save can acquire the complete new control block")
	check(not owner.capture_now(), "unchanged capture is idempotent")
	world.shutdown_for_tests()
	var preserved: Dictionary = RealityState.data[Owner.KEY].duplicate(true)
	RealityState.snapshot_preparing.emit()
	check(RealityState.data[Owner.KEY] == preserved, "retired owner cannot write after shutdown")
	world.free()
	failures.erase("exercise interrupted before completion")

func _open_service(prop: Node, player: PlayerController) -> void:
	if prop is BoilerProp: prop.interact_control("water_column",player)
	else: prop.call("interact",player)

## A restored physical owner stores transforms in 32-bit floats, so a saved
## 64-bit value cannot come back bit-identical. Compare as the game does:
## same keys and types, numbers within a part in a hundred thousand.
## Returns "" when equal, else the first differing path.
## Live readings, not facts that hold still between two looks: a running clock
## movement's spindle, and the boiler's gauge glass, which the boiler re-simulates
## every physics frame as water finds its level through the open cocks.
## Key -> the flag that makes it live ("" = always).
const LIVE_KEYS := {"native_drive": "movement_running", "glass": ""}

func _differs(a: Variant, b: Variant, path := "") -> String:
	if (a is float or a is int) and (b is float or b is int) and not (a is bool) and not (b is bool):
		return "" if is_equal_approx(float(a), float(b)) or absf(float(a) - float(b)) <= 1e-5 else path
	if typeof(a) != typeof(b): return path + " (type)"
	if a is Dictionary:
		if a.size() != b.size(): return path + " (keys)"
		for key: Variant in a:
			if not b.has(key): return path + "/" + str(key) + " (missing)"
			if LIVE_KEYS.has(str(key)) and (LIVE_KEYS[str(key)] == "" or bool(a.get(LIVE_KEYS[str(key)], false))): continue
			var inner := _differs(a[key], b[key], path + "/" + str(key))
			if not inner.is_empty(): return inner
		return ""
	if a is Array:
		if a.size() != b.size(): return path + " (length)"
		for i in a.size():
			var inner := _differs(a[i], b[i], path + "/" + str(i))
			if not inner.is_empty(): return inner
		return ""
	return "" if a == b else path

func _same(a: Variant, b: Variant) -> bool:
	var where := _differs(a, b)
	if not where.is_empty(): printerr("HOUSEHOLD STATE: differs at ", where)
	return where.is_empty()

