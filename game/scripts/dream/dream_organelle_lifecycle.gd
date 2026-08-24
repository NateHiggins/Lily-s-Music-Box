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
