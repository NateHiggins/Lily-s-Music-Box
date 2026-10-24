extends Node
## Compile in the real autoload context, so a fixture parser error exits with
## an explicit diagnostic instead of leaving an empty game at the lane ceiling.
func _ready() -> void:
	var script:=load("res://tests/v2_fire_maintenance_hand_bench.gd") as Script
	if script==null or not script.can_instantiate():
		push_error("FIRE MAINTENANCE HAND: fixture compilation failed; no hand checks executed")
		get_tree().quit(1)
		return
	var bench: Node=script.new()
	add_child(bench)
