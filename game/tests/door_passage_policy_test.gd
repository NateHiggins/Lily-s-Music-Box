extends Node3D
## Actual leaf/key/physics owners in a nearby isolated fixture. Player directional
## movement, installed door-frame fit and mechanical closer repair are separate
## programmes; this checks policy, custody and occupied leaf sweeps directly.
const Errors := preload("res://tests/guide_bell_error_capture.gd")
const Closer := preload("res://scripts/building/orison_v2_door_check_prop.gd")

class Carrier extends CharacterBody3D:
	var _capsule := CapsuleShape3D.new()
	var held: PhysicsBody3D
	func held_stock_body() -> PhysicsBody3D: return held

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var started := Time.get_ticks_msec()
var before_inputs: Dictionary
var endpoint_observations: Array[Dictionary] = []
var leaf_notifications: Array[Dictionary] = []

func _ready() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok: failures.append(label)
	print("DOOR POLICY: ", label, " = ", ok)

func _settle(door: DoorProp) -> void:
	for frame in 120:
		await get_tree().physics_frame
		if not door._moving and not door._key_turning:
			_endpoint(door, "command_callback_observed")
			# The idle Tween's settled callback precedes the AnimatableBody's
			# final sync-to-physics publication. physics_frame itself is emitted
			# before that tick; wait through it and the following boundary.
			await get_tree().physics_frame
			await get_tree().physics_frame
			_endpoint(door, "physics_endpoint_observed")
			return
	_check(false, "key and leaf finish within bounded fixture wait")

func _endpoint(door: DoorProp, phase: String) -> void:
	var target := door.motion_target_angle(door.open)
	var server_transform: Transform3D = PhysicsServer3D.body_get_state(door._body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	var server_angle := (door.global_transform.affine_inverse() * server_transform).basis.get_euler().y
	var sample := {"phase": phase, "physics_frame": Engine.get_physics_frames(),
		"angle": door._body.rotation.y, "physics_angle": server_angle, "target": target,
		"error_rad": door._body.rotation.y - target, "moving": door._moving,
		"key_turning": door._key_turning, "ready": door.is_ready_for_passage()}
	endpoint_observations.append(sample)
	print("DOOR POLICY ENDPOINT: ", JSON.stringify(sample))

func _leaf_changed(door: DoorProp) -> void:
	leaf_notifications.append({"door": str(door.name), "angle": door.mechanism_snapshot().angle,
		"moving": door._moving, "revision": door.motion_revision, "physics_frame": Engine.get_physics_frames()})

func _run() -> void:
	var logger := Errors.new()
	OS.add_logger(logger)
	before_inputs = _inputs()
	var prior: Dictionary = RealityState.data
	var preview: bool = RealityState.begin_preview_campaign(self)
	_check(preview, "isolated nonpersistent campaign acquired")
	if not preview:
		_write(logger.errors); OS.remove_logger(logger); get_tree().quit(1); return
	var door := DoorProp.new()
	door.name = "PassagePolicyOwnDoor"
	door.unit = DoorKeyring.player_unit()
	door.door_kind = "apartment_entry"
	door.width = .91
	add_child(door)
	door.manipulation_changed.connect(_leaf_changed.bind(door))
	var player := Carrier.new()
	player._capsule.radius = .33; player._capsule.height = 1.524
	var player_shape := CollisionShape3D.new()
	player_shape.shape = player._capsule
	player_shape.position.y = player._capsule.height * .5
	player.add_child(player_shape)
	add_child(player); player.add_to_group("player_controller")
	player.global_position = door.to_global(Vector3(door.width * .5, 0, 2.0))
	_check(door.is_in_group("passage_doors"), "full-size leaf registered for directional passage")
	_check(door.manipulation_target({"collider": door._body}).get("legacy", false), "full-size leaf permits ordinary primary click")
	_check(door.has_node("HingedLeaf/KeyholeControl") and door.control_prompt("keyhole") == "Lock door", "actual key barrel has its own clickable control")
	_check(door.passage_allowed() and door.request_passage(player), "authorized player requests actual opening")
	await _settle(door)
	_check(door.is_ready_for_passage() and is_equal_approx(door._body.rotation.y, door.motion_target_angle(true)), "real leaf reaches its authored opening stop")
	_check(leaf_notifications.size() == 1 and not leaf_notifications[0].moving \
		and is_equal_approx(float(leaf_notifications[0].angle), door.motion_target_angle(true)), "save and closer subscribers receive one physics-settled opening snapshot")
	_check(not player.get_collision_exceptions().has(door._body), "player never gains a leaf collision exception")
	var open_angle := door._body.rotation.y
	door._easy.update(30.0)
	_check(door.open and is_equal_approx(door._body.rotation.y, open_angle), "no return mechanism means no timed self-close")
	door.hold_passage(player)
	_check(door.passage_held(), "active approach can transiently hold a genuine closer")
	door.release_passage(player)
	_check(not door.passage_held(), "exit or cancellation releases passage custody")
	_check(leaf_notifications.size() == 2, "final approach release notifies real closer ownership")
	door.release_passage(player)
	_check(leaf_notifications.size() == 2, "repeated release cannot manufacture another proof handoff")
	var vanished := Node3D.new(); add_child(vanished)
	door.hold_passage(vanished); vanished.free()
	_check(not door.passage_held(), "dead passage owner leaves no durable hold")
	_check(leaf_notifications.size() == 3, "dead final owner publishes one closer handoff")
	door.hold_passage(player)
	await get_tree().create_timer(1.1).timeout
	_check(not door.passage_held(), "unrenewed passage lease expires after one second")
	_check(leaf_notifications.size() == 4, "expired final owner publishes one closer handoff")
	door.hold_passage(player)
	var before_manual := door.motion_revision
	door.interact(player)
	_check(not door.passage_held() and door.motion_revision > before_manual, "accepted manual motion supersedes passage custody")
	await _settle(door)
	_check(not door.open, "explicit primary leaf action closes an unoccupied doorway")
	_check(leaf_notifications.size() == 5 and is_zero_approx(float(leaf_notifications[-1].angle)), "manual close publishes one final closed snapshot")
	_check(not (door.interact_control("keyhole", player) as Dictionary).is_empty(), "clickable keyhole operates the existing key owner")
	await _settle(door)
	_check(door.leaf_state == "locked", "explicit key action locks")
	_check(not door.passage_allowed("unknown_resident") and not door.request_passage(null, "unknown_resident"), "unrelated character cannot borrow player's authority")
	var locked_snapshot := DoorKeyring.book().duplicate(true)
	RealityState.save_write_blocked = true
	_check(not door.request_passage(player) and DoorKeyring.book() == locked_snapshot, "blocked save owner refuses automatic unlock without mutation")
	RealityState.save_write_blocked = false
	_check(door.request_passage(player), "player's actual key permits automatic unlock and opening")
	await _settle(door)
	_check(door.leaf_state == "closed" and DoorKeyring.initial_state(door, "locked") == "closed", "automatic unlock persists and carries no latent relock")
	var snapshot := door.mechanism_snapshot()
	var identity := door.name
	door.free()
	door = DoorProp.new(); door.name = identity; door.unit = DoorKeyring.player_unit()
	door.door_kind = "apartment_entry"; door.width = .91; door.leaf_state = "locked"
	add_child(door); door.restore_mechanism(snapshot)
	_check(door.is_ready_for_passage() and door.leaf_state != "locked", "reconstructed open leaf keeps the remembered unlocked state")
	door.restore_mechanism({"angle": .25})
	_check(not door.is_ready_for_passage(), "partial restored leaf never advertises full passage clearance")
	_check(door.request_passage(player) and door._moving, "partial restored opening requests a real continuation tween")
	await _settle(door)
	_check(is_equal_approx(door._body.rotation.y, door.motion_target_angle(true)), "partial opening reaches full stop without transform snap")
	# A player on the pull side is a genuine obstruction to the opening arc.
	door.restore_mechanism({"angle": 0.0})
	player.global_position = door.to_global(Vector3(.45, 0, -.5))
	_check(not door.opening_clear() and not door.request_passage(player), "opening waits for player to clear the real swing")
	_check(is_zero_approx(door._body.rotation.y), "refused opening leaves the physical leaf still")
	player.global_position = door.to_global(Vector3(.45, 0, 2.0))
	var stock := StaticBody3D.new()
	var stock_shape := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = Vector3(.3, .4, .3); stock_shape.shape = box
	stock.add_child(stock_shape); add_child(stock); player.held = stock
	stock.global_position = door.to_global(Vector3(.45, 1, -.5))
	_check(not door.opening_clear(), "held object's actual collision shape obstructs opening")
	_check(not stock.get_collision_exceptions().has(door._body), "held stock never gains a leaf collision exception")
	stock.global_position = Vector3(4, 1, 4)
	_check(door.opening_clear(), "moving held stock clear restores opening eligibility")
	player.held = null; stock.free()
	var visitor := Node3D.new(); add_child(visitor); visitor.add_to_group("animated_residents")
	visitor.global_position = door.to_global(Vector3(.45, 0, -.5))
	_check(not door.opening_clear(), "visible resident obstructs opening")
	visitor.hide()
	_check(door.opening_clear(), "hidden absent presentation does not obstruct the leaf")
	visitor.free()
	_check(door.request_passage(player), "clear opening resumes through the same door owner")
	await _settle(door)
	player.global_position = door.to_global(Vector3(.45, 0, -.5))
	var closer := Closer.new()
	_check(closer._someone_in_the_swing(door), "actual mechanical closer consults player-inclusive sweep clearance")
	closer.free()
	door.interact(player)
	_check(not door._moving and door.open, "manual close also refuses an occupied swing")
	player.global_position = door.to_global(Vector3(.45, 0, 2.0))
	door.interact(player); await _settle(door)
	_check(not door.open and door.leaf_state != "locked", "explicit later close leaves lock choice explicit")
	var cabinet := DoorProp.new(); cabinet.door_kind = "cabinet"; cabinet.height = .7
	cabinet.position.x = 4; add_child(cabinet)
	_check(not cabinet.is_in_group("passage_doors") and cabinet.manipulation_target({"collider": cabinet._body}).get("kind") == "hinge", "cabinet retains direct hand manipulation")
	cabinet.manipulation_changed.connect(_leaf_changed.bind(cabinet))
	var before_cabinet := leaf_notifications.size()
	_check(cabinet._take_leaf(), "cabinet still accepts its direct hand owner")
	cabinet._move_by_hand(.4); cabinet._release_leaf()
	await _settle(cabinet)
	_check(leaf_notifications.size() == before_cabinet + 1 and is_equal_approx(float(leaf_notifications[-1].angle), .4), "cabinet hand release publishes one final snapshot without duplicate notifications")
	cabinet.free(); door.free(); player.free()
	_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior), "original campaign restored")
	_check(logger.errors.is_empty(), "no script or engine errors")
	_write(logger.errors)
	OS.remove_logger(logger)
	print("DOOR PASSAGE POLICY: ", checks.size(), " checks, ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _inputs() -> Dictionary:
	var result := {}
	for path: String in ["res://scripts/props/door_prop.gd", "res://scripts/props/easy_door_motion.gd",
			"res://scripts/building/orison_v2_door_check_prop.gd", "res://scripts/game/door_keyring.gd",
			"res://tests/door_passage_policy_test.gd", "res://tests/DoorPassagePolicyTest.tscn"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return result

func _write(errors: Array[String]) -> void:
	_check(_inputs() == before_inputs, "executed source inputs unchanged")
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = "user://tests/door_passage_policy"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": false, "selector": "v2",
		"scope": "Isolated actual DoorProp, key persistence and collision-shape occupant checks; direct owner calls. No directional player movement, installed doorway fit, repaired closer mechanics or artistic acceptance.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/tests/door_passage_policy_test.gd", "inputs": before_inputs},
		"contracts": {"leaf_policy": {"executed": true, "status": "PASS" if passed else "FAIL"}},
		"checks": checks, "failures": failures, "engine_errors": errors,
		"endpoint_observations": endpoint_observations, "leaf_notifications": leaf_notifications}
	FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
