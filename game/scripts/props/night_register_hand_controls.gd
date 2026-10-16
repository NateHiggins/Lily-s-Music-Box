extends RefCounted
var register: Node3D
var held := ""
var index_z := -.06
var lifts := {"slip":0.0,"apartment":0.0,"plant":0.0}
var parts: Dictionary = {}
var areas: Dictionary = {}
var rest: Dictionary = {}
var pen_tip := Vector3(.096,.016,.010)
var pen_distance := 0.0
var pen_signed := false
const DIRECTION := Vector3(0,.8,.6)
const TRAVEL := .065

func configure(owner: Node3D) -> void:
	register=owner
	parts={"index":register._slide,"slip":register._slip,"slip_return":register._stub,"pen":register._desk.get_node("RegisterPen")}
	for hook: String in register.HOOK_ORDER:
		parts[hook]=register._keys[hook][0]
		parts[hook+"_return"]=register._checks[hook][0]
		for node: Node3D in register._keys[hook]: rest[node]=node.position
	for key: String in parts:
		areas[key]=preload("res://scripts/props/manipulation_area.gd").install(parts[key],grip.bind(key))
	index_z=register.DETENT_Z[register.index_detent]
	refresh()

func grip(key: String) -> Dictionary:
	if key=="pen": return pen_grip()
	var base := key.trim_suffix("_return")
	if base=="slip" and not register.slip_available() and not register.slip_taken: return {}
	var moving: Node3D=parts[base]
	return {"owner":register,"part":moving,"frame":register._card if base=="index" else register,
		"kind":"slide","axis":Vector3.BACK if base=="index" else DIRECTION,
		"minimum":-.06 if base=="index" else 0.0,"maximum":.086 if base=="index" else TRAVEL,
		"read":func(): return index_z if base=="index" else lifts[base],
		"write":func(value: float): move(base,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held=base
			if key.ends_with("_return"): lifts[base]=TRAVEL
			refresh();return true,
		"owns":func(): return held==base,
		"end":func():
			held=""
			if base!="index" and is_out(base): lifts[base]=0.0
			refresh();register.manipulation_changed.emit()}

func is_out(key: String) -> bool:
	return register.slip_taken if key=="slip" else register.key_out(key)

func move(key: String,value: float) -> void:
	if held!=key or not is_finite(value): return
	if key=="index":
		index_z=clampf(value,-.06,.086)
		var selection := ""
		for i in range(1,register.DETENT_Z.size()):
			if absf(index_z-float(register.DETENT_Z[i]))<=.006: selection=register.OUTCOMES[i-1]
		register.select_outcome(selection)
	else:
		lifts[key]=clampf(value,0,TRAVEL)
		if lifts[key]>=TRAVEL-.001 and not is_out(key):
			if key=="slip": register.take_slip()
			else: register.take_key(key)
		elif lifts[key]<=.001 and is_out(key):
			var accepted: bool=register.replace_slip() if key=="slip" else register.return_key(key)
			if not accepted: lifts[key]=.012
	refresh()

func refresh() -> void:
	var pen: Node3D=parts.pen
	if held=="pen":
		var direction := Vector3(.20,.96,.18).normalized()
		pen.basis=Basis(Quaternion(Vector3.UP,direction))
		pen.position=pen_tip+direction*.0525
	else:
		# Lay the whole holder across the page, supported by its ferrule.
		# The writing point may reach the margins; the resting stock must not.
		pen.rotation=Vector3(0,0,PI/2)
		pen.position=Vector3(clampf(pen_tip.x,-.055,.055),.0176,clampf(pen_tip.z,-.058,.058))
	register._slide.position=Vector3(-.122,.004,index_z)
	for hook: String in register.HOOK_ORDER:
		var out: bool=register.key_out(hook)
		for node: Node3D in register._keys[hook]:
			node.position=rest[node]+DIRECTION*float(lifts[hook])
			node.rotation.z=0
			node.visible=not out or held==hook
		areas[hook].collision_layer=0 if out else 1
		areas[hook+"_return"].collision_layer=1 if out else 0
	var showing: bool=register.slip_available() or held=="slip"
	register._slip.position=Vector3(-.185,.250,.041)+DIRECTION*float(lifts.slip)
	register._slip.visible=showing
	areas.slip.collision_layer=1 if register.slip_available() else 0
	areas.slip_return.collision_layer=1 if register.slip_taken else 0
	var lettering: Array=[]
	lettering.append_array(register._slip_labels)
	for i in 2: lettering.append(register.get_node("SlipRule%d"%i))
	for node: Node3D in lettering:
		if not node.has_meta("physical_paper_rest"): node.set_meta("physical_paper_rest",node.position)
		node.position=node.get_meta("physical_paper_rest")+DIRECTION*float(lifts.slip)
		node.visible=showing

func pen_grip() -> Dictionary:
	return {"owner":register,"part":parts.pen,"frame":register._desk,"kind":"free",
		"read":func(): return pen_tip,
		"write":func(value: Vector3): write_pen(value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held="pen";pen_distance=0.0;pen_signed=false
			refresh();return true,
		"owns":func(): return held=="pen",
		"end":func(): held="";pen_distance=0.0;refresh();register.manipulation_changed.emit()}

func write_pen(value: Vector3) -> void:
	if held!="pen" or not value.is_finite(): return
	var next := Vector3(clampf(value.x,-.102,.102),.016,clampf(value.z,-.060,.060))
	if not pen_signed and register.ready_to_file():
		pen_distance+=Vector2(next.x-pen_tip.x,next.z-pen_tip.z).length()
	else: pen_distance=0.0
	pen_tip=next
	# Any ordinary short writing motion on the page counts. No pattern,
	# timing target, matching exercise or alternate filing authority.
	if pen_distance>=.035 and not pen_signed:
		pen_signed=register.sign_register()
		if pen_signed: index_z=register.DETENT_Z[register.index_detent]
	refresh()

func snapshot() -> Dictionary:
	var saved_lifts := lifts.duplicate()
	for key: String in saved_lifts:
		if is_out(key): saved_lifts[key]=0.0
	return {"slip_taken":register.slip_taken,"keys_out":register.keys_out.duplicate(),
		"round_open":register.round_open,"latched_job":register._latched_job,
		"index_z":index_z,"lifts":saved_lifts,"pen_tip":[pen_tip.x,pen_tip.z]}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=7: return false
	if value.get("slip_taken") is not bool or value.get("round_open") is not bool: return false
	if value.slip_taken and not value.round_open: return false
	if value.get("latched_job") is not String: return false
	if value.latched_job!="" and value.latched_job not in register.PRESENTABLE_JOBS: return false
	if value.round_open and value.latched_job=="": return false
	if value.get("keys_out") is not Dictionary or value.keys_out.size()!=2: return false
	for key: String in register.HOOK_ORDER:
		if value.keys_out.get(key) is not bool: return false
	if not finite_range(value.get("index_z"),-.06,.086): return false
	if value.get("lifts") is not Dictionary or value.lifts.size()!=3: return false
	for key: String in ["slip","apartment","plant"]:
		if not finite_range(value.lifts.get(key),0,TRAVEL): return false
		var out: bool=value.slip_taken if key=="slip" else value.keys_out[key]
		if out and value.lifts[key]!=0: return false
	if value.get("pen_tip") is not Array or value.pen_tip.size()!=2: return false
	return finite_range(value.pen_tip[0],-.102,.102) and finite_range(value.pen_tip[1],-.060,.060)

func finite_range(value: Variant,minimum: float,maximum: float) -> bool:
	return typeof(value) in [TYPE_FLOAT,TYPE_INT] and is_finite(float(value)) and value>=minimum and value<=maximum

func restore(value: Dictionary) -> void:
	if not valid(value): return
	held="";pen_distance=0.0;pen_signed=false
	register.slip_taken=value.slip_taken
	register.keys_out=value.keys_out.duplicate()
	register.round_open=value.round_open
	register._latched_job=value.latched_job
	index_z=value.index_z
	lifts=value.lifts.duplicate()
	pen_tip=Vector3(value.pen_tip[0],.016,value.pen_tip[1])
	register.index_detent=0
	for i in range(1,register.DETENT_Z.size()):
		if absf(index_z-float(register.DETENT_Z[i]))<=.006: register.index_detent=i
	# The original register record owns written lines. Never restore it from
	# a household position snapshot or replay acknowledge/sign callbacks.
	register.signed_lines=register._stored_lines().size()
	register._landing_left=0;register._balk_left=0
	register._refresh_board()
