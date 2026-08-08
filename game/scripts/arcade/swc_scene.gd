class_name SwcScene
extends RefCounted

## The authored gameplay description, loaded read-only.
##
## The runtime never writes to it and never derives appearance from it, because it
## contains none. Everything the player collides with, walks on, shoots and
## interacts with comes from here; a World Package only adds surfaces on top.

var scene_id: String = ""
var display_name: String = ""
var description: String = ""
var scene_hash: String = ""
var metrics: Dictionary = {}
## Present when this scene is a ten-second beat rather than a level.
var beat: Dictionary = {}
var is_beat: bool = false

var regions: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var entities: Array[Dictionary] = []

var _by_id: Dictionary = {}


static func load_from(path: String) -> SwcScene:
	var doc: Variant = SwcFormats.read_json(path)
	if typeof(doc) != TYPE_DICTIONARY:
		push_error("SwcScene: cannot load %s" % path)
		return null

	var data := SwcScene.new()
	data.scene_id = String(doc.get("scene_id", ""))
	data.display_name = String(doc.get("display_name", data.scene_id))
	data.description = String(doc.get("description", ""))
	data.metrics = doc.get("gameplay_metrics", {})
	data.beat = doc.get("beat", {})
	data.is_beat = not data.beat.is_empty()
	for region_variant in doc.get("regions", []):
		data.regions.append(region_variant)
	for connection_variant in doc.get("connections", []):
		data.connections.append(connection_variant)
	for entity_variant in doc.get("entities", []):
		var entity: Dictionary = entity_variant
		data.entities.append(entity)
		data._by_id[String(entity.get("semantic_id", ""))] = entity
	return data


func get_entity(semantic_id: String) -> Dictionary:
	return _by_id.get(semantic_id, {})


func of_type(type_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entity in entities:
		if String(entity.get("type", "")) == type_name:
			out.append(entity)
	return out


func metric(key: String, fallback: float) -> float:
	return float(metrics.get(key, fallback))


# ------------------------------------------------------------------ accessors
# Small helpers so gameplay code never re-implements the schema's shape.


static func position_of(entity: Dictionary) -> Vector3:
	var transform: Dictionary = entity.get("transform", {})
	var position: Array = transform.get("position", [0, 0, 0])
	return Vector3(position[0], position[1], position[2])


static func yaw_of(entity: Dictionary) -> float:
	var transform: Dictionary = entity.get("transform", {})
	var rotation: Array = transform.get("rotation_euler_deg", [0, 0, 0])
	return float(rotation[1])


static func scale_of(entity: Dictionary) -> Vector3:
	var transform: Dictionary = entity.get("transform", {})
	var s: Array = transform.get("scale", [1, 1, 1])
	return Vector3(s[0], s[1], s[2])


static func size_of(entity: Dictionary) -> Vector3:
	var bounds: Dictionary = entity.get("bounds", {})
	return Vector3(
		float(bounds.get("width", 1.0)),
		float(bounds.get("height", 1.0)),
		float(bounds.get("depth", 1.0))
	)


static func bounds_offset_of(entity: Dictionary) -> Vector3:
	var bounds: Dictionary = entity.get("bounds", {})
	var offset: Array = bounds.get("offset", [0, 0, 0])
	return Vector3(offset[0], offset[1], offset[2])


static func roles_of(entity: Dictionary) -> Array:
	return entity.get("gameplay_role", [])


static func has_role(entity: Dictionary, role: String) -> bool:
	return role in entity.get("gameplay_role", [])


static func params_of(entity: Dictionary) -> Dictionary:
	return entity.get("gameplay_params", {})


static func constraints_of(entity: Dictionary) -> Dictionary:
	return entity.get("constraints", {})


static func clearance_of(entity: Dictionary) -> Dictionary:
	var constraints := constraints_of(entity)
	if not bool(constraints.get("preserve_clearance", false)):
		return {}
	return constraints.get("clearance", {})


static func attachment_of(entity: Dictionary, name: String) -> Variant:
	for point_variant in constraints_of(entity).get("attachment_points", []):
		var point: Dictionary = point_variant
		if String(point.get("name", "")) == name:
			var position: Array = point.get("position", [0, 0, 0])
			return Vector3(position[0], position[1], position[2])
	return null
