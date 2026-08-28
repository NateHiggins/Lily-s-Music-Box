extends Node

const RUNTIME := preload("res://scenes/building/orison_v2_runtime.tscn")

var failures := 0
var passes := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := RUNTIME.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	var radiator := world.find_child(ServiceRoundDirector.RADIATOR_ID,
			true, false) as RadiatorProp
	_check(radiator != null and radiator.section_count == 10,
			"F02_B_RADIATOR_01 is one ten-section mechanical authority")
	var old_mass := world.find_child("F02_B_RADIATOR_MASS", true, false) as Node3D
	var old_use := world.find_child("F02_B_RADIATOR_USE", true, false) as Node3D
	_check(old_mass != null and not old_mass.visible and old_use != null \
			and not old_use.visible,
			"placeholder mass and display envelope retire under real composition")
	var bounds := _visual_bounds(radiator)
	_check(absf(bounds.position.y - 3.2) <= 0.025,
			"cast feet contact the F02 floor")
	_check(bounds.end.x < 15.60 and bounds.end.x > 15.46,
			"assembly stands off the exterior wall without floating")
	var castings := radiator.find_child("SharedCastSections", true,
			false) as MultiMeshInstance3D
	var body_bounds := castings.global_transform * castings.get_aabb()
	_check(body_bounds.position.z > -3.55 and body_bounds.end.z < -2.56,
			"body clears the F02_B_MAIN window opening")
	_check(bounds.size.y <= 0.86 and bounds.size.x <= 0.38
			and bounds.size.z <= 1.55,
			"installed envelope is bounded and avoids private-use circulation")
	var valve := radiator.find_child("TurnValveSurface", true, false) as Node3D
	var union := radiator.find_child("InspectUnionSurface", true, false) as Node3D
	var stance := radiator.global_transform * Vector3(0.0, -0.75, -1.0)
	_check(valve and valve.global_position.distance_to(stance) < 1.35,
			"visible valve is reachable from the accepted service stance")
	_check(union and union.global_position.distance_to(stance) < 1.35,
			"union and packing are reachable from the accepted service stance")
	var prompts: Array[String] = []
	for node: Node in radiator.find_children("*Surface", "", true, false):
		if node.has_method("interact_prompt"):
			prompts.append(str(node.call("interact_prompt")))
	_check(prompts.size() == 7 and prompts.has("Turn supply valve")
			and prompts.has("Inspect union and packing")
			and prompts.has("Listen at radiator"),
			"seven public surfaces name immediate physical actions")
	var commit_surface := radiator.find_child("CommitRepairSurface", true,
			false)
	_check(commit_surface.interact_prompt().is_empty(),
			"repair commit is absent before concrete prerequisites")
	world.work_orders.issue_job(ServiceRoundDirector.JOB_ID, "reported")
	world.work_orders.acknowledge_job(ServiceRoundDirector.JOB_ID)
	for evidence: String in ["radiator_airbound", "lobby_contact_compared",
			"boiler_pressure_compared"]:
		world.work_orders.record_job_evidence(ServiceRoundDirector.JOB_ID, evidence)
	world.work_orders.diagnose_job(ServiceRoundDirector.JOB_ID)
	world.work_orders.mark_job_repairable(ServiceRoundDirector.JOB_ID)
	_check(commit_surface.interact_prompt() == "Seat union and test radiator",
			"repair commit appears after physical diagnosis prerequisites")
	var state_expectations := {
		"sounding": func(r): return r.warm_sections > 1 and not r.union_open,
		"worsening_hammer": func(r): return r.warm_sections > 1,
		"wrong_valve_partial": func(r): return r.supply_position == 0.42 \
				and r.warm_sections < radiator.section_count,
		"opened_uncommitted": func(r): return r.union_open and r.vapor_visible \
				and r.damp_visible,
		"porter_temporary_shutoff": func(r): return r.supply_position == 0.0 \
				and r.porter_tag_visible,
		"repaired": func(r): return not r.union_open and not r.vapor_visible \
				and r.warm_sections >= 8,
		"cooling": func(r): return r.supply_position == 0.0 \
				and not r.porter_tag_visible,
	}
	for condition: String in state_expectations:
		radiator.apply_open_shift_condition(condition)
		var receipt := radiator.visual_state_receipt()
		_check(bool(state_expectations[condition].call(receipt)),
				"%s reconstructs its correct visual mechanism state" % condition)
	var mesh_nodes := radiator.find_children("*", "MeshInstance3D", true, false)
	var multimeshes := radiator.find_children("*", "MultiMeshInstance3D", true, false)
	var materials := {}
	for node: Node in mesh_nodes:
		var mesh_node := node as MeshInstance3D
		if mesh_node.material_override:
			materials[mesh_node.material_override.get_rid()] = true
	if castings.multimesh.mesh.surface_get_material(0):
		materials[castings.multimesh.mesh.surface_get_material(0).get_rid()] = true
	print("  COST  multimeshes=%d mesh_instances=%d materials=%d" % [
			multimeshes.size(), mesh_nodes.size(), materials.size()])
	_check(multimeshes.size() == 1 and mesh_nodes.size() <= 20
			and materials.size() <= 16,
			"shared sections keep mesh, material and draw cost bounded")
	var detached := false
	for node: Node in mesh_nodes + multimeshes:
		if not radiator.is_ancestor_of(node) or (node as Node3D).global_position \
				.distance_to(radiator.global_position) > 2.0:
			detached = true
	_check(not detached, "no pipe or decorative geometry is detached")
	world.shutdown_for_tests()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("RADIATOR REBUILD TEST: %d PASS / %d FAIL" % [passes, failures])
	get_tree().quit(failures)


func _visual_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
			continue
		var local := mesh_node.mesh.get_aabb()
		var global := mesh_node.global_transform * local
		result = global if not initialized else result.merge(global)
		initialized = true
	for node: Node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := node as MultiMeshInstance3D
		var global := mm.global_transform * mm.get_aabb()
		result = global if not initialized else result.merge(global)
		initialized = true
	return result


func _check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
