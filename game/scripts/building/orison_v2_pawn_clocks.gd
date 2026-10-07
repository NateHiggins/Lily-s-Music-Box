extends RefCounted
const ShopSeating := preload("res://scripts/building/orison_v2_shop_seating.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_pawnbroker":return true
	# This fitting introduces small panes but retires no original glazing.
	# Bind the unchanged shipping glazing owner explicitly before retirement.
	var glazing:=cell.get_node_or_null("F01_OWN_SHOP_PAWNBROKER_retail_shop_pawnbroker_glassish") as MeshInstance3D
	if glazing==null or glazing.mesh.get_surface_count()!=1:return false
	var original:=glazing.mesh
	var mat:=original.surface_get_material(0) as StandardMaterial3D
	if mat==null or mat.albedo_texture!=null or mat.roughness_texture==null or mat.normal_texture==null:return false
	if mat.roughness_texture.resource_path.get_file()!="T_glass_rough.png" or mat.normal_texture.resource_path.get_file()!="T_glass_normal.png":return false
	var shapes:=glazing.find_children("*","CollisionShape3D",true,false)
	if shapes.size()!=1 or shapes[0].shape is not ConcavePolygonShape3D:return false
	var faces: PackedVector3Array=shapes[0].shape.get_faces();var pose:=glazing.transform;var disabled: bool=shapes[0].disabled
	if not ShopSeating.mount_records(cell,layout,"res://data/orison_v2/pawn_clocks.json","PawnClocks","F01_retail_pawn_clocks_","pawn_clocks_part","",{"glassish":mat}):return false
	if glazing.mesh!=original or glazing.transform!=pose or shapes[0].disabled!=disabled or shapes[0].shape.get_faces()!=faces:return false
	cell.get_node("PawnClocks").set_meta("borrowed_glazing_owner",{"draw":glazing,"mesh":original,"faces":faces,"pose":pose,"disabled":disabled,"material":mat})
	return true
