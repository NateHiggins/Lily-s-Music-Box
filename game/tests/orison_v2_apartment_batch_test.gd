extends Node
## Prepared category-level composition/lifetime check. No played route claim.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const UNITS := ["2A", "2B", "3B", "4B"]
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("APARTMENT BATCH: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	var furniture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_furniture.json"))
	var fittings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/domestic_fittings.json"))
	for cycle in 2:
		RealityState.reset_campaign_for_tests()
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "full batch starts, cycle " + str(cycle))
		if world.startup_failed:
			world.shutdown_for_tests()
			world.free()
			break
		var refs: Array[WeakRef] = []
		for unit: String in UNITS:
			var wc := world.adapter.resolve(unit + "_wc") as BakedFurnitureInteraction
			check(wc != null, "toilet mounted for " + unit)
			if wc != null:
				refs.append(weakref(wc))
				wc.interact(world.player)
				check("refilling" in wc.interact_prompt(), "shared flush operates for " + unit)
			var counts := {"sink":0, "shower":0, "stove":0, "fridge":0}
			for record: Dictionary in fittings.fittings:
				if record.unit != unit: continue
				counts[record.kind] += 1
				var prop := world.adapter.resolve(record.id) as FunctionalProp
				check(prop != null and prop.get("unit") == unit, "household fitting mounted: " + str(record.id))
				if prop == null: continue
				refs.append(weakref(prop))
				if prop is TapProp:
					check(world.boiler_tend != null and world.boiler_tend.taps.count(prop) == 1,
							"water fitting has one real supply: " + str(record.id))
					for control_name in ["HotValveControl", "ColdValveControl"]:
						var control := prop.get_node_or_null(control_name) as Area3D
						check(control != null and control.get("tap") == prop,
								"independent water control: " + str(record.id) + "/" + control_name)
						if control != null: refs.append(weakref(control))
			check(counts == {"sink":2,"shower":1,"stove":1,"fridge":1},
					"complete sanitary/appliance category roster for " + unit)
		for record: Dictionary in furniture.furniture:
			var prop := world.adapter.resolve(record.id) as StaticBody3D
			check(prop != null, "furniture mounted: " + str(record.id))
			if prop == null: continue
			refs.append(weakref(prop))
			if record.kind == "wardrobe":
				check(prop.get("_case_wood") == record.mechanism.case_wood,
						"wardrobe retains its household wood: " + str(record.id))
				prop.call("interact", world.player)
				check("Close" in str(prop.call("interact_prompt")),
						"production wardrobe opens: " + str(record.id))
		# Free while cistern/wardrobe tweens are active, exercising their existing
		# teardown owners instead of waiting until all temporary state is idle.
		world.shutdown_for_tests()
		world.free()
		for ref in refs: check(ref.get_ref() == null, "batch subject retires with its world")
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("apartment_batch.json"),FileAccess.WRITE).store_string(
				JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("APARTMENT BATCH: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
