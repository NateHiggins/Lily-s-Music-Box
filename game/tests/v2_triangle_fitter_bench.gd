extends Node
const Reference := preload("res://tests/fixtures/v2_triangle_fitter_reference.gd")
const Candidate := preload("res://scripts/building/orison_v2_shop_seating.gd")

func _ready() -> void:
	var checks := 0
	var failures: Array[String] = []
	var records: Array = []
	for data_path: String in Candidate.FITTING_DATA:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		for cell_record: Dictionary in data.cells:
			var source_path := "res://assets/building/floor_01_cells/"+str(cell_record.id)+".gltf"
			if str(cell_record.id)=="passage": source_path="res://assets/building/orison_v2/passage/passage.gltf"
			if not ResourceLoader.exists(source_path): continue
			var cell: Node3D = load(source_path).instantiate()
			for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
				var boxes: Array[Dictionary] = []
				for box: Dictionary in cell_record.replace:
					if str(draw.name).trim_suffix("-col").ends_with("_"+str(box.key)): boxes.append(box)
				if boxes.is_empty(): continue
				var counts_before := {}; var counts_after := {}
				for box: Dictionary in boxes:
					counts_before[box.id]=0; counts_after[box.id]=0
				var extent := draw.mesh.get_aabb().size
				var tolerance := float(data.tolerance)+maxf(maxf(extent.x,extent.y),extent.z)/65535.
				var started := Time.get_ticks_usec()
				var before := Reference._without_boxes(draw,boxes,tolerance,counts_before)
				var reference_us := Time.get_ticks_usec()-started
				started = Time.get_ticks_usec()
				var after := Candidate._without_boxes(draw,boxes,tolerance,counts_after)
				var candidate_us := Time.get_ticks_usec()-started
				checks += 1
				var equal: bool = before != null and after != null and counts_before==counts_after and before.get("_surfaces")==after.get("_surfaces")
				if not equal: failures.append(str(cell_record.id)+"/"+str(draw.name))
				records.append({"cell":cell_record.id,"draw":str(draw.name),"exact_buffers_and_counts":equal,"reference_us":reference_us,"candidate_us":candidate_us,"removed":counts_after})
			cell.free()
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("fitter.json"),FileAccess.WRITE).store_string(JSON.stringify({"kind":"diagnostic","checks":checks,"failures":failures,"records":records},"\t"))
	print("V2 TRIANGLE FITTER: ",checks," loaded original draws; ",failures.size()," failures")
	get_tree().quit(0 if checks>0 and failures.is_empty() else 1)
