extends "res://scripts/props/radiator_prop.gd"
## Ordinary households share the existing apparatus and full-building heat
## model. The 2B union-packing situation has a separate production owner.

func bind_inventory(_custody_authority: MaintenanceInventory) -> void:
	inventory = null

func bind_heat_balance(model) -> void:
	if _balance != null and _balance.balance_changed.is_connected(_on_balance_changed):
		_balance.balance_changed.disconnect(_on_balance_changed)
	super.bind_heat_balance(model)
	if _balance != null:
		_balance.balance_changed.connect(_on_balance_changed)

func _on_balance_changed(_results: Dictionary) -> void:
	_apply_visual_state()

func _start_normal_function() -> void:
	super._start_normal_function()
	open_shift_condition = "steady"
	_apply_visual_state()

func _build_service_areas() -> void:
	var half_width := float(section_count - 1) * SECTION_PITCH * .5
	_service_area("listen", "Listen at radiator", Vector3(0,.46,-.12), Vector3(.38,.38,.16))
	_service_area("feel_temperature", "Feel section temperature", Vector3(.08,.48,-.12), Vector3(.42,.36,.14))
	_service_area("inspect_vent", "Inspect air vent", Vector3(half_width+.04,.62,-.06), Vector3(.17,.20,.20))
	_service_area("turn_valve", "Turn supply valve", Vector3(SUPPLY_X,.39,-.02), Vector3(.18,.18,.20))
	_service_area("service_vent", "Service air vent", Vector3(half_width+.04,.48,-.06), Vector3(.17,.10,.20))

func interact(_player: Node) -> void:
	perform_physical_action("listen")

func perform_physical_action(action_id: String) -> Dictionary:
	var result := {"action":action_id,"unit":unit}
	var heat := get_heat_state()
	match action_id:
		"turn_valve":
			set_supply_open(supply_position < .98)
			open_shift_condition = "steady" if supply_position >= .98 else "cooling"
			result.observation = "supply_open" if supply_position >= .98 else "supply_closed"
		"listen":
			result.observation = "riser_hammer" if bool(heat.get("hammer",false)) else "quiet_tick" if float(heat.get("heat",0)) > .05 else "quiet_pipe"
		"feel_temperature":
			result.observation = "warm_sections" if float(heat.get("heat",0)) > .05 else "cool_sections"
		"inspect_vent": result.observation = "vent_grade_%d" % vent_grade
		"service_vent":
			result.observation = "service_sequence_opened" if _begin_vent_service(get_tree().get_first_node_in_group("player_controller")) else "service_already_open"
		_: result.observation = "no_change"
	_apply_visual_state()
	physical_action.emit(action_id,result.duplicate(true))
	return result

func _apply_visual_state() -> void:
	super._apply_visual_state()
	if _section_multimesh == null or _balance == null: return
	var heat := get_heat_state()
	var warmth := clampf(float(heat.get("heat",0)) / maxf(.01,float(heat.get("target",.62))),0,1)
	_section_heat.clear()
	for i in section_count:
		var normalized := float(i) / maxf(1,float(section_count-1))
		var fill := warmth * (.72-normalized*.08)
		_section_heat.append(fill)
		_section_multimesh.multimesh.set_instance_color(i,Color(.30,.32,.34).lerp(Color(.93,.48,.23),fill)*( .91+.025*float((i*3)%4)))

func _exit_tree() -> void:
	if _balance != null and _balance.balance_changed.is_connected(_on_balance_changed):
		_balance.balance_changed.disconnect(_on_balance_changed)
	_balance = null
	if is_instance_valid(_service_panel):
		var panel := _service_panel
		_service_panel = null
		# Close through the panel's owner path so it also releases input.
		# During parent teardown the old player may already have retired.
		if not is_instance_valid(panel.get("_player")): panel.set("_player",null)
		panel.call("_close",false)
	super._exit_tree()
