extends Node

const PolicyScript := preload("res://scripts/audio/audio_policy.gd")
const CaptionScript := preload("res://scripts/ui/audio_caption_layer.gd")

var checks := 0
var failures := 0
var _old_setting := false
var _pointer_presses := 0


func _ready() -> void:
	get_viewport().size = Vector2i(1280, 720)
	_old_setting = bool(GameBoot.settings.gameplay_sound_captions)
	GameBoot.settings.gameplay_sound_captions = true
	var prior_mouse: int = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var policy = PolicyScript.new()
	add_child(policy)
	var listener := Node3D.new()
	listener.name = "CaptionListener"
	add_child(listener)
	policy.bind_listener(listener)
	var layer: Node = policy.get_node("AudioCaptionLayer")
	var rows := layer.get_child(0).get_child(0) as VBoxContainer
	# The fixture target is below the actual caption layer, at the same
	# viewport position. No caption visibility/filter or signal is overridden.
	var target_layer := CanvasLayer.new()
	target_layer.name = "CaptionPointerTargetLayer"
	target_layer.layer = 58
	add_child(target_layer)
	var target := Button.new()
	target.name = "ButtonBeneathCaptions"
	target.text = "Caption click-through target"
	target.focus_mode = Control.FOCUS_NONE
	target.pressed.connect(_on_pointer_pressed)
	target_layer.add_child(target)
	for i in 3: await get_tree().process_frame
	var strip: Rect2 = rows.get_global_rect()
	target.position = strip.position
	target.size = strip.size
	await get_tree().process_frame
	var empty_at: Vector2 = strip.get_center()
	var empty_hit: bool = await _viewport_click_hits(target, empty_at)
	_check("empty caption rows pass a real viewport click to the button below",
			rows.is_visible_in_tree() and rows.get_child_count() == 0
			and strip.has_area() and strip.has_point(empty_at)
			and target_layer.layer < int(layer.layer) and empty_hit)
	_check("a semantic cue reaches the caption surface",
			policy.present_3d(&"telephone.asking", Vector3(3, 0, 0), 1.0,
					&"caption_test"))
	_check("caption parity names only the audible cue and relative sector",
			rows.get_child_count() == 1
			and rows.get_child(0).text
			== "house line asks at the switchboard — RIGHT")
	layer.speak("house line asks at the switchboard — RIGHT")
	_check("a repeating source sustains one caption instead of stacking copies",
			rows.get_child_count() == 1 and layer._live.size() == 1
			and is_zero_approx(float(layer._live[0].age)))
	layer.speak("second")
	layer.speak("third")
	layer.speak("fourth")
	_check("caption traffic is capped at three readable lines",
			rows.get_child_count() == CaptionScript.MAX_LINES)
	# Aim through an actual live label, not an empty part of the strip.
	# The semantic cue and capped traffic above supply the production rows.
	for i in 3: await get_tree().process_frame
	var caption: Label = rows.get_child(0) as Label if rows.get_child_count() > 0 else null
	var populated_at: Vector2 = caption.get_global_rect().get_center() if caption != null else strip.get_center()
	var populated_hit: bool = await _viewport_click_hits(target, populated_at)
	_check("enabled populated caption rows pass a real viewport click to the button below",
			bool(layer.enabled) and caption != null and caption.is_visible_in_tree()
			and rows.get_global_rect().has_point(populated_at)
			and caption.get_global_rect().has_point(populated_at)
			and target_layer.layer < int(layer.layer) and populated_hit)
	GameBoot.settings.gameplay_sound_captions = _old_setting
	Input.mouse_mode = prior_mouse
	target_layer.queue_free()
	policy.release_source(&"caption_test")
	policy.queue_free()
	listener.queue_free()
	for i in 2: await get_tree().process_frame
	print("[AUDIO CAPTION] RESULT: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _on_pointer_pressed() -> void:
	_pointer_presses += 1


func _viewport_click_hits(target: Button, at: Vector2) -> bool:
	var before: int = _pointer_presses
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	var hovered_target: bool = get_viewport().gui_get_hovered_control() == target
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = at
	press.global_position = at
	press.pressed = true
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = at
	release.global_position = at
	release.pressed = false
	get_viewport().push_input(release, true)
	for i in 2: await get_tree().process_frame
	return hovered_target and target.get_global_rect().has_point(at) \
			and _pointer_presses == before + 1


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[AUDIO CAPTION] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
