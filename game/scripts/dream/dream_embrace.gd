class_name DreamEmbrace
extends Node
## CAPTURE BECOMES INTERIOR.
##
## One inward-facing shell closes from every edge of the existing camera while
## the existing service lamp remains in exactly the state the player chose.
## The shell is presentation only: no collision, hazard, camera, input verb or
## topology. All eye closure is a uniform on the already-batched hazard body.

signal completed

const SHADER := preload("res://shaders/dream_embrace.gdshader")
const CLOSE_SECONDS := 1.50
const HOLD_SECONDS := 0.18
const SHELL_RADIUS_M := 0.68
const FINAL_LOWPASS_HZ := 4200.0
const FINAL_REVERB_ROOM_SIZE := 0.045

var active := false
var progress := 0.0
var player: PlayerController
var hazard_material: ShaderMaterial
var case_id := ""

var _elapsed := 0.0
var _shell: MeshInstance3D
var _shell_material: ShaderMaterial
var _case_sound: AudioStreamPlayer
var _master_bus := -1
var _reverb: AudioEffectReverb
var _low_pass: AudioEffectLowPassFilter
var _finished := false
var _hidden_hud_layers: Array[CanvasLayer] = []


func begin(body: PlayerController, growth_material: ShaderMaterial,
		subject_case_id: String) -> bool:
	if active or body == null or body.camera == null:
		return false
	player = body
	hazard_material = growth_material
	case_id = subject_case_id
	active = true
	_elapsed = 0.0
	_finished = false
	_build_shell()
	_build_close_acoustics()
	_build_fifth_position()
	# The embrace owns bodily stillness, not the lamp switch. Stopping the
	# player's ordinary process also prevents an input edge from changing that
	# switch during the 1.5-second close; the settled world light remains live.
	player.velocity = Vector3.ZERO
	player.call_locked = true
	player.set_process(false)
	# The crosshair and telegram are tools for acting on a world. During capture
	# the frame itself is becoming interior; neither survives as a decal on her.
	for child in player.get_children():
		if child is CanvasLayer and child.visible:
			_hidden_hud_layers.append(child)
			child.visible = false
	set_meta("duration_s", CLOSE_SECONDS)
	set_meta("hold_s", HOLD_SECONDS)
	set_meta("direction", "none_frame_becomes_interior")
	set_meta("lamp_state_preserved", player.lamp_is_enabled())
	set_meta("topology", "none")
	set_meta("danger", "none_existing_capture_outcome_only")
	set_meta("acoustics", "close_short_warm_nondirectional")
	set_meta("photosensitivity", "monotonic_no_strobe")
	set_meta("hud_hidden", not _hidden_hud_layers.is_empty())
	_apply_progress(0.0)
	return true


func _build_shell() -> void:
	_shell = MeshInstance3D.new()
	_shell.name = "EmbraceInterior"
	var sphere := SphereMesh.new()
	sphere.radius = SHELL_RADIUS_M
	sphere.height = SHELL_RADIUS_M * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_shell.mesh = sphere
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell_material = ShaderMaterial.new()
	_shell_material.shader = SHADER
	_shell_material.set_shader_parameter("close_amount", 0.0)
	_shell_material.set_shader_parameter("biological_afterglow", 0.27)
	_shell_material.set_shader_parameter("lamp_enabled",
			1.0 if player.lamp_is_enabled() else 0.0)
	_shell_material.set_shader_parameter("debug_view", clampi(
			OS.get_environment("DREAM_EMBRACE_DEBUG").to_int(), 0, 2))
	_shell.material_override = _shell_material
	player.camera.add_child(_shell)


func _build_close_acoustics() -> void:
	_master_bus = AudioServer.get_bus_index("Master")
	if _master_bus < 0:
		return
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.30
	_reverb.damping = 0.88
	_reverb.spread = 0.12
	_reverb.hipass = 0.18
	_reverb.predelay_msec = 0.0
	_reverb.predelay_feedback = 0.0
	_reverb.dry = 1.0
	_reverb.wet = 0.0
	AudioServer.add_bus_effect(_master_bus, _reverb)
	_low_pass = AudioEffectLowPassFilter.new()
	_low_pass.cutoff_hz = 20500.0
	_low_pass.resonance = 0.08
	AudioServer.add_bus_effect(_master_bus, _low_pass)


## The resident wound's own recorded domestic signature loses direction here.
## It is a normal AudioStreamPlayer, not a 3D emitter: the ruled fifth position
## is inside the listener rather than a new point somewhere around the room.
func _build_fifth_position() -> void:
	var signature := PoltergeistLibrary.signature(case_id)
	_case_sound = AudioStreamPlayer.new()
	_case_sound.name = "CaseSoundFifthPosition"
	_case_sound.stream = PropAudio.get_stream(str(signature.get("sound", "pop")))
	_case_sound.pitch_scale = float(signature.get("pitch", 1.0))
	_case_sound.volume_db = -9.0
	add_child(_case_sound)
	set_meta("case_sound_key", str(signature.get("sound", "pop")))
	set_meta("case_sound_pitch", _case_sound.pitch_scale)
	set_meta("case_sound_position", "nondirectional_fifth")
	# Headless decoder teardown is not an audible proof and produces unrelated
	# leak noise. The production/windowed path plays the same bound stream.
	if DisplayServer.get_name() != "headless" and _case_sound.stream != null:
		_case_sound.play()


func _process(delta: float) -> void:
	if not active or _finished:
		return
	_elapsed += delta
	var linear := clampf(_elapsed / CLOSE_SECONDS, 0.0, 1.0)
	# Slow at first contact and at the final centre; always monotonic.
	_apply_progress(smoothstep(0.0, 1.0, linear))
	if _elapsed >= CLOSE_SECONDS + HOLD_SECONDS:
		_finished = true
		active = false
		completed.emit()


func _apply_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	if _shell_material != null:
		_shell_material.set_shader_parameter("close_amount", progress)
	if hazard_material != null:
		# Eyes finish closing before the last central view disappears, so the
		# player can actually witness the shame beat rather than merely infer it.
		hazard_material.set_shader_parameter("embrace_amount",
				smoothstep(0.08, 0.72, progress))
	if _low_pass != null:
		_low_pass.cutoff_hz = lerpf(20500.0, FINAL_LOWPASS_HZ, progress)
	if _reverb != null:
		_reverb.room_size = lerpf(0.30, FINAL_REVERB_ROOM_SIZE, progress)
		_reverb.dry = lerpf(1.0, 0.72, progress)
		_reverb.wet = lerpf(0.0, 0.36, progress)
	set_meta("progress", progress)


## Shot and contract harnesses freeze the real-time clock and place the same
## production presentation at exact stages. This never emits completion or an
## outcome and is not called by play.
func set_progress_for_proof(value: float) -> void:
	_apply_progress(value)


func set_lamp_state_for_proof(enabled: bool) -> void:
	if _shell_material != null:
		_shell_material.set_shader_parameter("lamp_enabled",
				1.0 if enabled else 0.0)


func shell_material() -> ShaderMaterial:
	return _shell_material


func close_reverb() -> AudioEffectReverb:
	return _reverb


func close_low_pass() -> AudioEffectLowPassFilter:
	return _low_pass


func case_sound_player() -> AudioStreamPlayer:
	return _case_sound


func _exit_tree() -> void:
	if _case_sound != null:
		_case_sound.stop()
		_case_sound.stream = null
	if _master_bus < 0:
		return
	for index in range(AudioServer.get_bus_effect_count(_master_bus) - 1,
			-1, -1):
		var effect := AudioServer.get_bus_effect(_master_bus, index)
		if effect == _reverb or effect == _low_pass:
			AudioServer.remove_bus_effect(_master_bus, index)
