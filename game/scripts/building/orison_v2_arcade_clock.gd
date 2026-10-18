extends RefCounted
## Exact visual replacement; retained suspension, finial and shared time owners survive.
const DATA_PATH="res://data/orison_v2/arcade_clock.json"
const Seating=preload("res://scripts/building/orison_v2_shop_seating.gd")
const Materials=preload("res://scripts/building/orison_v2_architectural_materials.gd")
const Movement=preload("res://scripts/building/orison_v2_arcade_clock_movement.gd")
static func mount_cell(cell: Node3D,layout: Dictionary) -> bool:
	if str(cell.name)!="passage":return true
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var optics: Dictionary=data.optics
	if optics.role!="Glazing" or optics.room_class!="public" or optics.registered_owner!="res://scripts/building/orison_v2_architectural_materials.gd" or optics.shader!="res://shaders/lamp_glass_surface.gdshader":return false
	if not Seating.mount_arcade_clock(cell,layout):return false
	var model:=cell.get_node("ArcadeClock") as Node3D
	var glass:=Materials.new().material_for(str(optics.role),str(optics.room_class)) as ShaderMaterial
	if glass==null or glass.shader.resource_path!=str(optics.shader):return false
	glass.set_shader_parameter("surface_roughness",float(optics.surface_roughness))
	glass.set_shader_parameter("normal_strength",float(optics.normal_strength))
	var matched:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("arcade_clock_part",""))!=str(optics.glass_part):continue
		draw.set_meta("glazing_source_surface",draw.mesh.surface_get_material(0));draw.material_override=glass;matched+=1
	if matched!=1:return false
	model.set_meta("optical_material",glass)
	var movement:=Movement.new();movement.name="ClockMovement"
	if not movement.configure(model):movement.free();return false
	model.add_child(movement)
	return true
