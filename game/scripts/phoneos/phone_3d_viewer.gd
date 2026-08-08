extends Node3D
## Standalone viewer for the 3D handset: a dark room, two soft lights,
## and a slow turntable so the object reads as an object.
##
##   godot --path game res://scenes/phoneos/Phone3D.tscn
##
## Arrow keys drive the trackpad, Enter opens, Escape backs out - the
## same PhoneOS underneath, now behind glass.

var phone: Phone3D
var _yaw := 0.0
var _spin := true


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07060a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("2a2436")
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.22
	env.glow_hdr_threshold = 0.70
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	phone = Phone3D.new()
	add_child(phone)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.012, 0.20)
	cam.fov = 34.0
	cam.look_at_from_position(cam.position, Vector3(0, 0.005, 0),
			Vector3.UP)
	add_child(cam)

	# Key light high and to the left, so the chamfer and the keycaps
	# both catch an edge; fill from the right at a third the strength.
	var key := DirectionalLight3D.new()
	key.light_color = Color("cfd6e8")
	key.light_energy = 1.5
	key.rotation_degrees = Vector3(-38, 34, 0)
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("6a5f7a")
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-16, -58, 0)
	add_child(fill)
	set_process(true)


func _process(delta: float) -> void:
	if _spin and phone:
		_yaw += delta * 0.32
		phone.rotation = Vector3(
				deg_to_rad(-12.0 + sin(_yaw * 0.7) * 5.0),
				sin(_yaw) * 0.45, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or phone == null:
		return
	var k := event as InputEventKey
	match k.keycode:
		KEY_SPACE: _spin = not _spin
		KEY_LEFT: phone.key("left")
		KEY_RIGHT: phone.key("right")
		KEY_UP: phone.key("up")
		KEY_DOWN: phone.key("down")
		KEY_ENTER, KEY_KP_ENTER: phone.key("ok")
		KEY_ESCAPE: phone.key("back")
		KEY_BACKSPACE: phone.key("backspace")
		_:
			var ch := char(k.unicode)
			if ch.strip_edges() != "" or ch == " ":
				phone.key("type", ch)
