extends Node
## M0.5 check 2, rung 3 — per-pixel BUFFER OWNERSHIP of the street frame.
##
## The ladder in §10ab said "then one buffer at a time". That is N renders
## and N diffs to answer one question: which merged buffer owns each black
## mass. A false-colour pass answers it for EVERY pixel at once: give every
## GeometryInstance3D that actually renders into the street camera's world a
## unique unshaded colour, render the same camera, and the frame IS the
## ownership map. No differencing, so no aligned-pair problem and no "small
## diff means not guilty" inference.
##
## This does NOT promote the evidence above buffer level. A merged
## per-(floor, category) buffer still answers as one node, and which
## generator record inside it drew the geometry is stage two: enumerate the
## records feeding that floor/category/material and restrict by coordinate.
## Merged AABB size is still not provenance.
##
## THE PALETTE DOES NOT WRAP. 4725 instances render in the main world and a
## 16-step channel grid holds 4095, so the frame is painted in
## ceil(n/4095) passes from the frozen camera: in each pass one chunk gets
## real ids and everything else gets reserved id 0, and the reader merges.
## No colour is ever reused. A finer grid was measured and rejected: Godot's
## dark-end sRGB round trip is not exact — nominal 8 lands at 1, 24 at 21,
## 40 at 38, 56 at 55 — so the 19-levels-per-channel that would fit every
## instance in one pass sits inside the round-trip error. 16 steps clear it
## by a factor of two, and the reader snaps to the nearest level.
##
## SEE-THROUGH SURFACES ARE HIDDEN, NOT PAINTED. An opaque override turns
## every transparent surface solid and it then swallows whatever stood
## behind it. The first run of this pass credited 23% of the frame to
## WeatherFX `_ground_flash` (weather_fx.gd:142), a 34 x 26 m quad with
## BLEND_MODE_ADD and albedo alpha 0.0 — a surface that can only ever
## brighten and was contributing nothing at all.
##
## StreetTraffic is hidden by default: rung 2 eliminated it, and it is the
## only mass that moves between saves. SHOT_HIDE overrides.
##
##     SHOT_DIR=C:/... godot --path game res://tests/StreetIdShot.tscn

## 16 levels per channel, minus the reserved id 0.
const CHUNK := 4095

var root: Node3D
var cam: Camera3D
var _eligible: Array[GeometryInstance3D] = []
var _entries: Array = []
var _world: World3D
var _vp: Viewport


func _ready() -> void:
	# Same pin as street_shot.gd: the day/night director reads the wall
	# clock, and every save in this run must differ by the override alone.
	if OS.get_environment("DAYNIGHT_FORCE") == "":
		OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(2.0).timeout

	var hide_env := OS.get_environment("SHOT_HIDE")
	if hide_env == "":
		hide_env = "StreetTraffic"
	var tokens: Array[String] = []
	for t in hide_env.split(","):
		var s := t.strip_edges()
		if s != "":
			tokens.append(s)
	for c in get_tree().root.get_children():
		_sweep(c, tokens)

	cam = Camera3D.new()
	cam.fov = 70
	add_child(cam)
	cam.make_current()
	root.view_override = cam
	if OS.get_environment("ID_CAMERA") == "GATEWAY_EAST":
		# Exact K0 approach 02. This mode exists to attribute the broad dark
		# silhouette which the beauty frame alone misidentified as the kiosk.
		cam.fov = 72.0
		cam.global_position = GameBoot.b2g([24.0, -23.9, 1.68])
		cam.look_at(GameBoot.b2g([16.0, -28.4, 1.70]))
	else:
		# Identical to street_shot.gd. If that camera moves, move this one.
		cam.global_position = GameBoot.b2g([-16.0, -13.5, 1.68])
		cam.look_at(GameBoot.b2g([26.0, -19.6, 1.30]))
	await get_tree().create_timer(3.0).timeout

	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		push_error("[IDMAP] SHOT_DIR unset")
		get_tree().quit(1)
		return
	await _save("%s/beauty.png" % dir)
	_prepare()
	var passes: int = ceili(float(_eligible.size()) / float(CHUNK))
	print("[IDMAP] %d instances over %d pass(es)" % [_eligible.size(), passes])
	for k in passes:
		_paint(k)
		await get_tree().process_frame
		await get_tree().process_frame
		await _save("%s/id_%d.png" % [dir, k])
	_legend(dir)
	_rays(dir)
	get_tree().quit(0)


func _sweep(n: Node, tokens: Array[String]) -> void:
	if n is CanvasLayer:
		n.visible = false
	if n is Label3D:
		n.visible = false
	if n is Node3D:
		for t in tokens:
			if String(n.name).findn(t) >= 0:
				(n as Node3D).visible = false
				print("[IDMAP] hidden %s" % n.name)
				break
	for c in n.get_children():
		_sweep(c, tokens)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[IDMAP] saved %s" % path)


## Unshaded, unfogged, untonemapped, so the colour that leaves the shader is
## the colour that lands in the PNG. Anything else and the legend is fiction.
func _prepare() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.glow_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = false
	cam.environment = env
	var attrs := CameraAttributesPractical.new()
	attrs.auto_exposure_enabled = false
	attrs.exposure_multiplier = 1.0
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_near_enabled = false
	cam.attributes = attrs

	_vp = get_viewport()
	_world = _vp.find_world_3d()
	var all: Array[GeometryInstance3D] = []
	for c in get_tree().root.get_children():
		_collect(c, all)
	var seethrough := 0
	for g in all:
		if _is_see_through(g):
			g.visible = false
			seethrough += 1
			print("[IDSKIP] %s" % get_tree().root.get_path_to(g))
	print("[IDMAP] %d see-through instances hidden" % seethrough)
	for g in all:
		if g.is_visible_in_tree():
			_eligible.append(g)


func _paint(pass_index: int) -> void:
	for i in _eligible.size():
		var slot: int = i - pass_index * CHUNK + 1
		var named: bool = slot >= 1 and slot <= CHUNK
		var col: Color = _colour(slot if named else 0)
		if named:
			var g := _eligible[i]
			_entries.append({
				"pass": pass_index,
				"col": col,
				"cls": g.get_class(),
				"path": String(get_tree().root.get_path_to(g)),
				"aabb": (g.global_transform * _aabb_of(g)).size,
				"detail": _instance_detail(g),
			})
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.disable_ambient_light = true
		m.vertex_color_use_as_albedo = false
		_eligible[i].material_override = m


## Anything that is not plain opaque MIX. A ShaderMaterial has no
## transparency property to read, so read its source: a spatial shader is
## opaque unless it writes ALPHA or declares a non-opaque render mode. That
## is not cosmetic — the puddle batch (exterior_detail_pass.gd:504) is
## `blend_mix, depth_prepass_alpha` and was being painted solid, which is
## the WeatherFX mistake again at 0.22% of the frame instead of 23%.
## Shaders that survive the test are still named in the log, because
## "opaque as far as I could tell" is worth being able to audit.
func _is_see_through(g: GeometryInstance3D) -> bool:
	for m in _materials_of(g):
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				return true
			if bm.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
				return true
		elif m is ShaderMaterial:
			var sh: Shader = (m as ShaderMaterial).shader
			var code := sh.code if sh != null else ""
			print("[IDSHADER] %s%s" % [get_tree().root.get_path_to(g),
					"  SEE-THROUGH" if _shader_blends(code) else "  opaque"])
			if _shader_blends(code):
				return true
	return false


func _shader_blends(code: String) -> bool:
	for token in ["blend_add", "blend_sub", "blend_mul", "depth_prepass_alpha",
			"depth_draw_never", "ALPHA", "ALPHA_SCISSOR"]:
		if code.find(token) >= 0:
			return true
	return false


func _materials_of(g: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if g.material_override != null:
		out.append(g.material_override)
	if g.material_overlay != null:
		out.append(g.material_overlay)
	var mesh: Mesh = null
	if g is MeshInstance3D:
		# get_active_material resolves override -> surface override -> mesh,
		# which a bare mesh.surface_get_material would miss.
		var mi := g as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var am: Material = mi.get_active_material(i)
				if am != null:
					out.append(am)
	elif g is MultiMeshInstance3D:
		var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
		mesh = mm.mesh if mm != null else null
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	elif g is GPUParticles3D:
		mesh = (g as GPUParticles3D).draw_pass_1
	if mesh != null:
		for i in mesh.get_surface_count():
			var sm: Material = mesh.surface_get_material(i)
			if sm != null:
				out.append(sm)
	return out


func _aabb_of(g: GeometryInstance3D) -> AABB:
	if g is VisualInstance3D:
		return (g as VisualInstance3D).get_aabb()
	return AABB()


func _instance_detail(g: GeometryInstance3D) -> String:
	var parts: Array[String] = []
	if g is MultiMeshInstance3D:
		var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
		if mm != null:
			parts.append("instances=%d" % mm.instance_count)
			if mm.mesh != null:
				parts.append("mesh=%s" % mm.mesh.resource_name)
	for mat in _materials_of(g):
		var label := mat.resource_name
		if label == "":
			label = mat.get_class()
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			label += "@%.3f,%.3f,%.3f" % [sm.albedo_color.r,
					sm.albedo_color.g, sm.albedo_color.b]
		parts.append("mat=" + label)
	return ";".join(parts)


func _collect(n: Node, out: Array[GeometryInstance3D]) -> void:
	# SubViewports carry their own World3D (arcade_machine.gd:82). Recursing
	# into them is what produced the SwcGraybox false positive.
	if n is SubViewport:
		return
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		if (g.get_world_3d() == _world and g.get_viewport() == _vp
				and g.is_visible_in_tree()):
			out.append(g)
	for c in n.get_children():
		_collect(c, out)


## Index 0 is reserved for "not named in this pass" and must be resolved by
## another pass. Pure black is the background and belongs to nothing.
func _colour(i: int) -> Color:
	var n := i % 4096
	return Color8((n % 16) * 16 + 8, ((n / 16) % 16) * 16 + 8,
			((n / 256) % 16) * 16 + 8)


func _legend(dir: String) -> void:
	print("[IDMAP] painted %d instances" % _entries.size())
	var file := FileAccess.open("%s/legend.tsv" % dir, FileAccess.WRITE)
	file.store_line("pass\trgb\tclass\taabb\tdetail\tpath")
	for e in _entries:
		var c: Color = e["col"]
		var s: Vector3 = e["aabb"]
		var line := "%d\t%d,%d,%d\t%s\t%.1fx%.1fx%.1f\t%s\t%s" % [e["pass"],
				c.r8, c.g8, c.b8, e["cls"], s.x, s.y, s.z, e["detail"],
				e["path"]]
		print("[IDLEG] " + line)
		file.store_line(line)


## Stage two needs the camera's own ray for a chosen pixel. Rather than
## re-run Godot once per pixel of interest, print the camera and a fixed
## calibration set — frame corners, edge midpoints and centre — so the
## reader can build rays itself and CHECK them against the engine's before
## trusting a single one. PROBE_PIXELS ("x,y;x,y;...") adds more.
func _rays(dir: String) -> void:
	var xf := cam.global_transform
	var size := get_viewport().get_visible_rect().size
	print("[IDCAM] fov=%.6f near=%.6f size=%d,%d keep=%d"
			% [cam.fov, cam.near, int(size.x), int(size.y), cam.keep_aspect])
	print("[IDCAM] origin\t%.6f,%.6f,%.6f" % [xf.origin.x, xf.origin.y,
			xf.origin.z])
	print("[IDCAM] basis_x\t%.6f,%.6f,%.6f" % [xf.basis.x.x, xf.basis.x.y,
			xf.basis.x.z])
	print("[IDCAM] basis_y\t%.6f,%.6f,%.6f" % [xf.basis.y.x, xf.basis.y.y,
			xf.basis.y.z])
	print("[IDCAM] basis_z\t%.6f,%.6f,%.6f" % [xf.basis.z.x, xf.basis.z.y,
			xf.basis.z.z])
	var spec := "0,0;%d,0;0,%d;%d,%d;%d,%d" % [int(size.x) - 1,
			int(size.y) - 1, int(size.x) - 1, int(size.y) - 1,
			int(size.x) / 2, int(size.y) / 2]
	var extra := OS.get_environment("PROBE_PIXELS")
	if extra == "":
		var f := FileAccess.open("%s/probe_pixels.txt" % dir, FileAccess.READ)
		if f != null:
			extra = f.get_as_text().strip_edges().replace("\n", ";")
	if extra != "":
		spec += ";" + extra
	var hit_file := FileAccess.open("%s/instance_hits.tsv" % dir,
			FileAccess.WRITE)
	hit_file.store_line("pixel\tbuffer\tindex\tt\tmin\tsize\tcolor")
	for item in spec.split(";"):
		var t := item.strip_edges()
		if t == "":
			continue
		var xy := t.split(",")
		if xy.size() != 2:
			continue
		var p := Vector2(float(xy[0]), float(xy[1]))
		var o := cam.project_ray_origin(p)
		var d := cam.project_ray_normal(p)
		print("[IDRAY] %d,%d\t%.4f,%.4f,%.4f\t%.6f,%.6f,%.6f"
				% [int(p.x), int(p.y), o.x, o.y, o.z, d.x, d.y, d.z])
		_record_multimesh_hits(hit_file, p, o, d)


func _record_multimesh_hits(file: FileAccess, pixel: Vector2,
		origin: Vector3, direction: Vector3) -> void:
	for g in _eligible:
		if not g is MultiMeshInstance3D:
			continue
		var node := g as MultiMeshInstance3D
		var mm := node.multimesh
		if mm == null or mm.mesh == null or mm.instance_count != 137:
			continue
		for i in mm.instance_count:
			var box: AABB = (node.global_transform
					* mm.get_instance_transform(i)) * mm.mesh.get_aabb()
			var distance := _ray_aabb(origin, direction, box)
			if distance < 0.0:
				continue
			var c := mm.get_instance_color(i)
			file.store_line("%d,%d\t%s\t%d\t%.4f\t%.3f,%.3f,%.3f\t"
					% [int(pixel.x), int(pixel.y), node.get_path(), i,
						distance, box.position.x, box.position.y, box.position.z]
					+ "%.3f,%.3f,%.3f\t%.3f,%.3f,%.3f" % [box.size.x,
						box.size.y, box.size.z, c.r, c.g, c.b])


func _ray_aabb(origin: Vector3, direction: Vector3, box: AABB) -> float:
	var t_near := 0.0
	var t_far := INF
	for axis in 3:
		var lo := box.position[axis]
		var hi := box.end[axis]
		if absf(direction[axis]) < 0.000001:
			if origin[axis] < lo or origin[axis] > hi:
				return -1.0
			continue
		var a := (lo - origin[axis]) / direction[axis]
		var b := (hi - origin[axis]) / direction[axis]
		if a > b:
			var swap := a
			a = b
			b = swap
		t_near = maxf(t_near, a)
		t_far = minf(t_far, b)
		if t_near > t_far:
			return -1.0
	return t_near if t_far >= 0.0 else -1.0
