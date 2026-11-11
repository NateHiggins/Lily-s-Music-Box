extends RefCounted
## A resident's strand hair. The cast builder writes, beside each rebuilt body,
## the guide strands (`<id>_hair.tfx`), which bones each strand follows
## (`.tfxbone`), closed shapes for the head and body the hair must stay out of
## (`.tfxmesh`), and a recipe (`<id>_hair.json`) for how the hair looks and
## moves. This fits them to an actor with the TressFX addon's own nodes.
##
## It is quiet when there is nothing to do: a body with no recipe, or a build
## without the addon, simply has no strand hair.

const RECIPE := "res://assets/characters/%s/%s_hair.json"
const STRAND_SHADER := "res://addons/tressfx/shaders/tressfx_strand.gdshader"
## Hair is only simulated near the camera, and thins with distance.
const SIMULATE_WITHIN := 14.0
const THIN_FROM := 2.5
const THIN_TO := 9.0


static func available() -> bool:
	return ClassDB.class_exists("TressFXHair") and ClassDB.class_exists("TressFXCollisionMesh")


## Fit the resident's hair. Returns the hair node, or null when there is none.
static func install(actor: Node3D, model: Node, resident_id: String) -> Node:
	var recipe_path := RECIPE % [resident_id, resident_id]
	if not available() or not FileAccess.file_exists(recipe_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(recipe_path))
	if parsed is not Dictionary or int(parsed.get("schema_version", 0)) != 1:
		push_warning("Resident hair recipe unreadable: " + recipe_path)
		return null
	var recipe: Dictionary = parsed
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var skeleton := skeletons[0] as Skeleton3D
	var folder := recipe_path.get_base_dir()
	var shapes: Array = []
	for row: Dictionary in recipe.get("colliders", []):
		var bone := str(row.get("bone", ""))
		if skeleton.find_bone(bone) < 0:
			bone = bone.replace(".", "_")
		if skeleton.find_bone(bone) < 0:
			continue
		var shape: Node = ClassDB.instantiate("TressFXCollisionMesh")
		shape.name = "HairKeepOut_" + bone
		actor.add_child(shape)
		shape.set("hair_skeleton", skeleton)
		shape.set("tfxmesh_path", folder.path_join(str(row.get("file", ""))))
		shape.set("follow_bone", bone)
		shape.set("num_cells_x", 56)
		shapes.append(shape)
	var hair: Node = ClassDB.instantiate("TressFXHair")
	hair.name = "StrandHair"
	actor.add_child(hair)
	hair.set("hair_skeleton", skeleton)
	hair.set("tfx_path", folder.path_join(str(recipe.get("hair", ""))))
	hair.set("tfxbone_path", folder.path_join(str(recipe.get("bones", ""))))
	hair.set("num_follow_hairs", int(recipe.get("follow", 3)))
	hair.set("follow_radius", float(recipe.get("follow_radius", 0.005)))
	hair.set("tip_separation", 0.25)
	hair.set("local_stiffness", float(recipe.get("local_stiffness", 0.95)))
	hair.set("global_stiffness", float(recipe.get("global_stiffness", 0.5)))
	hair.set("global_range", float(recipe.get("global_range", 0.3)))
	hair.set("lod_enabled", true)
	hair.set("lod_start_distance", THIN_FROM)
	hair.set("lod_end_distance", THIN_TO)
	hair.set("simulation_distance", SIMULATE_WITHIN)
	hair.set("simulate_offscreen", false)
	var listed: Array = hair.get("collision_meshes")
	for shape: Node in shapes:
		listed.append(shape)
	hair.set("collision_meshes", listed)
	var material := ShaderMaterial.new()
	material.shader = load(STRAND_SHADER)
	var base: Array = recipe.get("base_colour", [0.4, 0.3, 0.2])
	var tip: Array = recipe.get("tip_colour", base)
	material.set_shader_parameter("base_color", Color(float(base[0]), float(base[1]), float(base[2]), 0.8))
	material.set_shader_parameter("tip_color", Color(float(tip[0]), float(tip[1]), float(tip[2]), 0.8))
	material.set_shader_parameter("tip_percentage", 0.5)
	material.set_shader_parameter("fiber_radius", float(recipe.get("fibre_radius", 0.0011)))
	material.set_shader_parameter("k_diffuse", 0.35)
	material.set_shader_parameter("k_spec1", 0.02)
	material.set_shader_parameter("k_spec2", 0.12)
	material.set_shader_parameter("color_variation", 0.3)
	material.set_shader_parameter("root_shadow", 0.35)
	hair.set("material", material)
	return hair
