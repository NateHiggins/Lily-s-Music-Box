extends Node3D
## Rigid manufactured stocks driven only by the existing car-gate span.
const Model := preload("res://assets/props/lift_gate.glb")
const CELLS := 7
const ROWS := 3
const LINK_LENGTH := 0.6334826
const COUNTS := {"DrilledLink":42,"CrossPin_n4_p4":14,"CrossPin_n10_p10":7,
	"BottomPin_p4":1,"BottomRoller":8,"BottomPin_n4_p4":6,"BottomPin_n4":1,
	"JointPin_n4_p10":2,"JointPin_n10_n4_p4_p10":12,"JointPin_n10_p4":2,
	"TopFollowerPin_n4":1,"UpperGuideTrolley":8,"TopRoller":8,
	"TopFollowerPin_n4_p4":6,"TopFollowerPin_p4":1,"FixedRailsAndMounts":1}
var gate: Node3D
var batches: Dictionary = {}
var observed_span := -1.0

func mount(lift: OrisonElevator) -> void:
	var library := Model.instantiate()
	for key: String in COUNTS:
		var part := library.find_child(key,true,false) as MeshInstance3D
		if part == null or part.mesh == null or not part.transform.is_equal_approx(Transform3D.IDENTITY):
			push_error("Lift gate requires its exact physical-metre template: " + key)
			library.free()
			return
	gate = lift._gate
	gate.position.z = .95
	# Private metre sampling retains catalogue tile scale and later finishes.
	var material := (gate.get_child(0) as MeshInstance3D).material_override.duplicate() as StandardMaterial3D
	material.uv1_triplanar = false
	for child in gate.get_children():
		if child is MeshInstance3D: child.hide()
	gate.add_child(self)
	for key: String in COUNTS:
		var part := library.find_child(key,true,false) as MeshInstance3D
		var node := MultiMeshInstance3D.new()
		node.name = key
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = part.mesh
		batch.instance_count = int(COUNTS[key])
		node.multimesh = batch
		node.material_override = material
		add_child(node)
		batches[key] = node
	library.free()
	_update_geometry()

func _process(_delta: float) -> void:
	if gate and not is_equal_approx(observed_span,gate.scale.x): _update_geometry()

static func _layer(row: int) -> float:
	return .004 if row % 2 == 0 else .010

static func _pin(kind: String, layers: Array[float]) -> String:
	layers.sort()
	var key := kind
	for value: float in layers:
		key += "_" + ("n" if value < 0 else "p") + str(roundi(absf(value)*1000.0))
	return key

func _place(indices: Dictionary,key: String,at: Vector3,basis := Basis.IDENTITY) -> void:
	var index := int(indices.get(key,0))
	(batches[key] as MultiMeshInstance3D).multimesh.set_instance_transform(index,Transform3D(basis,at))
	indices[key] = index + 1

func _update_geometry() -> void:
	observed_span = gate.scale.x
	# Cancel only owner squash; actual links, pins and rails remain unit-scale.
	scale.x = 1.0 / observed_span
	var dx := .91 * observed_span / CELLS
	var dy := sqrt(LINK_LENGTH*LINK_LENGTH-dx*dx)
	var indices := {}
	for row in ROWS:
		for column in CELLS:
			for side: float in [-1.0,1.0]:
				var direction := Vector3(side*dx,dy,0) / LINK_LENGTH
				var basis := Basis(Vector3(direction.y,-direction.x,0),direction,Vector3.BACK)
				_place(indices,"DrilledLink",Vector3((column+.5)*dx,.20+(row+.5)*dy,side*_layer(row)),basis)
			_place(indices,_pin("CrossPin",[-_layer(row),_layer(row)]),Vector3((column+.5)*dx,.20+(row+.5)*dy,0))
	for row in ROWS+1:
		for column in CELLS+1:
			var layers: Array[float] = []
			if row > 0:
				if column > 0: layers.append(_layer(row-1))
				if column < CELLS: layers.append(-_layer(row-1))
			if row < ROWS:
				if column < CELLS and not layers.has(_layer(row)): layers.append(_layer(row))
				if column > 0 and not layers.has(-_layer(row)): layers.append(-_layer(row))
			var kind := "BottomPin" if row == 0 else ("TopFollowerPin" if row == ROWS else "JointPin")
			_place(indices,_pin(kind,layers),Vector3(column*dx,.20+row*dy,0))
			var travel := column*dx-column*.91/CELLS
			if row == 0:
				_place(indices,"BottomRoller",Vector3(column*dx,.20,0),Basis(Vector3.BACK,-travel/.006))
			if row == ROWS:
				_place(indices,"UpperGuideTrolley",Vector3(column*dx,2.13,0))
				_place(indices,"TopRoller",Vector3(column*dx,2.1265,.0025),Basis(Vector3.BACK,-travel/.0055))
	_place(indices,"FixedRailsAndMounts",Vector3.ZERO)
	for key: String in COUNTS:
		assert(int(indices.get(key,0)) == int(COUNTS[key]),"Lift gate stock count: " + key)
