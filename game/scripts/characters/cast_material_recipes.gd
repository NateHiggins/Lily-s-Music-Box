extends RefCounted
## Imported cast materials own their UV maps. The shared catalogue owns factors.
## Validate those bindings without replacing them with the tiled prop library.
const CATALOGUE := "res://data/material_catalog.json"
static var _recipes: Dictionary = {}

static func validate(model: Node3D, person: String) -> Array[String]:
	var errors: Array[String] = []
	if _recipes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
		if parsed is not Dictionary or parsed.is_empty():
			errors.append("cast material catalogue is missing or invalid")
			return errors
		_recipes = parsed
	var seen: Dictionary = {}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if draw.mesh == null:
			continue
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_active_material(surface) as BaseMaterial3D
			if material == null:
				errors.append("cast source material is not imported PBR: " + str(draw.name))
				continue
			var key := material.resource_name
			if seen.has(key):
				continue
			seen[key] = true
			if not key.begins_with("cast_" + person + "_") or not _recipes.has(key):
				errors.append("cast material has no registered recipe: " + key)
				continue
			var recipe: Dictionary = _recipes[key]
			var colour: Array = recipe.get("base_color", [])
			if colour.size() != 4:
				errors.append("cast recipe colour is invalid: " + key)
				continue
			# glTF factors are linear; Godot's importer stores albedo in sRGB.
			var expected := Color(float(colour[0]), float(colour[1]), float(colour[2]), float(colour[3])).linear_to_srgb()
			if not material.albedo_color.is_equal_approx(expected) or not is_equal_approx(material.roughness, float(recipe.get("roughness", -1.0))) or not is_equal_approx(material.metallic, float(recipe.get("metallic", -1.0))):
				errors.append("cast source factors differ from catalogue: " + key)
			var roughness: Texture2D = (material as ORMMaterial3D).orm_texture if material is ORMMaterial3D else material.roughness_texture
			if material.albedo_texture == null or roughness == null or not material.normal_enabled or material.normal_texture == null:
				errors.append("cast PBR maps incomplete: " + key)
			if material.uv1_triplanar:
				errors.append("cast source maps bypass primary UVs: " + key)
			material.set_meta("cast_recipe_key", key)
	return errors
