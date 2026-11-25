extends "res://tests/carried_case_route_test.gd"
## Held objects live in the inventory (order w4b7f08c909bb; Lily 2026-11-24, rulings
## held_put_down_20261124 and held_scope_20261124). In the production V2 root, with
## real player clicks and an isolated primary save:
##   aiming alone changes nothing; a pin borne on its board keeps the board on the
##   table; a click takes the pin into the case and the hand (no carry, world copy
##   hidden and without collision); a click on nothing puts it down and it stays in the
##   case; the case's push-out puts it back at its station; a click on the worktable
##   with the board in hand puts the board back; a disk reload keeps a stowed tool
##   stowed and packed; a save naming a stowed tool without its case item is refused.

const STATION := "KitchenPrep_2A"  # an Oak120 table with a rolling pin laid on its board
var executed_checks: Array[Dictionary] = []
var owned_nodes: Array[WeakRef] = []
var owned_shapes: Array[WeakRef] = []
var route_completed := false
var reconstructed := false
var denied := false


func _init() -> void:
	route_label = "KITCHEN TOOL INVENTORY ROUTE"


func _run() -> void:
	var started := Time.get_ticks_msec()
	await super._run()
	var retained_nodes := _retained(owned_nodes)
	var retained_shapes := _retained(owned_shapes)
	_require(retained_nodes == 0 and retained_shapes == 0,
		"the freed world releases its nodes, the hand slot's part and the station's tool shapes")
	_write_contract(started, retained_nodes, retained_shapes)
	get_tree().quit(0 if failures.is_empty() else 1)


func _require(ok: bool, label: String) -> bool:
	executed_checks.append({"label": label, "ok": ok})
	return super._require(ok, label)


func _track_world() -> void:
	owned_nodes.append(weakref(world))
	for node in world.find_children("*", "Node", true, false):
		owned_nodes.append(weakref(node))
		if node is CollisionShape3D and str(node.get_path()).contains(STATION):
			owned_shapes.append(weakref(node.shape))


func _retained(refs: Array[WeakRef]) -> int:
	var count := 0
	for ref in refs:
		if ref.get_ref() != null:
			count += 1
	return count


func _write_contract(started: int, nodes: int, shapes: int) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head_output: Array = []
	var digest_output: Array = []
	_require(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head_output) == 0, "contract records actual repository head")
	_require(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], digest_output) == 0,
		"contract records runtime input digest using existing authority")
	var source_path: String = get_script().resource_path
	var scene_path := "res://tests/KitchenToolInventoryRouteTest.tscn"
	var passed := failures.is_empty() and route_completed and reconstructed and denied
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2",
		"production_runtime": true,
		"scope": "Kitchen prep tools at KitchenPrep_2A live in the inventory: real-click take into case and hand, put-down, worktable and case put-back, disk reload and custody refusal. Other held objects and the first-person view are not covered.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false,
			"elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/" + source_path.trim_prefix("res://"),
			"test_sha256": FileAccess.get_sha256(source_path),
			"test_scene_path": "game/" + scene_path.trim_prefix("res://"),
			"test_scene_sha256": FileAccess.get_sha256(scene_path),
			"repository_head": str(head_output[0]).strip_edges() if not head_output.is_empty() else "",
			"runtime_inputs_sha256": str(digest_output[0]).strip_edges() if not digest_output.is_empty() else ""},
		"contracts": {"production_composition": {"executed": route_completed, "status": status,
				"identities": [STATION, STATION + "/RollingPin", STATION + "/Breadboard", "ReflectedPlayer/HandSlot", "CarriedCase"]},
			"save_reconstruction": {"executed": reconstructed, "status": status},
			"premature_action_denial": {"executed": denied, "status": status},
			"teardown": {"executed": true, "status": status, "measurement_scope": "runtime_owned",
				"retained_nodes": nodes, "retained_resources": shapes, "retained_playbacks": 0,
				"resource_scope": "The 2A station's tool and table collision shapes; shared imported meshes are outside this owner."}},
		"checks": executed_checks, "failures": failures}
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		directory = ProjectSettings.globalize_path("res://../tmp/kitchen-tool-inventory")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if not _require(file != null, "runtime contract output opens"):
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.flush()
	_require(file.get_error() == OK, "runtime contract flushed")
	print("KITCHEN TOOL CONTRACT: ", status, " checks=", executed_checks.size())


func _click_world() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	player._unhandled_input(event)
	await get_tree().physics_frame


func _aim(point: Vector3) -> void:
	player.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(point)


## The held look, as a mirror sees it: a camera that includes the avatar's layer,
## in front of the player and looking back. Windowed runs only; headless draws nothing.
func _capture_held(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	var avatar: Node = world.find_child("ReflectedPlayer", true, false)
	if avatar != null and avatar.has_method("set_reflection_active"):
		avatar.set_reflection_active(true)
	var look := Camera3D.new()
	look.cull_mask = 0xFFFFF
	look.fov = 50.0
	world.add_child(look)
	# Side-on and a little ahead, wherever the room leaves a clear sight line to the hand.
	var chest := player.global_position + Vector3.UP * 1.1
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var placed := false
	for direction: Vector3 in [right + forward * .4, -right + forward * .4, right, -right, right - forward * .5, -right - forward * .5, -forward]:
		var eye := chest + direction.normalized() * 1.2 + Vector3.UP * .15
		var query := PhysicsRayQueryParameters3D.create(chest, eye)
		query.exclude = [player.get_rid()]
		if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			look.global_position = eye
			placed = true
			break
	if not placed:
		look.global_position = chest + right * .7
	look.look_at(chest - Vector3.UP * .1)
	look.make_current()
	for frame in 8:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	player.camera.make_current()
	look.queue_free()
	if avatar != null and avatar.has_method("set_reflection_active"):
		avatar.set_reflection_active(false)


func _clear_feet(at: Vector3) -> bool:
	var collision: CollisionShape3D = null
	for child: Node in player.get_children():
		if child is CollisionShape3D:
			collision = child
			break
	if collision == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = Transform3D(Basis.IDENTITY, at) * collision.transform
	query.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _stand_at(station: Node3D) -> bool:
	for distance: float in [.95, 1.1, .8, 1.25]:
		for x: float in [0., -.2, .2]:
			var feet: Vector3 = station.to_global(Vector3(x, .025, -distance))
			if _clear_feet(feet + Vector3.UP * .02):
				player.global_position = feet
				player.velocity = Vector3.ZERO
				await get_tree().physics_frame
				await get_tree().physics_frame
				return true
	return false


func _route() -> void:
	var state: Node = world.household_state
	var view: Node = world.carried_case_view
	var station: Node3D = world.adapter.resolve(STATION)
	if not _require(state != null and view != null and station != null and station.tools.has("RollingPin") \
			and station.tools.has("Breadboard"), "the installed 2A prep table has its board and pin"):
		return
	_track_world()
	var board: RigidBody3D = station.tools.Breadboard
	var pin: RigidBody3D = station.tools.RollingPin
	var pin_item := CarriedCase.kitchen_tool_item(STATION, "RollingPin")
	var board_item := CarriedCase.kitchen_tool_item(STATION, "Breadboard")
	var path := "user://kitchen_tool_inventory_%d.save" % OS.get_process_id()
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	if not _require(RealityState.save_game(), "the isolated primary is written"):
		return
	if not _require(await _stand_at(station), "a clear stance in front of the 2A table"):
		return
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Aiming alone: the reticle queries every frame and must not take anything.
	await _aim(pin.global_position)
	var aimed: Dictionary = player._grab.find_target()
	for frame in 30:
		player._update_prompt()
		await get_tree().process_frame
	denied = _require(aimed.get("part") == pin and aimed.get("take") == "RollingPin" \
			and not station.stowed.has("RollingPin") and pin.visible and CarriedCase.place_of(pin_item).is_empty(),
		"aiming at the pin selects it and changes nothing")

	# The board bears the pin: it stays on the table.
	RealityState.flush_background_saves()
	var before := FileAccess.get_file_as_bytes(path)
	await _aim(board.to_global(Vector3(0, .02, -.11)))
	_require(player._grab.find_target().get("part") == board, "the board's clear front edge is selected")
	await _click_world()
	RealityState.flush_background_saves()
	denied = denied and _require(not station.stowed.has("Breadboard") and board.visible and CarriedCase.place_of(board_item).is_empty() \
			and CarriedCase.hand().is_empty() and FileAccess.get_file_as_bytes(path) == before,
		"a board bearing the pin is refused and the primary is untouched")

	# Take the pin: into the case and the hand, no carry.
	var pin_rest := pin.transform
	await _aim(pin.global_position)
	await _click_world()
	_require(station.stowed.has("RollingPin") and not pin.visible and pin.collision_layer == 0 \
			and not CarriedCase.place_of(pin_item).is_empty() and CarriedCase.hand() == pin_item \
			and not player._grab.active(), "a click takes the pin into the case and the hand, without a carry")
	var avatar: Node = world.find_child("ReflectedPlayer", true, false)
	if avatar != null and avatar.get("hand_slot") != null:
		_require(avatar.hand_slot.worn == pin_item and avatar.hand_slot.get_child_count() == 1,
			"the avatar's hand slot wears the pin")
		_track_world()
		await _capture_held("held_rolling_pin")

	# Put it down: a click on nothing usable empties the hand; it stays in the case.
	player.camera.look_at(player.camera.global_position + Vector3.UP * 3.0 + Vector3(0.01, 0, 0))
	await get_tree().physics_frame
	await _click_world()
	_require(CarriedCase.hand().is_empty() and station.stowed.has("RollingPin") \
			and not CarriedCase.place_of(pin_item).is_empty(), "putting the pin down keeps it in the case")

	# Reload from disk: still stowed and packed, nothing in hand, no second copy.
	RealityState.flush_background_saves()
	RealityState.load_game()
	await get_tree().physics_frame
	await get_tree().physics_frame
	reconstructed = _require(station.stowed.has("RollingPin") and not pin.visible and not CarriedCase.place_of(pin_item).is_empty() \
			and CarriedCase.hand().is_empty(), "a disk reload keeps the pin stowed and packed")

	# Take the now-free board into the hand, then put it back on the worktable.
	await _aim(board.to_global(Vector3(0, .02, -.11)))
	await _click_world()
	if not _require(station.stowed.has("Breadboard") and CarriedCase.hand() == board_item,
			"with the pin gone the board is taken into the hand"):
		return
	var table: Node3D = station.get_node("Worktable")
	await _aim(station.to_global(Vector3(.2, .88, 0)))
	_require(player._grab.find_target().get("put_back") == "Breadboard", "the worktable offers to take the board back")
	await _click_world()
	_require(not station.stowed.has("Breadboard") and board.visible and board.collision_layer != 0 \
			and CarriedCase.place_of(board_item).is_empty() and CarriedCase.hand().is_empty() \
			and board.transform.is_equal_approx(station.rests.Breadboard), "a click on the worktable puts the board back at its rest")

	# The case's push-out puts the pin back at its own station.
	await _key(KEY_TAB)
	await get_tree().create_timer(0.65).timeout
	var place := CarriedCase.place_of(pin_item)
	if not _require(view.opened and view._stacks.has(pin_item), "the case shows the packed pin"):
		return
	var size := CarriedCase.form_size(str(place.form), bool(place.turned))
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(place.y) + size.y * 0.5))
	_require(view.held_item == pin_item and view._verb_tag(pin_item) == "PUT BACK", "at its table the pin offers PUT BACK")
	await _press(_screen(view, float(place.x) + size.x * 0.5, float(CarriedCase.grid().y) + 2.5))
	await get_tree().create_timer(0.6).timeout
	_require(not view.opened and not station.stowed.has("RollingPin") and pin.visible \
			and CarriedCase.place_of(pin_item).is_empty() and pin.transform.is_equal_approx(pin_rest),
		"pushed out of the case at its table, the pin goes back to its rest")

	# Custody: a stowed tool without its case item is refused.
	var snapshot: Dictionary = state.snapshot()
	snapshot.records[STATION].value["Breadboard"] = {"stowed": true}
	_require(CarriedCase.place_of(board_item).is_empty() \
			and not state.valid_kitchen_custody(RealityState.data.get(CarriedCase.KEY, {}), snapshot.records),
		"a stowed board without its case item is refused")
	var orphan: Dictionary = RealityState.data.get(CarriedCase.KEY, {}).duplicate(true)
	orphan.places[board_item] = {"x": 0, "y": 0, "turned": false, "form": "flat"}
	_require(not state.valid_kitchen_custody(orphan, state.snapshot().records),
		"a case item for a board still on its table is refused")
	_require(station.valid_mechanism({"Breadboard": {"stowed": true}, "RollingPin": {"stowed": true}}) \
			and not station.valid_mechanism({"Breadboard": {"stowed": false}, "RollingPin": {"stowed": true}}),
		"the station's save accepts only a real stowed mark")
	for suffix in ["", ".bak", ".txn", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	route_completed = true
