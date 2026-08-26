class_name PeriodRealityLayer
extends Node3D
## Cheap, historically specific life beyond the playable block.
##
## One aircraft mesh, two mono procedural WAVs, no collision, no shadows, no
## persistence and no gameplay signal. These details may corroborate place and
## year; they may never become evidence or objectives.

const AIR_PASS_MIN := 7.0 * 60.0
const AIR_PASS_MAX := 13.0 * 60.0
const TRAIN_MIN := 4.0 * 60.0
const TRAIN_MAX := 9.0 * 60.0
const AIR_DURATION := 18.0
const SAMPLE_RATE := 24000

var _aircraft: MeshInstance3D
var _air_audio: AudioStreamPlayer3D
var _train_audio: AudioStreamPlayer3D
var _air_elapsed := -1.0
var _until_aircraft := 0.0
var _until_train := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 19280501 # Pitcairn's New York-Atlanta CAM 19 opening date.
	_build_aircraft()
	_build_audio()
	_until_aircraft = _rng.randf_range(AIR_PASS_MIN, AIR_PASS_MAX)
	_until_train = _rng.randf_range(TRAIN_MIN, TRAIN_MAX)
	set_process(true)


func _process(delta: float) -> void:
	if _air_elapsed >= 0.0:
		_air_elapsed += delta
		_update_aircraft()
	else:
		_until_aircraft -= delta
		if _until_aircraft <= 0.0:
			start_airmail_pass()
	_until_train -= delta
	if _until_train <= 0.0:
		trigger_train_pass()


func start_airmail_pass() -> bool:
	if _air_elapsed >= 0.0:
		return false
	_air_elapsed = 0.0
	_aircraft.visible = true
	_air_audio.play()
	_update_aircraft()
	return true


func trigger_train_pass() -> bool:
	if _train_audio.playing:
		return false
	_train_audio.play()
	_until_train = _rng.randf_range(TRAIN_MIN, TRAIN_MAX)
	return true


func diagnostic_snapshot() -> Dictionary:
	return {
		"aircraft_visible": _aircraft != null and _aircraft.visible,
		"aircraft_draws": 1,
		"aircraft_collision_bodies": find_children(
				"*", "CollisionObject3D", true, false).size(),
		"aircraft_shadow": _aircraft.cast_shadow if _aircraft else -1,
		"audio_streams": 2,
		"persistent": false,
	}


func _update_aircraft() -> void:
	var t := clampf(_air_elapsed / AIR_DURATION, 0.0, 1.0)
	var start := Vector3(-92.0, 51.0, -76.0)
	var finish := Vector3(98.0, 58.0, 82.0)
	var direction := (finish - start).normalized()
	_aircraft.position = start.lerp(finish, t)
	_aircraft.position.y += sin(t * PI) * 5.0 + sin(t * TAU * 3.0) * 0.18
	_aircraft.look_at(_aircraft.position + direction, Vector3.UP)
	_air_audio.position = _aircraft.position
	if t >= 1.0:
		_air_elapsed = -1.0
		_aircraft.visible = false
		_air_audio.stop()
		_until_aircraft = _rng.randf_range(AIR_PASS_MIN, AIR_PASS_MAX)


func _build_aircraft() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Compressed-distance Pitcairn Mailwing read: fabric biplane, narrow body,
	# upper/lower planes, conventional tail and a dark radial nose.
	_box(surface, Vector3(0.0, 0.0, 0.0), Vector3(0.34, 0.30, 2.8),
			Color(0.28, 0.12, 0.055))
	_box(surface, Vector3(0.0, 0.42, -0.25), Vector3(4.5, 0.08, 0.72),
			Color(0.72, 0.58, 0.25))
	_box(surface, Vector3(0.0, -0.22, -0.18), Vector3(4.0, 0.07, 0.62),
			Color(0.62, 0.47, 0.18))
	_box(surface, Vector3(0.0, 0.16, 1.20), Vector3(1.55, 0.07, 0.45),
			Color(0.62, 0.47, 0.18))
	_box(surface, Vector3(0.0, 0.48, 1.28), Vector3(0.08, 0.68, 0.44),
			Color(0.52, 0.36, 0.13))
	_box(surface, Vector3(0.0, 0.0, -1.48), Vector3(0.44, 0.44, 0.22),
			Color(0.09, 0.075, 0.060))
	var mesh := surface.commit()
	_aircraft = MeshInstance3D.new()
	_aircraft.name = "CAM19Mailwing"
	_aircraft.mesh = mesh
	_aircraft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aircraft.visibility_range_end = 260.0
	_aircraft.visible = false
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	_aircraft.material_override = material
	add_child(_aircraft)


func _build_audio() -> void:
	_air_audio = AudioStreamPlayer3D.new()
	_air_audio.name = "DistantRadialEngine"
	_air_audio.stream = _synthesize_loop(2.0, true)
	_air_audio.volume_db = -18.0
	_air_audio.max_distance = 210.0
	_air_audio.unit_size = 32.0
	add_child(_air_audio)
	_train_audio = AudioStreamPlayer3D.new()
	_train_audio.name = "DistantFlushingLine"
	_train_audio.stream = _synthesize_loop(9.0, false)
	_train_audio.position = Vector3(-78.0, 7.0, -42.0)
	_train_audio.volume_db = -24.0
	_train_audio.max_distance = 190.0
	_train_audio.unit_size = 38.0
	add_child(_train_audio)


func _synthesize_loop(seconds: float, radial: bool) -> AudioStreamWAV:
	var count := int(seconds * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise_state := 1928
	for i in count:
		var time := float(i) / SAMPLE_RATE
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := float(noise_state % 65536) / 32768.0 - 1.0
		var sample: float
		if radial:
			# Nine-cylinder uneven exhaust plus a two-blade propeller beat.
			var rpm := 31.0 + sin(time * TAU * 0.23) * 0.7
			var firing := sin(time * TAU * rpm) * 0.42 \
					+ sin(time * TAU * rpm * 2.0) * 0.20 \
					+ sin(time * TAU * rpm * 4.5) * 0.08
			sample = tanh(firing * 1.8) * 0.42 + noise * 0.018
		else:
			# Lo-V traction whine, rail joints and a final pneumatic sigh.
			var speed := 18.0 + time * 1.7
			var motor := sin(time * TAU * speed) * 0.15 \
					+ sin(time * TAU * speed * 2.03) * 0.08
			var joint_phase := fposmod(time, 0.62)
			var joint := exp(-joint_phase * 45.0) * sin(joint_phase * 520.0) * 0.38
			var brake := noise * smoothstep(seconds - 2.2, seconds - 0.4, time) * 0.10
			sample = motor + joint + brake
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if radial:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream


func _box(surface: SurfaceTool, center: Vector3, size: Vector3,
		color: Color) -> void:
	var half := size * 0.5
	var p := [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z),
	]
	for face in [[0, 2, 1, 0, 3, 2], [4, 5, 6, 4, 6, 7],
			[0, 4, 7, 0, 7, 3], [1, 2, 6, 1, 6, 5],
			[3, 7, 6, 3, 6, 2], [0, 1, 5, 0, 5, 4]]:
		for index in face:
			surface.set_color(color)
			surface.add_vertex(p[index])
