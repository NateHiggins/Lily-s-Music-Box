class_name DreamMembrane
extends RefCounted
## The wall membrane (DREAM_TENTACLE_DIRECTION §11): a disc of the Dream's
## tissue on the wall at the emergence point, driven by the behaviour's
## tension and the limb's progress through it. It never becomes a hole:
## after emergence it clings as a ring around the root.

const SHADER := preload("res://shaders/dream_membrane.gdshader")
const RADIUS_M := 0.30

var mesh: MeshInstance3D
var material: ShaderMaterial
var tension := 0.0
var through := 0.0


func build(parent: Node3D, at: Vector3, normal: Vector3, seed_v: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(RADIUS_M * 2.0, RADIUS_M * 2.0)
	plane.subdivide_width = 56
	plane.subdivide_depth = 56
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("radius_m", RADIUS_M)
	material.set_shader_parameter("seed", seed_v)
	mesh = MeshInstance3D.new()
	mesh.name = "Membrane"
	mesh.mesh = plane
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A PlaneMesh faces +y; lay it on the wall, 6 mm proud, facing out.
	var n := normal.normalized()
	var any := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var xa := any.cross(n).normalized()
	var za := n.cross(xa).normalized()
	mesh.transform = Transform3D(Basis(xa, n, za), at + n * 0.006)
	parent.add_child(mesh)


func update(want_tension: float, want_release: float, probe: Vector2,
		probe_depth: float, root_radius: float, delta: float) -> void:
	tension = lerpf(tension, want_tension, clampf(delta * 2.2, 0.0, 1.0))
	through = lerpf(through, clampf(want_release, 0.0, 1.0), clampf(delta * 3.0, 0.0, 1.0))
	material.set_shader_parameter("tension", tension)
	material.set_shader_parameter("through", through)
	material.set_shader_parameter("probe_offset", probe)
	material.set_shader_parameter("probe_depth", clampf(probe_depth, 0.0, 1.0))
	material.set_shader_parameter("root_radius_m", root_radius)
	mesh.visible = tension > 0.01 or through > 0.01


func set_debug_gray(on: bool) -> void:
	material.set_shader_parameter("debug_gray", on)
