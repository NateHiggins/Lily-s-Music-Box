extends RefCounted
## Source-derived steam graph; the existing acoustic owner holds its lease.
const DATA := "res://data/orison_v2/acoustic_heating.json"
var errors: Array[String] = []
var local_nodes := {}
var routes: Array = []

func _reject(message: String) -> bool:
	errors.append(message)
	return false

func merge_into(merged: Dictionary, adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is not Dictionary or data.get("schema_version")!=1 or data.get("network")!="heating" or data.get("coordinate_frame")!="blockout_local_blender":return _reject("Invalid physical heating schema")
	for binding: Dictionary in data.get("source_bindings",[]):
		var path := str(binding.get("path",""))
		if not path.begins_with("res://") or ".." in path or not FileAccess.file_exists(path) or binding.get("normalize_lines") is not bool:return _reject("Missing heating source: "+path)
		var bytes := FileAccess.get_file_as_bytes(path)
		if binding.normalize_lines:bytes=bytes.get_string_from_utf8().replace("\r\n","\n").to_utf8_buffer()
		var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		if hash.finish().hex_encode()!=binding.get("sha256"):return _reject("Stale heating source: "+path)
	if data.get("source_bindings",[]).size()!=8:return _reject("Missing bound heating sources")
	if data.get("retirements")!=[]:return _reject("Unexpected heating retirement")
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/acoustic_graph.json"))
	var old := {};var rooms := {};var legacy_external := {}
	for row: Dictionary in original.nodes:
		if row.network=="heating":old[str(row.id)]=row
	for row: Dictionary in layout.spaces:rooms[str(row.id)]=true
	for row: Dictionary in layout.levels:rooms[str(row.id)]=true
	for identity: String in old:
		for target: String in old[identity].connections:
			if not old.has(target):legacy_external[identity+"|"+target]=true
	for row: Dictionary in data.get("nodes",[]):
		var identity := str(row.get("id",""))
		if local_nodes.has(identity) or row.get("network")!="heating" or not rooms.has(str(row.get("room",""))):return _reject("Invalid heating node: "+identity)
		if old.has(identity):
			for key: String in ["frequency_band","delay_ms","damping","infection_receptivity"]:
				if row.get(key)!=old[identity].get(key):return _reject("Heating tuning changed: "+identity)
		elif not identity.begins_with("V2_HEAT_") or row.get("transit_only")!=true or row.get("delay_ms")!=0 or row.get("damping")!=0 or row.get("infection_receptivity")!=0:return _reject("Invalid passive heating junction")
		if row.get("physical_role") not in ["boiler","receiver_west","receiver_east"] and row.get("riser") not in ["H-A","H-B","H-C","H-D"]:return _reject("Invalid physical steam main")
		local_nodes[identity]=row
	for identity: String in old:
		if not local_nodes.has(identity):return _reject("Legacy heating identity lost: "+identity)
	var edges := {};var actual_external := {}
	for route: Dictionary in data.get("routes",[]):
		var a := str(route.get("start",""));var b := str(route.get("end",""))
		if a==b or not local_nodes.has(a) or not local_nodes.has(b) or route.get("points_local_godot",[]).size()<2:return _reject("Invalid physical heating edge")
		var key := "|".join([a,b] if a<b else [b,a])
		if edges.has(key):return _reject("Duplicate heating route")
		edges[key]=true
	for identity: String in local_nodes:
		for target: String in local_nodes[identity].connections:
			if local_nodes.has(target):
				if identity not in local_nodes[target].connections or not edges.has("|".join([identity,target] if identity<target else [target,identity])):return _reject("Heating edge lacks a physical route")
			else:
				if not merged.has(target):return _reject("Heating bridge target absent")
				actual_external[identity+"|"+target]=true
	var declared_external := {}
	for bridge: Dictionary in data.get("external_bridges",[]):
		var key := str(bridge.get("start",""))+"|"+str(bridge.get("end",""))
		if declared_external.has(key):return _reject("Duplicate external bridge declaration")
		declared_external[key]=true
	if declared_external!=legacy_external:return _reject("External bridge declaration differs from retained graph")
	if legacy_external!=actual_external:return _reject("Authored cross-network heating bridges changed")
	for identity: String in merged.keys():
		if merged[identity].get("network")=="heating":merged.erase(identity)
	for identity: String in local_nodes:
		var row: Dictionary=local_nodes[identity].duplicate(true)
		var point := Vector3(row.pos[0],row.pos[2],-row.pos[1])
		var world: Vector3=(adapter.root as Node3D).to_global(point)
		row.pos=[world.x,-world.z,world.y];merged[identity]=row
	routes=data.routes
	return true

func physical_owners_valid(adapter: OrisonV2AnchorAdapter) -> bool:
	for route: Dictionary in routes:
		var owner := adapter.root.get_node_or_null(NodePath(str(route.owner))) as Node3D
		if owner==null:return _reject("Missing installed heating stock: "+str(route.owner))
		if route.has("terminal_carrier"):
			var carrier := adapter.resolve(str(route.terminal_carrier)) as FunctionalProp
			if carrier==null or carrier.graph_node_id!=str(route.terminal_carrier):return _reject("Unbound heating appliance")
	for identity: String in local_nodes:
		if local_nodes[identity].physical_role not in ["radiator","boiler"]:continue
		var carrier := adapter.resolve(identity) as Node3D
		if carrier==null or carrier.global_position.distance_to(AcousticGraphData.node_pos(identity))>.001:return _reject("Heating graph differs from actual carrier: "+identity)
	return true
