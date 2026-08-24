class_name MaintenanceActivityRun
extends RefCounted
## One transient performance of a maintenance activity.
##
## Inputs advance an authored sequence, but the proposed mechanism patch is
## withheld until the final step succeeds. Aborting therefore has no rollback
## problem and this object never needs authority over world or save state.

signal step_changed(index: int, step: Dictionary)
signal input_rejected(reason: String, step: Dictionary)
signal completed(result: Dictionary)
signal aborted(activity_id: String)

var activity_id := ""
var profile: Dictionary = {}
var step_index := 0
var attempts := 0
var misses := 0
var running := false
var committed := false
var result: Dictionary = {}

var precision_scale := 1.0
var hold_assist := 1.0
var _started_msec := 0


func start(id: String, authored: Dictionary,
		accessibility: Dictionary = {}) -> bool:
	if running or id.is_empty() or authored.is_empty():
		return false
	activity_id = id
	profile = authored.duplicate(true)
	step_index = 0
	attempts = 0
	misses = 0
	committed = false
	result.clear()
	precision_scale = clampf(float(accessibility.get(
			"precision_scale", 1.0)), 1.0, 4.0)
	hold_assist = clampf(float(accessibility.get("hold_assist", 1.0)), 1.0, 4.0)
	_started_msec = Time.get_ticks_msec()
	running = true
	step_changed.emit(step_index, current_step())
	return true


func current_step() -> Dictionary:
	var steps: Array = profile.get("steps", [])
	if not running or step_index < 0 or step_index >= steps.size():
		return {}
	return (steps[step_index] as Dictionary).duplicate(true)


func submit(verb: String, value: float, hold_seconds := 0.0) -> bool:
	if not running:
		return false
	attempts += 1
	var step := current_step()
	if verb != str(step.get("verb", "")):
		return _reject("wrong_verb", step)
	var tolerance := minf(0.5, float(step.get("tolerance", 0.05)) \
			* precision_scale)
	if absf(clampf(value, 0.0, 1.0) - float(step.get("target", 0.5))) \
			> tolerance:
		return _reject("outside_detent", step)
	if verb == "hold_release":
		var required := float(step.get("hold_min_seconds", 0.0)) / hold_assist
		if hold_seconds < required:
			return _reject("released_early", step)
	step_index += 1
	var steps: Array = profile.get("steps", [])
	if step_index < steps.size():
		step_changed.emit(step_index, current_step())
		return true
	_commit()
	return true


func abort() -> bool:
	if not running or committed:
		return false
	running = false
	result.clear()
	aborted.emit(activity_id)
	return true


func census() -> Dictionary:
	return {
		"activity_id": activity_id,
		"running": running,
		"committed": committed,
		"step_index": step_index,
		"step_count": (profile.get("steps", []) as Array).size(),
		"attempts": attempts,
		"misses": misses,
		"elapsed_seconds": _elapsed_seconds(),
	}


func _reject(reason: String, step: Dictionary) -> bool:
	misses += 1
	input_rejected.emit(reason, step.duplicate(true))
	return false


func _commit() -> void:
	running = false
	committed = true
	var quality := "good" if misses == 0 else ("fair" if misses <= 2 else "poor")
	var completion: Dictionary = profile.get("completion", {})
	result = {
		"activity_id": activity_id,
		"quality": quality,
		"note": str(completion.get("note", "")),
		"mechanism_patch": (completion.get("mechanism_patch", {}) \
				as Dictionary).duplicate(true),
		"attempts": attempts,
		"misses": misses,
		"elapsed_seconds": _elapsed_seconds(),
	}
	completed.emit(result.duplicate(true))


func _elapsed_seconds() -> float:
	if _started_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _started_msec) / 1000.0
