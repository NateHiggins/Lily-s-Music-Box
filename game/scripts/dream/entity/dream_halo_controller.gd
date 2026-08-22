class_name DreamHaloController
extends RefCounted
## The halos (DREAM_TENTACLE_DIRECTION §8): three rings of luminous beads
## around the eye, each with its own transform and motion — the inner ring
## a smooth ceremonial rotation; the outer very slow, interrupted by tiny
## discontinuous angular jumps; the phase ring a third structure visible
## only at grazing view angles and during phase events. They are not
## jewellery on the body: they hold their own plane about the gaze axis,
## float in front of the eye, and lag its movement.
##
## The beads are small unshaded additive spheres in one MultiMesh (their
## brightness and visibility in the instance colour), so they have depth
## and catch nothing but their own light.

const INNER_N := 28
const OUTER_N := 16
const PHASE_N := 40
const INNER_R := 0.062
const OUTER_R := 0.098
const PHASE_R := 0.135

var multimesh: MultiMeshInstance3D
var material: StandardMaterial3D
var inner_angle := 0.0
var outer_angle := 0.0
var phase_angle := 0.0
var phase_event := 0.0
var visible_amount := 0.0
var centre := Vector3.ZERO
var axis := Vector3.FORWARD
var enabled := true
var gray := false
var _jump_clock := 0.0
var _rng := RandomNumberGenerator.new()
var last_events: Array[String] = []
## Diagnostic: TENTACLE_HALO_SCALE multiplies the bead size.
var bead_scale := 1.0


func build(parent: Node3D, seed_v: int) -> void:
	_rng.seed = seed_v
	var sc := OS.get_environment("TENTACLE_HALO_SCALE")
	if not sc.is_empty():
		bead_scale = maxf(0.1, sc.to_float())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	mm.mesh = sphere
	mm.instance_count = INNER_N + OUTER_N + PHASE_N
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 0.78, 0.36)
	material.cull_mode = BaseMaterial3D.CULL_BACK
	multimesh = MultiMeshInstance3D.new()
	multimesh.name = "Halos"
	multimesh.multimesh = mm
	multimesh.material_override = material
	multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(multimesh)


func phase(seconds := 1.8) -> void:
	phase_event = seconds
	last_events.append("halo_phase")


## `eye_pos` / `gaze` from the eye; `openness` fades the rings with the eye;
## `camera_pos` for the phase ring's grazing visibility.
func update(eye_pos: Vector3, gaze: Vector3, openness: float, camera_pos: Vector3,
		attention: float, delta: float) -> void:
	last_events.clear()
	# The rings lag the eye: their centre and axis ease after it.
	centre = centre.lerp(eye_pos + gaze * 0.06, clampf(delta * 5.0, 0.0, 1.0))
	axis = axis.slerp(gaze, clampf(delta * 3.0, 0.0, 1.0)).normalized()
	inner_angle += delta * 0.35
	# The outer ring: very slow, and every few seconds a tiny jump.
	outer_angle -= delta * 0.04
	_jump_clock += delta
	if _jump_clock > _rng.randf_range(2.5, 6.0):
		_jump_clock = 0.0
		outer_angle += _rng.randf_range(-0.09, 0.09)
		last_events.append("halo_phase")
	phase_angle += delta * 0.12
	if phase_event > 0.0:
		phase_event -= delta
	visible_amount = lerpf(visible_amount, smoothstep(0.3, 0.9, openness), clampf(delta * 2.0, 0.0, 1.0))
	var any := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var xa := any.cross(axis).normalized()
	var ya := axis.cross(xa).normalized()
	var view := (camera_pos - centre).normalized()
	var graze := 1.0 - absf(view.dot(axis))
	var phase_vis := clampf(smoothstep(0.55, 0.9, graze) * 0.7 + (1.0 if phase_event > 0.0 else 0.0), 0.0, 1.0)
	var mm := multimesh.multimesh
	var k := 0
	var hot := Color(1.0, 0.62, 0.18)
	var gold := Color(0.86, 0.66, 0.30)
	var phase_col := Color(0.62, 0.42, 0.78)
	for i in INNER_N:
		var a := inner_angle + float(i) * TAU / float(INNER_N)
		var p := centre + (xa * cos(a) + ya * sin(a)) * INNER_R + axis * 0.004 * sin(a * 3.0 + inner_angle)
		var br := 0.55 + 0.45 * pow(0.5 + 0.5 * sin(a * 7.0 - inner_angle * 4.0), 2.0)
		var r := 0.0042 * bead_scale * (0.8 + 0.4 * br)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(r, r, r)), p))
		var c := hot.lerp(gold, 0.4)
		c.a = visible_amount * br * (0.6 + 0.4 * attention)
		mm.set_instance_color(k, c)
		k += 1
	for i in OUTER_N:
		var a := outer_angle + float(i) * TAU / float(OUTER_N)
		var p := centre + (xa * cos(a) + ya * sin(a)) * OUTER_R - axis * 0.01
		var br := 0.35 if (i % 3 != 0) else 0.9
		var r := 0.0032 * bead_scale * (0.7 + 0.6 * br)
		mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(r, r, r)), p))
		var c := gold
		c.a = visible_amount * br
		mm.set_instance_color(k, c)
		k += 1
	for i in PHASE_N:
		var a := phase_angle + float(i) * TAU / float(PHASE_N)
		var wobble := 0.012 * sin(a * 5.0 + phase_angle * 2.0)
		var p := centre + (xa * cos(a) + ya * sin(a)) * (PHASE_R + wobble) + axis * 0.02 * cos(a * 2.0)
		# Slivers: flattened along the ring.
		var r := 0.0035 * bead_scale
		var tang := (-xa * sin(a) + ya * cos(a)).normalized()
		var rad := tang.cross(axis).normalized()
		var basis := Basis(tang * r * 2.6, axis * r * 0.5, rad * r * 0.5)
		mm.set_instance_transform(k, Transform3D(basis, p))
		var c := phase_col
		c.a = visible_amount * phase_vis * 0.8
		mm.set_instance_color(k, c)
		k += 1
	multimesh.visible = enabled and not gray and visible_amount > 0.02


func set_debug_gray(on: bool) -> void:
	gray = on


func set_enabled(on: bool) -> void:
	enabled = on
