extends Node3D
## Physical breeching joins the installed smoke collar to the authored shaft.
## BoilerProp retains draft, heat and service authority; this is architecture.
const RADIUS := .17
var sections: Array[Dictionary] = []
var chimney_base := Vector3.ZERO
var chimney_top := Vector3.ZERO

func mount(boiler: BoilerProp, layout: Dictionary) -> bool:
	var shaft: Dictionary = {}
	for record: Dictionary in layout.risers:
		if record.id == "B1_BOILER_FLUE": shaft = record
	if shaft.is_empty(): return false
	var rect: Array = shaft.rect
	var start := to_local(boiler.smoke_outlet())
	# Rise at the plant before crossing the tended rear aisle. The underside
	# of every horizontal section is 2.48 m above the basement floor.
	var high := to_local(boiler.global_position).y+2.65
	var inlet := Vector3(float(rect[0]),high,(float(rect[1])+float(rect[3]))*.5)
	var points: Array[Vector3] = [start,Vector3(start.x,high,start.z),
		Vector3(start.x,high,inlet.z),inlet]
	for index in points.size()-1:
		_pipe(points[index],points[index+1],index)
	for index in points.size()-1:
		var elbow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = RADIUS
		sphere.height = RADIUS*2
		sphere.radial_segments = 16
		sphere.rings = 8
		elbow.mesh = sphere
		elbow.material_override = MatLib.get_mat("cast_iron")
		elbow.position = points[index]
		add_child(elbow)
	var center := Vector3((float(rect[0])+float(rect[2]))*.5,float(shaft.to_y),inlet.z)
	chimney_base = center
	chimney_top = center+Vector3.UP*2.1
	var width := float(rect[2])-float(rect[0])
	var depth := float(rect[3])-float(rect[1])
	# Open masonry mouth above the roof. The existing enclosed structural
	# shaft below is retained; no simulated gas flow or new floor void is added.
	for side in [-1.0,1.0]:
		_box("Cheek",center+Vector3(side*(width-.10)*.5,1.05,0),Vector3(.10,2.1,depth),"brick")
		_box("Face",center+Vector3(0,1.05,side*(depth-.10)*.5),Vector3(width-.20,2.1,.10),"brick")
		_box("CopingSide",chimney_top+Vector3(side*(width-.10)*.5,0,0),Vector3(.16,.12,depth+.12),"concrete")
		_box("CopingEnd",chimney_top+Vector3(0,0,side*(depth-.10)*.5),Vector3(width-.20,.12,.16),"concrete")
	return true

func _pipe(a: Vector3, b: Vector3, index: int) -> void:
	var direction := (b-a).normalized()
	var length := a.distance_to(b)
	var basis := Basis(Quaternion(Vector3.UP,direction))
	var body := StaticBody3D.new()
	body.name = "Breeching_"+str(index)
	body.transform = Transform3D(basis,(a+b)*.5)
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = length
	mesh.radial_segments = 24
	visual.mesh = mesh
	visual.material_override = MatLib.get_mat("cast_iron")
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = length
	collision.shape = cylinder
	body.add_child(collision)
	sections.append({"from":a,"to":b,"body":body})
	# Raised slip-joint bands make the route and assembly readable by lamp.
	for along in [.12,length-.12]:
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = RADIUS+.015
		ring_mesh.bottom_radius = RADIUS+.015
		ring_mesh.height = .045
		ring_mesh.radial_segments = 24
		ring.mesh = ring_mesh
		ring.position.y = along-length*.5
		ring.material_override = MatLib.get_mat("metal")
		body.add_child(ring)

func _box(label: String, at: Vector3, size: Vector3, material: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = MatLib.get_mat(material)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
