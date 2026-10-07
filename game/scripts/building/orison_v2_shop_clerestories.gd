extends RefCounted
## Source clerestories retain openings and use the existing local glass owner.
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const ArchitecturalMaterials := preload("res://scripts/building/orison_v2_architectural_materials.gd")
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if not Seating.mount_shop_clerestories(cell,layout):return false
	if not cell.has_node("ShopClerestories"):return true
	var model: Node3D=cell.get_node("ShopClerestories")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/shop_clerestories.json"))
	var optics: Dictionary=data.optics
	if optics.role!="Glazing" or optics.room_class!="public" or optics.registered_owner!="res://scripts/building/orison_v2_architectural_materials.gd" or optics.shader!="res://shaders/lamp_glass_surface.gdshader" or float(optics.surface_roughness)!=.06:return false
	var glass:=ArchitecturalMaterials.new().material_for("Glazing","public") as ShaderMaterial
	if glass==null or glass.shader.resource_path!=str(optics.shader):return false
	glass.set_shader_parameter("surface_roughness",float(optics.surface_roughness))
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("shop_clerestories_part","")).ends_with("__glassish"):
			draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0))
			draw.material_override=glass
	model.set_meta("optical_material",glass)
	return true
