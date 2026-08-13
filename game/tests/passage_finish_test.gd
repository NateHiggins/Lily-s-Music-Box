extends Node
## Focused proof for the Passage's movable middle layer, against the integrated
## collision world rather than a prop-only inspection scene.

var _fails := 0
var root: Node3D


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _sweep(from: Vector3, to: Vector3) -> float:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.524
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), from + Vector3(0.0, 0.80, 0.0))
	query.motion = to - from
	query.collide_with_areas = false
	var result := root.get_viewport().find_world_3d().direct_space_state \
			.cast_motion(query)
	return float(result[0]) if result.size() >= 1 else 0.0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	# Keep the parked lobby player from overwriting the explicit zone probes on
	# the next physics tick; PassageVisibilityTest uses the same isolation.
	root.set_physics_process(false)
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	await get_tree().physics_frame

	var finish = root.passage_finish
	var carts := get_tree().get_nodes_in_group("passage_pushcarts")
	_check("finish owns three gated public-hall draws",
			finish.geometry_nodes.size() == 3)
	_check("three independently movable handcarts are installed",
			carts.size() == 3 and carts.all(func(cart):
				return cart is RigidBody3D))
	_check("the finish adds no real light to the pinned budget",
			finish.find_children("*", "Light3D", true, false).is_empty())
	_check("every cart has one player-blocking hull",
			carts.all(func(cart):
				return cart.find_children(
						"*", "CollisionShape3D", true, false).size() == 1 \
						and cart.collision_layer == 1))
	_check("all carts begin inside the six-metre architectural aisle",
			carts.all(func(cart):
				return cart.global_position.x > 11.0 \
						and cart.global_position.x < 17.0 \
						and cart.global_position.z > 38.6 \
						and cart.global_position.z < 64.6))
	_check("the untouched x=14 schedule spine remains capsule-clear",
			_sweep(Vector3(14.0, 0.06, 39.0),
					Vector3(14.0, 0.06, 64.0)) > 0.999)

	var cart = carts.filter(func(candidate):
		return String(candidate.get_meta("cart_id", "")) == "market")[0]
	var before: Vector3 = cart.global_position
	cart.shove_from(before + Vector3(1.0, 0.0, 0.0))
	await get_tree().create_timer(0.8).timeout
	var travelled := Vector2(before.x, before.z).distance_to(
			Vector2(cart.global_position.x, cart.global_position.z))
	print("    market cart shove distance=%.3f m" % travelled)
	_check("a deliberate shove physically moves the loaded market cart",
			travelled > 0.08)
	_check("the shoved cart remains in the bounded hall",
			cart.global_position.x > 11.0 and cart.global_position.x < 17.0
			and cart.global_position.z > 38.6 and cart.global_position.z < 64.6)

	root._apply_visibility(Vector3(14.0, 1.0, 28.316))
	_check("the STREET gate hides, freezes and disables every handcart",
			carts.all(func(candidate):
				return not candidate.visible and candidate.freeze \
						and candidate.collision_layer == 0))
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	_check("crossing the portal restores the movable layer",
			carts.all(func(candidate):
				return candidate.visible and not candidate.freeze \
						and candidate.collision_layer == 1))

	print("[PASSAGE FINISH] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
