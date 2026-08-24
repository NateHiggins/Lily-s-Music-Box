class_name DreamTentacleBehavior
extends RefCounted
## The Seductive Surveyor (DREAM_TENTACLE_DIRECTION §1A, §13, §17, §18): an
## explicit state machine — DORMANT, MEMBRANE_BULGE, EMERGING, ORIENTING,
## SEEKING, APPROACHING, HOVER_INSPECTION, TOUCHING, CARESSING, TASTING,
## RESTING, WATCH_PLAYER, FLINCH, RESUME, WITHDRAW, DONE — with its timings
## in a DreamBehaviorProfile, and the player's three zones. It decides; the
## controller's rig, eye, suckers and transformer carry it out.

enum S { DORMANT, MEMBRANE_BULGE, EMERGING, ORIENTING, SEEKING, APPROACHING,
		HOVER_INSPECTION, TOUCHING, CARESSING, TASTING, RESTING, WATCH_PLAYER,
		FLINCH, RESUME, WITHDRAW, DONE }
const NAMES := ["DORMANT", "MEMBRANE_BULGE", "EMERGING", "ORIENTING", "SEEKING",
		"APPROACHING", "HOVER_INSPECTION", "TOUCHING", "CARESSING", "TASTING",
		"RESTING", "WATCH_PLAYER", "FLINCH", "RESUME", "WITHDRAW", "DONE"]

## Timed transitions: state -> [profile duration field, next]. The rest
## are conditions in update().
const TIMED := {
	S.MEMBRANE_BULGE: ["membrane_bulge_s", S.EMERGING],
	S.EMERGING: ["emerge_s", S.ORIENTING],
	S.ORIENTING: ["orient_s", S.SEEKING],
	S.HOVER_INSPECTION: ["hover_s", S.TOUCHING],
	S.TOUCHING: ["touch_s", S.CARESSING],
	S.TASTING: ["taste_s", S.RESTING],
	S.WATCH_PLAYER: ["watch_player_s", S.RESUME],
	S.FLINCH: ["flinch_s", S.WATCH_PLAYER],
	S.RESUME: ["resume_s", S.CARESSING],
	S.WITHDRAW: ["withdraw_s", S.DONE],
}

var profile: DreamBehaviorProfile
var state: int = S.DORMANT
var state_clock := 0.0
var total_clock := 0.0
var caress_passes := 0
var hold := false
## Outputs, read by the controller each frame.
var tip_goal := Vector3.ZERO
var speed := 1.0
var sampling := false
var curl_target := 0.2
var grip_target := 0.0
var grow := 0.0
var membrane_tension := 0.0
## Where and how hard the still-hidden club is testing the membrane. Offset is
## in the membrane's normalized tangent plane; release is the progressive
## passage, owned here rather than inferred from visible limb length.
var membrane_probe := Vector2.ZERO
var membrane_probe_depth := 0.0
var membrane_release := 0.0
var eye_mode := "closed"
var interest := 0.3
var events: Array[String] = []
## Inputs.
var anchor := Vector3.ZERO
var anchor_normal := Vector3.UP
var tip := Vector3.ZERO
var contact := Vector3.ZERO
var contact_normal := Vector3.UP
var player_pos := Vector3.ZERO
var player_speed := 0.0
var has_player := false
var _player_watch_clock := 0.0
var _reach_entered := false
var _rush_latch := 0.0


func configure(p: DreamBehaviorProfile, hold_out: bool) -> void:
	profile = p if p != null else DreamBehaviorProfile.new()
	hold = hold_out
	_enter(S.MEMBRANE_BULGE)


func name_of(s: int) -> String:
	return NAMES[clampi(s, 0, NAMES.size() - 1)]


func _enter(s: int) -> void:
	state = s
	state_clock = 0.0
	match s:
		S.MEMBRANE_BULGE:
			events.append("membrane_strain")
			eye_mode = "closed"
		S.EMERGING:
			events.append("emergence")
			eye_mode = "closed"
		S.ORIENTING:
			eye_mode = "partial"
			events.append("eye_opening")
		S.SEEKING:
			eye_mode = "watch_object"
		S.HOVER_INSPECTION:
			eye_mode = "watch_object"
		S.TOUCHING:
			events.append("sucker_attach")
			eye_mode = "watch_contact"
		S.CARESSING:
			events.append("surface_caress")
			caress_passes += 1
			eye_mode = "watch_contact"
		S.TASTING:
			eye_mode = "watch_contact"
		S.RESTING:
			eye_mode = "explore_room"
		S.WATCH_PLAYER:
			events.append("player_attention")
			eye_mode = "lock_player"
		S.FLINCH:
			events.append("flinch")
			eye_mode = "lock_player"
		S.RESUME:
			eye_mode = "watch_object"
		S.WITHDRAW:
			events.append("withdrawal")
			eye_mode = "closing"


func withdraw() -> void:
	if state != S.WITHDRAW and state != S.DONE:
		_enter(S.WITHDRAW)


## The player's zones (§18): far — ignored unless in the field of interest;
## near — the eye watches now and then; arm's reach — the limb pauses, and
## a rush makes it flinch.
func _zone() -> String:
	if not has_player:
		return "far"
	var d := player_pos.distance_to(tip)
	if d < profile.zone_reach_m:
		return "reach"
	if d < profile.zone_near_m:
		return "near"
	return "far"


func update(delta: float) -> void:
	state_clock += delta
	total_clock += delta
	_rush_latch = maxf(0.0, _rush_latch - delta)
	var zone := _zone()
	var rushing := zone != "far" and player_speed > profile.rush_speed_mps
	# Interest: rises with contact, and with the player near.
	var want := 0.35
	if state in [S.TOUCHING, S.CARESSING, S.TASTING]:
		want = 0.75
	if zone == "reach" or state == S.WATCH_PLAYER:
		want = 0.95
	interest = lerpf(interest, want, clampf(delta * 0.8, 0.0, 1.0))
	# Interruptions from the player, in the states that can be interrupted.
	var interruptible := state in [S.SEEKING, S.APPROACHING, S.HOVER_INSPECTION,
			S.TOUCHING, S.CARESSING, S.TASTING, S.RESTING]
	if interruptible:
		if rushing and _rush_latch <= 0.0:
			_rush_latch = 6.0
			_enter(S.FLINCH)
		elif zone == "reach" and not _reach_entered:
			_reach_entered = true
			_enter(S.FLINCH)
		elif zone == "near":
			_player_watch_clock += delta
			if _player_watch_clock > 7.0 and state in [S.CARESSING, S.RESTING]:
				_player_watch_clock = 0.0
				_enter(S.WATCH_PLAYER)
	if zone != "reach":
		_reach_entered = false
	# Timed transitions, then the conditional ones.
	if TIMED.has(state):
		var row: Array = TIMED[state]
		if state_clock >= float(profile.get(str(row[0]))):
			var next: int = row[1]
			if state == S.RESUME:
				next = S.APPROACHING
			_enter(next)
	match state:
		S.SEEKING:
			if tip.distance_to(contact) < 0.28:
				_enter(S.APPROACHING)
		S.APPROACHING:
			if tip.distance_to(contact) < profile.hover_off_m + 0.025:
				_enter(S.HOVER_INSPECTION)
		S.CARESSING:
			if state_clock >= profile.caress_s:
				_enter(S.TASTING)
		S.RESTING:
			if state_clock >= profile.rest_s:
				if not hold and (caress_passes >= 2 or total_clock > 70.0):
					_enter(S.WITHDRAW)
				else:
					_enter(S.APPROACHING)
	_drive(delta)


## What the body should do in this state.
func _drive(_delta: float) -> void:
	var out := anchor + anchor_normal * 0.5
	sampling = false
	grip_target = 0.0
	speed = 1.0
	membrane_probe = Vector2.ZERO
	membrane_probe_depth = 0.0
	membrane_release = 1.0
	match state:
		S.DORMANT:
			grow = 0.0
			membrane_tension = 0.0
			membrane_release = 0.0
			tip_goal = anchor + anchor_normal * 0.05
		S.MEMBRANE_BULGE:
			grow = 0.0
			membrane_tension = smoothstep(0.0, 1.0, state_clock / maxf(0.1, profile.membrane_bulge_s))
			membrane_release = 0.0
			tip_goal = anchor + anchor_normal * 0.12
		S.EMERGING:
			var e := clampf(state_clock / maxf(0.1, profile.emerge_s), 0.0, 1.0)
			const SEARCH_END := 0.56
			if e < SEARCH_END:
				# Three palpations behind intact tissue. Each press rises and
				# recedes before the hidden club chooses another soft spot.
				var search := e / SEARCH_END
				var cycle := minf(search * 3.0, 2.999)
				var attempt := clampi(int(floor(cycle)), 0, 2)
				var local := fmod(cycle, 1.0)
				var sites := [Vector2(-0.38, 0.22), Vector2(0.32, -0.30),
						Vector2(0.10, 0.04)]
				membrane_probe = sites[attempt]
				membrane_probe_depth = sin(local * PI)
				membrane_release = 0.0
				grow = 0.0
				membrane_tension = 0.82 + membrane_probe_depth * 0.18
				var n := anchor_normal.normalized()
				var up_ref := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
				var tangent_x := up_ref.cross(n).normalized()
				var tangent_y := n.cross(tangent_x).normalized()
				tip_goal = anchor - n * (0.06 - membrane_probe_depth * 0.035) \
						+ tangent_x * membrane_probe.x * 0.22 \
						+ tangent_y * membrane_probe.y * 0.22
				speed = 0.55
				curl_target = 0.55
			else:
				# The third place yields. Length, release and weight do not share
				# a switch: tissue lets go continuously as the club crosses it.
				var q := clampf((e - SEARCH_END) / (1.0 - SEARCH_END), 0.0, 1.0)
				grow = smoothstep(0.0, 1.0, q)
				membrane_release = smoothstep(0.08, 0.92, q)
				membrane_probe = Vector2(0.10, 0.04).lerp(Vector2.ZERO,
						smoothstep(0.0, 0.75, q))
				membrane_probe_depth = 1.0 - smoothstep(0.15, 0.85, q)
				membrane_tension = 1.0 - 0.5 * q
				tip_goal = anchor + anchor_normal * (0.15 + 0.45 * q) \
						+ Vector3.UP * 0.08 * q
				speed = 1.4
				curl_target = 0.45 * (1.0 - q)
		S.ORIENTING:
			grow = 1.0
			membrane_tension = 0.5
			tip_goal = out + Vector3.UP * 0.12
			speed = 0.8
			curl_target = 0.15
		S.SEEKING:
			grow = 1.0
			membrane_tension = 0.45
			tip_goal = contact + contact_normal * 0.22
			speed = 0.85
			curl_target = 0.2
		S.APPROACHING:
			grow = 1.0
			var d := tip.distance_to(contact)
			speed = 0.3 if d < profile.slow_radius_m else 0.7
			tip_goal = contact + contact_normal * profile.hover_off_m
			sampling = d < profile.slow_radius_m * 2.0
			curl_target = 0.25
		S.HOVER_INSPECTION:
			grow = 1.0
			tip_goal = contact + contact_normal * profile.hover_off_m
			speed = 0.35
			sampling = true
			curl_target = 0.3
		S.TOUCHING:
			grow = 1.0
			tip_goal = contact
			speed = 0.45
			sampling = true
			grip_target = 0.8
			curl_target = 0.45
		S.CARESSING:
			grow = 1.0
			tip_goal = contact
			speed = 0.6
			sampling = true
			grip_target = 1.0
			curl_target = 0.6
		S.TASTING:
			grow = 1.0
			tip_goal = contact
			speed = 0.25
			sampling = true
			grip_target = 1.0
			curl_target = 0.75
		S.RESTING:
			grow = 1.0
			tip_goal = contact + contact_normal * 0.01
			speed = 0.2
			grip_target = 0.5
			curl_target = 0.5
		S.WATCH_PLAYER:
			grow = 1.0
			tip_goal = contact + contact_normal * 0.12
			speed = 0.3
			grip_target = 0.3
			curl_target = 0.55
		S.FLINCH:
			grow = 1.0
			var away := anchor_normal
			if has_player:
				away = (tip - player_pos).normalized()
			tip_goal = anchor + anchor_normal * 0.42 + away * 0.3 + Vector3.UP * 0.1
			speed = 3.2
			curl_target = 0.95
			grip_target = 0.0
		S.RESUME:
			grow = 1.0
			tip_goal = contact + contact_normal * 0.18
			speed = 0.5
			curl_target = 0.35
		S.WITHDRAW:
			var w := clampf(state_clock / maxf(0.1, profile.withdraw_s), 0.0, 1.0)
			grow = 1.0 - smoothstep(0.0, 1.0, w)
			membrane_release = 1.0 - smoothstep(0.55, 1.0, w)
			membrane_tension = 0.6 * (1.0 - w)
			tip_goal = anchor + anchor_normal * (0.5 * (1.0 - w) + 0.05)
			speed = 1.1
			curl_target = 0.3 + 0.5 * w
		S.DONE:
			grow = 0.0
			membrane_tension = 0.0
			membrane_release = 0.0
	# The reach is bounded.
	var off := tip_goal - anchor
	if off.length() > profile.reach_m:
		tip_goal = anchor + off.normalized() * profile.reach_m


func take_events() -> Array[String]:
	var out := events.duplicate()
	events.clear()
	return out
