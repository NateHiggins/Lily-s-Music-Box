class_name DreamMaterialProfile
extends Resource
## The Dream hero material's parameters (DIRECTION_2 §A–B, DIRECTION_3
## §A–§E): the colour story, the scatter, the film, the mineral and the
## coupled state, as data any Dream anatomy can carry. Applied to a
## ShaderMaterial built on `dream_entity_surface.gdshaderinc`.

@export_group("Flesh")
@export var flesh_deep := Color(0.048, 0.011, 0.062)
@export var flesh_body := Color(0.205, 0.045, 0.170)
@export var flesh_crest := Color(0.372, 0.112, 0.290)
@export var flesh_perfusion := Color(0.480, 0.075, 0.180)
@export_range(0.0, 1.0) var flesh_roughness := 0.54
@export_range(0.0, 3.0) var normal_anatomical := 1.0
@export_range(0.0, 3.0) var normal_tissue := 1.0
@export_range(0.0, 3.0) var normal_pore := 1.0
@export_range(0.0, 1.0) var iridophore := 0.40
@export_range(0.0, 1.0) var papilla := 0.5
@export_group("Subsurface")
@export_range(0.0, 1.0) var sss_amount := 0.42
@export var sss_transmit_deep := Color(0.42, 0.030, 0.055)
@export var sss_transmit_thin := Color(0.92, 0.115, 0.255)
@export var sss_depth_m := 0.006
@export_range(0.0, 1.0) var sss_boost := 0.10
@export_group("Film")
@export_range(0.0, 1.0) var wetness := 0.75
@export_range(0.0, 0.5) var film_roughness := 0.14
@export var film_drift := 0.035
@export_group("Gold")
@export var gold := Color(0.859, 0.659, 0.298)
@export var gold_hot := Color(1.0, 0.620, 0.180)
@export_range(0.0, 1.0) var gold_mineralization := 0.35
@export_range(0.0, 3.0) var gold_emission := 0.9
@export_range(0.0, 1.0) var gold_flow := 0.08
@export_group("Debug")
@export var gray := false


func apply(m: ShaderMaterial) -> void:
	if m == null:
		return
	m.set_shader_parameter("flesh_deep", _v(flesh_deep))
	m.set_shader_parameter("flesh_body", _v(flesh_body))
	m.set_shader_parameter("flesh_crest", _v(flesh_crest))
	m.set_shader_parameter("flesh_perfusion", _v(flesh_perfusion))
	m.set_shader_parameter("flesh_roughness", flesh_roughness)
	m.set_shader_parameter("normal_anatomical", normal_anatomical)
	m.set_shader_parameter("normal_tissue", normal_tissue)
	m.set_shader_parameter("normal_pore", normal_pore)
	m.set_shader_parameter("iridophore", iridophore)
	m.set_shader_parameter("papilla", papilla)
	m.set_shader_parameter("sss_amount", sss_amount)
	m.set_shader_parameter("sss_transmit_deep", _v(sss_transmit_deep))
	m.set_shader_parameter("sss_transmit_thin", _v(sss_transmit_thin))
	m.set_shader_parameter("sss_depth_m", sss_depth_m)
	m.set_shader_parameter("sss_boost", sss_boost)
	m.set_shader_parameter("wetness", wetness)
	m.set_shader_parameter("film_roughness", film_roughness)
	m.set_shader_parameter("film_drift", film_drift)
	m.set_shader_parameter("gold", _v(gold))
	m.set_shader_parameter("gold_hot", _v(gold_hot))
	m.set_shader_parameter("gold_mineralization", gold_mineralization)
	m.set_shader_parameter("gold_emission", gold_emission)
	m.set_shader_parameter("gold_flow", gold_flow)
	m.set_shader_parameter("debug_gray", gray)


## The coupled state (DIRECTION_2 §E), pushed every frame by the host.
static func push_state(m: ShaderMaterial, attention: float, pulse_phase: float,
		breath_phase: float, startle: float, dream_phase: float) -> void:
	if m == null:
		return
	m.set_shader_parameter("attention", attention)
	m.set_shader_parameter("pulse_phase", pulse_phase)
	m.set_shader_parameter("breath_phase", breath_phase)
	m.set_shader_parameter("startle", startle)
	m.set_shader_parameter("dream_phase", dream_phase)


static func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
