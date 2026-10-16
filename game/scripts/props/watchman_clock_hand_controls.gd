extends RefCounted
var detector: Node3D
var cover: Node3D
var held := ""
var cover_angle := 0.0
var stop_angle := 0.0
var key_angle := 0.0
var paper_lift := .018
var key_armed := true
var parts: Dictionary

func configure(owner: Node3D) -> void:
	detector=owner
	cover=Node3D.new();cover.name="DetectorCover"
	detector.add_child(cover);cover.position=Vector3(-.159,.20,.195)
	for node: Node3D in [detector._glass,detector.get_node("M03_DoorFrame")]: node.reparent(cover,true)
	parts={"cover":cover,"stop":detector._stop_lever,"key":detector._station_key,
		"datum":detector._dial,"seat":detector._spindle}
	for key: String in parts:
		preload("res://scripts/props/manipulation_area.gd").install(parts[key],grip.bind(key))
	refresh()

func grip(key: String) -> Dictionary:
	if key!="cover" and cover_angle<.9: return {}
	return {"owner":detector,"part":parts[key],"frame":detector,
		"kind":"slide" if key=="seat" else "hinge",
		"axis":Vector3.BACK if key=="seat" else (Vector3.DOWN if key=="cover" else Vector3.FORWARD),
		"minimum":0.0,"maximum":limit(key),
		"read":func(): return read(key),"write":func(value: float): move(key,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			if key!="cover" and cover_angle<.9: return false
			held=key;return true,
		"owns":func(): return held==key,
		"end":func(): held="";detector.manipulation_changed.emit()}

func limit(key: String) -> float:
	return {"cover":1.65,"stop":.62,"key":1.18,"datum":TAU,"seat":.026}[key]

func read(key: String) -> float:
	match key:
		"cover": return cover_angle
		"stop": return stop_angle
		"key": return key_angle
		"datum": return detector.datum*TAU
	return paper_lift

func move(key: String,value: float) -> void:
	if held!=key or not is_finite(value): return
	detector._native_drive.tick()
	value=clampf(value,0,limit(key))
	match key:
		"cover": cover_angle=value
		"stop":
			stop_angle=value
			detector.movement_running=stop_angle<.31
		"seat":
			if detector.movement_running: return
			paper_lift=value
			detector.dial_seated=paper_lift<=.002
			detector._native_drive.invalidate_proof()
		"datum":
			if detector.movement_running or not detector.dial_seated: return
			detector.datum=fposmod(value/TAU,1.0)
			detector._native_drive.spindle_turn=detector.datum
			detector.datum_set=detector.datum_error()<=detector.DATUM_TOLERANCE
			detector._native_drive.invalidate_proof()
		"key":
			key_angle=value
			if key_angle<.1: key_armed=true
			if key_angle>=1.17 and key_armed:
				key_armed=false
				if not detector._perform_ritual_action() and not detector._ritual_owns_clock():
					if detector._native_drive.punch() and not detector.detector_honest:
						detector.apply_maintenance_result({"activity_id":"watchman_detector_dial","quality":"good",
							"note":"seated and set paper; separate key punches record elapsed house time",
							"mechanism_patch":{"detector_honest":true}})
	detector._refresh_mechanism()

func refresh() -> void:
	cover.rotation.y=-cover_angle
	detector._stop_lever.rotation.z=-stop_angle
	detector._paper.position=Vector3(0,.22,.112+paper_lift)
	detector._paper.rotation.x=0
	detector._spindle.position.z=paper_lift
	detector._station_key.rotation.z=-key_angle
	detector._station_key.position=Vector3(-.125,.058,.128)
	detector._punch_head.position.z=detector.PUNCH_REST_Z-detector.PUNCH_TRAVEL*key_angle/1.18
	var cable := detector.get_node_or_null("M03_PunchCableWire") as Node3D
	if cable!=null:
		var travel: float=maxf(.0001,detector.PUNCH_TRAVEL*key_angle/1.18)
		cable.position=Vector3(0,.314,.183-travel*.5)
		cable.scale=Vector3(1,1,travel/.024)

func snapshot() -> Dictionary:
	return {"cover":cover_angle,"stop":stop_angle,"key":key_angle,"seat":paper_lift,"key_armed":key_armed}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=5 or value.get("key_armed") is not bool: return false
	for key: String in ["cover","stop","key","seat"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT]: return false
		if not is_finite(float(value[key])) or value[key]<0 or value[key]>limit(key): return false
	if value.key>=1.17 and value.key_armed: return false
	if value.key<.1 and not value.key_armed: return false
	return true

func restore(value: Dictionary) -> void:
	held=""
	if valid(value):
		cover_angle=value.cover;stop_angle=value.stop;key_angle=value.key;paper_lift=value.seat
	else:
		stop_angle=0 if detector.movement_running else .62
		paper_lift=0 if detector.dial_seated else .018
	key_armed=bool(value.key_armed) if valid(value) else key_angle<.1
	refresh()
