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
	## Column cast-iron radiator: nine sections of four round columns
	## between bulbous headers, on cabriole-ish feet, with a hand valve.
	_body = Node3D.new()
	add_child(_body)
	# a century of repaints: roughly a third of the building's radiators
	# got the landlord's aluminum paint (which is why pre-war radiators
	# so often run silver); the rest kept their dark enamel
	var silvered := hash(name) % 3 == 0
	var iron := Color(0.62, 0.63, 0.65) if silvered else Color(0.16, 0.16, 0.17)
	var iron_rough := 0.38 if silvered else 0.46
	var iron_metal := 0.55 if silvered else 0.2
	for i in 9:
		var sx := -0.36 + i * 0.09
		for j in 4:
			var col := make_cyl(0.021, 0.021, 0.50,
					Vector3(sx, 0.36, -0.066 + j * 0.044), iron,
					iron_rough, iron_metal, _body)
			col.scale = Vector3(1, 1, 0.8)
	for hz in [0.095, 0.645]:  # top / bottom headers, one per section
		for i in 9:
			var hd := make_cyl(0.032, 0.032, 0.085,
					Vector3(-0.36 + i * 0.09, hz, 0.0), iron,
					iron_rough - 0.04, iron_metal + 0.05, _body)
			hd.rotation_degrees = Vector3(0, 0, 90)
			hd.scale = Vector3(1, 1, 2.6)
	for fx in [-0.33, 0.33]:   # feet
		var ft := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.10, 0.055, 0.14)
		ft.mesh = fb
		ft.position = Vector3(fx, 0.027, 0.0)
		ft.material_override = _pmat(iron, iron_rough, iron_metal)
		_body.add_child(ft)
		make_cyl(0.030, 0.045, 0.045, Vector3(fx, 0.075, 0.0), iron,
				iron_rough, iron_metal, _body)
	# supply pipe, elbow and the valve wheel
	make_cyl(0.019, 0.019, 0.62, Vector3(0.44, 0.31, 0.0),
			Color(0.30, 0.28, 0.26), 0.4, 0.4, _body)
	make_cyl(0.030, 0.030, 0.05, Vector3(0.44, 0.635, 0.0),
			Color(0.30, 0.28, 0.26), 0.4, 0.4, _body)
	var wheel := make_ring(0.035, 0.009, Vector3(0.44, 0.70, 0.0),
			Color(0.62, 0.55, 0.30), 0.35, 0.7, _body)
	wheel.rotation_degrees = Vector3(0, 0, 0)
	make_cyl(0.008, 0.008, 0.05, Vector3(0.44, 0.675, 0.0),
			Color(0.62, 0.55, 0.30), 0.35, 0.7, _body)
	# semantic finishes: painted cast iron, steel supply, brass valve
	retexture(_body, [
		[Color(0.16, 0.16, 0.17), "metal", Color(0.40, 0.40, 0.44), 0.5],
		[Color(0.30, 0.28, 0.26), "metal", Color(0.52, 0.48, 0.44), 0.5],
		[Color(0.62, 0.55, 0.30), "brass", Color.WHITE],
	])
	# Nothing here moves relative to anything else here — the knock shakes
	# _body as a unit — so 62 primitives bake down to one mesh per finish.
	merge_static(_body)
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
