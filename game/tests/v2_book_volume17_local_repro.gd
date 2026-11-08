extends Node3D
## INERT nearby Volume17 pickup reproduction. The normal player owns all motion.
const Nook := preload("res://scripts/building/orison_v2_reading_nook.gd")
const STOCK_ID := "nook_books__Volume17"
const RECORDED_EYE := "Transform3D(0.8687908, 0.24290279, -0.4315099, 0, 0.8714215, 0.49053502, 0.49517933, -0.4261723, 0.757083, 0.4283762, -1.7810313, -13.789711)"
const RECORDED_DISTANCE_M := 1.13955938816071
const OWNER_ORIGIN := Vector3(.48500133, -3.2, -14.9897995)
const FPS_OFFSET := Vector3(.17, -.16, -.48)
const TICKS := 130

var precision:=preload("res://scripts/building/v2_contact_precision.gd").new()
var player: PlayerController
var book: RigidBody3D
var shelf: Node3D
var report: Dictionary = {"evidence_class": "INERT", "stock_id": STOCK_ID, "frames": []}
var _before: Dictionary
var _before_basis: Basis
var _observing := false
var _output := ""

func _ready() -> void:
	process_physics_priority = 100
	set_physics_process(false)
	_run.call_deferred()

func _exit_tree() -> void:
	precision.release()

func _run() -> void:
	if not precision.bind(get_world_3d()):
		_finish("native V2 contact precision required",2);return
	_output = OS.get_environment("SHOT_DIR")
	if _output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_finish("fresh writable SHOT_DIR required", 2)
		return
	if FileAccess.file_exists(_output.path_join("volume17_withdrawal.json")):
		_output = ""
		_finish("existing trace in SHOT_DIR", 2)
		return
	var viewport := get_viewport() as SubViewport
	if viewport == null or viewport.size != Vector2i(3440, 1440):
		_finish("detached native 3440x1440 viewport required", 2)
		return
	report.viewport_px = [viewport.size.x, viewport.size.y]
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var fixture := Node3D.new()
	fixture.name = "NativeNookFixture"
	add_child(fixture)
	var adapter := OrisonV2AnchorAdapter.new(fixture)
	if not Nook.mount(adapter):
		_finish("native nook mount refused", 2)
		return
	shelf = adapter.resolve("nook_books_library") as Node3D
	var copy_count := 0
	for collection: Node in fixture.find_children("*_library", "Node3D", true, false):
		copy_count += (collection.get("_books") as Dictionary).size()
	if shelf == null or copy_count != 61:
		_finish("expected native nook library and all 61 copies", 2)
		return
	var copies: Dictionary = shelf.get("_books")
	book = copies.get(STOCK_ID) as RigidBody3D
	if book == null:
		_finish("Volume17 identity missing", 2)
		return
	var construction: Dictionary = book.get("construction")
	if book.get("title_id") != "concrete" or construction.get("opening_style") != "hardback":
		_finish("Volume17 construction identity mismatch", 2)
		return
	var mounted_owner := shelf.global_transform
	var installed_owner := Transform3D(Basis(Vector3.UP, PI), OWNER_ORIGIN)
	fixture.global_transform = installed_owner * mounted_owner.affine_inverse() * fixture.global_transform
	report.native_copy_count = copy_count
	report.native_owner_before = var_to_str(mounted_owner)
	report.fixture_transform = var_to_str(fixture.global_transform)
	report.owner_transform = var_to_str(shelf.global_transform)
	report.book_at_mount = var_to_str(book.global_transform)

	var recorded_eye: Transform3D = str_to_var(RECORDED_EYE)
	var foot := recorded_eye.origin - Vector3.UP * PlayerController.STANDING_EYE
	var floor_body := StaticBody3D.new()
	floor_body.name = "FixtureStandingFloor"
	add_child(floor_body)
	# Original authored floor elevation supports the stance; native stock retains its shapes.
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(.8, .10, .8)
	floor_shape.shape = slab
	floor_body.add_child(floor_shape)
	var floor_top: float = float(JSON.parse_string(FileAccess.get_file_as_string(Nook.PATH)).floor_y)
	floor_body.global_position = Vector3(foot.x, floor_top - slab.size.y * .5, foot.z)
	report.fixture_floor = {"top_y": floor_top, "size_m": _vec(slab.size), "identity": _identity(floor_body)}

	player = PlayerController.new()
	player.name = "StancePlayer"
	add_child(player)
	player.global_transform = Transform3D(Basis(Vector3.UP, atan2(.792624, .609711)), foot)
	player.camera.global_transform = recorded_eye
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in 12:
		await get_tree().physics_frame
	report.standing_eye_error_m = player.camera.global_position.distance_to(recorded_eye.origin)
	report.player_before_aim = var_to_str(player.global_transform)
	if not player.is_on_floor() or player.collision_mask == 0 or report.standing_eye_error_m > .003:
		report.stance_contacts = _player_contacts()
		_finish("normal standing capsule did not settle at recorded eye", 2)
		return
	if int(book.get("shelf_slot")) < 0 or not is_zero_approx(float(book.get("opening"))):
		_finish("selected native copy must start closed and in its slot", 2)
		return
	var spine_local := Vector3(-.001, float(construction.height) * .65, 0)
	var spine := book.to_global(spine_local)
	report.selection = {"original_distance_m": RECORDED_DISTANCE_M,
		"local_distance_m": player.camera.global_position.distance_to(spine),
		"spine_local_m": _vec(spine_local), "spine_world_m": _vec(spine), "book": _identity(book)}
	player.camera.look_at(spine)
	for tick in 2:
		await get_tree().physics_frame
	var descriptor: Dictionary = player._grab.find_target()
	report.real_spine_ray = _hit(player._grab.last_hit)
	report.ray_part = _identity(descriptor.get("part"))
	report.before_primary = _snapshot()
	if descriptor.get("part") != book or descriptor.get("kind") != "free":
		_finish("real spine ray did not select the same Volume17", 2)
		return
	var primary := InputEventMouseButton.new()
	primary.button_index = MOUSE_BUTTON_LEFT
	primary.pressed = true
	primary.position = Vector2(viewport.size) * .5
	primary.global_position = primary.position
	viewport.notify_mouse_entered()
	viewport.push_input(primary, true)
	report.after_primary = _snapshot()
	report.primary_ray = _hit(player._grab.last_hit)
	if player.held_stock_body() != book:
		_finish("actual primary did not claim the original body", 2)
		return
	get_tree().physics_frame.connect(_before_tick)
	_observing = true
	set_physics_process(true)

func _before_tick() -> void:
	if _observing:
		_before = _snapshot()
		_before_basis = book.basis

func _physics_process(delta: float) -> void:
	if not _observing or _before.is_empty():
		return
	var after := _snapshot()
	if after.hold_blocked and after.extracted and after.stock_contact.is_empty():
		after.angular_probe = _rotation_candidate(delta)
	report.frames.append({"tick": report.frames.size() + 1, "before": _before, "after": after})
	_before = {}
	if report.frames.size() == TICKS:
		_observing = false
		get_tree().physics_frame.disconnect(_before_tick)
		set_physics_process(false)
		var reached: bool = after.same_body and after.fps_centre_error_m < .003
		report.reached_original_fps_goal = reached
		report.final = after
		_finish.call_deferred("reached" if reached else "original 3 mm FPS hand goal missed", 0 if reached else 1)

func _snapshot() -> Dictionary:
	var camera := player.camera.global_transform
	var view := camera.translated_local(Vector3(0, 0, -player._grab._held_depth))
	var centre: Vector3 = book.call("pickup_centre")
	var lift_goal: Vector3 = book.get("_pickup_lift_goal")
	var exit_goal: Vector3 = book.get("_pickup_exit")
	var motion: Dictionary = book.get("_last_motion")
	return {"physics_frame": Engine.get_physics_frames(), "player_transform": var_to_str(player.global_transform),
		"player_velocity_mps": _vec(player.velocity), "on_floor": player.is_on_floor(), "player_contacts": _player_contacts(),
		"camera_transform": var_to_str(camera), "book_transform": var_to_str(book.global_transform),
		"book_local_transform": var_to_str(book.transform), "same_body": player.held_stock_body() == book,
		"hand_active": player._grab.active(), "grab_depth_m": player._grab._held_depth,
		"held": book.get("_held"), "frozen": book.freeze, "slot": book.get("shelf_slot"),
		"lifted": book.get("_pickup_lifted"), "extracted": book.get("_pickup_extracted"),
		"hold_blocked": book.get("_hold_blocked"), "stock_contact": _hit(motion),
		"lift_goal_world_m": _vec(lift_goal), "exit_goal_world_m": _vec(exit_goal),
		"lift_error_m": book.global_position.distance_to(lift_goal), "exit_error_m": book.global_position.distance_to(exit_goal),
		"fps_goal_world_m": _vec(camera * FPS_OFFSET), "effective_hold_origin_world_m": _vec(view * FPS_OFFSET - view.basis * centre),
		"fps_centre_error_m": (book.global_transform * centre).distance_to(camera * FPS_OFFSET)}

func _rotation_candidate(delta: float) -> Dictionary:
	# Read-only follow-up for the boolean rotation guard. Production's recorded
	# translation contact takes precedence and remains in stock_contact.
	var wanted := shelf.global_basis.inverse() * player.camera.global_basis
	var original_angle := _before_basis.get_rotation_quaternion().angle_to(wanted.get_rotation_quaternion())
	var remaining := book.basis.get_rotation_quaternion().angle_to(wanted.get_rotation_quaternion())
	if original_angle < .0001 or remaining < .0001:
		return {}
	var accepted_angle := minf(original_angle, 6.0 * delta)
	var step_angle := accepted_angle / maxi(1, ceili(accepted_angle / .025))
	var candidate := book.global_transform
	candidate.basis = shelf.global_basis * book.basis.slerp(wanted, minf(1., step_angle / remaining))
	var exclusions: Array[RID] = book.call("_query_exclusions")
	var space := book.get_world_3d().direct_space_state
	for solid: CollisionShape3D in book.get("_solids"):
		if solid.disabled:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = solid.shape
		query.transform = candidate * solid.transform
		query.exclude = exclusions
		query.margin = .00001
		query.collision_mask = book.collision_mask
		var overlaps := space.intersect_shape(query, 1)
		if overlaps.is_empty():
			continue
		var contact := _hit(overlaps[0])
		var rest := space.get_rest_info(query)
		if rest.get("collider_id", -1) == overlaps[0].get("collider_id", 0):
			contact["normal"] = _vec(rest.normal)
			contact["point"] = _vec(rest.point)
		return {"kind": "independent next angular step overlap", "stock_shape": str(solid.get_path()),
			"candidate_transform": var_to_str(candidate), "contact": contact}
	return {"kind": "independent next angular step had no overlap"}

func _player_contacts() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		for contact in mini(hit.get_collision_count(), 4):
			rows.append({"collider": _identity(hit.get_collider(contact)), "rid": str(hit.get_collider_rid(contact)),
				"shape": hit.get_collider_shape_index(contact), "normal": _vec(hit.get_normal(contact)),
				"point": _vec(hit.get_position(contact))})
	return rows

func _hit(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {}
	var row := {"collider": _identity(hit.get("collider"))}
	for key: String in ["normal", "point", "position", "motion"]:
		if hit.has(key):
			row[key] = _vec(hit[key])
	for key: String in ["shape", "face_index", "safe", "unsafe", "unresolved_native_impact"]:
		if hit.has(key):
			row[key] = hit[key]
	if hit.has("rid"):
		row["rid"] = str(hit.rid)
	return row

func _identity(value: Variant) -> Dictionary:
	if value is not Node or not is_instance_valid(value):
		return {}
	var row := {"path": str(value.get_path()), "instance_id": value.get_instance_id()}
	if value is CollisionObject3D:
		row["rid"] = str(value.get_rid())
	return row

func _vec(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func _finish(reason: String, code: int) -> void:
	report.result = reason
	if not _output.is_empty():
		var file := FileAccess.open(_output.path_join("volume17_withdrawal.json"), FileAccess.WRITE)
		if file == null or not file.store_string(JSON.stringify(report, "\t")):
			push_error("VOLUME17 REPRO: cannot write trace")
			get_tree().quit(2)
			return
		file.close()
	print("VOLUME17 REPRO: ", reason, " frames=", report.frames.size())
	get_tree().quit(code)
