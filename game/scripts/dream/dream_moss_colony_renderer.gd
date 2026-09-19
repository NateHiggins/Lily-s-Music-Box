class_name DreamMossColonyRenderer
extends Node3D
## Bounded presentation of one DreamMossColony. This node owns meshes, pulse
## interpolation and visibility only. Every ecological quantity is read from
## the colony record owned by DreamEcologyDirector.

const MAX_BRANCH_SEGMENTS := 64
const MAX_CILIA_VISIBLE := 32
const MAX_ETHER_MOTES := 24
const MAX_PROTEINS_VISIBLE := 64
const MAX_CILIA_CARPET := 256
const BRANCH_SIDES := 5
const CELL_SHADER := preload("res://shaders/dream_moss_cellular.gdshader")
const CILIA_SHADER := preload("res://shaders/dream_rooted_cilium.gdshader")
const CellularStateScript := preload("res://scripts/dream/dream_cellular_state.gd")
const PhenotypeScript := preload("res://scripts/dream/dream_cellular_phenotype.gd")

var colony = null
var _heart: MeshInstance3D
var _sheet: MeshInstance3D
var _network: MeshInstance3D
var _cilia: MultiMeshInstance3D
var _cilia_carpet: MultiMeshInstance3D
var _ether: MultiMeshInstance3D
var _pulse: MeshInstance3D
var _proteins: MultiMeshInstance3D
var _heart_material: ShaderMaterial
var _network_material: ShaderMaterial
var _cilia_material: ShaderMaterial
var _ether_material: StandardMaterial3D
var _pulse_material: ShaderMaterial
var _protein_material: ShaderMaterial
var _state_packet
var _phenotype: Dictionary
var _clock := 0.0
var _refresh_clock := 0.0
var _report_clock := 0.0
var _report_from := Vector3.ZERO
var _report_value := 0.0
var _last_route_signature := ""
var _peak_visible := 0
var _report_presentations := 0
var _cilia_lod := "near"


func setup(owner_colony) -> void:
	colony = owner_colony
	name = "MossColony_%s" % str(colony.source_id)
	_build_materials()
	_build_heart()
	_build_sheet()
	_build_network()
	_build_cilia()
	_build_cilia_carpet()
	_build_ether()
	_build_pulse()
	_build_proteins()
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
	_animate_proteins()


func _build_materials() -> void:
	_phenotype = PhenotypeScript.profile(PhenotypeScript.Kind.MOSS, int(colony.seed))
	_heart_material = _cell_material(1.0)
	_network_material = _cell_material(0.0)
	_heart_material.set_shader_parameter("tissue_alpha", .92)
	_network_material.set_shader_parameter("tissue_alpha", .98)
	_cilia_material = ShaderMaterial.new()
	_cilia_material.shader = CILIA_SHADER
	_ether_material = _material(Color(0.20, 0.52, 0.48, 0.44), Color(0.08, 0.24, 0.22), 0.26, 0.10)
	_pulse_material = _cell_material(2.0)
	_protein_material = _cell_material(2.0)


func _cell_material(role: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CELL_SHADER
	material.set_shader_parameter("cellular_seed", float(colony.seed % 8191) * 0.013)
	material.set_shader_parameter("cellular_phenotype", Vector4(
			float(_phenotype.organization), float(_phenotype.windows),
			float(_phenotype.proteins), float(_phenotype.refractive)))
	material.set_shader_parameter("membrane_role", role)
	return material


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


func _build_sheet() -> void:
	_sheet = MeshInstance3D.new()
	_sheet.name = "PlasmodialFans"
	_sheet.material_override = _network_material
	add_child(_sheet)
	_rebuild_sheet()


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
	multimesh.use_custom_data = true
	multimesh.instance_count = MAX_CILIA_VISIBLE
	multimesh.visible_instance_count = 0
	multimesh.mesh = mesh
	_cilia.multimesh = multimesh
	add_child(_cilia)


func _build_cilia_carpet() -> void:
	_cilia_carpet = MultiMeshInstance3D.new()
	_cilia_carpet.name = "CiliaryCarpet"
	var ribbon := _curved_cilia_cluster_mesh()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = MAX_CILIA_CARPET
	multimesh.visible_instance_count = 0
	multimesh.mesh = ribbon
	_cilia_carpet.multimesh = multimesh
	_cilia_carpet.custom_aabb = AABB(Vector3(-1.8, -0.1, -1.8), Vector3(3.6, 0.6, 3.6))
	add_child(_cilia_carpet)


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


func _build_proteins() -> void:
	_proteins = MultiMeshInstance3D.new()
	_proteins.name = "MembraneProteinFamilies"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.010
	mesh.outer_radius = 0.030
	mesh.rings = 8
	mesh.ring_segments = 6
	mesh.material = _protein_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = MAX_PROTEINS_VISIBLE
	multimesh.visible_instance_count = 0
	multimesh.mesh = mesh
	_proteins.multimesh = multimesh
	add_child(_proteins)


func _refresh(force: bool) -> void:
	visible = colony != null and colony.phase != colony.Phase.CLEARED
	if not visible:
		return
	global_position = colony.origin if colony.origin != Vector3.INF else Vector3.ZERO
	var signature := _route_signature()
	if force or signature != _last_route_signature:
		_rebuild_network()
		_rebuild_sheet()
		_last_route_signature = signature
	var cilia_count := 0 if colony.phase >= colony.Phase.STAINED else \
			mini(MAX_CILIA_VISIBLE, _count_class(colony.OrganismClass.CILIUM))
	_cilia.multimesh.visible_instance_count = cilia_count
	var ether_count := clampi(int(colony.connected_ether_volume * 5.0), 0, MAX_ETHER_MOTES)
	if colony.phase >= colony.Phase.WITHERING:
		ether_count = int(float(ether_count) * (1.0 - colony.collapse_progress))
	_ether.multimesh.visible_instance_count = ether_count
	var information := clampf(colony.stored_information / 8.0, 0.0, 1.0)
	var protein_count := clampi(6 + int(colony.maturity * 14.0 + information * 8.0), 0, 28)
	if colony.phase >= colony.Phase.STAINED:
		protein_count = int(float(protein_count) * (0.32 if colony.phase == colony.Phase.STAINED else 0.0))
	_proteins.multimesh.visible_instance_count = protein_count
	_update_state_packet()
	_peak_visible = maxi(_peak_visible, 2 + cilia_count + ether_count + protein_count)


func _animate_heart() -> void:
	var maturity: float = colony.maturity
	var searching: bool = colony.phase == colony.Phase.SEARCHING
	var scale_value := 0.42 if searching else 0.55 + maturity * 1.35
	var breath: float = 1.0 + sin(_clock * (2.4 + colony.ether_production * 2.0)) * (0.035 + colony.ether_reserve * 0.06)
	if colony.phase == colony.Phase.DISTURBED:
		breath *= 0.86 + 0.12 * sin(_clock * 13.0)
	elif colony.phase >= colony.Phase.WITHERING:
		scale_value *= maxf(0.04, 1.0 - colony.collapse_progress)
	_heart.scale = Vector3(scale_value * 1.12, scale_value * 0.62, scale_value * 0.82) * breath
	var dead := clampf(colony.collapse_progress, 0.0, 1.0)
	_network.scale = Vector3(1.0, maxf(0.08, 1.0 - dead), 1.0)
	_sheet.scale = Vector3(1.0, maxf(0.04, 1.0 - dead * 0.88), 1.0)


func _animate_cilia() -> void:
	var ecological_count := mini(MAX_CILIA_VISIBLE, _count_class(colony.OrganismClass.CILIUM))
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var distance := global_position.distance_to(camera.global_position) if camera != null else 0.0
	var count := ecological_count
	_cilia_lod = "near"
	if distance > 8.0:
		count = int(ceil(float(ecological_count) * 0.25)); _cilia_lod = "far"
	elif distance > 3.5:
		count = int(ceil(float(ecological_count) * 0.55)); _cilia_lod = "mid"
	_cilia.multimesh.visible_instance_count = count
	var carpet_count := 0
	if ecological_count > 0 and colony.phase < colony.Phase.WITHERING:
		carpet_count = MAX_CILIA_CARPET if _cilia_lod == "near" else (96 if _cilia_lod == "mid" else 0)
	_cilia_carpet.multimesh.visible_instance_count = carpet_count
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
		_cilia.multimesh.set_instance_custom_data(i, Color(
				_hash01(i * 43 + colony.seed), 0.0, float(i % 2), 1.0))
	for i in carpet_count:
		var u := _hash01(i * 73 + colony.seed)
		var v := _hash01(i * 181 + colony.seed * 3)
		var angle := u * TAU
		var radius: float = 0.10 + sqrt(v) * (0.18 + float(colony.maturity) * 0.42)
		var wave := sin(_clock * 3.1 + radius * 18.0 + angle * 2.0) * 0.30
		var disturbed: float = float(colony.disturbance) * sin(float(i) * 2.31) * 0.55
		var basis := Basis(Vector3.UP, angle + floor(angle / (PI * 0.5)) * 0.17 + wave + disturbed)
		basis = basis.rotated(Vector3.RIGHT, 0.06 + wave * 0.12)
		basis = basis.scaled(Vector3(0.72, 0.62 + 0.38 * _hash01(i * 43 + colony.seed), 0.72))
		var at: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * radius + Vector3.UP * 0.036
		_cilia_carpet.multimesh.set_instance_transform(i, Transform3D(basis, at))
		_cilia_carpet.multimesh.set_instance_custom_data(i, Color(u, v, float(i % 7) / 6.0, 1.0))


func _animate_proteins() -> void:
	var count: int = _proteins.multimesh.visible_instance_count
	var hop_open: bool = colony.phase < colony.Phase.WITHERING
	for i in count:
		var compartment := i % 7
		var u := _hash01(i * 97 + colony.seed)
		var base_angle := float(compartment) / 7.0 * TAU
		var confined := sin(_clock * (0.11 + 0.03 * float(i % 3)) + u * TAU) * 0.07
		var hop: float = floor(_clock * 0.20 + u * 5.0) if hop_open else 0.0
		var angle: float = base_angle + confined + hop * 0.19
		var radius := 0.12 + 0.05 * float(i % 5)
		var cluster := clampf(colony.stored_information / 8.0 + _report_value, 0.0, 1.0)
		radius = lerpf(radius, 0.09 + 0.015 * float(i % 3), cluster)
		var at := Vector3(cos(angle) * radius, 0.043 + 0.004 * float(i % 3), sin(angle) * radius)
		var family := i % 5
		var basis := Basis(Vector3.UP, angle)
		if family == 1: basis = basis.scaled(Vector3(1.7, 0.72, 0.72))
		elif family == 2: basis = basis.scaled(Vector3(0.78, 1.0, 1.45))
		elif family == 3: basis = basis.scaled(Vector3(1.25, 0.65, 1.25))
		elif family == 4: basis = basis.scaled(Vector3(0.70, 1.35, 0.70))
		basis = basis.rotated(Vector3.RIGHT, 0.10 * sin(_clock + float(i)))
		_proteins.multimesh.set_instance_transform(i, Transform3D(basis, at))
		_proteins.multimesh.set_instance_custom_data(i, Color(float(i % 7) / 6.0, cluster, hop, 1.0))


func _update_state_packet() -> void:
	var withering: float = clampf(colony.collapse_progress, 0.0, 1.0)
	_state_packet = CellularStateScript.new({
		"ether": colony.ether_reserve,
		"information": colony.stored_information / 8.0,
		"novelty": 1.0 / float(1 + colony.known_targets.size()),
		"contact": colony.disturbance,
		"reporting": clampf(_report_clock, 0.0, 1.0),
		"breathing": clampf(colony.ether_production + float(colony.reports) * 0.04, 0.0, 1.0),
		"disturbance": colony.disturbance,
		"recall": 1.0 if colony.phase == colony.Phase.DISTURBED else 0.0,
		"senescence": withering,
		"death": 1.0 if colony.phase >= colony.Phase.STAINED else 0.0,
		"cleanup": 1.0 if colony.phase == colony.Phase.CLEARED else 0.0,
	})
	for material in [_heart_material, _network_material, _pulse_material, _protein_material]:
		material.set_shader_parameter("cellular_state_a", _state_packet.to_vector_a())
		material.set_shader_parameter("cellular_state_b", _state_packet.to_vector_b())
		material.set_shader_parameter("cellular_state_c", _state_packet.to_vector_c())
		material.set_shader_parameter("cellular_time", _clock)
	for material in [_cilia_material]:
		material.set_shader_parameter("cellular_state_a", _state_packet.to_vector_a())
		material.set_shader_parameter("cellular_state_b", _state_packet.to_vector_b())
		material.set_shader_parameter("cellular_state_c", _state_packet.to_vector_c())
		material.set_shader_parameter("cellular_time", _clock)


func _animate_ether() -> void:
	var count: int = _ether.multimesh.visible_instance_count
	var extent: float = maxf(0.25, colony.extent * 0.55)
	for i in count:
		var u := _hash01(i * 73 + colony.seed)
		var v := _hash01(i * 151 + colony.seed * 3)
		if i < 12:
			# Suspended vesicles and contractile vacuoles share the existing
			# bounded ether batch, but live beneath the translucent heart skin.
			var inner_angle := u*TAU + _clock*(.04+.01*float(i%3))
			var inner_radius := .04 + v*.16
			var inner := Vector3(cos(inner_angle)*inner_radius,
					.025 + .018*sin(_clock*.6+float(i)),sin(inner_angle)*inner_radius*.72)
			var inner_size := 1.15 + float(i%4)*.38
			_ether.multimesh.set_instance_transform(i,
					Transform3D(Basis.IDENTITY.scaled(Vector3(inner_size,inner_size*(1.0+float(i%2)),inner_size)),inner))
			continue
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


func _rebuild_sheet() -> void:
	if _sheet == null or colony == null or colony.origin == Vector3.INF:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _network_material)
	var phase_scale: float = [0.20, 0.28, 0.36, 0.45, 0.54, 0.64,
		0.58, 0.50, 0.40, 0.30, 0.0][clampi(colony.phase, 0, 10)]
	# One sampled implicit body forms every lobe and saddle.  This keeps the
	# plasmodium watertight-looking: there are no stacked pads or intersection
	# seams, while distal low fields naturally become thin pseudopod fans.
	var lobes := [
		[Vector3(-.03,.044,.01), Vector3(.25,.050,.21)],
		[Vector3(.14,.036,.05), Vector3(.20,.036,.15)],
		[Vector3(.31,.031,.11), Vector3(.24,.030,.14)],
		[Vector3(.50,.022,.16), Vector3(.30,.018,.18)],
		[Vector3(.66,.014,.12), Vector3(.25,.010,.23)],
		[Vector3(-.16,.034,.10), Vector3(.20,.032,.14)],
		[Vector3(-.32,.027,.21), Vector3(.25,.024,.16)],
		[Vector3(-.49,.016,.34), Vector3(.28,.012,.22)],
		[Vector3(-.04,.033,-.15), Vector3(.17,.030,.20)],
		[Vector3(-.10,.024,-.33), Vector3(.20,.020,.25)],
		[Vector3(.03,.014,-.52), Vector3(.30,.011,.22)],
		[Vector3(.25,.019,-.20), Vector3(.19,.017,.14)],
	]
	_append_fused_plasmodium(mesh, lobes, phase_scale / .64)
	mesh.surface_end()
	_sheet.mesh = mesh


func _append_fused_plasmodium(mesh: ImmediateMesh, lobes: Array, spread: float) -> void:
	const CELLS := 54
	const MIN_X := -0.78
	const MAX_X := 0.88
	const MIN_Z := -0.77
	const MAX_Z := 0.55
	for zi in CELLS:
		for xi in CELLS:
			var x0 := lerpf(MIN_X, MAX_X, float(xi) / CELLS)
			var x1 := lerpf(MIN_X, MAX_X, float(xi + 1) / CELLS)
			var z0 := lerpf(MIN_Z, MAX_Z, float(zi) / CELLS)
			var z1 := lerpf(MIN_Z, MAX_Z, float(zi + 1) / CELLS)
			var samples := [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)]
			var fields: Array[float] = []
			for sample in samples: fields.append(_plasmodium_field(sample,lobes,spread))
			if fields.max() < .34: continue
			var points: Array[Vector3] = []
			for i in 4:
				var edge := smoothstep(.34,.56,fields[i])
				var height := .004 + edge * (.015 + minf(fields[i],1.45)*.026)
				points.append(Vector3(samples[i].x,height,samples[i].y))
			_add_sheet_tri(mesh,points[0],points[1],points[2])
			_add_sheet_tri(mesh,points[0],points[2],points[3])


func _plasmodium_field(point: Vector2, lobes: Array, spread: float) -> float:
	var field := 0.0
	for record in lobes:
		var center: Vector3 = record[0] * Vector3(spread,1.0,spread)
		var radii: Vector3 = record[1] * Vector3(spread,1.0,spread)
		var dx := (point.x-center.x)/maxf(radii.x,.01)
		var dz := (point.y-center.z)/maxf(radii.z,.01)
		field += exp(-(dx*dx+dz*dz)*1.32)
	return field


func _add_sheet_tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0.0: normal = -normal
	for point in [a, b, c]:
		mesh.surface_set_normal(normal)
		mesh.surface_set_uv(Vector2(point.x, point.z))
		mesh.surface_add_vertex(point)


func _append_sheet_ellipsoid(mesh: ImmediateMesh, center: Vector3, radii: Vector3,
		sides: int, rings: int) -> void:
	for ring in rings:
		var v0 := float(ring) / float(rings)
		var v1 := float(ring + 1) / float(rings)
		var p0 := -PI * .5 + v0 * PI
		var p1 := -PI * .5 + v1 * PI
		for side_i in sides:
			var u0 := float(side_i) / float(sides)
			var u1 := float(side_i + 1) / float(sides)
			var a0 := u0 * TAU
			var a1 := u1 * TAU
			var pa := center + Vector3(cos(p0)*cos(a0),sin(p0),cos(p0)*sin(a0))*radii
			var pb := center + Vector3(cos(p0)*cos(a1),sin(p0),cos(p0)*sin(a1))*radii
			var pc := center + Vector3(cos(p1)*cos(a1),sin(p1),cos(p1)*sin(a1))*radii
			var pd := center + Vector3(cos(p1)*cos(a0),sin(p1),cos(p1)*sin(a0))*radii
			_add_smooth_sheet_tri(mesh, pa, pb, pc, center, radii)
			_add_smooth_sheet_tri(mesh, pa, pc, pd, center, radii)


func _add_smooth_sheet_tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3,
		center: Vector3, radii: Vector3) -> void:
	for point in [a,b,c]:
		var local: Vector3 = point - center
		mesh.surface_set_normal(Vector3(local.x/(radii.x*radii.x),
				local.y/(radii.y*radii.y),local.z/(radii.z*radii.z)).normalized())
		mesh.surface_set_uv(Vector2(point.x,point.z))
		mesh.surface_add_vertex(point)


func _curved_cilia_cluster_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _cilia_material)
	for strand in 7:
		var offset := (float(strand)-3.0)*.009
		for segment in 5:
			var t0 := float(segment)/5.0
			var t1 := float(segment+1)/5.0
			var strand_phase := (float(strand)-3.0)*.47
			var y0 := t0*.062*(.88+float(strand%2)*.12)
			var y1 := t1*.062*(.88+float(strand%2)*.12)
			var w0 := lerpf(.0018,.00018,t0)
			var w1 := lerpf(.0018,.00018,t1)
			var c0 := Vector3(offset + sin(t0*1.7+strand_phase)*t0*.010,y0,sin(t0*PI+strand_phase)*.014)
			var c1 := Vector3(offset + sin(t1*1.7+strand_phase)*t1*.010,y1,sin(t1*PI+strand_phase)*.014)
			for record in [[c0-Vector3(w0,0,0),Vector2(0,t0)],
					[c0+Vector3(w0,0,0),Vector2(1,t0)],
					[c1+Vector3(w1,0,0),Vector2(1,t1)],
					[c0-Vector3(w0,0,0),Vector2(0,t0)],
					[c1+Vector3(w1,0,0),Vector2(1,t1)],
					[c1-Vector3(w1,0,0),Vector2(0,t1)]]:
				mesh.surface_set_normal(Vector3.FORWARD)
				mesh.surface_set_uv(record[1])
				mesh.surface_add_vertex(record[0])
	mesh.surface_end()
	return mesh


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
			"cilia_carpet_visible": _cilia_carpet.multimesh.visible_instance_count if presented and _cilia_carpet != null else 0,
			"ether_motes": _ether.multimesh.visible_instance_count if presented and _ether != null else 0,
			"proteins_visible": _proteins.multimesh.visible_instance_count if presented and _proteins != null else 0,
			"cilia_lod": _cilia_lod,
			"report_presentations": _report_presentations,
			"report_visible": presented and _pulse != null and _pulse.visible,
			"peak_visible_elements": _peak_visible,
			"caps": {"branch_segments": MAX_BRANCH_SEGMENTS,
				"cilia": MAX_CILIA_VISIBLE, "cilia_carpet": MAX_CILIA_CARPET,
				"ether_motes": MAX_ETHER_MOTES,
				"membrane_proteins": MAX_PROTEINS_VISIBLE}}


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
