class_name SwcEnemySpawner
extends Node

## Proximity-activated enemy spawner.
##
## Wave number, count, activation radius and interval all come from the entity's
## gameplay_params, so encounter timing is identical in every compiled world. That
## is one of the invariants tests/test_gameplay_invariance.py asserts.

signal spawned(enemy: SwcEnemy)
signal exhausted(semantic_id: String)

var entity: SwcEntity
var wave: int = 1
var count: int = 1
var activation_radius_m: float = 16.0
var spawn_interval_s: float = 2.0

var _spawned: int = 0
var _timer: float = 0.0
var _active: bool = false
var _finished: bool = false
var _metrics: Dictionary = {}
var _player: SwcPlayer = null
var _container: Node3D = null
var _wave_enabled: bool = false


func configure(owner_entity: SwcEntity) -> void:
	entity = owner_entity
	wave = int(owner_entity.param("wave", 1))
	count = int(owner_entity.param("count", 1))
	activation_radius_m = float(owner_entity.param("activation_radius_m", 16.0))
	spawn_interval_s = maxf(0.1, float(owner_entity.param("spawn_interval_s", 2.0)))


func begin(player: SwcPlayer, container: Node3D, metrics: Dictionary) -> void:
	_player = player
	_container = container
	_metrics = metrics


func enable_wave(current_wave: int) -> void:
	_wave_enabled = current_wave >= wave


func remaining() -> int:
	return max(0, count - _spawned)


func _process(delta: float) -> void:
	if _finished or not _wave_enabled or _player == null or not _player.is_alive():
		return

	if not _active:
		if entity.global_position.distance_to(_player.global_position) > activation_radius_m:
			return
		_active = true
		_timer = 0.0

	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval_s
	_spawn_one()


func _spawn_one() -> void:
	if _spawned >= count:
		_finished = true
		exhausted.emit(entity.semantic_id)
		return
	_spawned += 1
	var enemy := SwcEnemy.create(_metrics, _player, entity)
	_container.add_child(enemy)
	enemy.wear(entity.presentation_anchor)
	# Nudged clear of the spawn marker so two enemies never appear interpenetrating.
	var jitter := Vector3(
		0.6 * (float(_spawned % 3) - 1.0), 0.0, 0.6 * (float(_spawned % 2) * 2.0 - 1.0)
	)
	enemy.global_position = entity.global_position + jitter
	spawned.emit(enemy)


## Immediate spawn, ignoring proximity and the wave gate. Used by screenshot
## capture and by headless checks; never by play.
func spawn_now() -> void:
	if _player == null or _container == null:
		return
	_spawn_one()


func reset() -> void:
	_spawned = 0
	_timer = 0.0
	_active = false
	_finished = false
	_wave_enabled = false
