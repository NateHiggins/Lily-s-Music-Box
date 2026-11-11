extends Node
## The domestic witnesses in V2 (v1r_witness_tells_20261109): a resident's
## intrusion reaches the household object V2 gave their flat, the object
## misbehaves and then puts itself back exactly, one of 4B's own things
## answers every intrusion, and nothing moves while it is watched.
const Witnesses := preload("res://scripts/building/orison_v2_domestic_witnesses.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _until(ready: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if ready.call():
			return true
		await get_tree().process_frame
	return bool(ready.call())


func _settle(node: Node) -> void:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while (quiet < 60 or not node.can_process()) and Time.get_ticks_msec() - began < 90000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	var witnesses: Node = world.get("domestic_witnesses")
	_check(witnesses != null and witnesses.get_script() == Witnesses, "V2 composes the domestic witnesses")
	if witnesses == null:
		_finish(world)
		return
	await _settle(witnesses)
	_check(witnesses.errors.is_empty() and witnesses.unmatched.is_empty(),
		"every tell found its V2 object (%s %s)" % [witnesses.errors, witnesses.unmatched])
	_check(witnesses.tells.size() == 19, "all nineteen of V1's tells are in V2: six on objects V2 had, thirteen on the possessed objects (%d)" % witnesses.tells.size())
	_check(world.sanity.intruded.is_connected(witnesses._on_intruded), "the routing is bound to the sanity director")

	# Each tell sits in its resident's flat.
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Witnesses.DATA))
	for spec: Dictionary in catalog.tells:
		var tell: Node = witnesses.tells.get(str(spec.id))
		if tell == null:
			continue
		_check(str(world.unit_at_world(tell.target.global_position)) == str(spec.unit),
			"%s is in %s" % [spec.id, spec.unit])

	# Unwatched (no player given), the director's own signal moves the object.
	witnesses.player = null
	var plant: Node = witnesses.tells["malcolm_plant"]
	var home: Transform3D = plant.target.transform
	world.sanity.intruded.emit("malcolm_memory_plants", 2)
	_check(plant.busy and not plant.target.transform.is_equal_approx(home), "Malcolm's intrusion turns the plant in 3A")
	_check(absf(angle_difference(plant.target.rotation.y, home.basis.get_euler().y)) > 0.9, "by about a third of a turn")
	var camera: Node = witnesses.tells["sacha_camera"]
	_check(not camera.busy, "nobody else's object answers Malcolm's case")
	var relay: Node = witnesses.tells["player_smart_speaker"]
	var radio: Node3D = relay.target
	_check(relay.busy and bool(radio.possessed) and bool(radio.powered), "one of 4B's own things answers: the wireless takes a voice")
	plant.restore()
	relay.restore()
	_check(plant.target.transform.is_equal_approx(home) and not plant.busy, "the plant is put back exactly")
	_check(not bool(radio.possessed) and not bool(radio.powered), "the wireless is as its listener left it")

	# Tier scales the camera's turn; the canvas hangs upside down in place.
	var tripod_home: Transform3D = camera.target.transform
	_check(witnesses.force("sacha_camera_delay", 3), "force routes Sacha's case")
	_check(is_equal_approx(absf(angle_difference(camera.target.rotation.y, tripod_home.basis.get_euler().y)), 0.34 * 3.0),
		"the camera has turned three steps after the player")
	witnesses.restore_all()
	var canvas: Node = witnesses.tells["iris_picture_frame"]
	var canvas_home: Transform3D = canvas.target.transform
	var centre_before: Vector3 = _centre(canvas.target)
	witnesses.force("iris_runaway_paint", 2)
	_check(canvas.busy and _centre(canvas.target).distance_to(centre_before) < 0.005
			and not canvas.target.transform.basis.is_equal_approx(canvas_home.basis),
		"Iris's canvas turns over where it hangs")
	witnesses.restore_all()
	_check(canvas.target.transform.is_equal_approx(canvas_home), "and hangs true again")
	var knob_tell: Node = witnesses.tells["cal_radio"]
	var knob: Node3D = knob_tell.target.get("_tuning_knob")
	var knob_home := knob.rotation
	witnesses.force("cal_memory_radio", 2)
	_check(not knob.rotation.is_equal_approx(knob_home), "Cal's set has been tuned by nobody")
	witnesses.restore_all()
	_check(knob.rotation.is_equal_approx(knob_home), "and is tuned back")

	# It restores itself on its own clock (tier 1: ten seconds).
	witnesses.force("malcolm_memory_plants", 1)
	_check(plant.busy, "the plant turns again")
	_check(await _until(func() -> bool: return not plant.busy, 14.0), "and turns back by itself")
	_check(plant.target.transform.is_equal_approx(home), "to exactly where it stood")

	# Watched, it does not move: the player stands and looks at it.
	var eye: Node3D = world.player
	witnesses.player = eye
	world.player.set_physics_process(false)
	var watched: Node = witnesses.tells["sacha_camera"]
	var watched_home: Transform3D = watched.target.transform
	var at: Vector3 = watched.target.global_position
	for i in 20:
		world.player.global_position = at + Vector3(1.3, 0.0, 0.3) - Vector3(0, fposmod(at.y, 3.2), 0)
		world.player.camera.look_at(at + Vector3(0, 0.1, 0))
		await get_tree().physics_frame
	world.player.global_position = at + Vector3(1.3, 0.0, 0.3) - Vector3(0, fposmod(at.y, 3.2), 0)
	world.player.camera.look_at(at + Vector3(0, 0.1, 0))
	_check(watched._watched(eye), "the player is looking at the camera on its tripod")
	_check(witnesses.force("sacha_camera_delay", 2) and watched.target.transform.is_equal_approx(watched_home) and not watched.busy,
		"watched, it only ticks and stays where it is")
	_finish(world)


static func _centre(node: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for draw: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var world_box := draw.global_transform * draw.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box.get_center()


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 DOMESTIC WITNESSES] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
