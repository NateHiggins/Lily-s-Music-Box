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
## sucker_attach, sucker_release, surface_caress, dream_conversion,
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
const RINGS := 96
const SEGS := 28
const COLLARS := 11

var field = null
var source_index := 0
var anchor := Vector3.ZERO
var anchor_normal := Vector3.UP
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
		candidates: Array, seed_v: int) -> void:
	field = living_field
	source_index = src
	anchor = at
	anchor_normal = normal.normalized()
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
	rig.configure(anchor, anchor_normal, behavior_profile.length_m, seed_phase)
	rig.tremor_hz = behavior_profile.tremor_hz
	rig.tremor_m = behavior_profile.tremor_m
	behavior = BehaviorScript.new()
	behavior.anchor = anchor
	behavior.anchor_normal = anchor_normal
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
	_probe.global_position = anchor + anchor_normal * 0.7
	add_child(_probe)


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
	if behavior.state == DreamTentacleBehavior.S.DONE:
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
	behavior.tip = rig.tip()
	behavior.update(delta)
	# The rig carries it out.
	grow = behavior.grow
	rig.grow = grow
	rig.tip_goal = behavior.tip_goal
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
	membrane.update(behavior.membrane_tension if toggles.membrane else 0.0, grow,
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
	_relay_events()
	if toggles.show_bones:
		_draw_bones()


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
	var contact_on := suckers.engaged_count > 0
	_light_contact.global_position = sensor.contact + sensor.contact_normal * 0.05
	_light_contact.light_energy = (0.3 * grip if contact_on else 0.0) if on else 0.0
	_light_contact.visible = on and contact_on


func _relay_events() -> void:
	for e in behavior.take_events():
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
			"suckers_engaged": suckers.engaged_count, "interest": behavior.interest}
