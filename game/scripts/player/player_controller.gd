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

var camera: Camera3D
var flashlight: SpotLight3D
var _prompt: Label
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
var _light_mask: TextureRect
## Set by building_root once the camera exists; the handset rides it.
var phone_carrier: Node3D
var _sway_clock := 0.0


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
	# The torch is a phone: a blue LED under phosphor, held low in the
	# off hand. Weak, cool, wide, and it drags a beat behind the eye —
	# the hand pivot is a sibling of the camera and chases it in
	# _process, so a fast look sweeps the beam late like a carried thing.
	_hand = Node3D.new()
	_hand.name = "PhoneHand"
	add_child(_hand)
	flashlight = SpotLight3D.new()
	flashlight.light_energy = 1.15
	flashlight.spot_range = 7.5
	flashlight.spot_angle = 38.0
	flashlight.spot_angle_attenuation = 1.9
	flashlight.spot_attenuation = 1.35
	flashlight.light_color = Color(0.78, 0.87, 1.0)
	flashlight.shadow_enabled = true
	# On from the first frame (ruled 2026-08-04): the phone rides lit in
	# the off hand all shift. F still toggles it for the brave.
	flashlight.visible = true
	_hand.add_child(flashlight)
	floor_snap_length = 0.4
	_build_hud()


func _build_hud() -> void:
	# The beam's screen mask sits under the HUD: gl_compatibility ignores
	# light_projector, so the torch pattern — hotspot, phosphor-blue
	# fringe, floor spill — multiplies over the frame instead, which is
	# also how a hand-held beam reads on camera. Oversized so its edges
	# stay offscreen while the sway drifts it.
	var mask_layer := CanvasLayer.new()
	mask_layer.layer = 6
	add_child(mask_layer)
	_light_mask = TextureRect.new()
	_light_mask.texture = load("res://assets/ui/phone_light_mask.png")
	_light_mask.stretch_mode = TextureRect.STRETCH_SCALE
	_light_mask.anchor_right = 1.0
	_light_mask.anchor_bottom = 1.0
	_light_mask.offset_left = -48
	_light_mask.offset_top = -48
	_light_mask.offset_right = 48
	_light_mask.offset_bottom = 48
	_light_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_light_mask.material = blend
	_light_mask.visible = true  # torch starts on; the mask rides with it
	mask_layer.add_child(_light_mask)
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	var dot := ColorRect.new()
	dot.size = Vector2(4, 4)
	dot.position = Vector2(638, 358)
	dot.color = Color(0.9, 0.92, 0.95, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)
	_prompt = Label.new()
	_prompt.position = Vector2(560, 384)
	_prompt.add_theme_font_size_override("font_size", 14)
	_prompt.modulate = Color(0.85, 0.9, 0.92)
	layer.add_child(_prompt)


## What the crosshair is looking at, refreshed for the prompt line.
func _update_prompt() -> void:
	_prompt.text = ""
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
			return
		if hit.collider.has_meta("cabin_panel"):
			_prompt.text = "[E]  Select next floor"
			return
	var node: Node = hit.collider
	while node:
		if node.has_method("interact_prompt"):
			_prompt.text = node.interact_prompt()
			return
		node = node.get_parent()


func _process(_delta: float) -> void:
	_update_prompt()
	_carry_phone_light(_delta)
	if call_locked:
		return
	# POLLED, not event-driven. An on-screen button presses an action
	# through Input.action_press(), which sets the action's state but never
	# manufactures an InputEvent — so anything handled in _unhandled_input
	# is unreachable from a touchscreen. Interact, the flashlight and
	# crouch were all in that dead zone: the HUD button lit up and the
	# game ignored it. Polling is the one path both a key and a thumb
	# travel, exactly like movement already does.
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("noclip"):
		noclip = not noclip
		collision_layer = 0 if noclip else 1
		collision_mask = 0 if noclip else 1
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


## The phone chases the eye instead of being bolted to it. Every frame
## the hand pivot slerps toward the camera's aim from just below-right
## of it, so a fast turn drags the beam behind the view and lets it
## catch up — plus a low breathing sway (bigger while walking) that the
## screen mask mirrors at a few pixels' amplitude.
func _carry_phone_light(delta: float) -> void:
	if _hand == null:
		return
	_sway_clock += delta * (2.6 if velocity.length() > 0.5 else 1.0)
	var sway := Vector3(
			sin(_sway_clock * 1.7) * 0.008,
			sin(_sway_clock * 3.1) * 0.006, 0.0)
	var hold := camera.transform \
			* Transform3D(Basis(), Vector3(0.16, -0.19, -0.06) + sway)
	var chase := minf(1.0, delta * (9.0 if flashlight.visible else 60.0))
	_hand.transform = Transform3D(
			_hand.transform.basis.slerp(hold.basis, chase),
			_hand.transform.origin.lerp(hold.origin, chase))
	if _light_mask != null and _light_mask.visible:
		_light_mask.position = Vector2(-48, -48) + Vector2(
				sin(_sway_clock * 1.7) * 9.0, sin(_sway_clock * 3.1) * 7.0)


## One look path for both a mouse and a dragged thumb, so the two can never
## drift into different sensitivities or clamp differently.
func apply_look(rel: Vector2) -> void:
	if call_locked:
		return
	rotate_y(-rel.x * MOUSE_SENS)
	camera.rotate_x(-rel.y * MOUSE_SENS)
	# The hand trails the view. One look path in, one hand lag out, so
	# a mouse and a dragged thumb can never disagree about it.
	if phone_carrier and phone_carrier.has_method("apply_look"):
		phone_carrier.apply_look(rel)
	camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


func _set_crouched(on: bool) -> void:
	crouched = on
	_capsule.height = CROUCH_HEIGHT if on else STANDING_HEIGHT
	_shape.position.y = _capsule.height / 2.0
	camera.position.y = CROUCH_EYE if on else STANDING_EYE


func _physics_process(delta: float) -> void:
	if call_locked:
		velocity = Vector3.ZERO
		return
	var wish := autopilot
	if wish == Vector3.ZERO:
		var input := Input.get_vector("move_left", "move_right",
				"move_forward", "move_back")
		wish = (transform.basis * Vector3(input.x, 0, input.y))
	if noclip:
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
	camera.rotation.z = lerpf(camera.rotation.z,
			-gravity_direction.x * 0.42, minf(1.0, delta * 2.5))
	var speed := CROUCH_SPEED if crouched \
			else (RUN if Input.is_action_pressed("run") else WALK)
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
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
			node.interact_area(hit.collider)
			return
		if node.has_method("interact"):
			node.interact(self)
			return
		node = node.get_parent()
