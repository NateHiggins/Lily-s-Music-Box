extends Node
## SR5 visual proof: production 2B before and after the shared organism stores
## its secretory/vascular answer at Lena's radiator.

var root: Node
var camera: Camera3D


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.ensure_case(ServiceRoundDirector.CASE_ID,
			ServiceRoundDirector.RESIDENT_ID)
	root = (load("res://scenes/building/orison_root.tscn") as PackedScene).instantiate()
	add_child(root)
	await _settle(8)
	_hide_presentation_pass()
	var radiator := root.get_node(ServiceRoundDirector.RADIATOR_ID) as RadiatorProp
	root.player.global_position = radiator.global_position + Vector3(1.1, 0.0, 0.1)
	camera = Camera3D.new()
	camera.fov = 51.0
	add_child(camera)
	camera.global_position = radiator.global_position + Vector3(1.42, 1.08, 0.12)
	camera.look_at(radiator.global_position + Vector3(0.0, 0.30, 0.0))
	camera.make_current()
	await _settle(10)
	await _capture("01_2b_control_a")
	await _capture("02_2b_control_b")

	var board := root.find_child(ServiceRoundDirector.BOARD_ID,
			true, false) as OtisProp
	var boiler := root.get_node(ServiceRoundDirector.BOILER_ID) as BoilerProp
	_prepare_route(board)
	boiler.apply_maintenance_result({
		"quality": "good", "note": "column proved",
		"mechanism_patch": {"water_level": 0.62, "column_proved": true}})
	await _settle(2)
	await _capture("03_answer_arrives")
	await _settle(10)
	await _capture("04_answer_in_body")
	radiator.apply_maintenance_result({
		"quality": "good", "note": "vent seated; supply returned fully open",
		"mechanism_patch": {"vent_grade": 2, "supply_position": 1.0}})
	await _settle(3)
	await _capture("05_repair_recognized")
	print("[DREAM SERVICE ANSWER SHOT] production A/A and response saved")
	get_tree().quit(0)


func _prepare_route(board: OtisProp) -> void:
	var orders: WorkOrders = root.work_orders
	const PREVIOUS := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(PREVIOUS, "reported")
	orders.acknowledge_job(PREVIOUS)
	orders.diagnose_job(PREVIOUS)
	orders.mark_job_awaiting_part(PREVIOUS)
	orders.mark_job_repairable(PREVIOUS)
	orders.record_job_repair(PREVIOUS, {"quality": "good", "note": "proof"})
	orders.close_job(PREVIOUS)
	root.service_round.answer_incoming_call()
	root.service_round.dialogue.choose(0)
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	root.service_round.dialogue.choose(0)
	root.player.world_modified.emit(
			root.get_node(ServiceRoundDirector.RADIATOR_ID).global_position,
			ServiceRoundDirector.RADIATOR_ID)
	board.apply_maintenance_result({
		"quality": "good", "note": "contacts squared",
		"mechanism_patch": {"stuck_flag": false, "contact_alignment": 0.63}})


func _hide_presentation_pass() -> void:
	# The proof is the production world response, not an objective, radio bug,
	# crosshair or held-tool caption. Keep every 3D owner live and suppress only
	# the presentation canvases that would cover the radiator.
	for node in root.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false


func _settle(frames: int) -> void:
	for _frame in frames:
		await get_tree().process_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var out_dir := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var error := get_viewport().get_texture().get_image().save_png(
			out_dir.path_join(label + ".png"))
	if error != OK:
		push_error("Dream Service Answer shot failed: %s" % label)
