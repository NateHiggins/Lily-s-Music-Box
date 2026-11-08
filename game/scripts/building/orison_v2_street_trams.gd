class_name OrisonV2StreetTrams
extends Node3D
## The trolley line on the Orison's avenue (Lily's ruling trams_route, 2026-11-08; design/V2_STREET_TRAMS_2026-11-08.md).
##
## The el station over the avenue is Queensboro Plaza, where Queens Boulevard begins, and in 1929 its trolleys ran
## on the street under the el. The cars are period traffic: this registers them with OrisonV2StreetTraffic as a
## rail kind, so they queue, stop at the T, yield and warn exactly as the street does. Every car on a track takes
## the same path (rail_journey), so the rails and the contact wire are laid along that path, sampled from the
## traffic's own pose function, and never drift from the cars. Arcs flash where the trolley wheel meets the wire,
## more often on aurora and STEVE nights (Lily's sun_storms ruling, 2026-11-04) and in the wet.

const DATA := "res://data/orison_v2/exterior/street_trams.json"
const SCHEMA := "orison.v2.street-trams.v1"
const StreetSurface := preload("res://scripts/building/orison_v2_city_streets.gd")
const LIT := ["lamp_lit", "saloon_lit", "lamp_tail", "window"]
const FLASHES := 3

var data: Dictionary = {}
var traffic: OrisonV2StreetTraffic
var world: Node
var kind_index := -1
## Per track (0 westbound, 1 eastbound): street-frame points along the car's path, and the yaw at each.
var paths: Array = [[], []]
var yaws: Array = [[], []]
var arc_count := 0
var built := false
var _due: Array[float] = [0.0, 0.0]
var _materials: Dictionary = {}
var _pole_mesh: Mesh
var _rosette_mesh: Mesh
var _rng := RandomNumberGenerator.new()
var _flashes: Array[Dictionary] = []
var _quiet := 0.0


static func load_table(path := DATA) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if source is not Dictionary or source.get("schema") != SCHEMA or source.get("frame") != "ORISON_FRONT_DOOR_THRESHOLD":
		return {}
	for key: String in ["stock", "finishes", "kind", "class", "headway_minutes", "line", "supports", "far_kerb_z",
			"near_kerb_z", "orison_facade_z", "cross", "arcs"]:
		if not source.has(key):
			return {}
	if (source.headway_minutes as Array).size() != 24:
		return {}
	# The car is read by the traffic as one of its own kinds, and its class as one of its classes: every field the
	# traffic reads must be here.
	for key: String in ["id", "stock", "speed", "paint", "extent", "width", "wheels", "horse", "figures", "voice",
			"class", "signal_arm"]:
		if not (source.kind as Dictionary).has(key):
			return {}
	for key: String in ["id", "acceleration", "service_brake", "panic_brake", "reaction", "warning", "brake"]:
		if not (source["class"] as Dictionary).has(key):
			return {}
	for finish: Dictionary in source.finishes:
		# Painted finishes divide out their map's mean (OrisonV2StreetTraffic.stock_material).
		if bool(finish.get("paint", false)) and (finish.get("albedo_mean", []) as Array).size() != 3:
			return {}
	if str(source["class"].warning) not in OrisonV2StreetTraffic.WARNING_CUES or str(source["class"].brake) not in OrisonV2StreetTraffic.WARNING_CUES:
		return {}
	return source


## Called by OrisonV2StreetTraffic.mount between configure and entering the tree, so the car stock is in the
## traffic's batches and its warm start already has cars on the line. Returns the line's node, or null.
static func attach(street_traffic: OrisonV2StreetTraffic, owner_world: Node) -> OrisonV2StreetTrams:
	var table := load_table()
	if table.is_empty():
		push_error("V2 street trams table is invalid")
		return null
	var line := OrisonV2StreetTrams.new()
	line.name = "TrolleyLine"
	line.data = table
	line.traffic = street_traffic
	line.world = owner_world
	for finish: Dictionary in table.finishes:
		line._materials[str(finish.id)] = OrisonV2StreetTraffic.stock_material(finish)
	var meshes := OrisonV2StreetTraffic.stock_meshes(str(table.stock), line._materials)
	for stock: String in ["tram_car", "tram_span_pole", "tram_rosette"]:
		if not meshes.has(stock):
			push_error("V2 street trams stock lacks " + stock)
			line.free()
			return null
	street_traffic.extra_meshes["tram_car"] = meshes.tram_car
	line._pole_mesh = meshes.tram_span_pole
	line._rosette_mesh = meshes.tram_rosette
	var kind: Dictionary = (table.kind as Dictionary).duplicate(true)
	kind.rail = true
	street_traffic._kinds.append(kind)
	line.kind_index = street_traffic._kinds.size() - 1
	var klass: Dictionary = table["class"]
	street_traffic._classes[str(klass.id)] = klass
	street_traffic.rail = line
	line._rng.randomize()
	# The first car each way is somewhere in its headway already, so the warm start may show one.
	for track in 2:
		line._due[track] = line._rng.randf() * line._headway() * 60.0
	return line


func _ready() -> void:
	for track in 2:
		_sample_track(track)
	_lay_rails()
	for i in FLASHES:
		_flashes.append(_make_flash())
	# The poles stand on whatever the kerb is; ask the physics world once it has the street in it.
	_raise_overhead.call_deferred()


# ---------------------------------------------------------------- the service

func _headway() -> float:
	var minute := float(traffic._now.get("minute_of_day", 720.0)) if traffic != null else 720.0
	var hours: Array = data.headway_minutes
	return float(hours[clampi(int(minute / 60.0), 0, 23)])


## One step of the traffic's clock: a car leaves each end on its headway.
func spawn_step(delta: float) -> void:
	for track in 2:
		_due[track] -= delta
		if _due[track] > 0.0:
			continue
		_due[track] = _headway() * 60.0 * _rng.randf_range(0.85, 1.15)
		traffic._live.append(traffic.rail_journey(kind_index, track == 0))


func live_cars() -> Array[Dictionary]:
	var cars: Array[Dictionary] = []
	for v: Dictionary in traffic._live:
		if int(v.kind) == kind_index:
			cars.append(v)
	return cars


# ---------------------------------------------------------------- the path

func _sample_track(track: int) -> void:
	var lane_west := track == 0
	var kind: Dictionary = traffic._kinds[kind_index]
	var v := traffic.rail_journey(kind_index, lane_west)
	var step := float(data.line.sample_m)
	var reach := float(data.cross.reach_m)
	var points: Array = []
	var headings: Array = []
	var take := func() -> void:
		var pose := traffic._world_pose(v)
		var x := float(pose[0])
		points.append(Vector3(x, float(traffic.data.site.road_y) + StreetSurface.surface_height(x), float(pose[1])))
		headings.append(float(pose[2]))
	# In from the cross street, round the corner, along the avenue to the stop line, round, and away.
	var run := reach
	while run > 0.0:
		v.run = run
		take.call()
		run -= step
	v.run = 0.0
	var arc := 0.0
	while arc < PI * 0.5:
		v.arc = arc
		take.call()
		arc += step / float(v.radius)
	v.phase = "street"
	var stop_line := traffic._junction_p(v, true) - traffic._cross_half() - float(traffic.data.junctions.stop_gap_m)
	var ps := stop_line - float(kind.extent[1])
	var p := float(v.pe)
	while p < ps:
		v.p = p
		take.call()
		p += step
	v.p = ps
	traffic._begin_exit(v, kind)
	arc = 0.0
	while arc < PI * 0.5:
		v.arc = arc
		take.call()
		arc += step / float(v.radius)
	v.arc = PI * 0.5
	run = 0.001
	while run < reach:
		v.run = run
		take.call()
		run += step
	paths[track] = points
	yaws[track] = headings


static func _left(yaw: float) -> Vector3:
	# A pose's yaw turns street +x; its left is the travel direction turned a quarter toward -z.
	var forward := Basis(Vector3.UP, yaw).x
	return Vector3(forward.z, 0.0, -forward.x)


# ---------------------------------------------------------------- rails and wire

func _lay_rails() -> void:
	var line: Dictionary = data.line
	var half_gauge := float(line.gauge_m) * 0.5
	var head := float(line.rail_head_m) * 0.5
	var lift := float(line.rail_top_above_road_m)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for track in 2:
		var points: Array = paths[track]
		for side: float in [-1.0, 1.0]:
			var along := 0.0
			for i in points.size() - 1:
				var a: Vector3 = points[i]
				var b: Vector3 = points[i + 1]
				var la := _left(float(yaws[track][i])) * side * half_gauge
				var lb := _left(float(yaws[track][i + 1])) * side * half_gauge
				var wa := _left(float(yaws[track][i])) * head
				var wb := _left(float(yaws[track][i + 1])) * head
				var length := a.distance_to(b)
				var top := Vector3.UP * lift
				_quad(tool, a + la - wa + top, b + lb - wb + top, b + lb + wb + top, a + la + wa + top,
						Vector2(along, 0.0), Vector2(along + length, float(line.rail_head_m)))
				along += length
	tool.generate_tangents()
	var rails := MeshInstance3D.new()
	rails.name = "TramRails"
	rails.mesh = tool.commit()
	rails.material_override = _two_sided("running_iron")
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rails)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv0: Vector2, uv1: Vector2) -> void:
	# a-b runs along; d-a across. A flat strip facing up; drawn two-sided, so the winding never hides it.
	var uvs := [Vector2(uv0.x, uv0.y), Vector2(uv1.x, uv0.y), Vector2(uv1.x, uv1.y), Vector2(uv0.x, uv1.y)]
	var corners := [a, b, c, d]
	for index: int in [0, 2, 1, 0, 3, 2]:
		tool.set_normal(Vector3.UP)
		tool.set_uv(uvs[index])
		tool.add_vertex(corners[index])


## A thin round wire through points, as a mapped tube (metres along, metres around).
static func _wire(tool: SurfaceTool, points: Array, radius: float) -> void:
	const SIDES := 5
	var along := 0.0
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var axis := (b - a)
		var length := axis.length()
		if length < 0.001:
			continue
		axis /= length
		var u := axis.cross(Vector3.UP)
		if u.length() < 0.1:
			u = axis.cross(Vector3.RIGHT)
		u = u.normalized()
		var w := axis.cross(u).normalized()
		for k in SIDES:
			var t0 := TAU * k / SIDES
			var t1 := TAU * (k + 1) / SIDES
			var o0 := (u * cos(t0) + w * sin(t0)) * radius
			var o1 := (u * cos(t1) + w * sin(t1)) * radius
			var around0 := radius * t0
			var around1 := radius * t1
			var quad := [[a + o0, Vector2(along, around0), o0], [b + o0, Vector2(along + length, around0), o0],
					[b + o1, Vector2(along + length, around1), o1], [a + o1, Vector2(along, around1), o1]]
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal((quad[index][2] as Vector3).normalized())
				tool.set_uv(quad[index][1])
				tool.add_vertex(quad[index][0])
		along += length


func _two_sided(id: String) -> StandardMaterial3D:
	var mat := (_materials[id] as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _ground(x: float, z: float, guess: float) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return guess
	var origin := global_transform * Vector3(x, guess + 1.2, z)
	var query := PhysicsRayQueryParameters3D.create(origin, global_transform * Vector3(x, guess - 3.0, z))
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return guess
	return (global_transform.affine_inverse() * (hit.position as Vector3)).y


func _raise_overhead() -> void:
	if is_inside_tree():
		await get_tree().physics_frame
	var line: Dictionary = data.line
	var wire_lift := float(line.wire_height_m)
	var eye := float(line.span_eye_z_m)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wires: Array = [[], []]
	for track in 2:
		for point: Vector3 in paths[track]:
			wires[track].append(point + Vector3.UP * wire_lift)
		_wire(tool, wires[track], float(line.wire_radius_m))
	# Support lines: each runs from one shackle eye, across both wires, to the other.
	var stations: Array[Array] = []
	var pole_feet: Array[Vector3] = []
	var rosettes: Array[Vector3] = []
	var road_y := float(traffic.data.site.road_y)
	for support: Dictionary in data.supports:
		var x := float(support.x)
		var guess := road_y + StreetSurface.surface_height(x) + 0.15
		var far_foot := Vector3(x, _ground(x, float(data.far_kerb_z), guess), float(data.far_kerb_z))
		pole_feet.append(far_foot)
		var near_eye: Vector3
		if str(support.near) == "rosette":
			var anchor := Vector3(x, far_foot.y + eye, float(data.orison_facade_z))
			rosettes.append(anchor)
			near_eye = anchor + Vector3(0, 0, float(line.rosette_reach_m))
		else:
			var near_foot := Vector3(x, _ground(x, float(data.near_kerb_z), guess), float(data.near_kerb_z))
			pole_feet.append(near_foot)
			near_eye = near_foot + Vector3.UP * eye
		stations.append([far_foot + Vector3.UP * eye, near_eye])
	# Up each cross street the line turns into: a pole on each side of it at a steady pitch.
	var junctions: Dictionary = traffic.data.junctions
	var offset := float(data.cross.kerb_offset_m)
	var pitch := float(data.cross.support_pitch_m)
	for jx: float in [float(junctions.west_x), float(junctions.east_x)]:
		var z := float(data.far_kerb_z) + pitch
		while z < float(data.far_kerb_z) + float(data.cross.reach_m):
			var feet: Array[Vector3] = []
			for side: float in [-1.0, 1.0]:
				var x := jx + side * offset
				var guess := road_y + StreetSurface.surface_height(x) + 0.15
				feet.append(Vector3(x, _ground(x, z, guess), z))
			pole_feet.append_array(feet)
			stations.append([feet[0] + Vector3.UP * eye, feet[1] + Vector3.UP * eye])
			z += pitch
	for station: Array in stations:
		var a: Vector3 = station[0]
		var b: Vector3 = station[1]
		var span: Array = [a]
		var crossings: Array = []
		for track in 2:
			var nearest := _nearest_to_segment(wires[track], a, b)
			if nearest.is_finite():
				crossings.append(nearest)
		crossings.sort_custom(func(p: Vector3, q: Vector3) -> bool:
			return Vector2(p.x - a.x, p.z - a.z).length() < Vector2(q.x - a.x, q.z - a.z).length())
		for wire_point: Vector3 in crossings:
			var hanger_top := wire_point + Vector3.UP * 0.32
			span.append(hanger_top)
			_wire(tool, [hanger_top, wire_point], float(line.span_radius_m))
		span.append(b)
		_wire(tool, span, float(line.span_radius_m))
	tool.generate_tangents()
	var overhead := MeshInstance3D.new()
	overhead.name = "TrolleyWire"
	overhead.mesh = tool.commit()
	overhead.material_override = _two_sided("cast_iron")
	overhead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overhead)
	_place(pole_feet, _pole_mesh, "TrolleyPoles", true)
	_place(rosettes, _rosette_mesh, "TrolleyRosettes", false)
	built = true


func _nearest_to_segment(points: Array, a: Vector3, b: Vector3) -> Vector3:
	# The wire point closest to the support line in plan, if the line passes within a metre of the wire.
	var best := Vector3.INF
	var best_d := 1.0
	var ab := Vector2(b.x - a.x, b.z - a.z)
	for point: Vector3 in points:
		var ap := Vector2(point.x - a.x, point.z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := (ap - ab * t).length()
		if d < best_d:
			best_d = d
			best = point
	return best


func _place(feet: Array, mesh: Mesh, label: String, solid: bool) -> void:
	if feet.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = feet.size()
	for i in feet.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, feet[i]))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multimesh
	add_child(node)
	if not solid:
		return
	var height := float(data.line.pole_height_m)
	for i in feet.size():
		var body := StaticBody3D.new()
		body.name = "%sBody%02d" % [label, i]
		var shape := CollisionShape3D.new()
		var column := CylinderShape3D.new()
		column.radius = float(data.line.pole_radius_m)
		column.height = height
		shape.shape = column
		body.add_child(shape)
		body.position = (feet[i] as Vector3) + Vector3.UP * height * 0.5
		add_child(body)


# ---------------------------------------------------------------- lamps and arcs

func _process(delta: float) -> void:
	if traffic == null or traffic.startup_failed or traffic.frozen:
		return
	update_lamps()
	_quiet = maxf(0.0, _quiet - delta)
	var chance := arc_rate() / 60.0 * delta
	for v: Dictionary in live_cars():
		if float(v.speed) > 1.0 and _rng.randf() < chance:
			flash(v)
	for f: Dictionary in _flashes:
		if float(f.left) <= 0.0:
			continue
		f.left = float(f.left) - delta
		var light: OmniLight3D = f.light
		var spark: MeshInstance3D = f.spark
		if float(f.left) <= 0.0:
			light.visible = false
			spark.visible = false
		elif not _reduced():
			light.light_energy = float(f.energy) * _rng.randf_range(0.35, 1.0)


## Headlamp, tail lamp, saloon and windows follow the street's dusk and dawn rule.
func update_lamps() -> void:
	var lit := OrisonV2StreetTraffic.lamp_factor(traffic._now, traffic.data.schedule.dusk, traffic.data.schedule.dawn)
	for id: String in LIT:
		var mat: StandardMaterial3D = _materials.get(id)
		if mat != null:
			mat.emission_energy_multiplier = float(mat.get_meta("lamp_energy", 1.0)) * lit


## Arcs a minute for each moving car, from the sky and the street.
func arc_rate() -> float:
	var arcs: Dictionary = data.arcs
	var rate := float(arcs.per_minute)
	var weather: Dictionary = world.weather_conditions() if world != null and world.has_method("weather_conditions") else {}
	for entry: Dictionary in weather.get("phenomena", []):
		if str(entry.get("id", "")) in arcs.aurora_phenomena:
			rate *= float(arcs.aurora_multiplier)
			break
	if bool(weather.get("wet", false)):
		rate *= float(arcs.wet_multiplier)
	return rate


func _reduced() -> bool:
	return bool(GameBoot.settings.get("reduce_flashing", false))


func _make_flash() -> Dictionary:
	var arcs: Dictionary = data.arcs
	var colour: Array = arcs.colour
	var light := OmniLight3D.new()
	light.light_color = Color(colour[0], colour[1], colour[2])
	light.omni_range = float(arcs.range_m)
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	var spark := MeshInstance3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.05
	bead.height = 0.1
	bead.radial_segments = 8
	bead.rings = 4
	spark.mesh = bead
	var glow := OrisonV2StreetTraffic.stock_material({"catalog_key": "milk_glass", "tint": [colour[0], colour[1], colour[2], 1.0],
			"normal": 0.4, "roughness": 1.0, "emission": [colour[0], colour[1], colour[2], 2.6]})
	spark.material_override = glow
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.visible = false
	add_child(spark)
	return {"light": light, "spark": spark, "left": 0.0, "energy": 0.0}


## A blue-violet flash at a car's trolley wheel. Reduced flashing gives one soft, steady glow at most every
## second and a half, never a flicker.
func flash(v: Dictionary) -> bool:
	if _reduced() and _quiet > 0.0:
		return false
	var slot: Dictionary = {}
	for f: Dictionary in _flashes:
		if float(f.left) <= 0.0:
			slot = f
			break
	if slot.is_empty():
		return false
	var arcs: Dictionary = data.arcs
	var pose := traffic._world_pose(v)
	var x := float(pose[0])
	var frame := Transform3D(StreetSurface.road_basis(x, float(pose[2])),
			Vector3(x, float(traffic.data.site.road_y) + StreetSurface.surface_height(x), float(pose[1])))
	var tip: Array = data.line.pole_tip
	var at := frame * Vector3(float(tip[0]), float(tip[1]), float(tip[2]))
	var seconds: Array = arcs.seconds
	var energy := float(arcs.energy) * (float(arcs.reduced_energy) if _reduced() else 1.0)
	slot.left = _rng.randf_range(float(seconds[0]), float(seconds[1])) * (3.0 if _reduced() else 1.0)
	slot.energy = energy
	var light: OmniLight3D = slot.light
	var spark: MeshInstance3D = slot.spark
	light.position = at
	light.light_energy = energy
	light.visible = true
	spark.position = at
	spark.visible = true
	if _reduced():
		_quiet = 1.5
	arc_count += 1
	return true
