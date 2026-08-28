extends Node

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const RUNTIME := preload("res://scenes/building/orison_v2_runtime.tscn")

var shots = ShotHarnessScript.new()
var world: OrisonV2RuntimeRoot
var radiator: RadiatorProp
var camera: Camera3D
var control_layer: CanvasLayer


func _ready() -> void:
	if not shots.setup(self, "RADIATOR-CONSEQUENCE-02", 15):
		get_tree().quit(2)
		return
	await _capture_previous_control()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = RUNTIME.instantiate()
	add_child(world)
	world.player.camera.current = false
	world.player.set_lamp_enabled(false)
	world.player.visible = false
	_hide_device_overlay()
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 58.0
	add_child(camera)
	radiator = world.find_child(ServiceRoundDirector.RADIATOR_ID,
			true, false) as RadiatorProp
	var practical := OmniLight3D.new()
	practical.light_color = Color("f0c99d")
	practical.light_energy = 1.25
	practical.omni_range = 4.0
	practical.shadow_enabled = true
	add_child(practical)
	practical.global_position = _installation_point(Vector3(-1.1, 1.55, -0.45))
	await shots.settle(0.7, "installed_radiator_ready")
	await _shot("02_new_full_three_quarter", Vector3(-1.55, 1.00, -1.15),
			Vector3(0, 0.38, 0))
	await _shot("03_valve_and_packing_assembly", Vector3(-1.05, 0.55, -0.55),
			Vector3(-0.45, 0.25, 0))
	await _shot("04_air_vent", Vector3(0.95, 0.90, -0.55),
			Vector3(0.46, 0.62, -0.08))
	await _shot("05_pipe_floor_connection", Vector3(-1.15, 0.40, -0.65),
			Vector3(-0.62, 0.13, 0))
	await _shot("06_section_and_manifold_detail", Vector3(0.15, 0.88, -0.80),
			Vector3(0, 0.49, 0))
	radiator.apply_open_shift_condition("sounding")
	await shots.settle(0.7, "normal_valve_settled")
	await _shot("07_normal_heating", Vector3(-1.30, 0.82, -1.00),
			Vector3(0, 0.38, 0))
	radiator.apply_open_shift_condition("worsening_hammer")
	radiator.play_ambient_cycle("knock", 1.0)
	await shots.settle(0.12, "hammer_phase")
	await _shot("08_hammering_fault", Vector3(-1.30, 0.82, -1.00),
			Vector3(0, 0.38, 0))
	radiator.apply_open_shift_condition("wrong_valve_partial")
	await shots.settle(0.7, "partial_valve_settled")
	await _shot("09_partial_wrong_valve_heating", Vector3(-1.30, 0.82, -1.00),
			Vector3(0, 0.38, 0))
	radiator.apply_open_shift_condition("opened_uncommitted")
	await shots.settle(0.7, "open_union_settled")
	await _shot("10_open_union_abandonment", Vector3(-1.0, 0.54, -0.52),
			Vector3(-0.40, 0.22, 0))
	radiator.apply_open_shift_condition("porter_temporary_shutoff")
	await shots.settle(0.7, "porter_valve_settled")
	await _shot("11_porter_shutoff_and_tag", Vector3(-1.12, 0.68, -0.68),
			Vector3(-0.50, 0.27, 0))
	radiator.apply_open_shift_condition("repaired")
	await shots.settle(0.7, "repair_valve_settled")
	await _shot("12_completed_repair", Vector3(-1.30, 0.82, -1.00),
			Vector3(0, 0.38, 0))
	radiator.apply_open_shift_condition("cooling")
	await shots.settle(0.7, "cooling_valve_settled")
	await _shot("13_cooling_state", Vector3(-1.30, 0.82, -1.00),
			Vector3(0, 0.38, 0))
	await _shot("14_in_room_gameplay_distance", Vector3(-2.0, 1.42, -2.1),
			Vector3(0, 0.42, 0))
	await _shot("15_player_service_stance", Vector3(0.0, 1.42, -1.15),
			Vector3(-0.28, 0.30, 0))
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if shots.finish() else 2)


func _capture_previous_control() -> void:
	var path := OS.get_environment("OPEN_SHIFT_PREVIOUS_CONTROL")
	var image := Image.load_from_file(path)
	if image.is_empty():
		push_error("previous radiator control missing: " + path)
		return
	control_layer = CanvasLayer.new()
	control_layer.layer = 100
	add_child(control_layer)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control_layer.add_child(rect)
	await shots.capture("01_previous_model_control")
	control_layer.queue_free()
	await get_tree().process_frame


func _hide_device_overlay() -> void:
	if world.service_set_carrier == null:
		return
	for child: Node in world.service_set_carrier.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false


func _shot(label: String, offset: Vector3, target_offset: Vector3) -> void:
	camera.global_position = _installation_point(offset)
	camera.look_at(_installation_point(target_offset))
	await shots.capture(label)


func _installation_origin() -> Vector3:
	return radiator.global_position + Vector3.DOWN * radiator.installation_drop


func _installation_point(local_offset: Vector3) -> Vector3:
	return radiator.global_transform * (Vector3.DOWN * radiator.installation_drop \
			+ local_offset)
