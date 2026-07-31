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
		var path := "res://assets/characters/%s/%s_rigged.glb" % [
				slug, slug]
		var scene := load(path) as PackedScene
		if scene == null:
			_check(false, profile.display + " GLB imports")
			continue
		var actor := scene.instantiate()
		add_child(actor)
		var player := _find_animation_player(actor)
		var names: Array = player.get_animation_list() if player else []
		_check(player != null and _contains(names, "idle"),
				profile.display + " idle imports")
		_check(player != null and _contains(names, "walk"),
				profile.display + " walk imports")
		var signature := JSON.stringify(profile.motion)
		signatures[signature] = true
		loaded += 1
		actor.queue_free()
	_check(loaded == 18, "all resident models instantiate")
	_check(signatures.size() == 18,
			"every resident has a unique authored motion signature")
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
