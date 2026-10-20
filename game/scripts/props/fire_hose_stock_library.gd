extends RefCounted
const PATH="res://data/orison_v2/fire_hose_stock.json"
const Hose=preload("res://scripts/props/native_flexible_hose.gd")
var data: Dictionary={}
var meshes: Dictionary={}
var finish: Material
func load_stock() -> bool:
	data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if int(data.get("schema_version",0))!=1:return false
	var packed: PackedScene=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		meshes[str(draw.name)]=draw.mesh
	model.free()
	if meshes.size()!=2 or data.stocks.size()!=2:return false
	for id: String in ["OutletStock","NozzleStock"]:
		if not meshes.has(id) or not data.stocks.has(id):return false
		var spec: Dictionary=data.stocks[id]
		var length: float=float(spec.get("length_m",0.))
		var outer: float=float(spec.get("outer_radius_m",0.))
		var inner: float=float(spec.get("inner_radius_m",0.))
		if not is_finite(length) or not is_finite(outer) or not is_finite(inner) or length<=0. or inner<=0. or outer<=inner:return false
		var bounds: AABB=meshes[id].get_aabb()
		if absf(bounds.size.y-length)>.0001 or absf(bounds.position.y)>.0001 or absf(bounds.size.x-outer*2.)>.0001 or absf(bounds.size.z-outer*2.)>.0001:return false
	finish=MatLib.get_mat(str(data.catalog_key)).duplicate()
	return true
func make_hose(id: String,appearance: Material=null) -> MeshInstance3D:
	if not meshes.has(id) or not data.stocks.has(id):return null
	var hose:=Hose.new()
	if not hose.bind(meshes[id],appearance if appearance!=null else finish,data.stocks[id]):hose.free();return null
	return hose
