extends RefCounted
## Native captured nut, receiving hose seat and open nozzle spigot.
const PATH="res://data/orison_v2/fire_nozzle_joint.json"
var data: Dictionary={}
var meshes: Dictionary={}
var finish: StandardMaterial3D
var physical_nut: ConcavePolygonShape3D
var physical_bounds:=AABB()
var clearance_start:=0.
var clearance_end:=0.
var clearance_radius:=0.
var pilot_min:=0.
var pilot_max:=0.
var pilot_clearance:=0.
var pilot_entry:=0.
func load_stock() -> bool:
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if raw is not Dictionary or raw.get("schema_version")!=1:return false
	data=raw
	if data.dimensions is not Dictionary or data.parts is not Dictionary or data.parts.size()!=3:return false
	var d: Dictionary=data.dimensions
	for key: String in ["pitch_m","radial_clearance_m","bore_radius_m","sealing_plane_y_m","nozzle_base_y_m","withdrawal_m"]:
		if typeof(d.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(d[key])) or d[key]<=0.:return false
	if d.pitch_m>=d.withdrawal_m or d.radial_clearance_m>=d.bore_radius_m or d.sealing_plane_y_m>=d.nozzle_base_y_m:return false
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
	model.free()
	if meshes.size()!=3:return false
	for key: String in ["HoseSeat","NozzleNut","NozzleSpigot"]:
		if not meshes.has(key) or data.parts.get(key)!="brass":return false
	if data.materials is not Dictionary or data.materials.size()!=1:return false
	var collision: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/fire_nozzle_collision.json"))
	if collision is not Dictionary or collision.get("schema_version")!=1 or collision.get("source_asset")!=data.asset:return false
	clearance_start=collision.clearance_start_m;clearance_end=collision.clearance_end_m;clearance_radius=collision.clearance_radius_m
	pilot_min=collision.pilot_origin_min_m;pilot_max=collision.pilot_origin_max_m;pilot_clearance=collision.pilot_clearance_m
	pilot_entry=collision.pilot_entry_radius_m
	if not is_finite(pilot_entry) or pilot_entry<=0.:return false
	if not is_finite(pilot_min) or not is_finite(pilot_max) or not is_finite(pilot_clearance) or pilot_min>=pilot_max or pilot_clearance<=0.:return false
	if not is_finite(clearance_start) or not is_finite(clearance_end) or not is_finite(clearance_radius) or clearance_start>=clearance_end or clearance_radius<=0.:return false
	if collision.vertices is not Array or collision.indices is not Array or collision.indices.size()%3!=0:return false
	var vertices:=PackedVector3Array();var faces:=PackedVector3Array()
	for point: Variant in collision.vertices:
		if point is not Array or point.size()!=3:return false
		var vertex:=Vector3(point[0],point[1],point[2])
		if not vertex.is_finite():return false
		vertices.append(vertex)
		physical_bounds=AABB(vertex,Vector3.ZERO) if vertices.size()==1 else physical_bounds.expand(vertex)
	for index: Variant in collision.indices:
		if typeof(index) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(index)) or index!=floor(float(index)) or index<0 or index>=vertices.size():return false
		faces.append(vertices[int(index)])
	if faces.is_empty():return false
	physical_nut=ConcavePolygonShape3D.new();physical_nut.backface_collision=true;physical_nut.set_faces(faces)
	var spec: Dictionary=data.materials.brass
	if spec.pigment!=1.:return false
	var tint: Array=spec.tint
	finish=MatLib.get_mat(str(spec.catalog_key)).duplicate()
	finish.uv1_triplanar=false;finish.albedo_color=Color(tint[0],tint[1],tint[2],tint[3]);finish.normal_scale=spec.normal;finish.roughness=spec.roughness;finish.metallic=spec.metallic
	return finish.normal_enabled and finish.albedo_texture!=null and finish.normal_texture!=null and finish.roughness_texture!=null
func maximum_angle() -> float:return TAU*float(data.dimensions.withdrawal_m)/float(data.dimensions.pitch_m)
func body_y(angle: float) -> float:return float(data.dimensions.nozzle_base_y_m)+float(data.dimensions.pitch_m)*angle/TAU
func make_part(key: String) -> MeshInstance3D:
	var draw:=MeshInstance3D.new();draw.name=key;draw.mesh=meshes[key];draw.material_override=finish;return draw
