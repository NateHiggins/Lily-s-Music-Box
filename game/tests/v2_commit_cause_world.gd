extends "res://tests/v2_hose_work_attribution.gd"
## INERT same played route. No commit scheduling or durability changes.
var render_pass_samples: Array = []
func _process(delta: float) -> void:
	super._process(delta)
	if not profile_active:return
	var started:=Time.get_ticks_usec()
	var rid:=get_viewport().get_viewport_rid()
	var passes: Dictionary={}
	for kind in [RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW]:
		passes[str(kind)]=[RenderingServer.viewport_get_render_info(rid,kind,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),RenderingServer.viewport_get_render_info(rid,kind,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),RenderingServer.viewport_get_render_info(rid,kind,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)]
	render_pass_samples.append({"process_frame":Engine.get_process_frames(),"phase":profile_phase,"passes":passes,"setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),"probe_usec":Time.get_ticks_usec()-started})

func _save_reload(wanted: Dictionary) -> void:
	profile_active=false
	# One untimed inventory, never a second per-frame target or world scan.
	var lights: Array=[]
	for node: Node in world.find_children("*","Light3D",true,false):
		var light:=node as Light3D
		var at: Vector3=light.global_position
		lights.append({"path":str(light.get_path()),"type":light.get_class(),"visible":light.is_visible_in_tree(),"shadow":light.shadow_enabled,"position":[at.x,at.y,at.z],"energy":light.light_energy,"range":light.get_param(Light3D.PARAM_RANGE)})
	var eye: Vector3=player.camera.global_position
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("render_passes.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Root viewport visible(0)/shadow(1) counters lag rendering. Values are objects/primitives/draw calls; primitives include points, lines or triangles. Untimed light inventory is at route end, not causal per-light timing.","samples":render_pass_samples,"lights":lights,"eye":[eye.x,eye.y,eye.z]},"\t"))
	var owner: Node=world.household_state
	var causes: Array=owner.profile_causes.duplicate(true)
	var useful:=not causes.is_empty()
	for row: Dictionary in causes:
		useful=useful and not row.changed.is_empty() and not row.stack.is_empty()
	_check(useful,"diagnostic commit origins identify changed subjects and call stacks")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("commit_causes.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Changed IDs and call origins for synchronous household commits in the actual route. No scheduling change. CPU overhead separately recorded; render CPU/GPU measurements lag their frame.","causes":causes},"\t"))
	await super._save_reload(wanted)
