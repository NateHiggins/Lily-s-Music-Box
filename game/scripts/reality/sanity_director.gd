class_name SanityDirector
extends Node
## The invisible one.
##
## There is no sanity meter, and there is never going to be one. A meter
## turns dread into a resource the player manages: they learn its rate, they
## learn what refills it, and the horror becomes budgeting. What this tracks
## instead is PRESSURE — a hidden number the player can only perceive as "the
## building has been getting worse" — and the only honest readout of it is
## the building itself.
##
## The director's job is authorship, not simulation. It answers four
## questions on a loop:
##
##   WHO      which resident's poltergeist is speaking (proximity, whose
##            case is live, who has been quiet too long)
##   WHERE    the room the player is actually in, so the act lands on props
##            they have already looked at
##   WHAT     which rung of that poltergeist's ladder the pressure has earned
##   WHEN     and, far more often, when NOT — see the pacing rules below
##
## Pacing is most of the design. Three things make escalation read as intent
## rather than as a random event generator:
##
##   1. A refractory period after every intrusion, longer for higher rungs.
##      Two hauntings back to back are one haunting with a stutter.
##   2. Mercy. After a rung-four address the building goes genuinely quiet
##      for a long beat. The silence is where the player does the thinking,
##      and the thinking is the entire point of the system.
##   3. Anti-repetition. A poltergeist will not play the same rung twice in
##      a row, and the director will not pick the same resident twice in a
##      row while another has something to say.
##
## Escalation is tied to progression and to cases, as asked: pressure climbs
## with infection, with how many cases are live, and hard while the player is
## actually working a call — the desk is where they are most committed and
## least able to leave, which is exactly when the building should lean on
## them.

signal intruded(case_id: String, tier: int)
signal attention_registered(case_id: String, tier: int)
signal attention_withheld(case_id: String, streak: int)

## Poll rate. Deliberately slow: this thing thinks in beats, not frames.
const TICK := 1.4
## Pressure needed before a rung becomes available at all. Rung four is a
## long way up, and is meant to be.
const TIER_GATE := {1: 0.12, 2: 0.34, 3: 0.62, 4: 0.86}
## Seconds of quiet owed after an intrusion of each tier.
const REFRACTORY := {1: 11.0, 2: 19.0, 3: 34.0, 4: 95.0}
## How far a resident's own unit can be from the player and still be the one
## who speaks. Beyond this the building speaks in the voice of whoever is
## nearest instead.
const HOME_REACH := 14.0
## How long the player has to notice what just changed before the building
## concludes they missed it.
const NOTICE_WINDOW := 14.0
## Where the campaign tally lives. Persisted with the rest of the reality
## state, because the building is supposed to remember across sessions how
## much it has already said to this player.
const WITNESS_KEY := "sanity_addresses_witnessed"

var enabled := true
## The hidden value. Exposed for the debug panel and the tests ONLY; nothing
## in the shipped HUD may read it.
var pressure := 0.0
var last_tier := 0
var intrusion_count := 0

var world: Node3D
var player: Node3D
var intrusions: Intrusions
var fourth_wall: FourthWallLayer
var personality: BuildingPersonalityDirector

var _accum := 0.0
var _quiet_until := 0.0
var _last_case := ""
var _last_rung: Dictionary = {}      # case_id -> tier
var _rng := RandomNumberGenerator.new()
# behaviour telemetry
var _still_for := 0.0
var _running_for := 0.0
var _last_pos := Vector3.ZERO
var _look_changes := 0.0
var _last_forward := Vector3.FORWARD
var _dwell: Dictionary = {}          # unit -> seconds
# attention: what the player is actually looking at, and whether they ever
# looked at the last thing that moved
var _gaze_node: Node3D = null
var _gaze_hold := 0.0
var _watching: Array[Node3D] = []
var _watch_deadline := 0.0
var _ignored_streak := 0


func setup(building: Node3D, body: Node3D, acts: Intrusions,
		meta: FourthWallLayer) -> void:
	world = building
	player = body
	intrusions = acts
	fourth_wall = meta
	_rng.randomize()
	if player:
		_last_pos = player.global_position


func bind_personality(director: BuildingPersonalityDirector) -> void:
	personality = director
	attention_registered.connect(personality.register_attention)
	attention_withheld.connect(personality.register_ignored)


func _process(delta: float) -> void:
	if not enabled or player == null:
		return
	_observe(delta)
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	pressure = _compute_pressure()
	_consider()


# ------------------------------------------------------------- watching

## Everything here is read off the player without asking them for anything.
## Standing still and staring is a different state from running in circles,
## and the building should not treat them alike.
func _observe(delta: float) -> void:
	var here: Vector3 = player.global_position
	var moved := here.distance_to(_last_pos)
	_last_pos = here
	if moved < 0.02:
		_still_for += delta
		_running_for = 0.0
	else:
		_still_for = 0.0
		if moved / maxf(delta, 0.0001) > 3.6:
			_running_for += delta
		else:
			_running_for = 0.0
	var forward := -player.global_transform.basis.z
	# Whipping the camera around is the tell for a rattled player. It decays,
	# so a single look behind does not count as fear.
	_look_changes = maxf(0.0, _look_changes - delta * 0.4) \
			+ forward.angle_to(_last_forward)
	_last_forward = forward
	var unit := _unit_at(here)
	if unit != "":
		_dwell[unit] = float(_dwell.get(unit, 0.0)) + delta
	_observe_gaze(delta)


## Where the player is actually looking, and for how long. This is the
## strongest signal the system has: standing in a room says very little,
## while holding your eyes on one object for four seconds says you have
## found something and are deciding what it means.
func _observe_gaze(delta: float) -> void:
	var cam = player.get("camera")
	if not (cam is Camera3D):
		return
	var camera: Camera3D = cam
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_transform.basis.z * 14.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var looked: Node3D = null
	if not hit.is_empty() and hit.collider is Node:
		# Collision shapes hang below the prop; walk up to the thing that
		# has a name and a personality.
		var node: Node = hit.collider
		while node != null and not (node is FunctionalProp):
			node = node.get_parent()
		if node is FunctionalProp:
			looked = node
	if looked == _gaze_node:
		_gaze_hold += delta
	else:
		_gaze_node = looked
		_gaze_hold = 0.0
	# Did they notice what just moved? Looking at any of the last act's
	# targets closes the loop.
	if not _watching.is_empty() and looked != null and _watching.has(looked):
		_noticed()
	elif not _watching.is_empty() \
			and Time.get_ticks_msec() / 1000.0 > _watch_deadline:
		_ignored()


## They looked. The point landed, so the building can afford to be patient:
## it has been heard, and repeating yourself to someone who is listening is
## how a haunting becomes noise.
func _noticed() -> void:
	_watching.clear()
	_ignored_streak = 0
	pressure = maxf(0.0, pressure - 0.05)
	_quiet_until = maxf(_quiet_until, Time.get_ticks_msec() / 1000.0 + 6.0)
	attention_registered.emit(_last_case, last_tier)


## They did not. An intrusion nobody saw is an intrusion that has to be made
## again — this is the one place the building gets LOUDER on purpose, and it
## is why a player who ignores the building ends up somewhere worse than one
## who pays attention. Sitting still and watching is rewarded; blundering
## through with the camera on the floor is not.
func _ignored() -> void:
	_watching.clear()
	_ignored_streak = mini(_ignored_streak + 1, 4)
	attention_withheld.emit(_last_case, _ignored_streak)
	print("[SANITY] unwitnessed (%d in a row)" % _ignored_streak)


## Which apartment the player is standing in, via the reality controllers
## that already own room bounds. No second source of truth for geometry.
func _unit_at(point: Vector3) -> String:
	for controller in get_tree().get_nodes_in_group(
			"apartment_reality_controllers"):
		if controller.contains_point(point):
			return controller.unit
	return ""


# ------------------------------------------------------------- pressure

## The hidden number. Nothing here is shown to the player; they only ever
## see its consequences, and the consequences are supposed to feel like the
## building's mood rather than like a stat.
func _compute_pressure() -> float:
	var p := 0.0
	# The building's own infection is the floor of the mood.
	p += clampf(Conductor.infection, 0.0, 1.0) * 0.34
	# Campaign progression: a building with live cases is a worse building.
	var live := 0
	var resolved := 0
	for case_id in RealityState.data.get("cases", {}).keys():
		var state: Dictionary = RealityState.data.cases[case_id]
		match str(state.get("stage", "unseen")):
			"active", "reopened": live += 1
			"resolved": resolved += 1
	p += clampf(live * 0.13, 0.0, 0.34)
	# Resolved cases genuinely calm the building. Understanding is the only
	# thing in this system that turns pressure DOWN, which is the argument
	# the whole game is making.
	p -= clampf(resolved * 0.05, 0.0, 0.25)
	# Working a call is the high-commitment state: hardest to walk away from,
	# most exposed. Asked for explicitly — most active when cases are active.
	var call_live := _call_active()
	if call_live:
		p += 0.22
	# Behaviour. A player standing perfectly still is either studying
	# something or too frightened to move; either way they are paying
	# attention, and attention is when an intrusion is worth spending.
	p += clampf(_still_for / 14.0, 0.0, 0.12)
	# Running is flight. Push a little, then back off — chasing a fleeing
	# player just reads as unfair.
	p += clampf(_running_for / 9.0, 0.0, 0.08) \
			- clampf((_running_for - 9.0) / 20.0, 0.0, 0.1)
	# Checking behind themselves means the last one landed.
	p += clampf(_look_changes / 26.0, 0.0, 0.09)
	# Holding a gaze is the strongest attention signal there is: they have
	# found something and are working out what it means. That is the moment
	# worth spending an intrusion on.
	p += clampf(_gaze_hold / 6.0, 0.0, 0.10)
	# Repeatedly missing what the building does makes it insist.
	p += _ignored_streak * 0.06
	# Campaign memory. A player who has already been addressed four times
	# meets a building that starts from somewhere worse — the escalation is
	# across the whole game, not just within a session.
	p += clampf(_witnessed() * 0.035, 0.0, 0.16)
	return clampf(p, 0.0, 1.0)


func _witnessed() -> int:
	return int(RealityState.data.get(WITNESS_KEY, 0))


func _call_active() -> bool:
	var ci = world.get("call_interface") if world else null
	if ci == null:
		return false
	# Anything from the caller's opening through to the response window.
	return int(ci.stage) >= 1 and int(ci.stage) <= 5


# ------------------------------------------------------------ deciding

func _consider() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _quiet_until:
		return
	if fourth_wall != null and fourth_wall.is_busy():
		return
	var tier := _tier_for(pressure)
	if tier == 0:
		return
	# Even when a rung is earned, most ticks do nothing. Dread is mostly the
	# absence of events, and a director that fires whenever it may becomes
	# a metronome.
	var odds := 0.18 + 0.30 * pressure
	if personality:
		odds += personality.haunting_urgency()
	if _call_active():
		odds += 0.16
	if _rng.randf() > odds:
		return
	var case_id := _choose_speaker()
	if case_id == "":
		return
	# Never the same rung twice running from the same voice.
	if int(_last_rung.get(case_id, 0)) == tier and tier > 1:
		tier = maxi(1, tier - 1)
	_fire(case_id, tier)


func _tier_for(p: float) -> int:
	var best := 0
	for tier in [1, 2, 3, 4]:
		if p >= float(TIER_GATE[tier]):
			best = tier
	return best


## Who speaks. Three claims compete: whoever the player is standing among,
## whoever has a live case, and whoever has been silent longest. Proximity
## wins most of the time because an intrusion has to land on props the
## player can already see.
func _choose_speaker() -> String:
	var here: Vector3 = player.global_position
	# A held gaze names a room more precisely than a position does — you can
	# stand in a corridor and be looking into somebody's kitchen.
	var gazed_unit := ""
	if _gaze_node != null and _gaze_hold > 1.2:
		gazed_unit = _unit_at(_gaze_node.global_position)
	var scored: Array = []
	for case_id in PoltergeistLibrary.ids():
		var profile: Dictionary = PoltergeistLibrary.profile(case_id)
		var score := 0.4
		var unit: String = profile.unit
		if _unit_at(here) == unit:
			score += 2.4                       # you are in their home
		if gazed_unit != "" and gazed_unit == unit:
			score += 1.3                       # and looking at their things
		var state: Dictionary = RealityState.case_state(case_id)
		match str(state.get("stage", "unseen")):
			"active", "reopened": score += 1.5
			"resolved": score -= 2.0           # they have said their piece
		# A resident whose case the player has been sitting in the middle of
		# has earned a turn.
		score += clampf(float(_dwell.get(unit, 0.0)) / 45.0, 0.0, 0.8)
		if case_id == _last_case:
			score -= 1.6                       # let somebody else speak
		if personality:
			score += personality.speaker_bias(unit, case_id)
		score += _rng.randf() * 0.5
		scored.append([score, case_id])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	if scored.is_empty() or scored[0][0] <= 0.0:
		return ""
	return scored[0][1]


func _fire(case_id: String, tier: int) -> void:
	var acts := PoltergeistLibrary.rung(case_id, tier)
	if acts.is_empty():
		return
	var performed := 0
	var addressed_targets: Array[Node3D] = []
	for act in acts:
		if intrusions.perform(str(act[0]), act[1]):
			performed += 1
			for target in intrusions.last_targets:
				if not addressed_targets.has(target):
					addressed_targets.append(target)
	if personality:
		var punctuation := personality.companion_act(tier)
		if not punctuation.is_empty() and intrusions.perform(
				str(punctuation[0]), punctuation[1]):
			performed += 1
			for target in intrusions.last_targets:
				if not addressed_targets.has(target):
					addressed_targets.append(target)
	if performed == 0:
		return
	intrusion_count += 1
	last_tier = tier
	_last_case = case_id
	_last_rung[case_id] = tier
	var now := Time.get_ticks_msec() / 1000.0
	_quiet_until = now + float(REFRACTORY[tier])
	# Arm the notice window on whatever actually moved. If the player never
	# looks at any of it, the building will conclude it was not heard.
	_watching = addressed_targets
	_watch_deadline = now + NOTICE_WINDOW
	# The address rung buys the longest silence in the game. The player has
	# just been told something true about a stranger's grief; the building
	# should have the grace to let them sit with it.
	if tier >= 4:
		pressure *= 0.35
		_ignored_streak = 0
		# and it is remembered for good: this building has now said one more
		# of the things it had to say.
		RealityState.data[WITNESS_KEY] = _witnessed() + 1
		RealityState.commit()
	print("[SANITY] %s rung %d (pressure %.2f, %d acts)"
			% [case_id, tier, pressure, performed])
	intruded.emit(case_id, tier)


# ------------------------------------------------------------ debug/test

## Deterministic entry point for tests and the debug panel: skip the dice and
## the pacing, run one rung now.
func force(case_id: String, tier: int) -> void:
	_fire(case_id, tier)


func stand_down() -> void:
	enabled = false
	_quiet_until = Time.get_ticks_msec() / 1000.0 + 3600.0
	if intrusions:
		intrusions.restore_all()


func stats() -> Dictionary:
	var result := {
		"pressure": pressure, "intrusions": intrusion_count,
		"last_tier": last_tier, "last_case": _last_case,
		"still_for": _still_for, "held": intrusions.held_count()
				if intrusions else 0,
		"gaze": str(_gaze_node.name) if _gaze_node else "—",
		"gaze_hold": _gaze_hold, "ignored": _ignored_streak,
		"witnessed": _witnessed(),
	}
	if personality:
		result["building_mood"] = personality.mood()
		result["building_floor"] = personality.state.favorite_floor
		result["building_tactic"] = personality.state.last_tactic
	return result
