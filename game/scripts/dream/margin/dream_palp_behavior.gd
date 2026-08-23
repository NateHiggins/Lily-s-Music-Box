class_name DreamPalpBehavior
extends RefCounted
## PHASE 5 — PERSONALITY AND INTENT (ecology architecture §8, §9).
##
##     "No global sine-wave waving."
##     "Use actual behavioral targeting to drive the desired pose."
##
## Two things live here, and they are deliberately separate.
##
## PERSONALITY is stable. §8 is explicit that it must not be reshuffled
## continuously, because that is what makes an individual appendage memorable
## rather than one sample of a distribution. It comes from the palp's seed and
## never changes for its whole life.
##
## INTENT is what it is doing about the world right now. §9 names ten movement
## primitives, and every one of them is a different relationship to a TARGET —
## probing toward one, tremoring on one, tracing along one, bracing against
## one, or having none at all. So the primitives are not animations; they are
## ways of choosing where the tip wants to be, and the rig solves toward that.

enum Act { PROBE, SAMPLE, HOVER, TOUCH, TRACE, BRACE, TASTE, WATCH, WITHDRAW, FREEZE }

const ACT_NAMES := ["probe", "sample", "hover", "touch", "trace", "brace",
		"taste", "watch", "withdraw", "freeze"]


## §8 — stable traits, from the seed, for life.
static func personality(seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + 7
	return {
		"curiosity": rng.randf(),
		"boldness": rng.randf(),
		"startle_threshold": rng.randf_range(0.15, 0.95),
		"contact_persistence": rng.randf(),
		"social_affinity": rng.randf(),
		"territoriality": rng.randf(),
		"object_interest": rng.randf(),
		"branch_likelihood": rng.randf(),
		"tremor_frequency": rng.randf_range(5.0, 9.0),   # §9: 5-9 Hz sampling
		"preferred_reach": rng.randf_range(0.45, 1.0),
		"phase_instability": rng.randf() * 0.4,
		"hero_affinity": rng.randf(),
		"critter_affinity": rng.randf(),
	}


## Choose what to do next. The traits bias the choice; they do not determine
## it, or every palp with high curiosity would be doing the same thing at the
## same moment.
static func next_act(p: Dictionary, rng: RandomNumberGenerator) -> int:
	var tr: Dictionary = p.traits
	var has_target: bool = p.has("target") and p.target != Vector3.INF
	if not has_target:
		# Nothing found. Curious ones keep probing; incurious ones idle.
		return Act.PROBE if rng.randf() < 0.35 + 0.5 * float(tr.curiosity) \
				else Act.HOVER
	match int(p.act):
		Act.PROBE:
			return Act.TOUCH
		Act.TOUCH:
			# What it does having arrived is the most characterful choice it
			# makes, and it is the one traits should own most strongly.
			var r := rng.randf()
			if r < 0.30 + 0.45 * float(tr.object_interest):
				return Act.TRACE
			if r < 0.72:
				return Act.TASTE
			return Act.BRACE
		Act.TRACE, Act.TASTE, Act.BRACE:
			if rng.randf() < 0.25 + 0.55 * (1.0 - float(tr.contact_persistence)):
				return Act.WITHDRAW
			return Act.SAMPLE
		Act.SAMPLE:
			return Act.TRACE if rng.randf() < float(tr.object_interest) else Act.WITHDRAW
		Act.WITHDRAW:
			return Act.PROBE
		_:
			return Act.PROBE


## How long the current act lasts. §9's primitives have very different
## natural durations: a sample is a flick, a brace is a commitment.
static func duration(act: int, tr: Dictionary, rng: RandomNumberGenerator) -> float:
	match act:
		Act.PROBE: return rng.randf_range(0.7, 1.6)
		Act.SAMPLE: return rng.randf_range(0.25, 0.6)
		Act.HOVER: return rng.randf_range(0.8, 2.2)
		Act.TOUCH: return rng.randf_range(0.35, 0.8)
		Act.TRACE: return rng.randf_range(1.2, 3.4) * (0.5 + float(tr.contact_persistence))
		Act.BRACE: return rng.randf_range(1.8, 4.0)
		Act.TASTE: return rng.randf_range(0.6, 1.5)
		Act.WATCH: return rng.randf_range(1.0, 2.6)
		Act.WITHDRAW: return rng.randf_range(0.5, 1.1)
		Act.FREEZE: return rng.randf_range(1.4, 3.2)
	return 1.0


## Where the tip wants to be, this instant, given what it is doing.
##
## This is the whole of §9: a primitive is a rule for producing a desired tip
## position, not a canned motion. `Probe` steps toward and pauses; `Sample`
## tremors in place at the individual's own frequency; `Trace` slides along
## the surface; `Brace` plants and stops moving at all.
static func desired_tip(p: Dictionary, clock: float) -> Vector3:
	var tr: Dictionary = p.traits
	var anchor: Vector3 = p.anchor
	var nrm: Vector3 = p.normal
	var reach: float = float(p.morph.length) * (0.55 + 0.45 * float(tr.boldness))
	var target: Vector3 = p.target if p.has("target") else Vector3.INF
	var side: Vector3 = p.side
	var up: Vector3 = nrm.cross(side)
	var phase: float = float(p.act_clock)
	match int(p.act):
		Act.PROBE:
			# Extend, stop, microcorrect, stop, extend — a staircase, never a
			# smooth glide.
			var steps: float = floor(phase * 3.4)
			var frac: float = clampf((phase * 3.4 - steps) * 2.2, 0.0, 1.0)
			var out: float = clampf((steps + frac) / 5.0, 0.0, 1.0)
			var toward: Vector3 = (target - anchor).normalized() if target != Vector3.INF \
					else nrm
			return anchor + toward * reach * out
		Act.SAMPLE:
			# Distal-only tremor at this individual's own frequency.
			var base: Vector3 = target if target != Vector3.INF else anchor + nrm * reach
			var f: float = float(tr.tremor_frequency)
			return base + side * sin(clock * f) * 0.004 \
					+ up * cos(clock * f * 1.31) * 0.004
		Act.HOVER:
			var b: Vector3 = anchor + nrm * reach * 0.7
			return b + side * sin(clock * 1.3) * 0.010 + up * cos(clock * 1.1) * 0.010
		Act.TOUCH:
			# Velocity decreases before contact: ease in, do not arrive at speed.
			if target == Vector3.INF:
				return anchor + nrm * reach * 0.6
			var t: float = smoothstep(0.0, 1.0, clampf(phase / 0.6, 0.0, 1.0))
			return anchor.lerp(target, 0.35 + 0.65 * t)
		Act.TRACE:
			# Follow the surface, not the air: slide along it from the contact.
			if target == Vector3.INF:
				return anchor + nrm * reach * 0.6
			var along: Vector3 = side * cos(float(p.trace_angle)) + up * sin(float(p.trace_angle))
			return target + along * (phase * 0.06)
		Act.TASTE:
			# Short repeated local sampling: on, off, on.
			if target == Vector3.INF:
				return anchor + nrm * reach * 0.6
			var beat: float = fposmod(phase * 3.2, 1.0)
			var lift: float = 0.018 * smoothstep(0.35, 0.75, beat)
			return target + nrm * lift
		Act.BRACE:
			# Planted. It does not move at all, which among a dozen moving
			# things is the most noticeable thing a palp can do.
			return target if target != Vector3.INF else anchor + nrm * reach * 0.5
		Act.WATCH:
			return anchor + nrm * reach * 0.85
		Act.WITHDRAW:
			var back: float = 1.0 - clampf(phase / 0.8, 0.0, 1.0)
			return anchor + nrm * reach * 0.5 * back
		Act.FREEZE:
			return p.last_tip if p.has("last_tip") else anchor + nrm * reach * 0.5
	return anchor + nrm * reach * 0.5


static func act_name(act: int) -> String:
	return ACT_NAMES[act]
