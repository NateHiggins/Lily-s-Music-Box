extends RefCounted
## Physical materials for the semantic geometry. The review palette is kept
## by the standalone blockout; the playable root explicitly enables this.
var cache: Dictionary = {}
var calibrated_inputs: Dictionary = {}

func key_for(part: String, room_class: String) -> String:
	if part.begins_with("B1_COAL_HEAP_"): return "soot"
	if part == "ROOF_TANK_BODY" or part.begins_with("ROOF_TANK_BUTT_"): return "timber"
	if part.begins_with("ROOF_TANK_"): return "cast_iron"
	if part.begins_with("ROOF_PARAPET_"): return "brick"
	if part == "Glazing": return "glass"
	if part == "Leaf": return "wood_dark"
	if part.begins_with("Jamb") or part.begins_with("Frame") or part == "Head": return "trim"
	if "Guard" in part: return "metal"
	if "Step" in part or part == "HalfLanding": return "stair"
	if part == "Floor":
		if room_class == "wet": return "ceramic"
		if room_class in ["public", "core"]: return "terrazzo"
		if room_class in ["service", "unresolved"]: return "concrete"
		return "floor_oak"
	if part == "Ceiling": return "trim"
	if part == "ExteriorSoffit": return "concrete"
	if room_class == "wet": return "subway_tile"
	if room_class == "service": return "concrete"
	return "plaster_stained"

func material_for(part: String, room_class: String) -> Material:
	var key := key_for(part,room_class)
	if key == "glass":
		if not cache.has(key):
			var glass := ShaderMaterial.new()
			glass.shader = preload("res://shaders/lamp_glass_surface.gdshader")
			cache[key] = glass
		return cache[key]
	var family := "walls"
	if part == "Floor": family = "floors"
	elif part in ["Ceiling", "ExteriorSoffit"]: family = "ceiling"
	elif key == "stair": family = "stairs"
	elif key in ["trim", "wood_dark", "metal"]: family = "trim"
	var recipe: Dictionary = {}
	for entry: Dictionary in SurfacePass.CLASSES:
		if entry.key == family:
			recipe = entry.recipe
			break
	var base := MatLib.get_mat(key)
	if key in ["stair", "concrete"]:
		# A semantic material needs the same catalogue identity as an imported
		# catalogue surface, otherwise its authored height map is never bound.
		# Keep the named copy stable without changing MatLib's shared resource.
		if not calibrated_inputs.has(key):
			var named := base.duplicate() as StandardMaterial3D
			named.resource_name = "M_" + key
			calibrated_inputs[key] = named
		base = calibrated_inputs[key]
	return SurfacePass.surface_for(base,recipe,key+":"+family,cache)
