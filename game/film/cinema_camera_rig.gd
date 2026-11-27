class_name CinemaCameraRig
extends Node3D
## Borrows the active view for a film shot. The player, prologue and inspection
## cameras keep their own input, movement, optics and transforms.

enum Mode { GAMEPLAY_FP, CINEMA_DIRECTOR }

## Optional dedicated child. A rig with no assigned camera creates one only
## after a current gameplay camera has agreed to yield the viewport.
@export var film_camera: Camera3D

var mode := Mode.GAMEPLAY_FP
var _previous: Camera3D
var _lens := CameraAttributesPhysical.new()
var _handheld := FastNoiseLite.new()


func begin_cinema(gameplay_camera: Camera3D) -> bool:
	if not is_inside_tree() or not is_instance_valid(gameplay_camera):
		return false
	if mode == Mode.CINEMA_DIRECTOR:
		return _previous == gameplay_camera and _owns_view()
	if not gameplay_camera.is_inside_tree() or gameplay_camera.is_queued_for_deletion():
		return false
	if gameplay_camera.get_viewport() != get_viewport() or not gameplay_camera.is_current() \
			or gameplay_camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return false
	if not is_instance_valid(film_camera):
		film_camera = Camera3D.new()
		film_camera.name = "FilmCamera"
		add_child(film_camera)
	if film_camera == gameplay_camera or not is_ancestor_of(film_camera) \
			or not film_camera.is_inside_tree() or film_camera.is_queued_for_deletion() \
			or film_camera.get_viewport() != get_viewport():
		return false
	_previous = gameplay_camera
	film_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	film_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	film_camera.h_offset = 0.0
	film_camera.v_offset = 0.0
	film_camera.global_transform = gameplay_camera.get_camera_transform().orthonormalized()
	film_camera.cull_mask = gameplay_camera.cull_mask
	film_camera.environment = gameplay_camera.environment
	film_camera.compositor = gameplay_camera.compositor
	_lens.frustum_near = gameplay_camera.near
	_lens.frustum_far = gameplay_camera.far
	# Match the outgoing view until the first authored sample. A physical
	# camera measures vertical FOV even when the source preserves its width.
	var tangent := tan(deg_to_rad(gameplay_camera.fov) * 0.5)
	if gameplay_camera.keep_aspect == Camera3D.KEEP_WIDTH:
		var view_size := get_viewport().get_visible_rect().size
		tangent *= view_size.y / maxf(view_size.x, 1.0)
	_lens.frustum_focal_length = 12.0 / maxf(tangent, 0.0001)
	var source_attributes := gameplay_camera.attributes
	if source_attributes == null:
		source_attributes = gameplay_camera.get_world_3d().camera_attributes
	_lens.exposure_multiplier = source_attributes.exposure_multiplier if source_attributes else 1.0
	film_camera.attributes = _lens
	_handheld.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_handheld.fractal_type = FastNoiseLite.FRACTAL_NONE
	_handheld.frequency = 0.36
	# Child tree_exiting arrives before Godot automatically selects some other
	# camera from this viewport when the child or the entire rig is removed.
	if not film_camera.tree_exiting.is_connected(end_cinema):
		film_camera.tree_exiting.connect(end_cinema)
	mode = Mode.CINEMA_DIRECTOR
	film_camera.make_current()
	return true


func end_cinema() -> void:
	if mode != Mode.CINEMA_DIRECTOR:
		return
	var restore := _previous
	var owned := _owns_view()
	mode = Mode.GAMEPLAY_FP
	_previous = null
	if not owned:
		return
	if is_instance_valid(restore) and restore.is_inside_tree() \
			and not restore.is_queued_for_deletion() and restore.get_viewport() == film_camera.get_viewport():
		restore.make_current()
	else:
		film_camera.clear_current()


func _owns_view() -> bool:
	return is_instance_valid(film_camera) and film_camera.is_inside_tree() and film_camera.is_current()


## Evaluate any output frame directly, including a backwards seek. Positions
## and aim marks are world metres. first_frame is the shot's absolute in point.
## travel_frames counts intervals: frames 0..1079 span 1079 intervals.
## Set both dolly_control_* positions to use a cubic Bezier rail. Otherwise the
## dolly runs straight between the two marks. focus_start_frame is shot-local.
## focus_frames and travel_frames can independently be zero for an instant cut.
func sample_shot(frame: int, fps: int, shot: Dictionary) -> bool:
	if mode != Mode.CINEMA_DIRECTOR:
		return false
	if not _owns_view():
		end_cinema()
		return false
	if frame < 0 or fps <= 0:
		return false
	for key: String in ["from_position", "to_position", "look_at_position"]:
		if not shot.get(key) is Vector3:
			return false
	var start: Vector3 = shot.from_position
	var finish: Vector3 = shot.to_position
	var aim_start: Vector3 = shot.look_at_position
	var aim_end: Variant = shot.get("look_at_end_position", aim_start)
	var control_a: Variant = shot.get("dolly_control_from")
	var control_b: Variant = shot.get("dolly_control_to")
	if not start.is_finite() or not finish.is_finite() or not aim_start.is_finite() \
			or not aim_end is Vector3 or not aim_end.is_finite():
		return false
	var curved := control_a != null or control_b != null
	if curved and (not control_a is Vector3 or not control_b is Vector3 \
			or not control_a.is_finite() or not control_b.is_finite()):
		return false
	for key: String in ["first_frame", "travel_frames", "focus_start_frame", "focus_frames",
			"focal_length_mm", "aperture_f", "focus_from_m", "focus_to_m", "handheld_m", "seed"]:
		if shot.has(key) and (typeof(shot[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(shot[key]))):
			return false
	var first := int(shot.get("first_frame", 0))
	var travel := int(shot.get("travel_frames", 0))
	var focus_start := int(shot.get("focus_start_frame", 0))
	var focus_duration := int(shot.get("focus_frames", travel))
	var focal_mm := float(shot.get("focal_length_mm", 35.0))
	var aperture := float(shot.get("aperture_f", 4.0))
	var focus_from := float(shot.get("focus_from_m", start.distance_to(aim_start)))
	var focus_to := float(shot.get("focus_to_m", focus_from))
	var handheld_m := float(shot.get("handheld_m", 0.0))
	if first < 0 or frame < first or travel < 0 or focus_start < 0 or focus_duration < 0 \
			or focal_mm <= 0.0 or aperture <= 0.0 or handheld_m < 0.0 \
			or minf(focus_from, focus_to) < (focal_mm + 1.0) / 1000.0:
		return false
	var local_frame := frame - first
	var travel_weight := _settled_weight(local_frame, travel)
	var focus_weight := _settled_weight(local_frame - focus_start, focus_duration)
	var eye := start.lerp(finish, travel_weight)
	if curved:
		eye = start.bezier_interpolate(control_a, control_b, finish, travel_weight)
	var initial_view := aim_start - start
	var view := aim_start.lerp(aim_end, travel_weight) - eye
	if initial_view.length_squared() < 0.000001 or view.length_squared() < 0.000001:
		return false
	initial_view = initial_view.normalized()
	view = view.normalized()
	var up := Vector3.UP if absf(initial_view.y) < 0.9999 else Vector3.FORWARD
	var opening := Basis.looking_at(initial_view, up)
	# Transport the opening up vector across the move. A continuous pedestal
	# past the zenith must not choose a new up axis halfway through a shot.
	var turn := Quaternion(initial_view, view)
	if initial_view.dot(view) < -0.999999:
		turn = Quaternion(opening.y, PI)
	var orientation := Basis.looking_at(view, turn * opening.y)
	if handheld_m > 0.0:
		var seed_value := int(shot.get("seed", 0))
		if _handheld.seed != seed_value:
			_handheld.seed = seed_value
		var seconds := float(local_frame) / float(fps)
		var sway := Vector3(_handheld.get_noise_2d(seconds, 11.0),
				_handheld.get_noise_2d(seconds, 29.0), _handheld.get_noise_2d(seconds, 53.0) * 0.35)
		eye += orientation * sway * handheld_m
	film_camera.global_transform = Transform3D(orientation, eye)
	# CameraAttributesPhysical uses the engine's 24 mm vertical gate. It owns
	# vertical FOV and near/far. The 180-degree shutter is exposure metadata;
	# it does not simulate motion blur.
	if _lens.frustum_focal_length != focal_mm:
		_lens.frustum_focal_length = focal_mm
	if _lens.exposure_aperture != aperture:
		_lens.exposure_aperture = aperture
	var focus_m := lerpf(focus_from, focus_to, focus_weight)
	if _lens.frustum_focus_distance != focus_m:
		_lens.frustum_focus_distance = focus_m
	if _lens.exposure_shutter_speed != fps * 2.0:
		_lens.exposure_shutter_speed = fps * 2.0
	return true


## A normalized pair of critically damped step responses starts and ends at
## rest. Closed-form evaluation makes a pickup match a continuous take.
static func _settled_weight(offset: int, intervals: int) -> float:
	if offset < 0:
		return 0.0
	if offset >= intervals:
		return 1.0
	var forward := 2.0 * float(offset) / float(intervals)
	var backward := 2.0 - forward
	var entering := 1.0 - (1.0 + forward) * exp(-forward)
	var leaving := 1.0 - (1.0 + backward) * exp(-backward)
	return entering / (entering + leaving)
