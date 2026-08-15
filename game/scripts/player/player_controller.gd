class_name PlayerController
extends CharacterBody3D
## Five-foot first-person controller. The building remains true-scale: a
## 1.41 m eye line beneath standard doors, peepholes, counters and residents
## is the scale cue. V toggles debug noclip.

const STANDING_HEIGHT := 1.524  # exactly 5'0"
const STANDING_EYE := 1.41
const BODY_RADIUS := 0.33
const CROUCH_HEIGHT := 0.96
const CROUCH_EYE := 0.84

const WALK := 3.0
const RUN := 4.6
const CROUCH_SPEED := 1.4
const GRAVITY := 9.8
const MOUSE_SENS := 0.0023
## A road impact is an interruption, never a failure state. The vehicle carries
## the body for less than a second; StreetTraffic owns the four-second immunity.
const STAGGER_SECONDS := 0.72
const STAGGER_DECEL := 5.2
const STAGGER_INPUT_DAMP := 0.76
const STAGGER_ROLL := 0.085

var camera: Camera3D
var flashlight: SpotLight3D
var _prompt: Label
var _prompt_panel: PanelContainer
var telegram_hud: TelegramHud
var noclip := false
var crouched := false
## True while seated at the support desk: movement and look are frozen and
## the mouse belongs to the call interface.
var call_locked := false
## Test hook: when non-zero, drives movement instead of player input.
var autopilot := Vector3.ZERO
## Set while the on-screen touch HUD is driving. A phone has no pointer to
## capture, so anything gated on MOUSE_MODE_CAPTURED has to consult this
## instead or it simply never runs there.
var touch_input := false

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _hand: Node3D
var _light_mask: PhoneLightMask
var _cookie_mask: PhoneLightMask
var _mask_view: SubViewport
var _cookie: ImageTexture
var _bake_due := 0.0
## A projector cannot be a live ViewportTexture — Godot refuses it and
## says to pass an image — so the cookie is read back on a timer. That
## readback is a GPU stall, and this ships to Android, which is why it
## is small and slow. Everything the cookie carries moves slower than
## this anyway; the fast flicker rides on light_energy instead.
const BAKE_EVERY := 0.10
const COOKIE := 512
## Metres to whatever the beam is currently landing on, eased. Drives
## both the cookie's blur and the cone edge's softness — see
## _measure_throw. Starts mid-range so the first bake is not a jump.
var _throw := 3.5
## Set by building_root once the camera exists; any carried-light model can
## publish the same beam pose without the controller knowing its object class.
var carried_device: Node3D
## A seated interaction is the one world verb allowed through call_locked.
## Keeping the owner here means E can stand up even after the seat teleports the
## camera away from the collision volume that originally received the ray.
var seated_interaction: Node
var _sway_clock := 0.0
var _stagger_left := 0.0
var _stagger_velocity := Vector3.ZERO
var _stagger_roll := 0.0


## SleepPressureDirector asks the body owner whether replacing the waking
## world is physically safe. Engagement, traffic and elevator seams remain
## separate gates owned by their own systems.
func sleep_entry_body_is_stable() -> bool:
	return not noclip and is_on_floor() and absf(velocity.y) < 0.35 \
			and _stagger_left <= 0.0 and global_position.is_finite()


## Presentation only. The controller forwards onset pressure to the modeled
## service set; it does not decide whether or when sleep begins.
func set_sleep_onset_progress(value: float) -> void:
	if carried_device and carried_device.has_method("set_sleep_onset_progress"):
		carried_device.set_sleep_onset_progress(clampf(value, 0.0, 1.0))


func _ready() -> void:
	add_to_group("player_controller")
	_capsule = CapsuleShape3D.new()
	_capsule.radius = BODY_RADIUS
	_capsule.height = STANDING_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position = Vector3(0, STANDING_HEIGHT * 0.5, 0)
	add_child(_shape)
	camera = Camera3D.new()
	camera.position = Vector3(0, STANDING_EYE, 0)
	camera.fov = 72.0
	add_child(camera)
	# The service set carries an ordinary tungsten inspection lamp low in the
	# off hand. Warm, weak, wide, and it drags a beat behind the eye —
	# the hand pivot is a sibling of the camera and chases it in
	# _process, so a fast look sweeps the beam late like a carried thing.
	_hand = Node3D.new()
	_hand.name = "ServiceSetHand"
	add_child(_hand)
	flashlight = SpotLight3D.new()
	# Down from 1.15 (ruled 2026-08-08). The torch was outshining the
	# building: walk into a room with six lit pendants and the brightest
	# thing on the wall was still the thing in your hand. The other two
	# thirds of that ruling are LightRig.fixture_gain, which came up, and
	# the atmosphere mask's floor, which stopped crushing every fixture in
	# the frame to a twentieth of itself.
	flashlight.light_energy = 0.74
	flashlight.spot_range = 7.5
	flashlight.spot_angle = 38.0
	flashlight.spot_angle_attenuation = 1.9
	flashlight.spot_attenuation = 1.35
	flashlight.light_color = Color(1.0, 0.80, 0.56)
	flashlight.shadow_enabled = true
	# On from the first frame, but no longer welded on: L operates the guarded
	# physical lever and every input surface reaches set_lamp_enabled().
	flashlight.visible = true
	# The lamp lights the building, not the isolated object holding it.
	flashlight.light_cull_mask = 0xFFFFF & ~(1 << 1)
	_hand.add_child(flashlight)
	floor_snap_length = 0.4
	_build_hud()


func _build_hud() -> void:
	# The beam's screen mask sits under the HUD: gl_compatibility ignores
	# light_projector, so the torch pattern — hotspot, warm fringe and
	# floor spill — multiplies over the frame instead, which is
	# also how a hand-held beam reads on camera. Oversized so its edges
	# stay offscreen while the sway drifts it.
	var mask_layer := CanvasLayer.new()
	mask_layer.layer = 6
	add_child(mask_layer)
	# Three plates blended live instead of one still image. The mix
	# answers to sanity pressure, to whether the player is walking, and
	# to the building intruding - see phone_light_mask.gd.
	_light_mask = PhoneLightMask.new()
	_light_mask.setup(self)
	mask_layer.add_child(_light_mask)

	# THE BEAM'S PATTERN, ON THE LIGHT. A second copy of the same mask
	# renders into this SubViewport and is baked onto the spotlight as
	# its projector cookie, so the hotspot, the fringe and the crack
	# land on GEOMETRY — they wrap a doorframe and hold still on a wall
	# as you walk into it, instead of sliding over the world at range
	# the way a screen-space pattern must.
	#
	# gl_compatibility supports this. The comment claiming otherwise had
	# been true of an older Godot, was never re-checked, and very nearly
	# cost a renderer migration.
	#
	# Both copies read the same sanity and the same speed, so the
	# atmosphere layer and the beam cannot drift out of agreement.
	_mask_view = SubViewport.new()
	_mask_view.size = Vector2i(COOKIE, COOKIE)
	_mask_view.disable_3d = true
	_mask_view.transparent_bg = false
	_mask_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask_view)
	_cookie_mask = PhoneLightMask.new()
	_cookie_mask.setup(self, true)
	_mask_view.add_child(_cookie_mask)
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	var dot := ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.position = Vector2(638, 358)
	dot.color = Color(0.9, 0.92, 0.95, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "InteractionPromptSlip"
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_left = -190
	_prompt_panel.offset_top = -58
	_prompt_panel.offset_right = 190
	_prompt_panel.offset_bottom = -18
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_theme_stylebox_override("panel", TelegramStyle.ink_tag())
	layer.add_child(_prompt_panel)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TelegramStyle.apply(_prompt, 15, true, Color("ead9b4"))
	_prompt_panel.add_child(_prompt)
	telegram_hud = TelegramHud.new()
	telegram_hud.name = "TelegramHud"
	add_child(telegram_hud)


## What the crosshair is looking at, refreshed for the prompt line.
func _update_prompt() -> void:
	_prompt.text = ""
	_prompt_panel.visible = false
	if is_instance_valid(seated_interaction):
		if seated_interaction.has_method("interact_prompt"):
			_prompt.text = seated_interaction.interact_prompt()
			_prompt_panel.visible = _prompt.text != ""
		return
	if call_locked or (not touch_input
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	var from := camera.global_position
	var to := from + camera.global_transform.basis * Vector3(0, 0, -2.1)
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return
	if hit.collider is Area3D:
		if hit.collider.has_meta("call_level"):
			_prompt.text = "[E]  Call elevator"
			_prompt_panel.visible = true
			return
		if hit.collider.has_meta("cabin_panel"):
			_prompt.text = "[E]  Select next floor"
			_prompt_panel.visible = true
			return
	var node: Node = hit.collider
	while node:
		if node.has_method("interact_prompt"):
			_prompt.text = node.interact_prompt()
			_prompt_panel.visible = _prompt.text != ""
			return
		node = node.get_parent()


func _process(_delta: float) -> void:
	_update_prompt()
	_carry_service_light(_delta)
	# E is the universal physical verb. A seat is deliberately allowed through
	# call_locked; every other locked panel continues to own its input.
	if Input.is_action_just_pressed("interact") \
			and (not call_locked or is_instance_valid(seated_interaction)):
		use_primary_interaction()
	# These are physical switches in the hand, not modal UI. They remain usable
	# while seated or in a protected conversation.
	if Input.is_action_just_pressed("lamp_toggle"):
		toggle_lamp()
	if Input.is_action_just_pressed("radio_toggle") \
			and carried_device and carried_device.has_method("toggle_radio_power"):
		carried_device.toggle_radio_power()
	if call_locked:
		return
	# POLLED, not event-driven. An on-screen button presses an action
	# through Input.action_press(), which sets the action's state but never
	# manufactures an InputEvent — so anything handled in _unhandled_input
	# is unreachable from a touchscreen. Interact, the carried lamp and
	# crouch were all in that dead zone: the HUD button lit up and the
	# game ignored it. Polling is the one path both a key and a thumb
	# travel, exactly like movement already does.
	if Input.is_action_just_pressed("noclip"):
		noclip = not noclip
		collision_layer = 0 if noclip else 1
		collision_mask = 0 if noclip else 1
		if noclip:
			_clear_stagger()
	if Input.is_action_just_pressed("crouch"):
		_set_crouched(not crouched)


func _unhandled_input(event: InputEvent) -> void:
	if call_locked:
		return
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and not touch_input:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The service set chases the eye instead of being bolted to it. Every frame
## the hand pivot slerps toward the camera's aim from just below-right
## of it, so a fast turn drags the beam behind the view and lets it
## catch up — plus a low breathing sway (bigger while walking) that the
## screen mask mirrors at a few pixels' amplitude.
func _carry_service_light(delta: float) -> void:
	if _hand == null:
		return
	_sway_clock += delta * (2.6 if velocity.length() > 0.5 else 1.0)
	# THE BEAM LEAVES THE SERVICE SET'S LAMP. The carrier publishes its
	# pose in camera space every frame — its modeled lens position and
	# direction down the carried object's own -Z — so the light
	# goes wherever the hand has turned it, breathing and stride
	# included. It used to be a spotlight at a fixed offset pointing
	# level, with its own invented sway, beside a phone that was pitched
	# somewhere else entirely and had no lamp modelled on it at all.
	var hold: Transform3D
	if carried_device and carried_device.get("beam_valid"):
		hold = camera.transform * carried_device.beam_xform
		if _light_mask:
			_light_mask.set_aim(carried_device.beam_aim)
	else:
		# No carried model in the scene (test rigs, mostly). Keep the old
		# hand-held offset so the building is still lit.
		var sway := Vector3(
				sin(_sway_clock * 1.7) * 0.008,
				sin(_sway_clock * 3.1) * 0.006, 0.0)
		hold = camera.transform \
				* Transform3D(Basis(), Vector3(0.16, -0.19, -0.06) + sway)
	# Less lag than before: the carried object trails the eye on its own
	# hand-lag, and stacking a second one on the light doubled it.
	_bake_cookie(delta)
	var chase := minf(1.0, delta * (16.0 if flashlight.visible else 60.0))
	_hand.transform = Transform3D(
			_hand.transform.basis.slerp(hold.basis, chase),
			_hand.transform.origin.lerp(hold.origin, chase))
	# The beam's own drift lives in the mask shader now, where it can be
	# scaled by walking speed; nudging the Control here as well would
	# double it.


## Read the blended plate back off the GPU and hand it to the light.
func _bake_cookie(delta: float) -> void:
	# The dummy headless renderer can return a non-null ViewportTexture whose
	# internal RID is null; asking it for an Image prints an engine error before
	# the empty-image guard below can run. WalkTest does not render a carried beam.
	if _mask_view == null or DisplayServer.get_name() == "headless":
		return
	_bake_due -= delta
	if _bake_due > 0.0:
		return
	_bake_due = BAKE_EVERY
	_measure_throw()
	var vt := _mask_view.get_texture()
	if vt == null:
		return
	var img := vt.get_image()
	if img == null or img.is_empty():
		return          # headless, or the pass has not resolved yet
	if _cookie == null:
		_cookie = ImageTexture.create_from_image(img)
		flashlight.light_projector = _cookie
	else:
		_cookie.update(img)


## HOW FAR THE BEAM IS THROWING. One ray, down the light's own axis, at
## the bake rate rather than per frame — the beam's softness has no
## business being a 60 Hz quantity and this is a physics query.
##
## Nothing found means nothing to land on, which is the corridor case:
## the beam runs out at its own range and is at its softest, which is
## exactly right and falls out of the arithmetic for free.
func _measure_throw() -> void:
	if flashlight == null or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var origin := flashlight.global_position
	var reach := flashlight.spot_range
	var params := PhysicsRayQueryParameters3D.create(
			origin, origin - flashlight.global_transform.basis.z * reach)
	params.exclude = [get_rid()]
	var hit := space.intersect_ray(params)
	var found: float = reach if hit.is_empty() \
			else origin.distance_to(hit.position)
	# Eased, not assigned. Sweeping the beam off a near wall and down a
	# corridor is a real thing a player does constantly, and a blur that
	# tracked it exactly would pop on every doorway. A third per bake is
	# about a third of a second to settle — slow enough to read as the
	# eye adjusting, fast enough that it has finished by the time you
	# have finished turning.
	_throw = lerpf(_throw, found, 0.34)
	if _cookie_mask:
		_cookie_mask.set_throw(_throw, reach)
	# The CONE EDGE softens with the same argument as the pattern inside
	# it. A hard-edged circle on a far wall is the single clearest tell
	# that a beam is a projected texture rather than light, and the
	# penumbra of a real torch at seven metres is most of a metre wide.
	var soft: float = clampf((_throw - 1.10) / (reach - 1.10), 0.0, 1.0)
	flashlight.spot_angle_attenuation = lerpf(1.90, 1.15, soft)


## One look path for both a mouse and a dragged thumb, so the two can never
## drift into different sensitivities or clamp differently.
func apply_look(rel: Vector2) -> void:
	if call_locked:
		return
	rotate_y(-rel.x * MOUSE_SENS)
	camera.rotate_x(-rel.y * MOUSE_SENS)
	# The hand trails the view. One look path in, one hand lag out, so
	# a mouse and a dragged thumb can never disagree about it.
	if carried_device and carried_device.has_method("apply_look"):
		carried_device.apply_look(rel)
	camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


func _set_crouched(on: bool) -> void:
	crouched = on
	_capsule.height = CROUCH_HEIGHT if on else STANDING_HEIGHT
	_shape.position.y = _capsule.height / 2.0
	camera.position.y = CROUCH_EYE if on else STANDING_EYE


## The device-neutral light contract. Keyboard, controller and touch all
## change this owner; the spotlight, beam plates and physical lever follow.
func set_lamp_enabled(on: bool) -> void:
	flashlight.visible = on
	if _light_mask:
		_light_mask.visible = on
	if _mask_view:
		_mask_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS \
				if on else SubViewport.UPDATE_DISABLED
	if carried_device and carried_device.has_method("set_lamp_enabled"):
		carried_device.set_lamp_enabled(on)


func toggle_lamp() -> void:
	set_lamp_enabled(not flashlight.visible)


func lamp_is_enabled() -> bool:
	return flashlight != null and flashlight.visible


func begin_seated_interaction(owner: Node) -> void:
	seated_interaction = owner
	call_locked = true


func end_seated_interaction(owner: Node = null) -> void:
	if owner != null and seated_interaction != owner:
		return
	seated_interaction = null
	call_locked = false


func use_primary_interaction() -> void:
	if is_instance_valid(seated_interaction):
		if seated_interaction.has_method("interact"):
			seated_interaction.interact(self)
		return
	if not call_locked:
		_try_interact()


## Traffic supplies a world-space carry vector. Keep look and partial steering
## alive throughout: this is a wet-pavement stumble, not a stun or cutscene.
func stagger(push: Vector3) -> bool:
	if call_locked or noclip or _stagger_left > 0.0:
		return false
	var horizontal := Vector3(push.x, 0.0, push.z)
	if not horizontal.is_finite() or horizontal.length_squared() < 0.01:
		return false
	_stagger_velocity = horizontal.limit_length(4.2)
	_stagger_left = STAGGER_SECONDS
	var side := _stagger_velocity.dot(global_transform.basis.x)
	if absf(side) < 0.05:
		side = _stagger_velocity.x + _stagger_velocity.z
	_stagger_roll = -signf(side) * STAGGER_ROLL
	return true


func _clear_stagger() -> void:
	_stagger_left = 0.0
	_stagger_velocity = Vector3.ZERO
	_stagger_roll = 0.0


func _physics_process(delta: float) -> void:
	if call_locked:
		velocity = Vector3.ZERO
		_clear_stagger()
		camera.rotation.z = lerpf(camera.rotation.z, 0.0,
				minf(1.0, delta * 10.0))
		return
	var wish := autopilot
	if wish == Vector3.ZERO:
		var input := Input.get_vector("move_left", "move_right",
				"move_forward", "move_back")
		wish = (transform.basis * Vector3(input.x, 0, input.y))
	if noclip:
		_clear_stagger()
		var up := Input.get_action_strength("jump") \
				- Input.get_action_strength("crouch")
		global_position += (wish * 6.0 + Vector3.UP * up * 4.0) * delta
		return
	var gravity_direction := _reality_gravity()
	# A collapsing distortion volume can disappear on the same physics tick
	# that the safety net returns the player. Never hand CharacterBody3D a
	# zero or non-finite up vector while those two states cross.
	if not gravity_direction.is_finite() \
			or gravity_direction.length_squared() < 0.25:
		gravity_direction = Vector3.DOWN
	up_direction = -gravity_direction
	var stagger_weight := clampf(_stagger_left / STAGGER_SECONDS, 0.0, 1.0)
	camera.rotation.z = lerpf(camera.rotation.z,
			-gravity_direction.x * 0.42 + _stagger_roll * stagger_weight,
			minf(1.0, delta * (10.0 if _stagger_left > 0.0 else 4.5)))
	var speed := CROUCH_SPEED if crouched \
			else (RUN if Input.is_action_pressed("run") else WALK)
	var input_gain := 1.0 - stagger_weight * STAGGER_INPUT_DAMP
	velocity.x = wish.x * speed * input_gain + _stagger_velocity.x
	velocity.z = wish.z * speed * input_gain + _stagger_velocity.z
	if not is_on_floor():
		velocity += gravity_direction * GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity += -gravity_direction * 3.4
	else:
		var into_floor := velocity.dot(gravity_direction)
		if into_floor > 0.0:
			velocity -= gravity_direction * into_floor
	if gravity_direction.dot(Vector3.DOWN) > 0.98:
		_try_step_up(delta)
	move_and_slide()
	if _stagger_left > 0.0:
		_stagger_left = maxf(0.0, _stagger_left - delta)
		_stagger_velocity = _stagger_velocity.move_toward(
				Vector3.ZERO, STAGGER_DECEL * delta)
		if _stagger_left <= 0.0:
			_stagger_velocity = Vector3.ZERO
			_stagger_roll = 0.0


func _reality_gravity() -> Vector3:
	for controller in get_tree().get_nodes_in_group(
			"apartment_reality_controllers"):
		if controller.contains_point(global_position):
			return controller.gravity_at(global_position)
	return Vector3.DOWN


## Brief metric: 0.28 m max step height. If forward motion is blocked at
## foot level but clear 0.30 m up, lift the capsule; floor snap settles it
## onto the tread. This is what makes risers, thresholds and ramp lips
## walkable without jumping.
func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	var probe := motion.normalized() * maxf(motion.length(), 0.06)
	if not test_move(global_transform, probe):
		return  # path clear at ground level
	var lift := Vector3.UP * 0.30
	if test_move(global_transform, lift):
		return  # no headroom
	if test_move(global_transform.translated(lift), probe):
		return  # still blocked higher: a real wall
	global_position.y += 0.30


func _try_interact() -> void:
	var from := camera.global_position
	var to := from + camera.global_transform.basis * Vector3(0, 0, -2.1)
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return
	var node: Node = hit.collider
	while node:
		if hit.collider is Area3D and node.has_method("interact_area"):
			var area_result: Variant = node.call("interact_area", hit.collider)
			_present_interaction_telegram(node, area_result)
			return
		if node.has_method("interact"):
			var result: Variant = node.call("interact", self)
			_present_interaction_telegram(node, result)
			return
		node = node.get_parent()


## Presentation follows the authoritative interaction; it cannot make a prop
## respond, open a job or acquire an item. Protected/modal interactions suppress
## the slip so a field note can never cover dialogue or a call surface.
func _present_interaction_telegram(owner: Node, result: Variant) -> void:
	if telegram_hud == null or call_locked or not is_instance_valid(owner):
		return
	var card := TelegramHud.card_from_interaction(owner, result)
	if card.is_empty() or str(card.get("body", "")).strip_edges() == "":
		return
	if carried_device == null \
			or not carried_device.has_method("print_telegram_card"):
		return
	if not bool(carried_device.call("print_telegram_card",
			str(card.get("title", "FIELD COPY")))):
		return
	telegram_hud.present(card)
