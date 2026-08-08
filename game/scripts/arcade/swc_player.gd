class_name SwcPlayer
extends CharacterBody3D

## First-person player.
##
## Built in code and configured entirely from the semantic scene's
## gameplay_metrics. Two packages of the same scene therefore produce identical
## movement, identical reach and identical damage - which is the claim
## tests/test_gameplay_invariance.py exists to keep honest.

signal health_changed(current: int, maximum: int)
signal died
signal interact_target_changed(prompt: String)

const _INTERACT_MASK := (
	SwcEntity.LAYER_WORLD | SwcEntity.LAYER_PROP | SwcEntity.LAYER_TRIGGER
)
const _MOUSE_SENSITIVITY := 0.0022
const _PITCH_LIMIT := 1.45
const _INTERACT_RANGE := 2.8

var walk_speed: float = 5.2
var sprint_speed: float = 7.6
var jump_velocity: float = 5.0
var gravity: float = 22.0
var eye_height: float = 1.62
var max_health: int = 100

var camera: Camera3D
## Absent in beats: a ten-second scene about a choice does not issue you a gun.
var weapon: SwcWeapon = null

## Beat movement. "free" is the FPS; "forward_only" auto-advances so the whole
## thing is playable with one thumb; "fixed" plants the player.
var movement_mode: String = "free"
var forward_speed: float = 0.0
var look_limit_rad: float = PI

var _health: int = 100
var _yaw: float = 0.0
var _pitch: float = 0.0
var _look_enabled: bool = true
var _interact_prompt: String = ""
var _hovered: SwcEntity = null
var _footstep_accumulator: float = 0.0
var _audio_source: SwcEntity = null
var _base_yaw: float = 0.0
var _travel_direction: Vector3 = Vector3.FORWARD


static func create(metrics: Dictionary, spawn_params: Dictionary) -> SwcPlayer:
	var player := SwcPlayer.new()
	player.walk_speed = float(metrics.get("player_walk_speed", 5.2))
	player.sprint_speed = float(metrics.get("player_sprint_speed", 7.6))
	player.jump_velocity = float(metrics.get("player_jump_velocity", 5.0))
	player.gravity = float(metrics.get("gravity", 22.0))
	player.eye_height = float(metrics.get("player_eye_height", 1.62))
	player.max_health = int(spawn_params.get("start_health", metrics.get("player_health", 100)))
	player._health = player.max_health
	player._build(
		metrics,
		int(spawn_params.get("start_ammo", 90)),
		String(spawn_params.get("start_weapon", "sidearm")) != "none",
	)
	return player


func _build(metrics: Dictionary, start_ammo: int, armed: bool) -> void:
	name = "SwcPlayer"
	collision_layer = SwcEntity.LAYER_PLAYER
	collision_mask = SwcEntity.LAYER_WORLD | SwcEntity.LAYER_PROP
	floor_max_angle = deg_to_rad(50.0)
	# Matches gameplay_metrics.max_step_height: stairs must be climbable in every
	# world, so the step height is authored, not tuned per skin.
	floor_snap_length = 0.4

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = float(metrics.get("player_radius", 0.36))
	capsule.height = float(metrics.get("player_height", 1.8))
	shape.shape = capsule
	shape.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	add_child(shape)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, eye_height, 0.0)
	camera.fov = 78.0
	camera.near = 0.05
	add_child(camera)

	set_meta("step_height", float(metrics.get("max_step_height", 0.32)))
	if not armed:
		return

	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.16, -0.12, -0.3)
	camera.add_child(muzzle)

	weapon = SwcWeapon.new()
	weapon.name = "SwcWeapon"
	add_child(weapon)
	weapon.configure(metrics, muzzle, self, start_ammo)

	# A minimal weapon "viewmodel". Dressing the weapon from a package is a later
	# phase; the anchor for it already exists.
	var viewmodel := MeshInstance3D.new()
	viewmodel.name = "WeaponViewmodel"
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.11, 0.34)
	viewmodel.mesh = box
	viewmodel.position = Vector3(0.22, -0.19, -0.38)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.24, 0.26)
	material.roughness = 0.45
	material.metallic = 0.7
	viewmodel.material_override = material
	camera.add_child(viewmodel)


func set_audio_source(entity: SwcEntity) -> void:
	## Where footstep and hurt sounds come from. The player_spawn entity owns them,
	## because they are the *player's* sounds and the player is not in the scene file.
	_audio_source = entity


func set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled


func set_movement_mode(mode: String, speed: float, look_limit_deg: float) -> void:
	movement_mode = mode
	forward_speed = speed
	look_limit_rad = deg_to_rad(clampf(look_limit_deg, 0.0, 180.0))


func travel_direction() -> Vector3:
	## The direction the player is being carried, which is NOT where they are
	## looking. A follower that trailed the gaze could be dodged by turning; one
	## that trails travel can only be seen on purpose.
	return _travel_direction


func is_looking_at(point: Vector3, angle_deg: float) -> bool:
	var to_point := point - camera.global_position
	if to_point.length_squared() < 0.0001:
		return true
	var forward := -camera.global_transform.basis.z
	return forward.dot(to_point.normalized()) >= cos(deg_to_rad(angle_deg))


func teleport_to(spawn: Transform3D) -> void:
	global_position = spawn.origin
	velocity = Vector3.ZERO
	_yaw = spawn.basis.get_euler().y
	_base_yaw = _yaw
	_travel_direction = (spawn.basis * Vector3.FORWARD).normalized()
	_travel_direction.y = 0.0
	if _travel_direction.length_squared() < 0.0001:
		_travel_direction = Vector3.FORWARD
	_travel_direction = _travel_direction.normalized()
	_pitch = 0.0
	rotation = Vector3(0.0, _yaw, 0.0)
	camera.rotation = Vector3.ZERO


func revive() -> void:
	_health = max_health
	health_changed.emit(_health, max_health)


## What the cabinet's controls are currently asking for.
##
## Nothing below reads the global `Input` singleton, and that is deliberate. This
## player lives inside a cabinet inside another game: if it polled the same keys
## the outer player walks on, every machine on the row would strafe whenever
## somebody crossed the arcade. The panel that has focus writes here and nothing
## else does, so an unattended cabinet is genuinely unattended.
var control := {
	"move": Vector2.ZERO,   # x = strafe, y = forward (-1 is forward)
	"look": Vector2.ZERO,   # consumed each frame
	"fire": false,
	"jump": false,
	"sprint": false,
}

var _jump_held := false

## What this world hands the player. Empty until a package says otherwise.
var held_object: Dictionary = {}


## Called by the panel once per frame. `look` is in the same units as mouse
## motion; everything else is a held state.
func drive(move: Vector2, look: Vector2, fire: bool, jump: bool, sprint: bool) -> void:
	control["move"] = move
	control["look"] = look
	control["fire"] = fire
	control["jump"] = jump
	control["sprint"] = sprint


## Drop every input. Called when a panel closes, so a key held at the moment the
## player stepped away does not stay held for the rest of the machine's life.
## Put this world's object in the player's hands, replacing the graybox stub.
## Purely presentational: the weapon underneath is untouched.
func wear_held_object(held: Dictionary) -> void:
	held_object = SwcHeldObject.spec(held)
	SwcHeldObject.build_viewmodel(camera, held_object)


func release_controls() -> void:
	drive(Vector2.ZERO, Vector2.ZERO, false, false, false)
	_jump_held = false


func _apply_look(delta: Vector2) -> void:
	_yaw -= delta.x
	if look_limit_rad < PI:
		_yaw = _base_yaw + clampf(
			wrapf(_yaw - _base_yaw, -PI, PI), -look_limit_rad, look_limit_rad
		)
	_pitch = clampf(_pitch - delta.y, -_PITCH_LIMIT, _PITCH_LIMIT)
	rotation = Vector3(0.0, _yaw, 0.0)
	camera.rotation = Vector3(_pitch, 0.0, 0.0)


## Touch drag, in the same units as mouse look. Phones are the target.
func apply_touch_look(relative: Vector2, sensitivity: float) -> void:
	if _look_enabled:
		_apply_look(relative * sensitivity)


func _physics_process(delta: float) -> void:
	if not is_alive():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Look is applied here rather than from an input event, because a cabinet only
	# receives motion while its panel holds focus.
	var look: Vector2 = control["look"]
	if _look_enabled and look != Vector2.ZERO:
		_apply_look(look * _MOUSE_SENSITIVITY)
		control["look"] = Vector2.ZERO

	if is_on_floor():
		velocity.y = 0.0
		var jump_wanted := bool(control["jump"])
		if movement_mode == "free" and jump_wanted and not _jump_held:
			velocity.y = jump_velocity
		_jump_held = jump_wanted
	else:
		velocity.y -= gravity * delta

	if movement_mode != "free":
		# A beat drives the player; input only aims.
		var carry := _travel_direction * (forward_speed if movement_mode == "forward_only" else 0.0)
		velocity.x = carry.x
		velocity.z = carry.z
		move_and_slide()
		_update_interaction()
		return

	var input: Vector2 = control["move"]
	var speed := sprint_speed if bool(control["sprint"]) else walk_speed
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_footstep_accumulator += speed * delta
		if _footstep_accumulator >= 2.6:
			_footstep_accumulator = 0.0
			if _audio_source != null:
				_audio_source.play_sound("footstep", -14.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 6.0 * delta)

	move_and_slide()
	_update_interaction()

	if weapon != null and bool(control["fire"]):
		weapon.try_fire()


func _update_interaction() -> void:
	var origin := camera.global_position
	var target := origin - camera.global_transform.basis.z * _INTERACT_RANGE
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, target, _INTERACT_MASK)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)

	var entity: SwcEntity = null
	if not hit.is_empty():
		entity = SwcEntity.owning_entity(hit.get("collider") as Node)

	var prompt := ""
	var interactable := _interactable_of(entity)
	if interactable != null:
		prompt = "[E] %s  -  %s" % [interactable.call("prompt"), entity.label_or_type()]
		_hovered = entity
	else:
		_hovered = null

	if prompt != _interact_prompt:
		_interact_prompt = prompt
		interact_target_changed.emit(prompt)


func _interactable_of(entity: SwcEntity) -> Node:
	if entity == null:
		return null
	for child_name: String in ["SwcDoor", "SwcPickup", "Objective"]:
		var node := entity.get_node_or_null(child_name)
		if node != null:
			return node
	return null


func hovered_interactable() -> Node:
	return _interactable_of(_hovered)


func apply_damage(amount: int) -> void:
	if not is_alive():
		return
	_health = max(0, _health - amount)
	health_changed.emit(_health, max_health)
	if _audio_source != null:
		_audio_source.play_sound("hurt", -4.0)
	if _health == 0:
		died.emit()


func heal(amount: int) -> void:
	_health = min(max_health, _health + amount)
	health_changed.emit(_health, max_health)


func can_take_health() -> bool:
	return _health < max_health


func health() -> int:
	return _health


func is_alive() -> bool:
	return _health > 0
