extends Node
## INC-V1: validates the presentation schema and proves one immutable bundle
## reaches the existing architecture, lineage and five fauna materials without
## creating another runtime owner.

const PROFILE_PATH := "res://data/dream_profiles.json"
const SEED_HEX := "f123456789abcdef"
const IncarnationProfile := preload(
		"res://scripts/dream/dream_incarnation_profile.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[INC-V1] START")
	var profiles: Dictionary = _json_dictionary(PROFILE_PATH).get("profiles", {})
	_data_contract(profiles)
	await _production_contract()
	print("[INC-V1] CHECKS: %d/%d fails=%d" %
			[checks - failures, checks, failures])
	print("DREAM INCARNATION TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _data_contract(profiles: Dictionary) -> void:
	var expected := {
		"mina_release_print": ["mina_caption_crisis", "mina", 1],
		"peter_release_print": ["peter_form_corridor", "peter", 2],
		"juno_release_print": ["juno_feedback_tetris", "juno", 3],
		"mae_release_print": ["mae_contradictory_antiques", "mae", 4],
	}
	for profile_id in expected:
		var profile: Dictionary = profiles.get(profile_id, {})
		var row: Array = expected[profile_id]
		var result := IncarnationProfile.resolve(
				profile.get("presentation", null), profile_id, str(row[0]))
		_check("%s presentation validates" % row[1], bool(result.get("ok", false)))
		var bundle: Dictionary = result.get("bundle", {})
		_check("%s has one enabled bounded identity" % row[1],
				str(bundle.get("incarnation_id", "")) == str(row[1])
				and int(bundle.get("incarnation_index", 0)) == int(row[2])
				and bool(bundle.get("production_enabled", false)))
		_check("%s names four substances and one reflection" % row[1],
				(bundle.get("substance_keys", PackedStringArray()) as PackedStringArray).size() == 4
				and not str(bundle.get("reflected_world_key", "")).is_empty())
		_check("%s revoices the five ordered fauna" % row[1],
				(bundle.get("fauna", []) as Array).size() == 5)

	var legacy := IncarnationProfile.resolve(null, "legacy_profile", "legacy_case")
	var legacy_bundle: Dictionary = legacy.get("bundle", {})
	_check("a legacy profile retains the exact inert current look",
			bool(legacy.get("ok", false))
			and int(legacy_bundle.get("incarnation_index", -1)) == 0
			and not bool(legacy_bundle.get("production_enabled", true))
			and (legacy_bundle.get("substance_keys", PackedStringArray())
					as PackedStringArray).is_empty()
			and legacy_bundle.get("pattern") == Vector4(0.0, 1.0, 1.0, 1.0)
			and legacy_bundle.get("irradiance") == Vector4.ONE)

	var cal := _valid_shape("cal")
	var cal_result := IncarnationProfile.resolve(
			cal, "cal_release_print", "cal_memory_radio")
	_check("presentation data cannot production-enable gated Cal",
			not bool(cal_result.get("ok", true))
			and "cal remains production gated" in cal_result.get("errors", []))
	var omar := _valid_shape("omar")
	var omar_result := IncarnationProfile.resolve(
			omar, "omar_release_print", "omar_unrepairable")
	_check("presentation data cannot production-enable gated Omar",
			not bool(omar_result.get("ok", true))
			and "omar remains production gated" in omar_result.get("errors", []))

	var mismatched: Dictionary = profiles.get("mina_release_print", {}).get(
			"presentation", {}).duplicate(true)
	var mismatch_result := IncarnationProfile.resolve(
			mismatched, "peter_release_print", "peter_form_corridor")
	_check("a look cannot impersonate another case or profile",
			not bool(mismatch_result.get("ok", true)))
	mismatched = (profiles.get("mina_release_print", {}).get(
			"presentation", {}) as Dictionary).duplicate(true)
	mismatched.motion = [1.2, 0.0, 0.0, 0.0]
	var fast_result := IncarnationProfile.resolve(
			mismatched, "mina_release_print", "mina_caption_crisis")
	_check("autonomous presentation cannot enter one-hertz motion",
			not bool(fast_result.get("ok", true)))


func _production_contract() -> void:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	var root := scene.instantiate() as DreamMazeRoot
	root.autonomous = false
	root.configure_dream({
		"case_id": "mina_caption_crisis",
		"profile_id": "mina_release_print",
		"window": {}, "seed_hex": SEED_HEX, "maze_revision": 1,
		"outcome": "", "night_index": 2, "spawn_anchor": 1,
	})
	add_child(root)
	await get_tree().process_frame
	var bundle := root.active_presentation()
	_check("the production root owns one immutable Mina presentation bundle",
			root.maze_built and str(bundle.get("incarnation_id", "")) == "mina"
			and int(bundle.get("incarnation_index", 0)) == 1)
	var materials: Array = root.get("_molten_materials")
	var all_bound := not materials.is_empty()
	var family_seen := PackedInt32Array()
	for value in materials:
		var material := value as ShaderMaterial
		if material == null or not is_equal_approx(float(
				material.get_shader_parameter("incarnation_id")), 1.0):
			all_bound = false
			continue
		var family := int(material.get_meta("dream_fauna_family_index", -1))
		if family >= 0:
			family_seen.append(family)
			var expected := IncarnationProfile.fauna_uniform(bundle, family)
			if material.get_shader_parameter("incarnation_fauna") != expected:
				all_bound = false
	_check("the existing collector binds every dream shader material", all_bound)
	family_seen.sort()
	_check("the same collector reaches all five fauna costumes exactly once",
			family_seen == PackedInt32Array([0, 1, 2, 3, 4]))
	_check("the seam creates no incarnation runtime owner",
			root.find_children("*Incarnation*", "Node", true, false).is_empty())
	_check("presentation is absent from the persisted dream context",
			not root.dream_context.has("presentation"))
	_check("presentation leaves the case truth unchanged",
			root.active_case_truth().get("statement", "")
					== "Silence does not require annotation")
	_check("presentation leaves Mina's hazard allowlist unchanged",
			(root.profile_hazards.get("allow", []) as Array).size() == 3)
	root.queue_free()
	await get_tree().process_frame


func _valid_shape(incarnation_id: String) -> Dictionary:
	var index := IncarnationProfile.IDS.find(incarnation_id)
	var fauna: Array[Dictionary] = []
	for family in IncarnationProfile.FAMILIES:
		fauna.append({"family": family, "pattern": 0, "jewel_token": 0,
				"substance_slot": 0, "response": 1.0})
	return {
		"incarnation_id": incarnation_id, "production_enabled": true,
		"palette": [0, 0, 0, 0], "pattern": [0, 1, 1, 1],
		"irradiance": [1, 1, 1, 1], "motion": [0.1, 0, 0, 0],
		"signature": {"id": IncarnationProfile.SIGNATURES[index],
				"threshold": 0.8, "strength": 0.5},
		"substance_keys": [
			"T_ai_dream_%s_a" % incarnation_id,
			"T_ai_dream_%s_b" % incarnation_id,
			"T_ai_dream_%s_c" % incarnation_id,
			"T_ai_dream_%s_d" % incarnation_id,
		],
		"reflected_world_key": "T_ai_dream_%s_reflected_world_test" % incarnation_id,
		"fauna": fauna,
	}


func _json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [incarnation ok] ", label)
	else:
		failures += 1
		printerr("  [INCARNATION FAIL] ", label)
