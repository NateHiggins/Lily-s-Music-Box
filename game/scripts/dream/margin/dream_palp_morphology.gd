class_name DreamPalpMorphology
extends RefCounted
## THE MARGIN'S ANATOMY (ecology architecture §5, §6, §7).
##
## Every palp is generated from an AUTHORED ARCHETYPE plus seeded variation
## inside that archetype's constraints. The ruling is explicit about why:
##
##     "Do not generate meaningless tubes."
##     "No procedural oatmeal. A Gold Jointed Finger should always remain
##      recognizably different from a Flat Ribbon."
##
## So the archetype owns the things that make it that species of organ — its
## cross-section progression, where its mass sits, what its far end is FOR —
## and the seed owns only proportion within those bounds. Two soft palps
## differ; a soft palp and a membrane tongue are never confusable.
##
## §7 is the load-bearing part. A tube with a different radius curve is still
## a tube. What actually reads as biological variety is the CROSS-SECTION
## CHANGING ALONG THE LENGTH — muscular root to flattened shaft to lobed
## sensory region to fine tip — so that is what an archetype authors.

## The archetypes. Development names; species canon comes later.
enum Kind {
	SOFT_PALP,        ## muscular fleshy exploratory organ
	FLAT_RIBBON,      ## broad tactile surface
	SUCKER_PROBE,     ## specialised surface sampler
	GOLD_FINGER,      ## rigid/flexible biomineral articulation
	CRYSTAL_FEELER,   ## fine probe with a sensory mineral organ
	CILIATED_WHISKER, ## long distance/vibration detector
}

const KIND_NAMES := ["soft_palp", "flat_ribbon", "sucker_probe",
		"gold_finger", "crystal_feeler", "ciliated_whisker"]

## A cross-section is (flatten, lobes, lobe_depth, asymmetry). One per station
## along the palp; the shader interpolates between them.
##   flatten    0 round .. 1 a ribbon
##   lobes      how many longitudinal swellings the section carries
##   depth      how pronounced those lobes are
##   asym       pushes the section off its own axis: no organ is symmetrical
const STATIONS := 4

## Per archetype, in order: the four cross-sections root -> tip.
const SECTIONS := {
	Kind.SOFT_PALP: [
		Vector4(0.10, 3.0, 0.16, 0.05),   # muscular root, softly lobed
		Vector4(0.22, 3.0, 0.10, 0.10),   # a compressed shaft
		Vector4(0.12, 5.0, 0.18, 0.06),   # lobed sensory swelling
		Vector4(0.05, 2.0, 0.06, 0.02),   # fine tip
	],
	Kind.FLAT_RIBBON: [
		Vector4(0.35, 2.0, 0.10, 0.08),
		Vector4(0.74, 1.0, 0.05, 0.04),   # broad and thin
		Vector4(0.86, 1.0, 0.03, 0.10),   # the tactile face
		Vector4(0.72, 2.0, 0.08, 0.14),   # a rippled trailing edge
	],
	Kind.SUCKER_PROBE: [
		Vector4(0.06, 2.0, 0.10, 0.03),
		Vector4(0.10, 2.0, 0.08, 0.05),
		Vector4(0.30, 4.0, 0.22, 0.10),   # the pad begins to spread
		Vector4(0.62, 1.0, 0.05, 0.06),   # a broad sampling face
	],
	Kind.GOLD_FINGER: [
		Vector4(0.14, 4.0, 0.26, 0.06),   # knuckled from the root
		Vector4(0.08, 3.0, 0.30, 0.12),   # a hard articulated swelling
		Vector4(0.16, 4.0, 0.28, 0.08),   # the second joint
		Vector4(0.06, 3.0, 0.14, 0.04),   # a blunt working end
	],
	Kind.CRYSTAL_FEELER: [
		Vector4(0.05, 2.0, 0.08, 0.04),
		Vector4(0.04, 2.0, 0.04, 0.03),   # very fine shaft
		Vector4(0.03, 3.0, 0.05, 0.02),
		Vector4(0.02, 6.0, 0.34, 0.03),   # the faceted organ at the end
	],
	Kind.CILIATED_WHISKER: [
		Vector4(0.12, 3.0, 0.14, 0.05),   # a muscular base
		Vector4(0.03, 2.0, 0.03, 0.02),   # then almost nothing
		Vector4(0.02, 2.0, 0.02, 0.02),
		Vector4(0.01, 2.0, 0.01, 0.01),   # a hair
	],
}

## length_min, length_max, base_radius, tip_ratio, stiffness, gold, crystal,
## suckers, cilia, branch_likelihood
const BOUNDS := {
	Kind.SOFT_PALP:        [0.16, 0.44, 0.021, 0.24, 0.30, 0.10, 0.05, 0.25, 0.20, 0.35],
	Kind.FLAT_RIBBON:      [0.22, 0.58, 0.026, 0.55, 0.18, 0.06, 0.02, 0.10, 0.10, 0.15],
	Kind.SUCKER_PROBE:     [0.12, 0.34, 0.019, 0.70, 0.34, 0.14, 0.04, 0.95, 0.15, 0.10],
	Kind.GOLD_FINGER:      [0.14, 0.38, 0.023, 0.34, 0.86, 0.72, 0.10, 0.05, 0.05, 0.05],
	Kind.CRYSTAL_FEELER:   [0.18, 0.46, 0.011, 0.90, 0.62, 0.30, 0.85, 0.00, 0.35, 0.05],
	Kind.CILIATED_WHISKER: [0.30, 0.70, 0.013, 0.06, 0.10, 0.05, 0.02, 0.00, 0.95, 0.02],
}

var kind: int = Kind.SOFT_PALP
var seed_value := 0.0
var length := 0.3
var base_radius := 0.02
var tip_ratio := 0.3
var stiffness := 0.3
var gold := 0.1
var crystal := 0.05
var suckers := 0.2
var cilia := 0.2
var branch_likelihood := 0.2
var twist := 0.0
var curvature := 0.0
var sections: Array[Vector4] = []


## Generate one individual. The archetype constrains; the seed varies.
static func generate(archetype: int, seed_v: int) -> DreamPalpMorphology:
	var m := DreamPalpMorphology.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	m.kind = archetype
	m.seed_value = float(seed_v % 733) * 0.021
	var b: Array = BOUNDS[archetype]
	m.length = rng.randf_range(float(b[0]), float(b[1]))
	# Proportion varies; the archetype's character does not.
	m.base_radius = float(b[2]) * rng.randf_range(0.80, 1.30)
	m.tip_ratio = clampf(float(b[3]) * rng.randf_range(0.85, 1.15), 0.01, 1.0)
	m.stiffness = clampf(float(b[4]) * rng.randf_range(0.85, 1.15), 0.0, 1.0)
	m.gold = clampf(float(b[5]) * rng.randf_range(0.7, 1.3), 0.0, 1.0)
	m.crystal = clampf(float(b[6]) * rng.randf_range(0.6, 1.4), 0.0, 1.0)
	m.suckers = clampf(float(b[7]) * rng.randf_range(0.8, 1.2), 0.0, 1.0)
	m.cilia = clampf(float(b[8]) * rng.randf_range(0.7, 1.3), 0.0, 1.0)
	m.branch_likelihood = clampf(float(b[9]) * rng.randf_range(0.6, 1.5), 0.0, 1.0)
	m.twist = rng.randf_range(-1.0, 1.0) * (1.0 - m.stiffness) * 1.4
	m.curvature = rng.randf_range(0.25, 1.0)
	# The sections themselves wobble a little per individual, never enough to
	# turn one archetype into another.
	var authored: Array = SECTIONS[archetype]
	for i in STATIONS:
		var s: Vector4 = authored[i]
		m.sections.append(Vector4(
				clampf(s.x * rng.randf_range(0.88, 1.12), 0.0, 0.95),
				s.y,
				s.z * rng.randf_range(0.8, 1.2),
				s.w * rng.randf_range(0.5, 1.6)))
	return m


func name_of_kind() -> String:
	return KIND_NAMES[kind]


## What the far end is FOR. §10 of the menagerie brief: the last 10-30% of an
## exploratory appendage must be more complex than the shaft carrying it.
func distal_specialisation() -> String:
	match kind:
		Kind.SUCKER_PROBE: return "pad"
		Kind.CRYSTAL_FEELER: return "crystal_organ"
		Kind.GOLD_FINGER: return "mineral_claw"
		Kind.FLAT_RIBBON: return "tactile_face"
		Kind.CILIATED_WHISKER: return "cilia_tuft"
		_: return "lobed_sensory"


func summary() -> Dictionary:
	return {"kind": name_of_kind(), "len": snappedf(length, 0.001),
			"distal": distal_specialisation(), "gold": snappedf(gold, 0.01),
			"stiff": snappedf(stiffness, 0.01)}
