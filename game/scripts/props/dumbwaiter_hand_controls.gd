extends RefCounted
## Physical load path: common shaft, counterweight, holding pawl and band brake.
var lift: Node3D
var held := ""
var brake_angle := 0.0
var pawl_angle := 0.0
var stable_seconds := 0.0
var grips: Array[MeshInstance3D] = []
var brake: MeshInstance3D
var pawl_pivot: Node3D
const TRAVEL := .17
const TURNS := TAU*3
const PAWL_HOME := Vector3(.37,.82,.39)
# At .10 radians the nose clears the .097 m tooth envelope.
const PAWL_CLEAR := .10

func configure(owner: Node3D) -> void:
	lift=owner
	brake=lift.get_node("M09_BrakeWheel")
	var left := lift.get_node("M09_HandGrip") as MeshInstance3D
	grips.append(left)
	var right := MeshInstance3D.new()
	right.name="HandGripRight";right.mesh=left.mesh
	lift.add_child(right);grips.append(right)
	pawl_pivot=Node3D.new();pawl_pivot.name="PawlHinge"
	pawl_pivot.position=PAWL_HOME;lift.add_child(pawl_pivot)
	brake_angle=lift.brake_bite*TURNS;pawl_angle=lift.pawl_lift*1.15
	refresh()
	for i in 2: preload("res://scripts/props/manipulation_area.gd").install(grips[i],grip.bind("left" if i==0 else "right"))
	preload("res://scripts/props/manipulation_area.gd").install(brake,grip.bind("brake"))
	preload("res://scripts/props/manipulation_area.gd").install(lift._pawl,grip.bind("pawl"))

func grip(key: String) -> Dictionary:
	var rope := key in ["left","right"]
	return {"owner":lift,"part":grips[0 if key=="left" else 1] if rope else (brake if key=="brake" else pawl_pivot),
		"frame":lift,"kind":"slide" if rope else "hinge",
		"axis":Vector3.UP if key=="left" else (Vector3.DOWN if key in ["right","brake"] else Vector3.BACK),
		"minimum":0.0,"maximum":TRAVEL if rope else (TURNS if key=="brake" else 1.15),
		"read":func(): return lift.car_travel*TRAVEL if rope else (brake_angle if key=="brake" else pawl_angle),
		"write":func(value: float): move(key,value),
		"begin":func():
			if not held.is_empty() or RealityState.save_write_blocked: return false
			held=key
			lift.rope_strain=1.0 if rope else 0.0
			return true,
		"owns":func(): return held==key,
		"end":func(): held="";lift.rope_strain=0.0;lift._refresh_mechanism();lift.manipulation_changed.emit()}

func move(key: String,value: float) -> void:
	if held!=key or not is_finite(value): return
	stable_seconds=0.0
	match key:
		"left","right":
			var next := clampf(value/TRAVEL,0,1)
			# The pawl allows lifting, but its tooth blocks descent until lifted.
			if lift.brake_bite>=lift.BAND_HOME or (next<lift.car_travel and pawl_angle<PAWL_CLEAR):
				lift._slip(.3)
				return
			lift.car_travel=next
		"brake":
			brake_angle=clampf(value,0,TURNS)
			lift.brake_bite=brake_angle/TURNS
		"pawl":
			pawl_angle=clampf(value,0,1.15)
			lift.pawl_lift=pawl_angle/1.15
	lift._refresh_mechanism()

func refresh() -> void:
	brake_angle=lift.brake_bite*TURNS;pawl_angle=lift.pawl_lift*1.15
	var travel: float=lift.car_travel*TRAVEL
	# The shaft has no gearing: pulling the right fall down raises the car.
	lift._sheave.basis=Basis(Vector3.BACK,-travel/.099)*Basis(Vector3.RIGHT,PI/2)
	lift._drum.basis=lift._sheave.basis
	lift._car.position.y=.13+travel
	lift._counterweight.position.y=.44-travel
	lift._rope.transform=Transform3D(Basis.IDENTITY,Vector3(-.17,.40,.375))
	for i in 2: grips[i].position=Vector3(-.269 if i==0 else -.071,.35+(travel if i==0 else -travel),.375)
	brake.transform=Transform3D(Basis(Vector3.DOWN,brake_angle),Vector3(.27,1.055-.0042*lift.brake_bite,.375))
	var radius: float=1.0+.03*(1.0-lift.brake_bite)
	lift._band.transform=Transform3D(Basis(Vector3.RIGHT,PI/2)*Basis.from_scale(Vector3(radius,1,radius)),Vector3(.17,.89,.375))
	var cam: float=.13*maxf(0,sin(travel/.099*24))*maxf(0,1-pawl_angle/PAWL_CLEAR) if held in ["left","right"] else 0.0
	pawl_pivot.basis=Basis(Vector3.BACK,pawl_angle+cam)
	lift._pawl.transform=Transform3D(pawl_pivot.basis,PAWL_HOME-pawl_pivot.basis*PAWL_HOME)*Transform3D(Basis.IDENTITY,Vector3(.31,.82,.39))

func tick(delta: float) -> void:
	var supported: bool=held in ["left","right"] or pawl_angle<PAWL_CLEAR or lift.brake_bite>=lift.BAND_HOME
	if not supported and lift.car_travel>0:
		lift.car_travel=maxf(0,lift.car_travel-delta*.32*(1.0-lift.brake_bite/lift.BAND_HOME))
		lift._refresh_mechanism()
		if is_zero_approx(lift.car_travel): lift.manipulation_changed.emit()
	if not held.is_empty() or lift.car_travel<.25 or pawl_angle<PAWL_CLEAR or lift.brake_bite<lift.BAND_HOME:
		stable_seconds=0
		return
	stable_seconds+=delta
	if stable_seconds>=1.8 and not lift.band_seated:
		lift.apply_maintenance_result({"activity_id":"dumbwaiter_brake_service","quality":"good",
			"note":"band tension holds the raised car with pawl clear and hand rope released",
			"mechanism_patch":{"band_seated":true}})
		lift.manipulation_changed.emit()

func snapshot() -> Dictionary:
	return lift.maintenance_snapshot()

func valid(state: Variant) -> bool:
	if state is not Dictionary or state.size()!=5 or state.get("band_seated") is not bool: return false
	for key: String in ["brake_bite","pawl_lift","rope_strain","car_travel"]:
		if typeof(state.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(state[key])) or state[key]<0 or state[key]>1: return false
	return true

func restore(state: Dictionary) -> void:
	if not valid(state): return
	held="";stable_seconds=0
	lift.restore_maintenance_snapshot(state)
	# A saved hand is not an invisible person holding the rope after load.
	lift.rope_strain=0
