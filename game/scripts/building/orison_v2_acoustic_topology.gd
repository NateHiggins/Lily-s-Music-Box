extends RefCounted
## Physical V2 ventilation through the existing propagation autoload.
## Other networks remain explicit migration debt; no nearest-owner guessing.
const DATA := "res://data/orison_v2/acoustic_ventilation.json"
const LEGACY := "res://data/acoustic_graph.json"
const PARITY := ["F02_A_MAIN_VANTRY_POINT", "F02_A_MONITOR_01",
	"F04_B_MONITOR_01", "F03_B_RADIATOR_01"]
var errors: Array[String] = []
var _lease := 0
var _local_nodes := {}
var _routes: Array = []
var heating

func _reject(message: String) -> bool:
	errors.append(message)
	return false

func _point(value: Variant) -> Vector3:
	if value is not Array or value.size()!=3: return Vector3(INF,INF,INF)
	for coordinate: Variant in value:
		if not (coordinate is float or coordinate is int): return Vector3(INF,INF,INF)
	return Vector3(value[0],value[1],value[2])

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	if _lease!=0: return _reject("Topology already mounted")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is not Dictionary or data.get("schema_version")!=1 or data.get("network")!="ventilation" \
			or data.get("coordinate_frame")!="blockout_local_blender": return _reject("Invalid local topology schema")
	if data.get("source_bindings") is not Array or data.source_bindings.is_empty(): return _reject("Missing physical source bindings")
	for binding: Dictionary in data.source_bindings:
		var path := str(binding.get("path",""))
		if not path.begins_with("res://") or ".." in path or not FileAccess.file_exists(path): return _reject("Missing source: "+path)
		if binding.get("normalize_lines") is not bool: return _reject("Missing source byte convention")
		var bytes := FileAccess.get_file_as_bytes(path)
		if binding.normalize_lines: bytes=bytes.get_string_from_utf8().replace("\r\n","\n").to_utf8_buffer()
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		if hash.finish().hex_encode()!=str(binding.get("sha256","")): return _reject("Stale physical source: "+path)
	var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY))
	if legacy is not Dictionary: return _reject("Missing retained topology")
	var old := {}
	for row: Dictionary in legacy.get("nodes",[]):
		if row.get("network")=="ventilation": old[str(row.id)]=row
	var accounted := {}
	var local_nodes := {}
	var rooms := {}
	for row: Dictionary in layout.spaces: rooms[str(row.id)]=true
	for row: Dictionary in layout.levels: rooms[str(row.id)]=true
	for row: Dictionary in data.get("nodes",[]):
		var identity := str(row.get("id",""))
		if not old.has(identity) or accounted.has(identity) or row.get("network")!="ventilation": return _reject("Duplicate/unknown ventilation identity: "+identity)
		if not rooms.has(str(row.get("room",""))) or not _point(row.get("pos")).is_finite(): return _reject("Unowned ventilation position: "+identity)
		for key: String in ["frequency_band","delay_ms","damping","infection_receptivity"]:
			if row.get(key)!=old[identity].get(key): return _reject("Authored acoustic tuning changed: "+identity)
		if str(row.get("riser","")) not in ["V-A","V-B","V-C","V-D"]: return _reject("Unknown physical stack")
		local_nodes[identity]=row;accounted[identity]=true
	for retired: Dictionary in data.get("retirements",[]):
		var identity := str(retired.get("id",""))
		if not old.has(identity) or accounted.has(identity): return _reject("Unaccounted retirement: "+identity)
		if str(retired.get("stack","")) not in ["A","B","C","D"] or str(retired.get("reason","")).is_empty(): return _reject("Retirement lacks physical reason")
		var height := float(old[identity].pos[2])
		if height>=float(retired.get("duct_bottom_y",-INF)) and height<=float(retired.get("duct_top_y",INF)): return _reject("Retired junction still lies in installed duct")
		accounted[identity]=true
	if accounted.size()!=old.size(): return _reject("Ventilation identity omitted")
	var edges := {}
	for route: Dictionary in data.get("routes",[]):
		var a := str(route.get("from",""));var b := str(route.get("to",""))
		if not local_nodes.has(a) or not local_nodes.has(b) or a==b: return _reject("Unknown route endpoint")
		if local_nodes[a].riser!=local_nodes[b].riser: return _reject("Route crosses unrelated installed stacks")
		if route.get("owner")!="VentilationDucts/Stack_"+str(local_nodes[a].riser).trim_prefix("V-"): return _reject("Route lacks physical owner")
		var points: Array = route.get("points_local_godot",[])
		if points.size()<2 or _point(points[0]).distance_to(GameBoot.b2g(local_nodes[a].pos))>.001 \
				or _point(points.back()).distance_to(GameBoot.b2g(local_nodes[b].pos))>.001: return _reject("Route misses its carrier")
		for index in points.size()-1:
			var start := _point(points[index]);var end := _point(points[index+1])
			if not start.is_finite() or not end.is_finite(): return _reject("Nonfinite duct route")
			var delta := (end-start).abs()
			if int(delta.x>.00001)+int(delta.y>.00001)+int(delta.z>.00001)>1: return _reject("Unfabricated diagonal duct")
		var key := "|".join([a,b] if a<b else [b,a])
		if edges.has(key): return _reject("Repeated physical route")
		edges[key]=true
	for identity: String in local_nodes:
		for neighbor: String in local_nodes[identity].get("connections",[]):
			if not local_nodes.has(neighbor) or identity not in local_nodes[neighbor].connections: return _reject("Nonreciprocal ventilation route")
			if not edges.has("|".join([identity,neighbor] if identity<neighbor else [neighbor,identity])): return _reject("Graph edge has no fabricated route")
	var merged := AcousticGraphData.nodes.duplicate(true)
	for identity: String in merged.keys():
		if merged[identity].get("network")=="ventilation": merged.erase(identity)
	for identity: String in local_nodes:
		var row: Dictionary=local_nodes[identity].duplicate(true)
		var world: Vector3 = (adapter.root as Node3D).to_global(GameBoot.b2g(row.pos))
		row.pos=[world.x,-world.z,world.y]
		merged[identity]=row
	# Retire the four adapter position patches into the same reversible lease.
	for identity: String in PARITY:
		var anchor := adapter.resolve(identity) as Node3D
		if anchor==null or not merged.has(identity): return _reject("Missing retained parity carrier: "+identity)
		merged[identity].pos=[anchor.global_position.x,-anchor.global_position.z,anchor.global_position.y]
	heating=preload("res://scripts/building/orison_v2_acoustic_heating.gd").new()
	if not heating.merge_into(merged,adapter,layout):return _reject("Heating topology refused: "+str(heating.errors))
	_lease=AcousticGraphData.push_topology(merged)
	if _lease==0: return _reject("Propagation owner refused topology")
	_local_nodes=local_nodes;_routes=data.routes
	return true

func physical_owners_valid(adapter: OrisonV2AnchorAdapter) -> bool:
	if heating==null or not heating.physical_owners_valid(adapter):return _reject("Physical heating owners refused: "+str(heating.errors if heating!=null else []))
	for route: Dictionary in _routes:
		if not adapter.root.get_node_or_null(NodePath(str(route.owner))) is StaticBody3D: return _reject("Installed duct owner missing: "+str(route.owner))
	for identity: String in _local_nodes:
		if identity.contains("_V_") and identity.ends_with("_RISER"): continue
		var owner := adapter.resolve(identity) as Node3D
		if owner==null or owner.global_position.distance_to(AcousticGraphData.node_pos(identity))>.001: return _reject("Installed carrier differs from source: "+identity)
	return true

func release() -> bool:
	if _lease==0: return true
	if not AcousticGraphData.release_topology(_lease): return _reject("Unknown topology lease")
	_lease=0;_local_nodes.clear();_routes.clear()
	return true
