extends Node
## SR4 visual proof: the production building and held 28-R show an unchanged
## no-call control, then the persistent Lena line slip and protected dialogue.

var root: Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.ensure_case(ServiceRoundDirector.CASE_ID,
			ServiceRoundDirector.RESIDENT_ID)
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	root = scene.instantiate()
	add_child(root)
	await _settle(8)
	root.service_set_carrier.set_proof_pose(2)
	await _settle(3)
	await _capture("01_no_call_control_a")
	await _capture("02_no_call_control_b")
	_close_previous_job()
	await _settle(3)
	await _capture("03_lena_line_waiting")
	root.service_round.answer_incoming_call()
	await _settle(3)
	await _capture("04_lena_call_answered")
	root.service_round.dialogue.choose(0)
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	await _settle(3)
	await _capture("05_lena_threshold_conversation")
	print("[SERVICE ROUND ROUTE SHOT] production A/A and call frames saved")
	get_tree().quit(0)


func _close_previous_job() -> void:
	var orders: WorkOrders = root.work_orders
	const JOB := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(JOB, "reported")
	orders.acknowledge_job(JOB)
	orders.diagnose_job(JOB)
	orders.mark_job_awaiting_part(JOB)
	orders.mark_job_repairable(JOB)
	orders.record_job_repair(JOB, {"quality": "good", "note": "proof gate"})
	orders.close_job(JOB)


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
		push_error("Service Round route shot failed: %s" % label)
