extends CharacterBody2D
class_name Player

signal request_inspect
signal request_interact
signal request_emote

@export var speed := 160.0
var move_input := Vector2.ZERO
var tap_to_move := false
var path: Array[Vector2] = []

func _physics_process(_delta: float) -> void:
	if tap_to_move and path.size() > 0:
		var target := path[0]
		var dir := (target - global_position)
		if dir.length() < 6.0:
			path.pop_front()
			velocity = Vector2.ZERO
		else:
			velocity = dir.normalized() * speed
	else:
		velocity = move_input.normalized() * speed
	move_and_slide()

func set_move_input(input_vec: Vector2) -> void:
	move_input = input_vec

func set_path(points: Array[Vector2]) -> void:
	path = points

func inspect() -> void:
	request_inspect.emit()

func interact() -> void:
	request_interact.emit()

func emote() -> void:
	request_emote.emit()
