extends Node3D
## The debug controls inside the pause surface.
##
## Pausing is the one thing that frees the pointer, and the controls used to
## sit on a lower canvas layer that pauses with the tree, so they were buried
## and frozen exactly when the mouse became usable. This proves the opposite:
## open Building Services, and the controls are visible, drawn above it, still
## processing, and their buttons actually run.

var checks := 0
var failures := 0
var _old_launch_mode: int
var _old_persistence := true


func _ready() -> void:
	print("[DEBUG IN PAUSE] START")
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
	var pause = building.player.pause_services
	_check("the debug controls and Building Services both exist",
			panel != null and pause != null)
	if panel == null or pause == null:
		_finish()
		return

	_check("the controls draw above the pause surface",
			panel.get_parent() is CanvasLayer
			and (panel.get_parent() as CanvasLayer).layer > int(pause.get("layer")))
	_check("the controls keep processing while the tree is paused",
			panel.process_mode == Node.PROCESS_MODE_ALWAYS
			or panel.get_parent().process_mode == Node.PROCESS_MODE_ALWAYS)

	pause.call("open")
	await get_tree().process_frame
	_check("pausing shows the controls", get_tree().paused
			and panel._body.visible and panel.hosted_in_pause())
	_check("pausing frees the pointer",
			Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	_check("the controls can process while paused", panel.can_process())

	var teleports := _find_button(panel, "▸ GO — teleports")
	_check("a control is reachable while paused", teleports != null)
	if teleports != null:
		teleports.emit_signal("pressed")
		await get_tree().process_frame
		_check("pressing it while paused runs its action",
				_find_button(panel, "Dream ecology") != null)

	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.physical_keycode = KEY_F1
	key.pressed = true
	get_viewport().push_input(key, true)
	key.pressed = false
	get_viewport().push_input(key, true)
	await get_tree().process_frame
	_check("F1 folds the controls away without leaving the pause surface",
			not panel._body.visible and get_tree().paused)
	get_viewport().push_input(key, true)
	key.pressed = false
	get_viewport().push_input(key, true)
	await get_tree().process_frame

	pause.call("close")
	await get_tree().process_frame
	_check("closing the pause surface returns the controls to their own state",
			not get_tree().paused and not panel.hosted_in_pause())
	_finish()


func _find_debug(node: Node) -> BuildingDebug:
	if node is BuildingDebug:
		return node
	for child in node.get_children():
		var found := _find_debug(child)
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
		print("[DEBUG IN PAUSE] PASS %s" % label)
	else:
		failures += 1
		printerr("[DEBUG IN PAUSE] FAIL %s" % label)


func _watchdog() -> void:
	await get_tree().create_timer(90.0).timeout
	printerr("[DEBUG IN PAUSE] FAIL watchdog: the run never finished")
	get_tree().quit(1)


func _finish() -> void:
	GameBoot.launch_mode = _old_launch_mode
	RealityState.persistence_enabled = _old_persistence
	print("[DEBUG IN PAUSE] %d/%d passed" % [checks - failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
