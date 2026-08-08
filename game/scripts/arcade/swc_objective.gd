class_name SwcObjective
extends Node

## The level objective: hold the interact key for a scene-defined duration.

signal progressed(fraction: float)
signal completed(objective_id: String)

var entity: SwcEntity
var objective_id: String = "objective"
var interact_time_s: float = 2.5

var _progress: float = 0.0
var _done: bool = false
var _held_this_frame: bool = false


func configure(owner_entity: SwcEntity) -> void:
	entity = owner_entity
	objective_id = String(owner_entity.param("objective_id", "objective"))
	interact_time_s = maxf(0.1, float(owner_entity.param("interact_time_s", 2.5)))


func hold(delta: float) -> void:
	if _done:
		return
	_held_this_frame = true
	_progress = minf(1.0, _progress + delta / interact_time_s)
	progressed.emit(_progress)
	if _progress >= 1.0:
		_done = true
		entity.play_sound("complete")
		completed.emit(objective_id)


func prompt() -> String:
	if _done:
		return "Complete"
	return "Hold to activate  %d%%" % int(_progress * 100.0)


func is_complete() -> bool:
	return _done


func progress() -> float:
	return _progress


func _process(delta: float) -> void:
	# Releasing the key bleeds progress back, so the hold has to be committed to.
	if not _held_this_frame and not _done and _progress > 0.0:
		_progress = maxf(0.0, _progress - delta / (interact_time_s * 1.5))
		progressed.emit(_progress)
	_held_this_frame = false
