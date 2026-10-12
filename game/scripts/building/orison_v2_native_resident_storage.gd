extends RefCounted
## Fixed native cage fabric. Original bay anchor/labels and service owners remain.
const PATH := "res://data/orison_v2/resident_storage.json"
var errors: Array[String] = []

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version")!=1:return false
	var asset := str(data.asset)
	if FileAccess.get_sha256(asset)!=str(data.asset_sha256):errors.append("native cage asset hash mismatch");return false
	var anchor := adapter.resolve(str(data.anchor)) as Node3D
	if anchor==null:return false
	var packed := load(asset) as PackedScene
	if packed==null:return false
	var model := packed.instantiate()
	var meshes := {}
	for source: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var mesh := source.mesh.duplicate() as ArrayMesh
		for surface in mesh.get_surface_count():
			var key := str(mesh.surface_get_material(surface).resource_name)
			var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			if mat==null or not MatLib.SETS.has(key):model.free();return false
			mat.uv1_triplanar=false
			mesh.surface_set_material(surface,mat)
		meshes[str(source.name)]=mesh
	model.free()
	if meshes.size()!=10:return false
	var base: Vector3 = adapter.root.to_local(anchor.global_position)
	var native := Node3D.new();native.name="NativeResidentStorage";anchor.add_child(native)
	for row: Dictionary in data.members:
		var name := str(row.name)
		if not meshes.has(name):errors.append("unknown cage part: "+name);return false
		var draw := MeshInstance3D.new();draw.name=str(row.unit)+"_"+name
		draw.mesh=meshes[name];draw.position=Vector3(row.position[0]-base.x,row.position[1],row.position[2]-base.z);draw.rotation.y=float(row.yaw)
		draw.set_meta("v2_storage_unit",str(row.unit));draw.set_meta("native_storage_part",name);native.add_child(draw)
		var body := StaticBody3D.new();body.name="Collision";draw.add_child(body)
		var shape := CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();body.add_child(shape)
	if data.labels.size()!=18:return false
	var seen := {}
	for row: Dictionary in data.labels:
		var unit := str(row.unit)
		if seen.has(unit):return false
		seen[unit]=true
		var label := Label3D.new();label.name="Cage_"+unit;label.text=unit;label.font_size=42;label.pixel_size=.003;label.double_sided=false
		label.position=Vector3(row.position[0]-base.x,row.position[1],row.position[2]-base.z);label.rotation.y=float(row.yaw);anchor.add_child(label)
	return true
