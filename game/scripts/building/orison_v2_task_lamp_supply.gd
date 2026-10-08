extends RefCounted
## Authorized outlet placements are passive presentation; LampProp owns power.
const PATH := "res://data/orison_v2/task_lamp_supply.json"
var errors: Array[String] = []
var installed: Dictionary = {}

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version")!=1: return false
	var model := (load(str(data.asset)) as PackedScene).instantiate()
	var materials := {}
	for spec: Dictionary in data.materials:
		var mat := MatLib.get_mat(str(spec.catalog)).duplicate() as StandardMaterial3D
		mat.uv1_triplanar=false
		mat.uv1_scale=Vector3.ONE/float(spec.tile)
		mat.normal_scale=float(spec.normal)
		mat.roughness=float(spec.roughness)
		mat.metallic=float(spec.metallic)
		mat.albedo_color=Color(spec.tint[0],spec.tint[1],spec.tint[2],spec.tint[3])
		materials[str(spec.key)]=mat
	var meshes := {}
	var parts: Array=[data.outlet]
	for row: Dictionary in data.installations:
		if not adapter.resolve(str(row.id)) is LampProp or not adapter.resolve(str(row.support)) is StaticBody3D:
			errors.append("source lamp/support: "+str(row.id))
		parts.append_array(row.parts)
	for part: Dictionary in parts:
		var source := model.find_child(str(part.mesh),true,false) as MeshInstance3D
		if source==null or source.mesh.get_surface_count()!=part.materials.size():
			errors.append("native supply partition: "+str(part.mesh)); continue
		var mesh := source.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count():
			if not materials.has(str(part.materials[i])): errors.append("supply material: "+str(part.materials[i])); continue
			mesh.surface_set_material(i,materials[str(part.materials[i])])
		meshes[str(part.mesh)]=mesh
	model.free()
	if not errors.is_empty(): return false
	for row: Dictionary in data.installations:
		var support := adapter.resolve(str(row.support)) as StaticBody3D
		var lamp := adapter.resolve(str(row.id)) as LampProp
		var root := Node3D.new()
		root.name="Supply_"+str(row.id)
		support.add_child(root)
		for part: Dictionary in row.parts:
			var draw := MeshInstance3D.new()
			draw.name=str(part.mesh);draw.mesh=meshes[str(part.mesh)]
			root.add_child(draw)
		var outlet := MeshInstance3D.new()
		outlet.name="FloorReceptacle";outlet.mesh=meshes[str(data.outlet.mesh)]
		outlet.position=Vector3(row.outlet[0],row.outlet[1],row.outlet[2])
		root.add_child(outlet)
		installed[str(row.id)]={"root":weakref(root),"lamp":weakref(lamp),"support":weakref(support),"light":lamp.light.get_instance_id(),"switch":lamp._switch_key.get_instance_id(),"graph":lamp.graph_node_id,"position":lamp.transform,"outlet":weakref(outlet)}
	return true
