extends RefCounted
## Fixed supply fabric. Original panel and lighting owners retain their authority.
const PATH := "res://data/orison_v2/electrical_connections.json"
var errors: Array[String] = []
var meshes: Dictionary = {}
var installed: Array[MeshInstance3D] = []
var segments: Array[Dictionary] = []
var data: Dictionary
var _root: Node3D
var _native: RefCounted
var source_actor: WeakRef

func mount(world: Node3D,native: RefCounted) -> bool:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH)); _native=native
	if data.get("schema_version") != 1: return false
	var actor: Node3D = world.adapter.resolve(str(data.panel_actor))
	if actor == null or actor.get_meta("v2_native_domestic_variant","") != "DomesticObject46":
		errors.append("source panel conduit absent"); return false
	source_actor=weakref(actor)
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("connection stock absent"); return false
	var model := packed.instantiate()
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh.duplicate() as ArrayMesh
		for i in mesh.get_surface_count():
			var key := str(mesh.surface_get_material(i).resource_name)
			if not MatLib.SETS.has(key): errors.append("connection finish "+key); continue
			var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/.65;mat.normal_scale=.15;mat.metallic=.75
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if key=="iron_neutral":mat.albedo_color=Color(.35,.37,.39)
			if key=="brass_dull":
				mat.metallic=.65
				mat.albedo_texture=load("res://assets/building/textures/mailbank/T_mailbank_brass_albedo.png")
				mat.roughness_texture=load("res://assets/building/textures/mailbank/T_mailbank_brass_rough.png")
			mesh.surface_set_material(i,mat)
		meshes[str(node.name)]=mesh
	model.free()
	if meshes.size()!=6 or not errors.is_empty():return false
	var tee := _point(data.tee_position)
	if not is_equal_approx(tee.y,float(native.data.get("feed_tee_y",INF))):
		errors.append("riser tee gap differs from supply datum");return false
	_root=Node3D.new();_root.name="NativeElectricalConnections";world.adapter.root.add_child(_root)
	var draw := _draw("RiserFeedTee",tee)
	var body := StaticBody3D.new();draw.add_child(body)
	var collider := CollisionShape3D.new();collider.shape=draw.mesh.create_trimesh_shape();body.add_child(collider)
	var points: Array[Vector3]=[]
	for p: Array in data.route_corners:points.append(_point(p))
	var radius := float(data.bend_radius);var start := points[0]
	for i in range(1,points.size()-1):
		var incoming := (points[i]-points[i-1]).normalized()
		var outgoing := (points[i+1]-points[i]).normalized()
		_span(start,points[i]-incoming*radius)
		_draw("FeedElbow",points[i]-incoming*radius,Basis(outgoing,incoming,outgoing.cross(incoming)))
		start=points[i]+outgoing*radius
	_span(start,points.back())
	_span(_point(data.utility_entry[0]),_point(data.utility_entry[1]),"UtilityEntryUnit",.016)
	for p: Array in data.ceiling_bearings:
		var at := _point(p)
		var axis := Vector3.BACK if at.x<8.1 else Vector3.RIGHT
		_draw("ThreadedCoupling",Vector3(at.x,-.32,at.z),Basis(Quaternion(Vector3.UP,axis)))
		_span(Vector3(at.x,-.291,at.z),Vector3(at.x,-.204,at.z),"CeilingRodUnit",.0035)
		_draw("CeilingSeat",Vector3(at.x,-.202,at.z))
		_draw("CeilingScrews",Vector3(at.x,-.202,at.z))
	return errors.is_empty()

func _point(p: Array) -> Vector3:return Vector3(p[0],p[1],p[2])
func _draw(key: String,at: Vector3,basis: Basis = Basis.IDENTITY) -> MeshInstance3D:
	var draw := MeshInstance3D.new();draw.name=key
	draw.mesh=meshes.get(key,_native.meshes.get(key));_root.add_child(draw);draw.transform=Transform3D(basis,at)
	draw.set_meta("native_electrical_connection",key);installed.append(draw);return draw
func _span(a: Vector3,b: Vector3,key: String = "ConduitUnit",radius: float = .0225) -> void:
	var length := a.distance_to(b)
	if length<=.001:errors.append("empty supply span");return
	var draw := _draw(key,(a+b)*.5,Basis(Quaternion(Vector3.UP,(b-a)/length)))
	draw.mesh=_native._scale_stock._length_mesh(draw.mesh,length)
	var body := StaticBody3D.new();draw.add_child(body)
	var collider := CollisionShape3D.new();var shape := CylinderShape3D.new()
	shape.radius=radius;shape.height=length;collider.shape=shape;body.add_child(collider)
	segments.append({"a":a,"b":b,"draw":weakref(draw)})
