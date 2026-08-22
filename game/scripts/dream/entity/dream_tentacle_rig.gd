class_name DreamTentacleRig
extends RefCounted
## The limb's spline rig (DREAM_TENTACLE_DIRECTION §3, §12). Sixteen joints
## in world space, each a damped spring after a target laid along a cubic
## from the root to where the tip wants to be — root heavy and slow,
## midsection fluid, final third dexterous, tip precise — with the length
## kept, a controllable distal curl, the antenna's tremor on the distal
## quarter only while sampling, and a parallel-transported side vector per
## joint so the shader can bend the body without rolling it.
##
## The SILHOUETTE is a profile along the length, sampled per joint and
## handed to the shader as (radius multiplier, flatten, twist, rib): the
## muscular root, a slightly compressed section, a rounded segment, a ribbed
## section, a flattened ribbon-like span, an articulated narrowing, the fine
## distal limb, the rounded sensory club.

const N := 16
const BASE_RADIUS := 0.078
const TIP_RADIUS := 0.017

## v, radius multiplier, flatten (ellipse), twist (rad), rib.
## SIX REGIONAL IDENTITIES the player's eye can follow (HERO_PASS §1):
## muscular root → compressed neck → ocular station → flattened
## transitional ribbon → ribbed mineralized shaft → articulated narrowing →
## dexterous distal → sensory club. Exaggerated for the game camera (§18):
## the silhouette must CHANGE, not taper.
const PROFILE := [
	[0.00, 1.45, 0.00, 0.00, 0.0],   # root: broad, muscular, in the membrane
	[0.07, 1.58, 0.12, 0.10, 0.0],   # the root's shoulder — the widest mass
	[0.16, 0.68, 0.36, 0.24, 0.0],   # a hard compressed NECK: a real waist
	[0.24, 0.80, 0.22, 0.38, 0.0],
	[0.33, 1.35, 0.10, 0.55, 0.0],   # the ocular station's brow rising
	[0.42, 1.92, 0.16, 0.70, 0.0],   # THE STATION: 2.8x the neck
	[0.50, 1.44, 0.30, 0.88, 0.0],   # its shoulder falling away
	[0.56, 0.62, 0.66, 1.05, 0.0],   # the flattened transitional RIBBON
	[0.63, 0.98, 0.24, 1.20, 1.0],   # ribbed / mineralized: section swells
	[0.70, 0.66, 0.40, 1.34, 1.0],   # and pinches
	[0.77, 1.02, 0.10, 1.46, 1.0],   # again — a ribbed rhythm, not a taper
	[0.83, 0.58, 0.16, 1.55, 0.0],   # an articulated knuckle's waist
	[0.89, 0.46, 0.08, 1.62, 0.0],   # the narrowing: dexterous
	[0.95, 0.70, 0.04, 1.66, 0.0],
	[1.00, 1.18, 0.00, 1.70, 0.0],   # the sensory CLUB: visibly specialized
]

var length_m := 1.6
var anchor := Vector3.ZERO
var anchor_normal := Vector3.UP
var pos := PackedVector3Array()
var vel := PackedVector3Array()
var target := PackedVector3Array()
var side := PackedVector3Array()
var prof := PackedVector4Array()
## Controls, set by the behaviour each frame.
var tip_goal := Vector3.ZERO
## The goal the body actually follows: eased after `tip_goal` at `speed`
## (m/s-ish), so the approach is deliberate and the flinch quick.
var goal_now := Vector3.ZERO
var speed := 1.0
var contact_normal := Vector3.UP
var contact_tangent := Vector3.RIGHT
## How much the distal run lies along the surface (the grip), 0..1.
var lay := 0.0
## The ventral roll (DIRECTION 9D, the impossible twist): the angle the
## distal anatomy turns about the body so the suckers face the surface,
## without the body twisting — the sleight is in the mesh parameterisation.
var roll := 0.0
## The WHOLE body's roll about its own axis, so the ocular station can be
## presented to whoever is watching (HERO_PASS §4: an organ the camera
## cannot see has no authority). An animal turns its head; the socket does
## not crawl around the limb.
var station_roll := 0.0
var curl := 0.0
var grow := 0.0
var sampling := false
var tremor_hz := 6.0
var tremor_m := 0.0035
var clock := 0.0
var phase_seed := 0.0
var _side_ref := Vector3.RIGHT
var _bin_ref := Vector3.FORWARD
var _settled := false


func configure(at: Vector3, normal: Vector3, length: float, seed_phase: float) -> void:
	anchor = at
	anchor_normal = normal.normalized()
	length_m = length
	phase_seed = seed_phase
	pos.resize(N)
	vel.resize(N)
	target.resize(N)
	side.resize(N)
	prof.resize(N)
	_side_ref = anchor_normal.cross(Vector3.UP)
	if _side_ref.length() < 0.1:
		_side_ref = anchor_normal.cross(Vector3.RIGHT)
	_side_ref = _side_ref.normalized()
	_bin_ref = anchor_normal.cross(_side_ref).normalized()
	for i in N:
		pos[i] = anchor + anchor_normal * 0.01 * float(i)
		vel[i] = Vector3.ZERO
		prof[i] = _profile_at(float(i) / float(N - 1))
	tip_goal = anchor + anchor_normal * 0.3
	goal_now = tip_goal
	_settled = false
	lay_targets()
	for i in N:
		pos[i] = target[i]
	_transport()


static func _profile_at(v: float) -> Vector4:
	var lo: Array = PROFILE[0]
	var hi: Array = PROFILE[PROFILE.size() - 1]
	for k in PROFILE.size() - 1:
		if v >= float(PROFILE[k][0]) and v <= float(PROFILE[k + 1][0]):
			lo = PROFILE[k]
			hi = PROFILE[k + 1]
			break
	var span := maxf(0.001, float(hi[0]) - float(lo[0]))
	var s := clampf((v - float(lo[0])) / span, 0.0, 1.0)
	s = s * s * (3.0 - 2.0 * s)
	return Vector4(lerpf(float(lo[1]), float(hi[1]), s), lerpf(float(lo[2]), float(hi[2]), s),
			lerpf(float(lo[3]), float(hi[3]), s), lerpf(float(lo[4]), float(hi[4]), s))


## The radius of the body at v (before the shader's relief).
static func radius_at(v: float) -> float:
	var taper := lerpf(BASE_RADIUS, TIP_RADIUS, pow(v, 0.8))
	# The club is a real terminal organ, not a rounded end.
	var club := 1.0 + 0.62 * smoothstep(0.86, 0.975, v) * (1.0 - smoothstep(0.985, 1.0, v))
	return taper * sqrt(maxf(0.0, 1.0 - pow(v, 14.0))) * float(_profile_at(v).x) * club


## Targets along a cubic from the root to the tip goal, bowed by the slack
## so the length is kept when the goal is near, then the distal curl.
func lay_targets() -> void:
	var chord := goal_now.distance_to(anchor)
	var slack := clampf((length_m * 0.92 - chord) / length_m, 0.0, 1.0) * maxf(grow, 0.05)
	# The bow takes up the slack, but the run must not be longer than the
	# body or the tip can never arrive: shrink the slack until it fits.
	for _pass in 4:
		_lay_cubic(slack)
		var run := 0.0
		for i in range(1, N):
			run += target[i].distance_to(target[i - 1])
		if run <= length_m * 0.97 or slack < 0.02:
			break
		slack *= clampf(length_m * 0.9 / run, 0.3, 0.95)
	_curl_targets()


func _lay_cubic(slack: float) -> void:
	var bow := _side_ref * (0.5 * slack * sin(clock * 0.31 + phase_seed)) \
			+ Vector3.UP * (0.32 * slack) + anchor_normal * (0.28 * slack)
	var p0 := anchor
	var p1 := anchor + anchor_normal * (0.28 + 0.22 * grow + 0.45 * slack) + bow * 0.55
	var p3 := goal_now
	var p2 := goal_now - contact_normal * (0.18 + 0.12 * curl) * (1.0 - 0.8 * lay) \
			- contact_tangent * 0.24 * lay + anchor_normal * 0.10 * (1.0 - lay) + bow
	for i in N:
		var s := float(i) / float(N - 1)
		var a := 1.0 - s
		target[i] = p0 * (a * a * a) + p1 * (3.0 * a * a * s) + p2 * (3.0 * a * s * s) + p3 * (s * s * s)


## The distal curl: the last third rotates about the side vector at its
## base, toward the contact surface, wrapping an edge; the tip stays on goal.
func _curl_targets() -> void:
	var p3 := goal_now
	if curl > 0.001:
		var base_i := int(0.66 * float(N - 1))
		var pivot := target[base_i]
		var tng := (target[base_i + 1] - target[base_i - 1]).normalized()
		var axis := tng.cross(contact_normal)
		if axis.length() < 0.05:
			axis = tng.cross(_side_ref)
		axis = axis.normalized()
		for i in range(base_i + 1, N):
			var s := float(i - base_i) / float(N - 1 - base_i)
			var ang := curl * 1.9 * s * s
			target[i] = pivot + (target[i] - pivot).rotated(axis, ang)
		# The tip stays on its goal: the curl bends the run, not the aim.
		var shift := p3 - target[N - 1]
		for i in range(base_i + 1, N):
			var s := float(i - base_i) / float(N - 1 - base_i)
			target[i] += shift * s


## One step: springs per joint (root heavy, tip precise), the tremor on the
## distal quarter while sampling, the length kept from the root.
func step(delta: float) -> void:
	var dt := clampf(delta, 0.0, 1.0 / 30.0)
	clock += delta
	# The goal eases toward where the behaviour wants the tip; the distance
	# closed per second is the behaviour's speed.
	var to_goal := tip_goal - goal_now
	var max_step := speed * dt
	if to_goal.length() > max_step:
		goal_now += to_goal.normalized() * max_step
	else:
		goal_now = tip_goal
	lay_targets()
	var seg := length_m / float(N - 1)
	for i in N:
		var s := float(i) / float(N - 1)
		# Hierarchy: stiffness and damping rise toward the tip.
		var k := lerpf(28.0, 300.0, s * s)
		var c := lerpf(9.0, 26.0, s)
		var t := target[i]
		if sampling and s > 0.75:
			var w := (s - 0.75) / 0.25
			t += _side_ref * (tremor_m * w * sin(clock * TAU * tremor_hz + s * 9.0 + phase_seed)) \
					+ _bin_ref * (tremor_m * 0.7 * w * sin(clock * TAU * (tremor_hz * 1.17) + 1.3))
		if i == 0:
			pos[i] = anchor
			vel[i] = Vector3.ZERO
			continue
		var acc := (t - pos[i]) * k - vel[i] * c
		vel[i] += acc * dt
		pos[i] += vel[i] * dt
	# Length: no joint further from its parent than a segment; the root holds.
	for i in range(1, N):
		var d := pos[i] - pos[i - 1]
		var l := d.length()
		if l > seg * 1.03:
			pos[i] = pos[i - 1] + d / l * seg * 1.03
			vel[i] *= 0.7
		elif l < 0.002:
			pos[i] = pos[i - 1] + anchor_normal * 0.002
	_transport()
	_roll_to_surface(dt)
	_settled = true


## The roll that brings the ventral side (u = 0.5) to face the contact
## surface at the tip, eased.
func _roll_to_surface(dt: float) -> void:
	var f := frame_at(0.92)
	var tng: Vector3 = f.tangent
	var sd: Vector3 = f.side
	var bn: Vector3 = f.binormal
	var want_dir := -contact_normal
	want_dir = (want_dir - tng * want_dir.dot(tng))
	if want_dir.length() < 0.05 or lay < 0.05:
		roll = lerpf(roll, 0.0, clampf(dt * 1.5, 0.0, 1.0))
		return
	want_dir = want_dir.normalized()
	# Ventral is at angle PI (+ twist); find the angle of want_dir in the
	# (side, binormal) frame and roll so that PI + twist + roll lands on it.
	var a := atan2(want_dir.dot(bn), want_dir.dot(sd))
	# The station roll is already applied to every frame, so the ventral
	# roll has to work relative to it — otherwise turning the body to
	# present the eye drags the suckers off the surface they are holding.
	var want_roll := a - PI - float(f.twist) - station_roll
	while want_roll > PI:
		want_roll -= TAU
	while want_roll < -PI:
		want_roll += TAU
	roll = lerp_angle(roll, want_roll, clampf(dt * 2.0, 0.0, 1.0))


## The roll at v: the body's own roll everywhere (easing in from the root,
## which is held by the membrane), plus the ventral roll on the distal third.
func roll_at(v: float) -> float:
	return station_roll * smoothstep(0.05, 0.35, v) + roll * smoothstep(0.45, 0.8, v)


func _transport() -> void:
	var prev := _side_ref
	for i in N:
		var tng: Vector3
		if i < N - 1:
			tng = pos[i + 1] - pos[i]
		else:
			tng = pos[i] - pos[i - 1]
		if tng.length() < 1e-5:
			tng = anchor_normal
		tng = tng.normalized()
		var sd := prev - tng * prev.dot(tng)
		if sd.length() < 1e-4:
			sd = tng.cross(Vector3.UP)
		sd = sd.normalized()
		side[i] = sd
		prev = sd


func tip() -> Vector3:
	return pos[N - 1]


func point_at(t: float) -> Vector3:
	var x := clampf(t, 0.0, 1.0) * float(N - 1)
	var i := mini(int(floor(x)), N - 2)
	var s := x - float(i)
	return pos[i].lerp(pos[i + 1], s)


## The frame at v: position, tangent, side, binormal, radius, flatten, twist.
func frame_at(v: float) -> Dictionary:
	var x := clampf(v, 0.0, 1.0) * float(N - 1)
	var i := mini(int(floor(x)), N - 2)
	var s := x - float(i)
	var p := pos[i].lerp(pos[i + 1], s)
	var tng := (pos[i + 1] - pos[i]).normalized()
	var sd := side[i].lerp(side[i + 1], s)
	sd = (sd - tng * sd.dot(tng)).normalized()
	var bn := tng.cross(sd).normalized()
	var pr := _profile_at(v)
	return {"pos": p, "tangent": tng, "side": sd, "binormal": bn,
			"radius": radius_at(v), "flatten": float(pr.y), "twist": float(pr.z)}


## A point on the body's surface at (u around, v along), as the shader
## places it before relief — for suckers, collars, the eye.
func surface_point(u: float, v: float, lift := 0.0) -> Dictionary:
	var f := frame_at(v)
	var a := u * TAU + float(f.twist) + roll_at(v)
	var fl := float(f.flatten)
	var radial: Vector3 = (f.side as Vector3) * cos(a) * (1.0 + fl) + (f.binormal as Vector3) * sin(a) * (1.0 - fl)
	var n := radial.normalized()
	var r := float(f.radius) * radial.length()
	return {"pos": (f.pos as Vector3) + n * (r + lift), "normal": n, "tangent": f.tangent, "radius": r}
