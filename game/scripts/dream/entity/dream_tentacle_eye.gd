class_name DreamTentacleEye
extends RefCounted
## The angel's eye (DREAM_TENTACLE_DIRECTION §8): a sphere seated in the
## limb's socket at 80 % of its length, dorsal; its own state machine —
## closed, partial, watching the object, watching the contact, exploring
## the room, locked on the player, closing — with pupil dilation following
## interest, an occasional slow blink, and a gaze that turns independently
## of the limb. Calm: the gaze eases, it never twitches. The interior shows
## through the pupil when it dilates past its threshold (§10).

const SHADER := preload("res://shaders/dream_eye.gdshader")
const EYE_V := 0.80
const EYE_U := 0.25
const RADIUS_M := 0.046

var mesh: MeshInstance3D
var material: ShaderMaterial
var mode := "closed"
var openness := 0.0
var pupil := 0.32
var interior := 0.0
var gaze := Vector3.FORWARD
var gaze_target := Vector3.ZERO
var position := Vector3.ZERO
var normal := Vector3.UP
var _blink_clock := 0.0
var _blink := 0.0
var _explore_clock := 0.0
var _explore_dir := Vector3.FORWARD
var _rng := RandomNumberGenerator.new()
var _next_blink := 6.0
var _interior_event := 0.0
## The viewer (the camera): when no player is near, the eye still glances
## at whoever is looking.
var viewer_pos := Vector3.ZERO
var last_events: Array[String] = []


func build(parent: Node3D, seed_v: int) -> void:
	_rng.seed = seed_v
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS_M
	sphere.height = RADIUS_M * 2.0
	sphere.radial_segments = 48
	sphere.rings = 32
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("seed", float(seed_v % 977) * 0.01)
	mesh = MeshInstance3D.new()
	mesh.name = "Eye"
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	parent.add_child(mesh)
	_next_blink = _rng.randf_range(5.0, 11.0)


## Open the interior for a moment (§10): a controlled glimpse.
func glimpse_interior(seconds := 2.4) -> void:
	_interior_event = seconds
	last_events.append("impossible_space")


func update(rig: DreamTentacleRig, contact: Vector3, player_pos: Vector3, has_player: bool,
		interest: float, grow: float, delta: float) -> void:
	last_events.clear()
	# Seat: the socket on the dorsal side at 80 %, the sphere sunk so the
	# lids can cover it; the gaze axis starts along the socket normal.
	var sp := rig.surface_point(EYE_U, EYE_V, -RADIUS_M * 0.28)
	position = sp.pos
	normal = sp.normal
	# Openness by mode, with the blink.
	var want_open := 0.0
	match mode:
		"closed", "closing":
			want_open = 0.0
		"partial":
			want_open = 0.45
		_:
			want_open = 1.0
	if grow < 0.85:
		want_open = minf(want_open, 0.0)
	_blink_clock += delta
	if _blink_clock > _next_blink and want_open > 0.5:
		_blink_clock = 0.0
		_next_blink = _rng.randf_range(6.0, 14.0)
		_blink = 1.0
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta * 2.6)
	var blink_shut := sin(clampf(_blink, 0.0, 1.0) * PI)
	var target_open := want_open * (1.0 - blink_shut)
	var rate := 1.6 if target_open < openness else 0.9
	if blink_shut > 0.01:
		rate = 6.0
	openness = lerpf(openness, target_open, clampf(delta * rate, 0.0, 1.0))
	# Where it looks: the object, the contact, the room, the player.
	var look_to := contact
	match mode:
		"watch_object", "watch_contact":
			look_to = contact
		"explore_room":
			_explore_clock -= delta
			if _explore_clock <= 0.0:
				_explore_clock = _rng.randf_range(1.8, 3.6)
				_explore_dir = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.6),
						_rng.randf_range(-1.0, 1.0)).normalized()
			look_to = position + _explore_dir * 3.0
		"lock_player":
			if has_player:
				look_to = player_pos
	# In any open mode the player near enough draws a glance; so does the
	# viewer, whoever is looking.
	if has_player and mode in ["watch_object", "watch_contact", "explore_room"] \
			and player_pos.distance_to(position) < 1.6:
		look_to = look_to.lerp(player_pos, 0.6)
	elif mode in ["watch_object", "watch_contact", "explore_room"] \
			and viewer_pos.distance_to(position) < 2.6:
		look_to = look_to.lerp(viewer_pos, 0.75)
	gaze_target = look_to
	var want_gaze := (look_to - position).normalized()
	# The gaze cannot leave the socket: within 55° of the socket normal.
	var cosang := want_gaze.dot(normal)
	if cosang < cos(deg_to_rad(68.0)):
		var axis := normal.cross(want_gaze)
		if axis.length() > 1e-4:
			want_gaze = normal.rotated(axis.normalized(), deg_to_rad(68.0))
		else:
			want_gaze = normal
	gaze = gaze.slerp(want_gaze, clampf(delta * 2.2, 0.0, 1.0)).normalized()
	# Pupil: dilates with interest, and deeply for the interior.
	var want_pupil := lerpf(0.22, 0.48, clampf(interest, 0.0, 1.0))
	if _interior_event > 0.0:
		_interior_event -= delta
		want_pupil = 0.78
	pupil = lerpf(pupil, want_pupil, clampf(delta * 1.4, 0.0, 1.0))
	interior = lerpf(interior, 1.0 if _interior_event > 0.0 else 0.0, clampf(delta * 2.0, 0.0, 1.0))
	# Transform: local +z along the gaze.
	var z := gaze
	var any := Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT
	var x := any.cross(z).normalized()
	var y := z.cross(x).normalized()
	mesh.transform = Transform3D(Basis(x, y, z), position)
	mesh.visible = grow > 0.6
	material.set_shader_parameter("pupil", pupil)
	material.set_shader_parameter("interior", interior)


func set_mode(m: String) -> void:
	if m != mode:
		mode = m
		if m == "partial":
			last_events.append("eye_opening")


func set_debug_gray(on: bool) -> void:
	material.set_shader_parameter("debug_gray", on)
