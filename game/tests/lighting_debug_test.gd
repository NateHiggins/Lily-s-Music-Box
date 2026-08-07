extends Node


func _ready() -> void:
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var scene := load(GameBoot.GAME_SCENE) as PackedScene
	var building := scene.instantiate()
	add_child(building)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := _find_debug(building)
	if panel == null:
		push_error("LIGHTING DEBUG TEST: panel did not instantiate")
		get_tree().quit(1)
		return
	var fixtures: Array = building.light_rig.debug_fixtures()
	building.light_rig.set_debug_inspection(true)
	if fixtures.is_empty() or building.light_rig._debug_handles.size() \
			!= fixtures.size():
		push_error("LIGHTING DEBUG TEST: walk-up handles are incomplete")
		get_tree().quit(1)
		return
	var fixture: Node = fixtures[0]
	building.light_rig.select_debug_fixture(fixture)
	if panel._selected_fixture != fixture:
		push_error("LIGHTING DEBUG TEST: world selection did not reach panel")
		get_tree().quit(1)
		return
	building.light_rig.set_fixture_tuning(fixture, "energy_multiplier", 0.73)
	building.light_rig.set_fixture_tuning(fixture, "temperature", 2400.0)
	var tuning: Dictionary = building.light_rig.fixture_tuning(fixture)
	if not is_equal_approx(float(tuning.energy_multiplier), 0.73) \
			or not is_equal_approx(float(tuning.temperature), 2400.0):
		push_error("LIGHTING DEBUG TEST: edits did not persist")
		get_tree().quit(1)
		return
	print("LIGHTING DEBUG TEST: PASS (%d selectable fixtures)" % fixtures.size())
	get_tree().quit(0)


func _find_debug(node: Node) -> BuildingDebug:
	if node is BuildingDebug:
		return node
	for child in node.get_children():
		var found := _find_debug(child)
		if found:
			return found
	return null
