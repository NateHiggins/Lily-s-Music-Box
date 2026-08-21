class_name DreamIncarnationPlateCache
extends RefCounted
## INC-V2: one active-case texture bundle. This is a resource holder owned by
## DreamMazeRoot, not a node or gameplay owner. Missing plates leave the current
## procedural presentation intact; another case is never substituted.

const CATALOG_PATH := "res://data/dream_plate_catalog.json"
const CHANNELS := ["albedo", "height", "normal", "roughness"]
const MIB := 1024.0 * 1024.0

var resources: Dictionary = {}
var active_incarnation := ""
var residency_bytes := 0
var last_error := ""
var _catalog: Dictionary = {}


func _init(catalog_override := {}) -> void:
	_catalog = catalog_override.duplicate(true) if not catalog_override.is_empty() \
			else _read_catalog()


func load_bundle(bundle: Dictionary, resource_override := {}) -> bool:
	unload()
	if not bool(bundle.get("production_enabled", false)):
		return true
	var incarnation_id := str(bundle.get("incarnation_id", ""))
	var available: Array = _catalog.get("available_cases", [])
	if incarnation_id not in available:
		last_error = "%s plates are not yet shipped" % incarnation_id
		return false
	var substance_keys: PackedStringArray = bundle.get(
			"substance_keys", PackedStringArray())
	if substance_keys.size() != 4:
		last_error = "active presentation requires four substance keys"
		return false
	var root := str(_catalog.get("root", ""))
	var channels: Dictionary = _catalog.get("channels", {})
	var substance_px := int(_catalog.get("substance_resolution", 0))
	for key in substance_keys:
		for channel in CHANNELS:
			var channel_record: Dictionary = channels.get(channel, {})
			var path := "%s/%s/%s/%s" % [root, incarnation_id, key,
					str(channel_record.get("suffix", ""))]
			if not _accept_texture("%s/%s" % [key, channel], path,
					substance_px, substance_px,
					int(channel_record.get("bytes_per_pixel", 0)),
					resource_override):
				unload(false)
				return false
	var reflected_key := str(bundle.get("reflected_world_key", ""))
	var reflection_size: Array = _catalog.get("reflection_resolution", [])
	if reflection_size.size() != 2:
		last_error = "reflection resolution missing from catalog"
		unload(false)
		return false
	var reflected_path := "%s/%s/%s/reflected_world.png" % [
			root, incarnation_id, reflected_key]
	if not _accept_texture(reflected_key, reflected_path,
			int(reflection_size[0]), int(reflection_size[1]), 4,
			resource_override):
		unload(false)
		return false
	active_incarnation = incarnation_id
	return true


func unload(clear_error := true) -> void:
	resources.clear()
	active_incarnation = ""
	residency_bytes = 0
	if clear_error:
		last_error = ""


func resource_count() -> int:
	return resources.size()


func residency_mib() -> float:
	return float(residency_bytes) / MIB


static func production_ceiling_bytes(catalog_override := {}) -> int:
	var catalog: Dictionary = catalog_override
	if catalog.is_empty():
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(CATALOG_PATH))
		catalog = parsed if parsed is Dictionary else {}
	var substance_px := int(catalog.get("substance_resolution", 0))
	var channels: Dictionary = catalog.get("channels", {})
	var total := 0
	for _plate in 4:
		for channel in CHANNELS:
			total += _mipped_bytes(substance_px, substance_px,
					int((channels.get(channel, {}) as Dictionary).get(
							"bytes_per_pixel", 0)))
	var reflection: Array = catalog.get("reflection_resolution", [])
	if reflection.size() == 2:
		total += _mipped_bytes(int(reflection[0]), int(reflection[1]), 4)
	return total


func _accept_texture(id: String, path: String, width: int, height: int,
		bytes_per_pixel: int, resource_override: Dictionary) -> bool:
	var value: Variant = resource_override.get(id, null)
	if value == null and ResourceLoader.exists(path):
		value = load(path)
	if value is not Texture2D:
		last_error = "missing texture %s" % path
		return false
	var texture := value as Texture2D
	if texture.get_width() != width or texture.get_height() != height:
		last_error = "%s is %dx%d; expected %dx%d" % [path,
				texture.get_width(), texture.get_height(), width, height]
		return false
	resources[id] = texture
	residency_bytes += _mipped_bytes(width, height, bytes_per_pixel)
	return true


static func _mipped_bytes(width: int, height: int, bytes_per_pixel: int) -> int:
	var total := 0
	var w := width
	var h := height
	while w > 0 and h > 0:
		total += w * h * bytes_per_pixel
		if w == 1 and h == 1:
			break
		w = maxi(1, w >> 1)
		h = maxi(1, h >> 1)
	return total


func _read_catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CATALOG_PATH))
	return parsed if parsed is Dictionary else {}
