extends Node3D
## DreamTentacleController — the first on-screen manifestation of the
## Dream's intelligence (design/DREAM_TENTACLE_DIRECTION.md). One limb of a
## hyperdimensional structure intersecting the room: the rig lays its
## spine, the behaviour decides, the eye looks, the halos hold their own
## plane, the suckers engage, the membrane gives it a way through the wall,
## the transformer invites what it touches into the Dream, and the lights
## move with it. Owned and tended by ApartmentEncroachment.
##
## Sound hooks (§22): `dream_event(name, position)` for membrane_strain,
## emergence, eye_opening, vein_pulse, gold_phase_shift, halo_phase,
## sucker_attach, sucker_release, electrochemical_exchange,
## secretion_transfer, surface_caress, dream_conversion,
## player_attention, flinch, impossible_space, withdrawal.

signal dream_event(event_name: String, at: Vector3)

const SHADER := preload("res://shaders/dream_tentacle.gdshader")
const RigScript := preload("res://scripts/dream/entity/dream_tentacle_rig.gd")
const BehaviorScript := preload("res://scripts/dream/entity/dream_tentacle_behavior.gd")
const OcularScript := preload("res://scripts/dream/entity/dream_ocular_assembly.gd")
const HaloScript := preload("res://scripts/dream/entity/dream_halo_controller.gd")
const SuckerScript := preload("res://scripts/dream/entity/dream_sucker_controller.gd")
const MembraneScript := preload("res://scripts/dream/entity/dream_membrane.gd")
const GoldSkeletonScript := preload("res://scripts/dream/entity/dream_gold_skeleton.gd")
const SensorScript := preload("res://scripts/dream/entity/dream_contact_sensor.gd")
const TransformerScript := preload("res://scripts/dream/entity/dream_surface_transformer.gd")
const BehaviorProfileScript := preload("res://scripts/dream/entity/dream_behavior_profile.gd")
const MaterialProfileScript := preload("res://scripts/dream/entity/dream_material_profile.gd")
const ContactProfileScript := preload("res://scripts/dream/entity/dream_contact_profile.gd")
const CellularStateScript := preload("res://scripts/dream/dream_cellular_state.gd")
const PhenotypeScript := preload("res://scripts/dream/dream_cellular_phenotype.gd")
const RINGS := 96
const SEGS := 28
const COLLARS := 11
## The spline centre begins below the measured support plane. The membrane
## stays on that plane, so the broad root passes through a flush socket
## instead of reading as a prop balanced on the floor or wall.
const ROOT_EMBED_M := 0.092
const MOSS_CONTACT_RADIUS_M := 0.18

var field = null
var source_index := 0
var anchor := Vector3.ZERO
var anchor_normal := Vector3.UP
var embedded_root := Vector3.ZERO
var support_tangent := Vector3.FORWARD
var support_kind := "surface"
var player: Node3D = null
var behavior_profile: DreamBehaviorProfile
var material_profile: DreamMaterialProfile
var contact_profile: DreamContactProfile

var rig: DreamTentacleRig
var behavior: DreamTentacleBehavior
var ocular: DreamOcularAssembly
var halo: DreamHaloController
var suckers: DreamSuckerController
var membrane: DreamMembrane
var skeleton: DreamGoldSkeleton
var sensor: DreamContactSensor
var transformer: DreamSurfaceTransformer

var clock := 0.0
## The organism's several clocks (DIRECTION_3 §D): none of these share a
## period, so nothing in the body beats with anything else.
const PULSE_S := 1.47
const BREATH_S := 5.3
var pulse_phase := 0.0
var breath_phase := 0.0
var startle := 0.0
var grow := 0.0
var grip := 0.0
var curl := 0.0
var seed_phase := 0.0
var target_name := ""
var deposits := 0
## E2 ecological binding. The controller still owns pose/anatomy; the colony
## decides whether this limb is supported, returning, reporting or senescent.
var ecology_colony = null
var ecology_record: Dictionary = {}
var ecology_purpose := -1
var ecology_purpose_name := "unbound"
var ecology_status := "unbound"
var ecology_ether_min := 1.0
var ecology_reports := 0
var ecology_tended_moss := false
var ecology_moss_distance_min := INF
var ecology_supported_goal := Vector3.INF
var ecology_moss_dwell_s := 0.0
var ecology_route_extension := 0.0
var _ecology_reported := false
var _ecology_failure_clock := 0.0

signal ecology_report_arrived(at: Vector3, value: float)
enum ExplorationState { RESTING_AT_MOSS, ORIENTING, LOCAL_SWEEP,
	TENTATIVE_REACH, SURFACE_CONTACT, PALPATING, EDGE_TRACING,
	REORIENTING, COMMITTED_REACH, INFORMATION_RETURN, BREATHING_REPORT,
	DEFENSIVE_RECALL, WITHERING }
const EXPLORATION_NAMES := ["resting_at_moss", "orienting", "local_sweep",
	"tentative_reach", "surface_contact", "palpating", "edge_tracing",
	"reorienting", "committed_reach", "information_return", "breathing_report",
	"defensive_recall", "withering"]
var exploration_state := ExplorationState.ORIENTING
var exploration_probe_directions: Array[Vector3] = []
var exploration_contact_s := 0.0
var exploration_reversals := 0
var exploration_target_reserved := false
var exploration_novelty := 1.0
## DT-5: how hard the nth-dimensional body is leaning into the local field.
## This is not contact conversion and leaves no stain or agents.
var emergence_pressure := 0.0
var emergence_pressure_peak := 0.0
var field_pressure_writes := 0
var _field_pressure_clock := 0.0
## A brief contact-organ flash makes the electrochemical handoff legible. It
## is a presentation response to the behavior event, not another field owner.
var exchange_flash := 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _light_eye: OmniLight3D
var _light_gold: OmniLight3D
var _light_contact: OmniLight3D
var _spine_prev := PackedVector3Array()
var _prev_clock := 0.0
var _slice_v := -1.0
var _slice_left := 0.0
var _slice_cooldown := 9.0
var _player_prev := Vector3.ZERO
var _player_speed := 0.0
var _candidates: Array = []
var _rng := RandomNumberGenerator.new()
## Debug toggles (§25).
## `halos` is OFF by default (DIRECTION_2 §29): with a real orbital
## skeleton, three lids and eighteen cilia around the eye, a ring of beads
## is one effect too many and reads as jewellery. TENTACLE_HALOS=1 restores
## it for evaluation.
var toggles := {"breathing": true, "peristalsis": true, "vein_pulse": true, "gold_flow": true,
		"gold_emission": true, "eye_tracking": true, "halos": false, "suckers": true,
		"contact_deformation": true, "surface_conversion": true, "rim": true, "phase_slice": true,
		"gold_structures": true, "crystal": true, "lids": true, "cilia": true, "socket": true,
		"membrane": true, "lights": true, "gray": false, "show_bones": false, "interior": true}
var _bones: MeshInstance3D
var _mask_view := 0
var _probe: ReflectionProbe
var _probe_recaptured := 0.0
var _probe_settle := 0.0
var _face_chosen := false


func setup(living_field, src: int, at: Vector3, normal: Vector3, who: Node3D,
		candidates: Array, seed_v: int, emergence_support_kind := "") -> void:
	field = living_field
	source_index = src
	anchor = at
	anchor_normal = normal.normalized()
	embedded_root = anchor - anchor_normal * ROOT_EMBED_M
	support_tangent = Vector3.UP - anchor_normal * Vector3.UP.dot(anchor_normal)
	if support_tangent.length_squared() < 0.01:
		support_tangent = Vector3.FORWARD - anchor_normal * Vector3.FORWARD.dot(anchor_normal)
	if support_tangent.length_squared() < 0.01:
		support_tangent = Vector3.RIGHT
	support_tangent = support_tangent.normalized()
	support_kind = String(emergence_support_kind)
	if support_kind.is_empty():
		support_kind = "floor" if anchor_normal.y > 0.70 else (
				"ceiling" if anchor_normal.y < -0.70 else "wall")
	player = who
	_candidates = candidates
	_rng.seed = seed_v
	seed_phase = _rng.randf_range(0.0, 6.28)
	name = "DreamTentacle"
	behavior_profile = BehaviorProfileScript.new()
	material_profile = MaterialProfileScript.new()
	contact_profile = ContactProfileScript.new()
	var hold := OS.get_environment("TENTACLE_HOLD") == "1"
	# The silhouette and motion tests (DIRECTION 28): gray, no emission.
	if OS.get_environment("TENTACLE_GRAY") == "1":
		toggles.gray = true
	if OS.get_environment("TENTACLE_BONES") == "1":
		toggles.show_bones = true
	if OS.get_environment("TENTACLE_HALOS") == "1":
		toggles.halos = true
	var mv := OS.get_environment("TENTACLE_MASK")
	if not mv.is_empty():
		_mask_view = mv.to_int()
	rig = RigScript.new()
	rig.configure(embedded_root, anchor_normal, behavior_profile.length_m, seed_phase)
	rig.tremor_hz = behavior_profile.tremor_hz
	rig.tremor_m = behavior_profile.tremor_m
	behavior = BehaviorScript.new()
	behavior.anchor = anchor
	behavior.anchor_normal = anchor_normal
	behavior.support_tangent = support_tangent
	behavior.configure(behavior_profile, hold)
	sensor = SensorScript.new()
	var world: World3D = get_viewport().find_world_3d() if get_viewport() != null else null
	if world != null:
		sensor.configure(world.direct_space_state)
	sensor.choose(anchor, anchor_normal, behavior_profile.reach_m, _candidates)
	target_name = sensor.target_name
	transformer = TransformerScript.new()
	transformer.configure(field, source_index, contact_profile)
	_build_body()
	# DIRECTION_2 §B / DIRECTION_3 §E: the collars are gone. What replaces
	# them is a grown mineral skeleton with roots in the flesh.
	skeleton = GoldSkeletonScript.new()
	skeleton.build(self, seed_v)
	ocular = OcularScript.new()
	ocular.build(self, seed_v)
	halo = HaloScript.new()
	halo.build(self, seed_v + 11)
	suckers = SuckerScript.new()
	suckers.build(self)
	suckers.multimesh.custom_aabb = AABB(anchor - Vector3(2.5, 2.5, 2.5), Vector3(5.0, 5.0, 5.0))
	halo.multimesh.custom_aabb = AABB(anchor - Vector3(2.5, 2.5, 2.5), Vector3(5.0, 5.0, 5.0))
	membrane = MembraneScript.new()
	membrane.build(self, anchor, anchor_normal, seed_phase)
	_build_lights()
	_build_probe()
	material_profile.apply(_material)
	_spine_prev = rig.pos.duplicate()
	if player != null:
		_player_prev = player.global_position
	_apply_toggles()


func bind_ecology(owner_colony, record: Dictionary, purpose: int) -> void:
	ecology_colony = owner_colony
	ecology_record = record
	ecology_purpose = purpose
	ecology_purpose_name = owner_colony.CLASS_NAMES[purpose]
	ecology_status = "exploring"
	var organism_id := int(record.get("id", -1))
	if organism_id >= 0 and not target_name.is_empty():
		exploration_target_reserved = owner_colony.reserve_target(target_name,
				purpose, organism_id)
	var prior: Dictionary = owner_colony.known_targets.get(target_name, {})
	if not prior.is_empty():
		exploration_novelty = clampf(float(prior.get("value", 0.0)) /
				float(1 + int(prior.get("repeats", 0))), 0.05, 1.0)
	# Honest distinctions using the established anatomy: no duplicate rigs.
	match purpose:
		owner_colony.OrganismClass.VIBRATION_LISTENER:
			behavior_profile.caress_s *= 1.25
			behavior_profile.rest_s *= 0.75
		owner_colony.OrganismClass.OCULAR_EXAMINER:
			behavior_profile.hover_s *= 1.45
		owner_colony.OrganismClass.SUCKER_SAMPLER:
			behavior_profile.caress_s *= 1.35
		owner_colony.OrganismClass.MANIPULATOR:
			behavior_profile.reach_m *= 0.88
		owner_colony.OrganismClass.RELAY_TENDRIL:
			behavior_profile.rest_s *= 1.8
			behavior_profile.reach_m *= 1.08
	_tick(0.0)


func _build_body() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for r in RINGS:
		var v := float(r) / float(RINGS - 1)
		for s in SEGS + 1:
			var u := float(s) / float(SEGS)
			var ang := u * TAU
			verts.append(Vector3(cos(ang), sin(ang), v))
			normals.append(Vector3(cos(ang), sin(ang), 0.0))
			uvs.append(Vector2(u, v))
	for r in RINGS - 1:
		for s in SEGS:
			var a := r * (SEGS + 1) + s
			var b := a + 1
			var c := a + SEGS + 1
			var d := c + 1
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("length_m", behavior_profile.length_m)
	_material.set_shader_parameter("seed", seed_phase)
	_material.set_shader_parameter("base_radius", DreamTentacleRig.BASE_RADIUS)
	_material.set_shader_parameter("tip_radius", DreamTentacleRig.TIP_RADIUS)
	_material.set_shader_parameter("prof", rig.prof)
	# The mineral roots, so the flesh scars and compresses where metal comes
	# through (DIRECTION_2 §B2). Packed as (v, u, breadth) per plate.
	var roots := GoldSkeletonScript.roots()
	var root_v := PackedFloat32Array()
	var root_u := PackedFloat32Array()
	var root_w := PackedFloat32Array()
	for r in roots:
		root_v.append(r.x)
		root_u.append(r.y)
		root_w.append(r.z)
	_material.set_shader_parameter("root_v", root_v)
	_material.set_shader_parameter("root_u", root_u)
	_material.set_shader_parameter("root_w", root_w)
	_material.set_shader_parameter("root_n", roots.size())
	# The orbit's footprint in the flesh is larger than the globe: the socket
	# has to close over it (DIRECTION_3 §H).
	_material.set_shader_parameter("eye_u", 0.18)
	_material.set_shader_parameter("eye_v", DreamOcularAssembly.EYE_V)
	_material.set_shader_parameter("eye_radius_m", DreamOcularAssembly.GLOBE_R * 1.55)
	_mesh = MeshInstance3D.new()
	_mesh.name = "Flesh"
	_mesh.mesh = mesh
	_mesh.material_override = _material
	_mesh.custom_aabb = AABB(anchor - Vector3(2.5, 2.5, 2.5), Vector3(5.0, 5.0, 5.0))
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)


func _build_lights() -> void:
	_light_eye = OmniLight3D.new()
	_light_eye.name = "EyeLight"
	_light_eye.light_color = Color(1.0, 0.84, 0.58)
	_light_eye.omni_range = 1.6
	_light_eye.shadow_enabled = false
	_light_eye.light_energy = 0.0
	add_child(_light_eye)
	_light_gold = OmniLight3D.new()
	_light_gold.name = "GoldLight"
	_light_gold.light_color = Color(1.0, 0.62, 0.22)
	_light_gold.omni_range = 1.4
	_light_gold.shadow_enabled = true
	_light_gold.light_energy = 0.0
	add_child(_light_gold)
	_light_contact = OmniLight3D.new()
	_light_contact.name = "ContactLight"
	_light_contact.light_color = Color(0.95, 0.55, 0.65)
	_light_contact.omni_range = 0.7
	_light_contact.shadow_enabled = false
	_light_contact.light_energy = 0.0
	add_child(_light_contact)


## Forward+ (DIRECTION_3 §K): polished metal in a dark room with nothing to
## reflect reads as flat grey. A small probe on the creature gives the gold
## and the wet film the room to reflect — the single feature that turns the
## skeleton from painted-looking into metal.
func _build_probe() -> void:
	_probe = ReflectionProbe.new()
	_probe.name = "DreamProbe"
	_probe.size = Vector3(4.0, 3.0, 4.0)
	_probe.origin_offset = Vector3.ZERO
	_probe.intensity = 1.0
	_probe.max_distance = 8.0
	# ONCE, not ALWAYS: a live probe re-renders six faces of the whole
	# building every frame and hung the device outright. The capture is
	# re-armed a moment after the creature is out, when the room is lit.
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_probe.interior = true
	_probe.enable_shadows = false
	_probe.cull_mask = 0xFFFFF
	_probe.position = Vector3.ZERO
	add_child(_probe)
	# A Node3D has no global transform until it belongs to the SceneTree. This
	# probe used to ask for one immediately before add_child(), producing an
	# engine error every time a waking tentacle emerged. Seat it only after the
	# parent gives it a world transform.
	_probe.global_position = anchor + anchor_normal * 0.7


## Review hooks (HERO_PASS §15–§16): the canonical assets have to be able
## to make each system perform on cue, without faking any of it — these
## call the real machinery.
func force_blink() -> void:
	ocular.force_blink()


func force_phase_slice(seconds := 0.45) -> void:
	_slice_v = _rng.randf_range(0.30, 0.68)
	_slice_left = seconds
	_slice_cooldown = 9.0
	_emit("gold_phase_shift", rig.point_at(_slice_v))


## Put the vascular bolus at a chosen point along the limb, so a still can
## show it where the frame wants it.
func align_pulse_to(v: float) -> void:
	clock = PULSE_S * fmod(clampf(v, 0.0, 1.0), 1.0)
	pulse_phase = fmod(clock / PULSE_S, 1.0)


func withdraw() -> void:
	behavior.withdraw()


func tip() -> Vector3:
	return rig.tip()


func state_name() -> String:
	return behavior.name_of(behavior.state)


func _process(delta: float) -> void:
	_tick(delta)


func _tick(delta: float) -> void:
	clock += delta
	pulse_phase = fmod(clock / PULSE_S, 1.0)
	breath_phase = fmod(clock / BREATH_S, 1.0)
	startle = maxf(0.0, startle - delta * 0.7)
	exchange_flash = maxf(0.0, exchange_flash - delta * 1.35)
	if behavior.state == DreamTentacleBehavior.S.DONE:
		_finish_ecology_return()
		queue_free()
		return
	# The player: position and speed for the zones.
	var has_player := player != null and is_instance_valid(player)
	if has_player:
		var pp: Vector3 = player.global_position
		if delta > 0.0:
			_player_speed = lerpf(_player_speed, pp.distance_to(_player_prev) / delta, 0.3)
		_player_prev = pp
		behavior.player_pos = pp
		behavior.player_speed = _player_speed
	behavior.has_player = has_player
	# The contact on the object, by what the behaviour is doing.
	var s := behavior.state
	var mode := "hover"
	if behavior.state == DreamTentacleBehavior.S.FLINCH and startle < 0.5:
		startle = 1.0
	if s == DreamTentacleBehavior.S.CARESSING:
		mode = "caress"
	elif s == DreamTentacleBehavior.S.TASTING:
		mode = "trace"
	sensor.update(behavior.total_clock, mode, seed_phase)
	behavior.contact = sensor.contact
	behavior.contact_normal = sensor.contact_normal
	behavior.contact_tangent = sensor.tangent_a
	behavior.tip = rig.tip()
	behavior.update(delta)
	_update_ecology(delta)
	_pressurize_emergence(delta)
	# The rig carries it out.
	grow = behavior.grow
	rig.grow = grow
	var supported_goal: Vector3 = behavior.tip_goal
	if ecology_colony != null:
		supported_goal = _ecology_route_goal(supported_goal, delta)
	rig.tip_goal = supported_goal
	rig.speed = behavior.speed
	rig.contact_normal = sensor.contact_normal
	rig.contact_tangent = sensor.tangent_a
	rig.lay = grip
	rig.sampling = behavior.sampling
	curl = lerpf(curl, behavior.curl_target, clampf(delta * 1.4, 0.0, 1.0))
	rig.curl = curl
	grip = lerpf(grip, behavior.grip_target, clampf(delta * 2.0, 0.0, 1.0))
	rig.step(delta)
	# The previous pose for the phase slice, kept a few frames behind.
	if clock - _prev_clock > 0.12:
		_spine_prev = rig.pos.duplicate()
		_prev_clock = clock
	_schedule_phase_slice(delta)
	# The probe re-captures periodically rather than every frame: the metal
	# tracks the room and the creature's own lights without re-rendering six
	# faces of the building at 60 Hz for a creature that moves this slowly.
	if _probe != null and grow > 0.5:
		_probe_recaptured -= delta
		if _probe_recaptured <= 0.0:
			_probe_recaptured = 2.0
			_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
			_probe_settle = 0.2
	if _probe_settle > 0.0:
		_probe_settle -= delta
		if _probe_settle <= 0.0 and _probe != null:
			_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	# The eye, the halos, the suckers, the membrane, the transformer.
	# The ocular station turns to face the room once the rig has settled
	# (HERO_PASS §4): an organ the camera cannot see has no authority.
	if not _face_chosen and grow > 0.55:
		_face_chosen = true
		var room_dir := anchor_normal
		if sensor.has_target:
			room_dir = (sensor.contact - ocular.position).normalized().lerp(anchor_normal, 0.35).normalized()
		ocular.choose_face(rig, room_dir)
		_material.set_shader_parameter("eye_u", ocular.eye_u)
	# Present the eye: roll the body until the socket's normal points at
	# whoever is watching. Slow — this is a creature turning, not a turret.
	if _face_chosen and toggles.eye_tracking:
		var watcher: Vector3 = behavior.player_pos if has_player else _viewer_pos()
		var want: Vector3 = (watcher - ocular.position).normalized()
		var f := rig.frame_at(DreamOcularAssembly.EYE_V)
		var tng: Vector3 = f.tangent
		var sd: Vector3 = f.side
		var bn: Vector3 = f.binormal
		# The angle the socket currently sits at, and where it should be.
		var flat: Vector3 = want - tng * want.dot(tng)
		if flat.length() > 0.15:
			flat = flat.normalized()
			var want_a := atan2(flat.dot(bn), flat.dot(sd))
			# The socket's CURRENT angle must include the roll already
			# applied. Leaving it out meant the correction never converged:
			# every frame asked for the same turn again and the creature
			# span continuously.
			var have_a := ocular.eye_u * TAU + float(f.twist) 					+ rig.station_roll * rig.station_ease(DreamOcularAssembly.EYE_V)
			var delta_a := wrapf(want_a - have_a, -PI, PI)
			# A dead zone, so it settles instead of hunting, and a slow rate.
			if absf(delta_a) > 0.10:
				rig.station_roll += delta_a * clampf(delta * 0.5, 0.0, 0.06)
	ocular.set_mode(behavior.eye_mode if toggles.eye_tracking else "watch_object")
	ocular.update(rig, sensor.contact, behavior.player_pos, has_player, behavior.interest,
			grow, pulse_phase, delta)
	var cam_pos := anchor + anchor_normal * 2.0
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		cam_pos = cam.global_position
	ocular.viewer_pos = cam_pos
	halo.update(ocular.position, ocular.gaze, ocular.openness, cam_pos, behavior.interest, delta)
	var holding := grip if toggles.suckers else 0.0
	suckers.update(rig, sensor.contact, sensor.contact_normal, holding, grow, delta)
	membrane.update(behavior.membrane_tension if toggles.membrane else 0.0,
			behavior.membrane_release, behavior.membrane_probe,
			behavior.membrane_probe_depth,
			DreamTentacleRig.radius_at(0.0) * 1.05, delta)
	if toggles.surface_conversion and suckers.engaged_count > 0:
		if transformer.touch(sensor.contact, sensor.contact_normal, grip, delta):
			deposits = transformer.deposits
			_emit("dream_conversion", sensor.contact)
	# A glimpse of the interior (§10) once, while tasting, with the eye open.
	if s == DreamTentacleBehavior.S.TASTING and behavior.state_clock > 0.8 \
			and ocular.interior < 0.01 and ocular.openness > 0.8 and toggles.interior \
			and behavior.caress_passes == 1:
		ocular.glimpse_interior(2.4)
		halo.phase(2.0)
	_push_uniforms()
	skeleton.update(rig, grow, pulse_phase, breath_phase, behavior.interest, startle, delta)
	_place_lights()


func _update_ecology(delta: float) -> void:
	if ecology_colony == null or ecology_record.is_empty() or _ecology_reported:
		return
	var information_gain := grip * delta * 0.055
	ecology_status = ecology_colony.update_excursion(ecology_record, rig.tip(),
			delta, information_gain)
	ecology_ether_min = minf(ecology_ether_min, float(ecology_record.ether))
	if ecology_status == "returning" and behavior.state not in [
			DreamTentacleBehavior.S.WITHDRAW, DreamTentacleBehavior.S.DONE]:
		behavior.withdraw()
	elif ecology_status == "senescent":
		_ecology_failure_clock += delta
		behavior.hold = true
		behavior.tip_goal = rig.tip()
		grow = maxf(0.05, grow - delta * 0.18)
		_material.set_shader_parameter("emission_strength", maxf(0.0,
				1.0 - _ecology_failure_clock * 0.35))


func _finish_ecology_return() -> void:
	if ecology_colony == null or ecology_record.is_empty() or _ecology_reported:
		return
	_ecology_reported = true
	if bool(ecology_record.senescent):
		return
	var observation := {"state_signature": target_name,
			"material_complexity": clampf(float(contact_profile.deposit), 0.0, 1.0),
			"modalities": [ecology_purpose_name]}
	var value: float = ecology_colony.report(ecology_record, target_name, observation)
	ecology_colony.release_target(target_name, ecology_purpose,
			int(ecology_record.get("id", -1)))
	ecology_reports += 1
	ecology_report_arrived.emit(anchor, value)
	_relay_events()
	if toggles.show_bones:
		_draw_bones()


func _pressurize_emergence(delta: float) -> void:
	# Proof harnesses may mute only this downstream write while retaining the
	# production field, membrane, limb, room and lighting. Default play is on.
	if OS.get_environment("TENTACLE_FIELD_PRESSURE") == "0":
		emergence_pressure = move_toward(emergence_pressure, 0.0, delta * 1.15)
		return
	var want := 0.0
	match behavior.state:
		DreamTentacleBehavior.S.MEMBRANE_BULGE:
			want = smoothstep(0.0, maxf(0.1, behavior_profile.membrane_bulge_s),
					behavior.state_clock)
		DreamTentacleBehavior.S.EMERGING:
			var e := clampf(behavior.state_clock / maxf(0.1, behavior_profile.emerge_s),
					0.0, 1.0)
			want = 1.0 - 0.22 * smoothstep(0.0, 1.0, e)
		DreamTentacleBehavior.S.ORIENTING:
			want = 0.62 * (1.0 - smoothstep(0.0,
					maxf(0.1, behavior_profile.orient_s), behavior.state_clock))
	# It leans in quickly but relaxes more slowly: volume arrives with the body
	# and ebbs after it, rather than switching at a state boundary.
	var rate := 2.8 if want > emergence_pressure else 1.15
	emergence_pressure = move_toward(emergence_pressure, want, delta * rate)
	emergence_pressure_peak = maxf(emergence_pressure_peak, emergence_pressure)
	_field_pressure_clock += delta
	if emergence_pressure <= 0.02 or _field_pressure_clock < 0.18:
		return
	_field_pressure_clock = 0.0
	if field != null and field.has_method("pressurize"):
		var radius := 0.52 + emergence_pressure * 0.26
		var amount := 0.30 + emergence_pressure * 0.62
		field.pressurize(anchor + anchor_normal * 0.08, source_index, amount, radius)
		field_pressure_writes += 1


## Phase slices (§9B): now and then a narrow band of the body belongs to
## the previous pose for a third of a second — only while it moves.
func _schedule_phase_slice(delta: float) -> void:
	if not toggles.phase_slice:
		_slice_v = -1.0
		return
	if _slice_left > 0.0:
		_slice_left -= delta
		if _slice_left <= 0.0:
			_slice_v = -1.0
		return
	_slice_cooldown -= delta
	if _slice_cooldown <= 0.0 and grow > 0.9:
		_slice_cooldown = _rng.randf_range(7.0, 16.0)
		_slice_v = _rng.randf_range(0.25, 0.7)
		_slice_left = 0.35
		_emit("gold_phase_shift", rig.point_at(_slice_v))


## Wherever the scene is being watched from: the active camera if there is
## one, otherwise a point out in the room.
func _viewer_pos() -> Vector3:
	var vp := get_viewport()
	if vp != null:
		var c := vp.get_camera_3d()
		if c != null:
			return c.global_position
	return anchor + anchor_normal * 2.0


func _push_uniforms() -> void:
	_material.set_shader_parameter("spine", rig.pos)
	_material.set_shader_parameter("side", rig.side)
	_material.set_shader_parameter("spine_prev", _spine_prev)
	_material.set_shader_parameter("grow", grow)
	_material.set_shader_parameter("eye_open", ocular.openness)
	_material.set_shader_parameter("contact_v", 0.95)
	_material.set_shader_parameter("contact_amount", grip if toggles.contact_deformation else 0.0)
	_material.set_shader_parameter("phase_slice_v", _slice_v)
	_material.set_shader_parameter("ventral_roll", rig.roll)
	_material.set_shader_parameter("station_roll", rig.station_roll)
	_material.set_shader_parameter("mask_view", _mask_view)
	MaterialProfileScript.push_state(_material, behavior.interest, pulse_phase,
			breath_phase, startle, 1.0 if _slice_left > 0.0 else 0.0)
	var returning := exploration_state == ExplorationState.INFORMATION_RETURN \
			or exploration_state == ExplorationState.BREATHING_REPORT
	var packet = CellularStateScript.new({
		"ether": 0.0 if ecology_colony == null else ecology_colony.ether_reserve,
		"information": clampf(float(ecology_record.get("information", 0.0)), 0.0, 1.0),
		"novelty": exploration_novelty,
		"contact": maxf(grip, exchange_flash),
		"reporting": 1.0 if returning else 0.0,
		"breathing": 1.0 if exploration_state == ExplorationState.BREATHING_REPORT else breath_phase,
		"disturbance": startle,
		"recall": 1.0 if exploration_state == ExplorationState.DEFENSIVE_RECALL else 0.0,
		"senescence": 1.0 if exploration_state == ExplorationState.WITHERING else 0.0,
	})
	var kind := PhenotypeScript.Kind.TACTILE
	var modality := 0
	match ecology_purpose_name:
		"sucker_sampler": kind = PhenotypeScript.Kind.CHEMICAL; modality = 1
		"manipulator": kind = PhenotypeScript.Kind.THERMAL; modality = 2
		"vibration_listener": kind = PhenotypeScript.Kind.VIBRATIONAL; modality = 3
		"ocular_examiner": kind = PhenotypeScript.Kind.OPTICAL; modality = 4
		"relay_tendril": kind = PhenotypeScript.Kind.ELECTRICAL; modality = 5
	var phenotype := PhenotypeScript.profile(kind, int(seed_phase * 100000.0))
	_material.set_shader_parameter("cellular_state_a", packet.to_vector_a())
	_material.set_shader_parameter("cellular_state_b", packet.to_vector_b())
	_material.set_shader_parameter("cellular_state_c", packet.to_vector_c())
	_material.set_shader_parameter("cellular_phenotype", Vector4(
			phenotype.organization, phenotype.windows, phenotype.proteins, phenotype.refractive))
	_material.set_shader_parameter("cellular_modality", modality)
	_material.set_shader_parameter("cellular_time", clock)


## The light it throws (§19): from the eye, from the gold mid-length, and
## from the suckers' rims at contact; its fluctuation is slices of a
## luminous structure crossing, not a flame — several frequencies and a
## spatial term, gated against each other.
func _light_slices() -> float:
	var a := 0.5 + 0.5 * sin(clock * 0.9 + seed_phase)
	var b := 0.5 + 0.5 * sin(clock * 2.3 + 1.7)
	var c := 0.5 + 0.5 * sin(clock * 5.1 + rig.tip().y * 3.0)
	var g1 := smoothstep(0.35, 0.65, a)
	var g2 := smoothstep(0.3, 0.7, b)
	return 0.62 + 0.38 * lerpf(g1, 1.0 - g1, g2) * (0.75 + 0.25 * c)


func _place_lights() -> void:
	var on: bool = toggles.lights and not toggles.gray
	var slices := _light_slices()
	_light_eye.global_position = ocular.position + ocular.normal * 0.06
	_light_eye.light_energy = (0.45 * ocular.openness + 0.1) * grow * slices if on else 0.0
	_light_eye.visible = on and grow > 0.02
	_light_gold.global_position = rig.point_at(0.42)
	_light_gold.light_energy = 0.5 * grow * slices * material_profile.gold_emission if on else 0.0
	_light_gold.visible = on and grow > 0.02
	var contact_on := suckers.engaged_count > 0 or exchange_flash > 0.01
	_light_contact.global_position = sensor.contact + sensor.contact_normal * 0.05
	_light_contact.light_energy = maxf(0.3 * grip, 0.85 * exchange_flash) \
			if on and contact_on else 0.0
	_light_contact.visible = on and contact_on


func _relay_events() -> void:
	for e in behavior.take_events():
		if e == "electrochemical_exchange":
			exchange_flash = 1.0
			# The existing vascular bolus arrives at the sensory club; no new
			# shader or animation clock is introduced for the exchange.
			align_pulse_to(0.97)
		_emit(str(e), rig.tip())
	for e in suckers.last_events:
		_emit(str(e), sensor.contact)
	for e in ocular.last_events:
		_emit(str(e), ocular.position)
	for e in halo.last_events:
		_emit(str(e), ocular.position)
	if transformer.last_event != "":
		transformer.last_event = ""


func _emit(event_name: String, at: Vector3) -> void:
	dream_event.emit(event_name, at)
	if OS.get_environment("ENCROACH_DEBUG") == "1":
		print("[TENTACLE] %s %s" % [event_name, state_name()])


## Debug (§25).
func set_toggle(key: String, on: bool) -> void:
	if toggles.has(key):
		toggles[key] = on
	_apply_toggles()


func _ecology_route_goal(target_goal: Vector3, delta: float) -> Vector3:
	# A supported limb has a visible two-contact grammar: emerge normally from
	# its floor/wall socket, flex inward to tend the moss, then release toward
	# the profiled object. Withdrawal reverses that bend through the moss.
	var moss: Vector3 = ecology_colony.origin + anchor_normal * 0.025
	var moss_distance := rig.tip().distance_to(moss)
	ecology_moss_distance_min = minf(ecology_moss_distance_min, moss_distance)
	# Contact is with the broad living heart, not its mathematical origin.
	if moss_distance <= MOSS_CONTACT_RADIUS_M:
		ecology_tended_moss = true
	if ecology_tended_moss and behavior.state != DreamTentacleBehavior.S.WITHDRAW:
		ecology_moss_dwell_s += maxf(delta, 0.0)
	_update_exploration_state(delta)
	var goal := target_goal
	var investigating := behavior.state >= DreamTentacleBehavior.S.ORIENTING \
			and behavior.state <= DreamTentacleBehavior.S.RESTING
	if investigating and not ecology_tended_moss:
		goal = moss
	elif investigating and ecology_moss_dwell_s < 0.72:
		# A real tending contact bears weight for a moment; it is not a waypoint
		# crossed at full speed.
		goal = moss + anchor_normal * (0.008 * sin(clock * 2.1 + seed_phase))
	elif investigating:
		# Extend asymmetrically through a quadratic load-bearing arc. The rig's
		# damped joints follow this slowly moving distal demand, giving the limb
		# inertia and distributed flex rather than a swivel at the socket.
		ecology_route_extension = move_toward(ecology_route_extension, 1.0,
				maxf(delta, 0.0) * 0.34)
		var s := smoothstep(0.0, 1.0, ecology_route_extension)
		var lateral := anchor_normal.cross(target_goal - moss)
		if lateral.length_squared() < 0.001:
			lateral = anchor_normal.cross(Vector3.RIGHT)
		lateral = lateral.normalized()
		var shoulder := moss + anchor_normal * 0.34 + lateral * sin(seed_phase) * 0.09
		goal = moss * ((1.0 - s) * (1.0 - s)) \
				+ shoulder * (2.0 * (1.0 - s) * s) + target_goal * (s * s)
		# The distal club leads an irregular bounded search before commitment:
		# two incommensurate phases produce reversals and hesitant corrections,
		# while amplitude dies as contact/novel information commits the animal.
		var search_weight := 1.0 - smoothstep(0.38, 0.82, s)
		var support_side := anchor_normal.cross(support_tangent).normalized()
		var sweep := support_tangent * sin(clock * 0.83 + seed_phase) * 0.105 \
				+ support_side * sin(clock * 1.37 + seed_phase * 0.61) * 0.072 \
				+ anchor_normal * sin(clock * 0.47 + seed_phase * 1.31) * 0.045
		goal += sweep * search_weight * sin(s * PI) \
				+ lateral * sin(clock * 1.17 + seed_phase) * 0.018 * sin(s * PI)
		if search_weight > 0.2 and delta > 0.0 and exploration_probe_directions.size() < 12:
			var direction := (goal - rig.tip()).normalized()
			if exploration_probe_directions.is_empty() \
					or direction.dot(exploration_probe_directions[-1]) < 0.92:
				exploration_probe_directions.append(direction)
	elif behavior.state == DreamTentacleBehavior.S.WITHDRAW:
		var withdraw_t := clampf(behavior.state_clock /
				maxf(0.1, behavior_profile.withdraw_s), 0.0, 1.0)
		if withdraw_t < 0.55:
			goal = target_goal.lerp(moss, smoothstep(0.0, 0.55, withdraw_t))
		else:
			goal = moss.lerp(anchor + anchor_normal * 0.05,
					smoothstep(0.55, 1.0, withdraw_t))
	ecology_supported_goal = goal
	return goal


func _update_exploration_state(delta: float) -> void:
	var previous := exploration_state
	var contact_distance := rig.tip().distance_to(sensor.contact)
	if ecology_colony.phase >= ecology_colony.Phase.WITHERING:
		exploration_state = ExplorationState.WITHERING
	elif behavior.state == DreamTentacleBehavior.S.WITHDRAW:
		exploration_state = ExplorationState.DEFENSIVE_RECALL \
				if ecology_colony.disturbance > 0.0 else ExplorationState.INFORMATION_RETURN
	elif not ecology_tended_moss or ecology_moss_dwell_s < 0.72:
		exploration_state = ExplorationState.RESTING_AT_MOSS
	elif contact_distance < 0.035 and behavior.state == DreamTentacleBehavior.S.TASTING:
		exploration_state = ExplorationState.EDGE_TRACING
	elif contact_distance < 0.035 and behavior.state in [DreamTentacleBehavior.S.TOUCHING,
			DreamTentacleBehavior.S.CARESSING]:
		exploration_state = ExplorationState.PALPATING
	elif contact_distance < 0.12:
		exploration_state = ExplorationState.SURFACE_CONTACT
	elif ecology_route_extension < 0.30:
		exploration_state = ExplorationState.LOCAL_SWEEP
	elif ecology_route_extension < 0.68:
		exploration_state = ExplorationState.TENTATIVE_REACH
	else:
		exploration_state = ExplorationState.COMMITTED_REACH
	if exploration_state in [ExplorationState.SURFACE_CONTACT,
			ExplorationState.PALPATING, ExplorationState.EDGE_TRACING]:
		exploration_contact_s += maxf(delta, 0.0)
	if previous != exploration_state and exploration_state in [ExplorationState.LOCAL_SWEEP,
			ExplorationState.REORIENTING, ExplorationState.TENTATIVE_REACH]:
		exploration_reversals += 1


func _apply_toggles() -> void:
	_material.set_shader_parameter("breathing", 1.0 if toggles.breathing else 0.0)
	_material.set_shader_parameter("peristalsis", 1.0 if toggles.peristalsis else 0.0)
	_material.set_shader_parameter("dbg_vein_pulse", toggles.vein_pulse)
	_material.set_shader_parameter("dbg_gold_flow", toggles.gold_flow)
	_material.set_shader_parameter("gold_flow", material_profile.gold_flow if toggles.gold_flow else 0.0)
	_material.set_shader_parameter("dbg_gold_emission", toggles.gold_emission)
	_material.set_shader_parameter("dbg_rim", toggles.rim)
	_material.set_shader_parameter("dbg_phase", toggles.phase_slice)
	_material.set_shader_parameter("debug_gray", toggles.gray)
	ocular.set_debug_gray(toggles.gray)
	ocular.eye_material.set_shader_parameter("dbg_interior", toggles.interior)
	halo.set_debug_gray(toggles.gray)
	halo.set_enabled(toggles.halos)
	suckers.set_debug_gray(toggles.gray)
	if skeleton != null:
		skeleton.set_debug_gray(toggles.gray)
		if not toggles.get("gold_structures", true):
			skeleton.set_visible(false)
	suckers.multimesh.visible = toggles.suckers
	membrane.set_debug_gray(toggles.gray)
	if _bones != null:
		_bones.visible = toggles.show_bones


func _draw_bones() -> void:
	if _bones == null:
		_bones = MeshInstance3D.new()
		_bones.name = "Bones"
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.2, 1.0, 0.4)
		m.no_depth_test = true
		_bones.material_override = m
		add_child(_bones)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in DreamTentacleRig.N - 1:
		im.surface_add_vertex(rig.pos[i])
		im.surface_add_vertex(rig.pos[i + 1])
	im.surface_add_vertex(sensor.contact)
	im.surface_add_vertex(sensor.contact + sensor.contact_normal * 0.15)
	# The gaze, and the halo plane.
	im.surface_add_vertex(ocular.position)
	im.surface_add_vertex(ocular.position + ocular.gaze * 0.3)
	im.surface_add_vertex(halo.centre - halo.axis * 0.05)
	im.surface_add_vertex(halo.centre + halo.axis * 0.05)
	im.surface_end()
	_bones.mesh = im


func census() -> Dictionary:
	return {"state": state_name(), "grow": grow, "grip": grip, "curl": curl,
			"target": target_name, "deposits": deposits, "tip": rig.tip(),
			"contact": sensor.contact, "anchor": anchor, "eye_open": ocular.openness,
			"embedded_root": embedded_root, "root_embed_m": ROOT_EMBED_M,
			"support_kind": support_kind, "support_normal": anchor_normal,
			"root_plane_error_m": absf((rig.anchor - anchor).dot(anchor_normal) + ROOT_EMBED_M),
			"suckers_engaged": suckers.engaged_count, "interest": behavior.interest,
			"synaptic_probe_index": behavior.synaptic_probe_index,
			"synaptic_probe_phase": behavior.synaptic_probe_phase,
			"synaptic_attempts": behavior.synaptic_attempts,
			"electrochemical_pulses": behavior.electrochemical_pulses,
			"secretion_transfers": behavior.secretion_transfers,
			"exchange_flash": exchange_flash,
			"emergence_pressure": emergence_pressure,
			"emergence_pressure_peak": emergence_pressure_peak,
			"field_pressure_writes": field_pressure_writes,
			"ecology_purpose": ecology_purpose_name, "ecology_status": ecology_status,
			"ecology_ether": float(ecology_record.get("ether", 0.0)),
			"ecology_ether_min": ecology_ether_min, "ecology_reports": ecology_reports,
			"ecology_tended_moss": ecology_tended_moss,
			"ecology_moss_distance_min": ecology_moss_distance_min,
			"ecology_moss_dwell_s": ecology_moss_dwell_s,
			"ecology_route_extension": ecology_route_extension,
			"ecology_supported_goal": ecology_supported_goal,
			"exploration_state": EXPLORATION_NAMES[exploration_state],
			"exploration_probe_directions": exploration_probe_directions.size(),
			"exploration_contact_s": exploration_contact_s,
			"exploration_reversals": exploration_reversals,
			"exploration_target_reserved": exploration_target_reserved,
			"exploration_novelty": exploration_novelty}
