extends Node3D
const Inspector=preload("res://tests/v2_grade_stock_inspector.gd")
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var ground:=preload("res://scripts/building/orison_v2_ground.gd").new();add_child(ground)
	var footings:=preload("res://scripts/building/orison_v2_city_foundations.gd").new();add_child(footings)
	var inspector:=Inspector.new();var report: Dictionary=inspector.inspect(self,ground,footings)
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("loaded_stock.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V2 GRADE STOCK: ","PASS" if inspector.failures.is_empty() else "FAIL"," checks=",inspector.checks," failures=",inspector.failures.size())
	get_tree().quit(0 if inspector.failures.is_empty() else 1)
