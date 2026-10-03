extends "res://tests/orison_v2_vertical_route_test.gd"
## Repeat the retained whole-building input circuit with the new seats installed.
func _init() -> void:
	route_label="UPPER WALL SEATS VERTICAL ROUTE"
func _prepare_player_start() -> void:
	if world.adapter.root.get_node_or_null("UpperWallSeats")==null:
		failures.append("production upper wall seats are installed")
	super._prepare_player_start()
