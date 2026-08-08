class_name SwcWorldBuilder
extends RefCounted

## Builds the playable world from the semantic scene alone.
##
## This runs before any World Package is considered, and it produces a complete,
## playable level: collision, traversal, interaction, combat, lighting, objectives.
## If package loading were deleted entirely, the game would still work - which is
## the property the whole architecture exists to protect.

const _PROP_TYPES := [
	"crate", "barrel", "machinery", "terminal", "table", "chair", "objective",
]


static func build(scene_data: SwcScene, parent: Node3D) -> Dictionary:
	var result := {
		"entities": {},
		"doors": [],
		"spawners": [],
		"pickups": [],
		"breakables": [],
		"triggers": [],
		"lights": [],
		"ambience_zones": [],
		"objective": null,
		"player_spawn": Transform3D(),
		"player_spawn_params": {},
	}

	for entity_data in scene_data.entities:
		var entity := SwcEntity.new()
		entity.setup(entity_data)
		parent.add_child(entity)

		_attach_gameplay(entity, entity_data, result)
		entity.build_graybox()
		result["entities"][entity.semantic_id] = entity

	return result


static func _attach_gameplay(
	entity: SwcEntity, entity_data: Dictionary, result: Dictionary
) -> void:
	var type_name := entity.semantic_type

	match type_name:
		"player_spawn":
			var origin := SwcScene.position_of(entity_data)
			var yaw := deg_to_rad(float(SwcScene.params_of(entity_data).get("yaw_deg", 0.0)))
			result["player_spawn"] = Transform3D(Basis(Vector3.UP, yaw), origin)
			result["player_spawn_params"] = SwcScene.params_of(entity_data)
			return

		"enemy_spawn":
			# The marker is never drawn. Its skin is the enemy prototype.
			entity.make_prototype_only()
			var spawner := SwcEnemySpawner.new()
			spawner.name = "Spawner"
			spawner.configure(entity)
			entity.add_child(spawner)
			result["spawners"].append(spawner)
			return

		"ambience_zone":
			result["ambience_zones"].append(entity)
			return

		"door":
			result["doors"].append(_build_door(entity, entity_data))
			return

		"pickup", "weapon":
			result["pickups"].append(_build_pickup(entity, entity_data))
			return

		"trigger_volume":
			result["triggers"].append(_build_trigger(entity, entity_data))
			return

		"objective":
			_build_static_body(entity, entity_data)
			var objective := SwcObjective.new()
			objective.name = "Objective"
			objective.configure(entity)
			entity.add_child(objective)
			result["objective"] = objective
			return

		"lamp":
			_build_static_body(entity, entity_data)
			var light := _build_light(entity, entity_data)
			if light != null:
				result["lights"].append(light)
			return

	_build_static_body(entity, entity_data)

	if SwcScene.has_role(entity_data, "breakable"):
		var breakable := SwcBreakable.new()
		breakable.name = "SwcBreakable"
		breakable.configure(entity)
		entity.add_child(breakable)
		result["breakables"].append(breakable)


# ------------------------------------------------------------------- collision


static func _collision_shapes(collision: Dictionary) -> Array[Dictionary]:
	## Returns [{shape: Shape3D, offset: Vector3}], derived only from the scene.
	var out: Array[Dictionary] = []
	var shape_kind := String(collision.get("shape", "none"))
	var raw_offset: Array = collision.get("offset", [0, 0, 0])
	var offset := Vector3(raw_offset[0], raw_offset[1], raw_offset[2])

	match shape_kind:
		"box":
			var extents: Array = collision.get("extents", [0.5, 0.5, 0.5])
			var box := BoxShape3D.new()
			box.size = Vector3(extents[0], extents[1], extents[2]) * 2.0
			out.append({"shape": box, "offset": offset})
		"cylinder":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = float(collision.get("radius", 0.5))
			cylinder.height = float(collision.get("height", 1.0))
			out.append({"shape": cylinder, "offset": offset})
		"capsule":
			var capsule := CapsuleShape3D.new()
			capsule.radius = float(collision.get("radius", 0.4))
			capsule.height = float(collision.get("height", 1.8))
			out.append({"shape": capsule, "offset": offset})
		"multi_box":
			for box_variant in collision.get("boxes", []):
				var entry: Dictionary = box_variant
				var box_offset: Array = entry.get("offset", [0, 0, 0])
				var box_extents: Array = entry.get("extents", [0.5, 0.5, 0.5])
				var shape := BoxShape3D.new()
				shape.size = Vector3(box_extents[0], box_extents[1], box_extents[2]) * 2.0
				out.append(
					{
						"shape": shape,
						"offset": offset
						+ Vector3(box_offset[0], box_offset[1], box_offset[2]),
					}
				)
	return out


static func _build_static_body(entity: SwcEntity, entity_data: Dictionary) -> void:
	var collision: Dictionary = entity_data.get("collision", {})
	var shapes := _collision_shapes(collision)
	if shapes.is_empty():
		return

	var layer_name := String(collision.get("layer", "world"))
	var body: PhysicsBody3D
	if layer_name == "dynamic":
		body = AnimatableBody3D.new()
		body.sync_to_physics = false
	else:
		body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = (
		SwcEntity.LAYER_PROP if layer_name == "prop" else SwcEntity.LAYER_WORLD
	)
	body.collision_mask = 0

	for record in shapes:
		var collider := CollisionShape3D.new()
		collider.shape = record["shape"]
		collider.position = record["offset"]
		body.add_child(collider)

	entity.collision_root.add_child(body)


static func _build_area(
	entity: SwcEntity, entity_data: Dictionary, monitor_mask: int
) -> Area3D:
	var shapes := _collision_shapes(entity_data.get("collision", {}))
	if shapes.is_empty():
		var fallback := BoxShape3D.new()
		fallback.size = SwcScene.size_of(entity_data)
		shapes = [{"shape": fallback, "offset": SwcScene.bounds_offset_of(entity_data)}]

	var area := Area3D.new()
	area.name = "TriggerArea"
	area.collision_layer = SwcEntity.LAYER_TRIGGER
	area.collision_mask = monitor_mask
	area.monitoring = true
	for record in shapes:
		var collider := CollisionShape3D.new()
		collider.shape = record["shape"]
		collider.position = record["offset"]
		area.add_child(collider)
	entity.collision_root.add_child(area)
	return area


# ---------------------------------------------------------------------- pieces


static func _build_door(entity: SwcEntity, entity_data: Dictionary) -> SwcDoor:
	# The hinge position is gameplay data: it comes from the entity's attachment
	# points, not from whatever the generated mesh happens to look like.
	var hinge: Variant = SwcScene.attachment_of(entity_data, "hinge")
	var pivot_offset: Vector3 = (
		hinge if hinge != null else Vector3(-SwcScene.size_of(entity_data).x * 0.5, 0, 0)
	)
	entity.install_motion_pivot(pivot_offset)
	_build_static_body(entity, entity_data)

	var door := SwcDoor.new()
	door.name = "SwcDoor"
	entity.add_child(door)
	door.configure(entity)
	return door


static func _build_pickup(entity: SwcEntity, entity_data: Dictionary) -> SwcPickup:
	var area := _build_area(entity, entity_data, SwcEntity.LAYER_PLAYER)
	var pickup := SwcPickup.new()
	pickup.name = "SwcPickup"
	entity.add_child(pickup)
	pickup.configure(entity, area)
	return pickup


static func _build_trigger(entity: SwcEntity, entity_data: Dictionary) -> SwcTriggerVolume:
	var area := _build_area(entity, entity_data, SwcEntity.LAYER_PLAYER)
	var trigger := SwcTriggerVolume.new()
	trigger.name = "Trigger"
	entity.add_child(trigger)
	trigger.configure(entity, area)
	return trigger


static func _build_light(entity: SwcEntity, entity_data: Dictionary) -> OmniLight3D:
	var params := SwcScene.params_of(entity_data)
	var light := OmniLight3D.new()
	light.name = "Light"
	# Energy and range are gameplay: they decide what the player can see, and every
	# world must present the same readability. A package may tint and scale them
	# (light_override) but never move or replace them.
	light.light_energy = float(params.get("energy", 2.0))
	light.omni_range = float(params.get("range_m", 8.0))
	light.light_color = Color(1.0, 0.98, 0.94)
	light.shadow_enabled = bool(params.get("shadows", true))
	light.distance_fade_enabled = true
	light.distance_fade_begin = 28.0
	light.distance_fade_length = 12.0

	var emitter: Variant = SwcScene.attachment_of(entity_data, "light_emitter")
	light.position = emitter if emitter != null else Vector3.ZERO
	# Remembered so a package's light_override scales the authored value instead of
	# replacing it, and so unloading a package restores the graybox exactly.
	light.set_meta("base_energy", light.light_energy)
	light.set_meta("base_range", light.omni_range)
	entity.add_child(light)
	return light
