class_name SwcTriggerVolume
extends Node

## A scripted-event volume. Fires once by default.

signal fired(trigger_id: String, action: String)

var entity: SwcEntity
var trigger_id: String = "trigger"
var action: String = ""
var once: bool = true

var _fired: bool = false


func configure(owner_entity: SwcEntity, area: Area3D) -> void:
	entity = owner_entity
	trigger_id = String(owner_entity.param("trigger_id", "trigger"))
	action = String(owner_entity.param("on_enter", ""))
	once = bool(owner_entity.param("once", true))
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not (body is SwcPlayer):
		return
	if once and _fired:
		return
	_fired = true
	fired.emit(trigger_id, action)


func reset() -> void:
	_fired = false
