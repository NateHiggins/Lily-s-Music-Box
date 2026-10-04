extends "res://tests/orison_v2_ceiling_top_closures_test.gd"
## Imported position/UV derivatives, normals and tangent handedness for the
## exact source-bound roof construction, including Boolean receiver junctions.
func _run() -> void:
	for kind: String in ["roof_drainage_falls","roof_drainage_ports","roof_drainage_leaders","roof_drainage_plant_weather","roof_drainage_door_weather","roof_drainage_receivers","roof_base_flashings","roof_membrane","roof_public_weathering","roof_service_weathering"]:
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_"+kind+".json"))
		var asset: String="res://assets/props/"+kind+".glb"
		check(FileAccess.get_sha256(asset)==fixture.asset_sha256,"imported mapping binds actual source export: "+kind)
		var expected: Dictionary={}
		var rows: Array=fixture.runtime_parts if fixture.has("runtime_parts") else fixture.parts if fixture.get("parts") is Array else fixture.closed_stocks if fixture.has("closed_stocks") else []
		for part: Dictionary in rows:expected[str(part.name)]=true
		var model: Node3D=(load(asset) as PackedScene).instantiate();add_child(model)
		var measured: Dictionary={}
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if kind=="roof_drainage_falls" and not expected.has(str(draw.name)):continue # Hidden physical envelopes are validated as closed native stocks.
			_check_planar_mapping(draw.mesh,true);measured[str(draw.name)]=true
		if not expected.is_empty():check(measured.size()==expected.size() and measured.keys().all(func(identity: String) -> bool:return expected.has(identity)),"all bound native material partitions inspected: "+kind)
		model.free()
	print("ROOF DRAINAGE UV: checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
