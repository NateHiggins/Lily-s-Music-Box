class_name ToasterProp
extends FunctionalProp
## Hero functional prop: late-70s two-slot pop-up toaster to the brief's
## dimensions (0.285 x 0.165 x 0.190, lever travel 46 mm, 4 mm overshoot).
## Normal cycle: lever press -> latch -> coils warm -> relay -> pop.
## Infected: the SAME cycle, but coil pulses ride motif accents and the
## release quantizes to the next motif event. Interact (E) to run it.

const LEVER_TRAVEL := 0.046

var _lever: MeshInstance3D
var _carriage: MeshInstance3D
var _coil_mat: StandardMaterial3D
var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _pop: AudioStreamPlayer3D
var _release_on_next_event := false
var cycles_completed := 0


func _build_visual() -> void:
	var shell := make_box(Vector3(0.285, 0.150, 0.165), Vector3(0, 0.095, 0),
			Color(0.78, 0.79, 0.80))
	var shell_mat := shell.material_override as StandardMaterial3D
	shell_mat.metallic = 0.9
	shell_mat.roughness = 0.2
	make_box(Vector3(0.285, 0.022, 0.165), Vector3(0, 0.011, 0),
			Color(0.13, 0.13, 0.14))                       # phenolic base
	make_box(Vector3(0.26, 0.012, 0.145), Vector3(0, 0.178, 0),
			Color(0.72, 0.73, 0.74))                       # crowned top plate
	for sz in [-1, 1]:
		make_box(Vector3(0.145, 0.006, 0.019),
				Vector3(0, 0.184, sz * 0.032), Color(0.05, 0.05, 0.05))
	# carriage + coal-dark cavity with emissive coil cards
	_carriage = make_box(Vector3(0.13, 0.008, 0.06), Vector3(0, 0.16, 0),
			Color(0.3, 0.3, 0.3))
	_coil_mat = StandardMaterial3D.new()
	_coil_mat.albedo_color = Color(0.08, 0.03, 0.02)
	_coil_mat.emission_enabled = true
	_coil_mat.emission = Color(1.0, 0.35, 0.08)
	_coil_mat.emission_energy_multiplier = 0.0
	for sz in [-1, 1]:
		var card := make_box(Vector3(0.13, 0.11, 0.004),
				Vector3(0, 0.11, sz * 0.05), Color.BLACK)
		card.material_override = _coil_mat
	# lever on a narrow slot, flattened-lozenge grip (not a sphere)
	_lever = make_box(Vector3(0.029, 0.015, 0.009),
			Vector3(0.155, 0.155, 0.02), Color(0.15, 0.15, 0.16))
	# browning dial
	var dial := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0095
	cyl.bottom_radius = 0.0095
	cyl.height = 0.009
	dial.mesh = cyl
	dial.rotation_degrees = Vector3(90, 0, 0)
	dial.position = Vector3(0.155, 0.06, 0.02)
	add_child(dial)
	# crumb tray lip
	make_box(Vector3(0.19, 0.008, 0.012), Vector3(0, 0.03, 0.085),
			Color(0.6, 0.6, 0.62))
	_hum = make_emitter("hum_loop", -60.0, true)
	_click = make_emitter("tick", -10.0)
	_pop = make_emitter("pop", -8.0)
	# interact target for the player's ray
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32, 0.22, 0.20)
	shape.shape = box
	shape.position = Vector3(0, 0.1, 0)
	area.add_child(shape)
	add_child(area)


func interact_prompt() -> String:
	return "[E]  Press the lever" if state == PState.IDLE else ""


func interact(_player: Node) -> void:
	start_cycle()


func _start_normal_function() -> void:
	state = PState.IDLE


func start_cycle() -> void:
	if state != PState.IDLE:
		return
	state = PState.STARTING
	print("[TOASTER] %s cycle start" % name)
	var tw := create_tween()
	tw.tween_property(_lever, "position:y", 0.155 - LEVER_TRAVEL, 0.16)
	tw.parallel().tween_property(_carriage, "position:y", 0.06, 0.16)
	tw.tween_callback(_latched)


func _latched() -> void:
	_click.pitch_scale = 1.0
	_click.play()
	state = PState.OPERATING
	create_tween().tween_property(_hum, "volume_db", -26.0, 0.4)
	create_tween().tween_property(_coil_mat,
			"emission_energy_multiplier", 2.2, 1.4)
	var browning := get_tree().create_timer(5.0, false)
	browning.timeout.connect(_request_release)


func _request_release() -> void:
	if state != PState.OPERATING:
		return
	# At meaningful infection the relay waits for the conductor's next
	# event — the toaster still toasts, it just keeps time now.
	if Conductor.infection > 0.4:
		_release_on_next_event = true
	else:
		_release()


func _release() -> void:
	if state != PState.OPERATING:
		return
	state = PState.COMPLETING
	_release_on_next_event = false
	_click.pitch_scale = 0.8
	_click.play()  # relay
	create_tween().tween_property(_coil_mat,
			"emission_energy_multiplier", 0.0, 0.8)
	create_tween().tween_property(_hum, "volume_db", -60.0, 0.4)
	var tw := create_tween()
	tw.tween_property(_carriage, "position:y", 0.164, 0.075)  # 4 mm overshoot
	tw.parallel().tween_property(_lever, "position:y", 0.159, 0.075)
	tw.tween_property(_carriage, "position:y", 0.16, 0.12)
	tw.parallel().tween_property(_lever, "position:y", 0.155, 0.12)
	tw.tween_callback(_cycle_done)
	_pop.play()


func _cycle_done() -> void:
	state = PState.IDLE
	cycles_completed += 1
	print("[TOASTER] %s pop (%d cycles)" % [name, cycles_completed])


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if _release_on_next_event:
		_release()
		return
	if state == PState.OPERATING:
		# coil pulse riding the motif accent
		_coil_mat.emission_energy_multiplier = 2.2 + accent * 1.6
		create_tween().tween_property(_coil_mat,
				"emission_energy_multiplier", 2.2, 0.25)
	elif state == PState.IDLE:
		_click.pitch_scale = 1.15
		_click.volume_db = -16.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_click.play()  # the latch answers without a hand on the lever
