extends RefCounted
## Native thread stock and fitted screw transform; no maintenance facts owner.
const PATH="res://data/orison_v2/fire_joint_stock.json"
var data: Dictionary={}
var meshes: Dictionary={}
var finishes: Dictionary={}
func load_stock() -> bool:
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if raw is not Dictionary or int(raw.get("schema_version",0))!=1:return false
	data=raw
	var d: Dictionary=data.dimensions
	for value: Variant in d.values():
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<=0.:return false
	if d.pitch_m<=d.gasket_thickness_m or d.radial_clearance_m>=d.bore_radius_m or d.male_origin_y_m<=d.empty_union_origin_y_m:return false
	var packed: PackedScene=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
	model.free()
	if meshes.size()!=6 or data.parts.size()!=6:return false
	for id: String in ["MaleOutlet","FemaleUnion","SwivelTail","HoseNeck","HoseRetainer","UnionGasket"]:
		if not meshes.has(id) or not data.parts.has(id):return false
	if data.materials.size()!=3:return false
	for key: String in ["brass","rubber","linen"]:
		if not data.materials.has(key):return false
		var spec: Dictionary=data.materials[key]
		if float(spec.pigment)!=1.:return false
		var tint: Array=spec.tint
		var mat: StandardMaterial3D=MatLib.get_mat(str(spec.catalog_key)).duplicate()
		mat.uv1_triplanar=false;mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
		mat.normal_scale=float(spec.normal);mat.roughness=float(spec.roughness);mat.metallic=float(spec.metallic)
		if not mat.normal_enabled or mat.albedo_texture==null or mat.roughness_texture==null or mat.normal_texture==null:return false
		finishes[key]=mat
	for key: String in data.parts:
		if not finishes.has(data.parts[key]):return false
	if data.parts.MaleOutlet!="brass" or data.parts.FemaleUnion!="brass" or data.parts.UnionGasket!="rubber":return false
	if data.parts.SwivelTail!="brass" or data.parts.HoseNeck!="linen" or data.parts.HoseRetainer!="brass":return false
	return true
func make_part(id: String) -> MeshInstance3D:
	if not meshes.has(id):return null
	var draw:=MeshInstance3D.new();draw.name=id;draw.mesh=meshes[id];draw.material_override=finishes[data.parts[id]]
	return draw
func union_pose(angle: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,angle),Vector3(0,float(data.dimensions.empty_union_origin_y_m)-float(data.dimensions.pitch_m)*angle/TAU,0))
