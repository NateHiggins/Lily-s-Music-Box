extends RefCounted
## Source-owned cases and stock with the existing clear dielectric finish.
const DATA := "res://data/orison_v2/pawn_display.json"
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_pawnbroker":return true
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if data is not Dictionary or cell.has_node("PawnDisplay"):return false
	var optics: Dictionary=data.optics
	if str(optics.role)!="Glazing" or str(optics.room_class)!="public" or str(optics.registered_owner)!="res://scripts/building/orison_v2_architectural_materials.gd" or str(optics.shader)!="res://shaders/lamp_glass_surface.gdshader" or float(optics.surface_roughness)!=.06:return false
	var original:=cell.get_node_or_null("F01_OWN_SHOP_PAWNBROKER_retail_shop_pawnbroker_glassish") as MeshInstance3D
	if original==null or original.mesh.get_surface_count()!=1 or original.material_override!=null:return false
	var factory:=ArchitecturalMaterials.new()
	var glass:=factory.material_for(str(optics.role),str(optics.room_class)) as ShaderMaterial
	if glass==null or glass.shader.resource_path!=str(optics.shader):return false
	glass.set_shader_parameter("surface_roughness",float(optics.surface_roughness))
	if not Seating.mount_pawn_display(cell,layout):return false
	var model: Node3D=cell.get_node("PawnDisplay")
	var panes:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("pawn_display_part","")).ends_with("__glassish"))
	if panes.size()!=3:return false
	for draw: MeshInstance3D in panes+[original]:
		if draw.mesh.surface_get_material(0) is not StandardMaterial3D:return false
		draw.set_meta("pawn_display_source_material",draw.mesh.surface_get_material(0))
		draw.set_meta("pawn_display_optical_owner",str(optics.registered_owner))
		draw.material_override=glass
	model.set_meta("optical_material",glass)
	model.set_meta("retained_glazing",{"draw":original,"mesh":original.mesh,"pose":original.transform,"faces":original.mesh.get_faces()})
	return true
