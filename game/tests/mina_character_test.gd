extends Node3D

var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var mina := AnimatedResident.new()
	# Owner replacement 2026-10-03: Gray Resolve, only the supplied batch.
	mina.setup("Mina Vale", "mina_vale", "2A",
			"res://assets/characters/mina_vale/mina_vale.gltf")
	add_child(mina)
	await get_tree().process_frame
	_check(mina._model != null, "rigged Mina scene instantiates")
	_check(mina._animation_player != null, "animation player imported")
	var names: Array = mina._animation_player.get_animation_list() \
			if mina._animation_player else []
	_check(_contains_fragment(names, "idle"), "idle action imported")
	_check(_contains_fragment(names, "walk"), "walk action imported")
	_check(names.size() == 20, "exactly twenty clips; retired donor set absent")
	_check(mina.mina_animation != null, "Mina behavior owner installed")
	for clip: String in MinaAnimationBehavior.CLIPS:
		_check(clip in names, "supplied clip present: " + clip)
		if clip not in names: continue
		var animation := mina._animation_player.get_animation(clip)
		var expected := Animation.LOOP_LINEAR if MinaAnimationBehavior.CLIPS[clip] else Animation.LOOP_NONE
		_check(animation.loop_mode == expected, "loop/one-shot classified: " + clip)
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_POSITION_3D: continue
			if String(animation.track_get_path(track)).get_slice(":", 1) != "Hips": continue
			var first := animation.position_track_interpolate(track, 0.0)
			var last := animation.position_track_interpolate(track, animation.length)
			var grounded := true
			for phase in [0.0, .25, .5, .75, 1.0]:
				var at := animation.position_track_interpolate(track, animation.length * phase)
				grounded = grounded and Vector2(at.x-first.x, at.z-first.z).length() < .001
			_check(grounded, "hip travel stays under route ownership: " + clip)
			if MinaAnimationBehavior.CLIPS[clip]:
				_check(first.distance_to(last) < .002, "loop hip seam joins: " + clip)
	# Runtime route calls must not restart a dialogue gesture each frame.
	_check(mina.play_case_role("strained"), "existing strained dialogue role resolves")
	mina._set_walking(false)
	_check(mina._animation_player.current_animation == "mina_strained", "stationary route does not overwrite a case beat")
	mina.mina_animation.update(8.0)
	_check(mina._animation_player.current_animation == "mina_talk_measured", "one-shot returns to speech during conversation")
	_check(mina.play_case_role("recognition"), "existing recognition dialogue role resolves")
	_check(not mina.play_case_role("not_shipped"), "missing role is refused")
	mina.play_case_role("idle")
	mina.mina_animation.set_motion(true, .4, 1.05)
	mina.mina_animation.update(4.0)
	_check(mina._animation_player.current_animation == "mina_stairs_up", "ascending route selects stair motion")
	mina.mina_animation.set_motion(true, -.4, 1.05)
	_check(mina._animation_player.current_animation == "mina_stairs_down", "descending route selects stair motion")
	mina.mina_animation.set_motion(false)
	mina.mina_animation.update(4.0)
	_check(mina._animation_player.current_animation == "mina_idle_calm", "walk stop settles into calm idle")
	mina.mina_animation.finish_conversation(true)
	_check(mina.mina_animation.route_busy and mina._animation_player.current_animation == "mina_quiet_thanks", "earned thanks holds the body for one gesture")
	mina._set_walking(false)
	_check(mina._animation_player.current_animation == "mina_quiet_thanks", "route idle preserves earned thanks")
	mina.mina_animation.update(7.0)
	_check(not mina.mina_animation.route_busy and mina._animation_player.current_animation == "mina_idle_calm", "thanks completes and releases navigation")
	var start := mina.position
	RealityCases.activate_case("mina_caption_crisis")
	await get_tree().create_timer(0.25).timeout
	_check(mina.position.distance_to(start) > 0.01,
			"active Mina paces with the walking clip")
	RealityCases.stabilize_case("mina_caption_crisis")
	await get_tree().create_timer(0.35).timeout
	_check(not mina._walking, "stabilized Mina returns to idle")
	print("MINA CHARACTER TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _contains_fragment(names: Array, fragment: String) -> bool:
	for item in names:
		if fragment in str(item).to_lower():
			return true
	return false


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [mina rig ok] ", label)
	else:
		failures += 1
		printerr("  [MINA RIG FAIL] ", label)
