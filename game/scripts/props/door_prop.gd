class_name DoorProp
extends Node3D
## Hinged door leaf spawned from a layout door opening. Interact (E) to
## swing it; latch clicks on close. Locked doors rattle and hold — the
## former-suite storage rooms and 6D keep their secrets for now.

var width := 0.81
var height := 2.03
var leaf_state := "closed"  # "closed" | "open" | "locked"
## Egress doors swing with the direction of travel (reversed hinge),
## so the street door never sweeps whoever stands in the vestibule.
var swing_out := false

var open := false
var _body: AnimatableBody3D
var _click: AudioStreamPlayer3D
var _moving := false


func _ready() -> void:
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = true
	add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.02, height - 0.02, 0.044)
	shape.shape = box
	shape.position = Vector3(width / 2.0, height / 2.0, 0)
	_body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	mi.position = shape.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.34, 0.26) if width > 0.85 \
			else Color(0.80, 0.78, 0.72)
	mat.roughness = 0.5
	mi.material_override = mat
	_body.add_child(mi)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.022
	sm.height = 0.044
	knob.mesh = sm
	knob.position = Vector3(width - 0.07, 0.96, 0.035)
	_body.add_child(knob)
	_click = AudioStreamPlayer3D.new()
	_click.stream = PropAudio.get_stream("tick")
	_click.volume_db = -14.0
	_click.unit_size = 2.5
	_click.max_distance = 12.0
	add_child(_click)
	if leaf_state == "open":
		# parked flat back against the wall so it never blocks a route
		open = true
		_body.rotation.y = deg_to_rad(-168 if swing_out else 168)


func interact_prompt() -> String:
	if leaf_state == "locked":
		return "[E]  Locked"
	return "[E]  Close door" if open else "[E]  Open door"


func interact(_player: Node) -> void:
	if _moving:
		return
	if leaf_state == "locked":
		_rattle()
		return
	_moving = true
	open = not open
	var swept := -100.0 if swing_out else 100.0
	var tw := create_tween()
	tw.tween_property(_body, "rotation:y",
			deg_to_rad(swept) if open else 0.0, 0.5) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_settled)


func _settled() -> void:
	_moving = false
	if not open:
		_click.pitch_scale = 0.9
		_click.play()  # latch


func _rattle() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_callback(_click.play)
		tw.tween_interval(0.09)
