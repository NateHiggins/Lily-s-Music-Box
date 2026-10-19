extends RefCounted
## Catalogue-bound native stock. Telephone truth remains HouseTelephoneNetwork.
const PLAN="res://data/orison_v2/house_switchboard.json"
var meshes: Dictionary={}
var finishes: Dictionary={}
var data: Dictionary={}

func _material(key: String,recipe: Dictionary) -> Material:
	var base: StandardMaterial3D=MatLib.get_mat(key).duplicate() as StandardMaterial3D
	var tint: Array=recipe.tint
	base.resource_name="M_"+key;base.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
	base.uv1_triplanar=false;base.uv1_scale=Vector3.ONE/float(MatLib.SETS[key][3])
	base.normal_enabled=base.normal_texture!=null;base.normal_scale=float(recipe.normal)
	base.roughness=float(recipe.roughness);base.metallic=float(recipe.get("metallic",base.metallic))
	if float(recipe.pigment)<.999:
		return SurfacePass.surface_for(base,{"pigment_variation":float(recipe.pigment),"relief_mul":0.})
	return base

func _part(parent: Node3D,identity: String) -> MeshInstance3D:
	var draw: MeshInstance3D=MeshInstance3D.new();draw.name=identity;draw.mesh=meshes[identity]
	draw.material_override=draw.mesh.surface_get_material(0);draw.set_meta("native_switchboard_part",identity);parent.add_child(draw)
	return draw

func mount(actor: HouseSwitchboardProp) -> bool:
	data=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	if data.get("schema_version")!=1:return false
	var packed: PackedScene=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node3D=packed.instantiate() as Node3D
	for recipe: Dictionary in data.finishes:
		var key: String=str(recipe.key)
		if not MatLib.SETS.has(key):model.free();return false
		finishes[key]=_material(key,recipe)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null or draw.mesh.get_surface_count()!=1:model.free();return false
		var key: String=str(draw.mesh.surface_get_material(0).resource_name)
		if not finishes.has(key):model.free();return false
		var stock: Mesh=draw.mesh.duplicate() as Mesh;stock.surface_set_material(0,finishes[key]);meshes[str(draw.name)]=stock
	model.free()
	if meshes.size()!=data.parts.size():return false
	for identity: String in data.parts:
		if not meshes.has(identity):return false
	if absf((meshes["PlugShaft"] as Mesh).get_aabb().end.z-float(data.plug.tip_z))>.0001:return false
	var fixed: Node3D=Node3D.new();fixed.name="NativeCabinet";actor.add_child(fixed)
	var collision: StaticBody3D=StaticBody3D.new();collision.name="NativeCabinetCollision";fixed.add_child(collision)
	for identity: String in data.parts:
		if identity.begins_with("Plug") or identity.begins_with("Listening") or identity.begins_with("Asking") or identity in ["CordStock","MountCleat"]:continue
		var draw: MeshInstance3D=_part(fixed,identity)
		var shape: CollisionShape3D=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();collision.add_child(shape)
	for y in [.15,.55]:
		var cleat: MeshInstance3D=_part(fixed,"MountCleat");cleat.position=Vector3(0,y,.09)
	actor._key=Node3D.new();actor._key.name="ListeningKey";actor._key.position=Vector3(data.key.pivot[0],data.key.pivot[1],data.key.pivot[2]);actor.add_child(actor._key)
	_part(actor._key,"ListeningKeyLever");_part(actor._key,"ListeningKeyKnob")
	var lamp: Node3D=Node3D.new();lamp.name="AskingLamp";lamp.position=Vector3(data.lamp.at[0],data.lamp.at[1],data.lamp.at[2]);actor.add_child(lamp)
	_part(lamp,"AskingLampBezel");actor._asking_lamp=_part(lamp,"AskingLampLens")
	actor._cord=Node3D.new();actor._cord.name="FlexibleCords";actor.add_child(actor._cord)
	actor.set_meta("v2_native_house_switchboard",true)
	return true

func plug(parent: Node3D,index: int) -> Node3D:
	var owner: Node3D=Node3D.new();owner.name="AnswerPlug" if index==0 else "TrunkPlug";parent.add_child(owner)
	for identity: String in data.parts:
		if identity.begins_with("Plug"):_part(owner,identity)
	return owner
