extends RefCounted
## Native parts retain their mesh owners. Travel is measured in metres/radians.
var tank: Node3D
var held := ""
var stop_angle := 0.0
var stable_seconds := 0.0
var parts: Dictionary = {}

func configure(owner: Node3D) -> void:
	tank=owner
	# Native dogleg and spindle terminate here, clear of the collector rim.
	tank._stop.position+=Vector3(.36,0,.125)
	for spoke: MeshInstance3D in tank._spokes: spoke.position+=Vector3(.36,0,.125)
	parts={"stop":tank._stop,"float":tank._float,"weight":tank._weight,"indicator":tank._telltale}
	for key: String in parts:
		preload("res://scripts/props/manipulation_area.gd").install(parts[key],grip.bind(key))
	refresh()

func grip(key: String) -> Dictionary:
	return {"owner":tank,"part":parts[key],"frame":tank,
		"kind":"hinge" if key=="stop" else "slide",
		"axis":Vector3.FORWARD if key=="stop" else (Vector3.RIGHT if key=="weight" else Vector3.UP),
		"minimum":0.0,"maximum":TAU*2 if key=="stop" else (.46 if key=="weight" else (.16 if key=="float" else 1.35)),
		"read":func(): return read(key),"write":func(value: float): move(key,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held=key
			return true,
		"owns":func(): return held==key,
		"end":func(): held="";tank.manipulation_changed.emit()}

func read(key: String) -> float:
	match key:
		"stop": return stop_angle
		"float": return tank.float_lift*.16
		"weight": return tank.weight_set*.46
	return tank.tell_tale*1.35

func move(key: String,value: float) -> void:
	if held!=key or not is_finite(value): return
	stable_seconds=0.0
	match key:
		"stop":
			# Clockwise seats the valve; a partial opening still supplies the tank.
			stop_angle=clampf(value,0,TAU*2)
			tank.riser_open=stop_angle<TAU*2-.01
		"float":
			if tank.riser_open:
				tank._balk(.8)
				return
			tank.float_lift=clampf(value/.16,0,1)
			if tank.float_lift>=.45 and tank.float_waterlogged:
				tank.float_waterlogged=false
				tank._pour_left=.9
		"weight":
			# The weight remains movable with a faulty float. The retained force
			# model, not an artificial step lock, makes that attempted bodge fail.
			tank.weight_set=clampf(value/.46,0,1)
		"indicator": tank.tell_tale=clampf(value/1.35,0,1)
	tank._refresh_mechanism()

func refresh() -> void:
	if tank.riser_open!=(stop_angle<TAU*2-.01): stop_angle=0 if tank.riser_open else TAU*2
	# Rotate about the shaft, preserving the native wheel's original X rotation.
	tank._stop.basis=Basis(Vector3.BACK,-stop_angle)*Basis(Vector3.RIGHT,PI/2)
	for i in tank._spokes.size(): tank._spokes[i].rotation.z=PI*float(i)/3-stop_angle
	# The captive weight follows the actual tilted lever, including its bore.
	tank._weight.position=tank._lever.position+tank._lever.basis*Vector3(-.22+.46*tank.weight_set,0,0)
	tank._weight.basis=tank._lever.basis

func tick(delta: float) -> void:
	if tank.ballcock_serviced: return
	if not held.is_empty() or not tank.riser_open or not tank.valve_holds() or tank.float_lift>.01:
		stable_seconds=0
		return
	stable_seconds+=delta
	if stable_seconds>=1.8:
		tank.apply_maintenance_result({"activity_id":"roof_tank_ballcock_service","quality":"good",
			"note":"drained float, set lever weight and observed the open supply holding",
			"mechanism_patch":{"ballcock_serviced":true}})

func snapshot() -> Dictionary:
	var state: Dictionary=tank.maintenance_snapshot()
	state["stop_angle"]=stop_angle
	return state

func valid(state: Variant) -> bool:
	if state is not Dictionary or state.size()!=7: return false
	for key: String in ["float_waterlogged","riser_open","ballcock_serviced"]:
		if state.get(key) is not bool: return false
	for key: String in ["weight_set","tell_tale","float_lift","stop_angle"]:
		if typeof(state.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(state[key])): return false
		if state[key]<0 or state[key]>(TAU*2 if key=="stop_angle" else 1.0): return false
	return state.riser_open==(state.stop_angle<TAU*2-.01)

func restore(state: Dictionary) -> void:
	if not valid(state): return
	held=""
	stable_seconds=0
	stop_angle=state.stop_angle
	tank.restore_maintenance_snapshot(state)
