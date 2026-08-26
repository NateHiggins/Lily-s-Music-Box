class_name SleepPressureDirector
extends Node
## N5's persistent onset owner. It turns an already-earned DreamDirector arm
## into one deterministic, protected and physically safe entry request.
##
## It owns no case eligibility, maze, pursuit, work-order or cure rule. Running,
## crouching, input and ordinary play never reduce pressure.

signal onset_started(case_id: String, form: String, duration_s: float)
signal onset_progress_changed(progress: float, form: String)
signal onset_blocked(reason: String)
signal sleep_entry_requested(case_id: String, form: String)

const PROFILE_PATH := "res://data/dream_profiles.json"
const FORMS: Array[String] = ["gradual", "sudden"]
const SAVE_STEP_SECONDS := 0.5

var dream_director: DreamDirector
var player: Node3D
var elevator: Node
var traffic: Node
## Deterministic harnesses advance the same production clock explicitly.
var manual_clock := false

var _profiles: Dictionary = {}
var _blocked_reason := ""
var _duration_s := 0.0
var _saved_bucket := 0
var _overlay: ColorRect
var _overlay_material: ShaderMaterial
var _hum: AudioStreamPlayer
var _hum_raised := false
var _low_pass: AudioEffectLowPassFilter
var _master_bus := -1


func _ready() -> void:
	_load_profiles()
	_build_presentation()
	set_process(false)


func setup(owner: DreamDirector) -> void:
	dream_director = owner
	if not dream_director.dream_armed.is_connected(_on_dream_armed):
		dream_director.dream_armed.connect(_on_dream_armed)
	if not dream_director.dream_entered.is_connected(_on_dream_entered):
		dream_director.dream_entered.connect(_on_dream_entered)
	if not dream_director.dream_ended.is_connected(_on_dream_ended):
		dream_director.dream_ended.connect(_on_dream_ended)
	_reconcile()


func bind_waking_services(body: Node3D, lift: Node = null,
		street: Node = null) -> void:
	player = body
	elevator = lift
	traffic = street
	_apply_presentation()
	set_process(dream_director != null
			and dream_director.phase() == "armed")


func detach_waking_services() -> void:
	if player != null and is_instance_valid(player) \
			and player.has_method("set_sleep_onset_progress"):
		player.call("set_sleep_onset_progress", 0.0)
	player = null
	elevator = null
	traffic = null
	set_process(false)


func pressure() -> float:
	if _duration_s <= 0.0:
		return 0.0
	return clampf(float(_state().get("elapsed_s", 0.0)) / _duration_s,
			0.0, 1.0)


func onset_form() -> String:
	return str(_state().get("onset_form", ""))


func blocked_reason() -> String:
	return _blocked_reason


func presentation_progress() -> float:
	return float(_overlay_material.get_shader_parameter("pressure")) \
			if _overlay_material else 0.0


func mix_cutoff_hz() -> float:
	return _low_pass.cutoff_hz if _low_pass else 20500.0


func room0_hum_is_playing() -> bool:
	return _hum_raised


## Pure deterministic policy used by production and the focused proof. The
## seed is never converted through JSON's lossy number representation.
func choose_onset_form(allowed: Array, seed_hex: String,
		always_warn: bool) -> String:
	var valid: Array[String] = []
	for candidate in allowed:
		var form := str(candidate)
		if form in FORMS and form not in valid:
			valid.append(form)
	if valid.is_empty():
		return ""
	if always_warn:
		return "gradual" if "gradual" in valid else ""
	if valid.size() == 1:
		return valid[0]
	var selector := 0
	for index in seed_hex.length():
		selector = (selector * 33 + seed_hex.unicode_at(index)) & 0x7fffffff
	return valid[selector % valid.size()]


## The test clock calls the exact production advance path without waiting 2.6
## wall-clock seconds at every blocked boundary.
func advance_for_test(delta: float) -> bool:
	if not manual_clock:
		return false
	_advance(maxf(0.0, delta))
	return true


func _process(delta: float) -> void:
	if not manual_clock:
		_advance(delta)


func _advance(delta: float) -> void:
	if dream_director == null or dream_director.phase() != "armed":
		set_process(false)
		return
	if player == null or not is_instance_valid(player):
		_set_blocked("waking_world_unbound")
		return
	if bool(player.get("call_locked")):
		_set_blocked("engaged")
		return
	if not player.has_method("sleep_entry_body_is_stable") \
			or not bool(player.call("sleep_entry_body_is_stable")):
		_set_blocked("unstable_body")
		return
	if elevator != null and is_instance_valid(elevator) \
			and elevator.has_method("blocks_sleep_entry") \
			and bool(elevator.call("blocks_sleep_entry",
					player.global_position)):
		_set_blocked("elevator_seam")
		return
	if traffic != null and is_instance_valid(traffic) \
			and traffic.has_method("blocks_sleep_entry") \
			and bool(traffic.call("blocks_sleep_entry",
					player.global_position)):
		_set_blocked("traffic")
		return
	_set_blocked("")
	var state := _state()
	if not bool(state.get("started", false)):
		state.started = true
		RealityState.commit()
		onset_started.emit(str(dream_director.context().case_id),
			onset_form(), _duration_s)
	var elapsed := minf(_duration_s,
			float(state.get("elapsed_s", 0.0)) + delta)
	state.elapsed_s = elapsed
	_apply_presentation()
	var bucket := int(floor(elapsed / SAVE_STEP_SECONDS))
	if bucket > _saved_bucket and elapsed < _duration_s:
		_saved_bucket = bucket
		RealityState.commit()
	if elapsed < _duration_s:
		return
	# Save the completed warning before DreamDirector commits `entered` and asks
	# the shell to remove the waking world. A crash has one forward answer.
	RealityState.commit()
	set_process(false)
	var case_id := str(dream_director.context().case_id)
	var form := onset_form()
	if dream_director.enter_armed_dream():
		sleep_entry_requested.emit(case_id, form)
	else:
		set_process(true)


func _on_dream_armed(_case_id: String, profile_id: String) -> void:
	_arm(profile_id)


func _on_dream_entered(_case_id: String, _seed_hex: String) -> void:
	_clear_state()


func _on_dream_ended(_case_id: String, _outcome: String) -> void:
	_clear_state()


func _arm(profile_id: String) -> bool:
	var profile := _profile_for_current_dream(profile_id)
	if profile.is_empty():
		push_warning("dream onset profile missing or invalid: %s" % profile_id)
		return false
	var onset: Dictionary = profile.onset
	var form := choose_onset_form(onset.allowed_forms,
			str(dream_director.context().seed_hex),
			bool(GameBoot.settings.get("always_warn_before_sleep", false)))
	if form.is_empty():
		return false
	_duration_s = float(onset.get("%s_seconds" % form, 0.0))
	if _duration_s <= 0.0:
		return false
	RealityState.data.sleep_pressure = {
		"onset_form": form,
		"elapsed_s": 0.0,
		"started": false,
	}
	_saved_bucket = 0
	RealityState.commit()
	_apply_presentation()
	set_process(true)
	return true


func _reconcile() -> void:
	if dream_director == null:
		return
	if dream_director.phase() != "armed":
		if not _state().is_empty():
			_clear_state()
		return
	var state := _state()
	var profile_id := str(dream_director.context().profile_id)
	var profile := _profile_for_current_dream(profile_id)
	if profile.is_empty():
		push_warning("dream onset profile missing or invalid: %s" % profile_id)
		return
	var form := str(state.get("onset_form", ""))
	var onset := profile.onset as Dictionary
	if form not in FORMS or form not in onset.allowed_forms:
		_arm(profile_id)
		return
	_duration_s = float(onset.get(
			"%s_seconds" % form, 0.0))
	if _duration_s <= 0.0:
		return
	state.elapsed_s = clampf(float(state.get("elapsed_s", 0.0)),
			0.0, _duration_s)
	_saved_bucket = int(floor(float(state.elapsed_s) / SAVE_STEP_SECONDS))
	_apply_presentation()
	set_process(true)


func _profile(profile_id: String) -> Dictionary:
	var profile: Variant = _profiles.get(profile_id, {})
	if profile is not Dictionary:
		return {}
	var record := profile as Dictionary
	if str(record.get("case_id", "")).is_empty() \
			or record.get("onset") is not Dictionary:
		return {}
	var onset := record.onset as Dictionary
	if onset.get("allowed_forms") is not Array:
		return {}
	# Accessibility is a data contract, not a best effort. A future sudden-only
	# profile would make Always warn lie, so the entire record is invalid.
	if "gradual" not in onset.allowed_forms:
		return {}
	for form in onset.allowed_forms:
		if str(form) not in FORMS \
				or float(onset.get("%s_seconds" % str(form), 0.0)) <= 0.0:
			return {}
	return record


func _profile_for_current_dream(profile_id: String) -> Dictionary:
	var record := _profile(profile_id)
	if record.is_empty() or dream_director == null \
			or str(record.case_id) != str(dream_director.context().case_id):
		return {}
	return record


func _load_profiles() -> void:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PROFILE_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("profiles") \
			is Dictionary:
		_profiles = (parsed as Dictionary).profiles
	else:
		push_warning("dream profile book is missing or invalid")


func _state() -> Dictionary:
	if not RealityState.data.has("sleep_pressure") \
			or RealityState.data.sleep_pressure is not Dictionary:
		RealityState.data.sleep_pressure = {}
	return RealityState.data.sleep_pressure


func _clear_state() -> void:
	RealityState.data.sleep_pressure = {}
	_duration_s = 0.0
	_saved_bucket = 0
	_set_blocked("")
	_set_presentation(0.0, "")
	RealityState.commit()
	set_process(false)


func _set_blocked(reason: String) -> void:
	if reason == _blocked_reason:
		return
	_blocked_reason = reason
	if not reason.is_empty():
		onset_blocked.emit(reason)


func _apply_presentation() -> void:
	_set_presentation(pressure(), onset_form())


func _build_presentation() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SleepOnsetPresentation"
	layer.layer = 11
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.name = "PeripheralNarrowing"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float pressure : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float radius = distance(SCREEN_UV, vec2(0.5));
	float edge = smoothstep(0.22, 0.72, radius);
	float grey = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 flatter = mix(source.rgb, vec3(grey), edge * pressure * 0.22);
	flatter = mix(flatter, vec3(0.42), edge * pressure * 0.10);
	COLOR = vec4(flatter * (1.0 - edge * pressure * 0.30), source.a);
}
"""
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter("pressure", 0.0)
	_overlay.material = _overlay_material
	layer.add_child(_overlay)
	_hum = AudioStreamPlayer.new()
	_hum.bus = "Hazard"
	_hum.name = "Room0OnsetHum"
	_hum.stream = PropAudio.get_stream("hum_loop")
	_hum.pitch_scale = 0.5
	_hum.volume_db = -60.0
	add_child(_hum)
	_master_bus = AudioServer.get_bus_index("Master")
	if _master_bus >= 0:
		_low_pass = AudioEffectLowPassFilter.new()
		_low_pass.cutoff_hz = 20500.0
		_low_pass.resonance = 0.10
		AudioServer.add_bus_effect(_master_bus, _low_pass)


func _set_presentation(value: float, form: String) -> void:
	var amount := clampf(value, 0.0, 1.0)
	if _overlay_material:
		_overlay_material.set_shader_parameter("pressure", amount)
	if _low_pass:
		_low_pass.cutoff_hz = lerpf(20500.0, 3600.0, amount)
	if player != null and is_instance_valid(player) \
			and player.has_method("set_sleep_onset_progress"):
		player.call("set_sleep_onset_progress", amount)
	if _hum:
		if amount > 0.0 and form == "gradual":
			_hum_raised = true
			# Headless has no audible result and its OGG decoder tears down after
			# the process verdict, producing a false resource leak. The focused
			# proof reads the same presentation state without opening a decoder.
			if DisplayServer.get_name() != "headless" and not _hum.playing:
				_hum.play()
			_hum.volume_db = lerpf(-60.0, -27.0, amount)
		else:
			_hum_raised = false
			if _hum.playing:
				_hum.stop()
	onset_progress_changed.emit(amount, form)


func _exit_tree() -> void:
	# Audio playback owns decoder objects outside the node tree. Stop and detach
	# the stream explicitly so repeated campaign-shell restore tests do not leave
	# one OGG decoder alive per destroyed warning.
	if _hum:
		_hum.stop()
		_hum.stream = null
	if _master_bus < 0 or _low_pass == null:
		return
	for index in range(AudioServer.get_bus_effect_count(_master_bus) - 1,
			-1, -1):
		if AudioServer.get_bus_effect(_master_bus, index) == _low_pass:
			AudioServer.remove_bus_effect(_master_bus, index)
			break
