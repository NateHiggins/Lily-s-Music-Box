extends RefCounted
## One source-owned passive furnishing batch; shared mounting keeps all source owners.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_pawnbroker":return true
	# The new bell and loupe borrow the retained window's optical maps.
	var glazing:=cell.get_node_or_null("F01_OWN_SHOP_PAWNBROKER_retail_shop_pawnbroker_glassish") as MeshInstance3D
	if glazing==null or glazing.mesh.get_surface_count()!=1:return false
	var original:=glazing.mesh
	var mat:=original.surface_get_material(0) as StandardMaterial3D
	if mat==null or mat.albedo_texture!=null or mat.roughness_texture==null or mat.normal_texture==null:return false
	if mat.roughness_texture.resource_path.get_file()!="T_glass_rough.png" or mat.normal_texture.resource_path.get_file()!="T_glass_normal.png":return false
	var shapes:=glazing.find_children("*","CollisionShape3D",true,false)
	if shapes.size()!=1 or shapes[0].shape is not ConcavePolygonShape3D:return false
	var faces: PackedVector3Array=shapes[0].shape.get_faces();var pose:=glazing.transform;var disabled: bool=shapes[0].disabled
	if not Seating.mount_pawn_fittings(cell,layout,{"glassish":mat}):return false
	if glazing.mesh!=original or glazing.transform!=pose or shapes[0].disabled!=disabled or shapes[0].shape.get_faces()!=faces:return false
	var model: Node3D=cell.get_node("PawnFittings")
	model.set_meta("borrowed_glazing_owner",{"draw":glazing,"mesh":original,"faces":faces,"pose":pose,"disabled":disabled,"material":mat})
	var display: Node3D=cell.get_node_or_null("PawnDisplay")
	if display==null:return false
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("pawn_fittings_part","")).ends_with("__glassish"):
			draw.material_override=display.get_meta("optical_material")
	return true
