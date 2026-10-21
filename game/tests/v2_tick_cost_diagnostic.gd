extends "res://tests/orison_v2_vertical_route_test.gd"
## Diagnostic interventions only. All modes are restored; this proves no gameplay.
var rows: Array=[]

func _init() -> void: route_label="V2 TICK COST DIAGNOSTIC"

func _route() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	player.velocity=Vector3.ZERO
	player.set_physics_process(false)
	var branches: Array=[]
	for child in world.get_children():
		var callbacks:=0
		var scripts: Dictionary={}
		var flags: Array=[]
		var nodes: Array=[child];nodes.append_array(child.find_children("*","",true,false))
		for node: Node in nodes:
			if node.get_script()==null or (not node.is_processing() and not node.is_physics_processing()): continue
			var path: String=node.get_script().resource_path
			scripts[path]=int(scripts.get(path,0))+1;callbacks+=1
			flags.append([weakref(node),node.is_processing(),node.is_physics_processing()])
		branches.append({"node":child,"name":str(child.name),"flags":flags,"callbacks":callbacks,"scripts":scripts})
	branches.sort_custom(func(a,b):return a.callbacks>b.callbacks)
	# Test the six largest callback owners plus the lamp's distinct CPU/GPU path.
	var selected: Array=branches.slice(0,mini(6,branches.size()))
	var shadow: Node3D=world.get_node("LampAtmosphere").scene_shadow
	RenderingServer.viewport_set_measure_render_time(shadow.viewport.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var solids: Node=world.get_node("V2StructuralOcclusion")
	await _sample("live",null)
	for branch: Dictionary in selected:
		for entry: Array in branch.flags:
			var node: Node=entry[0].get_ref()
			if is_instance_valid(node):node.set_process(false);node.set_physics_process(false)
		await _sample("without_ticks:"+branch.name,branch.scripts)
		for entry: Array in branch.flags:
			var node: Node=entry[0].get_ref()
			if is_instance_valid(node):node.set_process(entry[1]);node.set_physics_process(entry[2])
	world.process_mode=Node.PROCESS_MODE_DISABLED
	await _sample("frozen",null)
	var original_atlas: int=shadow.viewport.positional_shadow_atlas_size
	shadow.viewport.positional_shadow_atlas_size=0
	await _sample("frozen_shadow_atlas_zero",null)
	shadow.viewport.positional_shadow_atlas_size=original_atlas
	shadow.viewport.use_occlusion_culling=true
	await _sample("frozen_shadow_occlusion",null)
	for reference: WeakRef in solids.sources:
		var draw: MeshInstance3D=reference.get_ref()
		if is_instance_valid(draw):draw.ignore_occlusion_culling=false
	await _sample("frozen_all_wall_occlusion",null)
	for reference: WeakRef in solids.sources:
		var draw: MeshInstance3D=reference.get_ref()
		if is_instance_valid(draw):draw.ignore_occlusion_culling=true
	shadow.viewport.use_occlusion_culling=false
	world.process_mode=Node.PROCESS_MODE_INHERIT
	await _sample("live_restored",null)
	var inventory: Array=[]
	for branch: Dictionary in branches:
		var item:=branch.duplicate();item.erase("node");item.erase("flags");inventory.append(item)
	FileAccess.open(directory.path_join("tick_cost.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","branches":inventory,"samples":rows},"\t"))

func _sample(label: String, scripts: Variant) -> void:
	var stance:=player.global_transform
	for i in 30: await get_tree().process_frame
	var samples: Array=[]
	for i in 90:
		var started:=Time.get_ticks_usec()
		await get_tree().process_frame
		var shadow: Node3D=world.get_node("LampAtmosphere").scene_shadow
		samples.append([(Time.get_ticks_usec()-started)/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_cpu(shadow.viewport.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(shadow.viewport.get_viewport_rid())])
	rows.append({"label":label,"scripts":scripts,"samples":samples})
	var ordered: Array=samples.map(func(x):return x[0]);ordered.sort()
	print("TICK COST ",label," p50_ms=",ordered[int(ordered.size()/2)]," p95_ms=",ordered[int(ordered.size()*.95)])
	check_station(stance,label)

func check_station(stance: Transform3D, label: String) -> void:
	if not player.global_transform.is_equal_approx(stance):
		failures.append("camera station changed during "+label)
