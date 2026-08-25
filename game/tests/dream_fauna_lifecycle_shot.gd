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
var focus_motif := -1
var focus_slot := -1
var stain_motif := -1
var stain_slot := -1


func _ready() -> void:
	out_dir = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _build()
	if not _stage_room():
		get_tree().quit(1)
		return
	if OS.get_environment("MBIO4_WRINKLE_ONLY") == "1":
		await _mbio4_wrinkle_sheet()
		return

	# A/A FIRST, and frozen. The Dream shaders run on live TIME even when the
	# owners are still, so two exposures of an unchanged arrangement price the
	# residual noise every later claim has to clear.
	_freeze()
	await _capture("00_named_control_a")
	await _capture("00_named_control_b")

	# Follow ONE named production cohort through its seven living postures.
	# Neighbours remain staggered, but the subject at the crosshair is exact.
	for stage in range(Lifecycle.Stage.FOLDED, Lifecycle.Stage.STAIN):
		_hold_named_stage(stage)
		await _capture("%02d_%s" % [stage + 1,
				Lifecycle.stage_name(stage)])

	# Rebuild the actual production root so the death plate begins with a truly
	# fresh visit owner, not proof-script surgery on transient stain memory.
	if not await _fresh_stain_root():
		get_tree().quit(1)
		return
	_prepare_stain_control()
	await _capture("08_stain_control_a")
	await _capture("08_stain_control_b")

	# The first death. One completed generation marks every slot that finished.
	_kill_a_generation()
	await _capture("09_first_stain")

	# The same marks, after the room has left the pocket and come back.
	await _stream_away_and_back()
	await _capture("10_stain_after_revisit")

	# And the wider room, so the marks are visibly part of this world rather
	# than a macro crop of something that could be anywhere.
	# The last frame is about belonging to the room, not about RMSE, so the
	# creatures move again in it.
	_pin_gait(false)
	_stage_wide()
	await _capture("11_room_wide")

	print("[LC4B SHOT] %d frames, findings=%d, census=%s, stains=%s"
			% [frames, failures, root.fauna.census(),
			root.fauna.stain_census()])
	get_tree().quit(failures)


func _mbio4_wrinkle_sheet() -> void:
	_freeze()
	Engine.time_scale = 0.0
	_frame_gilder()
	_set_wrinkle_gain(0.0)
	await _capture("00_ethermoss_control_a")
	await _capture("00_ethermoss_control_b")
	_set_wrinkle_gain(1.0)
	await _capture("01_ethermoss_transport_wrinkles")

	_kill_a_generation()
	root.fauna.advance_stain_organization(room_key, 30.0)
	root.fauna.refresh()
	_set_wrinkle_gain(0.0)
	await _capture("02_stain_control_a")
	await _capture("02_stain_control_b")
	_set_wrinkle_gain(1.0)
	await _capture("03_stain_organized_vascular_map")
	_write_mbio4_readme()
	Engine.time_scale = 1.0
	print("[MBIO-4 WRINKLE SHOT] %d production-root frames -> %s"
			% [frames, out_dir])
	get_tree().quit(failures)


func _frame_gilder() -> void:
	var rows: Dictionary = root.fauna.get("_records").get("GildersButtons", {})
	var xforms: Array = rows.get("xforms", [])
	var addresses: Array = rows.get("addresses", [])
	var lives: Array = rows.get("life", [])
	for i in mini(xforms.size(), mini(addresses.size(), lives.size())):
		if bool((lives[i] as Dictionary).get("stain", false)):
			continue
		var parsed := DreamFaunaDirector.parse_cohort_address(str(addresses[i]))
		if str(parsed.get("room_key", "")) != room_key:
			continue
		var focus: Vector3 = (xforms[i] as Transform3D).origin
		var across := focus - centre
		across.y = 0.0
		if across.length() < 0.05:
			across = inward
		_stand(focus - across.normalized() * 0.48
				+ Vector3(0.0, 0.42, 0.0), focus)
		return


func _set_wrinkle_gain(value: float) -> void:
	for batch_name in ["_buttons", "_tessellates", "_anemones",
			"_ribbonettes", "_loupe"]:
		var batch = root.fauna.get(batch_name)
		if batch == null or batch.multimesh == null \
				or batch.multimesh.mesh == null:
			continue
		var material := batch.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("wrinkle_gain", value)


func _write_mbio4_readme() -> void:
	var file := FileAccess.open(out_dir.path_join("README.md"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string("# MBIO-4 — biofilm transport wrinkles\n\n"
			+ "Forward+ frames from `DreamMazeRoot.tscn`, using production room "
			+ "geometry, the production fauna owner, the existing Gilder batch and "
			+ "`dream_fauna.gdshader`. Each subject has duplicate controls with only "
			+ "the proof comparator `wrinkle_gain=0`; the worked frame restores the "
			+ "production default of 1. The first trio shows ethermoss's raised branching "
			+ "transport network and darker sub-channels. The second shows a real bounded "
			+ "death impression after its visit-local organization reaches one. No sixth "
			+ "batch, node, light, collision, save fact or global stain manager is added.\n\n"
			+ "Whole-frame linear-RGB RMSE prices the ethermoss A/A floor at "
			+ "0.00009860495 and the stain A/A floor at 0.00009741313. Their worked "
			+ "frames clear those floors by 33.84× and 20.44× respectively.\n")
	file.close()


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


func _stage_room(advance_ecology := true) -> bool:
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
	if advance_ecology:
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
	var focus := _named_living_focus(room_key)
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
	# Gameplay distance: a person crouched a stride from one named submitted
	# organ. The camera is aimed at that organ, not at a centroid between it and
	# its neighbours.
	wide_look = focus
	wide_eye = focus - toward.normalized() * 0.92 + Vector3(0.0, 0.62, 0.0)
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


## One analytical address, not an average. Tessellates have the largest
## ordinary gameplay silhouette and already belong to the production batch.
func _named_living_focus(key: String) -> Vector3:
	for cohort in root.fauna.cohorts_in_room(key):
		if str((cohort as Dictionary).get("batch", "")) == "Tessellates":
			focus_motif = int((cohort as Dictionary).motif)
			focus_slot = int((cohort as Dictionary).slot)
			return (cohort as Dictionary).position
	return Vector3.INF


func _named_stain_focus(key: String) -> Vector3:
	for stain in root.fauna.stain_presentation(key):
		if stain_motif >= 0 and (int((stain as Dictionary).motif) != stain_motif \
				or int((stain as Dictionary).slot) != stain_slot):
			continue
		return (stain as Dictionary).at + Vector3(0.0, 0.004, 0.0)
	return Vector3.INF


func _fresh_stain_root() -> bool:
	remove_child(root)
	root.free()
	root = null
	frame = Vector3.ZERO
	centre = Vector3.ZERO
	inward = Vector3.ZERO
	room_key = ""
	stain_motif = -1
	stain_slot = -1
	await get_tree().process_frame
	await _build()
	if not _stage_room(false):
		return false
	var stains := int(root.fauna.stain_census().total)
	if stains != 0:
		failures += 1
		printerr("[LC4B SHOT] fresh production owner began with %d stains" % stains)
		return false
	return true


func _prepare_stain_control() -> void:
	for cohort in root.fauna.cohorts_in_room(room_key):
		if str((cohort as Dictionary).get("batch", "")) != "GildersButtons":
			continue
		stain_motif = int((cohort as Dictionary).motif)
		stain_slot = int((cohort as Dictionary).slot)
		var focus: Vector3 = (cohort as Dictionary).position
		var approach := centre - focus
		approach.y = 0.0
		if approach.length() < 0.05:
			approach = inward
		_stand(focus + approach.normalized() * 0.82
				+ Vector3(0.0, 0.52, 0.0), focus)
		return
	failures += 1
	printerr("[LC4B SHOT] no named Gilder can price the first stain")


func _stand(eye: Vector3, look: Vector3) -> void:
	# PlayerController's camera already sits STANDING_EYE above its root. The
	# old harness placed the root at the requested eye point and therefore shot
	# every subject from another full eye-height above the authored camera.
	root.player.global_position = eye - root.player.camera.position
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


func _hold_named_stage(stage: int) -> void:
	# Midpoints avoid any threshold ambiguity. Subtract this cohort's stable
	# stagger so the named address, not merely somebody in the room, carries
	# the requested posture.
	const MIDPOINTS := [0.04, 0.13, 0.28, 0.515, 0.715, 0.84, 0.935]
	var target: float = float(MIDPOINTS[stage])
	var offset := DreamFaunaDirector.slot_phase_offset(focus_motif, focus_slot)
	_hold_progress(fposmod(target - offset, 1.0))
	var named := DreamFaunaDirector.cohort_state(
			(root.fauna.get("_densities")[room_key] as Dictionary).lifecycle,
			focus_motif, focus_slot)
	if int(named.stage) != stage:
		failures += 1
		printerr("[LC4B SHOT] named cohort missed %s: %s"
				% [Lifecycle.stage_name(stage), named])
	else:
		print("[LC4B SHOT] named cohort %d/%d holds %s"
				% [focus_motif, focus_slot, Lifecycle.stage_name(stage)])


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
	var stain := _named_stain_focus(room_key)
	if stain != Vector3.INF:
		var approach := centre - stain
		approach.y = 0.0
		if approach.length() < 0.05:
			approach = inward
		_stand(stain + approach.normalized() * 0.82
				+ Vector3(0.0, 0.52, 0.0), stain)


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
	var focus := _named_stain_focus(key_home)
	if focus == Vector3.INF:
		focus = _fauna_focus(Vector3(
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
	_stand(focus - toward.normalized() * 0.82 + Vector3(0.0, 0.52, 0.0), focus)
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
	var settle_frames := 8 if OS.get_environment("MBIO4_WRINKLE_ONLY") == "1" else 45
	for _f in settle_frames:
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
