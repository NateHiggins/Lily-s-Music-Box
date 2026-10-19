extends RefCounted
## Native visual successor; original valve angle and ownership stay on actor.
var data: Dictionary={}
var meshes: Dictionary={}
var finishes: Dictionary={}
func load_stock() -> bool:
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/fire_nozzle_detail.json"))
	if raw is not Dictionary or raw.get("schema_version")!=1:return false
	data=raw
	if data.parts.size()!=6 or data.materials.size()!=2 or data.lever_pivot_m.size()!=3:return false
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model: Node=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
	model.free()
	if meshes.size()!=6:return false
	var specs: Dictionary={"brass":data.materials.brass,"iron":data.materials.iron}
	for key: String in specs:
		var spec: Dictionary=specs[key];var tint: Array=spec.tint
		if spec.pigment!=1. or tint.size()!=4:return false
		var finish: StandardMaterial3D=MatLib.get_mat(str(spec.catalog_key)).duplicate()
		finish.uv1_triplanar=false;finish.albedo_color=Color(tint[0],tint[1],tint[2],tint[3]);finish.normal_scale=spec.normal;finish.roughness=spec.roughness;finish.metallic=spec.metallic
		if not finish.normal_enabled or finish.albedo_texture==null or finish.normal_texture==null or finish.roughness_texture==null:return false
		finishes[key]=finish
	for key: String in ["Barrel","ValveGland","ThrustWasher","Spindle","SpindleNut","ForgedLever"]:
		if not meshes.has(key) or not finishes.has(str(data.parts.get(key,""))):return false
	return true
func fit(actor: Node3D) -> bool:
	var barrel: MeshInstance3D
	var lever: MeshInstance3D
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F059":barrel=draw
		elif str(draw.get_meta("native_fire_part",""))=="F061":lever=draw
	if barrel==null or lever==null:return false
	var pivot: Array=data.lever_pivot_m
	actor._lever.position=Vector3(pivot[0],pivot[1],pivot[2])
	for row: Array in [[barrel,"Barrel"],[lever,"ForgedLever"]]:
		var draw: MeshInstance3D=row[0];var key: String=row[1]
		draw.mesh=meshes[key];draw.material_override=finishes[data.parts[key]];draw.transform=Transform3D.IDENTITY;draw.set_meta("native_fire_successor","fire_nozzle_detail/"+key)
	lever.set_meta("nozzle_collision_axis",Transform3D(Basis(Vector3.RIGHT,-PI*.5),Vector3.ZERO))
	for key: String in ["ValveGland","ThrustWasher","Spindle","SpindleNut"]:
		var draw:=MeshInstance3D.new();draw.name="Native"+key;draw.mesh=meshes[key];draw.material_override=finishes[data.parts[key]];actor._play_pipe.add_child(draw)
		draw.set_meta("nozzle_collision_axis",Transform3D(Basis(Vector3.RIGHT,-PI*.5),Vector3(0,0,.044)))
		if key=="Spindle":draw.set_meta("nozzle_collision_solid",true)
	return true
