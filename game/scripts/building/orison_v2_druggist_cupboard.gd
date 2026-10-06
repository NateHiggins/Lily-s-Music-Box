extends RefCounted
## Original cupboard identities; the thin fixed pane uses the existing glass owner.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_otis_son":return true
	if not Seating.mount_druggist_cupboard(cell,layout):return false
	var model: Node3D=cell.get_node("DruggistCupboard")
	var factory:=ArchitecturalMaterials.new()
	var glass:=factory.material_for("Glazing","public") as ShaderMaterial
	if glass==null or glass.shader.resource_path!="res://shaders/lamp_glass_surface.gdshader":return false
	glass.set_shader_parameter("surface_roughness",.06)
	var count:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("druggist_cupboard_part","")) != "storm_shop_otis___son_poison_cupboard__glassish":continue
		if draw.mesh.get_surface_count()!=1 or draw.mesh.surface_get_material(0) is not StandardMaterial3D:return false
		draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
		draw.set_meta("glazing_optical_owner","res://scripts/building/orison_v2_architectural_materials.gd")
		draw.material_override=glass;count+=1
	model.set_meta("optical_material",glass)
	return count==1
