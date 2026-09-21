extends Node3D
## Start the game already standing in the Dream zoo, with the voxel light on.
##
## The same two controls the debug panel offers, pressed for you at boot: the
## LIGHT section's voxel mode and the GO section's Dream zoo teleport. It
## calls the panel's own handlers rather than repeating them, so this can
## never drift from what the buttons do.
##
## Run it:
##   godot --path <repo>/game res://scenes/debug/ZooVisit.tscn
##
## ZOO_VISIT_LIGHT picks the light: full (default), debug, baseline, lamp.
## ZOO_VISIT_SMOKE=1 prints the state and exits instead of handing you the
## game, which is how the suite checks this launcher without a window.

const MODES := {"baseline": 0, "debug": 1, "full": 2}

var _building: Node3D


func _ready() -> void:
	print("[ZOO VISIT] START")
	if OS.get_environment("ZOO_VISIT_SMOKE") == "1":
		# The automated launcher check never writes the player's campaign.
		RealityState.persistence_enabled = false
		RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	call_deferred("_open")


func _open() -> void:
	# The selector is the one authority for which waking building this session
	# uses, and it reads ORISON_BUILDING_ROOT, so this launcher follows the v2
	# cutover without naming a scene of its own.
	_building = load(BuildingRootSelector.scene_path()).instantiate()
	add_child(_building)
	# The building assembles over several frames; the panel and the warehouse
	# are both built by its own setup, so wait for it rather than for a node.
	await get_tree().create_timer(1.8).timeout
	if bool(_building.get("startup_failed")):
		printerr("[ZOO VISIT] FAIL selected building did not finish startup")
		_quit(1)
		return

	var panel := _find_debug(_building)
	if panel == null:
		printerr("[ZOO VISIT] FAIL no debug controls in this launch")
		_quit(1)
		return

	var wanted := OS.get_environment("ZOO_VISIT_LIGHT").strip_edges().to_lower()
	if wanted.is_empty():
		wanted = "full"
	if panel._encroachment() == null:
		# V2 has its own production lamp. The zoo's shared exposure volume is
		# already live; the V1 apartment presenter is not an owner in this world.
		wanted = "zoo exposure field + carried lamp"
	elif wanted == "lamp":
		panel._set_voxel_light(false, -1)
	elif MODES.has(wanted):
		panel._set_voxel_light(true, int(MODES[wanted]))
	else:
		printerr("[ZOO VISIT] unknown ZOO_VISIT_LIGHT %s, using full" % wanted)
		panel._set_voxel_light(true, 2)
		wanted = "full"

	panel._teleport_to_zoo()
	await get_tree().process_frame

	# Hand over a game, not a menu: the pointer is captured and the panel is
	# folded away behind F1, exactly as a launch into the flat would be.
	var player = _building.player
	if player != null and player.has_method("set_mouse_released"):
		player.set_mouse_released(false)

	var zoo := _find_zoo(_building)
	var where := "nowhere" if zoo == null else str(zoo.stats())
	print("[ZOO VISIT] light=%s" % wanted)
	print("[ZOO VISIT] zoo=%s" % where)
	if zoo != null and player != null:
		print("[ZOO VISIT] standing inside the hall: %s"
				% zoo.hall_aabb().has_point(player.global_position))
	print("[ZOO VISIT] READY — F1 for controls and Return to building; ` frees the mouse")
	if OS.get_environment("ZOO_VISIT_SMOKE") == "1":
		_quit(0 if zoo != null else 1)


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


func _quit(code: int) -> void:
	get_tree().quit(code)
