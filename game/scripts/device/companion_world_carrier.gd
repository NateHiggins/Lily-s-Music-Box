extends ServiceSetCarrier
## World presentation adapter. Existing ServiceSetProp remains the sole radio,
## lamp, print and WorkOrders owner. V2 always presents this autonomous bot.
const Motion := preload("res://scripts/device/companion_motion.gd")
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")
var motion: Motion
var rig: Mechanism
var world_ready := false
var failure := ""
var _inspection_hold := false
var _reading_previous := false
var _lamp_face_state := true
var _call_face_presented := false
var session: Node
var witness: Node
var _pick_layers := {}
var screen_frame: Node

func setup(player: PlayerController, camera: Camera3D, work_orders: WorkOrders) -> void:
	_player = player
	player.get_parent().add_child(self)
	reading_distance = .44
	motion = Motion.new()
	motion.name = "CompanionFlight"
	motion.screen_framed = true
	add_child(motion)
	rig = Mechanism.new()
	motion.add_child(rig)
	var asset_started := Time.get_ticks_usec()
	if not rig.build():
		failure = "Native companion presentation refused"
		push_error(failure)
		return
	setup_records.append({"stage":"asset_and_presentation_bind", "start_usec":asset_started, "end_usec":Time.get_ticks_usec()})
	device = rig.device
	var lens: MeshInstance3D = device.teletype.torch_lens
	motion.light_aperture = rig.to_local(lens.to_global(lens.mesh.get_aabb().get_center()))
	device.bind_work_orders(work_orders)
	# Render layer2 is composited for the player and retained for mirrors.
	# The original inspection lamp remains the sole gameplay beam owner.
	var hand_started := Time.get_ticks_usec()
	_hand = preload("res://scripts/device/service_set_hand.gd").new(self, true)
	for area: Area3D in find_children("*", "Area3D", true, false):
		area.collision_layer = 1 << 23
		_pick_layers[area.get_instance_id()] = {"ref":weakref(area), "layer":area.collision_layer}
	setup_records.append({"stage":"target_shapes", "start_usec":hand_started, "end_usec":Time.get_ticks_usec()})
	player.set_physical_display_enabled(true)
	if player.telegram_hud != null:
		player.telegram_hud.card_presented.connect(func(_serial: int, card: Dictionary): print_telegram_card(card))
	var placement_started := Time.get_ticks_usec()
	if not await motion.setup(player, camera, rig):
		failure = "No clear native companion starting position"
		push_error(failure)
		return
	setup_records.append({"stage":"flight_initialization", "start_usec":placement_started, "end_usec":Time.get_ticks_usec()})
	screen_frame = preload("res://scripts/device/companion_screen_frame.gd").new()
	add_child(screen_frame)
	screen_frame.setup(self, camera)
	_lamp_face_state = device.lamp_enabled
	motion.behavior_changed.connect(_on_companion_behavior)
	world_ready = true
	session = preload("res://scripts/device/companion_session.gd").new()
	add_child(session)
	session.setup(self, player)
	witness = preload("res://scripts/device/companion_witness.gd").new()
	add_child(witness)
	witness.setup(session, player, player.get_parent())
	beam_valid = true # Publish the native aperture before the first player update.
	set_process(true)

func reading_limits() -> Vector2:
	return Vector2(.44, .72)

func adjust_reading_distance(amount: float) -> void:
	super.adjust_reading_distance(amount)
	if motion != null: motion.reading_distance = reading_distance

func request_correspondence() -> void:
	if session == null or session.retired: return
	if session.typing or session.opening:
		session.close()
		return
	if not session.available(): return
	if reading: session.begin()
	else:
		reading = true
		motion.recall()

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
	if session != null and session.retired: hidden = true
	_capture_hidden = hidden
	if rig != null: rig.visible = not hidden
	# Hidden review stock must not leave invisible query-only obstructions.
	for entry: Dictionary in _pick_layers.values():
		var area: Area3D = entry.ref.get_ref()
		if area != null: area.collision_layer = 0 if hidden else int(entry.layer)

func world_lamp_transform() -> Transform3D:
	# The original native optical aperture, not an offset at the player's eye.
	var lens: MeshInstance3D = device.teletype.torch_lens
	var aperture := lens.to_global(lens.mesh.get_aabb().get_center())
	var aim := lens.global_basis.orthonormalized()
	# Foreground flight keeps the paper square to the reader. Converge the
	# optical output on the authoritative viewed work without turning it away;
	# the original lamp owner and manufactured emitting aperture remain shared.
	if screen_frame != null and motion.light_target_valid and aperture.distance_squared_to(motion.light_target) > .0001:
		aim = Basis.looking_at(motion.light_target - aperture, _player.camera.global_basis.y)
	return Transform3D(aim, aperture)

func _advance_presentation(_delta: float) -> void:
	if not world_ready: return
	device.teletype.set_reading_illumination(reading and device.radio_powered and not _capture_hidden)
	if witness != null: witness.observe(_delta)
	beam_valid = true
	if device.lamp_enabled != _lamp_face_state:
		_lamp_face_state = device.lamp_enabled
		if _lamp_face_state: rig.play_reaction("lamp_trim")
	if not device.incoming_call: _call_face_presented = false
	elif not _call_face_presented and rig.play_reaction("wireless_call"): _call_face_presented = true
	# Reuse the ordinary hand's last authoritative world hit. No second target
	# scan. Foreground framing faces the shell toward the reader; optical
	# output converges on the viewed work from the native lens aperture.
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
	if _sleep_onset > .8:
		motion.request_behavior(&"sleep")
	elif session != null and (session.typing or session.opening):
		motion.request_behavior(&"type")
	elif _player.call_locked or device.incoming_call or session._foreign_editor_active() or (_player.inspecting() and _player.inspect_owner != self):
		rig.request_keyboard(false)
		motion.request_behavior(&"observe")
	elif reading:
		motion.request_behavior(&"present")
		# Reply reading is still computer use. The closed face covers the lower
		# copy window, so latch it only when the reader dismisses the apparatus.
		rig.request_keyboard(motion.steady_for_input())
	else:
		rig.request_keyboard(false)
		motion.request_behavior(&"accompany")
	screen_frame.present_reading = reading and not _player.protected_input_active() and not session._foreign_editor_active()

func _unhandled_input(event: InputEvent) -> void:
	if session != null and session.retired: return
	if not world_ready or event.is_echo() or _player.call_locked or _player.mouse_released or get_tree().paused: return
	if not _player.camera.is_current(): return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _player.inspecting() and not _player.touch_input: return
	if reading and not _player.inspecting() and event.is_action_pressed("companion_type"):
		if session.begin(): get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("teletype_read"):
		if _player.inspecting() and _player.inspect_owner == self: _player.end_inspection()
		reading = not reading
		if reading:
			motion.recall()
			rig.play_reaction("vaudeville_wink")
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

func _on_companion_behavior(value: StringName) -> void:
	if value == &"sleep": rig.play_reaction("catnap")
	elif value == &"think": rig.play_reaction("clockwork_thought")
