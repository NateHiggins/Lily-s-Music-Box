class_name TitleClockworkVeil
extends Control
## A restrained diagram, not a literal clock. Its incomplete rings and
## escapement ticks make the stairwell feel mechanically implicated without
## laying a bright game-UI effect over the architectural photograph.

var _elapsed := 0.0
var _returned := true
var _intensity := 1.0
var _target_intensity := 1.0


func set_record_state(returned: bool) -> void:
	_returned = returned
	_target_intensity = 1.0 if returned else 0.32


func _process(delta: float) -> void:
	_elapsed += delta
	_intensity = move_toward(_intensity, _target_intensity, delta * 0.7)
	queue_redraw()


func _draw() -> void:
	var s := size
	if s.x <= 1.0 or s.y <= 1.0:
		return
	var centre := Vector2(s.x * 0.285, s.y * 0.455)
	var unit := minf(s.x, s.y)
	var bronze := Color(0.63, 0.43, 0.20, 0.075 * _intensity)
	var cold := Color(0.28, 0.47, 0.58, 0.052 * _intensity)
	var phase := _elapsed * (0.21 if _returned else 0.055)
	for i in 4:
		var radius := unit * (0.13 + float(i) * 0.040)
		var start := phase * (1.0 if i % 2 == 0 else -0.62) + float(i) * 0.7
		draw_arc(centre, radius, start, start + PI * (0.90 + float(i) * 0.13),
				96, bronze if i % 2 == 0 else cold, 1.0, true)
	# Twelve uneven teeth, with the thirteenth position conspicuously absent.
	var tooth_radius := unit * 0.245
	for i in 13:
		if i == 8:
			continue
		var angle := phase * -0.41 + TAU * float(i) / 13.0
		var inner := centre + Vector2(cos(angle), sin(angle)) * tooth_radius
		var outer := centre + Vector2(cos(angle), sin(angle)) \
				* (tooth_radius + unit * (0.010 if i % 3 else 0.016))
		draw_line(inner, outer, bronze, 1.0, true)
	# An escapement arm crosses the shaft, stopping just short of the centre.
	var swing := sin(_elapsed * (2.6 if _returned else 0.95)) * 0.20
	var arm_angle := -0.56 + swing
	var arm_start := centre + Vector2(cos(arm_angle), sin(arm_angle)) * unit * 0.05
	var arm_end := centre + Vector2(cos(arm_angle), sin(arm_angle)) * unit * 0.19
	draw_line(arm_start, arm_end, cold, 1.25, true)
