extends "res://scripts/building/orison_v2_native_domestic_furniture.gd"
## Reuse immutable native partitions, with a separate world-owned storage cache.
const STORAGE_PATH := "res://data/orison_v2/domestic_storage.json"
func prepare() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORAGE_PATH))
	if not _prepare_family(data): return false
	for row: Dictionary in data.assemblies:
		for part: Dictionary in row.parts:
			if part.has("finish") and part.finish is not Dictionary: return false
	return true
