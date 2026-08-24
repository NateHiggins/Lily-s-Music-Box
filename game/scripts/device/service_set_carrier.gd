class_name ServiceSetCarrier
extends Node3D
## First-person carrier for the no-screen Vantry service set.  The instrument
## renders in an isolated held-object pass, while its lamp publishes a camera-
## space transform to the real-world light owned by PlayerController.

const CARRY_POS := Vector3(0.190, -0.205, -0.410)
const CARRY_ROT := Vector3(-18.0, -12.0, 5.0)
const REF_ASPECT := 16.0 / 9.0

var device: ServiceSetProp
var beam_xform := Transform3D()
var beam_aim := Vector2.ZERO
var beam_valid := false

var _player: PlayerController
var _pass_view: SubViewport
var _pass_cam: Camera3D
var _pass_src: Camera3D
var _life := 0.0
var _bob := 0.0
var _sway := Vector2.ZERO
var _proof_pose := 0
var _sleep_onset := 0.0


func setup(player: PlayerController, camera: Camera3D,
		work_orders: WorkOrders) -> void:
	_player = player
	camera.add_child(self)
	device = ServiceSetProp.new()
	device.name = "VantryServiceSet"
	device.bind_work_orders(work_orders)
	_build_overlay_pass(camera)
	set_process(true)


func set_lamp_enabled(on: bool) -> void:
	if device:
		device.set_lamp_enabled(on)


func lamp_is_enabled() -> bool:
	return device != null and device.lamp_enabled


func toggle_radio_power() -> void:
	if device:
		device.toggle_radio_power()


func set_radio_powered(on: bool) -> void:
	if device:
		device.set_radio_powered(on)


func radio_is_powered() -> bool:
	return device != null and device.radio_powered


func print_telegram_card(title: String) -> bool:
	return device != null and device.print_telegram_card(title)


## Proof-only turntable poses. Production always leaves this at zero.
func set_proof_pose(side: int) -> void:
	_proof_pose = clampi(side, 0, 2)


func apply_look(relative: Vector2) -> void:
	var drag := lerpf(1.0, 1.55, _sleep_onset)
	_sway.x = clampf(_sway.x - relative.x * 0.018 * drag, -7.5, 7.5)
	_sway.y = clampf(_sway.y - relative.y * 0.014 * drag, -5.0, 5.0)


func set_sleep_onset_progress(value: float) -> void:
	_sleep_onset = clampf(value, 0.0, 1.0)


func _build_overlay_pass(camera: Camera3D) -> void:
	_pass_src = camera
	var size := get_viewport().get_visible_rect().size
	_pass_view = SubViewport.new()
	_pass_view.name = "ServiceSetPass"
	_pass_view.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	_pass_view.transparent_bg = true
	_pass_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pass_view.handle_input_locally = false
	_pass_view.world_3d = World3D.new()
	add_child(_pass_view)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("4a3528")
	# The 28-R's black lacquer and phenolic need enough broad reflection to
	# separate plates before the two photographic keys describe their edges.
	environment.ambient_light_energy = 3.20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_pass_view.add_child(world_environment)

	_pass_cam = Camera3D.new()
	_pass_cam.name = "ServiceSetCamera"
	_pass_cam.cull_mask = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	_pass_cam.current = true
	_pass_cam.near = 0.02
	_pass_cam.fov = camera.fov
	_pass_view.add_child(_pass_cam)
	_pass_view.add_child(device)

	var key := OmniLight3D.new()
	key.light_color = Color("ffd3a1")
	key.light_energy = 16.0
	key.omni_range = 1.1
	key.shadow_enabled = false
	key.light_cull_mask = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	key.position = Vector3(-0.18, 0.22, -0.06)
	_pass_view.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("8191a0")
	rim.light_energy = 8.0
	rim.omni_range = 0.9
	rim.shadow_enabled = false
	rim.light_cull_mask = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	rim.position = Vector3(0.24, -0.12, -0.02)
	_pass_view.add_child(rim)

	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var rect := TextureRect.new()
	rect.texture = _pass_view.get_texture()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_viewport().size_changed.connect(_resize_pass)


func _resize_pass() -> void:
	if _pass_view == null:
		return
	var size := get_viewport().get_visible_rect().size
	_pass_view.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))


func _aspect_shift() -> float:
	var size := get_viewport().get_visible_rect().size
	if size.y <= 0.0:
		return 1.0
	return (size.x / size.y) / REF_ASPECT


func _process(delta: float) -> void:
	if device == null:
		return
	_life += delta
	var speed := Vector3(_player.velocity.x, 0.0,
			_player.velocity.z).length() if _player else 0.0
	_bob += delta * (2.1 + speed * 2.2)
	# During gradual onset the weight in the player's hand answers late. The
	# lamp is still controllable and truthful; only its physical recovery drags.
	var sway_recovery := lerpf(5.0, 1.65, _sleep_onset)
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * sway_recovery))
	if _pass_cam and _pass_src:
		_pass_cam.fov = _pass_src.fov

	var pose := CARRY_POS
	pose.x *= _aspect_shift()
	var rotation := CARRY_ROT
	var scale := Vector3.ONE
	if _proof_pose > 0:
		pose = Vector3(0, -0.01, -0.43)
		rotation = Vector3(0, 180.0 if _proof_pose == 1 else 0.0, 0)
		scale = Vector3.ONE * 1.05
	else:
		var stride := 0.0018 + speed * 0.0023
		pose += Vector3(sin(_bob * 1.6) * stride,
				sin(_bob * 3.2) * stride * 0.75,
				sin(_life * 0.57) * 0.0008)
		rotation += Vector3(sin(_life * 0.83) * 0.34 + _sway.y,
				sin(_life * 0.61) * 0.42 + _sway.x,
				sin(_life * 0.47) * 0.44)
	device.position = pose
	device.rotation_degrees = rotation
	device.scale = scale

	var aim := Basis.from_euler(device.rotation)
	beam_xform = Transform3D(aim, device.position + aim * ServiceSetProp.LAMP_AT)
	beam_valid = true
	beam_aim = Vector2(rotation.y - CARRY_ROT.y, rotation.x - CARRY_ROT.x)
