extends Node
func _ready() -> void:
	var candidate:=load("res://tests/v2_service_circulation_contract.gd") as Script
	var valid:=candidate!=null and candidate.can_instantiate()
	# Run the real source validator without constructing a rendered world.
	# This catches retained pipe bores and shared-wall owners before the long walk.
	var shell:=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.layout=shell._load_layout(shell.layout_path)
	shell._validate_layout()
	for failure: String in shell.failures:push_error(failure)
	valid=valid and shell.failures.is_empty()
	shell.free()
	print("V2 SERVICE CIRCULATION SOURCE BENCH: ","PASS" if valid else "FAIL")
	get_tree().quit(0 if valid else 1)
