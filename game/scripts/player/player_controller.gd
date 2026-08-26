class_name PlayerController
extends CharacterBody3D

const PauseServicesScript := preload("res://scripts/ui/pause_services.gd")

## THE PLAYER CHANGED SOMETHING IN THE WORLD.
##
## Emitted from the single interaction chokepoint, so it covers every prop
## that answers `interact` -- a door opened, a switch thrown, a fault put
## right -- without each of them having to know anybody is listening. The
## Dream ecology uses it to decide the world is worth its whole attention
## (ecology architecture §13).
signal world_modified(where: Vector3, what: String)
## Authoritative physical contact, independent of whatever sound is played.
signal mechanical_stimulus(where: Vector3, carrier: StringName, strength: float,
		direction: Vector3, duration: float, substrate: StringName)
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
var pause_services: CanvasLayer
var noclip := false
var crouched := false
## True while seated at the support desk: movement and look are frozen and
## the mouse belongs to the call interface.
var call_locked := false
## Test hook: when non-zero, drives movement instead of player input.
var autopilot := Vector3.ZERO
var _stride_travel := 0.0
var _stride_last := Vector3.INF
## Set while the on-screen touch HUD is driving. A phone has no pointer to
## capture, so anything gated on MOUSE_MODE_CAPTURED has to consult this
## instead or it simply never runs there.
var touch_input := false

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _hand: Node3D
var _light_mask: PhoneLightMask
## Whether this WORLD permits the screen-space beam plate at all. The dream
## does not. Held separately from the lamp's own on/off because
## `set_lamp_enabled()` shows and hides the plate with the switch, and a world
## that has refused it must not have that refusal undone by the next toggle --
## which is exactly what was happening: the dream turned the plate off at
## build, and the first lamp toggle turned it straight back on.
var _beam_mask_allowed := true
var _cookie_mask: PhoneLightMask
var _mask_view: SubViewport
var _cookie: ImageTexture
var _bake_due := 0.0
var _cookie_bake_pending := false
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
## World-space point where the carried beam lands. See _measure_throw().
var beam_splash := Vector3.ZERO
## Set by building_root once the camera exists; any carried-light model can
## publish the same beam pose without the controller knowing its object class.
var carried_device: Node3D
## A seated interaction is the one world verb allowed through call_locked.
## Keeping the owner here means E can stand up even after the seat teleports the
## camera away from the collision volume that originally received the ray.
var seated_interaction: Node
var _sway_clock := 0.0
## The switch's position. The filament lags it; the rules never do.
var _lamp_on := true
var _lamp_phase := 0.0
var _lamp_phase_total := 0.0
var _lamp_last_transient := -99.0
var _lamp_base_energy := 0.74
var _lamp_gutter_enabled := false
var _lamp_gutter_clock_s := 0.0
var _lamp_gutter_phase_s := 0.0
var _lamp_gutter_deep_every := 4
var _lamp_gutter_deep_offset := 0
var _lamp_gutter_pin := -1.0
var _lamp_gutter_multiplier := 1.0
var _lamp_gutter_base_range := 8.5
var _lamp_gutter_base_angle_attenuation := 2.4
var _lamp_audio: AudioStreamPlayer
var _lamp_on_wav: AudioStreamWAV
var _lamp_off_wav: AudioStreamWAV

## How long the filament takes to come up, and to let go. The rise is the
## slower of the two by four to one, which is what makes the off read as a
## pop rather than as a fade.
const LAMP_WARM_S := 0.52
const LAMP_POP_S := 0.24
## The cold-filament inrush, as a fraction of settled output. Small on
## purpose: this is a bloom, not a flashbulb.
const LAMP_INRUSH := 0.26
## The dying flare, and how much of the pop it occupies.
const LAMP_POP_FLARE := 0.70
const LAMP_POP_FLARE_FRACTION := 0.34
## Below this gap between toggles the transient is skipped entirely. The
## switch is never gated — see set_lamp_enabled() for why the two are
## different currencies.
const LAMP_TRANSIENT_MIN_GAP := 0.55
## Cold tungsten is red before it is white, both on the way up and on the way
## out. The settled colour is the one the lamp was authored with.
const LAMP_COLD_COLOR := Color(1.0, 0.42, 0.16)
const LAMP_SETTLED_COLOR := Color(1.0, 0.80, 0.56)
const LAMP_GUTTER_CYCLE_S := 18.0
const LAMP_GUTTER_FLOOR := 0.58
const LAMP_GUTTER_MEAN := 0.79
const LAMP_GUTTER_MAX_SLOPE := 0.30

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
	_lamp_base_energy = flashlight.light_energy
	# Non-positional: this is a lever under the player's own thumb, not a
	# sound in the room. The Tenant hears nothing of it either way — pursuit
	# reads the lamp's STATE through lamp_is_enabled(), never its noise.
	_lamp_audio = AudioStreamPlayer.new()
	_lamp_audio.name = "LampSwitch"
	_lamp_audio.bus = "Interaction"
	add_child(_lamp_audio)
	_lamp_on_wav = _lamp_stream(true)
	_lamp_off_wav = _lamp_stream(false)
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
	# A cookie bake explicitly requests one draw and reads it only after the
	# renderer signals frame_post_draw. UPDATE_ALWAYS let the first gameplay
	# tick read this target before its first draw, preserving unrelated stale
	# GPU contents as a projector image.
	_mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
	pause_services = PauseServicesScript.new()
	pause_services.name = "PauseServices"
	add_child(pause_services)
	pause_services.call("bind_player", self)


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
	_advance_lamp(_delta)
	_carry_service_light(_delta)
	if not call_locked:
		var stick_look := Input.get_vector("look_left", "look_right",
				"look_up", "look_down", 0.0)
		if stick_look.length_squared() > 0.0:
			apply_look_rate(stick_look, _delta)
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
	if GameBoot.developer_overlays_enabled() \
			and Input.is_action_just_pressed("noclip"):
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
	elif event.is_action_pressed("pause_services"):
		if pause_services and pause_services.call("can_open"):
			pause_services.call("open")
			get_viewport().set_input_as_handled()
		else:
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
	if _mask_view == null or DisplayServer.get_name() == "headless" \
			or not _lamp_on or not _beam_mask_allowed:
		return
	_bake_due -= delta
	if _bake_due > 0.0 or _cookie_bake_pending:
		return
	_bake_due = BAKE_EVERY
	_measure_throw()
	_cookie_bake_pending = true
	_mask_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_finish_cookie_bake()


## The viewport request above belongs to this frame. Reading its texture is
## legal only after that frame has actually been submitted and drawn.
func _finish_cookie_bake() -> void:
	await RenderingServer.frame_post_draw
	_cookie_bake_pending = false
	if _mask_view == null or not is_instance_valid(_mask_view) \
			or not _lamp_on or not _beam_mask_allowed:
		return
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
	# WHERE THE BEAM ACTUALLY LANDS, in world space. The raycast above already
	# knew this and threw it away, keeping only the distance for the cookie
	# blur. The dream's molten gold needs the POINT: the melt is a circular
	# pool centred on the splash, not a sphere centred on the lamp, and those
	# are different the moment the beam is not pointing at your feet.
	#
	# Taken from the eased throw rather than the raw hit so the splash inherits
	# the same settling the blur has -- otherwise the pool snaps across a
	# doorway while the beam's own softness lags behind it.
	beam_splash = origin - flashlight.global_transform.basis.z * _throw
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
	var sensitivity := clampf(float(GameBoot.settings.get(
			"look_sensitivity", 1.0)), 0.25, 2.0)
	rotate_y(-rel.x * MOUSE_SENS * sensitivity)
	camera.rotate_x(-rel.y * MOUSE_SENS * sensitivity)
	# The hand trails the view. One look path in, one hand lag out, so
	# a mouse and a dragged thumb can never disagree about it.
	if carried_device and carried_device.has_method("apply_look"):
		carried_device.apply_look(rel)
	camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


## A held stick is a rate, never a mouse delta. Its radial dead zone and curve
## are applied before radians-per-second conversion; mouse feel remains exact.
func apply_look_rate(axis: Vector2, delta: float) -> void:
	if call_locked or delta <= 0.0:
		return
	var shaped := resolved_stick_axis(axis,
			float(GameBoot.settings.get("controller_look_deadzone", 0.18)),
			float(GameBoot.settings.get("controller_look_curve", 1.65)))
	if shaped == Vector2.ZERO:
		return
	var sensitivity := clampf(float(GameBoot.settings.get(
			"controller_look_sensitivity", 1.0)), 0.25, 2.0)
	var y_sign := -1.0 if bool(GameBoot.settings.get(
			"controller_invert_y", false)) else 1.0
	rotate_y(-shaped.x * 2.45 * sensitivity * delta)
	camera.rotate_x(-shaped.y * y_sign * 2.05 * sensitivity * delta)
	if carried_device and carried_device.has_method("apply_look"):
		carried_device.apply_look(Vector2(shaped.x, shaped.y * y_sign)
				* 720.0 * delta)
	camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


static func resolved_stick_axis(axis: Vector2, deadzone: float,
		curve: float) -> Vector2:
	var magnitude := minf(axis.length(), 1.0)
	var inner := clampf(deadzone, 0.0, 0.90)
	if magnitude <= inner or magnitude <= 0.00001:
		return Vector2.ZERO
	var normalized := (magnitude - inner) / (1.0 - inner)
	var response := pow(normalized, clampf(curve, 1.0, 3.0))
	return axis.normalized() * response


func _set_crouched(on: bool) -> void:
	crouched = on
	_capsule.height = CROUCH_HEIGHT if on else STANDING_HEIGHT
	_shape.position.y = _capsule.height / 2.0
	camera.position.y = CROUCH_EYE if on else STANDING_EYE


## The device-neutral light contract. Keyboard, controller and touch all
## change this owner; the spotlight, beam plates and physical lever follow.
## THE LOGICAL STATE FLIPS ON THIS LINE. Everything below it is picture and
## sound, and none of it may reach the rules.
##
## `lamp_is_enabled()` used to answer `flashlight.visible`, which was fine
## while the lamp was a boolean. It is not fine now that switching off has a
## tail: the Vantry trunk's condition is `lamp_on`, and `DreamPursuer`
## acquires through `lamp_finds_target()`, so a filament still visibly dying
## for 160 ms would have kept killing the player and feeding the Tenant for
## 160 ms after they turned it off. N3 measured that switching off buys 7.800
## seconds; a visual flourish is not allowed to spend any of them.
func set_lamp_enabled(on: bool) -> void:
	var changed := on != _lamp_on
	_lamp_on = on
	if _light_mask:
		_light_mask.visible = on and _beam_mask_allowed
	if _mask_view:
		_mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if on and _beam_mask_allowed:
			_bake_due = 0.0
	if not on and flashlight:
		flashlight.light_projector = null
	if carried_device and carried_device.has_method("set_lamp_enabled"):
		carried_device.set_lamp_enabled(on)
	if not changed:
		# A NO-OP MUST BE A NO-OP. This used to zero `_lamp_phase` and force
		# `visible`, so any caller re-asserting the state the lamp was already
		# in — and several do, on entry and on device sync — cancelled a
		# transient mid-flight. The pop was dying two frames in, which read as
		# the curve being wrong rather than as something else stepping on it.
		if _lamp_phase <= 0.0:
			flashlight.visible = on
		return
	# NO STROBE, AND NO COOLDOWN EITHER. The brief bans flashing outright and
	# separately guarantees that "repeated toggling has no stamina cost and no
	# arbitrary cooldown", so the two rules have to be honoured in different
	# currencies: the SWITCH always works instantly, and only the TRANSIENT is
	# rate-limited. Mash the key and the lamp still obeys every press; it just
	# stops blooming and popping, which is the part that could flicker.
	var now := float(Time.get_ticks_msec()) / 1000.0
	var quiet: bool = now - _lamp_last_transient < LAMP_TRANSIENT_MIN_GAP
	_lamp_last_transient = now
	if on:
		flashlight.visible = true
	if quiet:
		_lamp_phase = 0.0
		flashlight.visible = on
		if on:
			_apply_lamp_gutter()
		else:
			flashlight.light_energy = 0.0
		flashlight.light_color = LAMP_SETTLED_COLOR
		return
	_lamp_phase = LAMP_WARM_S if on else LAMP_POP_S
	_lamp_phase_total = _lamp_phase
	_play_lamp_sound(on)


## The tungsten cycle, and it is not a fade.
##
## A cold filament is a low resistance, so switching on draws an inrush and the
## lamp overshoots before it settles — the characteristic bloom. It comes up
## through the colour as well as the brightness: cold tungsten glows red, then
## amber, then reaches its working warm white, and the whole run takes about
## half a second in a small hand lamp.
##
## Switching off is the same physics backwards and faster, which is why it
## POPS. The filament flares for a few tens of milliseconds as the current
## collapses, then falls dark down the same colour ramp it came up.
func _advance_lamp(delta: float) -> void:
	if flashlight == null:
		return
	if _lamp_phase <= 0.0:
		if flashlight.visible != _lamp_on:
			flashlight.visible = _lamp_on
		if _lamp_on:
			_apply_lamp_gutter()
			flashlight.light_color = LAMP_SETTLED_COLOR
		return
	_lamp_phase = maxf(0.0, _lamp_phase - delta)
	var done: float = 1.0 - _lamp_phase / maxf(0.0001, _lamp_phase_total)
	if _lamp_on:
		# Rise fast, overshoot, settle. `ease` with a <1 curve front-loads the
		# climb the way an inrush does; the overshoot decays out of it.
		var climb: float = ease(done, 0.25)
		var overshoot: float = LAMP_INRUSH * sin(done * PI) * (1.0 - done)
		flashlight.light_energy = _lamp_base_energy * (climb + overshoot) \
				* _lamp_gutter_multiplier
		flashlight.light_color = LAMP_COLD_COLOR.lerp(
				LAMP_SETTLED_COLOR, ease(done, 0.55))
	else:
		# The flare, then the collapse. Both inside LAMP_POP_S.
		var flare: float = 1.0 - minf(1.0, done / LAMP_POP_FLARE_FRACTION)
		var fall: float = 1.0 - done
		flashlight.light_energy = _lamp_base_energy \
				* (fall * fall + LAMP_POP_FLARE * flare) \
				* _lamp_gutter_multiplier
		flashlight.light_color = LAMP_SETTLED_COLOR.lerp(
				LAMP_COLD_COLOR, ease(done, 0.7))
		if _lamp_phase <= 0.0:
			flashlight.visible = false


## Ground speed, read from the body AFTER move_and_slide rather than
## from the run action. The hollow runner breaks under a run and holds
## under a walk, and the input is the wrong source twice over: it is true
## while you are pinned against a wall at zero speed, and false while you
## are still carrying a sprint's momentum.
func planar_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func toggle_lamp() -> void:
	set_lamp_enabled(not _lamp_on)


## The switch's position, never the filament's. See set_lamp_enabled().
func lamp_is_enabled() -> bool:
	return _lamp_on


## A world may re-rate the carried lamp. The warm-up and pop settle back to
## whatever this says, so a re-ranged lamp does not snap to the waking value
## the moment its filament finishes coming up.
func set_lamp_base_energy(value: float) -> void:
	_lamp_base_energy = maxf(0.0, value)
	if flashlight and _lamp_phase <= 0.0 and _lamp_on:
		_apply_lamp_gutter()


## IR-V2 lives below the switch in the existing lamp presentation owner.
## Campaign seed chooses only phase/deep-dip cadence; the root's run clock is
## the time source. No per-frame random state and no save record exist here.
func configure_dream_lamp_gutter(seed_hex: String, run_clock_s: float = 0.0) -> void:
	var halves := DreamMazeBuilder.seed_halves(seed_hex)
	var folded := int(halves[0]) ^ int(halves[1])
	_lamp_gutter_phase_s = float(folded & 0xFFFF) / 65535.0 \
			* LAMP_GUTTER_CYCLE_S
	_lamp_gutter_deep_every = 3 + ((folded >> 16) & 0x3) % 3
	_lamp_gutter_deep_offset = ((folded >> 20) & 0x7) \
			% _lamp_gutter_deep_every
	_lamp_gutter_base_range = flashlight.spot_range if flashlight else 8.5
	_lamp_gutter_base_angle_attenuation = flashlight.spot_angle_attenuation \
			if flashlight else 2.4
	_lamp_gutter_enabled = true
	set_lamp_gutter_clock(run_clock_s)


func set_lamp_gutter_clock(run_clock_s: float) -> void:
	_lamp_gutter_clock_s = maxf(0.0, run_clock_s)
	_lamp_gutter_multiplier = _lamp_gutter_pin if _lamp_gutter_pin >= 0.0 \
			else lamp_gutter_multiplier_at(_lamp_gutter_clock_s)
	_apply_lamp_gutter()


## Diagnostic harness pin, callable only by explicit test/shot code. Negative
## releases it back to the seeded run clock; there is no environment switch.
func pin_lamp_gutter_for_proof(multiplier: float = 1.0) -> void:
	_lamp_gutter_pin = clampf(multiplier, LAMP_GUTTER_FLOOR, 1.0) \
			if multiplier >= 0.0 else -1.0
	set_lamp_gutter_clock(_lamp_gutter_clock_s)


func lamp_delivered_multiplier() -> float:
	return _lamp_gutter_multiplier if _lamp_gutter_enabled else 1.0


func lamp_gutter_multiplier_at(run_clock_s: float) -> float:
	if not _lamp_gutter_enabled:
		return 1.0
	var absolute := maxf(0.0, run_clock_s) + _lamp_gutter_phase_s
	var cycle := int(floor(absolute / LAMP_GUTTER_CYCLE_S))
	var local := fposmod(absolute, LAMP_GUTTER_CYCLE_S)
	# Eleven-second dying sag, then a seven-second smoother recovery. smoothstep
	# bounds the common slope far below the deep-dip ceiling.
	var sag := smoothstep(0.0, 11.0, local) if local <= 11.0 \
			else 1.0 - smoothstep(11.0, LAMP_GUTTER_CYCLE_S, local)
	sag = pow(maxf(0.0, sag), 0.90)
	var value := 1.0 - 0.40 * sag
	if cycle % _lamp_gutter_deep_every == _lamp_gutter_deep_offset:
		# The rare dip is centred late in the sag. 0.80 s down, 0.65 s up;
		# 0.13 depth keeps its combined analytic slope <= 0.30/s.
		var down := smoothstep(9.10, 9.90, local)
		var up := 1.0 - smoothstep(9.90, 10.55, local)
		value -= 0.13 * down * up
	return clampf(value, LAMP_GUTTER_FLOOR, 1.0)


func _apply_lamp_gutter() -> void:
	if flashlight == null:
		return
	if not _lamp_gutter_enabled:
		if _lamp_on and _lamp_phase <= 0.0:
			flashlight.light_energy = _lamp_base_energy
		return
	var normalized := inverse_lerp(LAMP_GUTTER_FLOOR, 1.0,
			_lamp_gutter_multiplier)
	flashlight.spot_range = _lamp_gutter_base_range \
			* lerpf(0.88, 1.0, normalized)
	flashlight.spot_angle_attenuation = lerpf(2.8,
			_lamp_gutter_base_angle_attenuation, normalized)
	if _lamp_on and _lamp_phase <= 0.0:
		flashlight.light_energy = _lamp_base_energy * _lamp_gutter_multiplier


## Put the carried beam's SCREEN-SPACE mask away entirely.
##
## `PhoneLightMask` multiplies a torch plate over the whole frame. In the
## waking Orison that is most of what makes the lamp feel carried, and it is
## correct there: the beam is a screen effect because the building is lit by
## its own fixtures and the torch is a lens on top of them.
##
## In the dream it is wrong twice. The Klimt shader already answers the beam ON
## THE SURFACE -- the gold melts, ripples and reflects where the light lands --
## so the screen plate is a second, contradictory account of the same lamp. And
## because it is an oversized screen-space rect, it lays a flat lit RECTANGLE
## across the frame that follows the camera rather than the geometry, washing
## the ornament out and reading as a rendering artifact. It is the thing that
## was ruining the shots.
##
## So a world can decline it. The 3D SpotLight3D is untouched and still does
## all the actual lighting; only the screen plate goes.
## THE LAMP AS A POSE, published every frame and coupled to nothing.
##
## `beam_splash` used to be computed inside `_bake_cookie()`, which returns
## early when headless AND when the mask viewport is gone -- and the dream
## deliberately turns the mask off. So the splash silently stayed at the world
## ORIGIN, the dream's melt centred itself on (0,0,0), and whichever boxes
## happened to sit near the origin lit up as rectangles while the ceiling, the
## floor and the falling jewels stayed dark. Three separate bug reports, one
## uninitialised vector.
##
## The pose is now published on its own, from the light's own transform, with
## no dependency on cookies, masks or viewports. Anything that wants to know
## where the lamp is pointing can ask.
func lamp_pose() -> Dictionary:
	if flashlight == null:
		return {}
	# THE SPLASH, RAYCAST HERE rather than inherited from the cookie bake. It
	# used to come from `_bake_cookie()`, which returns early when headless and
	# when the mask viewport is gone -- and the dream turns the mask off, so it
	# silently stayed at the world origin. It has no business depending on a
	# texture bake; it is a fact about where the lamp is pointing.
	var origin: Vector3 = flashlight.global_position
	var aim: Vector3 = -flashlight.global_transform.basis.z.normalized()
	var landing: Vector3 = origin + aim * flashlight.spot_range
	var space := get_world_3d().direct_space_state
	if space != null:
		# EXCLUDE THE BODY, and use the query that does. A first version built
		# an excluded query and then passed a different, unexcluded one -- so
		# the ray hit the player's own capsule at zero distance and the splash
		# sat at their feet, which is indistinguishable from "the lamp is
		# pointing at nothing" and rendered as a black frame.
		var q := PhysicsRayQueryParameters3D.create(origin, landing)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			landing = hit.position
	beam_splash = landing
	return {
		"splash": landing,
		"origin": flashlight.global_position,
		# Godot lights face -Z.
		"dir": -flashlight.global_transform.basis.z.normalized(),
		"range": flashlight.spot_range,
		"angle_deg": flashlight.spot_angle,
		"energy": flashlight.light_energy if _lamp_on
				or flashlight.visible else 0.0,
		"on": _lamp_on,
	}


func set_beam_mask_enabled(on: bool) -> void:
	_beam_mask_allowed = on
	# The whole CanvasLayer, not just the plate on it. Hiding the PhoneLightMask
	# alone left its layer drawing, which is why a band of it survived across
	# the top of every dream frame after the plate itself was switched off.
	if _light_mask:
		_light_mask.visible = on
		var layer := _light_mask.get_parent() as CanvasLayer
		if layer:
			layer.visible = on
	if _mask_view:
		_mask_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if on and _lamp_on:
			_bake_due = 0.0
	# The projector is the same plate baked onto the light. A world that has
	# refused the screen version does not want the 3D one either.
	if not on and flashlight:
		flashlight.light_projector = null


## Tell the beam's screen mask that this world lights itself.
##
## The mask dims everything outside the beam, and how far it may dim is set by
## how much light the LightRig reports. A world without a rig reports nothing
## and gets the darkest vignette there is, which is wrong for the dream: it
## lights itself, and crushing its ambient made switching the lamp ON darken
## the frame. Waking Orison never calls this.
func set_world_lift_floor(value: float) -> void:
	var lift: float = clampf(value, 0.0, 1.0)
	if _light_mask:
		_light_mask.floor_lift = lift
	if _cookie_mask:
		_cookie_mask.floor_lift = lift


## Two transients, built rather than shipped, because the project already
## synthesises its traffic and its songbook rather than carrying wavs for them
## (`street_traffic.gd`, `song_synth.gd`) and a lamp switch is a far smaller
## piece of sound than either.
##
## ON is two events that overlap: the physical switch — a hard, dry contact
## click, because this is a lever on a service set and not a soft button — and
## then the filament finding its note, a low hum that swells in over the same
## half second the light takes to warm.
##
## OFF is one event and it is meant to be startling: the contact breaks, the
## filament flares and lets go, and the body of the sound is a short low thud
## with the click on top of it. It is the loudest thing the lamp ever does, so
## it lands as a decision rather than as a UI beep.
func _lamp_stream(on: bool) -> AudioStreamWAV:
	var rate := 22050
	var seconds: float = 0.62 if on else 0.26
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	# Fixed: the lamp sounds like itself every time, and a test that renders
	# audio gets the same bytes on every machine.
	rng.seed = 0x1A3F if on else 0x2B7E
	for i in n:
		var t := float(i) / float(rate)
		var v := 0.0
		if on:
			# The contact: a few milliseconds of dry noise, gone almost at
			# once.
			v += (rng.randf() * 2.0 - 1.0) * exp(-t * 220.0) * 0.85
			# The filament: a low note swelling in and settling, with a
			# little mains texture on it.
			var swell: float = clampf(t / 0.34, 0.0, 1.0)
			v += sin(TAU * 104.0 * t) * swell * 0.16 * exp(-t * 1.1)
			v += sin(TAU * 156.0 * t) * swell * 0.07 * exp(-t * 1.6)
		else:
			# The pop: hard attack, low body, quick decay.
			v += (rng.randf() * 2.0 - 1.0) * exp(-t * 130.0) * 0.9
			v += sin(TAU * 88.0 * t) * exp(-t * 26.0) * 0.75
			v += sin(TAU * 143.0 * t) * exp(-t * 40.0) * 0.35
		var s := int(clampf(v * 11000.0, -32000.0, 32000.0))
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _play_lamp_sound(on: bool) -> void:
	if _lamp_audio == null:
		return
	_lamp_audio.stream = _lamp_on_wav if on else _lamp_off_wav
	# The pop is the loud one on purpose.
	_lamp_audio.volume_db = -9.0 if on else -3.0
	_lamp_audio.play()


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
		_stride_last = Vector3.INF
		_stride_travel = 0.0
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
		_stride_last = Vector3.INF
		_stride_travel = 0.0
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
	var roll_target := resolved_camera_roll(gravity_direction,
			_stagger_roll * stagger_weight)
	camera.rotation.z = lerpf(camera.rotation.z, roll_target,
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
	_publish_foot_contacts()
	if _stagger_left > 0.0:
		_stagger_left = maxf(0.0, _stagger_left - delta)
		_stagger_velocity = _stagger_velocity.move_toward(
				Vector3.ZERO, STAGGER_DECEL * delta)
		if _stagger_left <= 0.0:
			_stagger_velocity = Vector3.ZERO
			_stagger_roll = 0.0


func resolved_camera_roll(gravity_direction: Vector3,
		stagger_roll: float) -> float:
	if bool(GameBoot.settings.get("reduce_camera_roll", false)):
		return 0.0
	return -gravity_direction.x * 0.42 + stagger_roll


## A step is measured after collision resolution. Animation and footstep
## audio cannot manufacture one, and teleport/noclip reset the accumulator.
func _publish_foot_contacts() -> void:
	var here := global_position
	if _stride_last == Vector3.INF:
		_stride_last = here
		return
	var travelled := Vector3(here.x - _stride_last.x, 0.0,
			here.z - _stride_last.z)
	_stride_last = here
	if not is_on_floor() or travelled.length() > 0.35:
		_stride_travel = 0.0
		return
	_stride_travel += travelled.length()
	var stride := 0.54 if crouched else 0.66
	if _stride_travel < stride:
		return
	_stride_travel = fmod(_stride_travel, stride)
	var direction := travelled.normalized() \
			if travelled.length_squared() > 0.0001 else Vector3.ZERO
	var force := clampf(planar_speed() / RUN, 0.18, 1.0)
	mechanical_stimulus.emit(here, &"impulse", force, direction, 0.42, &"floor")


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
			world_modified.emit(node.global_position if node is Node3D
					else global_position, node.name)
			return
		if node.has_method("interact"):
			var result: Variant = node.call("interact", self)
			_present_interaction_telegram(node, result)
			world_modified.emit(node.global_position if node is Node3D
					else global_position, node.name)
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
