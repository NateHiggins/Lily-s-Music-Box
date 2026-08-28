class_name DreamMossColonyRenderer
extends Node3D
## Bounded presentation of one DreamMossColony. This node owns meshes, pulse
## interpolation and visibility only. Every ecological quantity is read from
## the colony record owned by DreamEcologyDirector.

const MAX_BRANCH_SEGMENTS := 64
const MAX_CILIA_VISIBLE := 8
const MAX_ETHER_MOTES := 24
const BRANCH_SIDES := 5

var colony = null
var _heart: MeshInstance3D
var _network: MeshInstance3D
var _cilia: MultiMeshInstance3D
var _ether: MultiMeshInstance3D
var _pulse: MeshInstance3D
var _heart_material: StandardMaterial3D
var _network_material: StandardMaterial3D
var _cilia_material: StandardMaterial3D
var _ether_material: StandardMaterial3D
var _pulse_material: StandardMaterial3D
var _clock := 0.0
var _refresh_clock := 0.0
var _report_clock := 0.0
var _report_from := Vector3.ZERO
var _report_value := 0.0
var _last_route_signature := ""
var _peak_visible := 0
var _report_presentations := 0


func setup(owner_colony) -> void:
	colony = owner_colony
	name = "MossColony_%s" % str(colony.source_id)
	_build_materials()
	_build_heart()
	_build_network()
	_build_cilia()
	_build_ether()
	_build_pulse()
	_refresh(true)


func present_report(from: Vector3, value: float) -> void:
	if colony == null or value <= 0.0:
		return
	_report_from = from
	_report_value = clampf(value, 0.0, 1.0)
	_report_clock = 1.0
	_report_presentations += 1
	_pulse.visible = true


func _process(delta: float) -> void:
	if colony == null:
		visible = false
		return
	_clock += delta
	_refresh_clock -= delta
	if _refresh_clock <= 0.0:
		_refresh(false)
		_refresh_clock = 0.20
	_animate_heart()
	_animate_cilia()
	_animate_ether()
	_animate_report(delta)


func _build_materials() -> void:
	_heart_material = _material(Color(0.26, 0.035, 0.38, 0.90), Color(0.18, 0.015, 0.30), 0.34, 0.46)
	_network_material = _material(Color(0.31, 0.045, 0.43, 0.82), Color(0.12, 0.008, 0.20), 0.42, 0.52)
	_cilia_material = _material(Color(0.44, 0.10, 0.58, 0.92), Color(0.22, 0.03, 0.34), 0.30, 0.38)
	_ether_material = _material(Color(0.46, 0.18, 0.68, 0.16), Color(0.20, 0.05, 0.36), 0.20, 0.16)
	_pulse_material = _material(Color(0.78, 0.34, 0.96, 0.92), Color(0.75, 0.18, 1.0), 0.12, 1.0)


func _material(color: Color, emission: Color, roughness: float, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.08
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _build_heart() -> void:
	_heart = MeshInstance3D.new()
	_heart.name = "MossHeart"
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.18
	mesh.radial_segments = 16
	mesh.rings = 8
	_heart.mesh = mesh
	_heart.material_override = _heart_material
	add_child(_heart)


func _build_network() -> void:
	_network = MeshInstance3D.new()
	_network.name = "VascularNetwork"
	_network.material_override = _network_material
	add_child(_network)


func _build_cilia() -> void:
	_cilia = MultiMeshInstance3D.new()
	_cilia.name = "CiliaBed"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.004
	mesh.bottom_radius = 0.012
	mesh.height = 0.20
	mesh.radial_segments = 5
	mesh.rings = 1
	mesh.material = _cilia_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = MAX_CILIA_VISIBLE
	multimesh.visible_instance_count = 0
	multimesh.mesh = mesh
	_cilia.multimesh = multimesh
	add_child(_cilia)


func _build_ether() -> void:
	_ether = MultiMeshInstance3D.new()
	_ether.name = "EtherAtmosphere"
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _ether_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = MAX_ETHER_MOTES
	multimesh.visible_instance_count = 0
	multimesh.mesh = mesh
	_ether.multimesh = multimesh
	add_child(_ether)


func _build_pulse() -> void:
	_pulse = MeshInstance3D.new()
	_pulse.name = "InformationReturnPulse"
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 10
	mesh.rings = 5
	_pulse.mesh = mesh
	_pulse.material_override = _pulse_material
	_pulse.visible = false
	add_child(_pulse)


func _refresh(force: bool) -> void:
	visible = colony != null and colony.phase != colony.Phase.CLEARED
	if not visible:
		return
	global_position = colony.origin if colony.origin != Vector3.INF else Vector3.ZERO
	var signature := _route_signature()
	if force or signature != _last_route_signature:
		_rebuild_network()
		_last_route_signature = signature
	var cilia_count := 0 if colony.phase >= colony.Phase.STAINED else \
			mini(MAX_CILIA_VISIBLE, _count_class(colony.OrganismClass.CILIUM))
	_cilia.multimesh.visible_instance_count = cilia_count
	var ether_count := clampi(int(colony.connected_ether_volume * 5.0), 0, MAX_ETHER_MOTES)
	if colony.phase >= colony.Phase.WITHERING:
		ether_count = int(float(ether_count) * (1.0 - colony.collapse_progress))
	_ether.multimesh.visible_instance_count = ether_count
	_peak_visible = maxi(_peak_visible, 2 + cilia_count + ether_count)


func _animate_heart() -> void:
	var maturity: float = colony.maturity
	var searching: bool = colony.phase == colony.Phase.SEARCHING
	var scale_value := 0.42 if searching else 0.55 + maturity * 1.35
	var breath: float = 1.0 + sin(_clock * (2.4 + colony.ether_production * 2.0)) * (0.035 + colony.ether_reserve * 0.06)
	if colony.phase == colony.Phase.DISTURBED:
		breath *= 0.86 + 0.12 * sin(_clock * 13.0)
	elif colony.phase >= colony.Phase.WITHERING:
		scale_value *= maxf(0.04, 1.0 - colony.collapse_progress)
	_heart.scale = Vector3(scale_value, scale_value * 0.38, scale_value) * breath
	var dead := clampf(colony.collapse_progress, 0.0, 1.0)
	_heart_material.albedo_color = Color(0.26, 0.035, 0.38, 0.90).lerp(Color(0.12, 0.075, 0.10, 0.74), dead)
	_heart_material.emission_energy_multiplier = maxf(0.0, 0.46 * (1.0 - dead))
	_network_material.albedo_color = Color(0.31, 0.045, 0.43, 0.82).lerp(
			Color(0.24, 0.065, 0.12, 0.88), dead)
	_network_material.emission = Color(0.16, 0.018, 0.06)
	_network_material.emission_energy_multiplier = maxf(0.08 * dead,
			0.52 * (1.0 - dead))
	_network.scale = Vector3(1.0, maxf(0.08, 1.0 - dead), 1.0)


func _animate_cilia() -> void:
	var count: int = _cilia.multimesh.visible_instance_count
	for i in count:
		var angle := float(i) * 2.399963 + sin(float(colony.seed % 31)) * 0.2
		var radius := 0.16 + 0.035 * float(i % 3)
		var fold := 1.0
		if colony.phase >= colony.Phase.DISTURBED:
			fold = maxf(0.08, 1.0 - colony.collapse_progress * 1.3)
		var sweep := sin(_clock * 2.6 + float(i) * 0.83) * 0.22 * fold
		var at := Vector3(cos(angle) * radius, 0.055, sin(angle) * radius)
		var basis := Basis(Vector3.UP, angle + sweep)
		basis = basis.rotated(Vector3.RIGHT, 0.45 + (1.0 - fold) * 1.0)
		basis = basis.scaled(Vector3(1.0, fold, 1.0))
		_cilia.multimesh.set_instance_transform(i, Transform3D(basis, at))


func _animate_ether() -> void:
	var count: int = _ether.multimesh.visible_instance_count
	var extent: float = maxf(0.25, colony.extent * 0.55)
	for i in count:
		var u := _hash01(i * 73 + colony.seed)
		var v := _hash01(i * 151 + colony.seed * 3)
		var angle := u * TAU + _clock * (0.07 + 0.02 * float(i % 4))
		var radius := extent * (0.18 + 0.76 * v)
		var at := Vector3(cos(angle) * radius,
				0.08 + sin(_clock * 0.7 + float(i)) * 0.06 + v * 0.34,
				sin(angle) * radius)
		var concentration: float = colony.ether_at(global_position + at)
		var size := 0.25 + concentration * 0.9
		_ether.multimesh.set_instance_transform(i,
				Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at))


func _animate_report(delta: float) -> void:
	if _report_clock <= 0.0:
		_pulse.visible = false
		return
	_report_clock = maxf(0.0, _report_clock - delta * (0.75 + _report_value))
	var t := 1.0 - _report_clock
	var local_from := _report_from - global_position
	_pulse.position = local_from.lerp(Vector3(0, 0.08, 0), smoothstep(0.0, 1.0, t))
	_pulse.scale = Vector3.ONE * (0.65 + _report_value * 0.8) * (0.7 + sin(t * PI) * 0.4)
	if _report_clock <= 0.0:
		_pulse.visible = false


func _rebuild_network() -> void:
	var available := 0
	for route in colony.routes.values():
		if bool(route.live) and float(route.strength) > 0.015:
			available += maxi(0, (route.points as PackedVector3Array).size() - 1)
	if available <= 0:
		_network.mesh = null
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _network_material)
	var segments := 0
	var route_ids: Array = colony.routes.keys()
	route_ids.sort()
	for route_id in route_ids:
		var route: Dictionary = colony.routes[route_id]
		if not bool(route.live) or float(route.strength) <= 0.015:
			continue
		var points: PackedVector3Array = route.points
		for i in range(points.size() - 1):
			if segments >= MAX_BRANCH_SEGMENTS:
				break
			_append_branch(mesh, points[i] - colony.origin,
					points[i + 1] - colony.origin, float(route.strength), segments)
			segments += 1
	mesh.surface_end()
	_network.mesh = mesh


func _append_branch(mesh: ImmediateMesh, a: Vector3, b: Vector3,
		strength: float, segment_seed: int) -> void:
	var direction := b - a
	if direction.length_squared() < 0.0001:
		return
	var tangent := direction.normalized()
	var reference := Vector3.UP if absf(tangent.y) < 0.88 else Vector3.RIGHT
	var side := tangent.cross(reference).normalized()
	var radius := 0.010 + strength * 0.028
	var irregular := 0.82 + _hash01(segment_seed * 19 + colony.seed) * 0.35
	radius *= irregular
	for side_i in BRANCH_SIDES:
		var angle_a := TAU * float(side_i) / float(BRANCH_SIDES)
		var angle_b := TAU * float(side_i + 1) / float(BRANCH_SIDES)
		var ring_a := side.rotated(tangent, angle_a) * radius
		var ring_b := side.rotated(tangent, angle_b) * radius
		mesh.surface_set_normal(ring_a.normalized())
		mesh.surface_add_vertex(a + ring_a + Vector3.UP * 0.018)
		mesh.surface_set_normal(ring_b.normalized())
		mesh.surface_add_vertex(a + ring_b + Vector3.UP * 0.018)
		mesh.surface_set_normal(ring_a.normalized())
		mesh.surface_add_vertex(b + ring_a + Vector3.UP * 0.018)
		mesh.surface_set_normal(ring_b.normalized())
		mesh.surface_add_vertex(a + ring_b + Vector3.UP * 0.018)
		mesh.surface_set_normal(ring_b.normalized())
		mesh.surface_add_vertex(b + ring_b + Vector3.UP * 0.018)
		mesh.surface_set_normal(ring_a.normalized())
		mesh.surface_add_vertex(b + ring_a + Vector3.UP * 0.018)


func census() -> Dictionary:
	var presented := visible and is_inside_tree()
	return {"colony_source": colony.source_id if colony != null else -1,
			"owns_simulation": false, "nodes": get_child_count() + 1,
			"heart_visible": presented and _heart != null and _heart.visible,
			"cilia_visible": _cilia.multimesh.visible_instance_count if presented and _cilia != null else 0,
			"ether_motes": _ether.multimesh.visible_instance_count if presented and _ether != null else 0,
			"report_presentations": _report_presentations,
			"report_visible": presented and _pulse != null and _pulse.visible,
			"peak_visible_elements": _peak_visible,
			"caps": {"branch_segments": MAX_BRANCH_SEGMENTS,
				"cilia": MAX_CILIA_VISIBLE, "ether_motes": MAX_ETHER_MOTES}}


func _route_signature() -> String:
	var rows: Array[String] = []
	var ids: Array = colony.routes.keys()
	ids.sort()
	for route_id in ids:
		var route: Dictionary = colony.routes[route_id]
		rows.append("%s:%d:%d:%d" % [route_id, int(bool(route.live)),
				int(float(route.strength) * 1000.0), (route.points as PackedVector3Array).size()])
	return "|".join(rows)


func _count_class(kind: int) -> int:
	var total := 0
	for organism in colony.organisms:
		if int(organism["class"]) == kind and not bool(organism.senescent):
			total += 1
	return total


static func _hash01(value: int) -> float:
	return float(posmod(value * 1103515245 + 12345, 65521)) / 65520.0
