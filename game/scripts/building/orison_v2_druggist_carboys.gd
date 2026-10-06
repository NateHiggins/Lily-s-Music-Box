extends RefCounted
## Original hero identities; clear shells retain source maps and stoppers use opal glass.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")
const OpticalReceivers := preload("res://scripts/lamp/lamp_optical_receivers.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if str(cell.name)!="shop_otis_son":return true
	if not Seating.mount_druggist_carboys(cell,layout):return false
	var model: Node3D=cell.get_node("DruggistCarboys")
	var factory:=ArchitecturalMaterials.new()
	var glass:=factory.material_for("Glazing","public") as ShaderMaterial
	if glass==null or glass.shader.resource_path!="res://shaders/lamp_glass_surface.gdshader":return false
	glass.set_shader_parameter("surface_roughness",.06)
	var count:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("druggist_carboys_part",""))
		if not part.ends_with("__glassish_shell"):continue
		if draw.mesh.get_surface_count()!=1 or draw.mesh.surface_get_material(0) is not StandardMaterial3D:return false
		draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
		draw.set_meta("glazing_optical_owner","res://scripts/building/orison_v2_architectural_materials.gd")
		draw.material_override=glass
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The existing lamp owner binds and releases this surface automatically.
		# Twelve millimetres matches the shell wall.
		var haze:=OpticalReceivers.add_glass_haze(draw)
		var haze_material:=haze.material_override as ShaderMaterial
		haze_material.set_shader_parameter("thickness_m",.012)
		count+=1
	model.set_meta("optical_material",glass)
	return count==4
