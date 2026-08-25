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
	_check("one active case loads its sixteen substance maps and no reflection",
			cache.load_bundle(mina, resources) and cache.resource_count() == 16
			and cache.active_incarnation == "mina")
	_check("the live census is computed from exact dimensions, formats and mips",
			cache.residency_bytes == PlateCache.production_ceiling_bytes(catalog))
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D incarnation_albedo_0; uniform sampler2D incarnation_normal_0;"
	var material := ShaderMaterial.new()
	material.shader = shader
	cache.apply_to_material(material, mina)
	_check("the cache binds packed substance pairs without a reflection channel",
			material.get_shader_parameter("incarnation_albedo_0") != null
			and material.get_shader_parameter("incarnation_normal_0") != null)
	_check("the production lossless ceiling excludes every reflection plate",
			PlateCache.production_ceiling_bytes() == 55924040
			and is_equal_approx(float(PlateCache.production_ceiling_bytes())
					/ (1024.0 * 1024.0), 53.33332061767578))

	var peter_profile: Dictionary = profiles.get("peter_release_print", {})
	var peter_result := Profile.resolve(peter_profile.get("presentation", null),
			"peter_release_print", "peter_form_corridor")
	var peter: Dictionary = peter_result.get("bundle", {})
	_check("Peter replaces Mina with exactly one active sixteen-map bundle",
			cache.load_bundle(peter, _resources_for(peter, catalog))
			and cache.resource_count() == 16
			and cache.active_incarnation == "peter"
			and not cache.resources.has("%s/albedo" % str(mina.substance_keys[0])))
	var juno_profile: Dictionary = profiles.get("juno_release_print", {})
	var juno_result := Profile.resolve(juno_profile.get("presentation", null),
			"juno_release_print", "juno_feedback_tetris")
	var juno: Dictionary = juno_result.get("bundle", {})
	_check("Juno replaces Peter with exactly one active sixteen-map bundle",
			cache.load_bundle(juno, _resources_for(juno, catalog))
			and cache.resource_count() == 16
			and cache.active_incarnation == "juno"
			and not cache.resources.has("%s/albedo" % str(peter.substance_keys[0])))
	var mae_profile: Dictionary = profiles.get("mae_release_print", {})
	var mae_result := Profile.resolve(mae_profile.get("presentation", null),
			"mae_release_print", "mae_contradictory_antiques")
	var mae: Dictionary = mae_result.get("bundle", {})
	_check("Mae replaces Juno with exactly one active sixteen-map bundle",
			cache.load_bundle(mae, _resources_for(mae, catalog))
			and cache.resource_count() == 16
			and cache.active_incarnation == "mae"
			and not cache.resources.has("%s/albedo" % str(juno.substance_keys[0])))
	var cal_profile: Dictionary = profiles.get("cal_release_print", {})
	var cal_result := Profile.resolve(cal_profile.get("presentation", null),
			"cal_release_print", "cal_memory_radio")
	var cal: Dictionary = cal_result.get("bundle", {})
	_check("Cal replaces Mae with exactly one active sixteen-map bundle",
			cache.load_bundle(cal, _resources_for(cal, catalog))
			and cache.resource_count() == 16
			and cache.active_incarnation == "cal"
			and not cache.resources.has("%s/albedo" % str(mae.substance_keys[0])))
	var omar_profile: Dictionary = profiles.get("omar_release_print", {})
	var omar_result := Profile.resolve(omar_profile.get("presentation", null),
			"omar_release_print", "omar_unrepairable")
	var omar: Dictionary = omar_result.get("bundle", {})
	_check("Omar replaces Cal with exactly one active sixteen-map bundle",
			cache.load_bundle(omar, _resources_for(omar, catalog))
			and cache.resource_count() == 16
			and cache.active_incarnation == "omar"
			and not cache.resources.has("%s/albedo" % str(cal.substance_keys[0])))
	_check("an inactive profile cannot retain or substitute Omar's plates",
			cache.load_bundle(Profile.default_bundle(), {})
			and cache.resource_count() == 0
			and cache.active_incarnation.is_empty()
			and cache.last_error.is_empty())

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
		"channels": {
			"albedo": {"bytes_per_pixel": 4, "suffix": "albedo.png"},
			"height": {"bytes_per_pixel": 1, "suffix": "height.png"},
			"normal": {"bytes_per_pixel": 4, "suffix": "normal.png"},
			"roughness": {"bytes_per_pixel": 1, "suffix": "roughness.png"},
		},
		"available_cases": ["mina", "peter", "juno", "mae", "cal", "omar"],
		"root": "res://not_used",
	}


func _resources_for(bundle: Dictionary, catalog: Dictionary) -> Dictionary:
	var result := {}
	var size := int(catalog.substance_resolution)
	for key in bundle.substance_keys as PackedStringArray:
		for channel in PlateCache.CHANNELS:
			result["%s/%s" % [key, channel]] = _texture(size, size)
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
