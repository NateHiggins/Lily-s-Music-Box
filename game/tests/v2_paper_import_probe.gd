extends Node3D
## Small imported-coordinate diagnostic, not runtime qualification.
var points: Array[Vector3]=[]
var metric_bad:=0
var metric_edges:=0
func _ready() -> void:
	var loader: Script=load("res://scripts/building/orison_v2_bath_details.gd")
	if loader==null or not loader.can_instantiate():
		get_tree().quit(1);return
	var model: Node3D=load("res://assets/props/bath_paper_holder.glb").instantiate()
	add_child(model);collect(model,Transform3D.IDENTITY)
	var low:=Vector3(INF,INF,INF);var high:=-low
	for v in points:low=low.min(v);high=high.max(v)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bath_details.json"))
	var bounds: Array=[]
	for record: Dictionary in source.props:
		if record.kind=="toilet_roll":bounds=record.bounds;break
	var contained:=true
	for v in points:
		for axis in 3:
			if v[axis]<float(bounds[0][axis])-.00001 or v[axis]>float(bounds[1][axis])+.00001:contained=false
	var report: Dictionary={"evidence_class":"INERT","scope":"Imported static paper model coordinate/metric diagnosis only","bounds":[[low.x,low.y,low.z],[high.x,high.y,high.z]],"vertices":points.size(),"within_authored_bounds":contained,"metric_edges":metric_edges,"bad_metric_edges":metric_bad}
	print("PAPER IMPORT ",JSON.stringify(report))
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("imported_bounds.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	model.free();get_tree().quit(0 if contained and metric_bad==0 else 1)
func collect(node: Node3D,parent: Transform3D) -> void:
	var pose:=parent*node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var a: Array=node.mesh.surface_get_arrays(surface)
			var v: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV];var ix: PackedInt32Array=a[Mesh.ARRAY_INDEX]
			for point in v:points.append(pose*point)
			for t in range(0,ix.size(),3):
				for edge in 3:
					var i:=ix[t+edge];var j:=ix[t+(edge+1)%3];var distance:=v[i].distance_to(v[j]);metric_edges+=1
					if absf(uv[i].distance_to(uv[j])-distance)>maxf(.000002,distance*.005):metric_bad+=1
	for child in node.get_children():
		if child is Node3D:collect(child,pose)
