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
	var leaf_col := Color(0.42, 0.34, 0.26) if width > 0.85 \
			else Color(0.80, 0.78, 0.72)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = leaf_col
	mat.roughness = 0.5
	mi.material_override = mat
	_body.add_child(mi)
	# stile-and-rail identity: two recessed panel fields per face
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = leaf_col.darkened(0.16)
	pmat.roughness = 0.55
	for side in [-1.0, 1.0]:
		for pz in [[0.16, 0.88], [1.04, height - 0.18]]:
			var panel := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(width - 0.22, pz[1] - pz[0], 0.012)
			panel.mesh = pb
			panel.position = Vector3(width / 2.0, (pz[0] + pz[1]) / 2.0,
					side * 0.020)
			panel.material_override = pmat
			_body.add_child(panel)
	# lever on a rosette over a keyhole escutcheon, both faces
	var hw := StandardMaterial3D.new()
	hw.albedo_color = Color(0.62, 0.55, 0.30)
	hw.roughness = 0.28
	hw.metallic = 0.85
	for side in [-1.0, 1.0]:
		var rosette := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.026
		rc.bottom_radius = 0.026
		rc.height = 0.012
		rosette.mesh = rc
		rosette.rotation_degrees = Vector3(90, 0, 0)
		rosette.position = Vector3(width - 0.075, 0.96, side * 0.028)
		rosette.material_override = hw
		_body.add_child(rosette)
		var lever := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.11, 0.016, 0.014)
		lever.mesh = lb
		lever.position = Vector3(width - 0.075 - 0.045, 0.955,
				side * 0.043)
		lever.material_override = hw
		_body.add_child(lever)
		var esc := MeshInstance3D.new()
		var eb := BoxMesh.new()
		eb.size = Vector3(0.022, 0.055, 0.008)
		esc.mesh = eb
		esc.position = Vector3(width - 0.075, 0.875, side * 0.026)
		esc.material_override = hw
		_body.add_child(esc)
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
