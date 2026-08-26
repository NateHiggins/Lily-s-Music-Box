extends Node

const PolicyScript := preload("res://scripts/audio/audio_policy.gd")
const CaptionScript := preload("res://scripts/ui/audio_caption_layer.gd")

var checks := 0
var failures := 0
var _old_setting := false


func _ready() -> void:
	_old_setting = bool(GameBoot.settings.gameplay_sound_captions)
	GameBoot.settings.gameplay_sound_captions = true
	var policy = PolicyScript.new()
	add_child(policy)
	var listener := Node3D.new()
	listener.name = "CaptionListener"
	add_child(listener)
	policy.bind_listener(listener)
	_check("a semantic cue reaches the caption surface",
			policy.present_3d(&"telephone.asking", Vector3(3, 0, 0), 1.0,
					&"caption_test"))
	var layer: Node = policy.get_node("AudioCaptionLayer")
	var rows := layer.get_child(0).get_child(0) as VBoxContainer
	_check("caption parity names only the audible cue and relative sector",
			rows.get_child_count() == 1
			and rows.get_child(0).text
			== "house line asks at the switchboard — RIGHT")
	layer.speak("second")
	layer.speak("third")
	layer.speak("fourth")
	_check("caption traffic is capped at three readable lines",
			rows.get_child_count() == CaptionScript.MAX_LINES)
	GameBoot.settings.gameplay_sound_captions = _old_setting
	print("[AUDIO CAPTION] RESULT: %s %d/%d" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[AUDIO CAPTION] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1
