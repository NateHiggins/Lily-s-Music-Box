class_name SwcWeapon
extends Node

## Hitscan weapon.
##
## Damage, rate of fire, range and spread come from gameplay_metrics. Its sound
## comes from the loaded World Package. Nothing about how it sounds can change how
## much it hurts.

signal fired(from: Vector3, to: Vector3, hit: bool)
signal ammo_changed(current: int)
signal dry_fire

const _HIT_MASK := (
	SwcEntity.LAYER_WORLD | SwcEntity.LAYER_ENEMY | SwcEntity.LAYER_PROP
)

var damage: int = 24
var rounds_per_minute: float = 420.0
var range_m: float = 60.0
var spread_deg: float = 1.2

var ammo: int = 90
var _cooldown: float = 0.0
var _shot_index: int = 0
var _muzzle: Node3D
var _owner_body: CollisionObject3D


func configure(metrics: Dictionary, muzzle: Node3D, owner_body: CollisionObject3D, start_ammo: int) -> void:
	damage = int(metrics.get("weapon_damage", 24))
	rounds_per_minute = maxf(1.0, float(metrics.get("weapon_rounds_per_minute", 420.0)))
	range_m = float(metrics.get("weapon_range_m", 60.0))
	spread_deg = float(metrics.get("weapon_spread_deg", 1.2))
	_muzzle = muzzle
	_owner_body = owner_body
	ammo = start_ammo
	ammo_changed.emit(ammo)


func add_ammo(amount: int) -> void:
	ammo += amount
	ammo_changed.emit(ammo)


func can_fire() -> bool:
	return _cooldown <= 0.0 and ammo > 0


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func try_fire() -> void:
	if _cooldown > 0.0:
		return
	if ammo <= 0:
		dry_fire.emit()
		_cooldown = 0.3
		return

	_cooldown = 60.0 / rounds_per_minute
	ammo -= 1
	ammo_changed.emit(ammo)

	var origin := _muzzle.global_position
	var direction := -_muzzle.global_transform.basis.z
	direction = _apply_spread(direction)
	var target := origin + direction * range_m

	var space := _muzzle.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, target, _HIT_MASK)
	if _owner_body != null:
		query.exclude = [_owner_body.get_rid()]
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		fired.emit(origin, target, false)
		return

	var collider: Object = hit.get("collider")
	_apply_hit(collider)
	fired.emit(origin, hit["position"], true)


func _apply_hit(collider: Object) -> void:
	if collider is SwcEnemy:
		(collider as SwcEnemy).take_damage(damage)
		return
	var entity := SwcEntity.owning_entity(collider as Node)
	if entity == null:
		return
	var breakable := entity.get_node_or_null("SwcBreakable") as SwcBreakable
	if breakable != null:
		breakable.take_damage(damage)
		return
	entity.play_sound("weapon_impact", -8.0)


func _apply_spread(direction: Vector3) -> Vector3:
	if spread_deg <= 0.0:
		return direction
	# Deterministic per shot rather than random: two runs of the same inputs
	# produce the same shots, which keeps the bot-path tests meaningful.
	_shot_index += 1
	var angle := float(_shot_index) * 2.399963
	var magnitude := deg_to_rad(spread_deg) * (0.35 + 0.65 * fmod(float(_shot_index) * 0.618, 1.0))
	var basis := _muzzle.global_transform.basis
	return (
		direction
		+ basis.x * sin(angle) * magnitude
		+ basis.y * cos(angle) * magnitude
	).normalized()
