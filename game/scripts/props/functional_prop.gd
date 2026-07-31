class_name FunctionalProp
extends Node3D
## Base class for every conductor-aware object. The conductor requests
## events; this class gates them through the prop's mechanical profile
## (prop_catalog.json): action-rate limits, response latency, receptivity.
## Subclasses implement the actual mechanism and keep performing their
## NORMAL function — infection only retimes what the object already does.

enum PState { OFF, IDLE, STARTING, OPERATING, COMPLETING, FAULT, INFECTED }

@export var prop_type := "radiator"

## Acoustic-graph node this prop is bound to ("" = unbound; only reacts in
## global broadcast mode). Set by building_root from the shared markers.
var graph_node_id := ""

var profile: Dictionary = {}
var state: PState = PState.IDLE
var rng := RandomNumberGenerator.new()

static var _catalog: Dictionary = {}
var _last_action := -100.0


func _ready() -> void:
	rng.randomize()
	if _catalog.is_empty():
		var f := FileAccess.open("res://data/prop_catalog.json", FileAccess.READ)
		if f:
			_catalog = JSON.parse_string(f.get_as_text())
	profile = _catalog.get(prop_type, {
		"minimum_action_interval": 0.2, "infection_receptivity": 0.5,
		"response_latency": 0.05, "timing_drift": 0.02})
	Conductor.motif_event.connect(_on_motif_event)
	AcousticGraphData.network_event.connect(_on_network_event)
	AcousticGraphData.reality_event.connect(_on_reality_event)
	_build_visual()
	_start_normal_function()


func _build_visual() -> void:
	pass


func _start_normal_function() -> void:
	pass


func _on_motif_event(index: int, accent: float, pitch: float) -> void:
	_receive(index, accent, pitch, 1.0)


func _on_network_event(node_id: String, index: int, accent: float,
		pitch: float, strength: float) -> void:
	if node_id == graph_node_id and graph_node_id != "":
		_receive(index, accent, pitch, strength)


func _on_reality_event(_case_id: String, node_id: String, strength: float,
		recurrence: int) -> void:
	if node_id != graph_node_id or graph_node_id == "":
		return
	if state == PState.OFF or state == PState.FAULT:
		return
	var receptivity: float = float(
			profile.get("infection_receptivity", 0.5))
	if rng.randf() > clampf(strength * (0.8 + receptivity), 0.05, 1.0):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_action < float(
			profile.get("minimum_action_interval", 0.2)):
		return
	_last_action = now
	# Existing objects express the wave through their own mechanism: lights
	# dip, radiators knock, speakers thump, monitors flare. Recurrence raises
	# pitch slightly so the building learns the resident's changed pattern.
	_perform_synced_event(100 + recurrence,
			clampf(strength, 0.15, 1.0), float(recurrence) * 1.5)


func _receive(index: int, accent: float, pitch: float, strength: float) -> void:
	if state == PState.OFF or state == PState.FAULT:
		return
	accent = accent * lerpf(0.55, 1.0, strength)  # distant arrivals soften
	var receptivity: float = profile.get("infection_receptivity", 0.5) \
			* Conductor.infection * strength
	if rng.randf() > receptivity:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_action < profile.get("minimum_action_interval", 0.2):
		return  # a toaster cannot pop five times a second
	_last_action = now
	var latency: float = profile.get("response_latency", 0.05) \
			+ rng.randf_range(0.0, profile.get("timing_drift", 0.02))
	await get_tree().create_timer(latency, false).timeout
	if is_inside_tree():
		_perform_synced_event(index, accent, pitch)


## Override: express this motif event through the prop's own mechanism.
func _perform_synced_event(_index: int, _accent: float, _pitch: float) -> void:
	pass


func make_emitter(stream_key: String, volume_db := -8.0, loop_play := false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = PropAudio.get_stream(stream_key)
	p.volume_db = volume_db
	p.unit_size = 4.0
	p.max_distance = 26.0
	add_child(p)
	if loop_play:
		p.play()
	return p


func make_box(size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = offset
	mi.material_override = _pmat(color)
	add_child(mi)
	return mi


## Swap prototype flat colors for semantic texture sets: walks child
## meshes and replaces any material whose albedo matches a table row of
## [color, key, tint (, uv_scale)]. Emissive surfaces are left alone.
func retexture(node: Node, table: Array) -> void:
	for c in node.get_children():
		retexture(c, table)
	if node is MeshInstance3D 			and node.material_override is StandardMaterial3D:
		var m: StandardMaterial3D = node.material_override
		if m.emission_enabled:
			return
		for row in table:
			if m.albedo_color.is_equal_approx(row[0]):
				node.material_override = MatLib.get_mat(row[1], row[2],
						row[3] if row.size() > 3 else 1.0)
				return


## Collapse a finished, STATIC sub-tree into one mesh per material.
##
## Props are modelled as a heap of primitives — a column radiator is nine
## sections of four columns between bulbous headers, 62 MeshInstance3Ds
## that never move relative to each other. Each one is its own draw, and
## with shadow casters re-rendering the visible set per cube face the cost
## multiplies. Baking them into a mesh per material keeps the silhouette
## exactly and costs one draw per finish.
##
## Only ever call this on a sub-tree whose parts are fixed relative to
## `under`. Anything the prop animates individually must live outside it
## (or be named in `keep`) — a merged part no longer exists as a node.
## Call AFTER retexture(), so parts that end up sharing a finish merge
## into the same surface.
func merge_static(under: Node3D, keep: Array = []) -> int:
	var groups := {}          # material key -> {"mat":, "st": SurfaceTool}
	var victims: Array = []
	_gather_static(under, under, groups, victims, keep)
	if victims.size() < 2:
		return 0
	for v in victims:
		under.remove_child(v)
		v.queue_free()
	for key in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = groups[key]["st"].commit()
		mi.material_override = groups[key]["mat"]
		mi.cast_shadow = groups[key]["shadow"]
		under.add_child(mi)
	return victims.size() - groups.size()


func _gather_static(node: Node3D, root: Node3D, groups: Dictionary,
		victims: Array, keep: Array) -> void:
	for c in node.get_children():
		if c in keep or not (c is Node3D):
			continue
		if c is MeshInstance3D and c.mesh != null \
				and c.material_override is StandardMaterial3D:
			var key := _material_key(c.material_override)
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				# Carry the source's shadow setting onto the merged mesh.
				# Light fixtures switch casting OFF on purpose (a housing
				# inside its own omni throws self-shadow spokes across the
				# room); a merged mesh silently defaulting back to ON would
				# reintroduce that with no visible cause.
				groups[key] = {"mat": c.material_override, "st": st,
						"shadow": c.cast_shadow}
			var xf := _relative_xform(c, root)
			for s in c.mesh.get_surface_count():
				groups[key]["st"].append_from(c.mesh, s, xf)
			victims.append(c)
		else:
			_gather_static(c, root, groups, victims, keep)


## Transform of `node` in `root`'s space, computed without touching
## global_transform so this works before the prop enters the tree.
func _relative_xform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node3D = node
	while n != null and n != root:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf


## Group by what the material LOOKS like, not by object identity. Parts
## built by _pmat() each get their own instance, so identity would put
## every column in its own surface and merge nothing.
func _material_key(m: StandardMaterial3D) -> String:
	return "%s|%.3f|%.3f|%s|%s|%s" % [
		m.albedo_color, m.roughness, m.metallic,
		m.albedo_texture.get_rid() if m.albedo_texture else "-",
		m.normal_texture.get_rid() if m.normal_texture else "-",
		m.uv1_scale]


## Shared semantic texture material (see MatLib); tint multiplies maps.
func smat(key: String, tint := Color.WHITE,
		scale := 1.0) -> StandardMaterial3D:
	return MatLib.get_mat(key, tint, scale)


func _pmat(color: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	return mat


## Vertical cylinder/cone (rotate the returned node for other axes).
func make_cyl(r_top: float, r_bot: float, h: float, offset: Vector3,
		color: Color, rough := 0.5, metal := 0.0,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = h
	cyl.radial_segments = 14
	mi.mesh = cyl
	mi.position = offset
	mi.material_override = _pmat(color, rough, metal)
	(parent if parent else self).add_child(mi)
	return mi


## Torus ring lying in the XZ plane (rotate for portholes / fan shrouds).
func make_ring(r: float, tube: float, offset: Vector3, color: Color,
		rough := 0.4, metal := 0.0,
		parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = maxf(0.001, r - tube)
	t.outer_radius = r + tube
	t.rings = 20
	mi.mesh = t
	mi.position = offset
	mi.material_override = _pmat(color, rough, metal)
	(parent if parent else self).add_child(mi)
	return mi
