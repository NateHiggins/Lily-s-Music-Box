extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Shared native stock under each original passive furniture actor.
const PATH := "res://data/orison_v2/domestic_objects.json"

func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("assemblies") is not Array:return false
	for row: Dictionary in data.assemblies:
		for part: Dictionary in row.parts:
			if part.get("component")!="Body" or part.get("finish") is not Dictionary:return false
	return _prepare_family(data)
