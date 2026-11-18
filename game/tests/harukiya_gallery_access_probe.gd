extends Node3D
## Nearby contact diagnostic. Original coarse motor and actual controller run
## unchanged. Intermediate flat-endpoint failures are recorded, never waived.
const Routes := preload("res://tests/harukiya_destination_routes.gd")
const CollisionPolicy := preload("res://tests/orison_v2_first_slice_contract_test.gd")
const PlayerSupport := preload("res://tests/harukiya_player_support.gd")

class DirectionalMotor extends "res://tests/harukiya_mass_return_test.gd":
	func _ready() -> void:
		watching = false # Suppress the original full18 programme only.

class ObservedPlayer extends PlayerController:
	var goal_label := "initial"
	var resolved: Array[Dictionary] = []
	var lifts: Array[Dictionary] = []
	func _try_step_up(delta: float) -> void:
		var before := global_position
		var grounded := is_on_floor()
		super._try_step_up(delta)
		if global_position != before:
			lifts.append({"frame": Engine.get_physics_frames(), "goal": goal_label,
				"before": before, "after_original_lift": global_position, "previously_on_floor": grounded})
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if resolved.size() < 6000:
			resolved.append({"frame": Engine.get_physics_frames(), "goal": goal_label,
				"feet": global_position, "velocity": velocity, "on_floor": is_on_floor(),
				"floor_normal": get_floor_normal(), "slide_count": get_slide_collision_count()})

var bar: OrisonV2BarRegion
var player: ObservedPlayer
var motor: DirectionalMotor
var runtime: OrisonV2RuntimeRoot
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var legs: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var strict_rejections: Array[Dictionary] = []
var points: Dictionary = {}
var directory := ""
var started := 0
var lease := false
var prior_data: Dictionary
var prior_text := ""
var prior_mode := 0
var prior_mouse := Input.MOUSE_MODE_VISIBLE
var prior_frozen := false
var inputs: Dictionary = {}
var roundtrip := false
var float_controls: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok: failures.append(label); print("GALLERY ACCESS PROBE FAIL: ", label)
	return ok

func _run() -> void:
	started = Time.get_ticks_msec()
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK: get_tree().quit(2); return
	if FileAccess.file_exists(directory.path_join("runtime_contract.json")): get_tree().quit(2); return
	prior_data = RealityState.data; prior_text = JSON.stringify(prior_data, "", true, true)
	prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode; prior_frozen = CampaignTime._frozen_for_tests
	inputs = _inputs()
	var profile := OS.get_environment("GALLERY_ACCESS_ISOLATED_APPDATA").replace("\\", "/").simplify_path()
	if not _check(profile.begins_with("C:/ov/reports/harukiya_overhaul_20261112/gallery_access_")
		and OS.get_environment("APPDATA").replace("\\", "/").simplify_path() == profile
		and OS.get_user_data_dir().replace("\\", "/").simplify_path() == profile.path_join("PleaseRemainOnTheLine"), "dedicated gallery probe APPDATA applied before autoloads"):
		await _finish(); return
	if not _check(DisplayServer.get_name() != "headless", "actual rendered nearby gallery diagnostic"): await _finish(); return
	lease = RealityState.begin_preview_campaign(self)
	if not _check(lease, "exclusive nonpersistent gallery preview"): await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC; CampaignTime.set_frozen_for_tests(true)
	bar = OrisonV2BarRegion.new(); add_child(bar)
	if not _check(not bar.startup_failed, "actual production bar native geometry starts"): await _finish(); return
	var destination: Node3D = bar.destination
	for marker: Node3D in destination.get_node("Navigation").get_children(): points[str(marker.name)] = marker.global_position
	if not _check(points.has("stair_lower") and points.has("gallery_return"), "original lower landing and gallery datums exist"): await _finish(); return
	player = ObservedPlayer.new(); add_child(player); player.set_physics_process(false)
	# Single declared initial placement. XZ offset comes from the original
	# full-service failing leg's supported predecessor, not a corrected stance.
	var start: Vector3 = points.stair_lower + Vector3(-.072717, 0, -.004970)
	var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * .1, start - Vector3.UP * .1, 1)
	ray.exclude = [player.get_rid()]
	var support := get_world_3d().direct_space_state.intersect_ray(ray)
	if not _check(not support.is_empty() and absf(support.position.y - start.y) < .035, "declared original lower-landing predecessor has actual floor support"): await _finish(); return
	player.global_position = support.position
	player.rotation.y = -PI * .5 # Declared initial eastward look, then original motor turns.
	player.enable_low_step_probe(); player.camera.make_current(); player.set_mouse_released(false)
	runtime = OrisonV2RuntimeRoot.new(); runtime.player = player
	motor = DirectionalMotor.new(); motor.world = runtime; add_child(motor)
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.035, .04, .05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7, .72, .76)
	environment.environment.ambient_light_energy = .18; add_child(environment)
	var rig := LightRig.new(); add_child(rig)
	player.set_physics_process(true)
	await RenderingServer.frame_post_draw
	var up: bool = await Routes.walk(bar, "stair_lower", "gallery_return", Callable(self, "_leg"), Callable(self, "_check"))
	if up:
		_check(_snapshot(points.gallery_return).old_strict, "actual full gallery landing retains original strict support/height test")
		_check(bool(PlayerSupport.inspect(bar, player, points.gallery_return).supported), "replacement helper retains actual strict flat gallery support")
		_flat_float_control(points.gallery_return)
		await _capture("gallery_landing")
	if up and failures.is_empty():
		roundtrip = await Routes.walk(bar, "gallery_return", "stair_lower", Callable(self, "_leg"), Callable(self, "_check"))
		if roundtrip:
			_check(_snapshot(points.stair_lower).old_strict, "actual returned lower landing retains original strict support/height test")
			_check(bool(PlayerSupport.inspect(bar, player, points.stair_lower).supported), "replacement helper retains actual strict flat lower-landing support")
			_flat_float_control(points.stair_lower)
	_check(roundtrip, "original directional motor completes native gallery roundtrip")
	await _finish()

func _leg(goal: Vector3) -> bool:
	var label := "unknown"
	for identity: String in points:
		var at: Vector3 = points[identity]
		if at.distance_to(goal) < .00001: label = identity; break
	player.goal_label = label
	var moved: bool = await motor._walk_player(goal)
	var immediate := _snapshot(goal)
	var record := {"goal_id": label, "goal": goal, "original_motor_passed": moved, "immediate": immediate, "settling": []}
	# Preserve the exact original predicate before allowing normal idle physics.
	if not bool(immediate.old_strict):
		strict_rejections.append({"goal_id": label, "snapshot": immediate})
		if strict_rejections.size() == 1: await _capture("first_strict_endpoint_failure")
	for index in 6:
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		record.settling.append(_snapshot(goal))
	var settled := _snapshot(goal)
	record.settled = settled
	var witness: Dictionary = PlayerSupport.inspect(bar, player, goal)
	record.replacement_support = witness
	var replacement_ok := _check(bool(witness.supported), "exact support helper accepts settled original-motor endpoint " + label)
	if str(witness.kind) == "stair":
		var floated: Dictionary = PlayerSupport.inspect(bar, player, goal, player.global_position + Vector3.UP * .175)
		record.query_only_stair_float = floated
		replacement_ok = _check(not bool(floated.supported), "actual stair stale contacts reject query-only175mm capsule float " + label) and replacement_ok
	legs.append(record)
	# Continue only with actual engine floor contact on the actual capsule.
	# The old flat-tread predicate itself is never changed into an acceptance.
	return _check(moved and replacement_ok and bool(settled.safe_native_contact) and CollisionPolicy._service_collision_valid(player)
		and player.is_physics_processing() and Time.get_ticks_msec() - started < 150000,
		"ordinary native floor/capsule contact permits diagnostic continuation " + label)

func _snapshot(goal: Vector3) -> Dictionary:
	var feet := player.global_position
	var center := player._shape.global_position
	var radius := player._capsule.radius
	var height := player._capsule.height
	var axis_half := maxf(0.0, height * .5 - radius)
	var contacts: Array[Dictionary] = []
	var supported_contact := false
	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		var at := collision.get_position()
		var axis := Vector3(center.x, clampf(at.y, center.y - axis_half, center.y + axis_half), center.z)
		var surface_error := absf(at.distance_to(axis) - radius)
		var floor_normal := collision.get_normal().dot(Vector3.UP) >= cos(player.floor_max_angle)
		if floor_normal and surface_error < .035: supported_contact = true
		var collider: Object = collision.get_collider()
		contacts.append({"path": str(collider.get_path()) if collider is Node else str(collider), "shape": collision.get_collider_shape(),
			"at": at, "normal": collision.get_normal(), "depth": collision.get_depth(), "travel": collision.get_travel(),
			"remainder": collision.get_remainder(), "capsule_surface_error_m": surface_error, "floor_normal": floor_normal})
	var space := get_world_3d().direct_space_state
	var original_ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .04, feet - Vector3.UP * .08, 1)
	original_ray.exclude = [player.get_rid()]
	var original := space.intersect_ray(original_ray)
	var strict := not original.is_empty() and absf(original.position.y - feet.y) < .035 and absf(feet.y - goal.y) < .05
	var rays: Array[Dictionary] = []
	for offset: Vector2 in [Vector2.ZERO, Vector2(radius * .9, 0), Vector2(-radius * .9, 0), Vector2(0, radius * .9), Vector2(0, -radius * .9)]:
		var sample := feet + Vector3(offset.x, 0, offset.y)
		var ray := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * .35, sample - Vector3.UP * .4, 1)
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		rays.append({"offset_xz": offset, "hit": not hit.is_empty(), "at": hit.get("position"),
			"normal": hit.get("normal"), "path": str(hit.collider.get_path()) if not hit.is_empty() else ""})
	return {"frame": Engine.get_physics_frames(), "feet": feet, "capsule_center": center, "radius": radius, "height": height,
		"capsule_bottom": center - Vector3.UP * height * .5, "velocity": player.velocity, "on_floor": player.is_on_floor(),
		"floor_normal": player.get_floor_normal(), "contacts": contacts, "support_rays": rays, "goal_y_error": feet.y - goal.y,
		"horizontal_goal_gap": Vector2(feet.x - goal.x, feet.z - goal.z).length(), "old_strict": strict,
		"original_center_ray": {"hit": not original.is_empty(), "at": original.get("position")},
		"safe_native_contact": player.is_on_floor() and supported_contact}

func _flat_float_control(goal: Vector3) -> void:
	# Query-only negative. The actual controller remains on its real landing.
	var suspended := player.global_position + Vector3.UP * .175
	var ray := PhysicsRayQueryParameters3D.create(suspended + Vector3.UP * .04, suspended - Vector3.UP * .08, 1)
	ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var strict := not hit.is_empty() and absf(hit.position.y - suspended.y) < .035 and absf(suspended.y - goal.y) < .05
	float_controls.append({"query_only": true, "actual_feet": player.global_position, "suspended_query": suspended,
		"goal": goal, "original_center_ray_hit": not hit.is_empty(), "strict_accepted": strict,
		"replacement": PlayerSupport.inspect(bar, player, goal, suspended)})
	_check(not strict, "unchanged flat endpoint predicate rejects query-only175mm floating negative")
	_check(not bool(PlayerSupport.inspect(bar, player, goal, suspended).supported), "replacement flat predicate rejects same query-only175mm floating negative")

func _capture(identity: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path := directory.path_join(identity + ".png")
	if _check(image != null and not image.is_empty() and image.save_png(path) == OK, "actual gallery probe capture " + identity):
		captures.append({"path": path, "sha256": FileAccess.get_sha256(path)})

func _inputs() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime_digest: Array = []; var physical: Array = []
	_check(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], runtime_digest) == 0, "gallery runtime source binding")
	_check(OS.execute("python", [root.path_join("tools/v2_physical_inputs.py"), "--root", root], physical) == 0, "gallery physical source binding")
	var dependencies := {}
	for path: String in [get_script().resource_path, scene_file_path, "res://tests/harukiya_mass_return_test.gd",
		"res://tests/harukiya_roster_intake_test.gd", "res://tests/orison_v2_first_slice_contract_test.gd", "res://tests/harukiya_destination_routes.gd",
		"res://tests/harukiya_player_support.gd"]:
		dependencies["game/" + path.trim_prefix("res://")] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	return {"runtime_inputs_sha256": str(runtime_digest[0]).strip_edges() if not runtime_digest.is_empty() else "",
		"physical_inputs_sha256": str(physical[0]).strip_edges() if not physical.is_empty() else "", "test_dependencies": dependencies}

func _finish() -> void:
	Input.action_release("move_forward")
	var resolved: Array = player.resolved.duplicate(true) if is_instance_valid(player) else []
	var lifts: Array = player.lifts.duplicate(true) if is_instance_valid(player) else []
	if is_instance_valid(motor): motor.free()
	if is_instance_valid(player): player.free()
	if is_instance_valid(runtime): runtime.free()
	if is_instance_valid(bar): bar.shutdown(); bar.free()
	await get_tree().process_frame
	if lease: _check(RealityState.end_preview_campaign(self), "gallery preview returned")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse; CampaignTime.set_frozen_for_tests(prior_frozen)
	_check(is_same(RealityState.data, prior_data) and JSON.stringify(prior_data, "", true, true) == prior_text, "original campaign reference/content restored")
	_check(_inputs() == inputs, "gallery sources remain frozen")
	var passed := failures.is_empty()
	var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": true, "selector": "v2",
		"suite": "HarukiyaGalleryAccessProbe", "status": "PASS" if passed else "FAIL", "source": inputs,
		"scope": "Nearby actual bar/controller and unchanged original coarse directional motor. Single declared supported lower-landing initial placement; raw old strict endpoint versus resolved native floor/capsule contact and continued gallery roundtrip. Super-only step-up/physics observers. No18crowd replay, services renewal, production repair or artistic acceptance.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"contracts": {"nearby_gallery_roundtrip": {"executed": true, "status": "PASS" if roundtrip and passed else "FAIL"},
			"strict_endpoint_observation": {"executed": not legs.is_empty(), "status": "PASS" if not legs.is_empty() else "FAIL"}},
		"checks": checks, "failures": failures, "legs": legs, "strict_rejections": strict_rejections, "resolved_physics": resolved, "original_step_lifts": lifts, "captures": captures, "flat_float_controls": float_controls}
	result.source.test_path = "game/" + get_script().resource_path.trim_prefix("res://")
	result.source.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
	result.source.test_scene_path = "game/" + scene_file_path.trim_prefix("res://")
	result.source.test_scene_sha256 = FileAccess.get_sha256(scene_file_path)
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush(); var written := file.get_error() == OK; file.close()
	get_tree().quit(0 if passed and written else 1)
