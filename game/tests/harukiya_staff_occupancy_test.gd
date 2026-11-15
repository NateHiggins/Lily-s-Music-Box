extends Node3D
## Nearby actual bar/counter/cast pilot. Timetable and wardrobe are production
## owners; the rest of RuntimeRoot is intentionally unmounted and uncomposed.
const CastOwner := preload("res://scripts/characters/harukiya_cast.gd")
const CounterSource := preload("res://scripts/props/harukiya_counter_glass.gd")
const StandingReader := preload("res://scripts/characters/standing_occupancy.gd")
const PROFILES := "res://data/characters/harukiya_staff_standing_columns.json"
const PEOPLE := ["stacy", "lily"]
const FLOOR_CONTACT_TOLERANCE := .002
const REQUIRED := ["staff_same_actors_both_families", "staff_shift_group_lifecycle",
	"staff_unknown_outfit_refusal", "staff_native_column_clearance", "staff_preview_source_cleanup"]
var runtime: OrisonV2RuntimeRoot
var bar: OrisonV2BarRegion
var counter: Node3D
var cast: Node3D
var conversations: ResidentConversations
var panel: CaseDialoguePanel
var timetable: ScheduleDirector
var clock := CampaignClock.new()
var profiles: Dictionary = {}
var actor_ids: Dictionary = {}
var family_seen: Dictionary = {}
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details := {"scenarios": [], "native": [], "captures": []}
var output := ""
var started := 0
var lease := false
var prior_data: Dictionary
var prior_text := ""
var prior_mode := 0
var prior_mouse := Input.MOUSE_MODE_VISIBLE
var prior_frozen := false
var prior_files: Dictionary = {}
var initial_inputs: Dictionary = {}
var logger: Logger

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
		print("HARUKIYA STAFF OCCUPANCY FAIL: ", label)
	return ok

func _run() -> void:
	started = Time.get_ticks_msec()
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		get_tree().quit(2); return
	if FileAccess.file_exists(output.path_join("runtime_contract.json")):
		push_error("Staff occupancy refuses an existing receipt destination"); get_tree().quit(2); return
	for identity: String in REQUIRED: contracts[identity] = {"executed": false, "status": "NOT_RUN"}
	prior_data = RealityState.data
	prior_text = JSON.stringify(prior_data, "", true, true)
	prior_files = _save_files()
	prior_mode = GameBoot.launch_mode
	prior_mouse = Input.mouse_mode
	prior_frozen = CampaignTime._frozen_for_tests
	logger = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(logger)
	initial_inputs = _inputs()
	var profile := OS.get_environment("STAFF_OCCUPANCY_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	var live := OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	var user_dir := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not _check(profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/staff_occupancy_native_")
		and live == profile and user_dir == profile.path_join("PleaseRemainOnTheLine"), "dedicated native-pilot APPDATA applied before autoload startup"):
		await _finish(); return
	if not _check(DisplayServer.get_name() != "headless", "rendered nearby staff pilot"):
		await _finish(); return
	for key: String in ["SCHEDULE", "SCHEDULE_DAY", "SCHEDULE_DOY", "SCHEDULE_MINUTE", "SCHEDULE_FIRST_SAT", "AGENDA", "CAMPAIGN_TIME_FREEZE"]:
		_check(OS.get_environment(key).is_empty(), "no timetable or campaign override " + key)
	if not failures.is_empty(): await _finish(); return
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease, "exclusive nonpersistent staff pilot preview"): await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	CampaignTime.set_frozen_for_tests(true)
	if not _check(clock.configure_date(1929, 6, 13, 1200), "authored Thursday20:00 work context"): await _finish(); return
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
	if not _check(document is Dictionary, "installed source-bound standing profile document exists"): await _finish(); return
	profiles = document
	bar = OrisonV2BarRegion.new(); bar.name = "ProductionHarukiya"; add_child(bar)
	if not _check(not bar.startup_failed, "original nearby bar mounts its native geometry and owners"): await _finish(); return
	timetable = ScheduleDirector.new(); add_child(timetable); timetable.setup(null, bar.source_layout)
	if not _check(not timetable.data.is_empty(), "actual original resident/staff timetable loads"): await _finish(); return
	# Use the production resolver method itself. This RuntimeRoot stays outside
	# the tree, so no substitute agenda or full-world geometry is constructed.
	runtime = OrisonV2RuntimeRoot.new()
	runtime.campaign_clock = clock
	runtime.resident_presence = timetable
	panel = CaseDialoguePanel.new(); add_child(panel)
	conversations = ResidentConversations.new(); add_child(conversations); conversations.setup(panel)
	counter = CounterSource.new(); counter.name = "HarukiyaCounterGlass"
	if not _check(counter.configure(runtime, bar, conversations), "ordinary counter configure mounts original two-person cast"): await _finish(); return
	cast = counter.get("cast") as Node3D
	if not _check(is_instance_valid(cast) and bool(cast.get("ready_ok")), "installed staff cast ready"): await _finish(); return
	var actors: Dictionary = cast.get("actors")
	if not _check(actors.size() == 2 and actors.has("lily") and actors.has("stacy"), "exact two original staff presentations"): await _finish(); return
	for identity: String in PEOPLE:
		var actor: Node3D = actors[identity]
		actor_ids[identity] = actor.get_instance_id()
		_check(actor.get_script().resource_path == "res://scripts/characters/harukiya_staff_body.gd", "production owner uses measured actor subclass " + identity)
		family_seen[identity] = []
	_setup_light_camera(actors)
	await get_tree().physics_frame; await get_tree().physics_frame
	var native_before := failures.size()
	await _family_case("work", 1929, 6, 13)
	await _family_case("occasion", 1929, 7, 4)
	_contract("staff_native_column_clearance", failures.size() == native_before)
	var family_ok := true
	for identity: String in PEOPLE:
		family_ok = family_ok and family_seen[identity].has("work") and family_seen[identity].has("occasion")
	_contract("staff_same_actors_both_families", _check(family_ok, "both actual actors witnessed in both measured wardrobe families"))
	await _shift_cycle()
	_unknown_outfit()
	await _finish()

func _setup_light_camera(actors: Dictionary) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.035, .04, .05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7, .72, .76)
	environment.environment.ambient_light_energy = .18
	add_child(environment)
	var rig := LightRig.new(); add_child(rig)
	var camera := Camera3D.new(); add_child(camera); camera.make_current()
	var stacy: Node3D = actors.stacy
	var lily: Node3D = actors.lily
	var middle := (stacy.global_position + lily.global_position) * .5 + Vector3.UP * 1.0
	var across: Vector3 = counter.call("across")
	camera.global_position = middle - across * 3.2 + Vector3.UP * .4
	camera.look_at(middle)

func _contract(identity: String, ok: bool) -> void:
	contracts[identity] = {"executed": true, "status": "PASS" if ok else "FAIL"}

func _same_parts(left: Array, right: Array) -> bool:
	var a: Array = left.duplicate(); var b: Array = right.duplicate()
	a.sort(); b.sort()
	return a == b

func _matched_profile(identity: String, actor: Node3D) -> Dictionary:
	var parts: Array = actor.call("worn_parts")
	for row: Dictionary in profiles.get("profiles", []):
		if str(row.person) == identity and _same_parts(parts, row.parts): return row
	return {}

func _family_case(family: String, year: int, month: int, day: int) -> void:
	if not _check(clock.configure_date(year, month, day, 1200), "preview clock selects authored " + family + " evening"): return
	var date := "%04d-%02d-%02d" % [year, month, day]
	if not _check(conversations.today() == date and conversations.minute_now() == 1200,
		"actual conversation owner reads the selected saved preview campaign clock"): return
	cast.call("refresh_presence")
	await get_tree().physics_frame; await get_tree().physics_frame
	var actors: Dictionary = cast.get("actors")
	var scenario := {"family": family, "date": clock.local_datetime(), "columns": {}}
	for identity: String in PEOPLE:
		var actor: Node3D = actors[identity]
		_check(actor.get_instance_id() == int(actor_ids[identity]) and actor.is_visible_in_tree()
			and actor.is_in_group("animated_residents"), "same active original measured staff actor " + identity + "/" + family)
		var row := _matched_profile(identity, actor)
		var situation: Dictionary = CastOwner.evening_situation(identity, conversations.today(), conversations.minute_now())
		var selected: String = cast.get("_rules").choose(identity, situation)
		if not _check(not row.is_empty() and selected == family, "production evening rules select measured family " + identity + "/" + family): continue
		var column: Dictionary = StandingReader.read(actor)
		if not _check(not column.is_empty() and not bool(column.get("invalid", false)), "shared reader obtains valid actual staff column " + identity): continue
		var source_base: Array = row.base_local
		var expected: Vector3 = actor.global_transform * Vector3(float(source_base[0]), float(source_base[1]), float(source_base[2]))
		var base: Vector3 = column.base
		_check(base.is_equal_approx(expected) and is_equal_approx(float(column.radius), float(row.radius))
			and is_equal_approx(float(column.height), float(row.height)), "live column equals bound measured family and actual actor transform " + identity)
		_check(actor.call("standing_occupancy") == column, "shared reader preserves original producer values " + identity)
		family_seen[identity].append(family)
		scenario.columns[identity] = column.duplicate(true)
		_native_column(identity, family, column)
	if scenario.columns.size() == 2:
		var a: Dictionary = scenario.columns.stacy
		var b: Dictionary = scenario.columns.lily
		var a_base: Vector3 = a.base; var b_base: Vector3 = b.base
		var vertical := a_base.y < b_base.y + float(b.height) and b_base.y < a_base.y + float(a.height)
		_check(not vertical or Vector2(a_base.x - b_base.x, a_base.z - b_base.z).length() >= float(a.radius) + float(b.radius),
			"actual two staff measured standing columns remain separate " + family)
	details.scenarios.append(scenario)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path := output.path_join("staff_" + family + ".png")
	if _check(image != null and not image.is_empty() and image.save_png(path) == OK, "actual nearby staff family capture " + family):
		details.captures.append({"path": path, "sha256": FileAccess.get_sha256(path), "size": image.get_size()})

func _native_column(identity: String, family: String, column: Dictionary) -> void:
	var base: Vector3 = column.base
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(base + Vector3.UP * .08, base - Vector3.UP * .08, 1)
	var support := space.intersect_ray(ray)
	var witness := {"person": identity, "family": family, "column": column, "support": {}, "hits": []}
	if not _check(not support.is_empty() and absf(support.position.y - base.y) < .03, "actual nearby native floor supports measured column " + identity + "/" + family):
		details.native.append(witness); return
	var support_floor: Vector3 = support.position
	witness.support = {"path": str(support.collider.get_path()), "shape": int(support.shape), "at": support_floor}
	_check(absf(support_floor.y - base.y) <= FLOOR_CONTACT_TOLERANCE,
		"measured base differs from actual support by at most2mm " + identity + "/" + family)
	var shape := CylinderShape3D.new()
	shape.radius = float(column.radius)
	shape.height = float(column.height)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0.0
	query.collision_mask = 1
	query.transform.origin = base + Vector3.UP * shape.height * .5
	var hits := space.intersect_shape(query, 64)
	_check(hits.size() < 64, "native column overlap result is not truncated " + identity)
	for hit: Dictionary in hits:
		witness.hits.append(_native_hit(hit))
	# Preserve every full-column hit, then prove which contact slab contains it.
	# The second query changes only its lower end. No collider is excluded.
	var top := base.y + float(column.height)
	var upper_bottom := support_floor.y + FLOOR_CONTACT_TOLERANCE
	if not _check(top > upper_bottom, "measured column has a positive above-support interval " + identity):
		details.native.append(witness); return
	var upper_shape := CylinderShape3D.new()
	upper_shape.radius = shape.radius
	upper_shape.height = top - upper_bottom
	var upper_query := PhysicsShapeQueryParameters3D.new()
	upper_query.shape = upper_shape
	upper_query.margin = 0.0
	upper_query.collision_mask = 1
	upper_query.transform.origin = Vector3(base.x, (upper_bottom + top) * .5, base.z)
	var upper_hits := space.intersect_shape(upper_query, 64)
	var upper_records: Array[Dictionary] = []
	for hit: Dictionary in upper_hits:
		upper_records.append(_native_hit(hit))
	witness.upper_query = {"base": Vector3(base.x, upper_bottom, base.z), "radius": upper_shape.radius,
		"height": upper_shape.height, "original_top": top, "discarded_lower_slab_m": upper_bottom - base.y,
		"floor_contact_tolerance_m": FLOOR_CONTACT_TOLERANCE, "hits": upper_records, "excluded_colliders": 0}
	_check(upper_hits.is_empty(), "sameXZ/radius/top measured column clears actual native world above proven floor+2mm " + identity + "/" + family)
	if not upper_hits.is_empty(): witness.localization_only = _localize_column(identity, column, support_floor)
	witness.counter_negative = _counter_negative(column, support_floor.y)
	var door := bar.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if _check(door != null, "actual native entry door available for standing-query pilot"):
		var revision := door.motion_revision
		var angle: float = door.get("_body").rotation.y
		var clear := door.standing_position_clear(base, float(column.radius), float(column.height))
		witness.door = {"standing_open_sweep_clear": clear, "motion_revision": revision}
		_check(clear and door.motion_revision == revision and is_equal_approx(float(door.get("_body").rotation.y), angle),
			"native entry standing query clears actual staff location without operating leaf " + identity)
	details.native.append(witness)

func _native_hit(hit: Dictionary) -> Dictionary:
	var result := {"path": str(hit.collider.get_path()), "shape": int(hit.shape), "shape_class": "", "actual_shape_bounds": AABB()}
	var body := hit.collider as CollisionObject3D
	if body == null: return result
	var shape_owner := body.shape_find_owner(int(hit.shape))
	var collision := body.shape_owner_get_owner(shape_owner) as CollisionShape3D
	if collision == null or collision.shape == null: return result
	result.shape_class = collision.shape.get_class()
	result.actual_shape_owner = str(collision.get_path())
	var debug_mesh: ArrayMesh = collision.shape.get_debug_mesh()
	if debug_mesh != null: result.actual_shape_bounds = collision.global_transform * debug_mesh.get_aabb()
	return result

func _column_query(base: Vector3, top: float, radius: float) -> Array[Dictionary]:
	var shape := CylinderShape3D.new()
	shape.radius = radius; shape.height = top - base.y
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.margin = 0.0; query.collision_mask = 1
	query.transform.origin = Vector3(base.x, (base.y + top) * .5, base.z)
	return get_world_3d().direct_space_state.intersect_shape(query, 64)

func _localize_column(identity: String, column: Dictionary, support_floor: Vector3) -> Dictionary:
	var base: Vector3 = column.base
	var radius := float(column.radius)
	var top := base.y + float(column.height)
	var report := {"scope": "localization only; does not change original failure or actor placement",
		"original_column": column.duplicate(true), "crop_ladder": [], "candidate_search": {}}
	for crop: float in [.002, .01, .05, .25, .75]:
		var bottom := support_floor.y + crop
		var hits := _column_query(Vector3(base.x, bottom, base.z), top, radius)
		var rows: Array[Dictionary] = []
		for hit: Dictionary in hits: rows.append({"path": str(hit.collider.get_path()), "shape": int(hit.shape)})
		report.crop_ladder.append({"floor_offset_m": crop, "base": Vector3(base.x, bottom, base.z),
			"unchanged_original_top": top, "radius": radius, "hits": rows, "truncated": hits.size() >= 64})
	report.candidate_search = _clear_candidates(identity, column, support_floor)
	return report

func _clear_candidates(identity: String, column: Dictionary, support_floor: Vector3) -> Dictionary:
	var base: Vector3 = column.base
	var radius := float(column.radius)
	var top := base.y + float(column.height)
	var limit := 1.2 if identity == "stacy" else .8
	var steps := 12 if identity == "stacy" else 8
	var offsets: Array[Vector2] = []
	for x: int in range(-steps, steps + 1):
		for z: int in range(-steps, steps + 1):
			var offset := Vector2(x, z) * .1
			if offset.length() <= limit + .000001: offsets.append(offset)
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	var other := "lily" if identity == "stacy" else "stacy"
	var actors: Dictionary = cast.get("actors")
	var peer: Dictionary = StandingReader.read(actors[other])
	var result := {"step_m": .1, "limit_m": limit, "same_original_world_base_top_height": true,
		"support_level_tolerance_m": FLOOR_CONTACT_TOLERANCE, "best": [], "tested": 0,
		"behind_counter_rejected": 0, "support_rejected": 0, "native_rejected": 0,
		"peer_rejected": 0, "door_rejected": 0, "original_actor_positions_unchanged": true}
	if peer.is_empty() or bool(peer.get("invalid", false)):
		result.skipped_reason = "other actual measured staff column unavailable"; return result
	var peer_base: Vector3 = peer.base
	var across: Vector3 = counter.call("across")
	var door := bar.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if door == null: result.skipped_reason = "actual entry door unavailable"; return result
	var space := get_world_3d().direct_space_state
	for offset: Vector2 in offsets:
		var candidate := base + Vector3(offset.x, 0, offset.y)
		result.tested += 1
		var side := across.dot(candidate - counter.global_position)
		if identity == "stacy" and side <= 0.0:
			result.behind_counter_rejected += 1; continue
		var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * .08, candidate - Vector3.UP * .08, 1)
		var support := space.intersect_ray(ray)
		if support.is_empty() or absf(support.position.y - support_floor.y) > FLOOR_CONTACT_TOLERANCE \
				or absf(support.position.y - candidate.y) > FLOOR_CONTACT_TOLERANCE:
			result.support_rejected += 1; continue
		var floor_at: Vector3 = support.position
		var query_base := Vector3(candidate.x, floor_at.y + FLOOR_CONTACT_TOLERANCE, candidate.z)
		if not _column_query(query_base, top, radius).is_empty():
			result.native_rejected += 1; continue
		var vertical := candidate.y < peer_base.y + float(peer.height) and peer_base.y < candidate.y + float(column.height)
		var peer_gap := Vector2(candidate.x - peer_base.x, candidate.z - peer_base.z).length()
		if vertical and peer_gap < radius + float(peer.radius):
			result.peer_rejected += 1; continue
		if not door.standing_position_clear(candidate, radius, float(column.height)):
			result.door_rejected += 1; continue
		result.best.append({"base": candidate, "bar_local_base": bar.to_local(candidate), "offset_xz": offset,
			"distance_m": offset.length(), "radius": radius, "height": float(column.height), "original_top": top,
			"support": {"at": floor_at, "path": str(support.collider.get_path()), "shape": int(support.shape)},
			"upper_query_base": query_base, "entry_arc_clear": true, "other_actual_staff_gap_m": peer_gap,
			"behind_counter_projection_m": side})
		if result.best.size() == 8: break
	return result

func _counter_negative(column: Dictionary, floor_y: float) -> Dictionary:
	var source: Dictionary = {}
	for floor: Dictionary in bar.source_layout.floors:
		if str(floor.id) != "F01": continue
		for row: Dictionary in floor.furniture:
			if str(row.id) == "retail_bar_counter_top": source = row
	if not _check(not source.is_empty(), "negative control retains authored original counter-top datum"): return {}
	var rect: Array = source.rect
	var target: Vector3 = bar.to_global(GameBoot.b2g([(float(rect[0]) + float(rect[2])) * .5,
		(float(rect[1]) + float(rect[3])) * .5, float(source.z0) + float(source.h)]))
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(target + Vector3.UP * .08, target - Vector3.UP * .08, 1)
	var counter_hit := space.intersect_ray(ray)
	if not _check(not counter_hit.is_empty() and absf(counter_hit.position.y - target.y) < .002
		and counter_hit.position.y > floor_y + .2, "negative control ray identifies actual native counter-top at original datum"): return {}
	var original_base: Vector3 = column.base
	var top := original_base.y + float(column.height)
	var bottom := floor_y + FLOOR_CONTACT_TOLERANCE
	var shape := CylinderShape3D.new()
	shape.radius = float(column.radius)
	shape.height = top - bottom
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.margin = 0.0; query.collision_mask = 1
	query.transform.origin = Vector3(target.x, (bottom + top) * .5, target.z)
	var hits := space.intersect_shape(query, 64)
	var records: Array[Dictionary] = []
	var found := false
	for hit: Dictionary in hits:
		records.append({"path": str(hit.collider.get_path()), "shape": int(hit.shape)})
		if hit.collider == counter_hit.collider and int(hit.shape) == int(counter_hit.shape): found = true
	_check(hits.size() < 64 and found, "same measured radius/top upper-query detects actual counter obstruction negative control")
	return {"source": source, "actual_counter_top": counter_hit.position,
		"counter_path": str(counter_hit.collider.get_path()), "counter_shape": int(counter_hit.shape),
		"query_base": Vector3(target.x, bottom, target.z), "radius": shape.radius, "height": shape.height,
		"actual_counter_detected": found, "hits": records, "actor_transforms_changed": false}

func _shift_cycle() -> void:
	var before := failures.size()
	_check(clock.configure_date(1929, 6, 17, 1200), "original Monday evening timetable context")
	cast.call("refresh_presence")
	await get_tree().physics_frame
	var actors: Dictionary = cast.get("actors")
	for identity: String in PEOPLE:
		var actor: Node3D = actors[identity]
		_check(actor.get_instance_id() == int(actor_ids[identity]) and not actor.is_visible_in_tree()
			and not actor.is_in_group("animated_residents") and not actor.is_processing(), "offshift removes actual standing occupancy without replacing actor " + identity)
		_check((actor.call("standing_occupancy") as Dictionary).is_empty() and bool(StandingReader.read(actor).get("invalid", false)),
			"offshift producer is absent and shared reader refuses inactive measured actor " + identity)
	_check(clock.configure_date(1929, 6, 13, 1200), "original Thursday evening timetable reactivation")
	cast.call("refresh_presence")
	await get_tree().physics_frame
	for identity: String in PEOPLE:
		var actor: Node3D = actors[identity]
		var column: Dictionary = StandingReader.read(actor)
		_check(actor.get_instance_id() == int(actor_ids[identity]) and actor.is_visible_in_tree()
			and actor.is_in_group("animated_residents") and not column.is_empty() and not bool(column.get("invalid", false)), "shift return restores same actor and measured body " + identity)
	_contract("staff_shift_group_lifecycle", failures.size() == before)

func _unknown_outfit() -> void:
	var before := failures.size()
	var actors: Dictionary = cast.get("actors")
	for identity: String in PEOPLE:
		var actor: Node3D = actors[identity]
		var parts: Array = actor.call("worn_parts")
		var column: Dictionary = StandingReader.read(actor)
		var transform := actor.global_transform
		var accepted: bool = actor.call("wear", ["__unmeasured_staff_probe__"])
		_check(not accepted and actor.call("worn_parts") == parts and StandingReader.read(actor) == column
			and actor.global_transform == transform and actor.get_instance_id() == int(actor_ids[identity])
			and not str(actor.get("last_refusal")).is_empty(), "unknown outfit refuses atomically without changing measured actor " + identity)
		actor.scale = Vector3(1.01,1,1)
		_check(bool(StandingReader.read(actor).get("invalid",false)) and actor.is_in_group("animated_residents"), "unsupported scale stays discoverable and refuses measured clearance " + identity)
		actor.global_transform = transform
		_check(StandingReader.read(actor) == column, "restoring actual unit transform restores original measured occupancy " + identity)
	var legacy := Node3D.new(); add_child(legacy)
	_check(StandingReader.read(legacy).is_empty(), "legacy body without accessor retains original reader contract")
	legacy.free()
	_contract("staff_unknown_outfit_refusal", failures.size() == before)

func _save_files() -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".txn", ".tmp"]:
		var path: String = RealityState.save_path + suffix
		result[suffix] = {"exists": FileAccess.file_exists(path), "sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return result

func _inputs() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime_digest: Array = []; var physical: Array = []
	_check(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], runtime_digest) == 0, "bound staff pilot runtime inputs")
	_check(OS.execute("python", [root.path_join("tools/v2_physical_inputs.py"), "--root", root], physical) == 0, "bound staff pilot physical inputs")
	var dependencies := {}
	for path: String in [get_script().resource_path, scene_file_path, "res://tests/guide_bell_error_capture.gd"]:
		dependencies["game/" + path.trim_prefix("res://")] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return {"runtime_inputs_sha256": str(runtime_digest[0]).strip_edges() if not runtime_digest.is_empty() else "",
		"physical_inputs_sha256": str(physical[0]).strip_edges() if not physical.is_empty() else "", "test_dependencies": dependencies}

func _finish() -> void:
	var before := failures.size()
	if is_instance_valid(bar): bar.shutdown(); bar.free(); bar = null
	if is_instance_valid(panel): panel.free()
	if is_instance_valid(conversations): conversations.free()
	if is_instance_valid(runtime): runtime.free()
	if is_instance_valid(timetable): timetable.free()
	await get_tree().process_frame
	if lease:
		_check(RealityState.end_preview_campaign(self), "original preview ownership returned")
		lease = false
	GameBoot.launch_mode = prior_mode
	Input.mouse_mode = prior_mouse
	CampaignTime.set_frozen_for_tests(prior_frozen)
	_check(is_same(RealityState.data, prior_data) and JSON.stringify(RealityState.data, "", true, true) == prior_text,
		"original campaign reference and content restored")
	_check(_save_files() == prior_files, "actual isolated save backup/transaction bytes preserved")
	_check(_inputs() == initial_inputs, "runtime physical and test inputs remain frozen")
	var errors: Array = logger.get("errors")
	OS.remove_logger(logger)
	_check(errors.is_empty(), "native staff pilot has no unexpected engine errors")
	_contract("staff_preview_source_cleanup", failures.size() == before)
	for identity: String in REQUIRED:
		if failures.is_empty(): _check(bool(contracts[identity].executed) and str(contracts[identity].status) == "PASS", "required staff pilot contract " + identity)
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": true, "selector": "v2",
		"suite": "HarukiyaStaffOccupancyTest", "status": "PASS" if passed else "FAIL",
		"scope": "Nearby production Harukiya geometry, original counter/cast and production timetable resolver; same2staff measured columns in work/occasion, real Monday removal/Thursday reactivation, unknown-outfit refusal. Full-cylinder native hits retained; secondary sameXZ/radius/top query removes only lower interval through actual supportfloor+2mm and keeps every collider. Real native counter-top obstruction negative control. RuntimeRoot resolver remains unmounted; no full crowd/player service, actor movement, door-operation negative, mesh/cloth/unsampled-pose/export, cost, gameplay or artistic acceptance.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": initial_inputs, "contracts": contracts, "checks": checks, "failures": failures, "engine_errors": errors, "details": details}
	result.source.test_path = "game/" + get_script().resource_path.trim_prefix("res://")
	result.source.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
	result.source.test_scene_path = "game/" + scene_file_path.trim_prefix("res://")
	result.source.test_scene_sha256 = FileAccess.get_sha256(scene_file_path)
	var file := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK
	file.close()
	get_tree().quit(0 if passed and written else 1)
