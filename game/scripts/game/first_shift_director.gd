class_name FirstShiftDirector
extends Node
## Owns the one-time handoff from the authored arrival to normal case play.
## It deliberately delegates the camera and sound work to VirusSoundDirector;
## campaign state, startup policy, and the first actionable objective live here.

var building: Node3D
var tracker: ObjectiveTracker
var intro: VirusSoundDirector

## The shift begins on the south walk, just outside the passenger side of the
## eastbound car. Looking across the road teaches the complete 30 ft crossing
## before a word of UI does. Plan coordinates are converted here so exterior
## staging has one authority.
const ARRIVAL_POSITION_B := Vector3(-3.60, -24.72, 0.10)
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
	if get_tree().current_scene != building:
		return
	# Ruled 2026-08-04: no seized-camera arrival. A new game starts on the
	# south kerb facing the building, player in control from the first
	# frame. The authored thirty-second flyover survives behind
	# VirusSoundDirector.toggle_intro for scenario use.
	begin_first_shift()


## Public for a deterministic harness as well as the production deferred boot.
## `intro_complete` is the one-shot fact: loading an existing campaign can
## restore the curb spawn, but it can never manufacture the car again.
func begin_first_shift() -> bool:
	if bool(RealityState.data.get("intro_complete", false)):
		return false
	_place_at_arrival()
	if building and building.street_traffic:
		building.street_traffic.begin_arrival()
	RealityState.data.intro_complete = true
	RealityState.commit()
	if tracker:
		tracker.show_objective("FIRST SHIFT — ORISON APARTMENTS",
				"Report for Realty Maintenance. The extra I is not a typo. " +
				"The building has left a work order at the lobby terminal.")
	return true


func _on_intro_finished() -> void:
	if bool(RealityState.data.get("intro_complete", false)):
		return
	begin_first_shift()


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
