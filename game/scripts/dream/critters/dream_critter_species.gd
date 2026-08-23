class_name DreamCritterSpecies
extends RefCounted
## THE FIRST THREE SPECIES (ecology architecture §14, §15, §16, §24).
##
##     "Do not procedurally synthesize arbitrary animals from nothing. Use
##      authored anatomical species templates with controlled procedural
##      variation."
##
## A species here is a set of HARD RULES plus a set of dials. §16 is explicit
## about the difference: a Seam Grazer *must* have a flattened body, a low
## silhouette, a tactile underside and a seam-following organ; it *may* vary
## its length, width, feeler count, lattice pattern and rhythm; and it
## *cannot* become a spherical floating creature, a long tentacle or a
## six-foot spider. **Species identity comes before variety.**
##
## Each also carries exactly one impossible rule (§24), which is species
## biology rather than an effect applied to it. One rule, not a pile.

enum Kind { SEAM_GRAZER, CRYSTAL_LISTENER, FOLD_CRAB }

const NAMES := ["seam_grazer", "crystal_listener", "fold_crab"]

## The three body plans are deliberately as different as §3 asks for: a
## flattened crawler, a mostly-sensory radial organism, and a low multi-limbed
## walker. Nobody should confuse them in silhouette.
const SPECIES := {
	Kind.SEAM_GRAZER: {
		"thesis": "This organism tastes architectural seams, therefore its "
				+ "entire ventral anatomy is a flexible sensory comb.",
		"plan": "flattened_crawler",
		# body_len, body_wide, body_tall — a low silhouette is a HARD rule, so
		# the height bound cannot reach the width bound at any roll of the dice.
		"len_m": [0.14, 0.30],
		"wide_m": [0.10, 0.19],
		"tall_m": [0.018, 0.038],
		"limbs": [0, 0],
		"feelers": [3, 6],
		"rare_feelers": 8,          # §17: 5% get more
		"gold": [0.10, 0.28],
		"crystal": [0.02, 0.10],
		"cilia": [0.55, 0.95],      # the ventral comb
		"speed": [0.05, 0.13],
		"social": "opportunistic",
		# §24 — it can occupy both sides of a thin wall at once.
		"law": "both_sides_of_a_wall",
	},
	Kind.CRYSTAL_LISTENER: {
		"thesis": "This organism collects vibration, therefore most of its "
				+ "body is a mount for mineral resonators and it holds still "
				+ "to use them.",
		"plan": "radial_sensor",
		"len_m": [0.07, 0.13],
		"wide_m": [0.07, 0.13],
		"tall_m": [0.06, 0.12],
		"limbs": [3, 5],            # short props, not walking legs
		"feelers": [5, 9],          # long cilia: the actual organ
		"rare_feelers": 12,
		"gold": [0.20, 0.42],
		"crystal": [0.55, 0.90],    # the defining tissue
		"cilia": [0.70, 1.00],
		"speed": [0.01, 0.05],      # it barely moves, and freezes to listen
		"social": "solitary",
		# §24 — its sensory crystal rotates without its outside appearing to.
		"law": "crystal_turns_inside_a_still_shell",
	},
	Kind.FOLD_CRAB: {
		"thesis": "This organism works surfaces apart, therefore its front "
				+ "limbs are mouthparts and its joints are mineral cups.",
		"plan": "multi_limbed_walker",
		"len_m": [0.09, 0.20],
		"wide_m": [0.08, 0.17],
		# The bounds must GUARANTEE the rule, not merely usually satisfy it.
		# At 0.045 a crab could roll up 0.045 tall against 0.17 wide -- a ratio
		# of 0.26 against a rule demanding 0.35 -- and 23 of 1200 generated
		# individuals did exactly that. The floor is now wide_max * 0.35.
		"tall_m": [0.060, 0.11],
		"limbs": [6, 8],
		"feelers": [2, 4],
		"rare_feelers": 5,
		"gold": [0.40, 0.68],       # joint cups: the defining mineralisation
		"crystal": [0.05, 0.18],
		"cilia": [0.10, 0.35],
		"speed": [0.09, 0.22],
		"social": "colonial",
		# §24 — it shortens one leg without moving either end of it.
		"law": "leg_shortens_without_moving_its_ends",
	},
}


static func name_of(kind: int) -> String:
	return NAMES[kind]


static func rules(kind: int) -> Dictionary:
	return SPECIES[kind]


## §16's third clause, made executable: the things a species CANNOT be.
## A generator bug that turned a Seam Grazer into a tall lump should fail a
## test, not merely look wrong to somebody who happens to be watching.
static func violates_identity(kind: int, m: Dictionary) -> String:
	var r: Dictionary = SPECIES[kind]
	match kind:
		Kind.SEAM_GRAZER:
			if float(m.tall) >= float(m.wide) * 0.45:
				return "a seam grazer must keep a low silhouette"
			if float(m.cilia) < 0.4:
				return "a seam grazer must carry a ventral sensory comb"
			if int(m.limbs) > 0:
				return "a seam grazer crawls; it has no legs"
		Kind.CRYSTAL_LISTENER:
			if float(m.crystal) < 0.5:
				return "a crystal listener is mostly mineral resonator"
			if float(m.speed) > 0.06:
				return "a crystal listener holds still to listen"
			if int(m.feelers) < 5:
				return "a crystal listener needs its cilia array"
		Kind.FOLD_CRAB:
			if int(m.limbs) < 6:
				return "a fold crab is a multi-limbed walker"
			if float(m.gold) < 0.35:
				return "a fold crab's joints are mineral cups"
			if float(m.tall) < float(m.wide) * 0.35:
				return "a fold crab stands off the surface on its legs"
	return ""
