extends Node3D
## Read-only adapter for the existing production presentation. It neither
## advances electrical state nor creates a second light or switch authority.
class Output extends RefCounted:
	var switched_on := false
	var intensity_rate := 0.0
	var intensity := 0.0
	var color := Color.WHITE
	var angle := 38.0
	func write_output(target: Dictionary) -> void:
		target.intensity = intensity
		target.color = color
		target.cone_angle_deg = angle
		target.temporal_stability = 1.0

var state := Output.new()
var base_energy := 1.0
var range_m := 7.5
var _previous := 0.0

func observe_player(player: PlayerController, delta: float) -> void:
	global_transform = player.flashlight.global_transform
	range_m = player.flashlight.spot_range
	state.switched_on = player.lamp_is_enabled()
	state.intensity = player.flashlight.light_energy if state.switched_on else 0.0
	state.intensity_rate = (state.intensity-_previous)/maxf(delta,.00001)
	_previous = state.intensity
	state.color = player.flashlight.light_color
	state.angle = player.flashlight.spot_angle
