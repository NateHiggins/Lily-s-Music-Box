extends Node3D

var failures := 0


func _ready() -> void:
	var file := FileAccess.open(
			"res://data/resident_animation_profiles.json", FileAccess.READ)
	var profiles: Array = JSON.parse_string(file.get_as_text())
	_check(profiles.size() == 18, "all 18 resident profiles generated")
	var signatures := {}
	var loaded := 0
	for profile in profiles:
		var slug: String = profile.slug
		# The whole cast is hero-standard (2026-08-14 repopulation): each
		# resident ships the motion-free hero gltf plus a personal
		# <slug>_moves.glb baked onto its own rig by bake_model_moves.py;
		# the generated _rigged.glb placeholders are retired. The hero
		# path is production's (_upgrade prefers the gltf); the _rigged
		# fallback only catches a future resident whose hero has not been
		# converted yet.
		var path := "res://assets/characters/%s/%s.gltf" % [slug, slug]
		if not ResourceLoader.exists(path):
			path = "res://assets/characters/%s/%s_rigged.glb" % [
					slug, slug]
		var scene := load(path) as PackedScene
		if scene == null:
			_check(false, profile.display + " model imports")
			continue
		var actor := scene.instantiate()
		add_child(actor)
		var player := _find_animation_player(actor)
		# Every resident accepts a move-set graft: hero-standard residents
		# load their personal <slug>_moves.glb, anything without one (the
		# donor Evelyn) borrows the shared libraries. Graft BEFORE the
		# idle/walk checks — a motion-free hero has no player until the
		# graft brings one, and Evelyn's own ten clips carry no "idle"
		# name until the gesture library lands on top. Production runs
		# the same graft-then-play order in _upgrade/AnimatedResident.
		var grafted := ResidentMovesLibrary.apply(actor)
		if player == null:
			player = _find_animation_player(actor)
		var names: Array = player.get_animation_list() if player else []
		_check(player != null and _contains(names, "idle"),
				profile.display + " idle imports")
		_check(player != null and _contains(names, "walk"),
				profile.display + " walk imports")
		_check(grafted, profile.display + " accepts the shared move set")
		_check(player != null and player.has_animation("clip_06"),
				profile.display + " can settle (shared clip_06)")
		# Imported rigs retain their authored transforms. Runtime scale hacks
		# distort animation, collision expectations and head proportions.
		_check(actor.scale.is_equal_approx(Vector3.ONE),
				profile.display + " retains identity scale")
		var signature := JSON.stringify(profile.motion)
		signatures[signature] = true
		loaded += 1
		actor.queue_free()
	_check(loaded == 18, "all resident models instantiate")
	_check(signatures.size() == 18,
			"every resident has a unique authored motion signature")
	# The biped family gets Evelyn's set PLUS the 38-clip gesture library
	# (build_gesture_library.py). Prove it on a hero mesh: the graft must
	# land both a donor clip and the gesture repertoire.
	var hero := load("res://assets/characters/teresa_vale/teresa_vale.gltf") \
			as PackedScene
	_check(hero != null, "hero mesh loads for gesture graft check")
	if hero:
		var actor := hero.instantiate()
		add_child(actor)
		_check(ResidentMovesLibrary.apply(actor),
				"hero mesh accepts the biped move set")
		var player := _find_animation_player(actor)
		_check(player != null and player.has_animation("walk"),
				"hero mesh grafts Evelyn's walk")
		_check(player != null and player.has_animation("formal_bow"),
				"hero mesh grafts the gesture library (formal_bow)")
		_check(player != null and player.has_animation("idle_12"),
				"hero mesh grafts alternate idles (idle_12)")
		var gesture_count := 0
		if player:
			for clip_name in player.get_animation_list():
				gesture_count += 1
		_check(gesture_count >= 48,
				"hero repertoire holds Evelyn's 10 + 38 gestures (%d)"
				% gesture_count)
		actor.queue_free()
	var art_file := FileAccess.open(
			"res://data/character_memory_art.json", FileAccess.READ)
	var art_catalog: Dictionary = JSON.parse_string(art_file.get_as_text())
	_check(art_catalog.pieces.size() == 20,
			"20 character-defining memory artworks cataloged")
	var art_ids := {}
	for piece in art_catalog.pieces:
		art_ids[piece.id] = true
		_check(ResourceLoader.exists(
				"res://assets/building/textures/character_memories/" +
				piece.atlas), piece.id + " atlas imports")
	_check(art_ids.size() == art_catalog.pieces.size(),
			"every memory artwork has a unique placement id")
	var wall_art_file := FileAccess.open(
			"res://data/character_wall_art.json", FileAccess.READ)
	var wall_art_catalog: Dictionary = JSON.parse_string(
			wall_art_file.get_as_text())
	_check(wall_art_catalog.pieces.size() == 20,
			"20 character-specific wall artworks cataloged")
	var wall_art_ids := {}
	for piece in wall_art_catalog.pieces:
		wall_art_ids[piece.id] = true
		_check(ResourceLoader.exists(
				"res://assets/building/textures/character_wall_art/" +
				piece.atlas), piece.id + " wall-art atlas imports")
	_check(wall_art_ids.size() == wall_art_catalog.pieces.size(),
			"every wall artwork has a unique placement id")
	var hall_file := FileAccess.open(
			"res://data/hallway_art.json", FileAccess.READ)
	var hall_catalog: Dictionary = JSON.parse_string(hall_file.get_as_text())
	_check(hall_catalog.pieces.size() == 8,
			"8 shared hallway artworks cataloged")
	for piece in hall_catalog.pieces:
		_check(ResourceLoader.exists(
				"res://assets/building/textures/hallway_art/" + piece.atlas),
				piece.id + " hallway-art atlas imports")
	print("RESIDENT CAST TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _contains(names: Array, fragment: String) -> bool:
	for item in names:
		if fragment in str(item).to_lower():
			return true
	return false


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [cast ok] ", label)
	else:
		failures += 1
		printerr("  [CAST FAIL] ", label)
