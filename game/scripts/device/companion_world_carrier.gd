extends ServiceSetCarrier
## World presentation adapter. Existing ServiceSetProp remains the sole radio,
## lamp, print and WorkOrders owner. V2 always presents this autonomous bot.
const Motion := preload("res://scripts/device/companion_motion.gd")
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")
const PRESENTATION_SCALE := 0.42 # Native closed envelope becomes 83 × 153 mm.
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
var _lamp_target_frame := -1
var lamp_target_queries := 0
var _absence_owner: WeakRef
var _story_reflection := false
var _story_reflection_visible := false
var _story_motion_home := Transform3D.IDENTITY
var _story_rig_home := Transform3D.IDENTITY
var _world_story_owner:WeakRef
var _world_story_draws:Array[Dictionary]=[]
var _world_story_mask:=0
var _housing_shadow:MeshInstance3D
var _reflection_shadow_home:=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
var story_attitude:=Vector3.ZERO
var story_nudge:=Vector2.ZERO
var story_depth_scale:=1.0
var _story_pose_owner_id:=0

func story_pose_active() -> bool:return _story_pose_owner_id!=0

func set_story_face(owner:Node,expression:String) -> bool:
	if _player.text_input_owner!=owner or expression not in ["sympathetic","grinning","conspiratorial","thoughtful"]:return false
	_story_pose_owner_id=owner.get_instance_id()
	rig.reaction_player.cancel(false)
	rig.face_emotion=expression
	rig.display.set_expression(expression)
	return true

func set_story_pose(owner:Node,attitude:Vector3,nudge:Vector2,depth_scale:=1.0) -> bool:
	if _player.text_input_owner!=owner or not attitude.is_finite() or not nudge.is_finite() or not is_finite(depth_scale):return false
	_story_pose_owner_id=owner.get_instance_id()
	story_attitude=attitude.clamp(Vector3.ONE*-.12,Vector3.ONE*.12)
	story_nudge=nudge.clamp(Vector2.ONE*-.012,Vector2.ONE*.012)
	story_depth_scale=clampf(depth_scale,.96,1.04)
	return true

func release_story_pose(owner:Node) -> void:
	if is_instance_valid(owner) and _story_pose_owner_id==owner.get_instance_id():
		_story_pose_owner_id=0;story_attitude=Vector3.ZERO;story_nudge=Vector2.ZERO;story_depth_scale=1.0
		rig.face_emotion="";rig.display.set_expression("content")

func story_world_active() -> bool:
	return _world_story_owner!=null and is_instance_valid(_world_story_owner.get_ref())

func begin_story_world(owner:Node) -> bool:
	if not is_story_absent() or _absence_owner.get_ref()!=owner:return false
	if _world_story_owner!=null:return _world_story_owner.get_ref()==owner
	end_story_reflection(owner)
	_world_story_owner=weakref(owner)
	_world_story_mask=_player.camera.cull_mask&(1<<(ServiceSetProp.DEVICE_LAYER-1))
	_player.camera.cull_mask|=1<<(ServiceSetProp.DEVICE_LAYER-1)
	owner.tree_exiting.connect(_release_story_world.bind(owner.get_instance_id()),CONNECT_ONE_SHOT)
	for draw:GeometryInstance3D in rig.find_children("*","GeometryInstance3D",true,false):
		_world_story_draws.append({"ref":weakref(draw),"shadow":draw.cast_shadow})
		# Keep native render layers stable: this engine's light unpairing uses
		# the current layer mask and can retain stale pairs after a live swap.
		# Real room illumination and depth, including a real opaque housing shadow.
		# Labels and translucent glazing retain their original shadow policy.
		if draw is MeshInstance3D and str(draw.name)=="ShellStudy__ShellSteel":draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_visibility()
	return true

func end_story_world(owner:Node) -> void:
	if is_instance_valid(owner):_release_story_world(owner.get_instance_id())

func _release_story_world(owner_id:int) -> void:
	if _world_story_owner==null:return
	var owner:Node=_world_story_owner.get_ref()
	if owner!=null and owner.get_instance_id()!=owner_id:return
	if owner!=null and owner.tree_exiting.is_connected(_release_story_world.bind(owner_id)):
		owner.tree_exiting.disconnect(_release_story_world.bind(owner_id))
	for row:Dictionary in _world_story_draws:
		var draw:GeometryInstance3D=row.ref.get_ref()
		if draw!=null:draw.cast_shadow=row.shadow
	_world_story_draws.clear();_world_story_owner=null
	var mask:=1<<(ServiceSetProp.DEVICE_LAYER-1)
	_player.camera.cull_mask=(_player.camera.cull_mask&~mask)|_world_story_mask
	_apply_visibility()

func begin_story_reflection(owner:Node) -> bool:
	if not is_story_absent() or _absence_owner.get_ref()!=owner:return false
	if _story_reflection:return true
	_story_motion_home=motion.global_transform;_story_rig_home=rig.transform
	_reflection_shadow_home=_housing_shadow.cast_shadow
	_housing_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_story_reflection=true
	RenderingServer.frame_pre_draw.connect(_story_reflection_before_draw)
	return true

func pose_story_reflection(owner:Node,pose:Transform3D,visible_in_mirror:bool) -> bool:
	if not _story_reflection or not is_story_absent() or _absence_owner.get_ref()!=owner:return false
	motion.global_transform=pose
	rig.transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*PRESENTATION_SCALE),Vector3.ZERO)
	_story_reflection_visible=visible_in_mirror
	rig.visible=visible_in_mirror and not _capture_hidden
	# Reuse the instrument's existing device-only fill, without rendering its
	# foreground pass or illuminating/shadowing physical room surfaces.
	if is_instance_valid(screen_frame):screen_frame.view_camera.global_transform=_player.camera.global_transform
	return true

func end_story_reflection(owner:Node) -> void:
	if not _story_reflection or not is_story_absent() or _absence_owner.get_ref()!=owner:return
	_story_reflection=false;_story_reflection_visible=false
	_housing_shadow.cast_shadow=_reflection_shadow_home
	if RenderingServer.frame_pre_draw.is_connected(_story_reflection_before_draw):RenderingServer.frame_pre_draw.disconnect(_story_reflection_before_draw)
	motion.global_transform=_story_motion_home;rig.transform=_story_rig_home
	_apply_visibility()

func _story_reflection_before_draw() -> void:
	# Rendering continues through pause. Observer privacy must not depend on
	# the paused gameplay process or the director's current milestone.
	if not _story_reflection or not is_instance_valid(rig):return
	var visible_now:=_story_reflection_visible and not _capture_hidden and is_story_absent() and is_instance_valid(_player) and _player.camera.is_current()
	if rig.visible!=visible_now:rig.visible=visible_now

## Transient staging only: no radio, inventory, draft or lamp-save mutation.
## The owning scene releases this lease on exit, including interrupted previews.
func acquire_story_absence(owner: Node) -> bool:
	if not is_instance_valid(owner) or not owner.is_inside_tree() or not world_ready: return false
	if is_story_absent(): return _absence_owner.get_ref() == owner
	if session != null and session.retired: return false
	_absence_owner = weakref(owner)
	owner.tree_exiting.connect(_release_story_absence.bind(owner.get_instance_id()), CONNECT_ONE_SHOT)
	if session != null: session.close()
	_apply_visibility()
	_refresh_optical_output()
	return true

func release_story_absence(owner: Node) -> void:
	if is_instance_valid(owner): _release_story_absence(owner.get_instance_id())

func _release_story_absence(owner_id: int) -> void:
	if _absence_owner == null: return
	var owner: Node = _absence_owner.get_ref()
	if owner != null and owner.get_instance_id() != owner_id: return
	if owner != null and owner.tree_exiting.is_connected(_release_story_absence.bind(owner_id)):
		owner.tree_exiting.disconnect(_release_story_absence.bind(owner_id))
	if owner!=null:end_story_reflection(owner)
	_absence_owner = null
	_apply_visibility()
	_refresh_optical_output()

func is_story_absent() -> bool:
	return _absence_owner != null and is_instance_valid(_absence_owner.get_ref())

func is_capture_hidden() -> bool:
	return _capture_hidden or is_story_absent()

func _refresh_optical_output() -> void:
	if is_instance_valid(_player) and is_instance_valid(_player.lamp_presentation):
		_player.lamp_presentation.apply_output()

func setup(player: PlayerController, camera: Camera3D, work_orders: WorkOrders) -> void:
	_player = player
	player.get_parent().add_child(self)
	reading_distance = .22
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
	_housing_shadow=rig.model.find_child("ShellStudy__ShellSteel",true,false) as MeshInstance3D
	if _housing_shadow==null:failure="Native housing shadow source missing";push_error(failure);return
	# One opaque manufactured partition, not every label, key and glass layer.
	# It remains a real physical shadow after the narrative arrival finishes.
	_housing_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rig.scale = Vector3.ONE * PRESENTATION_SCALE
	rig.typing_arm=preload("res://scripts/device/companion_typing_arm.gd").new()
	rig.add_child(rig.typing_arm)
	if not rig.typing_arm.configure(rig,player,_arm_permitted):
		failure="Native typing arm refused";push_error(failure);return
	rig.temporal_register=preload("res://scripts/device/companion_temporal_register.gd").new()
	rig.add_child(rig.temporal_register)
	if not rig.temporal_register.configure(rig,self):
		failure="Native temporal register refused";push_error(failure);return
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
	return Vector2(.18, .32)

func arm_busy() -> bool:
	return rig!=null and rig.typing_arm!=null and rig.typing_arm.active()

func _arm_permitted() -> bool:
	return world_ready and reading and not is_capture_hidden() and device.radio_powered \
		and not device.incoming_call and not _player.protected_input_active() \
		and not _player.mouse_released and _sleep_onset<=.8 \
		and session!=null and not session.typing and not session.opening \
		and not session._foreign_editor_active() and not _player.inspecting() \
		and (_player.telegram_hud==null or not _player.telegram_hud._conversation_active)

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
	return world_ready and reading and not is_capture_hidden() and not _player.call_locked and not _player.mouse_released and (motion.stationary_for_hand or motion.steady_for_input())

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
	_apply_visibility()

func _apply_visibility() -> void:
	var hidden := is_capture_hidden()
	var world_story:=_world_story_owner!=null and is_instance_valid(_world_story_owner.get_ref())
	if rig != null: rig.visible = not hidden or ((world_story or (_story_reflection and _story_reflection_visible and is_story_absent())) and not _capture_hidden)
	# Hidden review stock must not leave invisible query-only obstructions.
	for entry: Dictionary in _pick_layers.values():
		var area: Area3D = entry.ref.get_ref()
		if area != null: area.collision_layer = 0 if hidden else int(entry.layer)

func world_lamp_transform() -> Transform3D:
	_update_lamp_target()
	# The original native optical aperture, not an offset at the player's eye.
	var lens: MeshInstance3D = device.teletype.torch_lens
	var aperture := lens.to_global(lens.mesh.get_aabb().get_center())
	var aim := lens.global_basis.orthonormalized()
	# Foreground flight keeps the paper square to the reader. Converge the
	# optical output on the authoritative viewed work without turning it away;
	# the original lamp owner and manufactured emitting aperture remain shared.
	if motion.light_target_valid and aperture.distance_squared_to(motion.light_target) > .0001:
		var direction := (motion.light_target - aperture).normalized()
		var up := _player.camera.global_basis.y
		if absf(direction.dot(up)) > .999: up = _player.camera.global_basis.x
		aim = Basis.looking_at(direction, up)
	return Transform3D(aim, aperture)

func _update_lamp_target() -> void:
	# Optical aiming has a different range from the hand's 2.1 m reach. One
	# body-only ray per physics tick follows the centre reticle, including while
	# a mechanism is held or the free inspection cursor is over the instrument.
	# Query-only control areas cannot become phantom surfaces for the beam.
	motion.light_target_valid = device.lamp_enabled
	if not device.lamp_enabled: return
	var frame := Engine.get_physics_frames()
	if frame == _lamp_target_frame: return
	_lamp_target_frame = frame
	var camera: Camera3D = _player.camera
	var centre := camera.get_viewport().get_visible_rect().size * .5
	var origin := camera.project_ray_origin(centre)
	var reach: float = _player.flashlight.spot_range
	var end := origin + camera.project_ray_normal(centre) * reach
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	lamp_target_queries += 1
	motion.light_target = end if hit.is_empty() else hit.position

func _advance_presentation(_delta: float) -> void:
	if not world_ready: return
	if _story_pose_owner_id!=0 and (not is_instance_valid(_player.text_input_owner) or _player.text_input_owner.get_instance_id()!=_story_pose_owner_id):
		_story_pose_owner_id=0;story_attitude=Vector3.ZERO;story_nudge=Vector2.ZERO;story_depth_scale=1.0
		rig.face_emotion="";rig.display.set_expression("content")
	device.teletype.set_reading_illumination(reading and device.radio_powered and not is_capture_hidden())
	if is_story_absent():
		rig.request_keyboard(false)
		return # No fabricated observations or autonomous replies before arrival.
	if witness != null: witness.observe(_delta)
	beam_valid = true
	if device.lamp_enabled != _lamp_face_state:
		_lamp_face_state = device.lamp_enabled
		if _lamp_face_state: rig.play_reaction("lamp_trim")
	if not device.incoming_call: _call_face_presented = false
	elif not _call_face_presented and rig.play_reaction("wireless_call"): _call_face_presented = true
	_update_lamp_target()
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
	elif _player.protected_input_active() or (is_instance_valid(_player.text_input_owner) and _player.text_input_owner!=rig.typing_arm) or device.incoming_call or session._foreign_editor_active() or (_player.inspecting() and _player.inspect_owner != self):
		rig.request_keyboard(false)
		motion.request_behavior(&"observe")
	elif reading:
		motion.request_behavior(&"type" if arm_busy() else &"present")
		# Reply reading is still computer use. The closed face covers the lower
		# copy window, so latch it only when the reader dismisses the apparatus.
		if not arm_busy():rig.request_keyboard(motion.steady_for_input())
	else:
		rig.request_keyboard(false)
		motion.request_behavior(&"accompany")
	screen_frame.present_reading = reading and not _player.protected_input_active() and not session._foreign_editor_active()

func _unhandled_input(event: InputEvent) -> void:
	if session != null and session.retired: return
	if is_capture_hidden(): return
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
