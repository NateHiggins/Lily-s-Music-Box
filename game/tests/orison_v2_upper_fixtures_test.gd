extends Node
## Prepared two-lifetime composition test. Execute only when engine use resumes.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const UNITS := ["5A", "5B", "5C", "6A", "6B", "6C"]
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("UPPER FIXTURES: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_fittings.json"))
	var acoustics := {}
	for record: Dictionary in source.fittings:
		if record.unit in UNITS and AcousticGraphData.nodes.has(record.id):
			acoustics[record.id] = AcousticGraphData.nodes[record.id].duplicate(true)
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "full V2 composition starts, cycle " + str(cycle))
		if world.startup_failed:
			world.shutdown_for_tests()
			world.free()
			break
		await get_tree().physics_frame
		var refs: Array[WeakRef] = []
		for unit: String in UNITS:
			var wc := world.adapter.resolve(unit + "_wc") as BakedFurnitureInteraction
			check(wc != null, "native water closet: " + unit)
			if wc != null:
				refs.append(weakref(wc))
				wc.interact(world.player)
				check("refilling" in wc.interact_prompt(), "flush starts: " + unit)
			var stand := world.adapter.resolve(unit + "_sink_support") as StaticBody3D
			check(stand != null, "supported kitchen sink: " + unit)
			if stand != null:
				refs.append(weakref(stand))
				check(stand.find_children("*", "CollisionShape3D", true, false).size() == 8,
						"open stand keeps its eight physical members: " + unit)
			var counts := {"sink": 0, "shower": 0, "stove": 0, "fridge": 0}
			for record: Dictionary in source.fittings:
				if record.unit != unit: continue
				counts[record.kind] += 1
				var prop := world.adapter.resolve(record.id) as FunctionalProp
				check(prop != null and prop.get("unit") == unit, "semantic fitting: " + str(record.id))
				if prop == null: continue
				refs.append(weakref(prop))
				var body := prop.get_node_or_null("FixtureBody") as StaticBody3D
				check(body != null and not body.find_children("*", "CollisionShape3D", true, false).is_empty(),
						"solid fixture body mounted: " + str(record.id))
				if prop is TapProp:
					check(world.boiler_tend.taps.count(prop) == 1, "one existing boiler supply: " + str(record.id))
					for label: String in ["HotValveControl", "ColdValveControl"]:
						var control := prop.get_node_or_null(label) as Area3D
						check(control != null and control.get("tap") == prop, "native water control: " + str(record.id) + "/" + label)
					prop.set_hot(true)
					prop.set_cold(true)
				elif prop is FridgeProp:
					check(prop.monitor_top == record.properties.monitor_top, "household fridge variant: " + unit)
					prop.set_door_open(true)
					if not prop.monitor_top:
						prop.set_ice_door_open(true)
						prop.set_tray_open(true)
				elif prop is StoveProp:
					check(not prop.ambient_lit, "authored cold stove: " + unit)
					prop.set_door_open(true)
			check(counts == {"sink": 2, "shower": 1, "stove": 1, "fridge": 1}, "complete fitting roster: " + unit)
		# Retire consumers while water/audio and appliance animation are active.
		world.shutdown_for_tests()
		world.free()
		for ref: WeakRef in refs: check(ref.get_ref() == null, "fixture retires with its world")
		for identity: String in acoustics:
			check(AcousticGraphData.nodes[identity] == acoustics[identity], "acoustic override restored: " + identity)
	print("UPPER FIXTURES: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
