extends WatchStationProp
## Native signal box; the original station and network retain record authority.
const STOCK := preload("res://assets/props/watch_stations.glb")
static var _stock: Dictionary = {}
signal manipulation_changed
var native_parts := 0
var door_angle := 0.0
var crank_angle := 0.0
var held_part := ""
var _hand_ready := false
func _build_visual() -> void:
	super()
	if _stock.is_empty():
		var source := STOCK.instantiate()
		for draw: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):_stock[str(draw.name)]=draw.mesh
		source.free()
	for draw: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var label := str(draw.name)
		if label.begins_with("WheelTooth"):label="WheelTooth"
		if _stock.has(label):draw.mesh=_stock[label];native_parts+=1
		elif label.begins_with("CaseCheek") or label=="ConduitElbow":draw.mesh=null
		elif draw.mesh is BoxMesh and draw.mesh.size.is_equal_approx(Vector3(.240,.020,.120)):draw.mesh=null
	# The original raised flag projects through the right cheek. Move its visual
	# pivot 38 mm inward; signal rotation/state and record authority are unchanged.
	_drop.position.x=.020
	_door.get_node("StationLegend").position.z+=.014
	for i in 3:
		var hinge := MeshInstance3D.new();hinge.name="NativeHinge%d" % i;hinge.mesh=_stock.HingeBarrel
		hinge.position=Vector3(0,-.10+i*.10,0);hinge.material_override=MatLib.get_mat("brass_dull")
		_door.add_child(hinge)
	set_meta("v2_native_watch_station",true)

func _ready() -> void:
	super()
	get_node("StationReach").collision_layer=0
	var area := preload("res://scripts/props/manipulation_area.gd")
	area.install(_door, _physical_grip.bind("door"))
	area.install(_crank, _physical_grip.bind("crank"))
	_hand_ready=true
	_refresh_station()

func _physical_grip(key: String) -> Dictionary:
	if key=="crank" and door_angle<.85: return {}
	return {"owner":self,"part":_door if key=="door" else _crank,"frame":self,
		"kind":"hinge","axis":Vector3.DOWN if key=="door" else Vector3.FORWARD,
		"minimum":0.0,"maximum":1.65 if key=="door" else TAU,
		"read":func(): return door_angle if key=="door" else crank_angle,
		"write":func(value: float): _move_part(key,value),
		"begin":func():
			if not held_part.is_empty() or RealityState.save_write_blocked: return false
			if key=="crank" and door_angle<.85: return false
			held_part=key
			return true,
		"owns":func(): return held_part==key,
		"end":func(): held_part="";manipulation_changed.emit()}

func _move_part(key: String,value: float) -> void:
	if held_part!=key or not is_finite(value): return
	if key=="door":
		door_angle=clampf(value,0,1.65)
		door_open=door_angle>=.85
	else:
		if drop_fallen: return
		# A missing tour key cannot engage the coded wheel. The original
		# guarded operation remains the sole source of records and signals.
		if not tour_key_available():
			_balk(.4,"socket")
			return
		crank_angle=clampf(value,0,TAU)
		if crank_angle>=TAU-.001: turn_crank()
	_refresh_station()

func _refresh_station() -> void:
	super()
	if not _hand_ready: return
	_door.rotation.y=-door_angle
	_crank.rotation.z=-crank_angle

# Existing scripted authority calls remain available, while player clicks
# cannot enter the inherited open/mark/close cycle.
func interact_control(_control_id: String,_player: Node) -> bool:
	return false

func control_grip(_control_id: String,_area: Node) -> Dictionary:
	return {}

func open_door() -> bool:
	if door_open: return super()
	door_angle=1.65
	return super()

func close_door() -> bool:
	if not door_open: return super()
	door_angle=0
	return super()

func reset_station() -> bool:
	crank_angle=0
	return super()

func inspection_view() -> Dictionary:
	return {"from":to_global(Vector3(.10,.22,.72)),"at":to_global(Vector3(0,.16,.07)),"fov":65.0}

# Persist physical positions only. The station/network retain their original
# session-only marks; restoring a handle must never publish a second mark.
func mechanism_snapshot() -> Dictionary:
	return {"door_angle":door_angle,"crank_angle":crank_angle}

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2: return false
	for key: String in ["door_angle","crank_angle"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT]: return false
		if not is_finite(float(value[key])) or value[key]<0: return false
		if value[key]>(1.65 if key=="door_angle" else TAU): return false
	return true

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	held_part=""
	door_angle=value.door_angle
	# A completed stroke is home again on a new session, whose record owner
	# deliberately starts a new round. Partial winding retains its position.
	crank_angle=0.0 if value.crank_angle>=TAU-.001 and not drop_fallen else value.crank_angle
	door_open=door_angle>=.85
	_refresh_station()

func maintenance_snapshot() -> Dictionary:
	var value := super()
	value["physical_controls"]=mechanism_snapshot()
	return value

func restore_maintenance_snapshot(value: Dictionary) -> void:
	held_part=""
	super(value)
	var physical: Variant=value.get("physical_controls")
	if valid_mechanism(physical): restore_mechanism(physical)
	else:
		door_angle=1.65 if door_open else 0.0
		crank_angle=TAU if drop_fallen else 0.0
		_refresh_station()
