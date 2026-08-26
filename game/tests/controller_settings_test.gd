extends Node
## Controller look can be configured before play and during play without
## escaping the 1280x720 minimum viewport.

var failures := 0


func _ready() -> void:
	OS.set_environment("TITLE_SCREEN_SILENT", "1")
	get_viewport().size = Vector2i(1280, 720)
	await _prove_title_surface()
	await _prove_pause_surface()
	print("CONTROLLER SETTINGS TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _prove_title_surface() -> void:
	var title := preload("res://scenes/ui/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title._open_settings()
	await get_tree().process_frame
	_check(title._controller_look_sensitivity != null
			and title._controller_invert_y != null
			and title._controller_look_deadzone != null
			and title._controller_look_curve != null,
			"title exposes the complete controller look set")
	_check(_inside_viewport(title._settings_panel),
			"scrolling title services stay inside 1280x720")
	_check(title._settings_panel.find_child(
			"BuildingServicesScroll", true, false) != null,
			"title overflow is a focus-following scroll surface")
	title.queue_free()
	await get_tree().process_frame


func _prove_pause_surface() -> void:
	var surface := PauseServices.new()
	add_child(surface)
	await get_tree().process_frame
	_check(surface.controller_look_sensitivity != null
			and surface.controller_invert_y != null
			and surface.controller_look_deadzone != null
			and surface.controller_look_curve != null,
			"in-game services expose the complete controller look set")
	_check(_inside_viewport(surface.panel),
			"scrolling in-game services stay inside 1280x720")
	_check(surface.panel.find_child("ServicesScroll", true, false) != null,
			"in-game overflow is a focus-following scroll surface")
	for key in ["controller_look_sensitivity", "controller_invert_y",
			"controller_look_deadzone", "controller_look_curve"]:
		_check(GameBoot.settings.has(key), "%s persists at the settings owner" % key)
	surface.queue_free()


func _inside_viewport(control: Control) -> bool:
	var viewport := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return viewport.encloses(control.get_global_rect())


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		failures += 1
		push_error("  FAIL  %s" % label)
