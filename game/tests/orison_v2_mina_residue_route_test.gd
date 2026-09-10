extends "res://tests/orison_v2_golden_repair_route_test.gd"
## Focused kitchen route from an actually earned and completed-wake save.
func _init() -> void:
	route_label = "V2 MINA PHYSICAL RESIDUE"
func _route() -> void:
	var fridge := world.adapter.resolve(MinaCaptionManifestation.RESIDUE_ANCHOR_ID) as FridgeProp
	if not _require(fridge!=null and fridge.monitor_top and fridge.unit=="2A","actual 2A refrigerator is mounted"): return
	var display: Node3D = fridge.find_child(MinaCaptionManifestation.RESIDUE_SOCKET_ID,true,false)
	if not _require(display!=null and not display.visible,"unearned residue stays hidden"): return
	var source := OS.get_environment("V2_EARNED_SAVE")
	if not _require(FileAccess.file_exists(source),"earned wake input exists"): return
	var previous: String = RealityState.save_path
	RealityState.save_path = source
	RealityState.load_game()
	RealityState.save_path = previous
	if not _require(display.visible and RealityState.has_waking_residue(MinaCaptionManifestation.RESIDUE_ID),"real loaded wake reveals the physical caption"): return
	if not await _enter_2a(): return
	for point in [Vector3(-10.5,3.2,2.5),Vector3(-12,3.2,2.5),Vector3(-12,3.2,3.7),Vector3(-11.2,3.2,4.42)]:
		if not await _walk(point): return
	var pose: Transform3D = display.global_transform
	var door: Node3D = fridge.get("_door")
	_require(display.get_parent()==door,"caption belongs to the moving food door")
	if not await _use(fridge,fridge.to_global(Vector3(.25,.8,-.4)),"refrigerator_closed"): return
	await get_tree().create_timer(.7).timeout
	_require(fridge.get("_open") and display.global_position.distance_to(pose.origin)>.15,
			"physical opening carries the caption with the door")
	await _capture("refrigerator_open",display.global_position)
	if not await _use(fridge,fridge.to_global(Vector3(0,.8,0)),"refrigerator_close"): return
	await get_tree().create_timer(.7).timeout
	_require(not fridge.get("_open") and display.global_transform.is_equal_approx(pose),"door closure restores the caption transform")
	await _capture("refrigerator_restored",display.global_position)
	var snapshot := RealityState.waking_residue(MinaCaptionManifestation.RESIDUE_ID).duplicate(true)
	world.mina_gameplay.bind_wake(world.core_loop)
	_require(RealityState.waking_residue(MinaCaptionManifestation.RESIDUE_ID)==snapshot,"door interaction leaves the factual record unchanged")

	for point in [Vector3(-12,3.2,4.42),Vector3(-12,3.2,3.7),Vector3(-12,3.2,2.5),Vector3(-13.4,3.2,2.5),Vector3(-13.4,3.2,-1.5),Vector3(-11.8,3.2,-1.5)]:
		if not await _walk(point): return
	var subjects: Array[Node3D] = [world.adapter.resolve("2A_sofa"),world.adapter.resolve("F02_A_CaptionDesk"),world.adapter.resolve("F02_A_MAIN_WINDOW_W_S"),world.mina_routine.actor]
	var state := RealityState.case_state(MinaCaptionManifestation.CASE_ID)
	for stage in ["active","reopened","stabilized","resolved"]:
		# Explicit presentation controls, after the earned-save physical route.
		state.stage = stage
		state.resolved = stage=="resolved"
		state.recurrence_count = 0 if stage=="active" else 1
		RealityState.commit()
		for i in subjects.size():
			var caption := subjects[i].get_node("MinaCaseCaption") as Label3D
			_require(caption.visible==(stage in ["active","reopened"]),"caption visibility "+stage+"/"+str(i))
			var expected: String = MinaCaptionManifestation.CAPTIONS[i].noun if stage=="active" else MinaCaptionManifestation.CAPTIONS[i].claim
			_require(caption.text==expected,"authored caption text "+stage+"/"+str(i))
		await _capture("captions_"+stage,subjects[0].global_position+Vector3.UP*.6)
	_require(display.visible,"resolution restores the already-earned refrigerator residue")
