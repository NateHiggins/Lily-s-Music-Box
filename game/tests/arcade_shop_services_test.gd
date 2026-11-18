extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Run the original shop programmes in one production world and one private campaign.

const ROUTES := {
	"pawn": preload("res://tests/pawn_route_test.gd"),
	"otis": preload("res://tests/otis_route_test.gd"),
	"shoe": preload("res://tests/shoe_route_test.gd"),
	"photo": preload("res://tests/photo_route_test.gd"),
}

func _init() -> void:
	route_label = "ARCADE SHOP SERVICES"

func _route() -> void:
	if not _require(world.passage_region.uses_prepared_geometry(), "expanded arcade is mounted"):
		return
	var directory := OS.get_environment("SHOT_DIR")
	var results := {}
	for key: String in ROUTES:
		var driver: Node = ROUTES[key].new()
		driver.externally_managed = true
		driver.world = world
		driver.player = player
		add_child(driver)
		var destination := directory.path_join(key) if not directory.is_empty() else ""
		OS.set_environment("SHOT_DIR", destination)
		if not destination.is_empty():
			DirAccess.make_dir_recursive_absolute(destination)
		player.camera.make_current()
		player.velocity = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("ARCADE SHOP START: ", key)
		await driver._route()
		results[key] = {"checks": driver.interaction_checks, "failures": driver.failures}
		for failure: String in driver.failures:
			failures.append(key + ": " + failure)
		print("ARCADE SHOP RESULT: ", key, " checks=", driver.interaction_checks.size(), " failures=", driver.failures.size())
		driver.free()
	OS.set_environment("SHOT_DIR", directory)
	if not directory.is_empty():
		var report := FileAccess.open(directory.path_join("shop_services.json"), FileAccess.WRITE)
		if _require(report != null, "service result is written"):
			report.store_string(JSON.stringify(results, "  "))
