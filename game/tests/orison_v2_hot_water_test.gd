extends Node
## Real V2 composition, deterministic plant ticks, shared flow readers and teardown.
## Prepared for the next authorized engine session; no played route is claimed.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("V2 HOT WATER: " + label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for cycle in 2:
		var world := Runtime.instantiate() as OrisonV2RuntimeRoot
		add_child(world)
		check(not world.startup_failed, "V2 starts")
		var owner := world.boiler_tend
		if owner == null:
			check(false, "plant controller exists")
			world.shutdown_for_tests()
			world.free()
			break
		owner.set_process(false)
		var owners := 0
		for child in world.get_children():
			if child is BoilerTend: owners += 1
		check(owners == 1, "one plant clock")
		check(owner.boiler == world.adapter.resolve("B1_BOILER_01"), "mounted boiler is authoritative")
		var expected: Array[String] = []
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://data/orison_v2/domestic_fittings.json"))
		for fitting: Dictionary in data.fittings:
			if fitting.kind in ["sink", "shower"]: expected.append(fitting.id)
		check(owner.taps.size() == expected.size(), "every mounted water fitting bound once")
		for identity in expected:
			var tap := world.adapter.resolve(identity) as TapProp
			check(tap != null and owner.taps.count(tap) == 1, "live fixture membership " + identity)
			if tap == null: continue
			if tap.fixture == "shower":
				var body := tap.get_node_or_null("FixtureBody") as StaticBody3D
				check(body != null and body.get_child_count() == 10,
						"shower has receptor pieces rather than a curtain-sized hull: " + identity)
				if body != null:
					var before := tap.get_flow_state()
					body.call("interact", null)
					check(tap.get_flow_state() == before and body.call("interact_prompt") == "",
							"receptor contact does not cycle the water or advertise a control")
				for control_name in ["HotValveControl", "ColdValveControl"]:
					var control := tap.get_node_or_null(control_name) as Area3D
					check(control != null and control.get("tap") == tap,
							"shower valve target belongs to its live tap: " + identity)
				# At standing height the receptor must not obstruct the curtain/valves.
				var overhead_clear := true
				if body != null:
					for collision: CollisionShape3D in body.get_children():
						var box := collision.shape as BoxShape3D
						overhead_clear = overhead_clear and box != null \
								and collision.position.y + box.size.y * .5 < .3
				check(overhead_clear, "shower collision stays below the control opening")
			tap.set_hot(true)
			tap.set_cold(false)
			check(is_equal_approx(float(tap.get_flow_state().temperature),
					0.18 + owner.boiler.boiler_output() * 0.82), "initial temperature " + identity)
		var previous_coal := owner.boiler.coal_charge
		owner._process(0.4)
		check(owner.boiler.coal_charge == previous_coal, "fractional tick accumulates")
		owner._process(0.6)
		check(owner.boiler.coal_charge < previous_coal, "one elapsed second burns real fuel")
		owner.boiler.set_draft(0.0)
		for tap in owner.taps:
			var hot := float(tap.get_flow_state().temperature)
			check(is_equal_approx(hot, 0.18 + owner.boiler.boiler_output() * 0.82), "plant signal updates hot tap")
			tap.set_cold(true)
			check(is_equal_approx(float(tap.get_flow_state().temperature), hot * 0.5), "cold valve dilutes hot supply")
			tap.set_hot(false)
			check(float(tap.get_flow_state().temperature) == 0.0, "cold-only stays cold")
			tap.set_cold(false)
		var refs: Array[WeakRef] = [weakref(owner), weakref(owner.boiler)]
		for tap in owner.taps: refs.append(weakref(tap))
		world.shutdown_for_tests()
		world.free()
		for reference in refs: check(reference.get_ref() == null, "world-owned service resource retires")
	# Membership and tick checks above fail if composition is disconnected or doubled.
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var out := FileAccess.open(directory.path_join("hot_water.json"), FileAccess.WRITE)
		out.store_string(JSON.stringify({"checks":checks,"failures":failures}, "\t"))
	print("V2 HOT WATER: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(failures.size())
