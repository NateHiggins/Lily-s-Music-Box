extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The first-person rubber-hose arm with the real hand: hidden at rest, reaching in
## and gripping while a part is held, palm on the grip, stowed and hidden again after
## release, drawn only by the first-person camera (never in mirrors), with captures.
const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const Arm := preload("res://scripts/player/first_person_hose_arm.gd")
const Receivers := preload("res://scripts/lamp/lamp_optical_receivers.gd")
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
	var mirror_cameras := 0
	var mirror_ok := true
	var lights_kept := true
	for mirror: Node in mirrors:
		var camera: Camera3D = mirror.get("_camera")
		if camera != null:
			mirror_cameras += 1
			mirror_ok = mirror_ok and camera.cull_mask & Arm.LAYER == 0
			# Ordinary lights sit on the depth-light bit while the lamp isolates depth;
			# a mirror must still draw them whenever the eye does.
			lights_kept = lights_kept and camera.cull_mask & Receivers.DEPTH_LIGHT_LAYER == player.camera.cull_mask & Receivers.DEPTH_LIGHT_LAYER
	_require(mirror_cameras > 0 and mirror_ok, "no mirror camera draws the arm (%d of %d mirrors have cameras)" % [mirror_cameras, mirrors.size()])
	_require(player.camera.cull_mask & Receivers.DEPTH_LIGHT_LAYER != 0 and lights_kept, "mirrors keep the ordinary depth-light bit the eye draws")
	_require(Arm.LAYER & (Receivers.DEPTH_CAMERA_EXCLUSIONS | Receivers.LAYER) == 0, "the arm layer is none of the lamp's reserved layers")
	_require(_arm_keeps_depth_isolation(arm, "mounted"), "with the arm mounted, nothing of the arm disturbs the lamp's depth isolation")
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
	var socket: BoneAttachment3D = arm.glove_socket()
	var wrist_gap := -1.0
	if socket != null:
		wrist_gap = socket.global_position.distance_to(arm.palm_position() - socket.global_basis.y.normalized() * Arm.PALM_FROM_WRIST * Arm.GLOVE_SCALE)
	_require(socket != null and socket.name == "GloveSocket" and socket.bone_name == "Hand" and int(socket.get_meta("render_layers", 0)) == Arm.LAYER and wrist_gap >= 0.0 and wrist_gap < 0.005,
			"the glove socket rides the Hand bone at the wrist, on the arm's layer (%.4f m)" % wrist_gap)
	_require(_arm_keeps_depth_isolation(arm, "drawn"), "with the arm drawn, nothing of the arm disturbs the lamp's depth isolation")
	var depth_view: Camera3D = world.get_node("LampAtmosphere").get("scene_shadow").get("camera")
	_require(arm.visible and depth_view != null and depth_view.cull_mask & Arm.LAYER == 0,
			"with the glove visible, the lamp's depth camera does not draw the arm (mask %d)" % (depth_view.cull_mask if depth_view != null else -1))
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
	# Something held, nothing grabbed: the held-objects slice raises the flag and the
	# glove carries it low in the corner of the view, then stows when it is put away.
	arm.set_holding(true)
	await get_tree().create_timer(0.5).timeout
	var carry: Vector3 = player.camera.to_global(Arm.CARRY)
	var carry_gap: float = arm.palm_position().distance_to(carry)
	_require(arm.visible and arm.reach >= 0.999 and arm.curl >= 0.95 and carry_gap < 0.03,
			"holding something with no grab, the glove carries it in view (%.3f m from its place)" % carry_gap)
	_require(arm.glove_socket().to_global(arm.palm_offset()).distance_to(arm.palm_position()) < 0.005, "palm_offset() is the palm in socket space")
	await _capture_interaction("hose_arm_carrying")
	arm.set_holding(false)
	await get_tree().create_timer(0.5).timeout
	_require(not arm.visible and arm.reach == 0.0, "put away, the arm stows itself again")


## The lamp's depth camera skips ordinary lights only while no drawn geometry uses
## its excluded bits (the receivers' depth_geometry_clear). The arm must never be
## such geometry. If isolation is off for some other reason, the test names the
## offending nodes rather than blaming the arm.
func _arm_keeps_depth_isolation(arm: Node3D, when: String) -> bool:
	var air: Node = world.get_node_or_null("LampAtmosphere")
	if air == null:
		return false
	var receivers: RefCounted = air.get("receivers")
	var shadow: Node = air.get("scene_shadow")
	if receivers == null or shadow == null:
		return false
	var offenders: Array[String] = []
	var arm_offends := false
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).layers & Receivers.DEPTH_CAMERA_EXCLUSIONS:
			arm_offends = arm_offends or arm.is_ancestor_of(node)
			if offenders.size() < 8:
				offenders.append("%s layers=%d" % [world.get_path_to(node), (node as GeometryInstance3D).layers])
	var clear := bool(receivers.get("depth_geometry_clear"))
	print("HOSE ARM DEPTH ISOLATION (%s): isolate=%s clear=%s excluded=%d offenders=%s" % [when, receivers.get("isolate_depth_lights"), clear, int(shadow.get("excluded_light_layers")), offenders])
	# The arm never offends; and isolation is on unless something else offends.
	return bool(receivers.get("isolate_depth_lights")) and not arm_offends and (clear or not offenders.is_empty())
