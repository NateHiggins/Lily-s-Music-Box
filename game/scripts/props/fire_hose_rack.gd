extends Node3D
## Blender-built rack fits the actual retained crowns; owns no maintenance fact.
const PATH="res://data/orison_v2/fire_hose_rack.json"
var actor: Node3D
var data: Dictionary={}
var meshes: Dictionary={}
var finishes: Dictionary={}
var arms: Array[MeshInstance3D]=[]
var _signature: Array=[]

static func imported_faces(mesh: Mesh) -> PackedVector3Array:
	# Mesh.get_faces()/create_trimesh_shape() weld through a rounded TriangleMesh.
	# These small native bearings need the actual imported vertices instead.
	var faces:=PackedVector3Array()
	for surface in range(mesh.get_surface_count()):
		var arrays: Array=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():faces.append_array(vertices)
		else:
			for index in indices:faces.append(vertices[index])
	return faces

func _draw(key: String,at: Vector3) -> MeshInstance3D:
	var draw:=MeshInstance3D.new();draw.name=key;draw.set_meta("rack_stock",key);draw.mesh=meshes[key];draw.material_override=finishes[data.parts[key]];draw.position=at;add_child(draw)
	var body:=StaticBody3D.new();body.name="NativeRackCollision";draw.add_child(body)
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(imported_faces(draw.mesh))
	var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider)
	return draw

func configure(owner_actor: Node3D) -> bool:
	actor=owner_actor
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if raw is not Dictionary or raw.get("schema_version")!=1:return false
	data=raw
	if data.get("parts") is not Dictionary or data.parts.size()!=5 or data.get("materials") is not Dictionary or data.materials.size()!=2:return false
	for key: String in ["pivot_y_m","pivot_z_m"]:
		if typeof(data.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])) or data[key]<=0.:return false
	if data.get("tip_local_m") is not Array or data.tip_local_m.size()!=3:return false
	for item: Variant in data.tip_local_m:
		if typeof(item) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(item)):return false
	if absf(float(data.tip_local_m[0]))>.000001 or data.tip_local_m[1]<=0. or data.tip_local_m[2]<=0.:return false
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
	model.free()
	if meshes.size()!=5:return false
	for key: String in ["MountBracket","CarrierArm","MountScrew","Shaft","EndNut"]:
		if not meshes.has(key) or not data.parts.has(key):return false
	for key: String in ["iron","brass"]:
		if not data.materials.has(key):return false
		var spec: Dictionary=data.materials[key]
		if spec.pigment!=1.:return false
		var tint: Array=spec.tint
		var mat: StandardMaterial3D=MatLib.get_mat(str(spec.catalog_key)).duplicate()
		mat.uv1_triplanar=false;mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3]);mat.normal_scale=spec.normal;mat.roughness=spec.roughness;mat.metallic=spec.metallic
		if not mat.normal_enabled or mat.albedo_texture==null or mat.normal_texture==null or mat.roughness_texture==null:return false
		finishes[key]=mat
	for value: Variant in data.parts.values():
		if not finishes.has(value):return false
	var pivot:=Vector3(0,float(data.pivot_y_m),float(data.pivot_z_m))
	for x: float in [-.270,.045]:
		_draw("MountBracket",pivot+Vector3.RIGHT*x)
		for y: float in [-.021,.021]:_draw("MountScrew",Vector3(x,pivot.y+y,.022))
	_draw("Shaft",pivot);_draw("EndNut",pivot)
	for leaf: Node3D in actor._fold_leaves:arms.append(_draw("CarrierArm",Vector3.ZERO))
	_process(0.)
	return arms.size()==10

func _process(_delta: float) -> void:
	if actor==null or arms.size()!=actor._fold_leaves.size():return
	var signature: Array=[]
	for leaf: Node3D in actor._fold_leaves:
		var crown: Node3D=leaf.get_node("NativeFoldCrown")
		signature.append(actor.to_local(crown.global_position))
	if signature==_signature:return
	var tip:=Vector3(data.tip_local_m[0],data.tip_local_m[1],data.tip_local_m[2])
	var length: float=Vector2(tip.y,tip.z).length()
	for index in range(arms.size()):
		var crown: Vector3=signature[index]
		var height: float=crown.y-float(data.pivot_y_m)
		if absf(height)>=length:push_error("Rack finger cannot reach its actual crown");return
		arms[index].position=Vector3(crown.x,float(data.pivot_y_m),float(data.pivot_z_m))
		arms[index].rotation.x=atan2(tip.y,tip.z)-asin(height/length)
	_signature=signature
