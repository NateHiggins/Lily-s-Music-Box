class_name DreamMazeRoot
extends Node3D
## N4 scene-boundary payload only. It proves identity, revision and the D00
## restart contract. N6 adds production module geometry and pursuit.

const START_MODULE_ID := "D00_4B_THRESHOLD"

var dream_context: Dictionary = {}
var start_marker: Marker3D


func configure_dream(context: Dictionary) -> void:
	dream_context = context.duplicate(true)


func _ready() -> void:
	add_to_group("dream_world")
	start_marker = Marker3D.new()
	start_marker.name = START_MODULE_ID
	add_child(start_marker)


func start_module_id() -> String:
	return START_MODULE_ID
