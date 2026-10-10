extends RefCounted
## Physical materials for the semantic geometry. The review palette is kept
## by the standalone blockout; the playable root explicitly enables this.
var cache: Dictionary = {}
var calibrated_inputs: Dictionary = {}

# Shared catalogue-key finish calibration, reviewed at fixed production light.
# Existing pigment maps, physical tile sizes and material identities remain.
# This only quiets the broad architecture; props retain their own finishes.
const FINISH := {
	"concrete": {"pigment_variation":0.65, "detail_albedo_strength":0.015,
		"detail_normal_strength":0.10, "normal_scale":0.12,
		"mask_amount":Vector4(0.0,0.05,0.0,0.05)},
	"trim": {"pigment_variation":0.75, "detail_albedo_strength":0.015,
		"detail_normal_strength":0.10, "normal_scale":0.10,
		"mask_amount":Vector4(0.0,0.04,0.0,0.04)},
	"floor_oak": {"pigment_variation":0.55, "detail_albedo_strength":0.025,
		"detail_normal_strength":0.18, "normal_scale":0.20,
		"mask_amount":Vector4(0.0,0.08,0.0,0.06)},
	"plaster_stained": {"pigment_variation":0.60, "detail_albedo_strength":0.025,
		"detail_normal_strength":0.18, "normal_scale":0.20,
		"mask_amount":Vector4(0.0,0.08,0.0,0.06)},
	"terrazzo": {"pigment_variation":0.60, "detail_albedo_strength":0.025,
		"detail_normal_strength":0.18, "normal_scale":0.20,
		"mask_amount":Vector4(0.0,0.08,0.0,0.06)},
}

func key_for(part: String, room_class: String) -> String:
	if part.begins_with("B1_COAL_HEAP_"): return "soot"
	# Dossier slice 68 (ROOF_DECK_WEST-004): the house tank's boards take the catalogue's staved tank finish,
	# the skyline towers' own; plain timber read as brick at the tank's scale. The overflow butt stays timber.
	if part == "ROOF_TANK_BODY": return "tank_staves"
	if part.begins_with("ROOF_TANK_BUTT_"): return "timber"
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
			recipe = entry.recipe.duplicate()
			break
	if FINISH.has(key): recipe.merge(FINISH[key],true)
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
