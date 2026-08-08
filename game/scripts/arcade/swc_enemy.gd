class_name SwcEnemy
extends CharacterBody3D

## A deliberately simple pursuer.
##
## Built in code rather than from a scene file so every tunable arrives from the
## semantic scene's gameplay_metrics. Its visual is a graybox capsule; dressing
## enemies with generated characters is a later phase (docs/roadmap.md), and the
## architecture already has the seam for it.

signal died(enemy: SwcEnemy)

const _RAY_MASK := SwcEntity.LAYER_WORLD | SwcEntity.LAYER_PROP

var max_health: int = 60
var damage: int = 9
var move_speed: float = 3.4
var attack_interval_s: float = 1.1
var attack_range_m: float = 22.0
var gravity: float = 22.0

var _health: int = 60
var _target: SwcPlayer = null
var _attack_cooldown: float = 0.0
var _alerted: bool = false
var _mesh: MeshInstance3D
var _eye: MeshInstance3D
var _skin: Node3D
var _spawner_entity: SwcEntity = null
var _bob: float = 0.0


static func create(metrics: Dictionary, target: SwcPlayer, source: SwcEntity) -> SwcEnemy:
	var enemy := SwcEnemy.new()
	enemy.max_health = int(metrics.get("enemy_health", 60))
	enemy.damage = int(metrics.get("enemy_damage", 9))
	enemy.move_speed = float(metrics.get("enemy_speed", 3.4))
	enemy.attack_interval_s = float(metrics.get("enemy_attack_interval_s", 1.1))
	enemy.attack_range_m = float(metrics.get("enemy_attack_range_m", 22.0))
	enemy.gravity = float(metrics.get("gravity", 22.0))
	enemy._health = enemy.max_health
	enemy._target = target
	enemy._spawner_entity = source
	enemy._build()
	return enemy


func _build() -> void:
	name = "SwcEnemy"
	collision_layer = SwcEntity.LAYER_ENEMY
	collision_mask = SwcEntity.LAYER_WORLD | SwcEntity.LAYER_PROP
	floor_max_angle = deg_to_rad(50.0)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	shape.shape = capsule
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.7
	_mesh.mesh = body
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.22, 0.22)
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = Color(0.5, 0.06, 0.06)
	material.emission_energy_multiplier = 0.35
	_mesh.material_override = material
	add_child(_mesh)

	_skin = Node3D.new()
	_skin.name = "Skin"
	add_child(_skin)

	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.12
	eye_mesh.height = 0.24
	eye.mesh = eye_mesh
	eye.position = Vector3(0.0, 0.45, -0.34)
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.9, 0.4)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.85, 0.3)
	eye_material.emission_energy_multiplier = 2.0
	eye.material_override = eye_material
	add_child(eye)
	_eye = eye


## Wear the character its spawner was skinned with.
##
## An enemy has no entry in the semantic scene - it does not exist until the
## spawner makes one - so it cannot have a binding of its own. Its spawner's
## binding is a *prototype* rather than a placement: the marker never renders, and
## every enemy it produces is dressed from it. This is the one place a package's
## presentation reaches something that was not in the scene file, and it still
## cannot touch a collider, a stat or a transform.
func wear(prototype: Node3D) -> void:
	if prototype == null or prototype.get_child_count() == 0:
		return
	for child in prototype.get_children():
		_skin.add_child(child.duplicate())
	# The capsule becomes the graybox, so F1 still strips every world back.
	_mesh.add_to_group(SwcViewModes.GROUP_GRAYBOX)
	_eye.add_to_group(SwcViewModes.GROUP_GRAYBOX)
	_skin.add_to_group(SwcViewModes.GROUP_PRESENTATION)

	# This enemy did not exist when the last sweep ran, so it starts wherever the
	# world currently is rather than fully dressed.
	var stripped := SwcViewModes.is_stripped(name, SwcViewModes.level)
	_mesh.visible = stripped
	_eye.visible = stripped
	_skin.visible = not stripped


func _process(delta: float) -> void:
	# A little idle motion, so a static mesh does not read as scenery. Purely
	# presentational: it moves the skin, never the body or its collider.
	if _skin == null or _skin.get_child_count() == 0:
		return
	_bob += delta
	_skin.position.y = sin(_bob * 2.4) * 0.035
	_skin.rotation.y = sin(_bob * 0.9) * 0.06


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	var distance := to_target.length()
	var flat := Vector3(to_target.x, 0.0, to_target.z)

	if not _alerted and distance <= attack_range_m and _has_line_of_sight():
		_alerted = true
		if _spawner_entity != null:
			_spawner_entity.play_sound("alert")

	if _alerted and flat.length() > 1.4:
		var direction := flat.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _alerted and distance <= 2.4 and _attack_cooldown <= 0.0:
		_target.apply_damage(damage)
		_attack_cooldown = attack_interval_s

	move_and_slide()


func _has_line_of_sight() -> bool:
	if _target == null:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.8,
		_target.global_position + Vector3.UP * 0.6,
		_RAY_MASK
	)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


func take_damage(amount: int) -> void:
	if _health <= 0:
		return
	_health -= amount
	_alerted = true
	if _mesh.material_override is StandardMaterial3D:
		var material := _mesh.material_override as StandardMaterial3D
		material.emission_energy_multiplier = 1.2
		get_tree().create_timer(0.08).timeout.connect(
			func() -> void:
				if is_instance_valid(self) and material != null:
					material.emission_energy_multiplier = 0.35
		)
	if _health <= 0:
		_die()


func _die() -> void:
	if _spawner_entity != null:
		_spawner_entity.play_sound("death")
	died.emit(self)
	queue_free()


func is_alive() -> bool:
	return _health > 0
