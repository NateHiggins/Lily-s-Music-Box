extends Node3D
## INERT source-shell discovery, not production gameplay acceptance.
func _ready() -> void:
	# Headless rendering returns identity MultiMesh instance transforms here.
	# Refuse an unusable discovery rather than exporting plausible-looking rows.
	if DisplayServer.get_name()=="headless":
		push_error("Front trim discovery requires the rendering backend; run windowed")
		get_tree().quit(1);return
	RealityState.persistence_enabled=false
	var shell=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.production_materials=true; shell.show_clearance_anchors=false; shell.show_reservation_volumes=false
	add_child(shell)
	if not shell.failures.is_empty(): get_tree().quit(1); return
	var records: Array=[]
	for room: Node in shell.get_children():
		var batch=room.get_node_or_null("HistoricMillwork") as MultiMeshInstance3D
		if batch==null: continue
		var sources: PackedStringArray=batch.get_meta("wall_sources")
		for i in batch.multimesh.instance_count:
			var pose: Transform3D=batch.transform*batch.multimesh.get_instance_transform(i)
			records.append({"room":str(room.name),"source":sources[i],"index":i,
				"position":[pose.origin.x,pose.origin.y,pose.origin.z],
				"basis":[[pose.basis.x.x,pose.basis.x.y,pose.basis.x.z],[pose.basis.y.x,pose.basis.y.y,pose.basis.y.z],[pose.basis.z.x,pose.basis.z.y,pose.basis.z.z]]})
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var bindings: Dictionary={}
	for source: String in ["game/data/orison_v2_blockout.json","game/scripts/building/orison_v2_millwork.gd","game/scripts/building/orison_v2_blockout.gd"]:
		bindings[source]=FileAccess.get_file_as_string("res://"+source.trim_prefix("game/")).replace("\r\n","\n").sha256_text()
	FileAccess.open(directory.path_join("trim_instances.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","source_bindings_lf":bindings,"records":records},"\t"))
	print("TRIM SOURCE DISCOVERY: ",records.size()," actual instances")
	shell.free();get_tree().quit()
