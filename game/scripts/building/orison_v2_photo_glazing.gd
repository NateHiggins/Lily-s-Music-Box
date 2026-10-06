extends RefCounted
## Fixed source-owned thin panes share the existing architectural glass shader.
const DATA := "res://data/orison_v2/photo_glazing.json"
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_photo_supplies":return true
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is not Dictionary or cell.has_node("PhotoGlazing") or not cell.has_node("PhotoCounter"):return _refuse("data/model/counter preflight")
	var optics: Dictionary=data.optics
	if str(optics.role)!="Glazing" or str(optics.room_class)!="public" or str(optics.registered_owner)!="res://scripts/building/orison_v2_architectural_materials.gd" or str(optics.shader)!="res://shaders/lamp_glass_surface.gdshader" or float(optics.surface_roughness)!=.06:return _refuse("existing optical owner and declared finish")
	var counter: Node3D=cell.get_node("PhotoCounter")
	var panes: Array=counter.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("photo_counter_part","")).ends_with("counter__glassish"))
	if panes.size()!=1:return _refuse("original four-pane counter partition")
	var factory:=ArchitecturalMaterials.new()
	var glass:=factory.material_for(str(optics.role),str(optics.room_class)) as ShaderMaterial
	if glass==null or glass.shader.resource_path!=str(optics.shader):return _refuse("actual registered shader")
	# Make the shader's existing default explicit on this cell's own instance.
	glass.set_shader_parameter("surface_roughness",float(optics.surface_roughness))
	if not is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),float(optics.surface_roughness)):return _refuse("actual local roughness")
	if not Seating.mount_photo_glazing(cell,layout):return _refuse("original fixed-glass source fitting")
	var model: Node3D=cell.get_node("PhotoGlazing")
	var draws:=model.find_children("*","MeshInstance3D",true,false)
	assert(draws.size()==3)
	for draw: MeshInstance3D in draws+panes:
		assert(draw.mesh.get_surface_count()==1 and draw.mesh.surface_get_material(0) is StandardMaterial3D)
		draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
		draw.set_meta("glazing_original_override",{"material":draw.material_override})
		draw.set_meta("glazing_optical_owner",str(optics.registered_owner))
		draw.material_override=glass
	model.set_meta("optical_material",glass)
	return true

static func _refuse(reason: String) -> bool:
	push_error("V2 photographic glazing: "+reason)
	return false
