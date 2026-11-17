extends Node3D
## THE FLOOR IS THE WAKING WORLD (order wd7c01339b8b0; Lily, 2026-11-17: "design the dream world around parkour,
## floor is lava logic, to get around without getting ejected back to the waking world"; her rulings
## dream_parkour_grace/body/tenant/ceiling_20261117, and for round 2, "all 3": real period furniture as the perches
## with the floor paling under you, harder courses that sway and sink, and the Tenant prowling below).
##
## In the dream the floor is where the waking world shows through: stand on it and it pales under you for half a
## second, then you fall awake (the director's `fall`; Bible IX: nobody dies in the dream). So a room is crossed on
## what is not floor. This node owns that:
##   - PERCHES are the building's own furniture, rebuilt from data/orison_v2/domestic_furniture.json with their own
##     surfaces and finishes, and solid to their own triangles. A day room (Her Day, Folded) furnishes its course
##     from the subject's own flat first; every room's middle is a table, a desk or a bed.
##   - COURSES run from every open door's sill to the middle, built connected: each next perch is placed within a
##     sure hop of the last. The hop grows with the room's depth in the fractal (deeper is harder), and deeper perches
##     sway, or sink while you stand on them.
##   - SILLS: every open doorway carries a raised threshold, so a doorway is always a landing.
##   - THE LAVA CLOCK: standing on a room floor for GRACE_S wakes you; the boards bloom pale under your feet first.
##   - THE PATH OVERHEAD (Lily's answer to the round 2 film: "move the limbs and make them transparent like the
##     waking cell, refine their shape to be continuous writhing tentacles indirectly showing the path"): the room's
##     lineage body keeps its meaning (a knot over the room and a reach to every doorway) but is redrawn here as
##     continuous tentacles in the waking cell's own membrane, high under the ceiling, each running from a doorway's
##     head over the perches of that door's course to the knot above the middle, and writhing slowly. Look up and
##     the way across is shown, never told.

const FURNITURE := "res://data/orison_v2/domestic_furniture.json"
const GRACE_S := 0.5
const SILL_H := 0.07
## The perches are the building's own furniture, mounted through the waking building's native owners (the same
## variants, authored UV charts, tangents and catalogue finishes), never rebuilt from raw source triangles (RUL-012).
const Domestic := preload("res://scripts/building/orison_v2_domestic_furniture.gd")
const WorkTables := preload("res://scripts/building/orison_v2_work_tables.gd")
## The sill is new geometry: a box with metric UVs and tangents in the catalogue's quartered oak, tiled as native wood.
const SILL_FINISH := "oak_quartered"
const SILL_TILE_M := 0.6
## The shallowest and the deepest course: the hop between perches and the climb between their tops.
const HOP_NEAR := 1.0
const HOP_FAR := 1.9
const STEP_NEAR := 0.75
const STEP_FAR := 1.1
## The test's fairness bound: the dream body clears this gap and climb (jump 5.2 m/s rises about 1.38 m).
const MAX_GAP_M := 2.0
const MAX_STEP_M := 1.15
## Depth at which a course is as hard as it gets.
const DEPTH_FAR := 8
## Furniture a body can stand on, by how a perch is used.
## The middle is where a body wakes into the dream, so it stands above the Tenant's reach: a table, a desk or a
## workbench (a sofa's or bed's seat is lower, and they stay ordinary perches).
const MIDDLE_KINDS := ["table_rect", "table_round", "desk", "workbench"]
const PERCH_KINDS := ["chair", "crate", "nightstand", "cupboard", "counter", "hamper", "suitcase",
		"coffee", "cardcabinet", "ashcan", "boottray", "table_rect", "table_round", "desk", "sofa", "bed"]
const SINK_MPS := 0.22
const CEILING_M := 3.0
## The tentacles run this far under the ceiling, above the eye of a body standing on the highest perch.
const PATH_HIGH_M := 2.74
const PATH_RINGS := 44
const PATH_SIDES := 9
const MEMBRANE_SHADER := preload("res://shaders/waking_colony_membrane.gdshader")
const SWAY_M := 0.14

var woken := false
var lava_s := 0.0
## Room key -> the room's course node.
var _courses: Dictionary = {}
## Aperture key -> sill.
var _sills: Dictionary = {}
var _pale: ColorRect
var _bloom: MeshInstance3D
var _sill_mat: StandardMaterial3D
var _native: RefCounted
var _storage: RefCounted
var _objects: RefCounted
var _beds: RefCounted
var _pieces: Array = []
var _materials: Dictionary = {}
var _moving: Array = []
var _time := 0.0
var _player: CharacterBody3D
var _skin: ShaderMaterial
## Room key -> {"node": MeshInstance3D, "chains": Array of PackedVector3Array, "knot": MeshInstance3D}
var _paths: Dictionary = {}


func _ready() -> void:
	name = "Parkour"
	_sill_mat = (MatLib.get_mat(SILL_FINISH) as StandardMaterial3D).duplicate() as StandardMaterial3D
	_sill_mat.uv1_triplanar = false
	_sill_mat.uv1_scale = Vector3.ONE / SILL_TILE_M
	# Seen from above, below and both doorway sides; the box is never entered.
	_sill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_native = Domestic.NativeFurniture.new()
	_storage = Domestic.NativeStorage.new()
	_objects = Domestic.NativeObjects.new()
	_beds = Domestic.new()
	for factory: RefCounted in [_native, _storage, _objects]:
		if not factory.call("prepare"):
			push_error("dream parkour: a native furniture owner refused to prepare")
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_pale = ColorRect.new()
	_pale.color = Color(0.93, 0.92, 0.88, 0.0)
	_pale.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_pale)
	_bloom = MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2(2.4, 2.4)
	_bloom.mesh = disc
	var bloom_mat := ShaderMaterial.new()
	bloom_mat.shader = Shader.new()
	bloom_mat.shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float amount = 0.0;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = amount * (1.0 - smoothstep(0.15, 1.0, d));
	ALBEDO = vec3(0.95, 0.94, 0.90) * a;
	ALPHA = a;
}"""
	_bloom.material_override = bloom_mat
	_bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bloom.visible = false
	add_child(_bloom)
	_skin = ShaderMaterial.new()
	_skin.shader = MEMBRANE_SHADER
	_skin.set_shader_parameter("tardi_normal", load("res://assets/dream/microscopy/tardigrade_membrane/normal.png"))
	_skin.set_shader_parameter("cytoplasm_web", load("res://assets/dream/waking_colony/cytoplasm_web.png"))
	# Lily on the round 3 film: "thinner and fainter so they hint rather than point". Less milk, less opal, less lens.
	_skin.set_shader_parameter("milk", 0.28)
	_skin.set_shader_parameter("opal_gain", 0.3)
	_skin.set_shader_parameter("lens_strength", 0.07)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FURNITURE))
	if data is Dictionary:
		for row: Dictionary in data.get("furniture", []):
			if (str(row.get("kind", "")) in PERCH_KINDS or str(row.get("kind", "")) in MIDDLE_KINDS) and _mountable(row):
				_pieces.append(row)


## Courses and sills to match the live pocket: build the new, free the forgotten.
func sync(rooms: DreamRoomBuilder, plan: Dictionary) -> void:
	var live: Dictionary = rooms._live
	for key: String in _courses.keys():
		if not live.has(key):
			_forget(_courses[key])
			_courses.erase(key)
			if _paths.has(key):
				(_paths[key].node as Node).queue_free()
				(_paths[key].knot as Node).queue_free()
				_paths.erase(key)
	for key: String in live:
		if not _courses.has(key):
			_courses[key] = _course(str(key), live[key], rooms)
			_paths[key] = _path_overhead(_courses[key])
	_stand_down_lineage()
	var wanted := {}
	for door: Dictionary in plan.get("doors", []):
		var a: Array = door.aperture
		wanted["%d_%d" % [roundi((float(a[0]) + float(a[2])) * 50.0), roundi((float(a[1]) + float(a[3])) * 50.0)]] = a
	for key: String in _sills.keys():
		if not wanted.has(key):
			(_sills[key] as Node).queue_free()
			_sills.erase(key)
	for key: String in wanted:
		if not _sills.has(key):
			var a: Array = wanted[key]
			_sills[key] = _box(self, "Sill", Vector3((a[0] + a[2]) * 0.5, SILL_H * 0.5, (a[1] + a[3]) * 0.5),
					Vector3(absf(a[2] - a[0]), SILL_H, absf(a[3] - a[1])), _sill_mat)


func _forget(course: Node) -> void:
	for body: Node in course.get_children():
		_moving.erase(body)
	course.queue_free()


## Every perch, sill and the room it belongs to, for the fairness check and the spawn.
func perches() -> Array:
	var out: Array = []
	for key: String in _courses:
		for body: Node in (_courses[key] as Node).get_children():
			out.append({"room": key, "body": body, "top": float(body.get_meta("top")), "rect": body.get_meta("rect"),
				"kind": str(body.get_meta("kind")), "role": str(body.get_meta("role")), "motion": str(body.get_meta("motion"))})
	for key: String in _sills:
		var body: Node = _sills[key]
		out.append({"room": "", "body": body, "top": float(body.get_meta("top")), "rect": body.get_meta("rect"),
			"kind": "sill", "role": "sill", "motion": ""})
	return out


## The hop and climb a room's course was built to.
func course_limits(room_key: String) -> Vector2:
	if not _courses.has(room_key):
		return Vector2(HOP_NEAR, STEP_NEAR)
	return Vector2(float(_courses[room_key].get_meta("hop")), float(_courses[room_key].get_meta("step")))


## The middle perch of a room: where a body is put down on entering the dream.
func spawn_on(room_key: String) -> Vector3:
	if not _courses.has(room_key):
		return Vector3.INF
	for body: Node in (_courses[room_key] as Node).get_children():
		if str(body.get_meta("role")) == "middle":
			var r: Array = body.get_meta("rect")
			return Vector3((r[0] + r[2]) * 0.5, float(body.get_meta("top")) + 0.05, (r[1] + r[3]) * 0.5)
	return Vector3.INF


## One physics step of the lava clock. True on the step the floor wakes the body.
func tick(player: CharacterBody3D, delta: float) -> bool:
	_player = player
	if woken or player == null:
		return false
	var on_floor := false
	if player.is_on_floor():
		for i in player.get_slide_collision_count():
			var hit := player.get_slide_collision(i)
			var body := hit.get_collider() as Node
			if body != null and str(body.name).begins_with("Floor") and hit.get_normal().y > 0.7:
				on_floor = true
				break
	lava_s = lava_s + delta if on_floor else 0.0
	var amount := clampf(lava_s / GRACE_S, 0.0, 1.0)
	_pale.color.a = amount * 0.45
	_bloom.visible = amount > 0.0
	if _bloom.visible:
		_bloom.global_position = Vector3(player.global_position.x, 0.012, player.global_position.z)
		(_bloom.material_override as ShaderMaterial).set_shader_parameter("amount", amount)
	if lava_s >= GRACE_S:
		woken = true
		return true
	return false


func _process(_delta: float) -> void:
	_skin.set_shader_parameter("cell_time", _time)
	for key: String in _paths:
		var path: Dictionary = _paths[key]
		(path.node as MeshInstance3D).mesh = _tentacles(path.chains, _time, str(key).hash())


## The pocket's own lineage bodies are redrawn as the path overhead; the old gold knots stand down in coursed rooms.
func _stand_down_lineage() -> void:
	# A lineage body hangs at its room's centre; node names cannot carry the room key's dots, so match by place.
	for body: Node in get_tree().get_nodes_in_group("dream_lineage_bodies"):
		var at := (body as Node3D).global_position
		for key: String in _courses:
			var r: Array = (_courses[key] as Node).get_meta("room_rect")
			if at.x >= float(r[0]) and at.x <= float(r[2]) and at.z >= float(r[1]) and at.z <= float(r[3]):
				(body as Node3D).visible = false


func _physics_process(delta: float) -> void:
	_time += delta
	var standing: Node = null
	if _player != null and is_instance_valid(_player) and _player.is_on_floor():
		for i in _player.get_slide_collision_count():
			var collider := _player.get_slide_collision(i).get_collider() as Node
			if collider != null and collider.has_meta("motion"):
				standing = collider
	for body: Node3D in _moving:
		if not is_instance_valid(body):
			continue
		var rest: Vector3 = body.get_meta("rest")
		match str(body.get_meta("motion")):
			"sway":
				var phase := float(body.get_meta("phase"))
				body.position = rest + Vector3(sin(_time * 2.4 + phase), 0.0, cos(_time * 1.9 + phase)) * SWAY_M
			"sink":
				# Sinks under you toward the floor and rises back when you leave it.
				var floor_y := rest.y - float(body.get_meta("top")) + 0.06
				var y := body.position.y + (-SINK_MPS if standing == body else SINK_MPS * 0.5) * delta
				body.position.y = clampf(y, floor_y, rest.y)


func _course(key: String, room: Dictionary, rooms: DreamRoomBuilder) -> Node3D:
	var node := Node3D.new()
	node.name = "Course_%s" % key.replace(".", "_").replace("@", "")
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var depth := int(room.get("depth", key.count(".")))
	var hard := clampf(float(depth) / float(DEPTH_FAR), 0.0, 1.0)
	var hop := lerpf(HOP_NEAR, HOP_FAR, hard)
	var step := lerpf(STEP_NEAR, STEP_FAR, hard)
	node.set_meta("room_rect", room.rect)
	node.set_meta("hop", hop)
	node.set_meta("step", step)
	var r: Array = room.rect
	var lo := Vector2(float(r[0]), float(r[1]))
	var hi := Vector2(float(r[2]), float(r[3]))
	var centre := (lo + hi) * 0.5
	var own := _own_pieces(str(room.get("source", "")), rooms)
	var placed: Array = []
	var chains: Array = []
	var middle := _pick(own, MIDDLE_KINDS, Vector2(hi.x - lo.x - 1.2, hi.y - lo.y - 1.2), 0.7, 2.0, rng)
	placed.append(_place(node, middle, centre, rng, "middle", "", lo, hi))
	for door: Dictionary in room.doors:
		if bool(door.sealed):
			continue
		var a: Array = door.aperture
		var current: Array = [a[0], a[1], a[2], a[3]]
		var current_top := SILL_H
		var chain := PackedVector3Array([Vector3((float(a[0]) + float(a[2])) * 0.5, 2.05, (float(a[1]) + float(a[3])) * 0.5)])
		var middle_rect: Array = placed[0].rect
		var guard := 0
		while gap(current, middle_rect) > hop and guard < 24:
			guard += 1
			var here := Vector2((float(current[0]) + float(current[2])) * 0.5, (float(current[1]) + float(current[3])) * 0.5)
			var dir := (centre - here).normalized()
			var near := _nearest_within(current, placed, hop)
			if not near.is_empty() and gap(near.rect, middle_rect) < gap(current, middle_rect) - 0.05:
				current = near.rect
				current_top = float(near.top)
				chain.append(Vector3((float(current[0]) + float(current[2])) * 0.5, PATH_HIGH_M, (float(current[1]) + float(current[3])) * 0.5))
				continue
			var piece := _pick(own, PERCH_KINDS, Vector2(1.3, 1.3), current_top - 0.9, current_top + step, rng)
			if piece.is_empty():
				break
			var size := _footprint(piece)
			var reach := _half_extent(current, dir) + hop * 0.75 + maxf(size.x, size.y) * 0.5
			var at := _clamp_into(here + dir * reach, size, lo, hi, 0.1)
			var rect := _rect_of(at, size)
			var tries := 0
			while _overlaps(rect, placed) and tries < 6:
				tries += 1
				at = _clamp_into(here + dir * reach * (1.0 - 0.12 * tries), size, lo, hi, 0.1)
				rect = _rect_of(at, size)
			if _overlaps(rect, placed):
				break
			var motion := ""
			if hard > 0.3 and rng.randf() < hard * 0.45:
				motion = "sink" if rng.randf() < 0.5 else "sway"
			var perch := _place(node, piece, at, rng, "perch", motion, lo, hi)
			placed.append(perch)
			current = perch.rect
			current_top = float(perch.top)
			chain.append(Vector3((float(rect[0]) + float(rect[2])) * 0.5, PATH_HIGH_M, (float(rect[1]) + float(rect[3])) * 0.5))
		chain.append(Vector3(centre.x, CEILING_M - 0.22, centre.y))
		chains.append(chain)
	node.set_meta("chains", chains)
	node.set_meta("knot", Vector3(centre.x, CEILING_M - 0.2, centre.y))
	return node


## The room's lineage redrawn as the path overhead: a knot above the middle and a tentacle to every doorway.
func _path_overhead(course: Node3D) -> Dictionary:
	var tentacles := MeshInstance3D.new()
	tentacles.name = "PathOverhead"
	tentacles.material_override = _skin
	tentacles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tentacles)
	var knot := MeshInstance3D.new()
	knot.name = "PathKnot"
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.13
	knot.mesh = ball
	knot.material_override = _skin
	knot.position = course.get_meta("knot")
	add_child(knot)
	return {"node": tentacles, "knot": knot, "chains": course.get_meta("chains")}


## Every chain as one continuous tube through its points, writhing: a travelling wave across the tentacle, held
## still at both ends so it always meets its doorway and its knot. Thicker toward the knot, fine at the door.
static func _tentacles(chains: Array, t: float, seed_value: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var made := false
	for c in chains.size():
		var points: PackedVector3Array = chains[c]
		if points.size() < 2:
			continue
		var phase := float((seed_value + c * 7919) % 628) / 100.0
		var spine: Array[Vector3] = []
		for i in PATH_RINGS:
			var s := float(i) / float(PATH_RINGS - 1)
			spine.append(_along(points, s))
		var rings: Array = []
		for i in PATH_RINGS:
			var s := float(i) / float(PATH_RINGS - 1)
			var ahead: Vector3 = spine[mini(i + 1, PATH_RINGS - 1)] - spine[maxi(i - 1, 0)]
			var tangent := ahead.normalized() if ahead.length() > 0.0001 else Vector3.FORWARD
			var side := tangent.cross(Vector3.UP).normalized()
			if side.length() < 0.5:
				side = Vector3.RIGHT
			var lift := side.cross(tangent).normalized()
			var hold := sin(PI * s)
			var writhe := side * sin(s * 9.0 - t * 1.3 + phase) * 0.09 * hold + lift * cos(s * 7.0 - t * 1.05 + phase) * 0.05 * hold
			var centre: Vector3 = spine[i] + writhe
			var radius := lerpf(0.012, 0.036, s) * (1.0 + 0.12 * sin(s * 13.0 - t * 2.0 + phase))
			var ring: Array[Vector3] = []
			for k in PATH_SIDES:
				var a := TAU * float(k) / float(PATH_SIDES)
				ring.append(centre + (side * cos(a) + lift * sin(a)) * radius)
			rings.append(ring)
		for i in PATH_RINGS - 1:
			var r0: Array = rings[i]
			var r1: Array = rings[i + 1]
			for k in PATH_SIDES:
				var k1 := (k + 1) % PATH_SIDES
				for v: Vector3 in [r0[k], r1[k], r1[k1], r0[k], r1[k1], r0[k1]]:
					st.add_vertex(v)
				made = true
	if not made:
		return ArrayMesh.new()
	st.generate_normals()
	return st.commit()


## A point a share `s` of the way along a polyline, smoothed (Catmull-Rom between the points).
static func _along(points: PackedVector3Array, s: float) -> Vector3:
	var n := points.size()
	var f := clampf(s, 0.0, 1.0) * float(n - 1)
	var i := mini(int(f), n - 2)
	var u := f - float(i)
	var p0 := points[maxi(i - 1, 0)]
	var p1 := points[i]
	var p2 := points[i + 1]
	var p3 := points[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


## The furniture of the flat a day room belongs to, so Mina's day is crossed on Mina's things.
func _own_pieces(source: String, rooms: DreamRoomBuilder) -> Array:
	var module: Dictionary = rooms.catalog.get("modules", {}).get(source, {})
	var records: Array = (module.get("source", {}) as Dictionary).get("records", [])
	if records.is_empty():
		return []
	var space := str(records[0].get("id", ""))
	var parts := space.split("_")
	if parts.size() < 3 or not parts[0].begins_with("F0"):
		return []
	var unit := parts[0].substr(2, 1) + parts[1]
	return _pieces.filter(func(row: Dictionary) -> bool: return str(row.id).begins_with(unit + "_"))


func _pick(own: Array, kinds: Array, max_size: Vector2, min_top: float, max_top: float, rng: RandomNumberGenerator) -> Dictionary:
	for pool: Array in [own, _pieces]:
		var fits: Array = pool.filter(func(row: Dictionary) -> bool:
			var s := _footprint(row)
			var top := _top(row)
			return str(row.kind) in kinds and top >= maxf(0.3, min_top) and top <= max_top \
					and minf(s.x, s.y) >= 0.3 and maxf(s.x, s.y) <= maxf(max_size.x, max_size.y) and minf(s.x, s.y) <= minf(max_size.x, max_size.y))
		if not fits.is_empty():
			return fits[rng.randi() % fits.size()]
	return {}


static func _top(row: Dictionary) -> float:
	return float(row.bounds[1][1]) - float(row.bounds[0][1])


static func _footprint(row: Dictionary) -> Vector2:
	return Vector2(float(row.bounds[1][0]) - float(row.bounds[0][0]), float(row.bounds[1][2]) - float(row.bounds[0][2]))


## Rebuild one real piece at `at`, its rect and top recorded for the course; moving pieces are animatable.
func _place(parent: Node3D, row: Dictionary, at: Vector2, _rng: RandomNumberGenerator, role: String, motion: String,
		_lo: Vector2, _hi: Vector2) -> Dictionary:
	var size := _footprint(row)
	var b: Array = row.bounds
	var body: PhysicsBody3D = AnimatableBody3D.new() if not motion.is_empty() else StaticBody3D.new()
	body.name = str(row.kind).capitalize().replace(" ", "")
	body.collision_layer = 1
	body.collision_mask = 0
	var offset := Vector3(-(float(b[0][0]) + float(b[1][0])) * 0.5, -float(b[0][1]), -(float(b[0][2]) + float(b[1][2])) * 0.5)
	if not _mount(body, row):
		push_error("dream parkour: native mount refused for " + str(row.id))
	# The native variants sit in the source record's own frame; centre the piece on its footprint.
	for child: Node in body.get_children():
		if child is Node3D:
			(child as Node3D).position += offset
	body.position = Vector3(at.x, 0.0, at.y)
	var top := _top(row)
	var rect := _rect_of(at, size)
	body.set_meta("top", top)
	body.set_meta("rect", rect)
	body.set_meta("kind", str(row.kind))
	body.set_meta("piece", str(row.id))
	body.set_meta("role", role)
	body.set_meta("motion", motion)
	body.set_meta("rest", body.position)
	body.set_meta("phase", float(str(row.id).hash() % 628) / 100.0)
	parent.add_child(body)
	if not motion.is_empty():
		_moving.append(body)
	return {"rect": rect, "top": top}


## True when the waking building has a native owner for this record (the same dispatch as its domestic furniture).
## Prep cabinets are left out: their native owner dresses only the working sliding-panel mechanism, not a perch.
func _mountable(row: Dictionary) -> bool:
	var kind := str(row.get("kind", ""))
	return str(row.id) in WorkTables.IDS or kind in Domestic.NATIVE_KINDS or kind in Domestic.STORAGE_KINDS \
			or kind in Domestic.OBJECT_KINDS or kind == "bed"


func _mount(body: StaticBody3D, row: Dictionary) -> bool:
	var id := str(row.id)
	var kind := str(row.kind)
	if id in WorkTables.IDS:
		return WorkTables.mount_on(body, id, row)
	if kind in Domestic.NATIVE_KINDS:
		return _native.call("mount_on", body, id)
	if kind in Domestic.STORAGE_KINDS:
		return _storage.call("mount_on", body, id)
	if kind in Domestic.OBJECT_KINDS:
		return _objects.call("mount_on", body, id)
	if kind == "bed":
		_beds.call("_add_bed", body, row)
		return true
	return false


func _box(parent: Node3D, label: String, centre: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = centre
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _metric_box(size, material)
	body.add_child(mesh)
	body.set_meta("top", centre.y + size.y * 0.5)
	body.set_meta("rect", [centre.x - size.x * 0.5, centre.z - size.z * 0.5, centre.x + size.x * 0.5, centre.z + size.z * 0.5])
	body.set_meta("kind", label.to_lower())
	parent.add_child(body)
	return body


## A box whose UVs are metres along each face, with tangents, so a catalogue finish tiles at its authored size.
static func _metric_box(size: Vector3, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	# Each face: normal, the two in-plane axes (u, v) and their half extents.
	var faces := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var centre := n * h
		var eu := absf(u.dot(h))
		var ev := absf(v.dot(h))
		var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		var points: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for c: Vector2 in corners:
			points.append(centre + u * eu * c.x + v * ev * c.y)
			uvs.append(Vector2(eu * c.x, -ev * c.y) + Vector2(eu, ev))
		for k: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(points[k])
	st.generate_tangents()
	var out := st.commit()
	out.surface_set_material(0, material)
	return out


static func _rect_of(at: Vector2, size: Vector2) -> Array:
	return [at.x - size.x * 0.5, at.y - size.y * 0.5, at.x + size.x * 0.5, at.y + size.y * 0.5]


static func _overlaps(rect: Array, placed: Array) -> bool:
	for other: Dictionary in placed:
		var o: Array = other.rect
		if rect[0] < o[2] + 0.1 and rect[2] > o[0] - 0.1 and rect[1] < o[3] + 0.1 and rect[3] > o[1] - 0.1:
			return true
	return false


static func _nearest_within(rect: Array, placed: Array, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := INF
	for other: Dictionary in placed:
		var g := gap(rect, other.rect)
		if g <= reach and g < best_gap and other.rect != rect:
			best = other
			best_gap = g
	return best


static func _half_extent(rect: Array, dir: Vector2) -> float:
	return absf(dir.x) * (float(rect[2]) - float(rect[0])) * 0.5 + absf(dir.y) * (float(rect[3]) - float(rect[1])) * 0.5


static func _clamp_into(at: Vector2, size: Vector2, lo: Vector2, hi: Vector2, margin: float) -> Vector2:
	return Vector2(clampf(at.x, lo.x + margin + size.x * 0.5, maxf(lo.x + margin + size.x * 0.5, hi.x - margin - size.x * 0.5)),
			clampf(at.y, lo.y + margin + size.y * 0.5, maxf(lo.y + margin + size.y * 0.5, hi.y - margin - size.y * 0.5)))


## Edge-to-edge gap between two perch rects in plan.
static func gap(a: Array, b: Array) -> float:
	var dx := maxf(0.0, maxf(float(a[0]) - float(b[2]), float(b[0]) - float(a[2])))
	var dz := maxf(0.0, maxf(float(a[1]) - float(b[3]), float(b[1]) - float(a[3])))
	return Vector2(dx, dz).length()
