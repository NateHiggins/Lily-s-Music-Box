extends RefCounted
## Original dispensary identities; local thin panes use the existing glass owner.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_otis_son":return true
	if not Seating.mount_druggist_dispensary(cell,layout):return false
	var model: Node3D=cell.get_node("DruggistDispensary")
	var factory:=ArchitecturalMaterials.new()
	var glass:=factory.material_for("Glazing","public") as ShaderMaterial
	if glass==null or glass.shader.resource_path!="res://shaders/lamp_glass_surface.gdshader":return false
	glass.set_shader_parameter("surface_roughness",.06)
	var count:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("druggist_dispensary_part","")) not in ["storm_shop_otis___son_disp__glassish","storm_shop_otis___son_balance_case__glassish"]:continue
		if draw.mesh.get_surface_count()!=1 or draw.mesh.surface_get_material(0) is not StandardMaterial3D:return false
		draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
		draw.set_meta("glazing_optical_owner","res://scripts/building/orison_v2_architectural_materials.gd")
		draw.material_override=glass;count+=1
	model.set_meta("optical_material",glass)
	return count==2
