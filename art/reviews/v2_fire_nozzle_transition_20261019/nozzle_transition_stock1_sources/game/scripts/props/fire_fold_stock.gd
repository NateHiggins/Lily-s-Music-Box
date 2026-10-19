extends Node3D
## Native continuous folds and an annular outlet throat; no fact/save owner.
const PATH="res://data/orison_v2/fire_fold_stock.json"
var actor: Node3D
var data: Dictionary={}
var meshes: Dictionary={}
var returns: Array[MeshInstance3D]=[]
var nozzle_throat: MeshInstance3D
var _signature: Array=[]
func configure(owner_actor: Node3D) -> bool:
	actor=owner_actor
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if raw is not Dictionary or raw.get("schema_version")!=1:return false
	data=raw
	if data.parts is not Array or data.parts.size()!=12:return false
	for key: String in ["outlet_from_crown_m","nozzle_from_leaf_m"]:
		if data.get(key) is not Array or data[key].size()!=3:return false
		for coordinate: Variant in data[key]:
			if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return false
	if data.get("nozzle_mouth_axes") is not Dictionary or data.nozzle_mouth_axes.size()!=4:return false
	for key: String in ["00","01","10","11"]:
		var axis: Variant=data.nozzle_mouth_axes.get(key)
		if axis is not Array or axis.size()!=3:return false
		for coordinate: Variant in axis:
			if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return false
		if absf(Vector3(axis[0],axis[1],axis[2]).length()-1.)>.00001:return false
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
	model.free()
	for key: String in ["FoldPair","FirstPair","LastLeg","Crown","OutletThroat","ReturnFlat","ReturnRise","ReturnDrop","NozzleThroat00","NozzleThroat01","NozzleThroat10","NozzleThroat11"]:
		if not meshes.has(key) or key not in data.parts:return false
	var spec: Dictionary=data.material
	if spec.pigment!=1.:return false
	var tint: Array=spec.tint
	var finish: StandardMaterial3D=MatLib.get_mat(str(spec.catalog_key)).duplicate()
	finish.uv1_triplanar=false;finish.uv1_scale=Vector3.ONE;finish.albedo_color=Color(tint[0],tint[1],tint[2],tint[3]);finish.normal_scale=spec.normal;finish.roughness=spec.roughness;finish.metallic=spec.metallic
	if not finish.normal_enabled or finish.albedo_texture==null or finish.normal_texture==null or finish.roughness_texture==null:return false
	for index in range(actor._fold_leaves.size()):
		var leaf: MeshInstance3D=actor._fold_leaves[index]
		leaf.mesh=meshes.LastLeg if index==9 else (meshes.FirstPair if index==0 else meshes.FoldPair);leaf.material_override=finish
		leaf.set_meta("native_fire_successor","fire_fold_stock")
		var crown: MeshInstance3D=leaf.get_node("NativeFoldCrown")
		crown.mesh=meshes.OutletThroat if index==9 else meshes.Crown;crown.material_override=finish
		actor._fold_turns[index].mesh=null;actor._fold_turns[index].set_meta("native_fire_successor","fire_fold_stock/returns")
		if index==0:continue
		var turn:=MeshInstance3D.new();turn.name="ConnectedReturn%02d"%index;turn.material_override=finish;add_child(turn);returns.append(turn)
	nozzle_throat=MeshInstance3D.new();nozzle_throat.name="NozzleTransition";nozzle_throat.material_override=finish;add_child(nozzle_throat)
	_process(0.)
	return returns.size()==9
func _process(_delta: float) -> void:
	if actor==null or returns.size()!=9:return
	var signature: Array=[]
	for leaf: Node3D in actor._fold_leaves:signature.append(actor.to_local(leaf.global_position))
	signature.append(actor.nozzle_coupled)
	if signature==_signature:return
	for index in range(1,10):
		var here: Vector3=signature[index];var previous: Vector3=signature[index-1]
		var difference: float=previous.y-here.y
		returns[index-1].mesh=meshes.ReturnRise if difference>.001 else (meshes.ReturnDrop if difference<-.001 else meshes.ReturnFlat)
		returns[index-1].position=here+Vector3(-.010,-.131,0)
	var offset: Array=data.nozzle_from_leaf_m
	nozzle_throat.position=signature[0]+Vector3(offset[0],offset[1],offset[2])
	nozzle_throat.mesh=meshes["NozzleThroat%d%d"%[int(actor.folds_fresh),int(actor.nozzle_coupled)]]
	_signature=signature
func outlet_position() -> Vector3:
	var endpoint: Array=data.outlet_from_crown_m
	return actor.to_local(actor._fold_leaves.back().get_node("NativeFoldCrown").to_global(Vector3(endpoint[0],endpoint[1],endpoint[2])))
func nozzle_connection() -> Dictionary:
	var axis: Array=data.nozzle_mouth_axes["%d%d"%[int(actor.folds_fresh),int(actor.nozzle_coupled)]]
	return {"at":nozzle_throat.global_position,"axis":actor.global_basis*Vector3(axis[0],axis[1],axis[2])}
