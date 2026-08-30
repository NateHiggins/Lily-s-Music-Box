class_name OrisonV2ExteriorCell
extends Node3D
## Bounded production composition for source-authored Orison v2 exterior cells.
##
## The spatial resolver owns placement. This builder only enumerates authored
## template records, shares primitive resources, and mounts existing gameplay
## implementations at public semantic surfaces. It never reads either v1
## layout and contains no branch for a particular shop or street identity.

const GEOMETRY_PATH := "res://data/orison_v2/exterior/exterior_geometry.json"
const SpatialResolverScript := preload(
		"res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const ShopBucketRegistryScript := preload(
		"res://scripts/building/orison_v2_shop_bucket_registry.gd")
const BodegaSignageScript := preload(
		"res://scripts/props/bodega_signage_prop.gd")

const DOCUMENT_KEYS := ["schema_version", "materials", "templates"]
const MATERIAL_KEYS := ["id", "albedo_rgba", "roughness", "metallic",
		"emission_rgb", "emission_energy"]
const TEMPLATE_KEYS := ["id", "boxes", "labels", "lights", "doors",
		"functional_props", "service_counters"]
const BOX_KEYS := ["id", "size_m", "position_m", "yaw_degrees",
		"material_id", "collision", "visible"]
const LABEL_KEYS := ["id", "text", "font_size", "pixel_size",
		"position_m", "yaw_degrees", "color_rgba", "outline_color_rgba",
		"outline_size", "billboard"]
const LIGHT_KEYS := ["id", "position_m", "color_rgb", "energy",
		"range_m", "shadows"]
const DOOR_KEYS := ["surface_id", "offset_uvn_m", "local_yaw_degrees",
		"width_m", "height_m", "leaf_state", "swing_out", "door_kind",
		"finish_variant"]
const FUNCTIONAL_PROP_KEYS := ["kind", "surface_id", "offset_uvn_m",
		"local_yaw_degrees", "prop_type"]
const COUNTER_KEYS := ["placement_id", "interaction_size_m",
		"physical_label"]
const DEPENDENCY_KEYS := ["player", "work_orders", "maintenance_inventory",
		"shop_service", "spatial_resolver", "shop_bucket_registry",
		"geometry_source"]
const PROP_SCRIPTS := {"bodega_signage": BodegaSignageScript}

var startup_failed := false
var startup_errors: Array[String] = []
var geometry_source_hash := ""

var player: PlayerController
var work_orders: WorkOrders
var maintenance_inventory: MaintenanceInventory
var shop_service: MaintenanceShopService
var spatial_resolver: Variant
var shop_bucket_registry: Variant

var _objective_tracker: ObjectiveTracker
var _geometry_source: Dictionary = {}
var _material_records: Dictionary = {}
var _geometry_templates: Dictionary = {}
var _material_cache: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _instance_nodes: Dictionary = {}
var _collision_bodies: Dictionary = {}
var _doors: Dictionary = {}
var _functional_props: Array[Node] = []
var _counter_shop_ids: Array[String] = []
var _audio_source_ids: Array[StringName] = []
var _owned_nodes: Array[Node] = []
var _owns_spatial_resolver := false
var _owns_shop_bucket_registry := false
var _configured := false
var _built := false
var _shutdown := false
var _teardown_receipt: Dictionary = {}


## Dependency injection is intentionally pre-tree only. A production parent
## may supply its sole authorities; an unparented supplied node is adopted by
## this module so teardown still has one deterministic owner.
func configure_dependencies(dependencies: Dictionary) -> bool:
	if is_inside_tree() or _built or _configured:
		return false
	for key: Variant in dependencies:
		if str(key) not in DEPENDENCY_KEYS:
			return false
	var value: Variant
	if dependencies.has("player"):
		value = dependencies.get("player")
		if value is not PlayerController:
			return false
		player = value as PlayerController
	if dependencies.has("work_orders"):
		value = dependencies.get("work_orders")
		if value is not WorkOrders:
			return false
		work_orders = value as WorkOrders
	if dependencies.has("maintenance_inventory"):
		value = dependencies.get("maintenance_inventory")
		if value is not MaintenanceInventory:
			return false
		maintenance_inventory = value as MaintenanceInventory
	if dependencies.has("shop_service"):
		value = dependencies.get("shop_service")
		if value is not MaintenanceShopService:
			return false
		shop_service = value as MaintenanceShopService
	if dependencies.has("spatial_resolver"):
		value = dependencies.get("spatial_resolver")
		if value == null or not value.has_method("instance_ids"):
			return false
		spatial_resolver = value
	if dependencies.has("shop_bucket_registry"):
		value = dependencies.get("shop_bucket_registry")
		if value == null or not value.has_method("source_ids"):
			return false
		shop_bucket_registry = value
	if dependencies.has("geometry_source"):
		value = dependencies.get("geometry_source")
		if value is not Dictionary:
			return false
		_geometry_source = (value as Dictionary).duplicate(true)
	_configured = true
	return true


func _ready() -> void:
	build()


func build() -> bool:
	if _built:
		return not startup_failed
	_built = true
	_shutdown = false
	startup_failed = false
	startup_errors.clear()
	if not global_transform.is_equal_approx(Transform3D.IDENTITY):
		_fail("exterior cell root must remain at the ruled shared-frame identity")
		return false
	add_to_group("orison_v2_exterior_cell")
	add_to_group("production_exterior_module")
	if not _load_geometry_source():
		return false
	if not _prepare_spatial_authority():
		return false
	if not _prepare_bucket_authority():
		return false
	if not _compose_authorities():
		return false
	var instances_root := Node3D.new()
	instances_root.name = "ExteriorInstances"
	add_child(instances_root)
	_owned_nodes.append(instances_root)
	for instance_id: String in spatial_resolver.instance_ids():
		_build_instance(instances_root, instance_id)
	if startup_failed:
		return false
	_mount_public_interactions()
	if startup_failed:
		return false
	_compose_player()
	if startup_failed:
		return false
	return true


func interaction_leaf(identity: String) -> DoorProp:
	return _doors.get(identity) as DoorProp


func service_counter(shop_id: String) -> Area3D:
	return shop_service.counter(shop_id) as Area3D if shop_service else null


func instance_node(instance_id: String) -> Node3D:
	return _instance_nodes.get(instance_id) as Node3D


func route(route_id: String) -> Dictionary:
	return spatial_resolver.resolve_route(route_id) if spatial_resolver else {}


func shop_snapshot(shop_id: String) -> Dictionary:
	return shop_bucket_registry.snapshot(shop_id) \
			if shop_bucket_registry else {}


## Legitimate initial-placement/reconstruction seam. Traversal proofs must not
## use it between route stages.
func place_player_at_route_waypoint(route_id: String,
		waypoint_id: String) -> bool:
	if player == null or spatial_resolver == null:
		return false
	var cursor: Dictionary = spatial_resolver.reconstruct_route(
			route_id, waypoint_id)
	var placement: Dictionary = cursor.get("placement", {})
	if placement.is_empty():
		return false
	var position_value: Variant = placement.get("position")
	var facing_value: Variant = placement.get("facing")
	if position_value is not Vector3 or facing_value is not Vector3:
		return false
	var local_position := position_value as Vector3
	var local_facing := facing_value as Vector3
	if not local_position.is_finite() or not local_facing.is_finite() \
			or local_facing.length_squared() < 0.000001:
		return false
	var world_position := global_transform * local_position
	var world_facing := (global_transform.basis * local_facing).normalized()
	player.global_position = world_position
	player.global_rotation = Vector3(0.0,
			atan2(-world_facing.x, -world_facing.z), 0.0)
	player.velocity = Vector3.ZERO
	return true


func authority_census() -> Dictionary:
	return {
		"player_controller": 1 if is_instance_valid(player) else 0,
		"work_orders": 1 if is_instance_valid(work_orders) else 0,
		"maintenance_inventory": 1 if is_instance_valid(
				maintenance_inventory) else 0,
		"maintenance_shop_service": 1 if is_instance_valid(
				shop_service) else 0,
		"shop_bucket_registry": 1 if shop_bucket_registry != null else 0,
		"spatial_resolver": 1 if spatial_resolver != null else 0,
	}


func cost_report() -> Dictionary:
	return {
		"instances": _instance_nodes.size(),
		"nodes": _count_nodes(self),
		"meshes": find_children("*", "MeshInstance3D", true, false).size(),
		"collision_shapes": find_children(
				"*", "CollisionShape3D", true, false).size(),
		"collision_objects": find_children(
				"*", "CollisionObject3D", true, false).size(),
		"doors": _doors.size(),
		"counters": _counter_shop_ids.size(),
		"lights": find_children("*", "Light3D", true, false).size(),
		"labels": find_children("*", "Label3D", true, false).size(),
		"shared_meshes": _mesh_cache.size(),
		"shared_materials": _material_cache.size(),
		"shared_shapes": _shape_cache.size(),
	}


## Public teardown knows only semantic source IDs and public service APIs.
## It never reaches into AudioPolicy's pool or a renderer node by name.
func teardown() -> Dictionary:
	return _teardown(true)


func shutdown_for_tests() -> Dictionary:
	return teardown()


func _exit_tree() -> void:
	if not _shutdown:
		_teardown(false)


func _load_geometry_source() -> bool:
	var source := _geometry_source
	if source.is_empty():
		var text := FileAccess.get_file_as_string(GEOMETRY_PATH)
		if text.is_empty():
			_fail("exterior geometry source missing or empty: %s" % GEOMETRY_PATH)
			return false
		var parsed: Variant = JSON.parse_string(text)
		if parsed is not Dictionary:
			_fail("exterior geometry source is not a dictionary")
			return false
		source = (parsed as Dictionary).duplicate(true)
		geometry_source_hash = text.sha256_text()
	else:
		geometry_source_hash = JSON.stringify(source).sha256_text()
	return _configure_geometry(source)


func _configure_geometry(source: Dictionary) -> bool:
	_material_records.clear()
	_geometry_templates.clear()
	if not _has_exact_keys(source, DOCUMENT_KEYS):
		_fail("exterior geometry document has unknown or missing fields")
	if int(source.get("schema_version", -1)) != 1:
		_fail("exterior geometry schema_version must be 1")
	var materials_value: Variant = source.get("materials")
	var templates_value: Variant = source.get("templates")
	if materials_value is not Array or (materials_value as Array).is_empty():
		_fail("exterior geometry materials must be a non-empty array")
	else:
		for value: Variant in materials_value:
			_validate_material(value)
	if templates_value is not Array or (templates_value as Array).is_empty():
		_fail("exterior geometry templates must be a non-empty array")
	else:
		for value: Variant in templates_value:
			_validate_template(value)
	if startup_failed:
		_material_records.clear()
		_geometry_templates.clear()
		return false
	_geometry_source = source.duplicate(true)
	return true


func _validate_material(value: Variant) -> void:
	if value is not Dictionary:
		_fail("exterior material record is not a dictionary")
		return
	var record: Dictionary = value as Dictionary
	var ident := str(record.get("id", ""))
	if not _has_exact_keys(record, MATERIAL_KEYS):
		_fail("%s material has unknown or missing fields" % ident)
	if ident.is_empty() or _material_records.has(ident):
		_fail("invalid or duplicate exterior material: %s" % ident)
		return
	if not _valid_color(record.get("albedo_rgba"), true) \
			or not _valid_color(record.get("emission_rgb"), false) \
			or not _number_in(record.get("roughness"), 0.0, 1.0) \
			or not _number_in(record.get("metallic"), 0.0, 1.0) \
			or not _number_in(record.get("emission_energy"), 0.0, 16.0):
		_fail("%s material values are malformed" % ident)
	_material_records[ident] = record.duplicate(true)


func _validate_template(value: Variant) -> void:
	if value is not Dictionary:
		_fail("exterior geometry template is not a dictionary")
		return
	var record: Dictionary = value as Dictionary
	var ident := str(record.get("id", ""))
	if not _has_exact_keys(record, TEMPLATE_KEYS):
		_fail("%s geometry template has unknown or missing fields" % ident)
	if ident.is_empty() or _geometry_templates.has(ident):
		_fail("invalid or duplicate exterior geometry template: %s" % ident)
		return
	var local_ids := {}
	_validate_record_array(ident, record.get("boxes"), BOX_KEYS,
			Callable(self, "_validate_box"), local_ids)
	_validate_record_array(ident, record.get("labels"), LABEL_KEYS,
			Callable(self, "_validate_label"), local_ids)
	_validate_record_array(ident, record.get("lights"), LIGHT_KEYS,
			Callable(self, "_validate_light"), local_ids)
	_validate_record_array(ident, record.get("doors"), DOOR_KEYS,
			Callable(self, "_validate_door"), {})
	_validate_record_array(ident, record.get("functional_props"),
			FUNCTIONAL_PROP_KEYS, Callable(self, "_validate_functional_prop"), {})
	_validate_record_array(ident, record.get("service_counters"), COUNTER_KEYS,
			Callable(self, "_validate_counter"), {})
	_geometry_templates[ident] = record.duplicate(true)


func _validate_record_array(template_id: String, value: Variant,
		keys: Array, validator: Callable, local_ids: Dictionary) -> void:
	if value is not Array:
		_fail("%s geometry collection must be an array" % template_id)
		return
	for raw: Variant in value:
		if raw is not Dictionary:
			_fail("%s geometry record is not a dictionary" % template_id)
			continue
		var record: Dictionary = raw as Dictionary
		if not _has_exact_keys(record, keys):
			_fail("%s geometry record has unknown or missing fields" % template_id)
		validator.call(template_id, record, local_ids)


func _validate_box(template_id: String, record: Dictionary,
		local_ids: Dictionary) -> void:
	var ident := str(record.get("id", ""))
	if not _claim_local_id(template_id, ident, local_ids) \
			or not _valid_size3(record.get("size_m")) \
			or not _valid_vec3(record.get("position_m")) \
			or not _finite_number(record.get("yaw_degrees")) \
			or not _material_records.has(str(record.get("material_id", ""))) \
			or record.get("collision") is not bool \
			or record.get("visible") is not bool:
		_fail("%s/%s box is malformed" % [template_id, ident])


func _validate_label(template_id: String, record: Dictionary,
		local_ids: Dictionary) -> void:
	var ident := str(record.get("id", ""))
	if not _claim_local_id(template_id, ident, local_ids) \
			or str(record.get("text", "")).is_empty() \
			or int(record.get("font_size", 0)) <= 0 \
			or not _number_in(record.get("pixel_size"), 0.0001, 0.1) \
			or not _valid_vec3(record.get("position_m")) \
			or not _finite_number(record.get("yaw_degrees")) \
			or not _valid_color(record.get("color_rgba"), true) \
			or not _valid_color(record.get("outline_color_rgba"), true) \
			or int(record.get("outline_size", -1)) < 0 \
			or record.get("billboard") is not bool:
		_fail("%s/%s label is malformed" % [template_id, ident])


func _validate_light(template_id: String, record: Dictionary,
		local_ids: Dictionary) -> void:
	var ident := str(record.get("id", ""))
	if not _claim_local_id(template_id, ident, local_ids) \
			or not _valid_vec3(record.get("position_m")) \
			or not _valid_color(record.get("color_rgb"), false) \
			or not _number_in(record.get("energy"), 0.0, 16.0) \
			or not _number_in(record.get("range_m"), 0.1, 64.0) \
			or record.get("shadows") is not bool:
		_fail("%s/%s light is malformed" % [template_id, ident])


func _validate_door(template_id: String, record: Dictionary,
		_unused: Dictionary) -> void:
	if str(record.get("surface_id", "")).is_empty() \
			or not _valid_vec3(record.get("offset_uvn_m")) \
			or not _finite_number(record.get("local_yaw_degrees")) \
			or not _number_in(record.get("width_m"), 0.45, 2.2) \
			or not _number_in(record.get("height_m"), 1.2, 3.5) \
			or str(record.get("leaf_state", "")) not in [
					"closed", "open", "locked"] \
			or record.get("swing_out") is not bool \
			or str(record.get("door_kind", "")).is_empty() \
			or not _whole_number(record.get("finish_variant"), 0, 64):
		_fail("%s door specification is malformed" % template_id)


func _validate_functional_prop(template_id: String, record: Dictionary,
		_unused: Dictionary) -> void:
	if not PROP_SCRIPTS.has(str(record.get("kind", ""))) \
			or str(record.get("surface_id", "")).is_empty() \
			or not _valid_vec3(record.get("offset_uvn_m")) \
			or not _finite_number(record.get("local_yaw_degrees")) \
			or str(record.get("prop_type", "")).is_empty():
		_fail("%s functional-prop specification is malformed" % template_id)


func _validate_counter(template_id: String, record: Dictionary,
		_unused: Dictionary) -> void:
	if str(record.get("placement_id", "")).is_empty() \
			or not _valid_size3(record.get("interaction_size_m")) \
			or str(record.get("physical_label", "")).strip_edges().is_empty():
		_fail("%s service-counter specification is malformed" % template_id)


func _prepare_spatial_authority() -> bool:
	if spatial_resolver == null:
		spatial_resolver = SpatialResolverScript.load_default()
		_owns_spatial_resolver = true
	if not spatial_resolver.is_valid():
		_fail("exterior spatial authority refused its source: %s" % [
				spatial_resolver.errors])
		return false
	for instance_id: String in spatial_resolver.instance_ids():
		var record: Dictionary = spatial_resolver.instance_record(instance_id)
		var template_id := str(record.get("template_id", ""))
		if not _geometry_templates.has(template_id):
			_fail("%s has no exterior geometry template %s" % [
					instance_id, template_id])
	return not startup_failed


func _prepare_bucket_authority() -> bool:
	if shop_bucket_registry == null:
		shop_bucket_registry = ShopBucketRegistryScript.new()
		_owns_shop_bucket_registry = true
	if shop_bucket_registry.source_ids().is_empty() \
			and not shop_bucket_registry.load_source():
		_fail("shop bucket authority refused its source: %s" % [
				shop_bucket_registry.errors])
		return false
	if not shop_bucket_registry.initialize_missing_state():
		_fail("shop bucket state refused initialization: %s" % [
				shop_bucket_registry.errors])
		return false
	var shop_ids := _spatial_shop_ids()
	var source_ids: Array = shop_bucket_registry.source_ids()
	for shop_id: String in shop_ids:
		if shop_id not in source_ids:
			_fail("spatial shop has no source-owned simulation bucket: %s" % shop_id)
	if startup_failed:
		return false
	if not shop_ids.is_empty() \
			and not shop_bucket_registry.bind_state(shop_ids[0]):
		_fail("shop bucket binding refused: %s" % [shop_bucket_registry.errors])
	return not startup_failed


func _compose_authorities() -> bool:
	if work_orders == null:
		_objective_tracker = ObjectiveTracker.new()
		_objective_tracker.name = "ObjectiveTracker"
		_objective_tracker.presentation_enabled = false
		_adopt(_objective_tracker)
		work_orders = WorkOrders.new()
		work_orders.name = "WorkOrders"
		work_orders.setup(_objective_tracker)
		work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
		_adopt(work_orders)
	else:
		_adopt_if_unparented(work_orders)
	if maintenance_inventory == null:
		maintenance_inventory = MaintenanceInventory.new()
		maintenance_inventory.name = "MaintenanceInventory"
		maintenance_inventory.setup()
		_adopt(maintenance_inventory)
	else:
		_adopt_if_unparented(maintenance_inventory)
	if shop_service == null:
		shop_service = MaintenanceShopService.new()
		shop_service.name = "MaintenanceShopService"
		_adopt(shop_service)
		shop_service.setup(maintenance_inventory, work_orders)
	else:
		_adopt_if_unparented(shop_service)
	if not shop_service.is_valid():
		_fail("maintenance shop authority refused production inventory: %s" % [
				shop_service.errors])
	return not startup_failed


func _build_instance(parent: Node3D, instance_id: String) -> void:
	var instance: Dictionary = spatial_resolver.instance_record(instance_id)
	var template_id := str(instance.get("template_id", ""))
	var geometry: Dictionary = _geometry_templates.get(template_id, {})
	var world: Transform3D = spatial_resolver.instance_world_transform(instance_id)
	if geometry.is_empty() or not _valid_transform(world):
		_fail("exterior instance cannot be constructed: %s" % instance_id)
		return
	var cell := Node3D.new()
	cell.name = instance_id
	cell.transform = world
	# Production source contains only the accepted primary cell. Disposable
	# piece-two fixtures control their own capture visibility outside this
	# builder; authored instances are never silently culled here.
	cell.visible = true
	cell.set_meta("template_id", template_id)
	cell.set_meta("region_id", str(instance.get("region_id", "")))
	cell.set_meta("lineage_id", str(instance.get("lineage_id", "")))
	cell.set_meta("semantic_identity", str(instance.get(
			"semantic_identity", "")))
	cell.set_meta("display_name", str(instance.get("display_name", "")))
	cell.add_to_group("orison_v2_exterior_instance")
	parent.add_child(cell)
	_instance_nodes[instance_id] = cell
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 1
	cell.add_child(body)
	_collision_bodies[instance_id] = body
	for value: Variant in geometry.get("boxes", []):
		_build_box(cell, body, value as Dictionary)
	for value: Variant in geometry.get("labels", []):
		_build_label(cell, value as Dictionary)
	for value: Variant in geometry.get("lights", []):
		_build_light(cell, value as Dictionary)


func _build_box(parent: Node3D, body: StaticBody3D,
		record: Dictionary) -> void:
	var size := _vec3(record.get("size_m"))
	var position := _vec3(record.get("position_m"))
	var yaw := float(record.get("yaw_degrees", 0.0))
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "ExteriorMesh"
	mesh_node.set_meta("authored_record_id", str(record.get("id", "")))
	mesh_node.mesh = _box_mesh(size)
	mesh_node.material_override = _material(str(record.get("material_id", "")))
	mesh_node.position = position
	mesh_node.rotation_degrees.y = yaw
	mesh_node.visible = bool(record.get("visible", true))
	parent.add_child(mesh_node)
	if bool(record.get("collision", false)):
		var shape_node := CollisionShape3D.new()
		shape_node.name = "ExteriorCollision"
		shape_node.set_meta("authored_record_id", str(record.get("id", "")))
		shape_node.shape = _box_shape(size)
		shape_node.position = position
		shape_node.rotation_degrees.y = yaw
		body.add_child(shape_node)


func _build_label(parent: Node3D, record: Dictionary) -> void:
	var label := Label3D.new()
	label.name = "ExteriorLabel"
	label.set_meta("authored_record_id", str(record.get("id", "")))
	label.text = str(record.get("text", ""))
	label.font_size = int(record.get("font_size", 48))
	label.pixel_size = float(record.get("pixel_size", 0.003))
	label.position = _vec3(record.get("position_m"))
	label.rotation_degrees.y = float(record.get("yaw_degrees", 0.0))
	label.modulate = _color(record.get("color_rgba"), true)
	label.outline_modulate = _color(record.get("outline_color_rgba"), true)
	label.outline_size = int(record.get("outline_size", 0))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED \
			if bool(record.get("billboard", false)) \
			else BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(label)


func _build_light(parent: Node3D, record: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.name = "ExteriorPractical"
	light.set_meta("authored_record_id", str(record.get("id", "")))
	light.position = _vec3(record.get("position_m"))
	light.light_color = _color(record.get("color_rgb"), false)
	light.light_energy = float(record.get("energy", 1.0))
	light.omni_range = float(record.get("range_m", 4.0))
	light.shadow_enabled = bool(record.get("shadows", false))
	parent.add_child(light)


func _mount_public_interactions() -> void:
	for instance_id: String in spatial_resolver.instance_ids():
		var instance: Dictionary = spatial_resolver.instance_record(instance_id)
		var template_id := str(instance.get("template_id", ""))
		var geometry: Dictionary = _geometry_templates.get(template_id, {})
		for value: Variant in geometry.get("doors", []):
			_mount_door(instance_id, value as Dictionary)
		for value: Variant in geometry.get("functional_props", []):
			_mount_functional_prop(instance_id, value as Dictionary)
		for value: Variant in geometry.get("service_counters", []):
			_mount_service_counter(instance_id, value as Dictionary)


func _mount_door(instance_id: String, specification: Dictionary) -> void:
	var surface_id := str(specification.get("surface_id", ""))
	var threshold := _threshold_for(instance_id, surface_id)
	if threshold.is_empty():
		_fail("%s door has no unique semantic threshold on %s" % [
				instance_id, surface_id])
		return
	var identity := str(threshold.get("interactive_leaf_id", ""))
	if identity.is_empty() or _doors.has(identity):
		_fail("exterior interactive leaf identity is missing/duplicate: %s" % identity)
		return
	var surface: Dictionary = threshold.get("surface", {})
	var world := _surface_mount(surface,
			_vec3(specification.get("offset_uvn_m")),
			float(specification.get("local_yaw_degrees", 0.0)))
	var instance_world: Transform3D = spatial_resolver.instance_world_transform(
			instance_id)
	if not _valid_transform(world) or not _valid_transform(instance_world):
		_fail("%s door surface transform is invalid" % identity)
		return
	var door := DoorProp.new()
	door.name = identity
	door.width = float(specification.get("width_m", 0.95))
	door.height = float(specification.get("height_m", 2.1))
	door.leaf_state = str(specification.get("leaf_state", "closed"))
	door.swing_out = bool(specification.get("swing_out", false))
	door.door_kind = str(specification.get("door_kind", "storefront"))
	door.finish_variant = int(specification.get("finish_variant", 0))
	door.transform = instance_world.affine_inverse() * world
	door.add_to_group("orison_v2_exterior_interaction")
	(instance_node(instance_id) as Node3D).add_child(door)
	_doors[identity] = door
	_audio_source_ids.append(StringName(identity))


func _mount_functional_prop(instance_id: String,
		specification: Dictionary) -> void:
	var kind := str(specification.get("kind", ""))
	var script: GDScript = PROP_SCRIPTS.get(kind)
	var surface: Dictionary = spatial_resolver.resolve_surface(instance_id,
			str(specification.get("surface_id", "")))
	var world := _surface_mount(surface,
			_vec3(specification.get("offset_uvn_m")),
			float(specification.get("local_yaw_degrees", 0.0)))
	var instance_world: Transform3D = spatial_resolver.instance_world_transform(
			instance_id)
	if script == null or not _valid_transform(world) \
			or not _valid_transform(instance_world):
		_fail("%s functional prop cannot resolve %s" % [instance_id, kind])
		return
	var prop: Node3D = script.new()
	prop.name = "ExteriorFunctionalProp"
	prop.set_meta("semantic_instance_id", instance_id)
	prop.set_meta("functional_prop_kind", kind)
	prop.set("prop_type", str(specification.get("prop_type", kind)))
	prop.transform = instance_world.affine_inverse() * world
	prop.add_to_group("orison_v2_exterior_interaction")
	(instance_node(instance_id) as Node3D).add_child(prop)
	var shop_id := str(spatial_resolver.instance_record(instance_id).get(
			"semantic_identity", ""))
	var provider := Callable(shop_bucket_registry, "snapshot").bind(shop_id)
	if prop.has_method("bind_hours_status_provider") \
			and not bool(prop.call("bind_hours_status_provider", provider)):
		_fail("%s/%s failed to bind its source-owned shop bucket" % [
				instance_id, kind])
	var audio_source_id := StringName("exterior-prop:%s:%s" % [
			instance_id, kind])
	if not prop.has_method("bind_audio_source") \
			or not bool(prop.call("bind_audio_source", audio_source_id)):
		_fail("%s/%s lacks a deterministic public audio binding" % [
				instance_id, kind])
	_functional_props.append(prop)
	_audio_source_ids.append(audio_source_id)


func _mount_service_counter(instance_id: String,
		specification: Dictionary) -> void:
	var instance: Dictionary = spatial_resolver.instance_record(instance_id)
	var shop_id := str(instance.get("semantic_identity", ""))
	var placement: Dictionary = spatial_resolver.resolve_placement(instance_id,
			str(specification.get("placement_id", "")))
	if not shop_id.begins_with("SHOP_") or placement.is_empty():
		_fail("%s counter lacks a semantic shop placement" % instance_id)
		return
	var position: Vector3 = placement.get("position", Vector3.INF)
	var facing: Vector3 = placement.get("facing", Vector3.INF)
	var basis: Basis = _basis_from_facing(facing)
	if not position.is_finite() or absf(basis.determinant()) < 0.000001:
		_fail("%s counter placement has an invalid transform" % shop_id)
		return
	var semantic_transform := Transform3D(basis, position)
	var counter: Area3D = shop_service.mount_counter(shop_id,
			global_transform * semantic_transform,
			_vec3(specification.get("interaction_size_m")),
			str(specification.get("physical_label", "counter")))
	if counter == null:
		_fail("maintenance-shop authority refused counter mount: %s" % shop_id)
		return
	counter.add_to_group("orison_v2_exterior_interaction")
	_counter_shop_ids.append(shop_id)
	_audio_source_ids.append(StringName("counter:%s" % shop_id))


func _compose_player() -> void:
	var created := false
	if player == null:
		player = PlayerController.new()
		player.name = "Player"
		created = true
	var route_id := _first_route_in_direction("toward_shop")
	var route_record: Dictionary = spatial_resolver.resolve_route(route_id)
	var nodes: Array = route_record.get("nodes", [])
	if route_id.is_empty() or nodes.is_empty():
		_fail("no semantic toward-shop route can place the production player")
		return
	var first: Dictionary = nodes[0]
	var placement: Dictionary = first.get("placement", {})
	var position: Vector3 = placement.get("position", Vector3.INF)
	var facing: Vector3 = placement.get("facing", Vector3.INF)
	if not position.is_finite() or not facing.is_finite() \
			or facing.length_squared() < 0.000001:
		_fail("production player route placement is malformed")
		return
	if player.get_parent() == null:
		player.position = position
		player.rotation.y = atan2(-facing.normalized().x,
				-facing.normalized().z)
		_adopt(player)
	elif created:
		_fail("new production player unexpectedly has an external parent")


func _threshold_for(instance_id: String, surface_id: String) -> Dictionary:
	var result := {}
	for threshold_id: String in spatial_resolver.threshold_ids():
		var resolved: Dictionary = spatial_resolver.resolve_threshold(threshold_id)
		if str(resolved.get("owner_instance_id", "")) != instance_id \
				or str(resolved.get("owner_surface_id", "")) != surface_id:
			continue
		if not result.is_empty():
			return {}
		result = resolved
	return result


func _first_route_in_direction(direction: String) -> String:
	for route_id: String in spatial_resolver.route_ids():
		var candidate: Dictionary = spatial_resolver.route_record(route_id)
		if str(candidate.get("direction", "")) == direction:
			return route_id
	return ""


func _spatial_shop_ids() -> Array[String]:
	var result: Array[String] = []
	for instance_id: String in spatial_resolver.instance_ids():
		var semantic := str(spatial_resolver.instance_record(instance_id).get(
				"semantic_identity", ""))
		if semantic.begins_with("SHOP_"):
			result.append(semantic)
	result.sort()
	return result


func _surface_mount(surface: Dictionary, offset: Vector3,
		local_yaw_degrees: float) -> Transform3D:
	if surface.is_empty():
		return _invalid_transform()
	var point: Vector3 = surface.get("point", Vector3.INF)
	var u_axis: Vector3 = surface.get("u_axis", Vector3.INF)
	var v_axis: Vector3 = surface.get("v_axis", Vector3.INF)
	var normal: Vector3 = surface.get("normal", Vector3.INF)
	if not point.is_finite() or not u_axis.is_finite() \
			or not v_axis.is_finite() or not normal.is_finite():
		return _invalid_transform()
	# Public surfaces may be vertical (V is up, N faces out) or horizontal
	# (N is up, V runs forward). Choose the more vertical axis as local Y,
	# then derive local Z from U x Y so the mount is right-handed in both
	# cases. This keeps nonzero-yaw fixtures attached instead of mirroring a
	# floor-owned instance.
	var right := u_axis.normalized()
	var floor_like := absf(normal.normalized().dot(Vector3.UP)) \
			>= absf(v_axis.normalized().dot(Vector3.UP))
	var up := normal.normalized() if floor_like else v_axis.normalized()
	var authored_forward := v_axis.normalized() if floor_like \
			else normal.normalized()
	var forward := right.cross(up).normalized()
	var base := Basis(right, up, forward)
	if base.determinant() <= 0.000001 \
			or forward.dot(authored_forward) < 0.999:
		return _invalid_transform()
	var position := point + u_axis * offset.x + v_axis * offset.y \
			+ normal * offset.z
	return Transform3D(base.orthonormalized() * Basis(Vector3.UP,
			deg_to_rad(local_yaw_degrees)), position)


func _basis_from_facing(value: Vector3) -> Basis:
	if not value.is_finite():
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	var forward := Vector3(value.x, 0.0, value.z)
	if forward.length_squared() < 0.000001:
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	forward = forward.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	return Basis(right, Vector3.UP, forward).orthonormalized()


func _material(material_id: String) -> StandardMaterial3D:
	if _material_cache.has(material_id):
		return _material_cache[material_id] as StandardMaterial3D
	var record: Dictionary = _material_records.get(material_id, {})
	var material := StandardMaterial3D.new()
	var albedo := _color(record.get("albedo_rgba"), true)
	material.albedo_color = albedo
	material.roughness = float(record.get("roughness", 1.0))
	material.metallic = float(record.get("metallic", 0.0))
	if albedo.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var emission_energy := float(record.get("emission_energy", 0.0))
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = _color(record.get("emission_rgb"), false)
		material.emission_energy_multiplier = emission_energy
	_material_cache[material_id] = material
	return material


func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.5f|%.5f|%.5f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_cache[key] = mesh
	return mesh


func _box_shape(size: Vector3) -> BoxShape3D:
	var key := "%.5f|%.5f|%.5f" % [size.x, size.y, size.z]
	if _shape_cache.has(key):
		return _shape_cache[key] as BoxShape3D
	var shape := BoxShape3D.new()
	shape.size = size
	_shape_cache[key] = shape
	return shape


func _teardown(detach_children: bool) -> Dictionary:
	if _shutdown:
		var repeated := _teardown_receipt.duplicate(true)
		repeated["already_torn_down"] = true
		return repeated
	_shutdown = true
	var freed_instances := _instance_nodes.size()
	var released_sources := _audio_source_ids.size()
	var released_audio := 0
	for source_id: StringName in _audio_source_ids:
		released_audio += AudioPolicy.release_source(source_id)
	var unmounted := 0
	if is_instance_valid(shop_service):
		for shop_id: String in _counter_shop_ids:
			if shop_service.unmount_counter(shop_id):
				unmounted += 1
	for prop: Node in _functional_props:
		if is_instance_valid(prop) \
				and prop.has_method("release_hours_status_provider"):
			prop.call("release_hours_status_provider")
	if _owns_shop_bucket_registry and shop_bucket_registry != null:
		shop_bucket_registry.teardown()
	if _owns_spatial_resolver and spatial_resolver != null:
		spatial_resolver.teardown()
	var detached := 0
	if detach_children:
		for node: Node in _owned_nodes.duplicate():
			if not is_instance_valid(node) or node.get_parent() != self:
				continue
			remove_child(node)
			node.queue_free()
			detached += 1
	_audio_source_ids.clear()
	_counter_shop_ids.clear()
	_functional_props.clear()
	_doors.clear()
	_collision_bodies.clear()
	_instance_nodes.clear()
	_owned_nodes.clear()
	_material_cache.clear()
	_mesh_cache.clear()
	_shape_cache.clear()
	_material_records.clear()
	_geometry_templates.clear()
	_geometry_source.clear()
	player = null
	work_orders = null
	maintenance_inventory = null
	shop_service = null
	_objective_tracker = null
	spatial_resolver = null
	shop_bucket_registry = null
	_teardown_receipt = {
		"ok": true,
		"already_torn_down": false,
		"released_audio_sources": released_sources,
		"removed_counters": unmounted,
		"freed_instances": freed_instances,
		"released_audio_voices": released_audio,
		"unmounted_counters": unmounted,
		"detached_owned_nodes": detached,
		"retained_strong_references": 0,
	}
	return _teardown_receipt.duplicate(true)


func _adopt(node: Node) -> void:
	if node.get_parent() == null:
		add_child(node)
	if node.get_parent() == self and node not in _owned_nodes:
		_owned_nodes.append(node)


func _adopt_if_unparented(node: Node) -> void:
	if node.get_parent() == null:
		_adopt(node)


func _claim_local_id(template_id: String, ident: String,
		local_ids: Dictionary) -> bool:
	if ident.is_empty() or local_ids.has(ident):
		_fail("%s has invalid or duplicate local geometry id: %s" % [
				template_id, ident])
		return false
	local_ids[ident] = true
	return true


func _fail(message: String) -> void:
	startup_failed = true
	startup_errors.append(message)
	push_error("ORISON V2 EXTERIOR CELL: " + message)


static func _count_nodes(root: Node) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		count += 1
		for child: Node in node.get_children():
			stack.append(child)
	return count


static func _has_exact_keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key: Variant in allowed:
		if not value.has(key):
			return false
	return true


static func _valid_vec3(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 3 \
			and _finite_number(value[0]) and _finite_number(value[1]) \
			and _finite_number(value[2])


static func _valid_size3(value: Variant) -> bool:
	return _valid_vec3(value) and float(value[0]) > 0.0 \
			and float(value[1]) > 0.0 and float(value[2]) > 0.0


static func _valid_color(value: Variant, alpha: bool) -> bool:
	var wanted := 4 if alpha else 3
	if value is not Array or (value as Array).size() != wanted:
		return false
	for component: Variant in value:
		if not _number_in(component, 0.0, 1.0):
			return false
	return true


static func _number_in(value: Variant, minimum: float,
		maximum: float) -> bool:
	return _finite_number(value) and float(value) >= minimum \
			and float(value) <= maximum


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _whole_number(value: Variant, minimum: int,
		maximum: int) -> bool:
	return _finite_number(value) and is_equal_approx(float(value),
			floorf(float(value))) and int(value) >= minimum and int(value) <= maximum


static func _vec3(value: Variant) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) \
			if _valid_vec3(value) else Vector3.INF


static func _color(value: Variant, alpha: bool) -> Color:
	if not _valid_color(value, alpha):
		return Color.MAGENTA
	return Color(float(value[0]), float(value[1]), float(value[2]),
			float(value[3]) if alpha else 1.0)


static func _valid_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and is_finite(value.basis.determinant()) \
			and absf(value.basis.determinant()) > 0.000001


static func _invalid_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
			Vector3.INF)
