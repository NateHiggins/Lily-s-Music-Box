extends Node3D
## Actual CampaignShell roots; production zone/scene APIs. External receipts bind each run.
## V1 has StreetCore/Passage. V2 does not: its result must never claim those gates.
## External stderr gate owns native-error acceptance AFTER process retirement.

const Selector := preload("res://scripts/building/building_root_selector.gd")
const CYCLES := 6
const FRAMES_PER_TRANSITION := 4
const STATIONS := [
	{"key": "street", "eye": Vector3(-16, 1.68, 13.5), "zone": Vector3(-16, 0.27, 13.5), "look": Vector3(26, 1.30, 19.6)},
	{"key": "passage", "eye": Vector3(14, 1.68, 50), "zone": Vector3(14, 1, 50), "look": Vector3(14, 1.6, 30)},
	{"key": "orison", "eye": Vector3(-0.4, 1.72, 9.1), "zone": Vector3(0, 0.27, 9), "look": Vector3(3.6, 1.25, 6.6)},
	{"key": "f04", "eye": Vector3(4.3, 11.25, 7.6), "zone": Vector3(4.3, 9.65, 7.6), "look": Vector3(4.3, 10.8, -6)},
	{"key": "harukiya", "eye": Vector3(3, -1.39, 34), "zone": Vector3(3, -1.39, 34), "look": Vector3(-11, -1.9, 33)},
]
var world
var shell: CampaignShell
var player: PlayerController
var camera: Camera3D
var phone: PhoneCamera
var phone_host: Node3D
var output := ""
var selected := ""
var variant := ""
var execution_scope := "full"
var arcade_capture_machine_id := 0
var checks: Array = []
var captures: Array = []
var transitions: Array = []
var populations: Array = []
var subviews: Array = []
var controls: Array = []
var failed := 0
var overlap: GeometryInstance3D
var overlap_mask := 0
var arcade_masks := {}
var arcade_owners := {}
var arcade_retired_ids := {}
var arcade_observations: Array = []
var vp: RID

func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	selected = OS.get_environment("ORISON_BUILDING_ROOT")
	variant = OS.get_environment("VULKAN_COMPOSED_VARIANT")
	execution_scope = OS.get_environment("VULKAN_COMPOSED_SCOPE")
	if execution_scope.is_empty(): execution_scope = "full"
	if output.is_empty() or selected not in ["v1", "v2"] or variant not in ["raw", "candidate", "omission", "viewport_omission"]:
		push_error("VULKAN COMPOSED requires SHOT_DIR, selected root, and declared source variant")
		get_tree().quit(2)
		return
	if execution_scope not in ["full", "root_retirement"] or (execution_scope != "full" and selected != "v1"):
		push_error("VULKAN COMPOSED requires a valid explicit execution scope")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		get_tree().quit(2)
		return
	CampaignTime.set_frozen_for_tests(true)
	OS.set_environment("DAYNIGHT_FORCE", "night")
	OS.set_environment("SCHEDULE", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	_check("campaign calendar seeded at authored 03:00 without host time", CampaignClock.new().configure_date(1928, 11, 10, 180.0))
	Selector.reset_for_tests(selected)
	_check("Vulkan Forward+ is active", RenderingServer.get_current_rendering_method() == "forward_plus")
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_phase("root_construct")
	shell = CampaignShell.new()
	shell.sleep_manual_clock = true
	add_child(shell)
	world = shell.active_world
	_check("CampaignShell composed the selected real root", world != null and world.scene_file_path == Selector.path_for(selected))
	if world == null:
		await _finish()
		return
	_check("root startup succeeded", world.get("startup_failed") != true)
	player = world.get("player") as PlayerController
	_check("real production player exists", player != null)
	if player == null:
		await _finish()
		return
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	# Leave root physics live: it owns SurfacePass.govern as well as the
	# visibility cache. The fixed player's position supplies the same zone.
	camera = player.camera
	camera.make_current()
	# Leave lighting, shadows, actor processes and renderer unchanged. These are
	# controlled teleports, not player traversal or a geometry-only benchmark.
	await get_tree().create_timer(1.6).timeout
	await _render_frames(8)
	if selected == "v1":
		await _v1()
	else:
		await _v2()
	await _finish()

func _v1() -> void:
	_check("actual V1 owns both production zone APIs", world.has_method("_apply_visibility") and world.has_method("_zone_toggle"))
	world.view_override = null
	world.show_all_floors = false
	world._apply_visibility(STATIONS[2].zone)
	world._index_street_core_geometry()
	world._index_late_f01_geometry()
	var core: Array = world.street_core_nodes
	_check("real StreetCore population is nonempty", core.size() > 1300)
	var harukiya_count := 0
	for geometry in core:
		if world._fully_in_harukiya_core(geometry): harukiya_count += 1
	populations.append({"stage": "actual_index_ready", "core_count": core.size(), "harukiya_core_count": harukiya_count,
		"readiness": "1.6-second timer plus eight rendered frames; actual counts retained, not a builder-completion signal"})
	var harukiya_census: Array = []
	for geometry in _geometry(world, true):
		if world._fully_in_harukiya_core(geometry):
			var bounds: AABB = world._measured_world_aabb(geometry)
			harukiya_census.append({"relative_path": str(world.get_path_to(geometry)), "class": geometry.get_class(),
				"indexed": core.has(geometry), "visible": geometry.visible, "layers": geometry.layers,
				"world_aabb": {"position": [bounds.position.x, bounds.position.y, bounds.position.z],
					"size": [bounds.size.x, bounds.size.y, bounds.size.z]}})
	populations.append({"stage": "harukiya_source_census", "clock": RealityState.data.campaign_clock.duplicate(true),
		"eligible_count": harukiya_count, "census": harukiya_census,
		"existing_greater_than_250_contract": "preserved in StreetCoreVisibilityTest; not weakened or cleared here"})
	_check("real Passage late foreign population is nonempty", world.passage_late_foreign_nodes.size() > 300)
	for geometry in core:
		if world.passage_late_foreign_nodes.has(geometry):
			overlap = geometry
			overlap_mask = geometry.layers
			break
	_check("real measured STREET/PASSAGE overlap exists", overlap != null and overlap_mask != 0)
	var actor: Node3D = world.find_child("F04_B_MONITOR_01", true, false)
	var f04: Array = world.functional_props_by_floor.get("F04", [])
	_check("real F04 terminal has registry ownership", actor is SignalTerminalProp and f04.has(actor))
	_check("F04 actor population exists independently of floor hierarchy", not f04.is_empty())
	await _setup_phone()
	for station in STATIONS:
		await _transition(station, -1, true)
	# Cabinets boot lazily within their production camera-distance radius.
	# Harukiya is the last real warmup station, not the far-away vestibule.
	await _render_frames(8)
	_collect_arcade_masks(world)
	_check("actual own-world arcade geometry exists after near-cabinet warmup", not arcade_masks.is_empty())
	await _capture_actual_arcade("actual_arcade_before_passage", true)
	_observe_material_ownership("before_measured", true)
	# Both direct portal orders and return to the apartment corridor; each
	# transition samples synchronous work AND the next four rendered frames.
	for cycle in CYCLES:
		for index in [0, 1, 0, 2, 3, 2]:
			await _transition(STATIONS[index], cycle, false)
		_observe_material_ownership("cycle_%d" % cycle, false)
	await _transition(STATIONS[4], CYCLES + 1, true)
	# Returning through the actual distance gate refreshes this viewport. Merely
	# reading it while far away could show its deliberately cached old texture.
	await _render_frames(8)
	_verify_arcade_return()
	await _capture_actual_arcade("actual_arcade_after_passage", false)
	await _mirror_consumer()
	await _owned_blocker_controls()
	if execution_scope == "full":
		await _separate_world_control()
	else:
		_phase("separate_world_case_explicitly_excluded")
	world._apply_visibility(STATIONS[2].zone)
	_check("real overlap restored exactly after all zone releases", overlap != null and overlap.layers == overlap_mask and not world._zone_layer_blocks.has(overlap.get_instance_id()))
	_check("arcade own-world geometry never acquired building masks", _arcade_masks_match())
	# End with a real blocked population, then retire the whole shell. Native
	# pairing/softshadow errors during this stage are failures even with exit0.
	await _transition(STATIONS[1], CYCLES, true)
	_observe_material_ownership("before_retirement", true)

func _transition(station: Dictionary, cycle: int, take_capture: bool) -> void:
	_phase("transition_%s_%d" % [station.key, cycle])
	player.global_position = station.zone
	camera.global_position = station.eye
	camera.look_at(station.look)
	var started := Time.get_ticks_usec()
	world._apply_visibility(station.zone)
	var apply_usec := Time.get_ticks_usec() - started
	var after_apply: int = world._visibility_apply_count
	world._update_floor_visibility()
	_check("%s unchanged-region physics request is cached" % station.key, world._visibility_apply_count == after_apply)
	_check_zone(station.key)
	phone.track(camera)
	var frames: Array = []
	for frame in FRAMES_PER_TRANSITION:
		var before_frame := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		frames.append({"ordinal": frame, "wait_usec": Time.get_ticks_usec() - before_frame,
			"viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(vp),
			"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(vp),
			"surface_governor": _surface_state(),
			"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)})
	# Measure explicit same-region scan cost after transition-frame samples;
	# these artificial repeated requests are not inside the rendered window.
	var stable := _zone_state()
	started = Time.get_ticks_usec()
	for _i in 16:
		world._apply_visibility(station.zone)
	var repeated_usec := Time.get_ticks_usec() - started
	_check("%s repeated explicit no-op scans preserve tables and masks" % station.key, stable == _zone_state())
	transitions.append({"station": station.key, "cycle": cycle, "warmup": cycle < 0,
		"apply_usec": apply_usec, "repeated_scan_count": 16, "repeated_scan_usec": repeated_usec, "frames": frames})
	populations.append({"station": station.key, "cycle": cycle, "population": _population(world), "zone": _zone_state()})
	_check("arcade lifecycle/isolation after " + str(station.key), _arcade_masks_match(str(station.key)))
	if take_capture:
		var prefix := "initial" if cycle < 0 else ("return" if cycle == CYCLES + 1 else "before_retirement")
		await _capture("%s_%s" % [prefix, station.key], get_viewport())
		if station.key in ["street", "passage", "orison"]:
			await _capture("%s_%s_phone" % [prefix, station.key], phone.lens)
	_write_progress("transition_" + str(station.key))

func _check_zone(key: String) -> void:
	var f04: Array = world.functional_props_by_floor.get("F04", [])
	var actors_show: bool = f04.all(func(n): return n.visible)
	var actors_hide: bool = f04.all(func(n): return not n.visible)
	if key == "street":
		_check("STREET suppresses every indexed core mask", not world.street_core_visible and world.street_core_nodes.all(func(n): return n.layers == 0))
		_check("STREET retains real F04 actor owners for facade views", actors_show)
	elif key == "passage":
		_check("PASSAGE retains F01 and hides F04 shell/actors", world.passage_visible and world.floor_nodes.F01.visible and not world.floor_nodes.F04.visible and actors_hide)
		_check("PASSAGE keeps real overlap blocked", overlap != null and overlap.layers == 0)
	elif key == "f04":
		_check("F04 corridor restores actual F04 actor owners", actors_show and world.floor_nodes.F04.visible)
		var f01: Array = world.functional_props_by_floor.get("F01", [])
		_check("F04 corridor does not force F01 actors visible", not f01.is_empty() and f01.all(func(n): return not n.visible))
	elif key == "orison":
		_check("ORISON drains real overlap blockers", overlap != null and overlap.layers == overlap_mask and not world._zone_layer_blocks.has(overlap.get_instance_id()))
		_check("ORISON lobby hides F04 actor owners", actors_hide)
	elif key == "harukiya":
		_check("Harukiya interior restores core gate", world.street_core_visible)

func _zone_state() -> Dictionary:
	var masks := {}
	for n in world.street_core_nodes:
		if is_instance_valid(n): masks[str(n.get_instance_id())] = n.layers
	return {"saved": world.passage_late_saved.duplicate(true), "blocks": world._zone_layer_blocks.duplicate(true), "core_masks": masks}

func _surface_state() -> Dictionary:
	var surface = world.get("surface_pass")
	if surface == null: return {}
	return {"budget": surface.budget, "props_tier_on": surface.props_tier_on,
		"governed_steps": surface.governed_steps, "pinned": surface.get("_govern_pinned"),
		"queued_material_changes": surface.get("_lever_queue").size()}

func _setup_phone() -> void:
	# Actual PhoneCamera implementation, explicitly mounted by this fixture.
	# This proves a shared-world consumer, not the physical handset UI flow.
	_check("profile photo directory is available", DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://photos")) == OK)
	phone_host = Node3D.new()
	phone_host.name = "HarnessPhoneCameraHost"
	add_child(phone_host)
	phone = PhoneCamera.new()
	phone_host.add_child(phone)
	phone.setup(phone_host)
	phone.bind_world(get_viewport())
	phone.set_active(true)
	phone.track(camera)
	_check("production phone lens shares selected root world", phone.lens.world_3d == camera.get_world_3d())
	subviews.append({"kind": "PhoneCamera", "ownership": "fixture-mounted production implementation", "shared_world": true})

func _mirror_consumer() -> void:
	var mirror := world.find_child("PlanarMirrorRenderer", true, false) as PlanarMirrorRenderer
	_check("actual V1 planar mirror owner exists", mirror != null)
	if mirror == null: return
	var cabinet: MedicineCabinetProp
	for node in world.functional_props_by_floor.get("F04", []):
		if node is MedicineCabinetProp:
			cabinet = node
			break
	_check("actual F04 medicine cabinet exists", cabinet != null)
	if cabinet == null: return
	world._apply_visibility(STATIONS[3].zone)
	var center := cabinet.mirror_center()
	var eye := center + cabinet.mirror_normal() * 1.25
	player.global_position = eye - Vector3.UP * player.STANDING_EYE
	camera.global_position = eye
	camera.look_at(center)
	await _render_frames(4)
	_check("production mirror selects real cabinet", mirror.active_mirror() == cabinet)
	_check("mirror borrows main world and excludes mirror layer", mirror._view.world_3d == camera.get_world_3d() and (mirror._camera.cull_mask & PlanarMirrorRenderer.MIRROR_LAYER) == 0)
	await _capture("actual_f04_mirror", get_viewport())
	await _capture("actual_f04_reflection", mirror._view)
	subviews.append({"kind": "PlanarMirrorRenderer", "ownership": "actual V1 root", "cabinet": str(cabinet.get_path()), "shared_world": true})

func _owned_blocker_controls() -> void:
	_phase("owned_blocker_controls")
	# Synthetic nodes are deliberately not inserted into production spatial
	# indices. The actual root's _zone_toggle is the sole mask writer here.
	var host := Node3D.new()
	host.name = "HarnessMaskOwners"
	add_child(host)
	host.position = Vector3(200, 50, 200)
	var neighbor := _mesh(host, "Neighbor", 1)
	for spec in [{"name": "mask33", "mask": 33, "own_visible": true, "parent_visible": true},
		{"name": "own_hidden", "mask": 1, "own_visible": false, "parent_visible": true},
		{"name": "parent_hidden", "mask": 1, "own_visible": true, "parent_visible": false},
		{"name": "authored_zero", "mask": 0, "own_visible": true, "parent_visible": true}]:
		var parent := Node3D.new()
		host.add_child(parent)
		parent.visible = spec.parent_visible
		var node := _mesh(parent, spec.name, spec.mask)
		node.visible = spec.own_visible
		for order in [["passage", "street_core"], ["street_core", "passage"]]:
			for blocker in order:
				world._zone_toggle(node, false, blocker)
				world._zone_toggle(node, false, blocker) # unchanged request
			_check("%s two independent blockers hide mask" % spec.name, node.layers == 0)
			world._zone_toggle(node, true, order[0])
			_check("%s first release cannot expose target" % spec.name, node.layers == 0)
			world._zone_toggle(node, true, order[1])
			world._zone_toggle(node, true, order[1])
			_check("%s exact mask and owner visibility survive" % spec.name, node.layers == spec.mask and node.visible == spec.own_visible and parent.visible == spec.parent_visible)
			_check("%s released tables drain" % spec.name, not world.passage_late_saved.has(node.get_instance_id()) and not world._zone_layer_blocks.has(node.get_instance_id()))
		# The legitimate owner changes visibility DURING the blocked interval.
		world._zone_toggle(node, false)
		node.visible = not bool(spec.own_visible)
		world._zone_toggle(node, true)
		_check("%s live owner change is not overwritten" % spec.name, node.visible == (not bool(spec.own_visible)) and node.layers == spec.mask)
		controls.append({"name": spec.name, "authored_mask": spec.mask, "two_release_orders": true})
	_check("unrelated neighbor is untouched", neighbor.layers == 1 and neighbor.visible)
	host.queue_free()
	await _render_frames(2)

func _separate_world_control() -> void:
	_phase("separate_world_control")
	var view := SubViewport.new()
	view.name = "HarnessIndependentWorld"
	view.size = Vector2i(320, 240)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var scene := Node3D.new()
	view.add_child(scene)
	var lens := Camera3D.new()
	scene.add_child(lens)
	lens.position = Vector3(0, 0, 4)
	lens.current = true
	var target := _mesh(scene, "SeparateWorldTarget", 33)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.25, 0.02)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.05, 0.005)
	target.material_override = material
	var light := OmniLight3D.new()
	scene.add_child(light)
	light.position = Vector3(0, 2, 2)
	light.shadow_enabled = true
	_check("owned viewport has separate actual scenario", target.get_world_3d().scenario != camera.get_world_3d().scenario)
	await _render_frames(4)
	await _capture("separate_world_initial", view)
	var initial_pixels := _orange_pixels(view)
	_check("separate-world target actually renders initially", initial_pixels > 50)
	for _i in 6:
		world._zone_toggle(target, false, "passage")
		await _render_frames(2)
		world._zone_toggle(target, true, "passage")
		await _render_frames(2)
	_check("separate-world target restores mask and its own world", target.layers == 33 and target.get_world_3d() == view.find_world_3d())
	await _capture("separate_world_restored", view)
	var restored_pixels := _orange_pixels(view)
	_check("separate-world target actually renders after restore", restored_pixels > 50)
	world._zone_toggle(target, false, "passage")
	await _render_frames(2)
	await _capture("separate_world_blocked", view)
	var blocked_pixels := _orange_pixels(view)
	_check("separate-world blocked target leaves image", blocked_pixels == 0)
	light.queue_free()
	await _render_frames(3)
	world._zone_toggle(target, true, "passage")
	_check("owned viewport tables drained before free", not world._zone_layer_blocks.has(target.get_instance_id()) and not world.passage_late_saved.has(target.get_instance_id()))
	view.queue_free()
	await _render_frames(3)
	subviews.append({"kind": "owned separate World3D", "ownership": "synthetic explicit helper boundary", "production_caller": "V1._zone_toggle", "not_actual_arcade_gameplay": true, "orange_pixels": [initial_pixels, restored_pixels, blocked_pixels]})

func _orange_pixels(view: SubViewport) -> int:
	var image := view.get_texture().get_image()
	if image == null or image.is_empty(): return 0
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.r > 0.12 and color.r > color.g * 1.8 and color.r > color.b * 2.5:
				count += 1
	return count

func _v2() -> void:
	_check("V2 genuinely has no V1 zone APIs", not world.has_method("_apply_visibility") and not world.has_method("_zone_toggle"))
	_check("actual V2 production terminal is present", world.find_child("F04_B_MONITOR_01", true, false) is SignalTerminalProp)
	await _setup_phone()
	var stance: Dictionary = world.core_loop.resolve_return_anchor()
	_check("V2 F04 uses actual semantic stance", stance.get("id") == "F04_B_BED" and stance.get("position") is Vector3)
	var terminal := world.find_child("F04_B_MONITOR_01", true, false) as Node3D
	if stance.get("position") is Vector3 and terminal != null:
		player.global_position = stance.position
		camera.global_position = player.global_position + Vector3.UP * player.STANDING_EYE
		camera.look_at(terminal.global_position + Vector3.UP * 0.35)
		phone.track(camera)
		await _render_frames(8)
		await _capture("v2_actual_f04_semantic_stance", get_viewport())
		await _capture("v2_actual_f04_phone", phone.lens)
	populations.append({"station": "v2_f04", "population": _population(world), "zone_gate_applicability": "absent in this root"})

func _collect_arcade_masks(node: Node) -> void:
	if node is ArcadeMachine:
		var geometry := _geometry(node, true)
		var authored_masks: Array = []
		for g in geometry:
			if not authored_masks.has(g.layers): authored_masks.append(g.layers)
		arcade_owners[node.get_instance_id()] = {"relative_path": str(world.get_path_to(node)),
			"owner_id": node.get_parent().get_instance_id(), "initial_geometry_count": geometry.size(),
			"initial_booted": node.is_booted(), "authored_masks": authored_masks}
		for g in geometry:
			arcade_masks[g.get_instance_id()] = {"mask": g.layers, "scenario": g.get_world_3d().scenario,
				"machine_id": node.get_instance_id(), "relative_path": str(node.get_path_to(g))}
		subviews.append({"kind": "ArcadeMachine", "path": str(node.get_path()), "geometry_count": geometry.size(), "own_world_3d": node.own_world_3d})
		return
	for child in node.get_children(): _collect_arcade_masks(child)

func _arcade_owner_state(machine_id: int, include_geometry := true) -> Dictionary:
	var machine := instance_from_id(machine_id) as ArcadeMachine
	if machine == null: return {"machine_missing": true}
	var owner := machine.get_parent() as ArcadeCabinetProp
	if owner == null: return {"cabinet_owner_missing": true}
	return {"machine_path": str(world.get_path_to(machine)), "owner_path": str(world.get_path_to(owner)),
		"booted": machine.is_booted(), "live": owner.get("_live"), "away_seconds": owner.get("_away"),
		"unload_delay": owner.UNLOAD_DELAY, "distance": camera.global_position.distance_to(owner.global_position),
		"unload_range": owner.UNLOAD_RANGE, "live_range": owner.LIVE_RANGE, "playing": owner._playing(),
		"own_world_3d": machine.own_world_3d, "update_mode": machine.render_target_update_mode,
		"current_geometry_count": _geometry(machine, true).size() if include_geometry else -1}

func _arcade_masks_match(stage := "final") -> bool:
	var issues: Array = []
	var retirements: Array = []
	# Census once per owner per observation, outside measured transition frames.
	# Old object IDs stay retired after a legitimate reboot; the replacement
	# population is independently checked instead of requiring immortal meshes.
	var owner_states := {}
	for machine_id in arcade_owners:
		var machine := instance_from_id(machine_id) as ArcadeMachine
		var state := _arcade_owner_state(machine_id, false)
		owner_states[machine_id] = state
		if machine == null:
			issues.append({"kind": "missing_cabinet_machine", "owner_state": state})
			continue
		var current := _geometry(machine, true)
		state.current_geometry_count = current.size()
		var own_world: World3D = machine.find_world_3d()
		for node in current:
			var isolated: bool = own_world != null and node.get_world_3d().scenario == own_world.scenario \
				and node.get_world_3d().scenario != camera.get_world_3d().scenario \
				and not world.street_core_nodes.has(node) and not world.passage_late_foreign_nodes.has(node) and not world.passage_late_interior_nodes.has(node)
			var masks: Array = arcade_owners[machine_id].authored_masks
			if not isolated or (not masks.is_empty() and not masks.has(node.layers)):
				issues.append({"kind": "current_own_world_population_corrupted", "geometry_path": str(world.get_path_to(node)),
					"actual_mask": node.layers, "initial_owner_mask_set": masks, "isolated": isolated, "owner_state": state})
	for id in arcade_masks:
		var node := instance_from_id(id) as GeometryInstance3D
		var expected: Dictionary = arcade_masks[id]
		if node == null or not node.is_inside_tree():
			var state: Dictionary = owner_states[expected.machine_id]
			var owner_retired: bool = state.get("booted") == false and state.get("playing") == false \
				and float(state.get("away_seconds", -1)) > float(state.get("unload_delay", INF))
			if owner_retired and not arcade_retired_ids.has(id):
				arcade_retired_ids[id] = {"observed_stage": stage, "owner_state": state.duplicate(true)}
			var record := {"kind": "baseline_geometry_retired", "geometry_path": expected.relative_path, "owner_state": state,
				"owner_retirement_verified": arcade_retired_ids.has(id), "original_retirement": arcade_retired_ids.get(id, {})}
			if arcade_retired_ids.has(id): retirements.append(record)
			else: issues.append(record)
			continue
		var indexed := {"street": world.street_core_nodes.has(node), "passage_foreign": world.passage_late_foreign_nodes.has(node), "passage_interior": world.passage_late_interior_nodes.has(node)}
		var mask_ok: bool = node.layers == expected.mask
		var world_ok: bool = node.get_world_3d().scenario == expected.scenario and node.get_world_3d().scenario != camera.get_world_3d().scenario
		if not mask_ok or not world_ok or indexed.values().has(true):
			issues.append({"kind": "still_live_baseline_geometry_corrupted", "geometry_path": str(world.get_path_to(node)), "class": node.get_class(), "expected_mask": expected.mask,
				"actual_mask": node.layers, "same_own_scenario": world_ok, "indexed": indexed, "owner_state": owner_states[expected.machine_id]})
	arcade_observations.append({"stage": stage, "issues": issues, "verified_owner_retirements": retirements})
	if not issues.is_empty(): print("[ARCADE OWNERSHIP ISSUES] ", JSON.stringify(issues.slice(0, 8)))
	return issues.is_empty()

func _verify_arcade_return() -> void:
	var returned := 0
	for machine_id in arcade_owners:
		var machine := instance_from_id(machine_id) as ArcadeMachine
		if machine == null: continue
		var state := _arcade_owner_state(machine_id)
		if float(state.get("distance", INF)) >= float(state.get("live_range", 0)): continue
		var current := _geometry(machine, true)
		var isolated: bool = current.all(func(n): return n.get_world_3d().scenario != camera.get_world_3d().scenario \
			and not world.street_core_nodes.has(n) and not world.passage_late_foreign_nodes.has(n) and not world.passage_late_interior_nodes.has(n))
		_check("return reactivates actual nearby arcade owner " + str(state.get("owner_path")), machine.is_booted() and not current.is_empty() and isolated)
		arcade_observations.append({"stage": "actual_return", "owner_state": state, "current_world_isolation": isolated})
		returned += 1
	_check("Harukiya return reaches actual arcade activation consumer", returned > 0)

func _capture_actual_arcade(identity: String, choose: bool) -> void:
	if choose:
		# Stable authored path selection among machines the real cabinet owner
		# has booted within its LIVE_RANGE. Never boot or force viewport updates.
		var chosen_path := ""
		for machine_id in arcade_owners:
			var state := _arcade_owner_state(machine_id)
			if state.get("booted") != true or state.get("live") != true: continue
			if float(state.get("distance", INF)) >= float(state.get("live_range", 0)): continue
			var path := str(state.get("machine_path", ""))
			if chosen_path.is_empty() or path < chosen_path:
				chosen_path = path
				arcade_capture_machine_id = machine_id
	var machine := instance_from_id(arcade_capture_machine_id) as ArcadeMachine
	_check("actual cabinet capture owner exists " + identity, machine != null)
	if machine == null: return
	var state := _arcade_owner_state(arcade_capture_machine_id)
	var own_world: World3D = machine.find_world_3d()
	_check("actual cabinet capture is currently live " + identity, machine.is_booted() and state.get("live") == true
		and machine.render_target_update_mode == SubViewport.UPDATE_ALWAYS and int(state.get("current_geometry_count", 0)) > 0)
	_check("actual cabinet capture resolves its own world " + identity, own_world != null and own_world != camera.get_world_3d())
	subviews.append({"kind": "actual_arcade_capture", "name": identity, "owner_state": state,
		"scope": "real cabinet's raw game viewport after actual near-camera activation; no forced render or synthetic content"})
	await _render_frames(2)
	await _capture(identity, machine)

func _geometry(node: Node, include_subviews := false) -> Array:
	var found: Array = []
	if node is SubViewport and not include_subviews: return found
	if node is GeometryInstance3D: found.append(node)
	for child in node.get_children(): found.append_array(_geometry(child, include_subviews))
	return found

func _population(node: Node) -> Dictionary:
	var rows := {"geometry": 0, "layer_zero": 0, "owner_hidden": 0, "eligible": 0, "classes": {}}
	for geometry in _geometry(node):
		rows.geometry += 1
		var type_name: String = geometry.get_class()
		rows.classes[type_name] = int(rows.classes.get(type_name, 0)) + 1
		if geometry.layers == 0: rows.layer_zero += 1
		if not geometry.is_visible_in_tree(): rows.owner_hidden += 1
		if geometry.layers != 0 and geometry.is_visible_in_tree(): rows.eligible += 1
	return rows

func _mesh(parent: Node, identity: String, mask: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = identity
	node.mesh = BoxMesh.new()
	node.layers = mask
	parent.add_child(node)
	return node

func _capture(identity: String, viewport: Viewport) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := output.path_join(identity + ".png")
	var okay: bool = image != null and not image.is_empty()
	if okay: okay = image.save_png(path) == OK
	_check("capture written " + identity, okay)
	captures.append({"name": identity, "file": path, "written": okay,
		"viewport": str(viewport.get_path()), "size": [viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y],
		"reviewed": false, "scope": "controlled composition, not traversal or human acceptance"})

func _render_frames(count: int) -> void:
	for _i in count: await RenderingServer.frame_post_draw

func _phase(label: String) -> void:
	print("[VULKAN COMPOSED PHASE] %s ticks_usec=%d" % [label, Time.get_ticks_usec()])
	if not output.is_empty(): _write_progress(label)

func _write_progress(stage: String) -> void:
	var file := FileAccess.open(output.path_join("progress.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"stage": stage, "root": selected, "variant": variant, "execution_scope": execution_scope, "checks": checks,
			"functional_failures": failed, "transitions": transitions, "populations": populations,
			"captures": captures, "arcade_observations": arcade_observations,
			"incomplete_run_not_final_proof": true}, "\t"))
		file.close()

func _check(label: String, okay: bool) -> void:
	checks.append({"label": label, "passed": okay})
	print("[VULKAN COMPOSED] %s %s" % ["PASS" if okay else "FAIL", label])
	if not okay: failed += 1

func _finish() -> void:
	_phase("before_retirement")
	if phone != null: phone.set_active(false)
	if phone_host != null: phone_host.queue_free()
	var shell_weak: WeakRef = weakref(shell) if shell != null else null
	var world_weak: WeakRef = weakref(world) if world != null else null
	if shell != null: shell.queue_free()
	# This uses the real _exit_tree path, not shutdown_for_tests or pre-cleared
	# render pairs. Allow queued frees and render work to finish before receipt.
	await get_tree().process_frame
	await _render_frames(4)
	await get_tree().create_timer(0.2).timeout
	_check("actual shell retired", shell_weak == null or shell_weak.get_ref() == null)
	_check("actual selected world retired", world_weak == null or world_weak.get_ref() == null)
	_check_material_retirement()
	_phase("after_retirement")
	arcade_masks.clear() # Only IDs/masks/RID values were retained, no World3D owner.
	var receipt := {"schema": "astra.vulkan_composed.probe.v2", "root": selected, "variant": variant, "execution_scope": execution_scope,
		"separate_world_case_executed": selected == "v1" and execution_scope == "full",
		"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(),
		"functional_failures": failed, "checks": checks, "captures": captures,
		"transitions": transitions, "populations": populations, "subviews": subviews, "owned_controls": controls, "arcade_observations": arcade_observations,
		"scope": "actual root composition, controlled teleports, source-bound script and rendered transition smoke measurements; stderr and images require independent external review",
		"v2_street_passage_applicability": "absent", "no_op_native_call_count_proven": false,
		"native_diagnostics_accepted": false,
		"material_contract": "actual_build_ownership_v1",
		"material_observations": material_observations, "material_retirement": material_retirement}
	var file := FileAccess.open(output.path_join("probe.json"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("[VULKAN COMPOSED] checks=%d failures=%d" % [checks.size(), failed])
	get_tree().quit(0 if failed == 0 else 1)

# Material-only observations follow the existing render/no-op timers.
# IDs/WeakRefs never become a second material or World3D lifetime owner.
const MATERIAL_CASE_UNITS := {
	"mina_caption_crisis": "2A", "peter_form_corridor": "4A",
	"juno_feedback_tetris": "2C", "mae_contradictory_antiques": "6C",
	"cal_memory_radio": "5B", "omar_unrepairable": "3B",
}
const MATERIAL_PROBE_INTENSITIES := [0.10, 0.12, 0.14, 0.16, 0.18, 0.20]
var material_observations: Array = []
var material_case_refs := {}
var material_finish_ids := {}
var material_cache_consumers := {}
var material_retirement := {"applicable": false}


func _observe_material_ownership(stage: String, exercise_refresh: bool) -> void:
	var enc = world.get("apartment_encroachment")
	var surface = world.get("surface_pass")
	var issues: Array = []
	if enc == null or surface == null:
		material_observations.append({"stage": stage, "owner_missing": true})
		_check("material " + stage + " actual production owners exist", false)
		return
	var record := {"stage": stage, "owner_source_sha256": FileAccess.get_sha256(enc.get_script().resource_path),
		"outside_measured_intervals": true, "surface_governor": _surface_state(),
		"cases": {}, "registries": {}, "private_geometry": 0, "actor_geometry": 0,
		"cache_consumers": [], "excluded_draws": [], "refresh_exercised": exercise_refresh}
	var expected_keys: Array = MATERIAL_CASE_UNITS.keys()
	expected_keys.sort()
	var actual_keys: Array = enc.surfaces.keys()
	actual_keys.sort()
	if actual_keys != expected_keys: issues.append("actual build did not publish exactly the six shipped case finishes")
	if not surface.props_tier_on or not surface._lever_queue.is_empty():
		issues.append("material precondition: prop tier must be active and its production queue settled")
	if not enc._props_ready: issues.append("actual production reach callback has not completed")
	var installed_by_floor := {}
	var cache_ids := {}
	for key in surface._cache:
		var cached = surface._cache[key]
		if cached is ShaderMaterial: cache_ids[cached.get_instance_id()] = str(key)
	# Independent consumer census: the current draw chooses a full override
	# before a surface override. Private/actor ancestry is read directly.
	for floor_id in enc.fields:
		installed_by_floor[floor_id] = {}
		if not enc.storey_materials.has(floor_id):
			issues.append("field has no actual active material registry: " + str(floor_id))
		var floor_node: Node = world.floor_nodes.get(floor_id)
		if floor_node == null:
			issues.append("missing actual floor owner " + str(floor_id))
			continue
		for node in floor_node.find_children("*", "MeshInstance3D", true, false):
			var draw := node as MeshInstance3D
			if not _material_boundary(draw).is_empty() or draw.mesh == null: continue
			var active: Array = []
			if draw.material_override != null:
				active.append({"slot": -1, "material": draw.material_override})
			else:
				for index in draw.mesh.get_surface_count():
					active.append({"slot": index, "material": draw.get_surface_override_material(index)})
			for item in active:
				var material := item.material as ShaderMaterial
				if not _material_layered(material): continue
				var material_id: int = material.get_instance_id()
				installed_by_floor[floor_id][material_id] = true
				if not _material_field_matches(material, floor_id, enc):
					issues.append("installed floor draw samples wrong/unbound field: " + str(world.get_path_to(draw)))
				if int(item.slot) >= 0 and cache_ids.has(material_id):
					var consumer_key := str(world.get_path_to(draw)) + ":" + str(item.slot)
					if not material_cache_consumers.has(consumer_key):
						material_cache_consumers[consumer_key] = {"draw": weakref(draw), "slot": int(item.slot),
							"material_id": material_id, "cache_key": cache_ids[material_id]}
	for case_id in MATERIAL_CASE_UNITS:
		var case_record := {"unit": MATERIAL_CASE_UNITS[case_id], "finishes": [], "props": []}
		var authored := _material_authored_unit(str(MATERIAL_CASE_UNITS[case_id]))
		var floor_id := str(authored.get("floor", ""))
		var unit: Dictionary = enc.units.get(case_id, {})
		if authored.is_empty() or unit.is_empty() or not enc.fields.has(floor_id):
			issues.append("actual authored unit or case field missing: " + str(case_id))
			record.cases[case_id] = case_record
			continue
		if unit.floor_node != world.floor_nodes.get(floor_id) or not (unit.rect as Vector4).is_equal_approx(authored.rect):
			issues.append("build unit provider disagrees with authored room bounds: " + str(case_id))
		for row in enc.surfaces.get(case_id, []):
			var draw := row.mesh as MeshInstance3D
			var material := row.material as ShaderMaterial
			if not is_instance_valid(draw) or material == null:
				issues.append("invalid actual finish row: " + str(case_id))
				continue
			var path := str(world.get_path_to(draw)) if world.is_ancestor_of(draw) else "detached:" + str(draw.name)
			var slot := int(row.surface)
			var material_id := material.get_instance_id()
			var live: bool = world.is_ancestor_of(draw) and draw.mesh != null and slot >= 0 and slot < draw.mesh.get_surface_count() \
				and draw.material_override == null and draw.get_surface_override_material(slot) == material
			var guard_ok: bool = _material_boundary(draw).is_empty() and str(draw.name).contains("_finish_") \
				and world.floor_nodes[floor_id].is_ancestor_of(draw)
			var marker_ok: bool = str(material.get_meta("living_storey", "")) == floor_id \
				and material.get_shader_parameter("has_encroachment") == true
			var rect = material.get_shader_parameter("unit_rect")
			if not live or not guard_ok or not marker_ok or not (rect is Vector4 and rect.is_equal_approx(authored.rect)):
				issues.append("finish build guard/marker/installed identity failure: " + path + ":" + str(slot))
			var key := path + ":" + str(slot)
			if material_finish_ids.has(key) and material_finish_ids[key] != material_id:
				issues.append("actual finish replaced across ordinary transitions: " + key)
			material_finish_ids[key] = material_id
			material_case_refs[material_id] = weakref(material)
			case_record.finishes.append({"path": path, "slot": slot, "material_id": material_id,
				"live": live, "guard_ok": guard_ok, "marker_ok": marker_ok})
		for row in enc.prop_rows.get(case_id, []):
			var draw := row.mesh as MeshInstance3D
			var material := row.material as ShaderMaterial
			if not is_instance_valid(draw) or material == null:
				issues.append("invalid actual prop row: " + str(case_id))
				continue
			var path := str(world.get_path_to(draw)) if world.is_ancestor_of(draw) else "detached:" + str(draw.name)
			var material_id := material.get_instance_id()
			var live: bool = world.is_ancestor_of(draw) and draw.material_override == material
			var marker_ok: bool = str(material.get_meta("encroachment_case", "")) == case_id \
				and str(material.get_meta("living_storey", "")) == floor_id
			var linked: bool = material.has_meta("encroachment_shared") and material.get_meta("encroachment_shared") == row.shared
			if not live or not marker_ok or not linked or not _material_boundary(draw).is_empty():
				issues.append("prop installed owner/marker/source link failure: " + path)
			if not _material_field_matches(material, floor_id, enc):
				issues.append("prop samples wrong/unbound field: " + path)
			if live:
				installed_by_floor[floor_id][material_id] = true
			material_case_refs[material_id] = weakref(material)
			case_record.props.append({"path": path, "material_id": material_id,
				"live": live, "marker_ok": marker_ok, "source_linked": linked})
		if case_record.finishes.is_empty() or case_record.props.is_empty():
			issues.append("case lacks actual nonempty finish/prop consumer: " + str(case_id))
		record.cases[case_id] = case_record
	for floor_id in enc.storey_materials:
		var registry: Array = enc.storey_materials[floor_id]
		var unique := {}
		var invalid := 0
		for material in registry:
			if not is_instance_valid(material): invalid += 1
			else: unique[material.get_instance_id()] = true
		var expected: Dictionary = installed_by_floor.get(floor_id, {})
		var actual_ids: Array = unique.keys()
		var expected_ids: Array = expected.keys()
		actual_ids.sort()
		expected_ids.sort()
		record.registries[floor_id] = {"slots": registry.size(), "unique": unique.size(),
			"invalid": invalid, "material_ids": actual_ids, "installed_ids": expected_ids}
		if invalid != 0 or registry.size() != unique.size() or actual_ids != expected_ids:
			issues.append("registry differs from unique installed consumers: " + str(floor_id))
	# A cached first-owner surface must remain the real installed draw while
	# the ordinary governor mutates that very cached resource.
	for key in material_cache_consumers:
		var consumer: Dictionary = material_cache_consumers[key]
		var draw := consumer.draw.get_ref() as MeshInstance3D
		var cached = surface._cache.get(consumer.cache_key)
		var live: bool = is_instance_valid(draw) and world.is_ancestor_of(draw) and _material_boundary(draw).is_empty() \
			and draw.mesh != null and consumer.slot >= 0 and consumer.slot < draw.mesh.get_surface_count() \
			and draw.material_override == null and cached is ShaderMaterial \
			and cached.get_instance_id() == consumer.material_id \
			and draw.get_surface_override_material(consumer.slot) == cached
		var budget_matches := cached is ShaderMaterial and _material_number_equals(cached.get_shader_parameter("parallax_budget"), surface.budget)
		if not live: issues.append("SurfacePass cache lost installed first-owner consumer: " + str(key))
		if not budget_matches: issues.append("SurfacePass cache governor value differs from actual budget: " + str(key))
		record.cache_consumers.append({"key": key, "material_id": consumer.material_id, "live": live, "budget_matches": budget_matches})
	if material_cache_consumers.is_empty(): issues.append("no actual installed SurfacePass cache consumer was observed")
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var draw := node as MeshInstance3D
		var boundary := _material_boundary(draw)
		if boundary.is_empty() or draw.mesh == null: continue
		if boundary == "private": record.private_geometry += 1
		elif boundary == "actor": record.actor_geometry += 1
		var materials: Array = [draw.material_override]
		var excluded_ids: Array = []
		var draw_contaminated := false
		for index in draw.mesh.get_surface_count():
			materials.append(draw.get_surface_override_material(index))
		for material in materials:
			if material == null: continue
			excluded_ids.append(material.get_instance_id())
			var contaminated: bool = material.has_meta("living_storey") or material.has_meta("encroachment_case")
			if material is ShaderMaterial:
				for floor_id in enc.fields:
					contaminated = contaminated or material.get_shader_parameter("living_tex") == enc.fields[floor_id].texture()
			if contaminated:
				draw_contaminated = true
				issues.append("excluded actual geometry acquired building field/owner: " + str(world.get_path_to(draw)))
		record.excluded_draws.append({"path": str(world.get_path_to(draw)), "boundary": boundary,
			"material_ids": excluded_ids, "contaminated": draw_contaminated})
	if record.private_geometry == 0 or record.actor_geometry == 0:
		issues.append("actual private and actor exclusion populations must both be nonempty")
	if exercise_refresh:
		record.refresh = _exercise_actual_material_refresh(enc)
		if record.refresh.passed != true: issues.append("immediate actual state/lifecycle consumer or restoration failure")
	record.issues = issues
	material_observations.append(record)
	_check("material " + stage + " actual build and installed ownership invariants", issues.is_empty())


func _material_boundary(draw: Node) -> String:
	var cursor := draw
	while cursor != null and cursor != world:
		if cursor is SubViewport: return "private"
		if cursor is CharacterBody3D or cursor.is_in_group("resident_placeholders") \
			or cursor.is_in_group("animated_residents") or str(cursor.name).begins_with("NPC_"):
			return "actor"
		if cursor.is_queued_for_deletion(): return "retiring"
		cursor = cursor.get_parent()
	return "" if cursor == world else "detached"


func _material_layered(material: ShaderMaterial) -> bool:
	return material != null and material.shader != null \
		and material.shader.resource_path.get_file().begins_with("orison_surface")


func _material_field_matches(material: ShaderMaterial, floor_id: String, enc) -> bool:
	if not enc.fields.has(floor_id): return false
	var field = enc.fields[floor_id]
	return material.get_shader_parameter("has_living") == true \
		and material.get_shader_parameter("living_tex") == field.texture() \
		and material.get_shader_parameter("living_origin") == field.origin \
		and material.get_shader_parameter("living_size") == field.size_m


func _material_authored_unit(unit: String) -> Dictionary:
	var bounds := Rect2()
	var found := false
	var floor_id := ""
	for floor_data in world.layout.floors:
		for room in floor_data.get("rooms", []):
			if str(room.get("unit", "")) != unit: continue
			var r: Array = room.rect
			var rect := Rect2(Vector2(float(r[0]), -float(r[3])), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))
			bounds = bounds.merge(rect) if found else rect
			found = true
			floor_id = str(floor_data.id)
	if not found: return {}
	return {"floor": floor_id, "rect": Vector4(bounds.position.x, bounds.position.y, bounds.end.x, bounds.end.y)}


func _exercise_actual_material_refresh(enc) -> Dictionary:
	var forced: Dictionary = enc._forced
	var forced_values: Dictionary = forced.duplicate(true)
	var facts: Dictionary = RealityState.data.duplicate(true)
	var before_state := _actual_material_state_snapshot(enc)
	var before_beachheads := _material_beachhead_snapshot(enc)
	var before_intensities: Dictionary = enc.intensities.duplicate(true)
	var precondition := _material_refresh_precondition(enc, before_beachheads)
	# A high-side inherited force or active beachhead can replace/retire an
	# override during refresh. Refuse before assigning or refreshing anything.
	if precondition.passed != true:
		return {"passed": false, "mutated": false, "precondition": precondition,
			"facts_unchanged": RealityState.data == facts, "before_state": before_state,
			"after_state": _actual_material_state_snapshot(enc), "before_beachheads": before_beachheads,
			"after_beachheads": _material_beachhead_snapshot(enc), "before_forced": forced_values,
			"after_forced": enc._forced.duplicate(true), "before_intensities": before_intensities,
			"after_intensities": enc.intensities.duplicate(true), "tested_current_materials": 0,
			"scope": "unsafe initial threshold side refused; no force assignment, refresh or gameplay write"}
	var poisoned := {}
	var okay := true
	# Under the beachhead threshold; synchronous probe and restoration occur
	# before another physics/render frame. No alternate finish/prop is made.
	enc._forced = forced.duplicate(true)
	for index in MATERIAL_CASE_UNITS.size():
		var case_id: String = MATERIAL_CASE_UNITS.keys()[index]
		enc._forced[case_id] = MATERIAL_PROBE_INTENSITIES[index]
	enc.refresh()
	var during_beachheads := _material_beachhead_snapshot(enc)
	okay = okay and before_beachheads == during_beachheads
	for case_id in MATERIAL_CASE_UNITS:
		var value: float = enc._forced[case_id]
		var floor_id := str(_material_authored_unit(MATERIAL_CASE_UNITS[case_id]).get("floor", ""))
		for row in enc.surfaces.get(case_id, []):
			var draw := row.mesh as MeshInstance3D
			if not is_instance_valid(draw) or draw.mesh == null or not world.is_ancestor_of(draw):
				okay = false
				continue
			var slot := int(row.surface)
			if slot < 0 or slot >= draw.mesh.get_surface_count():
				okay = false
				continue
			var material := draw.get_surface_override_material(slot) as ShaderMaterial
			if material == null:
				okay = false
				continue
			okay = okay and material == row.material and _material_number_equals(material.get_shader_parameter("intensity"), value)
			if not poisoned.has(material.get_instance_id()):
				poisoned[material.get_instance_id()] = {"material": material, "value": material.get_shader_parameter("living_lifecycle_stage"), "floor": floor_id}
			material.set_shader_parameter("living_lifecycle_stage", -17.0)
		for row in enc.prop_rows.get(case_id, []):
			var draw := row.mesh as MeshInstance3D
			if not is_instance_valid(draw) or not world.is_ancestor_of(draw):
				okay = false
				continue
			var material := draw.material_override as ShaderMaterial
			if material == null:
				okay = false
				continue
			var amount = material.get_shader_parameter("mask_amount")
			okay = okay and material == row.material and amount is Vector4 \
				and amount.is_equal_approx(Vector4(0, 0.35 * value, 0.25 * value, 0))
			if not poisoned.has(material.get_instance_id()):
				poisoned[material.get_instance_id()] = {"material": material, "value": material.get_shader_parameter("living_lifecycle_stage"), "floor": floor_id}
			material.set_shader_parameter("living_lifecycle_stage", -17.0)
	for floor_id in enc.fields:
		enc._push_living_lifecycle(floor_id, enc.fields[floor_id])
	for item in poisoned.values():
		if not enc.fields.has(item.floor):
			okay = false
			continue
		okay = okay and _material_number_equals(item.material.get_shader_parameter("living_lifecycle_stage"), float(enc.fields[item.floor].lifecycle_stage()))
	# Always restore even when a control fails; poisoning must not contaminate
	# subsequent captures or masquerade as a production visual difference.
	for item in poisoned.values(): item.material.set_shader_parameter("living_lifecycle_stage", item.value)
	enc._forced = forced
	enc.refresh()
	var after_state := _actual_material_state_snapshot(enc)
	var after_beachheads := _material_beachhead_snapshot(enc)
	var force_restored: bool = enc._forced == forced_values and forced == forced_values
	var intensities_restored: bool = enc.intensities == before_intensities
	okay = okay and RealityState.data == facts and before_state == after_state \
		and before_beachheads == after_beachheads and force_restored and intensities_restored
	return {"passed": okay, "mutated": true, "precondition": precondition,
		"tested_current_materials": poisoned.size(), "facts_unchanged": RealityState.data == facts,
		"same_frame_restored": before_state == after_state, "before_state": before_state, "after_state": after_state,
		"before_beachheads": before_beachheads, "during_beachheads": during_beachheads, "after_beachheads": after_beachheads,
		"before_forced": forced_values, "after_forced": enc._forced.duplicate(true), "force_restored": force_restored,
		"before_intensities": before_intensities, "after_intensities": enc.intensities.duplicate(true),
		"intensities_restored": intensities_restored,
		"scope": "actual installed build/prop rows; explicit production force hook and lifecycle push; no field tick or replacement geometry"}


func _material_refresh_precondition(enc, beachhead_state: Dictionary) -> Dictionary:
	var issues: Array = []
	var effective := {}
	var threshold: float = enc.BEACHHEAD_AT
	var actual_cases: Array = enc.surfaces.keys()
	var expected_cases: Array = MATERIAL_CASE_UNITS.keys()
	actual_cases.sort()
	expected_cases.sort()
	if actual_cases != expected_cases: issues.append("refresh scope differs from six declared cases")
	for case_id in MATERIAL_CASE_UNITS:
		var value: float = enc.intensity_for(case_id)
		effective[case_id] = value
		if not is_finite(value) or value < 0.0 or value >= threshold:
			issues.append("effective intensity is not below beachhead threshold: " + str(case_id))
		var installed = enc.intensities.get(case_id)
		if not _material_number_equals(installed, value):
			issues.append("recorded intensity is not current effective intensity: " + str(case_id))
	for value in MATERIAL_PROBE_INTENSITIES:
		if not is_finite(value) or value < 0.0 or value >= threshold:
			issues.append("declared probe value would cross beachhead threshold")
	for case_id in beachhead_state:
		var entry: Dictionary = beachhead_state[case_id]
		if entry.get("present", false) and (entry.get("live", false) != true or entry.get("original_count", -1) != 0):
			issues.append("beachhead is not live and inactive before force exercise: " + str(case_id))
	return {"passed": issues.is_empty(), "issues": issues, "threshold": threshold,
		"effective_intensities": effective, "probe_intensities": MATERIAL_PROBE_INTENSITIES,
		"environment": {"ENCROACH": OS.get_environment("ENCROACH"), "ENCROACH_FORCE": OS.get_environment("ENCROACH_FORCE")}}


func _material_beachhead_snapshot(enc) -> Dictionary:
	var snapshot := {}
	var keys: Array = MATERIAL_CASE_UNITS.keys()
	for case_id in enc.beachheads:
		if not keys.has(case_id): keys.append(case_id)
	for case_id in keys:
		if not enc.beachheads.has(case_id):
			snapshot[case_id] = {"present": false}
			continue
		var entry: Dictionary = enc.beachheads[case_id]
		var node := entry.get("node") as Node
		var live: bool = is_instance_valid(node) and world.is_ancestor_of(node) and _material_boundary(node).is_empty()
		var item := {"present": true, "live": live, "original_count": (entry.originals as Dictionary).size(), "draws": {}}
		if live:
			item.node_id = node.get_instance_id()
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var draw := child as MeshInstance3D
				if draw.mesh == null: continue
				var surfaces: Array = []
				for slot in draw.mesh.get_surface_count():
					var material := draw.get_active_material(slot)
					surfaces.append(material.get_instance_id() if material != null else 0)
				item.draws[str(world.get_path_to(draw))] = {"draw_id": draw.get_instance_id(), "mesh_id": draw.mesh.get_instance_id(),
					"override_id": draw.material_override.get_instance_id() if draw.material_override != null else 0, "active_material_ids": surfaces}
		snapshot[case_id] = item
	return snapshot


func _actual_material_state_snapshot(enc) -> Dictionary:
	var snapshot := {}
	for case_id in MATERIAL_CASE_UNITS:
		for row in enc.surfaces.get(case_id, []):
			var draw := row.mesh as MeshInstance3D
			if not is_instance_valid(draw) or not world.is_ancestor_of(draw) or draw.mesh == null: continue
			if int(row.surface) < 0 or int(row.surface) >= draw.mesh.get_surface_count(): continue
			var material := draw.get_surface_override_material(int(row.surface)) as ShaderMaterial
			if material == null: continue
			var key := str(world.get_path_to(draw)) + ":surface_" + str(row.surface)
			snapshot[key] = {"id": material.get_instance_id(), "intensity": material.get_shader_parameter("intensity"),
				"lifecycle": material.get_shader_parameter("living_lifecycle_stage")}
		for row in enc.prop_rows.get(case_id, []):
			var draw := row.mesh as MeshInstance3D
			if not is_instance_valid(draw) or not world.is_ancestor_of(draw): continue
			var material := draw.material_override as ShaderMaterial
			if material == null: continue
			var amount = material.get_shader_parameter("mask_amount")
			var amount2 = material.get_shader_parameter("mask2_amount")
			snapshot[str(world.get_path_to(draw)) + ":override"] = {"id": material.get_instance_id(),
				"amount": [amount.x, amount.y, amount.z, amount.w] if amount is Vector4 else null,
				"amount2": [amount2.x, amount2.y, amount2.z, amount2.w] if amount2 is Vector4 else null,
				"lifecycle": material.get_shader_parameter("living_lifecycle_stage")}
	return snapshot


func _material_number_equals(value, expected: float) -> bool:
	return (value is int or value is float) and is_equal_approx(float(value), expected)


func _check_material_retirement() -> void:
	if selected != "v1":
		material_retirement = {"applicable": false, "reason": "V2 does not compose this ApartmentEncroachment owner"}
		return
	var retained: Array = []
	for material_id in material_case_refs:
		if material_case_refs[material_id].get_ref() != null: retained.append(material_id)
	material_retirement = {"applicable": true, "owned_case_materials_observed": material_case_refs.size(),
		"retained_material_ids": retained, "released": material_case_refs.size() > 0 and retained.is_empty()}
	_check("material actual unique case materials retired with production root", material_retirement.released)
