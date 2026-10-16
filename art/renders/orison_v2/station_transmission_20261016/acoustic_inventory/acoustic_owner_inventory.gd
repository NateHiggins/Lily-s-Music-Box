extends SceneTree
## Read-only migration inventory. INERT: no propagation or acceptance claim.
var output := ""
func _initialize() -> void:
	output = OS.get_environment("SHOT_DIR")
	call_deferred("_run")

func _run() -> void:
	if output.is_empty():
		printerr("Acoustic inventory requires SHOT_DIR")
		quit(2)
		return
	var graph = root.get_node("AcousticGraphData")
	var reality = root.get_node("RealityState")
	reality.persistence_enabled = false
	reality.reset_campaign_for_tests()
	var original: Dictionary = graph.nodes.duplicate(true)
	var selector = load("res://scripts/building/building_root_selector.gd")
	selector.reset_for_tests("v2")
	var world = (load(selector.scene_path()) as PackedScene).instantiate()
	root.add_child(world)
	await create_timer(.5).timeout
	if world.startup_failed:
		printerr("Acoustic inventory: production startup failed")
		world.queue_free()
		quit(1)
		return
	var names := {}
	var consumers: Array[Dictionary] = []
	var explicit_bindings: Array[Dictionary] = []
	var all: Array[Node] = [world]
	while not all.is_empty():
		var node: Node = all.pop_back()
		for child: Node in node.get_children(): all.append(child)
		if not node is Node3D: continue
		var identity := str(node.name)
		var script: Script = node.get_script()
		var row := {"path":str(world.get_path_to(node)),"name":identity,
			"position_godot":[node.global_position.x,node.global_position.y,node.global_position.z],
			"script":script.resource_path if script else ""}
		# Inspect declared bindings, including mechanisms outside FunctionalProp.
		# These are candidate identities, not inferred network ownership.
		for property: Dictionary in node.get_property_list():
			var key := str(property.name)
			if key not in ["graph_node_id", "acoustic_node_id", "acoustic_id"]: continue
			var value = node.get(key)
			if value is String and not value.is_empty():
				var binding := row.duplicate(true)
				binding["property"] = key
				binding["identity"] = value
				explicit_bindings.append(binding)
		if original.has(identity):
			if not names.has(identity): names[identity] = []
			names[identity].append(row)
		# --script is compiled before autoload singleton names are registered.
		# Inspect the already-loaded ancestry instead of preloading prop classes.
		var ancestor: Script = script
		var functional := false
		while ancestor != null:
			if ancestor.resource_path == "res://scripts/props/functional_prop.gd":
				functional = true
				break
			ancestor = ancestor.get_base_script()
		if functional:
			row["graph_node_id"] = str(node.graph_node_id)
			row["prop_type"] = str(node.prop_type)
			consumers.append(row)
	var records: Array[Dictionary] = []
	var identities := original.keys()
	identities.sort()
	for identity: String in identities:
		var authored: Dictionary = original[identity]
		var composed: Dictionary = graph.nodes.get(identity,{})
		var row := {"id":identity,"legacy":authored,"composed":composed.duplicate(true),
			"named_owners":names.get(identity,[]),"bound_consumers":[]}
		for consumer: Dictionary in consumers:
			if consumer.graph_node_id == identity: row.bound_consumers.append(consumer)
		records.append(row)
	var new_consumers: Array[Dictionary] = []
	for consumer: Dictionary in consumers:
		if not consumer.graph_node_id.is_empty() and not original.has(consumer.graph_node_id): new_consumers.append(consumer)
	var report := {"evidence_class":"INERT","schema":"orison.v2-acoustic-owner-inventory.v1",
		"scope":"Observed names, prop bindings and coordinates only. Does not prove topology, audibility, physical pipe continuity, case behavior or acceptance.",
		"graph_coordinate_convention":"Legacy pos is Blender x,y,z; position_godot is x,y,z after GameBoot.b2g.",
		"nodes":records,"functional_consumers":consumers,"explicit_bindings":explicit_bindings,
		"consumers_without_legacy_graph_node":new_consumers,
		"observer_sha256":FileAccess.get_sha256(get_script().resource_path),
		"legacy_graph_sha256":FileAccess.get_sha256("res://data/acoustic_graph.json")}
	world.shutdown_for_tests()
	root.remove_child(world)
	world.free()
	await process_frame
	await process_frame
	report["graph_restored_exactly"] = graph.nodes == original
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("acoustic_owners.json"),FileAccess.WRITE)
	if file == null:
		printerr("Acoustic inventory output unavailable")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	print("ACOUSTIC OWNER INVENTORY: nodes=",records.size()," functional=",consumers.size()," graph_restored=",report.graph_restored_exactly)
	quit(0 if ok and report.graph_restored_exactly else 1)
