class_name DreamMaterialProfile
extends Resource
## The Dream material stack's parameters (DREAM_TENTACLE_DIRECTION §2, §5–7,
## §21): the colour story and the amounts of each state, as data that any
## Dream anatomy can carry. Applied to a ShaderMaterial built on
## `dream_entity_surface.gdshaderinc` by `apply()`.

@export_group("Flesh")
@export var flesh_deep := Color("24081F")
@export var flesh_body := Color("6B1640")
@export var flesh_crest := Color("9E3A78")
@export_range(0.0, 1.0) var wetness := 0.8
@export_range(0.0, 2.0) var subsurface := 1.0
@export_range(0.0, 1.0) var microdetail := 0.7
@export_group("Gold")
@export var gold := Color("DBA84C")
@export var gold_hot := Color("FF9E2E")
@export_range(0.0, 1.0) var gold_coverage := 0.42
@export_range(0.0, 2.0) var gold_emission := 1.0
@export_range(0.0, 1.0) var gold_flow := 0.12
@export_range(0.0, 1.0) var gold_ornament := 0.6
@export_group("Veins")
@export var vein := Color("80101F")
@export_range(0.0, 2.0) var vein_pulse := 1.0
@export var pulse_period_s := 1.5
@export_group("Suckers")
@export var sucker := Color("C77590")
@export_group("Hyper")
@export_range(0.0, 1.0) var phase_instability := 0.35
@export_range(0.0, 1.0) var iridescent_rim := 0.5
@export_group("Debug")
## Gray: the material test (§28) — no colour, no emission.
@export var gray := false


func apply(m: ShaderMaterial) -> void:
	if m == null:
		return
	m.set_shader_parameter("flesh_deep", Vector3(flesh_deep.r, flesh_deep.g, flesh_deep.b))
	m.set_shader_parameter("flesh_body", Vector3(flesh_body.r, flesh_body.g, flesh_body.b))
	m.set_shader_parameter("flesh_crest", Vector3(flesh_crest.r, flesh_crest.g, flesh_crest.b))
	m.set_shader_parameter("wetness", wetness)
	m.set_shader_parameter("subsurface", subsurface)
	m.set_shader_parameter("microdetail", microdetail)
	m.set_shader_parameter("gold", Vector3(gold.r, gold.g, gold.b))
	m.set_shader_parameter("gold_hot", Vector3(gold_hot.r, gold_hot.g, gold_hot.b))
	m.set_shader_parameter("gold_coverage", gold_coverage)
	m.set_shader_parameter("gold_emission", gold_emission)
	m.set_shader_parameter("gold_flow", gold_flow)
	m.set_shader_parameter("gold_ornament", gold_ornament)
	m.set_shader_parameter("vein_color", Vector3(vein.r, vein.g, vein.b))
	m.set_shader_parameter("vein_pulse", vein_pulse)
	m.set_shader_parameter("pulse_period_s", pulse_period_s)
	m.set_shader_parameter("sucker_color", Vector3(sucker.r, sucker.g, sucker.b))
	m.set_shader_parameter("phase_instability", phase_instability)
	m.set_shader_parameter("iridescent_rim", iridescent_rim)
	m.set_shader_parameter("debug_gray", gray)
