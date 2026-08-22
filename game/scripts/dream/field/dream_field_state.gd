class_name DreamFieldState
extends Resource
## The one canonical state every part of the Dream Field consumes
## (DREAM_FIELD_DIRECTION §16). The fog volumes, the depth-aware lens, the
## incarnating surfaces, the residue, the withdrawal and the tentacle all
## read THIS, which is what makes them read as one organism rather than a
## pile of effects (§14).

## The coordinate along the axis we cannot see. Advancing this — rather than
## moving anything through XYZ — is what makes the cross-section change
## topology in place.
@export var dream_w := 0.0
## The shared biological clocks, the same ones the tentacle runs on.
@export var pulse_phase := 0.0
@export var breath_phase := 0.0
@export_range(0.0, 1.0) var attention := 0.3
@export_range(0.0, 1.0) var incarnation := 0.0
@export_range(0.0, 1.0) var mineralization := 0.0
@export_range(0.0, 1.0) var vascular_pressure := 0.0
@export_range(0.0, 1.0) var phase_instability := 0.0
@export_range(0.0, 1.0) var contact_activity := 0.0
@export var seed := 1.0

## The live lobes, at most eight (§17): the anatomy currently near enough to
## our slice to matter. Each is {centre, radius, kind, w_offset, intensity,
## seed}.
var lobes: Array = []

const MAX_LOBES := 8
const KIND_MASS := 0
const KIND_TUBE := 1
const KIND_TOROID := 2
const KIND_FOLD := 3


func clear_lobes() -> void:
	lobes.clear()


func add_lobe(centre: Vector3, radius: float, kind: int, w_offset: float,
		intensity: float, lobe_seed: float) -> void:
	if lobes.size() >= MAX_LOBES:
		return
	lobes.append({"centre": centre, "radius": radius, "kind": kind,
			"w_offset": w_offset, "intensity": intensity, "seed": lobe_seed})


## The apparent 3-D radius of a lobe at the current slice — the whole trick,
## on the CPU as well so placement, residue and bounds agree with the shader.
func slice_radius(radius: float, w_offset: float) -> float:
	var d := dream_w - w_offset
	return sqrt(maxf(0.0, radius * radius - d * d))


## Is any part of this lobe in our space right now?
func lobe_present(i: int) -> bool:
	if i < 0 or i >= lobes.size():
		return false
	return slice_radius(float(lobes[i].radius), float(lobes[i].w_offset)) > 0.01


## Push the whole state onto one material. Every Dream shader takes the same
## uniform names, so this is the only place the packing lives.
func apply(m: ShaderMaterial) -> void:
	if m == null:
		return
	var centres := PackedVector4Array()
	var metas := PackedVector4Array()
	centres.resize(MAX_LOBES)
	metas.resize(MAX_LOBES)
	for i in MAX_LOBES:
		if i < lobes.size():
			var l: Dictionary = lobes[i]
			var c: Vector3 = l.centre
			centres[i] = Vector4(c.x, c.y, c.z, float(l.radius))
			metas[i] = Vector4(float(l.kind), float(l.w_offset), float(l.intensity),
					float(l.seed))
		else:
			centres[i] = Vector4.ZERO
			metas[i] = Vector4.ZERO
	m.set_shader_parameter("df_lobe", centres)
	m.set_shader_parameter("df_lobe_meta", metas)
	m.set_shader_parameter("df_lobe_count", mini(lobes.size(), MAX_LOBES))
	m.set_shader_parameter("df_dream_w", dream_w)
	m.set_shader_parameter("df_pulse", pulse_phase)
	m.set_shader_parameter("df_seed", seed)


## The field on the CPU, for placement and residue. A coarse mirror of the
## shader's `df_field`: the smooth union of the live lobes' slice spheres.
## Cheap on purpose — the exact anatomy belongs on the GPU.
func field_at(p: Vector3) -> float:
	var d := 1.0e6
	for i in lobes.size():
		var l: Dictionary = lobes[i]
		var r := slice_radius(float(l.radius), float(l.w_offset))
		if r <= 0.0001:
			continue
		var dist: float = (p - (l.centre as Vector3)).length() - r
		dist /= maxf(0.05, float(l.intensity))
		# The same smooth-min the shader uses, so the two agree on where
		# the body is.
		var k := 0.28
		var h := clampf(0.5 + 0.5 * (d - dist) / k, 0.0, 1.0)
		d = lerpf(d, dist, h) - k * h * (1.0 - h)
	return d


func influence_at(p: Vector3, skin := 0.25) -> float:
	return 1.0 - smoothstep(-skin, skin, field_at(p))
