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
	if _tentacle == null and not (OS.get_environment("SWEEP_MODE") in ["tendrils", "modelled", "margin"]):
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
func _modelled_hero_shots() -> void:
	var enc: Node = root.get("apartment_encroachment")
	var hero = enc.get("hero") if enc != null else null
	if hero == null:
		printerr("[SWEEP] no modelled hero — run with DREAM_HERO=1")
		return
	print("[SWEEP] hero census %s" % [hero.census()])
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
