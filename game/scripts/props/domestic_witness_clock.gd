class_name DomesticWitnessClock
extends FunctionalProp
## A familiar clock that behaves like it remembers the room differently.
## Static housing is cheap procedural geometry; hands, face and tell are kept
## separate so the director can animate them without cloth, particles or
## per-prop skeletal rigs.

var case_id := ""
var resident := ""
var style := "bauhaus"
var tell := "correction"
var frozen_time := "04:17"
var accent := Color(0.7, 0.2, 0.2)

var _hour: Node3D
var _minute: Node3D
var _second: Node3D
var _face: Node3D
var _tell_mark: MeshInstance3D
var _display: Label3D
var _tick: AudioStreamPlayer3D
var _home_rotation := 0.0
var _haunt_tween: Tween
var _possessed := false
var _tick_accum := 0.0
var _tick_interval := 1.0


func configure(spec: Dictionary) -> void:
	prop_type = "wall_clock"
	case_id = str(spec.case_id)
	resident = str(spec.resident)
	style = str(spec.style)
	tell = str(spec.tell)
	frozen_time = str(spec.time)
	accent = Color.from_string(str(spec.accent), Color(0.7, 0.2, 0.2))


func _ready() -> void:
	name = "DomesticWitness_%s" % case_id
	add_to_group("domestic_witness_clocks")
	add_to_group("reality_affected_props")
	super._ready()
	_home_rotation = rotation.y


func _build_visual() -> void:
	_face = Node3D.new()
	_face.name = "FaceRig"
	add_child(_face)
	_build_housing()
	_build_face()
	_build_hands()
	_build_collision()
	_tick = make_emitter("tick", -31.0)
	_tick.max_distance = 5.5


func _build_housing() -> void:
	var body_color := Color(0.11, 0.105, 0.095)
	var metal := Color(0.46, 0.43, 0.36)
	match style:
		"hospital": body_color = Color(0.76, 0.79, 0.75)
		"memphis": body_color = Color(0.10, 0.12, 0.16)
		"sunburst": body_color = Color(0.30, 0.20, 0.10)
		"motel": body_color = Color(0.16, 0.30, 0.29)
		"palette": body_color = Color(0.83, 0.72, 0.57)
		"digital": body_color = Color(0.055, 0.06, 0.065)
		"deco": body_color = Color(0.08, 0.13, 0.12)
	var radius := 0.19
	if style in ["digital", "flip", "writer", "motel"]:
		make_box(Vector3(0.42, 0.22, 0.055), Vector3(0, 0, 0), body_color)
	else:
		var shell := make_cyl(radius, radius, 0.05, Vector3.ZERO,
				body_color, 0.38, 0.15)
		shell.rotation_degrees.x = 90
	# Design-language silhouette details, kept restrained and low-poly.
	if style == "sunburst":
		for i in 12:
			var a := TAU * i / 12.0
			var spoke := make_box(Vector3(0.018, 0.13, 0.018),
					Vector3(sin(a) * 0.245, cos(a) * 0.245, 0.01), metal)
			spoke.rotation.z = -a
	if style == "deco":
		for x in [-0.17, 0.17]:
			var fin := make_box(Vector3(0.025, 0.28, 0.025),
					Vector3(x, 0, 0.008), accent.darkened(0.25))
			fin.rotation.z = x * 1.4
	if style == "courier":
		make_box(Vector3(0.30, 0.025, 0.025), Vector3(0, -0.215, 0), accent)
	if style == "stitch":
		for i in 8:
			var stitch := make_box(Vector3(0.025, 0.008, 0.012),
					Vector3(-0.13 + i * 0.037, -0.18, 0.033), accent)
			stitch.rotation.z = 0.18


func _build_face() -> void:
	var face_color := Color(0.88, 0.86, 0.78)
	if style in ["digital", "flip", "writer", "motel"]:
		face_color = Color(0.025, 0.03, 0.032)
		make_box(Vector3(0.34, 0.13, 0.008), Vector3(0, 0, 0.033), face_color)
	else:
		var face_disc := make_cyl(0.158, 0.158, 0.008,
				Vector3(0, 0, 0.031), face_color, 0.82)
		face_disc.rotation_degrees.x = 90
		for i in 12:
			var a := TAU * float(i) / 12.0
			var long_mark := i % 3 == 0
			var mark := make_box(Vector3(0.010 if long_mark else 0.006,
					0.028 if long_mark else 0.014, 0.006),
					Vector3(sin(a) * 0.126, cos(a) * 0.126, 0.041),
					accent if long_mark else Color(0.17, 0.16, 0.14))
			mark.rotation.z = -a
	_tell_mark = make_box(Vector3(0.026, 0.026, 0.009),
			Vector3(0, -0.112, 0.048), accent)
	_tell_mark.visible = false
	_display = Label3D.new()
	_display.text = frozen_time if style in ["digital", "flip", "writer", "motel"] else ""
	_display.font_size = 46
	_display.pixel_size = 0.0024
	_display.position = Vector3(0, -0.005, 0.043)
	_display.modulate = accent.lightened(0.18)
	_display.outline_size = 5
	_display.outline_modulate = Color(0, 0, 0, 0.85)
	_face.add_child(_display)


func _build_hands() -> void:
	if style in ["digital", "flip", "writer", "motel"]:
		return
	_hour = _hand("HourHand", 0.080, 0.012, 0.052)
	_minute = _hand("MinuteHand", 0.118, 0.008, 0.055)
	_second = _hand("SecondHand", 0.132, 0.004, 0.059, accent)
	_set_hand_time(frozen_time)


func _hand(title: String, length: float, width: float, depth: float,
		color := Color(0.08, 0.075, 0.07)) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = title
	_face.add_child(pivot)
	var blade := make_box(Vector3(width, length, 0.006),
			Vector3(0, length * 0.42, depth), color)
	remove_child(blade)
	pivot.add_child(blade)
	return pivot


func _set_hand_time(value: String) -> void:
	if _hour == null or "_" in value:
		return
	var parts := value.split(":")
	var h := float(parts[0].to_int() % 12)
	var m := float(parts[1].to_int())
	_hour.rotation.z = -TAU * (h + m / 60.0) / 12.0
	_minute.rotation.z = -TAU * m / 60.0
	_second.rotation.z = 0.0


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "WitnessBody"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.44, 0.34, 0.08)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _process(delta: float) -> void:
	_tick_accum += delta
	var target := 1.0 if not _possessed else 60.0 / maxf(48.0, Conductor.bpm)
	_tick_interval = lerpf(_tick_interval, target, minf(1.0, delta * 0.8))
	if _tick_accum >= _tick_interval:
		_tick_accum = fmod(_tick_accum, _tick_interval)
		if _tick and not _tick.playing:
			_tick.pitch_scale = 0.96 + rng.randf_range(-0.025, 0.025)
			_tick.play()
		if _second and not _possessed:
			_second.rotation.z -= TAU / 60.0


func stage_haunt(tier: int, player: Node3D) -> bool:
	if tier < 1 or _possessed:
		return false
	var watched := _is_watched(player)
	# While watched, only sound can be wrong. Visible mechanical movement is
	# reserved for the rare address rung; otherwise the player discovers it.
	if watched and tier < 4:
		_whisper_tick(tier)
		return true
	_possessed = true
	state = PState.INFECTED
	if _haunt_tween:
		_haunt_tween.kill()
	_haunt_tween = create_tween()
	_apply_tell(tier)
	_haunt_tween.tween_interval(9.0 + tier * 2.5)
	_haunt_tween.tween_callback(_restore)
	return true


func _apply_tell(tier: int) -> void:
	var turns := deg_to_rad(6.0 + tier * 4.0)
	match tell:
		"correction", "pending": _rewind_minutes(1 + tier * 2)
		"call_bell":
			if _minute:
				_minute.rotation.z += PI
			else:
				_flash_display("02:36")
		"label_time": _flash_display("YOU: NOW")
		"loose_second":
			if _second: _second.rotation.z = PI * 0.92
		"sample_skip": _rewind_minutes(4); _whisper_tick(tier + 2)
		"last_minute": _flash_display("05:42"); _rewind_minutes(1)
		"new_fault": _tell_mark.visible = true; rotation.z = turns * 0.25
		"listen_back": _rewind_minutes(3); _whisper_tick(tier + 3)
		"level": rotation.z = turns
		"untouched": _tell_mark.visible = true; _face.rotation.y = PI
		"checkout": _flash_display("11:00")
		"egress": rotation.z = -turns; _flash_display("NO EXIT")
		"broadcast": _flash_display("11:57"); _whisper_tick(tier + 4)
		"audience": _tell_mark.visible = true; _face.scale = Vector3(1.0 + tier * 0.025, 1.0, 1.0)
		"delay": _flash_display("-00:07")
		"unfinished": _flash_display("09:__")
		"two_histories": _flash_display("03:16 / 04:17"); rotation.z = turns * 0.35
		_: _rewind_minutes(tier)


func _rewind_minutes(amount: int) -> void:
	if _minute:
		_minute.rotation.z += TAU * float(amount) / 60.0
	if _hour:
		_hour.rotation.z += TAU * float(amount) / 720.0


func _flash_display(value: String) -> void:
	if _display:
		_display.text = value
	_tell_mark.visible = true


func _whisper_tick(tier: int) -> void:
	if _tick == null:
		return
	for i in mini(6, tier + 1):
		await get_tree().create_timer(0.11 + i * 0.035, false).timeout
		if is_instance_valid(_tick):
			_tick.pitch_scale = 0.78 + i * 0.035
			_tick.play()


func _restore() -> void:
	_possessed = false
	state = PState.OPERATING
	rotation.y = _home_rotation
	rotation.z = 0.0
	_face.rotation = Vector3.ZERO
	_face.scale = Vector3.ONE
	_tell_mark.visible = false
	_display.text = frozen_time if style in ["digital", "flip", "writer", "motel"] else ""
	_set_hand_time(frozen_time)


func _is_watched(player: Node3D) -> bool:
	if player == null:
		return false
	var candidate = player.get("camera")
	if not (candidate is Camera3D):
		return false
	var camera: Camera3D = candidate
	if not camera.is_position_in_frustum(global_position):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
			global_position)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(global_position) < 0.5


func _perform_synced_event(_index: int, accent_strength: float,
		_pitch: float) -> void:
	if _second:
		_second.rotation.z -= (TAU / 60.0) * clampf(accent_strength, 0.2, 1.0)
