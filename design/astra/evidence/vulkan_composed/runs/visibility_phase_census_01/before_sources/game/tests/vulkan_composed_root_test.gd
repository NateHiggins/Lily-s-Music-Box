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
	# Both direct portal orders and return to the apartment corridor; each
	# transition samples synchronous work AND the next four rendered frames.
	for cycle in CYCLES:
		for index in [0, 1, 0, 2, 3, 2]:
			await _transition(STATIONS[index], cycle, false)
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

func _transition(station: Dictionary, cycle: int, take_capture: bool) -> void:
	_phase("transition_%s_%d" % [station.key, cycle])
	player.global_position = station.zone
	camera.global_position = station.eye
	camera.look_at(station.look)
	var started := Time.get_ticks_usec()
	world._apply_visibility(station.zone)
	var apply_usec := Time.get_ticks_usec() - started
	var phase_profile: Dictionary = world._astra_visibility_profile.duplicate(true)
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
		"encroachment_material_census": _encroachment_material_census(),
		"phase_profile": phase_profile, "apply_usec": apply_usec, "repeated_scan_count": 16, "repeated_scan_usec": repeated_usec, "frames": frames})
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
	_phase("after_retirement")
	arcade_masks.clear() # Only IDs/masks/RID values were retained, no World3D owner.
	var receipt := {"schema": "astra.vulkan_composed.probe.v2", "root": selected, "variant": variant, "execution_scope": execution_scope,
		"separate_world_case_executed": selected == "v1" and execution_scope == "full",
		"pid": OS.get_process_id(), "renderer": RenderingServer.get_current_rendering_method(),
		"functional_failures": failed, "checks": checks, "captures": captures,
		"transitions": transitions, "populations": populations, "subviews": subviews, "owned_controls": controls, "arcade_observations": arcade_observations,
		"scope": "actual root composition, controlled teleports, source-bound script and rendered transition smoke measurements; stderr and images require independent external review",
		"v2_street_passage_applicability": "absent", "no_op_native_call_count_proven": false,
		"native_diagnostics_accepted": false}
	var file := FileAccess.open(output.path_join("probe.json"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("[VULKAN COMPOSED] checks=%d failures=%d" % [checks.size(), failed])
	get_tree().quit(0 if failed == 0 else 1)


# Diagnostic-only census, evaluated after both transition-frame and no-op
# timers stop. Array slots are not unique material resource ownership.
func _encroachment_material_census() -> Dictionary:
	var output: Dictionary = {}
	var encroachment := world.get("apartment_encroachment") as Node
	if encroachment == null:
		return {"owner_missing": true}
	var storeys: Dictionary = encroachment.get("storey_materials")
	for floor_id: Variant in storeys:
		var slots: Array = storeys[floor_id]
		var unique: Dictionary = {}
		var invalid := 0
		for material: Variant in slots:
			if is_instance_valid(material):
				unique[str(material.get_instance_id())] = true
			else:
				invalid += 1
		output[str(floor_id)] = {"slots": slots.size(), "unique_count": unique.size(),
			"duplicate_slots": slots.size() - unique.size() - invalid,
			"invalid_slots": invalid, "material_instance_ids": unique.keys()}
	return output
