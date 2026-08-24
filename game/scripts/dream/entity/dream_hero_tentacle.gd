class_name DreamHeroTentacle
extends Node3D
## THE MODELLED HERO, IN THE GAME.
##
## The Blender creature existed as an asset and nothing instantiated it: a
## grep for `dream_tentacle.glb` found exactly one reference, in the test that
## probes it. A hero nobody spawns is a file, not a character.
##
## This puts it in the world and dresses it. Every mesh in the glTF keeps the
## geometry Blender authored and the skin the armature drives, and takes the
## shared Dream material stack through `dream_hero_skin.gdshader`, which reads
## the anatomy from the masks the model carries rather than rediscovering it.
##
## The procedural limb is NOT replaced here: it is shelved (owner ruling
## 2026-08-22) and its grist lives on in DreamSurfaceTendrils. This is the
## thing that ruling made the hero.

const HERO_SCENE := preload("res://assets/dream/tentacle/dream_tentacle.glb")
const SKIN := preload("res://shaders/dream_hero_skin.gdshader")
const ANATOMY := preload("res://assets/dream/tentacle/T_dream_hero_anatomy.png")

## Name prefix -> the `system_kind` the skin dresses it as.
const SYSTEMS := {
	"GOLD": 1, "DENDRITE": 1,
	"CRYSTAL": 2,
	"MEMBRANE": 3,
	"SUCKER": 4,
	"CILIUM": 5,
}

var rig: Node3D = null
var meshes: Array[MeshInstance3D] = []
var materials: Array[ShaderMaterial] = []
var field = null
## 0 not through at all, 1 fully out. §2's MEMBRANE_BULGE and EMERGING drive
## it; the shader collapses the un-emerged part onto the membrane so the limb
## extrudes rather than appearing.
var grow := 0.0

var _clock := 0.0
var _seeded := 0.0
## The armature, and its deform bones in order from root to tip.
var skeleton: Skeleton3D = null
var _bones: PackedInt32Array = PackedInt32Array()
var _rest: Array[Quaternion] = []
## Where the creature is currently attending. Its own, not the player's.
var _attend := Vector3.ZERO
## §36 — the eye is the hero's face. Its own controls, its own clock.
var watch: Node3D = null
## §22 — the ecology it belongs to. It notices what is near it.
var critters = null
var noticing := Vector3.INF
## §13 — while the whole ecology is looking at one thing, so is it.
var attention_override := Vector3.INF
var _eye_bone := -1
var _lid_bones: PackedInt32Array = PackedInt32Array()
var _eye_rest: Array[Quaternion] = []
var _gaze := Vector3.FORWARD
var _gaze_hold := 0.0
var _blink := 0.0
var _blink_next := 3.0
var _nict := 0.0
var _nict_next := 1.7
var _attend_clock := 0.0
var _settle := 0.0

## §2 — the hero's behaviour states. Not all fifteen yet; these are the ones
## contact makes meaningful, and the rest have nothing to drive them.
## §2's fifteen. The first two are how it ARRIVES -- until they existed the
## creature was simply present from the first frame, which is the one thing a
## thing coming through from somewhere else should never be.
enum State { SEEKING, APPROACHING, HOVER_INSPECTION, TOUCHING, CARESSING,
		WITHDRAW, RESUME, CROSS_SECTION_WITHDRAW, ABSENT, RETURNING,
		MEMBRANE_BULGE, EMERGING, ORIENTING, TASTING, WATCH_PLAYER,
		INTERACT_MARGIN, INTERACT_CRITTER, FLINCH }
signal touched(where: Vector3, normal: Vector3)
signal released()
## H6 — it stopped having a cross-section. Not "it left".
signal sliced_out()
signal sliced_in()

var state: int = State.MEMBRANE_BULGE
var state_clock := 0.0
## What it is currently interested in: a real point on a real surface.
var target := Vector3.INF
var target_normal := Vector3.UP
var contact_point := Vector3.INF
var _space: PhysicsDirectSpaceState3D = null
var _caress_dir := Vector3.ZERO
var _last_tip := Vector3.INF
## §2's arrival. It starts having not arrived.
var _bulge := 0.0
## What most recently startled it, and how hard.
var _startle := 0.0
## Margin appendages currently on it, and the critter it is minding.
var margin = null
var _palps_on_me := 0
## The same periods the procedural limb runs on -- it is the same animal.
const PULSE_S := 1.47
const BREATH_S := 5.3

var _minding := Vector3.INF
## Whether this particular encounter has already had its nudge. One per
## meeting: a club resting against an animal is not nudging it repeatedly.
var _nudged_one := false
## How many animals it has actually touched, for the contract.
var nudged_critters := 0
## Its own clock for noticing the margin. Gating this on `state_clock` meant
## gating it on how long the CURRENT state had run -- which resets on every
## transition, so a threshold of three seconds was almost never reached and
## the hero never once noticed the appendages collecting on it.
var _margin_notice_gap := 0.0
## 0 fully present, 1 no cross-section at all.
var slice_close := 0.0
## How many ordinary withdrawals happen before it leaves the impossible way.
var _withdrawals := 0
const SLICE_EVERY := 3
## How near the tip must come before it counts as touching.
const TOUCH_M := 0.09
## HOW HARD IT IS CURRENTLY REACHING.
##
## The first version was open loop: a fixed bend amplitude chosen to look like
## a search. Measured, it never arrived — 0 touches, closest approach 0.905 m
## against a 0.09 m threshold — because a gentle sampling bend moves the tip
## about 0.2 m and the targets were up to 1.3 m away. A creature that reaches
## for something and always misses by an arm's length is not reaching.
##
## So the bend closes the loop on its own error: while approaching, it commits
## harder until the tip is actually there, and relaxes when it is not
## reaching for anything.
var _reach_gain := 1.0
## §12 — SECONDARY MOTION. One layer moved: bones. Nothing lagged, settled,
## reseated or oscillated, and that cascade is what produces apparent mass:
##
##     bone moves first, muscle mass follows, flesh settles,
##     gold structure reseats, cilia oscillate, wet highlight stabilises
##
## The solve and the search produce INTENT. These carry the flesh's response
## to it, one frame behind and overshooting slightly, more so toward the tip
## where there is less muscle to hold it.
var _settled: Array[Quaternion] = []
var _bone_vel: PackedFloat32Array = PackedFloat32Array()
var _prev_desired: Array[Quaternion] = []
## How much the body is currently moving, for the wet highlight to settle
## against. Rises instantly, falls slowly: a wet surface stops shimmering a
## moment after the thing under it stops.
var motion := 0.0
var lag_root := 0.0
var lag_tip := 0.0
const REACH_GAIN_MAX := 2.2


func setup(seed_v: int, at: Vector3, aim: Vector3 = Vector3.FORWARD) -> void:
	name = "DreamHeroTentacle"
	_seeded = float(seed_v % 617) * 0.031
	var inst := HERO_SCENE.instantiate()
	add_child(inst)
	rig = inst
	global_position = at
	# THE CREATURE COMES OUT OF A SURFACE. The model is built along +Y with
	# the membrane at the origin, so "emerging" means aligning +Y with the
	# surface normal — not standing it up and letting it lie on the floor
	# like a prop, which is how the first frame in a real room came out.
	if aim.length_squared() > 0.001:
		# The model is built along +Y in Blender, but the glTF axis conversion
		# lands its long axis on -Z in Godot — which is exactly what look_at
		# points at a target. Aligning +Y by hand instead stood the creature
		# bolt upright out of the floor, which the first frame showed plainly.
		var target := at + aim.normalized()
		var up_hint := Vector3.UP if absf(aim.normalized().y) < 0.9 else Vector3.RIGHT
		look_at_from_position(at, target, up_hint)
	_collect(inst)
	_measure_body()
	_dress()
	_find_skeleton(inst)
	_seat_riders()
	var world := get_viewport().find_world_3d() if get_viewport() != null else null
	if world != null:
		_space = world.direct_space_state


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect(child)


## WHICH WAY THE BODY RUNS, AND HOW LONG IT IS.
##
## Measured from the meshes rather than assumed, because the answer depends on
## glTF's axis conversion and on whatever the Blender script last did to the
## profile table. The long axis is simply the one the creature is longest on;
## the ROOT end is whichever end of it lies nearer this node's own origin,
## which is where `setup` planted the creature in the wall.
var _axis := 2
var _root_at := 0.0
var _body_len := 1.0


func _measure_body() -> void:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for mi in meshes:
		var box: AABB = mi.transform * mi.get_aabb()
		lo = lo.min(box.position)
		hi = hi.max(box.end)
	var span := hi - lo
	_axis = 0
	if span.y > span[_axis]:
		_axis = 1
	if span.z > span[_axis]:
		_axis = 2
	_body_len = maxf(0.001, span[_axis])
	# The end nearer the node origin is the root.
	_root_at = lo[_axis] if absf(lo[_axis]) < absf(hi[_axis]) else hi[_axis]


## Where a piece sits along the body: 1 at the root, 0 at the tip, matching the
## cage's own UV.y so a rider shares the phase of the flesh it is seated in.
func _seat_of(mi: MeshInstance3D) -> float:
	var box: AABB = mi.transform * mi.get_aabb()
	var c: float = box.get_center()[_axis]
	return clampf(1.0 - absf(c - _root_at) / _body_len, 0.0, 1.0)


func _dress() -> void:
	for mi in meshes:
		var kind := _kind_of(mi.name)
		var mat := ShaderMaterial.new()
		mat.shader = SKIN
		mat.set_shader_parameter("system_kind", kind)
		# EVERY RIDER ITS OWN PHASE -- but a SMALL one, and not the flesh.
		#
		# All ninety-four riders shared one seed, so every gold plate carried
		# identical noise and every crystal the same fracture: ninety-four
		# copies of one surface distributed over a body.
		#
		# The cage keeps the BASE seed, because the flesh is one body and
		# should read as continuous along its whole length. And the offset is
		# small: the shared stack's noise loses precision at large
		# coordinates, and an offset of up to forty turned the creature into
		# white and blue blocks. The name is stable across rebuilds, so a
		# given plate keeps its own character.
		var piece_seed: float = _seeded
		if kind != 0:
			piece_seed += float(hash(mi.name) % 89) * 0.037
		mat.set_shader_parameter("hero_seed", piece_seed)
		# The mineral systems carry the light; the flesh receives it. The
		# minerals also vary a little in how much they carry -- within the
		# palette, not across it.
		#
		# This MULTIPLIES A KNOWN BASE rather than reading the parameter back.
		# Written the other way round it called get_shader_parameter() on a
		# parameter nothing had set yet, which returns null, and `null * float`
		# aborted _dress() in the middle of its loop. Every mesh after the
		# first gold plate then kept the material glTF import gave it, so the
		# hero came out as a chalk-white untextured body -- a shading bug with
		# no shader anywhere near it.
		var gain := 1.8 if kind == 1 else (1.4 if kind == 2 else 1.0)
		if kind == 1 or kind == 2:
			gain *= 0.72 + float(hash(mi.name) % 311) / 311.0 * 0.62
		mat.set_shader_parameter("emission_gain", gain)
		# ONE HEARTBEAT FOR THE WHOLE ANIMAL. The cage has UVs and carries the
		# vascular clock in uv.y; a rider has no UVs at all, so it read the
		# clock as zero and every plate on the body pulsed in unison, out of
		# step with the flesh under it. Each rider is told its own seat.
		mat.set_shader_parameter("rider_v", -1.0 if kind == 0 else _seat_of(mi))
		# H1 production default is rest-space. The off switch exists only so the
		# staged proof can reproduce the old room-fixed surface as its comparator.
		mat.set_shader_parameter("flesh_rest_space",
				OS.get_environment("HERO_FLESH_REST") != "0")
		mat.set_shader_parameter("grow", grow)
		mat.set_shader_parameter("anatomy_map", ANATOMY)
		mat.set_shader_parameter("anatomy_strength", 1.0)
		mi.material_override = mat
		# The creature is placed in a room and must never be culled by a
		# bounding box computed for its rest pose.
		mi.extra_cull_margin = 4.0
		materials.append(mat)


func _kind_of(mesh_name: String) -> int:
	var upper := mesh_name.to_upper()
	for prefix in SYSTEMS:
		if upper.begins_with(prefix) or upper.contains(prefix):
			return int(SYSTEMS[prefix])
	return 0


## THE RIG, FOUND AND ORDERED.
##
## The creature shipped with twenty-eight deform bones, nine secondary
## controls and rotation limits on the root -- and nothing driving any of
## them. It stood in the room at rest pose, which the owner spotted
## immediately: "the new tentacle is not animated at all".
func _find_skeleton(node: Node) -> void:
	if node is Skeleton3D:
		skeleton = node as Skeleton3D
	else:
		for child in node.get_children():
			_find_skeleton(child)
			if skeleton != null:
				return
		return
	# Deform bones in order along the limb. The glTF keeps Blender's names.
	var named: Array = []
	for i in skeleton.get_bone_count():
		var n := skeleton.get_bone_name(i)
		if n.begins_with("DEF_"):
			named.append([n, i])
	named.sort_custom(func(a, b): return _bone_order(a[0]) < _bone_order(b[0]))
	for pair in named:
		_bones.append(int(pair[1]))
		var q := skeleton.get_bone_pose_rotation(int(pair[1]))
		_rest.append(q)
		_settled.append(q)
		_prev_desired.append(q)
		_bone_vel.append(0.0)
	# The secondary controls. They existed in the rig from the start and
	# nothing was weighted to them, so the eye could not look and the lids
	# could not close; the Blender binder now puts the globe, iris, pupil,
	# cornea and three lids on them.
	_eye_bone = skeleton.find_bone("CTL_EYE")
	for n in ["CTL_LID_DORSAL", "CTL_LID_VENTRO", "CTL_LID_NICT"]:
		var b := skeleton.find_bone(n)
		_lid_bones.append(b)
		_eye_rest.append(skeleton.get_bone_pose_rotation(b) if b >= 0
				else Quaternion.IDENTITY)


## DEF_<label>_<index>: the labels run root to tip in BONE_PLAN order.
func _bone_order(bone_name: String) -> float:
	const ORDER := ["ROOT", "PROX", "OCULAR", "MID", "DISTAL", "TIP"]
	var parts := bone_name.split("_")
	var label := parts[1] if parts.size() > 2 else ""
	var idx := float(parts[parts.size() - 1].to_int())
	var band := float(ORDER.find(label.to_upper()))
	if band < 0.0:
		band = 9.0
	return band * 100.0 + idx


## The motion language (§13): THIS ORGANISM IS CONTINUOUSLY SAMPLING.
##
## Not idle noise. It holds a search posture, commits to a direction, reaches,
## settles, and picks somewhere new — and a peristaltic wave runs out along
## it the whole time, because that is how the length of a limb like this
## actually carries force. The root barely moves: the membrane grips it.
func _animate(delta: float) -> void:
	if skeleton == null or _bones.is_empty():
		return
	var n := _bones.size()
	# The body now reaches for a REAL POINT rather than a direction out of a
	# sine. `_attend` is derived from the target, so every pose the rig solves
	# toward is something the creature actually chose to touch.
	if target != Vector3.INF:
		var toward := (target - global_position)
		if toward.length() > 0.01:
			_attend = (global_transform.basis.inverse() * toward.normalized())
	else:
		_attend_clock -= delta
		if _attend_clock <= 0.0:
			_attend_clock = 2.6 + fmod(absf(sin(_clock * 12.7 + _seeded)) * 3.4, 3.4)
			_attend = Vector3(sin(_clock * 1.7 + _seeded * 3.1),
					sin(_clock * 0.9 + _seeded), cos(_clock * 1.3 + _seeded * 2.2))
			_settle = 0.0
	_settle = minf(1.0, _settle + delta * 0.85)
	# The reach eases in, then holds: committed, not oscillating.
	var reach: float = smoothstep(0.0, 1.0, _settle)
	for i in n:
		var t := float(i) / float(maxi(1, n - 1))
		# The collar grips the root. This is the rotation limit Blender
		# carries as a constraint, which glTF does not export -- so it lives
		# here too, or the limb tears through its own membrane.
		var grip: float = smoothstep(0.0, 0.16, t)
		# A peristaltic wave travelling OUT along the limb.
		var wave: float = sin(t * 9.0 - _clock * 2.1 + _seeded) * 0.034
		# The search: the distal third does the fine work, the shaft carries it.
		var fine: float = smoothstep(0.55, 1.0, t)
		var bend_x: float = (_attend.x * 0.115 * _reach_gain * reach * (0.35 + fine)
				+ wave) * grip
		var bend_z: float = (_attend.z * 0.115 * _reach_gain * reach * (0.35 + fine)
				+ wave * 0.7) * grip
		# Breathing: the whole body swells and settles under the search.
		var breathe: float = sin(_clock * 0.8 + t * 2.0) * 0.006 * grip
		var q := Quaternion(Vector3.RIGHT, bend_x + breathe) 				* Quaternion(Vector3.FORWARD, bend_z) 				* Quaternion(Vector3.UP, _attend.y * 0.02 * reach * fine * grip)
		skeleton.set_bone_pose_rotation(_bones[i], _rest[i] * q)


## §22 — IT NOTICES THEM.
##
##     "tiny critter clings to hero gold plate; hero eye notices it; distal
##      club nudges it"
##
## The hero is the ecology's face, and a face that never looks at anything
## alive near it is scenery. This is deliberately only the FIRST half of the
## interaction -- it looks -- because looking is what the eye is for and it
## costs nothing to be honest that the club does not yet nudge anything.
func _notice_neighbours(_delta: float) -> void:
	noticing = Vector3.INF
	if critters == null or not is_instance_valid(critters):
		return
	# It notices along its whole body, not only at the very tip: a critter
	# clinging to a gold plate halfway down is exactly §22's example. Measured
	# against tip AND root, the same way the critters measure the hero.
	var tip := tip_world()
	var best := 1.5
	for c in critters.critters:
		var d: float = minf(tip.distance_to(c.pos), global_position.distance_to(c.pos))
		if d < best:
			best = d
			noticing = c.pos


## §36 — THE EYE PERFORMS.
##
## An eye that drifts smoothly is a camera. A real one FIXES: it jumps to a
## thing, holds it while the head moves under it, and jumps again. So the gaze
## is saccadic — held still for a beat, then relocated in a few frames — and
## the lids run on their own clocks, because a blink that is synchronised to
## the gaze reads as a machine.
func _animate_eye(delta: float) -> void:
	if skeleton == null or _eye_bone < 0:
		return
	_gaze_hold -= delta
	if _gaze_hold <= 0.0:
		_gaze_hold = 0.7 + fmod(absf(sin(_clock * 9.3 + _seeded * 5.0)) * 2.4, 2.4)
		# It looks where it is reaching, and at whoever is watching it.
		var want := _attend
		# §13 outranks everything, including its own errand.
		if attention_override != Vector3.INF:
			want = (attention_override - global_position).normalized()
			_gaze = want
			_gaze_hold = 0.25
		# Something alive and close outranks whatever it was reaching for.
		elif noticing != Vector3.INF:
			want = (noticing - global_position).normalized()
		# It watches its own hands: whatever it is reaching for gets looked at.
		elif target != Vector3.INF:
			want = (target - global_position).normalized()
		if watch != null and is_instance_valid(watch):
			var to_watcher := (watch.global_position - global_position)
			if to_watcher.length() < 4.5:
				want = to_watcher.normalized()
		_gaze = want.normalized()
	# The globe turns quickly into its new fixation, then stops dead.
	var local := global_transform.basis.inverse() * _gaze
	var yaw: float = atan2(local.x, -local.z) * 0.5
	var pitch: float = asin(clampf(local.y, -1.0, 1.0)) * 0.5
	var target := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
	var cur := skeleton.get_bone_pose_rotation(_eye_bone)
	skeleton.set_bone_pose_rotation(_eye_bone, cur.slerp(target, 1.0 - pow(0.0006, delta)))
	# Two lids on a slow blink, the nictitating membrane on its own faster
	# sweep — three lids that move together are one lid.
	_blink = maxf(0.0, _blink - delta)
	_blink_next -= delta
	if _blink_next <= 0.0:
		_blink_next = 2.4 + fmod(absf(cos(_clock * 7.1 + _seeded)) * 4.0, 4.0)
		_blink = 0.26
	_nict = maxf(0.0, _nict - delta)
	_nict_next -= delta
	if _nict_next <= 0.0:
		_nict_next = 1.1 + fmod(absf(sin(_clock * 5.7 + _seeded * 2.0)) * 2.2, 2.2)
		_nict = 0.17
	for i in _lid_bones.size():
		var b := _lid_bones[i]
		if b < 0:
			continue
		var phase: float = _nict if i == 2 else _blink
		var span: float = 0.17 if i == 2 else 0.26
		# A blink is fast shut and slower open, never a symmetrical sine.
		var t: float = 1.0 - clampf(phase / span, 0.0, 1.0)
		var shut: float = smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.35, 1.0, t))
		var close: float = shut * (1.05 if i == 2 else 1.0)
		var axis := Vector3.RIGHT if i == 0 else (Vector3.LEFT if i == 1 else Vector3.UP)
		skeleton.set_bone_pose_rotation(b,
				_eye_rest[i] * Quaternion(axis, close * 0.85))


## REACHING IS A SOLVE, NOT A POSE (§11: "rig from function").
##
## Bending every bone toward a direction does not steer a tip anywhere in
## particular -- it curls the limb, and the tip ends up somewhere on a spiral.
## Measured: 0 touches, closest approach 0.905 m, and closing the loop on the
## bend amplitude only improved that to 0.760. The creature was always going
## to miss, because nothing in the loop knew where the tip actually was.
##
## Cyclic coordinate descent does. Working from the tip back toward the root,
## each bone rotates by the angle that carries the tip closer to the target,
## damped hard at the root -- the collar grips it, and a creature that swings
## from its base to touch something reads as a boom arm rather than a limb.
func _solve_reach(delta: float) -> void:
	if skeleton == null or _bones.is_empty() or target == Vector3.INF:
		return
	var n := _bones.size()
	var to_local := skeleton.global_transform.affine_inverse()
	var goal: Vector3 = to_local * target
	var before: Vector3 = skeleton.get_bone_global_pose(_bones[n - 1]).origin
	# The search motion rewrites every bone from rest each frame, so the solve
	# cannot accumulate across frames -- it has to converge inside one. Three
	# iterations did not: closest approach went 0.905 to 0.760 to 0.626 m and
	# stalled there.
	for iteration in 14:
		for k in range(n - 1, -1, -1):
			var tip_l: Vector3 = skeleton.get_bone_global_pose(_bones[n - 1]).origin
			if tip_l.distance_to(goal) < TOUCH_M * 0.5:
				return
			var joint := skeleton.get_bone_global_pose(_bones[k])
			var a := tip_l - joint.origin
			var b := goal - joint.origin
			if a.length() < 0.001 or b.length() < 0.001:
				continue
			a = a.normalized()
			b = b.normalized()
			var axis := a.cross(b)
			if axis.length() < 0.0001:
				continue
			axis = axis.normalized()
			var ang: float = acos(clampf(a.dot(b), -1.0, 1.0))
			# The root barely participates; the distal third does the work.
			var t := float(k) / float(maxi(1, n - 1))
			var authority: float = smoothstep(0.0, 0.30, t) * (0.25 + 0.75 * t)
			ang = clampf(ang * authority * 0.85, -0.26, 0.26)
			var local_axis: Vector3 = joint.basis.inverse() * axis
			var q := Quaternion(local_axis.normalized(), ang)
			skeleton.set_bone_pose_rotation(_bones[k],
					skeleton.get_bone_pose_rotation(_bones[k]) * q)
	if OS.get_environment("HERO_SOLVE_DEBUG") == "1":
		var after: Vector3 = skeleton.get_bone_global_pose(_bones[n - 1]).origin
		print("[solve] tip moved %.4f m in-frame; err %.3f -> %.3f"
				% [before.distance_to(after), before.distance_to(goal),
				after.distance_to(goal)])


## The world position of the creature's distal club.
func tip_world() -> Vector3:
	if skeleton == null or _bones.is_empty():
		return global_position
	var b: int = _bones[_bones.size() - 1]
	return skeleton.global_transform * skeleton.get_bone_global_pose(b).origin


## §27 — find something worth touching. Cast from the tip into the room and
## take a real surface, so the creature reaches for the architecture rather
## than for a number.
func _pick_target() -> bool:
	if _space == null:
		if OS.get_environment("HERO_TARGET_DEBUG") == "1":
			print("[hero] no space state at all")
		return false
	# CAST FROM THE ROOT, NOT FROM THE TIP.
	#
	# Casting outward from the tip put every target BEYOND full extension: a
	# limb anchored to a wall can curl, which brings its tip back toward the
	# root, but it cannot lengthen. Instrumenting the solver showed it exactly
	# — the tip moved 0.33 m in-frame and the error converged to 0.803 m and
	# stopped, which is a solver doing its best against an impossible goal.
	#
	# The reachable set is a shell around the ROOT, so that is where the rays
	# start and that is what bounds them.
	var forward := (global_transform.basis * Vector3.FORWARD).normalized()
	# From mid-limb, because the root sits 4 cm off a wall and most rays from
	# there hit that wall inside the dead zone.
	var from := global_position + forward * 0.55
	var reach_m: float = 1.55
	for attempt in 14:
		var a := float(attempt) / 14.0 * TAU + _seeded
		var swing := Vector3(cos(a), sin(a * 0.7 + _seeded) * 0.6, sin(a))
		var dir := (forward * 1.1 + swing).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach_m)
		q.exclude = []
		var hit: Dictionary = _space.intersect_ray(q)
		if hit.is_empty():
			continue
		# Inside the shell it can actually work in: not against its own root,
		# not at the very limit of extension.
		var d: float = global_position.distance_to(hit.position)
		if d < 0.35 or d > reach_m:
			if OS.get_environment("HERO_TARGET_DEBUG") == "1":
				print("[hero] hit %s at %.2f m — outside [0.35, %.2f]"
						% [hit.collider.name if hit.has("collider") else "?",
						d, reach_m])
			continue
		target = hit.position
		target_normal = (hit.normal as Vector3).normalized()
		# Somewhere to slide to once it has made contact, along the surface.
		var any := Vector3.UP if absf(target_normal.y) < 0.9 else Vector3.RIGHT
		_caress_dir = any.cross(target_normal).normalized()
		return true
	if OS.get_environment("HERO_TARGET_DEBUG") == "1":
		print("[hero] fourteen rays from %s, nothing usable" % from)
	return false


## §2 — the state machine. Each state owns how long it lasts and what ends it.
## Is the player close enough to be worth stopping for?
func _player_near(range_m: float = 3.2) -> bool:
	if watch == null or not is_instance_valid(watch):
		return false
	# From any part of it, not only its root. A limb whose club is half a
	# metre from your face has noticed you, whatever its root thinks -- the
	# same reasoning as its notice of critters.
	var at: Vector3 = watch.global_position
	return minf(global_position.distance_to(at), tip_world().distance_to(at)) 			< range_m


## §2's reactive states outrank whatever errand it was on. A creature that
## finishes tracing a skirting board while somebody walks up to it is a
## machine running a program.
func _interrupt(delta: float) -> bool:
	# Nothing interrupts arrival or departure: it is not there to interrupt.
	if state == State.MEMBRANE_BULGE or state == State.EMERGING 			or state == State.CROSS_SECTION_WITHDRAW or state == State.ABSENT 			or state == State.RETURNING or state == State.FLINCH:
		return false
	if _startle > 0.45 and state != State.FLINCH:
		state = State.FLINCH
		state_clock = 0.0
		return true
	# A critter within reach of the club is checked BEFORE the player. Something
	# touching you outranks somebody approaching you, and with the player
	# tested first a close animal was starved out entirely -- the hero spent
	# whole takes watching the room over the head of a critter on its own club.
	if critters != null and is_instance_valid(critters) 			and state != State.INTERACT_CRITTER:
		# Anywhere ON it, not only at the club: §22's own example is a critter
		# clinging to a gold plate, which is halfway down the shaft.
		var tip_now := tip_world()
		for c in critters.critters:
			var how_near: float = minf(tip_now.distance_to(c.pos),
					global_position.distance_to(c.pos))
			if how_near < 0.55:
				_minding = c.pos
				state = State.INTERACT_CRITTER
				state_clock = 0.0
				_nudged_one = false
				return true
	if _player_near(2.2) and state != State.WATCH_PLAYER 			and state != State.INTERACT_CRITTER:
		state = State.WATCH_PLAYER
		state_clock = 0.0
		return true
	# Enough appendages collected on it to be worth noticing (§11).
	_palps_on_me = 0
	if margin != null and is_instance_valid(margin):
		for p in margin.palps:
			if float(p.get("hero_near", 0.0)) > 0.6:
				_palps_on_me += 1
	if _palps_on_me >= 5 and state != State.INTERACT_MARGIN 			and _margin_notice_gap <= 0.0:
		_margin_notice_gap = 14.0
		state = State.INTERACT_MARGIN
		state_clock = 0.0
		return true
	return false


## Something happened worth flinching at. Called from outside -- the player's
## own interactions are the obvious source.
func startle(amount: float = 1.0) -> void:
	_startle = clampf(_startle + amount, 0.0, 2.0)
	# §10 — WARNING SIGNALS. The largest thing in the ecology flinching is the
	# loudest event the margin ever gets, and it used to be silent to it: the
	# hero jumped and forty appendages carried on probing skirting boards.
	# The alarm is local, and the social pass carries it outward from there.
	if margin != null and is_instance_valid(margin):
		margin.alarm(tip_world(), amount * 0.9, 1.9)


func _behave(delta: float) -> void:
	state_clock += delta
	var tip := tip_world()
	_startle = maxf(0.0, _startle - delta * 0.6)
	_margin_notice_gap = maxf(0.0, _margin_notice_gap - delta)
	if _interrupt(delta):
		return
	match state:
		State.MEMBRANE_BULGE:
			# Nothing is through yet. The membrane swells, and that is all a
			# watcher gets for a moment.
			_bulge = minf(1.0, state_clock / 1.6)
			grow = 0.0
			if state_clock > 1.9:
				state = State.EMERGING
				state_clock = 0.0
		State.EMERGING:
			# It extrudes. `grow` collapses the part not yet through onto the
			# membrane, so the limb comes OUT rather than switching on.
			grow = smoothstep(0.0, 1.0, state_clock / 2.4)
			if grow >= 1.0:
				state = State.ORIENTING
				state_clock = 0.0
		State.ORIENTING:
			# Arrived, and taking stock before doing anything.
			grow = 1.0
			if state_clock > 1.5:
				state = State.SEEKING
				state_clock = 0.0
		State.TASTING:
			# Distinct from caressing: short repeated contact in one place,
			# lifting between each. §9's "Taste".
			contact_point = tip
			if state_clock > 1.6:
				state = State.WITHDRAW
				state_clock = 0.0
				released.emit()
		State.WATCH_PLAYER:
			# It stops and looks. The most unsettling thing a creature can do
			# when you come near is nothing at all.
			target = Vector3.INF
			if state_clock > 2.6 or not _player_near():
				state = State.SEEKING
				state_clock = 0.0
		State.INTERACT_MARGIN:
			# §11 — it has noticed the appendages collecting on it.
			if state_clock > 2.2:
				state = State.SEEKING
				state_clock = 0.0
		State.INTERACT_CRITTER:
			# §22 — it minds the animal, and its club moves toward it. THE
			# NUDGE IS A REAL DISPLACEMENT, NOT AN ANIMATION: the critter
			# controller feels this as a push, and answers by putting its
			# sensory structures out. This comment stood over an empty state
			# for a while, describing a beat that never happened.
			if _minding != Vector3.INF:
				target = _minding
				var club := tip_world()
				# Only once the club has actually ARRIVED. Nudging from across
				# the room would be the creature acting at a distance, which
				# is the one thing this beat must not look like.
				if club.distance_to(_minding) < 0.18 					and critters != null and is_instance_valid(critters):
					var touched_c: Dictionary = critters.nudged_by_hero(
							_minding, club, delta)
					if not touched_c.is_empty():
						# Follow it: a nudged animal moves, and a creature
						# that kept reaching for where it used to be is not
						# looking at it.
						_minding = touched_c.pos
						if not _nudged_one:
							_nudged_one = true
							nudged_critters += 1
							# §22's last clause: the neighbours notice.
							if margin != null and is_instance_valid(margin):
								margin.orient_nearby(_minding, 0.9)
			if state_clock > 2.4:
				_minding = Vector3.INF
				state = State.SEEKING
				state_clock = 0.0
		State.FLINCH:
			# Fast, then still. It does not resume where it left off.
			target = Vector3.INF
			contact_point = Vector3.INF
			_reach_gain = move_toward(_reach_gain, 0.25, delta * 6.0)
			if state_clock > 1.1:
				state = State.ORIENTING
				state_clock = 0.0
		State.SEEKING:
			_reach_gain = move_toward(_reach_gain, 1.0, delta * 1.2)
			# Look for something. If nothing is in reach, keep searching, and
			# the body falls back to its own sampling motion.
			if state_clock > 1.2:
				state_clock = 0.0
				if _pick_target():
					_settle = 0.0
					state = State.APPROACHING
		State.APPROACHING:
			var d := tip.distance_to(target)
			# Commit harder while it is still short, and ease as it arrives —
			# §9's "Touch": velocity decreases before contact.
			var want: float = clampf(1.0 + d * 4.0, 1.0, REACH_GAIN_MAX)
			var rate: float = 1.6 if d > TOUCH_M * 3.0 else 0.5
			_reach_gain = move_toward(_reach_gain, want, delta * rate)
			if d < TOUCH_M:
				contact_point = tip
				state = State.TOUCHING
				state_clock = 0.0
				touched.emit(contact_point, target_normal)
				# Contact is an attempt to communicate, not merely a collision.
				# The hero reaches the ecology through the margin it already
				# belongs to; no parallel owner or case-specific wire is created.
				_emit_contact_signal(contact_point)
			elif state_clock > 6.0:
				state = State.HOVER_INSPECTION
				state_clock = 0.0
		State.HOVER_INSPECTION:
			# It could not reach. Hold near, look at it, then give up.
			if state_clock > 2.4:
				state = State.WITHDRAW
				state_clock = 0.0
		State.TOUCHING:
			contact_point = tip
			if state_clock > 1.1:
				# What it does having arrived is the most characterful choice
				# it makes: trace the surface, or sample one spot repeatedly.
				state = State.CARESSING if fmod(absf(_seeded * 31.0), 1.0) > 0.4 						else State.TASTING
				state_clock = 0.0
		State.CARESSING:
			# Trace along the surface rather than pressing into it.
			target += _caress_dir * delta * 0.09
			contact_point = tip
			if state_clock > 3.2:
				state = State.WITHDRAW
				state_clock = 0.0
				released.emit()
		State.WITHDRAW:
			_reach_gain = move_toward(_reach_gain, 0.4, delta * 2.0)
			target = Vector3.INF
			contact_point = Vector3.INF
			_settle = maxf(0.0, _settle - delta * 1.4)
			if state_clock > 1.6:
				_withdrawals += 1
				# Most departures are ordinary. Occasionally it leaves the way it
				# actually can. §15 asks for restraint: one impossible rule, used
				# rarely enough that it stays meaningful.
				if _withdrawals % SLICE_EVERY == 0:
					state = State.CROSS_SECTION_WITHDRAW
				else:
					state = State.RESUME
				state_clock = 0.0
		State.CROSS_SECTION_WITHDRAW:
			# H6. The length does not change. The thickness goes to nothing,
			# everywhere along it at the same instant. It is not retracting and it
			# is not fading: our slice is moving past it.
			slice_close = minf(1.0, state_clock / 2.2)
			if slice_close >= 1.0:
				state = State.ABSENT
				state_clock = 0.0
				sliced_out.emit()
		State.ABSENT:
			slice_close = 1.0
			target = Vector3.INF
			contact_point = Vector3.INF
			if state_clock > 1.8:
				state = State.RETURNING
				state_clock = 0.0
		State.RETURNING:
			# And it returns the same way: no cross-section, then some.
			slice_close = maxf(0.0, 1.0 - state_clock / 1.6)
			if slice_close <= 0.0:
				sliced_in.emit()
				state = State.SEEKING
				state_clock = 0.0
		State.RESUME:
			if state_clock > 0.8:
				state = State.SEEKING
				state_clock = 0.0
	_last_tip = tip


func _emit_contact_signal(at: Vector3) -> void:
	if margin == null or not is_instance_valid(margin) or margin.director == null:
		return
	margin.director.emit_signal_packet(-1,
			DreamEcologyDirector.SrcClass.HERO_LIMB,
			DreamEcologyDirector.Fn.SECRETE, at, 0.55, 1.0,
			DreamEcologyDirector.Chem.SECRETION, 1.0, 1.2,
			DreamEcologyDirector.SrcClass.PALP)


func state_name() -> String:
	return ["SEEKING", "APPROACHING", "HOVER_INSPECTION", "TOUCHING",
			"CARESSING", "WITHDRAW", "RESUME", "CROSS_SECTION_WITHDRAW",
			"ABSENT", "RETURNING", "MEMBRANE_BULGE", "EMERGING", "ORIENTING",
			"TASTING", "WATCH_PLAYER", "INTERACT_MARGIN", "INTERACT_CRITTER",
			"FLINCH"][state]


## §12 — the flesh's answer to what the bones just decided.
##
## Read the pose the solve and the search wrote as the INTENT, then move the
## actual pose toward it with a time constant that lengthens distally, and let
## it carry past and come back. A limb whose every joint arrives at once has
## no mass in it.
## H4 — EVERY RIDER ON THE BONE IT ACTUALLY SITS ON.
##
## The deform chain runs root to tip, and a rider's seat is already known, so
## the two only have to be matched up. This is what lets a plate near the club
## answer to the club whipping while a plate on the collar barely stirs.
var _rider_bone := PackedInt32Array()
var _rider_kind := PackedInt32Array()
var _rider_prev := PackedVector3Array()
var _rider_vel := PackedVector3Array()
var _rider_push := PackedVector3Array()
## Where each piece sits on its bone, and which way is "out" from that bone --
## both fixed in the bone's own frame, so they follow it for free.
var _rider_seat := PackedVector3Array()
var _rider_out := PackedVector3Array()
var _rider_rest: Array[Transform3D] = []
var _rider_spin: Array[Quaternion] = []
var _rider_tilt := PackedVector3Array()
var _rider_squash := PackedFloat32Array()
## §10 — how far each sucker's rim has spread, how deep its cup has drawn
## back, and the piece's own radius across its axis.
var _rider_spread := PackedFloat32Array()
var _rider_cup := PackedFloat32Array()
var _rider_radius := PackedFloat32Array()
## How far each system ROCKS when the flesh under it bends, in radians per
## radian-per-second of the seat's own turning. Gold and crystal are plates
## and rock most; a sucker is soft and mostly does not.
const RIDER_ROCK := [0.0, 0.030, 0.024, 0.0, 0.010, 0.0]
const RIDER_ROCK_CAP := [0.0, 0.075, 0.060, 0.0, 0.030, 0.0]
## How far a sucker flattens when it is pressed, and how close to the contact
## it has to be to feel it at all.
const SUCKER_SQUASH := 0.42
const SUCKER_REACH := 0.13

## How hard each system trails, and how quickly it comes back. A hair whips
## and takes its time; a mineral plate barely shifts and snaps back.
##            kind:   0 flesh  1 gold  2 crystal 3 membrane 4 sucker 5 cilium
const RIDER_LAG := [0.000, 0.0055, 0.0040, 0.0130, 0.0080, 0.0290]
const RIDER_RATE := [1.0, 24.0, 28.0, 7.0, 16.0, 9.0]
const RIDER_CAP := [0.0, 0.003, 0.003, 0.012, 0.006, 0.026]
## The largest offset any rider is currently carrying, for the contract.
var rider_motion := 0.0


func _seat_riders() -> void:
	var count := meshes.size()
	_rider_bone.resize(count)
	_rider_kind.resize(count)
	_rider_prev.resize(count)
	_rider_vel.resize(count)
	_rider_push.resize(count)
	_rider_seat.resize(count)
	_rider_out.resize(count)
	_rider_tilt.resize(count)
	_rider_squash.resize(count)
	_rider_spread.resize(count)
	_rider_cup.resize(count)
	_rider_radius.resize(count)
	_rider_rest.resize(count)
	_rider_spin.resize(count)
	var n := _bones.size()
	for i in count:
		_rider_kind[i] = _kind_of(meshes[i].name)
		_rider_prev[i] = Vector3.ZERO
		_rider_vel[i] = Vector3.ZERO
		_rider_push[i] = Vector3.ZERO
		_rider_bone[i] = -1
		if n == 0 or skeleton == null or _rider_kind[i] == 0:
			continue
		# Seat is 1 at the root; the chain is ordered root first.
		var along: float = 1.0 - _seat_of(meshes[i])
		# THE MEMBRANE IS NOT DRAGGED BY THE COLLAR. It sits at the root, and
		# the root is the one part of the creature that is anchored -- it is
		# held in the wall and never translates, so seated on its own bone the
		# membrane measured a follow-through of two hundredths of a
		# millimetre. What actually pulls a membrane about is the LIMB passing
		# through it. So it answers to the limb a quarter of the way down,
		# which is the part whose swing it can feel.
		if _rider_kind[i] == 3:
			along = 0.25
		_rider_bone[i] = _bones[clampi(int(round(along * float(n - 1))), 0, n - 1)]
		var rest: Transform3D = skeleton.get_bone_global_pose(_rider_bone[i])
		_rider_rest[i] = rest
		_rider_spin[i] = rest.basis.get_rotation_quaternion()
		_rider_prev[i] = rest.origin
		# The piece's centre and its outward direction, both expressed in the
		# SEAT'S OWN FRAME. Held that way they need no re-deriving: wherever
		# the bone goes, the seat and the axis go with it exactly, which is
		# what makes a rigid piece rigid.
		var centre: Vector3 = (meshes[i].transform * meshes[i].get_aabb()).get_center()
		_rider_seat[i] = rest.affine_inverse() * centre
		var out: Vector3 = centre - rest.origin
		_rider_out[i] = (rest.basis.inverse() * out).normalized() 				if out.length() > 0.0005 else Vector3.UP
		# How wide the piece is ACROSS that axis, which is what tells the rim
		# from the cup. Taken from the two smaller box dimensions rather than
		# from the diagonal: on a flat sucker the diagonal is mostly its width
		# anyway, and on a long spur it is not.
		var box: AABB = meshes[i].transform * meshes[i].get_aabb()
		var ext: Vector3 = box.size * 0.5
		var big: float = maxf(ext.x, maxf(ext.y, ext.z))
		_rider_radius[i] = maxf(0.001, (ext.x + ext.y + ext.z - big) * 0.5)


## The riders answer the flesh, a beat late.
##
## Sprung against the LOCAL velocity of the bone each piece is seated on, not
## against the creature's overall motion: the point is that the club can whip
## while the collar is still, and one number for the whole body cannot say
## that. The offset is rigid and in model space, which is all a mineral plate
## or a hair needs -- they do not deform, they lag.
func _micro(delta: float) -> void:
	if skeleton == null or _rider_bone.is_empty():
		return
	# The contact is a point in the room; the pieces live in the creature's own
	# space. Converted once rather than per rider.
	var contact_local := Vector3.INF
	if contact_point != Vector3.INF:
		contact_local = to_local(contact_point)
	var most := 0.0
	for i in meshes.size():
		var b := _rider_bone[i]
		if b < 0:
			continue
		var kind := _rider_kind[i]
		var now: Vector3 = skeleton.get_bone_global_pose(b).origin
		var v: Vector3 = (now - _rider_prev[i]) / maxf(delta, 0.0001)
		_rider_prev[i] = now
		_rider_vel[i] = _rider_vel[i].lerp(v, 1.0 - exp(-14.0 * delta))
		# Trailing means displaced OPPOSITE the direction of travel.
		var want: Vector3 = -_rider_vel[i] * float(RIDER_LAG[kind])
		var cap: float = float(RIDER_CAP[kind])
		if want.length() > cap:
			want = want.normalized() * cap
		_rider_push[i] = _rider_push[i].lerp(want,
				1.0 - exp(-float(RIDER_RATE[kind]) * delta))
		materials[i].set_shader_parameter("rider_push", _rider_push[i])
		most = maxf(most, _rider_push[i].length())
		if float(RIDER_ROCK[kind]) <= 0.0 and kind != 4:
			continue
		# WHERE THIS PIECE IS NOW, AND WHICH WAY IS OUT. Carried in the seat's
		# frame, so the current answer is just the seat's current transform
		# applied to them.
		var seat: Transform3D = skeleton.get_bone_global_pose(b)
		var pivot: Vector3 = seat * _rider_seat[i]
		var axis: Vector3 = (seat.basis * _rider_out[i]).normalized()
		materials[i].set_shader_parameter("rider_pivot", pivot)
		materials[i].set_shader_parameter("rider_axis", axis)
		# UNDO THE POSE. The shared stack samples its mesostructure at the
		# fragment's WORLD position, so without this the pattern belongs to the
		# room and the creature moves through it -- a plate's grain slides
		# across the plate as the limb sweeps. Sending the transform that puts
		# this piece back where it started fixes the surface to the body.
		materials[i].set_shader_parameter("rider_unpose",
				_rider_rest[i] * seat.affine_inverse())
		# ROCKING. Driven by how fast the SEAT is turning, not by how fast it
		# is travelling: a plate on a limb that swings rigidly does not rock,
		# and a plate on flesh that bends underneath it does.
		var q: Quaternion = seat.basis.get_rotation_quaternion()
		var dq: Quaternion = q * _rider_spin[i].inverse()
		_rider_spin[i] = q
		# For a small rotation the vector part is half the axis-times-angle.
		var spin: Vector3 = Vector3(dq.x, dq.y, dq.z) * 2.0 / maxf(delta, 0.0001)
		var rock: Vector3 = -spin * float(RIDER_ROCK[kind])
		var rock_cap: float = float(RIDER_ROCK_CAP[kind])
		if rock.length() > rock_cap:
			rock = rock.normalized() * rock_cap
		_rider_tilt[i] = _rider_tilt[i].lerp(rock,
				1.0 - exp(-float(RIDER_RATE[kind]) * delta))
		materials[i].set_shader_parameter("rider_tilt", _rider_tilt[i])
		# PRESSING. Only the suckers, and only the ones actually near what the
		# creature is touching -- a limb resting one sucker on a radiator
		# should not flatten the twenty-five up its own shaft.
		if kind == 4:
			var press := 0.0
			if contact_local != Vector3.INF:
				# SQUARED, not linear. Linear falloff had a sucker two and a
				# half centimetres off the contact pressing at four fifths of
				# full, which makes the whole club read as one soft pad rather
				# than as a row of organs meeting a surface. Pressure between
				# two solids does not fall off in a straight line either.
				var reach: float = clampf(1.0 - pivot.distance_to(contact_local)
						/ SUCKER_REACH, 0.0, 1.0)
				press = reach * reach * SUCKER_SQUASH
			_rider_squash[i] = lerpf(_rider_squash[i], press,
					1.0 - exp(-12.0 * delta))
			materials[i].set_shader_parameter("rider_squash", _rider_squash[i])
			# §10 — SPREAD, GRIP AND RELEASE. The rim spreads as fast as the
			# press arrives; the cup draws back BEHIND it, slower, because a
			# grip is something that takes hold. Letting go is quicker than
			# either: nothing in an animal releases at the speed it gripped.
			var hold: float = press / maxf(0.0001, SUCKER_SQUASH)
			var s_rate: float = 11.0 if hold > _rider_spread[i] else 17.0
			var c_rate: float = 3.4 if hold > _rider_cup[i] else 15.0
			_rider_spread[i] = lerpf(_rider_spread[i], hold,
					1.0 - exp(-s_rate * delta))
			_rider_cup[i] = lerpf(_rider_cup[i], hold,
					1.0 - exp(-c_rate * delta))
			materials[i].set_shader_parameter("rider_grip", Vector4(
					_rider_spread[i], _rider_cup[i], 0.0, _rider_radius[i]))
	rider_motion = most


func _secondary(delta: float) -> void:
	if skeleton == null or _bones.is_empty():
		return
	var n := _bones.size()
	var moved := 0.0
	for i in n:
		var b := _bones[i]
		var desired: Quaternion = skeleton.get_bone_pose_rotation(b)
		var t := float(i) / float(maxi(1, n - 1))
		# The root is held by the collar and answers almost immediately; the
		# distal third is mostly water and takes its time.
		var rate: float = lerpf(26.0, 7.0, t)
		# Where the intent is going, so the flesh can overshoot along it.
		var lead: float = _prev_desired[i].angle_to(desired) / maxf(0.0001, delta)
		_bone_vel[i] = lerpf(_bone_vel[i], lead, 1.0 - exp(-6.0 * delta))
		var overshoot: float = clampf(_bone_vel[i] * 0.020 * t, 0.0, 0.35)
		var goal: Quaternion = _prev_desired[i].slerp(desired, 1.0 + overshoot)
		_settled[i] = _settled[i].slerp(goal, 1.0 - exp(-rate * delta))
		moved += _settled[i].angle_to(desired)
		skeleton.set_bone_pose_rotation(b, _settled[i])
		_prev_desired[i] = desired
	# How far behind the intent each end of the body is running. This is the
	# whole point of the pass, so it is measurable rather than asserted.
	lag_root = _settled[0].angle_to(_prev_desired[0])
	lag_tip = _settled[n - 1].angle_to(_prev_desired[n - 1])
	# Rises instantly, decays slowly.
	var now: float = moved / float(n)
	motion = maxf(now * 6.0, motion - delta * 0.9)
	motion = clampf(motion, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	_behave(delta)
	_notice_neighbours(delta)
	_animate(delta)
	# The search motion lays down a posture; the solve then steers the tip to
	# what the creature actually decided to touch. Only while it is reaching:
	# a limb that is not reaching for anything should not be solving.
	if state == State.APPROACHING or state == State.TOUCHING 			or state == State.CARESSING:
		_solve_reach(delta)
	# Intent is decided; now the flesh answers it, and then the things riding
	# on the flesh answer the flesh.
	_secondary(delta)
	_micro(delta)
	_animate_eye(delta)
	# THE ORGANISM'S SEVERAL CLOCKS (DIRECTION_3 §D). None of these shares a
	# period, so nothing in the body beats with anything else.
	#
	# EVERY ONE OF THEM WAS FROZEN. The shared stack carries attention,
	# pulse_phase, breath_phase, startle and dream_phase, the procedural limb
	# has pushed all five every frame since it existed, and the modelled hero
	# pushed none of them -- so it rendered at a fixed attention of 0.3 with a
	# vascular wave standing still on its body and a breath that never came.
	# The whole coupled-state layer was inert on the creature it was written
	# for. "Not animated at all" turned out to be true of the material as well
	# as the rig.
	var pulse_v: float = fmod(_clock / PULSE_S, 1.0)
	var breath_v: float = fmod(_clock / BREATH_S, 1.0)
	# What it is attending to, which is a fact the behaviour already knows.
	var attend := 0.30
	if state == State.WATCH_PLAYER or state == State.INTERACT_CRITTER 			or state == State.INTERACT_MARGIN:
		attend = 1.0
	elif target != Vector3.INF:
		attend = 0.65
	var dream_v := 0.0
	if field != null and field.state != null:
		dream_v = fmod(field.state.dream_w, 1.0)
	for mat in materials:
		mat.set_shader_parameter("attention", attend)
		mat.set_shader_parameter("pulse_phase", pulse_v)
		mat.set_shader_parameter("breath_phase", breath_v)
		mat.set_shader_parameter("startle", clampf(_startle, 0.0, 1.0))
		mat.set_shader_parameter("dream_phase", dream_v)
		mat.set_shader_parameter("body_motion", motion)
		mat.set_shader_parameter("slice_close", slice_close)
	for mat in materials:
		mat.set_shader_parameter("grow", grow)
		if field != null and field.state != null:
			field.apply_to(mat)


## Facts for the contract.
func census() -> Dictionary:
	var gripping := 0
	for i in _rider_cup.size():
		if _rider_cup[i] > 0.15:
			gripping += 1
	var skinned := 0
	for mi in meshes:
		if mi.skin != null:
			skinned += 1
	return {"meshes": meshes.size(), "skinned": skinned,
			"rider_motion": snappedf(rider_motion, 0.0001),
			"gripping": gripping,
			"nudged_critters": nudged_critters,
			"materials": materials.size(), "grow": grow,
			"deform_bones": _bones.size(), "eye_bone": _eye_bone,
			"lid_bones": _lid_bones.size(), "state": state_name(),
			"has_target": target != Vector3.INF,
			"touching": contact_point != Vector3.INF,
			"reach_gain": snappedf(_reach_gain, 0.01),
			"motion": snappedf(motion, 0.001),
			"slice_close": snappedf(slice_close, 0.001),
			"noticing_a_critter": noticing != Vector3.INF,
			"palps_on_me": _palps_on_me, "startle": snappedf(_startle, 0.01),
			"bulge": snappedf(_bulge, 0.01),
			"lag_root": snappedf(lag_root, 0.0001),
			"lag_tip": snappedf(lag_tip, 0.0001),
			"skeleton": skeleton != null}
