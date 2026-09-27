extends Node3D
## Visual linkage driven by the production gate span; no independent state.
const Model := preload("res://assets/props/lift_gate.glb")
const CELLS := 7
const ROWS := 3
const LINK_LENGTH := 0.6334826 # sqrt((.91 / 7)^2 + .62^2)
var gate: Node3D
var links: MultiMeshInstance3D
var pivots: MultiMeshInstance3D
var tracks: MultiMeshInstance3D
var observed_span := -1.0

func mount(lift: OrisonElevator) -> void:
	gate = lift._gate
	# Landing leaves occupy z=.998..1.052. The car gate belongs behind
	# them, not through their steel faces as the old z=1.04 lattice did.
	gate.position.z = .95
	var material := (gate.get_child(0) as MeshInstance3D).material_override
	for child in gate.get_children():
		if child is MeshInstance3D: child.hide()
	gate.add_child(self)
	var library := Model.instantiate()
	links = _batch((library.find_child("GateLink",true,false) as MeshInstance3D).mesh,material,CELLS*ROWS*2+CELLS+1)
	pivots = _batch((library.find_child("GatePivot",true,false) as MeshInstance3D).mesh,material,(CELLS+1)*(ROWS+2)+CELLS*ROWS)
	tracks = _batch((library.find_child("GateTrack",true,false) as MeshInstance3D).mesh,material,2)
	library.free()
	_update_geometry()

func _process(_delta: float) -> void:
	if gate and not is_equal_approx(observed_span,gate.scale.x): _update_geometry()

func _batch(mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh; batch.instance_count = count
	node.multimesh = batch; node.material_override = material
	add_child(node)
	return node

func _update_geometry() -> void:
	observed_span = gate.scale.x
	# Cancel only the owner's X squash. The mesh placements use its span,
	# while every metal strip and pivot keeps its manufactured thickness.
	scale.x = 1.0/observed_span
	var width := .91*observed_span
	var dx := width/CELLS
	var dy := sqrt(LINK_LENGTH*LINK_LENGTH-dx*dx)
	var index := 0
	var pin := 0
	for row in ROWS:
		for column in CELLS:
			for side in [-1.0,1.0]:
				var direction := Vector3(side*dx,dy,0).normalized()
				var basis := Basis(Vector3(direction.y,-direction.x,0),direction,Vector3.BACK)
				basis = basis.scaled_local(Vector3(1,LINK_LENGTH,1))
				links.multimesh.set_instance_transform(index,Transform3D(basis,Vector3((column+.5)*dx,.20+(row+.5)*dy,side*.003)))
				index+=1
			pivots.multimesh.set_instance_transform(pin,Transform3D(Basis.IDENTITY,Vector3((column+.5)*dx,.20+(row+.5)*dy,0)))
			pin+=1
	for row in ROWS+1:
		for column in CELLS+1:
			pivots.multimesh.set_instance_transform(pin,Transform3D(Basis.IDENTITY,Vector3(column*dx,.20+row*dy,0)))
			pin+=1
	for rail in 2:
		tracks.multimesh.set_instance_transform(rail,Transform3D(Basis.IDENTITY.scaled(Vector3(.91,1,1)),Vector3(.455,.18 if rail==0 else 2.13,0)))
	# Top carriers slide vertically through the track as the fixed-length
	# lattice grows slightly taller during closure toward the parked stack.
	for column in CELLS+1:
		links.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3(1,.10,1)),Vector3(column*dx,.20+ROWS*dy+.05,0)))
		index+=1
		pivots.multimesh.set_instance_transform(pin,Transform3D(Basis.IDENTITY,Vector3(column*dx,2.13,0)))
		pin+=1
