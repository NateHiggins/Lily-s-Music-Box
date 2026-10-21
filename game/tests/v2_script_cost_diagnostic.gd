extends "res://tests/v2_tick_cost_diagnostic.gd"
## Refine the measured architectural callback cost without removing collision.
func _init() -> void: route_label="V2 SCRIPT COST DIAGNOSTIC"

func _route() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	player.velocity=Vector3.ZERO;player.set_physics_process(false)
	var shadow: Node3D=world.get_node("LampAtmosphere").scene_shadow
	RenderingServer.viewport_set_measure_render_time(shadow.viewport.get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var groups: Dictionary={}
	for node: Node in world.find_children("*","",true,false):
		if node.get_script()==null or (not node.is_processing() and not node.is_physics_processing()):continue
		var path: String=node.get_script().resource_path
		if not groups.has(path):groups[path]=[]
		groups[path].append([weakref(node),node.is_processing(),node.is_physics_processing()])
	var singletons:=OS.get_environment("ORISON_SCRIPT_COST_SINGLETONS")=="1"
	var selected: Array=groups.keys().filter(func(path):return groups[path].size()<3 if singletons else groups[path].size()>=3)
	selected.sort_custom(func(a,b):return groups[a].size()>groups[b].size())
	var counts: Dictionary={}
	for path: String in selected:counts[path]=groups[path].size()
	await _sample("live",counts)
	var index:=0
	for path: String in selected:
		for entry: Array in groups[path]:
			var node: Node=entry[0].get_ref()
			if is_instance_valid(node):node.set_process(false);node.set_physics_process(false)
		await _sample("without_script:"+path,{path:groups[path].size()})
		for entry: Array in groups[path]:
			var node: Node=entry[0].get_ref()
			if is_instance_valid(node):node.set_process(entry[1]);node.set_physics_process(entry[2])
		index+=1
		if index%5==0:await _sample("live_control_"+str(index),null)
	await _sample("live_restored",null)
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("script_cost.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","groups":counts,"samples":rows,"failures":failures},"\t"))
