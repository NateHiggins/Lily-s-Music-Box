extends Node
const Fitter := preload("res://scripts/building/orison_v2_shop_seating.gd")
func _ready() -> void:
	OS.set_environment("ORISON_PROFILE_NATIVE","1")
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var failures: Array=[]
	var checks:=0
	for data_path: String in Fitter.FITTING_DATA:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(data_path))
		for record: Dictionary in data.cells:
			var path: String="res://assets/building/orison_v2/passage/passage.gltf" if record.id=="passage" else "res://assets/building/floor_01_cells/"+str(record.id)+".gltf"
			if not ResourceLoader.exists(path): continue
			var cell: Node3D=load(path).instantiate()
			cell.name=str(record.id)
			checks+=1
			if not Fitter.mount_records(cell,layout,data_path,"Profile","Profile_","profile_part"): failures.append(data_path+":"+str(record.id))
			cell.free()
	print("NATIVE FIT PROFILE: ",checks," isolated original fittings; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
