class_name ResidentRoutines
extends Node3D
## Eighteen people with somewhere to be.
##
## Until now every resident stood on one spot in the middle of their living
## room forever, which is the single most building-killing thing a populated
## building can do. This gives each of them a loop: time at home, time
## pacing it, an errand they run occasionally, and a place elsewhere in the
## Orison that is theirs — a bench, a landing, the laundry, the roof — that
## they go and sit in for a while because they like it there.
##
## The haunts are the point. A resident who only ever appears in their own
## apartment is set dressing; one you keep running into on the basement
## stairs is a neighbour. They are authored per person against the same
## wound their case and poltergeist are built from: Teresa, who cannot rest
## because rest summons alarms, sits in the lobby where she can see the
## door. Malcolm, who kept a cutting alive so a goodbye would not finish,
## goes up to the roof garden. Cal, tuning a radio to a moment that must
## never end, stands in the light court where the whole building is audible.
##
## Movement is waypointed rather than pathfound. Residents are deliberately
## non-colliding — the generator's movement audit authors every clearance
## and cannot see actors added in Godot — so nothing stops them walking
## through a wall except being told where the doors are. Routes therefore
## run home -> their own doorway -> the corridor ring -> the lift hall, and
## a resident whose haunt is on another floor rides the lift: they walk into
## it, are hidden for a moment, and step out upstairs. People do vanish into
## lifts, so the cheapest abstraction available is also the honest one.

const WALK_SPEED := 1.05
const RING_X := 4.38          # corridor ring, from the movement audit
const RING_Z := 8.30
const LIFT := Vector2(1.9, -5.6)      # Blender XY of the lift hall

## Where each resident goes when they are not at home, and why it is theirs.
## `at` is Blender XY; `z` names the storey.
const HAUNTS := {
	"evelyn_marsh": {"at": Vector2(4.55, -8.85), "floor": "F01",
		"why": "the brass mail bank on the east lobby wall — she checks it
		more often than anyone gets post"},
	"teresa_vale": {"at": Vector2(-2.45, -9.22), "floor": "F01",
		"why": "the lobby bench west of the street door, where she can see
		who comes in"},
	"mina_vale": {"at": Vector2(-2.2, -1.2), "floor": "F01",
		"why": "the light court, the quietest measurable place in it"},
	"lena_ortiz": {"at": Vector2(-9.6, 1.1), "floor": "F03",
		"why": "the west storage room, where the mending piles up"},
	"juno_kells": {"at": Vector2(0.0, 5.0), "floor": "F03",
		"why": "the utility room, for the hum of the risers"},
	"malcolm_reed": {"at": Vector2(-2.0, 6.0), "floor": "ROOF",
		"why": "the roof garden"},
	"omar_bell": {"at": Vector2(0.0, 5.0), "floor": "B1",
		"why": "the basement plant, next to the boiler he understands"},
	"rhea_sato": {"at": Vector2(0.0, 5.0), "floor": "F05",
		"why": "the fifth-floor utility room, the only room with no echo"},
	"peter_wren": {"at": Vector2(0.0, -8.6), "floor": "F01",
		"why": "the lobby noticeboard, reading it again"},
	"cam_ortiz": {"at": Vector2(0.0, 8.0), "floor": "F01",
		"why": "the rear door, half out of the building already"},
	"noel_price": {"at": Vector2(-2.2, 1.2), "floor": "F01",
		"why": "the light court, where nothing can be handled"},
	"transient_guests": {"at": Vector2(2.2, -6.2), "floor": "F01",
		"why": "the vestibule, bags at their feet"},
	"nadia_quell": {"at": Vector2(0.0, 5.0), "floor": "F06",
		"why": "the top-floor utility room, checking egress"},
	"cal_dwyer": {"at": Vector2(2.2, 1.0), "floor": "F04",
		"why": "the light court, where the whole building is audible"},
	"iris_bell": {"at": Vector2(-2.0, 6.0), "floor": "ROOF",
		"why": "the roof, for the light"},
	"sacha_reed": {"at": Vector2(-2.2, -1.2), "floor": "F02",
		"why": "the court landing, the best vantage in the building"},
	"jonah_price": {"at": Vector2(0.0, 5.0), "floor": "B1",
		"why": "the basement laundry, for the noise to write against"},
	"mae_kessler": {"at": Vector2(-9.6, 1.1), "floor": "F04",
		"why": "the west storage room, among other people's boxes"},
}

## Clip roles, resolved against whatever the model actually shipped with.
## Evelyn's arrived from Meshy as clip_01..clip_08 plus walk and run;
## identified by eye from rendered contact sheets (tests/ClipSheet.tscn):
##   clip_01  relaxed stand, hand on hip
##   clip_02  hand to chest, fingers at the glasses chain — fretting
##   clip_03  attentive stand, arms loose, slight sway
##   clip_04  head tipped all the way back, looking straight up
##   clip_05  sharp glance over the left shoulder, body still
##   clip_06  seated, hands settling to the lap
##   clip_07  hands working at counter height
##   clip_08  arm extended straight out at shoulder height (mail slots)
const ROLES := {
	"idle": "clip_01", "pace": "walk", "busy": "clip_07",
	"settle": "clip_06", "reach": "clip_08",
	# Not yet requested by any routine, named so they can be: the building
	# reactions (look_up for the light well, glance for a noise behind her,
	# fret for a bad night, wait for queueing at the lift).
	"look_up": "clip_04", "glance": "clip_05",
	"fret": "clip_02", "wait": "clip_03",
}

## The same physical clip means something different in a different life.
## These are state choices, not scale or speed caricatures: characterization
## comes from what residents do while waiting, working, and settling.
const CHARACTER_ROLES := {
	"evelyn_marsh": {"idle": "idle", "busy": "busy", "settle": "wait"},
	"teresa_vale": {"idle": "fret", "busy": "wait", "settle": "settle"},
	"mina_vale": {"idle": "wait", "busy": "busy", "settle": "glance"},
	"lena_ortiz": {"idle": "busy", "busy": "reach", "settle": "idle"},
	"juno_kells": {"idle": "glance", "busy": "busy", "settle": "wait"},
	"malcolm_reed": {"idle": "look_up", "busy": "reach", "settle": "idle"},
	"omar_bell": {"idle": "wait", "busy": "busy", "settle": "settle"},
	"rhea_sato": {"idle": "glance", "busy": "fret", "settle": "wait"},
	"peter_wren": {"idle": "fret", "busy": "reach", "settle": "wait"},
	"cam_ortiz": {"idle": "glance", "busy": "reach", "settle": "idle"},
	"noel_price": {"idle": "wait", "busy": "busy", "settle": "settle"},
	"transient_guests": {"idle": "wait", "busy": "fret", "settle": "wait"},
	"nadia_quell": {"idle": "idle", "busy": "reach", "settle": "wait"},
	"cal_dwyer": {"idle": "glance", "busy": "reach", "settle": "fret"},
	"iris_bell": {"idle": "look_up", "busy": "reach", "settle": "glance"},
	"sacha_reed": {"idle": "glance", "busy": "wait", "settle": "idle"},
	"jonah_price": {"idle": "fret", "busy": "busy", "settle": "wait"},
	"mae_kessler": {"idle": "wait", "busy": "reach", "settle": "settle"},
}

## Temperament: how each resident spends a night, and why it is theirs.
## HAUNTS says WHERE they go; this says HOW OFTEN, HOW LONG, and by which
## route - the difference between a shut-in and a man who lives in the
## basement. Every value is argued from the resident's own wound.
##
##   out    chance of leaving the flat at a decision point
##   tv     chance of the couch instead (0 for those who do not sit)
##   dwell  seconds at the haunt: [min, max]
##   rest   seconds at home between decisions: [min, max]
##   climb  preference for stairs over the lift, 0..1
const TEMPERAMENTS := {
	# Checks a mail bank nobody writes to, several times a night.
	"evelyn_marsh": {"out": 0.55, "tv": 0.18, "dwell": [20.0, 46.0],
		"rest": [14.0, 30.0], "climb": 0.9},
	# Night nurse, awake when the building is: on the bench watching the
	# street door because an alarm might yet be hers.
	"teresa_vale": {"out": 0.60, "tv": 0.10, "dwell": [70.0, 150.0],
		"rest": [12.0, 26.0], "climb": 0.8},
	# Everything must be annotated; the light court is the quietest
	# measurable place, and she stays until she has measured it.
	"mina_vale": {"out": 0.28, "tv": 0.20, "dwell": [80.0, 170.0],
		"rest": [26.0, 60.0], "climb": 0.5},
	# Mends for the whole building, so she goes down to the pile often.
	"lena_ortiz": {"out": 0.50, "tv": 0.24, "dwell": [50.0, 110.0],
		"rest": [18.0, 40.0], "climb": 0.6},
	# Recording the risers: out at strange hours, gone a long time.
	"juno_kells": {"out": 0.62, "tv": 0.06, "dwell": [90.0, 190.0],
		"rest": [12.0, 30.0], "climb": 0.55},
	# The roof garden and the cutting that keeps a goodbye open. Always
	# the stairs: he arrived in 1918 and the lift is for other people.
	"malcolm_reed": {"out": 0.58, "tv": 0.08, "dwell": [110.0, 230.0],
		"rest": [20.0, 44.0], "climb": 0.95},
	# The super who cannot call anything unrepairable. Practically lives
	# beside the boiler, and carries his tools down the stairs.
	"omar_bell": {"out": 0.78, "tv": 0.10, "dwell": [120.0, 260.0],
		"rest": [10.0, 22.0], "climb": 0.75},
	# Her mistakes are a captive note. Mostly behind her own door, and
	# when she does leave it is for the one room with no echo.
	"rhea_sato": {"out": 0.20, "tv": 0.16, "dwell": [70.0, 150.0],
		"rest": [30.0, 70.0], "climb": 0.4},
	# Certainty by re-reading: many short anxious trips to the same
	# noticeboard, never satisfied, never long.
	"peter_wren": {"out": 0.66, "tv": 0.12, "dwell": [14.0, 32.0],
		"rest": [10.0, 20.0], "climb": 0.7},
	# Rest reads as collapse. Barely home, never on the couch, stairs
	# every time - a courier does not wait for a lift.
	"cam_ortiz": {"out": 0.85, "tv": 0.0, "dwell": [16.0, 40.0],
		"rest": [8.0, 16.0], "climb": 0.98},
	# The flat is a museum of the life before the trial. He stays in it.
	"noel_price": {"out": 0.14, "tv": 0.30, "dwell": [30.0, 70.0],
		"rest": [40.0, 90.0], "climb": 0.3},
	# Perpetually departing, therefore perpetually in the entry.
	"transient_guests": {"out": 0.72, "tv": 0.05, "dwell": [40.0, 90.0],
		"rest": [10.0, 24.0], "climb": 0.5},
	# Organising the tenants against her own employers: she is on every
	# floor, all night, and she takes whatever moves fastest.
	"nadia_quell": {"out": 0.80, "tv": 0.06, "dwell": [40.0, 95.0],
		"rest": [9.0, 20.0], "climb": 0.35},
	# Perfect tuning prevents moments ending. He rarely leaves the reels.
	"cal_dwyer": {"out": 0.22, "tv": 0.34, "dwell": [90.0, 200.0],
		"rest": [34.0, 76.0], "climb": 0.45},
	# Painting for an audience she imagines: home, mostly, with the
	# occasional climb for the light.
	"iris_bell": {"out": 0.30, "tv": 0.14, "dwell": [80.0, 170.0],
		"rest": [26.0, 58.0], "climb": 0.8},
	# The recording displaced the experience, so the recording never
	# stops: stairwells, roof, everywhere, camera first.
	"sacha_reed": {"out": 0.70, "tv": 0.08, "dwell": [50.0, 120.0],
		"rest": [11.0, 24.0], "climb": 0.85},
	# An insomniac who cannot finish: out at the worst hours, wandering
	# the stairs rather than writing the verdict down.
	"jonah_price": {"out": 0.64, "tv": 0.22, "dwell": [60.0, 140.0],
		"rest": [13.0, 30.0], "climb": 0.9},
	# The Estate's last name, appraising by gaslight. Rare, formal,
	# unhurried outings, and never on foot up six storeys.
	"mae_kessler": {"out": 0.26, "tv": 0.20, "dwell": [60.0, 130.0],
		"rest": [32.0, 72.0], "climb": 0.12},
}
const DEFAULT_TEMPER := {"out": 0.45, "tv": 0.20, "dwell": [18.0, 50.0],
		"rest": [16.0, 34.0], "climb": 0.5}


static func temper_of(slug: String) -> Dictionary:
	return TEMPERAMENTS.get(slug, DEFAULT_TEMPER)


enum Stage { HOME, PACING, TO_LIFT, RIDING, AT_HAUNT, RETURNING, WATCHING,
		ON_STAIRS, RETURN_STAIRS, CROSSING, STREET }

## The walk to the shops, authored rather than pathfound.
##
## ResidentNav is built per storey from room rectangles; the street is
## not a room and never enters the graph. Rather than teach the graph
## about outdoors, these are the same authored routes the site itself is
## built around - gen_layout's route discipline says the walkable world
## is three paths, and two of them are these. Blender XY; the street
## surface is z 0.06.
##
## Residents used to cross to the shops hidden, the way they ride the
## lift. That was honest for a lift and a lie for a road: the bodega is
## forty metres away in plain sight of every south window, and a
## building whose residents vanish at the kerb is a building nobody
## lives on the street of. They walk it now, and are only hidden for
## the bit that is genuinely out of sight - the stair down to the bar,
## and the moment of stepping through a shop door.
const STREET_ROUTES := {
	"harukiya_bar": [
		Vector2(0.72, -10.70), Vector2(2.90, -13.60),
		Vector2(3.50, -15.10), Vector2(4.10, -19.30),
		Vector2(4.60, -23.60), Vector2(4.875, -26.40),
		Vector2(4.875, -28.05),
	],
	"bodega": [
		Vector2(0.72, -10.70), Vector2(6.20, -12.40),
		Vector2(12.00, -12.60), Vector2(16.60, -12.60),
		Vector2(18.67, -12.60),
	],
}
const STREET_Z := 0.06

var actors: Array = []
## Portal-graph pathfinding; see resident_nav.gd. Null-safe: without it
## everything degrades to the old straight-line walk.
var nav: ResidentNav
var elevator: OrisonElevator
## slug -> directive from the ScheduleDirector: {mode, key, activity,
## point?}. Empty per slug (and entirely, under DAYNIGHT=0) means the
## temperament wander below runs exactly as it always has.
var schedules: Dictionary = {}

var _layout: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _couch: Dictionary = {}     # unit -> sofa position
var _tv: Dictionary = {}        # unit -> television position


func build(layout: Dictionary, residents: Array) -> int:
	_layout = layout
	nav = ResidentNav.new()
	nav.name = "ResidentNav"
	add_child(nav)
	nav.build(layout)
	# Where each unit's couch and television stand, for the evening's
	# viewing: the resident walks to the sofa and faces the set, and
	# TVProp's own watcher-poll does the switching-on — sitting down IS the
	# remote control.
	for fl in layout["floors"]:
		for fu in fl.get("furniture", []):
			var fid := str(fu.get("id", ""))
			var at: Array = fu.get("at", [0, 0])
			var spot := GameBoot.b2g([float(at[0]), float(at[1]),
					float(fl["z"])])
			if fid.ends_with("_couch"):
				_couch[fid.split("_")[0]] = spot
			elif str(fu.get("asm", "")) == "tv":
				_tv[fid.split("_")[0]] = spot
	_rng.randomize()
	for node in residents:
		var slug := _slug_of(node)
		if slug == "":
			continue
		_upgrade(node, slug)
		if "externally_driven" in node:
			node.externally_driven = true
		var actor := {
			"node": node, "slug": slug,
			"home": node.global_position,
			"stage": Stage.HOME,
			"timer": _rng.randf_range(4.0, 26.0),
			"target": node.global_position,
			"anim": _player_of(node),
			"haunt": _haunt_point(slug),
			"hidden_for": 0.0,
			"path": PackedVector3Array(),
			"leg": 0,
			"unit": str(node.get("unit")) if "unit" in node else "",
			"home_door": _nearest_home_door(node),
			"door_cycle": 2,
			"vertical_mode": "",
			"target_floor": "",
			"at_venue": false,
			"cross_to": Vector3.ZERO,
			"sched_key": "",
			"street_homeward": false,
			"seat": null,
		}
		actors.append(actor)
	print("[ROUTINES] %d residents with somewhere to be" % actors.size())
	_validate_nav_when_settled()
	return actors.size()


## The graph is authored from plan data; the world is meshes and
## furniture. Two physics frames after build, prove every edge against
## the actual colliders and cut the liars.
func _validate_nav_when_settled() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if nav and is_inside_tree():
		nav.validate_with_collision(get_viewport().find_world_3d())


func bind_elevator(lift: OrisonElevator) -> void:
	elevator = lift


## The ScheduleDirector's hand. Stores the directive and hurries the
## actor's next decision so a change of hour is answered in seconds, not
## whenever the current dwell happens to run out.
func set_schedule(slug: String, directive: Dictionary) -> void:
	schedules[slug] = directive
	for actor in actors:
		if str(actor.slug) != slug:
			continue
		if int(actor.stage) in [Stage.HOME, Stage.AT_HAUNT]:
			actor.timer = minf(float(actor.timer),
					_rng.randf_range(2.0, 8.0))
		return


## Inside the door, off the street: where exterior trips cross over.
## West of the doorway on purpose — (0, -9) is the player's own spawn
## point, and a walk target inside the player's yield radius (0.62 m)
## can never be closed to _follow's 0.16 m: the resident walks in, is
## shoved back out, forever.
func _door_point() -> Vector3:
	return GameBoot.b2g([-1.9, -8.75, 0.06])


## Where an exterior crossing lands. At the Harukiya a resident claims a
## free couch socket (BarSeatZone, group "bar_seats") and sits in it;
## when the couches are full — or anywhere else — they stand near the
## venue anchor, jittered so a crowd reads as a crowd and not a stack.
func _venue_spot(actor: Dictionary, directive: Dictionary) -> Vector3:
	var anchor: Vector3 = directive.get("point", Vector3.ZERO)
	if str(directive.get("key", "")) == "harukiya_bar":
		for seat in get_tree().get_nodes_in_group("bar_seats"):
			if str(seat.occupied_by) == "" and not bool(seat.seated):
				seat.occupied_by = str(actor.slug)
				actor.seat = seat
				return seat.global_position
	return anchor + Vector3(_rng.randf_range(-0.8, 0.8), 0.0,
			_rng.randf_range(-0.8, 0.8))


## Load one of the authored street polylines into the actor's own path,
## forward or homeward. Deliberately NOT run through nav.route(): the
## graph has no outdoor nodes and would answer "no wall-safe route" for
## every one of these.
func _set_street_route(actor: Dictionary, key: String,
		homeward: bool) -> void:
	var pts: Array = STREET_ROUTES[key]
	var path := PackedVector3Array()
	for i in pts.size():
		var p: Vector2 = pts[pts.size() - 1 - i] if homeward else pts[i]
		path.append(GameBoot.b2g([p.x, p.y, STREET_Z]))
	actor.path = path
	actor.leg = 0
	actor.street_homeward = homeward
	actor.node.visible = true


func _release_seat(actor: Dictionary) -> void:
	var seat: Node3D = actor.get("seat")
	if seat != null and is_instance_valid(seat) \
			and str(seat.occupied_by) == str(actor.slug):
		seat.occupied_by = ""
	actor.seat = null


## Where the schedule wants this actor, if it still wants what the actor
## is currently doing.
func _schedule_holds(actor: Dictionary) -> bool:
	var directive: Dictionary = schedules.get(str(actor.slug), {})
	if directive.is_empty():
		return false
	return str(directive.get("mode", "")) in ["place", "exterior",
			"offsite"] \
			and str(directive.get("key", "")) == str(actor.get(
			"sched_key", ""))


## A scheduled decision replaces the temperament roll while a directive
## stands. Scheduled trips deliberately ignore the opening lockdown's
## locked leaf: the lockdown gates the PLAYER out of units; a tenant
## leaving their own flat has always had the key.
func _scheduled_decision(actor: Dictionary, directive: Dictionary) -> void:
	var mode := str(directive.get("mode", "home"))
	var activity := str(directive.get("activity", ""))
	var unit := _unit_of(actor)
	if mode == "home":
		if activity == "sleeping":
			actor.timer = _rng.randf_range(24.0, 60.0)
			return
		var roll := _rng.randf()
		var tv_chance := 0.65 if activity == "tv" else 0.12
		if roll < tv_chance and _couch.has(unit):
			actor.stage = Stage.WATCHING
			_set_route(actor, _couch[unit])
			actor.timer = _rng.randf_range(24.0, 70.0)
		else:
			actor.stage = Stage.PACING
			_set_route(actor, _near_home(actor))
			actor.timer = _rng.randf_range(6.0, 14.0)
		return
	# place / exterior / offsite: a trip. Exterior and offsite walk to
	# the lobby door first; the crossing happens at AT_HAUNT arrival.
	actor.sched_key = str(directive.get("key", ""))
	actor.at_venue = false
	if mode == "place":
		actor.haunt = directive.get("point", actor.haunt)
	else:
		actor.haunt = _door_point()
	_begin_trip(actor, false)


## Swap the flat sprite for a real mesh wherever one has been generated.
## Done here rather than in the spawner so the cast can be upgraded one
## resident at a time as their models arrive, without the spawn path having
## to know which of the eighteen currently exist. A hero model
## (<slug>.gltf, currently Evelyn's Meshy merge) wins over the generated
## <slug>_rigged.glb; the generated family then borrows the shared
## retargeted move set, so every resident can sit, work, reach and glance.
func _upgrade(node: Node3D, slug: String) -> bool:
	var path := "res://assets/characters/%s/%s.gltf" % [slug, slug]
	if not ResourceLoader.exists(path):
		path = "res://assets/characters/%s/%s_rigged.glb" % [slug, slug]
	if not ResourceLoader.exists(path):
		return false
	var figure: Node3D = node.get_node_or_null("RiggedCharacter") as Node3D
	if figure == null:
		var scene := load(path) as PackedScene
		if scene == null:
			return false
		figure = scene.instantiate()
		figure.name = "RiggedCharacter"
		node.add_child(figure)
	# The billboard and its name label go; the node itself stays, because
	# the case system, the movement audit and the resident group all know it
	# by identity.
	for child in node.get_children():
		if child is Sprite3D:
			child.visible = false
	for mesh in _meshes(figure):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Everything Meshy ships is a loop except the one-shots, and a clip that
	# plays once and freezes reads as the character dying. Looping is the
	# safe default until each clip is identified and classified. (Carried
	# over from the retired lobby test figure, which is where the merged
	# clips were first judged.)
	ResidentMovesLibrary.apply(figure)
	# No scaling of any kind (final ruling 2026-08-02): models ship and
	# render exactly as exported. The authored height factors remain in
	# the profiles as reference only.
	var anim := _player_of(node)
	if anim:
		for clip_name in anim.get_animation_list():
			var clip := anim.get_animation(clip_name)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
		var idle := _resolve_clip(anim, "idle")
		if idle != "" and anim.has_animation(idle):
			anim.play(idle)
			# Eighteen synchronized idles read as a drill team; desync them.
			anim.seek(_rng.randf() * anim.get_animation(idle).length, true)
		print("[ROUTINES] %s: %d clips" % [
				slug, anim.get_animation_list().size()])
	print("[ROUTINES] %s upgraded to a mesh" % slug)
	return true


## A resident's own baked clip beats the shared retargeted one: gaits stay
## personal while the borrowed library fills every other role.
func _resolve_clip(anim: AnimationPlayer, role: String) -> String:
	var suffix: String = {"idle": "_Idle", "pace": "_Walk"}.get(role, "")
	if suffix != "":
		for clip_name in anim.get_animation_list():
			if String(clip_name).ends_with(suffix):
				return String(clip_name)
	return ROLES.get(role, "")


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found


func _slug_of(node: Node) -> String:
	# NPCPlaceholder and AnimatedResident both carry the sprite id.
	for key in ["sprite", "slug", "resident_id"]:
		if key in node:
			return str(node.get(key))
	return ""


func _player_of(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _player_of(child)
		if found:
			return found
	return null


func _haunt_point(slug: String) -> Vector3:
	var spec: Dictionary = HAUNTS.get(slug, {})
	if spec.is_empty():
		return Vector3.ZERO
	var levels: Dictionary = _layout["meta"]["levels"]
	var z: float = float(levels.get(str(spec.floor), 0.0))
	var at: Vector2 = spec.at
	return GameBoot.b2g([at.x, at.y, z + 0.03])


func _play(actor: Dictionary, role: String) -> void:
	var anim: AnimationPlayer = actor.anim
	if anim == null:
		return
	var style: Dictionary = CHARACTER_ROLES.get(str(actor.slug), {})
	var characterized_role := str(style.get(role, role))
	var clip := _resolve_clip(anim, characterized_role)
	if clip != "" and anim.has_animation(clip) \
			and anim.current_animation != clip:
		anim.play(clip)


## Debug inspection: the cast holds still while lined up in the lobby.
var inspection_hold := false

## Residents yield to the player (ruling 2026-08-02): they are still
## non-colliding — the movement audit owns clearances — but a body in
## the player's space steps aside instead of being walked through.
const YIELD_RADIUS := 0.62
const YIELD_SPEED := 1.6
var _player: Node3D


func _process(delta: float) -> void:
	if inspection_hold:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(
				"player_controller") as Node3D
	for actor in actors:
		_step(actor, delta)
		_yield_to_player(actor, delta)


func _yield_to_player(actor: Dictionary, delta: float) -> void:
	if _player == null:
		return
	var node: Node3D = actor.node
	if not is_instance_valid(node):
		return
	# A non-finite player fails every comparison below silently - NaN is
	# not greater than, not less than, not equal to anything - so the
	# early returns all miss and eighteen residents normalise a NaN
	# vector every frame. The safety net exists precisely because the
	# player CAN end up nowhere; nobody steps aside for nowhere.
	if not _player.global_position.is_finite():
		return
	var away := node.global_position - _player.global_position
	if absf(away.y) > 1.2:
		return  # different storey
	away.y = 0.0
	var gap := away.length()
	if gap >= YIELD_RADIUS or gap < 0.001:
		return
	var push := minf(YIELD_SPEED * delta, YIELD_RADIUS - gap)
	node.global_position += away.normalized() * push


func _step(actor: Dictionary, delta: float) -> void:
	var node: Node3D = actor.node
	if not is_instance_valid(node):
		return
	actor.timer -= delta
	match int(actor.stage):
		Stage.HOME:
			# Coming off the lift there is still a walk to finish before
			# settling: idle only once the route is spent.
			if int(actor.leg) < actor.path.size():
				_play(actor, "pace")
				_manage_home_door(actor, true)
				_follow(actor, node, delta)
				return
			_manage_home_door(actor, true)
			_play(actor, "idle")
			if actor.timer <= 0.0:
				# A standing directive from the ScheduleDirector outranks
				# the temperament roll: the hour, not the mood, decides.
				var directive: Dictionary = schedules.get(
						str(actor.slug), {})
				if not directive.is_empty():
					_scheduled_decision(actor, directive)
					return
				# An evening at home is mostly pottering, sometimes the
				# television, occasionally an errand out of the flat. A
				# locked front door keeps the evening indoors: the opening
				# lockdown seals every unit but the player's, and a resident
				# does not walk through their own locked door.
				var unit := _unit_of(actor)
				var locked_in: bool = actor.home_door != null \
						and is_instance_valid(actor.home_door) \
						and actor.home_door.leaf_state == "locked"
				var temper := temper_of(str(actor.slug))
				var tv_chance: float = float(temper.tv)
				var roll := _rng.randf()
				if roll < tv_chance and _couch.has(unit):
					actor.stage = Stage.WATCHING
					_set_route(actor, _couch[unit])
					actor.timer = _rng.randf_range(24.0, 70.0)
				elif roll < tv_chance + float(temper.out) \
						and actor.haunt != Vector3.ZERO \
						and not locked_in:
					_begin_trip(actor, false)
				else:
					actor.stage = Stage.PACING
					_set_route(actor, _near_home(actor))
					actor.timer = _rng.randf_range(6.0, 14.0)
		Stage.WATCHING:
			if _follow(actor, node, delta):
				# At the sofa: face the set, and switch it on THEMSELVES —
				# the set is a thing residents operate, not a sensor.
				_play(actor, "settle")
				var unit := _unit_of(actor)
				if _tv.has(unit):
					var to: Vector3 = _tv[unit] - node.global_position
					node.rotation.y = atan2(-to.x, -to.z)
				if not bool(actor.get("tv_latched", false)):
					actor.tv_latched = true
					_set_unit_tv(unit, true)
			else:
				_play(actor, "pace")
			if actor.timer <= 0.0:
				# Enough television: off goes their latch (the player's own
				# latch on the same set survives), and home they go.
				if bool(actor.get("tv_latched", false)):
					actor.tv_latched = false
					_set_unit_tv(_unit_of(actor), false)
				actor.stage = Stage.HOME
				_set_route(actor, actor.home)
				actor.timer = _rng.randf_range(10.0, 30.0)
		Stage.PACING:
			_play(actor, "pace")
			if _follow(actor, node, delta) or actor.timer <= 0.0:
				actor.stage = Stage.HOME
				actor.timer = _rng.randf_range(8.0, 30.0)
				_play(actor, "busy")
		Stage.TO_LIFT:
			_play(actor, "pace")
			_manage_home_door(actor, false)
			if _follow(actor, node, delta):
				var source := nav.floor_at(node.global_position.y)
				if elevator == null:
					_finish_elevator_fallback(actor, node)
				elif not elevator.is_ready_at(source):
					elevator.npc_request(source)
				elif elevator.npc_request(str(actor.target_floor)):
					actor.stage = Stage.RIDING
					node.visible = false
		Stage.RIDING:
			if elevator == null:
				actor.hidden_for -= delta
			if (elevator != null and elevator.is_ready_at(str(actor.target_floor))) \
					or (elevator == null and actor.hidden_for <= 0.0):
				# Step out of the lift on the haunt's floor and WALK the
				# rest: arriving at the bench is half of what sells that
				# they went somewhere, rather than respawned there.
				node.global_position = _lift_point(actor.haunt.y)
				node.visible = true
				actor.stage = Stage.AT_HAUNT
				_set_route(actor, actor.haunt)
				var dwell: Array = temper_of(str(actor.slug)).dwell
				actor.timer = _rng.randf_range(dwell[0], dwell[1])
		Stage.AT_HAUNT:
			_manage_home_door(actor, false)
			var arrived := _follow(actor, node, delta)
			if arrived:
				_play(actor, "settle")
			else:
				_play(actor, "pace")
			# Arrival at the lobby door with a street directive: cross
			# over. Exterior venues reappear across the road after a
			# hidden beat, the way lift riders reappear upstairs;
			# offsite ("work") is the crossing that does not come back
			# until the schedule says so.
			var standing: Dictionary = schedules.get(str(actor.slug), {})
			if arrived and _schedule_holds(actor) \
					and str(standing.get("mode", "")) in [
					"exterior", "offsite"] \
					and not bool(actor.at_venue):
				actor.at_venue = true
				var key := str(standing.get("key", ""))
				if str(standing.mode) == "exterior" \
						and STREET_ROUTES.has(key):
					# Out the door and down the street on foot.
					_set_street_route(actor, key, false)
					actor.stage = Stage.STREET
					return
				node.visible = false
				if str(standing.mode) == "exterior":
					actor.stage = Stage.CROSSING
					actor.cross_to = _venue_spot(actor, standing)
					actor.timer = _rng.randf_range(5.0, 9.0)
				else:
					actor.timer = _rng.randf_range(30.0, 70.0)
				return
			if actor.timer <= 0.0:
				if _schedule_holds(actor):
					# The hour still wants them here; stay.
					actor.timer = _rng.randf_range(20.0, 45.0)
				elif bool(actor.at_venue):
					# The block ended somewhere off the nav graph.
					actor.at_venue = false
					_release_seat(actor)
					var key2 := str(actor.get("sched_key", ""))
					if STREET_ROUTES.has(key2):
						# Step back out of the shop and walk home.
						_set_street_route(actor, key2, true)
						node.global_position = actor.path[0]
						node.visible = true
						actor.stage = Stage.STREET
						return
					node.visible = false
					actor.stage = Stage.CROSSING
					actor.cross_to = _door_point()
					actor.timer = _rng.randf_range(5.0, 9.0)
				else:
					actor.sched_key = ""
					_begin_trip(actor, true)
		Stage.STREET:
			# Visible, on the pavement, walking it like anyone would.
			_play(actor, "pace")
			if not _follow(actor, node, delta):
				return
			node.visible = false
			if bool(actor.get("street_homeward", false)):
				# At the Orison's own door: back on the graph.
				actor.stage = Stage.CROSSING
				actor.cross_to = _door_point()
				actor.timer = _rng.randf_range(1.0, 2.0)
			else:
				# At the shop's door. The stair down to the bar and the
				# step through a shop door are the only parts genuinely
				# out of sight, so they are the only parts hidden.
				var standing2: Dictionary = schedules.get(
						str(actor.slug), {})
				actor.stage = Stage.CROSSING
				actor.cross_to = _venue_spot(actor, standing2)
				actor.timer = _rng.randf_range(2.5, 5.0)
		Stage.CROSSING:
			if actor.timer <= 0.0:
				node.global_position = actor.cross_to
				node.visible = true
				actor.stage = Stage.AT_HAUNT
				actor.path = PackedVector3Array()
				actor.leg = 0
				actor.timer = _rng.randf_range(20.0, 45.0)
				# A claimed seat comes with a facing: settle INTO the
				# couch, not toward wherever the walk left them pointed.
				var seat: Node3D = actor.get("seat")
				if seat != null and is_instance_valid(seat):
					node.rotation.y = seat.rotation.y
		Stage.RETURNING:
			# Walk back to the lift, ride it, and reappear walking home.
			if node.visible:
				_play(actor, "pace")
				if _follow(actor, node, delta):
					var source := nav.floor_at(node.global_position.y)
					if elevator == null:
						node.visible = false
						actor.hidden_for = _rng.randf_range(2.0, 4.5)
					elif not elevator.is_ready_at(source):
						elevator.npc_request(source)
					elif elevator.npc_request(str(actor.target_floor)):
						node.visible = false
			else:
				if elevator == null:
					actor.hidden_for -= delta
				if (elevator != null and elevator.is_ready_at(str(actor.target_floor))) \
						or (elevator == null and actor.hidden_for <= 0.0):
					node.global_position = _lift_point(actor.home.y)
					node.visible = true
					actor.stage = Stage.HOME
					_set_route(actor, actor.home)
					actor.timer = _rng.randf_range(10.0, 34.0)
		Stage.ON_STAIRS:
			_play(actor, "pace")
			_manage_home_door(actor, false)
			if _follow(actor, node, delta):
				actor.stage = Stage.AT_HAUNT
				actor.timer = _rng.randf_range(18.0, 50.0)
		Stage.RETURN_STAIRS:
			_play(actor, "pace")
			_manage_home_door(actor, true)
			if _follow(actor, node, delta):
				actor.stage = Stage.HOME
				actor.timer = _rng.randf_range(10.0, 34.0)
				_manage_home_door(actor, true)


## The resident's hand on their own switch.
func _set_unit_tv(unit: String, on: bool) -> void:
	if unit == "":
		return
	for tv in get_tree().get_nodes_in_group("televisions"):
		if str(tv.unit) == unit and tv.has_method("set_npc"):
			tv.set_npc(on)
			return


func _unit_of(actor: Dictionary) -> String:
	if str(actor.get("unit", "")) != "":
		return str(actor.unit)
	var spec: Dictionary = HAUNTS.get(str(actor.slug), {})
	# The haunts table has no unit field; the couch map is keyed by unit
	# prefix, so derive from the slug's home the same way the spawner does.
	for unit in _couch:
		if actor.home.distance_to(_couch[unit]) < 7.0:
			return unit
	return ""


func _begin_trip(actor: Dictionary, returning: bool) -> void:
	var node: Node3D = actor.node
	var destination: Vector3 = actor.home if returning else actor.haunt
	var source_floor: String = nav.floor_at(node.global_position.y)
	var destination_floor: String = nav.floor_at(destination.y)
	actor.target_floor = destination_floor
	actor.door_cycle = 0
	var temper := temper_of(str(actor.slug))
	if source_floor == destination_floor:
		actor.stage = Stage.HOME if returning else Stage.AT_HAUNT
		_set_route(actor, destination)
		var span: Array = temper.rest if returning else temper.dwell
		actor.timer = _rng.randf_range(span[0], span[1])
		return
	# The lift does not serve the roof. Otherwise residents split between
	# lift and stairs, weighted toward the lift for long climbs.
	var floor_gap: int = absi(nav.level_order.find(source_floor) \
			- nav.level_order.find(destination_floor))
	# Long climbs discourage everyone, but by how much is personal:
	# Cam takes the stairs from the sixth floor, Mae takes the lift
	# to the second.
	var climb: float = float(temper.climb)
	var use_stairs: bool = destination_floor == "ROOF" \
			or source_floor == "ROOF" \
			or _rng.randf() < climb * (1.0 if floor_gap <= 2 else 0.55)
	actor.vertical_mode = "stairs" if use_stairs else "elevator"
	if use_stairs:
		actor.path = nav.stair_route(node.global_position, destination)
		actor.leg = 0
		actor.stage = Stage.RETURN_STAIRS if returning else Stage.ON_STAIRS
	else:
		_set_route(actor, _lift_point(node.global_position.y))
		actor.stage = Stage.RETURNING if returning else Stage.TO_LIFT


func _finish_elevator_fallback(actor: Dictionary, node: Node3D) -> void:
	actor.stage = Stage.RIDING
	actor.hidden_for = _rng.randf_range(2.0, 4.5)
	node.visible = false


func _nearest_home_door(node: Node3D) -> DoorProp:
	var nearest: DoorProp = null
	var best := INF
	for candidate in get_tree().get_nodes_in_group("apartment_doors"):
		if not candidate is DoorProp:
			continue
		var door := candidate as DoorProp
		if absf(door.global_position.y - node.global_position.y) > 0.45:
			continue
		var d := door.global_position.distance_to(node.global_position)
		if d < best:
			best = d
			nearest = door
	return nearest


func _manage_home_door(actor: Dictionary, returning: bool) -> void:
	var door: DoorProp = actor.get("home_door")
	if not is_instance_valid(door):
		return
	var node: Node3D = actor.node
	var cycle := int(actor.door_cycle)
	var at_leaf := node.global_position.distance_to(door.global_position)
	if cycle == 0 and at_leaf < 1.45:
		door.npc_set_open(true)
		actor.door_cycle = 1
	elif cycle == 1:
		var passed := node.global_position.distance_to(actor.home) < 0.48 \
				if returning else at_leaf > 1.60
		if passed:
			door.npc_set_open(false)
			actor.door_cycle = 2


## Somewhere else in the same room. Kept short so nobody walks out through
## the wall they are standing next to.
func _near_home(actor: Dictionary) -> Vector3:
	var home: Vector3 = actor.home
	return home + Vector3(_rng.randf_range(-1.6, 1.6), 0.0,
			_rng.randf_range(-1.6, 1.6))


## The lift hall on whichever storey they are standing on.
func _lift_point(y: float) -> Vector3:
	return GameBoot.b2g([LIFT.x, LIFT.y, y])


## Plan a route through the portal graph. Same-floor by contract; the lift
## stages handle the vertical.
func _set_route(actor: Dictionary, target: Vector3) -> void:
	var node: Node3D = actor.node
	if nav != null:
		actor.path = nav.route(node.global_position, target)
	else:
		actor.path = PackedVector3Array([target])
	actor.leg = 0


## Walk the planned route waypoint by waypoint. Returns true when spent.
## Turns to face the way they are going, because a person sliding sideways
## across a room is worse than one standing still.
func _follow(actor: Dictionary, node: Node3D, delta: float) -> bool:
	while int(actor.leg) < actor.path.size():
		var target: Vector3 = actor.path[int(actor.leg)]
		var to := target - node.global_position
		var on_stairs := int(actor.stage) in [Stage.ON_STAIRS,
				Stage.RETURN_STAIRS]
		if not on_stairs:
			to.y = 0.0
		if to.length() < 0.16:
			actor.leg = int(actor.leg) + 1
			continue
		node.global_position += to.normalized() * WALK_SPEED * delta
		var facing := Vector2(to.x, to.z)
		if facing.length() > 0.01:
			# Imported walk faces +Z while Godot's conventional forward is -Z.
			# Correct at locomotion, not by scaling or rewriting the skeleton.
			node.rotation.y = atan2(-to.x, -to.z) + PI
		return false
	return true


func stats() -> Dictionary:
	var away := 0
	for actor in actors:
		if int(actor.stage) in [Stage.AT_HAUNT, Stage.RIDING]:
			away += 1
	return {"actors": actors.size(), "away": away}
