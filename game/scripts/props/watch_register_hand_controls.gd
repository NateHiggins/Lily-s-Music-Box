extends RefCounted
var register: Node3D
var test_key: Node3D
var held := ""
var reset_angle := 0.0
var test_angle := 0.0
var reset_armed := true
var upstream_closed := true

func configure(owner: Node3D) -> void:
	register=owner
	upstream_closed=register.line_closed
	test_key=register.get_node("M05_TestKey")
	test_key.position=Vector3(-.025,.08,.115)
	var area := preload("res://scripts/props/manipulation_area.gd")
	area.install(register._lever,grip.bind("reset"))
	area.install(test_key,grip.bind("line"))
	refresh()

func grip(key: String) -> Dictionary:
	return {"owner":register,"part":register._lever if key=="reset" else test_key,"frame":register,
		"kind":"hinge","axis":Vector3.LEFT if key=="reset" else Vector3.FORWARD,
		"minimum":0.0,"maximum":.9 if key=="reset" else PI/2,
		"read":func(): return reset_angle if key=="reset" else test_angle,
		"write":func(value: float): move(key,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held=key;return true,
		"owns":func(): return held==key,
		"end":func(): held="";register.manipulation_changed.emit()}

func move(key: String,value: float) -> void:
	if held!=key or not is_finite(value): return
	if key=="reset":
		reset_angle=clampf(value,0,.9)
		if reset_angle<.1: reset_armed=true
		if reset_angle>=.89 and reset_armed:
			reset_armed=false
			register.reset_shutters()
	else:
		test_angle=clampf(value,0,PI/2)
		apply_circuit()
	register._refresh_register()

func set_upstream(closed: bool) -> void:
	upstream_closed=closed
	apply_circuit()
	register._refresh_register()

func apply_circuit() -> void:
	# The local test contact is in series with the upstream circuit. Neither
	# switch closure nor restored physical settings can repair a broken wire.
	register.line_closed=upstream_closed and test_angle<.35

func refresh() -> void:
	register._lever.rotation.x=-reset_angle
	test_key.rotation.z=-test_angle
	for number: int in register.dropped:
		var shutter: Node3D=register._shutters[number]
		shutter.position.y=lerpf(register.SHUTTER_DROP_Y,register.SHUTTER_REST_Y,reset_angle/.9)

func snapshot() -> Dictionary:
	return {"reset":reset_angle,"test":test_angle,"reset_armed":reset_armed}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=3 or value.get("reset_armed") is not bool: return false
	for key: String in ["reset","test"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])): return false
		if value[key]<0 or value[key]>(.9 if key=="reset" else PI/2): return false
	if value.reset>=.89 and value.reset_armed: return false
	if value.reset<.1 and not value.reset_armed: return false
	return true

func restore(value: Dictionary) -> void:
	if not valid(value): return
	held=""
	reset_angle=value.reset;test_angle=value.test;reset_armed=value.reset_armed
	apply_circuit()
	register._refresh_register()
