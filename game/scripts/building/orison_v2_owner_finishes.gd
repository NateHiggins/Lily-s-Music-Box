extends RefCounted
## Scoped optical changes; original nodes, meshes, collision and state owners survive.
const PROFILE_PATH := "res://data/orison_v2/owner_finish_profiles.json"
var _profiles: Dictionary = {}
var _keys: Dictionary = {}
var _cache: Dictionary = {}

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	assert(int(data.schema) == 1)
	for group: Dictionary in data.groups:
		var recipes := {}
		for recipe: Dictionary in group.recipes: recipes[str(recipe.source_key)] = recipe
		_profiles[str(group.id)] = recipes
	for key: String in MatLib.SETS:
		if not _keys.has(str(MatLib.SETS[key][0])): _keys[str(MatLib.SETS[key][0])] = key

func apply_service_actors(root: Node) -> void:
	for actor: Node in root.find_children("*", "Node3D", true, false):
		var group := ""
		if actor is BoilerProp: group = "heating"
		elif actor is RadiatorProp: group = "heating"
		elif actor is WasherProp: group = "washer"
		elif actor is TapProp and actor.fixture in ["bath_sink", "shower"]: group = "bath"
		elif actor.get_script() == preload("res://scripts/building/orison_v2_water_closet.gd"): group = "bath"
		elif actor.has_meta("v2_furniture_id") or actor.has_meta("v2_surface_prop"): group = "domestic"
		elif actor.has_meta("v2_native_toaster_variant") or actor.has_meta("v2_native_medicine_variant"): group = "small_appliance"
		if not group.is_empty(): apply_actor(actor, group)

func apply_actor(actor: Node, group: String) -> void:
	if actor.has_meta("v2_owner_finish_group"): return
	var changed := 0
	for node: Node in actor.find_children("*", "GeometryInstance3D", true, false):
		if node is MeshInstance3D and node.mesh != null:
			# Overrides leave imported/shared geometry and collision arrays exact.
			if node.material_override != null:
				var tuned := material_for(node.material_override, group)
				if tuned != node.material_override:
					node.material_override = tuned
					changed += 1
			else:
				for surface in node.mesh.get_surface_count():
					var original: Material = node.get_active_material(surface)
					var tuned := material_for(original, group)
					if tuned != original:
						node.set_surface_override_material(surface, tuned)
						changed += 1
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var original: Material = node.material_override if node.material_override != null else node.multimesh.mesh.surface_get_material(0)
			var tuned := material_for(original, group)
			if tuned != original:
				node.material_override = tuned
				changed += 1
	if changed > 0:
		actor.set_meta("v2_owner_finish_group", group)
		actor.set_meta("v2_owner_finish_slots", changed)

func material_for(original: Material, group: String) -> Material:
	if original is not StandardMaterial3D: return original
	var source := original as StandardMaterial3D
	# Stateful water, fire, lamps and optical glass keep their exact resources.
	if source.emission_enabled or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or source.albedo_texture == null: return original
	var key: String = _keys.get(source.albedo_texture.resource_path.get_file(), "")
	var recipe: Dictionary = _profiles[group].get(key, {})
	if recipe.is_empty(): return original
	# Existing local rust/corrosion patches are separate from the clean casting.
	if key == "cast_iron" and source.albedo_color.r > source.albedo_color.g * 1.8: return original
	var cache_key := "%s:%s" % [group, source.get_instance_id()]
	if _cache.has(cache_key): return _cache[cache_key]
	var result := source.duplicate() as StandardMaterial3D
	var selected: String = str(recipe.get("catalog", key))
	if selected != key:
		var maps := MatLib.get_mat(selected)
		result.albedo_texture = maps.albedo_texture
		result.normal_texture = maps.normal_texture
		result.roughness_texture = maps.roughness_texture
		result.uv1_scale *= float(MatLib.SETS[key][3]) / float(MatLib.SETS[selected][3])
	if bool(recipe.get("untextured", false)):
		result.albedo_texture = null
		result.roughness_texture = null
		result.normal_texture = null
	var color: Array = recipe.color
	if not bool(recipe.get("retain_tint",false)):
		result.albedo_color = Color(color[0],color[1],color[2],color[3])
	result.normal_scale = float(recipe.normal)
	result.normal_enabled = result.normal_texture != null
	result.roughness = float(recipe.roughness)
	result.metallic = float(recipe.metallic)
	result.set_meta("v2_owner_finish", group + "/" + key)
	var final: Material = result
	if recipe.has("pigment") and not result.vertex_color_use_as_albedo:
		result.resource_name = "M_" + selected
		final = SurfacePass.surface_for(result,{"pigment_variation":float(recipe.pigment),"relief_mul":0.})
		final.set_meta("v2_owner_finish",group + "/" + key)
	_cache[cache_key] = final
	return final
