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
	_legend()
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
			})
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.disable_ambient_light = true
		m.vertex_color_use_as_albedo = false
		_eligible[i].material_override = m


## Anything that is not plain opaque MIX. A ShaderMaterial cannot be read
## this way, so it is treated as solid and named in the log — if a shader
## surface ever wins pixels, that answer needs checking by hand.
func _is_see_through(g: GeometryInstance3D) -> bool:
	for m in _materials_of(g):
		if m is BaseMaterial3D:
			var bm := m as BaseMaterial3D
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				return true
			if bm.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
				return true
		elif m is ShaderMaterial:
			print("[IDSHADER] %s" % get_tree().root.get_path_to(g))
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


func _legend() -> void:
	print("[IDMAP] painted %d instances" % _entries.size())
	for e in _entries:
		var c: Color = e["col"]
		var s: Vector3 = e["aabb"]
		print("[IDLEG] %d\t%d,%d,%d\t%s\t%.1fx%.1fx%.1f\t%s" % [e["pass"],
				c.r8, c.g8, c.b8, e["cls"], s.x, s.y, s.z, e["path"]])


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
