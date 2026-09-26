class_name ServiceSetCarrier
extends Node3D
## First-person carrier for the no-screen Vantry service set.  The instrument
## renders in an isolated held-object pass, while its lamp publishes a camera-
## space transform to the real-world light owned by PlayerController.
## The owner now requests an eye-adjacent emitter for close inspection.

const CARRY_POS := Vector3(0.145, -0.055, -0.330)
const CARRY_ROT := Vector3(-3.0, -4.0, 2.0)
const EYE_LIGHT_ORIGIN := Vector3(0.018, -0.018, -0.035)
var reading := false
var reading_distance := .305
const READING_NEAR := .260
const READING_FAR := .390
var _read_blend := 0.0
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
var _service_round: Node


func setup(player: PlayerController, camera: Camera3D,
		work_orders: WorkOrders) -> void:
	_player = player
	camera.add_child(self)
	device = ServiceSetProp.new()
	device.name = "VantryServiceSet"
	device.bind_work_orders(work_orders)
	_build_overlay_pass(camera)
	player.set_physical_display_enabled(true)
	if player.telegram_hud != null:
		player.telegram_hud.card_presented.connect(func(_serial: int, card: Dictionary):
			print_telegram_card(card))
	set_process(true)


func set_lamp_enabled(on: bool) -> void:
	if device:
		device.set_lamp_enabled(on)

func set_lamp_optical_output(color: Color, emission: float) -> void:
	if device:
		device.set_lamp_optical_output(color,emission)


func lamp_is_enabled() -> bool:
	return device != null and device.lamp_enabled


func toggle_radio_power() -> void:
	if _service_round and _service_round.has_method("has_incoming_call") \
			and bool(_service_round.call("has_incoming_call")):
		if device and not device.radio_powered:
			device.set_radio_powered(true)
			return
		_service_round.call("answer_incoming_call")
		return
	if device:
		device.toggle_radio_power()


func bind_service_round(owner: Node) -> void:
	_service_round = owner
	if _service_round and _service_round.has_signal("incoming_call_changed"):
		_service_round.connect("incoming_call_changed", _on_incoming_call_changed)
	_on_incoming_call_changed(_service_round != null \
			and _service_round.has_method("has_incoming_call") \
			and bool(_service_round.call("has_incoming_call")))


func _on_incoming_call_changed(waiting: bool) -> void:
	if device:
		device.set_incoming_call(waiting)


func set_radio_powered(on: bool) -> void:
	if device:
		device.set_radio_powered(on)


func radio_is_powered() -> bool:
	return device != null and device.radio_powered


func print_telegram_card(message: Variant) -> bool:
	return device != null and device.print_telegram_card(message)


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
	environment.ambient_light_energy = 0.80
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
	key.light_energy = 0.35
	key.omni_range = 1.1
	key.shadow_enabled = false
	key.light_cull_mask = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	key.layers = key.light_cull_mask
	key.position = Vector3(-0.18, 0.22, -0.06)
	_pass_view.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("8191a0")
	rim.light_energy = 0.12
	rim.omni_range = 0.9
	rim.shadow_enabled = false
	rim.light_cull_mask = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	rim.layers = rim.light_cull_mask
	rim.position = Vector3(0.24, -0.12, -0.02)
	_pass_view.add_child(rim)
	var softbox := DirectionalLight3D.new()
	softbox.name = "InstrumentBroadReflection"
	softbox.light_color = Color("fff2db")
	softbox.light_energy = 0.55
	softbox.rotation_degrees = Vector3(-18,-22,0)
	softbox.light_cull_mask = 1 << (ServiceSetProp.DEVICE_LAYER - 1)
	softbox.layers = softbox.light_cull_mask
	softbox.shadow_enabled = false
	_pass_view.add_child(softbox)

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


func adjust_reading_distance(amount: float) -> void:
	reading_distance=clampf(reading_distance+amount,READING_NEAR,READING_FAR)
	device.teletype.set_focus_position(inverse_lerp(READING_FAR,READING_NEAR,reading_distance))

func _process(delta: float) -> void:
	if device == null:
		return
	device.teletype.set_action_hint(_player._prompt.text if is_instance_valid(_player) else "")
	device.teletype.set_controls(device.radio_powered,device.lamp_enabled,device.order_open or device.incoming_call)
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
	_read_blend=move_toward(_read_blend,1.0 if reading else 0.0,delta*3.0)
	pose=pose.lerp(Vector3(0,-.015,-reading_distance),smoothstep(0.0,1.0,_read_blend))
	var rotation := CARRY_ROT.lerp(Vector3.ZERO,_read_blend)
	var scale := Vector3.ONE
	if _proof_pose > 0:
		pose = Vector3(0, -0.01, -0.43)
		rotation = Vector3(0, 180.0 if _proof_pose == 1 else 0.0, 0)
		scale = Vector3.ONE * 1.05
	elif not reading:
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

	beam_xform = Transform3D(Basis.IDENTITY, EYE_LIGHT_ORIGIN)
	beam_valid = true
	beam_aim = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if _player == null or _player.call_locked or _player.mouse_released or get_tree().paused:
		return
	if not _player.camera.is_current(): return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if reading and event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			adjust_reading_distance(-.012 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .012)
			get_viewport().set_input_as_handled()
			return
	if reading and event.is_action_pressed("teletype_closer"):
		adjust_reading_distance(-.012)
		get_viewport().set_input_as_handled()
		return
	if reading and event.is_action_pressed("teletype_farther"):
		adjust_reading_distance(.012)
		get_viewport().set_input_as_handled()
		return
	if reading and event.is_action_pressed("teletype_service"):
		device.teletype.toggle_service_cover()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("teletype_read"):
		reading=not reading
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("teletype_next"):
		if event is InputEventKey and event.shift_pressed: device.teletype.browse_report(1)
		else: device.teletype.turn_page(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("teletype_previous"):
		if event is InputEventKey and event.shift_pressed: device.teletype.browse_report(-1)
		else: device.teletype.turn_page(-1)
		get_viewport().set_input_as_handled()
