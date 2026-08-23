extends Node3D
## THE DREAM ECOLOGY STAGE (ecology architecture §34).
##
##     "Use an existing encroached apartment room with: wall margin, radiator,
##      sofa/furniture, corners/seams, player flashlight."
##
## The capture kept failing in real flats for reasons that had nothing to do
## with the ecology: a partition two metres out, a glass door, a boundary wall
## whose clear side is the landing. Those are facts about a building laid out
## for people to live in, not for a camera to work in.
##
## So this is a room built for the shot. It is deliberately NOT a replacement
## for testing in real flats — the ecology must survive those, and the other
## capture modes still run there. This one exists so the canonical review
## asset can show all three levels at once without fighting the architecture.
##
## What it has, and why each thing is here:
##
##   a long unbroken wall      the hero emerges from it, and the margin grows
##                             along it, so both are in one frame
##   four metres of clear floor the camera can stand back far enough to hold
##                             the hero and a palp cluster together
##   a radiator                §27's own example of a target different
##                             organisms interpret differently
##   a sofa and a low table    occluders, contact targets, and something for
##                             critters to walk around
##   a corner and a skirting   seams, which is what a seam grazer is FOR
##   a thin free-standing panel  6 cm, so the grazer's both-sides law can
##                             actually fire on camera
##
##     godot --path game res://tests/DreamStage.tscn

const FieldScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const MarginScript := preload("res://scripts/dream/margin/dream_margin_controller.gd")
const PalpRendererScript := preload("res://scripts/dream/margin/dream_palp_renderer.gd")
const CritterScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const HeroScript := preload("res://scripts/dream/entity/dream_hero_tentacle.gd")
const ResidueScript := preload("res://scripts/dream/dream_residue.gd")
const DirectorScript := preload("res://scripts/dream/dream_ecology_director.gd")

## The room. Long axis on X, the hero's wall at -X, the camera working from +X.
const ROOM := Vector3(6.0, 2.7, 4.2)

var field: DreamFieldController
var margin: DreamMarginController
var palps: DreamPalpRenderer
var critters: DreamCritterController
var hero: DreamHeroTentacle
var residue: DreamResidue
var director: DreamEcologyDirector
var camera: Camera3D
var lamp: SpotLight3D

## Where the hero comes through, and which way it faces.
## Close enough to the radiator that the hero can actually reach it. Its
## targets come from rays within about 1.5 m of its own root, and at the
## middle of the wall the radiator sat 1.69 m away -- so it spent a whole
## take finding nothing to touch and leaving no residue. §27 makes the
## radiator the canonical thing different organisms interpret differently;
## it should be within the hero's arm.
var hero_at := Vector3(-ROOM.x * 0.5 + 0.05, 1.35, 0.72)
var hero_aim := Vector3.RIGHT


func _ready() -> void:
	_build_room()
	_build_furniture()
	_build_light()
	_build_ecology()


## Everything is a box: the stage is about sightlines and collision, not about
## looking like a home. The real flats are where materials get judged.
func _box(at: Vector3, size: Vector3, colour: Color, name_hint: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_hint
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = size
	shape.shape = col
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return body


func _build_room() -> void:
	var t := 0.2
	var wall := Color(0.62, 0.58, 0.56)
	_box(Vector3(0, -t * 0.5, 0), Vector3(ROOM.x, t, ROOM.z),
			Color(0.34, 0.24, 0.19), "Floor")
	_box(Vector3(0, ROOM.y + t * 0.5, 0), Vector3(ROOM.x, t, ROOM.z),
			wall, "Ceiling")
	# The hero's wall: long, unbroken, nothing in front of it.
	_box(Vector3(-ROOM.x * 0.5 - t * 0.5, ROOM.y * 0.5, 0),
			Vector3(t, ROOM.y, ROOM.z), wall, "HeroWall")
	_box(Vector3(ROOM.x * 0.5 + t * 0.5, ROOM.y * 0.5, 0),
			Vector3(t, ROOM.y, ROOM.z), wall, "BackWall")
	_box(Vector3(0, ROOM.y * 0.5, -ROOM.z * 0.5 - t * 0.5),
			Vector3(ROOM.x, ROOM.y, t), wall, "SideWallA")
	_box(Vector3(0, ROOM.y * 0.5, ROOM.z * 0.5 + t * 0.5),
			Vector3(ROOM.x, ROOM.y, t), wall, "SideWallB")
	# A skirting run: a seam the length of the room, which is what a seam
	# grazer exists to taste.
	_box(Vector3(-ROOM.x * 0.5 + 0.06, 0.09, 0), Vector3(0.05, 0.18, ROOM.z),
			Color(0.70, 0.66, 0.62), "Skirting")


func _build_furniture() -> void:
	# §27's radiator, under the hero's wall and to one side of it.
	var rad := _box(Vector3(-ROOM.x * 0.5 + 0.20, 0.45, 1.35),
			Vector3(0.14, 0.62, 1.10), Color(0.74, 0.72, 0.68), "Radiator")
	for fin in 9:
		_box(Vector3(-ROOM.x * 0.5 + 0.20, 0.45, 0.88 + float(fin) * 0.12),
				Vector3(0.16, 0.58, 0.03), Color(0.78, 0.76, 0.72),
				"RadiatorFin%d" % fin)
	# A sofa and a low table: occluders, contact targets, obstacles to walk
	# around. Kept off the hero's wall so they never block the shot.
	_box(Vector3(1.1, 0.30, -1.15), Vector3(1.9, 0.60, 0.85),
			Color(0.30, 0.27, 0.33), "Sofa")
	_box(Vector3(1.1, 0.72, -1.50), Vector3(1.9, 0.55, 0.18),
			Color(0.30, 0.27, 0.33), "SofaBack")
	_box(Vector3(0.9, 0.36, 0.9), Vector3(1.0, 0.06, 0.60),
			Color(0.36, 0.26, 0.20), "Table")
	# SOMETHING WITHIN THE HERO'S ARM, IN FRONT OF IT.
	#
	# The hero casts for targets FORWARD, out of the wall it came through, to
	# about 1.5 m. Given four metres of clear floor it found nothing for
	# twenty-two seconds and never touched anything, so the take had no
	# residue in it at all. A pedestal at arm's length is what a limb reaching
	# into a room is for -- and it doubles as something for the margin to work
	# and the critters to climb.
	# It has to be at the LIMB'S OWN HEIGHT. Instrumenting the search showed
	# the rays fanning about 29 degrees below horizontal at most, so a waist
	# height plinth 0.85 m out passed under nothing and over the top of it.
	# OFF THE CAMERA'S LINE TO THE HERO. Directly in front of it, the plinth
	# stood between the lens and the creature and hid the limb every time it
	# retracted -- the thing it exists to give the hero was also the thing
	# blocking the shot of the hero. To one side, the limb reaches across and
	# both are visible.
	_box(Vector3(-1.75, 0.55, 1.35), Vector3(0.40, 1.10, 0.40),
			Color(0.42, 0.38, 0.36), "Pedestal")
	_box(Vector3(-1.75, 1.13, 1.35), Vector3(0.54, 0.06, 0.54),
			Color(0.48, 0.44, 0.41), "PedestalTop")

	# THE THIN PANEL. Six centimetres, standing free, so a seam grazer can be
	# on both sides of it where a camera can see both.
	_box(Vector3(-0.6, 0.85, 1.55), Vector3(1.30, 1.70, 0.06),
			Color(0.66, 0.63, 0.60), "ThinPanel")


## The player's own lamp, on the camera, exactly as in play.
func _build_light() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 60.0
	add_child(camera)
	camera.make_current()
	lamp = SpotLight3D.new()
	lamp.light_energy = 5.5
	lamp.spot_range = 12.0
	lamp.spot_angle = 46.0
	lamp.light_color = Color(1.0, 0.94, 0.84)
	camera.add_child(lamp)
	lamp.position = Vector3(0.14, -0.16, -0.05)
	# A little ambient so the room is not a void beyond the torch.
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.20, 0.17, 0.22)
	e.ambient_light_energy = 0.30
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)


func _build_ecology() -> void:
	field = FieldScript.new()
	add_child(field)
	# A rect that covers the room, and lobes seeded against the hero's wall so
	# the margin grows where the camera is looking.
	field.setup("stage".hash(),
			Vector4(-ROOM.x * 0.5, -ROOM.z * 0.5, ROOM.x * 0.5, ROOM.z * 0.5),
			0.0, Vector3(-ROOM.x * 0.5 + 0.4, 1.3, 0.0))
	residue = ResidueScript.new()
	add_child(residue)
	residue.setup("stage_residue".hash())
	residue.field = field
	margin = MarginScript.new()
	add_child(margin)
	margin.setup(field, "stage_margin".hash())
	palps = PalpRendererScript.new()
	add_child(palps)
	palps.setup(margin)
	critters = CritterScript.new()
	add_child(critters)
	critters.setup(field, "stage_critters".hash())
	critters.margin = margin
	critters.residue = residue
	hero = HeroScript.new()
	add_child(hero)
	hero.setup("stage_hero".hash(), hero_at, hero_aim)
	hero.field = field
	hero.critters = critters
	hero.touched.connect(func(where: Vector3, nrm: Vector3):
		residue.lay(where, nrm, 0.16, 1.0, 3.6))
	margin.hero = hero
	critters.hero = hero
	hero.margin = margin
	# In this capture the camera IS the player's viewpoint -- it carries the
	# player's own lamp -- so the hero watches it, and §2's WATCH_PLAYER can
	# fire when the shot pushes in.
	hero.watch = camera
	director = DirectorScript.new()
	add_child(director)
	director.setup("stage_director".hash())
	director.margin = margin
	director.critters = critters
	director.hero = hero
	director.field = field
	margin.director = director
	critters.director = director


## Where a camera can stand and hold all three levels at once. The whole point
## of building the room was that such a place exists in it.
func wide_stand() -> Dictionary:
	return {
		"eye": Vector3(2.35, 1.62, 1.35),
		"look": Vector3(-1.4, 1.30, 0.15),
	}


## A stand PERPENDICULAR to the creature, for anything that has to judge its
## LENGTH -- the arrival above all.
##
## `wide_stand` looks up the limb's own axis, because it is composed to hold
## the hero and a palp cluster in one frame. That is the worst possible angle
## for watching something extrude: the limb points at the lens, so it gains
## its whole length in foreshortening and grow 0.25 and grow 0.63 are the same
## photograph. Standing off to the side costs the palp cluster and buys the
## one axis the shot is actually about.
func side_stand() -> Dictionary:
	var aim: Vector3 = hero_aim.normalized()
	var across: Vector3 = aim.cross(Vector3.UP).normalized()
	# Toward the middle of the room rather than through the wall behind it.
	if (hero_at + across).length() > (hero_at - across).length():
		across = -across
	var look: Vector3 = hero_at + aim * 0.8
	return {"eye": look + across * 2.4 + Vector3.UP * 0.15, "look": look}


func census() -> Dictionary:
	return {"margin": margin.census(), "critters": critters.census(),
			"hero": hero.census(), "director": director.census(),
			"residue": residue.census()}
