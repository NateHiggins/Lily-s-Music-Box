class_name FridgeProp
extends FunctionalProp
## Kitchen refrigerator. Normal: compressor hum cycling on/off on a slow
## thermostat. Synced: compressor relay clicks land on motif events.

var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _running := true
## The door is a hinge, not a face: everything that swings hangs off
## `_door`, so both the player's hand and the poltergeist move one node.
var _door: Node3D
var _lamp: OmniLight3D
var _open := false
var _possessed := false


func _build_visual() -> void:
	## Rounded-shoulder 1950s refrigerator, matching the Blender library:
	## stepped crown, proud door face, vertical chrome handle, latch, badge.
	var body := Color(0.88, 0.87, 0.84)
	make_box(Vector3(0.60, 0.06, 0.58), Vector3(0, 0.03, 0),
			Color(0.09, 0.09, 0.09))                     # plinth
	make_box(Vector3(0.66, 1.46, 0.64), Vector3(0, 0.79, 0), body)
	make_box(Vector3(0.63, 0.08, 0.61), Vector3(0, 1.56, 0), body)
	make_box(Vector3(0.57, 0.06, 0.55), Vector3(0, 1.63, 0), body)
	make_box(Vector3(0.46, 0.04, 0.44), Vector3(0, 1.68, 0), body)
	# The lamp lives in the cabinet, dark until the door is off its seal.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.96, 0.86)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 1.5
	_lamp.position = Vector3(0, 1.05, 0.10)
	add_child(_lamp)
	# Hinge on the LEFT stile, so the door swings away from the handle
	# the way a real one does.
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(-0.31, 0.0, 0.33)
	add_child(_door)
	var swinging: Array[MeshInstance3D] = [
		make_box(Vector3(0.62, 1.40, 0.024), Vector3(0, 0.80, 0.332), body),
		make_box(Vector3(0.56, 1.32, 0.012), Vector3(0, 0.80, 0.351), body),
		make_cyl(0.016, 0.016, 0.46, Vector3(0.24, 0.95, 0.395),
				Color(0.80, 0.82, 0.85), 0.12, 1.0),     # chrome handle
		make_box(Vector3(0.08, 0.06, 0.05), Vector3(0.24, 0.96, 0.36),
				Color(0.80, 0.82, 0.85)),                # latch body
		make_box(Vector3(0.18, 0.06, 0.008), Vector3(0, 1.33, 0.358),
				Color(0.62, 0.55, 0.30)),                # maker's badge
	]
	for hz in [0.74, 1.16]:
		swinging.append(make_box(Vector3(0.03, 0.02, 0.045),
				Vector3(0.24, hz, 0.375), Color(0.80, 0.82, 0.85)))
	for piece in swinging:
		var keep := piece.position
		remove_child(piece)
		_door.add_child(piece)
		piece.position = keep - _door.position
	retexture(self, [
		[Color(0.88, 0.87, 0.84), "appliance", Color.WHITE],
		[Color(0.80, 0.82, 0.85), "chrome", Color.WHITE],
		[Color(0.62, 0.55, 0.30), "brass", Color.WHITE],
		[Color(0.09, 0.09, 0.09), "metal", Color(0.25, 0.25, 0.28)],
	])
	_hum = make_emitter("hum_loop", -22.0, true)
	_click = make_emitter("tick", -12.0)


func interact_prompt() -> String:
	return "[E]  %s the refrigerator" % ("Close" if _open else "Open")


func interact(_player: Node) -> void:
	set_door_open(not _open)


## One path for the hand and the haunting, so a possessed door cannot
## desync from the latch state the prompt reports.
func set_door_open(open: bool, seconds := 0.55) -> void:
	if _door == null:
		return
	_open = open
	_click.pitch_scale = 0.8 if open else 1.15
	_click.play()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	tween.tween_property(_door, "rotation:y",
			deg_to_rad(-105.0) if open else 0.0, seconds)
	create_tween().tween_property(_lamp, "light_energy",
			1.1 if open else 0.0, seconds * 0.6)


## Possession: the door keeps the motif. Short, hard beats with the
## lamp stuttering behind them - a fridge cannot speak, so it knocks.
func possess_fit(beats := 4) -> void:
	if _possessed or _door == null:
		return
	_possessed = true
	for i in range(beats):
		set_door_open(true, 0.16)
		await get_tree().create_timer(0.22, false).timeout
		if not is_inside_tree():
			return
		set_door_open(false, 0.13)
		await get_tree().create_timer(0.30 if i % 2 else 0.18,
				false).timeout
		if not is_inside_tree():
			return
	_possessed = false

func _start_normal_function() -> void:
	state = PState.OPERATING
	_thermostat_loop()


func _thermostat_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(35.0, 80.0), false).timeout
		if not is_inside_tree():
			return
		_running = not _running
		_click.pitch_scale = 0.9
		_click.play()
		create_tween().tween_property(_hum, "volume_db",
				-22.0 if _running else -50.0, 1.2)


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_click.pitch_scale = rng.randf_range(0.85, 0.95)
	_click.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_click.play()
	if not _running:
		_running = true
		create_tween().tween_property(_hum, "volume_db", -22.0, 0.6)
