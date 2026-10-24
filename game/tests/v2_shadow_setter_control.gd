extends Node3D
## INERT exact-engine control for redundant shadow setter invalidation.
var samples: Array=[]
var checks: Array=[]
var failures: Array=[]
var motion_updates: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok:failures.append(label)
func _ready() -> void:run.call_deferred()
func run() -> void:
	for fixture: Node in [CeilingLightProp.new(),LampProp.new(),LightFixtureProp.new()]:
		var primary: Light3D=SpotLight3D.new() if fixture is LampProp else OmniLight3D.new()
		fixture.light=primary;fixture.add_child(primary)
		if fixture is LightFixtureProp:
			fixture._entry_spot=SpotLight3D.new();fixture.add_child(fixture._entry_spot)
		for desired: bool in [false,true,true,false,false,true]:
			fixture.set_budget(1.,false,desired)
			check(primary.shadow_enabled==desired and primary.visible,"budget state/transition: "+str(fixture.get_script().resource_path)+" "+str(desired))
			if fixture is LightFixtureProp:check(fixture._entry_spot.shadow_enabled==desired and fixture._entry_spot.visible,"entry spot matches primary budget")
		if fixture is LightFixtureProp:
			fixture.set_powered(false);fixture.set_budget(1.,false,true)
			check(not primary.visible and not fixture._entry_spot.visible and not fixture.is_locally_enabled(),"power authority still refuses budget illumination")
		if fixture is LampProp:
			fixture._local_enabled=false;fixture.set_budget(1.,false,true)
			check(not primary.visible,"local lamp switch still refuses budget illumination")
		fixture.free()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var camera:=Camera3D.new();camera.position=Vector3(0,5,7);add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
	var light:=OmniLight3D.new();light.position=Vector3(0,3,0);light.omni_range=10.;light.shadow_enabled=true;light.omni_shadow_mode=OmniLight3D.SHADOW_CUBE;add_child(light)
	var mesh:=BoxMesh.new();mesh.size=Vector3(.22,.5,.22)
	var first_draw: MeshInstance3D
	for i in 400:
		var draw:=MeshInstance3D.new();draw.mesh=mesh;draw.position=Vector3((i%20-10)*.24,0,(i/20-10)*.24);add_child(draw)
		if first_draw==null:first_draw=draw
	var rid:=get_viewport().get_viewport_rid();RenderingServer.viewport_set_measure_render_time(rid,true)
	var budget_fixture:=CeilingLightProp.new();budget_fixture.light=light
	for phase: String in ["stable_a","repeat","stable_b","budget_repeat","stable_c","guarded"]:
		for frame in 40:
			if phase=="repeat":light.shadow_enabled=true
			if phase=="guarded" and not light.shadow_enabled:light.shadow_enabled=true
			if phase=="budget_repeat":budget_fixture.set_budget(1.,false,true)
			await RenderingServer.frame_post_draw
		var before:=Time.get_ticks_usec()
		for frame in 120:
			if phase=="repeat":light.shadow_enabled=true
			if phase=="guarded" and not light.shadow_enabled:light.shadow_enabled=true
			if phase=="budget_repeat":budget_fixture.set_budget(1.,false,true)
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			samples.append({"phase":phase,"wall_ms":(now-before)/1000.,"shadow":light.shadow_enabled,"shadow_draws":RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)});before=now
	# Correctness counts only: genuine movement/flag changes must invalidate
	# cached maps without repeated assignment of the unchanged flag.
	for reason: String in ["geometry_motion","light_motion","budget_off_on"]:
		for frame in 30:await RenderingServer.frame_post_draw
		if reason=="geometry_motion":first_draw.position.x+=.1
		elif reason=="light_motion":light.position.x+=.1
		else:
			budget_fixture.set_budget(1.,false,false)
			await RenderingServer.frame_post_draw
			budget_fixture.set_budget(1.,false,true)
		var counts: Array=[]
		for frame in 8:
			await RenderingServer.frame_post_draw
			counts.append(RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		check(counts.max()>0 and light.shadow_enabled,"real change refreshes shadow cache: "+reason)
		motion_updates.append({"reason":reason,"shadow_draws":counts})
	var out:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join("setter_control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Static isolated scene, unchanged true shadow flag in timed phases. Actual budget method and three fixture classes exercise transitions. Genuine motion refresh counts are correctness controls. Exact-engine control, not V2 performance or human acceptance.","samples":samples,"checks":checks,"failures":failures,"motion_updates":motion_updates},"\t"))
	budget_fixture.free();print("SHADOW SETTER CONTROL: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks.size()," samples=",samples.size())
	get_tree().quit(0 if failures.is_empty() else 1)
