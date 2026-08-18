class_name DreamHazard
extends RefCounted
## N7: one authored danger in the dream, and the fairness contract around it.
##
## The brief's bar is not "the hazard works", it is **"the player
## understands in the half-second before impact"**. So every hazard here
## owns three things in order: a TELL that starts at tell_radius, a
## CONDITION that decides whether the danger is live at all, and only
## then a CONTACT inside clearance_radius. A hazard that can contact
## before its tell has started is a bug by construction, and the field
## measures the realised warning on every impact so the claim is a
## number rather than an intention.
##
## Geometry comes from the catalog through DreamMazeBuilder's plan.
## Behaviour comes from the profile's tuning block. Nothing here is
## hardcoded per case: the same class runs Mina's three and the five the
## later slots introduce.

## Returned by evaluate() when nothing happens. An outcome string means
## the run ends and must be one of DreamDirector.OUTCOMES.
const NONE := ""

var id := ""
## The catalog socket this instance came from. See configure(): `id` is which
## hazard, `socket` is which KIND of hazard, and the fractal is what separated
## them.
var socket := ""
var kind := ""
var module := ""
var position := Vector3.ZERO
var clearance_radius := 0.35
var tell_radius := 4.60
var minimum_warning_s := 0.50
## True for a hazard whose mouth the builder cut out of the floor. Such a
## hazard is resolved by gravity, not by proximity — see evaluate().
var falls_through := false

## From the profile, not the catalog: what this does to a case's run.
var outcome := ""
var caption := ""
var condition := ""
var break_speed_mps := 3.8

## Tell state. -1.0 means the player has not been close enough yet.
var tell_started_s := -1.0
var contacted := false
var contact_s := -1.0
## The distance at which the tell first fired, kept for the impact record
## so a reviewer can see the player had room as well as time.
var tell_distance := 0.0


func configure(record: Dictionary, tuning: Dictionary) -> void:
	id = str(record.get("id", ""))
	# WHICH CATALOG SOCKET THIS IS, as distinct from WHICH INSTANCE OF IT.
	# The chain placed every module at most once, so a socket id named exactly
	# one hazard in the world and the two were the same fact. The fractal can
	# have three live rooms all remembering D03, and then "open_lift_void"
	# names three different holes in three different floors. `id` stays unique
	# so a tell, a contact and a caption can never be attributed to the wrong
	# one; `socket` is what the profile's allowlist and tuning are written
	# against. On the chain path they are identical and nothing changes.
	socket = str(record.get("socket", record.get("id", "")))
	kind = str(record.get("kind", ""))
	module = str(record.get("module", ""))
	var p: Array = record.get("position", [0.0, 0.0])
	position = Vector3(float(p[0]), 0.0, float(p[1]))
	clearance_radius = float(record.get("clearance_radius_m", 0.35))
	# The same rule the builder used to decide what to cut, read from the
	# same field, so geometry and behaviour can never disagree about which
	# hazards are holes.
	falls_through = kind == "positional"
	tell_radius = float(record.get("tell_radius_m", 4.60))
	minimum_warning_s = float(record.get("minimum_warning_s", 0.50))
	outcome = str(tuning.get("outcome", ""))
	caption = str(tuning.get("caption", ""))
	condition = str(tuning.get("condition", ""))
	break_speed_mps = float(tuning.get("break_speed_mps", 3.8))


## One deterministic step. `elapsed` is the run clock, so the warning a
## player actually got is measurable rather than inferred.
##
## Returns "" for nothing, or an outcome string when the run should end.
## A non-terminating hazard (the hollow runner breaks a floor rather than
## ending a dream) carries outcome "" and reports its contact through
## `contacted` instead.
func evaluate(player_pos: Vector3, lamp_on: bool, speed: float,
		elapsed: float) -> String:
	if contacted:
		return NONE
	var flat := Vector3(player_pos.x, 0.0, player_pos.z)
	var d := flat.distance_to(position)

	# THE TELL COMES FIRST AND IT IS UNCONDITIONAL. You hear the chain in
	# the shaft and the hiss in the trunk whether or not your lamp is on
	# and whether or not the danger is currently live -- that is the whole
	# point of darkness being survivable. Arming it here, before any
	# condition is consulted, is what makes the warning honest.
	if tell_started_s < 0.0 and d <= tell_radius:
		tell_started_s = elapsed
		tell_distance = d

	# A void does not "contact" anyone. The builder cut its mouth out of the
	# floor, so the player falls through real missing floor under real
	# gravity, and this only reads the result. Attribution is generous enough
	# to cover the square mouth's corners, which sit outside the clearance
	# circle, and a body below the trigger is necessarily inside a shaft.
	if falls_through:
		if player_pos.y > DreamMazeBuilder.FALL_TRIGGER_Y:
			return NONE
		if d > clearance_radius * 1.5:
			return NONE
		contacted = true
		contact_s = elapsed
		return outcome

	if d > clearance_radius:
		return NONE
	if not _condition_live(lamp_on, speed):
		return NONE
	contacted = true
	contact_s = elapsed
	return outcome


## Whether the danger is live at this instant. An unconditional hazard is
## always live inside its clearance; a conditional one is the interesting
## case, because it is where the light stops being purely a benefit.
func _condition_live(lamp_on: bool, speed: float) -> bool:
	match condition:
		"lamp_on":
			# The Vantry trunk's arc reaches for the beam. Darkness leaves
			# a clean narrow passage, which is the ruled lesson: light can
			# activate the danger it reveals.
			return lamp_on
		"running":
			# The hollow runner breaks under a run and holds under a walk.
			return speed >= break_speed_mps
		_:
			return true


## The fairness record the brief requires on every impact: when the tell
## started, how far away the player was when it did, the realised warning
## in seconds, the light state at contact, and the hazard that caused it.
func impact_record(lamp_on: bool) -> Dictionary:
	return {
		"hazard_id": id,
		"kind": kind,
		"module": module,
		"tell_start_s": tell_started_s,
		"tell_distance_m": tell_distance,
		"contact_s": contact_s,
		"realised_warning_s": (contact_s - tell_started_s)
				if tell_started_s >= 0.0 else -1.0,
		"minimum_warning_s": minimum_warning_s,
		"lamp_on": lamp_on,
		"outcome": outcome,
	}
