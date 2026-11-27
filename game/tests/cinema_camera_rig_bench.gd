extends Node3D
## Native camera ownership, optical units and frame-addressed pickup checks.

const Rig := preload("res://film/cinema_camera_rig.gd")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures.append(label)
		print("  FAIL  ", label)
	return ok


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("CINEMA CAMERA RIG: %s checks=%d failures=%d" % [status, _checks, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	var player := Camera3D.new()
	var foreign := Camera3D.new()
	add_child(player)
	add_child(foreign)
	player.fov = 69.0
	player.keep_aspect = Camera3D.KEEP_WIDTH
	player.position = Vector3(1.2, 1.65, 3.0)
	player.h_offset = 0.06
	player.make_current()
	var player_transform := player.global_transform
	var prior_projection := player.get_camera_projection()
	var rig := Rig.new()
	add_child(rig)
	_check(player.is_current() and rig.film_camera == null, "idle rig leaves gameplay current")
	_check(not rig.begin_cinema(foreign) and player.is_current(), "inactive source cannot surrender the view")
	if not _check(rig.begin_cinema(player), "current gameplay camera lends the viewport"):
		_finish()
		return
	var film: Camera3D = rig.film_camera
	var lens := film.attributes as CameraAttributesPhysical
	_check(rig.begin_cinema(player) and film.is_current(), "repeated acquisition preserves the same owner")
	_check(film.global_transform.is_equal_approx(player.get_camera_transform()), "opening handoff keeps the offset eye")
	var film_projection := film.get_camera_projection()
	_check(film_projection.x.is_equal_approx(prior_projection.x) and film_projection.y.is_equal_approx(prior_projection.y)
			and film_projection.z.is_equal_approx(prior_projection.z) and film_projection.w.is_equal_approx(prior_projection.w),
			"opening lens preserves the outgoing frustum")
	if not _check(lens != null, "film camera owns a physical lens"):
		_finish()
		return
	var shot := {
		"first_frame": 12, "travel_frames": 48,
		"from_position": Vector3(0.0, 1.1, 3.0), "to_position": Vector3(0.8, 1.4, 1.7),
		"look_at_position": Vector3(0.1, 1.3, 0.0),
		"dolly_control_from": Vector3(-0.3, 1.4, 2.9), "dolly_control_to": Vector3(0.6, 1.5, 2.2),
		"focal_length_mm": 50.0, "aperture_f": 2.8, "focus_from_m": 2.5, "focus_to_m": 1.1,
		"focus_start_frame": 8, "focus_frames": 24, "handheld_m": 0.0, "seed": 574
	}
	_check(rig.sample_shot(12, 24, shot) and film.global_position.is_equal_approx(shot.from_position),
			"first shot frame lands exactly on the start mark")
	_check(is_equal_approx(film.fov, rad_to_deg(2.0 * atan(12.0 / 50.0)))
			and is_equal_approx(lens.exposure_aperture, 2.8) and lens.exposure_shutter_speed == 48.0,
			"50 mm lens, f-number, 24 mm vertical gate and 180-degree shutter agree")
	_check(rig.sample_shot(60, 24, shot) and film.global_position.is_equal_approx(shot.to_position)
			and is_equal_approx(lens.frustum_focus_distance, 1.1), "dolly and rack reach their end marks")
	_check(rig.sample_shot(17, 24, shot) and is_equal_approx(lens.frustum_focus_distance, 2.5),
			"rack holds until its own in point")
	shot.handheld_m = 0.014
	_check(rig.sample_shot(32, 24, shot), "nonzero-frame pickup seeks directly")
	var pickup_transform := film.global_transform
	var pickup_focus := lens.frustum_focus_distance
	_check(pickup_focus < 2.5 and pickup_focus > 1.1, "focus lies between its metre marks during the rack")
	for frame: int in range(12, 33):
		rig.sample_shot(frame, 24, shot)
	_check(film.global_transform == pickup_transform and lens.frustum_focus_distance == pickup_focus,
			"direct pickup matches consecutive sampling exactly")
	shot.seed = 575
	_check(rig.sample_shot(32, 24, shot) and film.global_transform != pickup_transform, "different seed changes handheld sway")
	shot.seed = 574
	_check(rig.sample_shot(32, 24, shot) and film.global_transform == pickup_transform, "original seed reproduces the take")
	_check(not rig.sample_shot(11, 24, shot) and not rig.sample_shot(32, 0, shot)
			and film.global_transform == pickup_transform, "bad frame or cadence leaves the current sample intact")
	var invalid := shot.duplicate()
	invalid.dolly_control_from = null
	_check(not rig.sample_shot(32, 24, invalid) and film.global_transform == pickup_transform, "incomplete rail cannot disturb a good sample")
	rig.end_cinema()
	_check(player.is_current() and player.global_transform == player_transform and player.attributes == null
			and player.fov == 69 and player.keep_aspect == Camera3D.KEEP_WIDTH, "release restores the untouched gameplay camera")
	_check(rig.begin_cinema(player), "second take can acquire")
	foreign.make_current()
	_check(not rig.sample_shot(32, 24, shot), "film relinquishes a third-party takeover")
	rig.end_cinema()
	_check(foreign.is_current(), "repeated release preserves the successor")
	player.make_current()
	_check(rig.begin_cinema(player), "last take acquires before teardown")
	rig.free()
	_check(player.is_current(), "removing the rig restores its lender before the child camera exits")
	_finish()
