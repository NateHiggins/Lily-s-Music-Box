extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Runs the installed kitchen prep review (stations, bearings, surfaces, the real
## hand on the loose tools) in the composed world, and checks that the loose tools
## stay frozen script-carried stock: no contact reports and no continuous sweeps.

func _init() -> void:
	route_label = "KITCHEN PREP REVIEW"


func _route() -> void:
	var loose := 0
	var quiet := true
	for station: Node in world.find_children("*", "Node3D", true, false):
		if station.get("tools") is not Dictionary or station.get("hulls") is not Dictionary:
			continue
		for body: RigidBody3D in (station.tools as Dictionary).values():
			loose += 1
			quiet = quiet and body.freeze and not body.contact_monitor and not body.continuous_cd
	_require(loose >= 30 and quiet, "the %d loose kitchen tools rest frozen, with no contact reports or continuous sweeps" % loose)
	var review: Node = preload("res://tests/v2_kitchen_prep_installed_review.gd").new()
	add_child(review)
	var directory := OS.get_environment("SHOT_DIR")
	await review.run(world, directory)
	for row: Dictionary in review.checks:
		if not bool(row.ok):
			_require(false, "kitchen review: " + str(row.label))
	_require(review.failures.is_empty() and review.checks.size() > 0,
			"the installed kitchen review passes: %d checks, %d failures" % [review.checks.size(), review.failures.size()])
