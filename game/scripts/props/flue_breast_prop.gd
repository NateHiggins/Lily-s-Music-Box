class_name FlueBreastProp
extends FunctionalProp
## The chimney breast in the C-stack bedrooms: the room-side face of the
## flue. The masonry tube carries the boiler's motif six stories in ~70 ms
## — so this body answers noticeably BEFORE the radiator on the same
## floor, and a listening player can hear the two paths disagree.

var _knock: AudioStreamPlayer3D
var _draft: AudioStreamPlayer3D


func _build_visual() -> void:
	# soot-shadowed patch where a stove pipe once met the breast
	make_box(Vector3(0.5, 0.7, 0.03), Vector3(0, 1.3, 0),
			Color(0.10, 0.09, 0.09))
	_knock = make_emitter("knock", -10.0)
	_knock.pitch_scale = 0.62  # muffled through the masonry
	_draft = make_emitter("hum_loop", -60.0, true)
	_draft.pitch_scale = 0.35


func _start_normal_function() -> void:
	state = PState.OPERATING
	_draft_loop()


func _draft_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(18.0, 40.0), false).timeout
		if not is_inside_tree() or state != PState.OPERATING:
			continue
		# the flue breathes when the wind crosses the cap
		create_tween().tween_property(_draft, "volume_db", -26.0, 1.5)
		await get_tree().create_timer(3.0, false).timeout
		if is_inside_tree():
			create_tween().tween_property(_draft, "volume_db", -60.0, 2.0)


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_knock.volume_db = -10.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_knock.pitch_scale = clampf(0.62 * pow(2.0, pitch * 0.1 / 12.0), 0.5, 0.8)
	_knock.play()
