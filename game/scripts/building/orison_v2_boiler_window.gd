extends Node3D
## Manual architectural control. HouseholdState owns its durable boolean.
signal open_state_changed(open: bool)
const MODEL := preload("res://assets/props/boiler_window.glb")
const MAXIMUM_ANGLE := 35.0
const STAY_LENGTH := .27
var opened := false
var moving := false
var angle_degrees := 0.0
var latch_fraction := 0.0
var model: Node3D
var sash: Node3D
var latch: Node3D
var _phase := 0.0
var _hand_part: Node3D
var _sweep_shape := BoxShape3D.new()
var _actor: WeakRef

var _handle: PropControlArea


static func mount(root: Node3D, record: Dictionary) -> Node3D:
	var opening: Node3D=root.get_node(str(record.id))
	var window:=load("res://scripts/building/orison_v2_boiler_window.gd").new() as Node3D
	window.name="OperatingWindow"
	var span: Vector2=root.window_reveal_span(record)
	assert(absf(span.x-15.58)<.00001 and absf(span.y-15.93)<.00001,"Boiler window needs a rebuilt source reveal")
	window.position=Vector3((span.x+span.y)*.5-float(record.center[0]),float(record.sill)+float(record.height)*.5,0)
	window.rotation.y=PI*.5
	opening.add_child(window)
	for identity: String in ["Glazing","JambA","JambB"]:opening.get_node(identity).hide()
	return window

func _ready() -> void:
	model=MODEL.instantiate();model.name="Fabrication";add_child(model)
	sash=model.get_node("Sash");latch=sash.get_node("Latch")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key: String=draw.mesh.surface_get_material(0).resource_name
		draw.set_meta("material_key",key)
		var root: Node3D=get_parent().get_parent()
		draw.material_override=root.architectural_materials.material_for("Glazing","service") if key=="glass" else MatLib.get_mat(key)
		var body:=StaticBody3D.new();body.name="FittedCollision"
		var shape:=CollisionShape3D.new();shape.name="Surface";shape.shape=draw.mesh.create_trimesh_shape()
		body.add_child(shape);draw.add_child(body)
	# The hand target follows the cam through the sash movement. A room-side
	# handle gives no external well/grate prompt.
	var reach:=PropControlArea.new();reach.configure("hopper");reach.name="HandleReach";_handle=reach
	var hit_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.10,.12,.065)
	hit_shape.shape=box;hit_shape.position=Vector3(0,.025,-.023);reach.add_child(hit_shape);add_child(reach)
	_sweep_shape.size=Vector3(1.092,.918,.076)
	_apply_pose();set_physics_process(false)

func control_prompt(id: String) -> String:
	if id!="hopper":return ""
	return "" if moving or RealityState.save_write_blocked else "Close boiler window" if opened else "Open boiler window"

func interact_control(id: String,actor: Node = null) -> Dictionary:
	return interact_handle(actor) if id=="hopper" else {}

func interact_handle(actor: Node = null) -> Dictionary:
	if moving or _hand_part != null or RealityState.save_write_blocked:return {}
	var target: float=0.0 if opened else MAXIMUM_ANGLE
	if actor is CollisionObject3D:
		for i in 36:
			if _occupies_sweep(actor,lerpf(angle_degrees,target,float(i)/35.0)):return {}
		_actor=weakref(actor)
	opened=not opened;moving=true;_phase=0.0;set_physics_process(true)
	open_state_changed.emit(opened)
	return {"action":"boiler_window","open":opened}

func _occupies_sweep(actor: CollisionObject3D, angle: float) -> bool:
	var pose:=Transform3D(Basis(Vector3.RIGHT,-deg_to_rad(angle)),Vector3(0,-.44,-.13))
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=_sweep_shape;query.margin=0.0
	query.transform=global_transform*pose*Transform3D(Basis.IDENTITY,Vector3(0,.44,-.008))
	query.collision_mask=actor.collision_layer
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,128):
		if hit.collider==actor:return true
	return false

func _physics_process(delta: float) -> void:
	var next:=minf(_phase+delta,1.0)
	var value:=clampf((next-.18)/.70,0.0,1.0) if opened else clampf(next/.70,0.0,1.0)
	var eased:=value*value*(3.0-2.0*value)
	var angle: float=eased*MAXIMUM_ANGLE if opened else (1.0-eased)*MAXIMUM_ANGLE
	var actor: Node=_actor.get_ref() if _actor!=null else null
	if actor is CollisionObject3D and _occupies_sweep(actor,angle):return
	_phase=next;angle_degrees=angle
	latch_fraction=clampf(next/.18,0.0,1.0) if opened else 1.0-clampf((next-.70)/.18,0.0,1.0)
	_apply_pose()
	if next>=1.0:moving=false;_actor=null;set_physics_process(false)

func _apply_pose() -> void:
	sash.rotation.x=-deg_to_rad(angle_degrees);latch.rotation.z=latch_fraction*PI*.5
	for side: float in [-1.,1.]:
		var a:=Vector3(side*.555,-.37,-.168)
		var end:=sash.transform*Vector3(side*.555,.55,0)
		var delta:=end-a;var length: float=STAY_LENGTH
		var perpendicular:=Vector3(0,delta.z,-delta.y).normalized()
		var elbow: Vector3=(a+end)*.5+perpendicular*sqrt(maxf(0.0,length*length-delta.length_squared()*.25))
		var prefix: String="StayLeft" if side<0 else "StayRight"
		for link: Array in [["A",a,elbow],["B",elbow,end]]:
			var direction: Vector3=(link[2]-link[1]).normalized()
			model.get_node(prefix+str(link[0])).transform=Transform3D(Basis(Vector3.RIGHT,direction,Vector3.RIGHT.cross(direction)),link[1])

	_handle.transform=model.transform*sash.transform*latch.transform

func restore_open_state(value: bool) -> void:
	opened=value;moving=false;_actor=null;_hand_part=null;set_physics_process(false)
	angle_degrees=MAXIMUM_ANGLE if value else 0.0
	latch_fraction=1.0 if value else 0.0
	_apply_pose()


func control_grip(id: String, _area: Area3D) -> Dictionary:
	return _window_grip(latch) if id=="hopper" else {}

func manipulation_target(hit: Dictionary) -> Dictionary:
	if latch.is_ancestor_of(hit.collider): return _window_grip(latch)
	if sash.is_ancestor_of(hit.collider): return _window_grip(sash)
	return {}

func _window_grip(part: Node3D) -> Dictionary:
	var cam := part==latch
	return {"owner":self,"part":part,"frame":sash if cam else self,"kind":"hinge",
		"axis":Vector3.BACK if cam else Vector3.LEFT,"minimum":0.0,
		"maximum":PI*.5 if cam else deg_to_rad(MAXIMUM_ANGLE),
		"read":func(): return latch_fraction*PI*.5 if cam else deg_to_rad(angle_degrees),
		"write":func(value: float):
			if _hand_part != part: return
			if cam:
				# The keeper cannot accept the cam while the sash is away.
				if angle_degrees>.5 and value<PI*.4: return
				latch_fraction=value/(PI*.5)
			else:
				if latch_fraction<.8: return
				var next := rad_to_deg(value)
				var steps := maxi(1,ceili(absf(next-angle_degrees)))
				var start := angle_degrees
				for step in range(1,steps+1):
					var candidate := lerpf(start,next,float(step)/steps)
					if not _hand_sash_clear(candidate): break
					angle_degrees=candidate
				opened=angle_degrees>.5
			_apply_pose(),
		"owns":func(): return _hand_part == part,
		"begin":func():
			if _hand_part != null or RealityState.save_write_blocked: return false
			moving=false;_actor=null;set_physics_process(false);_hand_part=part
			return true,
		"end":func(): _hand_part=null;open_state_changed.emit(opened)}

func _hand_sash_clear(angle: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=_sweep_shape;query.margin=0.0
	query.transform=global_transform*Transform3D(Basis(Vector3.RIGHT,-deg_to_rad(angle)),Vector3(0,-.44,-.13))*Transform3D(Basis.IDENTITY,Vector3(0,.44,-.008))
	var excluded: Array[RID] = []
	for body: CollisionObject3D in find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	query.exclude=excluded
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,128):
		if not is_ancestor_of(hit.collider): return false
	return true

func mechanism_snapshot() -> Dictionary:
	return {"angle":angle_degrees,"latch":latch_fraction}

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2: return false
	for key: String in ["angle","latch"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])): return false
	return float(value.angle)>=0 and float(value.angle)<=MAXIMUM_ANGLE and float(value.latch)>=0 and float(value.latch)<=1 and (float(value.angle)<=.5 or float(value.latch)>=.8)

func restore_mechanism(value: Dictionary) -> void:
	if not valid_mechanism(value): return
	_hand_part=null;moving=false;_actor=null;set_physics_process(false)
	angle_degrees=float(value.angle);latch_fraction=float(value.latch);opened=angle_degrees>.5
	_apply_pose()
