extends "res://tests/v2_bathroom_moisture_review.gd"
## Untimed actual-world rain and transparent-order controls, not access proof.
func _init() -> void:route_label="V2 RAIN FILM PROBE"

func _route() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	_moisture=world.bathroom_moisture
	for source: Dictionary in _moisture._sources:
		if source.tap.unit=="4B":
			player.global_position=source.tap.to_global(Vector3(0.0,0.02,-0.9));player.velocity=Vector3.ZERO;break
	for frame in 12:await get_tree().physics_frame
	await _rain_review()
	await _ordering_control()
