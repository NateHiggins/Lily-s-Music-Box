extends RefCounted
## Registered clear dielectric finish. Diffuse absorption remains zero;
## authored glass stock controls microroughness and the tangent-space normal.
const ROUGH := preload("res://assets/building/textures/T_glass_rough.png")
const NORMAL := preload("res://assets/building/textures/T_glass_normal.png")

static func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("rough_tex", ROUGH)
	material.set_shader_parameter("normal_tex", NORMAL)
