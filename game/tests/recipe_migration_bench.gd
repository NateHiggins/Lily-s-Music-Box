extends Node
## Imported assets only: a failed migration should not require a full world boot.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var assets: Dictionary={"res://assets/props/light_switch.glb":true}
	for file in DirAccess.get_files_at("res://data/orison_v2"):
		if not file.ends_with(".json"):continue
		var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/"+file))
		if data is Dictionary and _uses_recipe(data) and str(data.get("asset","")).begins_with("res://assets/props/"):assets[str(data.asset)]=true
	var inspector := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var meshes := 0
	var rest_charts := 0
	var witness: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/task_lamp_flex_uv.json"))
	inspector.check(FileAccess.get_sha256(witness.asset)==witness.asset_sha256,"rest-chart witness binds current export")
	for path: String in assets:
		var scene := load(path) as PackedScene
		if scene==null:inspector.check(false,"migrated asset loads: "+path);continue
		var model := scene.instantiate()
		if path.ends_with("/light_switch.glb"):
			var names: Dictionary={}
			for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				for surface in draw.mesh.get_surface_count():
					var stock := draw.mesh.surface_get_material(surface)
					inspector.check(stock!=null and MatLib.SETS.has(stock.resource_name),"switch retains its material-name binding")
					if stock!=null:names[stock.resource_name]=true
			inspector.check(names.size()==4 and model.find_child("TogglePivot",true,false)!=null,"original switch material slots and operating pivot survive")
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if path==witness.asset and witness.meshes.has(str(draw.name)):
				_check_rest_chart(draw.mesh,witness.meshes[str(draw.name)],inspector);rest_charts+=1
			else:inspector._check_cap_mapping(draw.mesh,true)
			meshes+=1
		model.free()
	inspector.check(rest_charts==5,"all five physical rest charts checked")
	var summary := {"evidence_class":"INERT","assets":assets.keys(),"meshes":meshes,"rest_charts":rest_charts,"planar_meshes":meshes-rest_charts,"checks":inspector.checks,"failures":inspector.failures,"scope":"Loaded metre UVs and tangent derivatives; no composed-world, rendering or gameplay acceptance."}
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("recipe_migration_bench.json"),FileAccess.WRITE).store_string(JSON.stringify(summary,"\t"))
	print("RECIPE MIGRATION BENCH: ","PASS" if inspector.failures.is_empty() else "FAIL","; ",meshes," meshes; ",inspector.failures)
	var failed := not inspector.failures.is_empty();inspector.free();get_tree().quit(1 if failed else 0)

func _uses_recipe(value: Variant) -> bool:
	if value is Dictionary:
		if str(value.get("catalog_key",value.get("key","")))=="bakelite":return true
		for child in value.values():
			if _uses_recipe(child):return true
	elif value is Array:
		for child in value:
			if _uses_recipe(child):return true
	return false

# Curved textile follows the physical swept radius and rest length. A flat-stock
# edge-isometry criterion is inappropriate at bends; exact imported coordinates
# bind the independently checked native chart instead.
func _check_rest_chart(mesh: Mesh, record: Dictionary, inspector: Node) -> void:
	inspector.check(record.radius_m>0 and record.reference_length_m>0 and record.maximum_radius_error_m<.000005 and record.maximum_native_uv_error_m<.000002 and record.double_radius_negative_error_m>.001,"native physical radius, length and negative control")
	var pairs: Dictionary={}
	var basis := true
	var derivatives := true
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var complete:=normals.size()==vertices.size() and uv.size()==vertices.size() and tangents.size()==vertices.size()*4 and indices.size()%3==0
		inspector.check(complete,"rest chart has complete imported attributes and triangles")
		if not complete:return
		for i in vertices.size():
			var row:=PackedFloat32Array([vertices[i].x,vertices[i].y,vertices[i].z,uv[i].x,uv[i].y])
			for j in row.size():
				if row[j]==0:row[j]=0.0
			pairs[row.to_byte_array().hex_encode()]=true
			var tangent:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
			basis=basis and vertices[i].is_finite() and uv[i].is_finite() and tangent.is_finite() and absf(normals[i].length()-1)<.001 and absf(tangent.length()-1)<.001 and absf(tangent.dot(normals[i]))<.001 and absf(absf(tangents[i*4+3])-1)<.001
		for triangle in range(0,indices.size(),3):
			var a:=indices[triangle];var b:=indices[triangle+1];var c:=indices[triangle+2]
			var first:=vertices[b]-vertices[a];var second:=vertices[c]-vertices[a]
			var u:=uv[b]-uv[a];var v:=uv[c]-uv[a]
			var determinant:=u.x*v.y-v.x*u.y
			derivatives=derivatives and absf(determinant)>1e-12
			if absf(determinant)<=1e-12:continue
			var expected: Vector3=(first*v.y-second*u.y)/determinant
			var bitangent: Vector3=(second*u.x-first*v.x)/determinant
			for i: int in [a,b,c]:
				var actual:=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				var projected: Vector3=(expected-normals[i]*expected.dot(normals[i])).normalized()
				derivatives=derivatives and projected.dot(actual)>.999 and normals[i].cross(actual).dot(bitangent)*tangents[i*4+3]>0
	var keys:=pairs.keys();keys.sort()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for key: String in keys:hash.update((key+"\n").to_ascii_buffer())
	inspector.check(keys.size()==int(record.unique_position_uv_pairs) and hash.finish().hex_encode()==record.position_uv_sha256,"loaded coordinates exactly match the physical native rest chart")
	inspector.check(basis and derivatives,"rest chart has finite orthonormal basis and matching UV derivatives")
