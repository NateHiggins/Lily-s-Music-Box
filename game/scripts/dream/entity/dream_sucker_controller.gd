class_name DreamSuckerController
extends RefCounted
## Hero suckers (DREAM_TENTACLE_DIRECTION §16): two staggered ventral rows
## on the distal third as a MultiMesh of domes, placed on the rig's surface
## every frame. Near contact each sucker orients to the surface and engages
## in sequence from the tip backward — compresses, flattens, its rim lights
## — and releases in the reverse order when the limb leaves. Per-instance
## custom data: (engagement, rim light, sequence phase, size).

const SHADER := preload("res://shaders/dream_sucker.gdshader")
const ROWS := 2
const PER_ROW := 14
const V_FROM := 0.58
const V_TO := 0.96
const ENGAGE_DIST_M := 0.045

var multimesh: MultiMeshInstance3D
var material: ShaderMaterial
var engage := PackedFloat32Array()
var rim := PackedFloat32Array()
var count := 0
var engaged_count := 0
var _sequence_clock := 0.0
var last_events: Array[String] = []


func build(parent: Node3D) -> void:
	count = ROWS * PER_ROW
	engage.resize(count)
	rim.resize(count)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _dome_mesh()
	mm.instance_count = count
	material = ShaderMaterial.new()
	material.shader = SHADER
	multimesh = MultiMeshInstance3D.new()
	multimesh.name = "Suckers"
	multimesh.multimesh = mm
	multimesh.material_override = material
	multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(multimesh)


static func _dome_mesh() -> ArrayMesh:
	var rings := 6
	var segs := 14
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in rings + 1:
		var phi := (float(r) / float(rings)) * PI * 0.5
		for s in segs + 1:
			var th := (float(s) / float(segs)) * TAU
			var p := Vector3(cos(th) * cos(phi), sin(phi), sin(th) * cos(phi))
			verts.append(p)
			normals.append(p)
	for r in rings:
		for s in segs:
			var a := r * (segs + 1) + s
			var b := a + 1
			var c := a + segs + 1
			var d := c + 1
			indices.append(a); indices.append(b); indices.append(c)
			indices.append(b); indices.append(d); indices.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Place the suckers on the rig and engage those near the contact surface.
## `contact` / `contact_normal` describe the surface; `holding` is the
## behaviour's grip target; `grow` hides the part not yet through.
func update(rig: DreamTentacleRig, contact: Vector3, contact_normal: Vector3, holding: float,
		grow: float, delta: float) -> void:
	last_events.clear()
	_sequence_clock += delta
	var mm := multimesh.multimesh
	var k := 0
	var newly := 0
	var prev_engaged := engaged_count
	engaged_count = 0
	for row in ROWS:
		for i in PER_ROW:
			var v := lerpf(V_FROM, V_TO, (float(i) + 0.5 * float(row)) / float(PER_ROW))
			var u := 0.5 + (0.07 if row == 0 else -0.07)
			var sp := rig.surface_point(u, v, -0.002)
			var p: Vector3 = sp.pos
			var n: Vector3 = sp.normal
			var r := float(sp.radius)
			var size := clampf(r * 0.34, 0.006, 0.016)
			# Engagement: near the surface, facing it, in sequence from the
			# tip backward (the later the sucker from the tip, the later it
			# engages; release runs the other way).
			var to_surface := (p - contact).dot(contact_normal)
			var facing := maxf(0.0, -n.dot(contact_normal))
			var near := to_surface < ENGAGE_DIST_M and to_surface > -0.06 and facing > 0.25
			var order := float(PER_ROW - 1 - i) / float(PER_ROW)
			var want := 0.0
			if near and holding > 0.3:
				want = clampf((holding - order * 0.45) * 1.6, 0.0, 1.0)
			var was := engage[k]
			var rate := 6.0 if want > was else 3.5
			engage[k] = lerpf(was, want, clampf(delta * rate, 0.0, 1.0))
			if was < 0.5 and engage[k] >= 0.5:
				newly += 1
			if was >= 0.5 and engage[k] < 0.5:
				last_events.append("sucker_release")
			rim[k] = lerpf(rim[k], engage[k] * (0.6 + 0.4 * sin(_sequence_clock * 3.0 + float(i))), clampf(delta * 4.0, 0.0, 1.0))
			if engage[k] > 0.5:
				engaged_count += 1
			# Orientation: the dome's y is the sucker's normal; engaged suckers
			# turn to the surface.
			var up := n.lerp(-contact_normal, engage[k] * facing).normalized()
			var any := Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT
			var xa := any.cross(up).normalized()
			var za := up.cross(xa).normalized()
			var xf := Transform3D(Basis(xa, up, za), p)
			var hidden := v > grow
			if hidden:
				xf = Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), p)
			mm.set_instance_transform(k, xf)
			mm.set_instance_custom_data(k, Color(engage[k], rim[k], order, size))
			k += 1
	if newly > 0:
		last_events.append("sucker_attach")
	if engaged_count > 0 and prev_engaged == 0:
		last_events.append("first_contact")


func set_debug_gray(on: bool) -> void:
	material.set_shader_parameter("debug_gray", on)
