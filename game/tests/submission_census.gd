extends Node
## WHAT a selected performance station can submit, attributed four ways:
## render pass (beauty vs shadow), zone/owner, generated prefix, and
## material/surface identity — measured, not inferred from toggles.
##
##     godot --path game --resolution 2560x1440 res://tests/SubmissionCensus.tscn
##
## Two instruments, reconciled against each other in one run:
##  - Viewport.get_render_info asks for VISIBLE and SHADOW pass totals. Some
##    Compatibility builds collapse every call into VISIBLE and return zero for
##    SHADOW; that backend result is detected and labelled, never presented as
##    a successful reconciliation.
##  - A frustum census (RenderingServer.instances_cull_convex, the same
##    culler the engine uses) walks every GeometryInstance3D that can
##    reach the frame and counts its surfaces (a surface is a draw call
##    in a pass), its shadow-caster status, its transparency, and its
##    owner. Shadow influence is attributed per light: for every visible
##    shadowed light, which casters sit inside its radius.
##
## The census's surface sums must land near the measured totals or the
## attribution is fiction; the reconciliation line prints both.

const PERF := preload("res://tests/perf_probe.gd")
const WARMUP := 30
const SAMPLES := 45
const PLAYABLE_STREET := {
	"name": "street north pavement (player at lens)",
	"pos": Vector3(-16.0, 1.68, 13.5),
	"look": Vector3(26.0, 1.30, 19.6),
	"player_at_lens": true,
}

var root: Node3D
var cam: Camera3D
var _hold_orison_core_shadows := false


func _ready() -> void:
	# Diagnostic controls run after production light owners each frame, so their
	# state cannot be silently overwritten between the toggle and render submit.
	process_priority = 1000
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	root.light_rig.set_budgets(PERF.PINNED_LIGHT_BUDGET,
			PERF.PINNED_SHADOW_BUDGET)
	for c in root.get_children():
		if c is CanvasLayer:
			c.visible = false
	await get_tree().create_timer(1.5).timeout
	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	var station: Dictionary = PERF.STATIONS[10]
	if OS.get_environment("SUB_PLAYABLE_STREET") == "1":
		station = PLAYABLE_STREET
	var wanted := OS.get_environment("SUB_STATION")
	if wanted != "":
		for s in PERF.STATIONS:
			if String(s["name"]).findn(wanted) >= 0:
				station = s
				break
	cam.global_position = station["pos"]
	cam.look_at(station["look"])
	if bool(station.get("player_at_lens", false)):
		root.player.global_position = cam.global_position - Vector3(
				0.0, PlayerController.STANDING_EYE, 0.0)
		root.player.velocity = Vector3.ZERO
		root.player.set_physics_process(false)
		# This station models ordinary play, not a flying diagnostic camera.
		# BuildingRoot streams from the controller's feet in production. Leaving
		# the camera override active asks it about eye height instead, which sits
		# inside the 1.75 m overlap band for F02 and submits a second storey that
		# the real player never sees here. LightRig independently derives feet
		# height from a detached camera, so clearing this is correct for both.
		root.view_override = null
	for i in WARMUP:
		await get_tree().process_frame
	# A stationary attribution run may freeze the already-resolved fixture
	# ranking so a shadow-only control cannot be overwritten by LightRig's next
	# 0.2 s update. Use the same freeze in its fresh-process baseline.
	if OS.get_environment("SUB_FREEZE_LIGHTS") == "1" \
			or OS.get_environment("SUB_ORISON_CORE_SHADOWS_OFF") == "1":
		root.light_rig.set_process(false)
	if OS.get_environment("SUB_ORISON_CORE_SHADOWS_OFF") == "1":
		_hold_orison_core_shadows = true
		_suppress_orison_core_light_shadows(root)

	# Ground truth: pass-split totals and frame time.
	var vp := get_viewport()
	var ms := 0.0
	for i in SAMPLES:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		ms += (Time.get_ticks_usec() - t0) / 1000.0
	ms /= SAMPLES
	var vis_obj := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,
			Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
	var vis_calls := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,
			Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var sh_obj := vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW,
			Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
	var sh_calls := vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW,
			Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("[SUB] %s  %.2f ms  budget %d/%d" % [station["name"], ms,
			root.light_rig._active_budget, root.light_rig._shadow_budget])
	print("[SUB] PASS SPLIT  visible %d obj / %d calls   shadow %d obj / %d calls"
			% [vis_obj, vis_calls, sh_obj, sh_calls])
	var split_available := sh_obj > 0 or sh_calls > 0
	if not split_available:
		print("[SUB] PASS SPLIT UNAVAILABLE on %s: VISIBLE is backend-total; "
				% RenderingServer.get_current_rendering_method()
				+ "SHADOW is zero and must not be treated as ground truth")

	# The frustum set, per the engine's own culler.
	var world := vp.find_world_3d()
	var inside := {}
	for oid in RenderingServer.instances_cull_convex(cam.get_frustum(),
			world.scenario):
		inside[oid] = true

	var per_owner := {}
	var geo: Array = []
	_collect(root, geo)
	var frustum_objs := 0
	var frustum_surfaces := 0
	var caster_objs := 0
	var caster_surfaces := 0
	var transparent_surfaces := 0
	for g in geo:
		if not _submits(g):
			continue
		if not inside.has(g.get_instance_id()):
			continue
		var surfaces := _surface_count(g)
		var casts: bool = g.cast_shadow != \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		frustum_objs += 1
		frustum_surfaces += surfaces
		if casts:
			caster_objs += 1
			caster_surfaces += surfaces
		transparent_surfaces += _transparent_surfaces(g)
		var key := _owner_key(g)
		if not per_owner.has(key):
			per_owner[key] = {"objs": 0, "surf": 0, "cast_surf": 0,
					"trans": 0}
		per_owner[key]["objs"] += 1
		per_owner[key]["surf"] += surfaces
		if casts:
			per_owner[key]["cast_surf"] += surfaces
		per_owner[key]["trans"] += _transparent_surfaces(g)
	print("[SUB] FRUSTUM  %d objs / %d surfaces (%d transparent); casters %d objs / %d surfaces"
			% [frustum_objs, frustum_surfaces, transparent_surfaces,
			caster_objs, caster_surfaces])
	if split_available:
		print("[SUB] reconciliation: census surfaces %d vs measured visible calls %d"
				% [frustum_surfaces, vis_calls])
	else:
		print("[SUB] non-reconciliation: %d frustum beauty surfaces vs %d "
				% [frustum_surfaces, vis_calls]
				+ "backend-total calls (including repeated passes)")

	var rows: Array = []
	for k in per_owner:
		rows.append([per_owner[k]["surf"], k, per_owner[k]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("[SUB] %-44s %6s %6s %8s %6s" % ["owner (zone)", "objs", "surf",
			"castsurf", "trans"])
	for r in rows.slice(0, 30):
		var d: Dictionary = r[2]
		print("[SUB] %-44s %6d %6d %8d %6d" % [r[1], d["objs"], d["surf"],
				d["cast_surf"], d["trans"]])

	# Shadowed lights: which casters live inside each radius. Every such
	# pairing is geometry re-rendered into that light's shadow views.
	var lights: Array = []
	_lights(root, lights)
	var shadow_rows: Array = []
	for light in lights:
		if not light.visible or not light.is_visible_in_tree():
			continue
		if not light.shadow_enabled:
			continue
		var pos: Vector3 = light.global_position
		var radius: float = light.omni_range if light is OmniLight3D \
				else (light.spot_range if light is SpotLight3D else 0.0)
		var n_casters := 0
		var n_surf := 0
		for g in geo:
			if not _submits(g):
				continue
			if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var aabb: AABB = g.global_transform * _aabb_of(g)
			var closest := aabb.position.clamp(pos - Vector3.ONE * 1e6,
					pos)
			# distance from light to AABB
			var d := (aabb.get_center() - pos).length() \
					- aabb.get_longest_axis_size() * 0.5
			if d <= radius:
				n_casters += 1
				n_surf += _surface_count(g)
		var lp: Vector3 = light.global_position
		shadow_rows.append([n_surf, String(light.get_parent().name) + "/"
				+ String(light.name), light.get_class(), n_casters, radius,
				"(%.1f, %.1f, %.1f)" % [lp.x, lp.y, lp.z]])
	shadow_rows.sort_custom(func(a, b): return a[0] > b[0])
	print("[SUB] %d shadowed lights in tree; caster overlap per light:"
			% shadow_rows.size())
	for r in shadow_rows.slice(0, 20):
		print("[SUB]   %-44s %-12s r=%5.1f  casters %4d  surfaces %5d  at %s"
				% [r[1], r[2], r[4], r[3], r[0], r[5]])

	# Root-parented owners are outside the F01 ownership sweep entirely.
	# Which of the frustum set's owners hang off root (or a non-F01
	# floor), and does the ruled envelope call them foreign or Passage?
	print("[SUB] root-parented frustum owners vs the envelope:")
	var seen := {}
	for g in geo:
		if not _submits(g) or not inside.has(g.get_instance_id()):
			continue
		var top: Node = g
		while top.get_parent() != null and top.get_parent() != root:
			top = top.get_parent()
		if root.floor_nodes.values().has(top):
			continue
		var key := String(top.name)
		if seen.has(key):
			seen[key]["objs"] += 1
			continue
		var aabb: AABB = g.global_transform * _aabb_of(g)
		seen[key] = {"objs": 1, "side": _side(aabb)}
	var rrows: Array = []
	for k in seen:
		rrows.append([seen[k]["objs"], k, seen[k]["side"]])
	rrows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rrows.slice(0, 20):
		print("[SUB]   %-40s %5d objs  first-node side: %s"
				% [r[1], r[0], r[2]])

	# SUB_DIAG=1: the two remaining-ceiling measurements. Diagnostic
	# only — the first is the banned global shadow control scoped to
	# whatever is still shadowed here, the second hides everything but
	# the shell. Neither is a shippable policy; together they bound what
	# submission-side surgery could ever recover at this station.
	if OS.get_environment("SUB_DIAG") == "1":
		var base := await _ms()
		var toggled: Array = []
		for light in lights:
			if light is OmniLight3D or light is SpotLight3D:
				if light.shadow_enabled:
					toggled.append(light)
					light.shadow_enabled = false
		var no_shadow := await _ms()
		for light in toggled:
			light.shadow_enabled = true
		var hidden: Array = []
		for g in geo:
			if _submits(g) and inside.has(g.get_instance_id()) \
					and not root.passage_shell_nodes.has(g):
				hidden.append(g)
				g.visible = false
		var shell_only := await _ms()
		for g in hidden:
			if is_instance_valid(g):
				g.visible = true
		var neither_ms := 0.0
		for light in toggled:
			light.shadow_enabled = false
		for g in hidden:
			if is_instance_valid(g):
				g.visible = false
		neither_ms = await _ms()
		for light in toggled:
			light.shadow_enabled = true
		for g in hidden:
			if is_instance_valid(g):
				g.visible = true
		print("[SUB] DIAG base %.2f | local shadows off (%d lights) %.2f | shell-only %.2f | both %.2f"
				% [base, toggled.size(), no_shadow, shell_only, neither_ms])
	get_tree().quit(0)


func _process(_delta: float) -> void:
	if _hold_orison_core_shadows and root != null:
		_suppress_orison_core_light_shadows(root, false)


func _ms() -> float:
	for i in 10:
		await get_tree().process_frame
	var total := 0.0
	for i in SAMPLES:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		total += (Time.get_ticks_usec() - t0) / 1000.0
	return total / SAMPLES


## Same envelope as _point_is_in_passage, coarse: which side a sample
## AABB of the owner falls on. Attribution lead, not a classification.
func _side(world: AABB) -> String:
	var c := world.get_center()
	var in_throat := c.x >= 11.0 and c.x <= 17.0 \
			and c.z > 28.316 and c.z <= 38.6
	var in_hall := c.x >= 4.0 and c.x <= 24.0 \
			and c.z > 38.6 and c.z <= 64.6
	return "PASSAGE" if (in_throat or in_hall) else "foreign"


func _owner_key(g: Node) -> String:
	var zone := "orison"
	if root.passage_interior_nodes.has(g) \
			or root.passage_late_interior_nodes.has(g):
		zone = "PASSAGE-interior"
	elif root.passage_shell_nodes.has(g):
		zone = "PASSAGE-shell"
	elif String(g.name).contains("_retail_passage_proxy_"):
		zone = "STREET-proxy"
	var top: Node = g
	while top.get_parent() != null and top.get_parent() != root \
			and not (top.get_parent() in root.floor_nodes.values()):
		top = top.get_parent()
	var label := String(top.name)
	# merged glTF buffers carry their identity in the node name already
	if g is MeshInstance3D and top == g:
		label = String(g.name)
	return "%s (%s)" % [label.substr(0, 36), zone]


func _surface_count(g: Node) -> int:
	if g is MeshInstance3D and g.mesh != null:
		return g.mesh.get_surface_count()
	if g is MultiMeshInstance3D and g.multimesh != null \
			and g.multimesh.mesh != null:
		return g.multimesh.mesh.get_surface_count()
	return 1


func _transparent_surfaces(g: Node) -> int:
	var n := 0
	if g is MeshInstance3D and g.mesh != null:
		for i in g.mesh.get_surface_count():
			var m: Material = g.get_active_material(i)
			if m is BaseMaterial3D and (m as BaseMaterial3D).transparency \
					!= BaseMaterial3D.TRANSPARENCY_DISABLED:
				n += 1
	return n


func _aabb_of(g: Node) -> AABB:
	if g is VisualInstance3D:
		return (g as VisualInstance3D).get_aabb()
	return AABB()


## `visible` is only one of the two zone-gate writers. Root-parented runtime
## builders retain their authored visibility and are composed out by setting
## render layers to zero. Counting those nodes as frame submissions produced
## a plausible-looking but false list of Passage cabinets in a STREET frame.
func _submits(g: GeometryInstance3D) -> bool:
	return g.is_visible_in_tree() and g.layers != 0


## Narrow outdoor-lighting candidate: preserve every light, but remove shadow
## maps from sources physically inside the Orison shell. Entry/facade sources,
## the player's phone, the moon and Passage lights all lie outside this box.
func _suppress_orison_core_light_shadows(scene_root: Node,
		report := true) -> int:
	var pending: Array[Node] = [scene_root]
	var suppressed := 0
	var names: Array[String] = []
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is SubViewport:
			continue
		if node is Light3D and not (node is DirectionalLight3D):
			var light := node as Light3D
			var p := light.global_position
			if light.shadow_enabled \
					and absf(p.x) <= LightRig.ORISON_CORE_HALF_X \
					and absf(p.z) <= LightRig.ORISON_CORE_HALF_Z:
				light.shadow_enabled = false
				suppressed += 1
				if report:
					names.append("%s/%s" % [light.get_parent().name,
							light.name])
		for child in node.get_children():
			pending.append(child)
	if report:
		print("[SUB] ORISON-CORE LIGHT SHADOW CONTROL: %d lights suppressed"
				% suppressed)
		print("[SUB]   " + ", ".join(names))
	return suppressed


func _collect(n: Node, out: Array) -> void:
	if n is SubViewport:
		return
	if n is GeometryInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


func _lights(n: Node, out: Array) -> void:
	# Arcade cabinets own an isolated World3D. Their four `lamp_*` lights have
	# plausible world coordinates but cannot illuminate or shadow this viewport;
	# counting them recreated the SwcGraybox false positive in a new form.
	if n is SubViewport:
		return
	if n is Light3D:
		out.append(n)
	for c in n.get_children():
		_lights(c, out)
