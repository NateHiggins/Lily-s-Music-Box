extends Node
## MX-1 — the layered surface, proved on the flashlight's surfaces. Photographs
## the masonry walls and the compiled wall finishes of a storey from fixed
## stands under the carried torch, tier by tier, and prices each tier on the
## GPU. Frames, not adjectives (the M-COVER discipline, same harness shape).
##
##     SURF_DIR=<existing abs dir> godot --path game res://tests/SurfaceShot.tscn
##     SURF_STATIONS=bed_2a,cellar          optional filter by station key
##     SURF_OPTIONS=current,base,full       optional filter by option key
##     SURFACE_PROPS=1                      the draw-heavy tiers (furnishing
##                                          classes, batched props) take part
##     SURF_SETTLE_S=12                     seconds to let the world run before
##                                          each stand is framed (the living
##                                          field grows in real time)
##     SURF_PROP_STATE=oxide:0.8            "ship" also puts a state on every
##                                          layered prop at the stand (oxide,
##                                          gild, corrupt, grime, moisture,
##                                          wear, damage) — metal states on metal
##
## Boot and lighting are FreeCam's: production fixtures, the player's torch
## carried on the camera, no judging fill. Between the options of one stand
## only the MATERIAL of the `*_walls*` and `*_finish_*` surfaces changes:
## every option is built from the surface's own shipping maps and scalars, so
## "current" (StandardMaterial3D) and "base" (orison_surface with every layer
## off) differ only by the pipeline, and each further option differs from
## "base" by exactly the layers it names.
##
## Every option is built by SurfacePass.surface_for — the production builder
## — so what this photographs is what ships; the recipes here are the A/B.

const SAMPLE_FRAMES := 48
## The production builder (preloaded: a fresh class_name is not in the
## global class cache until the project is re-imported).
const SurfacePassScript := preload("res://scripts/building/surface_pass.gd")
const SETTLE_FRAMES := 4

## Stands: eye 1.55 m over the storey's floor, facing a perimeter wall.
const STATIONS := [
	# 2A is at Godot z +0.45..+9.65 (the layout's y is -z); the first frames
	# of this harness stood in 2D by mistake.
	{"key": "bed_2a", "floor": "F02", "pos": Vector3(-9.6, 1.55, 7.0),
			"yaw": 180.0, "pitch": -4.0, "room": "F02_A_BED"},
	{"key": "main_2a_west", "floor": "F02", "pos": Vector3(-10.4, 1.55, 3.4),
			"yaw": 90.0, "pitch": -3.0, "room": "F02_A_MAIN"},
	{"key": "bed_2a_graze", "floor": "F02", "pos": Vector3(-13.0, 1.45, 6.6),
			"yaw": 152.0, "pitch": -6.0, "room": "F02_A_BED"},
	{"key": "corridor", "floor": "F04", "pos": Vector3(4.3, 1.55, 7.6),
			"yaw": 0.0, "pitch": -2.0, "room": "F04_CORRIDOR"},
	{"key": "cellar", "floor": "B1", "pos": Vector3(9.6, 1.55, 4.0),
			"yaw": -90.0, "pitch": -3.0, "room": "B1_BOILER"},
	{"key": "lobby", "floor": "F01", "pos": Vector3(-0.4, 1.72, 9.1),
			"yaw": -58.0, "pitch": -6.0, "room": "F01_LOBBY"},
	{"key": "flat_4b", "floor": "F04", "pos": Vector3(-8.1, 1.55, -3.2),
			"yaw": 47.0, "pitch": -8.0, "room": "F04_B_MAIN"},
	# The F02 corridor outside 2A, where the organism goes when it leaves the flat.
	{"key": "corridor_2", "floor": "F02", "pos": Vector3(-4.2, 1.55, 5.4),
			"yaw": 90.0, "pitch": -6.0, "room": "F02_CORRIDOR", "demo": true},
	# The dream tentacle out of 2A's west wall by the sofa (TENTACLE_FORCE=1).
	{"key": "tentacle_2a", "floor": "F02", "pos": Vector3(-11.9, 1.35, 4.0),
			"yaw": 78.0, "pitch": -6.0, "room": "F02_A_MAIN", "demo": true},
	{"key": "tentacle_2a_close", "floor": "F02", "pos": Vector3(-12.7, 1.2, 4.25),
			"yaw": 96.0, "pitch": -8.0, "room": "F02_A_MAIN", "demo": true},
	# Metal close: the 4B kitchen's stove and taps, and a radiator.
	{"key": "kitchen_4b", "floor": "F04", "pos": Vector3(-8.6, 1.45, -7.6),
			"yaw": 160.0, "pitch": -12.0, "room": "F04_B_KITCHEN", "demo": true},
	{"key": "radiator_2a", "floor": "F02", "pos": Vector3(-11.8, 1.15, 4.6),
			"yaw": 105.0, "pitch": -18.0, "room": "F02_A_MAIN", "demo": true},
	# The six case flats, each facing a perimeter finish (WK-1 grammars).
	{"key": "flat_4a", "floor": "F04", "pos": Vector3(-9.6, 1.55, 7.0),
			"yaw": 180.0, "pitch": -4.0, "room": "F04_A_BED", "demo": true},
	{"key": "flat_2c", "floor": "F02", "pos": Vector3(9.6, 1.55, -3.0),
			"yaw": -90.0, "pitch": -3.0, "room": "F02_C_MAIN", "demo": true},
	{"key": "flat_6c", "floor": "F06", "pos": Vector3(9.6, 1.55, -3.0),
			"yaw": -90.0, "pitch": -3.0, "room": "F06_C_MAIN", "demo": true},
	{"key": "flat_5b", "floor": "F05", "pos": Vector3(-9.6, 1.55, -4.6),
			"yaw": 90.0, "pitch": -3.0, "room": "F05_B_MAIN", "demo": true},
	{"key": "flat_3b", "floor": "F03", "pos": Vector3(-9.6, 1.55, -4.6),
			"yaw": 90.0, "pitch": -3.0, "room": "F03_B_MAIN", "demo": true},
	# Floors (the M-COVER stands), now a class of the same surface.
	{"key": "corridor_floor", "floor": "F04", "pos": Vector3(4.3, 1.05, 5.2),
			"yaw": 0.0, "pitch": -34.0, "room": "F04_CORRIDOR"},
	{"key": "oak_floor", "floor": "F04", "pos": Vector3(-9.0, 1.05, -5.6),
			"yaw": 35.0, "pitch": -38.0, "room": "F04_B_MAIN"},
	# Close, along the wall: where a height tier shows or does not.
	{"key": "brick_close", "floor": "F02", "pos": Vector3(-8.3, 1.30, 8.75),
			"yaw": 125.0, "pitch": -8.0, "room": "F02_A_BED", "demo": true},
	{"key": "cellar_close", "floor": "B1", "pos": Vector3(12.55, 1.30, 2.6),
			"yaw": -118.0, "pitch": -6.0, "room": "B1_BOILER", "demo": true},
]

## Each option is a recipe of shader parameters over the "base" material.
const OPTIONS := [
	{"key": "current", "label": "shipping StandardMaterial3D", "recipe": null},
	{"key": "base", "label": "orison_surface, every layer off (control)", "recipe": {}},
	{"key": "ship", "label": "the class recipe as SurfacePass ships it", "recipe": {"__class__": true}},
	{"key": "ship_nomask", "label": "the class recipe without its standing-age masks", "recipe": {"__class__": true, "__nomask__": true}},
	{"key": "offset", "label": "+ height tier, offset parallax", "recipe": {"parallax_mode": 1}},
	{"key": "pom", "label": "+ height tier, POM", "recipe": {"parallax_mode": 2}},
	{"key": "detail", "label": "+ detail tier (self, 3.718x)", "recipe": {"has_detail": true}},
	{"key": "masks", "label": "+ masks: grime, moisture, wear, damage (procedural)",
			"recipe": {"mask_amount": Vector4(0.25, 0.55, 0.35, 0.35),
					"mask_threshold": Vector4(0.72, 0.45, 0.60, 0.50),
					"mask_softness": Vector4(0.08, 0.30, 0.20, 0.25)}},
	{"key": "full", "label": "POM + detail + masks",
			"recipe": {"parallax_mode": 2, "has_detail": true,
					"mask_amount": Vector4(0.25, 0.55, 0.35, 0.35),
					"mask_threshold": Vector4(0.72, 0.45, 0.60, 0.50),
					"mask_softness": Vector4(0.08, 0.30, 0.20, 0.25)}},
	{"key": "full_fields", "label": "the mask fields of 'full' (debug view)",
			"recipe": {"parallax_mode": 2, "has_detail": true, "debug_view": 1,
					"mask_amount": Vector4(0.25, 0.55, 0.35, 0.35),
					"mask_threshold": Vector4(0.72, 0.45, 0.60, 0.50),
					"mask_softness": Vector4(0.08, 0.30, 0.20, 0.25)}},
	{"key": "pom_x25", "label": "POM at 2.5x the calibrated relief (the exaggeration to judge)",
			"recipe": {"parallax_mode": 2, "relief_mul": 2.5}, "demo_only": true},
	{"key": "st_grime", "label": "state demo: grime 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask_amount": Vector4(0.0, 0.9, 0.0, 0.0), "mask_threshold": Vector4(0.5, 0.5, 0.5, 0.5), "mask_softness": Vector4(0.3, 0.3, 0.3, 0.3)}},
	{"key": "st_moisture", "label": "state demo: moisture 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask_amount": Vector4(0.0, 0.0, 0.9, 0.0), "mask_threshold": Vector4(0.5, 0.5, 0.5, 0.5), "mask_softness": Vector4(0.3, 0.3, 0.3, 0.3)}},
	{"key": "st_wear", "label": "state demo: wear 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask_amount": Vector4(0.0, 0.0, 0.0, 0.9), "mask_threshold": Vector4(0.5, 0.5, 0.5, 0.5), "mask_softness": Vector4(0.3, 0.3, 0.3, 0.3)}},
	{"key": "st_damage", "label": "state demo: damage 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask_amount": Vector4(0.9, 0.0, 0.0, 0.0), "mask_threshold": Vector4(0.55, 0.55, 0.55, 0.55), "mask_softness": Vector4(0.1, 0.1, 0.1, 0.1)}},
	{"key": "st_oxide", "label": "state demo: oxidation 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask2_amount": Vector4(0.9, 0.0, 0.0, 0.0), "mask2_threshold": Vector4(0.5, 0.5, 0.5, 0.5), "mask2_softness": Vector4(0.3, 0.3, 0.3, 0.3)}},
	{"key": "st_gild", "label": "state demo: gilding 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask2_amount": Vector4(0.0, 0.9, 0.0, 0.0), "mask2_threshold": Vector4(0.5, 0.5, 0.5, 0.5), "mask2_softness": Vector4(0.2, 0.2, 0.2, 0.2)}},
	{"key": "st_corrupt", "label": "state demo: corruption 0.9", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask2_amount": Vector4(0.0, 0.0, 0.9, 0.0), "mask2_threshold": Vector4(0.45, 0.45, 0.45, 0.45), "mask2_softness": Vector4(0.3, 0.3, 0.3, 0.3)}},
	{"key": "st_emit", "label": "state demo: emission mask 0.9 (amber)", "demo_only": true,
			"recipe": {"parallax_mode": 2, "mask_proc_scale": 2.2, "mask2_amount": Vector4(0.0, 0.0, 0.0, 0.9), "mask2_threshold": Vector4(0.55, 0.55, 0.55, 0.55), "mask2_softness": Vector4(0.2, 0.2, 0.2, 0.2), "emission_color": Color(1.0, 0.62, 0.25), "emission_energy": 1.6}},
	{"key": "corrupted", "label": "full + corruption and gilding states (supernatural on top)",
			"recipe": {"parallax_mode": 2, "has_detail": true,
					"mask_amount": Vector4(0.25, 0.55, 0.35, 0.35),
					"mask_threshold": Vector4(0.72, 0.45, 0.60, 0.50),
					"mask_softness": Vector4(0.08, 0.30, 0.20, 0.25),
					"mask2_amount": Vector4(0.0, 0.5, 0.85, 0.0),
					"mask2_threshold": Vector4(0.55, 0.62, 0.50, 0.55),
					"mask2_softness": Vector4(0.15, 0.12, 0.28, 0.15)}},
]

var root
var cam: Camera3D
var _dir := ""
var _results := {}
var _cache := {}
var _overridden: Array = []
var _props_pass = SurfacePassScript.new()
var _floor_y := {}


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	_dir = OS.get_environment("SURF_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	_hide_overlays(root)
	for fl in root.layout.floors:
		_floor_y[str(fl.id)] = float(fl.z)
	var player: PlayerController = root.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 220.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	player.flashlight.visible = true
	player._light_mask.visible = true
	player.flashlight.reparent(cam)
	player.flashlight.transform = Transform3D(Basis(), Vector3(0.16, -0.19, -0.06))
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var station_filter := OS.get_environment("SURF_STATIONS").split(",", false)
	var option_filter := OS.get_environment("SURF_OPTIONS").split(",", false)
	_results = {"window": str(DisplayServer.window_get_size()),
			"renderer": RenderingServer.get_current_rendering_method(),
			"sample_frames": SAMPLE_FRAMES, "stations": {}}
	for station in STATIONS:
		if not station_filter.is_empty() and not station_filter.has(station.key):
			continue
		var pos: Vector3 = station.pos
		pos.y += float(_floor_y.get(str(station.floor), 0.0))
		_place(pos, station.yaw, station.pitch)
		_room_lights_on(str(station.room))
		await get_tree().create_timer(0.6).timeout
		var settle := OS.get_environment("SURF_SETTLE_S")
		if not settle.is_empty():
			await get_tree().create_timer(float(settle)).timeout
		# Warm every variant before anything is timed: first use compiles.
		for option in OPTIONS:
			if bool(option.get("demo_only", false)) and not bool(station.get("demo", false)):
				continue
			_apply_option(str(station.floor), option)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
		_restore()
		var rows := {}
		for option in OPTIONS:
			if not option_filter.is_empty() and not option_filter.has(option.key):
				continue
			if bool(option.get("demo_only", false)) and not bool(station.get("demo", false)):
				continue
			# Two timing passes, the lower median kept: the first option timed
			# at a stand pays for whatever the GPU was still settling.
			var gpu := INF
			var cpu := INF
			var swapped := 0
			for _pass in 2:
				swapped = _apply_option(str(station.floor), option)
				for _i in SETTLE_FRAMES:
					await RenderingServer.frame_post_draw
				var gpu_samples: Array[float] = []
				var cpu_samples: Array[float] = []
				for _i in SAMPLE_FRAMES:
					var t0 := Time.get_ticks_usec()
					await RenderingServer.frame_post_draw
					cpu_samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)
					gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
				gpu_samples.sort()
				cpu_samples.sort()
				gpu = min(gpu, gpu_samples[gpu_samples.size() / 2])
				cpu = min(cpu, cpu_samples[cpu_samples.size() / 2])
			var calls := RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var path := _dir.path_join("%s__%s.png" % [station.key, option.key])
			await RenderingServer.frame_post_draw
			var err := get_viewport().get_texture().get_image().save_png(path)
			rows[option.key] = {"label": option.label, "surfaces_swapped": swapped,
					"gpu_ms": gpu, "cpu_ms": cpu, "draw_calls": calls, "png": path,
					"save_error": err}
			print("[SURF] %-14s %-12s gpu %.3f ms  cpu %.3f ms  calls %d  swapped %d  %s"
					% [station.key, option.key, gpu, cpu, calls, swapped,
					"ok" if err == OK else "SAVE FAILED %d" % err])
			_restore()
		_results.stations[station.key] = rows
	var f := FileAccess.open(_dir.path_join("surface.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_results, "  "))
		print("[SURF] wrote %s" % _dir.path_join("surface.json"))
	print("[SURF] DONE")
	get_tree().quit(0)


func _place(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	cam.global_position = pos
	cam.rotation = Vector3.ZERO
	cam.rotate_y(deg_to_rad(yaw_deg))
	cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(pitch_deg))


func _room_lights_on(room_id: String) -> void:
	if room_id.is_empty() or not ("switch_system" in root) or root.switch_system == null:
		return
	if not root.switch_system.toggle_room(room_id):
		root.switch_system.toggle_room(room_id)


## Every wall and finish surface of one storey takes the option's material;
## the "current" option leaves the shipping materials in place.
func _apply_option(floor_id: String, option: Dictionary) -> int:
	_restore()
	if option.recipe == null:
		return 0
	var floor_node: Node = root.floor_nodes.get(floor_id)
	if floor_node == null:
		return 0
	var swapped := 0
	if SurfacePassScript.draw_heavy_enabled() and option.recipe.has("__class__"):
		swapped += _props_pass.apply_props(root)
		_prop_state_demo()
	for node in floor_node.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var cls := SurfacePassScript._class_for(mi.name)
		if cls.is_empty():
			continue
		if bool(cls.get("draw_heavy", false)) and not SurfacePassScript.draw_heavy_enabled():
			continue
		for s in mi.mesh.get_surface_count():
			var original := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if original == null or original.albedo_texture == null:
				continue
			if original.cull_mode != BaseMaterial3D.CULL_BACK:
				continue
			# Restore to the PREVIOUS override (the production pass, the
			# encroachment), never to null: "current" is production minus
			# this class, not a bare StandardMaterial3D.
			_overridden.append([mi, s, mi.get_surface_override_material(s)])
			mi.set_surface_override_material(s, _surface_for(original, option, cls))
			swapped += 1
	return swapped


## SURF_PROP_STATE=<state>:<amount> — a state on every layered prop draw in
## the tree (the production sweep's and this harness's), for the frames that
## show oxidation on iron and gilding on brass rather than on plaster.
func _prop_state_demo() -> void:
	var spec := OS.get_environment("SURF_PROP_STATE")
	if spec.is_empty():
		return
	var bits := spec.split(":")
	var state := bits[0]
	var amount := float(bits[1]) if bits.size() > 1 else 0.8
	var seen := {}
	var count := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		if m == null or m.shader == null or not m.shader.resource_path.get_file().begins_with("orison_surface"):
			continue
		if seen.has(m.get_instance_id()):
			continue
		seen[m.get_instance_id()] = true
		# Props only: the triplanar materials. Walls keep their standing age.
		if int(m.get_shader_parameter("uv_mode") if m.get_shader_parameter("uv_mode") != null else 0) != 1:
			continue
		var a1: Vector4 = m.get_shader_parameter("mask_amount") if m.get_shader_parameter("mask_amount") != null else Vector4.ZERO
		var a2: Vector4 = m.get_shader_parameter("mask2_amount") if m.get_shader_parameter("mask2_amount") != null else Vector4.ZERO
		match state:
			"damage": a1.x = amount
			"grime": a1.y = amount
			"moisture": a1.z = amount
			"wear": a1.w = amount
			"oxide": a2.x = amount
			"gild": a2.y = amount
			"corrupt": a2.z = amount
			"emit": a2.w = amount
		m.set_shader_parameter("mask_amount", a1)
		m.set_shader_parameter("mask2_amount", a2)
		m.set_shader_parameter("mask_proc_scale", 6.0)
		m.set_shader_parameter("mask2_threshold", Vector4(0.45, 0.50, 0.46, 0.55))
		m.set_shader_parameter("mask2_softness", Vector4(0.30, 0.20, 0.30, 0.15))
		count += 1
	print("[SURF] prop state demo %s=%.2f on %d materials" % [state, amount, count])


func _restore() -> void:
	_props_pass.restore_props()
	for entry in _overridden:
		(entry[0] as MeshInstance3D).set_surface_override_material(int(entry[1]), entry[2])
	_overridden.clear()


## One surface material per (shipping material, option) from the production
## builder, with the option's recipe on top.
func _surface_for(original: BaseMaterial3D, option: Dictionary, cls: Dictionary) -> ShaderMaterial:
	var recipe: Dictionary = option.recipe
	if recipe.has("__class__"):
		recipe = cls.recipe
		if option.recipe.has("__nomask__"):
			recipe = recipe.duplicate()
			recipe.erase("mask")
			recipe["mask_amount"] = Vector4.ZERO
	elif str(cls.key) == "floors":
		# The floors' coverage rule is part of their base look, not a tier.
		recipe = recipe.duplicate()
		recipe["coverage_rule"] = true
	return SurfacePassScript.surface_for(original, recipe, "%s|%s" % [option.key, cls.key], _cache)


func _hide_overlays(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasLayer:
			c.visible = false
		elif c is Label3D and (c.name == "Nameplate"
				or node.is_in_group("resident_placeholders")):
			c.visible = false
		_hide_overlays(c)
