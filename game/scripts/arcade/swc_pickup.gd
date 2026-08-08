class_name SwcPickup
extends Node

## Health and ammo pickups.

signal collected(kind: String, amount: int, semantic_id: String)

var entity: SwcEntity
var kind: String = "health"
var amount: int = 25
var auto_collect: bool = true

var _taken: bool = false
var _area: Area3D


func configure(owner_entity: SwcEntity, area: Area3D) -> void:
	entity = owner_entity
	_area = area
	kind = String(owner_entity.param("kind", "health"))
	amount = int(owner_entity.param("amount", 25))
	auto_collect = bool(owner_entity.param("auto_collect", true))
	if auto_collect:
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is SwcPlayer):
		return
	if kind == "health" and not (body as SwcPlayer).can_take_health():
		return
	_take()


func interact(by: Node) -> bool:
	if _taken or not (by is SwcPlayer):
		return false
	_take()
	return true


func prompt() -> String:
	return "Take %s" % kind


func _take() -> void:
	_taken = true
	entity.play_sound("collect")
	collected.emit(kind, amount, entity.semantic_id)
	# The entity stays in the tree: it keeps its semantic identity, its place in
	# the binding table and its debug label. Only its presence in the world stops.
	entity.graybox_root.visible = false
	entity.presentation_anchor.visible = false
	if _area != null:
		_area.monitoring = false


func is_taken() -> bool:
	return _taken


func respawn() -> void:
	_taken = false
	if _area != null:
		_area.monitoring = true
