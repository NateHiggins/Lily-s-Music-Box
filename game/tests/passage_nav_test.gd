extends Node
## The four schedules that use shops must terminate in the rebuilt Passage,
## by routes that fit a resident-sized capsule through its real collision.

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


func _route_clear(route: PackedVector3Array) -> bool:
	for i in range(route.size() - 1):
		if _sweep(route[i], route[i + 1]) < 0.999:
			print("        blocked leg %d: %v -> %v" %
					[i, route[i], route[i + 1]])
			return false
	return true


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	var nav: ResidentNav = root.resident_routines.nav
	var expected := {
		"hand_laundry": "SITE_SHOP_DOOR_MODEL_LAUNDRY",
		"luncheonette": "SITE_SHOP_DOOR_LUNCHEONETTE",
		"news_cigars": "SITE_SHOP_DOOR_NEWS_CIGARS",
		"photo_supplies": "SITE_SHOP_DOOR_PHOTO_SUPPLIES",
	}
	_check("exactly four schedule destinations are Passage-owned",
			nav.passage_anchors.size() == 4)
	for place in expected:
		var route := nav.passage_route(place)
		var anchor := nav.passage_anchor(place)
		_check("%s has a finite door-derived venue anchor" % place,
				anchor.is_finite())
		_check("%s route starts beyond the ruled portal plane" % place,
				route.size() >= 5 and route[0].z > 28.316)
		_check("%s aisle route reaches its installed shop" % place,
				route.size() >= 5 and route[-1].distance_to(
					nav.passage_anchors[place].aisle) < 0.01)
		_check("%s Passage route is clear for a resident capsule" % place,
				_route_clear(route))
		var door = root.find_child(expected[place], true, false)
		_check("%s installed door exists at its schedule destination" % place,
				door != null)
		if door != null:
			var distance := Vector2(anchor.x, anchor.z).distance_to(
					Vector2(door.global_position.x, door.global_position.z))
			_check("%s anchor remains local to that door" % place,
					distance < 1.7)

	# Buying a paper never grants access to the locked proprietor side.
	var news := nav.passage_anchor("news_cigars")
	_check("NEWS & CIGARS schedule anchor remains on the customer aisle",
			news.x < 17.0)
	print("[PASSAGE NAV] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
