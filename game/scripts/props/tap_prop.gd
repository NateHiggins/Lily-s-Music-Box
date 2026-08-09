class_name TapProp
extends FunctionalProp
## The building's complete water fixtures: an enameled apartment-house
## lavatory, a roll-rim iron kitchen sink, or a corner shower receptor.
##
## The old division was a trap: Blender owned a generic modern fixture
## while this prop owned only the moving handles. It looked plausible in
## a bathroom and became two floating taps in the warehouse. The marker
## now owns the whole object, including every cavity the maintenance
## activities ask the player to touch.
##
## Water carries no signal. These are ordinary 1920s fixtures on pipe:
## second-hand porcelain enamel, exposed nickel-plated brass work, and
## the small failures caused by hands, minerals and standing water.

const PORCELAIN := Color(0.88, 0.87, 0.82)
const ENAMEL := Color(0.77, 0.79, 0.76)
const NICKEL := Color(0.72, 0.71, 0.67)
const BRASS := Color(0.55, 0.42, 0.21)
const IRON := Color(0.17, 0.17, 0.16)
const LINEN := Color(0.78, 0.76, 0.68)
const MINERAL := Color(0.67, 0.63, 0.48)
const RUST := Color(0.39, 0.18, 0.085)

## Set from the marker before `_ready()`. `fixture` is semantic; `prop_type`
## remains sink/shower so the possession catalog and water graph stay stable.
var fixture := "bath_sink"
var unit := ""
var drain_side := 1
var compact_kitchen := false
var has_drainboard := true

var _hot := false
var _cold := false
var _stopper := false
var _water_level := 0.0
var _boiler_temperature := 0.70
var _handles: Array[Node3D] = []
var _handle_turns: Array[float] = []
var _handle_wall_mounted: Array[bool] = []
var _stream: Node3D
var _basin_water: MeshInstance3D
var _water_empty_y := 0.0
var _water_full_y := 0.0
var _water_full_scale := Vector3.ONE
var _water: AudioStreamPlayer3D
var _tick: AudioStreamPlayer3D


func warehouse_variants() -> Array[Dictionary]:
	# PropWarehouse sets prop_type before asking. Returning the two sink
	# silhouettes here and the shower only under its own kind avoids the old
	# 2 kinds x 3 variants duplication.
	if prop_type == "shower":
		return [{"label": "shower / 1908 corner receptor",
				"properties": {"fixture": "shower", "unit": "3B"}}]
	return [
		{"label": "sink / apartment lavatory",
				"properties": {"fixture": "bath_sink", "unit": "2B"}},
		{"label": "sink / roll-rim kitchen",
				"properties": {"fixture": "kitchen_sink", "unit": "2B",
					"has_drainboard": true}},
	]


func _build_visual() -> void:
	var fixed := Node3D.new()
	fixed.name = "StaticFixture"
	add_child(fixed)
	if fixture == "shower":
		_build_shower(fixed)
	elif fixture == "kitchen_sink":
		_build_kitchen_sink(fixed)
	else:
		_build_bath_sink(fixed)

	retexture(self, [
		[PORCELAIN, "porcelain", Color(0.96, 0.94, 0.86), 0.72],
		[ENAMEL, "enamel", Color(0.78, 0.80, 0.75), 0.76],
		[NICKEL, "nickel_plated", Color(0.93, 0.91, 0.84), 0.42],
		[BRASS, "brass_dull", Color(0.78, 0.68, 0.44), 0.55],
		[IRON, "cast_iron", Color(0.33, 0.32, 0.29), 0.68],
		[LINEN, "linen", Color(0.88, 0.85, 0.75), 0.74],
	])
	# Valves, stopper and water remain separate because the player and the
	# haunting move them. Everything else is fixed enough to merge.
	merge_static(fixed)
	# Each valve still turns independently. Its stem, escutcheon, cross and
	# cap do not; merging inside the pivot preserves that verb and removes the
	# repeated primitive cost across sixty-six fixtures.
	for handle in _handles:
		merge_static(handle)

	_water = make_emitter(
			"shower_water" if fixture == "shower" else "sink_water",
			-21.0, true)
	if _water:
		_water.stream_paused = true
	_tick = make_emitter("tick", -27.0)


func _build_bath_sink(parent: Node3D) -> void:
	# 24-inch enameled lavatory with integral back and apron: the compact,
	# inexpensive apartment-house type in Mott's 1908 plate 1053.
	_tapered_pedestal(parent, 0.82)
	_open_oval_basin(parent, Vector3(0, 0.79, -0.02), 0.61, 0.46, 0.13,
			PORCELAIN)
	_box_on(parent, Vector3(0.61, 0.18, 0.045),
			Vector3(0, 0.87, 0.205), PORCELAIN)
	_build_pair_taps(Vector3(0, 0.91, 0.105), 0.18, false)
	_build_spout(Vector3(0, 0.91, 0.095), Vector3(0, 0.84, -0.04))
	_build_drain(parent, Vector3(0, 0.686, -0.02))
	_build_exposed_waste(parent, Vector3(0, 0.678, -0.02))
	_build_stopper(Vector3(0, 0.694, -0.055))
	_add_use_wear(parent, Vector3(0.22, 0.805, -0.19), false)
	_stream = _make_stream(Vector3(0, 0.865, -0.045), 0.178, 0.007)
	_water_empty_y = 0.689
	_water_full_y = 0.765
	_basin_water = _make_water_surface(
			Vector3(0, _water_empty_y, -0.02), Vector2(0.39, 0.25), true)


func _build_kitchen_sink(parent: Node3D) -> void:
	# Mott's smallest cheap roll-rim sink was 24 x 18 x 6 inches. The full
	# size fits the standard run; 4B keeps its existing 500 mm opening and
	# separate rack rather than pretending the hob has room for a board.
	var w := 0.50 if compact_kitchen else 0.61
	var d := 0.38 if compact_kitchen else 0.46
	var top := 0.905 if compact_kitchen else 0.90
	_open_rect_basin(parent, Vector3(0, top, 0), w, d, 0.15, ENAMEL)
	_box_on(parent, Vector3(w + 0.03, 0.16, 0.035),
			Vector3(0, top + 0.075, d * 0.5 - 0.004), ENAMEL)
	# Centre the valve penetrations inside the 160 mm integral back. At +170 mm
	# the escutcheons floated above its top edge; +110 mm keeps each mounting
	# plate visibly borne by enamel while leaving hand clearance over the rim.
	var mount_y := top + 0.11
	_build_pair_taps(Vector3(0, mount_y, d * 0.5 - 0.035), 0.19, true)
	# A bridge joins the two wall valves and gives the central riser a
	# mechanical origin. Without it the gooseneck was just a nickel pole
	# descending from nowhere when the player stood square to the run.
	_tube_between(self, Vector3(-0.095, mount_y, d * 0.5 - 0.055),
			Vector3(0.095, mount_y, d * 0.5 - 0.055), 0.011, NICKEL)
	var bridge_collar := _cyl_on(self, 0.022, 0.022, 0.035,
			Vector3(0, mount_y, d * 0.5 - 0.073), NICKEL)
	bridge_collar.rotation_degrees.x = 90.0
	_build_spout(Vector3(0, mount_y, d * 0.5 - 0.055),
			Vector3(0, top + 0.13, 0.015), true)
	_build_stopper(Vector3(0, top - 0.135, 0.01))
	if has_drainboard:
		_build_drainboard(parent, w, d, top)
	_add_use_wear(parent, Vector3(-w * 0.35, top + 0.004, -d * 0.37), true)
	_stream = _make_stream(Vector3(0, top + 0.115, 0.015), 0.245, 0.008)
	_water_empty_y = top - 0.137
	_water_full_y = top - 0.025
	_basin_water = _make_water_surface(Vector3(0, _water_empty_y, 0),
			Vector2(w - 0.09, d - 0.09))


func _build_shower(parent: Node3D) -> void:
	# A 28-inch corner receptor and exposed tubular shower, not the glass
	# cubicle the deleted assembly borrowed from the late twentieth century.
	_open_rect_basin(parent, Vector3(0, 0.12, 0), 0.72, 0.72, 0.12, ENAMEL)
	_box_on(parent, Vector3(0.74, 0.18, 0.035),
			Vector3(0, 0.20, 0.355), ENAMEL)
	_build_pair_taps(Vector3(0, 0.98, 0.335), 0.19, true)
	# Exposed nickel riser, crooked arm, broad period rose.
	_tube_between(parent, Vector3(0, 0.98, 0.35),
			Vector3(0, 1.89, 0.35), 0.010, NICKEL)
	_tube_between(parent, Vector3(0, 1.89, 0.35),
			Vector3(0, 1.89, 0.18), 0.010, NICKEL)
	var rose := _cyl_on(parent, 0.055, 0.075, 0.035,
			Vector3(0, 1.855, 0.18), NICKEL)
	rose.rotation_degrees.x = 180.0
	# A white-duck curtain on a 25-inch ring. The opening is intentional:
	# a full opaque wall hid the receptor and felt like collision geometry.
	_tube_between(parent, Vector3(-0.34, 2.02, -0.32),
			Vector3(0.34, 2.02, -0.32), 0.009, NICKEL)
	for x in [-0.31, -0.21, -0.11, -0.01, 0.09]:
		var fold := _box_on(parent, Vector3(0.095, 1.62, 0.010),
				Vector3(x, 1.19, -0.315), LINEN)
		fold.rotation_degrees.y = sin(x * 39.0) * 4.0
	_build_stopper(Vector3(0, 0.015, 0.01))
	_add_use_wear(parent, Vector3(0.25, 0.125, -0.24), true)
	_stream = _make_stream(Vector3(0, 1.82, 0.18), 1.71, 0.017)
	_water_empty_y = 0.016
	_water_full_y = 0.105
	_basin_water = _make_water_surface(Vector3(0, _water_empty_y, 0),
			Vector2(0.62, 0.62))


func _tapered_pedestal(parent: Node3D, top: float) -> void:
	_cyl_on(parent, 0.11, 0.18, 0.08, Vector3(0, 0.04, 0.06), PORCELAIN)
	_cyl_on(parent, 0.085, 0.11, top - 0.17,
			Vector3(0, (top - 0.17) * 0.5 + 0.08, 0.06), PORCELAIN)
	_cyl_on(parent, 0.20, 0.085, 0.09,
			Vector3(0, top - 0.045, 0.03), PORCELAIN)


func _open_oval_basin(parent: Node3D, at: Vector3, w: float, d: float,
		depth: float, color: Color) -> void:
	# One rolled edge, four inward-canted walls and a small elliptical floor
	# make the cavity. A second torus was tried at the bowl floor; viewed from
	# the bathroom door it read as a complete smaller sink laid over this one.
	# Real lavatories have one rim. The enamel sides carry the eye down instead.
	var outer := make_ring(w * 0.5, 0.025, at, color, 0.46, 0.0, parent)
	outer.scale.z = d / w
	_make_oval_bowl(parent, at, w, d, depth, color)


func _make_oval_bowl(parent: Node3D, at: Vector3, w: float, d: float,
		depth: float, color: Color) -> void:
	# A continuous low-poly enamel surface matters more here than extra
	# segments: disconnected boxes leave black seams under the bathroom's
	# grazing practical and make the floor look like a loose second object.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32
	var rings := [
		Vector3(w * 0.5 - 0.023, -0.006, d * 0.5 - 0.023),
		Vector3(w * 0.5 - 0.058, -depth * 0.55, d * 0.5 - 0.058),
		Vector3(w * 0.5 - 0.120, -depth + 0.018, d * 0.5 - 0.115),
	]
	for row in 2:
		for i in segments:
			var u0 := float(i) / segments
			var u1 := float(i + 1) / segments
			var a0 := u0 * TAU
			var a1 := u1 * TAU
			var upper: Vector3 = rings[row]
			var lower: Vector3 = rings[row + 1]
			var p00 := Vector3(cos(a0) * upper.x, upper.y,
					sin(a0) * upper.z)
			var p01 := Vector3(cos(a1) * upper.x, upper.y,
					sin(a1) * upper.z)
			var p10 := Vector3(cos(a0) * lower.x, lower.y,
					sin(a0) * lower.z)
			var p11 := Vector3(cos(a1) * lower.x, lower.y,
					sin(a1) * lower.z)
			var n0 := Vector3(cos(a0) * 0.62, 1.0,
					sin(a0) * 0.62).normalized()
			var n1 := Vector3(cos(a1) * 0.62, 1.0,
					sin(a1) * 0.62).normalized()
			# Concave faces use the opposite winding from an outside shell.
			# Explicit normals keep the enamel lit upward/outward rather than
			# inheriting the reversed triangle's downward normal.
			_bowl_vertex(st, p00, Vector2(u0, float(row) * 0.42), n0)
			_bowl_vertex(st, p11, Vector2(u1, float(row + 1) * 0.42), n1)
			_bowl_vertex(st, p10, Vector2(u0, float(row + 1) * 0.42), n0)
			_bowl_vertex(st, p00, Vector2(u0, float(row) * 0.42), n0)
			_bowl_vertex(st, p01, Vector2(u1, float(row) * 0.42), n1)
			_bowl_vertex(st, p11, Vector2(u1, float(row + 1) * 0.42), n1)
	var floor_ring: Vector3 = rings[2]
	for i in segments:
		var u0 := float(i) / segments
		var u1 := float(i + 1) / segments
		var a0 := u0 * TAU
		var a1 := u1 * TAU
		var edge0 := Vector3(cos(a0) * floor_ring.x, floor_ring.y,
				sin(a0) * floor_ring.z)
		var edge1 := Vector3(cos(a1) * floor_ring.x, floor_ring.y,
				sin(a1) * floor_ring.z)
		_bowl_vertex(st, edge0,
				Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5),
				Vector3.UP)
		_bowl_vertex(st, Vector3(0, floor_ring.y, 0), Vector2(0.5, 0.5),
				Vector3.UP)
		_bowl_vertex(st, edge1,
				Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5),
				Vector3.UP)
	st.generate_tangents()
	st.index()
	var bowl := MeshInstance3D.new()
	bowl.name = "ContinuousBowl"
	bowl.mesh = st.commit()
	bowl.position = at
	bowl.material_override = _pmat(color, 0.46, 0.0)
	parent.add_child(bowl)


func _bowl_vertex(st: SurfaceTool, point: Vector3, uv: Vector2,
		normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(uv)
	st.add_vertex(point)


func _open_rect_basin(parent: Node3D, at: Vector3, w: float, d: float,
		depth: float, color: Color) -> void:
	var lip := 0.035
	_box_on(parent, Vector3(w + lip, 0.025, lip),
			at + Vector3(0, 0, -d * 0.5), color)
	_box_on(parent, Vector3(w + lip, 0.025, lip),
			at + Vector3(0, 0, d * 0.5), color)
	_box_on(parent, Vector3(lip, 0.025, d),
			at + Vector3(-w * 0.5, 0, 0), color)
	_box_on(parent, Vector3(lip, 0.025, d),
			at + Vector3(w * 0.5, 0, 0), color)
	for x in [-1.0, 1.0]:
		_box_on(parent, Vector3(0.028, depth, d - 0.05),
				at + Vector3(x * (w * 0.5 - 0.026), -depth * 0.5, 0), color)
	for z in [-1.0, 1.0]:
		_box_on(parent, Vector3(w - 0.05, depth, 0.028),
				at + Vector3(0, -depth * 0.5, z * (d * 0.5 - 0.026)), color)
	_box_on(parent, Vector3(w - 0.07, 0.018, d - 0.07),
			at + Vector3(0, -depth + 0.01, 0), color)
	_build_drain(parent, at + Vector3(0, -depth + 0.021, 0))


func _build_drainboard(parent: Node3D, basin_w: float, d: float,
		top: float) -> void:
	var side := 1.0 if drain_side >= 0 else -1.0
	var board_w := 0.42
	var center_x := side * (basin_w * 0.5 + board_w * 0.5)
	_box_on(parent, Vector3(board_w, 0.026, d),
			Vector3(center_x, top - 0.003, 0), ENAMEL)
	# Raised draining ribs pitch toward the bowl. They are geometry because
	# a flat normal map disappears under the kitchen's grazing night light.
	for i in 7:
		var x := center_x + side * (-0.15 + i * 0.05)
		_box_on(parent, Vector3(0.010, 0.011, d - 0.075),
				Vector3(x, top + 0.014, 0), ENAMEL)


func _build_pair_taps(at: Vector3, separation: float,
		wall_mounted: bool) -> void:
	for i in 2:
		var pivot := Node3D.new()
		pivot.name = "HotValve" if i == 0 else "ColdValve"
		pivot.position = at + Vector3((-0.5 + i) * separation, 0, 0)
		add_child(pivot)
		_handles.append(pivot)
		_handle_turns.append(0.0)
		_handle_wall_mounted.append(wall_mounted)
		if wall_mounted:
			# These valves pierce the integral vertical back, so their stems
			# point out of it and the cross sits in the visible X/Y plane.
			# The earlier deck-mounted handle was exactly ninety degrees wrong:
			# a chrome cup with one dark bar was all the doorway could see.
			var stem := _cyl_on(pivot, 0.023, 0.027, 0.060,
					Vector3(0, 0, -0.018), NICKEL)
			stem.rotation_degrees.x = 90.0
			var escutcheon := make_ring(0.034, 0.007,
					Vector3(0, 0, 0.008), NICKEL, 0.38, 0.65, pivot)
			escutcheon.rotation_degrees.x = 90.0
			_box_on(pivot, Vector3(0.092, 0.014, 0.014),
					Vector3(0, 0, -0.052), NICKEL)
			_box_on(pivot, Vector3(0.014, 0.092, 0.014),
					Vector3(0, 0, -0.052), NICKEL)
			var cap := _cyl_on(pivot, 0.013, 0.013, 0.014,
					Vector3(0, 0, -0.060), BRASS)
			cap.rotation_degrees.x = 90.0
		else:
			_cyl_on(pivot, 0.023, 0.027, 0.058, Vector3.ZERO, NICKEL)
			for k in 2:
				var arm := _box_on(pivot, Vector3(0.085, 0.014, 0.014),
						Vector3(0, 0.035, 0), NICKEL)
				arm.rotation.y = PI * 0.5 * k
			_cyl_on(pivot, 0.012, 0.012, 0.012,
					Vector3(0, 0.035, 0), BRASS)


func _build_spout(base: Vector3, outlet: Vector3,
		high_arc := false) -> void:
	if high_arc:
		# Five short chords read as a bent gooseneck at this scale. A single
		# diagonal from back to drain read as a loose rod leaning in the bowl.
		var points := [
			base,
			base + Vector3(0, 0.12, 0),
			Vector3(0, base.y + 0.19, lerpf(base.z, outlet.z, 0.28)),
			Vector3(0, base.y + 0.21, lerpf(base.z, outlet.z, 0.62)),
			Vector3(0, outlet.y + 0.07, outlet.z),
			outlet,
		]
		for i in points.size() - 1:
			_tube_between(self, points[i], points[i + 1], 0.012, NICKEL)
	else:
		_tube_between(self, base, base + Vector3(0, 0.10, 0), 0.011, NICKEL)
		_tube_between(self, base + Vector3(0, 0.10, 0), outlet, 0.011, NICKEL)
	var mouth_r := 0.019 if high_arc else 0.014
	var mouth := _cyl_on(self, mouth_r, mouth_r * 0.82, 0.032,
			outlet, NICKEL)
	mouth.rotation_degrees.x = 90.0


func _build_exposed_waste(parent: Node3D, drain_at: Vector3) -> void:
	_tube_between(parent, drain_at, Vector3(0, 0.42, drain_at.z), 0.018, NICKEL)
	# The U is deliberately legible from the doorway; exposed supplies and
	# trap are part of this inexpensive fixture's period/class identity.
	var trap := make_ring(0.075, 0.014, Vector3(0, 0.40, 0.06), NICKEL,
			0.35, 0.75, parent)
	trap.rotation_degrees.x = 90.0
	for x in [-0.09, 0.09]:
		_tube_between(parent, Vector3(x, 0.03, 0.18),
				Vector3(x, 0.76, 0.18), 0.007, NICKEL)


func _build_drain(parent: Node3D, at: Vector3) -> void:
	_cyl_on(parent, 0.041, 0.041, 0.006, at, NICKEL)
	for x in [-0.022, 0.0, 0.022]:
		_box_on(parent, Vector3(0.007, 0.004, 0.065),
				at + Vector3(x, 0.005, 0), IRON)


func _build_stopper(at: Vector3) -> void:
	var stopper := Node3D.new()
	stopper.name = "Stopper"
	stopper.position = at
	add_child(stopper)
	_cyl_on(stopper, 0.036, 0.036, 0.010, Vector3.ZERO, NICKEL)


func _add_use_wear(parent: Node3D, at: Vector3, wet: bool) -> void:
	# These marks are placed where water pools and hands abrade. A tiled
	# texture would repeat them across clean vertical enamel as wallpaper.
	var mineral := _cyl_on(parent, 0.055, 0.075, 0.003,
			at, MINERAL, 0.88, 0.0)
	mineral.scale.z = 0.55
	if wet:
		var rust := _cyl_on(parent, 0.018, 0.031, 0.003,
				at + Vector3(0.05, 0.003, -0.025), RUST, 0.83, 0.0)
		rust.scale.z = 1.7


func _make_stream(from: Vector3, drop: float, radius: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "WaterStream"
	holder.position = from
	holder.visible = false
	add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.80, 0.84, 0.36)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 0.54
	cyl.height = drop
	cyl.radial_segments = 7
	column.mesh = cyl
	column.material_override = mat
	column.position.y = -drop * 0.5
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(column)
	return holder


func _make_water_surface(at: Vector3, size: Vector2,
		oval := false) -> MeshInstance3D:
	var tint := Color(0.59, 0.73, 0.78, 0.18)
	var water: MeshInstance3D
	if oval:
		water = _cyl_on(self, size.x * 0.5, size.x * 0.5, 0.004, at, tint)
		water.scale.z = size.y / size.x
	else:
		water = make_box(Vector3(size.x, 0.004, size.y), at, tint)
	var mat: StandardMaterial3D = water.material_override
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	water.visible = false
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_full_scale = water.scale
	return water


func _box_on(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := make_box(size, at, color)
	remove_child(node)
	parent.add_child(node)
	# `at` is in the requested parent's local space. Subtracting the parent's
	# root-space position here made every cross-handle arm fall back near the
	# prop origin while its cylinder stem remained correctly on the valve.
	node.position = at
	return node


func _cyl_on(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color, rough := 0.45,
		metal := 0.0) -> MeshInstance3D:
	var node := make_cyl(rt, rb, height, at, color, rough, metal, parent)
	return node


func _tube_between(parent: Node3D, a: Vector3, b: Vector3, radius: float,
		color: Color) -> MeshInstance3D:
	var delta := b - a
	var tube := _cyl_on(parent, radius, radius, delta.length(),
			(a + b) * 0.5, color, 0.34, 0.72)
	var direction := delta.normalized()
	# Godot's arc quaternion is undefined for exact antipodes. The exposed
	# waste drops straight down, so UP -> DOWN produced a non-finite transform
	# that the GL renderer tolerated visually and WalkTest correctly rejected.
	var dot := Vector3.UP.dot(direction)
	if dot < -0.9999:
		tube.rotation_degrees.x = 180.0
	elif dot < 0.9999:
		tube.quaternion = Quaternion(Vector3.UP, direction)
	return tube


func interact_prompt() -> String:
	if _hot or _cold:
		return "[E]  Turn off the %s" % _fixture_name()
	return "[E]  Turn on the %s" % _fixture_name()


func interact(_player: Node) -> void:
	# One-key interaction cycles useful temperatures, but the minigame APIs
	# below retain independent hot/cold valves and a separate stopper.
	if not _hot and not _cold:
		set_hot(true)
	elif _hot and not _cold:
		set_cold(true)
	else:
		set_hot(false)
		set_cold(false)


func set_hot(on: bool) -> void:
	_hot = on
	_update_flow()


func set_cold(on: bool) -> void:
	_cold = on
	_update_flow()


func set_stopper(closed: bool) -> void:
	_stopper = closed


func set_boiler_temperature(value: float) -> void:
	_boiler_temperature = clampf(value, 0.0, 1.0)


## Compatibility for old callers; independent valves remain authoritative.
func set_running(on: bool) -> void:
	set_cold(on)
	if not on:
		set_hot(false)


func get_flow_state() -> Dictionary:
	var mix := 0.0
	if _hot or _cold:
		mix = (_boiler_temperature if _hot else 0.0) / \
				(float(int(_hot) + int(_cold)))
	return {"hot": _hot, "cold": _cold, "stopper": _stopper,
			"temperature": mix, "water_level": _water_level}


## A stable maintenance pose for render/test tools: both independent valves
## open over a closed drain. Gameplay never calls this shortcut.
func set_service_pose() -> void:
	set_stopper(true)
	set_hot(true)
	set_cold(true)


func _update_flow() -> void:
	var flowing := _hot or _cold
	if _stream:
		_stream.visible = flowing
	if _water:
		_water.stream_paused = not flowing
		if flowing and not _water.playing:
			_water.play()
	if _tick and not _tick.playing:
		_tick.play()
	state = PState.OPERATING if flowing else PState.IDLE


func _start_normal_function() -> void:
	state = PState.IDLE


func _process(delta: float) -> void:
	var targets := [1.0 if _hot else 0.0, 1.0 if _cold else 0.0]
	for i in mini(_handles.size(), 2):
		_handle_turns[i] = move_toward(_handle_turns[i], targets[i], delta * 3.0)
		var turn := (1.0 if i == 0 else -1.0) * \
				_handle_turns[i] * PI * 0.5
		if _handle_wall_mounted[i]:
			_handles[i].rotation.z = turn
		else:
			_handles[i].rotation.y = turn
	var flowing := _hot or _cold
	if _stopper and flowing:
		_water_level = minf(1.0, _water_level + delta * 0.075)
	else:
		_water_level = maxf(0.0, _water_level - delta * 0.12)
	if _basin_water:
		_basin_water.visible = _water_level > 0.01
		# Water has one surface; it rises from the drain rather than growing
		# into a thick translucent lid fixed just below the rolled rim.
		_basin_water.position.y = lerpf(
				_water_empty_y, _water_full_y, _water_level)
		var spread := lerpf(0.52, 1.0, _water_level)
		_basin_water.scale.x = _water_full_scale.x * spread
		_basin_water.scale.y = _water_full_scale.y
		_basin_water.scale.z = _water_full_scale.z * spread
	# A hot shower fogs only while it is physically hot; this state is kept
	# for the director without adding a supernatural electrical affordance.
	if fixture == "shower" and _hot:
		state = PState.OPERATING


func _perform_synced_event(index: int, accent: float, _pitch: float) -> void:
	# Possession may only retime the mechanism: a valve twitches, or a closed
	# tap admits a brief, deniable thread of water. It does not receive data.
	if _hot or _cold:
		var which := posmod(index, 2)
		_handle_turns[which] = clampf(_handle_turns[which] - accent * 0.18, 0.0, 1.0)
	elif accent > 0.72:
		set_cold(true)
		await get_tree().create_timer(0.10 + accent * 0.18, false).timeout
		if is_inside_tree():
			set_cold(false)


func _fixture_name() -> String:
	if fixture == "shower":
		return "shower"
	if fixture == "kitchen_sink":
		return "kitchen tap"
	return "basin tap"
