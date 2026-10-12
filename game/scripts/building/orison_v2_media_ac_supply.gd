extends RefCounted
## Passive fitted leads; existing receiver/projector actors retain all authority.
const PATH := "res://data/orison_v2/media_ac_supply.json"
var errors: Array[String] = []

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var outlet_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/task_lamp_supply.json"))
	if data.get("schema_version") != 1: return false
	var model := (load(str(data.asset)) as PackedScene).instantiate()
	var outlet_model := (load(str(outlet_data.asset)) as PackedScene).instantiate()
	var source := outlet_model.find_child(str(outlet_data.outlet.mesh),true,false) as MeshInstance3D
	var outlet_mesh := source.mesh.duplicate() as ArrayMesh
	var materials := {}
	for spec: Dictionary in outlet_data.materials:
		var mat := MatLib.get_mat(str(spec.catalog)).duplicate() as StandardMaterial3D
		mat.uv1_triplanar=false; mat.uv1_scale=Vector3.ONE/float(spec.tile)
		mat.normal_scale=float(spec.normal); mat.roughness=float(spec.roughness); mat.metallic=float(spec.metallic)
		mat.albedo_color=Color(spec.tint[0],spec.tint[1],spec.tint[2],spec.tint[3])
		materials[str(spec.key)]=mat
	for index in outlet_data.outlet.materials.size():
		outlet_mesh.surface_set_material(index,materials[str(outlet_data.outlet.materials[index])])
	for row: Dictionary in data.installations:
		var appliance := adapter.resolve(str(row.id)) as Node3D
		var support := adapter.resolve(str(row.support)) as Node3D
		if appliance == null or support == null:
			errors.append("AC supply owner absent: "+str(row.id)); continue
		var root := Node3D.new(); root.name="MediaAC_"+str(row.id); support.add_child(root)
		for part: Dictionary in row.parts:
			var native := model.find_child(str(part.name),true,false) as MeshInstance3D
			if native == null: errors.append("AC native part absent: "+str(part.name)); continue
			var key := str(part.material)
			if not materials.has(key):
				var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				mat.uv1_triplanar=false; mat.normal_scale=.08
				if key == "linen": mat.albedo_color=Color(.40,.32,.23)
				materials[key]=mat
			var draw := MeshInstance3D.new(); draw.name=str(part.name); draw.mesh=native.mesh
			draw.material_override=materials[key]; draw.transform=native.transform; root.add_child(draw)
		var outlet := MeshInstance3D.new(); outlet.name="FloorReceptacle"; outlet.mesh=outlet_mesh
		outlet.position=Vector3(row.outlet[0],row.outlet[1],row.outlet[2]); root.add_child(outlet)
		appliance.set_meta("v2_media_ac_supply",weakref(root))
	model.free(); outlet_model.free()
	return errors.is_empty()
