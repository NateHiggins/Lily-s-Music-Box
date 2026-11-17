extends Node3D
## THE FLOOR IS THE WAKING WORLD (order wd7c01339b8b0; Lily, 2026-11-17: "design the dream world around parkour,
## floor is lava logic, to get around without getting ejected back to the waking world"; her rulings
## dream_parkour_grace/body/tenant/ceiling_20261117).
##
## In the dream the floor is where the waking world shows through: stand on it and the boards pale for half a
## second, then you fall awake (the director's existing `fall` outcome; Bible §IX: nobody dies in the dream). So a
## room is crossed on what is not floor. This node owns that:
##   - PERCHES: every live room gets a course of solid furniture from each open door to its middle, spaced and
##     stepped for the dream body (DreamMazeRoot sets its higher jump), seeded by the room's own key so a room is the
##     same course every time it is remembered. A room's middle is a table; its paths are trunks, chairs, cabinets.
##   - SILLS: every open doorway carries a raised threshold, so a doorway is always a landing.
##   - THE LAVA CLOCK: standing on a room floor for GRACE_S wakes you; leaving it in time forgives it.
## Fairness by construction (the room builder's own fairness clamp is the model): consecutive perches along a path
## are never further apart than MAX_GAP_M edge to edge nor more than MAX_STEP_M higher, so every open door reaches
## every other through the middle. DreamV2ParkourTest checks the graph.

const GRACE_S := 0.5
## The dream body clears this much gap and climb with room to spare (jump 5.2 m/s: about 1.38 m of rise).
const MAX_GAP_M := 1.35
const MAX_STEP_M := 0.75
const SILL_H := 0.07
## The hop the course is built to: comfortably inside the dream body's reach, so every link is a sure jump.
const HOP_M := 1.0
const PERCH_MIN := 0.62
const PERCH_MAX := 0.86

var woken := false
var lava_s := 0.0
## Room key -> the room's course node.
var _courses: Dictionary = {}
## Aperture key -> sill.
var _sills: Dictionary = {}
var _pale: ColorRect
var _wood: StandardMaterial3D
var _sill_mat: StandardMaterial3D


func _ready() -> void:
	name = "Parkour"
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.36, 0.25, 0.17)
	_wood.roughness = 0.72
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


## Courses and sills to match the live pocket: build the new, free the forgotten.
func sync(rooms: DreamRoomBuilder, plan: Dictionary) -> void:
	var live: Dictionary = rooms._live
	for key: String in _courses.keys():
		if not live.has(key):
			(_courses[key] as Node).queue_free()
			_courses.erase(key)
	for key: String in live:
		if not _courses.has(key):
			_courses[key] = _course(str(key), live[key])
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


## Every perch, sill and the room it belongs to, for the fairness check and the spawn.
func perches() -> Array:
	var out: Array = []
	for key: String in _courses:
		for body: Node in (_courses[key] as Node).get_children():
			out.append({"room": key, "body": body, "top": float(body.get_meta("top")), "rect": body.get_meta("rect"), "kind": str(body.get_meta("kind"))})
	for key: String in _sills:
		var body: Node = _sills[key]
		out.append({"room": "", "body": body, "top": float(body.get_meta("top")), "rect": body.get_meta("rect"), "kind": "sill"})
	return out


## The highest-middle perch of a room: where a body is put down on entering the dream.
func spawn_on(room_key: String) -> Vector3:
	if not _courses.has(room_key):
		return Vector3.INF
	for body: Node in (_courses[room_key] as Node).get_children():
		if str(body.get_meta("kind")) == "table":
			var r: Array = body.get_meta("rect")
			return Vector3((r[0] + r[2]) * 0.5, float(body.get_meta("top")) + 0.02, (r[1] + r[3]) * 0.5)
	return Vector3.INF


## One physics step of the lava clock. True on the step the floor wakes the body.
func tick(player: CharacterBody3D, delta: float) -> bool:
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
	_pale.color.a = clampf(lava_s / GRACE_S, 0.0, 1.0) * 0.72
	if lava_s >= GRACE_S:
		woken = true
		return true
	return false


func _course(key: String, room: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Course_%s" % key.replace(".", "_").replace("@", "")
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var r: Array = room.rect
	var lo := Vector2(float(r[0]), float(r[1]))
	var hi := Vector2(float(r[2]), float(r[3]))
	var centre := (lo + hi) * 0.5
	var room_size := hi - lo
	# The middle: a table, as large as the room allows.
	var table := Vector2(minf(1.3, room_size.x - 1.2), minf(0.9, room_size.y - 1.2)).max(Vector2(0.6, 0.6))
	var placed: Array = []
	placed.append(_perch(node, "table", centre, table, 0.76))
	for door: Dictionary in room.doors:
		if bool(door.sealed):
			continue
		# Walk from the door's sill toward the table, always putting the next perch within a sure hop of the last:
		# connected by construction. A perch already standing there is hopped to; a wall or a neighbour moves the
		# next one rather than dropping it.
		var a: Array = door.aperture
		var current: Array = [a[0], a[1], a[2], a[3]]
		var current_top := SILL_H
		var table_rect: Array = placed[0].rect
		var guard := 0
		while gap(current, table_rect) > HOP_M and guard < 24:
			guard += 1
			var here := Vector2((float(current[0]) + float(current[2])) * 0.5, (float(current[1]) + float(current[3])) * 0.5)
			var dir := (centre - here).normalized()
			var near := _nearest_within(current, placed, HOP_M)
			if not near.is_empty() and gap(near.rect, table_rect) < gap(current, table_rect) - 0.05:
				current = near.rect
				current_top = float(near.top)
				continue
			var size := Vector2(rng.randf_range(PERCH_MIN, PERCH_MAX), rng.randf_range(PERCH_MIN, PERCH_MAX))
			var reach := _half_extent(current, dir) + HOP_M * 0.8 + maxf(size.x, size.y) * 0.5
			var at := _clamp_into(here + dir * reach, size, lo, hi, 0.12)
			var rect := _rect_of(at, size)
			var tries := 0
			while _overlaps(rect, placed) and tries < 6:
				tries += 1
				at = _clamp_into(here + dir * reach * (1.0 - 0.12 * tries), size * (1.0 - 0.08 * tries), lo, hi, 0.12)
				size *= 0.92
				rect = _rect_of(at, size)
			if _overlaps(rect, placed):
				break
			var top := clampf(current_top + rng.randf_range(-0.3, MAX_STEP_M * 0.8), 0.42, 1.15)
			var kind := "chair" if top < 0.55 else ("trunk" if top < 0.85 else "cabinet")
			placed.append(_perch(node, kind, at, size, top))
			current = rect
			current_top = top
	return node


func _perch(parent: Node3D, kind: String, at: Vector2, size: Vector2, top: float) -> Dictionary:
	var body := _box(parent, kind.capitalize(), Vector3(at.x, top * 0.5, at.y), Vector3(size.x, top, size.y), _wood)
	return {"rect": body.get_meta("rect"), "top": top}


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


static func _inside(rect: Array, lo: Vector2, hi: Vector2, margin: float) -> bool:
	return rect[0] >= lo.x + margin and rect[1] >= lo.y + margin and rect[2] <= hi.x - margin and rect[3] <= hi.y - margin


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
