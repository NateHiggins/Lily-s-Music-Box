class_name DreamCritterSpecies
extends RefCounted
## AUTHORED CRITTER SPECIES (ecology architecture §14, §15, §16, §24).
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

enum Kind {
	SEAM_GRAZER, CRYSTAL_LISTENER, FOLD_CRAB, TARDIGRADE,
	STENTOR, LACRYMARIA, VORTICELLA, EUPLOTES, SPIROSTOMUM, HELIOZOAN,
	EUGLENA, VOLVOX, NOCTILUCA, BACILLARIA, SALPINGOECA, MESODINIUM,
}

const NAMES := [
	"seam_grazer", "crystal_listener", "fold_crab", "tardigrade",
	"stentor", "lacrymaria", "vorticella", "euplotes", "spirostomum",
	"heliozoan", "euglena", "volvox", "noctiluca", "bacillaria",
	"salpingoeca", "mesodinium",
]

## Every plan is authored around a source-observed anatomical mechanism. The
## first four are the original Dream fauna; the next twelve translate living
## microscopy into room-scale alien species without changing ecology authority.
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
		"micro_ribbing": [0.34, 0.62],
		"micro_pores": [0.72, 1.00],
		"internal_density": [0.18, 0.38],
		"optical_anisotropy": [0.18, 0.42],
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
		"micro_ribbing": [0.68, 0.96],
		"micro_pores": [0.10, 0.28],
		"internal_density": [0.62, 0.88],
		"optical_anisotropy": [0.78, 1.00],
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
		"micro_ribbing": [0.78, 1.00],
		"micro_pores": [0.16, 0.40],
		"internal_density": [0.48, 0.72],
		"optical_anisotropy": [0.38, 0.66],
		# §24 — it shortens one leg without moving either end of it.
		"law": "leg_shortens_without_moving_its_ends",
	},
	Kind.TARDIGRADE: {
		"thesis": "This cat-sized water bear carries a microscope's depth into "
				+ "the room: folded cuticle, eight hydrostatic lobopods, paired "
				+ "stylets, a suction pharynx and a storage-rich gut remain visible "
				+ "through one living body.",
		"plan": "cat_sized_tardigrade",
		# A house-cat body volume, but retaining eutardigrade proportions. This
		# is knowingly fantastic scale rather than a claim about allometry.
		"len_m": [0.55, 0.72],
		"wide_m": [0.26, 0.38],
		"tall_m": [0.24, 0.36],
		"limbs": [8, 8],
		# Six terminal papillae/lamellae around the mouth cone.
		"feelers": [6, 6],
		"rare_feelers": 8,
		"gold": [0.05, 0.14],
		"crystal": [0.26, 0.48],
		"cilia": [0.12, 0.30],
		"speed": [0.10, 0.19],
		"social": "deliberate",
		# Cuticular annuli/pseudopores, storage-cell density and oriented muscle
		# fields derive from the research checkpoint, not arbitrary noise.
		"micro_ribbing": [0.74, 1.00],
		"micro_pores": [0.56, 0.92],
		"internal_density": [0.72, 0.96],
		"optical_anisotropy": [0.58, 0.88],
		# A tun contracts the silhouette while the optical path retains more
		# depth than the outside can contain.
		"law": "tun_compacts_without_losing_optical_depth",
	},
	Kind.STENTOR: {
		"thesis": "A contractile trumpet whose oral spiral gathers the room and "
				+ "whose subcortical bands remember repeated disturbance.",
		"plan": "contractile_trumpet",
		"len_m": [0.24, 0.42], "wide_m": [0.12, 0.17], "tall_m": [0.24, 0.42],
		"limbs": [0, 0], "feelers": [10, 12], "rare_feelers": 12,
		"gold": [0.03, 0.10], "crystal": [0.20, 0.38], "cilia": [0.82, 1.00],
		"speed": [0.015, 0.045], "social": "anchored",
		"micro_ribbing": [0.78, 1.00], "micro_pores": [0.28, 0.52],
		"internal_density": [0.46, 0.70], "optical_anisotropy": [0.62, 0.88],
		"law": "trumpet_habituates_to_repeated_contraction",
	},
	Kind.LACRYMARIA: {
		"thesis": "An anchored teardrop hunts with a helical neck longer than "
				+ "the body should be able to contain.",
		"plan": "telescoping_hunter",
		"len_m": [0.14, 0.22], "wide_m": [0.09, 0.14], "tall_m": [0.08, 0.13],
		"limbs": [0, 0], "feelers": [1, 1], "rare_feelers": 1,
		"gold": [0.02, 0.08], "crystal": [0.18, 0.34], "cilia": [0.58, 0.82],
		"speed": [0.01, 0.035], "social": "anchored_hunter",
		"micro_ribbing": [0.56, 0.84], "micro_pores": [0.34, 0.60],
		"internal_density": [0.42, 0.68], "optical_anisotropy": [0.70, 0.98],
		"law": "neck_stochastically_samples_beyond_body_reach",
	},
	Kind.VORTICELLA: {
		"thesis": "A bell drinks through its oral vortex and a calcium spring "
				+ "coils the entire animal toward its holdfast.",
		"plan": "bell_on_spasmoneme",
		"len_m": [0.18, 0.28], "wide_m": [0.12, 0.19], "tall_m": [0.20, 0.34],
		"limbs": [1, 1], "feelers": [10, 12], "rare_feelers": 12,
		"gold": [0.02, 0.09], "crystal": [0.24, 0.42], "cilia": [0.84, 1.00],
		"speed": [0.0, 0.012], "social": "sessile",
		"micro_ribbing": [0.48, 0.72], "micro_pores": [0.26, 0.48],
		"internal_density": [0.50, 0.76], "optical_anisotropy": [0.66, 0.94],
		"law": "stalk_coils_as_one_calcium_spring",
	},
	Kind.EUPLOTES: {
		"thesis": "An armored single cell computes a gait through linked "
				+ "cirral bundles and walks on its ventral face.",
		"plan": "cirral_walker",
		"len_m": [0.18, 0.28], "wide_m": [0.12, 0.20], "tall_m": [0.035, 0.060],
		"limbs": [8, 8], "feelers": [3, 5], "rare_feelers": 6,
		"gold": [0.08, 0.20], "crystal": [0.30, 0.54], "cilia": [0.72, 0.96],
		"speed": [0.08, 0.18], "social": "walking",
		"micro_ribbing": [0.72, 0.98], "micro_pores": [0.42, 0.72],
		"internal_density": [0.54, 0.78], "optical_anisotropy": [0.58, 0.86],
		"law": "fourteen_cirri_step_through_finite_gait_states",
	},
	Kind.SPIROSTOMUM: {
		"thesis": "A giant spindle carries a calcium myoneme fishnet that "
				+ "shortens the entire cell faster than muscle.",
		"plan": "myoneme_spindle",
		"len_m": [0.40, 0.65], "wide_m": [0.075, 0.12], "tall_m": [0.07, 0.11],
		"limbs": [0, 0], "feelers": [10, 12], "rare_feelers": 12,
		"gold": [0.02, 0.07], "crystal": [0.20, 0.38], "cilia": [0.78, 1.00],
		"speed": [0.04, 0.10], "social": "trigger_wave",
		"micro_ribbing": [0.82, 1.00], "micro_pores": [0.30, 0.52],
		"internal_density": [0.70, 0.94], "optical_anisotropy": [0.70, 0.98],
		"law": "contraction_wave_twists_a_cortical_fishnet",
	},
	Kind.HELIOZOAN: {
		"thesis": "A vacuolate sun catches the world on microtubule rays and "
				+ "reels one captured density inward.",
		"plan": "axopod_sun",
		"len_m": [0.16, 0.25], "wide_m": [0.16, 0.25], "tall_m": [0.15, 0.24],
		"limbs": [0, 0], "feelers": [12, 12], "rare_feelers": 12,
		"gold": [0.03, 0.10], "crystal": [0.42, 0.68], "cilia": [0.05, 0.16],
		"speed": [0.006, 0.025], "social": "passive_hunter",
		"micro_ribbing": [0.24, 0.46], "micro_pores": [0.70, 0.98],
		"internal_density": [0.48, 0.74], "optical_anisotropy": [0.82, 1.00],
		"law": "one_axopod_collapses_and_transports_its_capture",
	},
	Kind.EUGLENA: {
		"thesis": "A spiral pellicle deforms around chloroplast helices while "
				+ "an eyespot compares the light crossing a rotating body.",
		"plan": "metabolic_flagellate",
		"len_m": [0.24, 0.38], "wide_m": [0.08, 0.14], "tall_m": [0.08, 0.13],
		"limbs": [0, 0], "feelers": [1, 1], "rare_feelers": 1,
		"gold": [0.03, 0.11], "crystal": [0.24, 0.46], "cilia": [0.44, 0.68],
		"speed": [0.10, 0.22], "social": "phototactic",
		"micro_ribbing": [0.76, 1.00], "micro_pores": [0.18, 0.38],
		"internal_density": [0.58, 0.84], "optical_anisotropy": [0.72, 0.98],
		"law": "metaboly_turns_the_eyespot_through_light",
	},
	Kind.VOLVOX: {
		"thesis": "A rolling cellular sphere carries daughter spheres whose "
				+ "living sheet opens and turns itself inside out.",
		"plan": "inverting_colony",
		"len_m": [0.24, 0.36], "wide_m": [0.24, 0.36], "tall_m": [0.24, 0.36],
		"limbs": [0, 0], "feelers": [10, 12], "rare_feelers": 12,
		"gold": [0.02, 0.08], "crystal": [0.28, 0.50], "cilia": [0.66, 0.90],
		"speed": [0.035, 0.08], "social": "clonal_colony",
		"micro_ribbing": [0.44, 0.70], "micro_pores": [0.82, 1.00],
		"internal_density": [0.36, 0.60], "optical_anisotropy": [0.46, 0.72],
		"law": "daughter_sheet_opens_and_inverts_inside_parent",
	},
	Kind.NOCTILUCA: {
		"thesis": "A giant vacuolate sea-sparkle catches prey on one grooved "
				+ "tentacle and sends a mechanosensory flash around its inner rind.",
		"plan": "scintillon_vacuole",
		"len_m": [0.28, 0.42], "wide_m": [0.28, 0.42], "tall_m": [0.25, 0.38],
		"limbs": [0, 0], "feelers": [1, 1], "rare_feelers": 2,
		"gold": [0.06, 0.16], "crystal": [0.34, 0.58], "cilia": [0.08, 0.22],
		"speed": [0.012, 0.035], "social": "drifting_interceptor",
		"micro_ribbing": [0.22, 0.44], "micro_pores": [0.68, 0.94],
		"internal_density": [0.22, 0.44], "optical_anisotropy": [0.52, 0.82],
		"law": "scintillon_wave_orbits_one_giant_vacuole",
	},
	Kind.BACILLARIA: {
		"thesis": "A raft of silica cells extends by sliding every neighbor "
				+ "past the next while the colony remains joined.",
		"plan": "sliding_diatom_raft",
		"len_m": [0.35, 0.55], "wide_m": [0.18, 0.30], "tall_m": [0.040, 0.070],
		"limbs": [0, 0], "feelers": [0, 0], "rare_feelers": 0,
		"gold": [0.12, 0.28], "crystal": [0.78, 1.00], "cilia": [0.0, 0.0],
		"speed": [0.025, 0.065], "social": "obligate_colony",
		"micro_ribbing": [0.82, 1.00], "micro_pores": [0.78, 1.00],
		"internal_density": [0.42, 0.66], "optical_anisotropy": [0.88, 1.00],
		"law": "parallel_frustules_slide_without_separating",
	},
	Kind.SALPINGOECA: {
		"thesis": "A clonal rosette points every collar outward while fine "
				+ "bridges keep all daughters attached to one extracellular center.",
		"plan": "choanoflagellate_rosette",
		"len_m": [0.20, 0.32], "wide_m": [0.20, 0.32], "tall_m": [0.18, 0.30],
		"limbs": [0, 0], "feelers": [12, 12], "rare_feelers": 12,
		"gold": [0.02, 0.08], "crystal": [0.22, 0.42], "cilia": [0.78, 1.00],
		"speed": [0.015, 0.045], "social": "clonal_rosette",
		"micro_ribbing": [0.36, 0.60], "micro_pores": [0.54, 0.82],
		"internal_density": [0.50, 0.74], "optical_anisotropy": [0.62, 0.90],
		"law": "bacterial_signal_unfurls_a_clonal_rosette",
	},
	Kind.MESODINIUM: {
		"thesis": "A bilobed ciliate carries a working foreign nucleus and "
				+ "plastid archipelago stolen intact from its prey.",
		"plan": "kleptoplast_ciliate",
		"len_m": [0.18, 0.30], "wide_m": [0.16, 0.25], "tall_m": [0.15, 0.24],
		"limbs": [0, 0], "feelers": [10, 12], "rare_feelers": 12,
		"gold": [0.04, 0.12], "crystal": [0.32, 0.56], "cilia": [0.76, 1.00],
		"speed": [0.09, 0.20], "social": "kleptoplastidic",
		"micro_ribbing": [0.52, 0.78], "micro_pores": [0.42, 0.68],
		"internal_density": [0.76, 1.00], "optical_anisotropy": [0.70, 0.96],
		"law": "stolen_nucleus_drives_borrowed_plastid_archipelago",
	},
}


static func name_of(kind: int) -> String:
	return NAMES[kind]


static func all_kinds() -> Array:
	var result: Array = []
	for kind in NAMES.size():
		result.append(kind)
	return result


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
		Kind.TARDIGRADE:
			if int(m.limbs) != 8:
				return "a tardigrade must retain four pairs of lobopods"
			if int(m.feelers) < 6:
				return "a tardigrade needs its peribuccal sensory crown"
			if float(m.length) < 0.50 or float(m.length) > 0.75:
				return "the review tardigrade must remain cat sized"
			if float(m.tall) < float(m.wide) * 0.60:
				return "a tardigrade is a deep-bodied lobopodian, not a flat crawler"
		Kind.STENTOR:
			if int(m.feelers) < 10 or float(m.cilia) < 0.8:
				return "Stentor needs a dense oral membranelle crown"
			if float(m.length) < float(m.wide) * 1.35:
				return "Stentor must retain a tapering trumpet axis"
		Kind.LACRYMARIA:
			if int(m.feelers) != 1:
				return "Lacrymaria must have one continuous hunting neck"
			if int(m.limbs) != 0:
				return "Lacrymaria anchors its cell body rather than walking"
		Kind.VORTICELLA:
			if int(m.limbs) != 1 or int(m.feelers) < 10:
				return "Vorticella needs one spasmoneme stalk and an oral ciliary wreath"
		Kind.EUPLOTES:
			if int(m.limbs) != 8:
				return "Euplotes needs eight rendered bundles representing fourteen cirri"
			if float(m.tall) >= float(m.wide) * 0.5:
				return "Euplotes must remain a flattened ventral walker"
		Kind.SPIROSTOMUM:
			if float(m.length) < float(m.wide) * 3.0:
				return "Spirostomum must remain a giant contractile spindle"
			if float(m.cilia) < 0.75:
				return "Spirostomum needs its longitudinal ciliary rows"
		Kind.HELIOZOAN:
			if int(m.feelers) != 12 or float(m.crystal) < 0.4:
				return "the heliozoan needs a rigid radial axopod array"
		Kind.EUGLENA:
			if int(m.feelers) != 1 or float(m.length) < float(m.wide) * 1.7:
				return "Euglena needs one flagellum and a fusiform pellicle"
		Kind.VOLVOX:
			if absf(float(m.length) - float(m.wide)) > 0.14:
				return "Volvox must remain a rolling spheroidal colony"
			if int(m.feelers) < 10:
				return "Volvox needs an outward somatic flagellar field"
		Kind.NOCTILUCA:
			if int(m.feelers) < 1 or float(m.internal_density) > 0.5:
				return "Noctiluca needs one feeding tentacle and a dominant low-density vacuole"
		Kind.BACILLARIA:
			if int(m.limbs) != 0 or int(m.feelers) != 0:
				return "Bacillaria glides without cilia, flagella or legs"
			if float(m.crystal) < 0.75:
				return "Bacillaria must retain its silica frustule identity"
		Kind.SALPINGOECA:
			if int(m.feelers) != 12 or float(m.cilia) < 0.75:
				return "Salpingoeca needs an outward collar-and-flagellum rosette"
		Kind.MESODINIUM:
			if float(m.internal_density) < 0.75 or int(m.feelers) < 10:
				return "Mesodinium needs dense stolen organelles and equatorial ciliary girdles"
	return ""
