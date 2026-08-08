class_name SwcBreakable
extends Node

## Crates and barrels: cover that can be removed by shooting it.

signal broken(semantic_id: String)

var entity: SwcEntity
var hitpoints: int = 30

var _remaining: int = 30
var _broken: bool = false


func configure(owner_entity: SwcEntity) -> void:
	entity = owner_entity
	hitpoints = int(owner_entity.param("hitpoints", 30))
	_remaining = hitpoints


func take_damage(amount: int) -> void:
	if _broken:
		return
	_remaining -= amount
	entity.play_sound("break", -6.0)
	if _remaining <= 0:
		_break()


func _break() -> void:
	_broken = true
	entity.play_sound("break")
	entity.graybox_root.visible = false
	entity.presentation_anchor.visible = false
	for body in entity.collision_root.get_children():
		if body is CollisionObject3D:
			(body as CollisionObject3D).collision_layer = 0
	broken.emit(entity.semantic_id)


func is_broken() -> bool:
	return _broken


func reset() -> void:
	_broken = false
	_remaining = hitpoints
	for body in entity.collision_root.get_children():
		if body is CollisionObject3D:
			(body as CollisionObject3D).collision_layer = SwcEntity.LAYER_PROP
