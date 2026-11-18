extends RefCounted
## Shared declaration for the verified Windows arcade bake.
const Bundle := preload("res://scripts/building/orison_v2_arcade_runtime_bundle.gd")
const ROOT := "res://arcade_stream/"
const MANIFEST := "manifest.json"
const SCHEMA := 1
const EXTRA_INPUTS := [
	"res://project.godot",
	"res://data/orison_v2/arcade_plaza_shells.json",
	"res://data/orison_v2/arcade_storefront_identity.json",
	"res://data/orison_v2/arcade_public_fittings.json",
	"res://data/orison_v2/arcade_aisle_pendants.json",
	"res://data/orison_v2/arcade_entry_threshold.json",
	"res://data/orison_v2/arcade_darkroom_curtain.json",
	"res://data/orison_v2/arcade_clock.json",
	"res://scripts/building/orison_v2_arcade_bake_manifest.gd",
	"res://tests/arcade_stream_bake.gd",
]

static func source_digests() -> Dictionary:
	var paths := Bundle.required_source_paths()
	if paths.is_empty(): return {}
	paths.append_array(EXTRA_INPUTS)
	for path in paths.duplicate():
		if path.get_extension() in ["glb","gltf"] and FileAccess.file_exists(path + ".import"):
			paths.append(path + ".import")
	paths.sort()
	var digests := {}
	for path in paths:
		if digests.has(path): continue
		if not FileAccess.file_exists(path): return {}
		var digest := FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text() \
			if path.get_extension() in ["gd","json","godot","gdshader","import"] else FileAccess.get_sha256(path)
		if digest.length() != 64: return {}
		digests[path] = digest
	return digests

static func check_shape(data: Dictionary, cell_ids: Array) -> bool:
	if data.get("schema") != SCHEMA or data.get("cells") is not Dictionary \
		or data.cells.size() != cell_ids.size() or not data.cells.has_all(cell_ids):
		return false
	var paths := {}
	for cell: String in cell_ids:
		var pieces: Variant = data.cells[cell]
		if pieces is not Array or pieces.is_empty(): return false
		for index in pieces.size():
			var row: Variant = pieces[index]
			if row is not Dictionary or row.get("file") != filename(cell,index) \
				or paths.has(row.file) or int(row.get("bytes",0)) <= 0 \
				or str(row.get("sha256","")).length() != 64:
				return false
			paths[row.file] = true
			if index == 0: continue
			if row.get("parent") is not String or row.parent.is_empty() or row.parent.is_absolute_path() \
				or ".." in row.parent.split("/") or row.get("positions") is not Array or row.positions.is_empty():
				return false
			var previous := -1
			for position: Variant in row.positions:
				if typeof(position) not in [TYPE_FLOAT,TYPE_INT] or int(position) <= previous \
					or float(position) != float(int(position)):
					return false
				previous = int(position)
	return true

static func filename(cell: String, index: int) -> String:
	return "%s_%03d.scn" % [cell,index]
