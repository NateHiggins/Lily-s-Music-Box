extends Node3D
## One button in the teleports section puts the visitor inside the Dream zoo,
## standing on their own legs, facing the specimens, with the room alive.
##
## The exhibit already existed, but its only entrance was the inspection
## camera: that rig freezes the player, takes the viewport and ties both the
## organelle wall's visibility and every organism's processing to itself. So
## "visit the zoo" and "inspect one specimen" were the same button, and only
## the second one worked. This proves the walking route: no camera taken, no
## player frozen, creatures running, plaques readable, and the safety net
## told that the hall floor is a legitimate place to stand.
##
## Deliberately free of pointer assertions so it can run headless — the
## headless server never captures the mouse, so those pass vacuously (H24).

var checks := 0
var failures := 0
var _old_launch_mode: int
var _old_persistence := true


func _ready() -> void:
	print("[ZOO TELEPORT] START")
	_watchdog()
	_old_launch_mode = GameBoot.launch_mode
	_old_persistence = RealityState.persistence_enabled
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	call_deferred("_run")


func _run() -> void:
	var building: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(building)
	await get_tree().create_timer(1.5).timeout

	var panel := _find_debug(building)
	_check("the debug controls exist", panel != null)
	if panel == null:
		_finish()
		return

	var button := _find_button(panel, "Dream zoo")
	_check("a Dream zoo button exists", button != null)
	var teleports: Node = panel._sections.get("GO — teleports")
	_check("it sits with the teleports, not under screenshots",
			teleports != null and button != null
			and _find_button(teleports, "Dream zoo") == button)
	if button == null:
		_finish()
		return

	button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var zoo := _find_zoo(building)
	_check("pressing it builds the zoo", zoo != null)
	if zoo == null:
		_finish()
		return

	var player: PlayerController = building.player
	var stand: Vector3 = zoo.zoo_stand()
	_check("the visitor is standing in the hall",
			zoo.hall_aabb().has_point(player.global_position))
	# Physics owns the body the moment it lands, so an exact match is the
	# wrong claim: what matters is arriving where the stand is and being
	# held up by the exhibit floor rather than sinking through it.
	var flat: float = Vector2(player.global_position.x - stand.x,
			player.global_position.z - stand.z).length()
	var lift: float = player.global_position.y - stand.y
	_check("on the exhibit floor at the stand (%.2f m across, %+.2f m up)"
			% [flat, lift],
			flat < 0.5 and lift > -0.3 and lift < 1.2)

	var forward: Vector3 = -player.global_basis.z
	var down_hall: Vector3 = (zoo.to_global(
			Vector3(0, 0.06, DreamEcologyWarehouse.HALL_CENTER_Z))
			- stand).normalized()
	_check("facing the specimens rather than the wall behind",
			forward.normalized().dot(down_hall) > 0.9)

	_check("the inspection camera was not taken", not zoo.active)
	_check("the visitor can still walk",
			player.is_physics_processing()
			and player.is_processing_unhandled_input())
	_check("the creatures are running", not zoo.simulation_paused)
	_check("the organelle wall is live, not blanked",
			zoo.organelle != null and zoo.organelle.active)
	_check("the bench plaques are readable",
			not zoo._specimen_labels.is_empty()
			and zoo._specimen_labels[0].visible)

	var stats: Dictionary = zoo.stats()
	_check("there is something to look at",
			int(stats.get("species", 0)) > 0
			and int(stats.get("placeholder_bays", 0)) > 0)

	var net: SafetyNet = building.safety_net
	_check("the hall is a legitimate place to stand",
			net == null or zoo.hall_aabb() in net.exempt_zones)
	# A free camera left behind keeps drawing the floor you left, because the
	# building takes the override as the eye when one exists.
	_check("a free camera comes along",
			building.view_override == null
			or zoo.hall_aabb().has_point(building.view_override.global_position))

	# The floor is built by the exhibit, not by the building, and the net that
	# rescues falling players has no idea this room exists. Both failures look
	# identical from the chair: you arrive and you are somewhere else.
	var arrival: Vector3 = player.global_position
	await get_tree().create_timer(0.8).timeout
	_check("still standing there a moment later",
			zoo.hall_aabb().has_point(player.global_position)
			and absf(player.global_position.y - arrival.y) < 0.25)

	# The two routes are different things and both have to keep working: the
	# orbit bench for one specimen, the walk for the room.
	var inspect := _find_button(panel, "Dream ecology")
	_check("the inspection route is still there", inspect != null)
	if inspect != null:
		inspect.emit_signal("pressed")
		await get_tree().process_frame
		_check("inspecting still takes the camera", zoo.active)
		button.emit_signal("pressed")
		await get_tree().process_frame
		_check("the zoo button hands it back and walks again",
				not zoo.active and not zoo.simulation_paused
				and player.is_physics_processing())
		# Leaving inspection has to give the controls back too, or the visitor
		# is walking a live hall with no way to reach any other control.
		_check("and the controls are on screen again", panel.visible)

	# Nobody presses this from a closed panel. The two real routes both hold
	# the body while they are open - the controls suspend it, and pausing
	# stops the tree - so the thing worth proving is that both hand it back.
	panel._set_menu_open(true)
	await get_tree().process_frame
	button.emit_signal("pressed")
	await get_tree().process_frame
	panel._set_menu_open(false)
	await get_tree().process_frame
	_check("pressing it from the open controls ends walkable in the hall",
			zoo.hall_aabb().has_point(player.global_position)
			and player.is_physics_processing()
			and player.is_processing_unhandled_input())

	var pause: PauseServices = player.pause_services
	_check("Building Services is reachable", pause != null)
	if pause != null:
		pause.open()
		await get_tree().process_frame
		button.emit_signal("pressed")
		await get_tree().process_frame
		pause.close()
		await get_tree().process_frame
		_check("pressing it while paused ends walkable in the hall",
				not get_tree().paused
				and zoo.hall_aabb().has_point(player.global_position)
				and player.is_physics_processing())
	_finish()


func _find_debug(node: Node) -> BuildingDebug:
	if node is BuildingDebug:
		return node
	for child in node.get_children():
		var found := _find_debug(child)
		if found != null:
			return found
	return null


func _find_zoo(node: Node) -> DreamEcologyWarehouse:
	if node is DreamEcologyWarehouse:
		return node
	for child in node.get_children():
		var found := _find_zoo(child)
		if found != null:
			return found
	return null


func _find_button(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text == label:
		return node
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("[ZOO TELEPORT] PASS %s" % label)
	else:
		failures += 1
		printerr("[ZOO TELEPORT] FAIL %s" % label)


func _watchdog() -> void:
	await get_tree().create_timer(150.0).timeout
	printerr("[ZOO TELEPORT] FAIL watchdog: the run never finished")
	get_tree().quit(1)


func _finish() -> void:
	GameBoot.launch_mode = _old_launch_mode
	RealityState.persistence_enabled = _old_persistence
	print("[ZOO TELEPORT] %d/%d passed" % [checks - failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
