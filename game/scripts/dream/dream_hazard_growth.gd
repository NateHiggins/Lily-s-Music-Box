class_name DreamHazardGrowth
extends MeshInstance3D
## THE PART OF HER BODY THAT CAN HURT YOU.
##
## One batched surface grows around every currently-live hazard whose danger
## does not depend on the service lamp.  The hazard field remains the sole
## contact owner: this class only makes those existing radii legible as a
## breathing, eye-bearing body.  Consequently switching the lamp off can hide
## detail, but can never stop the motion or disarm the thing underneath it.

const CLEAR_CEILING_M := 3.015
const TUBE_SIDES := 10
const PATH_STEPS := 18
const EYE_RINGS := 5
const EYE_SIDES := 8
const MAIN_BRANCHES := 9
const SIDE_BRANCHES := 2
const CONTACT_TUBE_RADIUS_M := 0.18


func configure(live_hazards: Array[DreamHazard], plan: Dictionary) -> void:
	name = "DreamHazardGrowth"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ids: Array[String] = []
	var sockets: Array[String] = []
	var eye_count := 0
	var tendril_count := 0
	var contact_path_count := 0
	for hazard in live_hazards:
		hazard.set_contact_paths([], 0.0)
		# The signal trunk is a different physical sentence: it reaches only
		# for the lit beam and goes quiet in darkness. Dressing that conditional
		# arc as an always-live tentacle would make the picture lie about play.
		# A lift void is equally literal: its danger is missing floor and its
		# contact is gravity. Tentacles around it would either be harmless lies
		# or change that authored lesson into a different hazard.
		if hazard.condition == "lamp_on" or hazard.falls_through \
				or hazard.contacted:
			continue
		var rect := _room_rect(plan, hazard.module)
		if rect.is_empty():
			continue
		ids.append(hazard.id)
		sockets.append(hazard.socket)
		var seed := absi(hazard.id.hash())
		var built := _append_hazard(tool, hazard, rect, seed)
		tendril_count += int(built.tendrils)
		eye_count += int(built.eyes)
		contact_path_count += int(built.contact_paths)
	if ids.is_empty():
		mesh = null
		visible = false
	else:
		mesh = tool.commit()
		visible = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	extra_cull_margin = 0.18
	add_to_group("dream_hazard_growth")
	set_meta("hazard_ids", ids)
	set_meta("hazard_sockets", sockets)
	set_meta("dark_live", true)
	set_meta("hazard_owner", "DreamHazardField")
	set_meta("tendrils", tendril_count)
	set_meta("eyes", eye_count)
	set_meta("contact_paths", contact_path_count)
	set_meta("motion_hz", 0.13)
	set_meta("max_sway_m", 0.045)
	set_meta("surfaces", mesh.get_surface_count() if mesh != null else 0)


func _append_hazard(tool: SurfaceTool, hazard: DreamHazard, rect: Array,
		seed: int) -> Dictionary:
	var core := Vector3(hazard.position.x, 0.10, hazard.position.z)
	var phase := float(seed & 4095) / 4095.0
	var ring_radius := maxf(0.20, hazard.clearance_radius * 0.74)
	var contact_paths: Array[PackedVector3Array] = []
	var tendrils := 0
	var eyes := 0
	# The root is a bruised rupture, not a plumbing manifold. Overlapping
	# ellipsoids hide the radial construction and give the branches something
	# bodily to disappear into.
	_append_ellipsoid(tool, core + Vector3.UP * 0.08, Vector3.RIGHT,
			Vector3.UP, Vector3.FORWARD,
			Vector3(ring_radius * 1.18, 0.17, ring_radius * 0.96), 0.0, phase)
	_append_ellipsoid(tool, core + Vector3(0.10, 0.18, -0.06),
			Vector3.RIGHT, Vector3.UP, Vector3.FORWARD,
			Vector3(ring_radius * 0.72, 0.24, ring_radius * 0.80), 0.0,
			fmod(phase + 0.19, 1.0))
	# Three warped collars make the floor/wall junction read as a rupture,
	# rather than seven garden hoses sharing a convenient origin.
	for ring in 3:
		var collar: Array[Vector3] = []
		for step in PATH_STEPS + 1:
			var t := float(step) / float(PATH_STEPS)
			var a := t * TAU
			var r := ring_radius * (0.78 + float(ring) * 0.14)
			collar.append(core + Vector3(cos(a) * r,
					0.018 + sin(a * 3.0 + phase * TAU) * 0.035,
					sin(a) * r))
		_append_tube(tool, collar, 0.045 + float(ring) * 0.010,
				0.018, phase + float(ring) * 0.17)

	var room_center := Vector3((float(rect[0]) + float(rect[2])) * 0.5,
			0.0, (float(rect[1]) + float(rect[3])) * 0.5)
	for branch in MAIN_BRANCHES:
		var branch_phase := fmod(phase + float(branch) / float(MAIN_BRANCHES),
				1.0)
		var angle := branch_phase * TAU
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var wall_reach := _reach_to_wall(core, direction, rect)
		var reach_scale := 0.76 + float((seed >> (branch * 2)) & 3) * 0.07
		var reach := clampf(wall_reach * reach_scale,
				ring_radius + 0.34, 4.25)
		var end := core + direction * reach
		match branch % 4:
			0:
				end.y = 0.055
			1:
				end = core + direction * minf(wall_reach - 0.08, 4.25)
				end.y = 0.82 + float((seed >> branch) & 3) * 0.42
			2:
				end = core + direction * minf(reach, 3.35)
				end.y = CLEAR_CEILING_M - 0.075
			_:
				end = core + direction * minf(wall_reach - 0.08, 4.25)
				end.y = CLEAR_CEILING_M * 0.76
		end.x = clampf(end.x, float(rect[0]) + 0.08,
				float(rect[2]) - 0.08)
		end.z = clampf(end.z, float(rect[1]) + 0.08,
				float(rect[3]) - 0.08)
		var side := Vector3(-direction.z, 0.0, direction.x)
		var curl_sign := -1.0 if ((seed >> branch) & 1) == 0 else 1.0
		var start := core + direction * ring_radius * 0.68
		var c1 := start + direction * ring_radius * 1.4 \
				+ Vector3.UP * (0.22 + 0.11 * float(branch % 4))
		var c2 := end - direction * minf(0.58, reach * 0.25) \
				+ side * curl_sign * minf(0.42, reach * 0.18)
		if end.y > 1.0:
			c2.y = minf(CLEAR_CEILING_M - 0.16, end.y + 0.42)
		var path: Array[Vector3] = []
		for step in PATH_STEPS + 1:
			var t := float(step) / float(PATH_STEPS)
			var point := _bezier(start, c1, c2, end, t)
			# Fine corkscrew motion is authored into the resting silhouette;
			# the shader adds only the living displacement.
			var envelope := sin(t * PI)
			point += side * sin(t * TAU * 1.5 + branch_phase * TAU) \
					* envelope * minf(0.085, reach * 0.035)
			path.append(point)
		var root_radius := clampf(hazard.clearance_radius * 0.32,
				0.095, 0.145)
		_append_tapered_tube(tool, path, root_radius,
				maxf(0.028, root_radius * 0.26), branch_phase)
		contact_paths.append(PackedVector3Array(path))
		tendrils += 1
		# A pair of capillary limbs makes the path fork and cling instead of
		# reading as a manufactured cable. They remain part of the same surface
		# and publish the same contact truth as their parent limb.
		for twig in SIDE_BRANCHES:
			var t0 := 0.48 + float(twig) * 0.22
			var twig_start := _bezier(start, c1, c2, end, t0)
			var twig_sign := -1.0 if twig == 0 else 1.0
			var twig_end := twig_start + side * twig_sign \
					* (0.34 + 0.10 * float((seed >> (branch + twig)) & 3))
			twig_end.x = clampf(twig_end.x, float(rect[0]) + 0.07,
					float(rect[2]) - 0.07)
			twig_end.z = clampf(twig_end.z, float(rect[1]) + 0.07,
					float(rect[3]) - 0.07)
			if branch % 4 == 0:
				twig_end.y = 0.045
			elif branch % 4 == 2:
				twig_end.y = CLEAR_CEILING_M - 0.055
			var twig_path: Array[Vector3] = []
			var twig_c1 := twig_start + side * twig_sign * 0.16 \
					+ Vector3.UP * (0.10 if branch % 4 == 0 else 0.0)
			for step in 9:
				var t := float(step) / 8.0
				twig_path.append(_bezier(twig_start, twig_c1,
						twig_end - side * twig_sign * 0.10, twig_end, t))
			_append_tapered_tube(tool, twig_path, root_radius * 0.42,
					0.010, fmod(branch_phase + float(twig) * 0.21, 1.0))
			contact_paths.append(PackedVector3Array(twig_path))
			tendrils += 1
		# Where a main limb reaches architecture it spreads laterally, like a
		# vine becoming load-bearing scar tissue. These crawlers remain thick
		# enough to be contact truth; the smaller shader veins are visual only.
		if branch % 4 in [1, 2, 3]:
			var crawl: Array[Vector3] = [end]
			if branch % 4 == 2:
				crawl.append(Vector3(
						clampf(end.x + side.x * curl_sign * 0.38,
						float(rect[0]) + 0.07, float(rect[2]) - 0.07),
						CLEAR_CEILING_M - 0.06,
						clampf(end.z + side.z * curl_sign * 0.38,
						float(rect[1]) + 0.07, float(rect[3]) - 0.07)))
				crawl.append(Vector3(
						clampf(end.x + side.x * curl_sign * 0.72,
						float(rect[0]) + 0.07, float(rect[2]) - 0.07),
						CLEAR_CEILING_M - 0.06,
						clampf(end.z + side.z * curl_sign * 0.72,
						float(rect[1]) + 0.07, float(rect[3]) - 0.07)))
			else:
				crawl.append(end + side * curl_sign * 0.34 + Vector3.UP * 0.31)
				crawl.append(end + side * curl_sign * 0.66 \
						+ Vector3.UP * (-0.28 if branch % 4 == 1 else 0.46))
				for crawl_index in crawl.size():
					var p := crawl[crawl_index]
					p.x = clampf(p.x, float(rect[0]) + 0.06,
							float(rect[2]) - 0.06)
					p.y = clampf(p.y, 0.06, CLEAR_CEILING_M - 0.06)
					p.z = clampf(p.z, float(rect[1]) + 0.06,
							float(rect[3]) - 0.06)
					crawl[crawl_index] = p
			_append_tapered_tube(tool, crawl, root_radius * 0.72,
					0.018, fmod(branch_phase + 0.37, 1.0))
			contact_paths.append(PackedVector3Array(crawl))
			tendrils += 1
			var plaque_forward := -direction if branch % 4 != 2 else Vector3.UP
			var plaque_side := side
			var plaque_up := Vector3.UP if branch % 4 != 2 else direction
			_append_ellipsoid(tool, end - plaque_forward * 0.035,
					plaque_side, plaque_up, plaque_forward,
					Vector3(root_radius * 1.15, root_radius * 1.35,
					root_radius * 0.34), 0.0, branch_phase)
		# Four eyes per danger, at alternating heights. They share this surface
		# and therefore cost no extra submission.
		if branch in [1, 2, 5, 7]:
			var eye_t := 0.48 if branch % 2 == 0 else 0.66
			var eye_at := _bezier(start, c1, c2, end, eye_t)
			var look := room_center - eye_at
			look.y = 0.12
			if look.length() < 0.01:
				look = -direction
			_append_eye(tool, eye_at, look.normalized(), root_radius * 0.86,
					branch_phase)
			eyes += 1
	hazard.set_contact_paths(contact_paths, CONTACT_TUBE_RADIUS_M)
	return {
		"tendrils": tendrils,
		"eyes": eyes,
		"contact_paths": contact_paths.size(),
	}


func _append_tapered_tube(tool: SurfaceTool, points: Array[Vector3],
		root_radius: float, tip_radius: float, phase: float) -> void:
	if points.size() < 2:
		return
	for ring in points.size() - 1:
		var t0 := float(ring) / float(points.size() - 1)
		var t1 := float(ring + 1) / float(points.size() - 1)
		var pulse0 := 0.84 + 0.13 * sin(t0 * TAU * 3.0 + phase * TAU) \
				+ 0.055 * sin(t0 * TAU * 7.0 - phase * 4.0)
		var pulse1 := 0.84 + 0.13 * sin(t1 * TAU * 3.0 + phase * TAU) \
				+ 0.055 * sin(t1 * TAU * 7.0 - phase * 4.0)
		_append_tube_segment(tool, points[ring], points[ring + 1],
				lerpf(root_radius, tip_radius, pow(t0, 0.72)) * pulse0,
				lerpf(root_radius, tip_radius, pow(t1, 0.72)) * pulse1,
				t0, t1, phase)


func _append_tube(tool: SurfaceTool, points: Array[Vector3], radius: float,
		tip_radius: float, phase: float) -> void:
	if points.size() < 2:
		return
	for ring in points.size() - 1:
		var t0 := float(ring) / float(points.size() - 1)
		var t1 := float(ring + 1) / float(points.size() - 1)
		_append_tube_segment(tool, points[ring], points[ring + 1],
				lerpf(radius, tip_radius, t0), lerpf(radius, tip_radius, t1),
				t0, t1, phase)


func _append_tube_segment(tool: SurfaceTool, a: Vector3, b: Vector3,
		ra: float, rb: float, t0: float, t1: float, phase: float) -> void:
	var tangent := (b - a).normalized()
	var side := tangent.cross(Vector3.UP)
	if side.length() < 0.001:
		side = tangent.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(tangent).normalized()
	for side_index in TUBE_SIDES:
		var angle0 := TAU * float(side_index) / float(TUBE_SIDES)
		var angle1 := TAU * float(side_index + 1) / float(TUBE_SIDES)
		var n0 := side * cos(angle0) + up * sin(angle0)
		var n1 := side * cos(angle1) + up * sin(angle1)
		var lobe0 := 1.0 + 0.10 * sin(angle0 * 3.0 + phase * TAU)
		var lobe1 := 1.0 + 0.10 * sin(angle1 * 3.0 + phase * TAU)
		var flex0 := sin(t0 * PI)
		var flex1 := sin(t1 * PI)
		_quad(tool, a + n0 * ra * lobe0, b + n0 * rb * lobe0,
				b + n1 * rb * lobe1, a + n1 * ra * lobe1,
				(n0 + n1).normalized(),
				Color(flex0, phase, 0.0, 1.0),
				Color(flex1, phase, 0.0, 1.0))


func _append_eye(tool: SurfaceTool, center: Vector3, look: Vector3,
		radius: float, phase: float) -> void:
	var forward := look.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var eye_scale := Vector3(radius * 1.20, radius * 0.68, radius * 0.38)
	_append_ellipsoid(tool, center + forward * radius * 0.20,
			side, up, forward, eye_scale, 0.30, phase)
	_append_ellipsoid(tool, center + forward * radius * 0.52,
			side, up, forward, Vector3(radius * 0.43, radius * 0.43,
			radius * 0.15), 0.62, phase)
	_append_ellipsoid(tool, center + forward * radius * 0.66,
			side, up, forward, Vector3(radius * 0.21, radius * 0.21,
			radius * 0.10), 1.0, phase)


func _append_ellipsoid(tool: SurfaceTool, center: Vector3, side: Vector3,
		up: Vector3, forward: Vector3, radii: Vector3, feature: float,
		phase: float) -> void:
	for ring in EYE_RINGS:
		var v0 := float(ring) / float(EYE_RINGS)
		var v1 := float(ring + 1) / float(EYE_RINGS)
		var lat0 := lerpf(-PI * 0.5, PI * 0.5, v0)
		var lat1 := lerpf(-PI * 0.5, PI * 0.5, v1)
		for segment in EYE_SIDES:
			var lon0 := TAU * float(segment) / float(EYE_SIDES)
			var lon1 := TAU * float(segment + 1) / float(EYE_SIDES)
			var n00 := side * (cos(lat0) * cos(lon0)) \
					+ up * sin(lat0) + forward * (cos(lat0) * sin(lon0))
			var n01 := side * (cos(lat0) * cos(lon1)) \
					+ up * sin(lat0) + forward * (cos(lat0) * sin(lon1))
			var n10 := side * (cos(lat1) * cos(lon0)) \
					+ up * sin(lat1) + forward * (cos(lat1) * sin(lon0))
			var n11 := side * (cos(lat1) * cos(lon1)) \
					+ up * sin(lat1) + forward * (cos(lat1) * sin(lon1))
			var a := center + side * n00.dot(side) * radii.x \
					+ up * n00.dot(up) * radii.y \
					+ forward * n00.dot(forward) * radii.z
			var b := center + side * n10.dot(side) * radii.x \
					+ up * n10.dot(up) * radii.y \
					+ forward * n10.dot(forward) * radii.z
			var c := center + side * n11.dot(side) * radii.x \
					+ up * n11.dot(up) * radii.y \
					+ forward * n11.dot(forward) * radii.z
			var d := center + side * n01.dot(side) * radii.x \
					+ up * n01.dot(up) * radii.y \
					+ forward * n01.dot(forward) * radii.z
			_quad(tool, a, b, c, d, (n00 + n01 + n10 + n11).normalized(),
					Color(0.22, phase, feature, 1.0),
					Color(0.22, phase, feature, 1.0))


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, normal: Vector3, color_a: Color, color_b: Color) -> void:
	for record in [[a, color_a], [b, color_b], [c, color_b],
			[a, color_a], [c, color_b], [d, color_a]]:
		tool.set_normal(normal)
		tool.set_color(record[1])
		tool.add_vertex(record[0])


func _room_rect(plan: Dictionary, room_id: String) -> Array:
	for entry in plan.get("modules", []):
		if str(entry.get("id", "")) == room_id:
			return entry.get("rect", [])
	return []


func _reach_to_wall(origin: Vector3, direction: Vector3, rect: Array) -> float:
	var candidates: Array[float] = []
	if direction.x > 0.001:
		candidates.append((float(rect[2]) - origin.x) / direction.x)
	elif direction.x < -0.001:
		candidates.append((float(rect[0]) - origin.x) / direction.x)
	if direction.z > 0.001:
		candidates.append((float(rect[3]) - origin.z) / direction.z)
	elif direction.z < -0.001:
		candidates.append((float(rect[1]) - origin.z) / direction.z)
	var best := INF
	for candidate in candidates:
		if candidate > 0.0:
			best = minf(best, candidate)
	return best if is_finite(best) else 2.0


func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u * u) + b * (3.0 * u * u * t) \
			+ c * (3.0 * u * t * t) + d * (t * t * t)
