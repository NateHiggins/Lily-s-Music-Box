extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## A knock in the production V2 root: the real door control on a fourth-floor
## apartment, the lower-third panel over the actual corridor, a reply by its
## number key, and the first conversation's handheld note on the carried set.
## Nothing is seeded: whoever is home behind the chosen door answers.

const DomesticDoors := preload("res://scripts/building/orison_v2_domestic_doors.gd")

func _init() -> void:
	route_label = "V2 KNOCK ROUTE"

func _prepare_player_start() -> void:
	# Placed in _route beside the chosen door; the production arrival is not
	# under test here.
	player.velocity = Vector3.ZERO

func _route() -> void:
	var conversations: ResidentConversations = world.conversations
	if not _require(conversations != null and conversations.errors.is_empty(),
			"resident conversations mounted without tree errors"): return
	var pick := _pick_door()
	if not _require(not pick.is_empty(), "a fourth-floor neighbour is home to knock on"): return
	var door: DoorProp = pick.door
	var unit: String = pick.unit
	var resident: String = pick.resident
	var knock_point: Vector3 = door._body.to_global(Vector3(door.width * 0.5,
			minf(door.height - 0.55, 1.48), 0.0))
	if not _require(door.get_node_or_null("KnockPanel") == null
			and door._body.get_node_or_null("KnockPanel") != null,
			"the apartment door carries its knock control"): return
	var side := await _stand_at(door, knock_point, unit)
	if not _require(side != 0.0, "the player can stand on the corridor side and aim at the knock"): return
	if not _require(world.player_unit() != unit, "the player is in the corridor, not in %s" % unit): return
	var device: Node = player.carried_device
	var printed_before := _printed_count(device)
	if not await _use(door, knock_point, "knock_" + unit): return
	await get_tree().create_timer(0.4).timeout
	var panel: CaseDialoguePanel = conversations.dialogue
	var tree: Dictionary = conversations.trees.get(resident, {})
	var first: String = str(tree.get("entries", {}).get("first_stable", ""))
	if not _require(panel.attention_active() and player.call_locked
			and panel.current_node_id == first,
			"the knock opens %s's first contact at %s" % [resident, first]): return
	var centre := get_viewport().get_visible_rect().size * 0.5
	var column_top := panel._column.get_global_rect().position.y
	print("[KNOCK ROUTE] column_top=%.0f centre_y=%.0f replies=%d" % [
			column_top, centre.y, panel.offered_labels().size()])
	_require(column_top > centre.y, "the lower third leaves the corridor's centre clear")
	var evidence_offered := false
	for label in panel.offered_labels():
		if str(label).contains("[") and str(label).contains("]"):
			evidence_offered = true
	_require(not evidence_offered, "no evidence reply is offered from the corridor")
	await _capture_now("knock_conversation")
	# A reply by its number key, through the input layer the player uses.
	var before_node := panel.current_node_id
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.physical_keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_require(panel.current_node_id != before_node,
			"pressing 1 takes the first reply (%s -> %s)" % [before_node, panel.current_node_id])
	for i in 40:
		if not panel.attention_active(): break
		panel.choose(0)
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_require(not panel.attention_active() and not player.call_locked,
			"the conversation ends and releases the player")
	_require(RealityState.conversation_visits(resident) == 1, "the campaign recorded the visit")
	_require(not conversations.note_pending("first_conversation"),
			"the first conversation filed its handheld note")
	_require(_printed_count(device) == printed_before + 1,
			"the carried set printed exactly one card for it (%d -> %d)" % [printed_before, _printed_count(device)])
	await get_tree().create_timer(0.6).timeout
	await _capture_now("knock_field_note")

## The first fourth-floor apartment entry, other than the player's own, whose
## tenant is home now. Nothing about who is home is seeded.
func _pick_door() -> Dictionary:
	var conversations: ResidentConversations = world.conversations
	for identity in DomesticDoors.SPECS:
		var spec: Dictionary = DomesticDoors.SPECS[identity]
		if str(spec.get("kind", "")) != "apartment_entry" or not str(identity).begins_with("F04"):
			continue
		var unit := str(spec.get("unit", ""))
		if unit == "" or unit == DoorKeyring.player_unit():
			continue
		var opening := world.adapter.resolve(identity) as Node3D
		var door := opening.get_node_or_null(identity + "_Leaf") as DoorProp if opening != null else null
		if door == null:
			continue
		for resident in conversations.residents_in(unit):
			if world.resident_is_home(resident) and conversations.has_tree(resident):
				return {"door": door, "unit": unit, "resident": resident, "identity": identity}
	return {}

## Stand a metre off the leaf on whichever side the ray reaches the knock
## from, and face it. Returns the side used, or 0 when neither works.
func _stand_at(door: DoorProp, knock_point: Vector3, unit: String) -> float:
	for side in [1.0, -1.0, 1.5, -1.5, 0.8, -0.8]:
		player.global_position = door.to_global(Vector3(door.width * 0.5, 0.02, side))
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.camera.look_at(knock_point)
		await get_tree().process_frame
		var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
				player.camera.global_position - player.camera.global_basis.z * 2.1)
		ray.collide_with_areas = true
		ray.exclude = [player.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		var node := hit.get("collider") as Node
		print("[KNOCK ROUTE] side=%.2f player=%s room=%s unit=%s hit=%s" % [side,
				str(player.global_position), world.room_at_world(player.global_position),
				world.player_unit(), str(node.name) if node != null else "none"])
		if node != null and node.name == "KnockPanel" and world.player_unit() != unit:
			return side
	return 0.0

static func _printed_count(device: Node) -> int:
	if device == null or not is_instance_valid(device):
		return -1
	var inner: Variant = device.get("device")
	if inner != null and is_instance_valid(inner):
		return int(inner.get("printed_count"))
	return -1

func _capture_now(identity: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + ".png"))
