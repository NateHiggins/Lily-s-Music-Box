extends RefCounted
## Reversible physical flue topology, merged into the existing shared lease.
const DATA="res://data/orison_v2/acoustic_flue.json"
var errors: Array[String]=[]
var local_nodes: Dictionary={}
var routes: Array=[]
var bridges: Array=[]
func _reject(message: String) -> bool:
	errors.append(message);return false
func _point(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])

func merge_into(merged: Dictionary,adapter: OrisonV2AnchorAdapter,layout: Dictionary) -> bool:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data.get("schema_version")!=1 or data.get("network")!="flue" or data.get("coordinate_frame")!="blockout_local_blender":return _reject("Invalid flue schema")
	if data.get("source_bindings",[]).size()!=8:return _reject("Missing flue source closure")
	for binding: Dictionary in data.source_bindings:
		var path:=str(binding.get("path",""))
		if not path.begins_with("res://") or ".." in path or not FileAccess.file_exists(path) or binding.get("normalize_lines") is not bool:return _reject("Invalid flue source path")
		var raw:=FileAccess.get_file_as_bytes(path)
		if binding.normalize_lines:raw=raw.get_string_from_utf8().replace("\r\n","\n").to_utf8_buffer()
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
		if hash.finish().hex_encode()!=binding.sha256:return _reject("Stale flue source: "+path)
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/acoustic_graph.json"));var old: Dictionary={};var rooms: Dictionary={}
	for row: Dictionary in legacy.nodes:
		if row.network=="flue":old[str(row.id)]=row
	for row: Dictionary in layout.spaces:rooms[str(row.id)]=true
	for row: Dictionary in layout.levels:rooms[str(row.id)]=true
	for row: Dictionary in data.nodes:
		var identity:=str(row.id)
		if local_nodes.has(identity) or row.network!="flue" or not rooms.has(str(row.room)) or not GameBoot.b2g(row.pos).is_finite():return _reject("Invalid flue carrier: "+identity)
		if row.physical_role not in ["boiler_column","thimble","stove_column","masonry_transfer"]:return _reject("Unknown flue role")
		if old.has(identity):
			for key: String in ["frequency_band","delay_ms","damping","infection_receptivity"]:
				if row.get(key)!=old[identity].get(key):return _reject("Flue tuning changed: "+identity)
		elif not identity.begins_with("V2_FLUE_") or row.get("transit_only")!=true or row.delay_ms!=0 or row.damping!=0 or row.infection_receptivity!=0:return _reject("Invalid passive flue carrier")
		local_nodes[identity]=row
	for identity: String in old:
		if not local_nodes.has(identity):return _reject("Legacy flue carrier omitted")
	var edges: Dictionary={}
	for route: Dictionary in data.routes:
		var a:=str(route.start);var b:=str(route.end)
		if a==b or not local_nodes.has(a) or not local_nodes.has(b) or route.owners.is_empty() or route.points_local_godot.size()<2:return _reject("Invalid physical flue route")
		if route.kind not in ["boiler_airway","stove_airway","sealed_thimble","stove_wall","structural_slab","boiler_wall"]:return _reject("Unknown acoustic carrier material")
		var points: Array=route.points_local_godot
		if _point(points[0]).distance_to(GameBoot.b2g(local_nodes[a].pos))>.00001 or _point(points.back()).distance_to(GameBoot.b2g(local_nodes[b].pos))>.00001:return _reject("Flue route misses its node")
		for index in points.size()-1:
			var d:=(_point(points[index+1])-_point(points[index])).abs()
			if int(d.x>.00001)+int(d.y>.00001)+int(d.z>.00001)>1:return _reject("Unmodeled diagonal flue route")
		var key: String="|".join([a,b] if a<b else [b,a])
		if edges.has(key):return _reject("Repeated flue route")
		edges[key]=true
	var external: Dictionary={};var expected: Dictionary={}
	for identity: String in old:
		for target: String in old[identity].connections:
			if not old.has(target):expected[identity+"|"+target]=true
	for bridge: Dictionary in data.external_bridges:
		if not local_nodes.has(str(bridge.start)) or not merged.has(str(bridge.end)) or bridge.owner!="BoilerFlue":return _reject("Invalid boiler bridge")
		external[str(bridge.start)+"|"+str(bridge.end)]=true
	if expected!=external:return _reject("Flue external authority bridge changed")
	for identity: String in local_nodes:
		for target: String in local_nodes[identity].connections:
			if local_nodes.has(target):
				if identity not in local_nodes[target].connections or not edges.has("|".join([identity,target] if identity<target else [target,identity])):return _reject("Flue edge lacks an actual carrier")
			elif not external.has(identity+"|"+target):return _reject("Undeclared flue bridge")
	for identity: String in old:merged.erase(identity)
	for identity: String in local_nodes:
		var row: Dictionary=local_nodes[identity].duplicate(true);var world: Vector3=(adapter.root as Node3D).to_global(GameBoot.b2g(row.pos))
		row.pos=[world.x,-world.z,world.y];merged[identity]=row
	routes=data.routes;bridges=data.external_bridges
	return true

func physical_owners_valid(adapter: OrisonV2AnchorAdapter) -> bool:
	for route: Dictionary in routes:
		for path: String in route.owners:
			if adapter.root.get_node_or_null(path)==null:return _reject("Missing flue carrier: "+path)
	for identity: String in local_nodes:
		if local_nodes[identity].physical_role!="thimble":continue
		var prop:=adapter.resolve(identity) as FlueBreastProp
		if prop==null or prop.graph_node_id!=identity or prop.resonance_origin().distance_to(AcousticGraphData.node_pos(identity))>.001:return _reject("Flue closure differs from physical origin")
	for bridge: Dictionary in bridges:
		var flue=adapter.root.get_node(str(bridge.owner));var boiler:=adapter.resolve(str(bridge.end)) as BoilerProp
		if boiler==null or flue.sections.is_empty() or boiler.smoke_outlet().distance_to((adapter.root as Node3D).to_global(flue.sections[0].from))>.001:return _reject("Boiler smoke collar is disconnected")
	return true
