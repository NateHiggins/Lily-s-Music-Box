extends Node
## The debug controls' light switch: lamp only, or the voxel field at one of
## its three response modes, chosen while standing in the room rather than
## through an environment variable and a restart.
##
## The switch is honest about refusal. A world whose target case room is not
## loaded cannot build the presenter, and the control must say so instead of
## silently doing nothing, so this test accepts either outcome and checks the
## contract each one owes: a running presenter whose mode follows the buttons,
## or a stated reason and no presenter.

var checks := 0
var failures := 0
var _old_launch_mode: int
var _old_persistence := true


func _ready() -> void:
	print("[DREAM LIGHT TOGGLE] START")
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
	var encroachment: Node = building.get("apartment_encroachment")
	_check("the apartment encroachment owns the voxel light", encroachment != null)
	if encroachment == null:
		_finish()
		return

	for label in ["Lamp only", "Voxel baseline", "Voxel debug", "Voxel full"]:
		_check("the light switch offers %s" % label, _find_button(panel, label) != null)
	_check("the switch starts on lamp only, with no presenter",
			encroachment.get("voxel_light_presenter") == null)

	var reason: String = encroachment.call("build_voxel_light_presenter")
	encroachment.call("release_voxel_light_presenter")
	var available := reason.is_empty()
	print("[DREAM LIGHT TOGGLE] voxel light %s" % [
			"available" if available else "unavailable: " + reason])

	if available:
		for mode in [0, 1, 2]:
			var button := _find_button(panel, ["Voxel baseline", "Voxel debug", "Voxel full"][mode])
			button.emit_signal("pressed")
			await get_tree().process_frame
			var presenter = encroachment.get("voxel_light_presenter")
			_check("mode %d builds the field and sets its response" % mode,
					is_instance_valid(presenter) and int(presenter.get("debug_mode")) == mode)
		_find_button(panel, "Lamp only").emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		_check("lamp only releases the field",
				encroachment.get("voxel_light_presenter") == null)
		_find_button(panel, "Voxel full").emit_signal("pressed")
		await get_tree().process_frame
		var again = encroachment.get("voxel_light_presenter")
		_check("the field can be rebuilt after release", is_instance_valid(again))
		_find_button(panel, "Lamp only").emit_signal("pressed")
		await get_tree().process_frame
	else:
		_find_button(panel, "Voxel full").emit_signal("pressed")
		await get_tree().process_frame
		_check("a refused switch leaves no presenter",
				encroachment.get("voxel_light_presenter") == null)
		_check("a refused switch says why",
				panel._light_status != null and "unavailable" in panel._light_status.text)
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
		print("[DREAM LIGHT TOGGLE] PASS %s" % label)
	else:
		failures += 1
		printerr("[DREAM LIGHT TOGGLE] FAIL %s" % label)


func _watchdog() -> void:
	await get_tree().create_timer(90.0).timeout
	printerr("[DREAM LIGHT TOGGLE] FAIL watchdog: the run never finished")
	get_tree().quit(1)


func _finish() -> void:
	GameBoot.launch_mode = _old_launch_mode
	RealityState.persistence_enabled = _old_persistence
	print("[DREAM LIGHT TOGGLE] %d/%d passed" % [checks - failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
