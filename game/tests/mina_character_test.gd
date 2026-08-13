extends Node3D

var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var mina := AnimatedResident.new()
	# The production standard (owner ruling 2026-08-13): the Grey Elegance
	# hero model, motion-free by contract, animated by her own baked
	# library via the AnimatedResident graft. The old generated rigged glb
	# this test used to load is deleted.
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
