extends Node

const SurfaceScript := preload("res://scripts/ui/pause_services.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	get_viewport().size = Vector2i(1280, 720)
	var owner = preload("res://scripts/player/player_controller.gd").new()
	add_child(owner)
	await get_tree().process_frame
	var surface = owner.get("pause_services")
	_check("player owns one in-game services surface", surface != null)
	var gameplay_bus := AudioServer.get_bus_index("Gameplay")
	var baseline_db := AudioServer.get_bus_volume_db(gameplay_bus)
	_check("escape surface opens during ordinary play", surface.open())
	_check("opening pauses the night", get_tree().paused and surface.is_open)
	await get_tree().process_frame
	_check("services establishes keyboard and controller focus",
			surface.apply_button.has_focus())
	var panel_rect: Rect2 = surface.panel.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	print("[PAUSE SERVICES] FIT rect=%s viewport=%s" % [panel_rect, viewport_size])
	_check("the full services surface fits the minimum viewport",
			panel_rect.position.x >= 0.0 and panel_rect.position.y >= 0.0
			and panel_rect.end.x <= viewport_size.x
			and panel_rect.end.y <= viewport_size.y)
	_check("surface exposes all six semantic mix controls",
			surface.sliders.size() == 6)
	_check("sleep warning accessibility is reachable during play",
			surface.onset_warning != null
			and surface.onset_warning.name == "AlwaysWarnBeforeSleep")
	_check("camera comfort controls are reachable during play",
			surface.reduce_roll != null and surface.look_sensitivity != null)
	_check("lightning flash suppression is reachable during play",
			surface.reduce_flashing != null
			and surface.reduce_flashing.name == "ReduceFlashing")
	var prior_roll_setting := bool(GameBoot.settings.reduce_camera_roll)
	GameBoot.settings.reduce_camera_roll = true
	_check("reduced motion removes visual roll but not its physical inputs",
			is_zero_approx(owner.resolved_camera_roll(Vector3(0.7, -0.7, 0), 0.08)))
	GameBoot.settings.reduce_camera_roll = prior_roll_setting
	var prior_sensitivity := float(GameBoot.settings.look_sensitivity)
	GameBoot.settings.look_sensitivity = 0.5
	owner.rotation.y = 0.0
	owner.apply_look(Vector2(100.0, 0.0))
	_check("look sensitivity scales the one mouse and touch look path",
			is_equal_approx(owner.rotation.y, -0.115))
	owner.rotation.y = 0.0
	GameBoot.settings.look_sensitivity = prior_sensitivity
	surface.sliders.gameplay_volume.value = 0.13
	surface.close(false)
	_check("return resumes the night", not get_tree().paused and not surface.is_open)
	_check("return without saving restores the user mix",
			is_equal_approx(AudioServer.get_bus_volume_db(gameplay_bus), baseline_db))
	owner.call_locked = true
	_check("a protected call retains escape ownership", not surface.open())
	owner.call_locked = false
	owner.seated_interaction = Node.new()
	_check("a seated interaction retains escape ownership", not surface.open())
	owner.seated_interaction = null
	_check("surface returns after modal ownership clears", surface.open())
	surface.close(false)
	print("[PAUSE SERVICES] RESULT: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[PAUSE SERVICES] %s %s" % ["PASS" if ok else "FAIL", label])
