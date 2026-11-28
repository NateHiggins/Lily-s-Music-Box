extends Node3D
## Coordinates the usual cast stations, single-file stage access and the song.
const Session := preload("res://scripts/characters/harukiya_show_session.gd")
const Walk := preload("res://scripts/characters/harukiya_show_walk.gd")
const ORDER := ["adela_voss", "stacy", "lily"]
const RETRY_SECONDS := 15.0
const APPROACH_TIMEOUT := 25.0
const AUDIENCE_DWELL := 1.25

enum Phase { IDLE, ARRIVING, SET, RETURNING }
var phase := Phase.IDLE
var cast_owner: Node3D
var _session: Node3D
var _motor: RefCounted
var _cast := {}
var _home := {}
var _returns := {}
var _queue: Array = []
var _moving := ""
var _held_day := ""
var _played_day := ""
var _wait := 0.0
var _audience_seconds := 0.0
var _walking_seconds := 0.0


func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE:
		if _audience_present():
			_audience_seconds = minf(_audience_seconds + delta, AUDIENCE_DWELL)
		else:
			_audience_seconds = 0.0
		_wait -= delta
		if _wait <= 0.0:
			_wait = .5
			var day := _evening()
			if not day.is_empty() and day != _played_day and _audience_seconds >= AUDIENCE_DWELL:
				_begin(day)
		return
	if phase != Phase.RETURNING and _evening() != _held_day:
		if phase == Phase.SET:
			_session.stop()
		else:
			_return()
	if _motor == null:
		return
	_walking_seconds += delta
	_motor.advance(delta)
	if _motor.arrived or not _cast[_moving].visible:
		_complete_leg()
	elif phase == Phase.ARRIVING and _walking_seconds > APPROACH_TIMEOUT:
		_return()


func busy() -> bool:
	return phase != Phase.IDLE


func _evening() -> String:
	var world: Node3D = cast_owner.world
	var clock: RefCounted = world.campaign_clock
	if clock == null:
		return ""
	var day: Dictionary = clock.day_info()
	if not day.get("civil_date_valid", false) or day.day not in ["fri", "sat"] or clock.minute_of_day() < 1140.0:
		return ""
	if not cast_owner.counter.on_shift() or not cast_owner.lily_is_here() or not cast_owner._adela_is_here() or not cast_owner._speaker.is_empty():
		return ""
	if PersonInventory.object_holder() != "lily" or PersonInventory.object_location() != "inventory":
		return ""
	return clock.datetime_string().get_slice("T", 0)


func _audience_present() -> bool:
	var player: Node3D = cast_owner.world.player
	if not is_instance_valid(player) or player.call_locked:
		return false
	var region: OrisonV2BarRegion = cast_owner.bar_region
	var aisle: Node3D = region.destination.get_node("Navigation/main_aisle_c")
	var offset := player.global_position - aisle.global_position
	return absf(offset.y) < 1.3 and Vector2(offset.x, offset.z).length() <= 10.0


func _begin(day: String) -> void:
	_cast = cast_owner.actors.duplicate()
	_cast.merge(cast_owner.performers)
	_session = Session.new()
	add_child(_session)
	if not _session.prepare(cast_owner.bar_region, _cast):
		_reset()
		return
	_session.finished.connect(_return)
	phase = Phase.ARRIVING
	_held_day = day
	for id: String in ORDER:
		_home[id] = _cast[id].global_transform
	_queue = ORDER.duplicate()
	_next()


func _next() -> void:
	if _queue.is_empty():
		if phase == Phase.RETURNING:
			_reset()
		elif _session.start():
			_played_day = _held_day
			phase = Phase.SET
		else:
			_return()
		return
	_moving = _queue.pop_front()
	var actor: Node3D = _cast[_moving]
	if not actor.visible:
		_complete_leg()
		return
	var points: PackedVector3Array = _session.route(_moving) if phase == Phase.ARRIVING else _returns[_moving]
	_motor = Walk.new()
	if not _motor.begin(actor, points):
		_motor = null
		if phase == Phase.ARRIVING:
			_return()
		else:
			_complete_leg()
		return
	_walking_seconds = 0.0


func _complete_leg() -> void:
	var actor: Node3D = _cast[_moving]
	if phase == Phase.ARRIVING and _motor != null:
		_returns[_moving] = _motor.retreat_to(_home[_moving].origin)
	elif phase == Phase.RETURNING and (not actor.visible or (_motor != null and _motor.arrived)):
		actor.global_transform = _home[_moving]
	_release_motor()
	_next()


func _return() -> void:
	if phase == Phase.ARRIVING and _motor != null:
		_returns[_moving] = _motor.retreat_to(_home[_moving].origin)
	_release_motor()
	phase = Phase.RETURNING
	_queue.clear()
	for id: String in ORDER:
		if _returns.has(id):
			_queue.push_front(id)
	_next()


func _release_motor() -> void:
	if _motor != null:
		_motor.release()
		_motor = null


func _reset() -> void:
	_release_motor()
	if is_instance_valid(_session):
		_session.reset()
		_session.queue_free()
		_session = null
	phase = Phase.IDLE
	_audience_seconds = 0.0
	_wait = RETRY_SECONDS
	_queue.clear()
	_returns.clear()
	_home.clear()


func shutdown() -> void:
	_reset()
	set_physics_process(false)
