extends Node
## Matched production-lighting stills at the PERF STATIONS, so a
## shadow policy's visual cost and its frame-time benefit are measured from
## the same viewpoints and can never quietly describe different places.
##
##     SHOT_DIR=C:/... [PERF_SHADOW_OFF=_furnish_]
##     godot --path game --resolution 1600x900 res://tests/ShadowPolicyShot.tscn
##
## The station list and the suppression pass are both READ FROM
## perf_probe.gd rather than copied. A copied station list drifts, and then
## the before/after render and the before/after measurement are of different
## cameras — which is exactly the class of error this whole check exists to
## avoid.
##
## Production lighting means production lighting: the same 64/16 budget the
## benchmark pins, the day/night director frozen so a pair differs by the
## policy alone, and no debug fill of any kind.

const PERF := preload("res://tests/perf_probe.gd")

var root: Node3D
var cam: Camera3D


func _ready() -> void:
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		push_error("[SHADOWSHOT] SHOT_DIR unset")
		get_tree().quit(1)
		return
	var mkdir_error := DirAccess.make_dir_recursive_absolute(dir)
	if mkdir_error != OK:
		push_error("[SHADOWSHOT] cannot create SHOT_DIR %s (%d)" % [dir, mkdir_error])
		get_tree().quit(1)
		return
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	var measured_shadow_budget := PERF.PINNED_SHADOW_BUDGET
	var shadow_override := OS.get_environment("PERF_SHADOW_BUDGET")
	if shadow_override != "":
		measured_shadow_budget = clampi(int(shadow_override),
				0, PERF.PINNED_LIGHT_BUDGET)
	root.light_rig.set_budgets(PERF.PINNED_LIGHT_BUDGET,
			measured_shadow_budget)
	await get_tree().create_timer(2.0).timeout
	for c in get_tree().root.get_children():
		_hide_ui(c)
	cam = Camera3D.new()
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	print("[SHADOWSHOT] resolved light/shadow budget %d/%d"
			% [root.light_rig._active_budget, root.light_rig._shadow_budget])
	PERF.apply_shadow_policy(root, self)
	await get_tree().create_timer(1.5).timeout

	var stations: Array = PERF.STATIONS
	var wanted := OS.get_environment("SHADOW_SHOT_STATION")
	if wanted != "":
		var needles: Array = Array(wanted.split("|", false))
		stations = PERF.STATIONS.filter(func(s):
			return needles.any(func(needle):
				return String(s["name"]).findn(needle) >= 0))
		if stations.is_empty():
			push_error("[SHADOWSHOT] unknown station %s" % wanted)
			get_tree().quit(1)
			return
	var i := 0
	for s in stations:
		i += 1
		_place_station(s)
		# Godot compiles shaders on first draw and streams floors off the
		# override camera; a single frame here photographs a half-built view.
		for j in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var slug := String(s["name"]).to_lower()
		for bad in [" ", "(", ")", "/"]:
			slug = slug.replace(bad, "_")
		var path := "%s/%02d_%s.png" % [dir, i, slug]
		var save_error := get_viewport().get_texture().get_image().save_png(path)
		if save_error != OK:
			push_error("[SHADOWSHOT] save_png %s returned %d" % [path, save_error])
			get_tree().quit(1)
			return
		print("[SHADOWSHOT] %02d %s" % [i, s["name"]])
	print("[SHADOWSHOT] %d stations saved" % i)
	get_tree().quit(0)


func _place_station(station: Dictionary) -> void:
	cam.global_position = station["pos"]
	cam.look_at(station["look"])
	var at_lens: bool = bool(station.get("player_at_lens", true))
	root.player.flashlight.visible = at_lens
	if not at_lens:
		root.view_override = cam
		return
	root.player.global_position = cam.global_position \
			- Vector3.UP * PlayerController.STANDING_EYE
	root.player.velocity = Vector3.ZERO
	root.player.set_physics_process(false)
	root.player.camera.global_transform = cam.global_transform
	root.view_override = null


func _hide_ui(n: Node) -> void:
	if n is CanvasLayer:
		n.visible = false
	if n is Label3D:
		n.visible = false
	for c in n.get_children():
		_hide_ui(c)
