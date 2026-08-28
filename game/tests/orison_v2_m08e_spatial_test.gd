extends Node
## M08E physical-owner route proof. No gameplay director is composed here.

const REVIEW := preload("res://scenes/building/orison_v2_m08e_spatial_review.tscn")
const PROD_LAYOUT := "res://data/building_layout.json"
const REQUIRED := ["F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER",
		"F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD",
		"F02_B_RADIATOR_01", "B1_BOILER_01"]
var failures := 0

func _ready() -> void:
	var production_hash := FileAccess.get_sha256(PROD_LAYOUT)
	var world := REVIEW.instantiate()
	add_child(world)
	await get_tree().physics_frame
	var root := world.get_node("Blockout") as Node3D
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	for identity: String in REQUIRED:
		_gate(root.find_children(identity, "Node3D", true, false).size() == 1,
				"unique spatial owner: " + identity)
	var route := _complete_route()
	player.position = route.pop_front()
	_gate(await _walk(player, route),
			"collision-bearing boiler-to-ritual-to-2B-to-porter-to-boiler-to-radiator route")
	_gate(FileAccess.get_sha256(PROD_LAYOUT) == production_hash,
			"production layout remains byte-stable")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("ORISON V2 M08E SPATIAL TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)

func _complete_route() -> Array[Vector3]:
	var points: Array[Vector3] = [Vector3(10.9, -3.2, -0.5),
		Vector3(10.9, -3.2, -0.4), Vector3(10.1, -3.2, -0.4),
		Vector3(9.0, -3.2, -0.4),
		Vector3(7.2, -3.2, -0.4), Vector3(4.9, -3.2, -0.4),
		Vector3(4.9, -3.2, -2.5), Vector3(2.3, -3.2, -3.0)]
	_append_up(points, -3.2)
	points.append_array([Vector3(0.0, 0.0, -1.5), Vector3(-1.5, 0.0, -1.5),
		Vector3(-2.0, 0.0, -2.2),
		Vector3(-3.25, 0.0, -0.95), Vector3(-4.0, 0.0, -0.6),
		Vector3(-4.0, 0.0, -1.75), Vector3(-1.5, 0.0, -1.5),
		Vector3(2.3, 0.0, -3.0)])
	_append_up(points, 0.0)
	points.append_array([Vector3(5.9, 3.2, -3.25), Vector3(8.7, 3.2, -3.25),
		Vector3(10.15, 3.2, -3.25), Vector3(13.6, 3.2, -1.8),
		Vector3(14.5, 3.2, -3.0), Vector3(11.9, 3.2, -2.5),
		Vector3(10.8, 3.2, -2.5), Vector3(10.15, 3.2, -3.25),
		Vector3(5.9, 3.2, -3.25), Vector3(2.3, 3.2, -3.0)])
	_append_down(points, 0.0)
	points.append_array([Vector3(0.0, 0.0, -1.5), Vector3(-1.5, 0.0, -1.5),
		Vector3(-3.2, 0.0, -2.2), Vector3(-1.5, 0.0, -1.5),
		Vector3(0.0, 0.0, -1.5), Vector3(2.3, 0.0, -3.0)])
	_append_down(points, -3.2)
	points.append_array([Vector3(2.3, -3.2, -3.0), Vector3(4.9, -3.2, -2.5),
		Vector3(4.9, -3.2, -0.4), Vector3(7.2, -3.2, -0.4),
		Vector3(9.0, -3.2, -0.4),
		Vector3(10.1, -3.2, -0.4), Vector3(10.9, -3.2, -0.4),
		Vector3(10.9, -3.2, -0.5), Vector3(10.9, -3.2, -0.4),
		Vector3(10.1, -3.2, -0.4), Vector3(9.0, -3.2, -0.4),
		Vector3(7.2, -3.2, -0.4), Vector3(4.9, -3.2, -0.4),
		Vector3(4.9, -3.2, -2.5), Vector3(2.3, -3.2, -3.0)])
	_append_up(points, -3.2)
	points.append(Vector3(2.3, 0.0, -3.0))
	_append_up(points, 0.0)
	points.append_array([Vector3(5.9, 3.2, -3.25), Vector3(10.15, 3.2, -3.25),
		Vector3(13.6, 3.2, -1.8), Vector3(14.5, 3.2, -3.0)])
	return points

func _append_up(points: Array[Vector3], base_y: float) -> void:
	for i in 10:
		points.append(Vector3(2.3, base_y + 0.16 * float(i + 1), -3.1 + 0.285 * (i + 0.5)))
	points.append(Vector3(2.3, base_y + 1.6, 1.25))
	points.append(Vector3(3.8, base_y + 1.6, 1.25))
	for i in 10:
		points.append(Vector3(3.8, base_y + 1.6 + 0.16 * float(i + 1), 1.03 - 0.285 * (i + 0.5)))
	points.append(Vector3(3.8, base_y + 3.2, -3.45))
	points.append(Vector3(2.3, base_y + 3.2, -3.0))

func _append_down(points: Array[Vector3], base_y: float) -> void:
	var up: Array[Vector3] = []
	_append_up(up, base_y)
	up.reverse()
	points.append_array(up)

func _walk(player: CharacterBody3D, waypoints: Array[Vector3]) -> bool:
	for target: Vector3 in waypoints:
		var frames := 0
		while Vector2(player.position.x - target.x, player.position.z - target.z).length() > 0.12 \
				or absf(player.position.y - target.y) > 0.25:
			var offset := target - player.position
			offset.y = 0.0
			player.velocity = offset.normalized() * 3.2
			player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y - 18.0 / 60.0
			player.call("move_review_velocity", Vector3(player.velocity.x, 0.0, player.velocity.z), 1.0 / 60.0)
			await get_tree().physics_frame
			frames += 1
			if frames > 420:
				var collision := player.get_last_slide_collision()
				var owner := "none" if collision == null else str((collision.get_collider() as Node).get_parent().get_path())
				print("[M08E BLOCKED] at=%s target=%s collider=%s" % [player.position, target, owner])
				return false
		if absf(player.position.y - target.y) > 0.68:
			print("[M08E LEVEL ERROR] at=%s target=%s" % [player.position, target])
			return false
	return true

func _gate(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
