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
