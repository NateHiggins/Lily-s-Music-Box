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
	if moving or RealityState.save_write_blocked:return {}
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
	opened=value;moving=false;_actor=null;set_physics_process(false)
	angle_degrees=MAXIMUM_ANGLE if value else 0.0
	latch_fraction=1.0 if value else 0.0
	_apply_pose()
