extends Node
## THE ACCEPTANCE FRAMES FOR WORKSTREAM A, photographed rather than asserted.
##
##     SHOT_DIR=<abs> DREAM_FRACTAL=1 godot --path game \
##             res://tests/DreamExposureShot.tscn
##
## DREAM_SURFACE_REDESIGN_BRIEF.md ends with an acceptance list that is
## entirely visual, and two of its items are claims this harness can settle on
## its own:
##
##   "Gold that persists after the beam has moved away, and keeps growing."
##   "The same corridor, unlit, must be photographable as an ordinary derelict
##    apartment hallway with nothing wrong with it."
##
## Both are comparisons, not frames, so the harness is built around ONE fixed
## camera and changes only time and the lamp switch. Nothing moves between
## shots. That makes 00 and 04 -- the same wall, the same pose, the lamp off in
## both -- a controlled pair whose entire difference is what the player
## uncovered in between. If the conversion were still instantaneous, as it was
## before DreamExposureField, those two frames would be identical.
##
## It also prints the field's own numbers beside each frame, so the evidence
## survives being looked at on a bad monitor.
##
## Needs a REAL WINDOW. --headless reports zero draws and saves black.

const SEED_HEX := "f123456789abcdef"
const CASE := "mina_caption_crisis"
const PROFILE := "mina_release_print"
## Physics runs at 60 Hz and the field accumulates off physics, so a dwell is
## counted in frames to stay independent of how fast this machine renders.
const HZ := 60.0

var _root: DreamMazeRoot
var _out := ""
var _log: Array[String] = []


func _ready() -> void:
	_out = OS.get_environment("SHOT_DIR")
	if _out == "":
		_out = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	_root = scene.instantiate() as DreamMazeRoot
	_root.configure_dream({
		"case_id": CASE, "profile_id": PROFILE, "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
	})
	add_child(_root)
	await get_tree().process_frame
	# No pursuit, no hazards, no 28 s cap: this is a photograph of a surface,
	# and a passage that folds halfway through it is not one.
	_root.autonomous = false
	for c in _root.get_children():
		if c is CanvasLayer:
			c.visible = false
	if _root.player == null or _root.exposure == null:
		printerr("[EXPOSURE SHOT] the passage did not build")
		get_tree().quit(1)
		return
	_aim_at_a_wall()
	print("[EXPOSURE SHOT] %s  out=%s" % [
			"FRACTAL" if DreamMazeRoot.fractal_enabled() else "chain", _out])
	_report_binding()
	# The level of cooled gold is set from measurement rather than taste:
	# sweep this and read the frame luminance back out.
	var glow := OS.get_environment("SETTLED_GLOW")
	if glow != "":
		for m in _root._molten_materials:
			m.set_shader_parameter("settled_glow", float(glow))
		print("[EXPOSURE SHOT] settled_glow overridden to %s" % glow)
	# THE DECISIVE CONTROL. `eaten` is
	#     latent * (unlit_reveal + (1 - unlit_reveal) * front)
	# so a material with unlit_reveal = 0.22 shows about a fifth of its latent
	# gold with the field reading zero -- which is the OLD behaviour, and it
	# is lit by the lamp exactly as it always was. That means a lit frame full
	# of gold does not by itself prove the field reached the shader at all.
	#
	# EXPOSURE_ISOLATE=1 sets unlit_reveal to 0 on every Klimt material, so
	# the only surviving path to gold is `front`, which is the field. If the
	# frames still convert under the beam, the field is bound and working; if
	# they go black, it never arrived.
	if OS.get_environment("EXPOSURE_ISOLATE") == "1":
		for m in _root._molten_materials:
			m.set_shader_parameter("unlit_reveal", 0.0)
		print("[EXPOSURE SHOT] ISOLATE: unlit_reveal=0 on %d materials; "
				% _root._molten_materials.size()
				+ "all remaining gold comes from the exposure field")

	# THE CONTROL, FIRST AND UNTOUCHED. Nothing has been lit yet, so whatever
	# is in this frame is decay alone -- the brief's "ordinary derelict
	# apartment hallway with nothing wrong with it".
	await _shot("00_unlit_before", false, 0.0)
	# Growth. Three points on one dwell, so the front is visibly advancing
	# rather than switching on.
	await _shot("01_lit_2s", true, 2.0)
	await _shot("02_lit_6s", true, 4.0)
	await _shot("03_lit_12s", true, 6.0)
	# THE BRIEF'S ACTUAL CLAIM: "gold that persists after THE BEAM HAS
	# MOVED AWAY". The lamp stays on and the player turns, so the wall they
	# spent twelve seconds converting is now at the cold rim of the cone
	# while fresh plaster is at its centre. One frame therefore carries the
	# whole thesis: converted-and-dim on one side, the growth front in the
	# middle, unconverted-and-lit on the other. If the conversion were still
	# instantaneous, only the new pool would be gold.
	_root.player.rotation.y += deg_to_rad(38.0)
	await _shot("04_beam_moved", true, 1.0)
	_root.player.rotation.y -= deg_to_rad(38.0)
	# And a harsher control the brief does NOT require: the lamp off
	# altogether, same pose as 00. Gold is metallic and not a light source,
	# so this is meant to be dim -- but it must not be identical to 00, or
	# nothing the player did to this room survived them leaving it.
	await _shot("05_unlit_after", false, 0.5)

	print("\n[EXPOSURE SHOT] %-18s %8s %8s %8s"
			% ["frame", "field", "room", "peak"])
	for line in _log:
		print(line)
	print("
[EXPOSURE SHOT] 04 is the acceptance frame: the beam moved "
			+ "off a wall it had already converted.")
	print("[EXPOSURE SHOT] 00 vs 05 is the harsher pair: same pose, lamp "
			+ "off in both.")
	get_tree().quit(0)


## Stand in the middle of the room the player woke in and face its longest
## wall, so the frame is mostly one surface and the growth front has somewhere
## to be seen crossing.
func _aim_at_a_wall() -> void:
	var rect: Array = []
	for module in _root.plan.get("modules", []):
		var r: Array = module.get("rect", [])
		if r.size() < 4:
			continue
		var centre := Vector2((float(r[0]) + float(r[2])) * 0.5,
				(float(r[1]) + float(r[3])) * 0.5)
		if Vector2(_root.player.position.x,
				_root.player.position.z).distance_to(centre) < 3.0:
			rect = r
			break
	if rect.is_empty():
		return
	var mid_x := (float(rect[0]) + float(rect[2])) * 0.5
	var mid_z := (float(rect[1]) + float(rect[3])) * 0.5
	var span_x := absf(float(rect[2]) - float(rect[0]))
	var span_z := absf(float(rect[3]) - float(rect[1]))
	var wide := span_x > span_z
	# Back off from the wall we are going to photograph, so the beam makes a
	# pool on it rather than a disc a hand's width across.
	if wide:
		_root.player.position = Vector3(mid_x - 1.4, 0.0, mid_z)
		_root.player.rotation.y = -PI / 2.0
	else:
		_root.player.position = Vector3(mid_x, 0.0, mid_z - 1.4)
		_root.player.rotation.y = PI
	_root.player.camera.rotation.x = 0.0


## Set the lamp, let `hold` seconds of dwell accumulate, and photograph.
func _shot(name: String, lamp: bool, hold: float) -> void:
	_root.player.set_lamp_enabled(lamp)
	for _f in int(hold * HZ):
		await get_tree().process_frame
	# Settle the lamp's own warm-up and let the last field upload reach the
	# GPU before the frame is read back.
	for _f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(name + ".png"))
	var room := _root.exposure.room_exposure(_root._here_key)
	_log.append("[EXPOSURE SHOT] %-18s %8.4f %8.4f %8.4f" % [
			name, _root.exposure.total(), room, _root.exposure.peak()])
	print("   saved %s  field=%.4f room=%.4f peak=%.4f"
			% [name, _root.exposure.total(), room, _root.exposure.peak()])


## Is the field actually bound to the materials? A sampler that never got set
## reads as hint_default_black, which is indistinguishable from "the player
## has not lit anything yet" in every frame -- so it has to be asked directly.
func _report_binding() -> void:
	var bound := 0
	for m in _root._molten_materials:
		if m.get_shader_parameter("exposure_tex") != null:
			bound += 1
	print("[EXPOSURE SHOT] exposure_tex bound on %d/%d materials, extent=%s"
			% [bound, _root._molten_materials.size(),
			str(_root._molten_materials[0].get_shader_parameter(
					"exposure_extent")) if not _root._molten_materials
					.is_empty() else "n/a"])
