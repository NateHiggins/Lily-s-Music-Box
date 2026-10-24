extends Node3D
## Diagnostic replay of a failed live-world query; no gameplay qualification.
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var path:=OS.get_environment("ORISON_HOSE_CAST_CAPTURE")
	var packed:=load(path) as PackedScene
	if packed==null:
		push_error("FITTING CAST REPLAY: capture did not load")
		get_tree().quit(1);return
	var captured: Node3D=packed.instantiate();add_child(captured)
	await get_tree().physics_frame;await get_tree().physics_frame
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=captured.get_meta("query_shape");query.transform=captured.get_meta("query_transform")
	query.motion=captured.get_meta("query_motion");query.margin=captured.get_meta("query_margin")
	query.collision_mask=captured.get_meta("query_mask");query.collide_with_areas=false
	var space:=get_world_3d().direct_space_state
	var all: PackedFloat32Array=space.cast_motion(query)
	var original: PackedFloat32Array=captured.get_meta("original_fractions")
	var matches: bool=all.size()==2 and original.size()==2 and absf(all[0]-original[0])<.01 and absf(all[1]-original[1])<.01
	print("FITTING CAST REPLAY: original=",original," reproduced=",all," matches=",matches)
	var rows: Array=[]
	for body: StaticBody3D in captured.get_children():
		var excluded: Array[RID]=[]
		for other: StaticBody3D in captured.get_children():
			if other!=body:excluded.append(other.get_rid())
		query.exclude=excluded
		var result: PackedFloat32Array=space.cast_motion(query)
		var row: Dictionary={"path":body.get_meta("original_path"),"fractions":Array(result)}
		rows.append(row)
		print("FITTING CAST CANDIDATE: ",JSON.stringify(row))
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		var file:=FileAccess.open(out.path_join("replay.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"INERT","capture":path,"matches":matches,"original":Array(original),"reproduced":Array(all),"candidates":rows},"\t"));file.close()
	get_tree().quit(0 if matches else 1)
