class_name DreamCritterGenerator
extends RefCounted
## Individuals inside a species' constraints (ecology architecture §17, §19).
##
##     "Two critters of the same species should feel related but not
##      duplicated."
##
## Everything here varies. None of it varies enough to cross a species
## boundary — `DreamCritterSpecies.violates_identity` is the executable
## statement of that, and the generator is checked against it rather than
## trusted.
##
## §17 also asks for RARE MORPHS: most Seam Grazers have four sensory palps,
## five percent have six, one percent an unusually large crystal organ. Very
## rare variation is what makes an individual memorable, so it is built in
## rather than left to chance.

const SpeciesScript := preload("res://scripts/dream/critters/dream_critter_species.gd")


static func generate(kind: int, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var r: Dictionary = SpeciesScript.rules(kind)
	var m := {
		"kind": kind,
		"seed": seed_v,
		"species": SpeciesScript.name_of(kind),
		"length": rng.randf_range(float(r.len_m[0]), float(r.len_m[1])),
		"wide": rng.randf_range(float(r.wide_m[0]), float(r.wide_m[1])),
		"tall": rng.randf_range(float(r.tall_m[0]), float(r.tall_m[1])),
		"limbs": rng.randi_range(int(r.limbs[0]), int(r.limbs[1])),
		"feelers": rng.randi_range(int(r.feelers[0]), int(r.feelers[1])),
		"gold": rng.randf_range(float(r.gold[0]), float(r.gold[1])),
		"crystal": rng.randf_range(float(r.crystal[0]), float(r.crystal[1])),
		"cilia": rng.randf_range(float(r.cilia[0]), float(r.cilia[1])),
		"speed": rng.randf_range(float(r.speed[0]), float(r.speed[1])),
		# §17's asymmetrical defects: a real animal is not mirrored.
		"asymmetry": rng.randf_range(0.0, 0.22),
		"limb_stagger": rng.randf_range(0.0, 0.35),
		"morph": "typical",
	}
	# §17 — rare morphs. Uncommon enough to be worth noticing.
	var roll := rng.randf()
	if roll < 0.05:
		m.feelers = int(r.rare_feelers)
		m.morph = "extra_feelers"
	if roll > 0.99:
		m.crystal = minf(1.0, float(m.crystal) * 1.9)
		m.morph = "great_crystal"
	# §19 — individual temperament on top of species defaults.
	m["confidence"] = rng.randf()
	m["curiosity"] = rng.randf()
	m["persistence"] = rng.randf()
	m["sociability"] = rng.randf()
	m["startle"] = rng.randf_range(0.1, 0.9)
	# §20 — movement varies by more than speed: which limb leads, how long it
	# pauses, whether it prefers to turn one way.
	m["lead_limb"] = rng.randi_range(0, maxi(1, int(m.limbs)) - 1)
	m["pause_bias"] = rng.randf()
	m["turn_bias"] = rng.randf_range(-1.0, 1.0)
	m["gait_phase"] = rng.randf_range(0.0, TAU)
	# §26 — MATERIAL VARIATION, SEEDED, INSIDE THE DREAM COLOUR LANGUAGE.
	#
	#     "Avoid arbitrary hue randomization. Everything remains within Dream
	#      color language."
	#
	# So none of these is a hue. They are balances between things the palette
	# already contains: how far toward magenta the plum sits, how proud the
	# crimson perfusion is, how coarse the skin, how wet, how much the
	# structure catches light. Two animals differ; neither becomes green.
	m["hue_bias"] = rng.randf()          # 0 aubergine .. 1 magenta
	m["perfusion"] = rng.randf_range(0.25, 1.0)
	m["skin_coarse"] = rng.randf_range(0.2, 1.0)
	m["pore_scale"] = rng.randf_range(0.6, 1.6)
	m["wetness"] = rng.randf_range(0.25, 0.95)
	m["iridescence"] = rng.randf_range(0.0, 0.7)
	m["alloy_tint"] = rng.randf()        # pale gold .. deep oxidised
	# §20 — MOVEMENT VARIATION BEYOND SPEED. Which limb leads is already
	# chosen; these are the rest of what makes two of a species walk unalike.
	m["gait_asymmetry"] = rng.randf_range(0.0, 0.35)
	m["stride_phase"] = rng.randf_range(0.0, TAU)
	m["body_bob"] = rng.randf_range(0.0, 0.5)
	m["sensor_tracking"] = rng.randf()   # how much it turns its sensors first
	m["law"] = String(r.law)
	m["thesis"] = String(r.thesis)
	m["plan"] = String(r.plan)
	m["social"] = String(r.social)
	return m


## How different two individuals are, for §38's acceptance test. Compares only
## the things a player could actually see: proportion, count and material
## balance — not temperament, which is invisible in a still frame.
static func visual_distance(a: Dictionary, b: Dictionary) -> float:
	var d := 0.0
	d += absf(float(a.length) - float(b.length)) / 0.3
	d += absf(float(a.wide) - float(b.wide)) / 0.2
	d += absf(float(a.tall) - float(b.tall)) / 0.12
	d += absf(float(a.limbs) - float(b.limbs)) / 8.0
	d += absf(float(a.feelers) - float(b.feelers)) / 12.0
	d += absf(float(a.gold) - float(b.gold))
	d += absf(float(a.crystal) - float(b.crystal))
	d += absf(float(a.cilia) - float(b.cilia))
	# Material balance is visible from across a room, so it counts -- but at
	# lower weight than anatomy, since §16 puts species identity first and two
	# grazers of different hue balance are still obviously two grazers.
	d += absf(float(a.hue_bias) - float(b.hue_bias)) * 0.4
	d += absf(float(a.perfusion) - float(b.perfusion)) * 0.3
	d += absf(float(a.wetness) - float(b.wetness)) * 0.25
	return d
