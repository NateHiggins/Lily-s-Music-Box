extends "res://tests/v2_hose_installed_world.gd"
## INERT occupied-world idle controls, followed by the inherited input route.
var _walk_count:=0

func _walk(target: Vector3) -> bool:
	var ok: bool=await super._walk(target)
	_walk_count+=1
	if ok and _walk_count==5:await _idle_controls()
	return ok

func _idle_controls() -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var helpers: Array[Node]=[]
	var original: Array[bool]=[]
	for reference: WeakRef in native.stations.values():
		var cabinet: Node3D=reference.get_ref()
		for name: String in ["NativeContinuousFolds","NativeHoseRack","NativeHoseRuns"]:
			var node: Node=cabinet.get_node(name)
			helpers.append(node);original.append(node.is_processing())
	var treatments: Array=[]
	for treatment: String in ["original_a","polling_disabled","original_b"]:
		for index in helpers.size():helpers[index].set_process(false if treatment=="polling_disabled" else original[index])
		profile_phase="idle_visual_"+treatment
		for frame in 24:await RenderingServer.frame_post_draw
		var intervals: Array=[]
		var previous:=Time.get_ticks_usec()
		for frame in 120:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec();intervals.append((now-previous)/1000.);previous=now
		treatments.append({"name":treatment,"wall_ms":intervals})
	# Direct-call cost is deliberately excluded from the stationary samples.
	profile_phase="capture_excluded_idle_call_cost"
	var calls: Array=[]
	for sample in 60:
		await get_tree().process_frame
		var started:=Time.get_ticks_usec()
		for node: Node in helpers:node._process(0.)
		calls.append((Time.get_ticks_usec()-started)/1000.)
	var enabled:=0
	for flag: bool in original:
		if flag:enabled+=1
	if OS.get_environment("V2_EXPECT_IDLE_HOSE_VISUALS")=="0":
		_check(enabled==0,"all24 stored native hose visual helpers have no scheduled idle callback")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("idle_visuals.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual occupied F02 standing view. Interleaved stationary control; direct calls are separate diagnostic work, not FPS evidence or runtime qualification.","helpers":helpers.size(),"scheduled_original":enabled,"treatments":treatments,"manual_all_helpers_ms":calls},"\t"))
