class_name DreamEcologyDirector
extends Node
## THE ECOLOGY'S WEATHER, AND ITS ONE MOMENT OF ONE-MINDEDNESS
## (ecology architecture §13, §31, §32, §33, §40).
##
## Two jobs, and §33 insists they stay separate:
##
## **The area state biases probabilities.** It does not drive animations and it
## does not synchronise anybody. During `FORAGING` there is more contact and
## more critter activity; during `WATCHING` there is less locomotion and more
## sensory orientation. Everyone still decides for themselves.
##
## **Global attention overrides local intent, and almost never happens.**
##
##     "Twenty procedural palps are doing different things. Several critters
##      are moving independently. Hero Tentacle is examining an object. A
##      sudden meaningful stimulus occurs. At the same instant: procedural tips
##      orient, critters stop or turn, hero eye fixes... Hold. Then autonomy
##      returns asynchronously."
##
## §40 makes the transition itself the acceptance test — *"the sudden
## transition from independent ecology to coordinated reaction should be
## immediately legible"* — so the two halves are built to be opposites. The
## snap is instantaneous and total; the release is staggered per individual,
## because a coordinated release would read as a machine switching off rather
## than as attention lapsing.
##
##     "This should be one of the most important reveals in the game: the
##      ecosystem may be one mind."

enum State { DORMANT, CURIOUS, FORAGING, SOCIAL, WATCHING, STARTLED,
		WITHDRAWING, HIGH_ATTENTION, INCARNATING }

const STATE_NAMES := ["dormant", "curious", "foraging", "social", "watching",
		"startled", "withdrawing", "high_attention", "incarnating"]

signal attention_seized(at: Vector3)
signal attention_released()

var margin = null
var critters = null
var hero = null
var field: DreamFieldController = null

var state: int = State.CURIOUS
var state_clock := 0.0
## Where everything is looking, while it is looking.
var attending := Vector3.INF
var attention_clock := 0.0
## The hold, before autonomy starts coming back.
const HOLD_S := 1.9

var _rng := RandomNumberGenerator.new()
var _released := 0
## Who has already been taken by this event. Needed because the margin keeps
## growing during it, and an appendage that emerges while the whole ecology is
## staring at something should be staring at it too -- a single palp going
## about its own business in the middle of the reveal breaks the entire beat.
var _seized: Dictionary = {}


func setup(seed_v: int) -> void:
	name = "DreamEcologyDirector"
	_rng.seed = seed_v


## §32 — states modify probabilities. This is the whole of their effect.
func bias() -> Dictionary:
	match state:
		State.DORMANT:
			return {"move": 0.35, "contact": 0.2, "social": 0.3, "orient": 0.4}
		State.FORAGING:
			return {"move": 1.15, "contact": 1.6, "social": 1.2, "orient": 0.9}
		State.SOCIAL:
			return {"move": 0.9, "contact": 0.8, "social": 1.8, "orient": 0.9}
		State.WATCHING:
			return {"move": 0.45, "contact": 0.5, "social": 0.7, "orient": 1.7}
		State.STARTLED:
			return {"move": 1.4, "contact": 0.2, "social": 0.4, "orient": 1.3}
		State.WITHDRAWING:
			return {"move": 0.8, "contact": 0.15, "social": 0.5, "orient": 0.6}
		State.HIGH_ATTENTION:
			return {"move": 0.3, "contact": 0.6, "social": 0.6, "orient": 2.0}
		State.INCARNATING:
			return {"move": 1.0, "contact": 1.4, "social": 1.0, "orient": 1.1}
	return {"move": 1.0, "contact": 1.0, "social": 1.0, "orient": 1.0}


func state_name() -> String:
	return STATE_NAMES[state]


func _process(delta: float) -> void:
	state_clock += delta
	if attending != Vector3.INF:
		_run_attention(delta)
		return
	# The area drifts between states on its own slow clock. Nothing here
	# commands an animation; it only changes how likely things are.
	if state_clock > _rng.randf_range(14.0, 34.0):
		state_clock = 0.0
		var options := [State.CURIOUS, State.FORAGING, State.SOCIAL,
				State.WATCHING, State.DORMANT]
		state = options[_rng.randi() % options.size()]


## §13 — EVERYTHING, AT ONCE.
##
## Called for a stimulus worth the whole ecology's notice. It is deliberately
## not automatic: nothing in here fires it on a timer, because §40 says it
## must stay rare enough to remain meaningful.
func seize_attention(at: Vector3) -> void:
	attending = at
	attention_clock = 0.0
	_released = 0
	_seized.clear()
	state = State.HIGH_ATTENTION
	# THE SNAP. Instantaneous and total: no easing, no per-individual delay,
	# because the legibility of the whole beat is that it is simultaneous.
	if margin != null:
		for p in margin.palps:
			_take(p, at)
	if critters != null:
		for c in critters.critters:
			_take_critter(c, at)
	if hero != null and is_instance_valid(hero):
		hero.attention_override = at
	attention_seized.emit(at)


func _take(p: Dictionary, at: Vector3) -> void:
	p.attend_override = at
	p.act = 7        # WATCH
	p.act_clock = 0.0
	p.act_left = HOLD_S + 4.0
	_seized["p%d" % int(p.id)] = true


func _take_critter(c: Dictionary, at: Vector3) -> void:
	c.attend_override = at
	c.moving = false
	_seized["c%d" % int(c.id)] = true


## Anything born mid-event joins it. Until this existed the margin spawned a
## palp during the reveal and it carried on probing a skirting board while
## seventy-one others stared at the same point.
func _sweep_newcomers() -> void:
	if margin != null:
		for p in margin.palps:
			if not _seized.has("p%d" % int(p.id)):
				_take(p, attending)
	if critters != null:
		for c in critters.critters:
			if not _seized.has("c%d" % int(c.id)):
				_take_critter(c, attending)


## Autonomy returns ASYNCHRONOUSLY. §13 is explicit about it, and it is the
## half that makes the event read as attention rather than as a switch: a
## coordinated release would look like a machine being turned off.
func _run_attention(delta: float) -> void:
	attention_clock += delta
	if attention_clock < HOLD_S:
		_sweep_newcomers()
		return
	if margin != null:
		for p in margin.palps:
			if p.get("attend_override", Vector3.INF) == Vector3.INF:
				continue
			# Each individual lets go on its own schedule, and a curious one
			# holds on longer than a jumpy one.
			var own: float = HOLD_S + float(p.traits.curiosity) * 2.6 \
					+ float(p.traits.startle_threshold) * 1.4
			if attention_clock > own:
				p.attend_override = Vector3.INF
				p.act_left = 0.0
				_released += 1
	if critters != null:
		for c in critters.critters:
			if c.get("attend_override", Vector3.INF) == Vector3.INF:
				continue
			var own: float = HOLD_S + float(c.morph.curiosity) * 3.0 \
					+ float(c.morph.startle) * 1.8
			if attention_clock > own:
				c.attend_override = Vector3.INF
				_released += 1
	if attention_clock > HOLD_S + 5.6:
		if hero != null and is_instance_valid(hero):
			hero.attention_override = Vector3.INF
		attending = Vector3.INF
		state = State.CURIOUS
		state_clock = 0.0
		attention_released.emit()


## Facts for the contract.
func census() -> Dictionary:
	var held := 0
	if margin != null:
		for p in margin.palps:
			if p.get("attend_override", Vector3.INF) != Vector3.INF:
				held += 1
	if critters != null:
		for c in critters.critters:
			if c.get("attend_override", Vector3.INF) != Vector3.INF:
				held += 1
	return {"state": state_name(), "attending": attending != Vector3.INF,
			"still_held": held, "released": _released,
			"attention_clock": snappedf(attention_clock, 0.01)}
