class_name FirstShiftDirector
extends Node
## Owns the one-time handoff from the authored arrival to normal case play.
## It deliberately delegates the camera and sound work to VirusSoundDirector;
## campaign state, startup policy, and the first actionable objective live here.

var building: Node3D
var tracker: ObjectiveTracker
var intro: VirusSoundDirector

## The authored intro is still a placeholder, but its handoff is canonical:
## the player's shift begins on the curb beside the car that brought them.
## Plan coordinates are converted here so exterior staging has one authority.
const ARRIVAL_POSITION_B := Vector3(2.75, -13.72, 0.10)
const ARRIVAL_LOOK_TARGET_B := Vector3(0.0, -9.82, 2.15)


func setup(root: Node3D, objective_tracker: ObjectiveTracker,
		intro_director: VirusSoundDirector) -> void:
	building = root
	tracker = objective_tracker
	intro = intro_director


func _ready() -> void:
	if intro:
		intro.intro_finished.connect(_on_intro_finished)
	call_deferred("_begin_if_needed")


func _begin_if_needed() -> void:
	if bool(RealityState.data.get("intro_complete", false)):
		_place_at_arrival()
		return
	# Test scenes instantiate the building as a child. Only the actual game
	# scene may seize the player's camera and run the thirty-second arrival.
	if get_tree().current_scene != building:
		return
	if tracker:
		tracker.show_objective("FIRST SHIFT — ORISON APARTMENTS",
				"Report for Realty Maintenance. The extra I is not a typo.")
	if intro and not intro.active:
		intro.start_seed(true)


func _on_intro_finished() -> void:
	if bool(RealityState.data.get("intro_complete", false)):
		return
	_place_at_arrival()
	RealityState.data.intro_complete = true
	RealityState.commit()
	if tracker:
		tracker.show_objective("FIRST SHIFT — WORK ORDER 002-A",
				"The building has left a work order at the lobby terminal.")


func _place_at_arrival() -> void:
	if building == null or building.player == null:
		return
	var player: PlayerController = building.player
	player.global_position = GameBoot.b2g([
		ARRIVAL_POSITION_B.x, ARRIVAL_POSITION_B.y, ARRIVAL_POSITION_B.z])
	player.velocity = Vector3.ZERO
	player.noclip = false
	player.call_locked = false
	player.collision_layer = 1
	player.collision_mask = 1
	player.camera.position = Vector3(0, PlayerController.STANDING_EYE, 0)
	player.camera.rotation = Vector3.ZERO
	var target := GameBoot.b2g([
		ARRIVAL_LOOK_TARGET_B.x, ARRIVAL_LOOK_TARGET_B.y,
		ARRIVAL_LOOK_TARGET_B.z])
	var flat_direction := target - player.global_position
	flat_direction.y = 0.0
	player.rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
