extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Prepared while engine use is paused. One initial F04 placement; all door
## opening and subsequent passage use the ordinary controller and input ray.

func _init() -> void:
	route_label = "4B DOOR ROUTE"

func _route() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(-4.65, 9.62, 0))
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var entry := _leaf("F04_DOOR_03")
	if not _require(entry != null and entry.door_kind == "apartment_entry"
			and entry.unit == "4B" and entry.is_in_group("apartment_doors"),
			"4B entry has its production subtype and apartment identity"): return
	# The apartment entry is the installed directional-only passage proof:
	# no preceding leaf click, key command or angle assignment.
	if not await _walk(Vector3(-6.65, 9.6, 0)): return
	if not _require(entry.is_ready_for_passage(), "directional input alone opens and clears installed 4B entry"): return
	for point in [Vector3(-6.65, 9.6, 0), Vector3(-8.3, 9.6, 0),
			Vector3(-10.8, 9.6, 0), Vector3(-13, 9.6, 0),
			Vector3(-13, 9.6, 4.7), Vector3(-14.42, 9.6, 4.7)]:
		if not await _walk(point): return
	if not await _use_water_valves("F04_4B_KITCHEN_SINK_01"): return
	if not _require(entry.is_ready_for_passage(), "entry stays open during kitchen work without return hardware"): return
	for point in [Vector3(-13, 9.6, 4.7), Vector3(-13, 9.6, 0),
			Vector3(-10.8, 9.6, 0), Vector3(-10.8, 9.6, 2.25),
			Vector3(-10.05, 9.6, 2.25)]:
		if not await _walk(point): return
	if not await _open_door("F04_B_HALL_DOOR"): return
	for point in [Vector3(-10.05, 9.6, 4.0), Vector3(-10.5, 9.6, 4.75)]:
		if not await _walk(point): return
	if not await _open_door("F04_B_BATH_DOOR"): return
	for point in [Vector3(-7.9, 9.6, 4.75), Vector3(-8.45, 9.6, 4.35)]:
		if not await _walk(point): return
	if not await _use_shower(): return
	for point in [Vector3(-7.9, 9.6, 4.75), Vector3(-7.6, 9.6, 4.7)]:
		if not await _walk(point): return
	if not await _use_water_valves("F04_4B_SINK_01"): return
	if not await _walk(Vector3(-7.25,9.6,4.5)): return
	var toilets: Array[BakedFurnitureInteraction] = []
	for prop: Node in world.get_node("Caretaking").subjects.values():
		if prop is BakedFurnitureInteraction and prop.owner_unit=="4B" and prop.furniture_kind=="toilet":
			toilets.append(prop)
	if not _require(toilets.size()==1,"4B has one physical toilet in the household care roster"): return
	var wc := toilets[0]
	if not await _drag_part(wc,wc.get_node("CisternHandle/HandleTouchPoint").global_position,deg_to_rad(-36),"4B_toilet_flush"): return
	if not _require(wc._refilling,"walking approach reaches the actual flush"): return
	await get_tree().create_timer(5.0).timeout
	if not _require(not wc._refilling,"toilet refills before leaving the bathroom"): return
	if not _require(_leaf("F04_B_BATH_DOOR").is_ready_for_passage(),
			"bathroom leaf stays open throughout the visit until explicitly closed"): return
	for point in [Vector3(-7.9, 9.6, 4.75), Vector3(-10.5, 9.6, 4.75)]:
		if not await _walk(point): return
	# The open bathroom leaf projects into the private hall. Close it from a
	# stance outside its sweep before testing the return path down that hall.
	if not await _close_door("F04_B_BATH_DOOR"): return
	for point in [Vector3(-9.8, 9.6, 5.5), Vector3(-9.8, 9.6, 7.25),
			Vector3(-8.8, 9.6, 7.25)]:
		if not await _walk(point): return
	if not await _walk(Vector3(-8.4,9.6,7.25)): return
	if not await _open_door("F04_B_CLOSET_DOOR"): return
	for point in [Vector3(-6.95, 9.6, 7.25), Vector3(-9.8, 9.6, 7.25),
			Vector3(-10.05, 9.6, 5.5), Vector3(-10.05, 9.6, 2.25),
			Vector3(-10.8, 9.6, 2.25), Vector3(-10.8, 9.6, 0),
			Vector3(-8.3, 9.6, 0), Vector3(-6.65, 9.6, 0),
			Vector3(-4.65, 9.6, 0)]:
		if not await _walk(point): return
	if not await _close_door("F04_DOOR_03"): return
	var entry_body := entry.get_node("HingedLeaf") as AnimatableBody3D
	var closed_ray := PhysicsRayQueryParameters3D.create(
			world.adapter.root.to_global(Vector3(-4.65, 10.7, 0)),
			world.adapter.root.to_global(Vector3(-6.65, 10.7, 0)), 1)
	closed_ray.exclude = [player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(closed_ray)
	_require(hit.get("collider") == entry_body, "closed entry restores its solid barrier")
	_require(not player.noclip and player.collision_mask == (1|player._native_contact_layers)
			and player.is_physics_processing(), "ordinary collision remains active after returning to public hall")

func _leaf(identity: String) -> DoorProp:
	var opening := world.adapter.resolve(identity) as Node3D
	if opening == null: return null
	return opening.get_node_or_null(identity + "_Leaf") as DoorProp

func _open_door(identity: String) -> bool:
	var door := _leaf(identity)
	if not _require(door != null, "production leaf exists: " + identity): return false
	# Directional approach can already have opened this accessible leaf.
	# Retain its real motion/readiness and key checks instead of clicking it
	# closed merely to recreate the retired click-before-walking sequence.
	if door.open:
		if not await _wait_for_door(door): return false
		return _require(door.passage_allowed() and door.is_ready_for_passage()
				and door.valid_mechanism(door.mechanism_snapshot()),
				"authorized directional approach leaves a clear saveable leaf: " + identity)
	if not _require(not door.open and door.leaf_state == "closed",
			"leaf starts closed and usable: " + identity): return false
	return await _operate_leaf(door, true, identity)

func _close_door(identity: String) -> bool:
	var door := _leaf(identity)
	if not _require(door != null and door.open, "open leaf ready to close: " + identity): return false
	return await _operate_leaf(door, false, identity + "_close")

## RUL-018 passage leaves use click commands. The ray, reach, tween and solid
## sweep remain production authorities; neither this helper nor the route
## writes a leaf angle or moves the walking player's body.
func _click_leaf(door: DoorProp, label: String) -> bool:
	var body := door.get_node("HingedLeaf") as AnimatableBody3D
	var aim := body.to_global(Vector3(door.width * .5, 1.1, 0))
	player.camera.look_at(aim)
	await get_tree().physics_frame
	player.camera.look_at(aim)
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	var node := hit.get("collider") as Node
	var matched := false
	while node != null:
		if node == door: matched = true
		node = node.get_parent()
	if not _require(matched and not player._grab.active(), "actual click ray reaches leaf: " + label): return false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	return _require(not player._grab.active(), "passage click does not acquire a hand grip: " + label)

func _operate_leaf(door: DoorProp, want_open: bool, label: String) -> bool:
	if not await _click_leaf(door, label): return false
	for frame in 180:
		await get_tree().physics_frame
		if label == "F02_B_ENTRY_DOOR_close" and frame == 0:
			var live_angle: float = door._body.rotation.y
			var live_revision := door.motion_revision
			var live_moving := door._moving
			RealityState.commit()
			if not _require(is_equal_approx(live_angle, door._body.rotation.y)
					and live_revision == door.motion_revision and live_moving == door._moving,
					"unrelated commit preserves commanded physical leaf motion: " + label): return false
		if not door._moving and not door._key_turning: break
	var target := door.motion_target_angle(want_open)
	var reached := door.open == want_open and absf(door._body.rotation.y - target) < .01
	if want_open: reached = reached and door.is_ready_for_passage()
	if not _require(door.valid_mechanism(door.mechanism_snapshot()), "physical leaf stop remains saveable: " + label): return false
	return _require(reached, "click reaches physical leaf stop open=" + str(want_open) + ": " + label)

func _use_shower() -> bool:
	var shower := world.adapter.resolve("F04_4B_SHOWER_01") as TapProp
	if not _require(shower != null and not shower.is_curtain_open(), "4B shower starts drawn"): return false
	if not await _drag_curtain(shower, 1.78, "4B_shower_open"): return false
	if not _require(shower.is_curtain_open(), "input gathers the real curtain"): return false
	if not await _use_water_valves("F04_4B_SHOWER_01"): return false
	if not await _drag_curtain(shower, 0.0, "4B_shower_draw"): return false
	return _require(not shower.is_curtain_open(), "input draws the curtain again")

func _drag_curtain(shower: TapProp, goal: float, label: String) -> bool:
	var shapes: Array[CollisionShape3D] = []
	for child: Node in shower._curtain_area.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			shapes.append(child)
	if not _require(not shapes.is_empty(), "curtain has moving physical selection shapes: " + label): return false
	# The front quarter of the native oval moves with the gathered cloth.
	# Follow that same physical segment in both directions, not the retired
	# rectangular shower's fixed open/closed coordinates.
	var contact: CollisionShape3D = shapes[int(shapes.size() * .75)]
	return await _drag_part(shower, contact.global_position, goal, label, shower._curtain_hand.hand)

func _use_water_valves(identity: String) -> bool:
	var tap := world.adapter.resolve(identity) as TapProp
	if not _require(tap != null, "water fixture exists: " + identity): return false
	if not _require(tap._handles.size() == 2 and is_instance_valid(tap._handles[0])
			and is_instance_valid(tap._handles[1]) and tap._handles[0] != tap._handles[1],
			"independent physical valve handles exist: " + identity): return false
	# Both TapProp and the native clawfoot bath put targets on the moving
	# handles. Root HotValveControl/ColdValveControl are legacy wall-cap fittings.
	var hot := tap._handles[0].get_node_or_null("ManipulationTarget") as Area3D
	var cold := tap._handles[1].get_node_or_null("ManipulationTarget") as Area3D
	if not _require(hot != null and cold != null and hot != cold,
			"independent moving valve targets exist: " + identity): return false
	var hot_grip: Dictionary = hot.call("manipulation_target", {})
	var cold_grip: Dictionary = cold.call("manipulation_target", {})
	if not _require(hot_grip.get("owner") == tap and cold_grip.get("owner") == tap
			and hot_grip.get("part") == tap._handles[0] and cold_grip.get("part") == tap._handles[1]
			and hot_grip.get("kind") == "hinge" and cold_grip.get("kind") == "hinge",
			"hot and cold targets preserve their exact fixture and handle identities: " + identity): return false
	if not await _drag_valve(tap, 0, PI*.5, identity + "_hot"): return false
	var hot_flow := tap.get_flow_state()
	if not _require(hot_flow.hot and not hot_flow.cold and float(hot_flow.temperature) > 0,
			"hot valve supplies boiler-heated water through input"): return false
	if not await _drag_valve(tap, 1, PI*.5, identity + "_mix"): return false
	var mix := tap.get_flow_state()
	if not _require(mix.hot and mix.cold and float(mix.temperature) < float(hot_flow.temperature),
			"independent cold valve dilutes the hot supply"): return false
	if not await _drag_valve(tap, 0, 0.0, identity + "_hot_off"): return false
	var cold_flow := tap.get_flow_state()
	if not _require(not cold_flow.hot and cold_flow.cold and float(cold_flow.temperature) == 0,
			"closing hot leaves only cold water"): return false
	if not await _drag_valve(tap, 1, 0.0, identity + "_cold_off"): return false
	var stopped := tap.get_flow_state()
	return _require(not stopped.hot and not stopped.cold, "both valves shut through input")

func _drag_valve(tap: TapProp, index: int, goal: float, label: String) -> bool:
	var part: Node3D = tap._handles[index]
	var target := part.get_node("ManipulationTarget") as Area3D
	# Native end-mounted handles have their mesh beyond the hinge pivot.
	# Use the actual moving collision box, never an assumed part-origin hit.
	for child: Node in target.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			return await _drag_part(tap, child.global_position, goal, label, part)
	return _require(false, "valve has a physical selection shape: " + label)

## Inherited callers use the passage click exception or acquire a cabinet or
## other part and drive its existing physical constraints.
func _use(owner_node: Node3D, target: Vector3, label: String) -> bool:
	if owner_node is DoorProp and owner_node.height >= 1.2 and owner_node.door_kind != "cabinet":
		var door := owner_node as DoorProp
		if door.leaf_state=="locked" and not door.passage_allowed():return await _try_locked_leaf(door,label)
		return await _operate_leaf(door,not door.open,label)
	player.camera.look_at(target)
	await get_tree().physics_frame
	player.camera.look_at(target)
	var grip: Dictionary=player._grab.find_target()
	if not _require(grip.get("owner")==owner_node,"actual player ray selects route part: "+label):return false
	if owner_node is DoorProp:
		var cabinet := owner_node as DoorProp
		if cabinet.leaf_state=="locked":return await _try_locked_cabinet_leaf(cabinet,grip,label)
		return await _drag_part(cabinet,target,0.0 if cabinet.open else cabinet.motion_target_angle(true),label)
	if not _require(grip.kind in ["hinge","slide"],"route part has a physical scalar constraint: "+label):return false
	var current: float=grip.read.call()
	var goal := float(grip.maximum) if absf(current-float(grip.minimum))<=absf(current-float(grip.maximum)) else float(grip.minimum)
	return await _drag_part(owner_node,target,goal,label)

func _try_locked_leaf(door: DoorProp,label: String) -> bool:
	var initial: float=door._body.rotation.y
	if not await _click_leaf(door,label):return false
	await get_tree().create_timer(.6).timeout
	var refused := is_equal_approx(initial,door._body.rotation.y) and not door.open and door.leaf_state=="locked"
	return _require(refused and not player._grab.active(),"inaccessible locked leaf refuses actual click: "+label)

func _try_locked_cabinet_leaf(door: DoorProp,grip: Dictionary,label: String) -> bool:
	var initial: float=grip.read.call()
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	player._unhandled_input(click)
	if not _require(player._grab.active() and is_equal_approx(initial,float(grip.read.call())),"locked leaf can be held without toggling: "+label):return false
	var opening_gesture := _part_gesture(grip,door.motion_target_angle(true))
	if not _require(opening_gesture.is_finite() and opening_gesture.length()>1.0,"locked refusal receives a nonzero opening gesture: "+label):
		player._unhandled_input(click)
		return false
	for attempt in 12:
		var event := InputEventMouseMotion.new()
		event.relative=_part_gesture(grip,door.motion_target_angle(true))
		player._unhandled_input(event)
		await get_tree().physics_frame
	var refused := is_equal_approx(initial,float(grip.read.call())) and not door.open and door.leaf_state=="locked"
	if player._grab.active():player._unhandled_input(click)
	await get_tree().physics_frame
	return _require(refused and not player._grab.active(),"locked leaf refuses actual opening motion and releases: "+label)

func _part_gesture(grip: Dictionary,goal: float) -> Vector2:
	var part: Node3D=grip.part
	var frame: Node3D=grip.frame
	var point: Vector3=part.to_global(player._grab.contact)
	var local_axis: Vector3=grip.axis.call() if grip.axis is Callable else grip.axis
	var axis: Vector3=(frame.global_basis*local_axis).normalized()
	var tangent := axis
	if grip.kind=="hinge":
		tangent=axis.cross(point-part.global_position)
		if tangent.length()<.025:
			tangent=axis.cross(player.camera.global_basis.x)*.06
			if tangent.length()<.01:tangent=axis.cross(player.camera.global_basis.y)*.06
	var gesture: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
	if gesture.length()<24.0 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
		gesture=Vector2(0,tangent.dot(player.camera.global_basis.z)*180.0)
	if float(grip.get("gesture_travel_px",0.0))>0.0:
		var fixed_axis: Vector2=player._grab._gesture_axis
		if fixed_axis.length_squared()<.01:fixed_axis=gesture.normalized()
		return fixed_axis*signf(goal-float(grip.read.call()))*12.0
	return gesture*signf(goal-float(grip.read.call()))*.06

## Drive only player input. Read the constraint to choose a screen-space gesture;
## never call its writer, bypass collision, or move the walking player.
func _drag_part(owner_node: Node3D, aim: Vector3, goal: float, label: String, expected_part: Node3D = null) -> bool:
	player.camera.look_at(aim)
	await get_tree().physics_frame
	# Ground settling/head motion may move the eye during that physics tick.
	# Re-aim from its actual new position before sampling the small valve target.
	player.camera.look_at(aim)
	var grip: Dictionary = player._grab.find_target()
	var selected: bool = grip.get("owner") == owner_node and (expected_part == null or grip.get("part") == expected_part)
	if not selected:
		print("GRAB RAY DIAGNOSTIC: ", label, " eye=", player.camera.global_position,
				" aim=", aim, " reach_m=", player.camera.global_position.distance_to(aim),
				" hit=", player._grab.last_hit, " expected_part=", expected_part, " selected_part=", grip.get("part"))
	if not _require(selected, "actual player ray selects operable part: " + label): return false
	var initial: float = grip.read.call()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	if not _require(player._grab.active() and player._grab.target.get("owner") == owner_node
			and player._grab.target.get("part") == grip.get("part")
			and is_equal_approx(initial, float(grip.read.call())), "click grabs the selected part without toggling: " + label): return false
	for step in 160:
		if absf(float(grip.read.call()) - goal) < .00001: break
		if not player._grab.active(): break
		var motion := InputEventMouseMotion.new()
		motion.relative = _part_gesture(grip,goal)
		player._unhandled_input(motion)
		await get_tree().physics_frame
	var reached: bool = absf(float(grip.read.call())-goal)<.00001
	if not reached:
		var held_point: Vector3 = grip.part.to_global(player._grab.contact)
		var sight := PhysicsRayQueryParameters3D.create(player.camera.global_position, held_point)
		sight.collide_with_areas = true
		sight.exclude = [player.get_rid()]
		var blocker := player.get_world_3d().direct_space_state.intersect_ray(sight)
		print("GRAB DIAGNOSTIC: ",label," value=",grip.read.call()," goal=",goal," held=",player._grab.active(),
				" player=",player.global_position," part=",part_path(grip.part)," contact=",held_point,
				" reach_m=",player.camera.global_position.distance_to(held_point)," blocker=",blocker,
				" call_locked=",player.call_locked," released=",player.mouse_released," captured=",player.pointer_captured(),
				" behind=",player.camera.is_position_behind(held_point))
	if player._grab.active(): player._unhandled_input(click)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if owner_node.has_method("mechanism_snapshot") and owner_node.has_method("valid_mechanism"):
		if not _require(owner_node.valid_mechanism(owner_node.mechanism_snapshot()), "physical stop remains saveable: " + label): return false
	return _require(reached and not player._grab.active(), "mouse motion reaches stop and second click releases: " + label)

func part_path(part: Node) -> String:
	return str(part.get_path()) if is_instance_valid(part) else "freed"
