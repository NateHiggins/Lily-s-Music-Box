extends Resource
class_name PlayerProfile

@export var hair_style: String = "LongWaves"
@export var hair_gradient: String = "Pink"
@export var aura_particles: String = "None"
@export var face_option: String = "Normal"
@export var outfit: String = "BalletBoots"

func to_dict() -> Dictionary:
	return {
		"hair_style": hair_style,
		"hair_gradient": hair_gradient,
		"aura_particles": aura_particles,
		"face_option": face_option,
		"outfit": outfit,
	}

func from_dict(d: Dictionary) -> void:
	hair_style = d.get("hair_style", hair_style)
	hair_gradient = d.get("hair_gradient", hair_gradient)
	aura_particles = d.get("aura_particles", aura_particles)
	face_option = d.get("face_option", face_option)
	outfit = d.get("outfit", outfit)
