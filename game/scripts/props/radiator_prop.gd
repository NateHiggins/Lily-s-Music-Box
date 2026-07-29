class_name RadiatorProp
extends FunctionalProp
## Cast-iron radiator blockout: eight fin sections, supply pipe, valve.
## Normal function: irregular thermal ticks as it heats and cools.
## Synced function: a knock — one section impacting — on motif events.

var _body: Node3D
var _knock: AudioStreamPlayer3D
var _tick: AudioStreamPlayer3D
var _shake := 0.0


func _build_visual() -> void:
	_body = Node3D.new()
	add_child(_body)
	for i in 8:
		var fin := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.055, 0.60, 0.16)
		fin.mesh = box
		fin.position = Vector3(-0.36 + i * 0.098, 0.36, 0.0)
		var mat := StandardMaterial3D.new()
		# a century of repaints: roughly a third got the landlord's
		# aluminum paint (which is why pre-war radiators run silver)
		if hash(name) % 3 == 0:
			mat.albedo_color = Color(0.62, 0.63, 0.65)
			mat.roughness = 0.38
			mat.metallic = 0.55
		else:
			mat.albedo_color = Color(0.16, 0.16, 0.17)
			mat.roughness = 0.46
			mat.metallic = 0.2
		fin.material_override = mat
		_body.add_child(fin)
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.7
	pipe.mesh = cyl
	pipe.position = Vector3(0.42, 0.35, 0.0)
	_body.add_child(pipe)
	_knock = make_emitter("knock", -6.0)
	_tick = make_emitter("tick", -16.0)


func _start_normal_function() -> void:
	state = PState.OPERATING
	_normal_tick_loop()


func _normal_tick_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(6.0, 16.0), false).timeout
		if not is_inside_tree():
			return
		if state == PState.OPERATING:
			_tick.pitch_scale = rng.randf_range(0.85, 1.2)
			_tick.play()


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_knock.volume_db = -6.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_knock.pitch_scale = clampf(pow(2.0, pitch * 0.15 / 12.0), 0.9, 1.1)
	_knock.play()
	_shake = maxf(_shake, accent * 0.006)


func _process(delta: float) -> void:
	if _shake > 0.0002:
		_body.position = Vector3(rng.randf_range(-_shake, _shake), 0,
				rng.randf_range(-_shake, _shake))
		_shake = maxf(_shake - delta * 0.04, 0.0)
	elif _body.position != Vector3.ZERO:
		_body.position = Vector3.ZERO
