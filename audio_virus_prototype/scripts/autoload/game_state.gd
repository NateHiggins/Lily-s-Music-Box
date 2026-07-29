extends Node
## Autoload "GameState": single source of truth for the run's state.
## Audio, dialogue, UI and environment all listen to these signals instead
## of referencing each other's scene nodes, so adding a new infected object
## means connecting to signals — not rewiring the scene.

signal stage_changed(stage: int)
signal isolation_changed(active: bool)
signal capture_changed(captured: bool)
signal route_changed(route: String)
signal infection_changed(room_level: float, caller_level: float)
signal outcome_committed(response: int)
signal run_reset

enum Stage { ORDINARY_CALL, ISOLATION, CAPTURE, TRANSMISSION, RESPONSE, OUTCOME }
enum Response { NONE, COMPLETE, INTERRUPT, SILENCE }

const ROUTE_NONE := "none"
const ROUTE_SPEAKERS := "speakers"
const ROUTE_HEADSET := "headset"
const ROUTE_ROOM := "room"

const STAGE_NAMES := ["ORDINARY_CALL", "ISOLATION", "CAPTURE", "TRANSMISSION", "RESPONSE", "OUTCOME"]
const RESPONSE_NAMES := ["NONE", "COMPLETE", "INTERRUPT", "SILENCE"]

var call_stage: int = Stage.ORDINARY_CALL
var is_noise_isolated := false
var motif_captured := false
var current_route := ROUTE_NONE
var radiator_infected := false
var computer_infected := false
var room_infection_level := 0.0
var caller_infection_level := 0.0
var player_response: int = Response.NONE
var motif_mutation := 0
var outcome_triggered := false


func set_stage(stage: int) -> void:
	if stage == call_stage:
		return
	call_stage = stage
	print("[STATE] stage -> %s" % STAGE_NAMES[stage])
	stage_changed.emit(stage)


func set_isolated(active: bool) -> void:
	if is_noise_isolated == active:
		return
	is_noise_isolated = active
	print("[STATE] noise isolated: %s" % active)
	isolation_changed.emit(active)


func set_captured(captured: bool) -> void:
	if motif_captured == captured:
		return
	motif_captured = captured
	print("[STATE] motif captured: %s" % captured)
	capture_changed.emit(captured)


func set_route(route: String) -> void:
	if current_route == route:
		return
	current_route = route
	print("[STATE] route -> %s" % route)
	route_changed.emit(route)


func set_room_infection(level: float) -> void:
	room_infection_level = clampf(level, 0.0, 1.0)
	infection_changed.emit(room_infection_level, caller_infection_level)


func set_caller_infection(level: float) -> void:
	caller_infection_level = clampf(level, 0.0, 1.0)
	infection_changed.emit(room_infection_level, caller_infection_level)


## Latch: only the first response commits an outcome, no matter how many
## motif instances or debug buttons try. Returns false if already decided.
func try_commit_outcome(response: int) -> bool:
	if outcome_triggered:
		print("[STATE] outcome already committed, ignoring %s" % RESPONSE_NAMES[response])
		return false
	outcome_triggered = true
	player_response = response
	print("[STATE] outcome -> %s" % RESPONSE_NAMES[response])
	set_stage(Stage.OUTCOME)
	outcome_committed.emit(response)
	return true


func reset() -> void:
	call_stage = Stage.ORDINARY_CALL
	is_noise_isolated = false
	motif_captured = false
	current_route = ROUTE_NONE
	radiator_infected = false
	computer_infected = false
	room_infection_level = 0.0
	caller_infection_level = 0.0
	player_response = Response.NONE
	motif_mutation = 0
	outcome_triggered = false
	print("[STATE] run reset")
	run_reset.emit()
	stage_changed.emit(call_stage)
	infection_changed.emit(0.0, 0.0)
