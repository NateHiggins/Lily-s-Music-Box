extends Node3D
## T3b: a traffic contact is a short physical stumble with retained agency.
## There is no health, damage, fail UI, camera takeover or bespoke audio cue.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_build_floor()
	var player := PlayerController.new()
	add_child(player)
	player.global_position = GameBoot.b2g(
			[0.0, StreetTraffic.LANE_EAST, 0.0])
	await get_tree().physics_frame

	var traffic := StreetTraffic.new()
	add_child(traffic)
	traffic.build(player)
	traffic.set_process(false)
	var motor := _kind_index("motor_car")
	traffic._live = [{"kind": motor, "lane": false, "dir": 1.0,
			"x": 0.0, "speed": 5.0, "stop_stage": 0, "dwell": 0.0}]
	var start := player.global_position
	traffic._check_shove()

	_check("production traffic reaches the player's public stagger contract",
			player._stagger_left == PlayerController.STAGGER_SECONDS)
	_check("the body is carried with eastbound traffic, not across its lane",
			player._stagger_velocity.x > 3.0
			and is_zero_approx(player._stagger_velocity.z))
	_check("the street owns exactly four seconds of repeat immunity",
			is_equal_approx(traffic._shove_cooldown, 4.0))
	var first_velocity := player._stagger_velocity
	_check("a second shove cannot stack into a launch",
			not player.stagger(Vector3(-3.4, 0.0, 0.0))
			and player._stagger_velocity == first_velocity)

	await get_tree().physics_frame
	_check("the stumble produces real displacement in vehicle direction",
			player.global_position.x > start.x
			and absf(player.global_position.z - start.z) < 0.03)
	_check("look remains live throughout the stumble",
			player.camera != null and not player.call_locked)

	await get_tree().create_timer(
			PlayerController.STAGGER_SECONDS + 0.35).timeout
	_check("the player recovers automatically without a get-up input",
			is_zero_approx(player._stagger_left)
			and player._stagger_velocity.is_zero_approx())
	_check("the brief camera roll settles rather than becoming a camera state",
			absf(player.camera.rotation.z) < 0.02)

	player.call_locked = true
	_check("a protected call cannot be interrupted by a stray shove",
			not player.stagger(Vector3(3.4, 0.0, 0.0)))
	player.call_locked = false
	_check("a new stumble can begin after the automatic recovery",
			player.stagger(Vector3(3.4, 0.0, 0.0)))
	player.noclip = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("debug noclip cancels rather than suspends a physical stumble",
			is_zero_approx(player._stagger_left)
			and player._stagger_velocity.is_zero_approx()
			and not player.stagger(Vector3(3.4, 0.0, 0.0)))
	player.noclip = false
	_check("zero and non-finite pushes are rejected without mutation",
			not player.stagger(Vector3.ZERO)
			and not player.stagger(Vector3(NAN, 0.0, 0.0))
			and is_zero_approx(player._stagger_left))

	var has_health := false
	for property in player.get_property_list():
		if str(property.name) in ["health", "hp", "damage"]:
			has_health = true
	_check("the stumble introduces no damage or health state", not has_health)

	print("[STREET STAGGER] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _build_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 40.0)
	collision.shape = shape
	collision.position = Vector3(0.0, -0.5, 21.0)
	floor.add_child(collision)
	add_child(floor)


func _kind_index(label: String) -> int:
	for index in StreetTraffic.KINDS.size():
		if str(StreetTraffic.KINDS[index][0]) == label:
			return index
	return -1
