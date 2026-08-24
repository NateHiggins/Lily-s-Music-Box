class_name DreamOrganelleLifecycle
extends RefCounted
## Ownerless lifecycle vocabulary for local expressions of the Dream body.
##
## This helper classifies; the organ's existing owner still decides how a
## folded, mature or shed body behaves. It owns no node, clock, route or fact.

enum Stage { FOLDED, BUD, JUVENILE, MATURE, EXCHANGE, SENESCENT, SHED, STAIN }
enum Reproduction { QUIESCENT, ASEXUAL, SEXUAL, PANSEXUAL }

const STAGE_NAMES := [
	"folded", "bud", "juvenile", "mature", "exchange", "senescent",
	"shed", "stain",
]
const REPRODUCTION_NAMES := ["quiescent", "asexual", "sexual", "pansexual"]
const STAGE_ENDS := [0.08, 0.18, 0.38, 0.65, 0.78, 0.90, 0.97, 1.0]
const MIN_LIFE_S := 45.0
const MAX_LIFE_S := 150.0


static func stage_at(progress: float) -> int:
	var age := clampf(progress, 0.0, 1.0)
	for index in STAGE_ENDS.size():
		if age < float(STAGE_ENDS[index]) or index == STAGE_ENDS.size() - 1:
			return index
	return Stage.STAIN


static func stage_name(stage: int) -> String:
	return STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)]


static func reproduction_name(mode: int) -> String:
	return REPRODUCTION_NAMES[clampi(
			mode, 0, REPRODUCTION_NAMES.size() - 1)]


## Environmental selection, not identity. `same_compatibility` describes a
## stable complementary cleft; `cross_compatibility` describes useful pattern
## exchange across unlike organ classes.
static func reproduction_for(environment: Dictionary) -> int:
	var food := clampf(float(environment.get("food", 0.0)), 0.0, 1.0)
	var ether := clampf(float(environment.get("ether", 0.0)), 0.0, 1.0)
	var density := clampf(float(environment.get("density", 0.0)), 0.0, 1.0)
	var diversity := clampf(float(environment.get("diversity", 0.0)), 0.0, 1.0)
	var same := clampf(float(environment.get(
			"same_compatibility", 0.0)), 0.0, 1.0)
	var cross := clampf(float(environment.get(
			"cross_compatibility", 0.0)), 0.0, 1.0)
	if food >= 0.62 and ether < 0.42 and density <= 0.50:
		return Reproduction.ASEXUAL
	if ether >= 0.55 and density >= 0.40 and same >= 0.55:
		return Reproduction.SEXUAL
	if ether >= 0.34 and cross >= 0.50 \
			and (same < 0.55 or diversity >= 0.55):
		return Reproduction.PANSEXUAL
	return Reproduction.QUIESCENT


static func life_seconds(environment: Dictionary) -> float:
	var food := clampf(float(environment.get("food", 0.0)), 0.0, 1.0)
	var ether := clampf(float(environment.get("ether", 0.0)), 0.0, 1.0)
	var stress := clampf(float(environment.get("stress", 0.0)), 0.0, 1.0)
	return clampf(MAX_LIFE_S - food * 65.0 - ether * 35.0 + stress * 20.0,
			MIN_LIFE_S, MAX_LIFE_S)


static func new_record(seed_phase := 0.0) -> Dictionary:
	return {
		"progress": fposmod(float(seed_phase), 1.0),
		"stage": stage_at(fposmod(float(seed_phase), 1.0)),
		"generation": 0,
		"births": 0,
		"deaths": 0,
		"stains": 0,
		"reproduction": Reproduction.QUIESCENT,
	}


## Advances caller-owned state. A completed life always leaves a stain; a new
## cohort begins only when the current environment permits reproduction.
static func advance(record: Dictionary, environment: Dictionary,
		seconds: float) -> Dictionary:
	var next := record.duplicate(true)
	var mode := reproduction_for(environment)
	next.reproduction = mode
	var progress := clampf(float(next.get("progress", 0.0)), 0.0, 1.0)
	progress += maxf(0.0, seconds) / life_seconds(environment)
	while progress >= 1.0:
		progress -= 1.0
		next.deaths = int(next.get("deaths", 0)) + 1
		next.stains = int(next.get("stains", 0)) + 1
		if mode == Reproduction.QUIESCENT:
			progress = 1.0
			break
		next.births = int(next.get("births", 0)) + 1
		next.generation = int(next.get("generation", 0)) + 1
	next.progress = progress
	next.stage = stage_at(progress)
	return next


## Fold and collapse are poses of complete tissue. Presentation may change its
## angle, compression or burial, never manufacture anatomy from zero scale.
static func anatomy_scale(_stage: int) -> float:
	return 1.0


## Four conservative compartments. Rates move matter clockwise through the
## room; they never add or discard it. Values are presentation mass, not save
## facts or player resources.
static func new_ether_cycle(ethermoss := 0.40, ether := 0.20,
		living_tissue := 0.30, death_stain := 0.10) -> Dictionary:
	var cycle := {
		"ethermoss": maxf(0.0, ethermoss),
		"ether": maxf(0.0, ether),
		"living_tissue": maxf(0.0, living_tissue),
		"death_stain": maxf(0.0, death_stain),
	}
	var total := cycle_total(cycle)
	if total <= 0.0:
		return {"ethermoss": 0.40, "ether": 0.20,
				"living_tissue": 0.30, "death_stain": 0.10}
	for key in cycle:
		cycle[key] = float(cycle[key]) / total
	return cycle


static func advance_ether_cycle(cycle: Dictionary, environment: Dictionary,
		seconds: float) -> Dictionary:
	var next := new_ether_cycle(float(cycle.get("ethermoss", 0.0)),
			float(cycle.get("ether", 0.0)),
			float(cycle.get("living_tissue", 0.0)),
			float(cycle.get("death_stain", 0.0)))
	var dt := maxf(0.0, seconds)
	var light := clampf(float(environment.get("light", 0.0)), 0.0, 1.0)
	var activity := clampf(float(environment.get("activity", 0.0)), 0.0, 1.0)
	var senescence := clampf(float(environment.get(
			"senescence", 0.0)), 0.0, 1.0)
	var reclamation := clampf(float(environment.get(
			"reclamation", 0.0)), 0.0, 1.0)
	var exhaled := minf(float(next.ethermoss), (0.006 + light * 0.012) * dt)
	var inhaled := minf(float(next.ether), (0.005 + activity * 0.015) * dt)
	var shed := minf(float(next.living_tissue),
			(0.002 + senescence * 0.020) * dt)
	var reclaimed := minf(float(next.death_stain),
			(0.001 + reclamation * 0.014) * dt)
	next.ethermoss = float(next.ethermoss) - exhaled + reclaimed
	next.ether = float(next.ether) + exhaled - inhaled
	next.living_tissue = float(next.living_tissue) + inhaled - shed
	next.death_stain = float(next.death_stain) + shed - reclaimed
	return next


static func cycle_total(cycle: Dictionary) -> float:
	return float(cycle.get("ethermoss", 0.0)) \
			+ float(cycle.get("ether", 0.0)) \
			+ float(cycle.get("living_tissue", 0.0)) \
			+ float(cycle.get("death_stain", 0.0))
