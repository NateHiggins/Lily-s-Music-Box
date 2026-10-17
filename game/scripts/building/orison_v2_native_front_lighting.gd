extends "res://scripts/building/orison_v2_native_fixed_lighting.gd"
## Visual stock only; existing fixture actors own power, optics and persistence.
const FRONT_PATH := "res://data/orison_v2/front_lighting_fixtures.json"

func prepare() -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(FRONT_PATH))
	if not _prepare_family(source): return false
	for row: Dictionary in source.instances:
		_offsets[str(row.id)] = Vector3.ZERO
	for row: Dictionary in source.assemblies:
		for i in row.parts.size():
			var component := str(row.parts[i].component)
			if component not in ["Body", "Mount", "Bulb", "Stained"]: return false
			_variants[str(row.id)][i]["component"] = component
	return true

func install_on(prop: LightFixtureProp) -> bool:
	if not super.install_on(prop): return false
	# The architectural slab underside is a single visible face. Rendering
	# front faces into these close ceiling lights' shadow maps avoids the
	# concentric self-shadow bands without inflating bias or losing shadows.
	prop.light.shadow_reverse_cull_face = true
	return true
