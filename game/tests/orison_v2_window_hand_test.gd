extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The 4B window by hand, in the production V2 root: the player's own ray and
## mouse raise and lower the blind on its pull cord, angle the slats up and down
## on the wand, and draw and open the drapes along the rod. Each value moves
## continuously, holds where it is released, and is what the household record
## saves. Windowed: the runtime refuses headless (front trim reads identity).

const WINDOW_ID := "F04_B_MAIN_WINDOW_W_N"
const Hand := preload("res://tests/orison_v2_first_slice_contract_test.gd")

var _actor: Node3D

func _init() -> void:
	route_label = "V2 WINDOW BY HAND"

func _prepare_player_start() -> void:
	player.velocity = Vector3.ZERO

func _route() -> void:
	_actor = world.adapter.root.get_node_or_null(WINDOW_ID + "/WindowTreatment") as Node3D
	if not _require(_actor != null, "4B's north window carries its treatment"): return
	var level_y: float = world.adapter.root.to_global(Vector3(0.0, float(world.adapter.root.level_y["F04"]), 0.0)).y
	var stance := Vector3.ZERO
	for depth in [1.0, -1.0]:
		var at: Vector3 = _actor.to_global(Vector3(0.0, 0.0, depth))
		stance = Vector3(at.x, level_y + 0.02, at.z)
		player.global_position = stance
		player.velocity = Vector3.ZERO
		for _frame in 6:
			await get_tree().physics_frame
		if _reaches(_actor.get_node("LiftControl") as Node3D): break
	if not _require(_reaches(_actor.get_node("LiftControl") as Node3D),
			"the player stands in the room and reaches the pull cord"): return
	await _shot("window_before")

	# The blind: up on the cord, then most of the way down.
	var lift_extent := 0.45
	if not await _drive("LiftControl", 0.85 * lift_extent, "raise the blind"): return
	_require(absf(_actor.raised - 0.85) < 0.03, "the blind rises to where it is let go (%.2f)" % _actor.raised)
	await _shot("window_raised")
	if not await _drive("LiftControl", 0.1 * lift_extent, "lower the blind"): return
	_require(absf(_actor.raised - 0.1) < 0.03, "the blind lowers to where it is let go (%.2f)" % _actor.raised)

	# The slats: angled up, then down, on the wand.
	if not await _drive("TiltControl", deg_to_rad(45.0), "angle the slats up"): return
	_require(absf(_actor.tilt_degrees - 45.0) < 3.0, "the slats hold at 45 degrees (%.1f)" % _actor.tilt_degrees)
	await _shot("window_slats_up")
	if not await _drive("TiltControl", deg_to_rad(-45.0), "angle the slats down"): return
	_require(absf(_actor.tilt_degrees + 45.0) < 3.0, "the slats hold at -45 degrees (%.1f)" % _actor.tilt_degrees)
	await _shot("window_slats_down")

	# The drapes: drawn nearly shut, then opened wide.
	var cloth_extent := (float(_actor.width) + 0.24) * 0.38
	if not await _drive("CurtainControl", 0.1 * cloth_extent, "draw the drapes"): return
	_require(_actor.curtain_open < 0.15, "the drapes draw nearly shut (%.2f)" % _actor.curtain_open)
	await _shot("window_drapes_drawn")
	if not await _drive("CurtainControl", 0.95 * cloth_extent, "open the drapes"): return
	_require(_actor.curtain_open > 0.9, "the drapes open wide (%.2f)" % _actor.curtain_open)
	await _shot("window_drapes_open")

	# The household record keeps what the hand left.
	for _frame in 4:
		await get_tree().process_frame
	_require(_saved_matches(_actor.settings_snapshot()),
			"the household record saves the blind and drapes as left: %s" % [_actor.settings_snapshot()])


## Re-stand facing the control, then grab, drag and release it with the player's
## own pointer through the shared hand driver.
func _drive(control_name: String, goal: float, label: String) -> bool:
	var control := _actor.get_node(control_name) as Node3D
	if not _require(_reaches(control), "the player's ray reaches the control: " + label): return false
	var hand = Hand.PatrolHand.new()
	add_child(hand)
	hand.player = player
	player.set_mouse_released(false)
	var moved: bool = await hand.operate(control.global_position, goal, _actor)
	hand.free()
	return _require(moved and not player._grab.active(), "actual grab, mouse motion and release: " + label)


func _reaches(control: Node3D) -> bool:
	player.camera.look_at(control.global_position)
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("collider") == control


func _saved_matches(snapshot: Dictionary) -> bool:
	var controls: Variant = RealityState.data.get("v2_household_controls", {})
	if controls is not Dictionary:
		return false
	var records: Variant = (controls as Dictionary).get("records", {})
	if records is not Dictionary:
		return false
	for key in records:
		var record: Variant = records[key]
		if record is Dictionary and str(record.get("kind", "")) == "blind" and str(key).contains(WINDOW_ID):
			var value: Dictionary = record.get("value", {})
			return absf(float(value.get("raise", -1)) - float(snapshot.raise)) < 0.001 \
					and absf(float(value.get("tilt_degrees", 999)) - float(snapshot.tilt_degrees)) < 0.01 \
					and absf(float(value.get("curtain_open", -1)) - float(snapshot.curtain_open)) < 0.001
	return false


func _shot(identity: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	player.camera.look_at(_actor.to_global(Vector3(0.0, -0.75, 0.0)))
	for _frame in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))
