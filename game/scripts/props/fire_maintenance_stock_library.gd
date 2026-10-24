extends RefCounted
## Shared native service stock, loaded once. Metre UVs and authored PBR maps.
const PATH := "res://data/orison_v2/fire_maintenance_meshes.json"
const PARTS := ["Bottle","Cap","Label","Tin","Gasket","BottleHinge","TerminalShell","TerminalMetal","TerminalLever"]
var meshes: Dictionary = {}
var finishes: Dictionary = {}
var data: Dictionary
var error := ""

func load_stock() -> bool:
	var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if decoded is not Dictionary or int(decoded.get("schema_version",0))!=1:return _fail("invalid service stock manifest")
	data=decoded
	if FileAccess.get_sha256(str(data.asset))!=str(data.asset_sha256):return _fail("service stock asset drift")
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return _fail("service stock export missing")
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var key:=str(draw.name)
		if key not in PARTS or meshes.has(key):model.free();return _fail("unexpected native service part: "+key)
		meshes[key]=draw.mesh
	model.free()
	if meshes.size()!=PARTS.size():return _fail("native service part count")
	for key: String in PARTS:
		var spec: Dictionary=data.finishes[key]
		var mat:=MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
		if mat==null or mat.albedo_texture==null or mat.roughness_texture==null or mat.normal_texture==null:return _fail("service PBR maps missing: "+key)
		mat.uv1_triplanar=false;mat.uv1_world_triplanar=false
		mat.uv1_scale=Vector3.ONE/float(MatLib.SETS[str(spec.catalog_key)][3])
		mat.normal_enabled=true;mat.normal_scale=float(spec.normal);mat.roughness=float(spec.roughness)
		if not is_equal_approx(float(spec.pigment),1.):return _fail("unsupported pigment mixture")
		var tint: Array=spec.tint
		mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		finishes[key]=mat
	return true

func draw(parent: Node3D, key: String) -> MeshInstance3D:
	var result:=MeshInstance3D.new();result.name=key;result.mesh=meshes[key];result.material_override=finishes[key]
	result.set_meta("fire_maintenance_part",key);parent.add_child(result)
	return result

func cap_pivot() -> Vector3:
	var p: Array=data.cap_pivot
	return Vector3(p[0],p[1],p[2])

func _fail(message: String) -> bool:
	error=message;return false
