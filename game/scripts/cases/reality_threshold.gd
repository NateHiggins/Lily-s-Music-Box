class_name RealityThreshold
extends Area3D
## A reusable non-Euclidean doorway. Crossing one plane transfers the body to
## its paired destination while preserving local offset, velocity and facing.

@export var enabled := true
var destination: RealityThreshold
var _cooldown: Dictionary = {}


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)


func pair_with(other: RealityThreshold) -> void:
	destination = other
	other.destination = self


func _physics_process(delta: float) -> void:
	for body in _cooldown.keys():
		_cooldown[body] = float(_cooldown[body]) - delta
		if _cooldown[body] <= 0.0 or not is_instance_valid(body):
			_cooldown.erase(body)


func _on_body_entered(body: Node3D) -> void:
	if not enabled or destination == null or _cooldown.has(body):
		return
	var local := global_transform.affine_inverse() * body.global_transform
	# Emerge forward from the paired plane instead of immediately retriggering.
	local.origin.z = -absf(local.origin.z) - 0.35
	body.global_transform = destination.global_transform * local
	if body is CharacterBody3D:
		body.velocity = destination.global_basis * (
				global_basis.inverse() * body.velocity)
	destination._cooldown[body] = 0.35
