class_name PlayerController
extends CharacterBody3D
## First-person controller matched to the brief's metrics: 1.75 m standing,
## 1.62 m eye height, 0.38 m capsule radius, 1.05 m crouch, 0.28 m steps
## (handled by stair ramp colliders + floor snap). V toggles debug noclip.

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

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D


func _ready() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.38
	_capsule.height = 1.75
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position = Vector3(0, 0.875, 0)
	add_child(_shape)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 72.0
	add_child(camera)
	flashlight = SpotLight3D.new()
	flashlight.light_energy = 2.4
	flashlight.spot_range = 14.0
	flashlight.spot_angle = 32.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.visible = false
	camera.add_child(flashlight)
	floor_snap_length = 0.4
	_build_hud()


func _build_hud() -> void:
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
	if call_locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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


func _unhandled_input(event: InputEvent) -> void:
	if call_locked:
		return
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("noclip"):
		noclip = not noclip
		collision_layer = 0 if noclip else 1
		collision_mask = 0 if noclip else 1
	elif event.is_action_pressed("crouch"):
		_set_crouched(not crouched)
	elif event.is_action_pressed("interact"):
		_try_interact()


func _set_crouched(on: bool) -> void:
	crouched = on
	_capsule.height = 1.05 if on else 1.75
	_shape.position.y = _capsule.height / 2.0
	camera.position.y = 0.92 if on else 1.62


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
	var speed := CROUCH_SPEED if crouched \
			else (RUN if Input.is_action_pressed("run") else WALK)
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 3.4
	else:
		velocity.y = minf(velocity.y, 0.0)
	_try_step_up(delta)
	move_and_slide()


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
