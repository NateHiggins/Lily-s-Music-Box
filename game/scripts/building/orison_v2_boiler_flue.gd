extends Node3D
## Physical breeching joins the installed smoke collar to the authored shaft.
## BoilerProp retains draft, heat and service authority; this is architecture.
const RADIUS := .17
const BEND := .27
const FABRICATION := preload("res://assets/props/breeching.glb")
var meshes: Dictionary = {}
var elbows: Array[StaticBody3D] = []
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
	var source := FABRICATION.instantiate()
	for part: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		meshes[str(part.name)]=part.mesh
	source.free()
	# The smoke collar exits horizontally. Give it a real elbow into the
	# vertical leg instead of beginning a capped cylinder at a sphere.
	var outward := (global_basis.inverse()*boiler.global_basis.z).normalized()
	var first := start+outward*BEND
	# Rise at the plant before crossing the tended rear aisle. The underside
	# of every horizontal section is 2.48 m above the basement floor.
	var high := to_local(boiler.global_position).y+2.65
	var inlet := Vector3(float(rect[0]),high,(float(rect[1])+float(rect[3]))*.5)
	var points: Array[Vector3] = [first,Vector3(first.x,high,first.z),
		Vector3(first.x,high,inlet.z),inlet]
	_elbow(first,outward,Vector3.UP,0)
	for index in points.size()-1:
		var direction := (points[index+1]-points[index]).normalized()
		var a := points[index]+direction*BEND
		var b := points[index+1]-direction*BEND if index<points.size()-2 else points[index+1]
		if a.distance_to(b)<.04 or (b-a).dot(direction)<=0:
			push_error("Breeching route cannot fit its fabricated elbows")
			return false
		_pipe(a,b,index)
		if index<points.size()-2:
			_elbow(points[index+1],direction,(points[index+2]-points[index+1]).normalized(),index+1)
	# Preserve the public route endpoint: the first elbow's mouth is exactly
	# the installed collar, while its straight leg starts above the bend.
	sections[0]["from"]=start
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
	var crown := (preload("res://assets/props/chimney_crown.glb") as PackedScene).instantiate() as Node3D
	crown.name="FittedChimneyCrown"
	crown.position=chimney_base
	crown.scale=Vector3(width/.45,1.0,depth/.70)
	add_child(crown)
	for part: MeshInstance3D in crown.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			part.set_surface_override_material(surface,MatLib.get_mat(part.mesh.surface_get_material(surface).resource_name))
	return true

func _pipe(a: Vector3, b: Vector3, index: int) -> void:
	var direction := (b-a).normalized()
	var length := a.distance_to(b)
	var basis := Basis(Quaternion(Vector3.UP,direction))
	var body := StaticBody3D.new()
	body.name = "Breeching_"+str(index)
	body.transform = Transform3D(basis,(a+b)*.5)
	add_child(body)
	var visual := _visual(body,"Pipe")
	# Bake the authored length into positions and metre UVs so MatLib's local
	# triplanar projection does not stretch a one-metre texture along the run.
	var pipe := ArrayMesh.new()
	for surface in visual.mesh.get_surface_count():
		var arrays := visual.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		for vertex in vertices.size(): vertices[vertex].y*=length
		for vertex in uv.size(): uv[vertex].y*=length
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uv
		pipe.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	visual.mesh=pipe
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = length
	collision.shape = cylinder
	body.add_child(collision)
	sections.append({"from":a,"to":b,"body":body})
	# Raised slip-joint bands make the route and assembly readable by lamp.
	for along in [-length*.5,length*.5]:
		var ring := _visual(body,"SlipBand")
		ring.position.y=along

func _visual(parent: Node3D, key: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name=key
	visual.mesh=meshes[key]
	for surface in visual.mesh.get_surface_count():
		visual.set_surface_override_material(surface,MatLib.get_mat(visual.mesh.surface_get_material(surface).resource_name))
	parent.add_child(visual)
	return visual

func _elbow(corner: Vector3, incoming: Vector3, outgoing: Vector3, index: int) -> void:
	var body := StaticBody3D.new()
	body.name="FabricatedElbow_"+str(index)
	body.transform=Transform3D(Basis(outgoing,incoming,outgoing.cross(incoming)),corner)
	add_child(body)
	var visual := _visual(body,"Elbow")
	var collision := CollisionShape3D.new()
	collision.shape=visual.mesh.create_trimesh_shape()
	body.add_child(collision)
	elbows.append(body)

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
	# Imported bonded masonry owns presentation; these eight original boxes
	# continue to own the chimney's physical envelope and coping collisions.
	visual.visible=false
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
