extends CharacterBody3D
## Deliberately small controller for the isolated v2 review scene. It uses the
## production input map, including both sticks, but owns no gameplay or save state.

@export var speed := 3.2
@export var acceleration := 14.0
@export var mouse_sensitivity := 0.0022
@export var controller_look_speed := 2.2
@export var review_step_height := 0.22

@onready var head: Node3D = $Head
var pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
		head.rotation.x = pitch
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(move.x, 0.0, move.y)).normalized()
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.1
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.05:
		rotation.y -= look.x * controller_look_speed * delta
		pitch = clampf(pitch - look.y * controller_look_speed * delta, -1.35, 1.35)
		head.rotation.x = pitch
	move_review_velocity(Vector3(velocity.x, 0.0, velocity.z), delta)

func move_review_velocity(horizontal: Vector3, delta: float) -> void:
	var before := global_position
	var was_on_floor := is_on_floor()
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	var advanced := Vector2(global_position.x - before.x,
			global_position.z - before.z).length()
	if advanced < horizontal.length() * delta * 0.2 and (was_on_floor or is_on_floor()):
		var up := Vector3.UP * review_step_height
		if not test_move(global_transform, up):
			global_position += up
			velocity.x = horizontal.x
			velocity.z = horizontal.z
			move_and_slide()
