extends RefCounted
## The opt-in Windows pack includes these exact declarations and raw inputs.
## Editor tests and packaged startup use the same bundle constructor.
const PACKAGE_MARKER := "res://arcade_prepared_package.json"
const INPUTS := {
	"shell": "res://tests/fixtures/arcade_plaza_shells_contract.json",
	"frames": "res://tests/fixtures/arcade_door_frames.json",
	"native": "res://tests/fixtures/arcade_all_native_projection.json",
	"raw": "res://tests/fixtures/arcade_all_raw_projection.json",
}
const ACTORS := "res://data/orison_v2/arcade_actor_projection.json"
const COBBLER := "res://data/orison_v2/arcade_cobbler_field.json"
const PRECISION_ASSETS := [
	"arcade_plaza_shells", "arcade_storefront_identity", "arcade_aisle_pendants",
	"arcade_public_fittings", "arcade_entry_threshold", "arcade_darkroom_curtain",
	"arcade_cobbler_field",
]

## Godot owns *.import remaps in the pack. Keep the reviewed editor
## settings in a separate namespace so ResourceLoader still gets its remap.
static func settings_archive_path(path: String) -> String:
	return "res://arcade_prepared_sources/" + path.trim_prefix("res://")

static func source_path(path: String) -> String:
	if path.ends_with(".import") and FileAccess.file_exists(PACKAGE_MARKER):
		return settings_archive_path(path)
	return path

static func read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

static func load_prepared() -> Dictionary:
	var declarations := {}
	for kind: String in INPUTS:
		var value := read(INPUTS[kind])
		if value.is_empty(): return {}
		declarations[kind] = value
	var projection := preload("res://scripts/building/orison_v2_arcade_actor_projection.gd").new()
	var placement := projection.prepare(read(ACTORS))
	if placement.is_empty() or declarations.frames.get("frames") is not Array \
		or declarations.native.get("cells") is not Array or declarations.raw.get("cells") is not Array:
		return {}
	return {
		"shell": declarations.shell,
		"frames": declarations.frames.frames,
		"native": declarations.native.cells,
		"raw": declarations.raw.cells,
		"placement": placement,
	}

## Include compiled scenes through the normal exporter. This list contains
## only files read byte-for-byte by the source and placement validators.
static func required_source_paths() -> PackedStringArray:
	var paths := {}
	for path: String in INPUTS.values(): paths[path] = true
	for kind: String in ["native","raw"]:
		var declaration := read(INPUTS[kind])
		var cells: Array = declaration.get("cells", [])
		if cells.size() != 11: return []
		for cell: Dictionary in cells:
			paths[str(cell.fabrication_source)] = true
			paths[str(cell.cell_source)] = true
			for path: String in cell.source_bindings: paths[path] = true
			for path: String in cell.get("native_assets", {}): paths[path] = true
	var cobbler := read(COBBLER)
	if cobbler.is_empty(): return []
	for path: String in cobbler.get("source_bindings", {}): paths[path] = true
	for stem: String in PRECISION_ASSETS:
		var asset := "res://assets/props/" + stem + ".glb"
		paths[asset] = true
		paths[asset + ".import"] = true
	for stem: String in ["arcade_clock","arcade_door_leaves"]:
		paths["res://assets/props/" + stem + ".glb"] = true
	var sorted := PackedStringArray(paths.keys())
	sorted.sort()
	return sorted
