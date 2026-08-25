extends Node
## LC-3B / LC-4B — the eight stages and the first death stain, photographed in
## the production Dream root through the production fauna renderer.
##
## No proof-only creature exists here. Every frame is `DreamMazeRoot`, the
## landed `DreamFaunaDirector`, the five landed batches and
## `dream_fauna.gdshader`, lit by the player's own service lamp. What the
## harness controls is WHICH stage each slot is holding when the shutter
## opens, by driving the room's own lifecycle clock -- the same clock the 3 Hz
## tick drives, stepped by hand so a 45-to-150-second life can be photographed
## inside a 60-second ceiling.

const SEED_HEX := "f123456789abcdef"
const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var root: DreamMazeRoot
var out_dir := ""
var failures := 0
var frames := 0
var room: Dictionary
var frame := Vector3.ZERO
var centre := Vector3.ZERO
var inward := Vector3.ZERO
var room_key := ""
var wide_eye := Vector3.ZERO
var wide_look := Vector3.ZERO


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	if not _stage_room():
		get_tree().quit(1)
		return

	# A/A FIRST, and frozen. The Dream shaders run on live TIME even when the
	# owners are still, so two exposures of an unchanged arrangement price the
	# residual noise every later claim has to clear.
	_freeze()
	await _capture("00_control_a")
	await _capture("00_control_b")

	# One room, many stages at once. The staggered offsets already put
	# neighbouring slots in different stages; this only holds the room's clock
	# where the spread is widest.
	_hold_progress(0.30)
	await _capture("01_stages_multi")

	_hold_progress(0.70)          # EXCHANGE band across the mature cohort
	await _capture("02_exchange_contact")

	_hold_progress(0.88)          # SENESCENT into SHED
	await _capture("03_senescent_shed")

	# The first death. One completed generation marks every slot that finished.
	_kill_a_generation()
	await _capture("04_first_stain")

	# The same marks, after the room has left the pocket and come back.
	await _stream_away_and_back()
	await _capture("05_stain_after_revisit")

	# And the wider room, so the marks are visibly part of this world rather
	# than a macro crop of something that could be anywhere.
	# The last frame is about belonging to the room, not about RMSE, so the
	# creatures move again in it.
	_pin_gait(false)
	_stage_wide()
	await _capture("06_room_wide")

	print("[LC4B SHOT] %d frames, findings=%d, census=%s, stains=%s"
			% [frames, failures, root.fauna.census(),
			root.fauna.stain_census()])
	get_tree().quit(failures)


func _build() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": "mina_caption_crisis",
			"profile_id": "mina_release_print", "window": {},
			"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
			"night_index": 3, "spawn_anchor": 1})
	add_child(root)
	await get_tree().process_frame
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	root.pursuer.set_physics_process(false)
	root.fauna.set_physics_process(false)
	# The Tenant would hush the room and submerge the tissue this sheet is
	# about. It is not part of the claim, so it is not in the frame.
	root.pursuer.visible = false
	root.player.camera.make_current()


func _stage_room() -> bool:
	room = root.rooms.room_at_key(root.get("_here_key"))
	room_key = str(room.get("key", ""))
	for body in get_tree().get_nodes_in_group("dream_lineage_bodies"):
		if str(body.get_meta("room_key", "")) != room_key:
			continue
		var birth: Array = body.get_meta("birth_frames", [])
		if birth.is_empty():
			continue
		frame = birth[0]
		break
	if frame == Vector3.ZERO:
		failures += 1
		printerr("[LC4B SHOT] no real birth-frame in the live room")
		return false
	var rect: Array = room.rect
	centre = Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	inward = centre - frame
	inward.y = 0.0
	# Feed the room through the PRODUCTION exposure writer so the densities,
	# and therefore the instance counts, are the ones play would produce.
	for _i in 24:
		root.call("_update_exposure", 0.25)
	for _i in 16:
		root.fauna.advance_fixed()
	root.fauna.refresh()

	# STAND WHERE THE TISSUE ACTUALLY IS.
	#
	# Aiming at the room centre put the creatures off to one side and outside
	# the player's own lamp cone, and the first sheet came back almost black
	# with the fauna a few unlit pixels across. The landed FA2 harness solves
	# this by standing relative to a real submitted instance, and so does this:
	# the focus is the centroid of what the director actually submitted, so the
	# lamp -- which rides the camera -- necessarily lights it.
	var focus := _fauna_focus(centre)
	if focus == Vector3.INF:
		failures += 1
		printerr("[LC4B SHOT] nothing was submitted to stand in front of")
		return false
	centre = focus
	var toward := focus - frame
	toward.y = 0.0
	if toward.length() < 0.05:
		toward = inward
	inward = toward
	# Gameplay distance: a person standing a stride and a half away, at eye
	# height, looking slightly down at the floor tissue. Not a macro crop.
	wide_look = focus
	wide_eye = focus - toward.normalized() * 1.05 + Vector3(0.0, 1.05, 0.0)
	_stand(wide_eye, wide_look)
	root.player.set_lamp_enabled(true)
	root.player.pin_lamp_gutter_for_proof(1.0)
	root.player.set("_lamp_phase", 0.0)
	root.player.set("_lamp_phase_total", 0.0)
	root.player.call("_advance_lamp", 0.0)
	root.call("_update_molten")
	return true


## The centroid of the tissue submitted IN ONE ROOM, in world space. Read from
## the director's own submission record, so it needs no node and no collision.
##
## `near` matters: the batch record spans every live room at once, and
## averaging all of them aimed the camera at a point between rooms with no
## creature anywhere near it. The first lit sheet was a photograph of a floor
## seam for exactly that reason.
func _fauna_focus(near: Vector3, radius := 3.2) -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for batch_name in ["GildersButtons", "Tessellates", "WineAnemones",
			"Ribbonettes", "TheLoupe"]:
		var rows: Dictionary = root.fauna.get("_records").get(batch_name, {})
		for xform in (rows.get("xforms", []) as Array):
			var at: Vector3 = (xform as Transform3D).origin
			if Vector2(at.x - near.x, at.z - near.z).length() > radius:
				continue
			sum += at
			count += 1
	if count == 0:
		return Vector3.INF
	return sum / float(count)


func _stand(eye: Vector3, look: Vector3) -> void:
	root.player.global_position = eye
	root.player.camera.look_at(look, Vector3.UP)
	root.call("_update_molten")


## Freeze the owners. The fauna director already stops on
## `set_physics_process(false)`; this also pins the exposure and molten passes
## so only the shader's own TIME still moves between the two control frames.
func _freeze() -> void:
	root.fauna.set_physics_process(false)
	root.set_physics_process(false)
	root.player.set_physics_process(false)
	_pin_gait(true)


## Still the idle gait for the measured frames.
##
## `gait` is `sin(TIME * ...)`: the shader animates the creatures whether or
## not their owner is ticking, so two exposures of an identical arrangement
## differ by however far the wobble travelled. Measured, that was a 0.0281
## whole-frame floor concentrated exactly where the fauna stand -- which is
## the same order as the stage differences being claimed, so the sheet was
## measuring the wobble and calling it the stage.
##
## Pinning one existing material uniform to zero removes the wobble and
## nothing else. It changes no production default, exactly as the lamp gutter
## is pinned for proof; the final gameplay frame restores it.
func _pin_gait(still: bool) -> void:
	for batch in root.fauna.get_children():
		var mesh_batch := batch as MultiMeshInstance3D
		if mesh_batch == null or mesh_batch.multimesh == null 				or mesh_batch.multimesh.mesh == null:
			continue
		var material := mesh_batch.multimesh.mesh.surface_get_material(0) 				as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("gait_amount", 0.0 if still else 0.12)


## Hold this room's lifecycle clock at a chosen point and re-submit. The
## staggered per-slot offsets do the rest: at any one progress the room's
## slots occupy several different stages at once.
func _hold_progress(progress: float) -> void:
	var densities: Dictionary = root.fauna.get("_densities")
	if not densities.has(room_key):
		failures += 1
		printerr("[LC4B SHOT] the staged room left the density record")
		return
	var state: Dictionary = densities[room_key]
	var life: Dictionary = state.lifecycle
	life.progress = clampf(progress, 0.0, 0.999)
	state.lifecycle = life
	root.fauna.refresh()
	root.call("_update_molten")
	_report_stages()


## Advance every slot in this room by one whole generation, which is what a
## completed life is. The director notices the edge and remembers an
## impression for each lineage that finished.
func _kill_a_generation() -> void:
	var densities: Dictionary = root.fauna.get("_densities")
	var state: Dictionary = densities[room_key]
	var life: Dictionary = state.lifecycle
	life.generation = int(life.generation) + 1
	state.lifecycle = life
	root.fauna.refresh()
	root.call("_update_molten")
	var marks := int(root.fauna.census().stain_marks)
	if marks <= 0:
		failures += 1
		printerr("[LC4B SHOT] a generation completed and left no mark")
	print("[LC4B SHOT] first death: %d marks, %s"
			% [marks, root.fauna.stain_census()])


## Walk to a named room, let a generation finish there, walk away, and walk
## BACK to that same room. The marks must return to the same places carrying
## the same bytes.
##
## The first version of this advanced to two arbitrary paths and never came
## home, then compared every submitted mark in the batch -- which is a
## comparison between two different sets of live rooms and was always going to
## disagree. A revisit has to actually revisit.
func _stream_away_and_back() -> void:
	var architecture := root.get("_architecture") as Node3D
	var path_home := PackedInt32Array([2, 3, 1, 2, 0, 3])
	var path_away := PackedInt32Array([1, 3, 2, 1, 3, 2])
	var key_home := DreamRoomBuilder.key_of(path_home)

	root.rooms.advance(architecture, path_home)
	await get_tree().process_frame
	root.fauna.refresh()
	# Finish a generation in THIS room, so the marks being followed are its own.
	var densities: Dictionary = root.fauna.get("_densities")
	if densities.has(key_home):
		var state: Dictionary = densities[key_home]
		var life: Dictionary = state.lifecycle
		life.generation = int(life.generation) + 1
		state.lifecycle = life
		root.fauna.refresh()
	var before := var_to_bytes(root.fauna.stain_presentation(key_home))
	var before_count: int = root.fauna.stain_presentation(key_home).size()

	root.rooms.advance(architecture, path_away)
	await get_tree().process_frame
	root.fauna.refresh()
	var remembered: int = root.fauna.stain_presentation(key_home).size()

	root.rooms.advance(architecture, path_home)
	await get_tree().process_frame
	root.fauna.refresh()
	var after := var_to_bytes(root.fauna.stain_presentation(key_home))

	if before != after or before_count <= 0:
		failures += 1
		printerr("[LC4B SHOT] marks did not return identically (%d before, "
				% before_count + "%d remembered while away)" % remembered)
	else:
		print("[LC4B SHOT] %d marks returned byte-identical after a real "
				% before_count + "revisit (%d remembered while away)"
				% remembered)

	# Stand in the room that was actually revisited, not in the one the sheet
	# opened on: after two advances the original room is no longer under foot.
	var home := root.rooms.room_at_key(key_home)
	if home.is_empty():
		failures += 1
		printerr("[LC4B SHOT] the revisited room is not live")
		return
	# Stand in front of the tissue that is live now, not the room this sheet
	# opened on: after two advances the original room is no longer under foot.
	var rect_probe: Array = home.rect
	var focus := _fauna_focus(Vector3(
			(float(rect_probe[0]) + float(rect_probe[2])) * 0.5, 0.0,
			(float(rect_probe[1]) + float(rect_probe[3])) * 0.5))
	if focus == Vector3.INF:
		failures += 1
		printerr("[LC4B SHOT] nothing submitted in the revisited room")
		return
	var rect: Array = home.rect
	var home_centre := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	var toward := focus - home_centre
	toward.y = 0.0
	if toward.length() < 0.05:
		toward = inward
	_stand(focus - toward.normalized() * 1.05 + Vector3(0.0, 1.05, 0.0), focus)
	centre = focus
	inward = toward
	room_key = key_home


func _stage_wide() -> void:
	# Further back and slightly higher: the whole occupied room, so the marks
	# are read as part of the architecture rather than as a detail shot.
	# `centre`/`inward` were re-pointed at the revisited room above.
	var focus := _fauna_focus(centre)
	if focus == Vector3.INF:
		focus = centre
	var away := inward
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(0.0, 0.0, 1.0)
	_stand(focus - away.normalized() * 3.2 + Vector3(0.0, 1.60, 0.0), focus)
	_report_stages()


func _report_stages() -> void:
	var counts := {}
	for batch_name in ["GildersButtons", "Tessellates", "WineAnemones",
			"Ribbonettes", "TheLoupe"]:
		var rows: Dictionary = root.fauna.get("_records").get(batch_name, {})
		for packed in (rows.get("custom", []) as Array):
			var decoded: Dictionary = DreamFaunaChannels.decode(packed)
			var stage: int = DreamFaunaDirector.stage_from_stream(
					int(decoded.flags))
			var name := Lifecycle.stage_name(stage)
			counts[name] = int(counts.get(name, 0)) + 1
	print("[LC4B SHOT] stages in frame: %s" % [counts])


func _stain_rows() -> Array:
	var out: Array = []
	var rows: Dictionary = root.fauna.get("_records").get("GildersButtons", {})
	var custom: Array = rows.get("custom", [])
	var xforms: Array = rows.get("xforms", [])
	var lives: Array = rows.get("life", [])
	for i in custom.size():
		if i >= lives.size():
			continue
		if not bool((lives[i] as Dictionary).get("stain", false)):
			continue
		out.append("%s|%s" % [xforms[i], custom[i]])
	out.sort()
	return out


func _capture(file_name: String) -> void:
	for _f in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name + ".png")
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		printerr("[LC4B SHOT] failed %s (%d)" % [path, error])
		return
	frames += 1
	print("[LC4B SHOT] saved %s  %dx%d" % [path, image.get_width(),
			image.get_height()])
