class_name FunctionalProp
extends Node3D
## Base class for every conductor-aware object. The conductor requests
## events; this class gates them through the prop's mechanical profile
## (prop_catalog.json): action-rate limits, response latency, receptivity.
## Subclasses implement the actual mechanism and keep performing their
## NORMAL function — infection only retimes what the object already does.

enum PState { OFF, IDLE, STARTING, OPERATING, COMPLETING, FAULT, INFECTED }

@export var prop_type := "radiator"
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
	_build_visual()
	_start_normal_function()


func _build_visual() -> void:
	pass


func _start_normal_function() -> void:
	pass


func _on_motif_event(index: int, accent: float, pitch: float) -> void:
	if state == PState.OFF or state == PState.FAULT:
		return
	var receptivity: float = profile.get("infection_receptivity", 0.5) * Conductor.infection
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mi.material_override = mat
	add_child(mi)
	return mi
