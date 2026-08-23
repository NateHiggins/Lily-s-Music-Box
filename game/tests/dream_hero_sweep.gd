extends Node
## THE CANONICAL FLASHLIGHT SWEEP (HERO_PASS §15–§17) and the review frame
## set. The primary review asset: the ACTUAL player lamp, the actual
## gameplay camera, the actual materials, moving past the creature so the
## material hierarchy has to declare itself —
##   surface moisture → micro-normal → skin volume / SSS → vascular depth
##   → rigid mineral → crystal interior → wet cornea.
##
##     SWEEP_DIR=<abs dir>     where the frames go (required)
##     SWEEP_MODE=video|set    the 10–15 s sweep, or the 15 stills
##     SWEEP_SECONDS=13        the sweep's length
##     SWEEP_FPS=30            frames a second
##     SWEEP_WARM=14           seconds to let the creature grow first
##
## Frames are written as `NNNN.png` for ffmpeg, or `NN_name.png` for the
## set. Not over-directed (§16): this should look like ordinary gameplay
## that happens to be pointed at something impossible.

const ANCHOR := Vector3(-13.62, 4.75, 4.35)
const ANCHOR_N := Vector3(1.0, 0.0, 0.0)
## 2A's main room, in Godot axes, inset from the walls: the camera is a
## person standing in a flat and may not leave it. (Line of sight alone let
## the first pass photograph the creature from inside the brickwork.)
const ROOM_MIN := Vector3(-13.45, 3.45, -9.40)
const ROOM_MAX := Vector3(13.45, 6.10, 9.40)

var root: Node3D
var cam: Camera3D
var _dir := ""
var _fps := 30.0
var _seconds := 13.0
var _tentacle: Node = null
var _frame := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	_dir = OS.get_environment("SWEEP_DIR")
	if _dir.is_empty():
		_dir = OS.get_user_data_dir()
	var f := OS.get_environment("SWEEP_FPS")
	if not f.is_empty():
		_fps = maxf(5.0, f.to_float())
	var s := OS.get_environment("SWEEP_SECONDS")
	if not s.is_empty():
		_seconds = clampf(s.to_float(), 2.0, 40.0)
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("TENTACLE_FORCE", "1")
	OS.set_environment("TENTACLE_HOLD", "1")
	OS.set_environment("TENTACLE_ANCHOR", "%f,%f,%f,%f,%f,%f" % [ANCHOR.x, ANCHOR.y, ANCHOR.z,
			ANCHOR_N.x, ANCHOR_N.y, ANCHOR_N.z])
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.4).timeout
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	_hide_overlays(root)
	var player: PlayerController = root.player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 90.0
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	# THE PLAYER'S OWN LAMP, carried on the camera exactly as in play.
	player.flashlight.visible = true
	player._light_mask.visible = true
	player.flashlight.reparent(cam)
	player.flashlight.transform = Transform3D(Basis(), Vector3(0.14, -0.16, -0.05))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Let the organism grow and the limb come out.
	var warm := 14.0
	var w := OS.get_environment("SWEEP_WARM")
	if not w.is_empty():
		warm = maxf(2.0, w.to_float())
	# The room's own fixtures, as in play: the torch is the REVEAL, not the
	# only light in the world. Without this the whole flat is a void and the
	# creature is a lit shape in blackness.
	if "switch_system" in root and root.switch_system != null:
		if not root.switch_system.toggle_room("F02_A_MAIN"):
			root.switch_system.toggle_room("F02_A_MAIN")
	_look_at_from(ANCHOR + Vector3(1.4, -0.2, 0.5), ANCHOR)
	await get_tree().create_timer(warm).timeout
	_tentacle = _find_tentacle()
	if _tentacle == null and not (OS.get_environment("SWEEP_MODE") in ["tendrils", "modelled", "margin", "archetypes", "critters", "ecology", "emerge"]):
		printerr("[SWEEP] no tentacle — nothing to photograph")
		get_tree().quit(1)
		return
	# Diagnostic: SWEEP_NO_LIVING=1 mutes the organism on every layered
	# surface, so a frame can prove whether the haze belongs to it.
	if OS.get_environment("SWEEP_NO_LIVING") == "1":
		var enc: Node = root.get("apartment_encroachment")
		for fid in enc.storey_materials:
			for m in enc.storey_materials[fid]:
				if is_instance_valid(m):
					(m as ShaderMaterial).set_shader_parameter("living_amount", 0.0)
		print("[SWEEP] living muted for diagnosis")
	if _tentacle != null:
		print("[SWEEP] tentacle out: %s" % [_tentacle.census()])
	if _tentacle != null:
		print("[SWEEP] station %s  face_u %.3f  normal %s" % [_tentacle.ocular.position,
				_tentacle.ocular.eye_u, _tentacle.ocular.normal])
	var mode := OS.get_environment("SWEEP_MODE")
	if mode == "set":
		await _frame_set()
	elif mode == "tendrils":
		await _tendril_shots()
	elif mode == "modelled":
		await _modelled_hero_shots()
	elif mode == "margin":
		await _margin_shots()
	elif mode == "archetypes":
		await _archetype_row()
	elif mode == "critters":
		await _critter_shots()
	elif mode == "ecology":
		await _ecology_capture()
	elif mode == "emerge":
		await _emergence_ladder()
	else:
		await _sweep()
	print("[SWEEP] DONE %d frames -> %s" % [_frame, _dir])
	get_tree().quit(0)


func _find_tentacle() -> Node:
	var enc: Node = root.get("apartment_encroachment")
	if enc == null:
		return null
	for floor_id in enc.tentacles:
		for t in enc.tentacles[floor_id]:
			if is_instance_valid(t):
				return t
	return null


## The path: it begins in the dark at the root, travels the whole anatomy,
## rests on the ocular station while it looks back, then goes on to the
## tactile tip. Positions are derived from the rig so the shot cannot drift
## out of frame when the creature changes.
func _sweep() -> void:
	var rig = _tentacle.rig
	var total := int(_seconds * _fps)
	# The rig's own landmarks: root, neck, station, ribbon, shaft, club.
	var root_p: Vector3 = rig.point_at(0.04)
	var station: Vector3 = _tentacle.ocular.position
	var club: Vector3 = rig.point_at(0.97)
	var eye_n: Vector3 = _tentacle.ocular.normal
	# The arc runs from the wall's normal round to the organ's own face, so
	# the dwell on the ocular station actually looks INTO it (§16).
	var out := ANCHOR_N
	# The camera arcs around the limb rather than dollying at it, so the
	# lamp's angle on every material keeps changing (§17).
	for i in total:
		var t := float(i) / float(maxi(1, total - 1))
		# Where the lamp is pointed: root → shaft → station (dwell) → club.
		var aim: Vector3
		if t < 0.30:
			aim = root_p.lerp(rig.point_at(0.30), smoothstep(0.0, 0.30, t) / 1.0)
		elif t < 0.46:
			aim = rig.point_at(0.30).lerp(station, smoothstep(0.30, 0.46, t))
		elif t < 0.74:
			aim = station
		else:
			aim = station.lerp(club, smoothstep(0.74, 1.0, t))
		# The arc: 55° of travel, a slow rise, closing in a little.
		var ang := lerpf(-0.50, 0.46, t)
		var dist := lerpf(1.05, 0.62, smoothstep(0.0, 0.7, t)) + 0.14 * sin(t * PI * 2.0)
		var up := lerpf(-0.16, 0.20, t)
		var side := out.cross(Vector3.UP).normalized()
		var base := out.lerp(eye_n, smoothstep(0.28, 0.62, t)).normalized()
		var side2 := base.cross(Vector3.UP).normalized()
		if side2.length() < 0.2:
			side2 = side
		var dir := (base * cos(ang) + side2 * sin(ang)).normalized()
		dir = _view_dir(aim, dir, dist)
		var eye := aim + dir * dist + Vector3.UP * up
		_look_at_from(eye, aim)
		# One deliberate event apiece, on the beats §16 asks for.
		if is_equal_approx(t, 0.0) or absf(t - 0.52) < 0.5 / float(total):
			_tentacle.ocular.notice(cam.global_position, 1.0)
		if absf(t - 0.70) < 0.5 / float(total):
			_tentacle.ocular.set_mode("lock_player")
		if absf(t - 0.76) < 0.5 / float(total):
			_tentacle.force_blink()
		if absf(t - 0.90) < 0.5 / float(total):
			_tentacle.force_phase_slice()
		await _capture_step()


## The fifteen acceptance stills (§15). Each names what it is proving.
func _frame_set() -> void:
	var rig = _tentacle.rig
	var station: Vector3 = _tentacle.ocular.position
	var club: Vector3 = rig.point_at(0.97)
	var shaft: Vector3 = rig.point_at(0.66)
	# AIM FROM THE ORGAN'S OWN NORMAL, not the anchor's. The station chooses
	# which face of the limb it looks out of, so a shot aimed along the wall
	# normal photographs a wall of flesh — which is exactly what the first
	# run produced.
	var eye_n: Vector3 = _tentacle.ocular.normal
	var out := ANCHOR_N
	var side := out.cross(Vector3.UP).normalized()
	var eye_side := eye_n.cross(Vector3.UP).normalized()
	if eye_side.length() < 0.2:
		eye_side = eye_n.cross(Vector3.RIGHT).normalized()
	# name, aim, direction, distance, and an optional action.
	var shots := [
		["01_direct_flashlight", shaft, out, 0.85, ""],
		["02_grazing_flashlight", shaft, (out * 0.25 + side).normalized(), 0.75, ""],
		["03_backlit_thin_tissue", club, (out * -0.2 + side * -1.0).normalized(), 0.55, ""],
		["04_macro_flesh_gold", rig.point_at(0.60), out, 0.24, ""],
		["05_gameplay_distance", station, (eye_n * 0.75 + out * 0.5).normalized(), 2.4, ""],
		["06_direct_eye_contact", station, eye_n, 0.42, "lock"],
		["07_eye_tracking_off_axis", station, (eye_n + eye_side * 0.9).normalized(), 0.48, "lock"],
		["08a_blink_start", station, eye_n, 0.34, "blink0"],
		["08b_blink_membrane", station, eye_n, 0.34, "blink1"],
		["08c_blink_overlap", station, eye_n, 0.34, "blink2"],
		["08d_blink_reopen", station, eye_n, 0.34, "blink3"],
		["09_cilia_reaction", station, (eye_n + eye_side * 0.45).normalized(), 0.30, "notice"],
		["10_vascular_pulse", rig.point_at(0.55), out, 0.62, "pulse"],
		["11_gold_articulation", rig.point_at(0.28), out, 0.40, "attention"],
		["12_crystal_glint", station, (eye_n * 0.7 + eye_side * 0.7).normalized(), 0.28, ""],
		["13_sucker_contact", club, (out * 0.6 - Vector3.UP * 0.5).normalized(), 0.32, ""],
		["14_phase_slice", shaft, out, 0.80, "phase"],
		["15_transformed_object", rig.point_at(0.99) + Vector3(0.0, -0.18, 0.0), out, 0.75, ""],
	]
	for shot in shots:
		var aim: Vector3 = shot[1]
		var dir: Vector3 = _view_dir(aim, shot[2], float(shot[3]))
		_look_at_from(aim + dir * float(shot[3]) + Vector3.UP * 0.06, aim)
		match str(shot[4]):
			"lock":
				_tentacle.ocular.set_mode("lock_player")
			"notice":
				_tentacle.ocular.notice(cam.global_position, 1.0)
			"attention":
				_tentacle.behavior.interest = 1.0
			"phase":
				_tentacle.force_phase_slice()
			"pulse":
				_tentacle.align_pulse_to(0.55)
			"blink0":
				_tentacle.force_blink()
			_:
				pass
		# Let the systems settle, and for the blink let it advance.
		var wait := 0.5
		if str(shot[4]).begins_with("blink"):
			wait = 0.0
		await get_tree().create_timer(wait).timeout
		if str(shot[4]) == "blink1":
			await get_tree().create_timer(0.16).timeout
		elif str(shot[4]) == "blink2":
			await get_tree().create_timer(0.10).timeout
		elif str(shot[4]) == "blink3":
			await get_tree().create_timer(0.22).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := _dir.path_join("%s.png" % str(shot[0]))
		var err := get_viewport().get_texture().get_image().save_png(path)
		_frame += 1
		print("[SWEEP] %-26s %s" % [str(shot[0]), "ok" if err == OK else "SAVE FAILED"])


## Where can this actually be photographed from? Sample the hemisphere that
## faces into the room and keep the direction with a clear line of sight to
## the target, preferring one near `prefer`. Assuming a direction is how the
## first two runs put the camera inside a wall and behind the limb.
func _view_dir(target: Vector3, prefer: Vector3, dist: float) -> Vector3:
	# Distances are a wish; the room is the constraint.
	dist = minf(dist, 3.0)
	var space := get_viewport().find_world_3d().direct_space_state
	var best := prefer
	var best_score := -INF
	# The FULL sphere: the limb curls after the organ picks its face, so the
	# eye can end up pointing at the wall it came out of. Line of sight is
	# the only honest test of where a photograph can be taken from — the
	# earlier hemisphere assumption put the camera inside the brickwork.
	var n := 120
	for i in n:
		var a := float(i) * 2.399963
		var z := 1.0 - 2.0 * (float(i) + 0.5) / float(n)
		var r := sqrt(maxf(0.0, 1.0 - z * z))
		var d := Vector3(cos(a) * r, z, sin(a) * r).normalized()
		# Nothing from below the floor or straight down through it.
		if d.y < -0.55:
			continue
		var eye := target + d * dist
		if eye.x < ROOM_MIN.x or eye.x > ROOM_MAX.x or eye.y < ROOM_MIN.y 				or eye.y > ROOM_MAX.y or eye.z < ROOM_MIN.z or eye.z > ROOM_MAX.z:
			continue
		var clear := 1.0
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(target + d * 0.05, eye)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				clear = 0.0
		var score := clear * 4.0 + d.dot(prefer) + 0.35 * d.dot(ANCHOR_N)
		if score > best_score:
			best_score = score
			best = d
	return best


func _look_at_from(eye: Vector3, target: Vector3) -> void:
	cam.global_position = eye
	var d := target - eye
	if d.length() < 0.01:
		return
	cam.look_at(target, Vector3.UP)


func _capture_step() -> void:
	await RenderingServer.frame_post_draw
	var path := _dir.path_join("%04d.png" % _frame)
	get_viewport().get_texture().get_image().save_png(path)
	_frame += 1


func _hide_overlays(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer and child.name != "SweepLayer":
			(child as CanvasLayer).visible = false
		_hide_overlays(child)


## DF-13: photograph the surface tendrils WHERE THEY ACTUALLY ARE. Guessing
## a stand's coordinates put the camera in a bathroom; the harness reads a
## live tendril's own anchor and frames that.
func _tendril_shots() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var tend = enc.get("surface_tendrils") if enc != null else null
	if tend == null:
		printerr("[SWEEP] no tendril system")
		return
	# WAIT FOR THE REAL EVENT. The patches concentrate, so at any instant most
	# of the storey has none; the acceptance frame is of a patch that has
	# actually surfaced in the LIT flat, so the harness waits for one rather
	# than photographing whatever happens to exist at second sixteen.
	var lit_min := Vector3(-13.45, 3.45, 0.65)
	var lit_max := Vector3(-5.75, 6.10, 6.05)
	var anchors: Array = []
	for attempt in 120:
		await get_tree().create_timer(0.5).timeout
		anchors.clear()
		for i in 24:
			if tend._life[i] >= 0.0:
				anchors.append({"p": tend._anchor[i], "n": tend._normal[i]})
		var in_flat := 0
		for a in anchors:
			var p: Vector3 = a.p
			if p.x >= lit_min.x and p.y >= lit_min.y and p.z >= lit_min.z 					and p.x <= lit_max.x and p.y <= lit_max.y and p.z <= lit_max.z 					and absf((a.n as Vector3).y) < 0.6:
				in_flat += 1
		if attempt % 10 == 0:
			print("[SWEEP] waiting: %s, %d in the lit flat" % [tend.census(), in_flat])
		if in_flat >= 3:
			break
	if anchors.is_empty():
		printerr("[SWEEP] no live tendrils to photograph")
		return
	print("[SWEEP] %d live tendrils; first at %s" % [anchors.size(), anchors[0].p])
	# Photograph the DENSEST PATCH INSIDE THE LIT FLAT. The centroid of two
	# dozen tendrils spread over a storey is a point in a wall, and a patch in
	# an unlit room photographs as black — neither is the acceptance test. The
	# test is: standing in 2A, do I see limbs coming out of the wall?
	var best := -1
	var best_n := -1
	for i in anchors.size():
		var p: Vector3 = anchors[i].p
		if p.x < lit_min.x or p.y < lit_min.y or p.z < lit_min.z 				or p.x > lit_max.x or p.y > lit_max.y or p.z > lit_max.z:
			continue
		# Prefer a patch on a WALL: standing off from a floor or ceiling patch
		# puts the camera inside the dream volume, which photographs as a
		# dark sphere and shows nothing.
		if absf((anchors[i].n as Vector3).y) > 0.6:
			continue
		var n := 0
		for j in anchors.size():
			if (anchors[j].p as Vector3).distance_to(p) < 0.7:
				n += 1
		if n > best_n:
			best_n = n
			best = i
	if best < 0:
		printerr("[SWEEP] no tendrils in the lit flat this run")
		return
	print("[SWEEP] densest lit patch: %d tendrils at %s" % [best_n, anchors[best].p])
	anchors = [anchors[best]] + anchors
	# The centroid, so several are in one frame, and a close pair.
	var shots := [
		["T1_field_of_tendrils", anchors[0].p, 2.30],
		["T2_close", anchors[0].p, 0.30],
		["T3_grazing", anchors[0].p, 0.42],
	]
	for shot in shots:
		var aim: Vector3 = shot[1]
		var prefer: Vector3 = anchors[0].n if str(shot[0]) != "T3_grazing" 				else (anchors[0].n as Vector3).cross(Vector3.UP).normalized()
		var dir := _view_dir(aim, prefer, float(shot[2]))
		_look_at_from(aim + dir * float(shot[2]) + Vector3.UP * 0.04, aim)
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := _dir.path_join("%s.png" % str(shot[0]))
		get_viewport().get_texture().get_image().save_png(path)
		_frame += 1
		print("[SWEEP] %s at %s" % [str(shot[0]), aim])


## THE MODELLED HERO, photographed in a real room under the player's own lamp.
## The Blender greys prove the sculpt; only this proves the character.
## HOW THE CREATURE ARRIVES, ONE STEP AT A TIME.
##
## `grow` runs nought to one in 2.4 seconds, which is far too fast to judge
## from a live take and far too easy to get backwards: a limb that fills in
## from the tip and a limb that extrudes from the root look identical in any
## single frame, and both look like "a tentacle". So the state machine is
## stopped and the parameter is driven by hand, one rung at a time, from a
## camera that can see both the wall it comes through and the room it reaches
## into.
func _emergence_ladder() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var hero = enc.get("hero") if enc != null else null
	if hero == null:
		printerr("[SWEEP] no modelled hero")
		return
	# Let it finish arriving and settle, then take the wheel.
	await get_tree().create_timer(9.0).timeout
	hero.set_process(false)
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for mi in hero.meshes:
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		lo = lo.min(box.position)
		hi = hi.max(box.end)
	var aim := (lo + hi) * 0.5
	var reach: float = maxf(0.4, (hi - lo).length())
	var dir := _view_dir(aim, Vector3.FORWARD, reach * 0.75)
	_look_at_from(aim + dir * reach * 0.75 + Vector3.UP * 0.05, aim)
	for step in 7:
		var g := float(step) / 6.0
		for mat in hero.materials:
			mat.set_shader_parameter("grow", g)
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("E%d_grow%.2f.png" % [step, g]))
		_frame += 1
		print("[SWEEP] grow %.2f" % g)


func _modelled_hero_shots() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var hero = enc.get("hero") if enc != null else null
	if hero == null:
		printerr("[SWEEP] no modelled hero — run with DREAM_HERO=1")
		return
	print("[SWEEP] hero census %s" % [hero.census()])
	# H6 — CROSS-SECTIONAL WITHDRAWAL. Force it and photograph the whole
	# event from one fixed camera, so the frames can be measured afterwards.
	# The signature is that the limb's LENGTH does not change while its
	# THICKNESS goes to nothing: it did not leave, it stopped having a cross
	# section.
	if OS.get_environment("SWEEP_SLICE") == "1":
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for mi in hero.meshes:
			var box: AABB = (mi as MeshInstance3D).global_transform 					* (mi as MeshInstance3D).get_aabb()
			lo = lo.min(box.position)
			hi = hi.max(box.end)
		var mid: Vector3 = (lo + hi) * 0.5
		var span: float = (hi - lo).length()
		var dir := _view_dir(mid, Vector3.FORWARD, span * 0.85)
		_look_at_from(mid + dir * span * 0.85, mid)
		await get_tree().create_timer(0.5).timeout
		hero.state = 7   # CROSS_SECTION_WITHDRAW
		hero.state_clock = 0.0
		print("[SWEEP] forcing cross-sectional withdrawal")
		for i in 12:
			await get_tree().create_timer(0.22).timeout
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					_dir.path_join("S%02d_close%.2f.png" % [i, hero.slice_close]))
			_frame += 1
		print("[SWEEP] slice_close reached %.3f, state %s"
				% [hero.slice_close, hero.state_name()])
	# §12 — DOES THE FLESH LAG THE BONE? A creature whose every joint arrives
	# at once has no mass in it. The distal third should run further behind
	# the intent than the root, which is held by the collar.
	if OS.get_environment("SWEEP_SECONDARY") == "1":
		var root_peak := 0.0
		var tip_peak := 0.0
		var motion_peak := 0.0
		for probe in 200:
			await get_tree().create_timer(0.06).timeout
			root_peak = maxf(root_peak, hero.lag_root)
			tip_peak = maxf(tip_peak, hero.lag_tip)
			motion_peak = maxf(motion_peak, hero.motion)
		print("[SWEEP] SECONDARY: lag root %.4f rad, tip %.4f rad, motion peak %.3f"
				% [root_peak, tip_peak, motion_peak])
		print("[SWEEP] %s" % ["FLESH LAGS BONE" if tip_peak > root_peak * 1.4
				and tip_peak > 0.004
				else "NO FOLLOW-THROUGH — every joint arrives together"])
	# H3 — DOES IT ACTUALLY TOUCH ANYTHING? A state machine that cycles
	# through TOUCHING without a tip near a surface has not touched anything.
	if OS.get_environment("SWEEP_CONTACT") == "1":
		var seen := {}
		# A GDScript lambda captures an int BY VALUE, so incrementing one
		# inside the callback left the outer counter at zero and reported a
		# working system as broken. Arrays are references.
		var touches := [0]
		var closest := 9.0
		hero.touched.connect(func(_w, _n): touches[0] += 1)
		for probe in 300:
			await get_tree().create_timer(0.1).timeout
			seen[hero.state_name()] = true
			if hero.target != Vector3.INF:
				closest = minf(closest, hero.tip_world().distance_to(hero.target))
			if touches[0] >= 2 and seen.size() >= 4:
				break
		print("[SWEEP] CONTACT: %d touches, closest approach %.3f m, states %s"
				% [touches[0], closest, seen.keys()])
		print("[SWEEP] %s" % ["CONTACT WORKS" if touches[0] >= 1
				else "NEVER TOUCHED — the reach does not arrive"])
	# THE SALIVA. Its whole point is that it plays a geological history in a
	# couple of seconds, so one frame proves nothing: this waits for a real
	# contact and then photographs the SAME patch at intervals across its
	# life. If the decay reads as opacity going down, that is a failure.
	if OS.get_environment("SWEEP_RESIDUE") == "1":
		var res = enc.get("residue")
		if res == null:
			printerr("[SWEEP] no residue system")
			return
		# By value again — the same trap as the touch counter. Vectors are
		# not reference types in GDScript either.
		var caught: Array = []
		hero.touched.connect(func(w: Vector3, n: Vector3):
			if caught.is_empty():
				caught.append(w)
				caught.append(n))
		for probe in 400:
			await get_tree().create_timer(0.1).timeout
			if not caught.is_empty():
				break
		var where: Vector3 = caught[0] if caught.size() > 0 else Vector3.INF
		var nrm: Vector3 = caught[1] if caught.size() > 1 else Vector3.UP
		if where == Vector3.INF:
			printerr("[SWEEP] the hero never touched anything")
			return
		print("[SWEEP] residue at %s, census %s" % [where, res.census()])
		var dir := _view_dir(where, nrm, 0.42)
		_look_at_from(where + dir * 0.42, where)
		for i in 8:
			await get_tree().create_timer(0.45).timeout
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					_dir.path_join("R%d_t%.1f.png" % [i, float(i) * 0.45]))
			_frame += 1
		print("[SWEEP] residue life photographed; census %s" % [res.census()])
	# THE SEATS, CHECKED AGAINST THE MODEL. Every rider is told where it sits
	# along the body so it can share the flesh's heartbeat, and a seat that is
	# silently zero looks exactly like a seat that is right -- the whole defect
	# it fixes was invisible in a still frame. So read the numbers back and
	# compare them with what the glTF actually says: on this model the cage
	# runs 1.6 m, GOLD_RIB_05 is centred a third of the way down and
	# GOLD_CRESCENT_25 near the tip.
	var seats := {}
	for mi in hero.meshes:
		seats[mi.name] = hero._seat_of(mi)
	var seat_lo := 2.0
	var seat_hi := -1.0
	for k in seats:
		seat_lo = minf(seat_lo, float(seats[k]))
		seat_hi = maxf(seat_hi, float(seats[k]))
	print("[SWEEP] SEATS across %d meshes: %.3f .. %.3f  (axis %d, len %.2f m)"
			% [seats.size(), seat_lo, seat_hi, hero._axis, hero._body_len])
	for probe_name in ["TENTACLE_BODY_CAGE", "GOLD_RIB_05", "EYE_GLOBE",
			"GOLD_CRESCENT_25"]:
		if seats.has(probe_name):
			print("[SWEEP]   %-20s seat %.3f" % [probe_name, seats[probe_name]])
	if seat_hi - seat_lo < 0.5:
		printerr("[SWEEP] SEATS ARE FLAT — the riders are not being placed")
	# H4 — THE RIDERS' OWN MOTION, WHICH NO STILL FRAME CAN SHOW.
	#
	# A rider that lags and a rider welded to the flesh are the same photograph
	# in every frame, so this is measured rather than looked at. And it is
	# measured PER SYSTEM, because the whole claim is that they differ: a
	# cilium is a hair and should trail far, a gold plate is a mineral seated
	# in flesh and should barely stir. One number for the body cannot say that,
	# and would have passed just as happily with every rider on one spring.
	var kind_names := ["flesh", "gold", "crystal", "membrane", "sucker", "cilium"]
	var peak := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for _probe in 120:
		await get_tree().create_timer(0.05).timeout
		for i in hero.meshes.size():
			var k: int = hero._rider_kind[i]
			peak[k] = maxf(peak[k], hero._rider_push[i].length())
	for k in 6:
		if k == 0:
			continue
		print("[SWEEP] RIDER %-9s peak offset %.2f mm" % [kind_names[k],
				float(peak[k]) * 1000.0])
	if float(peak[5]) <= float(peak[1]):
		printerr("[SWEEP] the cilia are no springier than the gold — one spring for everything")
	if float(peak[5]) < 0.0005:
		printerr("[SWEEP] the riders are not moving at all")
	# H1 A/B. The bake is either doing something visible or it is not, and the
	# only way to know is to photograph the same frame with it off.
	var ab: String = OS.get_environment("SWEEP_ANATOMY")
	if ab != "":
		var strength := ab.to_float()
		for mat in hero.materials:
			mat.set_shader_parameter("anatomy_strength", strength)
		print("[SWEEP] anatomy_strength forced to %.2f" % strength)
	# DOES IT ACTUALLY MOVE? A still frame cannot tell you, and the owner
	# caught the modelled hero standing at rest pose because nothing drove
	# its rig. So measure it: sample a distal bone's pose, wait, sample again.
	if hero.skeleton != null and hero._bones.size() > 4:
		var tip: int = hero._bones[hero._bones.size() - 3]
		var mid: int = hero._bones[hero._bones.size() / 2]
		var a_tip: Quaternion = hero.skeleton.get_bone_pose_rotation(tip)
		var a_mid: Quaternion = hero.skeleton.get_bone_pose_rotation(mid)
		await get_tree().create_timer(2.5).timeout
		var b_tip: Quaternion = hero.skeleton.get_bone_pose_rotation(tip)
		var b_mid: Quaternion = hero.skeleton.get_bone_pose_rotation(mid)
		var moved_tip: float = a_tip.angle_to(b_tip)
		var moved_mid: float = a_mid.angle_to(b_mid)
		# And where the TIP actually goes in the room, which is what a viewer
		# sees: per-bone angles understate it badly, since twenty-eight of
		# them accumulate down the chain.
		var tip_node: Node3D = hero.skeleton
		var far_a: Vector3 = hero.skeleton.global_transform * 				hero.skeleton.get_bone_global_pose(tip).origin
		await get_tree().create_timer(2.0).timeout
		var far_b: Vector3 = hero.skeleton.global_transform * 				hero.skeleton.get_bone_global_pose(tip).origin
		print("[SWEEP] the tip travelled %.3f m in 2 s" % far_a.distance_to(far_b))
		# The eye is the hero's face (§36). It had controls and nothing
		# weighted to them, so it could not look; assert that it now does.
		if hero._eye_bone >= 0:
			var e0: Quaternion = hero.skeleton.get_bone_pose_rotation(hero._eye_bone)
			var lid0: Quaternion = hero.skeleton.get_bone_pose_rotation(hero._lid_bones[0])
			var lid_max := 0.0
			var eye_max := 0.0
			# Long enough to catch a blink. The interval is 2.4-6.4 s and a
			# 4.8 s window missed one, which reported a working eye as
			# furniture — a flaky assertion is worse than none.
			for probe in 110:
				await get_tree().create_timer(0.12).timeout
				if eye_max > 0.01 and lid_max > 0.05:
					break
				eye_max = maxf(eye_max, e0.angle_to(
						hero.skeleton.get_bone_pose_rotation(hero._eye_bone)))
				lid_max = maxf(lid_max, lid0.angle_to(
						hero.skeleton.get_bone_pose_rotation(hero._lid_bones[0])))
			print("[SWEEP] EYE moved %.4f rad, LID moved %.4f rad  %s"
					% [eye_max, lid_max,
					"PERFORMING" if eye_max > 0.01 and lid_max > 0.05
					else "STATIC — the eye is furniture"])
		print("[SWEEP] MOTION over 2.5 s: tip %.4f rad, mid %.4f rad  %s"
				% [moved_tip, moved_mid,
				"MOVING" if moved_tip > 0.002 else "STATIC — the rig is not driven"])
	# Its real extent, from the meshes themselves rather than from a guess.
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for mi in hero.meshes:
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		lo = lo.min(box.position)
		hi = hi.max(box.end)
	var mid := (lo + hi) * 0.5
	var reach: float = maxf(0.4, (hi - lo).length())
	print("[SWEEP] hero spans %s .. %s (%.2f m)" % [lo, hi, reach])
	var shots := [
		["H1_whole", mid, reach * 0.95],
		["H2_ocular", mid, 0.34],
		["H3_root", Vector3(mid.x, lo.y + (hi.y - lo.y) * 0.12, mid.z), 0.55],
		["H4_three_quarter", mid, reach * 0.55],
	]
	if OS.get_environment("SWEEP_VIDEO") == "1":
		var aim0: Vector3 = mid_of(lo, hi)
		var d0: float = reach * 0.72
		var dir0 := _view_dir(aim0, Vector3.FORWARD, d0)
		_look_at_from(aim0 + dir0 * d0 + Vector3.UP * 0.05, aim0)
		for f in 150:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					_dir.path_join("v_%04d.png" % f))
		print("[SWEEP] 150 frames of motion")
	for shot in shots:
		var aim: Vector3 = shot[1]
		var dist: float = float(shot[2])
		var dir := _view_dir(aim, Vector3.FORWARD, dist)
		_look_at_from(aim + dir * dist + Vector3.UP * 0.05, aim)
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("%s.png" % str(shot[0])))
		_frame += 1
		print("[SWEEP] %s at %s (%.2f m)" % [str(shot[0]), aim, dist])


func mid_of(lo: Vector3, hi: Vector3) -> Vector3:
	return (lo + hi) * 0.5


## §37 — at least six nearby appendages must be clearly different WITHOUT
## relying on colour, and the edge must never look like repeated noodles.
## Only a photograph can settle that.
func _margin_shots() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var margin = enc.get("margin") if enc != null else null
	if margin == null:
		printerr("[SWEEP] no margin — run with DREAM_MARGIN unset")
		return
	var lit_min := Vector3(-13.45, 3.45, 0.65)
	var lit_max := Vector3(-5.75, 6.10, 6.05)
	var here: Array = []
	for attempt in 90:
		await get_tree().create_timer(0.5).timeout
		here.clear()
		for p in margin.palps:
			var q: Vector3 = p.anchor
			if q.x >= lit_min.x and q.y >= lit_min.y and q.z >= lit_min.z 					and q.x <= lit_max.x and q.y <= lit_max.y and q.z <= lit_max.z 					and absf((p.normal as Vector3).y) < 0.6:
				here.append(p)
		if attempt % 8 == 0:
			print("[SWEEP] waiting: %s, %d on lit walls" % [margin.census(), here.size()])
		if here.size() >= 5:
			break
	if here.is_empty():
		printerr("[SWEEP] no appendages on a lit wall")
		return
	# The densest cluster, so several archetypes are in one frame.
	# Frame the most VARIED cluster, not the biggest. §37 is about difference,
	# and the biggest cluster on the first run was six whiskers.
	var best := 0
	var best_score := -1.0
	for i in here.size():
		var near := {}
		var n := 0
		for j in here.size():
			if (here[j].anchor as Vector3).distance_to(here[i].anchor) < 1.1:
				near[here[j].morph.name_of_kind()] = true
				n += 1
		var score := float(near.size()) * 10.0 + float(n)
		if score > best_score:
			best_score = score
			best = i
	var best_n := 0
	for j in here.size():
		if (here[j].anchor as Vector3).distance_to(here[best].anchor) < 1.1:
			best_n += 1
	var kinds := {}
	for p in here:
		if (p.anchor as Vector3).distance_to(here[best].anchor) < 1.1:
			kinds[p.morph.name_of_kind()] = true
	var aim: Vector3 = here[best].anchor
	print("[SWEEP] cluster of %d at %s, archetypes %s" % [best_n, aim, kinds.keys()])
	for shot in [["M1_edge", 1.9], ["M2_gameplay", 1.1], ["M3_close", 0.42]]:
		var dist := float(shot[1])
		var dir := _view_dir(aim, here[best].normal, dist)
		_look_at_from(aim + dir * dist + Vector3.UP * 0.04, aim)
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("%s.png" % str(shot[0])))
		_frame += 1
		print("[SWEEP] %s" % str(shot[0]))


## §37's acceptance test, arranged deliberately: one of every archetype in a
## row on a wall in 2A, photographed at three distances.
func _archetype_row() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var margin = enc.get("margin") if enc != null else null
	if margin == null:
		printerr("[SWEEP] no margin")
		return
	# A real wall in the lit flat, found rather than guessed.
	var space := get_viewport().find_world_3d().direct_space_state
	var from := Vector3(-9.6, 4.60, 3.9)   # inside 2A main
	var found := {}
	for step in 16:
		var a := float(step) / 16.0 * TAU
		var dir := Vector3(cos(a), 0.0, sin(a))
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 5.0)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		if absf((hit.normal as Vector3).y) > 0.4:
			continue
		found = hit
		break
	if found.is_empty():
		printerr("[SWEEP] no wall found for the arrangement")
		return
	var at: Vector3 = found.position
	var nrm: Vector3 = (found.normal as Vector3).normalized()
	margin.frozen = true
	var n: int = margin.arrange_archetype_row(at + nrm * 0.02, nrm, 0.27)
	print("[SWEEP] arranged %d archetypes at %s" % [n, at])
	await get_tree().create_timer(1.5).timeout
	var kinds: Array = []
	for p in margin.palps:
		kinds.append(p.morph.name_of_kind())
	print("[SWEEP] row: %s" % [kinds])
	# Obliquely and from slightly above: head-on, the row is 1.7 m wide and a
	# 62-degree lens at a metre sees about one, and appendages growing along
	# the wall normal are foreshortened into blobs. From the side they are
	# seen in PROFILE, which is what §37 is asking about.
	var any2 := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
	var row_side := any2.cross(nrm).normalized()
	# A hard side view loses them altogether: appendages against a wall go
	# edge-on and vanish. Mostly head-on with a small offset, so each one is
	# seen slightly from the side and the whole row still fits the lens.
	for shot in [["A1_row_gameplay", 2.30, 0.42, 0.30],
			["A2_row_close", 1.45, 0.28, 0.20],
			["A3_row_macro", 0.80, 0.16, 0.12]]:
		var dist := float(shot[1])
		var lateral := float(shot[2])
		var lift := float(shot[3])
		_look_at_from(at + nrm * dist + row_side * lateral + Vector3.UP * lift, at)
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("%s.png" % str(shot[0])))
		_frame += 1
		print("[SWEEP] %s" % str(shot[0]))


## §25 — critters, on the actual architecture, under the player's own lamp.
func _critter_shots() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var ctrl = enc.get("critters") if enc != null else null
	if ctrl == null:
		printerr("[SWEEP] no critter controller")
		return
	var lit_min := Vector3(-13.45, 3.45, 0.65)
	var lit_max := Vector3(-5.75, 6.10, 6.05)
	var here: Array = []
	for attempt in 90:
		await get_tree().create_timer(0.5).timeout
		here.clear()
		# The camera carries the player's own lamp, so a critter does not have
		# to be standing in a lit room to be photographed — and waiting for
		# one to be got three shots of the same species twice running, which
		# says nothing about whether the species are distinguishable.
		for c in ctrl.critters:
			here.append(c)
		var species_here := {}
		for c in here:
			species_here[String(c.morph.species)] = true
		if attempt % 10 == 0:
			print("[SWEEP] waiting: %s, %d species available"
					% [ctrl.census(), species_here.size()])
		if species_here.size() >= 3 or (attempt > 40 and here.size() >= 1):
			break
	if here.is_empty():
		printerr("[SWEEP] no critters in the lit flat")
		return
	# One of each species if they are available: three photographs of the same
	# animal say nothing about whether the species are distinguishable.
	var picked: Array = []
	var seen_species := {}
	for c in here:
		var sp: String = String(c.morph.species)
		if not seen_species.has(sp):
			seen_species[sp] = true
			picked.append(c)
	for c in here:
		if picked.size() >= 3:
			break
		if not picked.has(c):
			picked.append(c)
	# §24 — if one is currently doing its impossible thing, photograph THAT.
	for c in here:
		if bool(c.get("twin", false)):
			var mid: Vector3 = ((c.pos as Vector3) + (c.twin_pos as Vector3)) * 0.5
			var across: Vector3 = ((c.twin_pos as Vector3) - (c.pos as Vector3)).normalized()
			var any := Vector3.UP if absf(across.y) < 0.9 else Vector3.RIGHT
			var side := any.cross(across).normalized()
			print("[SWEEP] LAW: a seam grazer on both sides of a wall at %s" % mid)
			for d in [0.85, 0.45]:
				_look_at_from(mid + side * d + Vector3.UP * d * 0.35, mid)
				await get_tree().create_timer(0.35).timeout
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(
						_dir.path_join("LAW_both_sides_%.2f.png" % d))
				_frame += 1
			break
	for idx in picked.size():
		var c: Dictionary = picked[idx]
		var at: Vector3 = c.pos
		var species: String = String(c.morph.species)
		print("[SWEEP] %s at %s (%s)" % [species, at, c.morph.morph])
		for shot in [["gameplay", 1.05], ["close", 0.42], ["macro", 0.20]]:
			var dist := float(shot[1])
			var dir := _view_dir(at, c.up, dist)
			_look_at_from(at + dir * dist + Vector3.UP * 0.02, at)
			await get_tree().create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					_dir.path_join("C%d_%s_%s.png" % [idx, species, str(shot[0])]))
			_frame += 1


## §34 — THE CANONICAL DREAM ECOLOGY CAPTURE.
##
## One encroached flat, all three levels at once, under the player's own lamp,
## for twenty seconds. The point is not any single organism: it is that the
## hero, the margin and the critters are visibly the same biology at three
## resolutions, behaving independently -- and then, once, not independently.
##
## It logs a beat sheet of what actually happened rather than what was
## intended, because a capture that claims sixteen behaviours and shows four
## is worse than one that shows four and says so.
func _ecology_capture() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var margin = enc.get("margin")
	var critters = enc.get("critters")
	var hero = enc.get("hero")
	var director = enc.get("ecology")
	var residue = enc.get("residue")
	if margin == null or critters == null or hero == null or director == null:
		printerr("[SWEEP] the ecology is not fully present")
		return
	var fps := 24
	var seconds := float(OS.get_environment("SWEEP_SECONDS").to_float())
	if seconds < 1.0:
		seconds = 20.0
	var frames := int(fps * seconds)
	# Frame the hero's own stretch of wall: it is the largest thing here and
	# the margin grows thickest around it.
	# PLACE THE HERO DELIBERATELY. Its own rule -- take the first vertical
	# surface a ray finds -- is right for play and wrong for a review: it put
	# the creature inside a glass door and behind panelling, and a canonical
	# capture should not be a lottery. Choose the wall in this flat with the
	# most clear room in front of it, exactly as §37's archetype row does.
	var space := get_viewport().find_world_3d().direct_space_state
	var from := Vector3(-9.6, 4.55, 3.4)
	var best_wall := {}
	var best_clear := 0.0
	for step in 24:
		var a := float(step) / 24.0 * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 6.0)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var nrm2: Vector3 = (hit.normal as Vector3).normalized()
		if absf(nrm2.y) > 0.35:
			continue
		# How much open room is in front of this wall -- and is that room
		# INSIDE the flat? A boundary wall's outward normal points into the
		# landing, which is four clear metres of somewhere else entirely, and
		# that is where the camera kept ending up.
		var out_from: Vector3 = (hit.position as Vector3) + nrm2 * 0.08
		var probe_in: Vector3 = (hit.position as Vector3) + nrm2 * 1.2
		if probe_in.x < -13.45 or probe_in.x > -5.75 				or probe_in.z < 0.65 or probe_in.z > 6.05:
			continue
		var q2 := PhysicsRayQueryParameters3D.create(out_from, out_from + nrm2 * 4.0)
		var block: Dictionary = space.intersect_ray(q2)
		var clear: float = 4.0 if block.is_empty() 				else out_from.distance_to(block.position)
		if clear > best_clear:
			best_clear = clear
			best_wall = {"pos": hit.position, "nrm": nrm2}
	if not best_wall.is_empty():
		# MOVE it, do not set it up again: setup() instantiates a fresh glTF
		# and appends to the mesh list, so calling it twice leaves two
		# creatures in the room and a census that counts both.
		var at: Vector3 = (best_wall.pos as Vector3) + (best_wall.nrm as Vector3) * 0.04
		var aim: Vector3 = best_wall.nrm
		var up_hint := Vector3.UP if absf(aim.y) < 0.9 else Vector3.RIGHT
		hero.look_at_from_position(at, at + aim, up_hint)
		# And make sure it is PRESENT. It cycles through cross-sectional
		# withdrawal on every third departure, and while absent its shader
		# discards every fragment -- a capture that began mid-withdrawal
		# photographed an empty room with the camera 0.67 m from the creature.
		hero.state = 0                # SEEKING
		hero.state_clock = 0.0
		hero.slice_close = 0.0
		print("[SWEEP] hero moved to the clearest wall (%.2f m of room) at %s"
				% [best_clear, at])
		await get_tree().create_timer(2.0).timeout

	# Frame the limb from the side it emerges INTO. Orbiting the root put the
	# camera against the wall the hero comes out of, looking at bare panelling
	# with the entire ecology behind it.
	var outward: Vector3 = -(hero.global_transform.basis.z).normalized()
	var focus: Vector3 = hero.global_position + outward * 0.55
	var up_h := Vector3.UP
	var across: Vector3 = outward.cross(up_h).normalized()
	var seen := {"branch": false, "attention": false, "twin": false,
			"fold": false, "residue": false, "brave": false, "shoved": false}
	print("[SWEEP] ecology capture: %d frames at %d fps" % [frames, fps])
	print("[SWEEP]   hero at %s, outward %s, focus %s"
			% [hero.global_position, outward, focus])
	var probe_eye: Vector3 = focus + outward * 2.25 + Vector3(0.0, 0.30, 0.0)
	print("[SWEEP]   first eye would be %s" % probe_eye)
	var glo := Vector3(1e9, 1e9, 1e9)
	var ghi := Vector3(-1e9, -1e9, -1e9)
	for mi in hero.meshes:
		var b: AABB = (mi as MeshInstance3D).global_transform 				* (mi as MeshInstance3D).get_aabb()
		glo = glo.min(b.position)
		ghi = ghi.max(b.end)
	print("[SWEEP]   hero GEOMETRY spans %s .. %s (%d meshes)"
			% [glo, ghi, hero.meshes.size()])
	for f in frames:
		var t := float(f) / float(fps)
		# A slow arc past the wall, ending closer than it began.
		var swing := sin(t * 0.22) * 0.85
		# 2.25 m put a partition between the camera and the creature: the
		# archetype row photographs this same wall from about 1.5 m and the
		# obstruction sits somewhere between. Stay inside it.
		var dist := 1.75 - t * 0.020
		# Ask for a direction that can actually SEE the creature. Computing a
		# stand-off from the wall normal alone put the camera on the far side
		# of a partition -- the arithmetic was right and the room was not.
		# _view_dir raycasts, which is why the other capture modes work.
		var want_dir: Vector3 = (outward + across * (swing / maxf(0.2, dist))
				+ Vector3(0.0, 0.13, 0.0)).normalized()
		# A stand that is INSIDE THE ROOM and can SEE the creature. _view_dir
		# alone samples the whole sphere and will happily choose a clear line
		# from outside the building, which is where the last attempt ended up.
		var eye: Vector3 = _stand_in_room(focus, want_dir, dist)
		# Something else takes the camera back during this mode -- the frames
		# came out as the ordinary player view, nameplate and all, while the
		# sweep camera sat exactly where it had been told to. Re-assert it.
		if not cam.current:
			cam.make_current()
			root.view_override = cam
		_look_at_from(eye, focus)
		# §13 once, at the two-thirds mark, so there is an independent ecology
		# to interrupt and time left to watch autonomy come back.
		if f == int(frames * 0.62):
			director.seize_attention(focus + Vector3(0.35, 0.1, 0.0))
			print("[SWEEP] t=%.1f  GLOBAL ATTENTION" % t)
		var mc: Dictionary = margin.census()
		var cc: Dictionary = critters.census()
		if int(mc.get("branches", 0)) > 0:
			seen.branch = true
		if director.attending != Vector3.INF:
			seen.attention = true
		if int(cc.get("on_both_sides", 0)) > 0:
			seen.twin = true
		if int(cc.get("folding_a_leg", 0)) > 0:
			seen.fold = true
		if int(cc.get("approaching_hero", 0)) > 0:
			seen.brave = true
		if int(cc.get("nudged_by_a_palp", 0)) > 0:
			seen.shoved = true
		if residue != null and int(residue.census().get("live", 0)) > 0:
			seen.residue = true
		await RenderingServer.frame_post_draw
		if f == 12:
			var active := get_viewport().get_camera_3d()
			print("[SWEEP]   hero state %s slice %.2f"
					% [hero.state_name(), hero.slice_close])
			print("[SWEEP]   at frame 12 cam is at %s; the ACTIVE camera is "
					% cam.global_position
					+ "%s at %s" % [active.name if active != null else "<none>",
					active.global_position if active != null else Vector3.ZERO])
		get_viewport().get_texture().get_image().save_png(
				_dir.path_join("eco_%04d.png" % f))
		_frame += 1
	print("[SWEEP] BEAT SHEET (what actually happened, not what was intended):")
	for k in seen:
		print("[SWEEP]   %-10s %s" % [k, "yes" if seen[k] else "NO"])
	print("[SWEEP] margin %s" % [margin.census()])
	print("[SWEEP] critters %s" % [critters.census()])


## A camera position that satisfies both constraints at once: inside the
## flat, and with an unobstructed line to what it is looking at. Neither on
## its own is enough -- clear line of sight from the wrong side of a wall is
## how three separate attempts at this shot ended up in a stairwell, in a
## glass door, and outdoors at night.
func _stand_in_room(target: Vector3, prefer: Vector3, dist: float) -> Vector3:
	var lo := Vector3(-13.30, 3.60, 0.80)
	var hi := Vector3(-5.90, 5.90, 5.90)
	var space := get_viewport().find_world_3d().direct_space_state
	var best := target + prefer * dist
	var best_score := -1.0
	for i in 40:
		var cand: Vector3
		if i == 0:
			cand = target + prefer * dist
		else:
			var a := float(i) / 40.0 * TAU
			var lift := 0.10 + 0.35 * float(i % 3) / 3.0
			var d := (prefer + Vector3(cos(a), lift, sin(a)) * 0.9).normalized()
			cand = target + d * dist
		if cand.x < lo.x or cand.y < lo.y or cand.z < lo.z 				or cand.x > hi.x or cand.y > hi.y or cand.z > hi.z:
			continue
		var q := PhysicsRayQueryParameters3D.create(cand, target)
		if not space.intersect_ray(q).is_empty():
			continue
		var score: float = prefer.dot((cand - target).normalized())
		if score > best_score:
			best_score = score
			best = cand
	return best
