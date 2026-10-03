extends Node3D
## Read-only adapter for the existing production presentation. It neither
## advances electrical state nor creates a second light or switch authority.
class Output extends RefCounted:
	var switched_on := false
	var intensity_rate := 0.0
	var intensity := 0.0
	var color := Color.WHITE
	var angle := 38.0
	var stability := 1.0
	func write_output(target: Dictionary) -> void:
		target.intensity = intensity
		target.color = color
		target.cone_angle_deg = angle
		target.temporal_stability = stability

var state := Output.new()
var base_energy := 1.0
var range_m := 7.5
var _previous := 0.0

func observe_player(player: PlayerController, delta: float) -> void:
	observe_light(player.flashlight, player.lamp_is_enabled(), delta)
	if is_instance_valid(player.lamp_presentation):
		state.stability = float(player.lamp_presentation.output.temporal_stability)
		state.intensity_rate = player.lamp_presentation.state.intensity_rate * player._lamp_base_energy

func observe_light(light: SpotLight3D, enabled: bool, delta: float) -> void:
	global_transform = light.global_transform
	range_m = light.spot_range
	state.switched_on = enabled
	state.intensity = light.light_energy if enabled else 0.0
	state.intensity_rate = (state.intensity-_previous)/maxf(delta,.00001)
	_previous = state.intensity
	state.color = light.light_color
	state.angle = light.spot_angle
	state.stability = 1.0
