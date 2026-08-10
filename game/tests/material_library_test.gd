extends Node
## The generated material contract is complete, physically accountable and
## safe to share. Visual locks are allowed only while their family awaits its
## explicit approval render; unlocked materials must match catalog scale.

const CONTRACT_PATH := "res://data/runtime_material_sets.json"
var failures := 0


func _ready() -> void:
	var text := FileAccess.get_file_as_string(CONTRACT_PATH)
	var parsed = JSON.parse_string(text)
	_check(parsed is Dictionary, "runtime manifest parses")
	if not parsed is Dictionary:
		get_tree().quit(failures)
		return
	var materials: Dictionary = parsed.get("materials", {})
	_check(materials.size() == MatLib.SETS.size(),
			"manifest and generated GDScript expose the same key count")
	for key in MatLib.SETS:
		_check(materials.has(key), "%s exists in the manifest" % key)
		var spec: Array = MatLib.SETS[key]
		for map_index in range(3):
			_check(ResourceLoader.exists(MatLib.TEX + str(spec[map_index])),
					"%s map %d resolves" % [key, map_index])
		var authored: Dictionary = materials.get(key, {})
		if not bool(authored.get("visual_lock", false)):
			_check(is_equal_approx(float(authored.meters_per_tile),
					float(authored.canonical_meters_per_tile)),
					"%s has one physical scale" % key)

	# A prop may duplicate and mutate a material; it may never modify the
	# shared cached source. Bookshelf used to turn global linen and paper into
	# vertex-colour materials while it was constructing its batched books.
	var linen := MatLib.get_mat("linen", Color.WHITE, 2.0)
	var paper := MatLib.get_mat("paper", Color.WHITE, 2.0)
	_check(not linen.vertex_color_use_as_albedo,
			"cached linen begins without prop-local vertex colour")
	_check(not paper.vertex_color_use_as_albedo,
			"cached paper begins without prop-local vertex colour")
	var shelf := BookshelfProp.new()
	add_child(shelf)
	await get_tree().process_frame
	_check(not linen.vertex_color_use_as_albedo,
			"bookshelf does not mutate cached linen")
	_check(not paper.vertex_color_use_as_albedo,
			"bookshelf does not mutate cached paper")
	shelf.queue_free()
	await get_tree().process_frame

	print("MATERIAL LIBRARY TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [material ok] ", label)
	else:
		failures += 1
		printerr("  [MATERIAL FAIL] ", label)
