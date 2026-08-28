extends Node

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const RUNTIME := preload("res://scenes/building/orison_v2_runtime.tscn")

var shots = ShotHarnessScript.new()
var world: OrisonV2RuntimeRoot
var camera: Camera3D


func _ready() -> void:
	if not shots.setup(self, "ETHOS-OPEN-SHIFT-1", 4):
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = RUNTIME.instantiate()
	add_child(world)
	world.player.camera.current = false
	world.player.visible = false
	if world.service_set_carrier:
		world.service_set_carrier.visible = false
		for child: Node in world.service_set_carrier.get_children():
			if child is CanvasLayer:
				(child as CanvasLayer).visible = false
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	var radiator := world.find_child(ServiceRoundDirector.RADIATOR_ID,
			true, false) as RadiatorProp
	camera.global_position = radiator.global_position + Vector3(-1.65, 0.75, 0.4)
	camera.look_at(radiator.global_position + Vector3.UP * 0.35)
	var evidence_light := OmniLight3D.new()
	evidence_light.light_energy = 3.0
	evidence_light.omni_range = 5.0
	evidence_light.position = camera.position + Vector3(0.2, 0.5, 0.2)
	add_child(evidence_light)
	await shots.settle(0.8, "world_ready")
	radiator.apply_maintenance_result({"mechanism_patch": {
		"vent_grade": 2, "supply_position": 1.0,
	}})
	await shots.capture("work/01_visible_committed_repair")
	radiator.apply_open_shift_condition("porter_temporary_shutoff")
	await shots.capture("ignore/01_porter_temporary_shutoff")
	radiator.apply_open_shift_condition("opened_uncommitted")
	await shots.capture("abandon/01_opened_uncommitted")
	radiator.apply_open_shift_condition("wrong_valve_partial")
	await shots.capture("meddle/01_wrong_valve_partial")
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if shots.finish() else 2)
