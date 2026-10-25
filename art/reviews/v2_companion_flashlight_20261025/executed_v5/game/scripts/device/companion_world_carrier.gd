extends ServiceSetCarrier
## World presentation adapter. Existing ServiceSetProp remains the sole radio,
## lamp, print and WorkOrders owner. Explicit candidate opt-in until qualified.
const Motion := preload("res://scripts/device/companion_motion.gd")
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")
var motion: Motion
var rig: Mechanism
var world_ready := false
var failure := ""
var _inspection_hold := false
var _reading_previous := false

func setup(player: PlayerController, camera: Camera3D, work_orders: WorkOrders) -> void:
	_player = player
	player.get_parent().add_child(self)
	reading_distance = .48
	motion = Motion.new()
	motion.name = "CompanionFlight"
	add_child(motion)
	rig = Mechanism.new()
	motion.add_child(rig)
	if not rig.build():
		failure = "Native companion presentation refused"
		push_error(failure)
		return
	device = rig.device
	var lens: MeshInstance3D = device.teletype.torch_lens
	motion.light_aperture = rig.to_local(lens.to_global(lens.mesh.get_aabb().get_center()))
	device.bind_work_orders(work_orders)
	# Render layer2 remains visible to the main/planar cameras, excluded from
	# room reflection probes and this instrument's own real lamp. No new light.
	_hand = preload("res://scripts/device/service_set_hand.gd").new(self, true)
	player.set_physical_display_enabled(true)
	if player.telegram_hud != null:
		player.telegram_hud.card_presented.connect(func(_serial: int, card: Dictionary): print_telegram_card(card))
	if not await motion.setup(player, camera, rig):
		failure = "No clear native companion starting position"
		push_error(failure)
		return
	world_ready = true
	beam_valid = true # Publish the native aperture before the first player update.
	set_process(true)

func reading_limits() -> Vector2:
	return Vector2(.42, .72)

func adjust_reading_distance(amount: float) -> void:
	super.adjust_reading_distance(amount)
	if motion != null: motion.reading_distance = reading_distance

func hand_camera() -> Camera3D:
	return _player.camera if is_instance_valid(_player) else null

func hand_is_enabled() -> bool:
	return world_ready and reading and not _capture_hidden and not _player.call_locked and not _player.mouse_released and (motion.stationary_for_hand or motion.steady_for_input())

func hand_begin() -> bool:
	return hand_is_enabled() and motion.hold_for_hand(true)

func hand_end() -> void:
	if world_ready and not _inspection_hold: motion.hold_for_hand(false)

func can_inspect_controls() -> bool:
	return hand_is_enabled()

func inspection_started() -> void:
	_inspection_hold = motion.hold_for_hand(true)

func inspection_ended() -> void:
	_inspection_hold = false
	if world_ready: motion.hold_for_hand(false)

func apply_look(_relative: Vector2) -> void:
	pass # Flight observes real gaze and velocity; no camera-mounted sway.

func set_capture_hidden(hidden: bool) -> void:
	_capture_hidden = hidden
	if rig != null: rig.visible = not hidden

func world_lamp_transform() -> Transform3D:
	# The original native optical aperture, not an offset at the player's eye.
	var lens: MeshInstance3D = device.teletype.torch_lens
	return Transform3D(lens.global_basis.orthonormalized(), lens.to_global(lens.mesh.get_aabb().get_center()))

func _process(_delta: float) -> void:
	if not world_ready: return
	beam_valid = true
	# Reuse the ordinary hand's last authoritative world hit. No second target
	# scan. The whole lamp-bearing shell turns toward the viewed work; the
	# optical aperture and real light retain their manufactured relationship.
	motion.light_target_valid = device.lamp_enabled
	motion.light_target = _player.camera.global_position - _player.camera.global_basis.z * 7.5
	var hit: Dictionary = _player._grab.last_hit
	if not hit.is_empty() and is_instance_valid(hit.get("collider")) and not is_ancestor_of(hit.collider):
		motion.light_target = hit.position
	if reading != _reading_previous:
		_reading_previous = reading
		if reading: motion.recall()
		else: motion.release_attention()
	motion.reading_distance = reading_distance
	device.teletype.set_action_hint(_player._prompt.text)
	device.teletype.set_controls(device.radio_powered, device.lamp_enabled, device.order_open or device.incoming_call)
	# During a protected call/inspection of another owner, retire the keyboard
	# and take an unobtrusive observing pose. Never acquire somebody else's focus.
	if _player.call_locked or (_player.inspecting() and _player.inspect_owner != self):
		rig.request_keyboard(false)
		motion.request_behavior(&"observe")
	elif reading: motion.request_behavior(&"present")
	else: motion.request_behavior(&"accompany")

func _unhandled_input(event: InputEvent) -> void:
	if not world_ready or event.is_echo() or _player.call_locked or _player.mouse_released or get_tree().paused: return
	if not _player.camera.is_current(): return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _player.inspecting(): return
	if event.is_action_pressed("teletype_read"):
		if _player.inspecting() and _player.inspect_owner == self: _player.end_inspection()
		reading = not reading
		if reading: motion.recall()
		else: motion.release_attention()
	elif reading and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		adjust_reading_distance(-.012 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .012)
	elif reading and event.is_action_pressed("teletype_closer"): adjust_reading_distance(-.012)
	elif reading and event.is_action_pressed("teletype_farther"): adjust_reading_distance(.012)
	elif event.is_action_pressed("teletype_next"):
		if event is InputEventKey and event.shift_pressed: device.teletype.browse_report(1)
		else: device.teletype.turn_page(1)
	elif event.is_action_pressed("teletype_previous"):
		if event is InputEventKey and event.shift_pressed: device.teletype.browse_report(-1)
		else: device.teletype.turn_page(-1)
	else: return
	get_viewport().set_input_as_handled()
