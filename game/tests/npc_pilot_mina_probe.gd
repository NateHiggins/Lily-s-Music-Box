extends Node3D
## NPC repair pilot (order w3473eaaf58a9), step 1: reproduce. Mina's rebuilt body plays each of her clips; the probe
## samples the clip pose (no modifiers) and reports per clip: cycle length, Hips travel, foot height range, and in
## the stance phase how fast a planted foot moves (the speed the body must travel for the foot not to slide). It
## then compares that with the speed MinaAnimationBehavior plays the walk at for the route's speed.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const Behaviour := preload("res://scripts/characters/mina_animation_behavior.gd")
const RATE := 120.0

var report := {}


func _ready() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _sample(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.get_bone_global_pose(bone).origin


func _clip(player: AnimationPlayer, skeleton: Skeleton3D, clip: String) -> Dictionary:
	var anim := player.get_animation(clip)
	var length := anim.length
	var feet := {"L": skeleton.find_bone("LeftToeBase"), "R": skeleton.find_bone("RightToeBase")}
	var ankles := {"L": skeleton.find_bone("LeftFoot"), "R": skeleton.find_bone("RightFoot")}
	var hips := skeleton.find_bone("Hips")
	player.play(clip)
	player.speed_scale = 1.0
	var head := skeleton.find_bone("Head")
	var yaw_sum := 0.0
	var lean_sum := 0.0
	var samples := 0
	for k in 21:
		player.seek(length * k / 20.0, true)
		skeleton.force_update_all_bone_transforms()
		var hb := skeleton.get_bone_global_pose(hips).basis
		# The body's facing: the hips' horizontal direction from the right hip to the left, turned a quarter.
		var lh := skeleton.get_bone_global_pose(skeleton.find_bone("LeftUpLeg")).origin
		var rh := skeleton.get_bone_global_pose(skeleton.find_bone("RightUpLeg")).origin
		var across := lh - rh
		yaw_sum += rad_to_deg(atan2(across.z, across.x))
		# Lean: hips-to-head direction against vertical, forward positive (+Z forward).
		var up := skeleton.get_bone_global_pose(head).origin - skeleton.get_bone_global_pose(hips).origin
		lean_sum += rad_to_deg(atan2(up.z, up.y))
		samples += 1
	var facing := {"yaw_deg": snappedf(yaw_sum / samples, .1), "lean_deg": snappedf(lean_sum / samples, .1)}
	var steps := int(ceil(length * RATE))
	var track := {"L": [], "R": [], "AL": [], "AR": [], "H": []}
	for i in steps + 1:
		var t := minf(i / RATE, length)
		player.seek(t, true)
		skeleton.force_update_all_bone_transforms()
		for side: String in ["L", "R"]:
			track[side].append(_sample(skeleton, feet[side]))
			track["A" + side].append(_sample(skeleton, ankles[side]))
		track["H"].append(_sample(skeleton, hips))
	# Forward axis: the horizontal axis along which the feet move most.
	var spread := Vector3.ZERO
	for side: String in ["L", "R"]:
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p: Vector3 in track[side]:
			lo = lo.min(p)
			hi = hi.max(p)
		spread = spread.max(hi - lo)
	var axis := Vector3(0, 0, 1) if spread.z >= spread.x else Vector3(1, 0, 0)
	var out := {"length": snappedf(length, .001), "axis": "z" if axis.z else "x"}
	out.merge(facing)
	var floor_y := INF
	var top_y := -INF
	for side: String in ["L", "R", "AL", "AR"]:
		for p: Vector3 in track[side]:
			floor_y = minf(floor_y, p.y)
			top_y = maxf(top_y, p.y)
	out["foot_y_min"] = snappedf(floor_y, .001)
	out["foot_y_max"] = snappedf(top_y, .001)
	var h0: Vector3 = track["H"][0]
	var h1: Vector3 = track["H"][-1]
	out["hips_travel"] = snappedf((h1 - h0).dot(axis), .001)
	out["hips_y"] = [snappedf(h0.y, .001)]
	# Stance: a toe within 1.5 cm of its own lowest point; its forward speed there is the treadmill speed.
	var stance_speeds: Array[float] = []
	var lateral := 0.0
	for side: String in ["L", "R"]:
		var points: Array = track[side]
		var low := INF
		for p: Vector3 in points:
			low = minf(low, p.y)
		for i in range(1, points.size()):
			var a: Vector3 = points[i - 1]
			var b: Vector3 = points[i]
			if a.y < low + .015 and b.y < low + .015:
				stance_speeds.append(-(b - a).dot(axis) * RATE)
	# Weight foot: whichever toe is lower carries the body; its backward and downward speed is what the ground
	# must supply. Median over the cycle, frames where the toes are within 2 cm of each other left out.
	var back: Array[float] = []
	var down: Array[float] = []
	for i in range(1, track["L"].size()):
		var la: Vector3 = track["L"][i - 1]
		var lb: Vector3 = track["L"][i]
		var ra: Vector3 = track["R"][i - 1]
		var rb: Vector3 = track["R"][i]
		if absf(lb.y - rb.y) < .02:
			continue
		var a := la if lb.y < rb.y else ra
		var b := lb if lb.y < rb.y else rb
		back.append(-(b - a).dot(axis) * RATE)
		down.append(-(b.y - a.y) * RATE)
	back.sort()
	down.sort()
	if back.size() > 8:
		out["weight_back_median"] = snappedf(back[back.size() / 2], .001)
		out["weight_back_q1"] = snappedf(back[back.size() / 4], .001)
		out["weight_back_q3"] = snappedf(back[back.size() * 3 / 4], .001)
		out["weight_down_median"] = snappedf(down[down.size() / 2], .001)
		out["weight_frames"] = back.size()
	# Step count: how many times the lower foot changes over one cycle.
	var swaps := 0
	var lower_left: bool = track["L"][0].y < track["R"][0].y
	for i in track["L"].size():
		var now: bool = track["L"][i].y < track["R"][i].y
		if now != lower_left and absf(track["L"][i].y - track["R"][i].y) > .02:
			swaps += 1
			lower_left = now
	out["steps"] = swaps
	stance_speeds.sort()
	if stance_speeds.size() > 4:
		out["stance_speed_median"] = snappedf(stance_speeds[stance_speeds.size() / 2], .001)
		out["stance_speed_p10"] = snappedf(stance_speeds[stance_speeds.size() / 10], .001)
		out["stance_speed_p90"] = snappedf(stance_speeds[stance_speeds.size() * 9 / 10], .001)
		out["stance_frames"] = stance_speeds.size()
	return out


func _fingers(player: AnimationPlayer, skeleton: Skeleton3D) -> Dictionary:
	var anim := player.get_animation("mina_walk")
	var tracked: Array[String] = []
	for t in anim.get_track_count():
		var path := str(anim.track_get_path(t))
		if "Hand" in path and ("Index" in path or "Thumb" in path or "Middle" in path or "Ring" in path or "Pinky" in path):
			tracked.append(path)
	var bones: Array[String] = []
	for b in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(b)
		if "HandIndex" in n or "HandThumb" in n:
			bones.append(n)
	return {"finger_tracks_in_walk": tracked.size(), "finger_bones": bones.size(), "sample": tracked.slice(0, 4)}


func run() -> void:
	RealityState.persistence_enabled = false
	CastBodies.set_for_test(["mina_vale"])
	var mina := Presentation.new()
	mina.setup("Mina Vale", "mina_vale", "2A", CastBodies.model_for("mina_vale"))
	mina.externally_driven = true
	add_child(mina)
	await frames(8)
	var body: Node3D = mina.cast_body
	if body == null or mina._animation_player == null:
		print("PILOT PROBE: no cast body")
		get_tree().quit(1)
		return
	var player: AnimationPlayer = mina._animation_player
	var skeleton: Skeleton3D = body.skeleton
	report["bones"] = skeleton.get_bone_count()
	report["fingers"] = _fingers(player, skeleton)
	var clips := {}
	for clip: String in Behaviour.CLIPS:
		if player.has_animation(clip):
			clips[clip] = _clip(player, skeleton, clip)
	report["clips"] = clips
	# What the behaviour plays for the route's usual speeds.
	var plays := {}
	for v: float in [0.8, 1.05, 1.2, 1.5]:
		var b := Behaviour.new()
		b.player = player
		b.set_motion(true, 0.0, v)
		plays[str(v)] = {"role": b.motion_role, "speed_scale": snappedf(b.motion_speed, .001)}
	report["behaviour"] = plays
	var out := OS.get_environment("PILOT_OUT")
	var text := JSON.stringify(report, "  ")
	if not out.is_empty():
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("PILOT PROBE REPORT ", text)
	get_tree().quit(0)
