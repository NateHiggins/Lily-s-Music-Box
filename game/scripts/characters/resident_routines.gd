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
	"evelyn_marsh": {"at": Vector2(0.0, -8.6), "floor": "F01",
		"why": "the lobby mail bank — she checks it more often than anyone
		gets post"},
	"teresa_vale": {"at": Vector2(3.4, -8.4), "floor": "F01",
		"why": "the lobby bench, facing the street door, where she can see
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
## Evelyn's arrived from Meshy as clip_01..clip_08 plus walk and run, so the
## roles are assigned by position and re-pointed once the clips are named.
const ROLES := {
	"idle": "clip_01", "pace": "walk", "busy": "clip_03",
	"settle": "clip_05", "reach": "clip_07",
}

enum Stage { HOME, PACING, TO_LIFT, RIDING, AT_HAUNT, RETURNING, WATCHING }

var actors: Array = []
## Portal-graph pathfinding; see resident_nav.gd. Null-safe: without it
## everything degrades to the old straight-line walk.
var nav: ResidentNav

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
		}
		actors.append(actor)
	print("[ROUTINES] %d residents with somewhere to be" % actors.size())
	return actors.size()


## Swap the flat sprite for a real mesh wherever one has been generated.
## Done here rather than in the spawner so the cast can be upgraded one
## resident at a time as their models arrive, without the spawn path having
## to know which of the eighteen currently exist.
func _upgrade(node: Node3D, slug: String) -> bool:
	var path := "res://assets/characters/%s/%s.gltf" % [slug, slug]
	if not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		return false
	# The billboard and its name label go; the node itself stays, because
	# the case system, the movement audit and the resident group all know it
	# by identity.
	for child in node.get_children():
		if child is Sprite3D:
			child.visible = false
	var figure := scene.instantiate()
	node.add_child(figure)
	for mesh in _meshes(figure):
		# One more shadow caster per resident, inside a per-object light cap
		# the LightRig is already rationing, for somebody stood in a room.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("[ROUTINES] %s upgraded to a mesh" % slug)
	return true


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
	var clip: String = ROLES.get(role, "")
	if clip != "" and anim.has_animation(clip) \
			and anim.current_animation != clip:
		anim.play(clip)


func _process(delta: float) -> void:
	for actor in actors:
		_step(actor, delta)


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
				_follow(actor, node, delta)
				return
			_play(actor, "idle")
			if actor.timer <= 0.0:
				# An evening at home is mostly pottering, sometimes the
				# television, occasionally an errand out of the flat.
				var unit := _unit_of(actor)
				var roll := _rng.randf()
				if roll < 0.30 and _couch.has(unit):
					actor.stage = Stage.WATCHING
					_set_route(actor, _couch[unit])
					actor.timer = _rng.randf_range(24.0, 70.0)
				elif roll < 0.55 and actor.haunt != Vector3.ZERO:
					actor.stage = Stage.TO_LIFT
					_set_route(actor, _lift_point(node.global_position.y))
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
			if _follow(actor, node, delta):
				actor.stage = Stage.RIDING
				actor.hidden_for = _rng.randf_range(2.0, 4.5)
				node.visible = false
		Stage.RIDING:
			actor.hidden_for -= delta
			if actor.hidden_for <= 0.0:
				# Step out of the lift on the haunt's floor and WALK the
				# rest: arriving at the bench is half of what sells that
				# they went somewhere, rather than respawned there.
				node.global_position = _lift_point(actor.haunt.y)
				node.visible = true
				actor.stage = Stage.AT_HAUNT
				_set_route(actor, actor.haunt)
				actor.timer = _rng.randf_range(18.0, 50.0)
		Stage.AT_HAUNT:
			if _follow(actor, node, delta):
				_play(actor, "settle")
			else:
				_play(actor, "pace")
			if actor.timer <= 0.0:
				actor.stage = Stage.RETURNING
				_set_route(actor, _lift_point(node.global_position.y))
		Stage.RETURNING:
			# Walk back to the lift, ride it, and reappear walking home.
			if node.visible:
				_play(actor, "pace")
				if _follow(actor, node, delta):
					node.visible = false
					actor.hidden_for = _rng.randf_range(2.0, 4.5)
			else:
				actor.hidden_for -= delta
				if actor.hidden_for <= 0.0:
					node.global_position = _lift_point(actor.home.y)
					node.visible = true
					actor.stage = Stage.HOME
					_set_route(actor, actor.home)
					actor.timer = _rng.randf_range(10.0, 34.0)


## The resident's hand on their own switch.
func _set_unit_tv(unit: String, on: bool) -> void:
	if unit == "":
		return
	for tv in get_tree().get_nodes_in_group("televisions"):
		if str(tv.unit) == unit and tv.has_method("set_npc"):
			tv.set_npc(on)
			return


func _unit_of(actor: Dictionary) -> String:
	var spec: Dictionary = HAUNTS.get(str(actor.slug), {})
	# The haunts table has no unit field; the couch map is keyed by unit
	# prefix, so derive from the slug's home the same way the spawner does.
	for unit in _couch:
		if actor.home.distance_to(_couch[unit]) < 7.0:
			return unit
	return ""


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
		to.y = 0.0
		if to.length() < 0.16:
			actor.leg = int(actor.leg) + 1
			continue
		node.global_position += to.normalized() * WALK_SPEED * delta
		node.rotation.y = atan2(-to.x, -to.z)
		return false
	return true


func stats() -> Dictionary:
	var away := 0
	for actor in actors:
		if int(actor.stage) in [Stage.AT_HAUNT, Stage.RIDING]:
			away += 1
	return {"actors": actors.size(), "away": away}
