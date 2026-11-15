extends "res://tests/staff_pose_attention.gd"
## PRIVATE diagnostic: inherited composed morph/skin sampler and shader inventory.
const ADELA_MODEL := "res://assets/characters/cast/adela_voss/adela_voss.gltf"
const ADELA_PARTS := ["p_top", "p_feet", "p_head"]
const ADELA_BINDINGS := "res://tests/fixtures/adela_pose_source_bindings.json"
var mode := ""
var original_mouse := 0
var pilot_logger

func _ready() -> void:
	var profile: String = OS.get_environment("ADELA_POSE_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var actual: String = OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/adela_runtime_intake_01/") or actual != profile.path_join("PleaseRemainOnTheLine"):
		push_error("Adela pilot requires dedicated isolated APPDATA before autoload")
		get_tree().quit(2); return
	mode = OS.get_environment("ADELA_POSE_MODE")
	if mode not in ["idle", "attention"]:
		push_error("ADELA_POSE_MODE must be idle or attention")
		get_tree().quit(2); return
	original_mouse = Input.mouse_mode
	pilot_logger = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(pilot_logger)
	_run.call_deferred()

func _signature() -> Dictionary:
	var result: Dictionary = super._signature()
	result["parent_observer_lf"] = FileAccess.get_file_as_string("res://tests/staff_pose_attention.gd").replace("\r\n", "\n").sha256_text()
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADELA_BINDINGS))
	if not _check(decoded is Dictionary and decoded.get("schema_version") == 1, "reviewed source binding document"):
		return result
	var document: Dictionary = decoded
	var observed: Dictionary = {}
	for path: String in document.sources:
		var binding: Dictionary = document.sources[path]
		if not _check(FileAccess.file_exists(path), "bound source exists " + path): continue
		var signature: String = FileAccess.get_sha256(path)
		if str(binding.kind) != "raw":
			var text: String = FileAccess.get_file_as_string(path).replace("\r\n", "\n")
			if str(binding.kind) == "params_lf":
				if not _check(text.count("[params]") == 1, "one importer parameter section"): continue
				text = text.get_slice("[params]", 1)
			else:
				_check(str(binding.kind) == "lf", "declared source hash algorithm")
			signature = text.sha256_text()
		_check(signature == str(binding.sha256), "reviewed source unchanged " + path)
		observed[path] = {"kind": binding.kind, "sha256": signature}
	result["source_bindings"] = observed
	result["mode"] = mode
	return result

func _run() -> void:
	output = OS.get_environment("SHOT_DIR")
	if not _check(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output) == OK, "private output directory"):
		get_tree().quit(2); return
	if not _check(DisplayServer.get_name() != "headless", "real rendered skin state required"):
		get_tree().quit(2); return
	inputs = _signature()
	prior_data = RealityState.data
	prior_text = JSON.stringify(prior_data, "", true, true)
	prior_status = _status().duplicate(true)
	prior_files = _save_bundle()
	captured_state = true
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease, "exclusive nonpersistent preview"): _finish(); return
	if not await _synthetic_order_check(): _finish(); return
	if not failures.is_empty(): _finish(); return
	grounding = Owner.new() # Unmounted grounding helper only; no attendance owner.
	grounding._floor_y = 0.0
	current_case = {"ensemble_key": "adela_voss_stage_" + mode, "person": "adela_voss", "outfit": "stage", "parts": ADELA_PARTS, "makeup": "stage", "stand_pose": "weight_on_one_leg", "mode": mode}
	scenarios.append(current_case.duplicate(true))
	expected_samples[str(current_case.ensemble_key)] = SAMPLE_COUNT
	actor = Cast.new()
	actor.configure("adela_voss", ADELA_MODEL, ADELA_PARTS, "weight_on_one_leg")
	add_child(actor)
	if not _check(actor.ready_ok, "actual stable Adela cast model"): _finish(); return
	grounding._ground_rest_shoes(actor)
	_check(actor.worn_parts() == ADELA_PARTS, "exact approved stage wardrobe")
	_check(actor.set_makeup("stage"), "actual stage makeup installed")
	var heads: Array[Node] = actor.model.find_children("Skin_head", "MeshInstance3D", true, false)
	if _check(heads.size() == 1, "one actual makeup head"):
		var head: MeshInstance3D = heads[0] as MeshInstance3D
		var paint: StandardMaterial3D = head.material_overlay as StandardMaterial3D
		_check(paint != null and paint.albedo_texture != null and paint.albedo_texture.resource_path == ADELA_MODEL.get_base_dir().path_join("adela_voss_makeup_stage.png"), "actual Adela stage makeup texture")
	actor.skeleton.skeleton_updated.connect(_capture_modified_pose)
	if not failures.is_empty(): _finish(); return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	attention_plan = _attention_stages()
	attention_case = {"name": "idle", "conversing": false, "staged": false}
	var began: int = Time.get_ticks_msec()
	for sample: int in SAMPLE_COUNT:
		if mode == "attention" and sample % 4 == 0: _begin_attention_stage(int(sample / 4), "adela_voss")
		await get_tree().create_timer(INTERVAL).timeout
		await RenderingServer.frame_post_draw
		if mode == "attention" and sample % 4 == 3: await _await_stage_observation()
		records.append(_measure("adela_voss", "stage", sample, (Time.get_ticks_msec() - began) / 1000.0))
		completed_samples[str(current_case.ensemble_key)] = int(completed_samples.get(str(current_case.ensemble_key), 0)) + 1
		if not failures.is_empty(): break
	if mode == "attention": _check_attention_coverage("adela_voss", "stage")
	if failures.is_empty(): await _capture_views("adela_voss", "stage")
	actor.stop_speaking()
	actor.attention._on_conversation_ended("adela_voss")
	actor.attention.staged_target = null
	_finish()

func _finish() -> void:
	_check(Input.mouse_mode == original_mouse, "owner mouse mode untouched")
	if pilot_logger != null:
		_check(pilot_logger.errors.is_empty(), "no engine script/shader errors")
	# Parent preserves actual save/state identity, exact sample counts, four
	# verified stills, source rehash and diagnostic report write/readback.
	super._finish()
