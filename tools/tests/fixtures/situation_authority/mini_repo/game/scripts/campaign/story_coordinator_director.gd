extends Node
## Synthetic coordinator exercising the violation lanes.  This file is an
## autonomous situation coordinator (the word autonomous is the claim).

const WAIT_MINUTES := 12.0

var situation
var radiator
var player_in_range := false


func fabricate_knowledge() -> void:
	situation.record_fact("npc_knowledge", {"neighbor": "heard_hammer"})


func timer_applies_consequence(elapsed: float) -> void:
	if elapsed >= WAIT_MINUTES:
		radiator.apply_open_shift_condition("porter_temporary_shutoff")
		situation.begin_compensation("porter")


func timer_schedules_only(elapsed: float) -> void:
	if elapsed >= WAIT_MINUTES:
		autonomous_event.emit("porter_dispatched", {})


func foreign_job_write() -> void:
	RealityState.data.work_orders.status = "closed"


func foreign_mechanism_write() -> void:
	radiator.heat_level = 0.0


func delegated_mechanism_call() -> void:
	radiator.apply_condition("worsening_hammer")


func string_custody() -> void:
	situation.part_custody = "player_has_widget"


func stamp_host_clock() -> void:
	situation.issued_at = Time.get_unix_time_from_system()
	RealityState.commit()


func measure_perf() -> void:
	var t0 := Time.get_ticks_msec()
	print("perf ms ", Time.get_ticks_msec() - t0)


func dynamic_meddle(target: Node) -> void:
	target.call("record_fact")


func _process(_delta: float) -> void:
	if player_in_range:
		situation.advance_simulation_minutes(0.05)
		RealityState.commit()
