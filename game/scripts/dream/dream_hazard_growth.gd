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
const TUBE_SIDES := 16
const PATH_STEPS := 18
const EYE_RINGS := 7
const EYE_SIDES := 12
const MAIN_BRANCHES := 9
const SIDE_BRANCHES := 2
const CONTACT_TUBE_RADIUS_M := 0.18
const BREACH_SEGMENTS := 18
const BREACH_HALF_WIDTH_M := 0.64
const BREACH_HALF_HEIGHT_M := 1.12
const BREACH_APPARENT_DEPTH_M := 32.0
const EYE_BRANCHES := [1, 2, 4, 5, 7]
const EYE_STATES := [
		"closed", "half_lidded", "half_lidded", "half_lidded", "open"]
const EYE_OPENNESS := [0.10, 0.38, 0.52, 0.64, 0.88]

## THE INTRUSION LIMBS -- workstream E, and the owner amplification of
## 2026-08-20 made geometry: "the warping gold resolves in animated gold
## tentacles that intrude in the space ... and embrace the player if they get
## too close." Three limbs erupt from the dominant breach mouth and cross the
## room -- an overhead arc, a floor run and a low drape, echoing the stage-4
## plate -- inside the SAME batched surface, so however far they reach the
## whole body remains one draw submission.
##
## THEIR EXTENT IS NOT BUILT HERE. The centerlines are authored at full
## length; how much of each limb exists at any moment is the durable exposure
## field's decision, applied in the lineage shader's vertex stage from one
## `intrusion_reach` uniform that DreamMazeRoot derives from the SAME field
## sample the reflected gold light already uses. Beyond the grown fraction the
## tube collapses to a hair-fine filament rather than vanishing -- the brief's
## "fine filaments running ahead of the main mass", and the reason nothing
## ever pops when exposure rises.
##
## DANGER OWNERSHIP, decided deliberately. These limbs are NOT hazard contact
## paths: touching one is not a wound, it is HER -- the ruled consequence is
## the capture, presented through the landed R8 embrace. So the centerlines
## are recorded on this mesh's meta and mirrored onto the source hazard as
## `embrace_paths` for attribution, while `DreamMazeRoot` performs the one
## proximity evaluation next to the embrace it triggers. No CollisionObject3D,
## no damage volume, no second combat system -- and `DreamHazardField` keeps
## sole ownership of every hazard outcome exactly as ruled.
const INTRUSION_LIMBS := 3
const INTRUSION_STEPS := 16
const INTRUSION_SIDES := 12
const INTRUSION_ROOT_RADIUS_M := 0.30
const INTRUSION_TIP_RADIUS_M := 0.045
## Vertex anatomy class for limbs. The registered ids are 0 body, .25 eye,
## .50 false-depth face, .625 living rim, .75 plaster, 1.0 lath; .375 sits
## outside every existing tolerance window (eye is +-0.10, the rest +-0.045).
const INTRUSION_CLASS := 0.375
## Centerline samples are clamped this far inside the room's clear footprint,
## so a limb can drape along a wall but never pierces one. The measured bones
## stay the waking Orison's whatever grows through them.
const INTRUSION_MARGIN_M := 0.34


func configure(live_hazards: Array[DreamHazard], plan: Dictionary) -> void:
	name = "DreamHazardGrowth"
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The body and every eye remain one submitted surface. Four full-precision
	# custom channels let the shader recognise an individual eye without a
	# node, material or draw per instance: center/flag, local side/gaze weight,
	# local up/scale, and blink/rest/target controls.
	for channel in 4:
		tool.set_custom_format(channel, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var ids: Array[String] = []
	var sockets: Array[String] = []
	var eye_records: Array[Dictionary] = []
	var tendril_count := 0
	var contact_path_count := 0
	var membrane_count := 0
	var capillary_count := 0
	var breach_record: Dictionary = {}
	var breach_owner: DreamHazard = null
	var breach_rect: Array = []
	var breach_seed := 0
	var prepared: Array[Dictionary] = []
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
		prepared.append({
			"hazard": hazard,
			"rect": rect,
			"seed": absi(hazard.id.hash()),
		})
	# One eye in the entire live batch is allowed to meet the current camera.
	# Which hazard owns it is deterministic, but the count does not grow with
	# the hazard population. Looking at the player is an event, not wallpaper.
	var tracker_seed := 0
	for prepared_record in prepared:
		tracker_seed = tracker_seed ^ int(prepared_record.seed)
	var tracker_hazard := tracker_seed % prepared.size() \
			if not prepared.is_empty() else -1
	for prepared_index in prepared.size():
		var prepared_record: Dictionary = prepared[prepared_index]
		var built_hazard := prepared_record.hazard as DreamHazard
		var built_rect: Array = prepared_record.rect
		var built_seed := int(prepared_record.seed)
		ids.append(built_hazard.id)
		sockets.append(built_hazard.socket)
		var owns_dominant_breach := prepared_index == tracker_hazard
		var built := _append_hazard(tool, built_hazard, built_rect, built_seed,
				owns_dominant_breach, plan)
		tendril_count += int(built.tendrils)
		eye_records.append_array(built.eye_records)
		contact_path_count += int(built.contact_paths)
		membrane_count += int(built.membranes)
		capillary_count += int(built.capillaries)
		if owns_dominant_breach:
			breach_record = built.breach_record
			breach_owner = built_hazard
			breach_rect = built_rect
			breach_seed = built_seed
	# The limbs go into the same SurfaceTool as everything above, before
	# commit, so the batch stays one surface and one submission.
	var intrusion_record: Dictionary = {}
	if not breach_record.is_empty():
		intrusion_record = _append_intrusion_limbs(tool, breach_record,
				breach_rect, breach_seed)
		if breach_owner != null:
			breach_owner.set_meta("embrace_paths",
					intrusion_record.get("limbs", []))
			breach_owner.set_meta("embrace_owner",
					"DreamMazeRoot/DreamEmbrace")
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
	set_meta("eyes", eye_records.size())
	set_meta("eye_records", eye_records)
	set_meta("eye_family", "seeded_compositional_v1")
	set_meta("eye_debug_views", PackedStringArray([
			"beauty", "rest_and_tracking", "gaze_target"]))
	var closed_or_half := 0
	var direct_trackers := 0
	for eye in eye_records:
		if str(eye.rest_state) in ["closed", "half_lidded"]:
			closed_or_half += 1
		if str(eye.gaze_mode) == "camera":
			direct_trackers += 1
	set_meta("eyes_closed_or_half", closed_or_half)
	set_meta("eyes_tracking_camera", direct_trackers)
	set_meta("contact_paths", contact_path_count)
	set_meta("wall_membranes", membrane_count)
	set_meta("visual_capillaries", capillary_count)
	set_meta("breaches", 0 if breach_record.is_empty() else 1)
	set_meta("breach_record", breach_record)
	set_meta("breach_owner", "DreamHazardField")
	set_meta("breach_rendering", "same_surface_interior_map_v1")
	set_meta("breach_navigation", "false_depth_wall_intact")
	set_meta("breach_debug_views", PackedStringArray([
			"beauty", "surface_ownership", "recession_bands"]))
	set_meta("phase_states", PackedStringArray([
			"ordinary_orison", "rupture", "living_gold"]))
	set_meta("phase_owner", "DreamExposureField")
	set_meta("phase_transition", "continuous_material_ordered_reveal_v1")
	set_meta("phase_warp", "aperture_local_rotational_v1")
	set_meta("phase_stage_thresholds", Vector4(0.10, 0.34, 0.48, 0.78))
	set_meta("phase_gold_thresholds", Vector2(0.70, 0.92))
	set_meta("phase_warp_max_uv", 0.085)
	set_meta("motion_hz", 0.13)
	set_meta("max_sway_m", 0.045)
	set_meta("material_layers", PackedStringArray([
			"subsurface_tissue", "wet_microfilm", "living_gold"]))
	set_meta("intrusion_record", intrusion_record)
	set_meta("intrusion_limbs",
			(intrusion_record.get("limbs", []) as Array).size())
	set_meta("intrusion_owner", "DreamExposureField/DreamMazeRoot")
	set_meta("intrusion_consequence", "capture_via_R8_embrace")
	set_meta("surfaces", mesh.get_surface_count() if mesh != null else 0)


func _append_hazard(tool: SurfaceTool, hazard: DreamHazard, rect: Array,
		seed: int, allow_camera_gaze_and_breach: bool,
		plan: Dictionary) -> Dictionary:
	var core := Vector3(hazard.position.x, 0.10, hazard.position.z)
	var phase := float(seed & 4095) / 4095.0
	var ring_radius := maxf(0.20, hazard.clearance_radius * 0.74)
	var contact_paths: Array[PackedVector3Array] = []
	var tendrils := 0
	var eye_records: Array[Dictionary] = []
	var membranes := 0
	var capillaries := 0
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
			# THE WALL DOES NOT RECEIVE A TENTACLE; IT BECOMES THE SAME
			# ORGANISM.  A shallow cluster of closed tissue lobes spreads behind
			# each load-bearing crawler and laps over the Orison's dado, casing
			# and cornice. It carries no contact path of its own:
			# the substantial limb in front remains the visible and mechanical
			# hazard, while this is the corrupted wall it has grown out of.
			var membrane_normal := plaque_forward
			var membrane_side := plaque_side
			var membrane_up := plaque_up
			var membrane_scale := Vector2(
					0.34 + 0.04 * float((seed >> (branch + 3)) & 3),
					0.42 + 0.05 * float((seed >> (branch + 5)) & 3))
			var built_capillaries := _append_wall_membrane(tool, end,
					membrane_side, membrane_up, membrane_normal,
					membrane_scale, branch_phase, seed + branch * 97, rect)
			membranes += 1
			capillaries += built_capillaries
		# Five compositional anchors per danger, each with a distinct and fully
		# deterministic eye record. Four rest shut or half-lidded; only the
		# selected batch owner may spend its open slot on camera attention.
		if branch in EYE_BRANCHES:
			var eye_slot := EYE_BRANCHES.find(branch)
			var eye := _eye_spec(hazard, seed, eye_slot,
					allow_camera_gaze_and_breach, room_center, core, end)
			var eye_t := float(eye.anchor_t)
			var eye_at := _bezier(start, c1, c2, end, eye_t)
			var target: Vector3 = eye.target
			var look := target - eye_at
			if look.length() < 0.01:
				look = -direction
			eye.anchor = eye_at
			eye.forward = look.normalized()
			_append_eye(tool, eye_at, look.normalized(),
					root_radius * 0.86 * float(eye.scale), branch_phase, eye)
			eye_records.append(eye)
	var breach_record: Dictionary = {}
	if allow_camera_gaze_and_breach:
		breach_record = _append_dominant_breach(tool, hazard, rect, seed, plan)
	hazard.set_contact_paths(contact_paths, CONTACT_TUBE_RADIUS_M)
	return {
		"tendrils": tendrils,
		"eyes": eye_records.size(),
		"eye_records": eye_records,
		"contact_paths": contact_paths.size(),
		"membranes": membranes,
		"capillaries": capillaries,
		"breach_record": breach_record,
	}


## ONE HOLE, NO SECOND WORLD.
##
## The selected dark-live danger tears the positive long wall of its Atlas
## room. The ragged edge, exposed lath and floor crumbs are real triangles in
## the danger's already-submitted surface; the impossible volume is a flat,
## opaque aperture whose shader supplies recession. The authoritative wall is
## deliberately neither cut nor de-collided. Therefore the image can be much
## deeper than the building while navigation, forgetting and provenance stay
## exactly where DreamAtlas and DreamHazard put them.
func _append_dominant_breach(tool: SurfaceTool, hazard: DreamHazard,
		rect: Array, seed: int, plan: Dictionary) -> Dictionary:
	var width := float(rect[2]) - float(rect[0])
	var depth := float(rect[3]) - float(rect[1])
	var side := Vector3.RIGHT
	var normal := Vector3.FORWARD
	var center := Vector3.ZERO
	var edge_margin := BREACH_HALF_WIDTH_M + 0.24
	var along_offset := minf(2.15, maxf(width, depth) * 0.18)
	if width >= depth:
		var along_plus := hazard.position.x + along_offset
		var along_minus := hazard.position.x - along_offset
		var plus_clearance := minf(along_plus - float(rect[0]),
				float(rect[2]) - along_plus)
		var minus_clearance := minf(along_minus - float(rect[0]),
				float(rect[2]) - along_minus)
		var along := along_plus if plus_clearance >= minus_clearance \
				else along_minus
		center = Vector3(clampf(along, float(rect[0]) + edge_margin,
				float(rect[2]) - edge_margin), 1.44, float(rect[3]))
	else:
		side = -Vector3.FORWARD
		normal = -Vector3.RIGHT
		var along_plus := hazard.position.z - along_offset
		var along_minus := hazard.position.z + along_offset
		var plus_clearance := minf(along_plus - float(rect[1]),
				float(rect[3]) - along_plus)
		var minus_clearance := minf(along_minus - float(rect[1]),
				float(rect[3]) - along_minus)
		var along := along_plus if plus_clearance >= minus_clearance \
				else along_minus
		center = Vector3(float(rect[2]), 1.44,
				clampf(along, float(rect[1]) + edge_margin,
				float(rect[3]) - edge_margin))
	center = _move_breach_clear_of_doors(center, side, normal, rect,
			hazard.module, plan, edge_margin)
	# Everything sits just inside the collision plane. The aperture is opaque,
	# so the intact wall behind it cannot flatten the interior-mapped view.
	center += normal * 0.045
	var phase := float(seed & 4095) / 4095.0
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for segment in BREACH_SEGMENTS:
		var angle := TAU * float(segment) / float(BREACH_SEGMENTS)
		var tooth := 0.78 + _breach_noise(seed, segment) * 0.30
		var outer_tooth := 0.86 + _breach_noise(seed + 7919,
				segment) * 0.32
		inner.append(center + side * cos(angle) * BREACH_HALF_WIDTH_M * tooth
				+ Vector3.UP * sin(angle) * BREACH_HALF_HEIGHT_M * tooth
				- normal * 0.010)
		outer.append(center
				+ side * cos(angle) * (BREACH_HALF_WIDTH_M + 0.18)
				* outer_tooth
				+ Vector3.UP * sin(angle) * (BREACH_HALF_HEIGHT_M + 0.17)
				* outer_tooth
				+ normal * (0.030 + 0.026 * _breach_noise(seed + 3571,
				segment)))

	var aperture_custom0 := Color(center.x, center.y, center.z, 0.50)
	var aperture_custom1 := Color(side.x, side.y, side.z,
			BREACH_HALF_WIDTH_M)
	var aperture_custom2 := Color(0.0, 1.0, 0.0, BREACH_HALF_HEIGHT_M)
	var aperture_custom3 := Color(normal.x, normal.y, normal.z, phase)
	var aperture_center := center - normal * 0.012
	for segment in BREACH_SEGMENTS:
		_breach_triangle(tool, aperture_center, inner[segment],
				inner[(segment + 1) % BREACH_SEGMENTS], normal,
				Color(0.0, phase, 0.08, 1.0), aperture_custom0,
				aperture_custom1, aperture_custom2, aperture_custom3)
		# The authoritative wall can be inherited mirrored by the fractal room
		# transform. Keep the false-depth face readable from either winding
		# without disabling culling for the much larger living body.
		_breach_triangle(tool, aperture_center,
				inner[(segment + 1) % BREACH_SEGMENTS], inner[segment], -normal,
				Color(0.0, phase, 0.08, 1.0), aperture_custom0,
				aperture_custom1, aperture_custom2, aperture_custom3)

	# Broken plaster is not a shader mask: the uneven annulus changes the
	# outline, depth and shadow of the wall wound. Alternating protrusion keeps
	# the edge from reading as a clean decorative oval.
	var plaster_custom := Color(center.x, center.y, center.z, 0.75)
	for segment in BREACH_SEGMENTS:
		var next := (segment + 1) % BREACH_SEGMENTS
		_breach_quad(tool, inner[segment] + normal * 0.012,
				outer[segment], outer[next], inner[next] + normal * 0.012,
				normal, Color(0.0, phase, 0.12, 1.0), plaster_custom,
				aperture_custom1, aperture_custom2, aperture_custom3)
	# The organism has swollen through the exposed edge as one continuous,
	# uneven lip. A previous lobe-per-segment version read as gemstones pinned
	# around a portal; the closed tube makes the same real silhouette read as a
	# wound instead, while remaining far too shallow to promise contact.
	var rim_path: Array[Vector3] = []
	for segment in BREACH_SEGMENTS:
		rim_path.append(inner[segment].lerp(outer[segment], 0.38)
				+ normal * 0.026)
	var rim_segments := 0
	var rim_custom := Color(center.x, center.y, center.z, 0.625)
	for segment in BREACH_SEGMENTS:
		# Three exposed plaster gaps stop the lip becoming a decorative portal
		# frame. Radius also changes at every fracture.
		if segment % 6 == 4:
			continue
		var next := (segment + 1) % BREACH_SEGMENTS
		var r0 := 0.058 + 0.056 * _breach_noise(seed + 5003, segment)
		var r1 := 0.058 + 0.056 * _breach_noise(seed + 5003, next)
		_append_tube_segment(tool, rim_path[segment], rim_path[next], r0, r1,
				float(segment) / float(BREACH_SEGMENTS),
				float(next) / float(BREACH_SEGMENTS),
				fmod(phase + 0.143, 1.0), rim_custom, aperture_custom1,
				aperture_custom2, aperture_custom3)
		rim_segments += 1

	# Plaster has torn away from real timber lath. Each row is broken at the
	# middle so the mapped tunnel keeps a legible vanishing point.
	var lath_custom := Color(center.x, center.y, center.z, 1.0)
	var lath_pieces := 0
	for row in 3:
		var row_y := -0.64 + float(row) * 0.62
		var left_inner := -0.12 - 0.055 * _breach_noise(seed + 101, row)
		var right_inner := 0.14 + 0.060 * _breach_noise(seed + 211, row)
		var left_outer := -BREACH_HALF_WIDTH_M * 0.92
		var right_outer := BREACH_HALF_WIDTH_M * 0.92
		var left_center := (left_inner + left_outer) * 0.5
		var right_center := (right_inner + right_outer) * 0.5
		_append_breach_box(tool,
				center + side * left_center + Vector3.UP * row_y
				+ normal * 0.038,
				side, Vector3.UP, normal,
				Vector3(absf(left_inner - left_outer) * 0.5, 0.024, 0.022),
				Color(0.0, phase, 0.24, 1.0), lath_custom,
				aperture_custom1, aperture_custom2, aperture_custom3)
		_append_breach_box(tool,
				center + side * right_center + Vector3.UP * row_y
				+ normal * 0.038,
				side, Vector3.UP, normal,
				Vector3(absf(right_outer - right_inner) * 0.5, 0.024, 0.022),
				Color(0.0, phase, 0.24, 1.0), lath_custom,
				aperture_custom1, aperture_custom2, aperture_custom3)
		lath_pieces += 2

	# Shallow, fist-sized debris says the wall tore toward the player while
	# remaining visibly too small to promise a second collision boundary.
	var rubble_pieces := 0
	for piece in 7:
		var lateral := (-0.72 + float(piece) * 0.24) \
				+ (_breach_noise(seed + 1237, piece) - 0.5) * 0.13
		var rubble_center := Vector3(center.x, 0.045, center.z) \
				+ side * lateral + normal * (0.12
				+ _breach_noise(seed + 1877, piece) * 0.22)
		_append_ellipsoid(tool, rubble_center, side, Vector3.UP, normal,
				Vector3(0.075 + 0.035 * _breach_noise(seed + 2551, piece),
				0.035 + 0.025 * _breach_noise(seed + 3011, piece),
				0.055 + 0.040 * _breach_noise(seed + 3557, piece)),
				0.12, phase, plaster_custom, aperture_custom1,
				aperture_custom2, aperture_custom3)
		rubble_pieces += 1

	return {
		"id": "%s/breach_00" % hazard.id,
		"hazard_id": hazard.id,
		"socket": hazard.socket,
		"module": hazard.module,
		"center": center,
		"normal": normal,
		"side": side,
		"half_width_m": BREACH_HALF_WIDTH_M,
		"half_height_m": BREACH_HALF_HEIGHT_M,
		"aperture_segments": BREACH_SEGMENTS,
		"rim_segments": rim_segments,
		"lath_pieces": lath_pieces,
		"rubble_pieces": rubble_pieces,
		"actual_recess_m": 0.087,
		"apparent_depth_m": BREACH_APPARENT_DEPTH_M,
		"interior": "nested_angular_frame_tunnel",
		"vanishing_point_eye": true,
		"navigation": "authoritative_wall_intact",
	}


## Three full-length limb centerlines out of the breach mouth, and their
## geometry. Deterministic from the breach owner's seed: the same pocket
## rebuild grows the same limbs, which is what lets the CPU's embrace
## evaluation and the GPU's grown fraction agree about a body neither of them
## owns alone.
func _append_intrusion_limbs(tool: SurfaceTool, breach: Dictionary,
		rect: Array, seed: int) -> Dictionary:
	var center: Vector3 = breach.get("center", Vector3.ZERO)
	var inward: Vector3 = (breach.get("normal", Vector3.FORWARD) as Vector3) \
			.normalized()
	var side: Vector3 = (breach.get("side", Vector3.RIGHT) as Vector3) \
			.normalized()
	var limbs: Array = []
	for limb_index in INTRUSION_LIMBS:
		var n0 := _breach_noise(seed + 4099, limb_index)
		var n1 := _breach_noise(seed + 4423, limb_index)
		var n2 := _breach_noise(seed + 4831, limb_index)
		var mouth := center \
				+ side * ((n0 - 0.5) * BREACH_HALF_WIDTH_M * 1.15) \
				+ Vector3.UP * ((n1 - 0.5) * BREACH_HALF_HEIGHT_M * 0.9)
		# Three archetypes from the stage-4 plate: an overhead arc, a floor
		# run, a low drape. Reach and lateral drift then vary per seed so two
		# buildings never grow the same body.
		var reach_len := 2.1 + n2 * 2.3
		var lateral := side * ((n1 - 0.5) * 2.4)
		var apex_y := float([2.30 + n0 * 0.35, 1.05 + 0.30 * n0,
				1.50 + 0.25 * n2][limb_index % 3])
		var tip_y := float([1.10 + 0.45 * n2, 0.24, 0.40][limb_index % 3])
		var p0 := mouth
		var p1 := mouth + inward * (reach_len * 0.34) + lateral * 0.30
		p1.y = lerpf(mouth.y, apex_y, 0.62)
		var p2 := mouth + inward * (reach_len * 0.74) + lateral * 0.80
		p2.y = apex_y
		var p3 := mouth + inward * reach_len + lateral
		p3.y = tip_y
		var points := PackedVector3Array()
		for step in INTRUSION_STEPS + 1:
			var t := float(step) / float(INTRUSION_STEPS)
			points.append(_clamp_into_room(
					_bezier(p0, p1, p2, p3, t), rect))
		# Sway is perpendicular to the eruption so the limb rocks across the
		# corridor rather than pumping in and out of its own wall.
		var sway_dir := inward.cross(Vector3.UP).normalized()
		if sway_dir.length() < 0.5:
			sway_dir = side
		sway_dir = (sway_dir * (1.0 if n2 > 0.5 else -1.0)
				+ Vector3.UP * 0.35).normalized()
		_append_limb_tube(tool, points, n0, mouth, sway_dir,
				0.09 + 0.07 * n1)
		limbs.append(points)
	return {
		"anchor": center + inward * 0.12,
		"limbs": limbs,
		"root_radius_m": INTRUSION_ROOT_RADIUS_M,
		"tip_radius_m": INTRUSION_TIP_RADIUS_M,
		"class": INTRUSION_CLASS,
		"steps": INTRUSION_STEPS,
		"hazard_id": str(breach.get("hazard_id", "")),
		"module": str(breach.get("module", "")),
		"consequence": "capture_via_R8_embrace",
	}


func _clamp_into_room(p: Vector3, rect: Array) -> Vector3:
	if rect.size() < 4:
		return p
	return Vector3(
			clampf(p.x, float(rect[0]) + INTRUSION_MARGIN_M,
					float(rect[2]) - INTRUSION_MARGIN_M),
			clampf(p.y, 0.16, CLEAR_CEILING_M - 0.22),
			clampf(p.z, float(rect[1]) + INTRUSION_MARGIN_M,
					float(rect[3]) - INTRUSION_MARGIN_M))


## A limb tube whose vertices carry what the vertex stage needs to grow it:
## per-ring centre (CUSTOM0.xyz + the .375 class), sway frame (CUSTOM1/2),
## and the ring's own 0..1 position along the limb (CUSTOM3.a). COLOR keeps
## the batch's established meaning exactly -- r flex, g phase, b tissue --
## because b also selects eye shading in the fragment and a limb tip that
## drifted up the blue channel would render as a pupil.
func _append_limb_tube(tool: SurfaceTool, points: PackedVector3Array,
		phase: float, anchor: Vector3, sway_dir: Vector3,
		sway_amp_m: float) -> void:
	if points.size() < 2:
		return
	var last := points.size() - 1
	for ring in last:
		var t0 := float(ring) / float(last)
		var t1 := float(ring + 1) / float(last)
		var a := points[ring]
		var b := points[ring + 1]
		var pulse0 := 0.86 + 0.11 * sin(t0 * TAU * 3.0 + phase * TAU) \
				+ 0.05 * sin(t0 * TAU * 7.0 - phase * 4.0)
		var pulse1 := 0.86 + 0.11 * sin(t1 * TAU * 3.0 + phase * TAU) \
				+ 0.05 * sin(t1 * TAU * 7.0 - phase * 4.0)
		var ra := lerpf(INTRUSION_ROOT_RADIUS_M, INTRUSION_TIP_RADIUS_M,
				pow(t0, 0.78)) * pulse0
		var rb := lerpf(INTRUSION_ROOT_RADIUS_M, INTRUSION_TIP_RADIUS_M,
				pow(t1, 0.78)) * pulse1
		var tangent := (b - a).normalized()
		var ring_side := tangent.cross(Vector3.UP)
		if ring_side.length() < 0.001:
			ring_side = tangent.cross(Vector3.RIGHT)
		ring_side = ring_side.normalized()
		var ring_up := ring_side.cross(tangent).normalized()
		var custom0_a := Color(a.x, a.y, a.z, INTRUSION_CLASS)
		var custom0_b := Color(b.x, b.y, b.z, INTRUSION_CLASS)
		var custom1 := Color(sway_dir.x, sway_dir.y, sway_dir.z, phase)
		var custom2 := Color(anchor.x, anchor.y, anchor.z, sway_amp_m)
		var custom3_a := Color(0.0, 0.0, 0.0, t0)
		var custom3_b := Color(0.0, 0.0, 0.0, t1)
		var color_a := Color(0.22 * sin(t0 * PI), phase, 0.0, 1.0)
		var color_b := Color(0.22 * sin(t1 * PI), phase, 0.0, 1.0)
		for side_index in INTRUSION_SIDES:
			var angle0 := TAU * float(side_index) / float(INTRUSION_SIDES)
			var angle1 := TAU * float(side_index + 1) \
					/ float(INTRUSION_SIDES)
			var n0 := ring_side * cos(angle0) + ring_up * sin(angle0)
			var n1 := ring_side * cos(angle1) + ring_up * sin(angle1)
			var lobe0 := 1.0 + 0.09 * sin(angle0 * 3.0 + phase * TAU)
			var lobe1 := 1.0 + 0.09 * sin(angle1 * 3.0 + phase * TAU)
			var quad_normal := (n0 + n1).normalized()
			for corner in [
					[a + n0 * ra * lobe0, color_a, custom0_a, custom3_a],
					[b + n0 * rb * lobe0, color_b, custom0_b, custom3_b],
					[b + n1 * rb * lobe1, color_b, custom0_b, custom3_b],
					[a + n0 * ra * lobe0, color_a, custom0_a, custom3_a],
					[b + n1 * rb * lobe1, color_b, custom0_b, custom3_b],
					[a + n1 * ra * lobe1, color_a, custom0_a, custom3_a]]:
				tool.set_normal(quad_normal)
				tool.set_color(corner[1])
				tool.set_custom(0, corner[2])
				tool.set_custom(1, custom1)
				tool.set_custom(2, custom2)
				tool.set_custom(3, corner[3])
				tool.add_vertex(corner[0])


func _breach_noise(seed: int, index: int) -> float:
	var hashed := absi(("breach:%d:%d" % [seed, index]).hash())
	return float(hashed & 65535) / 65535.0


## A wall belongs to the room's door schedule before it belongs to the wound.
## Sample the legal longitudinal span only when the preferred point would eat
## a real opening, then take the position with the greatest door clearance.
func _move_breach_clear_of_doors(wanted: Vector3, side: Vector3,
		normal: Vector3, rect: Array, module: String, plan: Dictionary,
		edge_margin: float) -> Vector3:
	var door_spans: Array[Vector2] = []
	for door_value in plan.get("doors", []):
		var door: Dictionary = door_value
		if str(door.get("from", "")) != module \
				and str(door.get("to", "")) != module:
			continue
		var aperture: Array = door.get("aperture", [])
		if aperture.size() < 4:
			continue
		if absf(normal.z) > 0.9:
			var wall_z := (float(aperture[1]) + float(aperture[3])) * 0.5
			if absf(wall_z - float(rect[3])) <= 0.26:
				door_spans.append(Vector2(minf(float(aperture[0]),
						float(aperture[2])), maxf(float(aperture[0]),
						float(aperture[2]))))
		else:
			var wall_x := (float(aperture[0]) + float(aperture[2])) * 0.5
			if absf(wall_x - float(rect[2])) <= 0.26:
				door_spans.append(Vector2(minf(float(aperture[1]),
						float(aperture[3])), maxf(float(aperture[1]),
						float(aperture[3]))))
	if door_spans.is_empty():
		return wanted
	var wanted_along := wanted.x if absf(side.x) > 0.9 else wanted.z
	var wanted_clearance := _breach_door_clearance(wanted_along, door_spans)
	if wanted_clearance >= BREACH_HALF_WIDTH_M + 0.12:
		return wanted
	var low := float(rect[0]) + edge_margin if absf(side.x) > 0.9 \
			else float(rect[1]) + edge_margin
	var high := float(rect[2]) - edge_margin if absf(side.x) > 0.9 \
			else float(rect[3]) - edge_margin
	var best_along := wanted_along
	var best_score := -INF
	for sample in 17:
		var along := lerpf(low, high, float(sample) / 16.0)
		var clearance := _breach_door_clearance(along, door_spans)
		var score := clearance - absf(along - wanted_along) * 0.015
		if score > best_score:
			best_score = score
			best_along = along
	var moved := wanted
	if absf(side.x) > 0.9:
		moved.x = best_along
	else:
		moved.z = best_along
	return moved


func _breach_door_clearance(along: float, spans: Array[Vector2]) -> float:
	var clearance := INF
	for span in spans:
		var distance := 0.0
		if along < span.x:
			distance = span.x - along
		elif along > span.y:
			distance = along - span.y
		clearance = minf(clearance, distance)
	return clearance


func _eye_spec(hazard: DreamHazard, seed: int, slot: int,
		allow_camera_gaze: bool, room_center: Vector3, core: Vector3,
		branch_end: Vector3) -> Dictionary:
	var eye_seed := absi(("%s:eye:%d:%d" % [hazard.id, slot, seed]).hash())
	var rest_state: String = str(EYE_STATES[slot])
	var openness: float = float(EYE_OPENNESS[slot])
	var scale := 0.76 + float((eye_seed >> 11) & 255) / 255.0 * 0.58
	var gaze_mode := "room_center"
	var target := room_center + Vector3.UP * (0.92 + 0.13 * float(slot))
	var target_kind := 0.25
	match slot:
		0:
			gaze_mode = "hazard_root"
			target = core + Vector3.UP * 0.34
			target_kind = 0.0
		1:
			gaze_mode = "branch_tip"
			target = branch_end
			target_kind = 0.50
		2:
			gaze_mode = "room_center"
			target_kind = 0.25
		3:
			gaze_mode = "hazard_root"
			target = core + Vector3.UP * 0.72
			target_kind = 0.0
		4:
			gaze_mode = "branch_tip"
			target = branch_end
			target_kind = 0.50
	if allow_camera_gaze and slot == 4:
		gaze_mode = "camera"
		target = room_center + Vector3.UP * 1.28
		target_kind = 1.0
		rest_state = "open"
		openness = 0.90
		scale = maxf(scale, 1.16)
	return {
		"id": "%s/eye_%02d" % [hazard.id, slot],
		"hazard_id": hazard.id,
		"socket": hazard.socket,
		"anchor_t": 0.43 + float((eye_seed >> 3) & 255) / 255.0 * 0.28,
		"anchor": Vector3.ZERO,
		"scale": scale,
		"rest_state": rest_state,
		"rest_openness": openness,
		"blink_phase": float(eye_seed & 4095) / 4095.0,
		"blink_hz": 0.045 + float((eye_seed >> 19) & 63) / 63.0 * 0.028,
		"gaze_mode": gaze_mode,
		"gaze_weight": 1.0 if gaze_mode == "camera" else 0.0,
		"target": target,
		"target_kind": target_kind,
		"roll_rad": deg_to_rad(-14.0
				+ float((eye_seed >> 25) & 255) / 255.0 * 28.0),
		"forward": Vector3.ZERO,
	}


## A cluster of overlapping, flattened lobes swollen out of the wall.  A
## first attempt used one triangulated fan; in the narrow 2.08 m hall its
## constant normal read as a paper sail beside the camera.  Closed lobes give
## the graft real changing normals, parallax and cast-shadow thickness while
## remaining shallow enough that the wall's collision is still honest.
func _append_wall_membrane(tool: SurfaceTool, center: Vector3,
		side: Vector3, up: Vector3, normal: Vector3, size: Vector2,
		phase: float, seed: int, rect: Array) -> int:
	var heart := center + normal * 0.070
	for lobe in 6:
		var a := phase * TAU + float(lobe) * TAU / 6.0
		var radial := 0.18 + 0.10 * float((seed >> lobe) & 1)
		var at := center + side * cos(a) * size.x * radial \
				+ up * sin(a) * size.y * radial \
				+ normal * (0.038 + 0.008 * float(lobe % 3))
		at.x = clampf(at.x, float(rect[0]) + 0.035,
				float(rect[2]) - 0.035)
		at.y = clampf(at.y, 0.035, CLEAR_CEILING_M - 0.035)
		at.z = clampf(at.z, float(rect[1]) + 0.035,
				float(rect[3]) - 0.035)
		var width_gain := 0.50 + 0.10 * float((seed >> (lobe + 4)) & 3)
		var height_gain := 0.46 + 0.09 * float((seed >> (lobe + 7)) & 3)
		_append_ellipsoid(tool, at, side, up, normal,
				Vector3(size.x * width_gain, size.y * height_gain,
				0.055 + 0.012 * float(lobe % 3)), 0.0,
				fmod(phase + float(lobe) * 0.071, 1.0))

	# Fine veins run ahead over the mouldings.  They remain visibly too thin
	# to promise contact and are not registered with DreamHazard; the thicker
	# parent crawler immediately in front of the patch is the danger.
	var capillaries := 0
	for branch in 7:
		var angle := phase * TAU + float(branch) * TAU / 7.0
		var reach := 0.82 + 0.15 * float((seed >> branch) & 3)
		var finish := center + side * cos(angle) * size.x * reach \
				+ up * sin(angle) * size.y * reach + normal * 0.040
		finish.x = clampf(finish.x, float(rect[0]) + 0.030,
				float(rect[2]) - 0.030)
		finish.y = clampf(finish.y, 0.030, CLEAR_CEILING_M - 0.030)
		finish.z = clampf(finish.z, float(rect[1]) + 0.030,
				float(rect[3]) - 0.030)
		var path: Array[Vector3] = []
		var tangent := side * (-sin(angle)) + up * cos(angle)
		for step in 7:
			var t := float(step) / 6.0
			var point := heart.lerp(finish, t)
			point += tangent * sin(t * PI) * (0.08 if branch % 2 == 0 else -0.06)
			path.append(point)
		_append_tapered_tube(tool, path, 0.031, 0.007,
				fmod(phase + float(branch) * 0.11, 1.0))
		capillaries += 1
	return capillaries


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
		ra: float, rb: float, t0: float, t1: float, phase: float,
		custom0: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom1: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom2: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom3: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
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
				Color(flex1, phase, 0.0, 1.0), custom0, custom1, custom2,
				custom3)


func _append_eye(tool: SurfaceTool, center: Vector3, look: Vector3,
		radius: float, phase: float, eye: Dictionary) -> void:
	var forward := look.normalized()
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var roll := float(eye.roll_rad)
	side = side.rotated(forward, roll)
	up = up.rotated(forward, roll)
	var center_data := Color(center.x, center.y, center.z, 0.25)
	var side_data := Color(side.x, side.y, side.z, float(eye.gaze_weight))
	var up_data := Color(up.x, up.y, up.z, radius)
	var control_data := Color(float(eye.blink_phase),
			float(eye.rest_openness), float(eye.blink_hz),
			float(eye.target_kind))
	# A plum lid is the silhouette. Antique sclera, iris and pupil then sit
	# progressively forward so they cannot vanish inside one opaque sphere.
	# All four volumes carry the same eye record and remain in the batch.
	_append_ellipsoid(tool, center,
			side, up, forward,
			Vector3(radius * 1.46, radius * 0.88, radius * 0.32), 0.0, phase,
			center_data, side_data, up_data, control_data)
	var eye_scale := Vector3(radius * 1.12, radius * 0.62, radius * 0.34)
	_append_ellipsoid(tool, center + forward * radius * 0.20,
			side, up, forward, eye_scale, 0.30, phase,
			center_data, side_data, up_data, control_data)
	_append_ellipsoid(tool, center + forward * radius * 0.52,
			side, up, forward, Vector3(radius * 0.49, radius * 0.49,
			radius * 0.15), 0.62, phase,
			center_data, side_data, up_data, control_data)
	_append_ellipsoid(tool, center + forward * radius * 0.66,
			side, up, forward, Vector3(radius * 0.27, radius * 0.27,
			radius * 0.10), 1.0, phase,
			center_data, side_data, up_data, control_data)


func _append_ellipsoid(tool: SurfaceTool, center: Vector3, side: Vector3,
		up: Vector3, forward: Vector3, radii: Vector3, feature: float,
		phase: float, custom0: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom1: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom2: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom3: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
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
					Color(0.22, phase, feature, 1.0), custom0, custom1,
					custom2, custom3)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, normal: Vector3, color_a: Color, color_b: Color,
		custom0: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom1: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom2: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom3: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	for record in [[a, color_a], [b, color_b], [c, color_b],
			[a, color_a], [c, color_b], [d, color_a]]:
		tool.set_normal(normal)
		tool.set_color(record[1])
		tool.set_custom(0, custom0)
		tool.set_custom(1, custom1)
		tool.set_custom(2, custom2)
		tool.set_custom(3, custom3)
		tool.add_vertex(record[0])


func _breach_triangle(tool: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, wanted_normal: Vector3, color: Color,
		custom0: Color, custom1: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom2: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom3: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var vb := b
	var vc := c
	var face_normal := (vb - a).cross(vc - a).normalized()
	if face_normal.dot(wanted_normal) < 0.0:
		vb = c
		vc = b
		face_normal = -face_normal
	for point in [a, vb, vc]:
		tool.set_normal(face_normal)
		tool.set_color(color)
		tool.set_custom(0, custom0)
		tool.set_custom(1, custom1)
		tool.set_custom(2, custom2)
		tool.set_custom(3, custom3)
		tool.add_vertex(point)


func _breach_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, wanted_normal: Vector3, color: Color,
		custom0: Color, custom1: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom2: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom3: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	_breach_triangle(tool, a, b, c, wanted_normal, color, custom0, custom1,
			custom2, custom3)
	_breach_triangle(tool, a, c, d, wanted_normal, color, custom0, custom1,
			custom2, custom3)


func _append_breach_box(tool: SurfaceTool, center: Vector3, side: Vector3,
		up: Vector3, normal: Vector3, half_size: Vector3, color: Color,
		custom0: Color, custom1: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom2: Color = Color(0.0, 0.0, 0.0, 0.0),
		custom3: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var sx := side * half_size.x
	var uy := up * half_size.y
	var nz := normal * half_size.z
	var p000 := center - sx - uy - nz
	var p001 := center - sx - uy + nz
	var p010 := center - sx + uy - nz
	var p011 := center - sx + uy + nz
	var p100 := center + sx - uy - nz
	var p101 := center + sx - uy + nz
	var p110 := center + sx + uy - nz
	var p111 := center + sx + uy + nz
	_breach_quad(tool, p001, p101, p111, p011, normal, color, custom0,
			custom1, custom2, custom3)
	_breach_quad(tool, p100, p000, p010, p110, -normal, color, custom0,
			custom1, custom2, custom3)
	_breach_quad(tool, p101, p100, p110, p111, side, color, custom0,
			custom1, custom2, custom3)
	_breach_quad(tool, p000, p001, p011, p010, -side, color, custom0,
			custom1, custom2, custom3)
	_breach_quad(tool, p011, p111, p110, p010, up, color, custom0,
			custom1, custom2, custom3)
	_breach_quad(tool, p000, p100, p101, p001, -up, color, custom0,
			custom1, custom2, custom3)


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
