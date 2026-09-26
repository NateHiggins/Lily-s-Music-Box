extends Node3D
## Presentation of the existing lift. No independent travel or fault authority.
const Model := preload("res://assets/building/v2_lift_drive.glb")
const SHEAVE_RADIUS := .315
var lift: OrisonElevator
var sheave: Node3D
var sheave_base := Basis.IDENTITY
var observed_car_height := 0.0
var driven_angle := 0.0
var counterweight: AnimatableBody3D
var crosshead: Node3D
var car_ropes: Array[Node3D] = []
var counter_ropes: Array[Node3D] = []
var deflectors: Array[Node3D] = []
var deflector_bases: Array[Basis] = []
var counter_height := 0.0
var total_vertical_rope := 0.0

func configure(source: OrisonElevator) -> bool:
	if source == null or source._cabin == null: return false
	lift = source
	var model := Model.instantiate() as Node3D
	if model == null: return false
	sheave = model.find_child("TractionSheave",true,false) as Node3D
	if sheave == null:
		model.free()
		return false
	add_child(model)
	sheave_base = sheave.basis
	_apply_materials(model)
	crosshead = model.find_child("CarCrosshead",true,false) as Node3D
	var weight := model.find_child("Counterweight",true,false) as Node3D
	if crosshead == null or weight == null: return false
	counterweight = AnimatableBody3D.new()
	counterweight.name = "CounterweightBody"
	counterweight.sync_to_physics = false
	model.add_child(counterweight)
	_clear_scene_owner(weight)
	weight.reparent(counterweight,false)
	_shape(counterweight,Vector3(-.65,0,1.22),Vector3(.40,1.50,.10))
	for index in 4:
		var car := model.find_child("CarRope"+str(index),true,false) as Node3D
		var counter := model.find_child("CounterRope"+str(index),true,false) as Node3D
		if car == null or counter == null: return false
		car_ropes.append(car)
		counter_ropes.append(counter)
	for identity: String in ["FirstDeflector","SecondDeflector"]:
		var wheel := model.find_child(identity,true,false) as Node3D
		if wheel == null: return false
		deflectors.append(wheel)
		deflector_bases.append(wheel.basis)
	var guides := StaticBody3D.new()
	guides.name = "CounterweightGuides"
	add_child(guides)
	for x: float in [-.90,-.40]: _shape(guides,Vector3(x,-11.35,1.22),Vector3(.025,22.30,.09))
	for x: float in [-.85,1.05]: _shape(guides,Vector3(x,-11.35,-.441),Vector3(.025,22.30,.09))
	var guard := StaticBody3D.new()
	guard.name = "PlantGuard"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.14,1.925,2.425)
	collision.shape = shape
	collision.position.y = .9625
	collision.position.z = .1175
	guard.add_child(collision)
	add_child(guard)
	var label := Label3D.new()
	label.name = "DriveIdentification"
	label.text = "PASSENGER LIFT\nDRIVE — KEEP CLEAR"
	label.font_size = 36
	label.pixel_size = .0015
	label.modulate = Color(.8,.78,.7)
	label.position = Vector3(0,2.13,1.09)
	add_child(label)
	_update_drive()
	return true

func _physics_process(_delta: float) -> void:
	_update_drive()

func _update_drive() -> void:
	if not is_inside_tree() or not is_instance_valid(lift) or not is_instance_valid(lift._cabin): return
	observed_car_height = lift._cabin.position.y
	# The rear tangent now carries the car: positive X rotation raises it.
	driven_angle = observed_car_height / SHEAVE_RADIUS
	sheave.basis = sheave_base * Basis(Vector3.RIGHT,driven_angle)
	# Read the existing travel owner. No second motion integrator, scheduler,
	# interlock, fault state or save value is introduced here.
	var bottom: float = lift.stops[lift.stop_order.front()]
	var top: float = lift.stops[lift.stop_order.back()]
	counter_height = bottom+top+.9-observed_car_height
	var car_roof := to_local(lift._cabin.to_global(Vector3(0,2.40,0))).y
	crosshead.position.y = car_roof
	counterweight.position.y = to_local(lift.to_global(Vector3(0,counter_height,0))).y
	var car_length := 1.02-(car_roof+.10)
	var counter_length := .238-(counterweight.position.y+.83)
	total_vertical_rope = car_length+counter_length
	for index in 4:
		_set_rope(car_ropes[index],1.02,car_length)
		_set_rope(counter_ropes[index],.238,counter_length)
	for index in deflectors.size():
		var direction := -1.0 if index == 0 else 1.0
		deflectors[index].basis = deflector_bases[index] * Basis(Vector3.RIGHT,direction*driven_angle*SHEAVE_RADIUS/.15)

func _set_rope(rope: Node3D, top: float, length: float) -> void:
	rope.position.y = top-length*.5
	rope.scale.y = maxf(.001,length)

func _shape(parent: CollisionObject3D, at: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = at
	parent.add_child(collision)

func _clear_scene_owner(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children(): _clear_scene_owner(child)

func _apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		for index in visual.mesh.get_surface_count():
			var material := visual.mesh.surface_get_material(index)
			if material != null and MatLib.SETS.has(material.resource_name):
				visual.set_surface_override_material(index,MatLib.get_mat(material.resource_name))
	for child: Node in node.get_children(): _apply_materials(child)
