extends Node
## Production presentation contains the case's authored caption anomaly, but
## no generic developer labels or eagerly-instantiated tuning handles.

var failures := 0


func _ready() -> void:
	var previous := OS.get_environment("ORISON_DEVELOPER_OVERLAYS")
	OS.set_environment("ORISON_DEVELOPER_OVERLAYS", "")
	_check(not GameBoot.developer_overlays_enabled(),
			"developer overlays are opt-in, even in a debug engine build")
	var object := CaseInteractable.new()
	add_child(object)
	object.setup("CAPTION CALIBRATOR", "Run caption calibration", func(): return {})
	_check(object.find_children("*", "Label3D", true, false).is_empty(),
			"generic case objects render no floating developer title")
	var case_source := FileAccess.get_file_as_string(
			"res://scripts/cases/mina_caption_manifestation.gd")
	_check(case_source.contains('"noun": "SOFA"')
			and case_source.contains('"noun": "DESK"'),
			"Mina's authored caption anomaly remains production gameplay")
	var rig_source := FileAccess.get_file_as_string(
			"res://scripts/building/light_rig.gd")
	_check(not rig_source.contains('call_deferred("_build_debug_handles")'),
			"ordinary boot does not instantiate light tuning handles")
	_check(rig_source.contains("func export_tuning() -> String:\n\tif not GameBoot.developer_overlays_enabled():")
			and rig_source.find("if not GameBoot.developer_overlays_enabled():") <
				rig_source.find("DisplayServer.clipboard_set(text)"),
			"production cannot write tuning files or replace the clipboard")
	var player_source := FileAccess.get_file_as_string(
			"res://scripts/player/player_controller.gd")
	_check(player_source.contains("if GameBoot.developer_overlays_enabled() \\\n\t\t\tand Input.is_action_just_pressed(\"noclip\")"),
			"production V cannot disable player collision")
	OS.set_environment("ORISON_DEVELOPER_OVERLAYS", "1")
	var diagnostic := CaseInteractable.new()
	add_child(diagnostic)
	diagnostic.setup("CAPTION CALIBRATOR", "Run caption calibration",
			func(): return {})
	_check(diagnostic.find_children("*", "Label3D", true, false).size() == 1,
			"explicit developer mode restores the diagnostic object title")
	OS.set_environment("ORISON_DEVELOPER_OVERLAYS", previous)
	print("RELEASE PRESENTATION TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		failures += 1
		push_error("  FAIL  %s" % label)
