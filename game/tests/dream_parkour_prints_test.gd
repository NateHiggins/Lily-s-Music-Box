extends Node3D
## Dream parkour across all six release prints (order wd7c01339b8b0, "six prints' day courses"). For each subject and
## two seeds: the dream builds; every live room has a course of the building's real furniture; every open doorway's
## sill reaches the middle over perches the dream body can clear; the body wakes on a perch; each room has a path
## tentacle to every open doorway. How many rooms the subject's day lends is printed for the record.
const SEEDS := ["f123456789abcdef", "0a1b2c3d4e5f6071"]
const PROFILES := {"mina_release_print": "mina_caption_crisis", "peter_release_print": "peter_form_corridor",
	"juno_release_print": "juno_feedback_tetris", "mae_release_print": "mae_contradictory_antiques",
	"cal_release_print": "cal_memory_radio", "omar_release_print": "omar_unrepairable"}
const Parkour := preload("res://scripts/dream/dream_parkour.gd")

var checks := 0
var failures: Array[String] = []
var root: DreamMazeRoot


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("DREAM PARKOUR PRINTS: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func _overlaps(a: Array, b: Array, pad: float) -> bool:
	return a[0] < b[2] + pad and a[2] > b[0] - pad and a[1] < b[3] + pad and a[3] > b[1] - pad


## True when a body could stand at (x, z) on a room floor: a ray down meets a Floor, and nothing solid is in the way.
func _floor_at(x: float, z: float) -> bool:
	var space := root.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, 2.5, z), Vector3(x, -0.5, z), 1, [root.player.get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or not str((hit.collider as Node).name).begins_with("Floor"):
		return false
	var body := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.5
	body.shape = capsule
	body.collision_mask = 1
	body.exclude = [root.player.get_rid()]
	body.transform = Transform3D(Basis(), Vector3(x, 0.8, z))
	return space.intersect_shape(body, 1).is_empty()


## Can a body standing on nodes[from] reach nodes[to]? A move is a hop of at most the course's gap that climbs at
## most its step (a drop may be any height); the walk runs the way a player does, from the doorway inward.
func _reaches(nodes: Array, from: int, to: int, limits: Vector2) -> bool:
	var seen := {from: true}
	var frontier: Array[int] = [from]
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		if at == to:
			return true
		for j in nodes.size():
			if seen.has(j):
				continue
			var close := Parkour.gap(nodes[at].rect, nodes[j].rect) <= limits.x + 0.01
			var rise := float(nodes[j].top) - float(nodes[at].top)
			if close and rise <= limits.y + 0.001:
				seen[j] = true
				frontier.append(j)
	return false


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 1320)
	for profile_id: String in PROFILES:
		for seed_hex: String in SEEDS:
			await _one(profile_id, str(PROFILES[profile_id]), seed_hex)
	_finish()


func _one(profile_id: String, case_id: String, seed_hex: String) -> void:
	var tag := "%s/%s" % [profile_id.trim_suffix("_release_print"), seed_hex.substr(0, 4)]
	root = (load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene).instantiate()
	root.autonomous = false
	root.configure_dream({"case_id": case_id, "profile_id": profile_id, "window": {},
		"seed_hex": seed_hex, "maze_revision": 1, "outcome": ""})
	add_child(root)
	await _physics(4)
	check(root.maze_built, "%s: the dream builds" % tag)
	var parkour: Node3D = root.parkour
	check(parkour != null, "%s: the dream has its course" % tag)
	if parkour == null or not root.maze_built:
		await _drop()
		return
	var live: Dictionary = root.rooms._live
	var perches: Array = parkour.perches()
	var coursed := {}
	for p: Dictionary in perches:
		if not str(p.room).is_empty():
			coursed[str(p.room)] = true
	check(coursed.size() == live.size(), "%s: every live room has a course (%d of %d)" % [tag, coursed.size(), live.size()])
	var lent := 0
	for key: String in live:
		var room: Dictionary = live[key]
		var source := str(room.get("source", ""))
		if source.is_empty():
			source = str(root.rooms.describe(root.rooms.path_of(key)).get("source", ""))
		if source.begins_with("DAY_"):
			lent += 1
		var nodes: Array = []
		var middle := -1
		for p: Dictionary in perches:
			if str(p.room) == key:
				if str(p.role) == "middle":
					middle = nodes.size()
				nodes.append(p)
		var sills: Array[int] = []
		# The course builder draws a path to every unsealed doorway, built beyond or not yet.
		var open_doors := (room.doors as Array).filter(func(d: Dictionary) -> bool: return not bool(d.sealed)).size()
		for door: Dictionary in room.doors:
			if bool(door.sealed) or str(door.leads_to).is_empty():
				continue
			for p: Dictionary in perches:
				if str(p.kind) == "sill" and _overlaps(p.rect, door.aperture, 0.01):
					sills.append(nodes.size())
					nodes.append(p)
					break
		check(middle >= 0, "%s %s: a table, desk or bed at its middle" % [tag, key])
		if middle < 0:
			continue
		var limits: Vector2 = parkour.course_limits(key)
		var stranded := sills.filter(func(s: int) -> bool: return not _reaches(nodes, s, middle, limits)).size()
		check(stranded == 0, "%s %s: every doorway reaches the middle over perches (%d stranded)" % [tag, key, stranded])
		var path: Dictionary = parkour._paths.get(key, {})
		check(not path.is_empty() and (path.chains as Array).size() == open_doors, "%s %s: a path tentacle to every open doorway" % [tag, key])
	var real := perches.filter(func(p: Dictionary) -> bool: return str(p.role) != "sill")
	check(real.all(func(p: Dictionary) -> bool: return (p.body as Node).has_meta("piece")), "%s: every perch is real furniture" % tag)
	# RUL-012: every drawn perch surface (furniture and sills) carries authored UVs and tangents and a mapped finish.
	var bare: Array[String] = []
	var empty := 0
	for p: Dictionary in perches:
		var body := p.body as Node
		if body.find_children("*", "MeshInstance3D", true, false).is_empty() or body.find_children("*", "CollisionShape3D", true, false).is_empty():
			empty += 1
		for draw: Node in (p.body as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := draw as MeshInstance3D
			for surface in mi.mesh.get_surface_count():
				var format: int = mi.mesh.surface_get_format(surface)
				var material: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(surface)
				var mapped := true
				if material is StandardMaterial3D:
					var sm := material as StandardMaterial3D
					mapped = not sm.uv1_triplanar and sm.albedo_texture != null and sm.normal_texture != null
				if format & Mesh.ARRAY_FORMAT_TEX_UV == 0 or format & Mesh.ARRAY_FORMAT_TANGENT == 0 or material == null or not mapped:
					bare.append("%s/%s" % [str(p.kind), mi.name])
	check(empty == 0, "%s: every perch is drawn and solid (%d empty)" % [tag, empty])
	check(bare.is_empty(), "%s: every perch surface has UVs, tangents and a mapped finish (%d bare: %s)" % [tag, bare.size(), bare.slice(0, 6)])
	check(root.player.position.y > 0.3, "%s: the body wakes on a perch (y %.2f)" % [tag, root.player.position.y])
	# How much of the subject's day is lent is the day owner's business (a day spent out lends little, by ruling: outside
	# places are later work), so it is reported, not held here; DreamV2RoomsTest holds Mina's.
	print("DREAM PARKOUR PRINTS %s rooms %d perches %d lent %d" % [tag, live.size(), real.size(), lent])
	await _drop()


func _drop() -> void:
	remove_child(root)
	root.queue_free()
	root = null
	await _physics(3)


func _finish() -> void:
	print("DREAM PARKOUR PRINTS RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
