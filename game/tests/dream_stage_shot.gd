extends Node
## Captures the staged Dream ecology (§34).
##     SHOT_SECONDS=20 godot --path game res://tests/DreamStageShot.tscn
const StageScript := preload("res://tests/dream_stage.gd")

var stage
var _dir := ""
var _frame := 0


func _ready() -> void:
	stage = StageScript.new()
	add_child(stage)
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = "user://dream_stage"
	DirAccess.make_dir_recursive_absolute(_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	call_deferred("_run")


## THE SALIVA, ACROSS ONE PATCH'S WHOLE LIFE, AND FROM THREE ANGLES AT ONCE.
##
## DREAM_SALIVA_DIRECTION sets two acceptance tests that a normal take cannot
## settle. The decay has to read as EROSION rather than as opacity going down,
## which needs the same patch photographed at known ages; and the colour has to
## be structural, which needs the SAME patch at the SAME age from more than one
## place -- "if it looks the same from two angles it is a painted rainbow and
## has failed". A patch laid by the creature wherever it happens to reach can
## give neither, so this lays one by hand on a flat panel and stands in front
## of it.
const SALIVA_AT := Vector3(-0.6, 1.15, 1.52)
const SALIVA_N := Vector3(0.0, 0.0, -1.0)


func _saliva_life() -> void:
	# Nobody else touches anything while this is running.
	stage.hero.set_process(false)
	# THE PANEL IS DELIBERATELY PALE -- it is a backdrop, chosen so a seam
	# grazer reads against it -- and the player's lamp is 5.5 at the lens. A
	# metre away that clips the panel to flat white, which is fine for a
	# gameplay frame and useless for judging a material against its
	# surroundings. Dimmed for this capture only, and only enough to hold the
	# panel; the goo is still lit by the player's own lamp from the player's
	# own position, which is the part the acceptance note cares about.
	stage.lamp.light_energy = 2.2
	var life := 6.0
	stage.residue.lay(SALIVA_AT, SALIVA_N, 0.17, 1.0, life)
	# IN FRONT OF THE PANEL, NOT BEHIND IT. The normal points away from the
	# surface, so the viewer stands ALONG it; subtracting put the lens outside
	# the room photographing the back of a wall, and a big soft bright disc in
	# the dark looks enough like an overexposed patch of goo to be believed.
	stage.camera.global_position = SALIVA_AT + SALIVA_N * 1.05 + Vector3.UP * 0.06
	stage.camera.look_at(SALIVA_AT, Vector3.UP)
	var was := 0.0
	for age in [0.25, 0.7, 1.3, 2.1, 3.0, 4.0, 5.2]:
		await get_tree().create_timer(maxf(0.02, float(age) - was)).timeout
		was = float(age)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("S_age%.2f.png" % float(age)))
		_frame += 1
		print("[stage] saliva age %.2f  %s" % [float(age), stage.residue.census()])
	# THE SAME PATCH, THE SAME INSTANT, THREE PLACES. A fresh one, held at the
	# age where the structural colour is strongest, and the camera moved
	# WITHOUT time passing -- so anything that differs between these frames is
	# the view angle and nothing else.
	stage.residue.lay(SALIVA_AT, SALIVA_N, 0.17, 1.0, life)
	await get_tree().create_timer(1.1).timeout
	get_tree().paused = true
	var arc := [-0.62, 0.0, 0.62]
	for i in arc.size():
		var a: float = float(arc[i])
		var eye: Vector3 = SALIVA_AT + Vector3(sin(a), 0.10, -cos(a)) * 1.05
		stage.camera.global_position = eye
		stage.camera.look_at(SALIVA_AT, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("S_angle%d.png" % i))
		_frame += 1
		print("[stage] saliva angle %.2f rad from %s" % [a, eye])
	get_tree().paused = false


## THE ARRIVAL, HELD STILL AT EACH RUNG.
##
## `grow` runs nought to one in 2.4 seconds. That is too fast to judge live and
## too easy to get backwards -- a limb filling in from the tip and a limb
## extruding from the root are the same picture in any single frame. So the
## state machine is stopped and the parameter is driven by hand, from the one
## stand in the room that holds the wall it comes through and the length it
## reaches, in the same shot.
##
## The apartment cannot take this picture: every flat in the building puts a
## partition or a door frame across the limb about a third of the way along,
## and behind it 0.33 and 0.67 are the same photograph. That is what the room
## in §34 is for.
func _emergence_ladder() -> void:
	var stand: Dictionary = stage.side_stand()
	stage.camera.global_position = stand.eye
	stage.camera.look_at(stand.look, Vector3.UP)
	print("[stage] ladder stand %s -> %s" % [stand.eye, stand.look])
	stage.hero.set_process(false)
	for step in 9:
		var g := float(step) / 8.0
		stage.hero.grow = g
		for mat in stage.hero.materials:
			mat.set_shader_parameter("grow", g)
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("E%d_grow%.2f.png" % [step, g]))
		_frame += 1
		print("[stage] grow %.2f" % g)


func _run() -> void:
	# Let the ecology populate the room before rolling.
	var warm := 14.0
	var w := OS.get_environment("SHOT_WARM")
	if not w.is_empty():
		warm = maxf(2.0, w.to_float())
	var stand: Dictionary = stage.wide_stand()
	stage.camera.global_position = stand.eye
	stage.camera.look_at(stand.look, Vector3.UP)
	await get_tree().create_timer(warm).timeout
	print("[stage] populated: %s" % [stage.census()])

	if OS.get_environment("SHOT_MODE") == "saliva":
		await _saliva_life()
		print("[stage] DONE %d frames -> %s" % [_frame, _dir])
		get_tree().quit(0)
		return
	if OS.get_environment("SHOT_MODE") == "emerge":
		await _emergence_ladder()
		print("[stage] DONE %d frames -> %s" % [_frame, _dir])
		get_tree().quit(0)
		return

	var seconds := 20.0
	var s := OS.get_environment("SHOT_SECONDS")
	if not s.is_empty():
		seconds = maxf(1.0, s.to_float())
	var fps := 24
	var frames := int(seconds * fps)
	# THE TAKE OPENS WITH IT ARRIVING. Forcing it to SEEKING guaranteed it was
	# visible but skipped §2's first two states entirely, and a thing coming
	# through from somewhere else should not simply be present in frame one.
	# MEMBRANE_BULGE swells the root, EMERGING extrudes the limb.
	stage.hero.state = 10                 # MEMBRANE_BULGE
	stage.hero.state_clock = 0.0
	stage.hero.slice_close = 0.0
	stage.hero.grow = 0.0
	var seen := {"branch": false, "attention": false, "twin": false,
			"fold": false, "residue": false, "brave": false, "shoved": false,
			"emerged": false, "watched_player": false, "flinched": false,
			"minded_critter": false, "noticed_margin": false, "tasted": false}
	print("[stage] rolling %d frames" % frames)
	for f in frames:
		var t := float(f) / float(fps)
		# A slow push in and across, staying inside the room.
		# The push ends close: near enough that the creature notices the
		# viewpoint and stops to look back, which is §2's WATCH_PLAYER and the
		# most unsettling thing it does.
		var eye: Vector3 = (stand.eye as Vector3).lerp(
				Vector3(-0.15, 1.44, 0.62), t / seconds)
		stage.camera.global_position = eye
		stage.camera.look_at(stand.look, Vector3.UP)
		# The player changes something two thirds of the way through: the
		# ecology notices, exactly as it does in the game.
		if f == int(frames * 0.62):
			stage.director.on_world_modified(
					Vector3(-2.75, 0.45, 1.35), "radiator")
			stage.hero.startle(1.0)
			print("[stage] t=%.1f  the player touched the radiator" % t)
		var mc: Dictionary = stage.margin.census()
		var cc: Dictionary = stage.critters.census()
		if int(mc.get("branches", 0)) > 0:
			seen.branch = true
		if stage.director.attending != Vector3.INF:
			seen.attention = true
		if int(cc.get("on_both_sides", 0)) > 0:
			seen.twin = true
		if int(cc.get("folding_a_leg", 0)) > 0:
			seen.fold = true
		if int(cc.get("approaching_hero", 0)) > 0:
			seen.brave = true
		if int(cc.get("nudged_by_a_palp", 0)) > 0:
			seen.shoved = true
		if int(stage.residue.census().get("live", 0)) > 0:
			seen.residue = true
		var st: String = String(stage.hero.census().state)
		if st == "EMERGING":
			seen.emerged = true
		elif st == "WATCH_PLAYER":
			seen.watched_player = true
		elif st == "FLINCH":
			seen.flinched = true
		elif st == "INTERACT_CRITTER":
			seen.minded_critter = true
		elif st == "INTERACT_MARGIN":
			seen.noticed_margin = true
		elif st == "TASTING":
			seen.tasted = true
		if f % 48 == 0:
			var hc: Dictionary = stage.hero.census()
			print("[stage]   t=%4.1f hero %s target=%s reach=%s"
					% [t, hc.state, hc.has_target, hc.reach_gain])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("stage_%04d.png" % f))
		_frame += 1
	print("[stage] BEAT SHEET:")
	for k in seen:
		print("[stage]   %-10s %s" % [k, "yes" if seen[k] else "NO"])
	print("[stage] final: %s" % [stage.census()])
	get_tree().quit(0)
