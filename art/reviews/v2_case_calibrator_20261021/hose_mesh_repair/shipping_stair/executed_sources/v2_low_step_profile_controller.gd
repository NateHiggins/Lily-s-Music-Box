extends PlayerController
## Diagnostic wrapper only; movement uses the shipping controller implementation.
var cost_phase:="startup"
var measured_ticks: Array=[]
var prompt_costs: Array=[]
func _physics_process(delta: float) -> void:
	var start:=Time.get_ticks_usec();var before: int=physics_profile_records.size()
	super._physics_process(delta)
	if profile_physics:
		var row: Dictionary={"phase":cost_phase,"total_ms":(Time.get_ticks_usec()-start)/1000.}
		if physics_profile_records.size()>before:row.merge(physics_profile_records.back())
		measured_ticks.append(row);physics_profile_records.clear()
func _update_prompt() -> void:
	var start:=Time.get_ticks_usec();super._update_prompt()
	if profile_physics:prompt_costs.append({"phase":cost_phase,"ms":(Time.get_ticks_usec()-start)/1000.})
