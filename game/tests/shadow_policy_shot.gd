extends Node
## Matched production-lighting stills at the ELEVEN PERF STATIONS, so a
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
## Production lighting means production lighting: the same 16/16 budget the
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
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	root.light_rig.set_budgets(PERF.PINNED_LIGHT_BUDGET,
			PERF.PINNED_SHADOW_BUDGET)
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

	var i := 0
	for s in PERF.STATIONS:
		i += 1
		cam.global_position = s["pos"]
		cam.look_at(s["look"])
		# Godot compiles shaders on first draw and streams floors off the
		# override camera; a single frame here photographs a half-built view.
		for j in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var slug := String(s["name"]).to_lower()
		for bad in [" ", "(", ")", "/"]:
			slug = slug.replace(bad, "_")
		get_viewport().get_texture().get_image().save_png(
				"%s/%02d_%s.png" % [dir, i, slug])
		print("[SHADOWSHOT] %02d %s" % [i, s["name"]])
	print("[SHADOWSHOT] %d stations saved" % i)
	get_tree().quit(0)


func _hide_ui(n: Node) -> void:
	if n is CanvasLayer:
		n.visible = false
	if n is Label3D:
		n.visible = false
	for c in n.get_children():
		_hide_ui(c)
