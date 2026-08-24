class_name MaintenanceActivityDirector
extends Node
## Presentation router for one short maintenance activity at a time.
##
## The director never applies the returned patch. A physical mechanism owns
## that mutation; WorkOrders separately decides whether a result is legal for
## a job. Keeping this node ignorant of both is the ownership seam.

signal activity_started(activity_id: String, step: Dictionary)
signal step_changed(activity_id: String, index: int, step: Dictionary)
signal input_rejected(activity_id: String, reason: String, step: Dictionary)
signal activity_completed(activity_id: String, result: Dictionary)
signal activity_aborted(activity_id: String)

var library: MaintenanceActivityLibrary
var active_run: MaintenanceActivityRun


func _ready() -> void:
	if library == null:
		library = MaintenanceActivityLibrary.load_default()


func bind_library(value: MaintenanceActivityLibrary) -> void:
	library = value


func begin(activity_id: String, accessibility: Dictionary = {}) -> bool:
	if active_run != null or library == null or not library.is_valid() \
			or not library.has_activity(activity_id):
		return false
	var run := MaintenanceActivityRun.new()
	run.step_changed.connect(_on_step_changed.bind(activity_id))
	run.input_rejected.connect(_on_input_rejected.bind(activity_id))
	run.completed.connect(_on_completed.bind(activity_id))
	run.aborted.connect(_on_aborted)
	active_run = run
	if not run.start(activity_id, library.activity(activity_id), accessibility):
		active_run = null
		return false
	activity_started.emit(activity_id, run.current_step())
	return true


func submit(verb: String, value: float, hold_seconds := 0.0) -> bool:
	return active_run != null and active_run.submit(verb, value, hold_seconds)


func abort() -> bool:
	return active_run != null and active_run.abort()


func census() -> Dictionary:
	return {} if active_run == null else active_run.census()


func _on_step_changed(index: int, step: Dictionary, activity_id: String) -> void:
	# start() emits before begin() publishes activity_started. Suppress that
	# duplicate; later changes are the actual step-to-step presentation seam.
	if index > 0:
		step_changed.emit(activity_id, index, step)


func _on_input_rejected(reason: String, step: Dictionary,
		activity_id: String) -> void:
	input_rejected.emit(activity_id, reason, step)


func _on_completed(result: Dictionary, activity_id: String) -> void:
	activity_completed.emit(activity_id, result)
	active_run = null


func _on_aborted(activity_id: String) -> void:
	activity_aborted.emit(activity_id)
	active_run = null
