class_name DreamMicrobiologyLight
extends RefCounted
## A small, ownerless receptor law for scaled-up microbial photobehaviour.
##
## This does not make a Dream organ "see". It turns the player's existing
## lamp into a local membrane stimulus: direct cone exposure arrives quickly,
## an adapted baseline follows more slowly, a sufficiently abrupt positive
## step causes one photoshock, and a refractory interval makes repeated
## flashes less effective. Controllers remain the owners of what their
## anatomy does with those numbers.

const ADAPT_LIGHT_S := 2.40
const ADAPT_DARK_S := 1.15
const SHOCK_DECAY_S := 0.42
const REFRACTORY_S := 1.50
const SENSITIVITY_RECOVER_S := 5.0
const SHOCK_STEP := 0.28
const SHOCK_LEVEL := 0.34


static func state() -> Dictionary:
	return {
		"level": 0.0,
		"adapted": 0.0,
		"response": 0.0,
		"shock": 0.0,
		"refractory": 0.0,
		"sensitivity": 1.0,
		"shocks": 0,
		"scan": 0.0,
	}


## Analytic exposure from the production lamp pose. The cone has a soft rim
## and inverse-square-like falloff, but remains dimensionless: this is a
## receptor drive, not a second account of the renderer's physical light.
static func sample(pose: Dictionary, at: Vector3) -> Dictionary:
	if pose.is_empty() or float(pose.get("energy", 0.0)) <= 0.0:
		return {"level": 0.0, "toward": Vector3.ZERO, "beam_dir": Vector3.ZERO}
	var origin: Vector3 = pose.get("origin", Vector3.ZERO)
	var beam: Vector3 = (pose.get("dir", Vector3.FORWARD) as Vector3).normalized()
	var delta := at - origin
	var distance := delta.length()
	var authored_range := maxf(0.01, float(pose.get("range", 1.0)))
	var limit := authored_range
	if pose.has("splash"):
		limit = minf(limit, origin.distance_to(pose.splash as Vector3) + 0.12)
	if distance <= 0.001 or distance >= limit:
		return {"level": 0.0, "toward": -beam, "beam_dir": beam}
	var ray := delta / distance
	var half_angle := deg_to_rad(float(pose.get("angle_deg", 45.0)) * 0.5)
	var inner := cos(half_angle * 0.72)
	var outer := cos(half_angle)
	var cone := smoothstep(outer, inner, beam.dot(ray))
	var range_falloff := pow(clampf(1.0 - distance / authored_range, 0.0, 1.0), 0.65)
	# 0.74 is the production hand-lamp's settled base energy. Normalising to
	# that owner value lets guttering reduce receptor drive without requiring
	# an invented brighter proof lamp.
	var energy := clampf(float(pose.get("energy", 0.0)) / 0.74, 0.0, 1.0)
	return {"level": clampf(cone * range_falloff * energy, 0.0, 1.0),
			"toward": -ray, "beam_dir": beam}


## Mutates one recipient's transient receptor state and returns true only on
## the frame a new photoshock is admitted through the refractory gate.
static func advance(receptor: Dictionary, direct: float, delta: float) -> bool:
	var dt := maxf(0.0, delta)
	var level := clampf(direct, 0.0, 1.0)
	var adapted_before := float(receptor.get("adapted", 0.0))
	var level_before := float(receptor.get("level", 0.0))
	var refractory := maxf(0.0, float(receptor.get("refractory", 0.0)) - dt)
	var sensitivity := float(receptor.get("sensitivity", 1.0))
	# Sensitivity is replenished in darkness, not merely by waiting under the
	# same lamp. That keeps unreliable-lamp repeats meaningfully weaker.
	if level < 0.08:
		sensitivity = move_toward(sensitivity, 1.0,
				dt / SENSITIVITY_RECOVER_S)
	# Photoshock is a STEP detector, not merely a detector of being poorly
	# adapted. Otherwise sustained light would fire again whenever the fixed
	# refractory timer elapsed, which is the opposite of adaptation.
	var onset := maxf(0.0, level - level_before)
	var admitted := onset >= SHOCK_STEP and level >= SHOCK_LEVEL and refractory <= 0.0
	var shock := maxf(0.0, float(receptor.get("shock", 0.0)) - dt / SHOCK_DECAY_S)
	if admitted:
		shock = sensitivity
		refractory = REFRACTORY_S
		sensitivity *= 0.62
		receptor.shocks = int(receptor.get("shocks", 0)) + 1
	var tau := ADAPT_LIGHT_S if level >= adapted_before else ADAPT_DARK_S
	var adapted := lerpf(adapted_before, level, 1.0 - exp(-dt / tau))
	var contrast := maxf(0.0, level - adapted)
	receptor.level = level
	receptor.adapted = adapted
	receptor.response = clampf(contrast * 1.8 + shock, 0.0, 1.0)
	receptor.shock = shock
	receptor.refractory = refractory
	receptor.sensitivity = sensitivity
	receptor.scan = fmod(float(receptor.get("scan", 0.0))
			+ dt * (0.42 + contrast * 1.9), TAU)
	return admitted
