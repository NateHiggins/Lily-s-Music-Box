extends Node3D
## Imported successor charts first; native cabinet controls in the same run.
const Metrics=preload("res://tests/orison_v2_domestic_native_test.gd")
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var packed: PackedScene=load("res://assets/props/fire_nozzle_hose.glb") as PackedScene
	if packed==null:push_error("Native nozzle stock missing");get_tree().quit(1);return
	var library: Node3D=packed.instantiate()
	var metrics: Node=Metrics.new();var count: int=0
	for draw: MeshInstance3D in library.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true);count+=1
	var ok: bool=metrics.failures.is_empty() and count==5
	for failure: String in metrics.failures:print("FIRE NOZZLE IMPORT FAILURE: ",failure)
	library.free();metrics.free()
	print("V2 FIRE NOZZLE STOCK: ","PASS" if ok else "FAIL"," parts=",count)
	if not ok:get_tree().quit(1);return
	var hands: Node3D=load("res://tests/v2_fire_hand_bench.gd").new();add_child(hands)
