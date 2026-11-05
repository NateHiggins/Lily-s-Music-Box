extends "res://tests/v2_book_lamp_diagnostic.gd"
## INERT nearby native nook and carrier. Reuses the original two-style input.
const LocalNook := preload("res://scripts/building/orison_v2_reading_nook.gd")
const LocalPrecision := preload("res://scripts/building/v2_contact_precision.gd")
const LocalCarrier := preload("res://scripts/device/companion_world_carrier.gd")
const LocalThermal := preload("res://scripts/lamp/carried_lamp_optical_driver.gd")
const LocalStance := preload("res://tests/v2_book_volume17_local_repro.gd")
const LIFT := Vector3.UP * .004
const NATIVE_MARGIN := .00002

# The parent diagnostic reads only _books from this view. Each member keeps
# its real shelf, world transform and collision owner.
class CandidateView extends Node3D:
	var _books: Dictionary = {}

var _local_precision := LocalPrecision.new()
var _local_report: Dictionary = {"evidence_class": "INERT", "selection": [], "actual_input_rays": []}
var _local_output := ""
var _mip_cache: Dictionary = {}

func _ready() -> void:
	set_process(false) # Disable only inherited city profiling.
	_run_local.call_deferred()

func _exit_tree() -> void:
	_local_precision.release()

func _run_local() -> void:
	_local_output = OS.get_environment("SHOT_DIR")
	if _local_output.is_empty() or DirAccess.make_dir_recursive_absolute(_local_output) != OK:
		push_error("Local two-style requires a fresh SHOT_DIR")
		get_tree().quit(2)
		return
	if FileAccess.file_exists(_local_output.path_join("local_two_style.json")):
		push_error("Local two-style report already exists")
		get_tree().quit(2)
		return
	var viewport := get_viewport() as SubViewport
	if not _require(viewport != null and viewport.size == NATIVE_PIXELS, "detached 3440x1440 viewport"):
		_finish_local()
		return
	if not _require(_local_precision.bind((self as Node3D).get_world_3d()), "native V2 contact precision"):
		_finish_local()
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var fixture := Node3D.new()
	fixture.name = "NativeNookFixture"
	add_child(fixture)
	var adapter := OrisonV2AnchorAdapter.new(fixture)
	if not _require(LocalNook.mount(adapter), "actual native nook mounts"):
		_finish_local()
		return
	var owner := adapter.resolve("nook_books_library") as Node3D
	var count := 0
	for collection: Node in fixture.find_children("*_library", "Node3D", true, false):
		count += (collection.get("_books") as Dictionary).size()
	if not _require(owner != null and count == 61, "all 61 native copies present"):
		_finish_local()
		return
	var installed_owner := Transform3D(Basis(Vector3.UP, PI), LocalStance.OWNER_ORIGIN)
	fixture.global_transform = installed_owner * owner.global_transform.affine_inverse() * fixture.global_transform
	var eye: Transform3D = str_to_var(LocalStance.RECORDED_EYE)
	var foot := eye.origin - Vector3.UP * PlayerController.STANDING_EYE
	var floor_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LocalNook.PATH))
	var floor_body := StaticBody3D.new()
	floor_body.name = "FixtureStandingFloor"
	add_child(floor_body)
	var slab := BoxShape3D.new()
	slab.size = Vector3(.8, .10, .8)
	var support := CollisionShape3D.new()
	support.shape = slab
	floor_body.add_child(support)
	floor_body.global_position = Vector3(foot.x, float(floor_data.floor_y) - slab.size.y * .5, foot.z)
	player = PlayerController.new()
	player.name = "StancePlayer"
	add_child(player)
	player.global_transform = Transform3D(Basis(Vector3.UP, atan2(.792624, .609711)), foot)
	player.camera.global_transform = eye
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	viewport.notify_mouse_entered()

	# Same native carrier and thermal setup used by the input-phase probe.
	var carrier := LocalCarrier.new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	if not _require(carrier.world_ready and carrier.device.teletype.torch_lens != null, "native carrier and aperture ready"):
		_finish_local()
		return
	var thermal := LocalThermal.new()
	add_child(thermal)
	if not _require(thermal.setup(player), "original thermal driver binds"):
		_finish_local()
		return
	for tick in 12:
		await get_tree().physics_frame
	var eye_error := player.camera.global_position.distance_to(eye.origin)
	_local_report.fixture = {"native_copies": count, "owner": _identity(owner),
		"owner_transform": var_to_str(owner.global_transform), "eye_error_m": eye_error,
		"player": _identity(player), "player_transform": var_to_str(player.global_transform),
		"camera_transform": var_to_str(player.camera.global_transform), "capsule_radius_m": player._capsule.radius,
		"capsule_height_m": player._capsule.height, "carrier": _identity(carrier)}
	if not _require(player.is_on_floor() and player.is_physics_processing() and not player._shape.disabled
			and player.collision_layer == 1 and player.collision_mask != 0 and eye_error < .003,
			"full player capsule and original standing eye"):
		_finish_local()
		return
	var source_hashes := _optics_sources()
	var candidates := CandidateView.new()
	for book: Node3D in owner._books.values():
		var row := _candidate(book)
		_local_report.selection.append(row)
		if row.available:
			candidates._books[book.stock_id] = book
	var stack_pair := false
	var volume32_unavailable := false
	for row: Dictionary in _local_report.selection:
		if row.stock_id == "nook_books__Volume32":
			volume32_unavailable = row.stage == "lift" and not row.available
		if row.stock_id != "nook_books__Volume17":
			continue
		var blocker: Dictionary = row.get("blocker", {})
		stack_pair = row.stage == "lift" and str(blocker.get("collider", {}).get("path", "")).ends_with("/nook_books__Volume32")
	_local_report.volume17_expected_stack_blocker = stack_pair
	var stack_control := _require(stack_pair, "Volume17 lift is unavailable under actual Volume32")
	stack_control = _require(volume32_unavailable, "Volume32 is also blocked at lift in the native stack") and stack_control
	if stack_control:
		await _two_style_run(candidates)
	candidates.free()
	two_style_controls.scope = "Nearby native nook, full player capsule and native carrier. Selection queries precede original actual ray, primary, withdrawal, hinge and Space controls."
	_require(_optics_sources() == source_hashes, "original observer and owner source hashes stayed fixed")
	_local_report.optics_sources_sha256 = source_hashes
	_finish_local()

func _candidate(book: Node3D) -> Dictionary:
	var style := str(book.construction.get("opening_style", "hardback"))
	var spine: Vector3 = book.to_global(Vector3(-.001, float(book.construction.height) * .65, 0))
	var eye: Vector3 = player.camera.global_position
	var row := {"stock_id": book.stock_id, "style": style, "title_id": book.title_id,
		"distance_m": eye.distance_to(spine), "book": _identity(book), "pose": var_to_str(book.global_transform),
		"available": false, "stage": "closed_placed_and_in_reach"}
	if style not in ["hardback", "paperback", "pamphlet"] or book.shelf_slot < 0 			or not is_zero_approx(book.opening) or row.distance_m > 2.1:
		return row
	var pose := book.global_transform
	var lift_hit := _sweep(book, pose, LIFT)
	if not lift_hit.is_empty():
		row.stage = "lift"
		row.blocker = lift_hit
		return row
	pose.origin += LIFT
	var withdrawal: Vector3 = book.shelf.pickup_withdrawal_for(book)
	var exit_hit := _sweep(book, pose, withdrawal)
	if not exit_hit.is_empty():
		row.stage = "withdrawal"
		row.blocker = exit_hit
		return row
	var query := PhysicsRayQueryParameters3D.create(eye, eye + (spine - eye).normalized() * 2.1)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()] # The original player ray owns this same exclusion.
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	row.stage = "spine_visibility"
	row.spine_ray = _hit_record(hit, book, spine)
	row.spine_provider = _first_spine_provider(hit, book)
	row.available = row.spine_provider.available
	return row

func _first_spine_provider(hit: Dictionary, book: Node3D) -> Dictionary:
	var result := {"available": false, "status": "no_hit"}
	if hit.is_empty():
		return result
	var provider := hit.get("collider") as Node
	while provider != null and not provider.has_method("manipulation_target"):
		provider = provider.get_parent()
	if provider == null:
		result.status = "first_hit_has_no_provider"
		return result
	result.provider = _identity(provider)
	var descriptor: Dictionary = provider.call("manipulation_target", hit)
	if descriptor.get("legacy", false):
		result.status = "first_provider_is_legacy"
		return result
	if descriptor.is_empty():
		result.status = "first_provider_returned_empty"
		return result
	var part := descriptor.get("part") as Node
	result.part = _identity(part)
	result.owner = _identity(descriptor.get("owner") as Node)
	result.frame = _identity(descriptor.get("frame") as Node)
	result.kind = str(descriptor.get("kind", ""))
	result.blocked = bool(descriptor.get("blocked", false))
	result.available = not result.blocked and part == book and result.kind == "free"
	result.status = "expected_free_book" if result.available else "first_provider_did_not_offer_expected_free_book"
	return result

func _sweep(book: Node3D, pose: Transform3D, motion: Vector3) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	for solid: CollisionShape3D in book._solids:
		if solid.disabled:
			continue
		var query: PhysicsShapeQueryParameters3D = book._shape_query(solid, pose)
		query.exclude = [book.get_rid()] # Shape query self only. No physical exceptions.
		query.margin = NATIVE_MARGIN
		var start := query.transform
		var rest := space.get_rest_info(query)
		if not rest.is_empty() and motion.dot(rest.normal) < -.0000001:
			return _query_contact(rest, solid, "resting contact into proposed motion")
		query.motion = motion
		var fractions := space.cast_motion(query)
		query.motion = Vector3.ZERO
		if fractions[0] < 1.:
			for depth: float in [.00005, .0002, .0005, .001]:
				query.transform = start.translated(motion * fractions[1] + motion.normalized() * depth)
				var contact := space.get_rest_info(query)
				if not contact.is_empty():
					return _query_contact(contact, solid, "first swept contact")
			return {"kind": "unresolved swept contact", "shape": str(solid.get_path()),
				"safe": fractions[0], "unsafe": fractions[1]}
		query.transform = start.translated(motion)
		var overlaps := space.intersect_shape(query, 1)
		if not overlaps.is_empty():
			var endpoint: Dictionary = overlaps[0]
			var endpoint_rest := space.get_rest_info(query)
			if endpoint_rest.get("collider_id", -1) == endpoint.get("collider_id", 0):
				endpoint.merge(endpoint_rest, true)
			return _query_contact(endpoint, solid, "endpoint overlap")
	return {}

func _query_contact(hit: Dictionary, solid: CollisionShape3D, kind: String) -> Dictionary:
	var node := instance_from_id(int(hit.get("collider_id", 0))) as Node
	return {"kind": kind, "collider": _identity(node), "rid": str(hit.get("rid", RID())),
		"shape_index": hit.get("shape", -1), "stock_shape": str(solid.get_path()),
		"point": var_to_str(hit.get("point")), "normal": var_to_str(hit.get("normal"))}

func _require(ok: bool, label: String) -> bool:
	if is_instance_valid(player) and (label.begins_with("first real spine ray") or label.begins_with("actual physical ")):
		var hit: Dictionary = player._grab.last_hit
		_local_report.actual_input_rays.append({"label": label, "accepted": ok,
			"collider": _identity(hit.get("collider") as Node), "rid": str(hit.get("rid", RID())),
			"shape": hit.get("shape"), "point": var_to_str(hit.get("position")), "normal": var_to_str(hit.get("normal"))})
	return super._require(ok, label)

func _hit_record(hit: Dictionary, book: Node3D, sample_at: Vector3) -> Dictionary:
	var row := super._hit_record(hit, book, sample_at)
	row.rid = str(hit.get("rid", RID()))
	row.face_index = hit.get("face_index")
	return row

func _two_style_capture(phase: String, book: Node3D) -> bool:
	if not await super._two_style_capture(phase, book):
		return false
	var draws: Array[Dictionary] = []
	for draw: MeshInstance3D in book.find_children("*", "MeshInstance3D", true, false):
		if not draw.is_visible_in_tree() or draw.mesh == null:
			continue
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_active_material(surface) as StandardMaterial3D
			if material != null:
				draws.append({"draw": _identity(draw), "surface": surface,
					"shading_mode": material.shading_mode, "normal_enabled": material.normal_enabled,
					"albedo": _mip(material.albedo_texture), "normal": _mip(material.normal_texture),
					"roughness": _mip(material.roughness_texture)})
	two_style_controls.frames[-1].native_loaded_material_mips = draws
	return true

func _mip(texture: Texture2D) -> Dictionary:
	if texture == null:
		return {}
	var identity := texture.get_instance_id()
	if not _mip_cache.has(identity):
		var image := texture.get_image()
		_mip_cache[identity] = {"texture": texture.resource_path, "instance_id": identity,
			"size": [texture.get_width(), texture.get_height()],
			"loaded_mip_count": image.get_mipmap_count() if image != null else null}
	return _mip_cache[identity]

func _finish_local() -> void:
	_local_report.two_style = two_style_controls
	_local_report.failures = failures
	var file := FileAccess.open(_local_output.path_join("local_two_style.json"), FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(_local_report, "\t")):
		push_error("Local two-style report write failed")
		get_tree().quit(2)
		return
	file.close()
	var passed: bool = failures.is_empty() and two_style_controls.completed
	if is_instance_valid(player):
		player.cancel_manipulation()
	print("LOCAL TWO-STYLE: ", "PASS" if passed else "FAIL", " frames=", two_style_controls.frames.size())
	get_tree().quit(0 if passed else 1)
