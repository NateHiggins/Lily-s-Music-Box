extends "res://scripts/props/bookshelf_prop.gd"
## Keep the native library and sorting UI; persist only the resident's order.
signal order_changed
var _reported_order: Array = []

func rebuild_books() -> void:
	super.rebuild_books()
	if sorter.order != _reported_order:
		_reported_order = sorter.order.duplicate()
		order_changed.emit()

func restore_order(value: Array) -> void:
	close_panel()
	sorter.order = value.duplicate()
	sorter.held = -1
	sorter.moves = 0
	_door_open = 0.0
	_door_target = 0.0
	_apply_doors()
	rebuild_books()

func panel_closed() -> void:
	sorter.held = -1
	super.panel_closed()

func close_panel() -> void:
	if not is_instance_valid(_panel):
		_panel = null
		return
	# The native panel is owned by the current scene, outside this world.
	# Detach its callback before retirement, then release any live player lock.
	var panel := _panel
	_panel = null
	panel.set("_prop", null)
	if not is_instance_valid(panel.get("_player")): panel.set("_player", null)
	panel.call("close")

func _exit_tree() -> void:
	close_panel()
	super._exit_tree()
