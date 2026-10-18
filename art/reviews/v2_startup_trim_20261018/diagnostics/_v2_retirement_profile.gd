extends Node
const Legacy=preload("res://tests/_v2_retirement_legacy.gd")
const Candidate=preload("res://tests/_v2_retirement_candidate.gd")
var rows: Array=[]
var failures: Array=[]
func _ready() -> void:run.call_deferred()
func run() -> void:
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("C:/PleaseRemainOnTheLine/tmp/v2-retirement-20261018/cases.json"))
	for entry: Dictionary in cases:
		var d: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://"+str(entry.data)))
		var record: Dictionary={}
		for cell_record: Dictionary in d.cells:
			if str(cell_record.id)==str(entry.cell):record=cell_record
		var path: String="res://assets/building/orison_v2/passage/passage.gltf" if entry.cell=="passage" else "res://assets/building/floor_01_cells/%s.gltf" % entry.cell
		var packed=load(path) as PackedScene
		if packed==null:failures.append("source load "+path);continue
		var cell=packed.instantiate()
		for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
			var boxes: Array[Dictionary]=[];var initial: Dictionary={}
			for box: Dictionary in record.replace:
				if str(draw.name).trim_suffix("-col").ends_with("_"+str(box.key)):
					boxes.append(box);initial[str(box.id)]=0
			if boxes.is_empty():continue
			var extent:=draw.mesh.get_aabb().size
			var tolerance:=float(d.tolerance)+maxf(maxf(extent.x,extent.y),extent.z)/65535.
			var timings: Array=[];var equal:=true;var old_counts: Dictionary;var new_counts: Dictionary
			for repeat in 2:
				old_counts=initial.duplicate();new_counts=initial.duplicate()
				var start:=Time.get_ticks_usec()
				var old=Legacy._without_boxes(draw,boxes,tolerance,old_counts)
				var middle:=Time.get_ticks_usec()
				var candidate=Candidate._without_boxes(draw,boxes,tolerance,new_counts)
				var end:=Time.get_ticks_usec()
				timings.append({"legacy_us":middle-start,"candidate_us":end-middle})
				equal=equal and old_counts==new_counts and ((old==null and candidate==null) or (old!=null and candidate!=null and var_to_bytes(old.get("_surfaces"))==var_to_bytes(candidate.get("_surfaces"))))
			var row={"programme":entry.data,"cell":entry.cell,"draw":str(draw.name),"boxes":boxes.size(),"equal":equal,"counts":old_counts,"timings":timings}
			rows.append(row)
			if not equal:failures.append(row)
		cell.free()
		print("RETIREMENT_PROFILE ",entry.data," ",entry.cell," failures=",failures.size())
		await get_tree().process_frame
	var report={"evidence_class":"INERT","rows":rows,"failures":failures,"programmes":cases.size()}
	var out=FileAccess.open("C:/PleaseRemainOnTheLine/tmp/v2-retirement-20261018/profile1.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  "));out.close()
	print("RETIREMENT PROFILE ","PASS" if failures.is_empty() else "FAIL"," draws=",rows.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
