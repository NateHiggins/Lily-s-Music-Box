extends "res://tests/harukiya_occupied_cost.gd"
## Reversible attribution only. No production quality change or budget waiver.
var attribution: Array = []
var fixture_states: Array = []
var light_states: Array = []
var view_states: Array = []
var rig_processing := false
var visibility_processing := false
var controls_owned := false
var light_inventory: Array = []
var control_labels: Array[String] = []
const WallPilot := preload("res://scripts/building/orison_v2_bar_occlusion.gd")
var wall_pilot: Node3D
var occlusion_mode := false
var occlusion_records: Array = []
var wall_original_enabled := false

func _opposition_programme() -> void:
	var mode := OS.get_environment("ORISON_COST_ATTRIBUTION")
	if not _check(mode in ["","groups","occlusion"],"declared attribution mode"): return
	control_labels.assign(["normal_a","drivers_frozen","directional_off","rig_off","other_off","shadows_restored_drivers_frozen","normal_return"] if mode == "groups" else ["normal_a","drivers_frozen","shadows_off","shadows_restored_drivers_frozen","normal_return"])
	occlusion_mode = mode == "occlusion"
	if occlusion_mode: control_labels.assign(["normal_a","wall_occlusion","normal_return"])
	if not await _prepare_cost_context(): return
	service_started = Time.get_ticks_msec(); service_active = true
	var reached: bool = await _go_service("gallery_return")
	service_active = false
	if not reached: return
	if not _check(bool(PlayerSupport.inspect(world.bar_region,world.player,world.player.global_position).get("supported",false)),"supported attribution stance"): return
	# Same route-facing heading2 as the original eight-view programme.
	world.player.rotation.y += PI
	world.player.camera.rotation = Vector3.ZERO
	rig_processing = world.light_rig.is_processing()
	visibility_processing = world.service_light_visibility.is_processing()
	for fixture: Node in world.light_rig._controlled_lights():
		fixture_states.append({"node":fixture,"processing":fixture.is_processing()})
	for light: Light3D in world.find_children("*","Light3D",true,false):
		var family := "directional" if light is DirectionalLight3D else "other"
		if family != "directional":
			for fixture: Dictionary in fixture_states:
				if fixture.node == light or fixture.node.is_ancestor_of(light): family = "rig"; break
		light_states.append({"node":light,"shadow":light.shadow_enabled,"family":family})
		light_inventory.append({"path":str(light.get_path()),"kind":light.get_class(),"family":family,
			"position":light.global_position,"shadow":light.shadow_enabled,"visible":light.is_visible_in_tree(),
			"energy":light.light_energy,"range":light.get_param(Light3D.PARAM_RANGE),
			"receiver_mask":light.light_cull_mask,"caster_mask":light.shadow_caster_mask})
	for view: SubViewport in world.find_children("*","SubViewport",true,false):
		view_states.append({"node":view,"path":str(view.get_path())})
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	controls_owned = true
	if occlusion_mode:
		wall_pilot = world.bar_region.wall_occlusion
		if not _check(is_instance_valid(wall_pilot),"installed production wall owner"): return
		wall_original_enabled = wall_pilot.enabled
		if not _check(wall_pilot.enabled and wall_pilot.errors.is_empty(),"production owner still valid after composed startup: "+str(wall_pilot.errors)): return
		occlusion_records = wall_pilot.records.duplicate(true)
		if not _check(get_viewport().use_occlusion_culling,"actual viewport occlusion enabled"): return
	for label: String in control_labels:
		if not _cohort_valid(): break
		_apply_control(label)
		var cohort: Dictionary = _cohort()
		timing = true
		for frame in WARM_FRAMES: await RenderingServer.frame_post_draw
		var row: Dictionary = await _measure_control(label)
		timing = false
		_check(_cohort_valid() and _cohort() == cohort,"unchanged active cohort across "+label)
		row.cohort = cohort
		if occlusion_mode:
			row.wall_occlusion_enabled = wall_pilot.enabled
			row.viewport_occlusion_enabled = get_viewport().use_occlusion_culling
			var image: Image = get_viewport().get_texture().get_image()
			var path: String = directory.path_join(label+".png")
			_check(image != null and image.save_png(path)==OK,"actual post-timing occlusion capture "+label)
			row.capture = path
		attribution.append(row)
		print("HARUKIYA ATTRIBUTION ",label," median_ms=",row.wall_ms.median," shadow_draws=",row.shadow_draws.median)
		if not failures.is_empty(): break
	_restore_controls()
	_check(attribution.size() == control_labels.size(),"all attribution controls and A/A return collected")
	# Original budget failure remains authoritative; controls are not passing substitutes.

func _apply_control(label: String) -> void:
	if occlusion_mode:
		if is_instance_valid(wall_pilot): wall_pilot.set_enabled(label == "wall_occlusion")
		return
	var frozen: bool = label not in ["normal_a","normal_return"]
	world.light_rig.set_process(false if frozen else rig_processing)
	world.service_light_visibility.set_process(false if frozen else visibility_processing)
	for row: Dictionary in fixture_states:
		row.node.set_process(false if frozen else row.processing)
	for row: Dictionary in light_states:
		row.node.shadow_enabled = false if _suppressed(label,row.family) else row.shadow

func _suppressed(label: String, family: String) -> bool:
	return label == "shadows_off" or label == family+"_off"

func _measure_control(label: String) -> Dictionary:
	var rid: RID = get_viewport().get_viewport_rid()
	var raw: Array = []
	var columns: Array = [[],[],[],[],[],[]]
	var private_samples: Dictionary = {}
	for row: Dictionary in view_states: private_samples[row.path] = []
	var previous: int = Time.get_ticks_usec()
	for frame in COST_FRAMES:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var values: Array = [float(now-previous)/1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(rid),
			RenderingServer.viewport_get_measured_render_time_gpu(rid),
			RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(rid,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
		previous = now; raw.append(values)
		for index in 6: columns[index].append(float(values[index]))
		for row: Dictionary in view_states:
			var view: SubViewport = row.node
			private_samples[row.path].append([view.render_target_update_mode,
				RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())])
	if label.ends_with("_off"):
		for row: Dictionary in light_states:
			var expected: bool = false if _suppressed(label,row.family) else row.shadow
			_check(row.node.shadow_enabled == expected,"shadow group control remains applied: "+str(row.node.get_path()))
	_check(world.find_children("*","Light3D",true,false).size() == light_states.size(),"light inventory unchanged across "+label)
	return {"label":label,"camera":world.player.camera.global_transform,"frames":COST_FRAMES,
		"columns":["wall_ms","main_cpu_ms","main_gpu_ms","main_visible_draws","main_shadow_draws","total_draws"],
		"samples":raw,"wall_ms":_distribution(columns[0]),"cpu_ms":_distribution(columns[1]),
		"gpu_ms":_distribution(columns[2]),"visible_draws":_distribution(columns[3]),
		"shadow_draws":_distribution(columns[4]),"total_draws":_distribution(columns[5]),
		"private_columns":["update_mode","cpu_ms","gpu_ms"],"private_samples":private_samples}

func _restore_controls() -> void:
	if not controls_owned: return
	_apply_control("normal_return")
	if is_instance_valid(wall_pilot):
		wall_pilot.set_enabled(wall_original_enabled)
		_check(wall_pilot.enabled == wall_original_enabled,"production wall owner original enable state restored")
		wall_pilot = null
	_check(world.light_rig.is_processing() == rig_processing and world.service_light_visibility.is_processing() == visibility_processing,"light policy processing restored")
	for row: Dictionary in fixture_states:
		_check(row.node.is_processing() == row.processing,"fixture processing restored: "+str(row.node.get_path()))
	for row: Dictionary in light_states:
		_check(row.node.shadow_enabled == row.shadow,"original shadow flag restored: "+str(row.node.get_path()))
	for row: Dictionary in view_states:
		RenderingServer.viewport_set_measure_render_time(row.node.get_viewport_rid(),false)
	controls_owned = false

func _finish() -> void:
	_restore_controls()
	await super._finish()

func _decorate_result(result: Dictionary) -> void:
	super._decorate_result(result)
	result.suite = "HarukiyaCostAttribution"
	result.scope = "Reversible gallery heading2 rendering attribution; controls are not production quality changes or budget passes. Original occupied_cost_01 failure remains. Diagnostic observer suspended during timing."
	result.details.attribution = attribution
	result.details.light_inventory = light_inventory
	result.details.control_labels = control_labels
	result.details.occlusion_pilot_records = occlusion_records
	result.details.occlusion_mode = occlusion_mode
	result.details.controls_restored = not controls_owned

