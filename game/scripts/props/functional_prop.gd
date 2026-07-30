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
