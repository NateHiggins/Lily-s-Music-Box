class_name DreamMazeRoot
extends Node3D
## N6: the production dream world. From the committed transaction context it
## deterministically assembles the campaign slot's module chain (N2 catalog),
## spawns the dream body of the player with the real service lamp, and runs
## the Tenant as one invisible navigation body wearing the subject's
## shadows-only silhouette (N3 contract). Capture reaches DreamDirector's
## existing outcome seam; no failure state exists here.
##
## N4's boundary contract is unchanged: identity and revision arrive through
## configure_dream before this node enters the tree, and every (re)build
## starts at D00. A chase frame is never reconstructed.

const START_MODULE_ID := "D00_4B_THRESHOLD"
const PROFILES_PATH := "res://data/dream_profiles.json"

## Tests drive pursuit steps manually when false.
var autonomous := true

## N7. The slot's authored ceiling, read from the catalog, and the clock
## against it. A passage that cannot end is not a passage.
var run_cap_s := 0.0
var run_elapsed_s := 0.0
## One outcome per dream, and it closes the door behind itself. Without
## this, a hazard firing in the same frame as capture would call
## end_dream twice and the second call would be into a director whose
## phase has already moved on.
var _outcome_committed := false

var dream_context: Dictionary = {}
var start_marker: Marker3D
var plan: Dictionary = {}
var player: PlayerController
var pursuer: DreamPursuer
var hazards: DreamHazardField
## Kept so a harness can re-arm the field for a fresh trial without
## reloading the profile or rebuilding the world.
var profile_hazards: Dictionary = {}
## Accessibility text for the hazard tells. Present always, silent unless the
## player has turned the setting on.
var captions: DreamCaptionLayer
var maze_built := false

## One warm fixture beyond each connector; exactly one ever burns.
## See _build_practicals().
var _practicals: Array[OmniLight3D] = []
var _lit_practical := -1

## Head height for the practical, and how far past the doorway it stands. The
## setback is short on purpose: far enough to be a fixture in the next room
## rather than a lamp in the opening, near enough that the aperture frames it.
const PRACTICAL_Y := 1.95
const PRACTICAL_SETBACK_M := 1.5

## How hard the floor gives way. `PlayerController.stagger()` clamps its push
## to 4.2 m/s, so this is well inside what the body already accepts from every
## other stagger in the game — the runner is a stumble, not a launch.
const STUMBLE_PUSH_MPS := 2.6

## The conduit and the arc it throws. See _build_hazard_visuals().
var _arcs: Array[Dictionary] = []
## Every Klimt material in the world, so the lamp can be pushed into all of
## them each frame. See _collect_molten_materials().
var _molten_materials: Array[ShaderMaterial] = []
## Chest height: where a conduit's arc would find a body, and where the beam
## splash it reaches for actually lands.
const ARC_Y := 1.20
## Where the beam splash lands: the floor just in front of the conduit.
const SPLASH_Y := 0.16
## The riser runs the module's full clear height. Read from the catalog at
## build time in `_build_world`; this is the catalog's own default and only
## stands in if that lookup is ever absent.
const CLEAR_CEILING_M := 3.015
## How lit this world tells the beam mask it is. Not 1.0: the torch must stay
## the reason you can see, and the vignette is most of why it feels carried.
## Back to zero with the ambient gone: there is no longer a floor for the mask
## to crush, and the vignette at full strength is more of the dramatic falloff
## the owner asked for rather than less.
const DREAM_LIFT_FLOOR := 0.0

## THE GUTTERING LAMP. In the waking Orison the service lamp throws 7.5 m,
## because a maintenance man wants to see the end of a corridor. In the dream
## it is the only light there is, and a torch that reaches the far wall of a
## 19.30 m hall shows you the whole hall — which hands over the maze, kills the
## claustrophobia and makes the gold uniform instead of found.
##
## So it is pulled to a POOL. Range is the hard cut; attenuation is the shape,
## and above 1.0 it falls off faster than physical inverse-square, which is
## what makes the edge of the pool arrive quickly rather than fading out over
## metres. Narrower and hotter, so what it does find is brilliant.
const DREAM_LAMP_RANGE := 4.6
const DREAM_LAMP_ATTENUATION := 1.9
const DREAM_LAMP_ANGLE := 40.0
const DREAM_LAMP_ANGLE_ATTENUATION := 2.4
const DREAM_LAMP_ENERGY := 3.2

## Deliberately small: Compatibility turns every particle into a submission and
## this frame is submission-bound. See _build_motes().
const MOTE_COUNT := 110


func configure_dream(context: Dictionary) -> void:
	dream_context = context.duplicate(true)


func _ready() -> void:
	add_to_group("dream_world")
	start_marker = Marker3D.new()
	start_marker.name = START_MODULE_ID
	add_child(start_marker)
	_build_world()


func start_module_id() -> String:
	return START_MODULE_ID


func _build_world() -> void:
	var profile := _load_profile(str(dream_context.get("profile_id", "")))
	if profile.is_empty():
		push_warning("dream profile missing; boundary payload only")
		return
	var seed_hex := str(dream_context.get("seed_hex", ""))
	var slot := int(profile.get("campaign_slot", 1))
	var catalog := DreamMazeBuilder.load_catalog()
	plan = DreamMazeBuilder.assemble(catalog, seed_hex, slot)
	if not (plan.get("defects", ["unbuilt"]) as Array).is_empty():
		push_error("dream maze assembly defects: %s" % str(plan.defects))
		return
	_build_environment()
	var constants: Dictionary = catalog.get("constants", {})
	var clear_ceiling := float(constants.get("clear_ceiling_m", 3.015))
	# THE RUN CEILING IS AUTHORED AND HAS NEVER BEEN READ. The catalog
	# carries campaign_run_ceilings_s [28, 38, 50, 62, 76, 90] and no
	# GDScript has ever consumed it, so every dream so far could run
	# forever. Slot 1 is Mina's 28 seconds.
	var ceilings: Array = constants.get("campaign_run_ceilings_s", [])
	run_cap_s = float(ceilings[slot - 1]) if slot >= 1 			and slot <= ceilings.size() else 0.0
	# The allowlist must be read BEFORE the geometry, because the geometry
	# depends on it: only an armed void gets its mouth cut.
	profile_hazards = profile.get("hazards", {})
	DreamMazeBuilder.build_geometry(self, plan, clear_ceiling,
			profile_hazards.get("allow", []))
	maze_built = true

	var spawn: Array = plan.spawn_player
	start_marker.position = Vector3(spawn[0], 0.0, spawn[1])
	# The dream body: the same controller, the same service lamp, already
	# lit at the threshold. The waking body was freed with its world; no
	# transform crosses the boundary.
	player = PlayerController.new()
	player.position = start_marker.position
	add_child(player)
	player.set_lamp_enabled(true)
	# The dream has no LightRig, so nothing would otherwise tell the beam's
	# screen mask that this world is lit at all and it would crush the ambient
	# to a fifth outside the beam -- switching the lamp ON would darken the
	# frame. See PlayerController.set_world_lift_floor().
	player.set_world_lift_floor(DREAM_LIFT_FLOOR)
	_make_lamp_local()

	pursuer = DreamPursuer.new()
	add_child(pursuer)
	pursuer.setup(plan, profile.get("pursuit", {}), player, seed_hex)
	pursuer.captured.connect(_on_captured)

	# The hazards the CASE runs, not the ones the geometry offers. The
	# builder places every socket in the chain; the profile's allowlist
	# is what arms three of them for Mina.
	hazards = DreamHazardField.new()
	hazards.setup(plan, profile_hazards, player)
	hazards.hazard_contact.connect(_on_hazard_contact)
	captions = DreamCaptionLayer.new()
	captions.name = "DreamCaptionLayer"
	add_child(captions)
	captions.listen_to(hazards)

	# NO BLACK LEVEL. It existed to keep "the nearest floor silhouette" under
	# the superseded ruling; carrying a lamp that lights the floor around you
	# is precisely the dropoff the owner has now asked to remove. The function
	# is kept, unused, because the accessibility mode "High-contrast edges"
	# will want exactly this and nothing else in the build does it.
	_build_practicals()
	_build_hazard_visuals()
	_build_motes()
	_collect_molten_materials()


## The dream's own environment, because the world that owned one was freed.
##
## `building_root.gd` builds a WorldEnvironment for the WAKING Orison.
## `CampaignShell` frees that world outright when it swaps in this one, and
## `project.godot` sets no `default_environment` to fall back on — so until
## 2026-08-17 the production dream ran with no environment of any kind. No
## ambient, no tonemap. Lamp off was pure black; lamp on was a beam splash in
## a void.
##
## That contradicted a ruled requirement rather than merely looking poor.
## ORISON_MAZE_BRIEF §"THE LIGHT IS THE GAME": "The world remains readable
## enough to move with the light off: black level keeps the nearest floor
## silhouette ... 'Off' means navigation by sound and memory, not a black
## video file." It was a black video file, and
## `art/renders/dream_env_n7/before/02_hall_lamp_off.png` is what that looked
## like.
##
## It went unnoticed because the harness that photographed the dream built its
## own. `dream_pursuit_shot.gd` adds a WorldEnvironment plus OmniLight3Ds
## frankly named `RecedingOrientationControl` and
## `NearestFloorBlackLevelControl` before capturing, so N6's proof frames
## demonstrated navigable darkness in a scene no player enters.
##
## These are that harness's own environment numbers, adopted rather than
## re-invented. But the environment is only a third of what it was doing, and
## measuring that was the correction: ambient 0.18 of a near-navy on soot
## plaster is worth almost nothing on its own, and adding it alone left
## `02_hall_lamp_off` still black. The harness's readable darkness came mostly
## from its two OmniLight3D "controls", and those are what
## `_build_black_level()` and `_build_practicals()` below promote.
func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05070d")
	# Ambient is the black level. It is what keeps the nearest floor a
	# silhouette rather than nothing, and it is deliberately COOL so the
	# carried tungsten lamp reads warm against it — the brief's soot black
	# and warm dirty service-lamp light.
	# NO AMBIENT. Owner ruling 2026-08-17, reversing the "dark, not pitch black"
	# call made earlier the same day: "i want a dramatic dark dropoff and
	# pitch blackness beyond".
	#
	# That earlier ruling was made against a flat graybox, where the only
	# alternative to ambient was a black screen. It does not survive the Klimt
	# pass: gold leaf under a tight lamp is brilliant, so the contrast is
	# carried by the SURFACE now and an ambient floor only greys the void and
	# flattens the drop. Pitch black beyond the pool is the point — it is what
	# makes the pool worth anything.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	# SKY CONTRIBUTION DEFAULTS TO 1.0, AND THAT IS WHY THE AMBIENT DID
	# NOTHING. With `AMBIENT_SOURCE_COLOR` Godot still blends the ambient
	# between `ambient_light_color` and the SKY by this ratio, and at the
	# default the colour is worth nothing at all — against a `BG_COLOR`
	# background there is no sky to take it from either, so the term
	# evaluated to zero.
	#
	# That is why raising `ambient_light_energy` appeared to do nothing when
	# this landed, and why the harness's own environment had never lifted the
	# black level in the first place. Both were setting a colour the renderer
	# was weighting at zero. Measured: the dream hall with the lamp off ran at
	# 95.3% of pixels at or below 3/255 with this line absent, which is pitch
	# black by any reading.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 3.2
	# GLOW IS THE HALF OF THIS THAT SELLS THE GOLD. Leaf is metal, so the only
	# thing it does is throw the lamp back — and a specular highlight with no
	# bloom around it reads as a white pixel rather than as light off leaf.
	# The threshold sits above the ambient floor so the DARK stays dark: only
	# what the beam actually wakes is allowed to bloom.
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.05
	environment.glow_bloom = 0.22
	environment.glow_hdr_threshold = 0.90
	environment.glow_hdr_scale = 2.6
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	# The near-field bloom is the shimmer; the wide one is the halo the whole
	# corridor gets when the beam finds a rich patch of ornament.
	environment.set("glow_levels/2", 0.9)
	environment.set("glow_levels/3", 0.7)
	environment.set("glow_levels/5", 0.45)
	# One restrained push, not a grade: the gold gains a little, the black
	# ground does not shift hue.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.18
	environment.adjustment_contrast = 1.06
	var world_environment := WorldEnvironment.new()
	world_environment.name = "DreamEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


## THE TRUNK YOU CAN SEE, AND THE ARC THAT REACHES FOR YOUR BEAM.
##
## Gate C's fairness contract wants three things from every hazard: a sound
## that precedes the danger, ONE VISIBLE CONFIRMATION UNDER THE SERVICE LAMP,
## and one reconstructable cause. The trunk had the first — `TRUNK HISS`,
## unconditional, measured — and neither of the others. It was an invisible
## point in an empty corridor that killed you if your lamp happened to be on.
## Its mechanism was proved (`DreamHazardTest` block D) and its *reason* was
## not visible to anybody.
##
## So the socket gets a conduit, which is the reconstructable cause — a real
## riser standing floor to ceiling where the catalog put the hazard — and the
## conduit gets an arc, which is the confirmation. §"EIGHT FIXED HAZARDS"
## words it exactly: "arc reaches toward the lit beam splash".
##
## WHEN IT REACHES IS DERIVED, NOT CHOSEN. The arc lives inside the socket's
## own authored `tell_radius`, so the sound and the sight describe the same
## neighbourhood and the pairing is legible: you hear the hiss whatever you
## do, and if your lamp is on you watch the arc reach. Turn the lamp off and
## it lets go. That is §"THE LIGHT IS THE GAME" made visible instead of
## merely lethal — light can activate the danger it reveals, and now you can
## see it happening rather than reconstructing it afterwards.
##
## It RAMPS with proximity and never strobes. The brief bans flashing outright
## and makes it non-negotiable, so the arc grows smoothly out of the conduit
## and brightens as it closes; nothing here blinks.
func _build_hazard_visuals() -> void:
	for hazard in hazards.hazards:
		if hazard.condition != "lamp_on":
			continue
		var conduit := MeshInstance3D.new()
		conduit.name = "DreamConduit_%s" % hazard.id
		var riser := BoxMesh.new()
		riser.size = Vector3(0.16, CLEAR_CEILING_M, 0.16)
		conduit.mesh = riser
		conduit.material_override = _dull_metal()
		conduit.position = Vector3(hazard.position.x,
				CLEAR_CEILING_M * 0.5, hazard.position.z)
		add_child(conduit)

		var arc := MeshInstance3D.new()
		arc.name = "DreamArc_%s" % hazard.id
		var spark := BoxMesh.new()
		# Built one metre long down -Z and scaled per frame, so the mesh is
		# authored once and only the transform moves.
		spark.size = Vector3(0.05, 0.05, 1.0)
		arc.mesh = spark
		arc.material_override = _arc_material()
		arc.visible = false
		add_child(arc)

		var glow := OmniLight3D.new()
		glow.name = "DreamArcGlow_%s" % hazard.id
		glow.light_color = Color("9fd4ff")
		glow.omni_range = 3.0
		glow.shadow_enabled = false
		glow.visible = false
		add_child(glow)

		_arcs.append({"hazard": hazard, "arc": arc, "glow": glow})


func _dull_metal() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("1b1d22")
	material.roughness = 0.62
	material.metallic = 0.55
	return material


func _arc_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("cfe8ff")
	material.emission_enabled = true
	material.emission = Color("9fd4ff")
	material.emission_energy_multiplier = 1.5
	# The arc is not a surface anyone should be able to read a shadow off.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Reach for the beam, or let go. Runs every physics frame beside the
## practical, and reads the same lamp the hazard's own condition reads so the
## picture can never disagree with the rule.
func _update_hazard_visuals() -> void:
	if _arcs.is_empty() or player == null:
		return
	var lamp_on: bool = player.has_method("lamp_is_enabled") \
			and bool(player.call("lamp_is_enabled"))
	for entry in _arcs:
		var hazard: DreamHazard = entry.hazard
		var arc: MeshInstance3D = entry.arc
		var glow: OmniLight3D = entry.glow
		var root_point := Vector3(hazard.position.x, ARC_Y, hazard.position.z)
		var to_player := _flat(player.global_position) - _flat(root_point)
		var distance := to_player.length()
		# Dead once it has fired: an arc still groping at a corpse is a
		# different scene than the one this is for.
		var live: bool = lamp_on and not hazard.contacted \
				and distance <= hazard.tell_radius and distance > 0.01
		if not live:
			arc.visible = false
			glow.visible = false
			continue
		# Nearer means longer and brighter, smoothly. At the tell edge it is a
		# twitch at the conduit; at the clearance it has crossed to the body.
		var closeness: float = clampf(
				1.0 - (distance - hazard.clearance_radius)
				/ maxf(0.01, hazard.tell_radius - hazard.clearance_radius),
				0.0, 1.0)
		# IT REACHES FOR THE SPLASH, NOT FOR THE EYE, and the difference is
		# the whole frame. Aiming the arc at the player points it straight
		# down the camera axis, where a 0.05 m emissive rod is seen end-on as
		# a blown-out blob that says nothing (the first attempt, and the first
		# render killed it). §"EIGHT FIXED HAZARDS" says "arc reaches toward
		# the lit beam splash" — the splash is on the floor and the wall in
		# front of the conduit, so the arc runs DOWN and OUT to meet it and is
		# read in profile, which is what an arc looks like.
		var reach: float = maxf(0.12, distance * closeness)
		var landing := root_point + to_player.normalized() * reach
		landing.y = SPLASH_Y
		arc.visible = true
		arc.global_position = (root_point + landing) * 0.5
		arc.look_at(landing)
		arc.scale = Vector3(1.0, 1.0, root_point.distance_to(landing))
		glow.visible = true
		glow.global_position = landing
		glow.light_energy = 0.18 + 0.55 * closeness


## What a broken board actually DOES.
##
## `DreamHazardField.advance_fixed()` returns an outcome only when the run
## should end, but it emits `hazard_contact` for every impact — its comment
## says "DreamMazeRoot decides what to do with it", and this is that decision.
## A hazard carrying `outcome ""` is not a hazard that does nothing; it is one
## whose consequence is not death.
##
## Mina's hollow runner is the only one so far. §"MINA'S FIRST RUN" gives it
## one lesson — *sprint is not always the answer* — and the hazard table gives
## it one behaviour: "running breaks it; walking crosses". Its profile already
## carried `condition: running` and `break_speed_mps: 3.8`, so the board
## already knew when to break. Nothing had ever said what breaking did.
##
## It does two things, both with mechanisms that already existed, because the
## brief bars the dream from adding bespoke controls:
##
##   1. `PlayerController.stagger()` — the boards give way, the sprint ends.
##      That is the whole lesson, paid immediately and physically.
##   2. The Tenant is handed the position. A board breaking under a running
##      body is the loudest thing in the passage, and `DreamPursuer` already
##      navigates to `last_known_position`; the pursuit contract has it moving
##      to the last known point and listening for movement. So the real cost
##      of sprinting is not the stumble, it is that the thing chasing you now
##      knows exactly where the noise came from.
##
## The run does not end, no outcome is committed, and the latch is untouched —
## a stagger cannot race a capture.
##
## LATER HAZARDS WILL NOT ALL WANT THIS. The eight-hazard table has two more
## non-terminal entries with different consequences: the counterweight passage
## is "impact/stagger, then pursuit", which is this; the fire-door return is
## "route closes; pursuit continues", which is not. When either lands it needs
## its own branch rather than inheriting the runner's.
func _on_hazard_contact(hazard_id: String, outcome: String) -> void:
	if outcome != DreamHazard.NONE:
		return
	if player == null or not is_instance_valid(player):
		return
	# Away from the board, along the way the body was already travelling, so
	# the stumble reads as the floor giving way underneath rather than as a
	# push from somewhere.
	var away := _flat(player.global_position - _hazard_position(hazard_id))
	if away.length() < 0.05:
		away = -_flat(player.global_transform.basis.z)
	player.stagger(away.normalized() * STUMBLE_PUSH_MPS)
	if pursuer != null and is_instance_valid(pursuer):
		pursuer.last_known_position = _flat(player.global_position)


func _hazard_position(hazard_id: String) -> Vector3:
	for hazard in hazards.hazards:
		if hazard.id == hazard_id:
			return hazard.position
	return player.global_position


## THE GOLD HAS TO KNOW WHERE THE LAMP IS.
##
## A fragment shader cannot see a light's position, and the molten term is
## entirely a function of it: gold only liquefies where the beam lands. There
## are three ways to tell it and this takes the plainest — cache every
## ShaderMaterial the builder made and push the lamp's world position and
## output into each one per frame.
##
## Registered global shader parameters would be tidier, but they live in
## project.godot and would be a project-wide edit for a dream-only effect. The
## cost here is a handful of materials times two setters, which is nothing
## against a frame this project has already proved is submission-bound.
func _collect_molten_materials() -> void:
	_molten_materials.clear()
	for node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry == null:
			continue
		var material := geometry.material_override as ShaderMaterial
		if material != null and not _molten_materials.has(material):
			_molten_materials.append(material)


func _update_molten() -> void:
	if _molten_materials.is_empty() or player == null \
			or player.flashlight == null:
		return
	# The lamp's own node, not the body: the light is carried in the off hand
	# and the pool is centred on the fixture rather than on the player's feet.
	var at := player.flashlight.global_position
	# Energy carries the warm-up and the pop straight into the metal, so the
	# gold runs as the filament comes up and freezes as it dies. Nothing extra
	# is needed to animate that -- it falls out of the lamp already being
	# animated.
	var energy: float = player.flashlight.light_energy \
			if player.lamp_is_enabled() or player.flashlight.visible else 0.0
	for material in _molten_materials:
		material.set_shader_parameter("lamp_pos", at)
		material.set_shader_parameter("lamp_energy", energy)


## GOLD IN THE AIR, VISIBLE ONLY WHERE THE LAMP FINDS IT.
##
## The single cheapest thing that turns a lit pool into a lit VOLUME: without
## motes the beam is a bright patch on a wall, and with them it is a shaft of
## light you are standing inside. It is also the same idea as the walls —
## suspended leaf that does nothing until the lamp reaches it.
##
## SHADED, and that is the whole trick. The owner's ruling disabled ambient
## entirely (see _build_environment), so a shaded particle outside the beam
## receives no light at all and is simply black — "only visible in the beam"
## costs nothing and needs no cone test in a shader. Inside the cone the spot
## lights it like any other surface.
##
## CPUParticles3D, not GPU, and the reason is measured rather than taste:
## weather_fx.gd's header records that Compatibility "expands each particle
## into a costly submission", the rain proposal records that moving the same
## effect to GPUParticles3D "did not change the renderer's economics", and
## TASKS.md P8b specifically exempts particle counts from the project's
## otherwise-standing "raise every limit, the GPU is free" direction. So the
## count is deliberately small and the quads are tiny.
func _build_motes() -> void:
	if player == null:
		return
	var motes := CPUParticles3D.new()
	motes.name = "DreamMotes"
	motes.amount = MOTE_COUNT
	motes.lifetime = 9.0
	motes.preprocess = 6.0
	motes.randomness = 1.0
	motes.local_coords = false
	# A box around the body rather than a point: dust is already in the room,
	# it is not being emitted by the player.
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(3.2, 1.7, 3.2)
	motes.position = Vector3(0.0, 1.2, 0.0)
	# Barely moving. Real dust in still air falls slower than it drifts, and
	# anything faster than this reads immediately as snow.
	motes.gravity = Vector3(0.0, -0.012, 0.0)
	motes.initial_velocity_min = 0.01
	motes.initial_velocity_max = 0.055
	motes.damping_min = 0.02
	motes.damping_max = 0.08
	motes.scale_amount_min = 0.006
	motes.scale_amount_max = 0.018
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	motes.mesh = quad
	var mat := StandardMaterial3D.new()
	# Shaded: the lamp is what makes them exist. See the note above.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(1.0, 0.86, 0.58)
	mat.metallic = 0.0
	mat.roughness = 0.55
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	# A mote is a speck of leaf, not a caster. Sixteen shadow slots are not
	# being spent on dust.
	mat.disable_receive_shadows = true
	motes.material_override = mat
	motes.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	player.add_child(motes)


## Pull the carried lamp down to a pool. See the constants above.
##
## The lamp keeps its own warm-up and pop: this changes the reach, never the
## switch, so N3's measured light contract is untouched.
func _make_lamp_local() -> void:
	if player == null or player.flashlight == null:
		return
	player.flashlight.spot_range = DREAM_LAMP_RANGE
	player.flashlight.spot_attenuation = DREAM_LAMP_ATTENUATION
	player.flashlight.spot_angle = DREAM_LAMP_ANGLE
	player.flashlight.spot_angle_attenuation = DREAM_LAMP_ANGLE_ATTENUATION
	player.flashlight.light_energy = DREAM_LAMP_ENERGY
	# The warm-up settles back to THIS, not to the waking lamp's output.
	player.set_lamp_base_energy(DREAM_LAMP_ENERGY)


## THE BLACK LEVEL. "The world remains readable enough to move with the light
## off: black level keeps the nearest floor silhouette" — and "nearest" is the
## whole specification. A uniform ambient bright enough to show the floor at
## your feet also shows the far end of a 19.30 m hall, which would hand the
## player the maze's extent for free and flatten exactly the claustrophobia
## the passage is for.
##
## So it is a lamp, not an ambient: dim, cool, shadowless, carried at ankle
## height, falling off within the room you are standing in. Cool because the
## service lamp is the only warm source the player owns and the two must never
## be confused — this one cannot be switched, cannot be aimed, and reveals
## nothing but where the floor stops.
##
## It does NOT make darkness safe, and cannot: `DreamPursuer` acquires on
## `lamp_is_enabled()`, the player's own service lamp, so nothing here feeds
## acquisition. N3's measured contract is untouched, which `DreamPursuitTest`
## re-proves at 39/39.
func _build_black_level() -> void:
	var floor_level := OmniLight3D.new()
	floor_level.name = "DreamBlackLevel"
	floor_level.position = Vector3(0.0, 0.28, 0.0)
	floor_level.light_color = Color("35415c")
	# Tuned against the frame, not inherited. The harness's control sat at
	# 0.48 over a 9.0 m range, but it was one of three sources lighting a
	# staged wall 1.8 m away; carried by the body against a 0.15-0.20 albedo
	# graybox it produced a frame indistinguishable from the black one it was
	# meant to replace. Brighter and SHORTER: the range is what keeps this
	# honest, because a 9 m falloff lights the far end of a 19.30 m hall and
	# hands over the room the player is supposed to be listening to.
	floor_level.light_energy = 1.6
	floor_level.omni_range = 4.5
	# A scarce shadow slot spent on a light whose entire job is to stop the
	# floor being nothing would be spent to hide the floor again.
	floor_level.shadow_enabled = false
	# Parented to the body, so it is carried rather than placed. The player
	# never outruns their own black level.
	player.add_child(floor_level)


## THE RECEDING PRACTICAL. "A warm 4B practical appears one connector ahead. It
## never slides away in view; the lit fixture changes only while a wall or
## closing door occludes it."
##
## Read carefully that is not one moving light. A light that slides ahead of
## the player is the thing the sentence forbids. It is a series of FIXTURES,
## one per module, of which exactly one is ever burning — and the handover from
## one to the next may only happen while the player cannot see it happen.
##
## So: build one at every module in the chain, light the one a module ahead,
## and defer every handover until the burning fixture is actually occluded.
## `_update_practical()` does the deferring, and will hold a stale fixture lit
## indefinitely rather than switch in view, which is the correct failure.
func _build_practicals() -> void:
	# ONE CONNECTOR AHEAD, and the position comes from the CONNECTOR.
	#
	# The first attempt put each fixture at its module's centre, which is this
	# project's most-repeated defect written fresh: a position taken from
	# something convenient instead of from the surface it has to meet. D01 is
	# 19.30 m long, so its centre stood 11.12 m from the doorway the player
	# looks through — beyond the fixture's own 9.5 m range. It lit correctly
	# and could not be seen, which is the worst way for a light to be wrong.
	#
	# `plan.doors[i]` is the aperture between module i and module i+1, indexed
	# by chain position. The fixture belongs just through it: aperture centre,
	# stepped into the room beyond, so it reads from the near side as a warm
	# room you have not reached.
	for i in plan.doors.size():
		var aperture: Array = plan.doors[i].aperture
		var mouth := Vector3(
				(float(aperture[0]) + float(aperture[2])) * 0.5, PRACTICAL_Y,
				(float(aperture[1]) + float(aperture[3])) * 0.5)
		var beyond: Array = plan.modules[i + 1].rect
		var inward := Vector3(
				(float(beyond[0]) + float(beyond[2])) * 0.5, PRACTICAL_Y,
				(float(beyond[1]) + float(beyond[3])) * 0.5) - mouth
		inward.y = 0.0
		if inward.length() > 0.01:
			inward = inward.normalized()
		var practical := OmniLight3D.new()
		practical.name = "DreamPractical_%02d_%s" % [i, str(plan.doors[i].to)]
		practical.position = mouth + inward * PRACTICAL_SETBACK_M
		practical.light_color = Color("ffb867")
		practical.light_energy = 0.72
		practical.omni_range = 9.5
		practical.shadow_enabled = false
		practical.visible = false
		add_child(practical)
		_practicals.append(practical)


## Which module the body is standing in, or -1 outside them all.
func _module_index_at(p: Vector3) -> int:
	for i in plan.modules.size():
		var rect: Array = plan.modules[i].rect
		if p.x >= float(rect[0]) and p.x <= float(rect[2]) \
				and p.z >= float(rect[1]) and p.z <= float(rect[3]):
			return i
	return -1


## Nothing may be seen to change. A handover waits for a wall.
func _update_practical() -> void:
	if _practicals.is_empty() or player == null:
		return
	var here := _module_index_at(player.global_position)
	if here < 0:
		return
	# Practical `i` stands beyond door `i`, the connector out of module `i`.
	# So the body's own module index IS the fixture it should be walking
	# toward. The last module has no door ahead and keeps the previous one
	# lit, which is the ruled ending: the guiding light was never a reachable
	# exit, and at the riser end it burns beyond a sealed grille.
	var wanted: int = mini(here, _practicals.size() - 1)
	if wanted == _lit_practical:
		return
	# The first one is free: nothing is burning yet, so nothing can be seen to
	# stop burning.
	if _lit_practical >= 0 and _practical_is_visible(_lit_practical):
		return
	if _lit_practical >= 0:
		_practicals[_lit_practical].visible = false
	_practicals[wanted].visible = true
	_lit_practical = wanted


## Line of sight from the eye to the fixture, against the maze's real opaque
## collision — the same bodies that block the Tenant's acquisition.
func _practical_is_visible(index: int) -> bool:
	var camera: Camera3D = player.camera
	if camera == null:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			camera.global_position, _practicals[index].global_position)
	query.exclude = [player.get_rid()]
	# Empty result means nothing stood in the way: the fixture is in view and
	# the handover has to wait.
	return space.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if maze_built:
		_update_practical()
		_update_hazard_visuals()
		_update_molten()
	if not autonomous or _outcome_committed:
		return
	if pursuer != null and not pursuer.is_captured:
		pursuer.advance_fixed(delta)
	if hazards != null:
		var hit := hazards.advance_fixed(delta)
		if hit != DreamHazard.NONE:
			_commit_outcome(hit)
			return
	if run_cap_s <= 0.0:
		return
	run_elapsed_s += delta
	if run_elapsed_s >= run_cap_s:
		_cap_fold()


## THE CAP CLOSES THE RUN BY TOPOLOGY, NOT BY CHEATING. When the slot's
## ceiling expires the Tenant is re-placed onto the chain waypoint AHEAD
## of the player, so the shorter converging route finishes the passage --
## the brief's own words: "the topology closes the distance; rubber-
## banding does not". It does NOT teleport the Tenant behind the camera,
## invent geometry, or touch the seeded pursuit numbers: reset_run zeroes
## the clock and preserves run_parameters() exactly.
##
## This is deliberately NOT the D09 terminal fold, which belongs to the
## final campaign slot and to a ring Mina's chain does not reach.
func _cap_fold() -> void:
	if pursuer == null or player == null or _outcome_committed:
		return
	var here := DreamMazeBuilder.nav_module_at(
			plan, player.position.x, player.position.z)
	var route: Array = DreamMazeBuilder.chain_route(
			plan, here, "D05_SERVICE_RISER") if here != "" else []
	if route.is_empty():
		# Already in the terminal module: close from its own far end
		# rather than from nowhere.
		var far: Array = plan.spawn_pursuer
		pursuer.reset_run(Vector3(far[0], 0.0, far[1]))
		return
	pursuer.reset_run(_flat(route[0]))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Every ending goes through one door. Capture, fall and contact are all
## dream outcomes and none of them is a failure state; the committed
## transaction owner decides what follows and this world only reports it.
func _commit_outcome(outcome: String) -> bool:
	if _outcome_committed:
		return false
	var shell := get_tree().get_first_node_in_group("campaign_shell")
	if shell is CampaignShell and (shell as CampaignShell).is_ancestor_of(self):
		if (shell as CampaignShell).dream_director.end_dream(outcome):
			_outcome_committed = true
			# Nothing may step into the frame between the durable commit
			# and CampaignShell's deferred free of this world.
			autonomous = false
			return true
		return false
	push_warning("%s with no campaign shell; outcome not committed" % outcome)
	return false


func _on_captured() -> void:
	_commit_outcome("capture")


func _load_profile(profile_id: String) -> Dictionary:
	if profile_id.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PROFILES_PATH))
	if parsed is not Dictionary:
		return {}
	var profiles: Dictionary = (parsed as Dictionary).get("profiles", {})
	var profile: Variant = profiles.get(profile_id, {})
	return profile if profile is Dictionary else {}
