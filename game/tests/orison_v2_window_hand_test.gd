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

	# The drapes hang from their rings: every hook spans from a ring's foot to the
	# heading, at the rod's depth, whether drawn or open.
	for cloth in [0.1, 0.95]:
		_actor.restore_settings({"raise": _actor.raised, "tilt_degrees": _actor.tilt_degrees, "curtain_open": cloth})
		_require(_heading_carried(_actor), "the heading is carried by its rings at curtain_open %.2f" % cloth)
	_require(_actor._sheers != null and _actor.sheer_fabric == "ninon" and not _actor.sheer_lace,
			"4B hangs its plain ninon glass curtain behind the drapes")

	# The households' drapery, as authored (design/ORISON_DRAPERY_2026-10-24.md).
	for wanted in [["1A", "linen", true], ["2A", "linen", false], ["3D", "velour", false], ["6C", "velour", true]]:
		var actor := _main_window(str(wanted[0]))
		if not _require(actor != null, "%s has a main-room window" % wanted[0]): continue
		_require(actor.fabric == wanted[1] and ((actor._sheers != null) == (wanted[0] != "3D"))
				and (actor.sheer_lace == wanted[2] or wanted[0] == "3D"),
				"%s hangs %s%s" % [wanted[0], wanted[1], " over lace-edged ninon" if wanted[2] else ""])
		_require(_heading_carried(actor), "%s's heading is carried by its rings" % wanted[0])
		_actor = actor
		var floor_y: float = actor.global_position.y - float(actor.height) - 0.6
		var at: Vector3 = actor.to_global(Vector3(0.0, 0.0, 1.6))
		player.global_position = Vector3(at.x, floor_y, at.z)
		player.velocity = Vector3.ZERO
		for _frame in 6:
			await get_tree().physics_frame
		await _shot("drapery_" + str(wanted[0]))


func _main_window(unit: String) -> Node3D:
	for actor: Node3D in get_tree().get_nodes_in_group("v2_window_treatments"):
		# Match the room, not the window's name: 6C's main window is F06_C_WINDOW_1.
		if str(actor.get_meta("unit")) == unit and str(actor.get_meta("space")).ends_with("_MAIN"):
			return actor
	return null


## The heading hangs from the rings: each hook's top reaches a ring's foot and its
## bottom reaches the panel's top edge, all at the rod's depth.
func _heading_carried(actor: Node3D) -> bool:
	if actor._rings == null or actor._panels == null:
		return false
	var top: float = actor._panels.multimesh.get_instance_transform(0).origin.y
	for i in actor._rings.multimesh.instance_count:
		var ring: Transform3D = actor._rings.multimesh.get_instance_transform(i)
		var hook: Transform3D = actor._hooks.multimesh.get_instance_transform(i)
		var foot: float = ring.origin.y - actor.RING_OUTER
		if absf(ring.origin.z - actor.ROD_DEPTH) > 0.0005 or absf(hook.origin.z - actor.ROD_DEPTH) > 0.0005:
			return false
		if absf(hook.origin.x - ring.origin.x) > 0.0005:
			return false
		var hook_top: float = hook.origin.y + actor.HOOK * 0.5
		var hook_bottom: float = hook.origin.y - actor.HOOK * 0.5
		if hook_top < foot - 0.0015 or hook_bottom > top + 0.0015:
			return false
	return true


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
