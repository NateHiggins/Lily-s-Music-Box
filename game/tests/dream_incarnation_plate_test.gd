extends Node
## INC-V2: exact one-case plate residency, no substitution, and release.

const PROFILE_PATH := "res://data/dream_profiles.json"
const Profile := preload("res://scripts/dream/dream_incarnation_profile.gd")
const PlateCache := preload(
		"res://scripts/dream/dream_incarnation_plate_cache.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[INC-V2 PLATES] START")
	var profiles: Dictionary = _json(PROFILE_PATH).get("profiles", {})
	var mina_profile: Dictionary = profiles.get("mina_release_print", {})
	var mina_result := Profile.resolve(mina_profile.get("presentation", null),
			"mina_release_print", "mina_caption_crisis")
	var mina: Dictionary = mina_result.get("bundle", {})
	var catalog := _test_catalog()
	var cache := PlateCache.new(catalog)
	var resources := _resources_for(mina, catalog)
	_check("one active case loads all sixteen substance maps and one reflection",
			cache.load_bundle(mina, resources) and cache.resource_count() == 17
			and cache.active_incarnation == "mina")
	_check("the live census is computed from exact dimensions, formats and mips",
			cache.residency_bytes == PlateCache.production_ceiling_bytes(catalog))
	_check("the production lossless ceiling is exactly 96 MiB",
			PlateCache.production_ceiling_bytes() == 100663284
			and is_equal_approx(float(PlateCache.production_ceiling_bytes())
					/ (1024.0 * 1024.0), 96.0))

	var peter_profile: Dictionary = profiles.get("peter_release_print", {})
	var peter_result := Profile.resolve(peter_profile.get("presentation", null),
			"peter_release_print", "peter_form_corridor")
	var peter: Dictionary = peter_result.get("bundle", {})
	_check("a missing next case cannot retain or substitute Mina's plates",
			not cache.load_bundle(peter, {}) and cache.resource_count() == 0
			and cache.active_incarnation.is_empty()
			and cache.last_error.contains("missing texture"))

	cache.load_bundle(mina, resources)
	cache.unload()
	_check("wake release drops every active resource reference and byte",
			cache.resource_count() == 0 and cache.residency_bytes == 0
			and cache.active_incarnation.is_empty())

	var gated := Profile.default_bundle()
	_check("an inactive profile loads no plates and is not an error",
			cache.load_bundle(gated, {}) and cache.resource_count() == 0
			and cache.last_error.is_empty())
	print("[INC-V2 PLATES] CHECKS: %d/%d fails=%d" %
			[checks - failures, checks, failures])
	print("DREAM INCARNATION PLATE TEST: %s" %
			("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _test_catalog() -> Dictionary:
	return {
		"substance_resolution": 8,
		"reflection_resolution": [16, 8],
		"channels": {
			"albedo": {"bytes_per_pixel": 4, "suffix": "albedo.png"},
			"height": {"bytes_per_pixel": 1, "suffix": "height.png"},
			"normal": {"bytes_per_pixel": 4, "suffix": "normal.png"},
			"roughness": {"bytes_per_pixel": 1, "suffix": "roughness.png"},
		},
		"available_cases": ["mina", "peter"],
		"root": "res://not_used",
	}


func _resources_for(bundle: Dictionary, catalog: Dictionary) -> Dictionary:
	var result := {}
	var size := int(catalog.substance_resolution)
	for key in bundle.substance_keys as PackedStringArray:
		for channel in PlateCache.CHANNELS:
			result["%s/%s" % [key, channel]] = _texture(size, size)
	var reflection: Array = catalog.reflection_resolution
	result[str(bundle.reflected_world_key)] = _texture(
			int(reflection[0]), int(reflection[1]))
	return result


func _texture(width: int, height: int) -> ImageTexture:
	var image := Image.create_empty(width, height, true, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.1, 0.3, 1.0))
	return ImageTexture.create_from_image(image)


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [plate ok] ", label)
	else:
		failures += 1
		printerr("  [PLATE FAIL] ", label)
