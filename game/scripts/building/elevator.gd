class_name OrisonElevator
extends Node3D
## The unreliable elevator: kinematic cabin traveling the shaft between
## stops, call buttons at every landing, a cycle button inside the cabin,
## and an arrival bell the conductor can also strike. Travels at 1.2 m/s
## with a settle bounce — musical phrases come later; plausibility first.

const SPEED := 1.2

var stops: Dictionary = {}   # level name -> z (godot y)
var stop_order: Array = []
var current := "F01"
var moving := false

var _cabin: AnimatableBody3D
var _bell: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D


func setup(elevator_data: Dictionary) -> void:
	var shaft: Array = elevator_data["shaft"]
	var cx := (float(shaft[0]) + float(shaft[2])) / 2.0
	var cy := (float(shaft[1]) + float(shaft[3])) / 2.0
	position = GameBoot.b2g([cx, cy, 0.0])
	for level in elevator_data["stops"]:
		stops[level] = float(elevator_data["stops"][level])
		stop_order.append(level)
	stop_order.sort_custom(func(a, b): return stops[a] < stops[b])

	_cabin = AnimatableBody3D.new()
	_cabin.sync_to_physics = true
	add_child(_cabin)
	var cw: float = float(elevator_data["cabin"][0])
	var cd: float = float(elevator_data["cabin"][1])
	_add_cabin_box(Vector3(cw, 0.12, cd), Vector3(0, 0.06, 0))          # floor
	_add_cabin_box(Vector3(cw, 0.08, cd), Vector3(0, 2.28, 0))          # ceiling
	_add_cabin_box(Vector3(0.05, 2.2, cd), Vector3(-cw / 2, 1.16, 0))   # west
	_add_cabin_box(Vector3(0.05, 2.2, cd), Vector3(cw / 2, 1.16, 0))    # east
	_add_cabin_box(Vector3(cw, 2.2, 0.05), Vector3(0, 1.16, -cd / 2))   # rear
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.position = Vector3(0, 2.1, 0)
	_cabin.add_child(light)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = PropAudio.get_stream("bell")
	_bell.volume_db = -10.0
	_cabin.add_child(_bell)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = PropAudio.get_stream("hum_loop")
	_hum.volume_db = -60.0
	_cabin.add_child(_hum)
	_hum.play()
	_cabin.position.y = stops[current]

	for level in stop_order:
		var btn := Area3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.16, 0.16, 0.16)
		shape.shape = box
		btn.add_child(shape)
		# beside the shaft opening, on the corridor side (south face)
		btn.position = Vector3(-1.35, stops[level] + 1.1, 1.35)
		btn.set_meta("call_level", level)
		add_child(btn)
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.12, 0.05)
		vis.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.85, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.7, 0.3)
		mat.emission_energy_multiplier = 0.6
		vis.material_override = mat
		btn.add_child(vis)
	var panel := Area3D.new()
	var pshape := CollisionShape3D.new()
	var pbox := BoxShape3D.new()
	pbox.size = Vector3(0.2, 0.4, 0.1)
	pshape.shape = pbox
	panel.add_child(pshape)
	panel.position = Vector3(cw / 2 - 0.12, 1.2, cd / 2 - 0.15)
	panel.set_meta("cabin_panel", true)
	_cabin.add_child(panel)


func _add_cabin_box(size: Vector3, offset: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	_cabin.add_child(shape)
	var vis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	vis.mesh = bm
	vis.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38)
	mat.roughness = 0.5
	mat.metallic = 0.3
	vis.material_override = mat
	_cabin.add_child(vis)


## Call buttons and the cabin panel resolve here via the player's ray.
func interact_area(area: Area3D) -> void:
	if moving:
		return
	if area.has_meta("call_level"):
		travel_to(area.get_meta("call_level"))
	elif area.has_meta("cabin_panel"):
		var i := stop_order.find(current)
		travel_to(stop_order[(i + 1) % stop_order.size()])


func travel_to(level: String) -> void:
	if moving or level == current or not stops.has(level):
		return
	moving = true
	var target: float = stops[level]
	var dur: float = absf(target - _cabin.position.y) / SPEED
	print("[ELEVATOR] %s -> %s (%.1fs)" % [current, level, dur])
	create_tween().tween_property(_hum, "volume_db", -16.0, 0.5)
	var tw := create_tween()
	tw.tween_property(_cabin, "position:y", target + 0.03, dur) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cabin, "position:y", target, 0.25)
	tw.tween_callback(func():
		moving = false
		current = level
		_bell.play()
		create_tween().tween_property(_hum, "volume_db", -60.0, 1.0))
