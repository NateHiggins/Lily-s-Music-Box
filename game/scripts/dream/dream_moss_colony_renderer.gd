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
## V2's waking colonies (Lily, 2026-11-09) are drawn from the Blender-authored
## cell in res://assets/dream/waking_colony: an opalescent, lensing membrane over
## genuinely interior organelles that stream around the cell, and a fringe of
## jointed cilia that step in a metachronal wave. The procedural presentation
## stays built (its census and report seams are unchanged) but is hidden.
## Set before setup.
var waking_style := false
const WAKING_CELL := "res://assets/dream/waking_colony/waking_colony.glb"
const WAKING_CILIA := 150
var _waking: Node3D
var _waking_materials: Array[ShaderMaterial] = []
var _waking_skeleton: MeshInstance3D
## The waking cell crawls and feels (Lily, 2026-11-13: "slowly crawl around
## the floor with the cilia touching objects in its reach ... exploratively").
## Presentation only: the colony record, its source point and everything the
## ecology reads stay where the colony is rooted. The drawn cell wanders on a
## leash around that point, keeps to open floor, and its cilia reach out to
## whatever the feelers find near its rim.
## Her ruling on the first film (waking_cell_crawl_film_20261113): roam the
## room faster and farther, more cilia touching with a longer reach, stronger
## colour, and the cilia deliberate, like a hive mind.
const WAKING_CRAWL_SPEED := 0.06         # metres a second at full pace
const WAKING_CRAWL_LEASH := 3.5          # metres from where it is rooted
const WAKING_BODY_RADIUS := 0.26
const WAKING_TOUCH_REACH := 0.32         # metres beyond the membrane
const WAKING_FEELERS := 24
const WAKING_LIMB_LENGTH := 0.124        # a cilium's reach, straightened, at scale one
const WAKING_LIMB_STRETCH := 2.3         # how far a reaching limb may lengthen
var crawl_enabled := true
## The room it may roam, in world X and Z; empty means the leash alone.
var crawl_bounds := Rect2()
var _crawl_target := Vector3.ZERO
var _crawl_rest := 0.0
var _crawl_check := 0.0
var _crawl_travelled := 0.0
var _crawl_effort := 0.0
var _crawl_heading := Vector2.ZERO
var _crawl_rng := RandomNumberGenerator.new()
var _feel_clock := 0.0
var _feel_hits: Array[Dictionary] = []
## What the whole cell is attending to: every cilium on that side turns to it.
var _attend_point := Vector3.ZERO
var _attend_want := 0.0
var _attend := 0.0
var _attend_shown := 0.0
var _study_cooldown := 0.0
var _waking_cilia: MultiMeshInstance3D
var _cilia_roots: Array[Dictionary] = []
var _cilia_rest_basis: Array[Basis] = []
var _cilia_rest_scale := PackedFloat32Array()
var _cilia_touch := PackedFloat32Array()
var _cilia_want := PackedFloat32Array()
var _cilia_aim: Array[Vector3] = []
var _organelles: Array[Dictionary] = []
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
	if waking_style:
		_build_waking()
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
	if waking_style and _waking != null:
		_animate_waking()
		_animate_touch(delta)
		return
	_animate_heart()
	_animate_cilia()
	_animate_ether()
	_animate_report(delta)
	_animate_proteins()


func _physics_process(delta: float) -> void:
	if not waking_style or _waking == null or not crawl_enabled or not is_visible_in_tree():
		return
	_crawl(delta)
	_feel_clock -= delta
	if _feel_clock <= 0.0:
		_feel_clock = 0.3
		_feel()


func _build_materials() -> void:
	_phenotype = PhenotypeScript.profile(PhenotypeScript.Kind.MOSS, int(colony.seed))
	_heart_material = _cell_material(1.0)
	_network_material = _cell_material(0.0)
	_cilia_material = ShaderMaterial.new()
	_cilia_material.shader = CILIA_SHADER
	_ether_material = _material(Color(0.46, 0.18, 0.68, 0.16), Color(0.20, 0.05, 0.36), 0.20, 0.16)
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
	var ribbon := CylinderMesh.new()
	ribbon.top_radius = 0.001
	ribbon.bottom_radius = 0.0045
	ribbon.height = 0.085
	ribbon.radial_segments = 3
	ribbon.rings = 1
	ribbon.material = _cilia_material
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
		basis = basis.rotated(Vector3.RIGHT, 0.18 + wave * 0.22)
		basis = basis.scaled(Vector3(0.72, 0.70 + 0.46 * _hash01(i * 43 + colony.seed), 0.72))
		var at: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * radius + Vector3.UP * 0.043
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
	var lobes := 48
	var phase_scale: float = [0.20, 0.28, 0.36, 0.45, 0.54, 0.64,
		0.58, 0.50, 0.40, 0.30, 0.0][clampi(colony.phase, 0, 10)]
	for i in lobes:
		var a0 := TAU * float(i) / float(lobes)
		var a1 := TAU * float(i + 1) / float(lobes)
		var branch0 := 0.68 + 0.24 * _hash01(i * 97 + colony.seed)
		var branch1 := 0.68 + 0.24 * _hash01((i + 1) * 97 + colony.seed)
		if i % 11 == 0: branch0 *= 1.18
		if (i + 1) % 11 == 0: branch1 *= 1.18
		var r0 := phase_scale * branch0
		var r1 := phase_scale * branch1
		var inner0 := Vector3(cos(a0) * minf(0.20, r0 * 0.55), 0.048 + 0.009 * sin(a0 * 3.0), sin(a0) * minf(0.20, r0 * 0.55))
		var inner1 := Vector3(cos(a1) * minf(0.20, r1 * 0.55), 0.048 + 0.009 * sin(a1 * 3.0), sin(a1) * minf(0.20, r1 * 0.55))
		var outer0 := Vector3(cos(a0) * r0, 0.012 + 0.040 * branch0, sin(a0) * r0)
		var outer1 := Vector3(cos(a1) * r1, 0.012 + 0.040 * branch1, sin(a1) * r1)
		_add_sheet_tri(mesh, Vector3(0, 0.075, 0), inner0, inner1)
		_add_sheet_tri(mesh, inner0, outer0, outer1)
		_add_sheet_tri(mesh, inner0, outer1, inner1)
	mesh.surface_end()
	_sheet.mesh = mesh


func _add_sheet_tri(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, b, c]:
		mesh.surface_set_normal(normal)
		mesh.surface_set_uv(Vector2(point.x, point.z))
		mesh.surface_add_vertex(point)


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


# ------------------------------------------------------------------ waking

# region, pigment, glow colour, glow, glassy, recipe, uv_tile. The recipe is a
# registered material (waking_colony_<recipe>, RUL-012) whose three maps
# art/tools/build_waking_colony_maps.py writes; uv_tile is the mesh's metres
# per UV unit over the recipe's meters_per_tile. Sphere-projected organelles
# take whole repeats around so the seam closes.
const ORGANELLE_LOOK := {
	"Nucleus": [1.0, Color(0.55, 0.18, 0.42), Color(0.9, 0.4, 0.8), 0.22, 0.0, "chromatin", Vector2(4.0, 2.0)],
	"Nucleolus": [2.0, Color(0.30, 0.05, 0.25), Color(1.0, 0.5, 0.9), 0.5, 0.0, "chromatin", Vector2(2.0, 1.0)],
	"Vacuole": [3.0, Color(0.55, 0.78, 0.85), Color(0.6, 0.9, 1.0), 0.08, 1.0, "vesicle", Vector2(2.0, 1.0)],
	"Mito": [4.0, Color(0.85, 0.45, 0.20), Color(1.0, 0.6, 0.3), 0.3, 0.0, "cristae", Vector2(2.0, 2.0)],
	"Granules": [5.0, Color(0.95, 0.85, 0.40), Color(1.0, 0.9, 0.5), 0.4, 0.0, "granule", Vector2(4.0, 4.0)],
	"Filaments": [6.0, Color(0.60, 0.30, 0.75), Color(0.8, 0.5, 1.0), 0.2, 0.0, "fibre", Vector2(12.0, 12.0)],
}
const WAKING_RECIPE_DIR := "res://assets/dream/waking_colony/"
const WAKING_CILIUM_RECIPE := "cuticle"
const WAKING_CILIUM_TILE := Vector2(1.0, 6.0)
## The cytoskeleton's fibres carry authored UVs: one turn around, and metres
## along over the recipe's tile, so the repeat is one.
const WAKING_TUBULE_RECIPE := "tubule"
const WAKING_TUBULE_TILE := Vector2(1.0, 1.0)
## One beat and one palette for the fibres, the limbs tied to them and the
## milky web: a pull shows the same colour, at the same moment, in all three.
const WAKING_PULL_RATE := 0.42
const WAKING_PULL_WAVES := 2.0
const WAKING_WORK_COLOR := Color(0.72, 0.36, 0.92)
const WAKING_STRIKE_COLOR := Color(1.0, 0.62, 0.38)
## The cilia step in this many companies around the cell, each as one.
const WAKING_COHORTS := 12.0
## The bank of vapour round the cell's foot (Lily, 2026-11-13): the
## encroachment's purple, in level sheets from the floor up.
const WAKING_VAPOR_COLOR := Color(0.50, 0.28, 0.70)
const WAKING_VAPOR_SHEETS := 11
const WAKING_VAPOR_TOP := 0.17          # metres
const WAKING_VAPOR_REACH := 0.80        # metres from the middle
const WAKING_LIMB_COLOR := Color(0.62, 0.42, 0.72)


## Binds one registered recipe's three maps to a colony material.
func _bind_waking_recipe(material: ShaderMaterial, recipe: String, tile: Vector2) -> void:
	for pair: Array in [["albedo_tex", "albedo"], ["rough_tex", "roughness"], ["normal_tex", "normal"]]:
		var path := "%s%s_%s.png" % [WAKING_RECIPE_DIR, recipe, pair[1]]
		var texture := load(path) as Texture2D
		if texture == null:
			push_error("waking colony recipe map missing: " + path)
			continue
		material.set_shader_parameter(pair[0], texture)
	material.set_shader_parameter("uv_tile", tile)
	material.set_meta("recipe", "waking_colony_" + recipe)


## The shared beat and palette; a shader ignores the ones it does not declare.
func _bind_waking_work(material: ShaderMaterial) -> void:
	material.set_shader_parameter("pull_rate", WAKING_PULL_RATE)
	material.set_shader_parameter("pull_waves", WAKING_PULL_WAVES)
	material.set_shader_parameter("work_color", WAKING_WORK_COLOR)
	material.set_shader_parameter("strike_color", WAKING_STRIKE_COLOR)
	material.set_shader_parameter("limb_color", WAKING_LIMB_COLOR)
	material.set_shader_parameter("cohorts", WAKING_COHORTS)
	material.set_shader_parameter("vapor_color", WAKING_VAPOR_COLOR)


func _build_waking() -> void:
	for node: Node3D in [_heart, _sheet, _network, _cilia, _cilia_carpet, _ether, _pulse, _proteins]:
		if node != null:
			node.visible = false
	var packed := load(WAKING_CELL) as PackedScene
	if packed == null:
		push_error("waking colony cell missing: " + WAKING_CELL)
		return
	_waking = packed.instantiate() as Node3D
	_waking.name = "WakingCell"
	add_child(_waking)
	var membrane_shader := preload("res://shaders/waking_colony_membrane.gdshader")
	var organelle_shader := preload("res://shaders/waking_colony_organelle.gdshader")
	var cilium_mesh: Mesh = null
	var root_mesh: Mesh = null
	for mi: MeshInstance3D in _waking.find_children("*", "MeshInstance3D", true, false):
		var key := str(mi.name)
		if key == "Cilium":
			cilium_mesh = mi.mesh
			mi.visible = false
			continue
		if key == "CiliumRoots":
			# Not drawn: each triangle says where one cilium starts and which way is out.
			root_mesh = mi.mesh
			mi.visible = false
			continue
		var material := ShaderMaterial.new()
		if key == "Membrane":
			material.shader = membrane_shader
			material.set_shader_parameter("tardi_normal", load("res://assets/dream/microscopy/tardigrade_membrane/normal.png"))
			material.set_shader_parameter("cytoplasm_web", load(WAKING_RECIPE_DIR + "cytoplasm_web.png"))
			_bind_waking_work(material)
		elif key == "Cytoskeleton":
			# The microtubule canopy is fixed to the cell: it works in place
			# and does not stream with the organelles.
			material.shader = preload("res://shaders/waking_colony_tubule.gdshader")
			_bind_waking_recipe(material, WAKING_TUBULE_RECIPE, WAKING_TUBULE_TILE)
			_bind_waking_work(material)
			_waking_skeleton = mi
		else:
			material.shader = organelle_shader
			var look: Array = ORGANELLE_LOOK.get(key.get_slice("_", 0), ORGANELLE_LOOK.Nucleus)
			material.set_shader_parameter("region", look[0])
			material.set_shader_parameter("base_color", look[1])
			material.set_shader_parameter("glow_color", look[2])
			material.set_shader_parameter("glow", look[3])
			material.set_shader_parameter("glassy", look[4])
			_bind_waking_recipe(material, str(look[5]), look[6])
			# Cyclosis: each organelle streams around the cell at its own pace,
			# on its own ellipse, so the interior keeps rearranging under the lens.
			var h := _hash01(key.hash() + int(colony.seed))
			_organelles.append({"node": mi, "rest": mi.position,
				"speed": (0.05 + 0.12 * h) * (1.0 if h > 0.3 else -1.0), "bob": 0.004 + 0.006 * h, "phase": h * TAU})
		mi.material_override = material
		_waking_materials.append(material)
	if cilium_mesh != null:
		_build_waking_cilia(cilium_mesh, _waking_cilium_roots(root_mesh))
	_build_waking_vapor()


## Where the drawn cell is now, in the world. The encroachment's field grows
## from here, so the purple follows the cell as it roams.
func waking_cell_position() -> Vector3:
	return _waking.global_position if _waking != null else global_position


## Level sheets round the cell's foot; the shader shapes them into a bank that
## hides where the membrane and the cilia meet the floor.
func _build_waking_vapor() -> void:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for sheet in WAKING_VAPOR_SHEETS:
		var rise := float(sheet) / float(WAKING_VAPOR_SHEETS - 1)
		var y := 0.004 + rise * (WAKING_VAPOR_TOP - 0.004)
		var first := points.size()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(Vector3(corner.x * WAKING_VAPOR_REACH, y, corner.y * WAKING_VAPOR_REACH))
			colors.append(Color(rise, 0.0, 0.0, 1.0))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/waking_colony_vapor.gdshader")
	material.set_shader_parameter("cloud_tex", load(WAKING_RECIPE_DIR + "cytoplasm_web.png"))
	material.set_shader_parameter("sheets", float(WAKING_VAPOR_SHEETS))
	_bind_waking_work(material)
	# After the membrane, which is drawn in the same pass and keeps depth: the
	# vapour in front of the dome must lie over it.
	material.render_priority = 1
	_waking_materials.append(material)
	var vapor := MeshInstance3D.new()
	vapor.name = "WakingVapor"
	vapor.mesh = mesh
	vapor.material_override = material
	vapor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_waking.add_child(vapor)


## The basal bodies the Blender build placed just inside the membrane: for each
## cilium its position, the way out through the membrane, and its place around
## the cell with two fixed random numbers. One triangle of CiliumRoots each.
func _waking_cilium_roots(mesh: Mesh) -> Array[Dictionary]:
	var roots: Array[Dictionary] = []
	if mesh == null or mesh.get_surface_count() == 0:
		return roots
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in points.size():
			indices.append(i)
	for t in range(0, indices.size() - 2, 3):
		var a := points[indices[t]]
		var b := points[indices[t + 1]]
		var c := points[indices[t + 2]]
		var centre := (a + b + c) / 3.0
		# Godot winds front faces clockwise; the outward side is the one that
		# faces away from the middle of the cell.
		var out := (b - a).cross(c - a).normalized()
		if out.dot(Vector3(centre.x, 0.0, centre.z)) < 0.0:
			out = -out
		var data := colors[indices[t]] if indices[t] < colors.size() else Color(float(t) / float(indices.size()), 0.5, 0.5)
		roots.append({"position": centre, "out": out, "around": data.r, "a": data.g, "b": data.b})
	roots.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.around) < float(q.around))
	return roots


func _build_waking_cilia(mesh: Mesh, roots: Array[Dictionary]) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/waking_colony_cilium.gdshader")
	_bind_waking_recipe(material, WAKING_CILIUM_RECIPE, WAKING_CILIUM_TILE)
	_bind_waking_work(material)
	material.set_shader_parameter("base_color", WAKING_LIMB_COLOR)
	_waking_materials.append(material)
	var cilia := MultiMeshInstance3D.new()
	cilia.name = "WakingCilia"
	cilia.material_override = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	# Each cilium starts at its basal body inside the cell and leaves through
	# the membrane; its curl turns down toward the floor, like a resting leg.
	multimesh.instance_count = roots.size()
	for i in roots.size():
		var root: Dictionary = roots[i]
		var out: Vector3 = root.out
		var length_axis := (out * 0.8 + Vector3.UP * 0.2).normalized()
		var curl := (Vector3.DOWN - length_axis * Vector3.DOWN.dot(length_axis)).normalized()
		# The cilium's own frame: length along +Y, the rest curl toward +Z.
		var basis := Basis(length_axis.cross(curl), length_axis, curl)
		basis = basis.rotated(length_axis, (float(root.b) - 0.5) * 0.5)
		var size := 0.9 + 0.5 * float(root.a)
		_cilia_rest_basis.append(basis)
		_cilia_rest_scale.append(size)
		_cilia_aim.append(Vector3.ZERO)
		multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * size), root.position))
		multimesh.set_instance_custom_data(i, Color(float(root.around), float(root.a), 0.0, 1.0))
	_cilia_roots = roots
	_cilia_touch.resize(roots.size())
	_cilia_want.resize(roots.size())
	_waking_cilia = cilia
	_crawl_rng.seed = int(colony.seed) * 7919 + 13 if colony != null else 13
	cilia.multimesh = multimesh
	cilia.custom_aabb = AABB(Vector3(-0.7, -0.05, -0.7), Vector3(1.4, 0.5, 1.4))
	_waking.add_child(cilia)


# ------------------------------------------------------------ crawl and touch

## Is there room for the cell here, on the same floor? `at` is in this node's
## own space. It must be inside the room it may roam, a flat cylinder the size
## of the cell must be free of every collider, and the floor must be under it
## at the height it is rooted on.
func _crawl_clear(at: Vector3) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	var space := world.direct_space_state
	var here := to_global(at)
	if crawl_bounds.has_area() and not crawl_bounds.grow(-WAKING_BODY_RADIUS).has_point(Vector2(here.x, here.z)):
		return false
	var body := CylinderShape3D.new()
	body.radius = WAKING_BODY_RADIUS
	body.height = 0.12
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.transform = Transform3D(Basis.IDENTITY, here + Vector3.UP * 0.10)
	query.collide_with_areas = false
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var down := PhysicsRayQueryParameters3D.create(here + Vector3.UP * 0.25, here + Vector3.DOWN * 0.15)
	var floor_hit := space.intersect_ray(down)
	return not floor_hit.is_empty() and absf(float(floor_hit.position.y) - here.y) < 0.04


## The whole way to a place is open, a body's width at a time.
func _crawl_way_clear(from: Vector3, to: Vector3) -> bool:
	var steps := maxi(1, int(ceil(from.distance_to(to) / 0.3)))
	for step in range(1, steps + 1):
		if not _crawl_clear(from.lerp(to, float(step) / float(steps))):
			return false
	return true


func _choose_crawl_target() -> void:
	var here := _waking.position
	for attempt in 10:
		var angle := _crawl_rng.randf() * TAU
		var far := _crawl_rng.randf_range(0.5, 1.8)
		var candidate := Vector3(here.x + cos(angle) * far, 0.0, here.z + sin(angle) * far)
		if candidate.length() > WAKING_CRAWL_LEASH:
			continue
		if _crawl_way_clear(here, candidate):
			_crawl_target = candidate
			return
	# Hemmed in: stay, and look again in a while.
	_crawl_target = here
	_crawl_rest = 2.5


func _crawl(delta: float) -> void:
	var going := 0.0
	if _crawl_rest > 0.0:
		_crawl_rest -= delta
	else:
		var here := _waking.position
		var ahead := Vector3(_crawl_target.x - here.x, 0.0, _crawl_target.z - here.z)
		if ahead.length() < 0.03:
			# Arrived: stand a while, then choose somewhere else.
			_crawl_rest = _crawl_rng.randf_range(1.0, 3.5) if _crawl_travelled > 0.0 else 0.0
			_choose_crawl_target()
		else:
			var way := ahead.normalized()
			_crawl_check -= delta
			var open := true
			if _crawl_check <= 0.0:
				_crawl_check = 0.2
				open = _crawl_clear(here + way * 0.08)
			if not open:
				# Something is in the way now (a chair moved, someone stands there).
				_crawl_rest = 1.0
				_choose_crawl_target()
			else:
				# It moves in surges, not at a glide.
				going = 0.55 + 0.45 * sin(_clock * 0.9)
				var step := way * WAKING_CRAWL_SPEED * going * delta
				_waking.position = here + step
				_crawl_travelled += step.length()
				# The cell's own frame is this node's: it does not turn.
				_crawl_heading = _crawl_heading.lerp(Vector2(way.x, way.z), minf(1.0, delta * 3.0))
	# The cilia take up and lay down the work together, never at a snap.
	_crawl_effort = move_toward(_crawl_effort, going, delta * (1.6 if going > _crawl_effort else 0.9))


## Feelers: low rays out from the rim at two heights, turning slowly so the
## cell sweeps the space between them. Each hit is something to reach for.
func _feel() -> void:
	_feel_hits.clear()
	_study_cooldown = maxf(0.0, _study_cooldown - 0.3)
	var world := get_world_3d()
	if world == null:
		return
	var space := world.direct_space_state
	var rx := 0.27
	var rz := 0.23
	var nearest := INF
	for k in WAKING_FEELERS:
		var angle := (float(k) / float(WAKING_FEELERS)) * TAU + _clock * 0.07
		var way := Vector3(cos(angle), 0.0, sin(angle))
		var rim := 1.0 / sqrt(pow(way.x / rx, 2.0) + pow(way.z / rz, 2.0))
		for height: float in [0.07, 0.17]:
			var from := _waking.to_global(way * rim * 0.6 + Vector3.UP * height)
			var to := _waking.to_global(way * (rim + WAKING_TOUCH_REACH) + Vector3.UP * height)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
			if hit.is_empty():
				continue
			var point: Vector3 = _waking.to_local(hit.position)
			_feel_hits.append({"angle": angle, "point": point})
			var far := Vector2(point.x, point.z).length() - rim
			if far < nearest:
				nearest = far
				_attend_point = point
			break
	# One mind: the whole cell attends to the nearest thing it has found, and
	# stops to study a new find before it moves on.
	_attend_want = 0.0 if _feel_hits.is_empty() else 1.0
	if not _feel_hits.is_empty() and _study_cooldown <= 0.0 and _crawl_rest <= 0.0 and _crawl_travelled > 0.0:
		_crawl_rest = 3.0
		_study_cooldown = 9.0
	# Which cilia answer: nearly all on that side whose reach covers the thing.
	var turn := int(floor(_clock / 4.0))
	for i in _cilia_roots.size():
		_cilia_want[i] = 0.0
		if _feel_hits.is_empty():
			continue
		var root_at: Vector3 = _cilia_roots[i].position
		var side := atan2(root_at.z, root_at.x)
		for hit: Dictionary in _feel_hits:
			if absf(angle_difference(side, float(hit.angle))) > TAU / float(WAKING_FEELERS) * 1.1:
				continue
			# Each cilium takes its own spot on the thing, a little off the ray.
			var spot: Vector3 = hit.point + Vector3(0.0, (_hash01(i * 37 + turn) - 0.4) * 0.07, 0.0) \
					+ Vector3(-sin(side), 0.0, cos(side)) * (_hash01(i * 53 + turn) - 0.5) * 0.05
			var far := root_at.distance_to(spot)
			if far < 0.05 or far > WAKING_LIMB_LENGTH * WAKING_LIMB_STRETCH:
				continue
			if _hash01(i * 71 + turn * 13) < 0.15:
				continue
			_cilia_want[i] = 1.0
			_cilia_aim[i] = spot
			break


## Where cilium `i` is now. At rest it stands on its root; while the cell
## attends to something, limbs on that side turn toward it; a limb that is
## feeling is turned onto its spot and lengthened so its straightened tip
## lands there.
func waking_cilium_pose(i: int) -> Transform3D:
	var root_at: Vector3 = _cilia_roots[i].position
	var basis := _cilia_rest_basis[i]
	var length := _cilia_rest_scale[i]
	var width := length
	if _attend > 0.0:
		var to_thing := _attend_point - root_at
		to_thing.y = 0.0
		var outward := Vector3(root_at.x, 0.0, root_at.z)
		if to_thing.length() > 0.01 and outward.length() > 0.01:
			# Only limbs that face the thing turn; the far side stands as it was.
			var facing := maxf(0.0, outward.normalized().dot(to_thing.normalized()))
			var axis := basis.y.cross(to_thing.normalized())
			if axis.length() > 0.01:
				basis = basis.rotated(axis.normalized(), 0.30 * _attend * facing)
	var now := _cilia_touch[i]
	if now > 0.0:
		var to_spot := _cilia_aim[i] - root_at
		var along := to_spot.normalized()
		var curl := Vector3.DOWN - along * Vector3.DOWN.dot(along)
		curl = curl.normalized() if curl.length() > 0.01 else basis.z
		var aim := Basis(along.cross(curl), along, curl).orthonormalized()
		var ease := smoothstep(0.0, 1.0, now)
		basis = basis.orthonormalized().slerp(aim, ease)
		length = lerpf(length, clampf(to_spot.length() / WAKING_LIMB_LENGTH, 0.8, WAKING_LIMB_STRETCH), ease)
		# A long reach is a longer limb, not a fatter one.
		width = minf(length, 1.3)
	return Transform3D(basis * Basis.from_scale(Vector3(width, length, width)), root_at)


## Ease each cilium between standing, attending and feeling.
func _animate_touch(delta: float) -> void:
	if _waking_cilia == null:
		return
	_attend = move_toward(_attend, _attend_want, delta * 0.8)
	var attending := not is_equal_approx(_attend, _attend_shown)
	_attend_shown = _attend
	var multimesh := _waking_cilia.multimesh
	for i in _cilia_roots.size():
		var now := _cilia_touch[i]
		var want := _cilia_want[i]
		if now == want and now == 0.0 and not attending:
			continue
		_cilia_touch[i] = move_toward(now, want, delta * (0.7 if want > now else 1.1))
		var root: Dictionary = _cilia_roots[i]
		multimesh.set_instance_transform(i, waking_cilium_pose(i))
		multimesh.set_instance_custom_data(i, Color(float(root.around), float(root.a), _cilia_touch[i], 1.0))


## How many cilia are reaching for something now (for tests and the census).
func waking_touching() -> int:
	var count := 0
	for value in _cilia_touch:
		if value > 0.5:
			count += 1
	return count


func _animate_waking() -> void:
	for material in _waking_materials:
		material.set_shader_parameter("cell_time", _clock)
		material.set_shader_parameter("effort", _crawl_effort)
		material.set_shader_parameter("heading", _crawl_heading)
	var rx := 0.27
	var rz := 0.23
	for row: Dictionary in _organelles:
		var rest: Vector3 = row.rest
		# Rotate on the cell's own ellipse: normalise, turn, scale back, so a
		# streaming organelle never leaves the membrane.
		var nx := rest.x / rx
		var nz := rest.z / rz
		var ang: float = _clock * float(row.speed) + float(row.phase) * 0.0
		var c := cos(ang)
		var s := sin(ang)
		var node: Node3D = row.node
		node.position = Vector3((nx * c - nz * s) * rx, rest.y + float(row.bob) * sin(_clock * 0.7 + float(row.phase)),
				(nx * s + nz * c) * rz)
		node.rotation.y = ang
