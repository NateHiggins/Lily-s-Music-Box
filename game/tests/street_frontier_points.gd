extends RefCounted
## Pure source-resolution helper for a nearby declared outside-frontier fixture.
## No actor movement, fake resolver document, collision or acceptance result.
const Connection := preload("res://scripts/building/orison_v2_world_connection.gd")
const Bar := preload("res://scripts/characters/orison_v2_bar_route.gd")
static func resolve(resolver: Object) -> Dictionary:
	var source:=Connection.read_object("res://data/orison_v2_blockout.json")
	var geometry:=Connection.read_object("res://data/orison_v2/exterior/exterior_geometry.json")
	var prepared:=Connection.prepare(source,geometry,resolver,Connection.read_object(Connection.CONFIG_PATH))
	if prepared.is_empty(): return {"ok":false,"reason":"actual production frame refused"}
	var transform: Transform3D=prepared.interior_transform
	var result: Dictionary={"ok":true,"registered_frame":transform,"production_geometry":prepared.geometry,
		"player_observed":Vector3(.00016,0,3.925441),"bar_stage0":Bar.STREET_APPROACH[0],"bar_stage1":Bar.STREET_APPROACH[1]}
	for id: String in ["cam_ortiz","transient_guests"]:
		var data:=Connection.read_object("res://data/orison_v2/%s_routine.json"%id)
		var found:=false; var point:=Vector3.INF
		for path: Array in data.get("paths",[]):
			for row: Array in path:
				if str(row[0])!="street": continue
				var candidate:=transform*Vector3(row[1],row[2],row[3])
				if found and point.distance_to(candidate)>.00001: return {"ok":false,"reason":"ambiguous real street datum "+id}
				point=candidate; found=true
		if not found: return {"ok":false,"reason":"missing real street datum "+id}
		result[id+"_street"]=point
	var turn: Dictionary=resolver.call("resolve_placement","STREET_ORISON_01","resident_bodega_inbound_turn")
	var alignment: Dictionary=resolver.call("resolve_placement","SHOP_BODEGA","street_alignment")
	if turn.is_empty() or alignment.is_empty(): return {"ok":false,"reason":"real authored candidate/goal absent"}
	result.turn=turn.position; result.alignment=alignment.position
	return result
