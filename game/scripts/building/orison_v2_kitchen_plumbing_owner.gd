extends Node3D
## Two packed service stops. Household mechanism snapshots persist positions.
signal manipulation_changed
var tap: TapProp
var record: Dictionary
var wheels: Array[Node3D]=[]
var openings:=Vector2.ONE
var held: int=-1
const TRAVEL=TAU*2.

func apply_pose() -> void:
	for index in wheels.size():wheels[index].rotation.z=-openings[index]*TRAVEL
	if is_instance_valid(tap):tap._update_flow()

func grip(index: int) -> Dictionary:
	if index not in [0,1] or wheels.size()!=2:return {}
	# The hand belongs to the whole retained fixture, as its upper valves do.
	# A moving contact may pass behind another part of the same sink without
	# losing the physical latch. This child still owns the saved stop fractions.
	return {"owner":tap,"part":wheels[index],"frame":self,"kind":"hinge","axis":Vector3.FORWARD,
		"minimum":0.,"maximum":TRAVEL,"minimum_lever":.001,"read":func():return openings[index]*TRAVEL,
		"write":func(angle: float):
			if held==index and is_finite(angle):openings[index]=clampf(angle/TRAVEL,0.,1.);apply_pose(),
		"owns":func():return held==index,
		"begin":func():
			if held!=-1 or tap._held_valve!=-1 or RealityState.save_write_blocked:return false
			held=index;return true,
		"end":func():held=-1;manipulation_changed.emit()}

func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(.32,.58,-.65)),"at":to_global(Vector3(0,.42,.20)),"fov":52.}

func mechanism_snapshot() -> Dictionary:
	return {"hot":openings.x,"cold":openings.y}

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2:return false
	for key: String in ["hot","cold"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])) or float(value[key])<0. or float(value[key])>1.:return false
	return true

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value):return
	held=-1;openings=Vector2(float(value.hot),float(value.cold));apply_pose()
