extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The first-person rubber-hose arm with the real hand: hidden at rest, reaching in
## and gripping while a part is held, palm on the grip, stowed and hidden again after
## release, drawn only by the first-person camera (never in mirrors), with captures.
const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const Arm := preload("res://scripts/player/first_person_hose_arm.gd")
var _hand: Node

func _init() -> void:
	route_label = "HOSE ARM"


func _route() -> void:
	var arm: Node3D = player.camera.get_node_or_null("FirstPersonHoseArm")
	if not _require(arm != null and arm.skeleton != null, "the first-person hose arm is mounted on the player camera"):
		return
	var draws := arm.find_children("*", "MeshInstance3D", true, false)
	_require(draws.size() >= 3 and draws.all(func(d): return d.layers == Arm.LAYER and d.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
			"the arm draws on its own layer and casts no shadow")
	_require(player.camera.cull_mask & Arm.LAYER != 0, "the first-person camera draws the arm layer")
	var mirrors := world.find_children("*", "Node", true, false).filter(func(n): return n.get_script() == preload("res://scripts/building/planar_mirror_renderer.gd"))
	var mirror_ok := true
	for mirror: Node in mirrors:
		var camera: Camera3D = mirror.get("_camera")
		if camera != null:
			mirror_ok = mirror_ok and camera.cull_mask & Arm.LAYER == 0
	_require(mirror_ok, "no mirror camera draws the arm (%d mirrors)" % mirrors.size())
	_require(not arm.visible, "at rest the arm is out of view")
	_hand = Hands.new()
	_hand.set_meta("shared_world_validation", true)
	add_child(_hand)
	_hand.player = player
	var counter: Node3D = world.shop_counters.hardware_paint
	var forward: Vector3 = -counter.global_basis.z
	player.global_position = counter.global_position + forward * 0.95 + Vector3.DOWN * 1.1
	player.velocity = Vector3.ZERO
	for frame in 3:
		await get_tree().physics_frame
	player.camera.look_at(counter.global_position)
	await _capture_interaction("hose_arm_before")
	await _hand.aim(counter.selector.to_global(Vector3(0, .094, -.025)))
	_hand.click()
	if not _require(player._grab.active(), "the real hand takes the picker"):
		return
	# The reach takes a fifth of a second, drawn on twos; wait by time, not frames.
	await get_tree().create_timer(0.5).timeout
	var grip: Vector3 = player._grab.target.part.to_global(player._grab.contact)
	var gap: float = arm.palm_position().distance_to(grip)
	_require(arm.visible and arm.reach >= 0.999 and arm.curl >= 0.95, "holding, the arm has reached in and the glove is closed (reach %.2f, curl %.2f)" % [arm.reach, arm.curl])
	_require(gap < 0.06, "the drawn palm is on the grip (%.3f m)" % gap)
	await _capture_interaction("hose_arm_holding")
	# Move the picker while holding: the glove follows it.
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-60, 0)
	player._unhandled_input(motion)
	for frame in 20:
		await get_tree().process_frame
	grip = player._grab.target.part.to_global(player._grab.contact)
	_require(arm.palm_position().distance_to(grip) < 0.06, "the glove follows the moved part (%.3f m)" % arm.palm_position().distance_to(grip))
	await _capture_interaction("hose_arm_moved")
	_hand.click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(0.5).timeout
	_require(not arm.visible and arm.reach == 0.0, "after release the arm stows itself out of view")
	await _capture_interaction("hose_arm_after")
