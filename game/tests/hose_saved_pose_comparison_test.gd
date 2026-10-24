extends Node
## INERT replay of the original failed disk-rebuild diagnostic, no world claim.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("V2_COMPARISON_SOURCE")))
	var comparator:=preload("res://tests/hose_saved_pose_comparison.gd")
	var checks: Array=[]
	checks.append({"label":"original one-ULP door JSON round-trip accepted","ok":comparator.compare(data.actual,data.wanted).equal})
	var changed: Dictionary=data.actual.duplicate(true);changed.door+=1e-9
	checks.append({"label":"door change beyond angular tolerance refused","ok":not comparator.compare(changed,data.wanted).equal})
	changed=data.actual.duplicate(true);changed.hose.water.pressure-=.001
	checks.append({"label":"water facts remain exact","ok":not comparator.compare(changed,data.wanted).equal})
	changed=data.actual.duplicate(true);changed.rubber_dressed=not changed.rubber_dressed
	checks.append({"label":"maintenance facts remain exact","ok":not comparator.compare(changed,data.wanted).equal})
	changed=data.actual.duplicate(true);changed.nozzle.position[0]+=.00002
	checks.append({"label":"20 micrometer pose error refused","ok":not comparator.compare(changed,data.wanted).equal})
	var ok: bool=checks.all(func(row):return row.ok)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("comparison_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"original_source":OS.get_environment("V2_COMPARISON_SOURCE")},"\t"))
	print("HOSE COMPARISON: ","PASS" if ok else "FAIL"," checks=",checks.size())
	get_tree().quit(0 if ok else 1)
