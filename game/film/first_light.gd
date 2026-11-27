extends Node3D
## First Light. A single 45-second radio-shop insert, staged for the movie only.
## ORISON_FILM_FRAMES can shorten the complete take for a technical proof.
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")
const NativeLamp := preload("res://scripts/props/native_task_lamp.gd")
const Bench := preload("res://assets/props/radio_bench.glb")
const Rain := preload("res://assets/audio/freesound/processed/props/rain_on_metal.ogg")
const Contact := preload("res://assets/audio/freesound/processed/mechanical/metal_tick.ogg")
const Reply := preload("res://assets/audio/freesound/processed/mechanical/vantry_line_chirp.ogg")
const Rig := preload("res://film/cinema_camera_rig.gd")
const Render := preload("res://film/cinema_render_manager.gd")
const LENGTH_SECONDS := 45
const REST := Vector3(-0.32, 0.24, 0.12)

@onready var rig: Rig = $CinemaRig
@onready var capture: Render = $Render
var vantry := Mechanism.new()
var rain: AudioStreamPlayer3D
var contacts: AudioStreamPlayer3D
var reply: AudioStreamPlayer3D
var duration_frames: int
var marks: Dictionary
var shot: Dictionary
var output_size := Vector2i.ZERO

# MovieWriter reads project dimensions before scene _ready, after scene instantiation.
# The CLI separately sets the actual display size. Overrides last for this film process.
func _init() -> void:
	if Engine.get_write_movie_path().is_empty() or not OS.has_environment("ORISON_FILM_SIZE"):
		return
	var parts := OS.get_environment("ORISON_FILM_SIZE").split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return
	var size := Vector2i(int(parts[0]), int(parts[1]))
	if size not in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		return
	output_size = size
	for key in ["viewport_width", "window_width_override"]:
		ProjectSettings.set_setting("display/window/size/" + key, size.x)
	for key in ["viewport_height", "window_height_override"]:
		ProjectSettings.set_setting("display/window/size/" + key, size.y)

func _ready() -> void:
	if output_size != Vector2i.ZERO:
		var window := get_window()
		window.content_scale_size = output_size
		window.content_scale_factor = 1.0
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.scaling_3d_scale = 1.0
	var fps := int(OS.get_environment("ORISON_FILM_FPS")) if OS.has_environment("ORISON_FILM_FPS") else 24
	duration_frames = int(OS.get_environment("ORISON_FILM_FRAMES")) if OS.has_environment("ORISON_FILM_FRAMES") else fps * LENGTH_SECONDS
	if duration_frames < 12 or fps not in [24, 60] or duration_frames > LENGTH_SECONDS * fps:
		_fail("Choose 24 or 60 fps and between 12 frames and the full 45 seconds.")
		return
	if not _dress_bench():
		_fail("Radio bench fabrication records or materials could not be mounted.")
		return
	var practical := NativeLamp.new()
	practical.variant = "emeralite"
	practical.position = Vector3(-0.90, 0.0, -0.02)
	add_child(practical)
	$TransomSpill.look_at(Vector3(0.15, 0.21, -0.6), Vector3.UP)
	var slats := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var edge := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var slit := smoothstep(0.12, 0.46, sin((float(y) + 0.17 * x) * 0.32))
			var transmission := slit * (1.0 - smoothstep(0.65, 1.0, edge))
			slats.set_pixel(x, y, Color.WHITE * transmission)
	slats.generate_mipmaps()
	$TransomSpill.light_projector = ImageTexture.create_from_image(slats)
	practical.set_process(false)
	add_child(vantry)
	if not vantry.build():
		_fail("Vantry failed to bind his installed mechanism: " + str(vantry.failures))
		return
	vantry.device.set_radio_powered(true, false)
	vantry.propulsion = 0.48
	vantry.position = REST
	rain = _source(Rain, &"Weather", Vector3(-1.4, 0.8, -1.6), -20.0)
	contacts = _source(Contact, &"Machinery", Vector3(0.24, 0.15, 0.08), -5.0)
	reply = _source(Reply, &"Dialogue", REST, -5.0)
	var last := duration_frames - 1
	marks = {"tick": roundi(last * 0.23), "second_tick": roundi(last * 0.32),
		"third_tick": roundi(last * 0.64), "answer": roundi(last * 0.69)}
	# Lens and aim carry one visible decision: leave the meter and wait on the listener.
	shot = {"from_position": Vector3(0.56, 0.34, 1.18), "to_position": Vector3(-0.20, 0.32, 0.78),
		"look_at_position": Vector3(-0.15, 0.19, 0.02), "look_at_end_position": REST + Vector3(0, 0.02, 0),
		"first_frame": marks.tick, "travel_frames": roundi(last * 0.46), "dolly_control_from": Vector3(0.53, 0.34, 1.13),
		"dolly_control_to": Vector3(-0.13, 0.31, 0.80), "focus_start_frame": 0,
		"focus_frames": maxi(1, roundi(last * 0.22)), "focus_from_m": 1.15, "focus_to_m": 0.65,
		"focal_length_mm": 34.0, "aperture_f": 5.6, "handheld_m": 0.0}
	if not rig.begin_cinema($Observer):
		_fail("The observer did not own the initial view.")
		return
	capture.frame_requested.connect(_frame)
	capture.failed.connect(_fail)
	capture.finished.connect(_finished)
	var directory := OS.get_environment("ORISON_FILM_STEMS")
	var stems := PackedStringArray(["Weather", "Machinery", "Dialogue"]) if not directory.is_empty() else PackedStringArray()
	var movie := not Engine.get_write_movie_path().is_empty()
	capture.start_capture(duration_frames, fps, movie, [$OperatorOverlay], stems, directory)

func _dress_bench() -> bool:
	var bench := Bench.instantiate() as Node3D
	bench.position = Vector3(-20.14, -1.01, -56.13)
	add_child(bench)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/radio_bench.json"))
	for part: Dictionary in data.cells[0].parts:
		var draw := bench.find_child(str(part.name), true, false) as MeshInstance3D
		var key := str(part.get("catalog_key", part.key))
		if not draw or not MatLib.SETS.has(key): return false
		var surface := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		surface.uv1_triplanar = false
		surface.uv1_scale = Vector3.ONE / float(part.tile)
		draw.material_override = surface
	$Backing.material_override = MatLib.get_mat("plaster_stained", Color(0.38, 0.46, 0.41))
	return true

func _source(stream: AudioStream, bus: StringName, where: Vector3, level_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.area_mask = 0
	player.volume_db = level_db
	player.position = where
	add_child(player)
	return player

func _frame(index: int, fps: int) -> void:
	if $OperatorOverlay.visible:
		_fail("Operator overlay survived capture handoff.")
		return
	if index == 1 and output_size != Vector2i.ZERO:
		var actual := Vector2i(get_viewport().get_texture().get_size())
		if actual != output_size:
			_fail("Backbuffer %s differs from requested %s." % [actual, output_size])
			return
	if not rig.sample_shot(maxi(index, int(marks.tick)), fps, shot):
		_fail("Film camera lost its owner or received an invalid shot.")
		return
	var t := float(index) / (duration_frames - 1)
	var listen := smoothstep(0.20, 0.37, t) * (1.0 - smoothstep(0.58, 0.73, t))
	var answer := smoothstep(0.62, 0.68, t) * (1.0 - smoothstep(0.73, 0.85, t))
	var seconds := float(index) / fps
	vantry.position = REST + Vector3(0.084 * listen, 0.009 * sin(seconds * 1.44) + 0.014 * answer, 0.012 * answer)
	vantry.rotation = Vector3(-0.04 - 0.10 * answer, 0.11 + 0.63 * listen, -0.13 * listen)
	reply.position = vantry.position
	if index == 0: rain.play()
	if index == marks.tick or index == marks.second_tick or index == marks.third_tick: contacts.play()
	if index == marks.answer: reply.play()
	if t > 0.91 and rain.playing:
		rain.volume_db = lerpf(-20.0, -60.0, smoothstep(0.91, 1.0, t))

func _finished(frames: int) -> void:
	print("FIRST LIGHT: PASS frames=%d hud_hidden_during_take=true" % frames)
	rig.end_cinema()

func _fail(reason: String) -> void:
	push_error("FIRST LIGHT: " + reason)
	get_tree().quit(1)
