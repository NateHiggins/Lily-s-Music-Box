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

const FURNITURE := "res://data/orison_v2/domestic_furniture.json"
const GRACE_S := 0.5
const SILL_H := 0.07
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
const PERCH_KINDS := ["chair", "crate", "nightstand", "cupboard", "prep_cabinet", "counter", "hamper", "suitcase",
		"coffee", "cardcabinet", "ashcan", "boottray", "table_rect", "table_round", "desk", "sofa", "bed"]
const SINK_MPS := 0.22
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
var _pieces: Array = []
var _materials: Dictionary = {}
var _moving: Array = []
var _time := 0.0
var _player: CharacterBody3D


func _ready() -> void:
	name = "Parkour"
	_sill_mat = StandardMaterial3D.new()
	_sill_mat.albedo_color = Color(0.46, 0.38, 0.30)
	_sill_mat.roughness = 0.6
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
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FURNITURE))
	if data is Dictionary:
		for row: Dictionary in data.get("furniture", []):
			if str(row.get("kind", "")) in PERCH_KINDS or str(row.get("kind", "")) in MIDDLE_KINDS:
				_pieces.append(row)


## Courses and sills to match the live pocket: build the new, free the forgotten.
func sync(rooms: DreamRoomBuilder, plan: Dictionary) -> void:
	var live: Dictionary = rooms._live
	for key: String in _courses.keys():
		if not live.has(key):
			_forget(_courses[key])
			_courses.erase(key)
	for key: String in live:
		if not _courses.has(key):
			_courses[key] = _course(str(key), live[key], rooms)
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
	node.set_meta("hop", hop)
	node.set_meta("step", step)
	var r: Array = room.rect
	var lo := Vector2(float(r[0]), float(r[1]))
	var hi := Vector2(float(r[2]), float(r[3]))
	var centre := (lo + hi) * 0.5
	var own := _own_pieces(str(room.get("source", "")), rooms)
	var placed: Array = []
	var middle := _pick(own, MIDDLE_KINDS, Vector2(hi.x - lo.x - 1.2, hi.y - lo.y - 1.2), 0.7, 2.0, rng)
	placed.append(_place(node, middle, centre, rng, "middle", "", lo, hi))
	for door: Dictionary in room.doors:
		if bool(door.sealed):
			continue
		var a: Array = door.aperture
		var current: Array = [a[0], a[1], a[2], a[3]]
		var current_top := SILL_H
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
	return node


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
	for surface: Dictionary in row.get("surfaces", []):
		var mesh := _surface_mesh(surface)
		if mesh == null:
			continue
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position = offset
		visual.material_override = _finish(str(surface.material))
		body.add_child(visual)
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		shape.position = offset
		body.add_child(shape)
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


func _surface_mesh(surface: Dictionary) -> ArrayMesh:
	var raw: Array = surface.get("vertices", [])
	var nrm: Array = surface.get("normals", [])
	if raw.is_empty() or raw.size() % 9 != 0 or nrm.size() != raw.size():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0, raw.size(), 3):
		vertices.append(Vector3(raw[i], raw[i + 1], raw[i + 2]))
		normals.append(Vector3(nrm[i], nrm[i + 1], nrm[i + 2]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if surface.has("uvs"):
		var uvs := PackedVector2Array()
		var raw_uv: Array = surface.uvs
		for i in range(0, raw_uv.size(), 2):
			uvs.append(Vector2(raw_uv[i], raw_uv[i + 1]))
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _finish(key: String) -> Material:
	if not _materials.has(key):
		var aliases := {"floor_oak": "oak_quartered", "fabric_cool": "linen", "fabric_green": "linen", "glassish": "brass_dull"}
		_materials[key] = MatLib.get_mat(str(aliases.get(key, key)), Color.WHITE)
	return _materials[key]


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
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = material
	mesh.mesh = bm
	body.add_child(mesh)
	body.set_meta("top", centre.y + size.y * 0.5)
	body.set_meta("rect", [centre.x - size.x * 0.5, centre.z - size.z * 0.5, centre.x + size.x * 0.5, centre.z + size.z * 0.5])
	body.set_meta("kind", label.to_lower())
	parent.add_child(body)
	return body


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
