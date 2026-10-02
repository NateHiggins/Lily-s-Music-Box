extends "res://tests/orison_v2_apartment_door_route_test.gd"
## Existing two-apartment fixture, actual installed frame and ordinary input.
func _init() -> void:
	route_label="A REAR WING APARTMENT ROUTE"
func _prepare_player_start() -> void:
	_require(world.adapter.root.get_node_or_null("RearWingASupport")!=null,"production rear-wing frame is installed")
	super._prepare_player_start()
