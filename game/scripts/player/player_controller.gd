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
var _carried_light_pose := preload("res://scripts/lamp/carried_lamp_pose.gd").new()
var lamp_presentation: Node
var _prompt: Label
var _prompt_panel: PanelContainer
var _target_dot: Control
var inspect_owner: Node3D
var _inspection_active := false
var _inspection_jump_consumed := false
var _inspect_camera_fov := 72.0
var _inspect_camera_pose := Transform3D.IDENTITY
var _inspect_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _inspect_anchor := Transform3D.IDENTITY
var _profile_disable_step_guard:=false
var step_guard_rejections:=0
var profile_physics:=false
var physics_profile_records: Array=[]
var _low_step_probe_enabled:=false
var _step_cap: CharacterBody3D
var _step_cap_shape: SphereShape3D
var _step_cap_exceptions: Array=[]
var _native_contact_agent: RefCounted
var _native_contact_layers:=0
var _grab: RefCounted
var telegram_hud: TelegramHud
var _interaction_hud: CanvasLayer
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
## Set while the player has deliberately released the pointer with the
## release_mouse key. A click must not silently take it back: that is what
## made every free pointer last exactly until the next click.
var mouse_released := false
## Last physical input family seen by the HUD. World props still author the
## action in their own words; this controller owns the button legend that
## introduces those words. Touch remains authoritative while its HUD is live
## because Input.action_press() deliberately manufactures no InputEvent.
var _prompt_input_family: StringName = &"keyboard"

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _hand: Node3D
## Retired compatibility reference for historical diagnostics. Never mounted.
var _light_mask: Control = null
var _beam_mask_allowed := false # Historical diagnostics; the renderer is retired.
var _throw_due := 0.0
## Throw measurement cadence; no cookie is baked and no GPU image is read back.
const THROW_EVERY := 0.10
## Metres to whatever the beam is currently landing on, eased. Drives
## cone-edge softness and the gameplay splash. Starts mid-range so the first
## measurement is not a jump.
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
	# The real lamp and participating air own the beam. No photographic
	# screen plate, flare canvas or projected cookie is constructed.
	# The spotlight owns no projected texture. The former second mask rendered
	# into a SubViewport and copied the GPU target back into light_projector;
	# reused backing memory made a deleted Dream plate recur on waking walls.
	flashlight.light_projector = null
	var layer := CanvasLayer.new()
	layer.layer = 7
	_interaction_hud=layer
	add_child(layer)
	var dot := preload("res://scripts/player/target_reticle.gd").new()
	_target_dot = dot
	_grab = preload("res://scripts/player/constrained_grab.gd").new(self)
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

func set_physical_display_enabled(enabled: bool) -> void:
	if _interaction_hud: _interaction_hud.visible=not enabled
	if telegram_hud: telegram_hud.set_physical_output(enabled)


## Orient a reconstructed player toward an authored world-space return subject.
func face_world_point(target: Vector3) -> void:
	var direction := target - global_position
	if not target.is_finite() or Vector2(direction.x, direction.z).length_squared() < .0001:
		return
	global_rotation = Vector3(0, atan2(-direction.x, -direction.z), 0)
	camera.look_at(target)

## What the crosshair is looking at, refreshed for the prompt line.
func _update_prompt() -> void:
	_prompt.text = ""
	_prompt_panel.visible = false
	if _grab != null:
		_grab.validate()
		# A latched hand retains its part; hovering must not scan another object.
		var can_aim := not call_locked and not mouse_released and (inspecting() or touch_input or Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
		var aimed: Dictionary = {} if _grab.active() or not can_aim else _grab.find_target()
		var available: bool = not call_locked and not mouse_released and aimed.get("part") is Node3D
		var feedback: Dictionary = _grab.feedback(aimed)
		if call_locked or mouse_released or (not inspecting() and not touch_input and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED): feedback.state="hidden"
		_target_dot.present(feedback.state,feedback.inspectable,
			get_viewport().get_mouse_position() if inspecting() else get_viewport().get_visible_rect().size*.5)
		if _grab.active() or available or aimed.get("blocked",false): return
	if is_instance_valid(seated_interaction):
		if seated_interaction.has_method("interact_prompt"):
			_prompt.text = format_interaction_prompt(
					seated_interaction.interact_prompt(), _current_prompt_family())
			_prompt_panel.visible = _prompt.text != ""
		return
	if call_locked or (not touch_input
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	# The same ray supplies legacy semantic prompts. Do not rescan the world.
	var hit: Dictionary = _grab.last_hit if _grab != null else {}
	if hit.is_empty():
		return
	if hit.collider is Area3D:
		if hit.collider.has_meta("call_level"):
			_prompt.text = format_interaction_prompt(
					"Call elevator", _current_prompt_family())
			_prompt_panel.visible = true
			return
		if hit.collider.has_meta("cabin_panel"):
			_prompt.text = format_interaction_prompt(
					"Select next floor", _current_prompt_family())
			_prompt_panel.visible = true
			return
		if hit.collider.has_meta("cabin_floor"):
			_prompt.text = format_interaction_prompt(
					"Ride to " + str(hit.collider.get_meta("cabin_floor")), _current_prompt_family())
			_prompt_panel.visible = true
			return
		if hit.collider.has_meta("cabin_alarm"):
			_prompt.text = format_interaction_prompt("Ring elevator alarm", _current_prompt_family())
			_prompt_panel.visible = true
			return
	var node: Node = hit.collider
	while node:
		if node.has_method("interact_prompt"):
			_prompt.text = format_interaction_prompt(
					node.interact_prompt(), _current_prompt_family())
			if node.has_method("key_prompt"):
				var key_words := str(node.call("key_prompt"))
				if not key_words.is_empty():
					var carrier := "[K]" if _current_prompt_family()==&"keyboard" else "[D-PAD UP]" if _current_prompt_family()==&"controller" else "[KEY]"
					_prompt.text += "\n"+carrier+"  "+key_words
			_prompt_panel.visible = _prompt.text != ""
			return
		node = node.get_parent()


## Replace only a legacy carrier at the beginning of a prompt. The semantic
## action remains exactly what the prop authored, including punctuation and
## runtime substitutions. This also makes migration incremental: old `[E]`
## strings and new carrier-free strings render identically on keyboard.
static func format_interaction_prompt(raw_prompt: String,
		input_family: StringName) -> String:
	var action := raw_prompt.strip_edges()
	for legacy in ["[E]", "[CLICK]", "[A]", "[TAP]"]:
		if action.begins_with(legacy):
			action = action.substr(legacy.length()).strip_edges()
			break
	if action.is_empty():
		return ""
	var carrier := "[CLICK]"
	if input_family == &"controller":
		carrier = "[A]"
	elif input_family == &"touch":
		carrier = "[TAP]"
	return "%s  %s" % [carrier, action]


func _current_prompt_family() -> StringName:
	return &"touch" if touch_input else _prompt_input_family


func _process(_delta: float) -> void:
	if not Input.is_action_pressed("jump"): _inspection_jump_consumed=false
	if _inspection_active:
		if not is_instance_valid(inspect_owner) or not inspect_owner.is_inside_tree() or call_locked:
			end_inspection()
		else:
			camera.global_transform = _inspect_anchor
	_advance_lamp(_delta)
	_carry_service_light(_delta)
	if not call_locked and not inspecting():
		var stick_look := Input.get_vector("look_left", "look_right",
				"look_up", "look_down", 0.0)
		if stick_look.length_squared() > 0.0:
			if _grab != null and _grab.active(): _grab.move(stick_look*_delta*450.0)
			else: apply_look_rate(stick_look, _delta)
	# E is the universal physical verb. A seat is deliberately allowed through
	# call_locked; every other locked panel continues to own its input.
	if Input.is_action_just_pressed("door_key") and not call_locked:
		use_key_interaction()
	elif Input.is_action_just_pressed("interact") \
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
		_update_prompt()
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
		collision_mask = 0 if noclip else (1|_native_contact_layers)
		if noclip:
			_clear_stagger()
	if Input.is_action_just_pressed("crouch") and not inspecting():
		_set_crouched(not crouched)
	# Resolve after controller look, interaction and eye-height changes so the
	# drawn target describes the camera and hand actually rendered this frame.
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not event.is_echo():
		if inspecting():
			_inspection_jump_consumed=true
			end_inspection()
			get_viewport().set_input_as_handled()
			return
		if begin_inspection():
			_inspection_jump_consumed=true
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] \
			and _grab!=null and _grab.active() and _grab.target.kind=="free":
		_grab.move_depth((-.025 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .025)*event.factor)
		get_viewport().set_input_as_handled()
		return
	if inspecting():
		if event.is_action_pressed("pause_services") or event.is_action_pressed("release_mouse"):
			end_inspection()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			if _grab.active(): _grab.move(event.relative)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			use_primary_interaction()
			get_viewport().set_input_as_handled()
		return
	if call_locked:
		return
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _grab != null and _grab.active(): _grab.move(event.relative)
		else: apply_look(event.relative)
	elif event.is_action_pressed("release_mouse"):
		set_mouse_released(not mouse_released)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and not touch_input and not mouse_released:
		if event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			use_primary_interaction()
			get_viewport().set_input_as_handled()
			return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause_services"):
		if pause_services and pause_services.call("can_open"):
			pause_services.call("open")
			get_viewport().set_input_as_handled()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_prompt_input_family = &"touch"
	elif event is InputEventJoypadButton and event.pressed:
		_prompt_input_family = &"controller"
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.20:
		_prompt_input_family = &"controller"
	elif event is InputEventKey and event.pressed:
		_prompt_input_family = &"keyboard"
	elif event is InputEventMouseButton and event.pressed:
		_prompt_input_family = &"keyboard"


## The service set chases the eye instead of being bolted to it. Every frame
## the hand pivot slerps toward the camera's aim from just below-right
## of it, so a fast turn drags the beam behind the view and lets it
## catch up — plus a low breathing sway (bigger while walking) that the
## screen mask mirrors at a few pixels' amplitude.
func _carry_service_light(delta: float) -> void:
	if _hand == null:
		return
	_sway_clock += delta * (2.6 if velocity.length() > 0.5 else 1.0)
	# The carrier publishes a held-light origin. Close-work convergence and a
	# swept aperture keep this offset source out of nearby walls and fittings.
	# The same real light remains authoritative for shadows and voxel injection.
	var hold: Transform3D
	if carried_device and carried_device.get("beam_valid"):
		hold = camera.transform * carried_device.beam_xform
	else:
		# No carried model in the scene (test rigs, mostly). Keep the old
		# hand-held offset so the building is still lit.
		var sway := Vector3(
				sin(_sway_clock * 1.7) * 0.008,
				sin(_sway_clock * 3.1) * 0.006, 0.0)
		hold = camera.transform \
				* Transform3D(Basis(), _carried_light_pose.ORIGIN + sway)
	# Less lag than before: the carried object trails the eye on its own
	# hand-lag, and stacking a second one on the light doubled it.
	_update_throw(delta)
	var chase := minf(1.0, delta * (16.0 if flashlight.visible else 60.0))
	# Repeated interpolation can accumulate scale drift; slerp needs rotations.
	_hand.transform = Transform3D(
			_hand.transform.basis.orthonormalized().slerp(hold.basis.orthonormalized(), chase),
			hold.origin)
	_hand.global_transform = _carried_light_pose.resolve(self,_hand.global_transform)
	# The beam's own drift lives in the mask shader now, where it can be
	# scaled by walking speed; nudging the Control here as well would
	# double it.


## Measure throw without ever reading a rendered viewport into the light.
##
## The retired cookie path copied a SubViewport through get_image(). When that
## target had not drawn, Godot could return pixels from reused GPU backing
## memory. That is how a deleted Dream/Klimt plate kept reappearing on waking
## walls: it was no longer an asset reference, it was stale render-target data.
func _update_throw(delta: float) -> void:
	if not _lamp_on:
		return
	_throw_due -= delta
	if _throw_due > 0.0:
		return
	_throw_due = THROW_EVERY
	_measure_throw()
	# This assignment is deliberately unconditional. No toggle, world change or
	# old serialized state may restore a projector image to the service lamp.
	flashlight.light_projector = null


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
	# The CONE EDGE softens with the same argument as the pattern inside
	# it. A hard-edged circle on a far wall is the single clearest tell
	# that a beam is a projected texture rather than light, and the
	# penumbra of a real torch at seven metres is most of a metre wide.
	var soft: float = clampf((_throw - 1.10) / (reach - 1.10), 0.0, 1.0)
	flashlight.spot_angle_attenuation = lerpf(1.90, 1.15, soft)


## One look path for both a mouse and a dragged thumb, so the two can never
## drift into different sensitivities or clamp differently.
func apply_look(rel: Vector2) -> void:
	if inspecting(): return
	if _grab != null and _grab.active() and not _grab.holding_pickup():
		_grab.move(rel)
		return
	if call_locked:
		return
	var sensitivity := clampf(float(GameBoot.settings.get(
			"look_sensitivity", 1.0)), 0.25, 2.0)
	# Rebuild from yaw rather than repeatedly multiplying the float basis.
	# Long mouse turns must not gradually shrink the physical capsule frame.
	rotation.y -= rel.x * MOUSE_SENS * sensitivity
	camera.rotate_x(-rel.y * MOUSE_SENS * sensitivity)
	# The hand trails the view. One look path in, one hand lag out, so
	# a mouse and a dragged thumb can never disagree about it.
	if carried_device and carried_device.has_method("apply_look"):
		carried_device.apply_look(rel)
	camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


## A held stick is a rate, never a mouse delta. Its radial dead zone and curve
## are applied before radians-per-second conversion; mouse feel remains exact.
func apply_look_rate(axis: Vector2, delta: float) -> void:
	if inspecting(): return
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
	rotation.y -= shaped.x * 2.45 * sensitivity * delta
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
	if on:
		_throw_due = 0.0
	if flashlight:
		flashlight.light_projector = null
	if carried_device and carried_device.has_method("set_lamp_enabled"):
		carried_device.set_lamp_enabled(on)
	if is_instance_valid(lamp_presentation):
		lamp_presentation.set_powered(on)
		if changed: _play_lamp_sound(on)
		return
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
	if is_instance_valid(lamp_presentation):
		lamp_presentation.advance_frame(delta)
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
	if is_instance_valid(lamp_presentation):
		lamp_presentation.apply_output()
		return
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
	# Compatibility with world builders. The screen effect is retired globally;
	# this call cannot allocate or restore it, including when passed true.
	if on and _lamp_on:
		_throw_due = 0.0
	# No world may restore the retired projector path.
	if flashlight:
		flashlight.light_projector = null


## Compatibility with older worlds; surface and volumetric lighting own lift.
func set_world_lift_floor(_value: float) -> void: pass


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
	if _grab != null and _grab.active():
		_grab.release()
		return
	if is_instance_valid(seated_interaction):
		if seated_interaction.has_method("interact"):
			seated_interaction.interact(self)
		return
	if not call_locked:
		var target: Dictionary = _grab.find_target() if _grab != null else {}
		if not target.is_empty():
			_grab.acquire(target)
			return
		if not inspecting(): _try_interact()


func use_key_interaction() -> void:
	if call_locked or is_instance_valid(seated_interaction) or (not touch_input and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED): return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
			camera.global_position-camera.global_basis.z*2.1)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var owner: Node = hit.get("collider")
	while owner:
		if owner.has_method("interact_key"):
			var result: Variant = owner.call("interact_key",self)
			_present_interaction_telegram(owner,result)
			world_modified.emit(owner.global_position if owner is Node3D else global_position,owner.name)
			return
		if owner.has_method("interact"): return
		owner = owner.get_parent()


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
	if _native_contact_agent!=null:
		# CharacterBody's transform round trips also accumulate basis drift
		# during walking. Keep an intended unit rigid frame orthonormal. The
		# 1e-4 bound admits float roundoff; deliberate scale and tilt retain
		# their original values and the contact agent's fallback protection.
		var scale_error: Vector3=(basis.get_scale()-Vector3.ONE).abs()
		var largest_error:=maxf(scale_error.x,maxf(scale_error.y,scale_error.z))
		if largest_error>.000001 and largest_error<.0001:
			basis=basis.orthonormalized()
		_native_contact_agent.sync()
	if inspecting():
		velocity=Vector3.ZERO
		return
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
		var up := (0.0 if _inspection_jump_consumed else Input.get_action_strength("jump")) \
				- Input.get_action_strength("crouch")
		global_position += (wish * 6.0 + Vector3.UP * up * 4.0) * delta
		if _grab!=null: _grab.follow_holder()
		_stride_last = Vector3.INF
		_stride_travel = 0.0
		return
	var physics_started:=Time.get_ticks_usec() if profile_physics else 0
	var gravity_direction := _reality_gravity()
	var gravity_done:=Time.get_ticks_usec() if profile_physics else 0
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
	elif Input.is_action_just_pressed("jump") and not _inspection_jump_consumed:
		velocity += -gravity_direction * 3.4
	else:
		var into_floor := velocity.dot(gravity_direction)
		if into_floor > 0.0:
			velocity -= gravity_direction * into_floor
	var step_started:=Time.get_ticks_usec() if profile_physics else 0
	if gravity_direction.dot(Vector3.DOWN) > 0.98:
		_try_step_up(delta)
	var step_done:=Time.get_ticks_usec() if profile_physics else 0
	move_and_slide()
	var slide_done:=Time.get_ticks_usec() if profile_physics else 0
	if _grab!=null: _grab.follow_holder()
	_publish_foot_contacts()
	if profile_physics and Time.get_ticks_usec()-physics_started>1000:
		var contacts: Array=[]
		for index in get_slide_collision_count():
			var collider: Object=get_slide_collision(index).get_collider()
			if collider is Node:contacts.append(str(collider.get_path()))
		physics_profile_records.append({"step_guard_disabled":_profile_disable_step_guard,"position":[global_position.x,global_position.y,global_position.z],"gravity_ms":(gravity_done-physics_started)/1000.,"step_ms":(step_done-step_started)/1000.,"slide_ms":(slide_done-step_done)/1000.,"follow_and_contact_ms":(Time.get_ticks_usec()-slide_done)/1000.,"contacts":contacts})
		if physics_profile_records.size()>6000:physics_profile_records.pop_front()
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
func enable_low_step_probe() -> void:
	# V2 opts in after _ready. The lower hemisphere is exactly the capsule
	# surface throughout the legal300mm step band (current radius330mm).
	# Keep this query body physically inert between synchronous test calls.
	if _capsule==null:return
	if _step_cap==null:
		_step_cap=CharacterBody3D.new();_step_cap.name="StepCapQuery"
		_step_cap.top_level=true;_step_cap.collision_layer=0;_step_cap.collision_mask=0
		_step_cap_shape=SphereShape3D.new();_step_cap_shape.radius=_capsule.radius
		var shape:=CollisionShape3D.new();shape.shape=_step_cap_shape;_step_cap.add_child(shape)
		add_child(_step_cap);_step_cap.global_transform=Transform3D.IDENTITY
		_step_cap.add_collision_exception_with(self)
	_low_step_probe_enabled=true

func install_native_contact_agent(agent: RefCounted) -> bool:
	if agent==null or _native_contact_agent!=null:return false
	_native_contact_agent=agent;agent.sync();return true

func set_native_contact_layers(layers: int) -> void:
	_native_contact_layers=layers
	# Supplemental query layers never replace the world's physical layer.
	collision_mask=0 if noclip else (1|layers)

func clear_native_contact_agent() -> void:
	var previous: RefCounted=_native_contact_agent;_native_contact_agent=null
	if previous!=null:previous.release()

func _step_path_blocked(probe: Vector3) -> bool:
	if not _low_step_probe_enabled or _step_cap==null or _capsule.radius<.30 or _shape.basis!=Basis.IDENTITY:
		return test_move(global_transform,probe)
	if _step_cap_shape.radius!=_capsule.radius:_step_cap_shape.radius=_capsule.radius
	var exceptions: Array=get_collision_exceptions()
	if exceptions!=_step_cap_exceptions:
		for previous: Variant in _step_cap_exceptions:
			if is_instance_valid(previous) and previous!=self:_step_cap.remove_collision_exception_with(previous)
		for body: PhysicsBody3D in exceptions:
			if body!=_step_cap:_step_cap.add_collision_exception_with(body)
		_step_cap_exceptions=exceptions.duplicate()
	var centre: Vector3=_shape.position-Vector3.UP*(_capsule.height*.5-_capsule.radius)
	_step_cap.collision_mask=collision_mask
	var blocked:=_step_cap.test_move(global_transform*Transform3D(Basis.IDENTITY,centre),probe)
	_step_cap.collision_mask=0
	return blocked

func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	# The previous resolved contact is authoritative evidence of a solid above
	# our legal lift. Moving into that face cannot become a step; avoid three
	# costly full-capsule casts against detailed native stock. Sliding below
	# still resolves every actual obstruction and refreshes these contacts.
	if not _profile_disable_step_guard and _blocked_above_step(motion):
		if profile_physics:step_guard_rejections+=1
		return
	var probe := motion.normalized() * maxf(motion.length(), 0.06)
	if not _step_path_blocked(probe):
		return  # path clear at ground level
	var lift := Vector3.UP * 0.30
	if test_move(global_transform, lift):
		return  # no headroom
	if test_move(global_transform.translated(lift), probe):
		return  # still blocked higher: a real wall
	global_position.y += 0.30


func _blocked_above_step(motion: Vector3) -> bool:
	for index in get_slide_collision_count():
		var contact:=get_slide_collision(index)
		if contact.get_position().y>global_position.y+.30 and contact.get_normal().dot(motion)<-.00001:
			return true
	return false


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
	if not bool(carried_device.call("radio_is_powered")):
		return
	telegram_hud.present(card)


## Release the pointer during play, or take it back. While released the
## player keeps standing where they are: look follows the mouse only while
## it is captured, and a click no longer recaptures it.
func set_mouse_released(released: bool) -> void:
	if released and _grab != null: _grab.release()
	mouse_released = released
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if released \
			else Input.MOUSE_MODE_CAPTURED
	print("[PLAYER] pointer %s (backtick key)" % ["released" if released else "captured"])


func _exit_tree() -> void:
	if _grab != null: _grab.release()
	clear_native_contact_agent()


func cancel_manipulation() -> void:
	end_inspection(false)
	if _grab != null: _grab.release(false)


func inspecting() -> bool:
	return _inspection_active and is_instance_valid(inspect_owner)

func begin_inspection() -> bool:
	if call_locked or mouse_released or _grab == null or not _grab.active(): return false
	var owner: Node3D = _grab.target.owner
	if owner.has_method("inspection_owner_for"): owner=owner.inspection_owner_for(_grab.target.part)
	if not owner.has_method("inspection_view"): return false
	var view: Dictionary = owner.inspection_view_for(_grab.target.part) if owner.has_method("inspection_view_for") else owner.inspection_view()
	var from: Vector3 = view.from
	var at: Vector3 = view.at
	# Do not move the eye through a neighbouring wall into another room.
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,from)
	query.exclude=[get_rid()]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false): query.exclude.append(body.get_rid())
	if owner is CollisionObject3D: query.exclude.append(owner.get_rid())
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	_inspect_camera_pose=camera.transform
	_inspect_camera_fov=camera.fov
	camera.fov=clampf(float(view.get("fov",camera.fov)),40.0,100.0)
	_inspect_mouse_mode=Input.mouse_mode
	inspect_owner=owner
	_inspection_active=true
	_grab.release()
	camera.global_position=from
	camera.look_at(at)
	_inspect_anchor=camera.global_transform
	velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(get_viewport().get_visible_rect().size*.5)
	if owner.has_method("inspection_started"): owner.call("inspection_started")
	return true

func end_inspection(notify_change := true) -> void:
	if not _inspection_active: return
	var previous_owner:=inspect_owner
	if _grab != null: _grab.release(notify_change)
	inspect_owner=null
	_inspection_active=false
	camera.transform=_inspect_camera_pose
	camera.fov=_inspect_camera_fov
	Input.mouse_mode=_inspect_mouse_mode
	if is_instance_valid(previous_owner) and previous_owner.has_method("inspection_ended"): previous_owner.call("inspection_ended")
