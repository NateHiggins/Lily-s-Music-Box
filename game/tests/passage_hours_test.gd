extends Node
## Deterministic PS6 proof: one 03:00 arcade state, one daytime reversal, and
## the same public zone boundary production uses.

var _fails := 0
var root: Node3D


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("DAYNIGHT_FORCE", "")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.7).timeout
	root.set_physics_process(false)
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	await get_tree().physics_frame

	var hours: PassageHoursDirector = root.passage_finish.hours_director
	var carts := get_tree().get_nodes_in_group("passage_pushcarts")
	_check("all eleven generated shopfront markers reach the hours owner",
			hours.shop_specs.size() == 11)
	_check("ten ordinary units close and exactly one keeps night service",
			hours.closed_shop_ids.size() == 10
			and String(hours._night_service_spec.trade) == "hardware")
	_check("hours furniture is three bounded MultiMesh draws",
			hours.geometry_nodes.size() == 3
			and hours.geometry_nodes.all(func(node):
				return node is MultiMeshInstance3D))
	_check("canonical 03:00 resolves to AFTER_HOURS",
			hours.is_after_hours())
	_check("ten lattices extend while only the hardware packet stays folded",
			hours._closed_grilles.visible
			and not hours._folded_regular.visible
			and hours._folded_night_service.visible)
	_check("ten physical barriers close no hardware aperture",
			hours.barrier_shapes.size() == 10
			and hours.barrier_shapes.all(func(shape):
				return not shape.disabled \
				and not String(shape.get_meta("shop_id", "")).contains(
						"HARDWARE_PAINT")))

	var regular_lights: Array[LightFixtureProp] = []
	var hardware_light := root.get_node_or_null(
			"SITE_SHOP_LT_HARDWARE_PAINT") as LightFixtureProp
	for spec in hours._regular_specs:
		var fixture := root.get_node_or_null(NodePath(String(spec.id).replace(
				"SITE_SHOP_HOURS_", "SITE_SHOP_LT_"))) as LightFixtureProp
		if fixture:
			regular_lights.append(fixture)
	_check("all ten closed shop circuits are dark",
			regular_lights.size() == 10
			and regular_lights.all(func(fixture): return not fixture.powered))
	_check("HARDWARE PAINT alone retains its night-service circuit",
			hardware_light != null and hardware_light.powered)
	_check("all three carts are visibly chained and refuse motion",
			carts.size() == 3 and carts.all(func(cart):
				return cart.is_after_hours_locked() and cart.freeze \
				and cart._night_chain.visible and cart._night_lock.visible))

	hours.apply_for_minute(750.0)
	await get_tree().physics_frame
	_check("daytime folds every grille back to its pier",
			not hours.is_after_hours() and not hours._closed_grilles.visible
			and hours._folded_regular.visible
			and hours._folded_night_service.visible)
	_check("daytime removes every hours-only collision",
			hours.barrier_shapes.all(func(shape): return shape.disabled))
	_check("daytime restores all eleven circuits without a stale dark shop",
			regular_lights.all(func(fixture): return fixture.powered)
			and hardware_light.powered)
	_check("daytime releases all three carts and hides their chains",
			carts.all(func(cart):
				return not cart.is_after_hours_locked() and not cart.freeze \
				and not cart._night_chain.visible \
				and not cart._night_lock.visible))

	hours.apply_for_minute(180.0)
	root._apply_visibility(Vector3(14.0, 1.0, 28.316))
	await get_tree().physics_frame
	_check("STREET owns neither after-hours geometry nor its collision",
			hours.geometry_nodes.all(func(node): return not node.visible)
			and hours.barrier_shapes.all(func(shape): return shape.disabled))
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	await get_tree().physics_frame
	_check("returning to PASSAGE restores the exact after-hours state",
			hours._closed_grilles.visible
			and not hours._folded_regular.visible
			and hours._folded_night_service.visible
			and hours.barrier_shapes.all(func(shape): return not shape.disabled)
			and carts.all(func(cart):
				return cart.visible and cart.is_after_hours_locked() \
				and cart.freeze))

	print("[PASSAGE HOURS] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
