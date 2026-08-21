extends Node
## PRESENTATION AUDIT — H13. One instrument, not another defect ledger.
##
##   godot --headless --path game res://tests/PresentationAudit.tscn   # data + physics passes
##   godot --path game res://tests/PresentationAudit.tscn              # + OrbitSweep (real window)
##
##   AUDIT_OUT=<existing abs dir>   writes presentation_audit.json (+ orbit_sweep.csv)
##   AUDIT_ORBIT_STEP=30            yaw step in degrees for the OrbitSweep
##   AUDIT_SKIP=a,b                 skip passes: overlap support art density walls ceilings orbit
##
## It boots the production BuildingRoot exactly as WalkTest does and then asks
## the LIVE scene the questions the 2026-08-20 data sweep could only ask the
## JSON (design/walkthrough_punchlist.md). Every pass prints `[AUDIT]` rows;
## the JSON carries the same rows for the punchlist. The process exits 0 when
## every requested pass ran and 1 only when the building failed to boot: an
## instrument that fails its own run on a finding stops being run.
##
## PASSES
##   overlap   live cross-class AABBs: marker-spawned prop meshes against each
##             other and against the baked rect boxes, penetration > 3 cm,
##             minus the assembly whitelist (a toaster sits IN a counter run)
##   support   > 3 cm support rays under free-standing marker props — floating
##             and clipping both, since both read as wrong
##   art       WalkTest's `[ART]` wall-art sweep, verbatim
##   density   dressing records per square metre by room; the bottom decile
##   walls     1.4 m rays across every authored wall at 0.25 m, minus authored
##             openings — a miss is a hole you can see through
##   ceilings  upward rays from a five-point grid per room, classified by WHO
##             owns the hit (this floor's ceiling, the slab above, nothing),
##             beside the data's ceiling-rect coverage and the production
##             visibility rule for the floor above at standing eye — the
##             `show_all_floors` toggle is applied for real and read back
##   orbit     (window only) eight stations × 360° yaw × three pitches:
##             LightRig granted set, lights the engine culler calls visible,
##             granted lights whose range sphere meets the frustum, and mean
##             luma per screen sixth — the three things that separate
##             visibility gating from rank churn from direction-dependence
##
## The 183-still harness is a separate command, rerun as part of the proof:
##   SHOT_DIR=<dir> SCREENSHOT_TEST_CAMERA_LIGHT=1 godot --path game res://tests/WalkthroughShots.tscn

const EYE := 1.62
const SUPPORT_TOLERANCE := 0.03
const OVERLAP_TOLERANCE := 0.03
const WALL_RAY_HEIGHT := 1.4
const WALL_SAMPLE_STEP := 0.25
const WALL_REACH := 0.35
const CEILING_REACH := 3.6
const ORBIT_PITCHES := [-20.0, 0.0, 20.0]
## perf_probe's interior stations, same coordinates, so light evidence and
## performance evidence cannot quietly measure different viewpoints.
const ORBIT_STATIONS := [
	{"name": "lobby", "pos": Vector3(-0.4, 1.72, 9.1)},
	{"name": "atrium eye", "pos": Vector3(0.0, 1.8, 0.2)},
	{"name": "corridor F04", "pos": Vector3(4.3, 11.25, 7.6)},
	{"name": "apartment 4B", "pos": Vector3(-8.1, 11.25, -3.2)},
	{"name": "roof", "pos": Vector3(-6.0, 21.4, 9.5)},
	{"name": "harukiya", "pos": Vector3(3.0, -1.39, 34.0)},
	{"name": "arcade cluster", "pos": Vector3(0.15, 1.72, 29.65)},
	{"name": "passage throat", "pos": Vector3(14.0, 1.68, 33.2)},
]
## Marker kinds that are dressing rather than infrastructure, signage or
## circulation. Lights are listed separately because they hang from things.
const PROP_KINDS := ["sink", "radiator", "shower", "mirror", "stove", "fridge",
		"toaster", "kitchen_linear", "bookshelf", "speaker", "kettle", "lamp",
		"monitor", "boxfan", "exhaust_fan", "washer", "wall_clock", "boiler",
		"laundry_airer", "chandelier", "songbook_terminal", "darts",
		"point_ball", "pendant_shade", "sconce_globe", "eye_pendant",
		"flush_dome", "cage_bulb"]
const LIGHT_KINDS := ["pendant_shade", "sconce_globe", "eye_pendant",
		"flush_dome", "cage_bulb", "chandelier", "street_lamp", "kitchen_linear"]
const FREE_STANDING := ["stove", "fridge", "toaster", "kettle", "bookshelf",
		"lamp", "boxfan", "washer", "boiler", "laundry_airer",
		"songbook_terminal", "monitor", "speaker", "point_ball"]
## Assemblies that legitimately interpenetrate. `*` means "with anything".
## The toaster/dishrack and booth/mirror leads are deliberately NOT here.
const ASSEMBLY_WHITELIST := [
	# The sink marker's mesh is the whole unit — basin, drainer and splash —
	# so a kettle on the drainer "overlaps" it by the drainer's depth.
	["kettle", "sink"], ["toaster", "sink"], ["mug", "sink"],
	["dishrack", "sink"], ["towel", "sink"], ["bottles", "sink"],
	["mirror", "sink"], ["shower", "toilet"], ["radiator", "sill"],
	["stove", "stove_plinth"],
	["pipe", "*"], ["switch", "*"], ["door", "*"], ["electrical_junction", "*"],
	["lamp", "nightstand"], ["lamp", "desk"], ["lamp", "table_rect"],
	["papers", "desk"], ["papers", "table_rect"], ["coffee", "sofa"],
	["bookpile", "shelf"], ["bookpile", "bookshelf"], ["bottles", "shelf"],
	["nightstand", "bed"], ["chair", "desk"], ["chair", "table_rect"],
	["chair", "table_round"], ["plant", "table_round"], ["plant", "shelf"],
	["plant", "nightstand"], ["headphones", "desk"], ["radio", "shelf"],
	["radio", "nightstand"], ["mug", "desk"], ["mug", "table_rect"],
	["mug", "table_round"], ["mug", "nightstand"], ["monitor", "desk"],
	["speaker", "shelf"], ["speaker", "bookshelf"], ["wall_clock", "*"],
	["kitchen_linear", "counter"], ["kitchen_linear", "splashback"],
]

var root
var layout: Dictionary = {}
var _out_dir := ""
var _skip: PackedStringArray = []
var _results: Dictionary = {}
var _nodes_by_name: Dictionary = {}
var _id_prefix := RegEx.new()
var _id_suffix := RegEx.new()
var _frustum_inside_sign := -1.0


func _ready() -> void:
	# Same boot discipline as WalkTest: canonical 03:00, never the real save,
	# every case seeded the way a first launch does.
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		var definition: Dictionary = RealityCases.definitions[case_id]
		RealityState.ensure_case(case_id,
				str(definition.get("resident_id", "")))
	_out_dir = OS.get_environment("AUDIT_OUT")
	_skip = OS.get_environment("AUDIT_SKIP").split(",", false)
	_id_prefix.compile("^(B1|F0\\d|ROOF|[1-6][A-D]|b1|f0\\d)_")
	_id_suffix.compile("(_?\\d+)+$")
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	layout = root.layout
	if layout.is_empty() or not layout.has("floors"):
		printerr("[AUDIT] BuildingRoot produced no layout; nothing to audit")
		get_tree().quit(1)
		return
	root.show_all_floors = true
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_index_nodes(root)
	var headless := DisplayServer.get_name() == "headless"
	print("[AUDIT] presentation audit on %s, %d floors, %d named nodes, %s"
			% [RenderingServer.get_current_rendering_method(),
			(layout.floors as Array).size(), _nodes_by_name.size(),
			"headless (physics + data passes)" if headless
			else "windowed (+ OrbitSweep)"])
	if _wants("overlap"):
		_overlap_pass()
	if _wants("support"):
		_support_pass()
	if _wants("art"):
		_wall_art_report()
	if _wants("density"):
		_density_pass()
	if _wants("walls"):
		_wall_gap_pass()
	if _wants("ceilings"):
		_ceiling_pass()
	if _wants("orbit") and not headless:
		await _orbit_pass()
	elif _wants("orbit"):
		print("[AUDIT][ORBIT] skipped: needs a real window (run without --headless)")
	_write_results()
	print("[AUDIT] DONE — %d passes: %s" % [_results.size(),
			", ".join(_results.keys())])
	get_tree().quit(0)


func _wants(pass_name: String) -> bool:
	return not _skip.has(pass_name)


## ---------------------------------------------------------------- shared

func _index_nodes(node: Node) -> void:
	if not _nodes_by_name.has(node.name):
		_nodes_by_name[node.name] = node
	for child in node.get_children():
		_index_nodes(child)


## World-space bounds of what a prop actually DRAWS, which is what the eye
## judges — not its marker footprint, and not a light's range box.
static func _world_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var visuals: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	visuals.append_array(node.find_children("*", "MultiMeshInstance3D", true, false))
	visuals.append_array(node.find_children("*", "CSGShape3D", true, false))
	if node is MeshInstance3D or node is CSGShape3D:
		visuals.append(node)
	for visual in visuals:
		var vi := visual as VisualInstance3D
		if vi == null or not vi.visible:
			continue
		var local: AABB = vi.get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var xf := vi.global_transform
		for i in 8:
			var corner := xf * local.get_endpoint(i)
			if first:
				result = AABB(corner, Vector3.ZERO)
				first = false
			else:
				result = result.expand(corner)
	return result


static func _penetration(a: AABB, b: AABB) -> float:
	var depth := INF
	for axis in 3:
		var overlap := minf(a.end[axis], b.end[axis]) \
				- maxf(a.position[axis], b.position[axis])
		depth = minf(depth, overlap)
	return depth


func _whitelisted(class_a: String, class_b: String) -> bool:
	# Hung and recessed fixtures live inside soffits, canopies and ceilings
	# by construction; their overlaps are not a dressing finding.
	if LIGHT_KINDS.has(class_a) or LIGHT_KINDS.has(class_b):
		return true
	for pair in ASSEMBLY_WHITELIST:
		var p0 := str(pair[0])
		var p1 := str(pair[1])
		if (p0 == class_a and (p1 == "*" or p1 == class_b)) \
				or (p0 == class_b and (p1 == "*" or p1 == class_a)):
			return true
	return false


## "B1_hopper" -> "hopper", "4B_dishrack_01" -> "dishrack". A label for
## ranking, not an identity.
func _box_class(id: String) -> String:
	var s := _id_prefix.sub(id, "")
	s = _id_suffix.sub(s, "")
	return s if not s.is_empty() else id


func _floor_for_y(y: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for fl in layout.floors:
		var d := absf(y - float(fl.z))
		if d < best_d:
			best_d = d
			best = fl
	return best


## Which floor node owns a scene node — the ancestor that is one of
## BuildingRoot.floor_nodes — or "" for root-owned props and site geometry.
func _owning_floor(node: Node) -> String:
	var floors: Dictionary = root.floor_nodes
	var cursor := node
	while cursor != null:
		for fid in floors:
			if floors[fid] == cursor:
				return str(fid)
		cursor = cursor.get_parent()
	return ""


static func _point_in_rect(x: float, y: float, rect: Array) -> bool:
	return x >= float(rect[0]) and x <= float(rect[2]) \
			and y >= float(rect[1]) and y <= float(rect[3])


## Live marker props with a drawn AABB: {id, kind, floor, aabb, node}.
func _marker_props() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fl in layout.floors:
		for m in fl.markers:
			var kind := str(m.kind)
			if not PROP_KINDS.has(kind):
				continue
			var node: Node = _nodes_by_name.get(str(m.id))
			if node == null or not (node is Node3D):
				continue
			var aabb := _world_aabb(node)
			if aabb.size == Vector3.ZERO:
				continue
			out.append({"id": str(m.id), "kind": kind, "floor": str(fl.id),
					"aabb": aabb, "node": node, "unit": str(m.get("unit", ""))})
	return out


## Baked rect boxes from the layout (the only furniture records with a size):
## {id, class, floor, aabb}. Pipes, switches, slats and site batches excluded.
func _data_boxes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fl in layout.floors:
		var fz := float(fl.z)
		for r in fl.furniture:
			if not r.has("rect") or r.has("slat") or r.has("asm"):
				continue
			if r.has("zone") or r.has("batch"):
				continue
			var rect: Array = r.rect
			var z0 := float(r.get("z0", 0.0))
			var h := float(r.get("h", 0.0))
			if h <= 0.0:
				continue
			var position := Vector3(float(rect[0]), fz + z0, -float(rect[3]))
			var size := Vector3(float(rect[2]) - float(rect[0]), h,
					float(rect[3]) - float(rect[1]))
			out.append({"id": str(r.id), "class": _box_class(str(r.id)),
					"floor": str(fl.id), "aabb": AABB(position, size)})
	return out


## ---------------------------------------------------------------- overlap

func _overlap_pass() -> void:
	var props := _marker_props()
	var boxes := _data_boxes()
	var rows: Array[Dictionary] = []
	var same_class := 0
	var whitelisted := 0
	for i in props.size():
		var a: Dictionary = props[i]
		for j in range(i + 1, props.size()):
			var b: Dictionary = props[j]
			if a.floor != b.floor:
				continue
			var depth := _penetration(a.aabb, b.aabb)
			if depth <= OVERLAP_TOLERANCE:
				continue
			if a.kind == b.kind:
				same_class += 1
				continue
			if _whitelisted(a.kind, b.kind):
				whitelisted += 1
				continue
			rows.append(_overlap_row(a.id, a.kind, b.id, b.kind, a.floor, depth,
					a.aabb.intersection(b.aabb)))
		for box in boxes:
			if box.floor != a.floor:
				continue
			var depth := _penetration(a.aabb, box.aabb)
			if depth <= OVERLAP_TOLERANCE:
				continue
			if _whitelisted(a.kind, box["class"]):
				whitelisted += 1
				continue
			rows.append(_overlap_row(a.id, a.kind, box.id, box["class"], a.floor,
					depth, a.aabb.intersection(box.aabb)))
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x.volume) > float(y.volume))
	print("[AUDIT][OVERLAP] %d live props vs %d props + %d baked boxes: %d cross-class "
			% [props.size(), props.size(), boxes.size(), rows.size()]
			+ "interpenetrations > %.0f cm (%d whitelisted assemblies, %d same-class skipped)"
			% [OVERLAP_TOLERANCE * 100.0, whitelisted, same_class])
	for row in rows.slice(0, 40):
		print("[AUDIT][OVERLAP] %s  %s(%s) x %s(%s)  depth %.3f m  volume %.4f m3"
				% [row.floor, row.a, row.class_a, row.b, row.class_b,
				row.depth, row.volume])
	_results["overlap"] = {"props": props.size(), "boxes": boxes.size(),
			"whitelisted": whitelisted, "same_class": same_class, "rows": rows}


func _overlap_row(a: String, class_a: String, b: String, class_b: String,
		floor_id: String, depth: float, shared: AABB) -> Dictionary:
	return {"a": a, "class_a": class_a, "b": b, "class_b": class_b,
			"floor": floor_id, "depth": depth, "volume": shared.get_volume(),
			"at": shared.get_center()}


## ---------------------------------------------------------------- support

func _support_pass() -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var rows: Array[Dictionary] = []
	var checked := 0
	for prop in _marker_props():
		if not FREE_STANDING.has(prop.kind):
			continue
		checked += 1
		var node: Node3D = prop.node
		var aabb: AABB = prop.aabb
		# The marker origin is where the generator believes the base sits. The
		# mesh AABB bottom is NOT that: a cord, skirt or cable coil hangs
		# below the base by design, so it is reported only as reach.
		var base: Vector3 = node.global_position
		var reach_below := base.y - aabb.position.y
		var exclude: Array[RID] = []
		for body in node.find_children("*", "CollisionObject3D", true, false):
			exclude.append((body as CollisionObject3D).get_rid())
		if node is CollisionObject3D:
			exclude.append((node as CollisionObject3D).get_rid())
		var query := PhysicsRayQueryParameters3D.create(
				base + Vector3(0.0, 0.30, 0.0), base - Vector3(0.0, 0.50, 0.0))
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		var verdict := ""
		var gap := NAN
		if hit.is_empty():
			verdict = "no collider within 0.5 m below the base"
		else:
			gap = base.y - float(hit.position.y)
			if gap > SUPPORT_TOLERANCE:
				verdict = "base floats %.0f mm above %s" % [gap * 1000.0,
						str(hit.collider.name)]
			elif gap < -SUPPORT_TOLERANCE:
				verdict = "base sunk %.0f mm into %s" % [-gap * 1000.0,
						str(hit.collider.name)]
		if verdict.is_empty():
			continue
		if reach_below > SUPPORT_TOLERANCE:
			verdict += " (mesh reaches %.0f mm below the base)" % (reach_below * 1000.0)
		rows.append({"id": prop.id, "kind": prop.kind, "floor": prop.floor,
				"unit": prop.unit, "gap": gap, "reach_below": reach_below,
				"verdict": verdict,
				"support": str(hit.collider.name) if not hit.is_empty() else "",
				"at": base})
	print("[AUDIT][SUPPORT] %d free-standing props rayed at their authored base: %d outside +/- %.0f mm"
			% [checked, rows.size(), SUPPORT_TOLERANCE * 1000.0])
	for row in rows:
		print("[AUDIT][SUPPORT] %s %s %s (%s): %s" % [row.floor, row.id, row.kind,
				row.unit, row.verdict])
	_results["support"] = {"checked": checked, "rows": rows}


## ---------------------------------------------------------------- art
## WalkTest._wall_art_report, verbatim except for the suite's _check line.

func _wall_art_report() -> void:
	var space := get_viewport().world_3d.direct_space_state
	var blocked: Array[String] = []
	var unbacked: Array[String] = []
	var total := 0
	for group in ["character_memories", "character_wall_art", "hallway_art"]:
		for art in get_tree().get_nodes_in_group(group):
			if not (art is Node3D):
				continue
			total += 1
			var node: Node3D = art
			var origin: Vector3 = node.global_position
			# The quad faces local +Z, so this is the side you must stand
			# on to see the picture at all.
			var out: Vector3 = node.global_transform.basis.z.normalized()
			var front := PhysicsRayQueryParameters3D.create(
					origin + out * 0.05, origin + out * 0.34)
			if not space.intersect_ray(front).is_empty():
				blocked.append(str(node.name))
			var back := PhysicsRayQueryParameters3D.create(
					origin, origin - out * 0.40)
			if space.intersect_ray(back).is_empty():
				unbacked.append(str(node.name))
	print("[ART] %d pieces; %d with something close in front, %d with "
			% [total, blocked.size(), unbacked.size()] +
			"nothing solid behind")
	if not blocked.is_empty():
		print("[ART] close in front: %s" % [blocked])
	if not unbacked.is_empty():
		print("[ART] nothing behind: %s" % [unbacked])
	_results["art"] = {"pieces": total, "blocked": blocked, "unbacked": unbacked}


## ---------------------------------------------------------------- density

func _density_pass() -> void:
	var rows: Array[Dictionary] = []
	for fl in layout.floors:
		var fid := str(fl.id)
		var dressing: Array[Vector2] = []
		for r in fl.furniture:
			if r.has("slat") or r.has("zone") or r.has("batch"):
				continue
			var asm := str(r.get("asm", ""))
			if asm == "pipe" or asm == "switch":
				continue
			if r.has("at"):
				dressing.append(Vector2(float(r.at[0]), float(r.at[1])))
			elif r.has("rect"):
				var rect: Array = r.rect
				dressing.append(Vector2((float(rect[0]) + float(rect[2])) * 0.5,
						(float(rect[1]) + float(rect[3])) * 0.5))
		for m in fl.markers:
			if PROP_KINDS.has(str(m.kind)) and not LIGHT_KINDS.has(str(m.kind)):
				dressing.append(Vector2(float(m.pos[0]), float(m.pos[1])))
		for room in fl.rooms:
			var kind := str(room.get("kind", ""))
			if kind.contains("shaft") or kind.contains("elev") \
					or kind.contains("stair") or kind.contains("well") \
					or kind.contains("void"):
				continue
			var rect: Array = room.rect
			var area := (float(rect[2]) - float(rect[0])) \
					* (float(rect[3]) - float(rect[1]))
			if area <= 0.5:
				continue
			var count := 0
			for p in dressing:
				if _point_in_rect(p.x, p.y, rect):
					count += 1
			rows.append({"room": str(room.id), "floor": fid, "kind": kind,
					"area": area, "records": count, "per_m2": count / area})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.per_m2) < float(b.per_m2))
	var decile := maxi(1, int(ceil(rows.size() * 0.1)))
	var median := float(rows[rows.size() / 2].per_m2) if not rows.is_empty() else 0.0
	print("[AUDIT][DENSITY] %d rooms; median %.2f dressing records / m2; bottom decile (%d):"
			% [rows.size(), median, decile])
	for row in rows.slice(0, decile):
		print("[AUDIT][DENSITY] %s %s (%s) %.1f m2: %d records, %.2f / m2"
				% [row.floor, row.room, row.kind, row.area, row.records, row.per_m2])
	_results["density"] = {"rooms": rows.size(), "median_per_m2": median,
			"bottom_decile": rows.slice(0, decile), "all": rows}


## ---------------------------------------------------------------- walls

func _wall_gap_pass() -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var rows: Array[Dictionary] = []
	var rays := 0
	var openings_skipped := 0
	var half_x := float(layout.meta.footprint[0]) * 0.5
	var half_y := float(layout.meta.footprint[1]) * 0.5
	for fl in layout.floors:
		var fid := str(fl.id)
		var floor_gaps := 0
		var wall_index := -1
		for wall in fl.walls:
			wall_index += 1
			var a := Vector2(float(wall.a[0]), float(wall.a[1]))
			var b := Vector2(float(wall.b[0]), float(wall.b[1]))
			var length := a.distance_to(b)
			if length < 0.4:
				continue
			var height := float(wall.get("h", 3.02))
			if height < WALL_RAY_HEIGHT + 0.05:
				continue
			var base := float(wall.get("z", fl.z))
			var dir := (b - a) / length
			var normal := Vector2(-dir.y, dir.x)
			var exterior := (absf(a.x) > half_x - 0.3 and absf(b.x) > half_x - 0.3) \
					or (absf(a.y) > half_y - 0.3 and absf(b.y) > half_y - 0.3)
			var s := 0.15
			while s <= length - 0.15:
				var p := a + dir * s
				if _in_authored_opening(wall, s, WALL_RAY_HEIGHT):
					openings_skipped += 1
					s += WALL_SAMPLE_STEP
					continue
				rays += 1
				var from := GameBoot.b2g([p.x + normal.x * WALL_REACH,
						p.y + normal.y * WALL_REACH, base + WALL_RAY_HEIGHT])
				var to := GameBoot.b2g([p.x - normal.x * WALL_REACH,
						p.y - normal.y * WALL_REACH, base + WALL_RAY_HEIGHT])
				var hit := space.intersect_ray(
						PhysicsRayQueryParameters3D.create(from, to))
				if hit.is_empty():
					floor_gaps += 1
					rows.append({"floor": fid, "wall": wall_index,
							"exterior": exterior, "mat": str(wall.get("mat", "")),
							"along_m": s, "length_m": length,
							"at": GameBoot.b2g([p.x, p.y, base + WALL_RAY_HEIGHT])})
				s += WALL_SAMPLE_STEP
		if floor_gaps > 0:
			print("[AUDIT][WALLS] %s: %d see-through samples" % [fid, floor_gaps])
	print("[AUDIT][WALLS] %d rays at %.1f m across authored walls (%d samples inside authored openings skipped): %d see-through"
			% [rays, WALL_RAY_HEIGHT, openings_skipped, rows.size()])
	# Group by wall so one missing wall is one row, not forty.
	var by_wall := {}
	for row in rows:
		var key := "%s#%d" % [row.floor, row.wall]
		if not by_wall.has(key):
			by_wall[key] = {"floor": row.floor, "wall": row.wall,
					"exterior": row.exterior, "mat": row.mat, "length_m": row.length_m,
					"samples": 0, "first_at": row.at}
		by_wall[key].samples += 1
	for key in by_wall:
		var w: Dictionary = by_wall[key]
		print("[AUDIT][WALLS] %s wall %d (%s, %.1f m, %s): %d of ~%d samples see through, first at %s"
				% [w.floor, w.wall, w.mat, w.length_m,
				"exterior" if w.exterior else "interior", w.samples,
				int(w.length_m / WALL_SAMPLE_STEP), _v3(w.first_at)])
	_results["walls"] = {"rays": rays, "openings_skipped": openings_skipped,
			"gaps": rows.size(), "walls": by_wall.values()}


## An authored opening's span along the wall, read permissively: `at` may be
## the centre or the start, so the span [at - w/2, at + w] covers both.
static func _in_authored_opening(wall: Dictionary, along: float,
		height: float) -> bool:
	for opening in wall.get("openings", []):
		var at := float(opening.get("at", 0.0))
		var w := float(opening.get("w", 0.0))
		var sill := float(opening.get("sill", 0.0))
		var h := float(opening.get("h", 2.1))
		if along < at - w * 0.5 - 0.05 or along > at + w + 0.05:
			continue
		if height < sill - 0.05 or height > sill + h + 0.05:
			continue
		return true
	return false


## ---------------------------------------------------------------- ceilings

func _ceiling_pass() -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var rows: Array[Dictionary] = []
	var levels: Dictionary = layout.meta.levels
	var floor_ids: Array = levels.keys()
	floor_ids.sort_custom(func(a, b): return float(levels[a]) < float(levels[b]))
	for fl in layout.floors:
		var fid := str(fl.id)
		if fid == "ROOF":
			continue
		var fz := float(fl.z)
		var above := ""
		var idx := floor_ids.find(fid)
		if idx >= 0 and idx + 1 < floor_ids.size():
			above = str(floor_ids[idx + 1])
		for room in fl.rooms:
			var kind := str(room.get("kind", ""))
			if kind.contains("shaft") or kind.contains("elev") \
					or kind.contains("well") or kind.contains("void"):
				continue
			var rect: Array = room.rect
			var x0 := float(rect[0])
			var y0 := float(rect[1])
			var x1 := float(rect[2])
			var y1 := float(rect[3])
			if (x1 - x0) * (y1 - y0) < 1.0:
				continue
			var coverage := _ceiling_coverage(fl, rect)
			var grid := [Vector2(0.5, 0.5), Vector2(0.25, 0.25), Vector2(0.75, 0.25),
					Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
			# A ceiling sits at +3.015 and the slab above at +3.02: the eye
			# cannot tell them apart and neither can a ray, so classify by
			# height and by the data, and keep WHO was hit as evidence.
			var closed := 0
			var tall := 0
			var none := 0
			var tall_h := 0.0
			var owners := {}
			var open_in := {}
			var eye_sample := Vector3.ZERO
			for g in grid:
				var px := lerpf(x0, x1, g.x)
				var py := lerpf(y0, y1, g.y)
				var eye := GameBoot.b2g([px, py, fz + EYE])
				eye_sample = eye
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
						eye, eye + Vector3.UP * CEILING_REACH))
				if hit.is_empty():
					none += 1
					var host := _smallest_other_room(fl, str(room.id), px, py)
					open_in[host] = int(open_in.get(host, 0)) + 1
					continue
				var owner := _owning_floor(hit.collider)
				var name := "%s:%s" % [owner if not owner.is_empty() else "root",
						str(hit.collider.name)]
				owners[name] = int(owners.get(name, 0)) + 1
				var hit_h := float(hit.position.y) - fz
				if hit_h < 3.1:
					closed += 1
				else:
					tall += 1
					tall_h = maxf(tall_h, hit_h)
			# The production rule for the floor above at THIS eye, applied for
			# real: flip show_all_floors off, let the root decide, read back.
			var above_visible := true
			if not above.is_empty() and root.floor_nodes.has(above):
				root.show_all_floors = false
				root._apply_visibility(eye_sample)
				above_visible = bool(root.floor_nodes[above].visible)
				root.show_all_floors = true
				root._apply_visibility(eye_sample)
			if closed == grid.size() and coverage > 0.98:
				continue
			var verdict := ""
			if none > 0:
				var hosts: Array[String] = []
				for host in open_in:
					hosts.append("%d in %s" % [int(open_in[host]), str(host)])
				var in_well := 0
				for host in open_in:
					if kind == "atrium" or str(host).contains("ATRIUM"):
						in_well += int(open_in[host])
				var reading := "open light well by design"
				if in_well == 0:
					reading = "generator omission"
				elif in_well < none:
					reading = "%d in the light well by design, %d OUTSIDE it — check" % [
							in_well, none - in_well]
				verdict = "%d/%d rays find nothing within %.1f m above the eye (%s) — %s" % [
						none, grid.size(), CEILING_REACH, ", ".join(hosts), reading]
			elif tall > 0:
				verdict = "%d/%d rays reach %.2f m — a void above ceiling height" % [
						tall, grid.size(), tall_h]
			else:
				verdict = "data covers %.0f%%; every ray still meets a surface at ceiling height, so the %s slab underside closes the rest — %s" % [
						coverage * 100.0, above if not above.is_empty() else "upper",
						"VISIBLE at standing eye (reads as bare ceiling)" if above_visible
						else "HIDDEN by the visibility gate at standing eye (reads as a hole)"]
			rows.append({"floor": fid, "room": str(room.id), "kind": kind,
					"data_coverage": coverage, "closed": closed, "tall": tall,
					"none": none, "open_in": open_in,
					"above_visible_at_eye": above_visible,
					"owners": owners, "verdict": verdict})
	print("[AUDIT][CEILINGS] %d rooms where data coverage or rays fall short of a closed ceiling:" % rows.size())
	for row in rows:
		print("[AUDIT][CEILINGS] %s %s (%s) data %.0f%%: %s  hits %s"
				% [row.floor, row.room, row.kind, float(row.data_coverage) * 100.0,
				row.verdict, str(row.owners)])
	_results["ceilings"] = {"rows": rows}


## The smallest OTHER room on the floor holding a point, or "no room" — an
## open ray inside the atrium rect is a light well, not a missing ceiling.
static func _smallest_other_room(fl: Dictionary, room_id: String, x: float,
		y: float) -> String:
	var best := "no room"
	var best_area := INF
	for other in fl.rooms:
		if str(other.id) == room_id:
			continue
		var r: Array = other.rect
		if not _point_in_rect(x, y, r):
			continue
		var area := (float(r[2]) - float(r[0])) * (float(r[3]) - float(r[1]))
		if area < best_area:
			best_area = area
			best = str(other.id)
	return best


## Fraction of a room rect under ANY ceiling rect on its floor, sampled at
## 0.25 m. Any rect, not only the ones that name this room: a hall ceiling
## that happens to cover a closet is still a ceiling.
static func _ceiling_coverage(fl: Dictionary, rect: Array) -> float:
	var ceilings: Array = fl.get("ceilings", [])
	var covered := 0
	var total := 0
	var x := float(rect[0]) + 0.125
	while x < float(rect[2]):
		var y := float(rect[1]) + 0.125
		while y < float(rect[3]):
			total += 1
			for c in ceilings:
				if _point_in_rect(x, y, c.rect):
					covered += 1
					break
			y += 0.25
		x += 0.25
	return float(covered) / float(total) if total > 0 else 0.0


## ---------------------------------------------------------------- orbit

func _orbit_pass() -> void:
	var step := 30.0
	var env_step := OS.get_environment("AUDIT_ORBIT_STEP")
	if not env_step.is_empty():
		step = maxf(5.0, float(env_step))
	var cam := Camera3D.new()
	cam.fov = 72.0
	add_child(cam)
	cam.make_current()
	# Hand the rig this camera, or it keeps budgeting around the player parked
	# in the lobby (WalkthroughShots learned this from perf_probe).
	root.view_override = cam
	_hide_overlays(root)
	var rig = root.light_rig
	var world := get_viewport().find_world_3d()
	# Which way do Camera3D.get_frustum() planes face? Decide empirically from
	# a point 5 m straight ahead rather than from memory of the engine source.
	cam.global_position = ORBIT_STATIONS[0].pos
	await RenderingServer.frame_post_draw
	var ahead := cam.global_position - cam.global_transform.basis.z * 5.0
	var positive := 0
	for plane in cam.get_frustum():
		if plane.distance_to(ahead) > 0.0:
			positive += 1
	# Outward-facing planes put an inside point at negative distance to all
	# six; inward-facing planes put it at positive distance to all six.
	_frustum_inside_sign = -1.0 if positive == 0 else 1.0
	print("[AUDIT][ORBIT] frustum planes face %s (probe ahead: %d/6 positive)"
			% ["outward" if positive == 0 else "inward", positive])
	var csv: Array[String] = ["station,yaw,pitch,granted,in_frustum_expected,culled_visible,missing_box,missing_centre,s0,s1,s2,s3,s4,s5"]
	var summaries: Array[Dictionary] = []
	for station in ORBIT_STATIONS:
		cam.global_position = station.pos
		cam.rotation = Vector3.ZERO
		await get_tree().create_timer(0.45).timeout
		var granted_sets := {}
		var granted_frames := {}
		var granted_energy := {}
		var max_missing := 0
		var missing_names := {}
		var centre_missing_total := 0
		var centre_missing_names := {}
		var luma_min := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
		var luma_max := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var frames := 0
		for pitch in ORBIT_PITCHES:
			var yaw := 0.0
			while yaw < 360.0:
				cam.rotation = Vector3(deg_to_rad(float(pitch)), deg_to_rad(yaw), 0.0)
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				frames += 1
				var granted: Array[String] = []
				var expected := 0
				var missing := 0
				var centre_missing := 0
				var culled := {}
				for oid in RenderingServer.instances_cull_convex(cam.get_frustum(),
						world.scenario):
					var inst := instance_from_id(oid)
					if inst is Light3D and (inst as Light3D).visible:
						culled[inst] = true
				var planes := cam.get_frustum()
				for fixture in rig._controlled_lights():
					var source: Light3D = fixture.light
					if source == null or not source.visible or source.light_energy <= 0.05:
						continue
					granted.append(str(fixture.name))
					granted_frames[str(fixture.name)] = int(granted_frames.get(
							str(fixture.name), 0)) + 1
					granted_energy[str(fixture.name)] = source.light_energy
					# The light's OWN bounds against the frustum — a spot's box
					# is far smaller than its range sphere, and the culler tests
					# exactly this box.
					var inside := _aabb_meets_frustum(source.global_transform,
							source.get_aabb(), planes, _frustum_inside_sign)
					if inside:
						expected += 1
						if not culled.has(source):
							missing += 1
							missing_names[str(fixture.name)] = true
							# The strict form: a light whose CENTRE is inside
							# every plane cannot be a corner-case of the box
							# test. If the culler dropped one of these, the
							# engine really did hide a light in view.
							var centre_in := true
							for plane in planes:
								if plane.distance_to(source.global_position) 										* _frustum_inside_sign < 0.0:
									centre_in = false
									break
							if centre_in:
								centre_missing += 1
								centre_missing_names[str(fixture.name)] = true
				granted.sort()
				granted_sets[",".join(granted)] = true
				max_missing = maxi(max_missing, missing)
				centre_missing_total += centre_missing
				var sixths := _screen_sixths()
				for i in 6:
					luma_min[i] = minf(luma_min[i], sixths[i])
					luma_max[i] = maxf(luma_max[i], sixths[i])
				csv.append("%s,%.0f,%.0f,%d,%d,%d,%d,%d,%s" % [station.name, yaw, pitch,
						granted.size(), expected, culled.size(), missing, centre_missing,
						",".join(sixths.map(func(v): return "%.3f" % v))])
				yaw += step
		# A fixture lit in some frames and not others at a FIXED eye is a
		# fixture crossing the 0.05 energy line over time (flicker), not a
		# direction-dependent grant: name it so nobody reads it as churn.
		var partial: Array[String] = []
		for fixture_name in granted_frames:
			var lit := int(granted_frames[fixture_name])
			if lit < frames:
				partial.append("%s lit %d/%d frames (last energy %.3f)" % [
						fixture_name, lit, frames, float(granted_energy[fixture_name])])
		var summary := {"station": station.name, "frames": frames,
				"granted_sets": granted_sets.size(), "partial_fixtures": partial,
				"max_missing_box": max_missing,
				"missing_box_fixtures": missing_names.keys(),
				"centre_inside_dropped_total": centre_missing_total,
				"centre_inside_dropped_fixtures": centre_missing_names.keys(),
				"luma_min": luma_min,
				"luma_max": luma_max}
		summaries.append(summary)
		print("[AUDIT][ORBIT] %s: %d frames, granted set %s%s; "
				% [station.name, frames,
				"STABLE" if granted_sets.size() == 1 else "varies (%d distinct)" % granted_sets.size(),
				(" — " + ", ".join(partial)) if not partial.is_empty() else ""]
				+ "granted lights with CENTRE in view dropped by the culler: %d%s (box-test edge cases: max %d/frame); luma sixths min %s max %s"
				% [centre_missing_total,
				(" " + str(centre_missing_names.keys())) if centre_missing_total > 0 else "",
				max_missing,
				str(luma_min.map(func(v): return "%.2f" % v)),
				str(luma_max.map(func(v): return "%.2f" % v))])
	root.view_override = null
	_results["orbit"] = {"step_deg": step, "stations": summaries}
	if not _out_dir.is_empty():
		var f := FileAccess.open(_out_dir.path_join("orbit_sweep.csv"), FileAccess.WRITE)
		if f:
			f.store_string("\n".join(csv) + "\n")
			print("[AUDIT][ORBIT] wrote %s (%d rows)" % [
					_out_dir.path_join("orbit_sweep.csv"), csv.size() - 1])


## Separating-plane test: the box is outside the frustum only if all eight
## corners sit beyond one plane. Same conservative answer the culler gives.
static func _aabb_meets_frustum(xf: Transform3D, local: AABB,
		planes: Array[Plane], inside_sign: float) -> bool:
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(xf * local.get_endpoint(i))
	for plane in planes:
		var all_out := true
		for corner in corners:
			if plane.distance_to(corner) * inside_sign >= 0.0:
				all_out = false
				break
		if all_out:
			return false
	return true


## Mean luma of each screen sixth (3 columns x 2 rows), from a 96 x 64 resample.
func _screen_sixths() -> Array:
	var image := get_viewport().get_texture().get_image()
	image.resize(96, 64, Image.INTERPOLATE_BILINEAR)
	var sums := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var counts := [0, 0, 0, 0, 0, 0]
	for y in 64:
		for x in 96:
			var c := image.get_pixel(x, y)
			var idx := (x * 3 / 96) + (y * 2 / 64) * 3
			sums[idx] += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			counts[idx] += 1
	var out := []
	for i in 6:
		out.append(sums[i] / maxi(1, counts[i]))
	return out


func _hide_overlays(node: Node) -> void:
	for c in node.get_children():
		if c is CanvasLayer:
			c.visible = false
		_hide_overlays(c)


## ---------------------------------------------------------------- output

static func _v3(v: Variant) -> String:
	if not (v is Vector3):
		return str(v)
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _write_results() -> void:
	if _out_dir.is_empty():
		return
	var path := _out_dir.path_join("presentation_audit.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("[AUDIT] cannot write %s (does the directory exist?)" % path)
		return
	f.store_string(JSON.stringify(_jsonable(_results), "  "))
	print("[AUDIT] wrote %s" % path)


## JSON.stringify renders Vector3/AABB as strings already; nodes must not
## reach it, and Dictionaries with Vector keys do not exist here.
func _jsonable(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for k in value:
			if k == "node":
				continue
			out[str(k)] = _jsonable(value[k])
		return out
	if value is Array:
		var out := []
		for v in value:
			out.append(_jsonable(v))
		return out
	if value is Vector3 or value is AABB or value is Vector2:
		return _v3(value) if value is Vector3 else str(value)
	if value is Object:
		return str(value)
	return value
