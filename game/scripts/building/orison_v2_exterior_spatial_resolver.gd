class_name OrisonV2ExteriorSpatialResolver
extends RefCounted
## Source-owned public spatial seam for bounded Orison v2 exterior cells.
##
## Only a root instance is placed in the ruled shared frame. Every child
## instance inherits the complete transform of a named public surface and adds
## an authored UVN offset plus local yaw. The resolver never reads v1 layout
## coordinates and never exposes its mutable source dictionaries.

const DATA_PATH := "res://data/orison_v2/exterior/regions.json"
const SCRIPT_PATH := (
		"res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const FrameContract := preload(
		"res://scripts/building/orison_v2_frame_contract.gd")
const LineageRegistry := preload(
		"res://scripts/reality/corruption_lineage_registry.gd")

const DOCUMENT_KEYS := ["schema_version", "frame", "regions",
		"surface_templates", "instances", "thresholds", "routes"]
const FRAME_KEYS := ["origin_identity", "outward_axis", "unit",
		"canonical_root_instance_id"]
const REGION_KEYS := ["id", "kind", "lineage_id", "boundary"]
const TEMPLATE_KEYS := ["id", "kind", "lineage_id", "boundary_xz_m",
		"surfaces", "placements"]
const SURFACE_KEYS := ["id", "kind", "point_m", "u_axis", "v_axis",
		"normal", "size_m"]
const PLACEMENT_KEYS := ["id", "purpose", "surface_id", "offset_uvn_m",
		"facing_local"]
const INSTANCE_KEYS := ["id", "template_id", "region_id", "lineage_id",
		"owner_instance_id", "owner_surface_id", "offset_uvn_m",
		"local_yaw_degrees", "root_frame_identity", "semantic_identity",
		"display_name"]
const THRESHOLD_KEYS := ["id", "shop_id", "region_id", "lineage_id",
		"owner_instance_id", "owner_surface_id", "exterior_placement_id",
		"interior_placement_id", "interactive_leaf_id"]
const ROUTE_KEYS := ["id", "direction", "lineage_id", "region_ids",
		"threshold_ids", "nodes"]
const ROUTE_NODE_KEYS := ["id", "owner_instance_id", "placement_id"]

var errors: Array[String] = []
var source_hash := ""

var _frame: Dictionary = {}
var _regions: Dictionary = {}
var _templates: Dictionary = {}
var _instances: Dictionary = {}
var _thresholds: Dictionary = {}
var _routes: Dictionary = {}
var _instance_transform_cache: Dictionary = {}


static func load_default() -> Variant:
	# Runtime loading avoids cold global-class cache ordering for a new class.
	var resolver: Variant = load(SCRIPT_PATH).new()
	resolver.load_source()
	return resolver


func load_source(path: String = DATA_PATH) -> bool:
	errors.clear()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("exterior spatial source missing or empty: %s" % path)
		_clear()
		return false
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		errors.append("exterior spatial source is not a dictionary")
		_clear()
		return false
	if not configure(parsed as Dictionary):
		return false
	source_hash = text.sha256_text()
	return true


## Configure supports test-only additional roots and cells. A root may have a
## finite nonzero shared-frame offset and yaw; only the document's canonical
## root is required to remain at exact shared-frame identity.
func configure(source: Dictionary) -> bool:
	errors.clear()
	_clear()
	if not _has_exact_keys(source, DOCUMENT_KEYS):
		errors.append("exterior spatial document has unknown or missing fields")
	if int(source.get("schema_version", -1)) != 1:
		errors.append("exterior spatial schema_version must be 1")
	_validate_frame(source.get("frame"))
	_index_regions(source.get("regions"))
	_index_templates(source.get("surface_templates"))
	_index_instances(source.get("instances"))
	_index_thresholds(source.get("thresholds"))
	_index_routes(source.get("routes"))
	_validate_instance_graph()
	_validate_threshold_references()
	_validate_route_references()
	if not errors.is_empty():
		_clear()
		return false
	return true


func is_valid() -> bool:
	return errors.is_empty() and not _frame.is_empty() \
			and not _regions.is_empty() and not _instances.is_empty()


func region_ids() -> Array[String]:
	return _sorted_ids(_regions)


func template_ids() -> Array[String]:
	return _sorted_ids(_templates)


func instance_ids() -> Array[String]:
	return _sorted_ids(_instances)


func threshold_ids() -> Array[String]:
	return _sorted_ids(_thresholds)


func route_ids() -> Array[String]:
	return _sorted_ids(_routes)


func region_record(region_id: String) -> Dictionary:
	return _copy_record(_regions, region_id)


func template_record_for_instance(instance_id: String) -> Dictionary:
	var instance: Dictionary = _instances.get(instance_id, {})
	return _copy_record(_templates, str(instance.get("template_id", "")))


func instance_record(instance_id: String) -> Dictionary:
	return _copy_record(_instances, instance_id)


func threshold_record(threshold_id: String) -> Dictionary:
	return _copy_record(_thresholds, threshold_id)


func route_record(route_id: String) -> Dictionary:
	return _copy_record(_routes, route_id)


func surface_record(instance_id: String, surface_id: String) -> Dictionary:
	var template := template_record_for_instance(instance_id)
	for value: Variant in template.get("surfaces", []):
		if value is Dictionary and str(value.get("id", "")) == surface_id:
			return (value as Dictionary).duplicate(true)
	return {}


func placement_record(instance_id: String, placement_id: String) -> Dictionary:
	var template := template_record_for_instance(instance_id)
	for value: Variant in template.get("placements", []):
		if value is Dictionary and str(value.get("id", "")) == placement_id:
			return (value as Dictionary).duplicate(true)
	return {}


## Immutable value result for builders and cost tests. Transform3D is a value
## type; callers cannot mutate the resolver's cached transform through it.
func instance_world_transform(instance_id: String) -> Transform3D:
	if not _instances.has(instance_id):
		return _invalid_transform()
	return _instance_world_transform_internal(instance_id, {})


func resolve_surface(instance_id: String, surface_id: String) -> Dictionary:
	var instance: Dictionary = _instances.get(instance_id, {})
	var surface := surface_record(instance_id, surface_id)
	if instance.is_empty() or surface.is_empty():
		return {}
	var world := instance_world_transform(instance_id)
	if not _valid_transform(world):
		return {}
	var u_axis := (world.basis * _vec3(surface.get("u_axis"))).normalized()
	var v_axis := (world.basis * _vec3(surface.get("v_axis"))).normalized()
	var normal := (world.basis * _vec3(surface.get("normal"))).normalized()
	var point := world * _vec3(surface.get("point_m"))
	return {
		"instance_id": instance_id,
		"template_id": str(instance.get("template_id", "")),
		"region_id": str(instance.get("region_id", "")),
		"lineage_id": str(instance.get("lineage_id", "")),
		"surface_id": surface_id,
		"kind": str(surface.get("kind", "")),
		"point": point,
		"u_axis": u_axis,
		"v_axis": v_axis,
		"normal": normal,
		"size_m": (surface.get("size_m", []) as Array).duplicate(),
		"transform": Transform3D(Basis(u_axis, normal, v_axis), point),
	}


func resolve_placement(instance_id: String, placement_id: String) -> Dictionary:
	var instance: Dictionary = _instances.get(instance_id, {})
	var placement := placement_record(instance_id, placement_id)
	if instance.is_empty() or placement.is_empty():
		return {}
	var surface := resolve_surface(instance_id,
			str(placement.get("surface_id", "")))
	if surface.is_empty():
		return {}
	var offset := _vec3_array(placement.get("offset_uvn_m"))
	var position: Vector3 = surface.point \
			+ (surface.u_axis as Vector3) * offset[0] \
			+ (surface.v_axis as Vector3) * offset[1] \
			+ (surface.normal as Vector3) * offset[2]
	var world := instance_world_transform(instance_id)
	var facing := (world.basis * _vec3(
			placement.get("facing_local"))).normalized()
	return {
		"instance_id": instance_id,
		"template_id": str(instance.get("template_id", "")),
		"region_id": str(instance.get("region_id", "")),
		"lineage_id": str(instance.get("lineage_id", "")),
		"semantic_identity": str(instance.get("semantic_identity", "")),
		"placement_id": placement_id,
		"purpose": str(placement.get("purpose", "")),
		"surface_id": str(placement.get("surface_id", "")),
		"position": position,
		"facing": facing,
	}


func resolve_threshold(threshold_id: String) -> Dictionary:
	var record: Dictionary = _thresholds.get(threshold_id, {})
	if record.is_empty():
		return {}
	var owner_id := str(record.get("owner_instance_id", ""))
	var surface := resolve_surface(owner_id,
			str(record.get("owner_surface_id", "")))
	var exterior := resolve_placement(owner_id,
			str(record.get("exterior_placement_id", "")))
	var interior := resolve_placement(owner_id,
			str(record.get("interior_placement_id", "")))
	if surface.is_empty() or exterior.is_empty() or interior.is_empty():
		return {}
	return {
		"id": threshold_id,
		"shop_id": str(record.get("shop_id", "")),
		"region_id": str(record.get("region_id", "")),
		"lineage_id": str(record.get("lineage_id", "")),
		"owner_instance_id": owner_id,
		"owner_surface_id": str(record.get("owner_surface_id", "")),
		"interactive_leaf_id": str(record.get("interactive_leaf_id", "")),
		"surface": surface,
		"exterior": exterior,
		"interior": interior,
	}


func resolve_route(route_id: String) -> Dictionary:
	var record: Dictionary = _routes.get(route_id, {})
	if record.is_empty():
		return {}
	var resolved_nodes: Array[Dictionary] = []
	for value: Variant in record.get("nodes", []):
		var node: Dictionary = value as Dictionary
		var placement := resolve_placement(
				str(node.get("owner_instance_id", "")),
				str(node.get("placement_id", "")))
		if placement.is_empty():
			return {}
		resolved_nodes.append({
			"id": str(node.get("id", "")),
			"owner_instance_id": str(node.get("owner_instance_id", "")),
			"placement_id": str(node.get("placement_id", "")),
			"placement": placement,
		})
	var resolved_thresholds: Array[Dictionary] = []
	for value: Variant in record.get("threshold_ids", []):
		var threshold := resolve_threshold(str(value))
		if threshold.is_empty():
			return {}
		resolved_thresholds.append(threshold)
	return {
		"id": route_id,
		"direction": str(record.get("direction", "")),
		"lineage_id": str(record.get("lineage_id", "")),
		"region_ids": (record.get("region_ids", []) as Array).duplicate(),
		"thresholds": resolved_thresholds,
		"nodes": resolved_nodes,
	}


## Reconstruct one semantic cursor from current source. No serialized world
## position participates in the result.
func reconstruct_route(route_id: String, waypoint_id: String) -> Dictionary:
	var route := resolve_route(route_id)
	for value: Variant in route.get("nodes", []):
		if value is Dictionary and str(value.get("id", "")) == waypoint_id:
			return {
				"route_id": route_id,
				"waypoint_id": waypoint_id,
				"direction": str(route.get("direction", "")),
				"placement": (value as Dictionary).get(
						"placement", {}).duplicate(true),
			}
	return {}


func resolved_boundary_xz(instance_id: String) -> Array[Vector2]:
	var template := template_record_for_instance(instance_id)
	var bounds: Variant = template.get("boundary_xz_m")
	var world := instance_world_transform(instance_id)
	if bounds is not Array or bounds.size() != 4 or not _valid_transform(world):
		return []
	var result: Array[Vector2] = []
	for local: Vector3 in [
		Vector3(float(bounds[0]), 0.0, float(bounds[1])),
		Vector3(float(bounds[2]), 0.0, float(bounds[1])),
		Vector3(float(bounds[2]), 0.0, float(bounds[3])),
		Vector3(float(bounds[0]), 0.0, float(bounds[3]))]:
		var point := world * local
		result.append(Vector2(point.x, point.z))
	return result


func teardown() -> void:
	errors.clear()
	source_hash = ""
	_clear()


func _validate_frame(value: Variant) -> void:
	if value is not Dictionary:
		errors.append("frame must be a dictionary")
		return
	var frame: Dictionary = value as Dictionary
	if not _has_exact_keys(frame, FRAME_KEYS):
		errors.append("frame has unknown or missing fields")
	var ruled: Variant = FrameContract.load_default()
	if not ruled.errors.is_empty():
		errors.append("ruled shared-frame source is invalid")
		return
	var neighbourhood: Dictionary = ruled.data.get("neighbourhood", {})
	var origin: Dictionary = neighbourhood.get("origin", {})
	if str(frame.get("origin_identity", "")) != str(origin.get("identity", "")) \
			or str(frame.get("outward_axis", "")) \
			!= str(neighbourhood.get("outward_axis", "")) \
			or str(frame.get("unit", "")) != "m" \
			or str(frame.get("canonical_root_instance_id", "")).is_empty():
		errors.append("frame disagrees with the ruled Orison v2 shared frame")
	if _vec3_array(origin.get("point_m")) != Vector3.ZERO:
		errors.append("ruled neighbourhood origin must remain [0,0,0]")
	_frame = frame.duplicate(true)


func _index_regions(value: Variant) -> void:
	if value is not Array or (value as Array).is_empty():
		errors.append("regions must be a non-empty array")
		return
	var lineages := LineageRegistry.new()
	if not lineages.load_registry():
		errors.append("corruption lineage registry refused its source")
		return
	for raw: Variant in value:
		if raw is not Dictionary:
			errors.append("region record is not a dictionary")
			continue
		var record: Dictionary = raw as Dictionary
		var ident := str(record.get("id", ""))
		if not _has_exact_keys(record, REGION_KEYS):
			errors.append("%s region has unknown or missing fields" % ident)
		if not ident.begins_with("REGION_") or _regions.has(ident):
			errors.append("invalid or duplicate region identity: %s" % ident)
			continue
		if str(record.get("kind", "")).is_empty():
			errors.append("%s region has no kind" % ident)
		var lineage_id := str(record.get("lineage_id", ""))
		if lineage_id.is_empty() or not lineages.has_space(lineage_id):
			errors.append("%s region has missing lineage %s" % [ident, lineage_id])
		if not _valid_boundary(record.get("boundary")):
			errors.append("%s region has malformed boundary" % ident)
		_regions[ident] = record.duplicate(true)


func _index_templates(value: Variant) -> void:
	if value is not Array or (value as Array).is_empty():
		errors.append("surface_templates must be a non-empty array")
		return
	var lineages := LineageRegistry.new()
	if not lineages.load_registry():
		errors.append("corruption lineage registry refused its source")
		return
	for raw: Variant in value:
		if raw is not Dictionary:
			errors.append("surface template is not a dictionary")
			continue
		var record: Dictionary = raw as Dictionary
		var ident := str(record.get("id", ""))
		if not _has_exact_keys(record, TEMPLATE_KEYS):
			errors.append("%s template has unknown or missing fields" % ident)
		if ident.is_empty() or _templates.has(ident):
			errors.append("invalid or duplicate template identity: %s" % ident)
			continue
		var lineage_id := str(record.get("lineage_id", ""))
		if str(record.get("kind", "")).is_empty() or lineage_id.is_empty() \
				or not lineages.has_space(lineage_id):
			errors.append("%s template has invalid kind or lineage" % ident)
		if not _valid_bounds(record.get("boundary_xz_m")):
			errors.append("%s template has invalid boundary_xz_m" % ident)
		_validate_template_records(ident, record)
		_templates[ident] = record.duplicate(true)


func _validate_template_records(template_id: String,
		record: Dictionary) -> void:
	var surfaces_value: Variant = record.get("surfaces")
	var placements_value: Variant = record.get("placements")
	if surfaces_value is not Array or (surfaces_value as Array).is_empty():
		errors.append("%s must declare public surfaces" % template_id)
		return
	if placements_value is not Array or (placements_value as Array).is_empty():
		errors.append("%s must declare named placements" % template_id)
		return
	var surface_ids := {}
	for raw: Variant in surfaces_value:
		if raw is not Dictionary:
			errors.append("%s has non-dictionary surface" % template_id)
			continue
		var surface: Dictionary = raw as Dictionary
		var ident := str(surface.get("id", ""))
		if not _has_exact_keys(surface, SURFACE_KEYS):
			errors.append("%s/%s surface has unknown or missing fields" % [
				template_id, ident])
		if ident.is_empty() or surface_ids.has(ident):
			errors.append("%s has invalid or duplicate surface %s" % [
				template_id, ident])
			continue
		if str(surface.get("kind", "")).is_empty() \
				or not _valid_vec3(surface.get("point_m")) \
				or not _valid_surface_axes(surface) \
				or not _valid_size(surface.get("size_m")):
			errors.append("%s/%s surface geometry is malformed" % [
				template_id, ident])
		surface_ids[ident] = true
	var placement_ids := {}
	for raw: Variant in placements_value:
		if raw is not Dictionary:
			errors.append("%s has non-dictionary placement" % template_id)
			continue
		var placement: Dictionary = raw as Dictionary
		var ident := str(placement.get("id", ""))
		if not _has_exact_keys(placement, PLACEMENT_KEYS):
			errors.append("%s/%s placement has unknown or missing fields" % [
				template_id, ident])
		if ident.is_empty() or placement_ids.has(ident):
			errors.append("%s has invalid or duplicate placement %s" % [
				template_id, ident])
			continue
		if str(placement.get("purpose", "")).is_empty() \
				or not surface_ids.has(str(placement.get("surface_id", ""))) \
				or not _valid_vec3(placement.get("offset_uvn_m")) \
				or not _valid_direction(placement.get("facing_local")):
			errors.append("%s/%s placement is malformed" % [template_id, ident])
		placement_ids[ident] = true


func _index_instances(value: Variant) -> void:
	if value is not Array or (value as Array).is_empty():
		errors.append("instances must be a non-empty array")
		return
	for raw: Variant in value:
		if raw is not Dictionary:
			errors.append("instance record is not a dictionary")
			continue
		var record: Dictionary = raw as Dictionary
		var ident := str(record.get("id", ""))
		if not _has_exact_keys(record, INSTANCE_KEYS):
			errors.append("%s instance has unknown or missing fields" % ident)
		if ident.is_empty() or _instances.has(ident):
			errors.append("invalid or duplicate instance identity: %s" % ident)
			continue
		var template_id := str(record.get("template_id", ""))
		var region_id := str(record.get("region_id", ""))
		var lineage_id := str(record.get("lineage_id", ""))
		if not _templates.has(template_id) or not _regions.has(region_id):
			errors.append("%s names a missing template or region" % ident)
		elif lineage_id != str(_templates[template_id].get("lineage_id", "")) \
				or lineage_id != str(_regions[region_id].get("lineage_id", "")):
			errors.append("%s lineage differs from template or region" % ident)
		if not _valid_vec3(record.get("offset_uvn_m")) \
				or not _finite_number(record.get("local_yaw_degrees")):
			errors.append("%s has a malformed offset or local yaw" % ident)
		if str(record.get("semantic_identity", "")).is_empty() \
				or str(record.get("display_name", "")).is_empty():
			errors.append("%s has incomplete semantic presentation fields" % ident)
		_instances[ident] = record.duplicate(true)


func _index_thresholds(value: Variant) -> void:
	if value is not Array:
		errors.append("thresholds must be an array")
		return
	for raw: Variant in value:
		if raw is not Dictionary:
			errors.append("threshold record is not a dictionary")
			continue
		var record: Dictionary = raw as Dictionary
		var ident := str(record.get("id", ""))
		if not _has_exact_keys(record, THRESHOLD_KEYS):
			errors.append("%s threshold has unknown or missing fields" % ident)
		if not ident.begins_with("THRESHOLD_") or _thresholds.has(ident):
			errors.append("invalid or duplicate threshold identity: %s" % ident)
			continue
		_thresholds[ident] = record.duplicate(true)


func _index_routes(value: Variant) -> void:
	if value is not Array or (value as Array).is_empty():
		errors.append("routes must be a non-empty array")
		return
	for raw: Variant in value:
		if raw is not Dictionary:
			errors.append("route record is not a dictionary")
			continue
		var record: Dictionary = raw as Dictionary
		var ident := str(record.get("id", ""))
		if not _has_exact_keys(record, ROUTE_KEYS):
			errors.append("%s route has unknown or missing fields" % ident)
		if not ident.begins_with("ROUTE_") or _routes.has(ident):
			errors.append("invalid or duplicate route identity: %s" % ident)
			continue
		_routes[ident] = record.duplicate(true)


func _validate_instance_graph() -> void:
	var frame_identity := str(_frame.get("origin_identity", ""))
	var canonical_root := str(_frame.get("canonical_root_instance_id", ""))
	if not _instances.has(canonical_root):
		errors.append("canonical root instance is missing: %s" % canonical_root)
	for ident: String in instance_ids():
		var record: Dictionary = _instances[ident]
		var owner_id := str(record.get("owner_instance_id", ""))
		var owner_surface_id := str(record.get("owner_surface_id", ""))
		var root_identity := str(record.get("root_frame_identity", ""))
		if owner_id.is_empty() != owner_surface_id.is_empty():
			errors.append("%s has a partial owner reference" % ident)
		elif owner_id.is_empty():
			if root_identity != frame_identity:
				errors.append("%s root is not attached to the ruled frame" % ident)
		elif not root_identity.is_empty():
			errors.append("%s child also claims shared-frame ownership" % ident)
		elif owner_id == ident or not _instances.has(owner_id) \
				or surface_record(owner_id, owner_surface_id).is_empty():
			errors.append("%s names a missing/self owner instance or surface" % ident)
		if ident == canonical_root:
			if not owner_id.is_empty() \
					or _vec3_array(record.get("offset_uvn_m")) != Vector3.ZERO \
					or not is_zero_approx(float(record.get(
							"local_yaw_degrees", INF))):
				errors.append("canonical root must remain at exact ruled origin/yaw")
	# Resolution performs the cycle check and caches every complete transform.
	for ident: String in instance_ids():
		var resolved := _instance_world_transform_internal(ident, {})
		if not _valid_transform(resolved):
			errors.append("instance transform does not resolve: %s" % ident)


func _validate_threshold_references() -> void:
	var frame: Variant = FrameContract.load_default()
	for ident: String in threshold_ids():
		var record: Dictionary = _thresholds[ident]
		var owner_id := str(record.get("owner_instance_id", ""))
		var owner: Dictionary = _instances.get(owner_id, {})
		var shop_id := str(record.get("shop_id", ""))
		if owner.is_empty() or shop_id != owner_id \
				or frame.shop_id(shop_id) != shop_id:
			errors.append("%s does not identify a canonical shop instance" % ident)
		if str(record.get("region_id", "")) \
				!= str(owner.get("region_id", "")) \
				or str(record.get("lineage_id", "")) \
				!= str(owner.get("lineage_id", "")):
			errors.append("%s region/lineage differs from its owner" % ident)
		var surface_id := str(record.get("owner_surface_id", ""))
		if resolve_surface(owner_id, surface_id).is_empty() \
				or resolve_placement(owner_id, str(record.get(
						"exterior_placement_id", ""))).is_empty() \
				or resolve_placement(owner_id, str(record.get(
						"interior_placement_id", ""))).is_empty() \
				or str(record.get("interactive_leaf_id", "")).is_empty():
			errors.append("%s has an unresolved public surface or placement" % ident)


func _validate_route_references() -> void:
	var lineages := LineageRegistry.new()
	lineages.load_registry()
	for ident: String in route_ids():
		var record: Dictionary = _routes[ident]
		if str(record.get("direction", "")) not in [
				"toward_shop", "toward_orison"]:
			errors.append("%s route has invalid direction" % ident)
		var lineage_id := str(record.get("lineage_id", ""))
		if lineage_id.is_empty() or not lineages.has_space(lineage_id):
			errors.append("%s route has missing lineage" % ident)
		var region_ids: Variant = record.get("region_ids")
		var threshold_values: Variant = record.get("threshold_ids")
		var nodes: Variant = record.get("nodes")
		if region_ids is not Array or (region_ids as Array).is_empty() \
				or threshold_values is not Array \
				or nodes is not Array or (nodes as Array).size() < 2:
			errors.append("%s route collections are malformed" % ident)
			continue
		if not _unique_existing_strings(region_ids, _regions):
			errors.append("%s route names duplicate/missing regions" % ident)
		if not _unique_existing_strings(threshold_values, _thresholds):
			errors.append("%s route names duplicate/missing thresholds" % ident)
		var node_ids := {}
		for raw: Variant in nodes:
			if raw is not Dictionary:
				errors.append("%s route has a non-dictionary node" % ident)
				continue
			var node: Dictionary = raw as Dictionary
			var node_id := str(node.get("id", ""))
			if not _has_exact_keys(node, ROUTE_NODE_KEYS) \
					or node_id.is_empty() or node_ids.has(node_id) \
					or resolve_placement(str(node.get(
							"owner_instance_id", "")), str(node.get(
							"placement_id", ""))).is_empty():
				errors.append("%s route node is duplicate or unresolved: %s" % [
					ident, node_id])
			node_ids[node_id] = true


func _instance_world_transform_internal(instance_id: String,
		visiting: Dictionary) -> Transform3D:
	if _instance_transform_cache.has(instance_id):
		return _instance_transform_cache[instance_id]
	if visiting.has(instance_id):
		errors.append("instance ownership cycle reaches %s" % instance_id)
		return _invalid_transform()
	var record: Dictionary = _instances.get(instance_id, {})
	if record.is_empty():
		return _invalid_transform()
	var next_visiting := visiting.duplicate()
	next_visiting[instance_id] = true
	var offset := _vec3_array(record.get("offset_uvn_m"))
	var yaw := Basis(Vector3.UP, deg_to_rad(float(record.get(
			"local_yaw_degrees", 0.0))))
	var owner_id := str(record.get("owner_instance_id", ""))
	var result: Transform3D
	if owner_id.is_empty():
		# Shared-frame axes are U=+X, V=+Z, N=+Y.
		var origin := Vector3(offset.x, offset.z, offset.y)
		result = Transform3D(yaw, origin)
	else:
		var owner_world := _instance_world_transform_internal(
				owner_id, next_visiting)
		if not _valid_transform(owner_world):
			return owner_world
		var owner_surface := surface_record(owner_id,
				str(record.get("owner_surface_id", "")))
		if owner_surface.is_empty():
			return _invalid_transform()
		var point := owner_world * _vec3(owner_surface.get("point_m"))
		var u_axis := (owner_world.basis * _vec3(
				owner_surface.get("u_axis"))).normalized()
		var v_axis := (owner_world.basis * _vec3(
				owner_surface.get("v_axis"))).normalized()
		var normal := (owner_world.basis * _vec3(
				owner_surface.get("normal"))).normalized()
		var origin := point + u_axis * offset.x + v_axis * offset.y \
				+ normal * offset.z
		var owner_frame := Basis(u_axis, normal, v_axis)
		if owner_frame.determinant() <= 0.0:
			errors.append("owner surface frame is not right-handed: %s/%s" % [
				owner_id, str(record.get("owner_surface_id", ""))])
			return _invalid_transform()
		result = Transform3D(owner_frame.orthonormalized() * yaw, origin)
	_instance_transform_cache[instance_id] = result
	return result


static func _valid_surface_axes(surface: Dictionary) -> bool:
	for field: String in ["u_axis", "v_axis", "normal"]:
		if not _valid_direction(surface.get(field)):
			return false
	var u_axis := _vec3(surface.get("u_axis")).normalized()
	var v_axis := _vec3(surface.get("v_axis")).normalized()
	var normal := _vec3(surface.get("normal")).normalized()
	return absf(u_axis.dot(v_axis)) < 0.0001 \
			and absf(u_axis.dot(normal)) < 0.0001 \
			and absf(v_axis.dot(normal)) < 0.0001


static func _valid_boundary(value: Variant) -> bool:
	if value is not Array or (value as Array).size() < 3:
		return false
	for point: Variant in value:
		if point is not Array or (point as Array).size() != 2 \
				or not _finite_number(point[0]) \
				or not _finite_number(point[1]):
			return false
	return true


static func _valid_bounds(value: Variant) -> bool:
	if value is not Array or (value as Array).size() != 4:
		return false
	for coordinate: Variant in value:
		if not _finite_number(coordinate):
			return false
	return float(value[0]) < float(value[2]) \
			and float(value[1]) < float(value[3])


static func _valid_size(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 \
			and _finite_number(value[0]) and float(value[0]) > 0.0 \
			and _finite_number(value[1]) and float(value[1]) > 0.0


static func _valid_vec3(value: Variant) -> bool:
	if value is not Array or (value as Array).size() != 3:
		return false
	return _finite_number(value[0]) and _finite_number(value[1]) \
			and _finite_number(value[2])


static func _valid_direction(value: Variant) -> bool:
	return _valid_vec3(value) and _vec3(value).length_squared() > 0.000001


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _vec3(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) \
			if _valid_vec3(value) else Vector3.INF


## UVN arrays intentionally stay UVN here; root conversion into XYZ is
## explicit in `_instance_world_transform_internal`.
static func _vec3_array(value: Variant) -> Vector3:
	return _vec3(value)


static func _valid_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() \
			and is_finite(value.basis.determinant()) \
			and absf(value.basis.determinant()) > 0.000001


static func _invalid_transform() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.INF)


static func _has_exact_keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key: Variant in allowed:
		if not value.has(key):
			return false
	return true


static func _unique_existing_strings(value: Array,
		index: Dictionary) -> bool:
	var seen := {}
	for raw: Variant in value:
		if raw is not String:
			return false
		var ident := str(raw)
		if ident.is_empty() or seen.has(ident) or not index.has(ident):
			return false
		seen[ident] = true
	return true


static func _copy_record(index: Dictionary, ident: String) -> Dictionary:
	var value: Variant = index.get(ident, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _sorted_ids(index: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw: Variant in index:
		result.append(str(raw))
	result.sort()
	return result


func _clear() -> void:
	source_hash = ""
	_frame = {}
	_regions = {}
	_templates = {}
	_instances = {}
	_thresholds = {}
	_routes = {}
	_instance_transform_cache = {}
