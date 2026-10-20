extends RefCounted
## Native case/frame successor. The inherited pivot and all repair facts remain.
const PATH := "res://data/orison_v2/fire_cabinet_skin.json"
var data: Dictionary={}
var meshes: Dictionary={}
var finishes: Dictionary={}
var aliases: Dictionary={}
var station_styles: Dictionary={}
var retired_visuals: Array=[]

func load_stock() -> bool:
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if raw is not Dictionary or raw.get("schema_version")!=1:return false
	data=raw
	retired_visuals=data.retired_source_visuals
	for row: Dictionary in data.station_styles:station_styles[str(row.station_id)]=str(row.style)
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):meshes[str(draw.name)]=draw.mesh
	model.free()
	if meshes.size()!=data.parts.size():return false
	for spec: Dictionary in data.materials:
		var key: String=str(spec.catalog_key)
		if not MatLib.SETS.has(str(spec.catalog_key)):return false
		var mat: StandardMaterial3D
		if key.begins_with("glass_"):mat=preload("res://scripts/building/orison_v2_expressive_glass.gd").make(key)
		else:mat=MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
		if mat==null:return false
		mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/float(spec.tile)
		mat.normal_scale=float(spec.normal);mat.roughness=1.
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if not mat.normal_enabled or mat.normal_texture==null:return false
		finishes[key]=mat
	for record: Dictionary in data.parts:
		var key: String=str(record.id)
		if not meshes.has(key):return false
		var finish: String=str(record.material)
		if not finishes.has(finish):return false
		var mesh: ArrayMesh=meshes[key].duplicate() as ArrayMesh
		for surface in mesh.get_surface_count():mesh.surface_set_material(surface,finishes[finish])
		meshes[key]=mesh
	aliases={"Paint":finishes.fire_cabinet_enamel,"Lining":finishes.fire_cabinet_lining,
		"Iron":finishes.fire_hardware_steel,"Brass":finishes.radiator_service_brass,"Glass":finishes.glass_cut}
	return true

func fit(actor: Node3D) -> bool:
	if not station_styles.has(actor.station_id):return false
	var style: String=str(station_styles[actor.station_id])
	if not finishes.has(style):return false
	for pane: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if pane.get_meta("native_fire_part","")=="F069":
			pane.material_override=finishes[style]
			pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for record: Dictionary in data.parts:
		var key: String=str(record.id)
		if key.begins_with("F") and key.length()==4:continue
		var position: Array=record.position
		var at:=Vector3(position[0],position[1],position[2])
		var draw:=MeshInstance3D.new();draw.name=key;draw.mesh=meshes[key]
		draw.set_meta("native_fire_skin",key)
		if record.parent=="door":
			actor._door_pivot.add_child(draw);draw.position=at-actor._door_pivot.position
		else:actor.add_child(draw);draw.position=at
		if str(record.material).begins_with("glass_"):draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true
