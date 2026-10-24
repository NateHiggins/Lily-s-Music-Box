extends PlayerController
## Test-only timing around the one authoritative target scan.
var prompt_costs: Array=[]
func _update_prompt() -> void:
	var start:=Time.get_ticks_usec()
	super._update_prompt()
	prompt_costs.append((Time.get_ticks_usec()-start)/1000.)
