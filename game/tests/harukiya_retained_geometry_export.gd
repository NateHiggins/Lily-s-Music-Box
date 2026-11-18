extends SceneTree
## Offline export of ALREADY captured evaluated surfaces. Does not replay a pose,
## move an actor, compose a world, or promote a diagnostic to runtime proof.
var failures:Array[String]=[]
var source_files:Dictionary={}
func _initialize() -> void:_export.call_deferred()
func _export() -> void:
	var source:=OS.get_environment("ORISON_RETAINED_DIAGNOSTIC")
	var output:=OS.get_environment("SHOT_DIR")
	if source.is_empty() or output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK:quit(2);return
	if FileAccess.file_exists(output.path_join("geometry.bin")):quit(2);return
	var source_hash:=FileAccess.get_sha256(source)
	var decoded:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
	if decoded is not Dictionary:quit(2);return
	var binary:=FileAccess.open(output.path_join("geometry.bin"),FileAccess.WRITE)
	if binary==null:quit(2);return
	var rows:Array=[]
	for observation_index:int in decoded.observations.size():
		var observation:Dictionary=decoded.observations[observation_index]
		if not observation.has("actors"):continue
		for actor_id:String in observation.actors:
			for surface:Dictionary in observation.actors[actor_id].evaluated_surfaces:
				var file:String=str(surface.file)
				if not FileAccess.file_exists(file):failures.append("missing retained mesh "+file);continue
				var before:=FileAccess.get_sha256(file)
				var mesh:=load(file) as ArrayMesh
				if mesh==null or mesh.get_surface_count()!=1:failures.append("invalid retained mesh "+file);continue
				var arrays:Array=mesh.surface_get_arrays(0)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				if vertices.size()!=int(surface.vertices) or indices.size()!=int(surface.triangles)*3:
					failures.append("retained mesh size differs "+file);continue
				var valid:=true
				for v:Vector3 in vertices:
					if not v.is_finite():valid=false;break
				for index:int in indices:
					if index<0 or index>=vertices.size():valid=false;break
				if not valid:failures.append("invalid retained vertex/index "+file);continue
				var vertex_data:=vertices.to_byte_array();var index_data:=indices.to_byte_array()
				var vertex_offset:=binary.get_position();binary.store_buffer(vertex_data)
				var index_offset:=binary.get_position();binary.store_buffer(index_data)
				source_files[file]=before
				if FileAccess.get_sha256(file)!=before:failures.append("retained mesh changed during export "+file)
				rows.append({"observation_index":observation_index,"technical_state":observation.newly_authored_technical_state,
					"actor":actor_id,"source_mesh":surface.mesh,"source_surface":surface.surface,
					"retained_file":file,"retained_sha256":before,"vertex_count":vertices.size(),
					"triangle_count":indices.size()/3,"vertex_offset":vertex_offset,"vertex_bytes":vertex_data.size(),
					"index_offset":index_offset,"index_bytes":index_data.size()})
	binary.close()
	if FileAccess.get_sha256(source)!=source_hash:failures.append("original diagnostic changed")
	var result:Dictionary={"evidence_class":"INERT","status":"EXPORTED_RETAINED_GEOMETRY" if failures.is_empty() else "FAIL",
		"source_diagnostic":source,"source_sha256":source_hash,"source_meshes":source_files,
		"binary":output.path_join("geometry.bin"),"binary_sha256":FileAccess.get_sha256(output.path_join("geometry.bin")),
		"encoding":"little-endian float32 XYZ vertices followed by little-endian int32 triangle indices; explicit byte offsets per surface; world coordinates from original evaluated mesh",
		"surfaces":rows,"failures":failures,"scope":"Exact retained finite-pose geometry only; no replay, new pose, collision or full physical qualification"}
	FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("RETAINED GEOMETRY EXPORT: ","PASS" if failures.is_empty() else "FAIL"," surfaces=",rows.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
